# Prompt XVIII — Full-System Recovery & Intelligence Initiative: report

Completed work and proposed work are kept apart. Every "done" item names its evidence: a file, a test, or a measurement. Commits on
`ccr-17f6469c-lf3p64` after `6228830`.

## 1. Errors fixed

Each failure was reproduced first, by driving every engine operation with edge-case inputs and by calling every API handler with mocked
requests. The root cause was then fixed, and a regression test added.

| Failure (reproduced) | Root cause | Fix | Regression test |
|---|---|---|---|
| `verifySource` threw `TypeError: Cannot read properties of undefined (reading 'length')` for every input without a recovered program | No input validation; `verifyRecovery` dereferenced `undefined` | Answers `{ ok:false, error }`; the page shows the reason instead of storing it as a result | `tests/xviii-audit.test.mjs` |
| `/api/fetch` answered **500** for a link whose file name holds a malformed `%`-escape | `decodeURIComponent` threw `URIError` outside the handled path | A malformed escape is kept as the literal name | `tests/api.test.mjs` |
| `/api/fetch` reported an empty answer (204 or zero bytes) as "The download was interrupted" | `res.body` was `null`; `getReader()` threw and was mapped to "interrupted" | Empty bodies read as empty; the endpoint answers 422 "empty file" | `tests/api.test.mjs` |
| `/api/license` answered any HTTP method, and failed outside Vercel | Used framework helpers (`res.status().send()`); no method check | Plain Node response, GET only, id read from the URL when there is no parsed query, repeated `?id=` refused | `tests/license.test.mjs` |
| The Custom format tab rendered unstyled | It used `.pad`, `.row-item`, `table.table` and `.meta`, which had no CSS | Report-page styles added (one readable column, section headings, tables) | screenshots; e2e |
| On a phone the header lost its action row; on a tablet the command bar scrolled its first item (Deobfuscate) out of view | Flex rules let the actions share a row at zero width; the command bar was a single scrolling row at every width | Explicit header rows; the command bar wraps between 860 and 1100 px | screenshots at 390, 820, 1180 and 1440 px; e2e "phone-sized screen" |

All the other operations returned without throwing on the same inputs, which are now a regression test: empty, whitespace, BOM, shebang,
CRLF, syntax errors, unterminated strings and comments, 3000-deep nesting, Luau syntax, bytecode headers, binary data and NUL bytes.

### Remaining issues, prioritised

1. **LuaQ**: the program is not in the file (KNOWN-ISSUES 67). Out of scope by design.
2. **MoonVeil 2.1.0**: only two builds of one program exist, so other handler kinds are unknown (60).
3. **MoonVeil 1.4.5 and 2.0.26**: structural reconstruction is partial (19, 47).
4. **Prometheus current mainline**: loops over `pairs` stay `while` loops (68). s03 diverges inside Prometheus itself (58).
5. **IronBrikked**: follows its own compiler's miscompiles (57).
6. **AzureVM**: 11 of 48 layered builds keep the VM (65).
7. **Loader Analysis**: static only (69).
8. **MBA**: linear class only (70).

## 2. Loader architectures

Fourteen classes, each detected statically with evidence; see `docs/LOADERS.md` for the definitions:

- direct-remote, http-client, api-backed, token-auth, device-bound, encoded, multi-stage, dynamic, runtime-constructed, config-first, cached,
  asset-module, bytecode-returning, payload-in-file.

Measured on 88 unique corpus files that contain a network call:

- 57 make requests, of which 25 are pure loaders.
- Cases: 36 public, 11 with no authorised interface, 9 dynamic, 1 key-only.
- Most frequent architectures: direct-remote 35, cached 16, config-first 13, dynamic 13, multi-stage 10.

## 3. API feasibility

The full table is in `docs/LOADERS.md`. In short:

- **Retrievable on your action:** fixed addresses on GitHub raw and gist, Pastebin, rentry, paste.ee and Discord attachments, through
  `/api/fetch`.
- **Owner-configured:** the operator's own private files, through `/api/fetch?auth=1`. The credential is in the server environment, the route
  is token-gated, scoped to a host and path prefix, and the credential is re-checked on every redirect.
- **Not retrieved:**
  - key-system services (Panda: case 3);
  - licensing services that serve only their own client (Luarmor: case 6);
  - platform assets;
  - dynamic addresses.

**Answer to the question.** OMEGA NEXUS can retrieve, analyse and reconstruct a loader's payload **when the loader names a fixed public
address on an allowed host and you confirm the fetch**. The stage is then analysed like any script, and how well it is reconstructed depends
on its obfuscator. When the payload needs a key, comes only from a service's own client, or has an address that exists only at run time, it
is not retrieved, and the analysis reports the loader's structure.

**Investigated services:**

- **Luarmor:** host patterns observed in 10 real loaders. Its official documentation was not reachable from this environment.
- **Polsec:** no public information could be found, so nothing is claimed.
- **Panda:** a third-party documentation mirror of its key-validation library.

## 4. Loader Analysis status

**Implemented:**

- `src/loader/analyze.js`;
- worker ops `loader` and `stage`;
- the Loader tab: case ladder, progress list, architectures, requests with retrieval routes, service notes, redacted markers, and retrieved
  stages with their SHA-256 that can be opened into the pipeline, with the loader restorable;
- owner credentials on `/api/fetch`.

**Tests:** 15 unit tests, 2 e2e tests, and the owner-credential test in `tests/api.test.mjs`.

**Security:**

- secrets are redacted in every result (a test asserts that no secret value appears in the result);
- nothing is fetched without confirmation, which the e2e test asserts;
- no client impersonation and no key forwarding.

## 5. New methods

See `docs/METHODS.md`; every source was verified.

**Added and tested:**

1. **Linear MBA simplification** (SiMBA, CheckMATE @ CCS 2022): `src/passes/mba.js`. 6 tests, including equivalence on real Lua 5.1. No
   current fixture uses MBAs, so it changes no target number.
2. **Loader source-to-sink analysis.**

**Mapped to code already in the repo:**

- devirtualisation (Rolles, WOOT 2009);
- opaque predicates by proof (LOOP, CCS 2015). The SMT solver was declined as an unnecessary dependency;
- differential testing;
- partial evaluation.

**Proposed:**

- handler synthesis (Syntia, USENIX Security 2017), with a test plan;
- condition-based structuring (DREAM, NDSS 2015), with the `goto` count as its metric.

## 6. Per-obfuscator improvements (measured)

- **Prometheus, current mainline (Weak/Medium/Strong, 21 builds):**
  - Measured on real Lua 5.1: all 21 recovered programs print exactly what the obfuscated programs print. 18 of 21 also print what the
    originals print; the 3 s03 builds diverge **inside Prometheus**, because Vmify drops the parentheses that truncate `gsub` to one value.
  - New this round: the Vmify generic-`for` lowering is re-raised, so 16 of the originals' 33 generic `for` loops now come back as `for`.
  - Correction to earlier docs: the claim that "the Vmify interpreter is the residual" was stale. The VM is fully lifted; what holds the
    semantic score below the gate is loop and expression form. Scorecard numbers: see "Scorecard after this round" below.
- **All other targets** (MoonVeil, IronBrew, IronBrikked, LuaQ, Vault, Hercules, Luraph, Panda, Hardened Obscura, RealObfuscator, AzureVM,
  custom): no change in this round. Their per-metric status is in `docs/VERSION-MATRIX.md` and `docs/MATRIX.md`, regenerated from the
  committed fixtures. Luarmor-wrapped scripts now get a Loader Analysis case instead of only a "remote loader" note.

## 7. Website redesign

Implemented in the real site (`index.html`, `css/app.css`, `src/app/main.js`, `src/app/loader-view.js`). Every element ID was kept, so all
69 earlier e2e tests still pass unchanged.

**Hierarchy:**

1. A header for sources, results and utilities.
2. A command bar with the one primary action and the tools in segmented, labelled groups: one hairline frame per group instead of a border on
   every button.
3. Tabs in three groups (Work · Reports · Library) with thin separators, and a new Loader tab.

**Design changes:**

- Calmer palette tokens and a lighter timer.
- One compact summary block under the editors, replacing two heavy strips.
- Report pages share a single readable column.
- Modals and menus with rounded corners and a short pop animation; motion is removed under `prefers-reduced-motion`.
- No gradients, glow or glass.

**Earlier requirements kept:** stacked editors, tool names shown in words at 1000 px, and the AI check always in view.

**Verified** at 1440, 1180, 820 and 390 px, in dark and light, with no horizontal page overflow at any size.

## 8. Tests

| Suite | Result |
|---|---|
| Unit and integration (`npm test`) | see "Final verification" below |
| e2e (`tests/e2e/ui.e2e.mjs`) | see "Final verification" below |

New test files:

- `xviii-audit` (2 tests);
- `xviii-loader` (15);
- `xviii-mba` (6);
- `xviii-prometheus` (4);
- additions to `api` (3) and `license` (2);
- 2 e2e tests.

## 9. Limitations

- Retrieval is limited to public allow-listed hosts on the user's action, plus owner-configured credentials. That is a design choice, not a
  gap.
- Service documentation that the build environment cannot reach (`docs.luarmor.net`, `docs.rs`) is not verified. Adding those hosts to the
  environment's allow-list would allow it.
- MBA support is limited to linear expressions inside `bit32` calls.
- Prometheus `pairs` loops stay as `while` loops.

## 10. Next priorities

1. A second LuaQ sample of a known program, for handler mapping (needs the user).
2. More MoonVeil 2.1.0 builds.
3. Handler synthesis (method 4) for unknown handler kinds.
4. Condition-based structuring for the `goto` fallbacks.
5. A proof of "no false key" to raise `pairs` loops.
6. The bot: still waiting for the go/no-go decision (`docs/BOT-RECOMMENDATION.md`).
