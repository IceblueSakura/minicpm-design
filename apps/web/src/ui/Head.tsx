import { useEffect, useRef } from 'react';
import { current, currentModel, isBlank, isRemote } from '../core/selectors';
import { SCENES } from '../core/scenes';
import { Icon } from './Icon';
import { MOD, useApp, useStore } from './hooks';
import { useMenu } from './Menu';
import { SceneMenu, TitleSheet } from './menus';
import { useShell } from './Shell';

function RenameField({ id, title }: { id: string; title: string }) {
  const store = useStore(), { setRenaming } = useShell(), ref = useRef<HTMLInputElement>(null);
  useEffect(() => { ref.current?.select(); }, []);
  return (
    <input
      ref={ref} className="head-rename" defaultValue={title} aria-label="对话标题"
      onBlur={e => { store.rename(id, e.target.value); setRenaming(null); }}
      onKeyDown={e => { if (e.key === 'Enter') e.currentTarget.blur(); if (e.key === 'Escape') setRenaming(null); }}
    />
  );
}

export function Head({ scrolled }: { scrolled: boolean }) {
  const store = useStore(), s = useApp(), c = current(s), { open } = useMenu(), shell = useShell();
  const fresh = isBlank(c) && c.autoTitle, model = currentModel(s), where = isRemote(s) ? '远程' : '本机';
  const temp = (
    <button className="icon-btn" aria-pressed={c.temp} aria-label="临时对话" title="临时对话：不保存记录，也不写入记忆" onClick={() => store.toggleTemp()}><Icon name="temp" /></button>
  );
  const renaming = shell.renaming === c.id;

  if (shell.compact) {
    const name = c.temp && fresh ? '临时对话' : model?.name ?? 'MiniCPM';
    const sub = s.loading ? (s.swapFrom ? '正在换模型' : '正在准备') : c.temp ? '不保存记录' : fresh ? `${where}处理` : `${model?.short ?? ''} · ${where}`;
    return (
      <header className={`head${scrolled ? ' scrolled' : ''}`}>
        <button className="icon-btn" aria-label="打开对话列表" onClick={shell.toggleNav}><Icon name="menu" /></button>
        {renaming ? <RenameField id={c.id} title={c.title} /> : (
          <button
            className="head-title" aria-haspopup="dialog" aria-expanded="false"
            onClick={e => open({ key: 'title', anchor: e.currentTarget, label: '当前对话', role: 'dialog', render: () => <TitleSheet /> })}
          >
            <span className="ht-main"><b>{fresh ? name : c.title}</b><Icon name="down" /></span>
            <small>{sub}</small>
          </button>
        )}
        {fresh ? temp : <button className="icon-btn" aria-label="新对话" onClick={() => { store.newConversation(); shell.promptRef.current?.focus(); }}><Icon name="compose" /></button>}
      </header>
    );
  }
  return (
    <header className={`head${scrolled ? ' scrolled' : ''}`}>
      <button className="icon-btn only-collapsed" aria-label="展开侧栏" onClick={shell.toggleNav}><Icon name="panel-l" /></button>
      {renaming ? <RenameField id={c.id} title={c.title} /> : <button className="head-title" title="重命名" onClick={() => shell.setRenaming(c.id)}>{c.title}</button>}
      <button
        className="scene-chip" aria-haspopup="menu" aria-expanded="false" title="切换应用场景"
        onClick={e => open({ key: 'scene', anchor: e.currentTarget, label: '应用场景', role: 'menu', render: () => <SceneMenu /> })}
      >{SCENES[c.scene].name}<Icon name="down" /></button>
      {c.temp && !isBlank(c) && <span className="temp-tag"><Icon name="temp" />临时对话，不保存记录</span>}
      <span className="head-gap" />
      {fresh && temp}
      <button className="icon-btn" aria-pressed={shell.inspector} aria-label="对话详情" title={`对话详情 (${MOD}I)`} onClick={shell.toggleInspector}><Icon name="panel-r" /></button>
    </header>
  );
}
