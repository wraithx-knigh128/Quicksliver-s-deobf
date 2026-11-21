// POST /api/github — read a Lua/Luau source from GitHub for the page: a file, or the listing of a repository, folder or profile.
//
//   body     { url: "<any GitHub link src/loader/github.js understands>", mode?: "auto" | "file" | "listing" }
//   headers  x-qs-license: <licence>   (Premium; see api/_lib/entitlement.js)
//            x-github-token: <token>   (optional: the user's own GitHub token, for their private repositories)
//   answer   { ok, outcome, label, message, target, file?: { name, path, size, sha256, contentClass, base64 }, listing?, licensing }
//
// The answer's `outcome` is one of src/loader/github.js OUTCOMES: a private repository, a deleted one, a missing file or branch, the rate
// limit, a legal block and content that is not Lua are told apart (as far as GitHub's answers allow: without a token GitHub answers a private
// repository exactly as a missing one, and the message says so). A 200 is not a success until the body is Lua.
//
// Security: only GitHub's own hosts are reachable (no user-chosen host, no IP, no port, redirects re-checked against the same list on every
// hop); sizes are capped while reading; every request has a deadline. The user's token is sent only to api.github.com and
// raw.githubusercontent.com, never stored, never logged, never part of an answer or an error. Listings are of what the user named: one
// repository (its Lua files), or one profile (its public repositories' metadata). Nothing is fetched from a listing until the user picks it.

import crypto from 'node:crypto';
import { parseGitHubRef, GitHubRefError, OUTCOMES, contentClass, diagnoseFailure, luaFilesOfTree } from '../src/loader/github.js';
import { parse } from '../src/core/parser.js';
import { checkEntitlement } from './_lib/entitlement.js';

const HOSTS = new Set(['raw.githubusercontent.com', 'api.github.com', 'gist.githubusercontent.com']);
const TOKEN_HOSTS = new Set(['raw.githubusercontent.com', 'api.github.com']);
const MAX_FILE = 4 * 1024 * 1024;
const MAX_JSON = 2 * 1024 * 1024;

const json = (res, status, body, headers = {}) => {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
  res.end(JSON.stringify(body));
};

/** GET one GitHub address; never throws for an HTTP status (the status is the evidence), only for a refused address or a transport failure. */
export async function githubGet(url, { fetchImpl = fetch, token = null, maxBytes = MAX_FILE, deadline = Date.now() + 10_000, accept = '*/*' } = {}) {
  let current = new URL(url);
  for (let hop = 0; hop < 4; hop++) {
    if (current.protocol !== 'https:' || current.username || current.password || current.port || !HOSTS.has(current.hostname.toLowerCase())) {
      return { status: 0, refused: true, error: 'The address leads outside GitHub.' };
    }
    const left = deadline - Date.now();
    if (left <= 0) return { status: 0, error: 'GitHub took too long to answer.' };
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), left);
    const headers = { 'User-Agent': 'QuickSilver', Accept: accept };
    if (current.hostname === 'api.github.com') headers['X-GitHub-Api-Version'] = '2022-11-28';
    if (token && TOKEN_HOSTS.has(current.hostname.toLowerCase())) headers.Authorization = `Bearer ${token}`;
    let res;
    try {
      res = await fetchImpl(current.toString(), { redirect: 'manual', signal: ctl.signal, headers });
    } catch (e) {
      clearTimeout(timer);
      return { status: 0, error: e && e.name === 'AbortError' ? 'GitHub took too long to answer.' : 'GitHub could not be reached.' };
    }
    if (res.status >= 300 && res.status < 400 && res.headers.get('location')) {
      clearTimeout(timer);
      try { current = new URL(res.headers.get('location'), current); } catch { return { status: 0, error: 'GitHub sent an invalid redirect.' }; }
      continue;
    }
    const declared = Number(res.headers.get('content-length') || 0);
    if (declared > maxBytes) { clearTimeout(timer); ctl.abort(); return { status: 413, headers: res.headers }; }
    const chunks = [];
    let total = 0;
    try {
      if (res.body) {
        const reader = res.body.getReader();
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          total += value.length;
          if (total > maxBytes) { ctl.abort(); return { status: 413, headers: res.headers }; }
          chunks.push(value);
        }
      }
    } catch { return { status: 0, error: 'The download was interrupted.' }; } finally { clearTimeout(timer); }
    const bytes = new Uint8Array(total);
    let at = 0;
    for (const c of chunks) { bytes.set(c, at); at += c.length; }
    return { status: res.status, headers: res.headers, bytes, url: current.toString() };
  }
  return { status: 0, error: 'Too many redirects.' };
}

const jsonOf = (r) => { try { return JSON.parse(Buffer.from(r.bytes || []).toString('utf8')); } catch { return null; } };
const latin1 = (b) => Buffer.from(b).toString('latin1');
const parsesAsLua = (text) => { try { parse(text); return true; } catch { return false; } };

/** Retrieve one file and classify the answer. Exported for the tests (which pass a fetchImpl that plays GitHub). */
export async function retrieveFile(t, { fetchImpl, token, deadline }) {
  const raw = await githubGet(t.urls.raw, { fetchImpl, token, deadline, maxBytes: MAX_FILE });
  if (raw.refused) return { outcome: 'invalid-url', message: raw.error };
  if (raw.status === 200) {
    const cls = contentClass(raw.bytes, { contentType: raw.headers.get('content-type') || '', parses: (s) => parsesAsLua(s) });
    if (!cls.lua) return { outcome: 'not-lua', message: cls.reason, contentClass: cls.kind };
    const sha256 = crypto.createHash('sha256').update(raw.bytes).digest('hex');
    return { outcome: 'retrieved', contentClass: cls.kind, contentReason: cls.reason, bytes: raw.bytes, sha256 };
  }
  // why did it fail? ask GitHub's API the questions that tell the cases apart (each answer is evidence; none is assumed)
  const probes = { raw: raw.status ? { status: raw.status, headers: raw.headers } : undefined };
  if (raw.status === 404 || raw.status === 403 || raw.status === 401 || raw.status === 0) {
    const repo = await githubGet(t.urls.repo, { fetchImpl, token, deadline, maxBytes: MAX_JSON, accept: 'application/vnd.github+json' });
    probes.repo = repo.status ? { status: repo.status, headers: repo.headers } : undefined;
    if (repo.status === 404) {
      const owner = await githubGet(t.urls.owner, { fetchImpl, token, deadline, maxBytes: MAX_JSON, accept: 'application/vnd.github+json' });
      probes.owner = owner.status ? { status: owner.status, headers: owner.headers } : undefined;
    } else if (repo.status === 200) {
      if (t.urls.branch) {
        const br = await githubGet(t.urls.branch, { fetchImpl, token, deadline, maxBytes: MAX_JSON, accept: 'application/vnd.github+json' });
        probes.branch = br.status ? { status: br.status, headers: br.headers } : undefined;
      }
      if (!probes.branch || probes.branch.status !== 404) {
        const c = await githubGet(t.urls.contents, { fetchImpl, token, deadline, maxBytes: MAX_JSON, accept: 'application/vnd.github+json' });
        probes.contents = c.status ? { status: c.status, headers: c.headers, isDir: c.status === 200 && Array.isArray(jsonOf(c)) } : undefined;
      }
    }
  }
  return diagnoseFailure(probes, { token: !!token });
}

/** The Lua files of a repository (or folder), or the public repositories of a profile: metadata only. */
export async function listTarget(t, { fetchImpl, token, deadline }) {
  if (t.kind === 'profile') {
    const r = await githubGet(t.urls.repos, { fetchImpl, token, deadline, maxBytes: MAX_JSON, accept: 'application/vnd.github+json' });
    if (r.status !== 200) {
      const owner = r.status === 404 ? { status: 404 } : undefined;
      return diagnoseFailure({ repo: { status: r.status === 404 ? 404 : r.status, headers: r.headers }, owner }, { token: !!token });
    }
    const list = (jsonOf(r) || []).filter((x) => x && !x.fork && !x.archived).map((x) => ({ name: x.name, language: x.language || null, description: x.description ? String(x.description).slice(0, 200) : null, updated: x.pushed_at || x.updated_at || null, size: x.size ?? null, private: !!x.private, defaultBranch: x.default_branch || null }));
    const lua = list.filter((x) => /^(?:Lua|Luau)$/i.test(x.language || ''));
    return { outcome: 'listing', listing: { kind: 'profile', owner: t.owner, repositories: lua.length ? lua : list, onlyLua: lua.length > 0, total: list.length } };
  }
  const r = await githubGet(t.urls.tree, { fetchImpl, token, deadline, maxBytes: MAX_JSON, accept: 'application/vnd.github+json' });
  if (r.status !== 200) {
    const repo = await githubGet(t.urls.repo, { fetchImpl, token, deadline, maxBytes: MAX_JSON, accept: 'application/vnd.github+json' });
    const probes = { repo: { status: repo.status, headers: repo.headers } };
    if (repo.status === 404) { const o = await githubGet(t.urls.owner, { fetchImpl, token, deadline, maxBytes: MAX_JSON }); probes.owner = { status: o.status, headers: o.headers }; }
    if (repo.status === 200 && r.status === 404) probes.branch = { status: 404 };
    if (repo.status === 200 && r.status === 409) probes.repo = { status: 409 };
    return diagnoseFailure(probes, { token: !!token });
  }
  const body = jsonOf(r) || {};
  let files = luaFilesOfTree(body.tree || []);
  if (t.kind === 'dir') files = files.filter((f) => f.path === t.path || f.path.startsWith(`${t.path.replace(/\/$/, '')}/`));
  return { outcome: 'listing', listing: { kind: t.kind, owner: t.owner, repo: t.repo, ref: t.ref || null, path: t.path || '', files, truncated: !!body.truncated } };
}

export function createHandler({ fetchImpl = fetch, env = process.env, now = () => Date.now() } = {}) {
  const hits = [];
  return async function handler(req, res) {
    if (req.method === 'GET') return json(res, 200, { ok: true, service: 'github', modes: ['auto', 'file', 'listing'] });
    if (req.method !== 'POST') return json(res, 405, { ok: false, outcome: 'invalid-url', message: 'POST a GitHub link.' }, { Allow: 'GET, POST' });
    const site = req.headers && req.headers['sec-fetch-site'];
    if (site && !['same-origin', 'none'].includes(site)) return json(res, 403, { ok: false, outcome: 'forbidden', message: 'This endpoint is for the QuickSilver page only.' });
    const ent = await checkEntitlement(req, 'github', { env });
    if (!ent.ok) return json(res, ent.status, { ok: false, outcome: ent.code, message: ent.message, licensing: ent.licensing });
    const limit = Number(env.QS_GITHUB_RPM) || 30;
    const t0 = now();
    while (hits.length && t0 - hits[0] > 60_000) hits.shift();
    if (hits.length >= limit) return json(res, 429, { ok: false, outcome: 'rate-limited', message: `More than ${limit} GitHub requests a minute on this server.`, licensing: ent.licensing }, { 'Retry-After': '30' });
    hits.push(t0);
    let body;
    try {
      if (req.body && typeof req.body === 'object') body = req.body;
      else {
        const chunks = []; let n = 0;
        for await (const c of req) { n += c.length; if (n > 8192) throw new Error('large'); chunks.push(c); }
        body = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
      }
    } catch { return json(res, 400, { ok: false, outcome: 'invalid-url', message: 'The request body is not valid JSON (or is too large).' }); }
    const rawToken = req.headers && req.headers['x-github-token'];
    const token = typeof rawToken === 'string' && /^[A-Za-z0-9_]{20,255}$/.test(rawToken.trim()) ? rawToken.trim() : null;
    if (rawToken && !token) return json(res, 400, { ok: false, outcome: 'token-rejected', message: 'That does not look like a GitHub token (ghp_…, github_pat_…). Nothing was sent to GitHub.' });
    let t;
    try { t = parseGitHubRef(body && body.url); } catch (e) {
      if (e instanceof GitHubRefError) return json(res, 400, { ok: false, outcome: 'invalid-url', label: OUTCOMES['invalid-url'].label, message: e.message });
      throw e;
    }
    const mode = (body && body.mode) || 'auto';
    const deadline = now() + 20_000;
    const target = { kind: t.kind, owner: t.owner || null, repo: t.repo || null, ref: t.ref || null, path: t.path || null, gist: t.gist || null, page: t.urls.page || null };
    try {
      if (t.kind === 'gist') {
        const r = await githubGet(t.urls.raw, { fetchImpl, token: null, deadline });
        if (r.status !== 200) return json(res, 200, { ok: false, outcome: r.status === 404 ? 'file-missing' : 'unavailable', label: OUTCOMES[r.status === 404 ? 'file-missing' : 'unavailable'].label, message: r.status === 404 ? 'The gist (or that file of it) does not exist, or is secret and was not shared with this link.' : `GitHub answered HTTP ${r.status || 'nothing'}.`, target, licensing: ent.licensing });
        const cls = contentClass(r.bytes, { contentType: r.headers.get('content-type') || '', parses: parsesAsLua });
        if (!cls.lua) return json(res, 200, { ok: false, outcome: 'not-lua', label: OUTCOMES['not-lua'].label, message: cls.reason, target, licensing: ent.licensing });
        return json(res, 200, { ok: true, outcome: 'retrieved', target, file: { name: t.file || `${t.gist}.lua`, path: t.file || '', size: r.bytes.length, sha256: crypto.createHash('sha256').update(r.bytes).digest('hex'), contentClass: cls.kind, contentReason: cls.reason, base64: Buffer.from(r.bytes).toString('base64') }, licensing: ent.licensing });
      }
      if (t.kind !== 'file' || mode === 'listing') {
        if (t.kind === 'file') return json(res, 400, { ok: false, outcome: 'invalid-url', message: 'A file link has no listing; ask for the file.' });
        const out = await listTarget(t, { fetchImpl, token, deadline });
        const ok = out.outcome === 'listing';
        return json(res, 200, { ok, outcome: out.outcome, label: OUTCOMES[out.outcome] ? OUTCOMES[out.outcome].label : out.outcome, message: out.message || null, target, listing: out.listing || null, retryAfter: out.retryAfter ?? null, licensing: ent.licensing });
      }
      const out = await retrieveFile(t, { fetchImpl, token, deadline });
      if (out.outcome !== 'retrieved') return json(res, 200, { ok: false, outcome: out.outcome, label: OUTCOMES[out.outcome] ? OUTCOMES[out.outcome].label : out.outcome, message: out.message, target, retryAfter: out.retryAfter ?? null, licensing: ent.licensing });
      const name = (t.path.split('/').pop() || 'file.lua').replace(/[^\w.\-]+/g, '_').slice(0, 80);
      return json(res, 200, { ok: true, outcome: 'retrieved', target, file: { name, path: t.path, size: out.bytes.length, sha256: out.sha256, contentClass: out.contentClass, contentReason: out.contentReason, base64: Buffer.from(out.bytes).toString('base64') }, licensing: ent.licensing });
    } catch {
      return json(res, 502, { ok: false, outcome: 'unavailable', label: OUTCOMES.unavailable.label, message: 'Unexpected error while reading from GitHub.', target });
    }
  };
}

// exported for the tests
export { latin1 };
export default createHandler();
