import { useLayoutEffect } from 'react';
import { attOk, cannotSend, current, currentModel, isBlank, activeScenes } from '../core/selectors';
import { EXTRA_STARTERS, SCENES } from '../core/scenes';
import { Icon } from './Icon';
import { MOD, useApp, useStore } from './hooks';
import { useMenu } from './Menu';
import { AttachSheet, ModelMenu } from './menus';
import { useShell } from './Shell';
import { AttachmentChip } from './Thread';

export function Composer() {
  const store = useStore(), s = useApp(), c = current(s), { open } = useMenu(), shell = useShell();
  const { compact, promptRef } = shell;
  const draft = s.drafts[c.id] ?? '';
  const has = !!draft.trim() || s.atts.length > 0;
  const busy = s.reply?.conversationId === c.id;
  const unreadable = s.atts.some(a => !attOk(s, a));
  // Empty, the main button is the fastest way to show it something: on a phone with no live mode, the camera.
  const shot = compact && !has && !busy;
  const m = currentModel(s);

  useLayoutEffect(() => {
    const p = promptRef.current;
    if (!p) return;
    p.style.height = 'auto';
    p.style.height = `${Math.min(p.scrollHeight, 220)}px`;
  }, [draft, compact, promptRef]);

  return (
    <form
      className={`composer${has ? ' has-input' : ''}${c.temp ? ' temp' : ''}`} aria-label="输入"
      onSubmit={e => { e.preventDefault(); store.send(); }}
    >
      {compact && s.thinking && (
        <div className="modes"><button type="button" className="mode" aria-label="关闭深度思考" onClick={() => store.toggleThinking()}><Icon name="bulb" />深度思考<Icon name="close" /></button></div>
      )}
      {!!s.atts.length && (
        <div className="chips">
          {s.atts.map(a => (
            <AttachmentChip key={a.id} a={a} bad={!attOk(s, a)}>
              {!attOk(s, a) && <span className="sub">这个模型读不了</span>}
              {a.busy && <span className="sub">正在处理</span>}
              <button type="button" aria-label={`移除 ${a.name}`} onClick={() => store.removeAttachment(a.id)}><Icon name="close" /></button>
            </AttachmentChip>
          ))}
        </div>
      )}
      <div id="textBox">
        <label className="sr" htmlFor="prompt">消息</label>
        <textarea
          id="prompt" ref={promptRef} rows={1} value={draft}
          placeholder={compact ? '问问 MiniCPM' : '写点什么，或把图片、文件拖到这里'}
          onChange={e => store.setDraft(e.target.value)}
          onPaste={e => { const files = [...e.clipboardData.files]; if (files.length) { e.preventDefault(); store.addFiles(files); } }}
          onKeyDown={e => {
            // During IME composition Enter picks a candidate; it must never send.
            if (e.key !== 'Enter' || e.nativeEvent.isComposing || compact) return;
            const mod = e.metaKey || e.ctrlKey;
            if (s.sendKey === 'enter' ? !e.shiftKey : mod) { e.preventDefault(); store.send(); }
          }}
        />
      </div>
      <div className="c-row" id="cRow">
        <button
          type="button" className="icon-btn" data-action="attach" aria-label="添加附件" title="添加图片、视频或文件" aria-expanded="false"
          onClick={e => { if (compact) open({ key: 'attach', anchor: e.currentTarget, label: '添加内容', role: 'menu', render: () => <AttachSheet /> }); else shell.pickFile(); }}
        ><Icon name="plus" /></button>
        <button type="button" className="toggle" id="thinking" aria-pressed={s.thinking} title="先思考再回答，适合复杂问题" onClick={() => store.toggleThinking()}><Icon name="bulb" /><span>深度思考</span></button>
        <span className="c-gap" />
        {m && (
          <button
            type="button" className="model-btn" id="modelBtn" aria-haspopup="menu" aria-expanded="false" aria-label={`模型：${m.name}，点击切换`} disabled={!!s.loading} title="切换模型"
            onClick={e => open({ key: 'model', anchor: e.currentTarget, label: '模型', role: 'menu', render: () => <ModelMenu /> })}
          ><span className="full">{m.name}</span><span className="short">{m.short}</span><Icon name="down" /></button>
        )}
        {shot ? <button type="button" className="live-btn" id="shotBtn" aria-label="拍照提问" title="拍照提问" onClick={shell.takePhoto}><Icon name="camera" /><span>拍照</span></button> : (
          <button
            type="submit" className="send-btn" id="sendBtn" aria-label={busy ? '停止生成' : '发送'}
            title={busy ? '停止生成 (Esc)' : s.sendKey === 'enter' ? '发送 (Enter)' : `发送 (${MOD}Enter)`}
            disabled={!busy && (!has || unreadable || cannotSend(s) || !!s.reply || s.queued)}
          ><Icon name={busy ? 'stop' : 'up'} /></button>
        )}
      </div>
    </form>
  );
}

export function Starters() {
  const store = useStore(), s = useApp(), c = current(s), shell = useShell();
  if (!isBlank(c) || !activeScenes(s, c).length) return null;
  const list = [...SCENES[c.scene].starters, ...EXTRA_STARTERS].slice(0, 3);
  return (
    <div className="starters">
      {list.map(starter => (
        <button
          key={starter.title} className="starter"
          onClick={() => {
            if (starter.camera) { shell.takePhoto(); return; }
            store.setDraft(starter.prompt ?? '');
            shell.promptRef.current?.focus();
          }}
        ><Icon name={starter.icon} /><b>{starter.title}</b><small>{starter.sub}</small></button>
      ))}
    </div>
  );
}
