// POST /api/research   server-side research extraction: fetch one public document and extract grounded findings from it.
//
// Off unless an operator configures it. It spends the operator's API budget and reads URLs on the operator's behalf, so:
//
//   * QS_RESEARCH_TOKEN must be set, and the caller must send it in the `x-research-token` header (constant-time compare). Unset: 501, nothing runs.
//   * ANTHROPIC_API_KEY must be set for the model step. Unset: the rule-based extraction still runs (`"model": null`) and says why.
//   * only hosts on the research list are fetched (api/_lib/research-fetch.js; QS_RESEARCH_HOSTS adds to it), https only, size and time capped;
//   * per-instance rate limit (QS_RESEARCH_RPM, default 6 a minute). Serverless instances do not share memory, so this is a brake, not a quota;
//     set a spend limit on the API key as the real one.
//   * no CORS headers are sent: the endpoint is for the operator's own tools, not for pages on other origins.
//
// Body: { "url": "https://..." , "subject": "Luraph" }  or  { "text": "...", "url": "https://example/where-it-came-from", "subject": "..." }
// Setup, variables and the response shape: docs/COMPAT-RESEARCH.md.

import crypto from 'node:crypto';
import { fetchText, ResearchFetchError } from './_lib/research-fetch.js';
import { classifySource, extractFindings, injectionScan, digest } from './_lib/research-extract.js';
import { extractWithModel, ResearchAIError, configFromEnv } from './_lib/research-ai.js';

const json = (res, status, body, headers = {}) => {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
  res.end(JSON.stringify(body));
};

const same = (a, b) => {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
};

async function readBody(req, limit = 400_000) {
  if (req.body && typeof req.body === 'object') return req.body;
  const chunks = [];
  let n = 0;
  for await (const c of req) { n += c.length; if (n > limit) throw new ResearchFetchError('The request body is too large.', 'too_large', 413); chunks.push(c); }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch { throw new ResearchFetchError('The body is not valid JSON.', 'bad_request', 400); }
}

export function createHandler({ env = process.env, fetchImpl = fetch, aiConfig = null, now = () => Date.now() } = {}) {
  const hits = [];
  return async function handler(req, res) {
    if (req.method !== 'POST') return json(res, 405, { ok: false, error: { code: 'method', message: 'POST only' } }, { Allow: 'POST' });
    if (!env.QS_RESEARCH_TOKEN) return json(res, 501, { ok: false, error: { code: 'not_configured', message: 'The research endpoint is switched off. Set QS_RESEARCH_TOKEN (see docs/COMPAT-RESEARCH.md).' } });
    if (!same(req.headers['x-research-token'] || '', env.QS_RESEARCH_TOKEN)) return json(res, 401, { ok: false, error: { code: 'unauthorized', message: 'Missing or wrong x-research-token.' } });

    const limit = Number(env.QS_RESEARCH_RPM) || 6;
    const t = now();
    while (hits.length && t - hits[0] > 60_000) hits.shift();
    if (hits.length >= limit) return json(res, 429, { ok: false, error: { code: 'rate_limited', message: `More than ${limit} requests a minute.` } }, { 'Retry-After': '30' });
    hits.push(t);

    try {
      const body = await readBody(req);
      const subject = typeof body.subject === 'string' ? body.subject.slice(0, 80) : null;
      let doc;
      if (typeof body.text === 'string') {
        if (body.text.length > 300_000) throw new ResearchFetchError('The text is too large.', 'too_large', 413);
        doc = { url: typeof body.url === 'string' ? body.url : 'urn:supplied-text', text: body.text, sha256: crypto.createHash('sha256').update(body.text).digest('hex'), supplied: true };
      } else if (typeof body.url === 'string') {
        const got = await fetchText(body.url, { fetchImpl });
        doc = { url: got.url, text: got.text, sha256: crypto.createHash('sha256').update(got.text).digest('hex'), bytes: got.bytes, truncated: got.truncated, contentType: got.contentType };
      } else throw new ResearchFetchError('Send "url" or "text".', 'bad_request', 400);

      const source = doc.supplied && !/^https:/.test(doc.url) ? null : classifySource(doc.url, subject);
      const rules = extractFindings(doc.text);
      const out = { ok: true, source: { url: doc.url, sha256: doc.sha256, bytes: doc.bytes ?? doc.text.length, truncated: !!doc.truncated, credibility: source }, rules: { findings: rules, injection: injectionScan(doc.text), digest: digest(doc.text, rules) }, model: null };

      const cfg = aiConfig || configFromEnv(env);
      if (!cfg.apiKey && !cfg.client) { out.model = { skipped: 'no_credentials', message: 'ANTHROPIC_API_KEY is not set, so only the rule-based extraction ran.' }; return json(res, 200, out); }
      try {
        out.model = await extractWithModel({ text: doc.text, url: doc.url, subject, retrievedAt: new Date(now()).toISOString(), sourceClass: source && source.class }, cfg);
      } catch (e) {
        if (!(e instanceof ResearchAIError)) throw e;
        // the rules' answer is still valid; the model step failed for a stated reason
        out.model = { failed: e.code, message: e.message, retryAfterSeconds: e.retryAfterSeconds ?? null };
        return json(res, 200, out, e.code === 'rate_limited' && e.retryAfterSeconds ? { 'Retry-After': String(e.retryAfterSeconds) } : {});
      }
      return json(res, 200, out);
    } catch (e) {
      if (e instanceof ResearchFetchError) return json(res, e.status, { ok: false, error: { code: e.code, message: e.message } });
      return json(res, 500, { ok: false, error: { code: 'internal', message: 'Unexpected error.' } });
    }
  };
}

export default createHandler();
