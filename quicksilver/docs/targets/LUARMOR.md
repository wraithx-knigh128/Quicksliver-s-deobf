# Luarmor loaders: what the file contains, what is recoverable, and what is not in it (Prompts XX–XXI)

Implementation: `src/loader/luarmor.js`, the Loader tab ("Luarmor loader" section). Tests: `tests/xx-luarmor.test.mjs`. Evidence: the real
loaders in the local corpus, read as text and never executed: 8 unique bootstraps, 2 SDK loaders (one of them the user's own `MainLoader.lua`),
and 1 key-link script.

## The central question

> When a user supplies a Luarmor loader, how much of the actual Lua/Luau implementation can OMEGA NEXUS recover from the loader itself, and
> what additional authorised information is required for the rest?

**Recoverable from the loader itself:** all of the loader's own logic.

- For a bootstrap, that means the cache-or-download logic.
- For an SDK loader, the key-entry flow, the handling of each status code, and any UI.
- When that code is itself obfuscated (one corpus loader is Luraph-wrapped), it goes through the Deobfuscator, and that result is measured
  there, not assumed.

**Not recoverable from the loader:** the protected script. It is not in the file. The service delivers it after a key check.

- Luarmor documents no interface that returns it (`docs/API-CATALOGUE.md`).
- What is needed is the script itself, which its owner already holds: they uploaded it.
- Pasted into the Deobfuscator, it goes through the normal pipeline like any script.

**Opaque:** the bootstrap's data table (`_bsdata0`). Its only consumer is the service's init runtime, which is not in the file, so what the
values mean cannot be determined from the loader. The analysis describes its shape:

- the number of values;
- the numbers it holds;
- each string's form: raw bytes, hex digits (with the bit length a hex string of that size represents), or a token.

It does not decode them.

## Variants (observed)

| Variant | What the file shows | Local logic | Not in the file |
|---|---|---|---|
| bootstrap | `_bsdata0 = {…}` (numbers, raw-byte strings, a hex string, a token), then: run a cached init script if `readfile` finds one; otherwise download `cdn.luarmor.net/v4_init_<tag>.lua`, cache it with `writefile`, delete older cached copies, run it | recovered in full | the init runtime (the service's client code); the protected script |
| sdk | downloads the SDK library (`sdkapi-public.luarmor.net/library.lua`), sets `script_key`, calls `check_key`, handles `KEY_VALID`, `KEY_HWID_LOCKED`, `KEY_INCORRECT`, `KEY_EXPIRED`, `KEY_BANNED` (…), then calls `load_script`; often with a hub's own UI | recovered in full, or through the Deobfuscator when obfuscated | the SDK library; the protected script |
| loader-url | `loadstring(game:HttpGet("https://api.luarmor.net/files/v3|v4/loaders/<id>.lua"))()` after `script_key = …` | the one statement | the protected script |
| key-link | a link to `ads.luarmor.net/get_key` (the user is sent to get a key); no loader | recovered in full | — |

## The five operations, kept apart

| # | Operation | Bootstrap | SDK | Loader-url |
|---|---|---|---|---|
| 1 | Analyse the loader | done | done | done |
| 2 | Recover code present in the loader | partial: logic in full, data opaque | done, or via the Deobfuscator when obfuscated | done |
| 3 | Retrieve the delivered payload | not available: no documented interface | not available | not available |
| 4 | Deobfuscate the retrieved payload | needs input: the owner supplies their script (Prompt XXI) | needs input | needs input |
| 5 | Validate behaviour | on the supplied script: its reconstruction is run next to it | the same | the same |

## Luarmor's documented API, re-verified (Prompt XXI)

Prompt XXI asked again whether any officially supported interface returns the script a loader delivers. The answer is unchanged: **none
does.**

**Sources and how they were read.**

- `docs.luarmor.net` and the Mintlify-hosted copy do not resolve from this project's environment, so they were not read directly. Their
  content was read through search-engine snippets.
- A source repository of the same documentation was read in full: `github.com/Stefanuk12/luarmor`, with its `openapi.json` (title "Luarmor
  API", version 3.0.0).
- That repository is under a personal account. It describes itself as "a better version of the Luarmor documentation" and does not claim to
  be Luarmor's own. **It is treated as a lead, corroborated by the snippets from `docs.luarmor.net`, not as an authoritative source.**

**What the API offers.** Base `https://api.luarmor.net`, the API key in the `Authorization` header with no prefix:

| Operation | Endpoint |
|---|---|
| Service status | `GET /status` (no key) |
| Key details: projects, and their scripts as metadata (id, name, version, flags) | `GET /v3/keys/{api_key}/details` |
| Key statistics | `GET /v3/keys/{api_key}/stats` |
| Users and keys | `POST` / `GET` / `PATCH` / `DELETE /v3/projects/{project_id}/users`, plus `…/users/resethwid`, `…/linkdiscord`, `…/blacklist`, `…/unban` |
| Upload a new version of a script, and change its settings | `PUT /v3/projects/{project_id}/scripts/{script_id}`. The body's `script` is "the new source code of the script". An `x-turnstile-token` header is optional, "if the request is challenged". |
| Follow a background upload | `GET /v3/projects/{project_id}/scripts/{script_id}/progress/{track_id}` |

A separate key-check API, for approved third-party (non-Lua) platforms, checks keys. It does not deliver scripts.

**Conditions that apply to every call:**

- The HTTP API answers only from **IP addresses the owner whitelisted**; anything else gets 403. A host without a fixed outbound address,
  such as a typical serverless deployment, cannot use it.
- "Generally 60 requests per minute"; over the limit the answer is 429.
- Errors are JSON `{ "success": false, "message": … }` with status 400 (usually an invalid key), 403 (IP not whitelisted or wrong key), 404,
  429, and 504 (large uploads).

**What it does not offer.** No endpoint returns a script's contents or its obfuscated output. The documentation states: "Luarmor does not
store your source code by default". Its loader addresses (`/files/v3|v4/loaders/…`) are the service's delivery route to its own client after a
key and device check. They are **not** an owner interface, and this project does not call them.

## The connected workflow for a Luarmor loader (Prompt XXI)

Loader input → loader analysis (this module) → authorisation check → retrieval → payload validation → obfuscator detection → deobfuscation →
syntax validation → behavioural validation → output.

For a Luarmor loader, the stages go as follows:

1. **Retrieval** stops at "payload unavailable", with the reason. Nothing is downloaded.
2. **Authorisation check (optional, owner only).** When the deployment holds the owner's API key (`QS_LUARMOR_API_KEY`) and its outbound
   address is on the owner's whitelist, *Check ownership* calls the details endpoint above. It reports whether the script id in the loader
   address is one of the key's scripts, with its name and version. The answer never contains code, and it leaves out everything else the
   endpoint returns (e-mail, Discord id, plan, keys).
   - The loader id is assumed to be the `script_id` of the details response. **This is an inference.** If it is wrong, the check answers
     "not among your scripts": a false negative, never a false claim.
   - Code: provider `luarmor` in `api/_lib/providers.js`. Tests: `tests/xxi-fetcher.test.mjs`.
3. **The owner's payload.** *Supply the payload* takes the file the owner holds: the obfuscated output, or their source. It runs the rest of
   the chain, the same code as a retrieved payload (`processPayload` in `src/loader/intel.js`).
4. **Result.** The result is one of the eight outcome classes of `src/validate/outcome.js`, and it is "fully reconstructed and behaviourally
   validated" only when the reconstruction behaved identically to that file in the sandbox.

## Boundaries, on purpose

- The service's client code (the init runtime and the SDK library) is not fetched, deobfuscated or analysed.
- The data table is not decoded.
- Interpreting either would mean working on the protection mechanism itself. That would not recover anything the owner does not already have.
- Key values are redacted. In the recovered loader logic, a `script_key` literal is replaced by a placeholder, and the analysis says so.
