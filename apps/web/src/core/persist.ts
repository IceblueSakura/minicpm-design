import { ITEM_TYPES } from './types';
import type { AppState, Conversation } from './types';

export type Saved = Partial<Pick<AppState, 'conversations' | 'current' | 'drafts' | 'model' | 'backend' | 'theme' | 'sendKey' | 'persona' | 'preset' | 'params' | 'prefs' | 'sceneOff' | 'memories' | 'netLog'>> & {
  remoteUrl?: string;
  onboarded?: boolean;
};

export interface Persistence { load(): Saved | null; save(saved: Saved): void }

const KEY = 'minicpm.state.v1';
const LOAD_MARK = 'minicpm.loading';

// localStorage is enough for the skeleton. Attachments and long histories move to IndexedDB with the real backend.
export const localPersistence: Persistence = {
  load() {
    try {
      const saved = JSON.parse(localStorage.getItem(KEY) ?? 'null') as Saved | null;
      if (saved?.conversations) saved.conversations = saved.conversations.map(c => ({ ...c, items: c.items.filter(i => ITEM_TYPES.includes(i.type)) }));
      return saved;
    } catch { return null; }
  },
  save(saved) {
    try { localStorage.setItem(KEY, JSON.stringify(saved)); } catch { /* full or blocked: the session keeps working */ }
  },
};

/** Written before a load starts and cleared after, so the next run can tell the load killed the app. */
export const loadMark = {
  set() { try { localStorage.setItem(LOAD_MARK, '1'); } catch { /* best effort */ } },
  clear() { try { localStorage.removeItem(LOAD_MARK); } catch { /* best effort */ } },
  get() { try { return localStorage.getItem(LOAD_MARK) === '1'; } catch { return false; } },
};

export function snapshot(s: AppState): Saved {
  const keep = s.prefs.keepHistory;
  const conversations: Conversation[] = keep
    ? s.conversations.filter(c => !c.temp && c.items.length).map(c => ({ ...c, items: c.items.map(i => (i.type === 'user' ? { ...i, atts: i.atts.map(({ url: _url, prepared: _prepared, ...a }) => a) } : i)) }))
    : [];
  return {
    conversations, current: keep ? s.current : undefined, drafts: keep ? s.drafts : {},
    model: s.model, backend: s.backend, remoteUrl: s.remote.url, theme: s.theme, sendKey: s.sendKey, persona: s.persona,
    preset: s.preset, params: s.params, prefs: s.prefs, sceneOff: s.sceneOff, memories: s.memories, netLog: s.netLog,
    onboarded: s.onboard === null,
  };
}
