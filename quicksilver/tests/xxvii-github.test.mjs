// Prompt XXVII Part II: GitHub loader workflow — link forms, input recognition, content checks, every failure class, SSRF limits, the
// user's token, and Premium enforcement on the server.
//
// GitHub itself is played by a fake (fakeGitHub below) that answers the way GitHub's REST API and raw host are documented to answer
// (404 for a private repository without a token, 403 + x-ratelimit-remaining: 0 for the rate limit, 451 for a legal block, a JSON array for
// a folder). One live test reads a public file through raw.githubusercontent.com; it runs only with QS_LIVE_GITHUB=1.

import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { parseGitHubRef, findGitHubRefs, recognizeInput, contentClass, diagnoseFailure, isGitHubLink, luaFilesOfTree, OUTCOMES } from '../src/loader/github.js';
import { createHandler, githubGet } from '../api/github.js';
import { checkEntitlement } from '../api/_lib/entitlement.js';

// ---- link forms ------------------------------------------------------------------------------------------------------------------------

test('github: every documented link form resolves to the same file, with the raw address it is read from', () => {
  const forms = [
    'https://raw.githubusercontent.com/alice/tools/main/src/loader.lua',
    'https://raw.githubusercontent.com/alice/tools/refs/heads/main/src/loader.lua',
    'https://github.com/alice/tools/blob/main/src/loader.lua',
    'https://www.github.com/alice/tools/raw/main/src/loader.lua',
    'https://github.com/alice/tools/raw/refs/heads/main/src/loader.lua',
    'https://api.github.com/repos/alice/tools/contents/src/loader.lua?ref=main',
    'github.com/alice/tools/blob/main/src/loader.lua',
  ];
  for (const f of forms) {
    const t = parseGitHubRef(f);
    assert.equal(t.kind, 'file', f);
    assert.deepEqual([t.owner, t.repo, t.ref, t.path], ['alice', 'tools', 'main', 'src/loader.lua'], f);
    assert.equal(t.urls.raw, 'https://raw.githubusercontent.com/alice/tools/main/src/loader.lua', f);
  }
  assert.equal(parseGitHubRef('https://github.com/alice/tools').kind, 'repo');
  assert.equal(parseGitHubRef('https://github.com/alice/tools.git').repo, 'tools');
  assert.deepEqual((({ kind, ref, path }) => ({ kind, ref, path }))(parseGitHubRef('https://github.com/alice/tools/tree/dev/scripts')), { kind: 'dir', ref: 'dev', path: 'scripts' });
  assert.equal(parseGitHubRef('https://github.com/alice').kind, 'profile');
  const g = parseGitHubRef('https://gist.githubusercontent.com/alice/0123456789abcdef0123/raw/abcdefabcdefabcdefab/script.lua');
  assert.deepEqual([g.kind, g.gist, g.file], ['gist', '0123456789abcdef0123', 'script.lua']);
  assert.equal(parseGitHubRef('https://gist.github.com/alice/0123456789abcdef0123').kind, 'gist');
  // a file path with spaces and unicode is encoded once, segment by segment
  assert.equal(parseGitHubRef('https://github.com/alice/tools/blob/main/my%20dir/ä.lua').urls.raw, 'https://raw.githubusercontent.com/alice/tools/main/my%20dir/%C3%A4.lua');
});

test('github: links that are not GitHub, or that try to reach elsewhere, are refused before any request (SSRF)', () => {
  const bad = [
    'http://169.254.169.254/latest/meta-data',            // cloud metadata
    'https://github.com.evil.example/alice/tools',        // look-alike host
    'https://raw.githubusercontent.com.evil.example/a/b/main/x.lua',
    'https://alice@github.com/alice/tools',               // credentials in the URL
    'https://github.com:8443/alice/tools',                // a port
    'https://raw.githubusercontent.com/alice/tools/main/%2e%2e/%2e%2e/etc/passwd',
    'https://raw.githubusercontent.com/alice/tools/main/a%2fb.lua',
    'https://github.com/settings/tokens',                 // a GitHub page, not a repository
    'https://github.com/alice/tools/issues/1',
    'https://api.github.com/user',
    'file:///etc/passwd',
    'javascript:alert(1)',
    'not a url',
    '',
  ];
  for (const b of bad) assert.throws(() => parseGitHubRef(b), (e) => e.code === 'invalid-url', b);
  assert.equal(isGitHubLink('https://github.com/alice/tools'), true);
  assert.equal(isGitHubLink('https://example.com/x.lua'), false);
});

test('github: input recognition picks the pipeline — a GitHub link, another link, a loader, bytecode or a script', () => {
  assert.equal(recognizeInput('https://github.com/alice/tools/blob/main/a.lua').kind, 'github-link');
  assert.equal(recognizeInput('  https://raw.githubusercontent.com/alice/tools/main/a.lua \n').kind, 'github-link');
  assert.equal(recognizeInput('https://pastebin.com/raw/abc123').kind, 'link');
  const loader = recognizeInput('loadstring(game:HttpGet("https://raw.githubusercontent.com/alice/tools/main/main.lua"))()');
  assert.equal(loader.kind, 'loader');
  assert.equal(loader.github.length, 1);
  assert.equal(loader.github[0].path, 'main.lua');
  assert.equal(recognizeInput('\x1bLuaQ\x00\x01').kind, 'bytecode');
  assert.equal(recognizeInput('local x = 1 print(x)').kind, 'script');
  assert.equal(recognizeInput('   ').kind, 'empty');
  const refs = findGitHubRefs('a = "https://github.com/alice/tools/blob/main/a.lua", b = "https://github.com/settings/x"');
  assert.equal(refs.length, 2);
  assert.ok(refs[0].path && refs[1].error);
});

test('github: a 200 is not a success until the body is Lua — web pages, JSON errors, binary data and plain text are refused', () => {
  const parses = () => true;
  assert.equal(contentClass('local a = 1\nreturn a', { parses }).lua, true);
  assert.equal(contentClass('\x1bLuaQ\x00rest').kind, 'bytecode');
  assert.equal(contentClass('<!DOCTYPE html><html><body>Sign in</body></html>').kind, 'html');
  assert.equal(contentClass('{"message":"Not Found","documentation_url":"https://docs.github.com"}').kind, 'json-error');
  assert.equal(contentClass('404: Not Found').kind, 'not-found-text');
  assert.equal(contentClass('').kind, 'empty');
  assert.equal(contentClass(new Uint8Array([0, 1, 2, 3, 0, 0, 7, 8, 1, 2])).kind, 'binary');
  assert.equal(contentClass('Hello there, this is a readme with no code.', { parses: () => false }).lua, false);
  assert.equal(contentClass('local function f() if x then return end', { parses: () => false }).kind, 'lua-invalid');
});

test('github: failure diagnosis tells apart private, deleted, missing file, missing branch, rate limit, legal block and a rejected token', () => {
  const H = (o) => o;
  assert.equal(diagnoseFailure({ raw: { status: 404 }, repo: { status: 404 }, owner: { status: 200 } }).outcome, 'private-or-missing');
  assert.equal(diagnoseFailure({ raw: { status: 404 }, repo: { status: 404 }, owner: { status: 200 } }, { token: true }).outcome, 'not-found-with-token');
  assert.equal(diagnoseFailure({ raw: { status: 404 }, repo: { status: 404 }, owner: { status: 404 } }).outcome, 'owner-not-found');
  assert.equal(diagnoseFailure({ raw: { status: 404 }, repo: { status: 200 }, contents: { status: 404 } }).outcome, 'file-missing');
  assert.equal(diagnoseFailure({ raw: { status: 404 }, repo: { status: 200 }, branch: { status: 404 } }).outcome, 'ref-missing');
  assert.equal(diagnoseFailure({ raw: { status: 404 }, repo: { status: 403, headers: H({ 'x-ratelimit-remaining': '0', 'x-ratelimit-reset': String(Math.floor(Date.now() / 1000) + 600) }) } }).outcome, 'rate-limited');
  assert.equal(diagnoseFailure({ raw: { status: 429, headers: H({ 'retry-after': '120' }) } }).retryAfter, 120);
  assert.equal(diagnoseFailure({ raw: { status: 451 } }).outcome, 'legal-block');
  assert.equal(diagnoseFailure({ raw: { status: 404 }, repo: { status: 401 } }).outcome, 'token-rejected');
  assert.equal(diagnoseFailure({ raw: { status: 404 } }).outcome, 'unavailable', 'without the API nothing more is claimed');
  for (const o of ['private-or-missing', 'file-missing', 'rate-limited', 'not-lua', 'retrieved-needs-reconstruction']) assert.ok(OUTCOMES[o].label);
});

// ---- the server function against a fake GitHub ----------------------------------------------------------------------------------------

const LUA = 'local Players = game:GetService("Players")\nprint(Players.LocalPlayer)\n';
function fakeGitHub({ repos = {}, users = ['alice'], rate = false, legal = false, seen = [] } = {}) {
  // repos: { 'alice/tools': { private: false, branches: { main: { 'a.lua': LUA } } } }
  return async (url, init = {}) => {
    const u = new URL(url);
    seen.push({ url, auth: init.headers && init.headers.Authorization ? 'yes' : 'no', host: u.hostname });
    const tokenOk = init.headers && init.headers.Authorization === 'Bearer ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const res = (status, body = '', headers = {}) => new Response(body, { status, headers });
    if (rate) return res(403, '{"message":"API rate limit exceeded"}', { 'x-ratelimit-remaining': '0', 'x-ratelimit-reset': String(Math.floor(Date.now() / 1000) + 300) });
    if (legal) return res(451, 'Unavailable for legal reasons');
    const visible = (key) => repos[key] && (!repos[key].private || tokenOk);
    if (u.hostname === 'raw.githubusercontent.com') {
      const [owner, repo, ref, ...rest] = u.pathname.split('/').filter(Boolean).map(decodeURIComponent);
      const key = `${owner}/${repo}`;
      if (!visible(key)) return res(404, '404: Not Found');
      if (repos[key].redirect) return res(302, '', { location: repos[key].redirect });
      const br = repos[key].branches[ref === 'HEAD' ? 'main' : ref];
      const body = br && br[rest.join('/')];
      if (body === undefined) return res(404, '404: Not Found');
      return res(200, body, { 'content-type': 'text/plain; charset=utf-8' });
    }
    if (u.hostname === 'api.github.com') {
      const p = u.pathname.split('/').filter(Boolean);
      if (p[0] === 'users') {
        if (!users.includes(p[1])) return res(404, '{"message":"Not Found"}');
        if (p[2] === 'repos') return res(200, JSON.stringify(Object.entries(repos).filter(([k, v]) => k.startsWith(`${p[1]}/`) && !v.private).map(([k, v]) => ({ name: k.split('/')[1], language: v.language || 'Lua', fork: false, archived: false, pushed_at: '2026-11-01T00:00:00Z', size: 3 }))));
        return res(200, JSON.stringify({ login: p[1] }));
      }
      if (p[0] === 'repos') {
        const key = `${p[1]}/${p[2]}`;
        if (!visible(key)) return res(404, '{"message":"Not Found"}');
        if (!p[3]) return res(200, JSON.stringify({ full_name: key, private: !!repos[key].private }));
        if (p[3] === 'branches') return repos[key].branches[decodeURIComponent(p[4])] ? res(200, '{}') : res(404, '{"message":"Branch not found"}');
        if (p[3] === 'contents') {
          const ref = u.searchParams.get('ref') || 'main';
          const files = repos[key].branches[ref] || {};
          const path = p.slice(4).map(decodeURIComponent).join('/');
          if (files[path] !== undefined) return res(200, JSON.stringify({ type: 'file', path }));
          const inDir = Object.keys(files).filter((f) => f.startsWith(`${path}/`));
          return inDir.length ? res(200, JSON.stringify(inDir.map((f) => ({ type: 'file', path: f })))) : res(404, '{"message":"Not Found"}');
        }
        if (p[3] === 'git' && p[4] === 'trees') {
          const ref = decodeURIComponent(p[5]);
          const files = repos[key].branches[ref === 'HEAD' ? 'main' : ref];
          if (!files) return res(404, '{"message":"Not Found"}');
          return res(200, JSON.stringify({ tree: Object.entries(files).map(([path, body]) => ({ path, type: 'blob', size: body.length, sha: 'x' })), truncated: false }));
        }
      }
    }
    return res(404, 'not found');
  };
}

function call(handler, body, headers = {}) {
  return new Promise((resolve) => {
    const out = { headers: {} };
    const res = {
      statusCode: 200,
      setHeader(k, v) { out.headers[k.toLowerCase()] = v; },
      end(b) { out.status = this.statusCode; out.body = JSON.parse(b); resolve(out); },
    };
    handler({ method: 'POST', headers, body }, res);
  });
}

const REPOS = {
  'alice/tools': { branches: { main: { 'a.lua': LUA, 'scripts/b.luau': 'local t: number = 1\nreturn t', 'README.md': '# hi', 'page.lua': '<!DOCTYPE html><html></html>' } } },
  'alice/secret': { private: true, branches: { main: { 'private.lua': LUA } } },
  'alice/moved': { redirect: 'https://evil.example/steal.lua', branches: { main: {} } },
};

test('github server: a public file is retrieved, checked as Lua, hashed and returned', async () => {
  const h = createHandler({ fetchImpl: fakeGitHub({ repos: REPOS }), env: {} });
  const r = await call(h, { url: 'https://github.com/alice/tools/blob/main/a.lua' });
  assert.equal(r.body.ok, true);
  assert.equal(r.body.outcome, 'retrieved');
  assert.equal(Buffer.from(r.body.file.base64, 'base64').toString(), LUA);
  assert.equal(r.body.file.sha256, crypto.createHash('sha256').update(LUA).digest('hex'));
  assert.equal(r.body.file.contentClass, 'lua');
  assert.equal(r.body.licensing, 'not-activated');
  assert.equal(r.headers['cache-control'], 'no-store');
});

test('github server: every failure class is reported as itself, never as a retrieval', async () => {
  const h = createHandler({ fetchImpl: fakeGitHub({ repos: REPOS }), env: {} });
  const cases = [
    ['https://github.com/alice/secret/blob/main/private.lua', 'private-or-missing'],
    ['https://github.com/nobody-here/tools/blob/main/a.lua', 'owner-not-found'],
    ['https://github.com/alice/tools/blob/main/missing.lua', 'file-missing'],
    ['https://github.com/alice/tools/blob/nobranch/a.lua', 'ref-missing'],
    ['https://github.com/alice/tools/blob/main/README.md', 'not-lua'],
    ['https://github.com/alice/tools/blob/main/page.lua', 'not-lua'],
    ['https://github.com/alice/moved/blob/main/x.lua', 'invalid-url'],
    ['https://example.com/x.lua', 'invalid-url'],
  ];
  for (const [url, want] of cases) {
    const r = await call(h, { url });
    assert.equal(r.body.ok, false, url);
    assert.equal(r.body.outcome, want, `${url}: ${r.body.message}`);
    assert.ok(r.body.message, url);
  }
  const rl = await call(createHandler({ fetchImpl: fakeGitHub({ repos: REPOS, rate: true }), env: {} }), { url: 'https://github.com/alice/tools/blob/main/a.lua' });
  assert.equal(rl.body.outcome, 'rate-limited');
  assert.ok(rl.body.retryAfter > 0);
  const lg = await call(createHandler({ fetchImpl: fakeGitHub({ repos: REPOS, legal: true }), env: {} }), { url: 'https://github.com/alice/tools/blob/main/a.lua' });
  assert.equal(lg.body.outcome, 'legal-block');
});

test('github server: the user\'s token opens their private repository, goes only to GitHub, and is never echoed', async () => {
  const seen = [];
  const h = createHandler({ fetchImpl: fakeGitHub({ repos: REPOS, seen }), env: {} });
  const token = 'ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const r = await call(h, { url: 'https://github.com/alice/secret/blob/main/private.lua' }, { 'x-github-token': token });
  assert.equal(r.body.outcome, 'retrieved');
  assert.ok(!JSON.stringify(r.body).includes(token));
  assert.ok(seen.every((s) => s.auth === 'no' || ['api.github.com', 'raw.githubusercontent.com'].includes(s.host)));
  const wrong = await call(h, { url: 'https://github.com/alice/secret/blob/main/private.lua' }, { 'x-github-token': 'ghp_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' });
  assert.equal(wrong.body.outcome, 'not-found-with-token');
  const junk = await call(h, { url: 'https://github.com/alice/secret/blob/main/private.lua' }, { 'x-github-token': 'not a token; DROP' });
  assert.equal(junk.body.outcome, 'token-rejected');
  // a redirect off GitHub is never followed (and so a token could never travel with it)
  const off = await githubGet('https://raw.githubusercontent.com/alice/moved/main/x.lua', { fetchImpl: fakeGitHub({ repos: REPOS }), token });
  assert.equal(off.refused, true);
});

test('github server: repository and profile listings are metadata of what was named — nothing is downloaded from them', async () => {
  const seen = [];
  const h = createHandler({ fetchImpl: fakeGitHub({ repos: REPOS, seen }), env: {} });
  const r = await call(h, { url: 'https://github.com/alice/tools' });
  assert.equal(r.body.outcome, 'listing');
  assert.deepEqual(r.body.listing.files.map((f) => f.path), ['a.lua', 'page.lua', 'scripts/b.luau']);
  assert.ok(!seen.some((s) => s.host === 'raw.githubusercontent.com'), 'no file was read for a listing');
  const p = await call(h, { url: 'https://github.com/alice' });
  assert.equal(p.body.outcome, 'listing');
  assert.ok(p.body.listing.repositories.every((x) => x.name !== 'secret'), 'a private repository is not listed without a token');
  const missing = await call(h, { url: 'https://github.com/nobody-here' });
  assert.equal(missing.body.outcome, 'owner-not-found');
  assert.deepEqual(luaFilesOfTree([{ path: 'node_modules/x.lua', type: 'blob' }, { path: 'a.txt', type: 'blob' }, { path: 'b.lua', type: 'blob' }, { path: 'c.png', type: 'blob' }]).map((f) => f.path), ['b.lua', 'a.txt']);
});

// ---- Premium enforcement on the server -------------------------------------------------------------------------------------------------

async function keyPair() {
  const kp = await crypto.webcrypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const jwk = await crypto.webcrypto.subtle.exportKey('jwk', kp.publicKey);
  const sign = async (payload) => {
    const p = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const sig = await crypto.webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, kp.privateKey, new TextEncoder().encode(`QS1.${p}`));
    return `QS1.${p}.${Buffer.from(sig).toString('base64url')}`;
  };
  return { jwk: { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y }, sign };
}

test('premium: once a licence key is configured, the server refuses GitHub retrieval without a valid Premium licence', async () => {
  const { jwk, sign } = await keyPair();
  const env = { QS_LICENSE_PUBLIC_KEY: JSON.stringify(jwk) };
  const h = createHandler({ fetchImpl: fakeGitHub({ repos: REPOS }), env });
  const url = 'https://github.com/alice/tools/blob/main/a.lua';
  const now = Math.floor(Date.now() / 1000);
  assert.equal((await call(h, { url })).status, 401);
  assert.equal((await call(h, { url }, { 'x-qs-license': 'QS1.garbage.sig' })).status, 403);
  const basic = await sign({ v: 1, id: 'QS-BASIC-1', plan: 'basic', features: ['recover'], exp: now + 3600 });
  const r1 = await call(h, { url }, { 'x-qs-license': basic });
  assert.equal(r1.status, 403);
  assert.equal(r1.body.outcome, 'premium_required');
  const expired = await sign({ v: 1, id: 'QS-OLD-1', plan: 'premium', exp: now - 86400 });
  assert.equal((await call(h, { url }, { 'x-qs-license': expired })).body.outcome, 'licence_expired');
  const premium = await sign({ v: 1, id: 'QS-PREM-1', plan: 'premium', exp: now + 3600 });
  const ok = await call(h, { url }, { 'x-qs-license': premium });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.ok, true);
  assert.equal(ok.body.licensing, 'enforced');
  const revoked = createHandler({ fetchImpl: fakeGitHub({ repos: REPOS }), env: { ...env, QS_REVOKED_IDS: 'QS-PREM-1' } });
  assert.equal((await call(revoked, { url }, { 'x-qs-license': premium })).body.outcome, 'licence_revoked');
  // a licence signed by another key is refused
  const other = await keyPair();
  const forged = await other.sign({ v: 1, id: 'QS-PREM-9', plan: 'premium', exp: now + 3600 });
  assert.equal((await call(h, { url }, { 'x-qs-license': forged })).status, 403);
  // a feature-scoped licence (not the Premium plan) entitles exactly its features
  const scoped = await sign({ v: 1, id: 'QS-GH-1', plan: 'team', features: ['github'], exp: now + 3600 });
  assert.equal((await checkEntitlement({ headers: { 'x-qs-license': scoped } }, 'github', { env })).ok, true);
  assert.equal((await checkEntitlement({ headers: { 'x-qs-license': scoped } }, 'reconstruct', { env })).ok, false);
});

test('premium: a deployment that requires a licence but has no key fails closed', async () => {
  const r = await checkEntitlement({ headers: {} }, 'github', { env: { QS_REQUIRE_LICENSE: '1' } });
  assert.equal(r.ok, false);
  assert.equal(r.status, 503);
  const open = await checkEntitlement({ headers: {} }, 'github', { env: {} });
  assert.equal(open.ok, true);
  assert.equal(open.licensing, 'not-activated');
});

// ---- live (opt-in) --------------------------------------------------------------------------------------------------------------------

test('github live: a public file is read from raw.githubusercontent.com and classified (QS_LIVE_GITHUB=1)', { skip: process.env.QS_LIVE_GITHUB !== '1' }, async () => {
  const h = createHandler({ env: {} });
  const ok = await call(h, { url: 'https://github.com/wraithx-knigh128/Gtimcrow/blob/main/message.txt' });
  assert.equal(ok.body.ok, true, ok.body.message);
  assert.equal(ok.body.outcome, 'retrieved');
  // that file is Lua-like but does not parse (a decompiler's output with an unmatched `end`): it is classed as Lua that does not parse
  assert.equal(ok.body.file.contentClass, 'lua-invalid');
  const missing = await call(h, { url: 'https://github.com/wraithx-knigh128/Gtimcrow/blob/main/does-not-exist.lua' });
  assert.equal(missing.body.ok, false);
  // GitHub's API decides between a missing file and the rest; when this machine's unauthenticated API quota (60 an hour) is used up, the
  // honest answer is the rate limit, with when to retry — observed live while writing this test
  assert.ok(['file-missing', 'rate-limited'].includes(missing.body.outcome), missing.body.outcome);
  if (missing.body.outcome === 'rate-limited') assert.ok(missing.body.retryAfter > 0);
});
