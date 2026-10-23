// Licence configuration.
//
// PUBLIC_KEY is the ECDSA P-256 public key (JWK) that licence tokens are checked against. It is created
// by `node tools/license/keygen.mjs`, which writes it here. While it is null the licence system is installed
// but not activated: every feature is available and the interface says so.

export const PUBLIC_KEY = null;

/** Limits applied when a licence key is required but missing, invalid or expired. */
export const POLICY = Object.freeze({
  evaluation: {
    recover: true,        // the pipeline itself works in evaluation mode...
    sandbox: false,       // ...without executing anything,
    export: false,        // ...and the recovered text can be read and compared but not exported
    compare: true,
    maxBytes: 100_000,    // ...up to this size
  },
});

/** Optional revocation endpoint (the Vercel function in api/license.js). Null disables the check. */
export const REVOCATION_ENDPOINT = null;
