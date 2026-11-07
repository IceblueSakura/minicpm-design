import { createContext, useContext, useEffect, useState, useSyncExternalStore } from 'react';
import type { AppStore } from '../core/store';
import type { AppState } from '../core/types';

export const StoreContext = createContext<AppStore>(null!);
export const useStore = () => useContext(StoreContext);

export function useApp<T = AppState>(pick: (s: AppState) => T = s => s as T): T {
  const store = useStore();
  return useSyncExternalStore(store.subscribe, () => pick(store.getState()));
}

// Mirrors the "Compact form" media query in styles/app.css. Change them together.
const COMPACT_QUERY = '(max-width:839px),(max-height:479px) and (pointer:coarse)';

export function useCompact() {
  const [compact, setCompact] = useState(() => matchMedia(COMPACT_QUERY).matches);
  useEffect(() => {
    const query = matchMedia(COMPACT_QUERY), update = () => setCompact(query.matches);
    update();
    query.addEventListener('change', update);
    return () => query.removeEventListener('change', update);
  }, []);
  return compact;
}

export const MOD = /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl+';
