import { mkdir, writeFile } from 'node:fs/promises';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { join } from 'node:path';
import type { Plugin, ViteDevServer } from 'vite';

const PREFIX = '/__relay-check';
const REPORT_FILE = 'relay-check-report.json';
const MAX_REPORT_BYTES = 64 * 1024;

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on('data', (chunk: Buffer) => {
      chunks.push(chunk);
      if (Buffer.concat(chunks).length > MAX_REPORT_BYTES) {
        reject(new Error('report too large'));
        req.destroy();
      }
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
    req.on('error', reject);
  });
}

async function answer(
  server: ViteDevServer,
  url: URL,
  req: IncomingMessage,
  res: ServerResponse
): Promise<void> {
  const path = url.pathname.slice(PREFIX.length);

  if (path === '/echo') {
    res.setHeader('Set-Cookie', `relay_sid=step0; Path=${PREFIX}; Max-Age=86400; HttpOnly`);
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ cookie: req.headers.cookie ?? null }));
    return;
  }
  if (path === '/redirect') {
    res.statusCode = 302;
    res.setHeader('Location', `${PREFIX}/echo`);
    res.end();
    return;
  }

  const status = /^\/status\/(\d{3})$/.exec(path);
  if (status) {
    res.statusCode = Number(status[1]);
    const retryAfter = url.searchParams.get('retry-after');
    if (retryAfter !== null) res.setHeader('Retry-After', retryAfter);
    res.setHeader('Content-Type', 'text/plain');
    res.end(`status ${status[1]}`);
    return;
  }

  const big = /^\/big\/(\d{1,5})$/.exec(path);
  if (big) {
    res.setHeader('Content-Type', 'text/plain');
    res.end('x'.repeat(Number(big[1]) * 1024));
    return;
  }

  if (path === '/report' && req.method === 'POST') {
    const body = await readBody(req);
    // Written to a file rather than the console: the gyo CLI does not forward what the dev
    // server prints.
    await mkdir(server.config.cacheDir, { recursive: true });
    await writeFile(join(server.config.cacheDir, REPORT_FILE), body);
    res.end('ok');
    return;
  }

  res.statusCode = 404;
  res.end('unknown relay check');
}

/**
 * Answers the shell's relay checks (src/pages/relay_check_view.tsx): redirects, cookies, refusals
 * and large bodies, all without leaving the development machine. Served by `vite dev` only. What
 * the page reports ends up in node_modules/.vite/relay-check-report.json.
 */
export function relayCheckServer(): Plugin {
  return {
    name: 'keek-news:relay-check',
    apply: 'serve',
    configureServer(server: ViteDevServer) {
      server.middlewares.use((req, res, next) => {
        const url = new URL(req.url ?? '/', 'http://relay-check');
        if (!url.pathname.startsWith(PREFIX)) {
          next();
          return;
        }
        answer(server, url, req, res).catch((error: unknown) => {
          res.statusCode = 500;
          res.end(String(error));
        });
      });
    },
  };
}
