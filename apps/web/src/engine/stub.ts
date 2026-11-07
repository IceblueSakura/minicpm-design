// Empty implementation of the backend contract. It runs no model: replies say so, and the waits
// are timers, so every interface path works before the real WebGPU backend exists.
//
// ?stub=nogpu|offline|oom|empty opens the matching failure, for review and screenshots.
import { EngineError } from './types';
import type {
  DeviceProfile, DownloadEvent, DownloadHandle, Engine, GenerateRequest, GenerationEvent, ModelOption, ModelStore, PreparedImage,
} from './types';

const flags = new Set(new URLSearchParams(globalThis.location?.search ?? '').getAll('stub'));
const INSTALLED_KEY = 'minicpm.stub.installed';

const sleep = (ms: number, signal?: AbortSignal) => new Promise<void>(resolve => {
  const timer = setTimeout(resolve, ms);
  signal?.addEventListener('abort', () => { clearTimeout(timer); resolve(); }, { once: true });
});

async function readDevice(): Promise<DeviceProfile> {
  const { quota = 0, usage = 0 } = await navigator.storage?.estimate?.() ?? {};
  const memory = (navigator as { deviceMemory?: number }).deviceMemory;
  return {
    canRunLocal: !flags.has('nogpu'),
    memoryGB: memory ?? null,
    freeStorageGB: quota ? (quota - usage) / 2 ** 30 : null,
    accelerator: null,
  };
}

export class StubEngine implements Engine {
  private readonly remote: boolean;
  private images = 0;
  constructor(place: 'local' | 'remote') { this.remote = place === 'remote'; }

  probe() { return readDevice(); }

  async load(_optionId: string, signal?: AbortSignal) {
    await sleep(2000, signal);
    if (flags.has('oom')) throw new EngineError('outOfMemory');
  }

  async unload() {}

  async prepareImage(_file: File): Promise<PreparedImage> {
    await sleep(1000);
    return { handle: `stub-image-${++this.images}` };
  }

  async *generate(request: GenerateRequest, signal: AbortSignal): AsyncIterable<GenerationEvent> {
    if (flags.has('offline')) throw new EngineError('unavailable');
    const started = performance.now();
    const asked = request.messages.at(-1)?.text ?? '';
    const memory = asked.match(/^(?:请|帮我)?记住[：:，,\s]*(.+?)[。.！!]?$/)?.[1].replace(/^我/, '你');
    const search = /^(?:查一下|搜一下)\s*(.+)$/.exec(asked)?.[1];
    const reminder = /^每天.*提醒我/.test(asked);

    let reply = `这是占位回答，${this.remote ? '远程服务' : '本机模型'}还没有接入。\n\n收到了 ${asked.length} 个字。`;
    if (memory) reply = request.canRemember ? '好，记下了。' : '现在不能写入记忆，这条我记不下来。';
    if (search) reply = '这个问题要查一下才知道。';
    if (reminder) reply = '它不在后台运行，但可以到点提醒你回来。';

    await sleep(request.thinking ? 900 : 260, signal);
    for (let i = 0; i < reply.length && !signal.aborted; i += 2) {
      yield { type: 'text', delta: reply.slice(i, i + 2) };
      await sleep(36, signal);
    }
    if (signal.aborted) return;
    if (memory && request.canRemember) yield { type: 'memory', text: memory };
    if (search) yield { type: 'askSearch', query: search };
    if (reminder) yield { type: 'action', kind: 'notify', when: '每天 09:00', text: asked.replace(/^每天.*提醒我/, '') };
    yield { type: 'done', tokensPerSecond: 0, seconds: (performance.now() - started) / 1000 };
  }
}

const option = (family: string, name: string, short: string, tier: 'q4' | 'f16', sizeGB: number, memoryGB: number, recommended: boolean): ModelOption => ({
  id: `${family}-${tier}`, family, name, short, kind: 'vision', caps: ['image', 'video'],
  spec: tier === 'q4' ? { label: '轻量', tag: 'Q4' } : { label: '完整', tag: 'F16' },
  sizeGB, memoryGB, recommended, loadSeconds: Math.round(sizeGB * 2),
});

// Placeholder catalog: the first stage has vision models only. The real list comes from the hardware.
const CATALOG = [
  option('minicpm-v-4.6', 'MiniCPM-V 4.6', 'V 4.6', 'q4', 3.7, 5, true),
  option('minicpm-v-4.6', 'MiniCPM-V 4.6', 'V 4.6', 'f16', 11, 13, false),
  option('minicpm-v-4.5', 'MiniCPM-V 4.5', 'V 4.5', 'q4', 5.1, 7, false),
];

export class StubModelStore implements ModelStore {
  async catalog(): Promise<ModelOption[]> { return CATALOG; }

  async installed(): Promise<string[]> {
    if (flags.has('empty')) return [];
    return JSON.parse(localStorage.getItem(INSTALLED_KEY) ?? '[]');
  }

  private save(ids: string[]) { localStorage.setItem(INSTALLED_KEY, JSON.stringify(ids)); }

  download(optionId: string, onEvent: (event: DownloadEvent) => void): DownloadHandle {
    let pct = 0, paused = false;
    const timer = setInterval(async () => {
      if (paused) return;
      pct = Math.min(100, pct + 2);
      if (pct < 100) return onEvent({ status: 'running', pct });
      clearInterval(timer);
      onEvent({ status: 'verifying', pct });
      await sleep(600);
      const family = CATALOG.find(o => o.id === optionId)?.family;
      const kept = (await this.installed()).filter(id => CATALOG.find(o => o.id === id)?.family !== family);
      this.save([...kept, optionId]);
      onEvent({ status: 'done', pct });
    }, 80);
    return {
      pause() { paused = true; onEvent({ status: 'paused', pct }); },
      resume() { paused = false; onEvent({ status: 'running', pct }); },
      cancel() { clearInterval(timer); },
    };
  }

  async remove(optionId: string) { this.save((await this.installed()).filter(id => id !== optionId)); }
}
