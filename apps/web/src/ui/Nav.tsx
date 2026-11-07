import { useEffect, useRef, useState } from 'react';
import { ago, currentModel, dayGroup, engineStatus, isBlank } from '../core/selectors';
import { SCENES } from '../core/scenes';
import type { Conversation } from '../core/types';
import { Icon } from './Icon';
import { MOD, useApp, useStore } from './hooks';
import { useLongPress } from './longPress';
import { useMenu } from './Menu';
import { ConversationMenu, ResourcesMenu } from './menus';
import { useShell } from './Shell';

function Row({ c }: { c: Conversation }) {
  const store = useStore(), { open } = useMenu(), { closeNav, compact } = useShell();
  const active = useApp(s => s.current) === c.id, busy = useApp(s => s.reply?.conversationId) === c.id;
  const menu = (anchor: HTMLElement | null) => open({ key: `task-${c.id}`, anchor, label: '对话操作', role: 'menu', render: () => <ConversationMenu id={c.id} /> });
  const press = useLongPress(compact, () => menu(null));
  return (
    <div className={`task${active ? ' current' : ''}`}>
      <button className="task-main" aria-current={active ? 'page' : undefined} onClick={() => { store.select(c.id); closeNav(); }} {...press}>
        <span className="task-title">
          <b>{c.title}</b>
          {busy ? <span className="task-flag busy" title="正在生成" /> : c.unread && <span className="task-flag unread" title="有新回复" />}
        </span>
        <span className="task-meta">{SCENES[c.scene].name} · {ago(c.updatedAt)}</span>
      </button>
      <button className="icon-btn task-more" aria-label={`${c.title} 的更多操作`} aria-haspopup="menu" onClick={e => menu(e.currentTarget)}><Icon name="more" /></button>
    </div>
  );
}

function Resizer() {
  const ref = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(() => Number(localStorage.getItem('minicpm.navWidth')) || 264);
  const drag = useRef<{ x: number; w: number } | null>(null);
  const max = () => Math.max(208, Math.min(420, (document.querySelector('.app')?.clientWidth ?? 1200) - 520));
  const set = (v: number) => setWidth(Math.round(Math.max(208, Math.min(max(), v))));
  useEffect(() => {
    document.documentElement.style.setProperty('--nav-w', `${width}px`);
    localStorage.setItem('minicpm.navWidth', String(width));
  }, [width]);
  return (
    <div
      ref={ref} className="nav-resizer" role="separator" aria-orientation="vertical" aria-label="调整侧栏宽度"
      aria-valuemin={208} aria-valuemax={420} aria-valuenow={width} tabIndex={0}
      onPointerDown={e => { e.preventDefault(); drag.current = { x: e.clientX, w: width }; e.currentTarget.setPointerCapture(e.pointerId); e.currentTarget.classList.add('drag'); }}
      onPointerMove={e => { if (drag.current) set(drag.current.w + e.clientX - drag.current.x); }}
      onPointerUp={e => { drag.current = null; e.currentTarget.classList.remove('drag'); }}
      onDoubleClick={() => set(264)}
      onKeyDown={e => {
        const d = e.shiftKey ? 48 : 12, next = { ArrowLeft: width - d, ArrowRight: width + d, Home: 208, End: max() }[e.key];
        if (next !== undefined) { e.preventDefault(); set(next); }
      }}
    />
  );
}

export function Nav({ searchRef }: { searchRef: React.RefObject<HTMLInputElement | null> }) {
  const store = useStore(), s = useApp(), { open } = useMenu(), shell = useShell();
  const [query, setQuery] = useState('');
  const q = query.trim().toLowerCase();
  const list = s.conversations
    .filter(c => !c.temp && (!isBlank(c) || c.id === s.current) && `${c.title} ${SCENES[c.scene].name}`.toLowerCase().includes(q))
    .toSorted((a, b) => b.updatedAt - a.updatedAt);
  const [dot, status] = engineStatus(s);
  const name = currentModel(s)?.name ?? '还没有模型';
  let group = '';
  return (
    <aside className="nav" aria-label="对话" role={shell.compact && shell.navOpen ? 'dialog' : undefined} aria-modal={shell.compact && shell.navOpen ? true : undefined}>
      <div className="nav-top">
        <button className="icon-btn nav-back" aria-label="回到对话" onClick={shell.toggleNav}><Icon name="chev" className="i back" /></button>
        <div className="brand">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path className="a" d="M4 10.500V9M8 10.500V6M12 10.500V3.500M16 10.500V7.500M20 10.500V9.500" /><path className="b" d="M4 13.500V15M8 13.500V16.500M12 13.500V16M16 13.500V20.500M20 13.500V17" /></svg>
          MiniCPM
        </div>
        <button className="icon-btn only-wide" aria-label="收起侧栏" title="收起侧栏" onClick={shell.toggleNav}><Icon name="panel-l" /></button>
      </div>
      <button className="nav-new" onClick={() => { store.newConversation(); shell.closeNav(); shell.promptRef.current?.focus(); }}>
        <Icon name="plus" /><span>新对话</span><kbd>{MOD}N</kbd>
      </button>
      <label className="nav-search">
        <Icon name="search" /><span className="sr">搜索对话</span>
        <input ref={searchRef} type="search" placeholder="搜索对话" autoComplete="off" value={query} onChange={e => setQuery(e.target.value)} />
        <kbd>{MOD}K</kbd>
      </label>
      <nav className="nav-list" aria-label="对话列表">
        {list.map(c => {
          const g = dayGroup(c.updatedAt), head = g !== group;
          group = g;
          return <div key={c.id}>{head && <div className="nav-group">{g}</div>}<Row c={c} /></div>;
        })}
        {!list.length && <div className="nav-empty">没有找到“{query}”。试试场景名，比如生活助手。</div>}
      </nav>
      <div className="nav-foot">
        <button
          className="engine" aria-haspopup="dialog" aria-expanded="false" aria-label={`${name}，${status}。查看详情`}
          onClick={e => open({ key: 'resources', anchor: e.currentTarget, label: '运行状态', role: 'dialog', render: () => <ResourcesMenu /> })}
        >
          <span className="eng-id"><span className={`dot ${dot}`} /><span style={{ minWidth: 0 }}><b>{name}</b><small>{status}</small></span></span>
        </button>
        <button className="icon-btn" aria-label="设置" title="设置" onClick={() => shell.openSettings(shell.compact ? 'index' : 'general')}><Icon name="gear" /></button>
      </div>
      <Resizer />
    </aside>
  );
}
