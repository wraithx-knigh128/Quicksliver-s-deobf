// Owner-authorised retrieval providers for /api/retrieve.
//
// Each provider uses one documented API with a credential the deployment's operator put in the server environment. A provider is only
// "configured" when its credential is present; it reaches only the fixed hosts listed here; responses are validated before anything is
// returned; credentials never appear in a response, an error or a log line. Sources for each API are in docs/API-CATALOGUE.md.
//
//   roblox-asset   Roblox Open Cloud Asset Delivery: GET https://apis.roblox.com/asset-delivery-api/v1/assetId/{id} with `x-api-key`
//                  (scope legacy-asset:manage) → JSON with a temporary `location` → GET that URL (Roblox CDN) → the asset file
//                  (a model: .rbxm / .rbxmx, possibly gzip-compressed). Env: QS_ROBLOX_API_KEY.
//   github         GitHub REST "get repository content": GET https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={ref} with
//                  `Accept: application/vnd.github.raw` and a fine-grained token. Env: QS_GITHUB_TOKEN, and QS_GITHUB_REPOS (a required
//                  comma-separated owner/repo allow-list, so the token can only be used for the repositories the operator named).
//   pastebin       Pastebin API raw output of the user's own paste: POST https://pastebin.com/api/api_raw.php with api_dev_key,
//                  api_user_key, api_paste_key, api_option=show_paste. Env: QS_PASTEBIN_DEV_KEY, QS_PASTEBIN_USER_KEY.
//
//   luarmor        OWNER CHECK ONLY, never a retrieval. Luarmor's documented v3 API: GET https://api.luarmor.net/v3/keys/{api_key}/details
//                  (the owner's API key in the path) lists the owner's projects and their scripts as metadata — script_id, name, version.
//                  The check answers one question: is the script this loader references one of the owner's own scripts? It returns no code:
//                  no documented Luarmor endpoint returns a script's contents ("Luarmor does not store your source code by default"), and
//                  acting as Luarmor's loader client is not an authorised route. Luarmor's API only answers from IP addresses the owner
//                  whitelisted, so a deployment without a fixed outbound address gets 403. Env: QS_LUARMOR_API_KEY.
//
// Not providers, on purpose (docs/API-CATALOGUE.md): Polsec, Panda — no documented call returns a protected script, and acting as their loader
// client is not an authorised route. Luarmor is here only for the owner check above.

export class ProviderError extends Error {
  constructor(code, message, status) { super(message); this.code = code; this.status = status; }
}

const MAX_BYTES = 8 * 1024 * 1024;

/** GET/POST with a fixed host allow-list, a deadline, a size cap, no redirects outside the list, and one retry on transient failures. */
export async function providerRequest(url, { fetchImpl = fetch, hosts, method = 'GET', headers = {}, body, timeoutMs = 10_000, maxBytes = MAX_BYTES, retries = 1, sleep = (ms) => new Promise((r) => setTimeout(r, ms)) } = {}) {
  let attempt = 0;
  for (;;) {
    try {
      return await once(url);
    } catch (e) {
      const transient = e instanceof ProviderError && (e.code === 'timeout' || e.code === 'upstream_unavailable' || e.code === 'rate_limited');
      if (!transient || attempt >= retries) throw e;
      attempt++;
      await sleep(e.retryAfterMs ? Math.min(e.retryAfterMs, 5000) : 400 * attempt);
    }
  }
  async function once(start) {
    let current = new URL(start);
    for (let hop = 0; hop < 3; hop++) {
      if (current.protocol !== 'https:' || !hosts.some((h) => (h instanceof RegExp ? h.test(current.hostname) : current.hostname === h))) throw new ProviderError('bad_upstream', 'The service pointed to an address outside the provider’s hosts.', 502);
      const ctl = new AbortController();
      const timer = setTimeout(() => ctl.abort(), timeoutMs);
      let res;
      try {
        res = await fetchImpl(current.toString(), { method, headers: { 'User-Agent': 'QuickSilver', ...headers }, body, redirect: 'manual', signal: ctl.signal });
      } catch (e) {
        clearTimeout(timer);
        throw new ProviderError(e && e.name === 'AbortError' ? 'timeout' : 'upstream_unavailable', e && e.name === 'AbortError' ? 'The service took too long to answer.' : 'Could not reach the service.', 504);
      }
      if (res.status >= 300 && res.status < 400 && res.headers.get('location')) { clearTimeout(timer); current = new URL(res.headers.get('location'), current); method = 'GET'; body = undefined; continue; }
      if (res.status === 401 || res.status === 403) { clearTimeout(timer); throw new ProviderError('upstream_auth', 'The service refused the configured credential (or it lacks access to this item).', 502); }
      if (res.status === 404) { clearTimeout(timer); throw new ProviderError('not_found', 'The service says this item does not exist (or the credential cannot see it).', 404); }
      if (res.status === 429) { clearTimeout(timer); const e = new ProviderError('rate_limited', 'The service is rate-limiting requests.', 429); e.retryAfterMs = Number(res.headers.get('retry-after')) * 1000 || 0; throw e; }
      if (res.status >= 500) { clearTimeout(timer); throw new ProviderError('upstream_unavailable', `The service answered ${res.status}.`, 502); }
      if (!res.ok) { clearTimeout(timer); throw new ProviderError('upstream_error', `The service answered ${res.status}.`, 502); }
      const declared = Number(res.headers.get('content-length') || 0);
      if (declared > maxBytes) { clearTimeout(timer); throw new ProviderError('too_large', 'The item is larger than the size limit.', 413); }
      const chunks = [];
      let total = 0;
      try {
        if (res.body && res.body.getReader) {
          const reader = res.body.getReader();
          for (;;) {
            const { done, value } = await reader.read();
            if (done) break;
            total += value.length;
            if (total > maxBytes) { ctl.abort(); throw new ProviderError('too_large', 'The item is larger than the size limit.', 413); }
            chunks.push(value);
          }
        } else if (res.arrayBuffer) { const b = new Uint8Array(await res.arrayBuffer()); total = b.length; if (total > maxBytes) throw new ProviderError('too_large', 'The item is larger than the size limit.', 413); chunks.push(b); }
      } catch (e) {
        if (e instanceof ProviderError) throw e;
        throw new ProviderError('upstream_unavailable', 'The download was interrupted.', 502);
      } finally { clearTimeout(timer); }
      // a body shorter than the length the server declared is a cut-off transfer, not a smaller file. (With a content-encoding the declared
      // length counts the compressed bytes and fetch has already decoded them, so the comparison only holds for an unencoded body.)
      if (declared && !res.headers.get('content-encoding') && total !== declared) throw new ProviderError('upstream_unavailable', `The download ended early: ${total} of ${declared} bytes arrived.`, 502);
      const bytes = new Uint8Array(total);
      let at = 0;
      for (const c of chunks) { bytes.set(c, at); at += c.length; }
      return { bytes, contentType: res.headers.get('content-type') || '', url: current.toString() };
    }
    throw new ProviderError('bad_upstream', 'Too many redirects.', 502);
  }
}

const text = (b) => new TextDecoder().decode(b);

export const PROVIDERS = {
  'roblox-asset': {
    env: ['QS_ROBLOX_API_KEY'],
    validate(t) { if (!/^\d{1,20}$/.test(String(t.assetId || ''))) throw new ProviderError('bad_request', 'assetId must be a number.', 400); },
    async retrieve(t, env, opts) {
      const meta = await providerRequest(`https://apis.roblox.com/asset-delivery-api/v1/assetId/${t.assetId}`, { ...opts, hosts: ['apis.roblox.com'], headers: { 'x-api-key': env.QS_ROBLOX_API_KEY, Accept: 'application/json' } });
      let j;
      try { j = JSON.parse(text(meta.bytes)); } catch { throw new ProviderError('bad_upstream', 'Asset Delivery did not answer with JSON.', 502); }
      if (!j || typeof j.location !== 'string') throw new ProviderError('bad_upstream', j && j.errors ? 'Asset Delivery returned an error for this asset.' : 'Asset Delivery did not return a download location.', 502);
      // the location is a temporary CDN URL; only Roblox hosts are followed
      const file = await providerRequest(j.location, { ...opts, hosts: [/(^|\.)rbxcdn\.com$/, /(^|\.)roblox\.com$/] });
      return { bytes: file.bytes, contentType: file.contentType, name: `asset-${t.assetId}.rbxm` };
    },
  },
  github: {
    env: ['QS_GITHUB_TOKEN', 'QS_GITHUB_REPOS'],
    validate(t, env) {
      if (!/^[\w.-]+$/.test(t.owner || '') || !/^[\w.-]+$/.test(t.repo || '')) throw new ProviderError('bad_request', 'owner and repo are required.', 400);
      if (typeof t.path !== 'string' || !t.path || t.path.includes('..') || t.path.length > 400) throw new ProviderError('bad_request', 'path is required.', 400);
      if (t.ref != null && !/^[\w./-]{1,200}$/.test(String(t.ref))) throw new ProviderError('bad_request', 'ref is not valid.', 400);
      const allowed = String(env.QS_GITHUB_REPOS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
      if (!allowed.includes(`${t.owner}/${t.repo}`.toLowerCase())) throw new ProviderError('forbidden', 'That repository is not on this deployment’s list.', 403);
    },
    async retrieve(t, env, opts) {
      const path = t.path.split('/').map(encodeURIComponent).join('/');
      const url = `https://api.github.com/repos/${t.owner}/${t.repo}/contents/${path}${t.ref ? `?ref=${encodeURIComponent(t.ref)}` : ''}`;
      const r = await providerRequest(url, { ...opts, hosts: ['api.github.com', 'raw.githubusercontent.com'], headers: { Authorization: `Bearer ${env.QS_GITHUB_TOKEN}`, Accept: 'application/vnd.github.raw', 'X-GitHub-Api-Version': '2022-11-28' } });
      if (/application\/json/.test(r.contentType) && /^\s*\[/.test(text(r.bytes.subarray(0, 64)))) throw new ProviderError('bad_request', 'That path is a directory, not a file.', 400);
      return { bytes: r.bytes, contentType: r.contentType, name: t.path.split('/').pop() };
    },
  },
  pastebin: {
    env: ['QS_PASTEBIN_DEV_KEY', 'QS_PASTEBIN_USER_KEY'],
    validate(t) { if (!/^[A-Za-z0-9]{4,16}$/.test(t.key || '')) throw new ProviderError('bad_request', 'key must be a paste key.', 400); },
    async retrieve(t, env, opts) {
      const form = new URLSearchParams({ api_dev_key: env.QS_PASTEBIN_DEV_KEY, api_user_key: env.QS_PASTEBIN_USER_KEY, api_paste_key: t.key, api_option: 'show_paste' });
      const r = await providerRequest('https://pastebin.com/api/api_raw.php', { ...opts, hosts: ['pastebin.com'], method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: form.toString() });
      // Pastebin answers errors with HTTP 200 and a text starting "Bad API request"
      const head = text(r.bytes.subarray(0, 64));
      if (/^Bad API request/i.test(head)) throw new ProviderError(/invalid (api_dev_key|api_user_key)/i.test(head) ? 'upstream_auth' : 'upstream_error', /invalid (api_dev_key|api_user_key)/i.test(head) ? 'Pastebin refused the configured keys.' : 'Pastebin refused the request for this paste.', 502);
      return { bytes: r.bytes, contentType: r.contentType, name: `${t.key}.lua` };
    },
  },
};

PROVIDERS.luarmor = {
  env: ['QS_LUARMOR_API_KEY'],
  kind: 'metadata',
  validate(t) { if (!/^[0-9a-fA-F]{32}$/.test(String(t.loaderId || ''))) throw new ProviderError('bad_request', 'loaderId must be the 32-hex identifier from the loader address.', 400); },
  async retrieve(t, env, opts) {
    let r;
    try {
      r = await providerRequest(`https://api.luarmor.net/v3/keys/${encodeURIComponent(env.QS_LUARMOR_API_KEY)}/details`, { ...opts, hosts: ['api.luarmor.net'], headers: { Accept: 'application/json' }, maxBytes: 1024 * 1024 });
    } catch (e) {
      // the documented meanings: 403 = IP not whitelisted or wrong key, 400 = usually an invalid API key
      if (e instanceof ProviderError && e.code === 'upstream_auth') throw new ProviderError('upstream_auth', 'Luarmor refused the request (HTTP 403): its API answers only from IP addresses the owner whitelisted, with a valid API key.', 502);
      if (e instanceof ProviderError && e.code === 'upstream_error' && /400/.test(e.message)) throw new ProviderError('upstream_auth', 'Luarmor says the configured API key is not valid (HTTP 400).', 502);
      throw e;
    }
    let j;
    try { j = JSON.parse(text(r.bytes)); } catch { throw new ProviderError('bad_upstream', 'Luarmor did not answer with JSON.', 502); }
    if (!j || j.success === false) throw new ProviderError('upstream_auth', `Luarmor refused the request${j && j.message ? `: ${String(j.message).slice(0, 120)}` : ''}.`, 502);
    if (!Array.isArray(j.projects)) throw new ProviderError('bad_upstream', 'Luarmor’s answer has no project list.', 502);
    const id = String(t.loaderId).toLowerCase();
    let match = null;
    let scripts = 0;
    for (const p of j.projects) {
      for (const sc of Array.isArray(p && p.scripts) ? p.scripts : []) {
        scripts++;
        if (String(sc && sc.script_id || '').toLowerCase() === id) match = { projectName: String(p.name || p.project_name || ''), scriptName: String(sc.script_name || ''), scriptVersion: sc.script_version == null ? null : String(sc.script_version) };
      }
    }
    // only what answers the question is returned: never the e-mail, Discord id, plan, keys or user list the same answer contains
    return { json: { owned: !!match, ...(match || {}), projectsSeen: j.projects.length, scriptsSeen: scripts, contents: 'not available: no documented Luarmor endpoint returns a script’s contents' } };
  },
};

/** Which providers this environment has credentials for (names only). */
export function configuredProviders(env) {
  return Object.entries(PROVIDERS).filter(([, p]) => p.env.every((k) => env[k])).map(([id]) => id);
}
