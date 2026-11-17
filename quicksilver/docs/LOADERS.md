# Loaders and remote sources — architectures, access, and what OMEGA NEXUS can retrieve

Prompt XVIII §II. Implementation: `src/loader/analyze.js` (engine), `api.loaderSource` / `api.loaderStage` (worker ops `loader`, `stage`),
`src/app/loader-view.js` (the **Loader** tab), `api/fetch.js` + `api/_lib/safe-fetch.js` (retrieval). Tests: `tests/xviii-loader.test.mjs`,
`tests/api.test.mjs` (fetch and owner credentials), `tests/e2e/ui.e2e.mjs` (the two "Loader:" tests).

## The short answer

> *If I provide OMEGA NEXUS with a loader, under what circumstances can it retrieve the associated obfuscated Lua source, analyze it, and
> reconstruct it?*

OMEGA NEXUS retrieves a payload **only when the loader names a fixed address on a public host and you press Fetch**. The page's fetcher reads
GitHub raw and gist, Pastebin, rentry, paste.ee and Discord attachments. The download is kept as its own stage, with its address, size and
SHA-256. It is not run. It goes through the same pipeline as a pasted script, so how well it is reconstructed depends on its obfuscator; see
`docs/MATRIX.md`.

It does **not** retrieve a payload in these cases:

- the payload needs a key;
- a licensing service hands the payload only to its own client;
- the address exists only at run time;
- the address is on a host outside the list.

In each of these cases it says which of these applies and continues with what the loader itself shows: the requests, the address templates,
the decoding steps, the service, and the key and device checks.

The one key-based route is **owner-configured**. The deployment's operator can attach their own credential, for example a token for their
own private repository, to specific addresses on allowed hosts. The credential is held in the server environment and is used only with an
operator token (see "Owner credentials" below). Nothing sends a user's `script_key` to a service, and nothing pretends to be a game client.

## Architectures the analysis distinguishes

Every class is reported with the evidence it was read from. A loader usually has several classes.

| Class | What it means | How it is recognised (static) |
|---|---|---|
| `direct-remote` | `loadstring(game:HttpGet("<fixed URL>"))()` | A network call whose result flows into `loadstring`/`load` with no step in between, and whose address is a literal. |
| `http-client` | The payload comes through an executor HTTP client | `request{…}`, `http_request`, `syn.request`, `http.request`, `fluxus.request`, or `HttpService:RequestAsync`. The address is read from `Url`. |
| `api-backed` | The address is a versioned API, or a JSON response is decoded | A `/api/` or `/vN/` path, or `JSONDecode`. |
| `token-auth` | A key or token takes part in the request | Assignments to `script_key`, `api_key` and similar names. Weak names such as `key` or `token` count only when set globally to a credential-shaped string. Also key-like URL parameters and `Authorization`/API-key headers. |
| `device-bound` | The service ties access to a device | `gethwid`, `GetClientId`, `RbxAnalyticsService`, `identifyexecutor`. |
| `encoded` | The address or the download is encoded | The address is built with `string.char` (decoded statically when every byte is constant), or the download goes through a decoding call (`base64…`, `decrypt…`, `decompress…`) before `loadstring`. |
| `multi-stage` | More than one fetched chunk is executed | Two or more requests reach an execution sink. Downloaded stages that are loaders again are classified as such (`classifyStage`). |
| `dynamic` | The address exists only at run time | The address comes from calls, fields or values the file does not fix. |
| `runtime-constructed` | Part of the address is computed | A fixed host and path joined with run-time parts (`.. game.PlaceId ..`). The template is shown as `https://host/x/{game.PlaceId}.lua`. |
| `config-first` | Configuration is set before the payload is loaded | `getgenv().X = …` or `_G.X = …` before the request. |
| `cached` | The payload is kept on disk | `writefile` plus `readfile`/`isfile` around the request. |
| `asset-module` | A platform asset is the payload | `require(<asset id>)` or `game:GetObjects("rbxassetid://…")`. |
| `bytecode-returning` | A compiled chunk is involved | The file carries a Lua bytecode header. A downloaded stage that is bytecode is classified `bytecode` and routed to the decompiler. |
| `payload-in-file` | The program is in the file | There is no network request, or the file carries a large literal, a numeric array or its own program next to its requests. |

Address resolution never runs anything. It follows local bindings, `..`, `string.format`, `table.concat`, Luau string interpolation and
constant `string.char`. Anything else becomes a named hole.

### Measured on the corpus

The input was 99 corpus files that contain a network call: 88 unique by SHA-256, mostly real third-party scripts in `local/corpus`. They were
read with the analyzer as committed (`node` + `src/loader/analyze.js`, nothing executed).

- **57 of the 88 make requests.** 25 are pure loaders; the other 32 carry a program of their own and load libraries.
- **Cases:** 36 public, 11 with no authorised interface (10 Luarmor, 1 platform asset), 9 dynamic, 1 key-only.
- **Pure loaders:** 16 public, 7 with no authorised interface, 2 dynamic. 11 of the 16 public ones name a host on the fetch list; the other 5
  need you to fetch them yourself.
- **Architectures:** direct-remote 35, cached 16, config-first 13, dynamic 13, multi-stage 10, runtime-constructed 9, api-backed 8,
  device-bound 6, token-auth 4, http-client 4, asset-module 1.

This sample is selected by "contains a network call", so these are not population frequencies. They show that every class occurs in real
scripts, and that the public direct loader is the common case.

## The six accessibility cases

The analysis puts each loader in one case. Other cases that also apply are listed under it.

| # | Case | Decided when | What happens |
|---|---|---|---|
| 1 | Payload in the loader | There is no network request. | The normal pipeline handles the file. |
| 2 | Public source | Every executed address is a fixed public address with no key. | Fetch on your action if the host is on the list. Otherwise you fetch it and paste it. |
| 3 | Needs a user-owned key | Key or token markers, a key-system service, or an auth header. | Not retrieved. Only the key holder may obtain it, through the service's own tools. The owner-credential route covers the operator's own resources. |
| 4 | Generated dynamically | An executed address is dynamic or partly computed. | Not retrieved. The fixed parts of the template are shown. |
| 5 | Encrypted or transformed | A decoding step sits between the download and `loadstring`, or the address is encoded. | The retrieved file is the encoded form. The pipeline decodes it where the encoding is known. |
| 6 | No authorised interface | A licensing service that serves only its own client (Luarmor), or a platform asset. | Not retrieved. The loader's visible structure is analysed. |

## Services investigated

| Service | What was verified, and how | Recognised by | Case |
|---|---|---|---|
| **Luarmor** | Observed in 10 corpus scripts, read statically. Bootstraps download `cdn.luarmor.net/v4_init_<name>.lua`, cache it with `writefile` and run it. Loaders use `api.luarmor.net/files/v3/loaders/<hex>.lua` and `/files/v4/loaders/<id>.lua`. An SDK library comes from `sdkapi-public.luarmor.net/library.lua`. The client sets `script_key`. Third-party scripts show a key check that returns codes such as `KEY_HWID_LOCKED`, which suggests device binding. Luarmor's own documentation (`docs.luarmor.net`) is **not reachable from this environment** (DNS refused by the network policy), so nothing beyond the observed loaders is claimed. Community API wrappers describe owner-side key and user management (add key, reset HWID); no documented endpoint hands a protected script to a third party was found. | `*.luarmor.net`, or `script_key` together with "luarmor" | 6 (and 3) |
| **Polsec** | **No public documentation, service page or loader sample could be found.** Web searches for "Polsec" return nothing related. Nothing is claimed about it. A Polsec loader is analysed generically: requests, address shapes, key markers, and the case decided from those. | — | decided generically |
| **Panda Development key system** | A third-party mirror of its client-library documentation describes a "get key" link and a key-validation call against the service's API. How the protected script is delivered is not documented publicly. | `*.pandadevelopment.net` | 3 |
| **GitHub raw / gist, Pastebin, rentry, paste.ee, Discord CDN** | Public file hosts. Public files are readable without credentials. These are the hosts `/api/fetch` reaches. | host | 2 |
| **Roblox assets** | `require(<id>)` and `GetObjects` are delivered by the platform to a running game. This tool has no authorised route to the asset store. | `require(<number>)`, `rbxassetid://` | 6 |

## Feasibility table

| Category | Retrieval method | Authentication | Documentation | Accessibility | Reconstruction support | Restrictions |
|---|---|---|---|---|---|---|
| Payload in the loader | None needed | None | n/a | Full | The normal pipeline, measured per obfuscator in `docs/MATRIX.md` | None |
| Direct loader, allowed public host | `/api/fetch` on your confirmation | None | Host's public raw URLs | Full | The downloaded stage goes through the pipeline | Allow-list, https only, 4 MB, 10 s, no ports or credentials in the URL, redirects only within the list |
| Direct loader, other public host | You fetch it and paste it | None | — | You decide | Same as above, once pasted | The fetcher does not reach hosts outside the list, by design (no open proxy) |
| Operator's own private file (repo, gist) | `/api/fetch?auth=1` with an operator token | The operator's credential, from server env | GitHub token docs (fine-grained, read-only) | Operator only | Same pipeline | Token-gated; scoped to host and path prefix; never returned; not carried across redirects |
| Key-system service (Panda, …) | **None** | The user's key | Third-party client-library docs only | Owner only, via the service | The loader's structure only | No key is sent anywhere by this tool |
| Licensing service that serves its own client (Luarmor) | **None** | Key, plus device binding | Official docs unreachable here; no third-party source endpoint found | Not accessible to third parties | The loader's structure; the bootstrap is recognised (`luarmor` family) | No client impersonation, no HWID spoofing, no key sharing |
| Dynamic or runtime-constructed address | **None** from the file | Varies | — | Unknown until run time | The address template and the run-time values it depends on | Not resolved by running the loader |
| Encrypted or transformed download | `/api/fetch` if the address is public | Varies | — | The encoded form | Decoded by the pipeline where the encoding is a known layer | Unknown encodings stay encoded |
| Platform asset (`require(id)` / `GetObjects`) | **Owner provider** `/api/retrieve` (`roblox-asset`, Prompt XIX): Roblox Open Cloud Asset Delivery, then the model's scripts are extracted (`src/loader/rbx.js`) | The owner's Open Cloud key (`legacy-asset:manage`), configured by the operator | Roblox announcement (see `docs/API-CATALOGUE.md`) | The owner's assets | Each script goes through the pipeline | Off unless `QS_RETRIEVE_MODE` and `QS_ROBLOX_API_KEY` are set; ZSTD model chunks not decoded |
| Server-delivered VM program (LuaQ) | **None** | Vendor session | — | Not accessible | The VM architecture is described (`docs/targets/LUAQ.md`) | The program is not retrieved |

## Owner credentials (`/api/fetch`, optional)

This is for the case where the payload belongs to whoever runs the deployment, such as their own private repository.

- `QS_FETCH_AUTH` is a JSON array of `{ host, pathPrefix, header?, scheme?, secretEnv }`. The secret itself lives in the environment variable
  named by `secretEnv`.
- Only hosts already on the allow-list can be configured, so credentials never widen what the fetcher reaches.
- A request uses the credential only with `auth=1` **and** the header `x-fetch-token: <QS_FETCH_AUTH_TOKEN>` (constant-time compare), and only
  for URLs under the configured prefix. Without both, the answer is 501 when nothing is configured, 401 for a bad token, and 403 for an address
  outside the scope.
- The credential is re-checked on every redirect hop, so a redirect cannot carry it to another host or path.
- The page never holds the operator token. This route is for the operator's own tools. It is not meant for visitors.

## Prompt XIX: Loader Intelligence

Retrieval became an end-to-end, staged process (`src/loader/intel.js`):

1. identify;
2. route;
3. transport;
4. payload, with its layers (`src/loader/payload.js`);
5. classify;
6. reconstruct;
7. recurse into further loaders.

Each stage is measured on its own: an HTTP success is not a payload, a payload is not a reconstruction, and a reconstruction is not verified
behaviour.

- **Owner providers.** `/api/retrieve` adds three owner-authorised providers: Roblox Asset Delivery, GitHub contents and Pastebin owner raw.
  It is off by default.
- **Measured.** On 22 fixture loaders (`docs/LOADER-SCORECARD.md`), through the real server handlers, retrieval, decoding, reconstruction
  and behaviour are counted separately.
- **Services.** All service research is in `docs/API-CATALOGUE.md`.

## Loader Analysis module — status

**Completed (in this branch, with tests):**

- Static analysis:
  - requests and the API each uses;
  - address shapes;
  - sinks and decoding steps;
  - architectures;
  - service family;
  - key, token and device markers, with values redacted (the test asserts that no secret value appears anywhere in the result);
  - the six cases;
  - a retrieval route per request.
- An obfuscated loader: the `loader` op also reads the recovered text and uses whichever names more addresses.
- Stages:
  - fetched only after a confirmation dialog;
  - each one is classified (script, loader, bytecode, web page, binary) and kept separately with its SHA-256;
  - each can be opened in the Deobfuscator or analysed as a further loader, and the original loader can be put back.
- The Loader tab:
  - the case, with a six-step ladder;
  - a progress list (read → identify → decide → retrieve → analyse);
  - architecture cards, the request table with routes, service notes, markers and stages.
- Owner credentials on `/api/fetch`.

**Not done / limits:**

- Addresses computed by code the analyzer cannot evaluate statically stay templates. Running the loader to learn them would mean executing a
  network client, which this tool does not do.
- Service families are recognised only where there is evidence: hosts observed in real loaders, or public documentation.
- Polsec is not recognised, because nothing about it could be found.
- `docs.luarmor.net` and `docs.rs` could not be read from this environment. Adding them to the environment's network allow-list would let the
  Luarmor notes be checked against the official documentation.
