// POST /api/assistant   the research assistant over a case file (see api/_lib/assistant-ai.js).  GET ?check=1 says whether it is configured.
//
// Off unless an operator turns it on: it spends their API budget on behalf of visitors.
//   QS_ASSISTANT_MODE    off (default) | open | token
//   QS_ASSISTANT_TOKEN   required in `x-assistant-token` when the mode is `token`
//   ANTHROPIC_API_KEY    the credential; QS_RESEARCH_MODEL / QS_RESEARCH_EFFORT choose model and effort, as for /api/research
//   QS_ASSISTANT_RPM     requests per minute per instance (default 4)
// The body is { "case": { ... } } built by the page; the script itself is never sent. No CORS headers. Setup: docs/RECONSTRUCT.md.

import crypto from 'node:crypto';
import { askAssistant } from './_lib/assistant-ai.js';
import { ResearchAIError, configFromEnv } from './_lib/research-ai.js';

const json = (res, status, body, headers = {}) => {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
  res.end(JSON.stringify(body));
};
const same = (a, b) => { const x = Buffer.from(String(a)); const y = Buffer.from(String(b)); return x.length === y.length && crypto.timingSafeEqual(x, y); };

async function readBody(req, limit = 200_000) {
  if (req.body && typeof req.body === 'object') return req.body;
  const chunks = [];
  let n = 0;
  for await (const c of req) { n += c.length; if (n > limit) throw new ResearchAIError('The request body is too large.', 'too_large', 413); chunks.push(c); }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch { throw new ResearchAIError('The body is not valid JSON.', 'bad_request', 400); }
}

export function createHandler({ env = process.env, aiConfig = null, now = () => Date.now() } = {}) {
  const hits = [];
  return async function handler(req, res) {
    const mode = env.QS_ASSISTANT_MODE || 'off';
    const cfg = aiConfig || configFromEnv(env);
    const configured = mode !== 'off' && !!(cfg.apiKey || cfg.client);
    if (req.method === 'GET') {
      return json(res, 200, { ok: true, configured, mode, model: configured ? cfg.model : null, reason: configured ? null : mode === 'off' ? 'The assistant is switched off on this deployment (QS_ASSISTANT_MODE).' : 'ANTHROPIC_API_KEY is not set.' });
    }
    if (req.method !== 'POST') return json(res, 405, { ok: false, error: { code: 'method', message: 'POST a case file, or GET ?check=1.' } }, { Allow: 'GET, POST' });
    if (mode === 'off') return json(res, 501, { ok: false, error: { code: 'not_configured', message: 'The research assistant is switched off on this deployment (set QS_ASSISTANT_MODE; see docs/RECONSTRUCT.md).' } });
    if (mode === 'token' && !same(req.headers['x-assistant-token'] || '', env.QS_ASSISTANT_TOKEN || '\0')) return json(res, 401, { ok: false, error: { code: 'unauthorized', message: 'Missing or wrong x-assistant-token.' } });
    const limit = Number(env.QS_ASSISTANT_RPM) || 4;
    const t = now();
    while (hits.length && t - hits[0] > 60_000) hits.shift();
    if (hits.length >= limit) return json(res, 429, { ok: false, error: { code: 'rate_limited', message: `More than ${limit} requests a minute.` } }, { 'Retry-After': '30' });
    hits.push(t);
    try {
      const body = await readBody(req);
      if (!body.case || typeof body.case !== 'object') throw new ResearchAIError('Send { "case": { ... } }.', 'bad_request', 400);
      if (JSON.stringify(body.case).length > 120_000) throw new ResearchAIError('The case file is too large.', 'too_large', 413);
      const out = await askAssistant(body.case, cfg);
      return json(res, 200, { ok: true, ...out });
    } catch (e) {
      if (e instanceof ResearchAIError) return json(res, e.status, { ok: false, error: { code: e.code, message: e.message, retryAfterSeconds: e.retryAfterSeconds ?? null } }, e.code === 'rate_limited' && e.retryAfterSeconds ? { 'Retry-After': String(e.retryAfterSeconds) } : {});
      return json(res, 500, { ok: false, error: { code: 'internal', message: 'Unexpected error.' } });
    }
  };
}

export default createHandler();
