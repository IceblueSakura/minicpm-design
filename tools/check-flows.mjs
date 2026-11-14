// Behavioral checks for the single-file prototype; no app dependencies or build step.
// Run: node tools/check-flows.mjs (set CHROME_BIN when Chrome is not on PATH).
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { setTimeout as delay } from 'node:timers/promises';

const profile = await mkdtemp(join(tmpdir(), 'minicpm-flows-'));
const executable = process.env.CHROME_BIN ?? (process.platform === 'darwin'
  ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : 'google-chrome-stable');
const browser = spawn(executable, ['--headless=new', '--disable-gpu', '--disable-extensions', '--no-first-run',
  '--no-default-browser-check', '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'],
{ stdio: 'ignore' });
let launchError;
browser.on('error', error => { launchError = error; });
const exited = new Promise(resolve => { browser.once('exit', resolve); browser.once('error', resolve); });
let socket;

try {
  let port;
  const deadline = Date.now() + 10_000;
  while (!port && Date.now() < deadline) {
    if (launchError) throw launchError;
    try { port = Number((await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]); }
    catch { await delay(25); }
  }
  assert.ok(port, 'Chrome must expose a local debugging port');
  const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  socket = new WebSocket(pages.find(page => page.type === 'page').webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  let nextID = 0;
  const pending = new Map(), events = new Map(), pageErrors = [];
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.id) {
      const request = pending.get(message.id);
      if (!request) return;
      pending.delete(message.id);
      clearTimeout(request.timeout);
      if (message.error) request.reject(new Error(JSON.stringify(message.error)));
      else request.resolve(message.result);
    } else {
      if (message.method === 'Runtime.exceptionThrown') pageErrors.push(message.params.exceptionDetails);
      events.get(message.method)?.(message.params);
    }
  });
  const command = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++nextID;
    const timeout = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 10_000);
    pending.set(id, { resolve, reject, timeout });
    socket.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const result = await command('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    assert.equal(result.exceptionDetails, undefined, JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  await command('Page.enable');
  await command('Runtime.enable');
  const open = async query => {
    const loaded = new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Page did not load')), 10_000);
      events.set('Page.loadEventFired', () => { clearTimeout(timeout); events.delete('Page.loadEventFired'); resolve(); });
    });
    await command('Page.navigate', { url: new URL(`../index.html${query}`, import.meta.url).href });
    await loaded;
  };
  const until = async expression => {
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline) {
      if (await evaluate(expression)) return;
      await delay(10);
    }
    assert.fail(`Timed out waiting for ${expression}`);
  };

  for (const status of ['paused', 'wifi', 'failed', 'badfile']) {
    await test(`cancel first download (${status}) returns to model selection`, async () => {
      await open(`?onboard=download&dl=62&dlstate=${status}&still=1&backend=local`);
      const result = await evaluate(`document.querySelector('[data-action="dl-cancel"]').click();
        ({step:state.onboard, downloading:!!state.dl, modelChoices:document.querySelectorAll('[data-action="ob-pick"]').length})`);
      assert.equal(result.step, 'model');
      assert.equal(result.downloading, false);
      assert.ok(result.modelChoices > 0);
    });
  }

  await test('only one message queues; the second remains a draft', async () => {
    await open('?view=empty&prep=1&still=1&backend=local');
    const waiting = await evaluate(`$('#prompt').value='问题 A';send();$('#prompt').value='问题 B';syncComposer();send();
      ({draft:$('#prompt').value, disabled:$('#sendBtn').disabled, sent:cur().items.filter(x=>x.type==='user').map(x=>x.text)})`);
    assert.deepEqual(waiting, { draft: '问题 B', disabled: true, sent: ['问题 A'] });
    const started = await evaluate(`clearTimeout(loadTimer);state.loaded=state.model;finishLoad();
      ({draft:$('#prompt').value,request:state.lastRequest.messages.at(-1).text,answers:cur().items.filter(x=>x.type==='ai').length})`);
    assert.deepEqual(started, { draft: '问题 B', request: '问题 A', answers: 1 });
  });

  await test('retry targets the selected failed message and is single-flight', async () => {
    await open('?view=empty&engine=offline&still=1&backend=local');
    const result = await evaluate(`$('#prompt').value='问题 A';send();$('#prompt').value='问题 B';send();state.engine='ready';
      const first=cur().items[0];actions['retry-send']({dataset:{id:first.id}});actions['retry-send']({dataset:{id:first.id}});
      ({request:state.lastRequest.messages.at(-1).text,items:cur().items.map(x=>({type:x.type,text:x.text,failed:!!x.failed}))})`);
    assert.equal(result.request, '问题 A');
    assert.deepEqual(result.items.map(item => item.type), ['user', 'ai', 'user']);
    assert.equal(result.items[0].failed, false);
    assert.equal(result.items[2].failed, true);
    assert.equal(result.items[2].text, '问题 B');
    const regenerated = await evaluate(`finishReply();actions.regen(document.querySelector('.msg-ai [data-action=\"regen\"]'));
      ({request:state.lastRequest.messages.at(-1).text,items:cur().items.map(x=>({type:x.type,text:x.text,failed:!!x.failed}))})`);
    assert.equal(regenerated.request, '问题 A');
    assert.deepEqual(regenerated.items.map(item => item.type), ['user', 'ai', 'user']);
    assert.equal(regenerated.items[2].text, '问题 B');
    assert.equal(regenerated.items[2].failed, true);
  });

  await test('navigation preserves text and attachments, including reselecting the same chat', async () => {
    await open('?view=empty&still=1&backend=local');
    const result = await evaluate(`const original=state.current;$('#prompt').value='草稿内容';
      state.atts=[{id:'draft-image',kind:'image',name:'report.jpg'}];selectTask(original);newTask();
      const next=state.current;selectTask(original);
      ({different:next!==original,text:$('#prompt').value,attachments:state.atts.map(x=>x.name)})`);
    assert.deepEqual(result, { different: true, text: '草稿内容', attachments: ['report.jpg'] });
  });

  await test('a temporary draft and queued reply cannot survive leaving the conversation', async () => {
    await open('?view=empty&temp=1&prep=1&still=1&backend=local');
    const result = await evaluate(`const original=state.current;$('#prompt').value='临时内容';send();newTask();
      clearTimeout(loadTimer);state.loaded=state.model;finishLoad();
      ({exists:!!task(original),draft:!!state.drafts[original],queued:!!state.queued,reply:!!state.reply})`);
    assert.deepEqual(result, { exists: false, draft: false, queued: false, reply: false });
  });

  await test('deleting a queued conversation never starts an orphan reply', async () => {
    await open('?view=empty&prep=1&still=1&backend=local');
    const result = await evaluate(`const original=state.current;$('#prompt').value='删除前的消息';send();deleteTask(original);
      clearTimeout(loadTimer);state.loaded=state.model;finishLoad();
      ({exists:!!task(original),queued:!!state.queued,reply:!!state.reply})`);
    assert.deepEqual(result, { exists: false, queued: false, reply: false });
    const restored = await evaluate(`actions['toast-undo']();selectTask(original);
      ({text:cur().items[0].text,failed:cur().items[0].failed,retry:!!document.querySelector('[data-action=\"retry-send\"]')})`);
    assert.deepEqual(restored, { text: '删除前的消息', failed: true, retry: true });
  });

  await test('deleting a background queue unlocks the current composer immediately', async () => {
    await open('?view=empty&prep=1&still=1&backend=local');
    const result = await evaluate(`const original=state.current;$('#prompt').value='问题 A';send();newTask();
      $('#prompt').value='问题 B';syncComposer();deleteTask(original);
      ({draft:$('#prompt').value,disabled:$('#sendBtn').disabled,queued:!!state.queued})`);
    assert.deepEqual(result, { draft: '问题 B', disabled: false, queued: false });
  });

  await test('a cold load failure followed by an explicit location change releases the queue', async () => {
    await open('?view=empty&prep=1&still=1&backend=local');
    await evaluate(`state.proto.oom=true;$('#prompt').value='问题 A';send()`);
    await until(`!!state.swapFail`);
    assert.equal(await evaluate(`state.swapFail?.cold`), true);
    const result = await evaluate(`state.remote.url='https://gpu.example.com';setBackend('remote');
      const failed=cur().items[0].failed;$('#prompt').value='问题 B';send();
      ({failed,queued:!!state.queued,request:state.lastRequest.messages.at(-1).text})`);
    assert.deepEqual(result, { failed: true, queued: false, request: '问题 B' });
  });

  await test('retry after a location change places the destination mark before the retried message', async () => {
    await open('?view=empty&still=1&backend=local');
    const result = await evaluate(`$('#prompt').value='本机历史';send();finishReply();state.engine='offline';
      $('#prompt').value='问题 A';send();$('#prompt').value='问题 B';send();const first=cur().items[2];
      state.remote.url='https://gpu.example.com';setBackend('remote');state.engine='ready';
      actions['retry-send']({dataset:{id:first.id}});
      ({types:cur().items.map(x=>x.type),mark:cur().items[2].text,request:state.lastRequest.messages.at(-1).text})`);
    assert.deepEqual(result.types, ['user', 'ai', 'place', 'user', 'ai', 'user']);
    assert.match(result.mark, /gpu\.example\.com/);
    assert.equal(result.request, '问题 A');
  });

  await test('offline mode blocks backup enable, restore and cloud deletion without changing data', async () => {
    await open('?view=empty&offline=1&still=1&backend=local');
    const result = await evaluate(`state.backup.on=true;state.backup.hasCloud=true;const count=tasks.length;
      actions['backup-restore']();actions['backup-delete']();state.backup.on=false;actions['backup-on']();
      ({added:tasks.length-count,enabled:state.backup.on,hasCloud:state.backup.hasCloud,status:state.backup.status})`);
    assert.deepEqual(result, { added: 0, enabled: false, hasCloud: true, status: 'idle' });
  });

  await test('cloud deletion stops backup instead of leaving automatic re-upload enabled', async () => {
    await open('?view=empty&still=1&backend=local');
    await evaluate(`state.backup.on=true;state.backup.hasCloud=true;runBackup();actions['backup-delete']()`);
    const result = await evaluate(`({enabled:state.backup.on,hasCloud:state.backup.hasCloud,status:state.backup.status})`);
    assert.deepEqual(result, { enabled: false, hasCloud: false, status: 'idle' });
  });

  for (const interruption of ['offline', 'disable']) {
    await test(`an interrupted backup resumes after ${interruption} is reversed`, async () => {
      await open('?view=empty&still=1&backend=local');
      await evaluate(`state.backup.on=true;runBackup()`);
      await evaluate(interruption === 'offline' ? `state.prefs.offlineMode=true` : `actions['backup-toggle']()`);
      await until(`state.backup.pending`);
      assert.equal(await evaluate(`state.backup.pending`), true);
      await evaluate(interruption === 'offline' ? `actions['offline-off']()` : `actions['toast-undo']()`);
      await until(`state.backup.hasCloud`);
      assert.deepEqual(await evaluate(`({on:state.backup.on,cloud:state.backup.hasCloud,pending:state.backup.pending})`),
        { on: true, cloud: true, pending: false });
    });
  }

  await test('no uncaught page errors occurred during the flows', () => assert.deepEqual(pageErrors, []));
} finally {
  socket?.close();
  browser.kill('SIGTERM');
  await exited;
  await rm(profile, { recursive: true, force: true });
}
