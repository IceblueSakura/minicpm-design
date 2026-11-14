import type { DownloadStatus, GenerationParams, ModelOption, PreparedImage, DeviceProfile } from '../engine/types';

export type SceneId = 'life' | 'work' | 'game' | 'community';
export type Place = 'local' | 'remote';

export interface Attachment {
  id: string;
  kind: 'image' | 'video' | 'audio' | 'file';
  name: string;
  sub: string;
  /** Object URL, gone after a reload; the row then falls back to the file icon. */
  url?: string;
  busy?: boolean;
  prepared?: PreparedImage;
}

export interface UserItem { type: 'user'; id: string; text: string; atts: Attachment[]; failed?: boolean }
export interface AiItem {
  type: 'ai'; id: string; text: string;
  /** Which model answered, so an upgrade later can tell old answers apart. */
  model: string;
  stat?: string;
  cut?: 'length' | 'crash';
}
export interface AskItem { type: 'ask'; id: string; query: string; state: 'open' | 'allowed' | 'denied' }
export interface ActionItem { type: 'action'; id: string; kind: 'notify' | 'memo'; when?: string; text: string; state: 'open' | 'added' | 'declined' }
export interface MemoryItem { type: 'memory'; id: string; text: string }
export interface PlaceItem { type: 'place'; id: string; text: string }
export type ThreadItem = UserItem | AiItem | AskItem | ActionItem | MemoryItem | PlaceItem;
export const ITEM_TYPES: readonly string[] = ['user', 'ai', 'ask', 'action', 'memory', 'place'];

export interface Conversation {
  id: string;
  title: string;
  autoTitle: boolean;
  temp: boolean;
  scene: SceneId;
  updatedAt: number;
  items: ThreadItem[];
  /** Where the last message went: 'local' or a host. A change leaves a marker in the thread. */
  place: string;
  sources: string[];
  unread?: boolean;
}

export interface Prefs {
  lang: string; textSize: string; openTo: 'new' | 'last'; defaultScene: SceneId;
  replyLang: string; replyLength: 'short' | 'normal' | 'long'; callName: string;
  hd: boolean; idleRelease: string; thermal: boolean;
  offlineMode: boolean; webSearch: 'off' | 'ask' | 'auto'; updates: boolean; analytics: boolean; crash: 'ask' | 'never' | 'auto';
  keepHistory: boolean; tempDefault: boolean; retention: string; memory: boolean;
  tech: boolean;
}

export const DEFAULT_PREFS: Prefs = {
  lang: 'system', textSize: 'm', openTo: 'new', defaultScene: 'life',
  replyLang: 'ui', replyLength: 'normal', callName: '',
  hd: false, idleRelease: '15', thermal: true,
  offlineMode: false, webSearch: 'ask', updates: true, analytics: false, crash: 'ask',
  keepHistory: true, tempDefault: false, retention: 'never', memory: true,
  tech: true,
};

export type PresetId = 'saver' | 'balanced' | 'detail' | 'custom';
export const PRESETS: Record<Exclude<PresetId, 'custom'>, { label: string; sub: string; params: GenerationParams }> = {
  saver: { label: '省电', sub: '回答更短，更省电', params: { max_tokens: 512, temperature: .7, top_p: .9, top_k: 40, repeat_penalty: 1.05, n_ctx: 2048 } },
  balanced: { label: '均衡', sub: '默认，适合大多数情况', params: { max_tokens: 1024, temperature: .7, top_p: .9, top_k: 40, repeat_penalty: 1.05, n_ctx: 4096 } },
  detail: { label: '细致', sub: '回答更完整，响应更慢', params: { max_tokens: 2048, temperature: .7, top_p: .9, top_k: 40, repeat_penalty: 1.05, n_ctx: 8192 } },
};

export interface Download { optionId: string; pct: number; status: DownloadStatus }
export interface Toast { id: number; text: string; actionLabel?: string; action?: () => void }
export interface NetEvent { kind: string; detail: string; at: number }

export interface AppState {
  ready: boolean;
  onboard: null | 'welcome' | 'model' | 'download';
  obPick: string | null;

  conversations: Conversation[];
  current: string;
  drafts: Record<string, string>;
  atts: Attachment[];
  thinking: boolean;

  device: DeviceProfile;
  catalog: ModelOption[];
  installed: string[];
  /** The app's one current model, shared by every conversation. */
  model: string | null;
  loaded: string | null;
  loading: string | null;
  /** Set while switching: the old model is released first, so `loaded` alone cannot tell a switch from a cold start. */
  swapFrom: string | null;
  swapFail: { id: string; cold: boolean } | null;
  /** The last run died while loading, so this run does not retry on its own. */
  loadCrashed: boolean;
  dl: Download | null;

  backend: Place;
  remote: { url: string; hasToken: boolean };
  engine: 'ready' | 'offline';

  reply: { conversationId: string; itemId: string } | null;
  /** A sent message waiting for the model or its images. */
  queued: boolean;

  theme: 'system' | 'light' | 'dark';
  sendKey: 'enter' | 'mod';
  persona: string;
  preset: PresetId;
  params: GenerationParams;
  prefs: Prefs;
  sceneOff: SceneId[];
  memories: string[];
  netLog: NetEvent[];

  toast: Toast | null;
  announce: string;
}
