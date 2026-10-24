// The serverless functions (api/fetch.js, api/origin.js) with the network replaced by canned responses.

import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler as createFetch } from '../api/fetch.js';
import { createHandler as createOrigin } from '../api/origin.js';
import { normalizeUrl, FetchRefused } from '../api/_lib/safe-fetch.js';
import { fragmentContains } from '../api/_lib/search.js';
import { hashLine, normalizeLine } from '../src/origin/lines.js';

function call(handler, { method = 'GET', url = '/', query = {}, body, headers = {} } = {}) {
  return new Promise((resolve) => {
    const res = {
      statusCode: 200, headers: {}, chunks: [],
      setHeader(k, v) { this.headers[k.toLowerCase()] = v; },
      end(data) { resolve({ status: this.statusCode, headers: this.headers, body: data ? Buffer.from(data) : Buffer.alloc(0) }); },
    };
    handler({ method, url, query, body, headers: { 'sec-fetch-site': 'same-origin', ...headers }, socket: { remoteAddress: '1.2.3.4' } }, res);
  });
}
const textRes = (text, { status = 200, type = 'text/plain', headers = {} } = {}) => {
  const bytes = new TextEncoder().encode(text);
  return {
    status, ok: status >= 200 && status < 300,
    headers: new Map(Object.entries({ 'content-type': type, 'content-length': String(bytes.length), ...headers })),
    body: new ReadableStream({ start(c) { c.enqueue(bytes); c.close(); } }),
    json: async () => JSON.parse(text),
  };
};
// Map#get is case-sensitive; the code under test asks for lower-case names, which is what we store.

test('links are turned into raw links and refused outside the list', () => {
  assert.equal(normalizeUrl('https://github.com/a/b/blob/main/x/y.lua').toString(), 'https://raw.githubusercontent.com/a/b/main/x/y.lua');
  assert.equal(normalizeUrl('https://gist.github.com/user/0123abcd').toString(), 'https://gist.githubusercontent.com/user/0123abcd/raw');
  assert.equal(normalizeUrl('https://pastebin.com/AbCd1234').toString(), 'https://pastebin.com/raw/AbCd1234');
  assert.equal(normalizeUrl('https://rentry.co/abc').toString(), 'https://rentry.co/abc/raw');
  assert.equal(normalizeUrl('https://raw.githubusercontent.com/a/b/c/d.lua').toString(), 'https://raw.githubusercontent.com/a/b/c/d.lua');
  for (const bad of ['http://raw.githubusercontent.com/a', 'https://evil.example/x', 'https://user:pw@raw.githubusercontent.com/a', 'https://raw.githubusercontent.com:8443/a', 'https://127.0.0.1/x', 'https://raw.githubusercontent.com.evil.com/a', 'nope', 'file:///etc/passwd']) {
    assert.throws(() => normalizeUrl(bad), FetchRefused, bad);
  }
});

test('/api/fetch returns the file untouched and names it', async () => {
  const handler = createFetch({ fetchImpl: async () => textRes('print("hi")\n') });
  const r = await call(handler, { query: { url: 'https://raw.githubusercontent.com/a/b/main/script.lua' } });
  assert.equal(r.status, 200);
  assert.equal(r.body.toString(), 'print("hi")\n');
  assert.equal(r.headers['x-qs-name'], 'script.lua');
  assert.equal(r.headers['cache-control'], 'no-store');
});

test('/api/fetch refuses pages, big files, bad redirects and cross-site callers', async () => {
  const html = createFetch({ fetchImpl: async () => textRes('<html></html>', { type: 'text/html; charset=utf-8' }) });
  assert.equal((await call(html, { query: { url: 'https://pastebin.com/AbCd1234' } })).status, 415);

  const big = createFetch({ fetchImpl: async () => textRes('x', { headers: { 'content-length': String(50 * 1024 * 1024) } }) });
  assert.equal((await call(big, { query: { url: 'https://raw.githubusercontent.com/a/b/c/d.lua' } })).status, 413);

  const redirect = createFetch({ fetchImpl: async () => ({ status: 302, ok: false, headers: new Map([['location', 'https://evil.example/x']]), body: null }) });
  const rr = await call(redirect, { query: { url: 'https://raw.githubusercontent.com/a/b/c/d.lua' } });
  assert.equal(rr.status, 400);
  assert.match(JSON.parse(rr.body).error, /redirects somewhere/);

  const ok = createFetch({ fetchImpl: async () => textRes('x') });
  assert.equal((await call(ok, { query: { url: 'https://raw.githubusercontent.com/a/b/c/d.lua' }, headers: { 'sec-fetch-site': 'cross-site' } })).status, 403);
  assert.equal((await call(ok, { method: 'POST', query: {} })).status, 405);
  assert.equal((await call(ok, { query: { url: 'https://raw.githubusercontent.com/a/b/c/d.lua'.padEnd(2500, 'a') } })).status, 400);
});

test('/api/fetch follows a redirect between allowed hosts', async () => {
  let n = 0;
  const handler = createFetch({
    fetchImpl: async (u) => (n++ === 0
      ? { status: 301, ok: false, headers: new Map([['location', 'https://raw.githubusercontent.com/moved/file.lua']]), body: null }
      : textRes(`from ${u}`)),
  });
  const r = await call(handler, { query: { url: 'https://github.com/a/b/blob/main/f.lua' } });
  assert.equal(r.status, 200);
  assert.match(r.body.toString(), /raw\.githubusercontent\.com\/moved\/file\.lua/);
});

// ---- origin ---------------------------------------------------------------------------------------------------------------

const githubItem = (repo, path, fragment) => ({ path, html_url: `https://github.com/${repo}/blob/main/${path}`, repository: { full_name: repo }, text_matches: [{ fragment }] });

test('/api/origin says so when no token is configured, and validates input', async () => {
  const off = createOrigin({ env: {} });
  const r = await call(off, { method: 'POST', body: { fingerprints: [{ query: 'some distinctive line' }] } });
  assert.equal(JSON.parse(r.body).configured, false);

  const handler = createOrigin({ env: { QS_ORIGIN_GITHUB_TOKEN: 't' }, fetchImpl: async () => { throw new Error('no network in this test'); }, sleep: async () => {} });
  const bad = async (body) => (await call(handler, { method: 'POST', body })).status;
  assert.equal(await bad({}), 400);
  assert.equal(await bad({ fingerprints: [] }), 400);
  assert.equal(await bad({ fingerprints: Array(9).fill({ query: 'long enough query' }) }), 400);
  assert.equal(await bad({ fingerprints: [{ query: 'short' }] }), 400);
  assert.equal(await bad({ fingerprints: [{ query: 'x'.repeat(200) }] }), 400);
  assert.equal((await call(handler, { method: 'GET' })).status, 405);
  assert.equal((await call(handler, { method: 'POST', body: { fingerprints: [{ query: 'long enough query' }] }, headers: { 'sec-fetch-site': 'cross-site' } })).status, 403);
});

test('/api/origin collects files per fingerprint, drops fuzzy matches, and hashes the best files', async () => {
  const queries = ['the quick brown fox jumps over the lazy dog', 'local function calculateDamageMultiplier', 'unrelated phrase nobody wrote anywhere'];
  const file = 'line one is long enough here\nlocal function calculateDamageMultiplier(x)\nthe quick brown fox jumps over the lazy dog\nend\n';
  const seen = [];
  const fetchImpl = async (url) => {
    seen.push(url);
    if (url.startsWith('https://api.github.com/search/code')) {
      const q = decodeURIComponent(url.split('q=')[1].split('&')[0]);
      if (q.includes('quick brown fox')) return textRes(JSON.stringify({ items: [githubItem('alice/hub', 'src/main.lua', 'the quick brown fox jumps over the lazy dog'), githubItem('bob/other', 'x.lua', 'fox dog')] }));
      if (q.includes('calculateDamageMultiplier')) return textRes(JSON.stringify({ items: [githubItem('alice/hub', 'src/main.lua', 'local function calculateDamageMultiplier(x)')] }));
      return textRes(JSON.stringify({ items: [] }));
    }
    if (url.startsWith('https://raw.githubusercontent.com/alice/hub/HEAD/src/main.lua')) return textRes(file);
    return textRes('', { status: 404 });
  };
  const handler = createOrigin({ env: { QS_ORIGIN_GITHUB_TOKEN: 't' }, fetchImpl, sleep: async () => {} });
  const r = await call(handler, { method: 'POST', body: { fingerprints: queries.map((query) => ({ query })) } });
  const out = JSON.parse(r.body);
  assert.equal(out.configured, true);
  assert.equal(out.queried, 3);
  assert.equal(out.matches.length, 1, 'the fuzzy result from bob/other is dropped');
  assert.equal(out.matches[0].repo, 'alice/hub');
  assert.deepEqual(out.matches[0].hits, [0, 1]);
  assert.ok(out.matches[0].lineHashes.includes(hashLine(normalizeLine('the quick brown fox jumps over the lazy dog'))));
  assert.ok(seen.every((u) => u.startsWith('https://api.github.com/') || u.startsWith('https://raw.githubusercontent.com/')));
});

test('/api/origin reports a rate limit instead of failing', async () => {
  let n = 0;
  const fetchImpl = async () => (n++ === 0
    ? textRes(JSON.stringify({ items: [] }))
    : { status: 403, ok: false, headers: new Map([['x-ratelimit-reset', '1900000000']]), body: null, json: async () => ({}) });
  const handler = createOrigin({ env: { QS_ORIGIN_GITHUB_TOKEN: 't' }, fetchImpl, sleep: async () => {} });
  const r = await call(handler, { method: 'POST', body: { fingerprints: [{ query: 'first long query line' }, { query: 'second long query line' }] } });
  const out = JSON.parse(r.body);
  assert.equal(out.queried, 1);
  assert.match(out.note, /rate limit/);
});

test('/api/origin limits how often one address can ask', async () => {
  const handler = createOrigin({ env: { QS_ORIGIN_GITHUB_TOKEN: 't' }, fetchImpl: async () => textRes(JSON.stringify({ items: [] })), sleep: async () => {}, now: () => 1_000_000 });
  let last = 0;
  for (let i = 0; i < 14; i++) last = (await call(handler, { method: 'POST', body: { fingerprints: [{ query: 'a long enough query line' }] }, headers: { 'x-forwarded-for': '9.9.9.9' } })).status;
  assert.equal(last, 429);
});

test('fragmentContains needs nearly all the words', () => {
  assert.equal(fragmentContains('local function calculateDamageMultiplier(x)', 'local function calculateDamageMultiplier'), true);
  assert.equal(fragmentContains('fox dog', 'the quick brown fox jumps over the lazy dog'), false);
});
