import { createContext, useContext } from 'react';
import type { RefObject } from 'react';

export type SettingsTab = 'index' | 'general' | 'voice' | 'models' | 'privacy' | 'applications' | 'advanced' | 'memories' | 'network' | 'resources';

export interface ShellApi {
  compact: boolean;
  navOpen: boolean;
  toggleNav(): void;
  closeNav(): void;
  inspector: boolean;
  toggleInspector(): void;
  settings: SettingsTab | null;
  openSettings(tab?: SettingsTab): void;
  closeSettings(): void;
  renaming: string | null;
  setRenaming(id: string | null): void;
  promptRef: RefObject<HTMLTextAreaElement | null>;
  pickFile(): void;
  takePhoto(): void;
}

export const ShellContext = createContext<ShellApi>(null!);
export const useShell = () => useContext(ShellContext);
