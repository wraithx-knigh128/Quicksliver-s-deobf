# Prompt XXVIII — QuickSilver v1.8: one Deobfuscate, the GitHub workflow end to end, and the supplied artwork

Measured 2026-11-21 in this repository. Every number below comes from a file in `data/research/` or a test in `tests/`, named where it is used.

## 1. Why the Prompt XXVII implementation fell short

| What XXVII shipped | Why it did not meet the requirement |
|---|---|
| Three entry points on the landing (Workspace, **VM Reverser**, **Loader & GitHub**), the same three in the title bar, three feature cards, and 13 tabs | The VM reverser and the loader analysis were separate tools the person had to choose between, not parts of one pipeline. |
| A GitHub link was retrieved, put in the editor, and then *branched* (`onGitHubFile`): a loader opened the Loader tab and ran Loader Analysis, which only **listed** what the loader downloads; retrieving and reconstructing the payload needed "Run Loader Intelligence", a confirmation dialog, and reading the result in a stage card | A GitHub loadstring never ended in the reconstructed payload as *the* result. The Deobfuscator tab showed the loader's own code; the payload's reconstruction was buried in the Loader tab. Retrieval and reconstruction were two workflows. |
| Plain (not obfuscated) retrieved code was "shown as retrieved", nothing more | Inconsistent with the other paths; the person had to press Deobfuscate again. |
| Names were measured on the plain engine only (`tools/audit/names.mjs`) | The **site** runs the NEXUS pipeline, whose role mapper named every `GetService(...)` result `service`, `service1`, `service2`. Measured now: on VM-lifted fixtures the site recovered **32 of 119** names the program states for itself, the plain engine **80 of 119** — the site was the worse of the two, and nobody saw it (§5). |
| The renamer treated any script whose names were mostly one or two letters as minified | A plain module `local M = {} function M.add(a, b) … return M` came back as `local tbl = {} function tbl.add(param, param1)`: the author's names traded for placeholders (§5). |
| Original vector art (`art/*.svg`) "in the direction of" the supplied pictures | The prompt asks for the **supplied** images as the foundation; they were only used as a mood reference. |
| Lilita One chosen as "a legal font in the spirit of GTA" | The GTA font was never identified, so the choice could not be compared with it (§8). |
| A landing screen as a separate gate before the work, with feature cards | A generic marketing pattern; the work was one click further away than it needed to be. |

## 2. The unified pipeline (`src/pipeline/unified.js`)

`deobfuscate(input, deps)` is the only thing the Deobfuscate button calls. It does no I/O itself: the page passes functions that call its own engine worker and the site's `/api/github` and `/api/fetch`; the tests pass the real engine functions and a mock network.

| # | Stage | What decides it |
|---|---|---|
| 1 | Input recognition | `recognizeInput`: empty, compiled chunk, GitHub link, other link, loader (`loadstring` + an HTTP call), source |
| 2 | Loader identification | `analyzeLoader` on the program — and, for an obfuscated program, on its **reconstruction** too, so an obfuscated loader is followed as well |
| 3 | URL & source analysis | each address: its form (GitHub file / raw / API / gist / repository / profile, or another host) and whether an authorised route reaches it |
| 4 | Authorised retrieval | GitHub through `/api/github` (host allowlist, redirects re-checked, token only to GitHub); other public paste hosts through `/api/fetch`; nothing else |
| 5 | Payload identification | `decodePayload` (gzip/zlib/base64 layers, models, bytecode); a 200 that is HTML, JSON or text is not a payload; then the program's **role**: obfuscated, secondary loader (followed), dependency, configuration, plain, invalid |
| 6 | Obfuscator & version detection | `detect` |
| 7–12 | Transformation analysis · strings & constants · VM & bytecode · control & data flow · functions & expressions · source generation | the engine's own steps (`recoverSource(…, {nexus: true})`, the same call the workbench makes), grouped by what each step does; VM lifts report functions and instructions; unresolved places, missing constants, empty bodies and placeholder parameters turn a stage to *warn* |
| 13 | Syntax & semantic validation | the outcome class (`src/validate/outcome.js`) and its evidence; behaviour is compared only when the person ticks "Check behaviour" |
| 14 | Delivery | the reconstructed **payload** the input leads to — followed through every loader — plus each dependency and intermediate loader as labelled extras |

Delivery rules (each is a test in `tests/xxviii-unified.test.mjs`):

* A loader is followed to the first program that is not itself a loader; that program's reconstruction is the result. Loaders on the way are delivered as `name.loader.lua`, never as the payload.
* A loader whose payload was not obtained delivers **nothing in its place**. If the loader's own code was reconstructed (an obfuscated loader), it is shown labelled "the loader, not the payload" and the verdict stays *Payload unavailable*.
* Every address is retrieved once (a loop of loaders ends); at most 4 levels, 10 retrievals and 4 dependencies per run.
* Nothing retrieved is run. Luarmor-style protected services are never requested.

## 3. GitHub: recognition, retrieval, classes

Forms recognised (unchanged from XXVII, now all handled by the one pipeline): `github.com/O/R/blob/REF/PATH`, `…/raw/…`, `raw.githubusercontent.com/O/R/REF/PATH`, `api.github.com/repos/O/R/contents/PATH?ref=REF`, gists, `github.com/O/R` (repository), `…/tree/REF/PATH` (folder), `github.com/O` (profile), and any of these inside a loadstring.

What the person is told about where the program came from (`SOURCE` in `unified.js`):

| Class | When |
|---|---|
| Supplied directly | the program is the input |
| Public source retrieved | a file was retrieved and reconstructed (or is plain, a configuration or a module) |
| Public loader; its payload is protected | the loader's address belongs to a protected service (Luarmor and the like): not requested |
| Authorisation required | a token GitHub rejected, a Premium refusal from this site, or a route that needs the owner's key |
| Private or deleted | GitHub answers 404 for both without a token; the page says so and offers the token field |
| Missing or deleted | the account, branch or file does not exist |
| Unavailable | rate limit (with the retry time), legal block, too large, GitHub not answering |
| Retrieved, but not reconstructed | the file arrived and is Lua, but it does not parse, or the reconstruction did not reach a usable result |
| Retrieved, but the content is not Lua | an HTML page, a JSON error, text |

### Live check (real GitHub, real `/api/github` handler, real engine): `data/research/live-github-xxviii.json`

`NODE_USE_ENV_PROXY=1 node tools/live/github-unified.mjs …` serves `api/github.js` locally and runs the pipeline exactly as the page does.

| Input | Result |
|---|---|
| `loadstring(game:HttpGet("https://raw.githubusercontent.com/wraithx-knigh128/Quicksliver-s-deobf/…/zartha/s07_roblox_style__constants.lua"))()` | retrieved 17,053 bytes → Zartha VM lifted (3 functions, 83 instructions) → `s07_roblox_style__constants.deobf.lua`, 57 lines, 0 of 12 locals placeholders, **syntax-valid, behaviourally unverified**, source *Public source retrieved* |
| the same file as a `github.com/…/blob/…` link | the same result |
| `github.com/wraithx-knigh128/Gtimcrow/blob/main/message.txt` and a loadstring of its raw URL | retrieved 344,059 bytes (SHA-256 `39b61811…`) → **does not parse** (7684:13) → *Retrieved, but not reconstructed*, nothing delivered. This is the other tool's broken output from Test 8; the pipeline refuses to "deobfuscate" it. |
| `…/Gtimcrow/blob/main/does-not-exist.lua` | raw 404; the follow-up API probe was refused by this build environment's proxy (below), so the class is *Unavailable*, not *Missing* |
| `github.com/wraithx-knigh128/Gtimcrow` (a repository listing) | the API call was refused by this environment's proxy: *Unavailable*, nothing delivered |

**Not live-verified here:** every `api.github.com` call (repository and profile listings, the probes that tell *missing* from *private*) is answered `403` by this session's network proxy, which only opens the GitHub API for repositories attached to the session; attaching the repository was not permitted. Those paths are covered by `tests/xxvii-github.test.mjs` (the handler against GitHub's documented responses) and `tests/xxviii-unified.test.mjs` / the e2e tests (the pipeline and the page against `/api/github`'s answers); on the deployed site the API is reached directly.

## 4. Discovery: relevant only

* A **repository or folder** link lists that repository's Lua files and retrieves the entry point when it is unambiguous (the only file, or the only one named `main`/`init`/`loader`/`source`/`script`); otherwise the person chooses. Then only the files the entry point **names** (by path or module name, in its text or its reconstruction) are retrieved as dependencies; a file nothing names is never read (test: *repository link … no indiscriminate harvesting*).
* A **profile** link lists the account's public repositories; only the one chosen is opened.
* A **loader** is followed only to the addresses it contains. No search, no crawling of other repositories or other accounts.

## 5. Reconstruction repairs

| Defect (found while building the pipeline) | Fix | Test |
|---|---|---|
| The site named `GetService("Players")`, `("RunService")`, `("ReplicatedStorage")` results `service`, `service1`, `service2` | a role read from the callee alone ("result of GetService()") gives way to the name the call's own argument states | `xxviii-unified: three GetService results …` |
| Plain modules lost their authors' names (`M`, `a`, `b` → `tbl`, `param`, `param1`) | short names count as a minifier's only in runs of five or more (or with machine-made names); otherwise a short name is renamed only when evidence names it, never to a type-only fallback; `M` is conventional | `names: plain source keeps its author's names` |
| Parameters stayed `param`, `param1` although the program said what they were | **usage evidence**: the members the program reads or calls on a variable name its kind when they belong to one kind of Roblox object only (`x.UserId`, `x:Kick()` → `player`; `x.WalkSpeed`, `x:TakeDamage()` → `humanoid`; `x.KeyCode` → `input`; `x:Disconnect()` → `connection`; `x:FireServer()` → `remote` …); members two kinds share (`Name`, `Parent`, `Position`) and members of two kinds on one variable decide nothing | `MEMBER_KIND` / `kindFromMembers` in `src/passes/rename.js` |
| Retrieved Lua that does not parse was labelled "not Lua" | *Retrieved, but not reconstructed* | `xxviii-unified: a retrieved file that is Lua but does not parse …` |

Names, measured over every corpus fixture with an original (`tools/audit/names.mjs`, 1,227 files; *anchored* = locals of the original whose initialiser states their name, e.g. a `GetService` call; *generic* = `_r3`, `a1`, `param`, `value`, `tbl` …):

NAMES_TABLE

No VM instruction handling changed in this prompt; VM lifts are reported stage by stage (unresolved instructions, missing constants, empty bodies) instead of being folded into one verdict.

## 6. False successes removed

* A GitHub loadstring no longer ends with the **loader** in the result pane: the result is the payload's reconstruction, or nothing with the reason.
* A retrieved file is never reported as reconstructed because it was retrieved: retrieval (stage 4) and reconstruction (stages 7–13) succeed or fail separately, and the source class says which.
* A Premium refusal from the server is *Authorisation required*, never a retrieval (e2e: *a Premium refusal …*).
* The stage rail cannot show *done* for a stage that did not run: stages that were not reached are *skipped* with "Not reached." or the reason.

## 7. Assets used

| File | From | Use |
|---|---|---|
| `img/sunset-desktop-960/1672.{webp,jpg}` (37 / 76 KB WebP) | the supplied 1672×941 PNG (palm sunset) | the backdrop on screens wider than 4:5 |
| `img/sunset-mobile-540/828.{webp,jpg}` (27 / 42 KB WebP) | the supplied 1242×2688 JPEG (portrait palm sunset) | the backdrop on tall screens (phones) |
| `img/city-588.{webp,jpg}` (22 KB WebP) | the supplied 588×441 city-and-highway JPEG | the one cinematic picture, in the Coverage band |
| — | the supplied GTA VI logo | **not used** (reference only; no logo on the page) |

The first two arrive through `<picture>` with WebP and JPEG sources; the one that fits is preloaded. The rights question is in `THIRD_PARTY_NOTICES.md`: the city frame appears to come from Rockstar Games' GTA VI trailer, and publishing these pictures needs the rights holder's permission.

## 8. Typography

* **The GTA font is Pricedown** (Ray Larabie, Typodermic Fonts, 1998). The *Grand Theft Auto* wordmark is a customised Pricedown Black; the *VI* numeral of the GTA VI logo is custom lettering, not a published typeface. Sources: Typodermic's licence page, Font Squirrel's Pricedown licence summary, GTA Wiki *Fonts*, GamesRadar and Creative Bloq on the logo's history.
* **It is not shipped.** No font file was supplied, and Pricedown's free licence covers desktop use, not embedding in a website (webfont use needs a paid licence from the foundry).
* **What the page does:** the display face `"QS Display"` (`css/site.css`) uses the visitor's own installed Pricedown when the browser allows it (`local()`: nothing downloaded or redistributed), otherwise **Lilita One** (OFL). Lilita One was kept after a side-by-side comparison of fourteen free display faces against the GTA VI logo's lowercase lettering (`docs/assets/font-comparison-xxviii.webp`): it is the closest in weight, condensed proportions and x-height; Titan One and Paytone One are rounder and wider, Passion One lighter. `fonts/licensed/README.md` is the drop-in for a licensed Pricedown webfont.
* Display face: brand, Premium User label, headings, the Deobfuscate button. Text: Rubik. Code: the platform's monospace (Cascadia / SF Mono / Menlo / Consolas), unchanged for readability.

## 9. Design

* **One page.** Top bar (brand, Deobfuscate · Coverage · Expert tools, the Premium User badge), the wordmark and Premium User label over the open sky of the supplied picture, then the workspace: one text area (paste, drop, or Upload file — source, a loadstring or a link), a live line saying what was recognised, *Check behaviour*, and **Deobfuscate**. While it runs, the fourteen stages fill in (each clickable for its detail); then the result: verdict, file name, facts (source, protection, lines, time), Download · Copy · Report · Open in Expert tools, the code, and four closed sections (why this verdict, all fourteen stages, loader chain, virtual machine). Then the Coverage band with the supplied city picture, and the not-affiliated notice.
* **Expert tools** is the former workbench, one quiet link away (and one button back). Its *VM Reverser* and *Loader & GitHub* tabs are now *VM details* and *Loader details*: inspection panels, not separate products. The landing gate, the section switcher and the feature cards are gone. The choice of screen lasts for the tab only; a new visit starts on Deobfuscate.
* Phone: the portrait picture, stages in two columns, a full-width Deobfuscate, the code scrolling inside its own box (no horizontal page scroll — e2e).

## 10. Performance (`data/research/perf-xxviii.json`, headless Chromium, software compositing)

| Screen | fps | long frames | layouts / paints (5 s) | main thread ms (5 s) | FCP ms | CLS |
|---|---|---|---|---|---|---|
| Deobfuscate page, desktop | 60.2 | 0 | 0 / 0 | 120 | 144 | 0.001 |
| Deobfuscate page, phone, CPU 4× slower | 60.2 | 0 | 0 / 0 | 521 | 212 | 0 |
| Deobfuscate page while running, desktop | 59.8 | 0 | 3 / 178 | 358 | 160 | 0.002 |
| Expert tools, desktop | 60.4 | 0 | 0 / 0 | 78 | 104 | 0.001 |
| Expert tools, phone, CPU 4× slower | 60.4 | 0 | 0 / 0 | 213 | 176 | 0.001 |

Prompt XXVII's landing for comparison (`data/research/perf-xxvii.json`): landing, desktop 47.6 fps, 159 ms main thread; landing, phone, CPU 4× slower 60.2 fps, 721 ms main thread. The supplied pictures add 37–76 KB (desktop) or 27–42 KB (phone) as WebP; the SVG scene they replace was removed.

Only `transform` and `opacity` animate; there is no `filter` or `backdrop-filter` on the page (e2e checks every element). The backdrop drift is the only continuous animation and pauses in Expert tools; under reduced motion nothing animates. The paints during a run are the result being drawn and scrolled into view, not an animation.

## 11. Tests

TESTS_SECTION

## 12. Limitations

* **Behaviour** is unverified unless the person ticks *Check behaviour*, which runs the input and the reconstruction side by side in the project's own sandbox interpreter (KNOWN-ISSUES 78, 80).
* **GitHub API paths** were not live-verified in this environment (§3).
* **Dependency discovery** is textual: a file is a dependency when the entry point names it by path or module name. Roblox-style `require(script.Parent.Module)` cannot be mapped to repository files and is not followed.
* **Usage naming** knows only members that belong to one Roblox class; a program that uses only shared members (`Name`, `Parent`, `Position`) keeps its placeholders. That is deliberate: no evidence, no name.
* **Luraph v14 handler-table and v15.1/15.2, IronBrew 3, MoonSec V3, PSU** and the other formats listed in KNOWN-ISSUES are still identified, not reconstructed; the pipeline reports them as such.
* **The supplied pictures** need publication rights before a public launch (§7).
* **Pricedown** shows only where the visitor has it installed, until a webfont licence is bought (§8).
