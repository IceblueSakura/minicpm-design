import { useRef } from 'react';
import type { PointerEvent } from 'react';

/** Compact form only: touch-hold opens the sheet the desktop shows as buttons. */
export function useLongPress(enabled: boolean, run: () => void) {
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const y = useRef(0), fired = useRef(false);
  const cancel = () => clearTimeout(timer.current);
  if (!enabled) return {};
  return {
    onPointerDown(e: PointerEvent) {
      fired.current = false;
      if (e.pointerType === 'mouse' || (e.target as HTMLElement).closest('.icon-btn,a,summary')) return;
      y.current = e.clientY;
      timer.current = setTimeout(() => { fired.current = true; run(); }, 450);
    },
    onPointerMove(e: PointerEvent) { if (Math.abs(e.clientY - y.current) > 8) cancel(); },
    onPointerUp: cancel,
    onPointerCancel: cancel,
    onClickCapture(e: React.MouseEvent) { if (fired.current) { fired.current = false; e.stopPropagation(); e.preventDefault(); } },
    onContextMenu(e: React.MouseEvent) { e.preventDefault(); },
  };
}
