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
    __APP_VERSION__: JSON.stringify(require('./package.json').version),
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
