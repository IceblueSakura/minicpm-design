// Popover on wide windows, bottom sheet in the compact form. One primitive, as in the prototype.
import { createContext, useCallback, useContext, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useCompact } from './hooks';

interface Open { key: string; anchor: HTMLElement | null; label: string; role: string; render: () => ReactNode }
interface MenuApi {
  open(menu: Open): void;
  close(refocus?: boolean): void;
  isOpen: boolean;
  current: Open | null;
}
const Ctx = createContext<MenuApi>(null!);
export const useMenu = () => useContext(Ctx);

export function MenuProvider({ children }: { children: ReactNode }) {
  const [menu, setMenu] = useState<Open | null>(null);
  const menuRef = useRef<Open | null>(null);
  menuRef.current = menu;

  const close = useCallback((refocus = false) => {
    const anchor = menuRef.current?.anchor;
    anchor?.setAttribute('aria-expanded', 'false');
    setMenu(null);
    if (refocus && anchor?.isConnected) anchor.focus();
  }, []);
  const open = useCallback((next: Open) => {
    if (menuRef.current?.key === next.key) { close(); return; }
    menuRef.current?.anchor?.setAttribute('aria-expanded', 'false');
    next.anchor?.setAttribute('aria-expanded', 'true');
    setMenu(next);
  }, [close]);
  const api = useMemo(() => ({ open, close, isOpen: !!menu, current: menu }), [open, close, menu]);

  return <Ctx.Provider value={api}>{children}</Ctx.Provider>;
}

/** Rendered inside the shell, so menu content can reach it through context. */
export function MenuHost() {
  const { current, close } = useMenu();
  return current && <Surface menu={current} close={close} />;
}

function Surface({ menu, close }: { menu: Open; close: (refocus?: boolean) => void }) {
  const compact = useCompact();
  const ref = useRef<HTMLDivElement>(null);
  const [drag, setDrag] = useState<{ y0: number; dy: number } | null>(null);

  useLayoutEffect(() => {
    const el = ref.current!;
    if (compact || !menu.anchor) return;
    const r = menu.anchor.getBoundingClientRect(), m = el.getBoundingClientRect();
    el.style.left = `${Math.max(8, Math.min(r.left, innerWidth - m.width - 8))}px`;
    el.style.top = `${Math.max(8, r.bottom + 6 + m.height > innerHeight - 8 ? r.top - m.height - 6 : r.bottom + 6)}px`;
  }, [compact, menu]);

  useEffect(() => { ref.current?.querySelector<HTMLElement>('.mi,.btn')?.focus(); }, [menu.key]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { e.stopPropagation(); close(true); return; }
      if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
      const items = [...ref.current!.querySelectorAll<HTMLElement>('.mi:not(:disabled)')];
      if (!items.length) return;
      e.preventDefault();
      const at = items.indexOf(document.activeElement as HTMLElement);
      items[(at + (e.key === 'ArrowDown' ? 1 : items.length - 1)) % items.length].focus();
    };
    const onDown = (e: PointerEvent) => {
      const target = e.target as Node;
      if (!ref.current?.contains(target) && !menu.anchor?.contains(target)) close();
    };
    document.addEventListener('keydown', onKey, true);
    document.addEventListener('pointerdown', onDown);
    return () => { document.removeEventListener('keydown', onKey, true); document.removeEventListener('pointerdown', onDown); };
  }, [close, menu.anchor]);

  return createPortal(<>
    {compact && <div className="sheet-scrim" onClick={() => close(true)} />}
    <div
      ref={ref}
      className={`menu${compact ? ' sheet' : ''}`}
      role={menu.role}
      aria-label={menu.label}
      aria-modal={compact || undefined}
      style={drag ? { transform: `translateY(${drag.dy}px)`, transition: 'none' } : undefined}
    >
      {compact && (
        <div
          className="grip"
          aria-hidden="true"
          onPointerDown={e => { e.currentTarget.setPointerCapture(e.pointerId); setDrag({ y0: e.clientY, dy: 0 }); }}
          onPointerMove={e => { if (drag) setDrag({ ...drag, dy: Math.max(0, e.clientY - drag.y0) }); }}
          onPointerUp={() => { const far = (drag?.dy ?? 0) > 70; setDrag(null); if (far) close(true); }}
          onPointerCancel={() => setDrag(null)}
        />
      )}
      {menu.render()}
    </div>
  </>, document.body);
}

export function MenuItem({ title, sub, icon, tick, danger, role = 'menuitem', onClick }: {
  title: string; sub?: string; icon?: ReactNode; tick?: boolean; danger?: boolean; role?: string; onClick: () => void;
}) {
  return (
    <button type="button" className={`mi${danger ? ' danger' : ''}`} role={role} aria-checked={tick === undefined ? undefined : tick} onClick={onClick}>
      {icon}
      <span><b>{title}</b>{sub && <small>{sub}</small>}</span>
      {tick && <span className="tick">✓</span>}
    </button>
  );
}
