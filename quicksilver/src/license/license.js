// QuickSilver licence tokens.
//
// A token is   QS1.<payload>.<signature>   where payload is base64url(JSON) and signature is a raw
// (r || s) ECDSA P-256 / SHA-256 signature over the ASCII bytes "QS1." + payload. Verification needs only
// the public key (config.js); the private key never leaves the issuer's machine (tools/license).
//
// What this does and does not protect: the check runs in the user's browser, so someone willing to edit the
// JavaScript can bypass it. It stops casual sharing, makes tokens unforgeable without the private key, expire,
// and be revoked (optional server check). See docs/LICENSING.md for the full threat model.

const PREFIX = 'QS1';

const b64uToBytes = (s) => {
  const pad = '='.repeat((4 - (s.length % 4)) % 4);
  const bin = atob(s.replace(/-/g, '+').replace(/_/g, '/') + pad);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
};

const textOf = (bytes) => new TextDecoder('utf-8', { fatal: true }).decode(bytes);

/**
 * Check a token against a public key.
 * @param {string} token
 * @param {JsonWebKey|null} publicKeyJwk
 * @param {{now?: number, subtle?: SubtleCrypto}} [opts] now = unix seconds
 * @returns {Promise<{status: 'valid'|'expired'|'not-yet-valid'|'invalid'|'missing'|'unconfigured', payload?: object, reason?: string}>}
 */
export async function verifyToken(token, publicKeyJwk, opts = {}) {
  if (!publicKeyJwk) return { status: 'unconfigured', reason: 'No public key is configured, so licences cannot be checked.' };
  if (!token || typeof token !== 'string') return { status: 'missing', reason: 'No licence key has been entered.' };
  const parts = token.trim().split('.');
  if (parts.length !== 3 || parts[0] !== PREFIX) return { status: 'invalid', reason: 'This is not a QuickSilver licence key.' };

  const subtle = opts.subtle || (typeof crypto !== 'undefined' ? crypto.subtle : null);
  if (!subtle) return { status: 'invalid', reason: 'This browser cannot verify signatures (WebCrypto is unavailable).' };

  let payload;
  let signature;
  try {
    payload = JSON.parse(textOf(b64uToBytes(parts[1])));
    signature = b64uToBytes(parts[2]);
  } catch {
    return { status: 'invalid', reason: 'The licence key is damaged (it could not be decoded).' };
  }
  if (signature.length !== 64) return { status: 'invalid', reason: 'The licence key is damaged (bad signature length).' };

  let ok = false;
  try {
    const key = await subtle.importKey('jwk', publicKeyJwk, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
    ok = await subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, signature, new TextEncoder().encode(`${PREFIX}.${parts[1]}`));
  } catch {
    return { status: 'invalid', reason: 'The licence key could not be verified.' };
  }
  if (!ok) return { status: 'invalid', reason: 'The signature does not match: this key was not issued for this product, or it was altered.' };

  if (payload.v !== 1 || typeof payload.id !== 'string') return { status: 'invalid', reason: 'Unsupported licence format.' };
  const now = opts.now ?? Math.floor(Date.now() / 1000);
  const skew = 300; // five minutes of clock drift is not worth refusing a customer over
  if (payload.nbf && now + skew < payload.nbf) return { status: 'not-yet-valid', payload, reason: 'This licence is not valid yet.' };
  if (payload.exp && now - skew > payload.exp) return { status: 'expired', payload, reason: `This licence expired on ${new Date(payload.exp * 1000).toISOString().slice(0, 10)}.` };
  return { status: 'valid', payload };
}

/** What a licence state allows. Unconfigured builds (no public key) are not restricted. */
export function entitlements(state, policy) {
  const full = { recover: true, sandbox: true, export: true, compare: true, maxBytes: null, level: 'full' };
  if (state.status === 'unconfigured') return { ...full, level: 'open' };
  if (state.status === 'valid') {
    const f = new Set(state.payload.features || []);
    return {
      recover: f.has('recover'),
      sandbox: f.has('sandbox'),
      export: f.has('export'),
      compare: f.has('compare'),
      maxBytes: state.payload.maxBytes || null,
      level: state.payload.plan || 'licensed',
    };
  }
  return { ...policy.evaluation, level: 'evaluation' };
}

/** Optional: ask the deployment whether this licence id has been revoked. Fails open when offline. */
export async function checkRevocation(id, endpoint, fetchImpl = (typeof fetch === 'function' ? fetch : null)) {
  if (!endpoint || !fetchImpl) return { revoked: false, checked: false };
  try {
    const res = await fetchImpl(`${endpoint}?id=${encodeURIComponent(id)}`, { cache: 'no-store' });
    if (!res.ok) return { revoked: false, checked: false };
    const body = await res.json();
    return { revoked: body.revoked === true, checked: true };
  } catch {
    return { revoked: false, checked: false };
  }
}

export function describeLicense(state, ent) {
  const p = state.payload || {};
  return {
    status: state.status,
    reason: state.reason || null,
    licensee: p.name || null,
    id: p.id || null,
    plan: p.plan || null,
    expires: p.exp ? new Date(p.exp * 1000).toISOString().slice(0, 10) : p.id ? 'never' : null,
    features: p.features || [],
    entitlements: ent,
  };
}
