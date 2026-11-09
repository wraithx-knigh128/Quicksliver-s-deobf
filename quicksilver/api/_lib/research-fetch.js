// Research fetching: public sources only, with limits that keep it from being a proxy and from being turned on private networks.
//
// Policy, not capability: the host list is what this tool is *permitted* to read. Whether a host is reachable from where the code runs is a separate
// fact (a sandbox may block it), and a refusal by the network is recorded as such, never replaced by a guess.
//
//   * https only, no credentials in the URL, no port, no IP literals;
//   * only hosts on the list, and redirects only to hosts on the list;
//   * text-like content types only, a size cap enforced while reading, a deadline;
//   * robots.txt is read for hosts that publish one and a Disallow for our user agent is honoured (GitHub raw content has none);
//   * one request per host per second.

export const USER_AGENT = 'QuickSilver-Research/1.0 (source-intelligence; read-only; contact via the project repository)';

/** Hosts the research service may read. `QS_RESEARCH_HOSTS` (comma separated) adds to this list; it never removes from it. */
export const DEFAULT_HOSTS = [
  'raw.githubusercontent.com', 'gist.githubusercontent.com', 'github.com', 'gist.github.com',
  'lura.ph', 'prometheus-lua.github.io', 'luau.org', 'luau-lang.org', 'www.lua.org', 'luajit.org',
  'git.openpunk.com', 'devforum.roblox.com', 'birk.blog', 'pypi.org', 'registry.npmjs.org',
];

export class ResearchFetchError extends Error {
  constructor(message, code = 'refused', status = 400) { super(message); this.code = code; this.status = status; }
}

export function permittedHosts(env = process.env) {
  const extra = String(env.QS_RESEARCH_HOSTS || '').split(',').map((h) => h.trim().toLowerCase()).filter((h) => /^[a-z0-9.-]+$/.test(h));
  return new Set([...DEFAULT_HOSTS, ...extra]);
}

const isIpLiteral = (h) => /^\d{1,3}(\.\d{1,3}){3}$/.test(h) || h.includes(':') || /^\[.*\]$/.test(h);

/** Validate a URL against the policy and turn a GitHub page link into the raw file link. */
export function normalizeResearchUrl(input, hosts = permittedHosts()) {
  let u;
  try { u = new URL(String(input).trim()); } catch { throw new ResearchFetchError('That is not a valid URL.', 'bad_url'); }
  if (u.protocol !== 'https:') throw new ResearchFetchError('Only https URLs are read.', 'bad_url');
  if (u.username || u.password) throw new ResearchFetchError('URLs with credentials are refused.', 'bad_url');
  if (u.port) throw new ResearchFetchError('URLs with a port are refused.', 'bad_url');
  const host = u.hostname.toLowerCase();
  if (isIpLiteral(host) || host === 'localhost' || !host.includes('.')) throw new ResearchFetchError('Only named public hosts are read.', 'bad_url');
  if (!hosts.has(host)) throw new ResearchFetchError(`${host} is not on the research host list.`, 'host_not_permitted');
  const m = host === 'github.com' ? u.pathname.match(/^\/([^/]+)\/([^/]+)\/(?:blob|raw)\/(.+)$/) : null;
  if (m) u = new URL(`https://raw.githubusercontent.com/${m[1]}/${m[2]}/${m[3]}`);
  return u;
}

const lastRequest = new Map();
async function politely(host, minGapMs) {
  const wait = (lastRequest.get(host) || 0) + minGapMs - Date.now();
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  lastRequest.set(host, Date.now());
}

/** Does robots.txt of this host forbid this path for us? Unreachable or absent robots.txt means no restriction was published. */
export async function robotsAllows(url, { fetchImpl = fetch, timeoutMs = 8000 } = {}) {
  const host = new URL(url).hostname;
  if (host.endsWith('githubusercontent.com') || host === 'github.com') return true;
  try {
    const res = await fetchImpl(`https://${host}/robots.txt`, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(timeoutMs), redirect: 'manual' });
    if (!res.ok) return true;
    const text = (await res.text()).slice(0, 100_000);
    let applies = false;
    const path = new URL(url).pathname;
    for (const raw of text.split(/\r?\n/)) {
      const line = raw.replace(/#.*/, '').trim();
      const [k, ...rest] = line.split(':');
      const v = rest.join(':').trim();
      if (/^user-agent$/i.test(k)) applies = v === '*' || /quicksilver/i.test(v);
      else if (applies && /^disallow$/i.test(k) && v && path.startsWith(v)) return false;
    }
    return true;
  } catch { return true; }
}

const TEXTUAL = /^(text\/|application\/(json|xml|javascript|x-yaml|toml|markdown)|application\/.*\+(json|xml))/i;

/**
 * Read one URL as text under the policy.
 * @returns {Promise<{url: string, finalUrl: string, status: number, contentType: string, text: string, bytes: number, truncated: boolean}>}
 */
export async function fetchText(input, { fetchImpl = fetch, hosts = permittedHosts(), maxBytes = 2 * 1024 * 1024, timeoutMs = 20_000, minGapMs = 1000, honourRobots = true } = {}) {
  let current = normalizeResearchUrl(input, hosts);
  const original = current.toString();
  if (honourRobots && !(await robotsAllows(current.toString(), { fetchImpl }))) throw new ResearchFetchError('robots.txt forbids reading this path.', 'robots_disallowed', 403);
  const deadline = Date.now() + timeoutMs;
  for (let hop = 0; hop < 4; hop++) {
    const left = deadline - Date.now();
    if (left <= 0) throw new ResearchFetchError('The site took too long to answer.', 'timeout', 504);
    await politely(current.hostname, minGapMs);
    let res;
    try {
      res = await fetchImpl(current.toString(), { redirect: 'manual', signal: AbortSignal.timeout(left), headers: { 'User-Agent': USER_AGENT, Accept: 'text/plain, text/markdown, text/html, application/json;q=0.9, */*;q=0.1' } });
    } catch (e) {
      if (e && e.name === 'TimeoutError') throw new ResearchFetchError('The site took too long to answer.', 'timeout', 504);
      // a refusal by the network (DNS, an egress proxy that does not allow the host) surfaces as "fetch failed" with a cause such as "Request was cancelled"
      const why = `${e && e.message} ${e && e.cause && e.cause.message} ${e && e.cause && e.cause.code}`;
      const blocked = /ENOTFOUND|EAI_AGAIN|ECONNREFUSED|refused|fetch failed|cancelled|tunnel|proxy/i.test(why);
      throw new ResearchFetchError(blocked ? 'The host could not be reached from here (DNS or network policy).' : 'The request failed.', blocked ? 'unreachable' : 'network', 502);
    }
    if (res.status >= 300 && res.status < 400) {
      const loc = res.headers.get('location');
      let next;
      try { next = normalizeResearchUrl(new URL(loc, current).toString(), hosts); } catch { throw new ResearchFetchError('The site redirects somewhere the policy does not allow.', 'redirect_refused', 400); }
      current = next;
      continue;
    }
    if (!res.ok) throw new ResearchFetchError(`The site answered ${res.status}.`, res.status === 404 ? 'not_found' : res.status === 429 ? 'rate_limited' : 'http_error', res.status === 404 ? 404 : 502);
    const type = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (type && !TEXTUAL.test(type)) throw new ResearchFetchError(`Content type ${type} is not text.`, 'not_text', 415);
    const declared = Number(res.headers.get('content-length') || 0);
    if (declared > maxBytes * 4) throw new ResearchFetchError('The document is far larger than the size limit.', 'too_large', 413);
    const chunks = [];
    let got = 0;
    let truncated = false;
    const reader = res.body.getReader();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      got += value.length;
      if (got > maxBytes) { chunks.push(value.slice(0, value.length - (got - maxBytes))); truncated = true; await reader.cancel(); break; }
      chunks.push(value);
    }
    const bytes = Buffer.concat(chunks);
    return { url: original, finalUrl: current.toString(), status: res.status, contentType: type, text: bytes.toString('utf8'), bytes: bytes.length, truncated };
  }
  throw new ResearchFetchError('Too many redirects.', 'redirect_refused', 400);
}
