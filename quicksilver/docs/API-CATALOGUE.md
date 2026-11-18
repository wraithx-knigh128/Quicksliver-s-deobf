# API and service catalogue: Lua/Luau script delivery, protection and analysis (Prompt XIX)

This catalogue covers each service or API that a loader may point at, and that OMEGA NEXUS might integrate with. For each one it records:

1. what the service is for, and how it is built;
2. which of its operations are documented;
3. how its loaders talk to it;
4. how it delivers the payload;
5. what authentication it uses;
6. whether there is an **authorised** way to retrieve source;
7. what form the payload takes;
8. whether OMEGA NEXUS can integrate with it;
9. its limits and requirements.

Each claim is marked by source and reliability:

- **A**: official documentation.
- **B**: official vendor page or marketing.
- **C**: third-party code or a wrapper that uses the API.
- **D**: community post or search summary.
- **O**: observed by this project in real loaders, read as text and never executed.

How the research was done. The official documentation sites could not be opened directly from the build environment, for two reasons:

- The page-fetch tool could not resolve them.
- A direct download was refused by the session's safety policy.

So official pages were read through web search, which returns the indexed page content. Claims that rest on a single search summary carry
the grade of that source, and are not treated as verified against the live page. Nothing was bypassed to obtain any of this.

The integration status columns are kept separate on purpose: **research** done, **implementation** done, **testing** done, or **theoretical**
only.

---

## Licensing and protection services

### Luarmor

| | |
|---|---|
| Purpose / architecture | A whitelist and licensing service. A script owner uploads a script; users get a key; a loader checks the key (and the device) with the service, then runs the script it is served (A, O). |
| Documented API | The v3 REST API at `api.luarmor.net`, authenticated with an API key (A, C). Documented operations: <br>• **users**: create / patch / delete / list keys under `/v3/projects/:project_id/users`; `resethwid`, `linkdiscord`, `blacklist`, `unban`; <br>• **scripts**: `PUT /v3/projects/:project_id/scripts/:script_id` to **update (upload)** a script; <br>• **key details**: `GET /v3/keys/:api_key/details` lists the projects and the scripts in them (metadata) (A via search, C). <br>A separate third-party key-check API and an SDK at `sdkapi-public.luarmor.net` exist (A). |
| Loader communication | Loaders run `loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/<32 hex>.lua"))()` (now also `/files/v4/`), with `script_key` set beforehand. Bootstraps fetch `cdn.luarmor.net/v4_init_<name>.lua` and cache it with `writefile`. SDK loaders call `check_key` and `load_script` (O, D). |
| Delivery | Served to the loader after a key and device check. Status codes such as `KEY_HWID_LOCKED` appear in third-party loaders (D). |
| Authorised source retrieval | **None documented.** The owner API uploads scripts and lists them as metadata; no documented call returns a script's contents. The owner already holds the source they uploaded. |
| Payload form | Not documented. What the loader endpoint returns was **not requested** by this project: doing so would mean acting as the service's client. |
| Integration | Research: done, and re-verified in Prompt XXI (`docs/targets/LUARMOR.md`): **no endpoint returns script contents**; the API answers only from IP addresses the owner whitelisted; about 60 requests a minute; script upload may be Turnstile-challenged. Implementation: recognition (`luarmor` family, case 6, `script_key` redacted); loader analysis (`src/loader/luarmor.js`); an **owner check** (provider `luarmor`: `GET /v3/keys/{key}/details`, metadata only, with the owner's key); and the owner-supplied payload route through the validated chain. Testing: `tests/xviii-loader.test.mjs`, `tests/xx-luarmor.test.mjs`, `tests/xxi-fetcher.test.mjs`, `tests/xxi-outcome.test.mjs`. Retrieval of the protected script: **not implemented — no authorised interface exists**. |
| Limits | No authorised third-party retrieval. Device binding. The official docs page found in search is about 667 days old (`/files/v4/` loaders already exist). |
| Sources | [docs.luarmor.net](https://docs.luarmor.net/) (A, through search); [3rd-party key check API](https://docs.luarmor.net/docs-for-3rd-parties/3rd-party-external-key-check-api) (A); [Stefanuk12/luarmor](https://github.com/Stefanuk12/luarmor), a documentation repository with `openapi.json` (C: a personal account, not confirmed as Luarmor's own); [Stefanuk12/luarmor-deploy-action](https://github.com/Stefanuk12/luarmor-deploy-action), on the upload's IP whitelist and Turnstile requirement (C); [dlt connector notes](https://dlthub.com/context/source/luarmor) (C); [socket.dev: luarmor npm](https://socket.dev/npm/package/luarmor) (C); 10 loaders in the local corpus (O). |

### Polsec

| | |
|---|---|
| Purpose / architecture | A Lua whitelist and script-protection service: license keys, HWID locking, analytics, obfuscation, and optional ad monetisation. It runs under several domains (`polsec.sh`, `getpolsec.com`, `polsec.net`); it is not clear whether they share one operator (B). |
| Documented API | The marketing pages say "a complete REST API that allows you to manage keys, scripts, and users" (B). The docs site (`docs.getpolsec.com`) documents a Discord-bot setup with commands such as `/whitelist` (B). **No endpoint reference was found.** |
| Loader / delivery | Not documented publicly. No Polsec loader exists in the corpus. |
| Authorised source retrieval | None found. |
| Integration | Research: done (limited by the absence of documentation). Implementation: host recognition (`polsec` family, case 6). Testing: unit-tested through the shared family code. Retrieval: **theoretical / not possible** without documented endpoints. |
| Sources | [polsec.sh](https://polsec.sh/), [getpolsec.com](https://getpolsec.com/), [polsec.net](https://polsec.net/), [docs.getpolsec.com](https://docs.getpolsec.com/) (B). An unrelated GitHub project, [anasss927/api](https://github.com/anasss927/api), describes itself as "similar to PolSec" (C, not Polsec's). |

### Panda: PandAuth / Panda Key System / Kryptic Vault ("PandaVault")

| | |
|---|---|
| Purpose / architecture | A key system with HWID-locked keys checked server-side, ad-gated key links, and "Kryptic Vault" script hosting. Scripts are uploaded, obfuscated, and stored server-side "AES-256 encrypted", and users get a one-line loader (B). |
| Documented API | Base URL `api.pandauth.com`, header `X-API-Key` (keys are under Service Settings → General → API Key), no OAuth (A, through search). Key-management endpoints: extend expiry, check HWID binding (A). A third-party mirror documents the client library: `GetKeyLink`, `ValidateKey(key, service)`, and security levels (C). |
| Loader | `loadstring(game:HttpGet("https://vss.pandauth.com/kv/…"))()` (B). Older key checks went through `pandadevelopment.net` (C). |
| Authorised source retrieval | **None documented.** The vault serves its loader after validation of key, HWID and service. |
| Integration | Research: done. Implementation: recognition of `panda-vault` (vss.pandauth.com, case 6) and `panda-keys` (pandadevelopment.net, case 3). Testing: done (`tests/xviii-loader.test.mjs`). Retrieval: not possible through a documented route. |
| Sources | [pandauth.com authentication docs](https://pandauth.com/docs/api-reference/authentication) (A); [dash.pandauth.com](https://dash.pandauth.com/) and [new.pandadevelopment.net](https://new.pandadevelopment.net/) (B); [Pelinda library mirror](https://pelican-development.gitbook.io/pelinda-documentation/client-apis/library-overview/roblox/panda-v3-library) (C); [Panda Prometheus-Modified](https://github.com/Panda-Repositories/Prometheus-Modified) (open-source obfuscator, already a target). |

### LuaProt (luaprot.net)

| | |
|---|---|
| Purpose / API | Hubs, keys and blacklists. An SDK takes a script id, checks a user key (returning linked Discord details) and loads the script. The documented `hubs` GET returns the hubs and script **metadata** for the authenticated account (A, through search). |
| Authorised source retrieval | None documented. |
| Integration | Recognition only (`luaprot` family, case 6). Sources: [luaprot docs index](https://context7.com/websites/luaprot_net/llms.txt?tokens=10000) (A, through an index). |

### Platoboost, Work.ink, Junkie and similar key gates

No official developer documentation could be found. Search results were dominated by **bypass tools**, which were not used. These services gate a key behind ads or tasks; the script is delivered by the script's own loader. Status: research only. No integration, and none is warranted without documentation.

---

## Platform and hosting APIs with an authorised owner route (implemented)

### Roblox Open Cloud: Asset Delivery

| | |
|---|---|
| Purpose | Download an asset's content (for example a model holding a `ModuleScript`, which is what `require(<assetId>)` loads). |
| Documented operation | `GET https://apis.roblox.com/asset-delivery-api/v1/assetId/{assetId}` (and a versioned variant) with an Open Cloud API key with scope `legacy-asset:manage` in `x-api-key`. It returns **JSON with a temporary `location`**, which a second GET downloads. The content may be compressed (A: Roblox announcement; D: forum replies). The Assets API itself does not return content (D). |
| Auth | User-scoped API keys only; group keys are not accepted for this scope (D). Public assets may be readable with any user's key (D). |
| Payload form | A model file: `.rbxm` binary (LZ4 chunks) or `.rbxmx` XML. The program is the `Source` of its Script / LocalScript / ModuleScript instances. |
| Integration | Research: done. **Implementation: done**: `api/_lib/providers.js` (`roblox-asset`) runs both steps and validates the JSON. The key is sent only to `apis.roblox.com`, and the file is accepted only from Roblox CDN hosts. `src/loader/rbx.js` extracts the scripts. **Testing: done**: `tests/xix-retrieve.test.mjs` with a mock upstream; `tests/xix-rbx.test.mjs` on real Studio files (rojo-rbx/rbx-test-files: 108 files, binary and XML agreeing); remote-loader fixtures `owner-roblox-model-*`. **Not tested against the live Roblox API**: no owner key was provided. |
| Limits | Needs the owner's own key, which the operator must configure (`QS_ROBLOX_API_KEY`, `QS_RETRIEVE_MODE`). ZSTD-compressed model chunks are recognised but not decoded. |
| Sources | [Creator Action Required: New Asset Delivery API Endpoints](https://devforum.roblox.com/t/creator-action-required-new-asset-delivery-api-endpoints-for-community-tools/3574403) (A, Roblox staff announcement); [Assets API does not retrieve content](https://devforum.roblox.com/t/opencloud-asset-api-doesnt-retrieve-the-asset-content/3760488) (D); [binary model format](https://dom.rojo.space/binary) (C, community specification; verified against real files). |

### GitHub: repository contents

| | |
|---|---|
| Documented operation | `GET /repos/{owner}/{repo}/contents/{path}?ref=…`. The raw media type returns the file body. Fine-grained tokens need **Contents: read** (A). |
| Integration | **Implemented** (`github` provider). The token is used only with `api.github.com`, and only for repositories on the operator's `QS_GITHUB_REPOS` allow-list. Directories are refused. **Tested** with mocks. Public files go through the existing link fetcher. |
| Sources | [Repository contents](https://docs.github.com/en/rest/repos/contents), [fine-grained token permissions](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens) (A). |

### Pastebin

| | |
|---|---|
| Documented operations | Public and unlisted pastes: `https://pastebin.com/raw/<key>` (already used by the link fetcher). The user's own private paste: `POST https://pastebin.com/api/api_raw.php` with `api_dev_key`, `api_user_key` (from `api_login.php`), `api_paste_key` and `api_option=show_paste`. Errors come back with HTTP 200 and a body starting `Bad API request` (C: wrappers pbwrap and go-pastebin; the official page was not readable here). |
| Integration | **Implemented** (`pastebin` provider): `Bad API request` bodies are treated as errors, and key errors are named without showing the keys. **Tested** with mocks. **Not tested live**. |
| Sources | [pbwrap source](https://pbwrap.readthedocs.io/en/latest/_modules/pbwrap/pbwrap.html), [go-pastebin](https://pkg.go.dev/github.com/TwiN/go-pastebin) (C). |

### Public raw hosts (GitHub raw, gist, Pastebin raw, rentry, paste.ee, Discord CDN)

**Implemented** through `/api/fetch` since Prompt XVIII: allow-listed, https only, size and time limited. Owner credentials can be configured
per host and path prefix (`QS_FETCH_AUTH`).

---

## Obfuscation services with documented APIs (for authorised fixtures)

| Service | Documented | Use for OMEGA NEXUS | Status |
|---|---|---|---|
| Luraph | The API key comes from the account page. Obfuscation jobs block for up to 60 s, at most 3 calls per job. Plan-restricted (C: the official Node SDK README). | With the user's own key: obfuscate a **known** source to get ground-truth fixtures (the main Luraph blocker in `docs/KNOWN-ISSUES.md` 62). | Theoretical; needs the user's key and plan. |
| Prometheus, Panda Prometheus-Modified, IronBrew 2, Hercules, … | Open source. | Already generated locally in isolation (`tests/corpus/tools/run_isolated.py`). | Done (earlier prompts). |

Sources: [luraph-node README](https://cdn.jsdelivr.net/npm/luraph@2.0.9/README.md) (C).

## Open-source analysis projects surveyed (methods, not dependencies)

| Project | What it does (self-described) | Relevance |
|---|---|---|
| [jte/lua-decompiler](https://github.com/jte/lua-decompiler) | Rust/WASM decompiler for Lua 5.1–5.5, LuaJIT and Luau bytecode v3–14. | Luau bytecode is a payload form this project classifies but does not decompile. A candidate for future work: a separate bytecode-lifting stage, measured on its own. Not integrated (licence and size not reviewed; no unnecessary dependencies). |
| [sarb2u/luau-bytecode-lens](https://github.com/sarb2u/luau-bytecode-lens) | A Luau toolkit split into lift, IR and emit crates, with inverse transform passes. | Architecture reference: transforms paired with their inverse passes. |
| [PumbaaDev/luau-decompiler](https://github.com/PumbaaDev/luau-decompiler) | An offline Luau decompiler "verified by semantic round-trip testing". | The same validation stance as this project's oracle tests. |
| [danielkasprzak/Lua-Bytecode-Deobfuscator](https://github.com/danielkasprzak/Lua-Bytecode-Deobfuscator) | Removes bytecode encryption (FiveM). | Not a current target. |
| [ShufflePerson/De4Lua](https://github.com/ShufflePerson/De4Lua) | A universal deobfuscator (Node.js), in development. | Not production-ready per its README. |
| [rojo-rbx/rbx-dom](https://github.com/rojo-rbx/rbx-dom), [rbx-test-files](https://github.com/rojo-rbx/rbx-test-files) | Roblox model format libraries and a test corpus (MIT). | **Used**: the format reference and real test files for `src/loader/rbx.js`. |

The READMEs are self-descriptions (C). Their code quality and licences were not reviewed, and none of these projects was added as a dependency.
