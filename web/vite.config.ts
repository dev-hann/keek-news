/// <reference types="vitest/config" />
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import { relayCheckServer } from './dev/relay-check-server.ts';

const require = createRequire(import.meta.url);

export default defineConfig({
  plugins: [react(), tailwindcss(), relayCheckServer()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url).href) },
  },
  define: {
    // The version the app shows is the app's, not the web package's: the one the
    // shell is released under. It is bumped there, once, for both.
    __APP_VERSION__: JSON.stringify(require('../shell/gyo.config.json').version),
  },
  server: {
    host: true,
    port: 3000,
    strictPort: true,
  },
  test: {
    include: ['test/**/*.test.ts', 'test/**/*.test.tsx'],
    setupFiles: ['./test/setup.ts'],
  },
});
