// /api/retrieve — owner-authorised retrieval through documented service APIs (api/_lib/providers.js).
//
//   GET  /api/retrieve?check=1                     → { mode, providers: [names] }   (never any credential)
//   POST /api/retrieve { provider, ...target }     → the item's bytes (application/octet-stream), X-QS-Provider / X-QS-Name headers
//
// Off unless the operator turns it on, because it spends the operator's own credentials:
//   QS_RETRIEVE_MODE   off (default) | token | open
//                      token: the caller must send `x-retrieve-token: <QS_RETRIEVE_TOKEN>` (for the operator's own tools);
//                      open:  any visitor of the page may use the configured providers — only for a private deployment, since the
//                             credentials are the operator's.
//   QS_RETRIEVE_RPM    requests per minute per instance (default 10)
// Provider credentials: see api/_lib/providers.js. Nothing is stored; errors name the failing step, never a credential.

import crypto from 'node:crypto';
import { PROVIDERS, ProviderError, configuredProviders } from './_lib/providers.js';

const json = (res, status, body, headers = {}) => {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
  res.end(JSON.stringify(body));
};
const same = (a, b) => { const x = Buffer.from(String(a)); const y = Buffer.from(String(b)); return x.length === y.length && crypto.timingSafeEqual(x, y); };

async function readBody(req, limit = 4000) {
  if (req.body && typeof req.body === 'object') return req.body;
  const chunks = [];
  let n = 0;
  for await (const c of req) { n += c.length; if (n > limit) throw new ProviderError('bad_request', 'The request body is too large.', 413); chunks.push(c); }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch { throw new ProviderError('bad_request', 'The body is not valid JSON.', 400); }
}

export function createHandler({ env = process.env, fetchImpl = fetch, now = () => Date.now(), sleep } = {}) {
  const hits = [];
  return async function handler(req, res) {
    const mode = env.QS_RETRIEVE_MODE || 'off';
    const providers = mode === 'off' ? [] : configuredProviders(env);
    if (req.method === 'GET') return json(res, 200, { ok: true, mode, providers });
    if (req.method !== 'POST') return json(res, 405, { ok: false, error: { code: 'method', message: 'POST a retrieval, or GET ?check=1.' } }, { Allow: 'GET, POST' });
    const site = req.headers && req.headers['sec-fetch-site'];
    if (site && !['same-origin', 'none'].includes(site)) return json(res, 403, { ok: false, error: { code: 'forbidden', message: 'This endpoint is for the QuickSilver page and the operator’s tools only.' } });
    if (mode === 'off') return json(res, 501, { ok: false, error: { code: 'not_configured', message: 'Owner retrieval is switched off on this deployment (QS_RETRIEVE_MODE).' } });
    if (mode === 'token' && !same((req.headers && req.headers['x-retrieve-token']) || '', env.QS_RETRIEVE_TOKEN || '\0')) return json(res, 401, { ok: false, error: { code: 'unauthorized', message: 'Missing or wrong x-retrieve-token.' } });
    const limit = Number(env.QS_RETRIEVE_RPM) || 10;
    const t = now();
    while (hits.length && t - hits[0] > 60_000) hits.shift();
    if (hits.length >= limit) return json(res, 429, { ok: false, error: { code: 'rate_limited', message: `More than ${limit} retrievals a minute.` } }, { 'Retry-After': '30' });
    hits.push(t);
    try {
      const body = await readBody(req);
      const p = PROVIDERS[body.provider];
      if (!p) throw new ProviderError('bad_request', 'Unknown provider.', 400);
      if (!providers.includes(body.provider)) throw new ProviderError('not_configured', 'That provider has no credential on this deployment.', 501);
      p.validate(body, env);
      const out = await p.retrieve(body, env, { fetchImpl, sleep });
      res.statusCode = 200;
      res.setHeader('Content-Type', 'application/octet-stream');
      res.setHeader('Content-Length', String(out.bytes.length));
      res.setHeader('Cache-Control', 'no-store');
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('X-QS-Provider', body.provider);
      res.setHeader('X-QS-Name', String(out.name || 'item').replace(/[^\w.-]+/g, '_').slice(0, 80));
      res.setHeader('X-QS-Upstream-Type', String(out.contentType || '').slice(0, 80));
      res.end(Buffer.from(out.bytes));
    } catch (e) {
      if (e instanceof ProviderError) return json(res, e.status || 502, { ok: false, error: { code: e.code, message: e.message } });
      return json(res, 500, { ok: false, error: { code: 'internal', message: 'Unexpected error.' } });
    }
  };
}

export default createHandler();
