'use strict';

// Shared HTTP handler for POST /api/resolve. Works with a plain Node
// http server and with a Vercel Node serverless function, since both pass
// Node-style (req, res) objects.

const { validateUrl, resolveChain, RateLimiter } = require('./resolver.js');

const MAX_REQUEST_BYTES = 4_096;

function sendJson(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'X-Content-Type-Options': 'nosniff',
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

// First hop of X-Forwarded-For when present (set by the platform in front of
// us), otherwise the socket address. Used only as a rate-limit key.
function getClientIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (xff) return String(xff).split(',')[0].trim();
  return (req.socket && req.socket.remoteAddress) || 'unknown';
}

// Read and JSON-parse the request body with a hard size cap. Honors a body that
// the platform already parsed onto req.body.
function readJsonBody(req) {
  return new Promise((resolve) => {
    if (req.body && typeof req.body === 'object') {
      resolve({ ok: true, value: req.body });
      return;
    }
    let raw = '';
    let tooBig = false;
    req.on('data', (c) => {
      raw += c;
      if (raw.length > MAX_REQUEST_BYTES) { tooBig = true; req.destroy(); }
    });
    req.on('end', () => {
      if (tooBig) return resolve({ ok: false, reason: 'Request body too large.' });
      if (!raw) return resolve({ ok: true, value: {} });
      try { resolve({ ok: true, value: JSON.parse(raw) }); }
      catch { resolve({ ok: false, reason: 'Invalid JSON body.' }); }
    });
    req.on('error', () => resolve({ ok: false, reason: 'Could not read request body.' }));
  });
}

// Build a handler bound to a rate limiter and resolve options.
function createResolveHandler({ rateLimiter, resolveOptions = {} } = {}) {
  const limiter = rateLimiter || new RateLimiter();

  return async function handleResolve(req, res) {
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST');
      return sendJson(res, 405, { error: 'Method not allowed. Use POST.' });
    }

    const ip = getClientIp(req);
    const rl = limiter.check(ip);
    if (!rl.allowed) {
      res.setHeader('Retry-After', String(rl.retryAfterSec || 60));
      return sendJson(res, 429, { error: 'Rate limit exceeded. Try again shortly.' });
    }

    const parsed = await readJsonBody(req);
    if (!parsed.ok) return sendJson(res, 400, { error: parsed.reason });

    const target = parsed.value && parsed.value.url;
    if (typeof target !== 'string' || !target.trim()) {
      return sendJson(res, 400, { error: 'Provide a "url" string.' });
    }

    const v = validateUrl(target.trim());
    if (!v.ok) return sendJson(res, 400, { error: v.reason });

    try {
      const result = await resolveChain(v.url.toString(), resolveOptions);
      return sendJson(res, 200, result);
    } catch (e) {
      return sendJson(res, 500, { error: 'Internal error while resolving.' });
    }
  };
}

module.exports = { createResolveHandler, sendJson, getClientIp, readJsonBody, MAX_REQUEST_BYTES };
