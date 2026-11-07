// State and rules, free of any UI framework. The iOS AppModel mirrors this file rule for rule.
import { EngineError } from '../engine/types';
import type { DownloadHandle, Engine, GenerateRequest, GenerationEvent, RequestMessage } from '../engine/types';
import type { Backends } from '../engine';
import { loadMark, localPersistence, snapshot } from './persist';
import type { Persistence } from './persist';
import { backendReady, cannotSend, attOk, canRemember, current, isBlank, isRemote, option, remoteHost } from './selectors';
import { DEFAULT_PREFS, PRESETS } from './types';
import type { AiItem, AppState, Attachment, Conversation, PresetId, Prefs, SceneId, ThreadItem, UserItem } from './types';

const uid = (prefix: string) => `${prefix}-${crypto.randomUUID().slice(0, 8)}`;
const NOT_YET = '这项还没接入';

const blank = (prefs: Prefs): Conversation => ({
  id: uid('c'), title: '新对话', autoTitle: true, temp: prefs.tempDefault, scene: prefs.defaultScene,
  updatedAt: Date.now(), items: [], place: 'local', sources: [],
});

const initial = (): AppState => {
  const first = blank(DEFAULT_PREFS);
  return {
    ready: false, onboard: null, obPick: null,
    conversations: [first], current: first.id, drafts: {}, atts: [], thinking: false,
    device: { canRunLocal: true, memoryGB: null, freeStorageGB: null, accelerator: null },
    catalog: [], installed: [], model: null, loaded: null, loading: null, swapFrom: null, swapFail: null, loadCrashed: false, dl: null,
    backend: 'local', remote: { url: '', hasToken: false }, engine: 'ready', reply: null, queued: false,
    theme: 'system', sendKey: 'enter', persona: '你是一个耐心、直接的助手。回答简短，先说结论。',
    preset: 'balanced', params: { ...PRESETS.balanced.params }, prefs: { ...DEFAULT_PREFS },
    sceneOff: [], memories: [], netLog: [], toast: null, announce: '',
  };
};

export class AppStore {
  private state = initial();
  private readonly listeners = new Set<() => void>();
  private readonly backends: Backends;
  private readonly persistence: Persistence;

  private loadThen: (() => void)[] = [];
  private readonly preparing = new Map<string, Promise<void>>();
  private loadAbort: AbortController | null = null;
  private replyAbort: AbortController | null = null;
  private download: DownloadHandle | null = null;
  private saveTimer: ReturnType<typeof setTimeout> | undefined;
  private toastTimer: ReturnType<typeof setTimeout> | undefined;
  private idleTimer: ReturnType<typeof setTimeout> | undefined;
  private toastSerial = 0;

  constructor(backends: Backends, persistence: Persistence = localPersistence) {
    this.backends = backends;
    this.persistence = persistence;
  }

  getState = () => this.state;
  subscribe = (fn: () => void) => { this.listeners.add(fn); return () => { this.listeners.delete(fn); }; };

  private set(patch: Partial<AppState>) {
    this.state = { ...this.state, ...patch };
    this.listeners.forEach(fn => fn());
    if (this.state.ready) {
      clearTimeout(this.saveTimer);
      this.saveTimer = setTimeout(() => this.persistence.save(snapshot(this.state)), 300);
    }
  }

  private patchConversation(id: string, fn: (c: Conversation) => Conversation) {
    this.set({ conversations: this.state.conversations.map(c => (c.id === id ? fn(c) : c)) });
  }
  private patchItem(conversationId: string, itemId: string, fn: (item: ThreadItem) => ThreadItem) {
    this.patchConversation(conversationId, c => ({ ...c, items: c.items.map(i => (i.id === itemId ? fn(i) : i)) }));
  }
  private push(conversationId: string, item: ThreadItem) {
    this.patchConversation(conversationId, c => ({ ...c, items: [...c.items, item], updatedAt: Date.now() }));
  }
  private get engine(): Engine { return this.backends.engines[this.state.backend]; }

  /* ---------- Boot ---------- */
  async boot() {
    const saved = this.persistence.load();
    const crashed = loadMark.get();
    loadMark.clear();
    const device = await this.backends.engines.local.probe();
    const [catalog, installed] = await Promise.all([this.backends.models.catalog(device), this.backends.models.installed()]);

    const prefs = { ...DEFAULT_PREFS, ...saved?.prefs };
    const days = Number(prefs.retention);
    const kept = (saved?.conversations ?? []).filter(c => !days || Date.now() - c.updatedAt < days * 864e5);
    const last = prefs.openTo === 'last' ? kept.find(c => c.id === saved?.current) : undefined;
    const start = last ?? blank(prefs);

    const model = saved?.model && catalog.some(o => o.id === saved.model) ? saved.model : installed[0] ?? catalog.find(o => o.recommended)?.id ?? null;
    this.set({
      ...(saved?.theme && { theme: saved.theme }), ...(saved?.sendKey && { sendKey: saved.sendKey }),
      ...(saved?.persona !== undefined && { persona: saved.persona }), ...(saved?.preset && { preset: saved.preset }), ...(saved?.params && { params: saved.params }),
      ...(saved?.sceneOff && { sceneOff: saved.sceneOff }), ...(saved?.memories && { memories: saved.memories }), ...(saved?.netLog && { netLog: saved.netLog }),
      ...(saved?.drafts && { drafts: saved.drafts }),
      prefs, device, catalog, installed, model, loadCrashed: crashed,
      conversations: last ? kept : [start, ...kept], current: start.id,
      backend: saved?.backend ?? 'local', remote: { url: saved?.remoteUrl ?? '', hasToken: false },
      onboard: saved?.onboarded ? null : 'welcome',
      ready: true,
    });
    if (!crashed && !this.state.onboard) this.prepare();
  }

  /* ---------- Model lifecycle ---------- */
  /** Opening starts the load right away, so the wait passes while you type. */
  prepare(then?: () => void) {
    const { model, loaded, loading, installed } = this.state;
    if (isRemote(this.state) || !model || !installed.includes(model) || !this.state.device.canRunLocal) { then?.(); return; }
    if (loaded === model) { then?.(); return; }
    if (then) this.loadThen.push(then);
    if (loading === model) return;
    void this.runLoad(model, loaded);
  }

  private async runLoad(id: string, from: string | null) {
    this.loadAbort?.abort();
    const abort = this.loadAbort = new AbortController();
    loadMark.set();
    this.set({ loading: id, loadCrashed: false });
    try {
      if (from) await this.engine.unload();
      if (from) this.set({ loaded: null });
      await this.engine.load(id, abort.signal);
      loadMark.clear();
      if (abort.signal.aborted) return;
      this.set({ loaded: id, loading: null, swapFrom: null });
      const waiting = this.loadThen;
      this.loadThen = [];
      waiting.forEach(fn => fn());
    } catch (error) {
      loadMark.clear();
      if (abort.signal.aborted) return;
      const cold = !from;
      this.set({ loading: null, swapFrom: null, swapFail: { id, cold }, model: from ?? id, engine: error instanceof EngineError && error.code === 'unavailable' ? 'offline' : this.state.engine });
      // A failed switch goes back to the old model. With nothing to fall back on, what was waiting keeps waiting for a retry.
      if (from) this.prepare();
    }
  }

  retryLoad() {
    const fail = this.state.swapFail;
    this.set({ swapFail: null, loadCrashed: false });
    if (fail && !fail.cold) this.setModel(fail.id); else this.prepare();
  }
  dismissSwapFail() { this.set({ swapFail: null }); }

  cancelLoad() {
    const { loading, swapFrom } = this.state;
    if (!loading || !swapFrom) return;
    this.loadAbort?.abort();
    // The old model was released first, so going back takes a wait too. Anything queued rides along with it.
    this.set({ loading: null, swapFrom: null, model: swapFrom });
    this.prepare();
    this.showToast(`已取消，继续用 ${option(this.state, swapFrom)?.name ?? '原来的模型'}`);
  }

  /** Confirmed by the caller: a mistap in the picker must do nothing. */
  setModel(id: string, then?: () => void) {
    const s = this.state;
    if (s.model === id) { then?.(); return; }
    if (s.reply) { this.showToast('这条回答还没结束', '停止并换', () => { this.stopReply(); this.setModel(id, then); }); return; }
    this.set({ swapFail: null, model: id, swapFrom: s.model });
    if (isRemote(s)) { this.set({ swapFrom: null }); then?.(); return; }
    this.prepare(then);
  }

  /* ---------- Download ---------- */
  startDownload(optionId: string) {
    if (this.state.prefs.offlineMode) { this.showToast('离线模式开着，下载不了模型', '关闭离线模式', () => { this.setPref('offlineMode', false); this.startDownload(optionId); }); return; }
    this.download?.cancel();
    this.set({ dl: { optionId, pct: 0, status: 'running' } });
    this.download = this.backends.models.download(optionId, event => {
      if (event.status === 'done') { void this.finishDownload(optionId); return; }
      this.set({ dl: { optionId, pct: event.pct, status: event.status } });
    });
  }
  private async finishDownload(optionId: string) {
    const o = option(this.state, optionId);
    const wasCurrent = this.state.model && option(this.state, this.state.model)?.family === o?.family;
    const installed = await this.backends.models.installed();
    this.download = null;
    this.set({ installed, dl: null, onboard: null, model: wasCurrent || !this.state.model ? optionId : this.state.model });
    if (wasCurrent && this.state.loaded && this.state.loaded !== optionId) this.set({ loaded: null });
    this.showToast(`${o?.name ?? '模型'} 准备好了`);
    this.prepare();
  }
  pauseDownload() { this.download?.pause(); }
  resumeDownload() { this.download?.resume(); }
  cancelDownload() { this.download?.cancel(); this.download = null; this.set({ dl: null }); }
  async removeModel(optionId: string) {
    await this.backends.models.remove(optionId);
    this.set({ installed: await this.backends.models.installed() });
  }

  /* ---------- First run ---------- */
  obNext() { this.set({ onboard: 'model' }); }
  obPick(id: string) { this.set({ obPick: id }); }
  obDownload() {
    const id = this.state.obPick ?? this.state.catalog.find(o => o.recommended)?.id;
    if (!id) return;
    this.set({ model: id, onboard: 'download' });
    this.startDownload(id);
  }
  obLeave() { this.set({ onboard: null }); }
  obRemote() { this.set({ onboard: null, backend: 'remote' }); }

  /* ---------- Conversations ---------- */
  private leaveTemp(next: string) {
    const c = current(this.state);
    if (!c?.temp || c.id === next || isBlank(c)) return;
    this.set({ conversations: this.state.conversations.filter(x => x.id !== c.id) });
    this.showToast('临时对话已清除');
  }

  select(id: string) {
    this.leaveTemp(id);
    this.set({ current: id, atts: [] });
    this.patchConversation(id, c => ({ ...c, unread: false }));
  }

  newConversation() {
    const existing = this.state.conversations.find(c => isBlank(c) && c.autoTitle);
    if (existing) { this.select(existing.id); return; }
    const c = blank(this.state.prefs);
    this.set({ conversations: [c, ...this.state.conversations] });
    this.select(c.id);
  }

  deleteConversation(id: string) {
    const list = this.state.conversations, index = list.findIndex(c => c.id === id), gone = list[index];
    if (this.state.reply?.conversationId === id) this.stopReply();
    const rest = list.filter(c => c.id !== id);
    this.set({ conversations: rest });
    if (!rest.length) { const c = blank(this.state.prefs); this.set({ conversations: [c], current: c.id }); }
    else if (this.state.current === id) this.set({ current: rest[Math.min(index, rest.length - 1)].id });
    this.showToast(`已删除“${gone.title}”`, '撤销', () => {
      const now = [...this.state.conversations];
      now.splice(Math.min(index, now.length), 0, gone);
      this.set({ conversations: now });
    });
  }

  rename(id: string, title: string) {
    const text = title.trim();
    if (text) this.patchConversation(id, c => ({ ...c, title: text, autoTitle: false }));
  }
  setScene(scene: SceneId) { this.patchConversation(this.state.current, c => ({ ...c, scene })); }
  toggleTemp() { this.patchConversation(this.state.current, c => ({ ...c, temp: !c.temp })); }

  /* ---------- Composer ---------- */
  setDraft(text: string) { this.set({ drafts: { ...this.state.drafts, [this.state.current]: text } }); }
  toggleThinking() { this.set({ thinking: !this.state.thinking }); }

  addFiles(files: File[]) {
    for (const file of files) {
      const kind = file.type.startsWith('image/') ? 'image' : file.type.startsWith('audio/') ? 'audio' : file.type.startsWith('video/') ? 'video' : 'file';
      if (!attOk(this.state, { kind })) { this.showToast(`当前模型读不了${kind === 'audio' ? '音频' : '视频'}`); continue; }
      const att: Attachment = { id: uid('a'), kind, name: file.name, sub: `${Math.max(1, Math.round(file.size / 1024))} KB`, url: kind === 'image' ? URL.createObjectURL(file) : undefined, busy: kind === 'image' };
      this.set({ atts: [...this.state.atts, att] });
      // An image is processed as soon as it is added, so the wait passes while you type.
      if (kind === 'image') this.preparing.set(att.id, this.engine.prepareImage(file).then(prepared => this.patchAttachment(att.id, { busy: false, prepared }), () => this.patchAttachment(att.id, { busy: false })));
    }
  }
  private patchAttachment(id: string, patch: Partial<Attachment>) {
    const apply = (a: Attachment) => (a.id === id ? { ...a, ...patch } : a);
    this.set({
      atts: this.state.atts.map(apply),
      conversations: this.state.conversations.map(c => ({ ...c, items: c.items.map(i => (i.type === 'user' && i.atts.some(a => a.id === id) ? { ...i, atts: i.atts.map(apply) } : i)) })),
    });
  }
  removeAttachment(id: string) { this.set({ atts: this.state.atts.filter(a => a.id !== id) }); }

  /** Marks the first message after the place changed, so a mixed conversation stays honest. */
  private markPlace(c: Conversation) {
    const place = isRemote(this.state) ? remoteHost(this.state) : 'local';
    if (c.items.length && c.place !== place) this.push(c.id, { type: 'place', id: uid('i'), text: isRemote(this.state) ? `从这里开始发送到 ${place} 处理，上文也包括在内` : '从这里开始只在这台设备上处理' });
    this.patchConversation(c.id, x => ({ ...x, place }));
  }

  send() {
    const s = this.state, c = current(s);
    if (s.reply?.conversationId === c.id) { this.stopReply(); return; }
    if (s.reply || s.queued || cannotSend(s)) return;
    const text = (s.drafts[c.id] ?? '').trim();
    if (!text && !s.atts.length) return;
    const failed = !backendReady(s);
    if (isBlank(c) && c.autoTitle) this.patchConversation(c.id, x => ({ ...x, title: (text || s.atts[0].name).slice(0, 24), autoTitle: false }));
    if (!failed) this.markPlace(c);
    const item: UserItem = { type: 'user', id: uid('i'), text, atts: s.atts, failed };
    this.push(c.id, item);
    this.patchConversation(c.id, x => ({ ...x, sources: [...x.sources, ...s.atts.map(a => a.name)] }));
    const { [c.id]: _sent, ...drafts } = this.state.drafts;
    this.set({ atts: [], drafts });
    // Sending early is allowed: the reply just waits for the images and the model.
    const images = Promise.all(s.atts.map(a => this.preparing.get(a.id)));
    if (!failed) this.queueReply(c.id, undefined, images);
  }

  /** One reply at a time, and one in the queue: a second send during the wait stays in the box. */
  private queueReply(conversationId: string, continuing?: string, waitFor: Promise<unknown> = Promise.resolve()) {
    this.set({ queued: true });
    this.prepare(() => void waitFor.then(() => {
      this.set({ queued: false });
      void this.startReply(conversationId, continuing);
    }));
  }

  retrySend(itemId: string) {
    const c = current(this.state);
    if (!backendReady(this.state) || this.state.reply || this.state.queued) return;
    this.patchItem(c.id, itemId, i => ({ ...i, failed: false }));
    this.queueReply(c.id);
  }

  regenerate(itemId: string) {
    if (this.state.reply || this.state.queued) return;
    const c = current(this.state), at = c.items.findIndex(i => i.id === itemId);
    this.patchConversation(c.id, x => ({ ...x, items: x.items.slice(0, at) }));
    this.queueReply(c.id);
  }

  continueReply(itemId: string) {
    if (this.state.reply || this.state.queued) return;
    const c = current(this.state);
    this.patchItem(c.id, itemId, i => ({ ...i, cut: undefined }) as AiItem);
    this.queueReply(c.id, itemId);
  }

  private buildRequest(c: Conversation): GenerateRequest {
    const s = this.state, p = s.prefs;
    const messages = c.items.flatMap((i): RequestMessage[] => (
      i.type === 'user' ? [{ role: 'user', text: i.text, images: i.atts.flatMap(a => a.prepared ?? []) }]
      : i.type === 'ai' && i.text ? [{ role: 'assistant', text: i.text, images: [] }] : []));
    const remember = canRemember(s, c);
    const lines = [s.persona, p.callName && `称呼用户为“${p.callName}”。`, { short: '回答尽量简短。', normal: '', long: '回答尽量详细。' }[p.replyLength],
      remember && s.memories.length ? `已知用户的偏好：\n${s.memories.join('\n')}` : ''];
    return { modelId: s.model ?? '', system: lines.filter(Boolean).join('\n\n'), messages, params: s.params, thinking: s.thinking, highDetail: p.hd, canRemember: remember };
  }

  private async startReply(conversationId: string, continuing?: string) {
    const c = this.state.conversations.find(x => x.id === conversationId);
    if (!c || this.state.reply) return;
    clearTimeout(this.idleTimer);
    const itemId = continuing ?? uid('i');
    if (!continuing) this.push(conversationId, { type: 'ai', id: itemId, text: '', model: this.state.model ?? '' });
    const abort = this.replyAbort = new AbortController();
    this.set({ reply: { conversationId, itemId } });
    const request = this.buildRequest({ ...c, items: c.items.filter(i => i.id !== itemId) });
    const after: ThreadItem[] = [];
    try {
      for await (const event of this.engine.generate(request, abort.signal)) this.onEvent(conversationId, itemId, event, after);
      if (abort.signal.aborted) this.patchItem(conversationId, itemId, i => ({ ...i, text: (i as AiItem).text ? `${(i as AiItem).text} …` : '已停止。' }));
    } catch (error) {
      this.failReply(conversationId, itemId, error);
    }
    this.replyAbort = null;
    this.set({ reply: null });
    after.forEach(item => this.push(conversationId, item));
    if (this.state.current !== conversationId) this.patchConversation(conversationId, x => ({ ...x, unread: true }));
    this.scheduleIdleRelease();
  }

  private onEvent(conversationId: string, itemId: string, event: GenerationEvent, after: ThreadItem[]) {
    const patchAi = (fn: (i: AiItem) => AiItem) => this.patchItem(conversationId, itemId, i => fn(i as AiItem));
    switch (event.type) {
      case 'text': patchAi(i => ({ ...i, text: i.text + event.delta })); break;
      case 'cut': patchAi(i => ({ ...i, cut: event.reason })); break;
      case 'done': patchAi(i => ({ ...i, stat: `${option(this.state, this.state.model)?.short ?? ''} · ${event.tokensPerSecond.toFixed(0)} tok/s · ${event.seconds.toFixed(1)} s` })); break;
      case 'memory':
        if (canRemember(this.state, this.state.conversations.find(c => c.id === conversationId)!)) {
          this.keepMemory(event.text);
          after.push({ type: 'memory', id: uid('i'), text: event.text });
        }
        break;
      case 'askSearch': if (this.state.prefs.webSearch !== 'off') after.push({ type: 'ask', id: uid('i'), query: event.query, state: 'open' }); break;
      case 'action': after.push({ type: 'action', id: uid('i'), kind: event.kind, when: event.when, text: event.text, state: 'open' }); break;
    }
  }

  /** Never switches place on failure: falling over to remote would send content off the device. */
  private failReply(conversationId: string, itemId: string, error: unknown) {
    const c = this.state.conversations.find(x => x.id === conversationId);
    const item = c?.items.find(i => i.id === itemId) as AiItem | undefined;
    if (error instanceof EngineError && error.code === 'unavailable') this.set({ engine: 'offline' });
    if (item?.text) { this.patchItem(conversationId, itemId, i => ({ ...i, cut: 'crash' })); return; }
    this.patchConversation(conversationId, x => {
      const items = x.items.filter(i => i.id !== itemId);
      const last = items.findLastIndex(i => i.type === 'user');
      return { ...x, items: items.map((i, n) => (n === last ? { ...i, failed: true } : i)) };
    });
  }

  stopReply() { this.replyAbort?.abort(); }

  private scheduleIdleRelease() {
    const minutes = Number(this.state.prefs.idleRelease);
    clearTimeout(this.idleTimer);
    if (!minutes || isRemote(this.state)) return;
    this.idleTimer = setTimeout(() => {
      if (this.state.reply || !this.state.loaded) return;
      void this.engine.unload();
      this.set({ loaded: null });
    }, minutes * 6e4);
  }

  /* ---------- Things the model asks for ---------- */
  private keepMemory(text: string) {
    if (!this.state.memories.includes(text)) this.set({ memories: [...this.state.memories, text] });
    this.set({ announce: `已记住：${text}` });
  }
  undoMemory(text: string) { this.set({ memories: this.state.memories.filter(m => m !== text) }); }
  redoMemory(text: string) { this.keepMemory(text); }
  forget(index: number) {
    const memories = [...this.state.memories], [gone] = memories.splice(index, 1);
    this.set({ memories });
    this.showToast(`已删除“${gone}”`, '撤销', () => {
      const now = [...this.state.memories];
      now.splice(index, 0, gone);
      this.set({ memories: now });
    });
  }

  denySearch(itemId: string) { this.patchItem(this.state.current, itemId, i => ({ ...i, state: 'denied' }) as ThreadItem); }
  /** Web search has no backend yet. Nothing is sent, so the record must not say it was. */
  allowSearch(itemId: string) {
    this.denySearch(itemId);
    this.showToast('联网搜索还没接入，什么都没有发送');
  }
  answerAction(itemId: string, yes: boolean) {
    const c = current(this.state), item = c.items.find(i => i.id === itemId);
    if (item?.type !== 'action') return;
    if (!yes) { this.patchItem(c.id, itemId, i => ({ ...i, state: 'declined' }) as ThreadItem); return; }
    if (item.kind === 'notify') { this.showToast(NOT_YET); return; }
    void navigator.clipboard?.writeText(item.text);
    this.patchItem(c.id, itemId, i => ({ ...i, state: 'added' }) as ThreadItem);
    this.showToast('已复制');
  }

  /* ---------- Place ---------- */
  /** Place only changes by hand. Nothing has left the device yet, so it is undoable instead of confirmed first. */
  setBackend(place: 'local' | 'remote') {
    const before = this.state.backend;
    if (before === place) return;
    this.apply(place);
    if (!backendReady(this.state)) return;
    const undo = () => this.apply(before);
    if (place === 'local') { this.showToast('已切换到这台设备，下一条消息生效', '撤销', undo); return; }
    this.showToast(isBlank(current(this.state)) ? `内容会发送到 ${remoteHost(this.state)} 处理` : `这个对话的上文也会发送到 ${remoteHost(this.state)}`, '撤销', undo);
  }
  private apply(place: 'local' | 'remote') {
    this.set({ backend: place, engine: 'ready' });
    if (place === 'local') this.prepare();
  }
  setRemoteUrl(url: string) { this.set({ remote: { ...this.state.remote, url: url.trim() } }); }
  /** Held in memory only for now; a real token goes through a secret store, not the saved state. */
  setRemoteToken(token: string) { this.set({ remote: { ...this.state.remote, hasToken: !!token } }); }
  reconnect() {
    this.showToast('正在重新连接…');
    this.set({ engine: 'ready' });
    this.prepare();
  }

  /* ---------- Preferences ---------- */
  setTheme(theme: AppState['theme']) { this.set({ theme }); }
  setSendKey(sendKey: AppState['sendKey']) { this.set({ sendKey }); }
  setPersona(persona: string) { this.set({ persona }); }
  setPref<K extends keyof Prefs>(key: K, value: Prefs[K]) { this.set({ prefs: { ...this.state.prefs, [key]: value } }); }
  setPreset(id: Exclude<PresetId, 'custom'>) { this.set({ preset: id, params: { ...PRESETS[id].params } }); }
  setParam(key: keyof AppState['params'], value: number) { this.set({ preset: 'custom', params: { ...this.state.params, [key]: value } }); }
  resetParams() { this.setPreset('balanced'); this.showToast('已恢复默认'); }
  toggleScene(id: SceneId) {
    const off = this.state.sceneOff;
    this.set({ sceneOff: off.includes(id) ? off.filter(x => x !== id) : [...off, id] });
  }
  clearAll() {
    const before = this.state.conversations;
    const fresh = blank(this.state.prefs);
    this.set({ conversations: [fresh], current: fresh.id, drafts: {} });
    this.showToast('已清除全部对话', '撤销', () => this.set({ conversations: before, current: before[0].id }));
  }

  /* ---------- Feedback ---------- */
  showToast(text: string, actionLabel?: string, action?: () => void) {
    clearTimeout(this.toastTimer);
    const id = ++this.toastSerial;
    this.set({ toast: { id, text, actionLabel, action }, announce: text });
    this.toastTimer = setTimeout(() => { if (this.state.toast?.id === id) this.set({ toast: null }); }, actionLabel ? 7000 : 3200);
  }
  runToast() {
    const action = this.state.toast?.action;
    this.set({ toast: null });
    action?.();
  }
  notYet() { this.showToast(NOT_YET); }
}

