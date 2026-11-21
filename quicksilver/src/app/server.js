// Calls from the page to this site's own server functions. The licence key the visitor entered (stored in this browser only, see
// license-ui.js) travels with each call in `x-qs-license`, because the server decides Premium access itself (api/_lib/entitlement.js).
// Only same-origin /api/ paths are sent this way; nothing is sent anywhere else.

const LICENCE_KEY = 'qs.license.v1';
const licence = () => { try { return localStorage.getItem(LICENCE_KEY) || ''; } catch { return ''; } };

/** fetch() for `/api/...` with the licence header. A path that is not this site's API is refused rather than sent. */
export function serverFetch(path, init = {}) {
  const p = String(path);
  if (!/^\/?api\/[a-z]+(?:[?#].*)?$/i.test(p)) return Promise.reject(new Error(`Not an API path of this site: ${p}`));
  const headers = new Headers(init.headers || {});
  const lic = licence();
  if (lic) headers.set('x-qs-license', lic);
  return fetch(p.startsWith('/') ? p : `/${p}`, { credentials: 'omit', referrerPolicy: 'no-referrer', ...init, headers });
}

/** A readable sentence for a server refusal that concerns the licence (or null when it is something else). */
export function licenceRefusal(status, body) {
  const code = body && (body.outcome || (body.error && body.error.code));
  if (status === 401 && code === 'licence_required') return 'This is a Premium feature. Enter your licence key (key icon, top right) and try again.';
  if (status === 403 && /^licen[cs]e_|^premium_required$/.test(code || '')) return (body.message || (body.error && body.error.message)) || 'Your licence does not include this Premium feature.';
  if (status === 503 && code === 'licensing_unavailable') return 'This deployment requires a licence, but the server has no licence key configured.';
  return null;
}
