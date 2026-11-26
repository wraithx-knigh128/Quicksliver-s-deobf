// Premium entitlement, checked by the server for the features that run on it.
//
// The page checks a licence too, but that check runs in the visitor's browser and can be edited away (docs/LICENSING.md). What runs on this
// server — GitHub retrieval with a token, the Luraph engine, the AI assistant — is only done for a request that carries a valid licence:
//
//   header  x-qs-license: QS1.<payload>.<signature>      (the same token the page stores; ECDSA P-256, verified here with WebCrypto)
//
// A token entitles a feature when its payload has `plan: "premium"`, or lists the feature in `features`. Expiry, not-before and the
// revocation list (QS_REVOKED_IDS, as api/license.js) are honoured.
//
// Which public key: QS_LICENSE_PUBLIC_KEY (a JWK, JSON) in the server's environment, else the one built into src/license/config.js. With
// neither, licensing is not activated (the repository's state, docs/LICENSING.md): requests are served and the answer says
// `licensing: "not-activated"` — unless QS_REQUIRE_LICENSE=1, which makes the server refuse rather than serve unlicensed (fail closed).
// Nothing about the token is logged or echoed except the licence id when it is valid.

import { verifyToken } from '../../src/license/license.js';
import { PUBLIC_KEY } from '../../src/license/config.js';

export const SERVER_FEATURES = Object.freeze({ github: 'GitHub retrieval', reconstruct: 'Luraph reconstruction engine', assistant: 'AI research assistant', retrieve: 'owner retrieval', engine: 'Server deobfuscation engines (MoonSec V3)' });

function publicKey(env) {
  if (env.QS_LICENSE_PUBLIC_KEY) {
    try { return JSON.parse(env.QS_LICENSE_PUBLIC_KEY); } catch { return { invalid: true }; }
  }
  return PUBLIC_KEY;
}

/**
 * @param {object} req Node request (headers read case-insensitively)
 * @param {string} feature one of SERVER_FEATURES
 * @returns {Promise<{ok: boolean, status: number, code: string, message: string, licensing: 'not-activated'|'enforced', licence?: {id: string, plan: string|null}}>}
 */
export async function checkEntitlement(req, feature, { env = process.env, now } = {}) {
  const key = publicKey(env);
  const header = (req && req.headers && (req.headers['x-qs-license'] || req.headers['X-QS-License'])) || '';
  const token = Array.isArray(header) ? header[0] : String(header || '');
  if (key && key.invalid) return { ok: false, status: 500, code: 'licensing_misconfigured', message: 'The server’s licence key setting is not valid JSON.', licensing: 'enforced' };
  if (!key) {
    if (env.QS_REQUIRE_LICENSE === '1') return { ok: false, status: 503, code: 'licensing_unavailable', message: 'This deployment requires a licence, but no licence key is configured on the server.', licensing: 'enforced' };
    return { ok: true, status: 200, code: 'open', message: 'Licensing is not activated on this deployment.', licensing: 'not-activated' };
  }
  if (!token) return { ok: false, status: 401, code: 'licence_required', message: `${SERVER_FEATURES[feature] || 'This feature'} is a Premium feature: enter your licence key first.`, licensing: 'enforced' };
  if (token.length > 4096) return { ok: false, status: 400, code: 'licence_invalid', message: 'The licence key is not valid.', licensing: 'enforced' };
  const v = await verifyToken(token, key, { now: now ?? undefined });
  if (v.status !== 'valid') return { ok: false, status: 403, code: `licence_${v.status.replace(/-/g, '_')}`, message: v.reason || 'The licence key is not valid.', licensing: 'enforced' };
  const p = v.payload;
  const revoked = (env.QS_REVOKED_IDS || '').split(',').map((s) => s.trim()).filter(Boolean);
  if (revoked.includes(p.id)) return { ok: false, status: 403, code: 'licence_revoked', message: 'This licence has been revoked.', licensing: 'enforced' };
  const features = Array.isArray(p.features) ? p.features : [];
  if (p.plan !== 'premium' && !features.includes(feature)) return { ok: false, status: 403, code: 'premium_required', message: `${SERVER_FEATURES[feature] || 'This feature'} needs a Premium licence; this licence does not include it.`, licensing: 'enforced' };
  return { ok: true, status: 200, code: 'licensed', message: 'Licensed.', licensing: 'enforced', licence: { id: p.id, plan: p.plan || null } };
}
