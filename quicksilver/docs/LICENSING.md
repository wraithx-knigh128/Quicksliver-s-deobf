# Licensing

QuickSilver is a private tool. Access can be controlled with signed licence keys. This page says what that does and, just as important, what it cannot do.

## How a key works

* A key is `QS1.<payload>.<signature>`. The payload is base64url JSON: `{ v, id, name, plan, features, iat, exp, maxBytes? }`. The signature is ECDSA P-256 / SHA-256 over the ASCII bytes `QS1.` + payload.
* The page verifies the signature with the **public** key in `src/license/config.js` using WebCrypto, **offline**. The private key never leaves the issuer's machine (`license/keys/private.pem`, git-ignored, with the record of issued keys in `license/issued.jsonl`).
* `features` are `recover`, `sandbox`, `export` and `compare`; `maxBytes` caps the input size. `exp: null` means the key does not expire.

## Setting it up

```
node tools/license/keygen.mjs                     # creates the key pair and writes the public key into src/license/config.js
node tools/license/issue.mjs --name "Alice" --days 365 --features recover,sandbox,export,compare
node tools/license/issue.mjs --name "Trial" --days 7 --features recover,compare --max-bytes 200000
```

`issue.mjs` prints the key and appends a record (id, name, plan, expiry) to `license/issued.jsonl`. Back up `license/keys/` somewhere private: a lost private key means no new keys can be issued for the same public key,
and a leaked one means anyone can issue keys.

**While `PUBLIC_KEY` is `null` the system is installed but switched off**: every feature is available and the status bar says `Licence: not enforced`. That is the state of this repository.

## Without a valid key (once a public key is configured)

`POLICY.evaluation` in `src/license/config.js`: recovery and compare work on input up to 100,000 bytes; the sandbox (decoder evaluation, Trace, Dump) and Export are off. The interface says which limit applied.

## Revocation

`api/license.js` answers `GET /api/license?id=QS-...` with `{ revoked: true|false }`, from the `QS_REVOKED_IDS` environment variable (comma-separated). To use it, set `REVOCATION_ENDPOINT` in `src/license/config.js`.
The check is advisory and fails open (a network error does not lock someone out); it reveals nothing about other licences.

## What this does not protect

The check runs in the visitor's browser, and the recovery engine is JavaScript they download. Anyone willing to edit that JavaScript can remove the check. What the scheme does give you:

* keys that cannot be forged without the private key, that expire, and that can be revoked;
* a clear, enforced policy for honest users and a record of who was issued what.

If the recovery code itself must be kept private, it has to run on a server you control (the engine is plain ES modules and would run in a Vercel function) and the browser only talks to it. That is a different deployment and is not what this repository ships.

## Third-party licences

Obfuscators whose output is in the test corpus, and the attribution their licences require, are in `THIRD_PARTY_NOTICES.md`. Prometheus requires that products using it carry the sentence
"Based on Prometheus by Elias Oelschner, https://github.com/prometheus-lua/Prometheus"; it is in the About dialog, the README and the notices. The recovery modules contain no source code of any of these tools.
Leaked or stolen obfuscator sources are not used, referenced or reproduced anywhere in the project.
