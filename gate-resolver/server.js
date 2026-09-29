'use strict';

// Local dev server for Gate Resolver. Serves the static UI and mounts the same
// /api/resolve handler used by the Vercel serverless function. On Vercel these
// static files are served by the platform and api/resolve.js runs the handler,
// so this file is for local development only.

const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const { createResolveHandler } = require('./api/_lib/handler.js');
const { RateLimiter } = require('./api/_lib/resolver.js');

const PORT = Number(process.env.PORT) || 8080;
const HOST = process.env.HOST || '127.0.0.1';

const STATIC = {
  '/': { file: 'index.html', type: 'text/html; charset=utf-8' },
  '/index.html': { file: 'index.html', type: 'text/html; charset=utf-8' },
  '/app.js': { file: 'app.js', type: 'text/javascript; charset=utf-8' },
};

const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'Content-Security-Policy':
    "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'; base-uri 'none'; form-action 'self'",
  'Referrer-Policy': 'no-referrer',
};

const resolveHandler = createResolveHandler({
  rateLimiter: new RateLimiter({ windowMs: 60_000, max: 20 }),
  resolveOptions: { budgetMs: 30_000, maxHops: 10 },
});

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'GET' && STATIC[url.pathname]) {
    const entry = STATIC[url.pathname];
    fs.readFile(path.join(__dirname, entry.file), (err, data) => {
      if (err) { res.writeHead(404); res.end('Not found'); return; }
      res.writeHead(200, { 'Content-Type': entry.type, ...SECURITY_HEADERS });
      res.end(data);
    });
    return;
  }

  if (url.pathname === '/api/resolve') {
    resolveHandler(req, res);
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not found');
});

if (require.main === module) {
  server.listen(PORT, HOST, () => {
    console.log(`Gate Resolver listening on http://${HOST}:${PORT}`);
  });
}

module.exports = { server };
