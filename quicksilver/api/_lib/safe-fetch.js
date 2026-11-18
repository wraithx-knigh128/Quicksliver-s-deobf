// Fetching on behalf of the page, with the limits that keep it from being used as an open proxy:
// https only, a short list of hosts, no credentials in the URL, no ports, redirects followed only to the same list,
// a size cap that is enforced while reading, and a deadline.

export const ALLOWED_HOSTS = new Set([
  'raw.githubusercontent.com',
  'gist.githubusercontent.com',
  'github.com',
  'gist.github.com',
  'pastebin.com',
  'rentry.co',
  'paste.ee',
  'cdn.discordapp.com',
  'media.discordapp.net',
]);

export class FetchRefused extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}

/** Turn a link to a page into the link to the raw file, and refuse anything that is not an allowed https URL. */
export function normalizeUrl(input) {
  let u;
  try { u = new URL(String(input).trim()); } catch { throw new FetchRefused('That is not a valid link.'); }
  if (u.protocol !== 'https:') throw new FetchRefused('Only https links are allowed.');
  if (u.username || u.password) throw new FetchRefused('Links with a user name or password are not allowed.');
  if (u.port) throw new FetchRefused('Links with a port are not allowed.');
  const host = u.hostname.toLowerCase();
  if (!ALLOWED_HOSTS.has(host)) throw new FetchRefused(`${host} is not on the list of sites this tool will fetch from (${[...ALLOWED_HOSTS].join(', ')}).`);

  let m;
  if (host === 'github.com' && (m = u.pathname.match(/^\/([^/]+)\/([^/]+)\/(?:blob|raw)\/(.+)$/))) {
    u = new URL(`https://raw.githubusercontent.com/${m[1]}/${m[2]}/${m[3]}`);
  } else if (host === 'gist.github.com' && (m = u.pathname.match(/^\/([^/]+)\/([0-9a-f]+)\/?$/i))) {
    u = new URL(`https://gist.githubusercontent.com/${m[1]}/${m[2]}/raw`);
  } else if (host === 'pastebin.com' && (m = u.pathname.match(/^\/([A-Za-z0-9]{6,12})$/))) {
    u = new URL(`https://pastebin.com/raw/${m[1]}`);
  } else if (host === 'rentry.co' && (m = u.pathname.match(/^\/([A-Za-z0-9_-]+)\/?$/))) {
    u = new URL(`https://rentry.co/${m[1]}/raw`);
  } else if (host === 'paste.ee' && (m = u.pathname.match(/^\/p\/([A-Za-z0-9]+)$/))) {
    u = new URL(`https://paste.ee/r/${m[1]}`);
  }
  return u;
}

/**
 * GET with redirects restricted to the allowed hosts. Returns { bytes: Uint8Array, type, url }.
 * @param {string|URL} url already normalised
 */
export async function safeGet(url, { fetchImpl = fetch, maxBytes = 4 * 1024 * 1024, timeoutMs = 10_000, headers = {}, credentialFor = null } = {}) {
  let current = new URL(url);
  const deadline = Date.now() + timeoutMs;
  for (let hop = 0; hop < 4; hop++) {
    const left = deadline - Date.now();
    if (left <= 0) throw new FetchRefused('The site took too long to answer.', 504);
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), left);
    let res;
    try {
      // an owner-configured credential is attached only to the URL it was configured for, re-checked on every hop, so a redirect cannot carry it elsewhere
      const cred = credentialFor ? credentialFor(current) : null;
      res = await fetchImpl(current.toString(), { redirect: 'manual', signal: ctl.signal, headers: { 'User-Agent': 'QuickSilver', Accept: '*/*', ...headers, ...(cred || {}) } });
    } catch (e) {
      clearTimeout(timer);
      throw new FetchRefused(e && e.name === 'AbortError' ? 'The site took too long to answer.' : 'Could not reach the site.', 502);
    }
    if (res.status >= 300 && res.status < 400) {
      clearTimeout(timer);
      const loc = res.headers.get('location');
      if (!loc) throw new FetchRefused('The site sent a redirect without a destination.', 502);
      let next;
      try { next = new URL(loc, current); } catch { throw new FetchRefused('The site sent an invalid redirect.', 502); }
      if (next.protocol !== 'https:' || next.username || next.password || next.port || !ALLOWED_HOSTS.has(next.hostname.toLowerCase())) {
        throw new FetchRefused('The link redirects somewhere this tool will not follow.', 400);
      }
      current = next;
      continue;
    }
    // the upstream status is kept where it means something to the next stage: 401/403 is an authorisation answer, 404 an absent file;
    // everything else is the site failing (502)
    if (!res.ok) {
      clearTimeout(timer);
      if (res.status === 401 || res.status === 403) throw new FetchRefused(`The site refused access (HTTP ${res.status}): this file needs an authorisation this tool does not have.`, 403);
      throw new FetchRefused(`The site answered ${res.status}.`, res.status === 404 ? 404 : 502);
    }
    const declared = Number(res.headers.get('content-length') || 0);
    if (declared > maxBytes) { clearTimeout(timer); throw new FetchRefused(`The file is larger than ${Math.round(maxBytes / 1024 / 1024)} MB.`, 413); }
    const chunks = [];
    let total = 0;
    if (!res.body) { clearTimeout(timer); return { bytes: new Uint8Array(0), type: res.headers.get('content-type') || '', url: current.toString() }; }
    try {
      const reader = res.body.getReader();
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.length;
        if (total > maxBytes) { ctl.abort(); throw new FetchRefused(`The file is larger than ${Math.round(maxBytes / 1024 / 1024)} MB.`, 413); }
        chunks.push(value);
      }
    } catch (e) {
      if (e instanceof FetchRefused) throw e;
      throw new FetchRefused('The download was interrupted.', 502);
    } finally { clearTimeout(timer); }
    // a body shorter than the length the server declared is a cut-off transfer, not a smaller file. (With a content-encoding the declared
    // length counts the compressed bytes and fetch has already decoded them, so the comparison only holds for an unencoded body.)
    if (declared && !res.headers.get('content-encoding') && total !== declared) throw new FetchRefused(`The download ended early: ${total} of ${declared} bytes arrived.`, 502);
    const bytes = new Uint8Array(total);
    let at = 0;
    for (const c of chunks) { bytes.set(c, at); at += c.length; }
    return { bytes, type: res.headers.get('content-type') || '', url: current.toString() };
  }
  throw new FetchRefused('Too many redirects.', 508);
}

/**
 * Owner-configured credentials for /api/fetch (off unless configured). QS_FETCH_AUTH is a JSON array of
 *   { "host": "raw.githubusercontent.com", "pathPrefix": "/owner/private-repo/", "header": "Authorization", "scheme": "token", "secretEnv": "QS_FETCH_SECRET_1" }
 * The secret itself lives in the environment variable named by secretEnv; it is never part of the configuration, a response or an error.
 * Only hosts already on ALLOWED_HOSTS can be configured: credentials never widen what the fetcher can reach.
 * Returns { rules, credentialFor(url) } or null when nothing (valid) is configured.
 */
export function authConfig(env = process.env) {
  if (!env.QS_FETCH_AUTH) return null;
  let list;
  try { list = JSON.parse(env.QS_FETCH_AUTH); } catch { return null; }
  if (!Array.isArray(list)) return null;
  const rules = [];
  for (const r of list) {
    if (!r || typeof r !== 'object') continue;
    const host = String(r.host || '').toLowerCase();
    const prefix = String(r.pathPrefix || '');
    const header = String(r.header || 'Authorization');
    const secret = r.secretEnv && env[r.secretEnv];
    if (!ALLOWED_HOSTS.has(host) || !prefix.startsWith('/') || prefix.length < 2 || !/^[A-Za-z][A-Za-z0-9-]{0,40}$/.test(header) || !secret) continue;
    rules.push({ host, prefix, header, value: r.scheme ? `${String(r.scheme)} ${secret}` : String(secret) });
  }
  if (!rules.length) return null;
  return {
    rules: rules.map(({ host, prefix, header }) => ({ host, prefix, header })),
    credentialFor(url) {
      const u = new URL(url);
      const rule = rules.find((x) => u.protocol === 'https:' && u.hostname.toLowerCase() === x.host && u.pathname.startsWith(x.prefix));
      return rule ? { [rule.header]: rule.value } : null;
    },
  };
}
