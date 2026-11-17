# Prompt XIX — Advanced API & Loader Intelligence: report

What is completed and what is proposed are kept apart throughout. For every integration, four things are stated separately: whether the
research, the implementation and the testing are done, and what remains theoretical. The work is in the commits on `ccr-17f6469c-lf3p64`
after `2acfeb1`.

The question this report answers: *if I give OMEGA NEXUS a loader, can it retrieve the payload, reconstruct it, and say what happened?* The
answer is in §2 and §7, and it is measured in `docs/LOADER-SCORECARD.md`.

## 1. Newly discovered APIs and services

The detail and sources are in `docs/API-CATALOGUE.md`.

| Service | Kind | Research | Implementation | Testing | Theoretical / not possible |
|---|---|---|---|---|---|
| Luarmor | licensing / whitelist | done (official API through search; 10 real loaders observed) | recognition, case 6, key redaction | done | retrieval: no documented endpoint returns a script |
| Polsec (polsec.sh / getpolsec.com / polsec.net) | licensing / whitelist / obfuscation | done (marketing; Discord-bot docs; no endpoint reference exists) | host recognition, case 6 | done | retrieval: no documentation |
| Panda: PandAuth / Kryptic Vault | key system + vault hosting | done (`X-API-Key` API; vault loader `vss.pandauth.com/kv/…`) | recognition (`panda-vault` case 6, `panda-keys` case 3) | done | retrieval: no documented endpoint |
| LuaProt | hubs / keys / blacklist | done (hubs endpoint returns metadata) | recognition, case 6 | done | retrieval: none documented |
| Roblox Open Cloud Asset Delivery | platform | done (Roblox announcement + forum) | **owner provider** + model reader | **done** (mock upstream; real Studio model files) | live call: needs the owner's key |
| GitHub contents | hosting | done (official docs) | **owner provider** (allow-listed repositories) | **done** (mock) | live call: needs a token |
| Pastebin owner raw | hosting | done (third-party wrappers; the official page could not be read here) | **owner provider** | **done** (mock) | live call: needs keys |
| Luraph API | obfuscation service | done (SDK README) | — | — | with the user's key: ground-truth Luraph fixtures |
| Platoboost / Work.ink / Junkie | key gates | searched: no developer docs; results were bypass tools (not used) | — | — | — |
| Open-source decompilers and deobfuscators (6 projects) | analysis tools | surveyed (READMEs) | rbx-dom format and test files **used** | — | Luau bytecode decompilation (§8) |

## 2. Documented capabilities

What the services' documented APIs actually do:

- **Licensing services** (Luarmor, Polsec, Panda, LuaProt) document *management* calls: keys, users, HWID resets, script metadata. Luarmor
  also documents *uploading* a script.
- **Not one of them documents a call that returns a protected script.**
- **Retrieval routes that are documented:**
  - Roblox Asset Delivery, for the owner's asset;
  - GitHub contents, for a token's repositories;
  - Pastebin `api_raw.php`, for the user's own paste;
  - public raw hosts.

## 3. Loader architectures

The fourteen classes from Prompt XVIII still apply (`docs/LOADERS.md`). New in this round, at the **payload** level:

- encoded and compressed transports (base64, hex, gzip, zlib, JSON fields), each recorded as a layer;
- model payloads (`.rbxm` / `.rbxmx`), with the scripts extracted;
- error answers delivered as success: an HTML page or a JSON error returned with HTTP 200;
- multi-stage chains: a payload that is itself a loader is analysed as the next stage.

## 4. Luarmor and Polsec findings

### Luarmor

The documented REST API (`api.luarmor.net/v3`, API key) covers:

- managing users and keys;
- updating a script (`PUT …/scripts/:id`);
- listing key details and projects.

Loaders fetch `/files/v3|v4/loaders/<id>.lua` with `script_key` set; bootstraps cache an init script fetched from `cdn.luarmor.net`.

**Answer, case by case:**

| Situation | Answer |
|---|---|
| Source directly available | Not applicable; the loader holds no program. |
| Public payload | No; the loader endpoint is key-gated. |
| Owner's API key | Uploads and manages; it does **not** return the script. |
| Official authenticated retrieval endpoint | None documented. |
| Dynamically generated payload | Not documented. |
| Execution or distribution only | **Yes, this is what the service provides.** |
| Unavailable through an authorised interface | **Yes.** |

So OMEGA NEXUS recognises a Luarmor loader, redacts its key, explains the access model and analyses the loader's structure. It does not
retrieve the payload, because there is no authorised way to.

### Polsec

Its sites advertise a REST API for keys, scripts and users, but no endpoint reference could be found. Its documentation covers a Discord bot.
The same conclusion as Luarmor follows, with lower confidence because nothing is documented.

## 5. Additional services worth integrating

- **Roblox Asset Delivery**: implemented. It turns `require(<id>)` loaders from "case 6" into "case 3, retrievable by the owner".
- **GitHub and Pastebin owner routes**: implemented.
- **Luraph API**, with the user's own key: proposed, as a source of ground-truth fixtures. It is the main Luraph blocker (KNOWN-ISSUES 62).
- **The licensing services**: worth integrating **only if** a vendor documents an owner export endpoint.

## 6. Retrieval methods supported by authorised access

| Route | Who may use it | Where it is configured | Status |
|---|---|---|---|
| Public raw hosts (`/api/fetch`) | anyone, on confirmation | built in | implemented and tested (Prompt XVIII) |
| Owner credential per host and path prefix (`/api/fetch?auth=1`) | the operator's tools (token-gated) | `QS_FETCH_AUTH`, `QS_FETCH_AUTH_TOKEN` | implemented and tested (Prompt XVIII) |
| Owner providers (`/api/retrieve`) | `token` mode: the operator's tools; `open` mode: page visitors (private deployments only) | `QS_RETRIEVE_MODE`, `QS_ROBLOX_API_KEY`, `QS_GITHUB_TOKEN` + `QS_GITHUB_REPOS`, `QS_PASTEBIN_DEV_KEY` + `QS_PASTEBIN_USER_KEY` | implemented and tested with mocks; not run live (no owner keys were provided) |

How the routes are secured:

- Secrets live only in the server environment.
- Each provider reaches only its fixed hosts. The Roblox key goes only to `apis.roblox.com`, and the file is accepted only from Roblox CDN
  hosts.
- Responses are validated.
- Errors name the step that failed, never a credential.
- Limits: one retry on transient failures, a size cap, and a per-instance rate limit.

## 7. Loader Analysis / Intelligence implementation progress

All of the following are **implemented and tested**:

- **`src/loader/intel.js`**: a staged orchestrator.
  1. identify;
  2. route;
  3. transport;
  4. payload;
  5. classify;
  6. reconstruct;
  7. recurse.

  Each stage keeps its own result, and an outcome is assigned per request.
- **`src/loader/payload.js`**: transport and serialization layers.
- **`src/loader/rbx.js`**: Roblox model reader.
- **The website**: the Loader tab's "Retrieve and analyse…".
  - It asks for confirmation and lists each address first.
  - It shows a measured summary and one row per request (transport, payload layers, program → confidence, outcome).
  - Retrieved payloads and reconstructed results can be opened.
  - Reports export as Markdown or JSON.
  - `.rbxm` / `.rbxmx` files open as their scripts.
- **Measurement.** `docs/LOADER-SCORECARD.md` covers 22 cases and 23 stages, run through the real server handlers in front of a mock
  service:

  | Measure | Result |
  |---|---|
  | Stages with an authorised route | 19 |
  | Transport succeeded | 14 |
  | Payload was code | 11 |
  | Reconstructed (obfuscated → high confidence) | 5 |
  | Plain code | 4 |
  | Retrieved but not reconstructed | 1 |
  | Not code (error page, truncated stream, JSON error) | 3 |
  | Behaviour checks on Lua 5.1 equal to the retrieved payload | 9 / 9 |

## 8. Newly researched deobfuscation techniques

See `docs/METHODS.md` §9–13.

- **Added:**
  - transport and serialization recovery;
  - Roblox container extraction, verified on real Studio files and against the reference LZ4 library;
  - loader-level semantic validation.
- **Proposed:** Luau bytecode decompilation, informed by the surveyed open-source decompilers. It is blocked on fixtures, which need
  `luau-compile`.
- **Compared:** static and dynamic analysis for loaders. Dynamic analysis stays network-free, so a delivery service is never contacted.

## 9. Actual reconstruction improvements

- **New payloads now reach the pipeline:**
  - payloads behind base64, hex, gzip, zlib or a JSON field;
  - scripts inside Roblox models;
  - each stage of a multi-stage loader.

  Before this round, all of these stopped at the loader.
- **Measured:** on the fixtures, 5 obfuscated payloads (IronBrew 2, Prometheus, and one inside a gzipped model) were retrieved, decoded and
  reconstructed at high confidence, and their behaviour matched on the reference Lua.
- **The reconstruction engine itself was not changed in this round.** The Prompt XVIII scorecard still applies.

## 10. Remaining technical limitations

- KNOWN-ISSUES 69: static loader analysis.
- KNOWN-ISSUES 71: providers not run live.
- KNOWN-ISSUES 72: no authorised route for the licensing services.
- KNOWN-ISSUES 73: ZSTD model chunks and Luau bytecode.
- The official documentation sites could not be opened directly from the build environment: the page-fetch tool could not resolve them, and
  a direct download was refused by the session's safety policy. They were read through search, and the reliability grades say so.

## 11. Recommended next investigations

1. One live, authorised retrieval per provider with the owner's own key: Roblox (an asset you own), GitHub (a private repository),
   Pastebin (your own paste).
2. Build `luau-compile` and create Luau bytecode fixtures, then write a Luau bytecode reader (METHODS §12).
3. ZSTD decoding for newer model files.
4. The Luraph API with your key, for ground-truth Luraph fixtures.
5. Ask the licensing vendors whether an owner export endpoint exists. If one is documented, it becomes a provider like the three above.

## Tests

| Test file | Tests |
|---|---|
| `tests/xix-rbx.test.mjs` | 4 |
| `tests/xix-retrieve.test.mjs` | 6 |
| `tests/xix-loader-intel.test.mjs` | 23 |
| e2e (Loader Intelligence; Roblox model file) | 2 |

The full-suite and e2e results are recorded in the commit that follows this report.
