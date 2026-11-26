// Minimal static server for the spike page. No dependencies.
//
// With SPIKE_DEV_RELAY=1 it also serves /__relay, a local copy of the Kotlin
// HttpBridge contract, so the page logic can be exercised in a desktop browser
// that has no native bridge. Never enable it outside the spike.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const PORT = Number(process.env.PORT || 3000);
const DEV_RELAY = process.env.SPIKE_DEV_RELAY === '1';
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
};

async function relay(url, headers) {
  const started = performance.now();
  const response = await fetch(url, { headers, redirect: 'manual' });
  const bytes = new Uint8Array(await response.arrayBuffer());
  return {
    status: response.status,
    contentType: response.headers.get('content-type'),
    bodyBase64: Buffer.from(bytes).toString('base64'),
    elapsedMs: Math.round(performance.now() - started),
  };
}

function serveStatic(req, res) {
  const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  const filePath = path.join(__dirname, pathname === '/' ? 'index.html' : pathname);
  if (!filePath.startsWith(__dirname + path.sep) || !fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    res.writeHead(404).end('not found');
    return;
  }
  res.writeHead(200, {
    'Content-Type': TYPES[path.extname(filePath)] || 'application/octet-stream',
    'Cache-Control': 'no-store',
  });
  fs.createReadStream(filePath).pipe(res);
}

const server = http.createServer(async (req, res) => {
  const { pathname, searchParams } = new URL(req.url, 'http://localhost');
  if (pathname === '/__relay') {
    if (!DEV_RELAY) {
      res.writeHead(404).end('dev relay disabled');
      return;
    }
    try {
      const target = searchParams.get('url') || '';
      const headers = JSON.parse(Buffer.from(searchParams.get('headers') || '', 'base64url').toString('utf8'));
      const body = await relay(target, headers);
      console.log(`[relay] ${target} -> ${body.status} (${body.elapsedMs} ms)`);
      res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify(body));
    } catch (error) {
      console.log(`[relay] failed: ${error.message}`);
      res.writeHead(502, { 'Content-Type': 'application/json' }).end(JSON.stringify({ error: error.message }));
    }
    return;
  }
  serveStatic(req, res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`spike page on http://0.0.0.0:${PORT} (dev relay ${DEV_RELAY ? 'ON' : 'off'})`);
});
