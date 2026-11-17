// Run a remote-loader fixture through Loader Intelligence, with the mock service behind the real server handlers (api/fetch.js,
// api/retrieve.js), so what is measured is what the deployment would do. Retrieval and reconstruction are recorded separately.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHandler as createFetch } from '../../api/fetch.js';
import { createHandler as createRetrieve } from '../../api/retrieve.js';
import { analyzeLoader } from '../../src/loader/analyze.js';
import { decodePayload } from '../../src/loader/payload.js';
import { loaderIntel } from '../../src/loader/intel.js';
import { detect } from '../../src/detect/detect.js';
import { recover } from '../../src/recover/pipeline.js';

export const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'tests', 'corpus', 'remote-loaders');
export const manifest = () => JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
const binary = (s) => { let o = ''; for (let i = 0; i < s.length; i++) o += String.fromCharCode(s.charCodeAt(i) & 255); return o; };

function upstream(service) {
  return async (url, init = {}) => {
    const key = url.startsWith('https://apis.roblox.com/asset-delivery-api/v1/assetId/') ? `provider:roblox-asset:${url.split('/').pop()}` : url.startsWith('https://cdn.rbx.test/') ? decodeURIComponent(url.slice('https://cdn.rbx.test/'.length)) : url;
    if (key.startsWith('provider:roblox-asset:') && url.startsWith('https://apis.roblox.com/')) {
      if (!service[key]) return response(Buffer.from('{"errors":[{"code":404}]}'), 404, 'application/json');
      if (!init.headers || !init.headers['x-api-key']) return response(Buffer.from('{}'), 401, 'application/json');
      return response(Buffer.from(JSON.stringify({ location: `https://c0.rbxcdn.com/${encodeURIComponent(key)}` })), 200, 'application/json');
    }
    const k2 = url.startsWith('https://c0.rbxcdn.com/') ? decodeURIComponent(url.slice('https://c0.rbxcdn.com/'.length)) : key;
    const spec = service[k2];
    if (!spec) return response(Buffer.from('404: Not Found'), 404, 'text/plain');
    if (spec.fail === 'network') throw new TypeError('fetch failed');
    const bytes = fs.readFileSync(path.join(dir, 'bodies', spec.file));
    return response(bytes, spec.status || 200, spec.type || 'text/plain');
  };
}
function response(bytes, status, type) {
  return { status, ok: status >= 200 && status < 300, headers: new Map([['content-type', type], ['content-length', String(bytes.length)]]), body: new ReadableStream({ start(c) { if (bytes.length) c.enqueue(new Uint8Array(bytes)); c.close(); } }) };
}
function invoke(handler, req) {
  return new Promise((resolve) => {
    const res = { statusCode: 200, headers: {}, setHeader(k, v) { this.headers[k.toLowerCase()] = v; }, end(d) { resolve({ status: this.statusCode, headers: this.headers, body: d ? new Uint8Array(Buffer.from(d)) : new Uint8Array(0) }); } };
    handler({ headers: { 'sec-fetch-site': 'same-origin' }, ...req }, res);
  });
}

/** @returns {Promise<{ case: object, report: object }>} */
export async function runCase(c, { sandbox = true } = {}) {
  const service = c.service || {};
  const fetchImpl = upstream(service);
  const fetcher = createFetch({ fetchImpl, env: {} });
  const retriever = createRetrieve({ fetchImpl, env: { QS_RETRIEVE_MODE: 'open', QS_ROBLOX_API_KEY: 'test-key' }, sleep: async () => {} });
  const fetchStage = async (req) => {
    const t = Date.now();
    const r = req.retrieval.route === 'provider:roblox-asset'
      ? await invoke(retriever, { method: 'POST', body: { provider: 'roblox-asset', assetId: String(req.url) } })
      : await invoke(fetcher, { method: 'GET', query: { url: req.url } });
    const ok = r.status === 200;
    let error = null;
    if (!ok) { try { const j = JSON.parse(new TextDecoder().decode(r.body)); error = typeof j.error === 'string' ? j.error : j.error && j.error.message; } catch { error = `HTTP ${r.status}`; } }
    return { ok, status: r.status, bytes: ok ? r.body : null, contentType: r.headers['x-qs-upstream-type'] || '', error, ms: Date.now() - t };
  };
  const report = await loaderIntel(binary(c.loader), {
    analyze: (src, o) => analyzeLoader(src, { ...o, providers: c.providers || [] }),
    fetchStage,
    decode: decodePayload,
    detect: (t) => detect(t),
    recover: (t) => recover(t, { sandbox: { enabled: sandbox } }),
  }, { routes: ['link-fetcher', ...(c.providers || []).map((p) => `provider:${p}`)] });
  return { case: c, report };
}
