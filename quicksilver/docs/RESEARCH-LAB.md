# The research laboratory

NEXUS (`NEXUS.md`) analyses one script. The laboratory is how the engine learns what works on *kinds* of scripts, and how that knowledge reaches the page. It is built on one rule:

> **Research first. Experiment second. Verify third. Integrate fourth.** A technique is never called successful by the technique; only the judge, on a record whose behaviour check ran, does that.

Code: `src/research/` (runs in the page and in Node), `tools/lab/` (Node only; not deployed), data: `data/research/`. Run it with `npm run lab`.

## 1. What exists

| Piece | Where | What it does |
|---|---|---|
| Program generator | `tools/lab/generate.mjs` | Original test programs from a seed alone (11 kinds of block: arithmetic, strings, sorting, closures, recursion, `pcall`, varargs, metatables, bytes, loops, records). Every program prints what it computes. |
| Transformations | `tools/lab/transforms.mjs` | 20 controlled transformations: 11 known ones (the independent mutators built for the adaptive tests: flattening in three styles, two string schemes, opaque predicates, proxies, junk, renaming, wrapper; and comment confetti); 3 **custom systems written for the laboratory** (stream-cipher strings, program-as-bytes behind `loadstring`, functions called through a table); 6 **stacked** (nested) combinations. |
| Plans | `src/research/plans.js` | The techniques under evaluation: 7 configurations of the engine (plain or inside NEXUS; structure reader on or off; sandbox on or off). A plan can also carry its own `run`, so a new technique is one more entry. |
| Experiment runner | `tools/lab/run.mjs` | For every (program, transformation, plan): transform, check the transformation itself kept behaviour, observe the text as the page would, run the plan, compare behaviour and closeness to the original, ask the judge. One JSON line per experiment, with the code revision, seeds, hashes and the interpreter used. |
| Judge | `src/research/judge.js` | The only place that names an outcome. Nine verdicts. |
| Knowledge base | `src/research/kb.js`, `tools/lab/kb.mjs` | Counts per (transformation, plan) and per (observed signature, plan); statements derived by stated rules; gaps; defects. |
| Technique evaluation | `tools/lab/compare.mjs` | The same experiments on two revisions of the engine, cell by cell, with every regression listed. |
| Family SDK | `src/research/families.js` | A family is data: id, origin, versions, a signature over features. A registry matches signatures. |
| Study framework | `src/research/study.js`, `tools/lab/study.mjs` | Learns a signature for a system nobody described to the engine, measures it on held-out programs, registers it only if it passes. |
| Advisor | `src/research/advisor.js` | Looks up what the verified experiments say for what an input shows, and ranks the plans. |
| Page | `src/app/research-view.js`, `report-md.js` | The Research tab, live NEXUS stages in the progress bar, the advisor in the Deobfuscate flow, the Markdown report. |

## 2. How an experiment is judged

Two measures that do not use what is known about how the input was made:

* **fidelity**: how close the token sequence is to the original's (`core/fidelity.js`), for the transformed input and for the reconstruction;
* **opacity**: how many obfuscation indicators the text shows (`signature.js`), counted the same way before and after.

| Verdict | Meaning |
|---|---|
| `verified-recovery` | behaviour identical, and the result is close to the original (fidelity at least 0.9) and better than the input |
| `verified-partial` | behaviour identical, and better: closer to the original by at least 0.05, or fewer indicators without losing closeness |
| `behaviour-kept-no-gain` | behaviour identical, nothing gained |
| `behaviour-kept-worse` | behaviour identical, further from the original than the input |
| `failed-behaviour` | the reconstruction does something different (a defect) |
| `failed-parse`, `error` | not valid source; the technique threw |
| `inconclusive` | the original printed nothing, or a limit stopped a run |
| `tool-broken` | the *transformation* changed behaviour; the experiment says nothing about the technique and is excluded |

Behaviour is decided on a **reference Lua runtime** (PUC Lua 5.1 and LuaJIT, through `tools/runtime/`) when one is installed, with QuickSilver's own interpreter run alongside as a cross-check; every record names `behaviourSource` and the runtimes, and a disagreement between the two is recorded and counted (there were none in the shipped data). Without a reference runtime the sandbox decides and the record says so (`docs/COMPAT-RESEARCH.md` section 1). Equal behaviour on a run is evidence for that input, not proof for all inputs.

**The judge was changed twice after seeing results, and both changes are recorded here:**

1. *Success by high fidelity alone.* The first version called `rename` (fidelity 0.99 → 0.98) a success because the fidelity was already high. A reconstruction must now be better than its input, by fidelity or by fewer indicators. The tests pin this case.
2. *An asymmetric noise band.* Gaining fidelity needed +0.05, "further from the original" needed −0.05, but "stayed close enough while the indicators fell" tolerated only −0.03. A drop of 0.04, caused by the engine's ordinary constant folding while every comment was removed, was therefore "no gain". The band is now one band (`SLACK = GAIN = 0.05`) and a test pins that it stays equal. This changed 113 of 2,576 verdicts, all upward, mostly comment confetti and applied to every plan alike. Before the change, on 64 programs, NEXUS verified 48 and the plain plans 36 (75% against 56%; the 95% intervals overlapped, so the knowledge base made no statement and this document should only have called it suggestive). After it, NEXUS verifies 64 and the plain plans 47 of 64 (intervals 94–100% against 62–83%). Whichever judge is used, NEXUS is ahead; only the second makes the difference a derived statement, and the choice of band was not made to get that result: it removed an inconsistency in the code that was there whatever the data said.

## 3. What the experiments found

Shipped data: **2,576 experiments** (20 transformations × 7 plans × 16 programs, plus comment confetti on 48 more programs to settle a close call), **0 defects** (no reconstruction behaved differently from its original), 0 transformations excluded.

Verified successes (representative rows; the full matrix is the Research tab). Rows are out of 16 programs, except confetti, which is out of 64:

| Transformation | generic | structure reader | + sandbox | NEXUS | NEXUS + sandbox |
|---|---|---|---|---|---|
| comment confetti (of 64) | 47 | 47 | 47 | **64** | **64** |
| control-flow flattening (three styles) | 0–3 | 16 | 16 | 16 | 16 |
| string table / inline byte strings | 0 | 0 | **16** | 0 | **16** |
| lab custom: stream-cipher strings | 0 | 0 | **16** | 0 | **16** |
| lab custom: program as bytes behind `loadstring` | 0 | 0 | **16** | 0 | **16** |
| lab custom: functions called through a table | 16 (fewer indicators only) | 16 (**near the original**) | 16 | 16 | 16 (**near the original**) |
| cipher inside a loader (nested) | 0 | 0 | **16** | 0 | **16** |
| opaque predicates, operator proxies | 0 | 16 | 16 | 16 | 16 |

Derived statements (each with its rule and counts in `knowledge.json`): decoders and computed `loadstring` payloads need the sandbox (10 statements, each with both counts); NEXUS beats the plain engine and the structure reader alone on comment confetti; the structure reader beats the generic passes on flattening, opaque predicates and proxies; the sandbox alone is not enough, since NEXUS without the structure reader but with the sandbox recovers the cipher 1 time in 16 where NEXUS with it recovers 16, because the decoder evaluation lives in the structure reader; and one layer hides another (a signature learned for the cipher does not fire when a loader wraps it).

**Techniques evaluated, and what the record shows:**

1. `1-functions-lift`: a new strategy (`src/adaptive/strategies/functions.js`) lifts functions kept in a machine-named table back to local functions. On its own it improved 44 experiments and **made 12 worse**, and the record keeps them.
2. The regressions were not in the new strategy. They came from an existing one: after the lift, `proxies.inline` folded a helper with *three* operations (`(s * 1103515245 + 12345) % 2147483648`) into its call site, although its documentation says a proxy "only stands in for an operation". The same cause explained a result found earlier in the same data: renamed code lost its structure.
3. `2-proxies-one-operation`: the inliner now requires a body with at most one operation. 140 experiments improved, **0 regressed**; `rename` from 6 to 16 of 16.
4. `3-phase3-total` against the baseline revision (`d509bbc`, before both changes): **184 improved, 0 regressed**. Near-original results (`verified-recovery`) for the table-dispatch system went from 0 to 16 of 16, and for the stacked variant from 0 to 11 of 16.

**Unfamiliar systems studied** (signatures learned from programs 1–16, measured on programs 101–116): accepted `confetti`, `strings-indexed`, `rename`, `wrap`, and the lab's custom `xorpack`, `loadwrap`, `tabledispatch` (precision and recall 1.00 on held-out programs); rejected `flatten-chain/-tree/-seq` (the three styles share one surface: precision 0.33) and `strings-inline` (0.50); no signature for `opaque`, `proxies`, `junk` (the feature vocabulary does not capture them). All attempts, with numbers, are in `data/research/study.json`.

## 4. What the page does with it

* **Advisor.** On Deobfuscate, the page measures what the input shows (never runs it), finds the experiments whose transformed text showed the same signs (or, if too few, similar ones, labelled so), and ranks the plans that run inside NEXUS by the lower bound of the 95% interval of their verified-success rate, less a penalty for results that kept behaviour and lost structure. With fewer than 8 matching trials it says so and uses the default plan. A plan that needs the sandbox is *recommended*, never applied until the person has allowed the sandbox. Switching the structure reader off in Settings overrides the advisor.
* **Live stages.** The ten NEXUS stages move the progress bar and name themselves in the status line as they finish.
* **Research tab.** The measured matrix, the advice for the current input with its trials and intervals, the techniques evaluated (with what got worse), the statements the experiments support (each with its rule), the systems studied, registered families, and outside research with its grade.
* **Reports.** Export → *Analysis report (.md)* (plan and evidence, verification, what was inferred, dependencies, stages, limits); the JSON report carries the advice and the ledger.

## 5. Adding a new transformation family

1. Put samples in the catalogue (`tools/lab/transforms.mjs`), or supply a family's output you own as samples.
2. `npm run lab:study` learns a signature and measures it on held-out programs. If it passes, it lands in `data/research/custom-families.json`; if not, the attempt and its numbers land in `study.json`.
3. `npm run lab:run` measures every plan on it. `npm run lab:kb` rebuilds `summary.json` and `knowledge.json`; the advisor and the Research tab read them.
4. A new reconstruction technique is one more plan (or one more adaptive strategy). Evaluate it by running the lab on the revision before and after, and `node tools/lab/compare.mjs before.jsonl after.jsonl --label name`. Keep the comparison whatever it shows.

Nothing in the page, the advisor or the registry has to change for a new family.

## 6. Limits

* **Everything measured here is on generated programs**, transformed by tools written for or used by this project, and behaviour is checked on PUC Lua 5.1 and LuaJIT (with this project's interpreter as a cross-check; Luau is not available). It says how the plans behave on *kinds* of transformation. It does not say how any commercial tool's output behaves.
* **Luraph and other closed-source tools: no reconstruction is claimed.** The research environment could not reach the vendor's site, a web search found no official changelog, and no sample output exists; version identification from the vendor's SDK history is documented in `COMPAT-RESEARCH.md`. `sources.json` records exactly that. A person who owns output of such a tool can add it as samples; until then the laboratory has no experiment for it, so no statement can be made.
* **LuaXen** (MIT, one commit) was read: its obfuscator example runs two stages in a row, which makes it a nested case. It needs a real Lua runtime to run, which the research environment did not have, so no output was produced.
* **No online research happens at run time.** The research in `sources.json` was done once, from this environment, with the grade of each source. The page does not browse. The advisor is a statistical lookup over verified experiments, not a language model, and it improves only when the laboratory is run again.
* **Small matrices.** 16 programs per cell gives intervals of roughly ±15% at the top; the knowledge base makes no statement from fewer than 12 trials.
* **The study framework finds what the feature vocabulary can see.** Opaque predicates, proxies and junk have no signature; flattening styles cannot be told apart from the surface; a system wrapped by another is invisible until the wrapper is peeled.
* **The judge changed twice** (section 2). The shipped data is all from the current judge; numbers quoted from earlier runs in conversation or commits are not.
* **Confetti has 64 programs per cell and everything else 16.** The extra programs were added for one transformation after a close call; cells are not comparable in precision across rows.
