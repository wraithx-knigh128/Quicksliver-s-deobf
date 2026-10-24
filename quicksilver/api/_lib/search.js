// Searching public code for lines of a script.
//
// One provider is implemented: GitHub's code search (https://docs.github.com/en/rest/search/search#search-code), which needs
// a token of the site owner (QS_ORIGIN_GITHUB_TOKEN). Each fingerprint is searched as an exact phrase restricted to Lua.
// The files that match most fingerprints are then fetched from raw.githubusercontent.com and reduced to a list of line hashes,
// so the page can count how much of the user's script appears in them without the server ever holding the script.
//
// Not verified against the live API from the development environment (it blocks api.github.com); the parsing is covered by
// tests with recorded-shape responses. Rate limits are respected and reported, never worked around.

import { normalizeLine, hashLine } from '../../src/origin/lines.js';
import { safeGet } from './safe-fetch.js';

const API = 'https://api.github.com/search/code';
const wordsOf = (s) => (s.toLowerCase().match(/[a-z0-9_]+/g) || []);

/** GitHub matches tokens loosely; keep only results whose fragment really contains the phrase's words in order-insensitive bulk. */
export function fragmentContains(fragment, query) {
  const have = new Set(wordsOf(fragment));
  const need = wordsOf(query);
  if (!need.length) return false;
  return need.filter((w) => have.has(w)).length / need.length >= 0.85;
}

/**
 * @param {{query: string}[]} fingerprints
 * @returns {Promise<{matches: {repo, path, url, rawUrl, hits: number[]}[], queried: number, note: string|null}>}
 */
export async function searchGitHub(fingerprints, { token, fetchImpl = fetch, delayMs = 1100, sleep = (ms) => new Promise((r) => setTimeout(r, ms)) } = {}) {
  const files = new Map();
  let note = null;
  let queried = 0;
  for (let i = 0; i < fingerprints.length; i++) {
    if (i) await sleep(delayMs);
    const q = `"${fingerprints[i].query}" language:Lua`;
    let res;
    try {
      res = await fetchImpl(`${API}?q=${encodeURIComponent(q)}&per_page=8`, {
        headers: {
          Accept: 'application/vnd.github.text-match+json',
          Authorization: `Bearer ${token}`,
          'User-Agent': 'QuickSilver',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      });
    } catch { note = 'GitHub could not be reached.'; break; }
    if (res.status === 401) { note = 'The GitHub token on this site was rejected.'; break; }
    if (res.status === 403 || res.status === 429) {
      const reset = res.headers.get('x-ratelimit-reset');
      note = `GitHub's search rate limit was reached${reset ? ` (resets at ${new Date(Number(reset) * 1000).toISOString()})` : ''}; the result covers ${queried} of ${fingerprints.length} lines.`;
      break;
    }
    if (!res.ok) { note = `GitHub answered ${res.status}.`; break; }
    queried++;
    let body;
    try { body = await res.json(); } catch { continue; }
    for (const item of body.items || []) {
      const repo = item.repository && item.repository.full_name;
      if (!repo || !item.path) continue;
      const fragments = (item.text_matches || []).map((t) => t.fragment || '');
      if (!fragments.some((f) => fragmentContains(f, fingerprints[i].query))) continue;
      const key = `${repo}/${item.path}`;
      if (!files.has(key)) files.set(key, { repo, path: item.path, url: item.html_url, hits: new Set() });
      files.get(key).hits.add(i);
    }
  }
  const matches = [...files.values()].map((f) => ({ ...f, hits: [...f.hits].sort((a, b) => a - b) })).sort((a, b) => b.hits.length - a.hits.length).slice(0, 5);
  return { matches, queried, note };
}

/** Line hashes of a public file, from its raw URL (page URL -> raw by the usual pattern). */
export async function hashesOf(match, { fetchImpl = fetch } = {}) {
  const raw = `https://raw.githubusercontent.com/${match.repo}/HEAD/${match.path.split('/').map(encodeURIComponent).join('/')}`;
  const { bytes } = await safeGet(raw, { fetchImpl, maxBytes: 1_500_000, timeoutMs: 8000 });
  let text = '';
  for (let i = 0; i < bytes.length; i += 8192) text += String.fromCharCode(...bytes.subarray(i, i + 8192));
  const out = new Set();
  for (const row of text.split(/\r?\n/)) {
    const t = normalizeLine(row);
    if (t.length >= 16) out.add(hashLine(t));
    if (out.size >= 40_000) break;
  }
  return [...out];
}
