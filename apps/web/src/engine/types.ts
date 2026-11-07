// The contract the inference backend implements. See docs/11-client-architecture.md.
// Everything crossing it is plain data plus AbortSignal, so an implementation can live in a Worker.

export type Capability = 'image' | 'video' | 'audio' | 'speech' | 'live';
export type ModelKind = 'vision' | 'omni';

export interface DeviceProfile {
  /** False when this browser cannot run a model locally; the UI offers remote instead. */
  canRunLocal: boolean;
  /** Null means unreadable, which is not the same as zero. */
  memoryGB: number | null;
  freeStorageGB: number | null;
  accelerator: string | null;
}

/** One downloadable choice. The backend lists these from the hardware it can read. */
export interface ModelOption {
  id: string;
  /** Options of one family replace each other on disk: one spec per model. */
  family: string;
  name: string;
  short: string;
  kind: ModelKind;
  caps: Capability[];
  spec: { label: string; tag: string };
  sizeGB: number;
  memoryGB: number;
  recommended: boolean;
  /** Rough wait shown in banners; replaced by measured values once devices are tested. */
  loadSeconds: number;
}

export type DownloadStatus = 'running' | 'paused' | 'wifi' | 'failed' | 'verifying' | 'badfile' | 'done';
export interface DownloadEvent { status: DownloadStatus; pct: number }
export interface DownloadHandle { pause(): void; resume(): void; cancel(): void }

export interface ModelStore {
  catalog(device: DeviceProfile): Promise<ModelOption[]>;
  installed(): Promise<string[]>;
  download(optionId: string, onEvent: (event: DownloadEvent) => void): DownloadHandle;
  remove(optionId: string): Promise<void>;
}

export interface GenerationParams {
  max_tokens: number;
  temperature: number;
  top_p: number;
  top_k: number;
  repeat_penalty: number;
  n_ctx: number;
}

/** Opaque to the app. Sent back inside a request; generate() waits if it is still being processed. */
export interface PreparedImage { handle: string }

export interface RequestMessage {
  role: 'user' | 'assistant';
  text: string;
  images: PreparedImage[];
}

export interface GenerateRequest {
  modelId: string;
  /** Persona and the memories worth using. */
  system: string;
  messages: RequestMessage[];
  params: GenerationParams;
  thinking: boolean;
  highDetail: boolean;
  /** False in temporary chats or with memory off: the model has to say it cannot remember. */
  canRemember: boolean;
}

export type GenerationEvent =
  | { type: 'text'; delta: string }
  | { type: 'memory'; text: string }
  | { type: 'askSearch'; query: string }
  | { type: 'action'; kind: 'notify' | 'memo'; when?: string; text: string }
  | { type: 'cut'; reason: 'length' }
  | { type: 'done'; tokensPerSecond: number; seconds: number };

export type EngineErrorCode = 'unavailable' | 'outOfMemory' | 'network' | 'notInstalled';

export class EngineError extends Error {
  readonly code: EngineErrorCode;
  constructor(code: EngineErrorCode, message = code) {
    super(message);
    this.name = 'EngineError';
    this.code = code;
  }
}

export interface Engine {
  probe(): Promise<DeviceProfile>;
  /** One model at a time. Rejects with outOfMemory when it does not fit. */
  load(optionId: string, signal?: AbortSignal): Promise<void>;
  unload(): Promise<void>;
  prepareImage(file: File): Promise<PreparedImage>;
  /** Aborting ends the stream without an error; what was generated stays. */
  generate(request: GenerateRequest, signal: AbortSignal): AsyncIterable<GenerationEvent>;
}
