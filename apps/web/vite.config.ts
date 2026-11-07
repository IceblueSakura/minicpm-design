import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

// Multi-threaded WebAssembly backends need SharedArrayBuffer, which needs cross-origin isolation.
// Set here so the app is already tested under the headers the WebGPU backend will require.
const isolation = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
};

export default defineConfig({
  base: './',
  plugins: [react()],
  server: { headers: isolation },
  preview: { headers: isolation },
  test: { include: ['src/**/*.test.ts'] },
});
