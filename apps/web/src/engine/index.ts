import { StubEngine, StubModelStore } from './stub';
import type { Engine, ModelStore } from './types';

export interface Backends {
  /** One instance per run location. The app only switches between them when the user does. */
  engines: Record<'local' | 'remote', Engine>;
  models: ModelStore;
}

// The single place to swap in the WebGPU backend: replace `local` and `models` here.
export const createBackends = (): Backends => ({
  engines: { local: new StubEngine('local'), remote: new StubEngine('remote') },
  models: new StubModelStore(),
});
