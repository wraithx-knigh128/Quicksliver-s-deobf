// GitHub references in loaders: what a link points at, how to read it, and why a read failed.
//
// This module does no networking. It is shared by the page (to recognise what the user submitted) and by the server function api/github.js
// (which performs the requests, through a fixed list of GitHub hosts). Everything that decides an outcome is a pure function of what GitHub
// answered, so every outcome is tested without the network (tests/xxvii-github.test.mjs).
//
// Forms understood (with or without www., with refs/heads/ or refs/tags/ spelled out):
//   https://raw.githubusercontent.com/OWNER/REPO/REF/PATH                       file
//   https://github.com/OWNER/REPO/blob/REF/PATH   …/raw/REF/PATH                file
//   https://github.com/OWNER/REPO/tree/REF[/PATH]                                directory (a listing)
//   https://github.com/OWNER/REPO[.git]                                          repository (a listing of its Lua files)
//   https://github.com/OWNER                                                     profile (a listing of the owner's public repositories)
//   https://api.github.com/repos/OWNER/REPO/contents/PATH[?ref=REF]             file
//   https://gist.github.com/OWNER/ID    https://gist.githubusercontent.com/OWNER/ID/raw[/SHA][/FILE]    gist
//
// Outcomes (OUTCOMES below) separate what the user can act on: a private repository needs their authorisation; a repository that does not
// exist, a missing file or branch, a rate limit, a legal block and content that is not Lua are each said as such. A 200 alone is never a
// success: the body has to be Lua (or Luau, or a compiled chunk) before it is passed on.

export class GitHubRefError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

export const GITHUB_HOSTS = Object.freeze(['github.com', 'raw.githubusercontent.com', 'api.github.com', 'gist.github.com', 'gist.githubusercontent.com']);

/** Outcome codes, each with the label the interface shows. `ok` is true only where a file was retrieved and is Lua. */
export const OUTCOMES = Object.freeze({
  'retrieved-plain': { ok: true, label: 'Public source retrieved (not obfuscated)' },
  'retrieved-needs-reconstruction': { ok: true, label: 'Public source retrieved; it is obfuscated and goes to reconstruction' },
  'retrieved-reconstructed': { ok: true, label: 'Retrieved and reconstructed' },
  'retrieved-not-reconstructed': { ok: true, label: 'Retrieved; reconstruction did not succeed' },
  listing: { ok: true, label: 'Repository listing' },
  'invalid-url': { ok: false, label: 'Not a valid GitHub link' },
  'private-or-missing': { ok: false, label: 'Repository not found, or private (needs your authorisation)' },
  'not-found-with-token': { ok: false, label: 'Repository not found, or your token has no access to it' },
  'owner-not-found': { ok: false, label: 'No GitHub account by that name (deleted or never existed)' },
  'file-missing': { ok: false, label: 'The repository exists, but the file is not in it' },
  'ref-missing': { ok: false, label: 'The repository exists, but the branch or tag does not' },
  'repo-empty': { ok: false, label: 'The repository is empty' },
  'rate-limited': { ok: false, label: 'GitHub rate limit reached' },
  'token-rejected': { ok: false, label: 'GitHub rejected the token' },
  'legal-block': { ok: false, label: 'Unavailable for legal reasons (HTTP 451)' },
  'not-lua': { ok: false, label: 'Retrieved, but the content is not Lua or Luau' },
  'too-large': { ok: false, label: 'The file is larger than the limit' },
  'is-directory': { ok: false, label: 'The address is a directory, not a file' },
  unavailable: { ok: false, label: 'Source unavailable (GitHub did not answer as expected)' },
  licence: { ok: false, label: 'Premium licence required by this site' },
});

const OWNER = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$/;
const REPO = /^[A-Za-z0-9._-]{1,100}$/;
const GIST = /^[0-9a-f]{20,40}$/i;
const RESERVED_OWNER = new Set(['about', 'apps', 'blog', 'collections', 'contact', 'customer-stories', 'enterprise', 'explore', 'features', 'issues', 'login', 'logout', 'marketplace', 'new', 'notifications', 'orgs', 'pricing', 'pulls', 'search', 'security', 'settings', 'site', 'sponsors', 'topics', 'trending', 'join', 'organizations', 'codespaces', 'readme']);

function segmentsOf(pathname) {
  const raw = pathname.split('/').filter(Boolean);
  const out = [];
  for (const s of raw) {
    let d;
    try { d = decodeURIComponent(s); } catch { throw new GitHubRefError('invalid-url', 'The link has a malformed %-escape.'); }
    if (d === '.' || d === '..' || /[\x00-\x1f\x7f\\]/.test(d) || d.includes('/')) throw new GitHubRefError('invalid-url', 'The link has a path segment that is not allowed.');
    out.push(d);
  }
  return out;
}

const checkOwner = (o) => { if (!OWNER.test(o) || RESERVED_OWNER.has(o.toLowerCase())) throw new GitHubRefError('invalid-url', `“${o}” is not a GitHub account name.`); return o; };
const checkRepo = (r) => { const x = r.replace(/\.git$/i, ''); if (!REPO.test(x) || x === '.' || x === '..') throw new GitHubRefError('invalid-url', `“${r}” is not a repository name.`); return x; };

/** `refs/heads/main/a/b.lua` → ['main', 'a/b.lua']; `main/a/b.lua` → ['main', 'a/b.lua'] (a branch name with a slash cannot be told apart from a folder without asking GitHub). */
function refAndPath(segs) {
  if (segs[0] === 'refs' && (segs[1] === 'heads' || segs[1] === 'tags') && segs.length >= 3) return [segs[2], segs.slice(3).join('/')];
  return [segs[0], segs.slice(1).join('/')];
}

const enc = (p) => p.split('/').map(encodeURIComponent).join('/');

/** The URLs a target is read through. */
export function urlsFor(t) {
  const base = t.owner && t.repo ? `https://api.github.com/repos/${encodeURIComponent(t.owner)}/${encodeURIComponent(t.repo)}` : null;
  if (t.kind === 'file') {
    return {
      raw: `https://raw.githubusercontent.com/${encodeURIComponent(t.owner)}/${encodeURIComponent(t.repo)}/${t.ref ? encodeURIComponent(t.ref) : 'HEAD'}/${enc(t.path)}`,
      contents: `${base}/contents/${enc(t.path)}${t.ref ? `?ref=${encodeURIComponent(t.ref)}` : ''}`,
      repo: base, owner: `https://api.github.com/users/${encodeURIComponent(t.owner)}`,
      branch: t.ref ? `${base}/branches/${encodeURIComponent(t.ref)}` : null,
      page: `https://github.com/${t.owner}/${t.repo}/blob/${t.ref || 'HEAD'}/${enc(t.path)}`,
    };
  }
  if (t.kind === 'repo' || t.kind === 'dir') {
    return { repo: base, owner: `https://api.github.com/users/${encodeURIComponent(t.owner)}`, tree: `${base}/git/trees/${encodeURIComponent(t.ref || 'HEAD')}?recursive=1`, branch: t.ref ? `${base}/branches/${encodeURIComponent(t.ref)}` : null, page: `https://github.com/${t.owner}/${t.repo}` };
  }
  if (t.kind === 'profile') return { owner: `https://api.github.com/users/${encodeURIComponent(t.owner)}`, repos: `https://api.github.com/users/${encodeURIComponent(t.owner)}/repos?per_page=100&sort=updated&type=owner`, page: `https://github.com/${t.owner}` };
  if (t.kind === 'gist') return { api: `https://api.github.com/gists/${t.gist}`, raw: `https://gist.githubusercontent.com/${encodeURIComponent(t.owner || 'anonymous')}/${t.gist}/raw${t.file ? `/${encodeURIComponent(t.file)}` : ''}`, page: `https://gist.github.com/${t.gist}` };
  return {};
}

/**
 * What a GitHub link points at.
 * @param {string} input
 * @returns {{kind: 'file'|'dir'|'repo'|'profile'|'gist', owner?: string, repo?: string, ref?: string|null, path?: string, gist?: string, file?: string, urls: object}}
 * @throws {GitHubRefError} code 'invalid-url' (not a URL, not https, not GitHub, a malformed path) — never a network question
 */
export function parseGitHubRef(input) {
  let u;
  const text = String(input || '').trim();
  if (text.length > 2000) throw new GitHubRefError('invalid-url', 'The link is too long.');
  try { u = new URL(/^[a-z][a-z0-9+.-]*:/i.test(text) ? text : `https://${text}`); } catch { throw new GitHubRefError('invalid-url', 'That is not a valid link.'); }
  if (u.protocol !== 'https:' && u.protocol !== 'http:') throw new GitHubRefError('invalid-url', 'Only https links to GitHub are read.');
  if (u.username || u.password) throw new GitHubRefError('invalid-url', 'Links with a user name or password are not accepted (send a token separately).');
  if (u.port) throw new GitHubRefError('invalid-url', 'Links with a port are not GitHub links.');
  const host = u.hostname.toLowerCase().replace(/^www\./, '');
  if (!GITHUB_HOSTS.includes(host)) throw new GitHubRefError('invalid-url', `${host} is not a GitHub address.`);
  const segs = segmentsOf(u.pathname);
  let t;
  if (host === 'raw.githubusercontent.com') {
    if (segs.length < 4) throw new GitHubRefError('invalid-url', 'A raw GitHub link needs an owner, a repository, a branch and a file.');
    const [ref, path] = refAndPath(segs.slice(2));
    if (!path) throw new GitHubRefError('invalid-url', 'The raw link names no file.');
    t = { kind: 'file', owner: checkOwner(segs[0]), repo: checkRepo(segs[1]), ref: ref === 'HEAD' ? null : ref, path };
  } else if (host === 'github.com') {
    if (!segs.length) throw new GitHubRefError('invalid-url', 'The link names no account or repository.');
    if (segs.length === 1) t = { kind: 'profile', owner: checkOwner(segs[0]) };
    else {
      const owner = checkOwner(segs[0]); const repo = checkRepo(segs[1]);
      const mode = segs[2];
      if (!mode) t = { kind: 'repo', owner, repo, ref: null, path: '' };
      else if (mode === 'blob' || mode === 'raw') {
        const [ref, path] = refAndPath(segs.slice(3));
        if (!ref || !path) throw new GitHubRefError('invalid-url', 'The link names no file.');
        t = { kind: 'file', owner, repo, ref, path };
      } else if (mode === 'tree') {
        const [ref, path] = segs.length > 3 ? refAndPath(segs.slice(3)) : [null, ''];
        t = path ? { kind: 'dir', owner, repo, ref, path } : { kind: 'repo', owner, repo, ref, path: '' };
      } else throw new GitHubRefError('invalid-url', `GitHub pages of type “${mode}” do not point at source files.`);
    }
  } else if (host === 'api.github.com') {
    if (segs[0] !== 'repos' || segs.length < 5 || segs[3] !== 'contents') throw new GitHubRefError('invalid-url', 'Only the repository contents API (/repos/OWNER/REPO/contents/PATH) is understood.');
    const ref = u.searchParams.get('ref');
    if (ref !== null && (!ref || /[\x00-\x1f\x7f]|\.\./.test(ref))) throw new GitHubRefError('invalid-url', 'The ref parameter is not valid.');
    t = { kind: 'file', owner: checkOwner(segs[1]), repo: checkRepo(segs[2]), ref: ref || null, path: segs.slice(4).join('/') };
  } else {
    // gists: gist.github.com/OWNER/ID, gist.github.com/ID, gist.githubusercontent.com/OWNER/ID/raw[/SHA][/FILE]
    const idAt = segs.findIndex((s) => GIST.test(s));
    if (idAt < 0) throw new GitHubRefError('invalid-url', 'The link names no gist.');
    const owner = idAt > 0 ? checkOwner(segs[0]) : null;
    const rest = segs.slice(idAt + 1);
    const file = rest[0] === 'raw' ? rest.filter((s, i) => i > 0 && !GIST.test(s)).pop() || null : null;
    t = { kind: 'gist', owner, gist: segs[idAt].toLowerCase(), file };
  }
  if (t.ref && (/[\x00-\x1f\x7f~^:?*[\\]|\.\.|@\{/.test(t.ref) || t.ref.length > 200)) throw new GitHubRefError('invalid-url', 'The branch or tag name is not valid.');
  return { ...t, urls: urlsFor(t) };
}

/** Is this text a link to GitHub (alone, nothing else)? */
export function isGitHubLink(text) {
  const s = String(text || '').trim();
  if (!s || /\s/.test(s)) return false;
  try { parseGitHubRef(s); return true; } catch { return false; }
}

const URL_IN_TEXT = /https?:\/\/(?:www\.)?(?:github\.com|raw\.githubusercontent\.com|api\.github\.com|gist\.github\.com|gist\.githubusercontent\.com)\/[^\s"'`<>()\]\[]+/gi;

/** Every GitHub reference written out in a text (a loader, a README), parsed; unparseable ones are reported with the reason. */
export function findGitHubRefs(text) {
  const seen = new Set();
  const refs = [];
  for (const m of String(text || '').matchAll(URL_IN_TEXT)) {
    const url = m[0].replace(/[.,;]+$/, '');
    if (seen.has(url)) continue;
    seen.add(url);
    try { refs.push({ url, ...parseGitHubRef(url) }); } catch (e) { refs.push({ url, error: e.message }); }
  }
  return refs;
}

/**
 * What kind of input the user submitted, so the right pipeline runs:
 *   github-link    a link to a GitHub file, directory, repository, profile or gist (retrieve, then reconstruct)
 *   link           some other single link (the general link fetcher)
 *   loader         a script whose program is fetched at run time (loadstring(game:HttpGet(...)) and the like): loader analysis
 *   bytecode       a compiled chunk
 *   script         anything else: the deobfuscation pipeline
 *   empty
 * The loader test is deliberately the cheap textual one; the loader analysis decides properly once it runs.
 */
export function recognizeInput(text) {
  const s = String(text || '');
  const t = s.trim();
  if (!t) return { kind: 'empty' };
  if (t.charCodeAt(0) === 27) return { kind: 'bytecode' };
  if (!/\s/.test(t) && /^(?:https?:\/\/)?[\w.-]+\.[a-z]{2,}\//i.test(t)) {
    try { const ref = parseGitHubRef(t); return { kind: 'github-link', ref }; } catch (e) {
      if (e.code === 'invalid-url' && /github/i.test(t)) return { kind: 'github-link', error: e.message };
      return { kind: 'link' };
    }
  }
  const fetches = /\b(?:HttpGet(?:Async)?|HttpPost|GetAsync|RequestAsync|request|http_request|syn\.request)\b/.test(t);
  const executes = /\b(?:loadstring|load)\s*\(/.test(t);
  if (fetches && executes && t.length < 20000) return { kind: 'loader', github: findGitHubRefs(t).filter((r) => !r.error) };
  return { kind: 'script' };
}

/**
 * Is a retrieved body Lua (or Luau, or a compiled chunk)? A 200 that carries an HTML page, a JSON error, an empty body or binary data is not.
 * @param {Uint8Array|string} body
 * @param {{contentType?: string, parses?: (text: string) => boolean}} [opts] parses: the caller's parser (the page and the server pass ours)
 */
export function contentClass(body, opts = {}) {
  const bytes = typeof body === 'string' ? null : body;
  const n = bytes ? bytes.length : body.length;
  if (!n) return { lua: false, kind: 'empty', reason: 'The file is empty.' };
  const at = (i) => (bytes ? bytes[i] : body.charCodeAt(i) & 255);
  if (at(0) === 0x1b && at(1) === 0x4c && at(2) === 0x75 && at(3) === 0x61) return { lua: true, kind: 'bytecode', reason: 'A compiled Lua chunk.' };
  let text = '';
  const m = Math.min(n, 65536);
  if (bytes) { for (let i = 0; i < m; i++) text += String.fromCharCode(bytes[i]); } else text = body.slice(0, m);
  let ctrl = 0;
  for (let i = 0; i < text.length; i++) { const c = text.charCodeAt(i); if (c < 9 || (c > 13 && c < 32)) ctrl++; }
  if (ctrl / text.length > 0.05) return { lua: false, kind: 'binary', reason: 'The file is binary data, not source text.' };
  const head = text.replace(/^﻿/, '').trimStart().slice(0, 400);
  if (/^<(?:!doctype|html|head|body|\?xml)/i.test(head) || /text\/html/i.test(opts.contentType || '')) return { lua: false, kind: 'html', reason: 'GitHub answered with a web page, not the file (a login page, an error page or a page that is not a raw file).' };
  if (/^\{[\s\S]*"message"\s*:/.test(head) && /documentation_url|"status"/.test(text.slice(0, 2000))) return { lua: false, kind: 'json-error', reason: 'GitHub answered with an error message, not the file.' };
  if (/^404: Not Found\s*$/.test(text.trim())) return { lua: false, kind: 'not-found-text', reason: 'GitHub answered “404: Not Found”.' };
  const full = bytes ? null : body;
  const parses = opts.parses && n <= 4 * 1024 * 1024 ? opts.parses(full ?? (bytes ? decodeLatin1(bytes) : '')) : null;
  if (parses === true) return { lua: true, kind: 'lua', reason: 'Lua / Luau source that parses.' };
  // without a parse, look for the shape of Lua: keywords, calls, assignments
  const luaish = (text.match(/\b(?:local|function|end|then|return|if|for|while|do|nil|true|false)\b/g) || []).length;
  if (parses === false && luaish >= 3) return { lua: true, kind: 'lua-invalid', reason: 'Lua-like source that does not parse (incomplete, damaged, or a dialect this parser does not read).' };
  if (parses === null && luaish >= 3) return { lua: true, kind: 'lua', reason: 'Lua-like source (not parsed).' };
  return { lua: false, kind: 'text', reason: 'The file is text, but not Lua or Luau source.' };
}

function decodeLatin1(bytes) { let s = ''; for (let i = 0; i < bytes.length; i += 8192) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 8192)); return s; }

/**
 * Why a file read failed, from the answers GitHub gave to the probes api/github.js makes. Pure: the server passes the HTTP statuses (and
 * headers it needs); the tests pass the same shapes. Each probe is `{status, headers?}` or undefined when it was not made.
 *   raw       the raw file                       (raw.githubusercontent.com)
 *   repo      GET /repos/OWNER/REPO               (api.github.com)
 *   owner     GET /users/OWNER
 *   contents  GET /repos/OWNER/REPO/contents/PATH?ref=REF
 *   branch    GET /repos/OWNER/REPO/branches/REF
 * @returns {{outcome: string, message: string, retryAfter?: number}}
 */
export function diagnoseFailure(p, { token = false } = {}) {
  const rateLimited = (x) => x && (x.status === 429 || (x.status === 403 && String(hdr(x, 'x-ratelimit-remaining')) === '0'));
  for (const x of [p.raw, p.repo, p.owner, p.contents, p.branch]) {
    if (rateLimited(x)) {
      const reset = Number(hdr(x, 'x-ratelimit-reset')) || 0;
      const retry = Number(hdr(x, 'retry-after')) || (reset ? Math.max(0, Math.round(reset - Date.now() / 1000)) : 60);
      return { outcome: 'rate-limited', message: `GitHub’s rate limit for this server is used up; try again in about ${Math.ceil(retry / 60)} minute(s)${token ? '' : ', or add your own GitHub token'}.`, retryAfter: retry };
    }
  }
  for (const x of [p.raw, p.repo, p.contents]) if (x && x.status === 451) return { outcome: 'legal-block', message: 'GitHub has made this repository unavailable for legal reasons (HTTP 451, typically a DMCA takedown).' };
  for (const x of [p.repo, p.contents, p.owner]) if (x && x.status === 401) return { outcome: 'token-rejected', message: 'GitHub rejected the token (expired, revoked or mistyped). Nothing was retrieved.' };
  if (p.raw && p.raw.status === 413) return { outcome: 'too-large', message: 'The file is larger than this tool reads.' };
  if (p.repo && p.repo.status === 404) {
    if (p.owner && p.owner.status === 404) return { outcome: 'owner-not-found', message: 'There is no GitHub account by that name: it was deleted, renamed, or never existed.' };
    return token
      ? { outcome: 'not-found-with-token', message: 'GitHub reports no such repository for your token: it was deleted or renamed, or the token was not given access to it.' }
      : { outcome: 'private-or-missing', message: 'GitHub reports no such public repository. It is either private (GitHub answers the same way for private repositories), deleted, or never existed. If it is yours and private, add a GitHub token with read access to it.' };
  }
  if (p.repo && p.repo.status === 409) return { outcome: 'repo-empty', message: 'The repository exists but has no commits.' };
  if (p.repo && p.repo.status === 200) {
    if (p.branch && p.branch.status === 404) return { outcome: 'ref-missing', message: 'The repository exists, but it has no branch or tag by that name.' };
    if (p.contents && p.contents.status === 404) return { outcome: 'file-missing', message: 'The repository exists, but that file is not in it (moved, renamed or deleted, or the path is spelled differently).' };
    if (p.contents && p.contents.status === 200 && p.contents.isDir) return { outcome: 'is-directory', message: 'The address is a folder; choose a file from its listing.' };
  }
  if (p.raw && p.raw.status === 404 && !p.repo) return { outcome: 'unavailable', message: 'The raw file answered 404, and GitHub’s API could not be asked why (the file, the branch or the repository is missing, or the repository is private).' };
  const s = (p.raw && p.raw.status) || (p.repo && p.repo.status) || 0;
  return { outcome: 'unavailable', message: s ? `GitHub answered HTTP ${s}.` : 'GitHub could not be reached.' };
}

function hdr(x, name) {
  const h = x && x.headers;
  if (!h) return undefined;
  if (typeof h.get === 'function') return h.get(name);
  const k = Object.keys(h).find((n) => n.toLowerCase() === name);
  return k ? h[k] : undefined;
}

/** Which files of a repository tree are worth listing: Lua/Luau sources, then text files that may hold Lua, never vendored folders' bulk. */
export function luaFilesOfTree(tree, { max = 300 } = {}) {
  const items = (tree || []).filter((x) => x && x.type === 'blob' && typeof x.path === 'string');
  const score = (p) => (/\.(?:lua|luau)$/i.test(p) ? 0 : /\.txt$/i.test(p) ? 1 : 9);
  return items.filter((x) => score(x.path) < 9 && !/(?:^|\/)(?:node_modules|\.git)\//.test(x.path))
    .sort((a, b) => score(a.path) - score(b.path) || a.path.localeCompare(b.path))
    .slice(0, max)
    .map((x) => ({ path: x.path, size: x.size ?? null, sha: x.sha || null, likelyLoader: /loader|main|init|load/i.test(x.path.split('/').pop()) }));
}
