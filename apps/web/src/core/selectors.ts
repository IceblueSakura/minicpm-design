// Derived state and the privacy copy. Every "where does my content go" line reads from here,
// so a new path out of the device has one place to land (AGENTS.md: privacy copy must stay true).
import type { ModelOption } from '../engine/types';
import type { AppState, Attachment, Conversation, SceneId } from './types';
import { SCENE_IDS } from './scenes';

export type BackendState = 'unset' | 'nonet' | 'nogpu' | 'offline' | 'nomodel' | 'ready';

export const isRemote = (s: AppState) => s.backend === 'remote';
export const remoteHost = (s: AppState) => { try { return new URL(s.remote.url).host; } catch { return s.remote.url; } };
export const current = (s: AppState): Conversation => s.conversations.find(c => c.id === s.current)!;
export const option = (s: AppState, id: string | null): ModelOption | undefined => s.catalog.find(o => o.id === id);
export const currentModel = (s: AppState) => option(s, s.model);

export function backendState(s: AppState): BackendState {
  if (isRemote(s) && !s.remote.url) return 'unset';
  if (isRemote(s) && s.prefs.offlineMode) return 'nonet';
  if (!isRemote(s) && !s.device.canRunLocal) return 'nogpu';
  if (s.engine === 'offline') return 'offline';
  if (!isRemote(s) && !(s.model && s.installed.includes(s.model))) return 'nomodel';
  return 'ready';
}
export const backendReady = (s: AppState) => backendState(s) === 'ready';
export const cannotSend = (s: AppState) => ['nomodel', 'nogpu', 'nonet', 'unset'].includes(backendState(s));
export const sendingOut = (s: AppState) => isRemote(s) && !!s.remote.url && !s.prefs.offlineMode;

export function privacyLine(s: AppState): string {
  if (isRemote(s)) return !s.remote.url ? '还没设置远程服务，内容不会发送' : s.prefs.offlineMode ? '离线模式开着，内容不会发送' : `内容会发送到 ${remoteHost(s)} 处理`;
  return '只在这台设备上处理，内容不会离开';
}

export function privacySummary(s: AppState): [string, string] {
  if (sendingOut(s)) return [`内容正发送到 ${remoteHost(s)}`, '处理时图片和文字会离开本机，对话记录仍保存在这里。'];
  if (isRemote(s)) return ['内容现在不会发送', s.remote.url ? '离线模式开着，关闭后才会发送到远程服务。' : '运行位置选了远程服务，填好地址后才会发送到那里。'];
  return ['你的内容留在这台设备上', '图片、文件和对话都在本机处理，断网也能用。'];
}

export const processedAt = (s: AppState) => (sendingOut(s) ? '内容会发送到这台服务器处理。' : isRemote(s) ? '现在不会发送。' : '图片和文件都留在本机。');

export const can = (s: AppState, cap: ModelOption['caps'][number]) => !!currentModel(s)?.caps.includes(cap);
export const attOk = (s: AppState, a: Pick<Attachment, 'kind'>) => (a.kind === 'audio' ? can(s, 'audio') : a.kind === 'video' ? can(s, 'video') : true);
export const canRemember = (s: AppState, c: Conversation) => s.prefs.memory && !c.temp;
export const isBlank = (c: Conversation) => c.items.length === 0;
export const activeScenes = (s: AppState, c?: Conversation): SceneId[] => SCENE_IDS.filter(id => !s.sceneOff.includes(id) || id === c?.scene);
export const specText = (o: ModelOption) => `${o.spec.label} ${o.spec.tag}`;
export const capsText = (o: ModelOption) => o.caps.map(c => ({ image: '看图', video: '看视频', audio: '听语音', speech: '说话', live: '实时对话' })[c]).join(' · ');
export const kindText = (o: ModelOption) => (o.kind === 'omni' ? '全能' : '看图');

/** One row per family: the spec on disk if there is one, else the catalog's first. */
export function modelChoices(s: AppState): ModelOption[] {
  const seen = new Map<string, ModelOption>();
  for (const o of s.catalog) {
    const had = seen.get(o.family);
    if (!had || (s.installed.includes(o.id) && !s.installed.includes(had.id))) seen.set(o.family, o);
  }
  return [...seen.values()];
}

export function dlText(s: AppState): string {
  const d = s.dl, o = option(s, d?.optionId ?? null);
  if (!d || !o) return '';
  const pct = Math.round(d.pct), left = (o.sizeGB * (100 - d.pct) / 100).toFixed(1);
  return {
    running: `${pct}% · 还差 ${left} GB`, paused: `已暂停 · ${pct}%`, wifi: `等待 Wi-Fi · ${pct}%，还差 ${left} GB`,
    failed: `下载中断 · ${pct}%，已下载的部分还在`, verifying: '正在检查文件…', badfile: '文件不完整，要重新下载', done: '',
  }[d.status];
}

export function engineStatus(s: AppState): [dot: string, text: string] {
  const st = backendState(s);
  if (st === 'unset') return ['bad', '远程服务未配置'];
  if (st === 'nonet') return ['bad', '离线模式已开'];
  if (st === 'nogpu') return ['bad', '这个浏览器不能本机运行'];
  if (st === 'offline') return ['bad', isRemote(s) ? '连不上远程服务' : '模型未启动'];
  if (st === 'nomodel') return ['warn', s.dl ? `下载中 ${Math.round(s.dl.pct)}%` : '模型未下载'];
  if (s.loading) return ['warn', s.swapFrom ? '正在换模型' : '正在准备模型'];
  return ['ok', `${isRemote(s) ? '远程' : '本机运行'} · ${s.reply ? '生成中' : '空闲'}`];
}

export function dayGroup(at: number, now = Date.now()): string {
  const day = (t: number) => new Date(t).setHours(0, 0, 0, 0);
  const days = Math.round((day(now) - day(at)) / 864e5);
  return days <= 0 ? '今天' : days === 1 ? '昨天' : days < 7 ? '最近 7 天' : '更早';
}

export function ago(at: number, now = Date.now()): string {
  const minutes = Math.floor((now - at) / 6e4);
  if (minutes < 1) return '刚刚';
  if (minutes < 60) return `${minutes} 分钟前`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)} 小时前`;
  return new Date(at).toLocaleDateString('zh-Hans', { month: 'numeric', day: 'numeric' });
}
