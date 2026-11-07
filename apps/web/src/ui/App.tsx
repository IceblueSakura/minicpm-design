import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { current, isBlank } from '../core/selectors';
import { Banner } from './Banner';
import { Composer, Starters } from './Composer';
import { Head } from './Head';
import { useApp, useCompact, useStore } from './hooks';
import { Inspector } from './Inspector';
import { MenuHost, MenuProvider, useMenu } from './Menu';
import { Nav } from './Nav';
import { Onboard } from './Onboard';
import { Settings } from './Settings';
import { ShellContext } from './Shell';
import type { SettingsTab, ShellApi } from './Shell';
import { Thread } from './Thread';
import sprite from './sprite.svg?raw';

function useTheme() {
  const theme = useApp(s => s.theme);
  useEffect(() => {
    const dark = matchMedia('(prefers-color-scheme: dark)');
    const apply = () => {
      const t = new URLSearchParams(location.search).get('theme') ?? (theme === 'system' ? (dark.matches ? 'dark' : 'light') : theme);
      document.documentElement.dataset.theme = t;
      document.querySelector<HTMLMetaElement>('#themeColor')!.content = t === 'dark' ? '#141A18' : '#FAFBF8';
    };
    apply();
    dark.addEventListener('change', apply);
    return () => dark.removeEventListener('change', apply);
  }, [theme]);
}

/** The back gesture closes the top layer in the compact form, the same way it does in the native clients. */
function useBackLayers(depth: number, closeTop: () => void) {
  const count = useRef(0), skip = useRef(0), close = useRef(closeTop);
  close.current = closeTop;
  useEffect(() => {
    for (let i = count.current; i < depth; i++) history.pushState(null, '');
    if (depth < count.current) { skip.current++; history.go(depth - count.current); }
    count.current = depth;
  }, [depth]);
  useEffect(() => {
    const onPop = () => {
      if (skip.current) { skip.current--; return; }
      count.current = Math.max(0, count.current - 1);
      close.current();
    };
    addEventListener('popstate', onPop);
    return () => removeEventListener('popstate', onPop);
  }, []);
}

function Workspace() {
  const store = useStore(), s = useApp(), compact = useCompact(), menu = useMenu();
  const [navOpen, setNavOpen] = useState(false);
  const [navCollapsed, setNavCollapsed] = useState(false);
  const [inspector, setInspector] = useState(() => innerWidth >= 1560);
  const [settings, setSettings] = useState<SettingsTab | null>(null);
  const [renaming, setRenaming] = useState<string | null>(null);
  const [scrolled, setScrolled] = useState(false);
  const [dropping, setDropping] = useState(false);

  const promptRef = useRef<HTMLTextAreaElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const cameraRef = useRef<HTMLInputElement>(null);

  const toggleNav = useCallback(() => { if (compact) setNavOpen(o => !o); else setNavCollapsed(o => !o); }, [compact]);
  const shell = useMemo<ShellApi>(() => ({
    compact, navOpen, toggleNav, closeNav: () => setNavOpen(false),
    inspector, toggleInspector: () => setInspector(o => !o),
    settings, openSettings: (tab = 'general') => { setNavOpen(false); setSettings(tab); }, closeSettings: () => setSettings(null),
    renaming, setRenaming, promptRef,
    pickFile: () => fileRef.current?.click(), takePhoto: () => cameraRef.current?.click(),
  }), [compact, navOpen, toggleNav, inspector, settings, renaming]);

  useEffect(() => { if (!compact) { setNavOpen(false); setSettings(t => (t === 'index' ? 'general' : t)); } }, [compact]);

  const depth = compact ? +menu.isOpen + +navOpen + +inspector + (settings ? (settings === 'index' ? 1 : 2) : 0) : 0;
  useBackLayers(depth, () => {
    if (menu.isOpen) menu.close(true);
    else if (inspector) setInspector(false);
    else if (navOpen) setNavOpen(false);
    else if (settings) setSettings(settings === 'index' ? null : 'index');
  });

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (s.reply) store.stopReply();
        else if (settings) setSettings(null);
        return;
      }
      if (!(e.metaKey || e.ctrlKey)) return;
      const run = ({
        n: () => { store.newConversation(); promptRef.current?.focus(); },
        k: () => searchRef.current?.focus(),
        b: toggleNav,
        i: () => setInspector(o => !o),
        ',': () => setSettings('general'),
      } as Record<string, () => void>)[e.key.toLowerCase()];
      if (run) { e.preventDefault(); run(); }
    };
    addEventListener('keydown', onKey);
    return () => removeEventListener('keydown', onKey);
  }, [s.reply, settings, store, toggleNav]);

  const blank = isBlank(current(s));
  const gate = !!s.onboard;
  const sheet = compact && menu.isOpen;
  const overlayInspector = inspector && innerWidth <= 1180;
  const pick = (input: HTMLInputElement) => { store.addFiles([...(input.files ?? [])]); input.value = ''; };

  return (
    <ShellContext.Provider value={shell}>
      <div
        className={`app${navCollapsed && !compact ? ' nav-collapsed' : ''}${navOpen ? ' nav-open' : ''}${inspector ? ' ins-open' : ''}`}
        inert={gate || sheet}
        onDragEnter={e => { if (e.dataTransfer.types.includes('Files')) setDropping(true); }}
        onDragOver={e => { if (dropping) e.preventDefault(); }}
        onDragLeave={e => { if (!e.relatedTarget) setDropping(false); }}
        onDrop={e => { e.preventDefault(); setDropping(false); store.addFiles([...e.dataTransfer.files]); }}
      >
        <Nav searchRef={searchRef} />
        <main className="work" inert={(compact && navOpen) || overlayInspector}>
          <Head scrolled={scrolled} />
          <div className={`body${blank ? ' empty' : ''}`}>
            <Thread onScrolled={setScrolled} />
            {dropping && <div className="drop">松开以添加到这条消息</div>}
            <div className="bottom"><div className="bottom-in">
              <Banner />
              <Composer />
              <Starters />
            </div></div>
          </div>
        </main>
        {inspector && <Inspector />}
        <Settings />
        <div className="scrim" onClick={() => setInspector(false)} />
        <input ref={fileRef} type="file" multiple hidden accept="image/*,video/*,.txt,.md,.pdf,.pptx,.docx" onChange={e => pick(e.target)} />
        <input ref={cameraRef} type="file" hidden accept="image/*" capture="environment" onChange={e => pick(e.target)} />
      </div>
      <Onboard />
      <MenuHost />
      <Feedback />
    </ShellContext.Provider>
  );
}

function Feedback() {
  const store = useStore(), toast = useApp(s => s.toast), announce = useApp(s => s.announce);
  return <>
    {toast && <div className="toast" role="status"><span>{toast.text}</span>{toast.actionLabel && <button onClick={() => store.runToast()}>{toast.actionLabel}</button>}</div>}
    <div className="sr" aria-live="polite">{announce}</div>
  </>;
}

export function App() {
  const ready = useApp(s => s.ready);
  useTheme();
  if (!ready) return null;
  return <>
    <div dangerouslySetInnerHTML={{ __html: sprite }} />
    <MenuProvider><Workspace /></MenuProvider>
  </>;
}
