/// <reference types="vitest/config" />
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import { relayCheckServer } from './dev/relay-check-server.ts';

export default defineConfig({
  plugins: [react(), relayCheckServer()],
  server: {
    host: true,
    port: 3000,
    strictPort: true,
  },
  test: {
    include: ['test/**/*.test.ts'],
  },
});
