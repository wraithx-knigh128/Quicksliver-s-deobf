// GET /api/fetch?url=<link>   fetches a raw text file for the page (the browser cannot: other sites do not allow it).
//
// Only the sites in _lib/safe-fetch.js are reachable and the answer is the file itself, never interpreted. The page
// puts it in the editor; nothing is stored here.

import { normalizeUrl, safeGet, FetchRefused } from './_lib/safe-fetch.js';

const json = (res, status, body) => {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(body));
};

export function createHandler({ fetchImpl = fetch } = {}) {
  return async function handler(req, res) {
    if (req.method && req.method !== 'GET') { json(res, 405, { error: 'GET only' }); return; }
    const site = req.headers && req.headers['sec-fetch-site'];
    if (site && !['same-origin', 'none'].includes(site)) { json(res, 403, { error: 'This endpoint is for the QuickSilver page only.' }); return; }
    try {
      const raw = (req.query && req.query.url) || new URL(req.url, 'http://x').searchParams.get('url') || '';
      if (raw.length > 2000) throw new FetchRefused('That link is too long.');
      const url = normalizeUrl(raw);
      const { bytes, type } = await safeGet(url, { fetchImpl });
      if (/text\/html/i.test(type)) throw new FetchRefused('That link is a web page, not a raw file. Open the page and copy the "Raw" link.', 415);
      const name = decodeURIComponent(url.pathname.split('/').filter(Boolean).pop() || 'download.lua').replace(/[^\w.\-]+/g, '_').slice(0, 80);
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
