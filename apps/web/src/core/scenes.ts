import type { SceneId } from './types';

export interface Starter { icon: string; title: string; sub: string; prompt?: string; camera?: boolean }

// Ids are stable; names are display text and may change. Live starters return with the omni model.
export const SCENES: Record<SceneId, { name: string; hint: string; source: string; starters: Starter[] }> = {
  life: { name: '生活助手', source: '内置', hint: '生活交流、物品观察', starters: [
    { icon: 'file', title: '读一张单据', sub: '拍照或上传图片', prompt: '帮我看看这张单据上有什么要注意的' } ] },
  work: { name: '工作助手', source: '内置', hint: '材料分析、屏幕协作、工作整理', starters: [
    { icon: 'file', title: '分析一份材料', sub: '拖入 PDF、PPT 或图片', prompt: '帮我梳理这份材料的主要内容' },
    { icon: 'clock', title: '安排今天的工作', sub: '按截止时间和依赖排序', prompt: '帮我安排今天的工作' } ] },
  game: { name: '游戏助手', source: '内置', hint: '围绕游戏画面提供辅助', starters: [
    { icon: 'file', title: '分析一张截图', sub: '看阵容、地图或配装', prompt: '帮我分析这张游戏截图' } ] },
  community: { name: '社区助手', source: '内置', hint: '社区消息整理、定时通知', starters: [
    { icon: 'clock', title: '设置定时通知', sub: '到点提醒你来整理消息', prompt: '每天早上提醒我整理社区消息' },
    { icon: 'file', title: '整理一批消息', sub: '粘贴或上传聊天记录', prompt: '帮我整理这批社区消息' } ] },
};

export const EXTRA_STARTERS: Starter[] = [
  { icon: 'camera', title: '拍一张问问', sub: '拍下面前的东西', camera: true },
  { icon: 'file', title: '看一张图', sub: '上传图片，问它细节', prompt: '帮我看看这张图' },
  { icon: 'file', title: '读一份文档', sub: '提取要点和数字', prompt: '帮我提取这份文档的要点' },
];

export const SCENE_IDS = Object.keys(SCENES) as SceneId[];
