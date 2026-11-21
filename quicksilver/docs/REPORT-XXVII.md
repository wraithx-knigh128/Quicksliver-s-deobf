# Prompt XXVII — QuickSilver v1.8 Premium: engineering report

Every number here was measured in this round, on this repository, with the tool named next to it. Where something could not be measured (a GPU
device, GitHub's API from the build environment), it says so.

## 1. Summary

| Area | Before | After | Measured with |
|---|---|---|---|
| Zartha constant-protected builds: masked strings read back | 0 | **390 decided, 0 wrong, 79 left undecided** (15 builds) | `tests/xxvii-reconstruction.test.mjs`, check against the originals |
| Those builds that run exactly like the original program (real Lua 5.1) | 0 of 15 | 2 of 15 (the two Roblox builds) | reference Lua (`tests/helpers/lua-oracle.mjs`) |
| VM-lifted fixtures (107): names the original states through its own expressions, recovered | 62 of 119 | **80 of 119** | `tools/audit/names.mjs` |
| VM-lifted fixtures: parameters with placeholder names | 633 of 633 | 561 of 629 | `tools/audit/names.mjs` |
| GitHub link forms understood | raw + `blob` (via the general fetcher) | file, raw (`refs/heads/…`), `blob`/`raw`/`tree`, repository, profile, contents API, gist | `tests/xxvii-github.test.mjs` |
| GitHub failure classes told apart | 3 (refused / 404 / other) | 15 (`src/loader/github.js` OUTCOMES) | same |
| Server features enforced by the server | none | GitHub retrieval, Luraph engine, AI assistant | `tests/xxvii-github.test.mjs`, `tests/xxvii-premium-py.test.mjs` |
| Website (NEXUS) results that disagreed with the engine's own class on VM-lifted builds | 95 of 404 (90 called "not deobfuscated", 5 "invalid input") | **0 of 404** (class identical; 44 only lowered high→medium) | `tests/xxvii-reconstruction.test.mjs` "site mode" |
| Recovery time, 95 fixtures (mean per file) | 406–421 ms | 422–429 ms (within run-to-run noise) | `node timing.mjs` on both trees, two runs each |
| Workspace idle rendering | 60 fps, 0 paints | 60 fps, 0 paints, 0 running animations | `tools/perf/measure-ui.mjs` |
| False-positive "Luraph" detections from its macro names | 5 files (2 of the 43,288-file collection, 3 of the 748-file labelled sample) and the user's own Test 8 file | 0 | `tests/xxvii-reconstruction.test.mjs` "build-flag macros", `data/research/corpus-eval.json` |

## 2. Defect report (found this round, each fixed at its source)

| # | Defect | Root cause | Fix | Test |
|---|---|---|---|---|
| D1 | `game:GetService("Players")` rebuilt into a variable named `_r3_c1_1` (AzureVM and other lifters) | The renamer's machine-name test did not know the decompiler's later-generation temporaries (`_r<reg>_c<gen>`), so in "smart" mode they were left as they were | `looksObfuscated` recognises `_r…`, `a<n>`, `up<n>`, `L_<n>` | xxvii-reconstruction "register temporaries" |
| D2 | `local value1` … `value1 = RunService.Heartbeat:Connect(…)` kept the name `value1` | Names were derived only from a local's initialiser; a local declared empty and assigned later (how a decompiler writes hoisted locals) had no evidence | the first assignment is evidence | "declared empty" |
| D3 | `local function fn(param)` called as `fn(player.Character)`; `local value = fn(…)` where fn returns its local `humanoid` | No argument tracking (what every call site passes) and no return-value tracking | parameters named when every call site agrees; call results named after the one variable the function returns | same |
| D4 | Callbacks of Roblox events had parameter `param` | No use of the API's documented parameter names | `SIGNAL_PARAMS` (PlayerAdded→player, Heartbeat→deltaTime, Touched→otherPart, …) | "nothing is invented" |
| D5 | All strings of Zartha's constant-protected builds stayed masked (`_G["h~ov~ozozyw~"]`), 15 builds | Each string is `bxor(byte, k)`, k∈2..30, and the key is not in the file; this had been recorded as unrecoverable | key search ranked by evidence (§4); undecidable strings stay masked and are counted | xxvii-reconstruction, zartha-vm |
| D6 | (found while fixing D5) the generator's padding constants (`FakeConstants`: "SHA1", "65536", …) looked like strings to recover | They are never read by an instruction | only constants an instruction reads are the program's | precision test |
| D7 | (found while fixing D5) not every string in a protected build is masked | Some tables are written plain | "no mask" (key 0) competes with the 29 keys on the same evidence | "key 0" assertion |
| D8 | A GitHub link that failed said only "the site answered 404" | `/api/fetch` is a general fetcher; it never asked GitHub why | `api/github.js` asks GitHub's API the questions that separate the cases (§5) | xxvii-github |
| D9 | Repository and profile links, the contents API and `refs/heads/` raw links were refused | the fetcher only rewrote `blob` links | `parseGitHubRef` covers every documented form | xxvii-github |
| D10 | A private repository could not be read at all | no route for the user's own token | the user's token (this tab only) goes to GitHub only | xxvii-github |
| D11 | Premium checked only in the browser | the licence check ran client-side; server functions served anyone | `api/_lib/entitlement.js` and `licence_check` in `api/reconstruct.py` | xxvii-github, xxvii-premium-py |
| D12 | Pressing Deobfuscate on a loader ran the deobfuscator on the loader; on a pasted link, on the link text | no input recognition | `recognizeInput`: GitHub link → retrieval; loader → Loader Analysis; script → pipeline | e2e "input recognition" |
| D13 | A result full of placeholder names gave no sign of it | the evidence counted bodies and holes, not names | `naming` in the evidence; the outcome says how many locals are placeholders (class unchanged: names do not change behaviour) | "evidence" test |
| D14 | (live) the GitHub live test failed | GitHub's API was rate-limited for this machine (60/h unauthenticated); the test assumed it was not | the test accepts the honest `rate-limited` answer with its retry time — the server had reported it correctly | xxvii-github live |
| D16 | **The website reported correctly lifted VM programs as "not deobfuscated"**: 49 Zartha, 30 AzureVM, 7 LuaXen, 4 FusGato builds (a false negative, found by comparing the site's pipeline with the engine's) | NEXUS (always on in the page) checks that the result uses no global name the input's code does not; a program read out of a VM's data names its globals only in that data. The list of steps allowed to do that held 8 steps and none of the newer lifters | every VM lifter is in the list (`src/nexus/pipeline.js` REBUILDS) | "site mode: a program a VM lifter rebuilt" |
| D17 | **The website called 5 Zartha builds "invalid input"** that the engine recovers | NEXUS refused an input that does not parse as written; the plain pipeline mends the generator's documented defect first | such an input goes to the plain pipeline (which records the mend) | "site mode: an input that parses only after a documented repair" |
| D18 | **False-positive detection: a plain file was shown as "Luraph 85 %"** (the user's Test 8 comparison file, retrieved live from GitHub) | Luraph's build-flag macros (`LPH_NO_VIRTUALIZE`, …) counted as 0.85 evidence; they belong to source written *for* Luraph (it compiles them away), and the file defined fallback stubs for them. Across the 43,288-file collection the rule decided only 2 files, both LuaObfuscator builds with the same stubs | stubs defined in the file are no evidence; macros used without stubs are a hint below the threshold (0.45) | "build-flag macros" |
| D19 | (introduced this round, caught by the live check) the v1.8 theme hid the editor's text | the editor is a transparent text area over a highlighting layer; `premium.css` gave it an opaque background | the rule no longer touches the editor; an e2e assertion checks the text area stays transparent | e2e "VM Reverser" |
| D20 | (introduced this round, caught by the live check) a file retrieved from GitHub was said to show "no obfuscator" before detection had run | the retrieval kept the page busy while handing the file over, so detection refused to run and the note read its absence as "none" | the busy state ends before the hand-off; a detection that has not run is said as such | live GitHub check |
| D21 | (design, from the e2e suite) Deobfuscate on a loader opened only the Loader Analysis | the textual loader test could take an obfuscated script away from the deobfuscator | a loader is deobfuscated like any script, and its Loader Analysis runs as well | e2e "input recognition", "workflow: a script that only downloads its program" |
| D15 | Generated records drifted after the renamer change (`outputBytes` only) | records hold output sizes | `tools/formats/measure.mjs` regenerated; the recovered code itself is unchanged | formats.test |

## 3. VM reverser improvements (Part I)

The audit (`tools/audit/names.mjs`, every fixture with a known original) separated the causes the prompt listed:

* **Instruction interpretation, operand mapping, register/stack tracking, control flow:** no new defect found on the lifted fixtures (they parse,
  and the ones with readable strings already ran like their originals).
* **Missing constant recovery:** D5–D7 (Zartha). Fixed by key search.
* **Lost global references:** the masked names were the globals (`_G["`sq||"]` is `pcall`); key search restores them first, so the
  decompiler writes `pcall(…)`, not `_G[…]`.
* **Weak semantic reconstruction / generic parameters:** D1–D4. Names now come from data-flow evidence (definition, first assignment, return
  value, every call site, documented event signatures). No identifier is hard-coded: `localPlayer` comes from the field `.LocalPlayer` the program reads.

Example (Obscura 1.1.0 VM build of s07, before → after): `local _r3_c1_1 = game:GetService("Players")` → `local Players = …`;
`local function fn(param)` → `fn(character)`; `local value = fn(localPlayer.Character)` → `local humanoid = …`;
`value1 = RunService.Heartbeat:Connect(function(param)` → `connection = …(function(deltaTime)`.

## 4. New reconstruction method: evidence-ranked key search (`src/recover/keysearch.js`)

A masked string has only 30 readings. Each is priced by evidence:
1. **Role in the program** (from the lifted instructions): a global or method name must be an identifier; a string passed to `match`/`gsub`/`find`/`gmatch`
   is a pattern; to `format`, a format string; `select`'s first argument can only be `'#'` or a number.
2. **Runtime names:** a reading that is the one name the runtime defines (Lua library, Roblox globals, services, common API members) decides.
3. **Word statistics:** common English words (SCOWL sizes 10/20) are cheap, other words are priced by a character trigram model built from this
   repository's documentation; unbalanced quotes, stray symbols and lone letters are expensive.

A reading is accepted only with a clear margin (wider for short strings); otherwise the string stays masked and is counted. Precision on the 15
builds: every decided string is a string of the original program or one the generator adds (`Tamper detected`, `_OBFUSCATED`, `%d+`). The report says
these are judgements from evidence, not decryptions.

## 5. Loader and GitHub retrieval (Part II)

* **Input recognition** (`recognizeInput`): GitHub link, other link, loader, bytecode, script. A GitHub link is retrieved first; a loader is deobfuscated
  and its Loader Analysis runs too (what it downloads, and Loader Intelligence to retrieve and reconstruct each stage); a script goes to the pipeline.
* **Link forms** (`parseGitHubRef`): see §1. Owner/repo names, refs and paths are validated; `..`, encoded slashes, control characters, credentials,
  ports and look-alike hosts are refused before any request.
* **Retrieval** (`api/github.js`): only `raw.githubusercontent.com`, `api.github.com`, `gist.githubusercontent.com`; redirects re-checked every hop;
  size capped while reading; a 20 s deadline; 30 requests a minute per instance. The body must be Lua (or Luau, or a compiled chunk): HTML, JSON errors,
  "404: Not Found", binary and plain text are refused (`contentClass`). A 200 alone is never a success.
* **Diagnosis** (`diagnoseFailure`): raw 404 → GET repository → (404) GET owner → owner missing, or "not found, or private" (GitHub answers 404 for a
  private repository so as not to confirm it exists — its documentation says so); (200) GET branch → branch missing; GET contents → file missing / a
  folder. 403/429 with `x-ratelimit-remaining: 0` → rate limit with the retry time; 451 → legal block; 401 → token rejected.
* **Repository / profile:** a repository lists its `.lua`/`.luau`/`.txt` files (vendored folders skipped), a profile its public Lua/Luau repositories
  (forks and archives skipped). Metadata only: nothing is downloaded until the user picks a file.
* **Private repositories:** the user's own token, kept in the tab's memory, sent only with that request, only to GitHub; never logged or echoed.
* **Hand-off:** a retrieved obfuscated file goes straight to reconstruction, a loader to the Loader Analysis, plain source is shown as plain;
  Loader Intelligence uses the same route for GitHub stages.

Results: 11 tests against a fake GitHub that answers as GitHub documents, all passing. **Live:** the public file
`wraithx-knigh128/Gtimcrow/main/message.txt` was retrieved through the real raw host and classed `lua-invalid` (it is Lua that does not parse —
correct for that file); a missing file in the same repository was reported as `rate-limited` because GitHub's API refused this machine's
unauthenticated quota at that moment — also correct. GitHub's API could not be exercised further from here.

## 6. False successes and reporting (Part III)

* No reconstruction class was loosened. The six classes map to the prompt's list: validated (behaviourally validated), syntax-valid-unverified,
  partial, not-deobfuscated (detected but not reconstructed — with "Architecture identified (…); source unresolved" where known), unsupported-format,
  invalid-input / payload-unavailable / authorization-unavailable (failed).
* Zartha protected builds: 13 of 15 stay **partial** (some strings undecided — said so with the count), 1 became syntax-valid-unverified (every
  string decided), and none is called validated without a behaviour comparison.
* Placeholder names are now counted and said in every result (D13).
* GitHub: a retrieval is reported only for a Lua body; every failure is its own class (D8).
* **False negatives on the website (D16, D17):** 95 results of VM-lifted builds were shown with a worse class than the engine had established. The
  site's pipeline and the engine now agree on all 404 lifter fixtures, and a test keeps them agreeing.

## 7. Website (Parts V–VII)

* **Identity:** QUICKSILVER v1.8 / PREMIUM USER in Lilita One (OFL; a heavy rounded display face in the spirit of the reference, not a copy of any logo),
  with Rubik (OFL) for headings. Both self-hosted (`fonts/`), 49 KB, under the strict CSP (`font-src 'self'` added).
* **Scene:** original SVG art drawn by `tools/art/build-scene.mjs` (palms, skyline and its reflection, clouds, a raised highway with traffic, birds) over
  a CSS sunset. No reference image, logo or game asset is used; the landing says QuickSilver is not affiliated with Rockstar Games or Take-Two.
* **Screens:** a cinematic landing (first visit; remembered afterwards; the brand brings it back) and the workspace with section navigation —
  Workspace, **VM Reverser** (new tab: what the last reconstruction did with a VM, key-search and naming evidence, the verdict and why, and what the
  reverser reads, with a status per family), **Loader & GitHub** (a GitHub field over the Loader Analysis).
* **Premium:** "Premium user" is shown only when true (licensing not activated, or a Premium licence); otherwise "Premium · evaluation".
* **Motion:** only `transform` and `opacity` animate; no blur, no backdrop filter, no JavaScript animation loop; the scene stops in the workspace and
  under `prefers-reduced-motion` (tested). Dark is the default theme (the identity is a dark design); a stored choice of light is kept.

## 8. Performance (Part VIII)

`tools/perf/measure-ui.mjs`, headless Chromium with **software compositing** (no GPU in this environment), 5 s windows; `data/research/perf-xxvii.json`.

| Screen | fps | long frames | paints | layouts | main thread / 5 s | LCP | CLS |
|---|---|---|---|---|---|---|---|
| landing, 1440×900 | 47.6 | 0 | 0 | 0 | 159 ms | 268 ms | 0 |
| landing, 390×844, CPU 4× slower | 60.2 | 0 | 0 | 0 | 721 ms | 308 ms | 0 |
| workspace, 1440×900 | 60.4 | 0 | 0 | 0 | 70 ms | 160 ms | 0.001 |
| workspace, 390×844, CPU 4× slower | 60.4 | 0 | 0 | 0 | 260 ms | 284 ms | 0.001 |

Before (the previous interface, same tool): workspace 60 fps, 0 paints, 95 ms / 394 ms. The workspace is unchanged in cost. The landing's cost is the
browser ticking 13 composited animations (no paint, no layout); the two full-screen opacity animations were removed after the first measurement
(34 → 44–48 fps at 1440×900 in software). Page weight 3.49 MB → 3.90 MB (+ art 180 KB, fonts 49 KB, key-search word model 116 KB, styles 25 KB).
Largest contentful paint 420 → 236 ms (desktop). Recovery speed: unchanged within noise (§1).

## 9. Research (Part IV)

* **Naming without debug information.** The unluac decompiler (Rust) runs a separate naming stage fed by data-flow and treats debug metadata as
  evidence when present; LuaReSym (ICPC 2026) recovers variable liveness ranges in stripped Lua bytecode by data-flow and dominance (F1 0.974 against
  unluac/LuaDec heuristics). Neural approaches (DIRE 2019, DIRTY 2022) predict names from decompiled C with 66–74 % exact matches, much less on unseen
  code. QuickSilver keeps to evidence-backed names (what the program states); a learned model would be a separate, labelled layer (KNOWN-ISSUES 92).
* **Short-key XOR without the key.** Malware tooling brute-forces single-byte keys and scores by English letter frequency or known plaintext
  (xorBruteForcer, brutexor, xor-kpa); the known weakness is identifiers and non-prose strings. The key search adds the program's own evidence
  (roles, runtime names, pattern/format shape) to the language score, and refuses to decide without a margin.
* **GitHub behaviour** used by the diagnosis: 404 instead of 403 for private repositories (GitHub REST troubleshooting); rate-limit headers and
  403/429 responses (GitHub REST rate-limit documentation).

Sources: https://docs.rs/crate/unluac/1.4.3 · https://conf.researchr.org/details/icpc-2026/icpc-2026-research/10/LuaReSym-Recovering-Variables-Liveness-Range-in-Stripped-Lua-Bytecode-via-Multi-Stag ·
https://arxiv.org/abs/1909.09029 · https://www.usenix.org/conference/usenixsecurity22/presentation/chen-qibin ·
https://www.sans.org/blog/tools-for-examining-xor-obfuscation-for-malware-analysis · https://isc.sans.edu/diary/22490 ·
https://docs.github.com/en/rest/using-the-rest-api/troubleshooting-the-rest-api · https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api

## 10. Tests and regression

**Unit and integration suite** (`npm test`, with the reference Lua runtimes, `QS_LUA_PYTHON` set — the same conditions as the previous round's baseline):

| Run | Tests | Pass | Fail | Skipped |
|---|---|---|---|---|
| Baseline, previous round (commit c339755) | 1206 | 1200 | 0 | 6 |
| This round, first checkpoint (commit 28d4272) | 1229 | 1222 | 0 | 7 |
| This round, final code | 1232 | 1223 | 2 | 7 |

The two failures of the final run were both consequences of fixing the macros false positive (D18) and were resolved at their source: the labelled-collection
evaluation was regenerated (exactly the 3 plain files changed; nothing else moved) together with the format database and `docs/AUDIT.md` that derive
from it, and a Luarmor test that had asserted the false positive ("an obfuscated loader") was corrected to the true reading, with a new test for a loader
that really is protected. The affected test files were re-run afterwards: 47 of 47 (formats, format database) and 12 of 12 (Luarmor) pass. The 7 skips
are samples kept outside the repository (licence or ownership) and the opt-in live GitHub test (`QS_LIVE_GITHUB=1`, run separately: passes).

**Browser end-to-end suite** (`tests/e2e/ui.e2e.mjs`, Chromium): **85 of 85 pass** on the final code. On the way there it found D19–D21 above, and three
tests that encoded superseded behaviour (GitHub stages now go through `/api/github`; transitions are not scene animations; a Reconstruct test fed the
engine a script that does not compile, which the engine has rightly called "no program observed" since the previous round — that round's e2e suite had
not been re-run, as its report said). One live end-to-end check ran against the real GitHub raw host with the real `/api/github` handler (§5).

**Engine-level checks added this round:** key-search precision (390 decided, 0 wrong), the site pipeline agreeing with the engine on all 404 VM-lifter
fixtures, evidence-based naming (and that nothing is invented), placeholder counting, GitHub forms/failure classes/SSRF/token handling, Premium
enforcement in Node and Python.

## 11. Remaining limitations

* **Luraph 14.x handler-table (Test 8) and 15.1/15.2:** still not reconstructed (KNOWN-ISSUES 86, 87). No static 14.x reader was built this round.
* **LuaObfuscator.com VM:** constants and listing only (88). **Boronide, IronBrew 3, PSU, MoonSec V3, Synapse Xen:** identified only (90).
* **Zartha:** 79 strings undecided across 15 builds (91). **Names:** most parameters still have placeholder names where the program gives no evidence (92).
* **GitHub:** private vs deleted needs the user's token; the API diagnosis was not exercised live from this environment (93).
* **Premium:** the browser engine cannot be protected by a server; licensing is not activated in this repository (94).
* **Performance:** no GPU or real phone was available; absolute fps is from software compositing (95).
