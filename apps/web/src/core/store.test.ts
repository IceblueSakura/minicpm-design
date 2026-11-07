import { describe, expect, it, vi } from 'vitest';
import type { Backends } from '../engine';
import { EngineError } from '../engine/types';
import type { DeviceProfile, Engine, GenerationEvent, ModelOption, ModelStore } from '../engine/types';
import { localPersistence } from './persist';
import type { Persistence, Saved } from './persist';
import { backendState, current, privacyLine } from './selectors';
import { AppStore } from './store';

const option = (id: string, family = id): ModelOption => ({
  id, family, name: id, short: id, kind: 'vision', caps: ['image'], spec: { label: '轻量', tag: 'Q4' }, sizeGB: 1, memoryGB: 1, recommended: true, loadSeconds: 1,
});
const device: DeviceProfile = { canRunLocal: true, memoryGB: 8, freeStorageGB: 50, accelerator: null };

function fakeEngine(over: Partial<Engine> = {}): Engine {
  return {
    probe: async () => device,
    load: async () => {},
    unload: async () => {},
    prepareImage: async () => ({ handle: 'h' }),
    async *generate(): AsyncIterable<GenerationEvent> { yield { type: 'text', delta: 'hi' }; },
    ...over,
  };
}

async function setup({ local = fakeEngine(), remote = fakeEngine(), saved = { onboarded: true } as Saved | null } = {}) {
  const models: ModelStore = {
    catalog: async () => [option('a'), option('b')],
    installed: async () => ['a', 'b'],
    download: () => ({ pause() {}, resume() {}, cancel() {} }),
    remove: async () => {},
  };
  const persistence: Persistence = { load: () => saved, save: () => {} };
  const backends: Backends = { engines: { local, remote }, models };
  const store = new AppStore(backends, persistence);
  await store.boot();
  await vi.waitFor(() => expect(store.getState().loaded).toBe('a'));
  return store;
}

const say = (store: AppStore, text: string) => { store.setDraft(text); store.send(); };
const settled = (store: AppStore) => vi.waitFor(() => expect(store.getState()).toMatchObject({ queued: false, reply: null }));

describe('privacy copy', () => {
  it('names the destination whenever content can leave', async () => {
    const store = await setup();
    expect(privacyLine(store.getState())).toContain('这台设备');
    store.setRemoteUrl('wss://gpu.example.com/omni');
    store.setBackend('remote');
    expect(privacyLine(store.getState())).toBe('内容会发送到 gpu.example.com 处理');
    store.setPref('offlineMode', true);
    expect(privacyLine(store.getState())).toBe('离线模式开着，内容不会发送');
  });
});

describe('backend state', () => {
  it('reports the remote problem before anything local', async () => {
    const store = await setup();
    store.setBackend('remote');
    expect(backendState(store.getState())).toBe('unset');
    store.setRemoteUrl('wss://x.example');
    store.setPref('offlineMode', true);
    expect(backendState(store.getState())).toBe('nonet');
  });
});

describe('switching models', () => {
  it('goes back to the old model when the new one does not fit', async () => {
    const local = fakeEngine({ load: async id => { if (id === 'b') throw new EngineError('outOfMemory'); } });
    const store = await setup({ local });
    store.setModel('b');
    await vi.waitFor(() => expect(store.getState().swapFail?.id).toBe('b'));
    await vi.waitFor(() => expect(store.getState().loaded).toBe('a'));
    expect(store.getState().model).toBe('a');
    expect(store.getState().swapFail).toEqual({ id: 'b', cold: false });
  });

  it('keeps a message sent during the wait and answers it after the load', async () => {
    let finish = () => {};
    const local = fakeEngine({ load: id => (id === 'b' ? new Promise(resolve => { finish = resolve; }) : Promise.resolve()) });
    const store = await setup({ local });
    store.setModel('b');
    await vi.waitFor(() => expect(store.getState().loading).toBe('b'));
    say(store, '你好');
    say(store, '第二句留在输入框');
    expect(current(store.getState()).items.map(i => i.type)).toEqual(['user']);
    finish();
    await vi.waitFor(() => expect(current(store.getState()).items.map(i => i.type)).toEqual(['user', 'ai']));
  });
});

describe('failures', () => {
  it('never moves to remote on its own and keeps the message', async () => {
    const local = fakeEngine({ async *generate() { throw new EngineError('unavailable'); } });
    const store = await setup({ local });
    store.setRemoteUrl('wss://x.example');
    say(store, '你好');
    await settled(store);
    const s = store.getState();
    expect(s.backend).toBe('local');
    expect(s.engine).toBe('offline');
    expect(current(s).items).toMatchObject([{ type: 'user', text: '你好', failed: true }]);
  });
});

describe('place marker', () => {
  it('leaves one line where content starts going elsewhere', async () => {
    const store = await setup();
    say(store, '一');
    await settled(store);
    store.setRemoteUrl('wss://x.example');
    store.setBackend('remote');
    say(store, '二');
    await settled(store);
    say(store, '三');
    await settled(store);
    const marks = current(store.getState()).items.filter(i => i.type === 'place');
    expect(marks).toHaveLength(1);
    expect(marks[0]).toMatchObject({ text: '从这里开始发送到 x.example 处理，上文也包括在内' });
  });
});

describe('memory', () => {
  it('does not write in a temporary conversation', async () => {
    const local = fakeEngine({ async *generate() { yield { type: 'memory', text: '喜欢短回答' }; } });
    const store = await setup({ local });
    store.toggleTemp();
    say(store, '记住');
    await settled(store);
    expect(store.getState().memories).toEqual([]);
    expect(current(store.getState()).items.some(i => i.type === 'memory')).toBe(false);
  });
});

describe('persistence', () => {
  it('skips item types this version does not know', () => {
    const data = new Map([['minicpm.state.v1', JSON.stringify({ conversations: [{ id: 'c', items: [{ type: 'live', id: '1' }, { type: 'user', id: '2', text: 'x', atts: [] }] }] })]]);
    vi.stubGlobal('localStorage', { getItem: (k: string) => data.get(k) ?? null });
    expect(localPersistence.load()?.conversations?.[0].items.map(i => i.type)).toEqual(['user']);
    vi.unstubAllGlobals();
  });
});
