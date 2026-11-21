// GitHub retrieval in the page: a link (file, folder, repository, profile or gist) → /api/github → the file in the editor, or a listing to pick
// from. The visitor's own GitHub token (for their private repositories) is optional, is kept only in this tab's memory, and is sent only to
// this site's /api/github, which sends it only to GitHub (api/github.js). Every answer that is not a retrieved Lua file is shown as what it is.

import { h, modal, fmtBytes } from './dom.js';
import { serverFetch, licenceRefusal } from './server.js';
import { parseGitHubRef, OUTCOMES } from '../loader/github.js';

let sessionToken = '';   // this tab only; never written to storage

const b64ToBytes = (b64) => { const s = atob(b64); const u = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i); return u; };

/** One request to /api/github. Returns the server's JSON, or a local error in the same shape. */
export async function githubRequest(url, { mode = 'auto', token = sessionToken } = {}) {
  let res;
  try {
    res = await serverFetch('/api/github', { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { 'x-github-token': token } : {}) }, body: JSON.stringify({ url, mode }) });
  } catch (e) {
    return { ok: false, outcome: 'unavailable', message: `The site could not be reached: ${e.message || e}` };
  }
  let body = null;
  try { body = await res.json(); } catch { /* not JSON */ }
  if (!body) return { ok: false, outcome: 'unavailable', message: res.status === 404 ? 'GitHub retrieval needs the deployed site (its /api/github function); it is not available on this server.' : `The server answered ${res.status}.` };
  const lic = licenceRefusal(res.status, body);
  if (lic) return { ...body, ok: false, outcome: body.outcome || 'licence', message: lic };
  if (body.ok && body.file && body.file.base64) body.file.bytes = b64ToBytes(body.file.base64);
  return body;
}

/** The label for an outcome code (the server's, or the shared table's). */
export const outcomeLabel = (r) => r.label || (OUTCOMES[r.outcome] ? OUTCOMES[r.outcome].label : r.outcome);

/** Pick one file from a listing. Resolves to the chosen file's GitHub link, or null. */
async function pickFromListing(listing) {
  if (listing.kind === 'profile') {
    const repos = listing.repositories || [];
    const list = h('ul.gh-list', repos.map((r) => h('li', h('button.btn.chip', { type: 'button', 'data-url': `https://github.com/${listing.owner}/${r.name}` }, r.name), r.language ? h('span.faint', ` ${r.language}`) : null, r.description ? h('span.faint', ` — ${r.description}`) : null)));
    let chosen = null;
    list.addEventListener('click', (e) => { const b = e.target.closest('button[data-url]'); if (b) { chosen = b.dataset.url; b.closest('.modal')?.querySelector('.mfoot .primary')?.click(); } });
    const r = await modal({
      title: `Repositories of ${listing.owner}`,
      body: [h('p', listing.onlyLua ? `Public Lua / Luau repositories (${repos.length} of ${listing.total}). Choose one to list its files; nothing is downloaded until you choose a file.` : `No public repository is marked Lua or Luau; all ${repos.length} public repositories are listed.`), list],
      buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'ok', label: 'Open', primary: true }],
    });
    if (r !== 'ok' || !chosen) return null;
    const next = await githubRequest(chosen, { mode: 'listing' });
    if (!next.ok) { await showFailure(next); return null; }
    return pickFromListing(next.listing);
  }
  const files = listing.files || [];
  if (!files.length) { await modal({ title: 'No Lua files', body: [h('p', `No .lua, .luau or .txt file was found in ${listing.owner}/${listing.repo}${listing.path ? `/${listing.path}` : ''}.`)], buttons: [{ id: 'ok', label: 'Close', primary: true }] }); return null; }
  let chosen = null;
  const ref = listing.ref || 'HEAD';
  const list = h('ul.gh-list', files.map((f) => h('li', h('button.btn.chip', { type: 'button', 'data-path': f.path }, f.path), f.size != null ? h('span.faint', ` ${fmtBytes(f.size)}`) : null, f.likelyLoader ? h('span.badge.info', ' entry point?') : null)));
  list.addEventListener('click', (e) => { const b = e.target.closest('button[data-path]'); if (b) { chosen = b.dataset.path; b.closest('.modal')?.querySelector('.mfoot .primary')?.click(); } });
  const r = await modal({
    title: `${listing.owner}/${listing.repo}`,
    body: [h('p', `${files.length} Lua / Luau file(s)${listing.truncated ? ' (GitHub truncated the tree; very large repositories are listed in part)' : ''}. Choose the file to retrieve.`), list],
    buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'ok', label: 'Retrieve', primary: true }],
  });
  if (r !== 'ok' || !chosen) return null;
  return `https://github.com/${listing.owner}/${listing.repo}/blob/${ref}/${chosen.split('/').map(encodeURIComponent).join('/')}`;
}

export async function showFailure(r) {
  const privateHint = r.outcome === 'private-or-missing' || r.outcome === 'not-found-with-token';
  await modal({
    title: outcomeLabel(r),
    body: [h('p', r.message || ''), privateHint ? h('p.note.info', 'If the repository is yours and private, add a fine-grained GitHub token with read-only “Contents” access to it, and try again. The token is used for this tab only.') : null, r.retryAfter ? h('p.note', `Retry in about ${Math.ceil(r.retryAfter / 60)} minute(s).`) : null].filter(Boolean),
    buttons: [{ id: 'ok', label: 'Close', primary: true }],
  });
}

/**
 * The whole flow for one link. `onFile(name, bytes, meta)` receives a retrieved Lua file. Returns the final server answer.
 * @param {string} url
 * @param {{onFile: Function, setBusy?: Function}} ctx
 */
export async function retrieveGitHub(url, ctx) {
  let target;
  try { target = parseGitHubRef(url); } catch (e) { await showFailure({ outcome: 'invalid-url', message: e.message }); return { ok: false, outcome: 'invalid-url' }; }
  const busy = ctx.setBusy || (() => {});
  busy('Retrieving from GitHub');
  try {
    let r = await githubRequest(url, { mode: target.kind === 'file' || target.kind === 'gist' ? 'file' : 'listing' });
    if (r.ok && r.outcome === 'listing') {
      busy(null);
      const chosen = await pickFromListing(r.listing);
      if (!chosen) return r;
      busy('Retrieving from GitHub');
      r = await githubRequest(chosen, { mode: 'file' });
    }
    if (!r.ok) { busy(null); await showFailure(r); return r; }
    await ctx.onFile(r.file.name, r.file.bytes, { source: 'github', target: r.target, sha256: r.file.sha256, contentClass: r.file.contentClass, contentReason: r.file.contentReason });
    return r;
  } finally { busy(null); }
}

/** The link dialog's GitHub part: an optional token field (kept for this tab only). */
export function tokenField() {
  const input = h('input', { type: 'password', autocomplete: 'off', spellcheck: 'false', placeholder: 'Optional: your GitHub token, for your private repositories', 'aria-label': 'GitHub token (optional)', value: sessionToken, style: { width: '100%', marginTop: '8px' } });
  input.addEventListener('change', () => { sessionToken = input.value.trim(); });
  return input;
}
export const setSessionToken = (t) => { sessionToken = String(t || '').trim(); };
