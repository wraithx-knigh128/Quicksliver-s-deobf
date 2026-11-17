// GET /api/fetch?url=<link>   fetches a raw text file for the page (the browser cannot: other sites do not allow it).
//
// Only the sites in _lib/safe-fetch.js are reachable and the answer is the file itself, never interpreted. The page
// puts it in the editor; nothing is stored here.
//
// Owner credentials (optional, off by default): GET /api/fetch?url=<link>&auth=1 with header `x-fetch-token: <QS_FETCH_AUTH_TOKEN>` attaches a
// credential the operator configured in QS_FETCH_AUTH (see _lib/safe-fetch.js authConfig) to URLs under the configured host and path prefix, e.g.
// the operator's own private repository. Without the token, or for any other URL, the request is the anonymous one. Secrets stay in the server's
// environment; nothing about them is returned. This is the route for "the payload needs a key you own": the key is the owner's, set by the owner.

import crypto from 'node:crypto';
import { normalizeUrl, safeGet, FetchRefused, authConfig } from './_lib/safe-fetch.js';

const same = (a, b) => { const x = Buffer.from(String(a)); const y = Buffer.from(String(b)); return x.length === y.length && crypto.timingSafeEqual(x, y); };

const json = (res, status, body) => {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(body));
};

export function createHandler({ fetchImpl = fetch, env = process.env } = {}) {
  return async function handler(req, res) {
    if (req.method && req.method !== 'GET') { json(res, 405, { error: 'GET only' }); return; }
    const site = req.headers && req.headers['sec-fetch-site'];
    if (site && !['same-origin', 'none'].includes(site)) { json(res, 403, { error: 'This endpoint is for the QuickSilver page only.' }); return; }
    try {
      const raw = (req.query && req.query.url) || new URL(req.url, 'http://x').searchParams.get('url') || '';
      if (raw.length > 2000) throw new FetchRefused('That link is too long.');
      const url = normalizeUrl(raw);
      const wantsAuth = ((req.query && req.query.auth) || new URL(req.url || '/', 'http://x').searchParams.get('auth')) === '1';
      let credentialFor = null;
      if (wantsAuth) {
        const cfg = authConfig(env);
        if (!cfg || !env.QS_FETCH_AUTH_TOKEN) throw new FetchRefused('Authenticated fetching is not set up on this deployment (QS_FETCH_AUTH and QS_FETCH_AUTH_TOKEN).', 501);
        if (!same((req.headers && req.headers['x-fetch-token']) || '', env.QS_FETCH_AUTH_TOKEN)) throw new FetchRefused('Missing or wrong x-fetch-token.', 401);
        if (!cfg.credentialFor(url)) throw new FetchRefused('No owner credential is configured for that address.', 403);
        credentialFor = cfg.credentialFor;
      }
      const { bytes, type } = await safeGet(url, { fetchImpl, credentialFor });
      if (/text\/html/i.test(type)) throw new FetchRefused('That link is a web page, not a raw file. Open the page and copy the "Raw" link.', 415);
      if (!bytes.length) throw new FetchRefused('The link returned an empty file.', 422);
      const last = url.pathname.split('/').filter(Boolean).pop() || 'download.lua';
      let decoded;
      try { decoded = decodeURIComponent(last); } catch { decoded = last; }   // a malformed %-escape is a name, not an error
      const name = decoded.replace(/[^\w.\-]+/g, '_').slice(0, 80);
      res.statusCode = 200;
      res.setHeader('Content-Type', 'application/octet-stream');
      res.setHeader('Content-Length', String(bytes.length));
      res.setHeader('X-QS-Name', /\.(lua|luau|txt)$/i.test(name) ? name : `${name}.lua`);
      res.setHeader('Cache-Control', 'no-store');
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.end(Buffer.from(bytes));
    } catch (e) {
      if (e instanceof FetchRefused) { json(res, e.status, { error: e.message }); return; }
      json(res, 500, { error: 'Unexpected error.' });
    }
  };
}

export default createHandler();
