// Prompt XXI — the API source-fetching layer: defects found in the audit, each with its regression test. Upstream services are mocks; no
// network is used.
//
//   D8  a transfer that ends before the declared Content-Length was accepted as a complete (smaller) file
//   D9  an upstream 401/403 was reported by /api/fetch as 502, so an authorisation failure looked like an unavailable service
//   D7  the Luarmor owner check: metadata only, through Luarmor's documented API with the owner's key — never a script's contents
import test from 'node:test';
import assert from 'node:assert/strict';
import { safeGet, FetchRefused } from '../api/_lib/safe-fetch.js';
import { providerRequest, ProviderError, PROVIDERS, configuredProviders } from '../api/_lib/providers.js';
import { createHandler as createFetch } from '../api/fetch.js';
import { createHandler as createRetrieve } from '../api/retrieve.js';

const resp = (body, { status = 200, type = 'text/plain', headers = {}, declared } = {}) => {
  const bytes = typeof body === 'string' ? new TextEncoder().encode(body) : body;
  return { status, ok: status >= 200 && status < 300, headers: new Map(Object.entries({ 'content-type': type, 'content-length': String(declared ?? bytes.length), ...headers })), body: new ReadableStream({ start(c) { if (bytes.length) c.enqueue(bytes); c.close(); } }) };
};
function call(handler, { method = 'GET', body, query, headers = {} } = {}) {
  return new Promise((resolve) => {
    const res = { statusCode: 200, headers: {}, setHeader(k, v) { this.headers[k.toLowerCase()] = v; }, end(d) { resolve({ status: this.statusCode, headers: this.headers, body: d ? Buffer.from(d) : Buffer.alloc(0) }); } };
    handler({ method, body, query, url: query ? `/api/x?${new URLSearchParams(query)}` : '/api/x', headers: { 'sec-fetch-site': 'same-origin', ...headers } }, res);
  });
}

// ---- D8 ---------------------------------------------------------------------------------------------------------------------------------

test('D8 safeGet: a body shorter than its declared length is rejected as cut off, not returned as a smaller file', async () => {
  const fetchImpl = async () => resp('local x = 1\nprint(x', { declared: 500 });
  await assert.rejects(safeGet(new URL('https://raw.githubusercontent.com/a/b/main/x.lua'), { fetchImpl }), (e) => e instanceof FetchRefused && /ended early: 19 of 500 bytes/.test(e.message) && e.status === 502);
});

test('D8 safeGet: a content-encoded body is not compared with its (compressed) declared length', async () => {
  const fetchImpl = async () => resp('local x = 1\nprint(x)\n', { declared: 12, headers: { 'content-encoding': 'gzip' } });
  const r = await safeGet(new URL('https://raw.githubusercontent.com/a/b/main/x.lua'), { fetchImpl });
  assert.equal(new TextDecoder().decode(r.bytes), 'local x = 1\nprint(x)\n');
});

test('D8 providerRequest: a short transfer is a transient failure (retried once), then reported — never returned', async () => {
  let n = 0;
  const fetchImpl = async () => { n++; return resp('partial', { declared: 9000 }); };
  await assert.rejects(providerRequest('https://api.github.com/x', { fetchImpl, hosts: ['api.github.com'], sleep: async () => {} }), (e) => e instanceof ProviderError && /ended early/.test(e.message));
  assert.equal(n, 2, 'one retry');
});

test('D8 end to end: /api/fetch answers 502 for a cut-off transfer', async () => {
  const h = createFetch({ fetchImpl: async () => resp('print(1', { declared: 100 }), env: {} });
  const r = await call(h, { query: { url: 'https://pastebin.com/raw/Abcdef12' } });
  assert.equal(r.status, 502);
  assert.match(JSON.parse(r.body).error, /ended early/);
});

// ---- D9 ---------------------------------------------------------------------------------------------------------------------------------

test('D9 /api/fetch: an upstream 401/403 stays an authorisation answer (403), a 404 stays 404, a 500 is 502', async () => {
  for (const [up, want, re] of [[403, 403, /refused access \(HTTP 403\)/], [401, 403, /refused access \(HTTP 401\)/], [404, 404, /answered 404/], [500, 502, /answered 500/]]) {
    const h = createFetch({ fetchImpl: async () => resp('{"error":"x"}', { status: up, type: 'application/json' }), env: {} });
    const r = await call(h, { query: { url: 'https://pastebin.com/raw/Private1' } });
    assert.equal(r.status, want, `upstream ${up}`);
    assert.match(JSON.parse(r.body).error, re);
  }
});

// ---- D7: Luarmor owner check --------------------------------------------------------------------------------------------------------------

const KEY = 'LUARMOR-OWNER-KEY-SECRET-0123456789';
const ID = '0123456789abcdef0123456789abcdef';
const DETAILS = { success: true, message: 'ok', email: 'owner@example.invalid', discord_id: '1234567890', plan: 'premium', expires_at: 0,
  projects: [{ id: 'p1', name: 'My hub', scripts: [{ script_name: 'Main', script_id: ID, script_version: '1.4', ffa: false, silent: false }, { script_name: 'Other', script_id: 'f'.repeat(32) }] }] };

function luarmorUpstream(answer, seen = []) {
  return async (url, init) => { seen.push({ url, init }); return typeof answer === 'function' ? answer(url) : answer; };
}
const retrieveWith = (fetchImpl, extra = {}) => createRetrieve({ fetchImpl, env: { QS_RETRIEVE_MODE: 'open', QS_LUARMOR_API_KEY: KEY, ...extra }, sleep: async () => {} });

test('Luarmor owner check: configured only with the owner key; the answer is metadata, never code, and carries no personal data or key', async () => {
  assert.ok(configuredProviders({ QS_LUARMOR_API_KEY: 'k' }).includes('luarmor'));
  assert.equal(PROVIDERS.luarmor.kind, 'metadata');
  const seen = [];
  const r = await call(retrieveWith(luarmorUpstream(resp(JSON.stringify(DETAILS), { type: 'application/json' }), seen)), { method: 'POST', body: { provider: 'luarmor', loaderId: ID.toUpperCase() } });
  assert.equal(r.status, 200);
  const j = JSON.parse(r.body);
  assert.deepEqual({ owned: j.owned, projectName: j.projectName, scriptName: j.scriptName, scriptVersion: j.scriptVersion, scriptsSeen: j.scriptsSeen }, { owned: true, projectName: 'My hub', scriptName: 'Main', scriptVersion: '1.4', scriptsSeen: 2 });
  assert.match(j.contents, /not available/);
  const all = r.body.toString() + JSON.stringify(r.headers);
  for (const secret of [KEY, 'owner@example.invalid', '1234567890', 'premium']) assert.ok(!all.includes(secret), `${secret.slice(0, 8)}… must not be returned`);
  // the only request is the documented details endpoint on api.luarmor.net; nothing under /files/ (the loader route) is ever requested
  assert.equal(seen.length, 1);
  assert.equal(new URL(seen[0].url).hostname, 'api.luarmor.net');
  assert.match(new URL(seen[0].url).pathname, /^\/v3\/keys\/[^/]+\/details$/);
  assert.ok(!seen.some((s) => /\/files\//.test(s.url)));
});

test('Luarmor owner check: a script that is not among the key’s scripts is reported as not owned', async () => {
  const r = await call(retrieveWith(luarmorUpstream(resp(JSON.stringify(DETAILS), { type: 'application/json' }))), { method: 'POST', body: { provider: 'luarmor', loaderId: 'a'.repeat(32) } });
  const j = JSON.parse(r.body);
  assert.equal(j.owned, false);
  assert.equal(j.scriptName, undefined);
});

test('Luarmor owner check: the documented refusals are named (403 IP whitelist, 400 invalid key, success:false), the key never echoed', async () => {
  for (const [answer, re] of [
    [resp('{"success":false,"message":"IP not whitelisted"}', { status: 403, type: 'application/json' }), /whitelisted/],
    [resp('{"success":false,"message":"Invalid API key"}', { status: 400, type: 'application/json' }), /not valid \(HTTP 400\)/],
    [resp('{"success":false,"message":"Invalid API key"}', { type: 'application/json' }), /Invalid API key/],
    [resp('<html>nope</html>', { type: 'text/html' }), /did not answer with JSON/],
  ]) {
    const r = await call(retrieveWith(luarmorUpstream(answer)), { method: 'POST', body: { provider: 'luarmor', loaderId: ID } });
    assert.equal(r.status, 502);
    const j = JSON.parse(r.body);
    assert.match(j.error.message, re);
    assert.ok(!r.body.toString().includes(KEY));
  }
});

test('Luarmor owner check: input is validated before any request; without the key the provider is not configured', async () => {
  const seen = [];
  const bad = await call(retrieveWith(luarmorUpstream(resp('{}'), seen)), { method: 'POST', body: { provider: 'luarmor', loaderId: '../../v3/projects' } });
  assert.equal(bad.status, 400);
  assert.equal(seen.length, 0);
  const off = await call(createRetrieve({ fetchImpl: luarmorUpstream(resp('{}'), seen), env: { QS_RETRIEVE_MODE: 'open' } }), { method: 'POST', body: { provider: 'luarmor', loaderId: ID } });
  assert.equal(off.status, 501);
  assert.equal(seen.length, 0);
});
