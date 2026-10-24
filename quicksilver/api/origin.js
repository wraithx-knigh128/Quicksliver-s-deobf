// POST /api/origin   { fingerprints: [{ query: "..." }, ...] }
//
// Searches public code for a handful of short lines of the user's script and answers with the files that contain them:
// repository, path, link, which fingerprints they matched, and the hashes of their lines (so the page can measure overlap
// locally). The script itself is never sent; the page sends at most eight lines of at most 140 characters each.
//
// Configuration (Vercel environment variables):
//   QS_ORIGIN_GITHUB_TOKEN   a GitHub token (no scopes needed) with which to use code search; without it the endpoint says it is not configured
//   QS_ORIGIN_DISABLED=1     switch the endpoint off

import { searchGitHub, hashesOf } from './_lib/search.js';

const json = (res, status, body) => {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(body));
};

const WINDOW_MS = 60 * 60 * 1000;
const MAX_PER_WINDOW = 12;

/** Best-effort per-instance rate limit (serverless instances do not share memory, so this only slows down a single hot instance). */
function makeLimiter() {
  const hits = new Map();           // ip -> [timestamps]
  return (ip, now) => {
    const list = (hits.get(ip) || []).filter((t) => now - t < WINDOW_MS);
    if (list.length >= MAX_PER_WINDOW) { hits.set(ip, list); return true; }
    list.push(now);
    hits.set(ip, list);
    return false;
  };
}

async function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  const chunks = [];
  let size = 0;
  for await (const c of req) { size += c.length; if (size > 20_000) throw new Error('too large'); chunks.push(c); }
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
}

export function createHandler({ fetchImpl = fetch, env = process.env, now = () => Date.now(), sleep } = {}) {
  const limited = makeLimiter();
  return async function handler(req, res) {
    if (req.method !== 'POST') { json(res, 405, { error: 'POST only' }); return; }
    const site = req.headers && req.headers['sec-fetch-site'];
    if (site && !['same-origin', 'none'].includes(site)) { json(res, 403, { error: 'This endpoint is for the QuickSilver page only.' }); return; }
    if (env.QS_ORIGIN_DISABLED === '1') { json(res, 200, { configured: false, note: 'The online search is switched off on this site.' }); return; }
    const token = env.QS_ORIGIN_GITHUB_TOKEN;
    if (!token) { json(res, 200, { configured: false, note: 'The online search is not set up on this site: the owner has to add a GitHub token (QS_ORIGIN_GITHUB_TOKEN).' }); return; }
    const ip = String((req.headers && (req.headers['x-forwarded-for'] || '')).split(',')[0].trim() || (req.socket && req.socket.remoteAddress) || 'unknown');
    if (limited(ip, now())) { json(res, 429, { error: 'Too many checks from this address; try again later.' }); return; }

    let body;
    try { body = await readBody(req); } catch { json(res, 400, { error: 'The request body is not valid JSON.' }); return; }
    const fps = Array.isArray(body.fingerprints) ? body.fingerprints : [];
    if (!fps.length || fps.length > 8) { json(res, 400, { error: 'Send between 1 and 8 fingerprint lines.' }); return; }
    const clean = [];
    for (const f of fps) {
      const q = f && typeof f.query === 'string' ? f.query.replace(/["\\]/g, ' ').replace(/\s+/g, ' ').trim() : '';
      if (q.length < 8 || q.length > 140) { json(res, 400, { error: 'Each fingerprint must be 8 to 140 characters.' }); return; }
      clean.push({ query: q });
    }

    try {
      const found = await searchGitHub(clean, { token, fetchImpl, sleep });
      const matches = [];
      for (const [i, m] of found.matches.entries()) {
        let lineHashes = null;
        if (i < 3) { try { lineHashes = await hashesOf(m, { fetchImpl }); } catch { lineHashes = null; } }
        matches.push({ repo: m.repo, path: m.path, url: m.url, hits: m.hits, lineHashes });
      }
      json(res, 200, { configured: true, provider: 'GitHub code search', queried: found.queried, matches, note: found.note });
    } catch {
      json(res, 502, { configured: true, error: 'The search failed.' });
    }
  };
}

export default createHandler();
