// /api/retrieve and its providers (api/_lib/providers.js): off by default, mode-gated, validated, scoped to fixed hosts, credentials never
// echoed, upstream failures named, one retry on transient errors. The upstream services are mocks; no network.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../api/retrieve.js';
import { providerRequest, ProviderError, PROVIDERS } from '../api/_lib/providers.js';

const SECRET = { QS_ROBLOX_API_KEY: 'RBX-SECRET-KEY-123', QS_GITHUB_TOKEN: 'ghp_SECRETSECRET', QS_GITHUB_REPOS: 'me/private-scripts', QS_PASTEBIN_DEV_KEY: 'PBDEVSECRET', QS_PASTEBIN_USER_KEY: 'PBUSERSECRET' };
const resp = (body, { status = 200, type = 'application/octet-stream', headers = {} } = {}) => {
  const bytes = typeof body === 'string' ? new TextEncoder().encode(body) : body;
  return { status, ok: status >= 200 && status < 300, headers: new Map(Object.entries({ 'content-type': type, 'content-length': String(bytes.length), ...headers })), body: new ReadableStream({ start(c) { c.enqueue(bytes); c.close(); } }) };
};
function call(handler, { method = 'POST', body, headers = {} } = {}) {
  return new Promise((resolve) => {
    const res = { statusCode: 200, headers: {}, setHeader(k, v) { this.headers[k.toLowerCase()] = v; }, end(d) { resolve({ status: this.statusCode, headers: this.headers, body: d ? Buffer.from(d) : Buffer.alloc(0) }); } };
    handler({ method, body, headers: { 'sec-fetch-site': 'same-origin', ...headers } }, res);
  });
}
const noSecret = (r) => { const all = JSON.stringify(r.headers) + r.body.toString('latin1'); for (const v of Object.values(SECRET)) assert.ok(!all.includes(v), `secret ${v.slice(0, 6)}… leaked`); };

test('off by default; check lists only configured provider names', async () => {
  const off = createHandler({ env: { ...SECRET } });
  const c = await call(off, { method: 'GET' });
  assert.deepEqual(JSON.parse(c.body), { ok: true, mode: 'off', providers: [] });
  assert.equal((await call(off, { body: { provider: 'github' } })).status, 501);
  const on = createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'token', QS_RETRIEVE_TOKEN: 'op' } });
  const k = await call(on, { method: 'GET' });
  assert.deepEqual(JSON.parse(k.body).providers.sort(), ['github', 'pastebin', 'roblox-asset']);
  noSecret(k);
  assert.equal((await call(on, { body: { provider: 'github' } })).status, 401, 'token mode needs the token');
  const partial = createHandler({ env: { QS_RETRIEVE_MODE: 'open', QS_ROBLOX_API_KEY: 'x' } });
  assert.deepEqual(JSON.parse((await call(partial, { method: 'GET' })).body).providers, ['roblox-asset']);
  assert.equal((await call(partial, { body: { provider: 'github', owner: 'a', repo: 'b', path: 'c' } })).status, 501, 'an unconfigured provider is refused');
});

test('roblox-asset: two documented steps, the key sent only to apis.roblox.com, the file only from the Roblox CDN', async () => {
  const seen = [];
  const fetchImpl = async (url, init) => {
    seen.push({ url, key: init.headers['x-api-key'] || null });
    if (url.startsWith('https://apis.roblox.com/asset-delivery-api/v1/assetId/123')) return resp(JSON.stringify({ location: 'https://c4.rbxcdn.com/abc' }), { type: 'application/json' });
    if (url === 'https://c4.rbxcdn.com/abc') return resp('<roblox><Item class="ModuleScript"><Properties><string name="Name">M</string><ProtectedString name="Source"><![CDATA[return 1]]></ProtectedString></Properties></Item></roblox>');
    return resp('no', { status: 404 });
  };
  const h = createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'open' }, fetchImpl });
  const r = await call(h, { body: { provider: 'roblox-asset', assetId: '123' } });
  assert.equal(r.status, 200);
  assert.match(r.body.toString(), /ModuleScript/);
  assert.equal(r.headers['x-qs-provider'], 'roblox-asset');
  assert.deepEqual(seen.map((s) => [new URL(s.url).hostname, !!s.key]), [['apis.roblox.com', true], ['c4.rbxcdn.com', false]], 'the API key goes to the API host only');
  noSecret(r);
  // a location outside Roblox's hosts is not followed
  const evil = createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'open' }, fetchImpl: async () => resp(JSON.stringify({ location: 'https://evil.example/x' }), { type: 'application/json' }) });
  const e = await call(evil, { body: { provider: 'roblox-asset', assetId: '123' } });
  assert.equal(JSON.parse(e.body).error.code, 'bad_upstream');
  assert.equal((await call(h, { body: { provider: 'roblox-asset', assetId: '12a' } })).status, 400);
});

test('github: only allow-listed repositories, raw media type, directories refused', async () => {
  let auth = null;
  const fetchImpl = async (url, init) => { auth = init.headers.Authorization; return url.includes('/contents/dir') ? resp('[{"name":"a"}]', { type: 'application/json' }) : resp('print("private")'); };
  const h = createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'open' }, fetchImpl });
  const ok = await call(h, { body: { provider: 'github', owner: 'me', repo: 'private-scripts', path: 'src/main.lua', ref: 'main' } });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.toString(), 'print("private")');
  assert.equal(auth, `Bearer ${SECRET.QS_GITHUB_TOKEN}`);
  noSecret(ok);
  assert.equal((await call(h, { body: { provider: 'github', owner: 'someone', repo: 'else', path: 'x.lua' } })).status, 403, 'a repository not on the list');
  assert.equal((await call(h, { body: { provider: 'github', owner: 'me', repo: 'private-scripts', path: '../x' } })).status, 400);
  assert.equal((await call(h, { body: { provider: 'github', owner: 'me', repo: 'private-scripts', path: 'dir' } })).status, 400);
});

test('pastebin: an error answered with HTTP 200 is an error; refused keys are named without being shown', async () => {
  const mk = (text) => createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'open' }, fetchImpl: async () => resp(text, { type: 'text/plain' }) });
  const ok = await call(mk('local x = 1'), { body: { provider: 'pastebin', key: 'AbCd1234' } });
  assert.equal(ok.status, 200);
  const bad = await call(mk('Bad API request, invalid api_user_key'), { body: { provider: 'pastebin', key: 'AbCd1234' } });
  assert.equal(JSON.parse(bad.body).error.code, 'upstream_auth');
  noSecret(bad);
  const missing = await call(mk('Bad API request, invalid permission to view this paste or invalid api_paste_key'), { body: { provider: 'pastebin', key: 'AbCd1234' } });
  assert.equal(JSON.parse(missing.body).error.code, 'upstream_error');
});

test('upstream failures are named; one retry on a transient error; size cap; rate limit', async () => {
  const codes = async (fetchImpl) => { const h = createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'open' }, fetchImpl, sleep: async () => {} }); const r = await call(h, { body: { provider: 'github', owner: 'me', repo: 'private-scripts', path: 'a.lua' } }); return [r.status, JSON.parse(r.body.toString() || '{}').error?.code]; };
  assert.deepEqual(await codes(async () => resp('x', { status: 401 })), [502, 'upstream_auth']);
  assert.deepEqual(await codes(async () => resp('x', { status: 404 })), [404, 'not_found']);
  assert.deepEqual(await codes(async () => { throw Object.assign(new Error('x'), { name: 'TypeError' }); }), [504, 'upstream_unavailable']);
  let n = 0;
  const flaky = async () => (n++ === 0 ? resp('x', { status: 503 }) : resp('print(1)'));
  const h = createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'open' }, fetchImpl: flaky, sleep: async () => {} });
  assert.equal((await call(h, { body: { provider: 'github', owner: 'me', repo: 'private-scripts', path: 'a.lua' } })).status, 200, 'one retry after a 503');
  await assert.rejects(providerRequest('https://api.github.com/x', { hosts: ['api.github.com'], fetchImpl: async () => resp('x', { headers: { 'content-length': String(50 * 1024 * 1024) } }) }), (e) => e instanceof ProviderError && e.code === 'too_large');
  const limited = createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'open', QS_RETRIEVE_RPM: '1' }, fetchImpl: async () => resp('print(1)') });
  await call(limited, { body: { provider: 'github', owner: 'me', repo: 'private-scripts', path: 'a.lua' } });
  assert.equal((await call(limited, { body: { provider: 'github', owner: 'me', repo: 'private-scripts', path: 'a.lua' } })).status, 429);
});

test('cross-site callers and unknown providers are refused', async () => {
  const h = createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'open' } });
  assert.equal((await call(h, { body: { provider: 'github' }, headers: { 'sec-fetch-site': 'cross-site' } })).status, 403);
  // Luarmor has no documented endpoint that returns a script. Since Prompt XXI a `luarmor` provider exists, but only as the owner's
  // metadata check: without the owner's key it is not configured, and with it a request for a script is refused as invalid
  assert.equal((await call(h, { body: { provider: 'luarmor', script: 'x' } })).status, 501, 'not configured without the owner key');
  const owner = createHandler({ env: { ...SECRET, QS_RETRIEVE_MODE: 'open', QS_LUARMOR_API_KEY: 'k' }, fetchImpl: async () => { throw new Error('must not be called'); } });
  assert.equal((await call(owner, { body: { provider: 'luarmor', script: 'x' } })).status, 400, 'a request for a script (no loader id) is refused before any request');
  assert.equal(PROVIDERS.luarmor.kind, 'metadata', 'the Luarmor provider never returns a script');
});
