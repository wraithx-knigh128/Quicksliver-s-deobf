# QuickSilver Deobfuscator

Recover readable Lua and Luau from obfuscated scripts. The page runs entirely in the browser: a script is parsed, analysed and rewritten as text in a web worker, and is **never executed**
unless the person using it switches on the sandbox or presses Trace / Dump and confirms the dialog. Nothing is uploaded.

> Based on Prometheus by Elias Oelschner, https://github.com/prometheus-lua/Prometheus

Use it only on scripts you own or are authorised to analyse.

## What it does

The page is laid out like a code editor: **Obfuscated source** above, **Deobfuscated source** below, both with Lua syntax colouring, a draggable divider between them and a maximise button on each.

| Control | What it does |
|---|---|
| Open File / From link / Load example | `.lua`, `.luau` or `.txt` only (anything else is refused by extension; compiled Lua chunks are reported as such rather than shown as text). From link fetches through this site's own function from a short allow-list (raw GitHub, gist, Pastebin, rentry, paste.ee, Discord attachments) and only reads. |
| **Deobfuscate** (Ctrl+Enter) | Detects what protects the script and runs the recovery pipeline. |
| Luraph · IronBrew · MoonVeil | Say plainly what is and is not possible for that family, then run the matching path (IronBrew 2 and MoonVeil: rebuild the program from the VM's data; Luraph: sandbox dump). |
| Detect · Beautify · Rename · Dump · AI check | Identify the obfuscator; re-indent only; give machine-made names readable ones; capture what a script loads when it runs in the sandbox; estimate whether code reads as AI-written or copied. |
| Analyze · Trace · Compare · Export | Static report; behavioural trace in the sandbox; side-by-side diff of input and result; save the result, a JSON report or a zip bundle. |
| Tabs | Deobfuscator · Compare · Detection · Analysis · AI check · Luast (syntax tree) · Examples · Obfuscators. |
| Timer | The pill in the title bar counts while an operation runs and keeps the time it took; its tooltip lists the last few. The **Examples** tab times every bundled example. |

### What it can recover, measured

* **Structure no list of obfuscators knows** (`src/adaptive/`): after the family steps, every script is also read for what its code is made of, whoever wrote the tool. Loops that choose their next block by a state variable (an `if`/`elseif` chain, a binary-search tree or several `if`s in a row; the next state a number, a delta, a bit operation, a table lookup or `cond and A or B`) are rebuilt into ordinary `if`/`while`/`repeat`; tiny functions that only stand in for an operator or a constant are replaced by what they do; conditions that arithmetic settles (`x * x >= 0`, `(n * n + n) % 2 == 0`) are decided by proof; tables of constants read through computed keys are read; decoder functions are found by what they do (return text built by a loop from constants that are not themselves text) and, with the sandbox on, evaluated. A change is kept only if the result still parses, introduces no name the script did not use, and leaves less of what the strategy was called for; the page lists what it saw, what it did and what it left, with the reason for each. Measured on independent transformations of six programs, run on real Lua 5.1 (and 5.4 and LuaJIT for some): see `tests/adaptive-behaviour.test.mjs`. Those transformations were written by the same people as the engine, so this shows the shapes are handled, not that every obfuscator is. Code a person wrote (a readable helper, a settings table, a flag) is left alone. **Check the behaviour** (in the Details panel) runs the original and the result in the sandbox, after asking, and compares what each did.

Numbers are measured on output of the real tools (Prometheus, Hercules, IronBrew 2, Zenfus, AzureVM, Clyde, the single-page obfuscator, Colisseum, Simple-Lua-Obfuscator) generated from programs written for this project, not on hand-written look-alikes. The full table is
`docs/COMPATIBILITY.md` (generated); the same data is the **Compatibility** tab. In short:

* **IronBrew 2**: the embedded chunk is read (not run), the handlers are identified by shape, the Lua 5.1 chunk is rebuilt and decompiled. Supported.
* **Prometheus**: formatting, name mangling, string splitting, number rewriting, proxied locals, anti-tamper, wrappers, and (with the sandbox switched on) EncryptStrings and ConstantArray. The Vmify
  register VM, including the two layers of the Strong preset, is unflattened back into statements and control flow. The recovered program prints what the obfuscated one prints, on a real Lua 5.1. (Measured on a program with nested loops that exit early: Medium and both layers of Strong are rebuilt on three seeds and print what the original prints; some Strong results keep the string decryptor and say so. See `docs/ARCHITECTURE.md`.)
  Original variable and function names are not in the output and cannot be recovered; names are guesses from use.
* **Hercules**: the module and preset outputs, including the bytecode-encoding module (with the sandbox on, the compiled Lua 5.4 chunk is read out and decompiled; the original local and function names come back because the chunk keeps its
  debug information). Its virtual-machine module is detected and reported but not recovered.
* **Colisseum** (AGPL-3.0, pure Lua): the `easy`, `medium`, `hard` and `full` presets come back as the original program (100% fidelity and the same output on all 32 fixtures; the tamper guard is removed without being run and the
  string decryptor is evaluated in the sandbox, with Lua 5.4 integers because that is what it was written for). `total` and `fortress` compile the program for a VM: detected and reported as not recovered.
* **Zenfus** (MIT; a generated Lua 5.4 bytecode VM) and **AztupBrew** (a fork of IronBrew 2, one public sample): detected and flagged as VMs that are not recovered statically; the opt-in trace reproduces what the program does
  (the sandbox runs Lua 5.4 bitwise operators, `goto`, `string.unpack` and integers for this). **Simple-Lua-Obfuscator** (base64 pieces handed to `load`): recovered with the sandbox on.
  Four more named candidates (Joker, Zero Lua, Strong FiveM, "NeuroForge") turned out to be READMEs and advertisements without code and are only recognised by name; one of them is documented as untrusted. See `docs/RESEARCH.md`.
* **AzureVM** (MIT; a Prometheus-based Lua 5.1 bytecode VM), **Clyde** (MIT; Luau, TypeScript) and the **single-page obfuscator** (`index.html`, MIT): run in isolated runners and measured. The page obfuscator's `_D` strings and Clyde's rename and string/flow modes are recovered
  (the Clyde string decoder with the sandbox on); the VM modes of AzureVM and Clyde are detected and flagged as not recovered. **Stealth-X** (hosted, no licence) is recognised from its public samples, which are read as text and not stored.
* **MoonVeil 2.0.25** and **Kirus 1.5** (closed source; one real script each, supplied by a user and not stored here): a zstd + `EncodingService` wrapper around a MoonVeil script is opened without running anything, the script is read back to readable Lua with its constants decoded,
  and the function MoonVeil compiled to its own VM is **rebuilt from the VM's data** (`src/recover/moonveil-vm/`): the layout of the data and the meaning of the interpreter's cells are read off the script's own interpreter, the encrypted part is opened by searching for the one small number its key depends on,
  and every instruction is partially evaluated against the interpreter's handlers. Nothing is run; the report says the result was not compared with a run of the original. About five to six seconds for a 10,000-instruction program in the browser worker (measured in Chromium on one machine), with a progress bar. A MoonVeil build whose interpreter has another shape is reported, not guessed at. The Kirus program is not recovered.
* **Obscura** (MIT, Luau; three revisions), **XFuscator** (2013), **LuaXen**, **RealObfuscator** 2.2.1 and **zynaa/LuaObfuscator**: run in isolation (an isolated Lua state, or a no-network namespace sandbox for the Python and Rust tools; nothing ran on the host)
  and measured per revision. Recovered: every Obscura configuration except its VM (89% to 100%, same output on Luau), XFuscator's character-array wrapper and encrypted constants, LuaXen's AST stage, RealObfuscator's rename, lightweight and native modes, zynaa's four
  levels where the tool's own output is valid. Identified and flagged as **not recovered**: the per-build VMs (Obscura VM, Zartha, FusGato, LuaXen IronBrikked, RealObfuscator vm). A script that no rule knows is classified by what it is made of (a loader that
  downloads its program, a minified or plain script, a program stored as numbers ...) and the page says when the program is not in the file. The Obfuscators tab shows, per tool, the revisions run, the failure patterns, what was changed because of them
  and what is assumed (`data/research/format-db.json`, generated by `tools/formats/build-db.mjs`). See `docs/RESEARCH.md` and `docs/KNOWN-ISSUES.md` (Phase IX, Phase X).
* **Measured in six separate categories** (`src/core/metrics.js`; the dashboard shows them per configuration, with the method as a tooltip): identification, structure (parent>child node types of the two syntax trees),
  semantic fidelity, runtime equivalence (counted only where the tool's own output ran like the original), completeness (the output shows no obfuscation, a leftover VM included, **and** the engine lists nothing unresolved),
  and stability. They are never averaged into one number. `docs/AUDIT.md` is generated from the data and lists the status of every format, version and configuration; `docs/KNOWN-ISSUES.md` (Phase X) lists what stays open and why.
* **Obscura's VM** (all three revisions, including the hardened 1.1.0 build) is still **not lifted**, but what its data holds is read without running the program: the functions, their bytes of instructions and the decrypted
  constants (every string of the original program is among them on all 39 VM fixtures). The output header says "NOT lifted back to source" next to that profile (`src/recover/vmprofile.js`).
* **A derivative of a known tool** (a renamed Prometheus fork with its own watermark and anti-tamper block) was run to find out whether recovery depended on the original's exact text. It did, in three places; they are
  generalised and tested (a wrapper behind a preamble, an anti-tamper block recognised by what it does, proxied locals with their accessors declared apart). `docs/RESEARCH.md`, Prompt X.
* **Loader-style packers** (a program encoded as ASCII codes, hex, binary, URL escapes, base64, XOR, reversed text, ... and handed to `loadstring`): literal and folded payloads are unwrapped without running anything; a payload computed by a
  decoder is read in the sandbox when the script is nothing but that loader. Measured on 66 packers I wrote for this project (labelled synthetic: they are not the output of any real tool).
* **Luraph (v14 / v15 / v15.1), MoonSec V3, PSU and the rest**: detected from banners and structure where that is possible. The original source of a Luraph script **cannot** be
  recovered statically and the tool does not pretend to; the sandbox dump and trace describe what one run does. No real output of these closed-source obfuscators was available, so nothing about them is tested
  beyond detection signatures. For Luraph the page also **estimates the generation** (v13-era, v14, v15, v15.1) from a banner (confidence at most 0.7: a banner is a comment anyone can write) or, for an unprotected script, from the `LPH_*` macros it uses, using the
  macro sets in the vendor's own SDK history; it says plainly that this is recognition, not reconstruction (`docs/COMPAT-RESEARCH.md`).
* A trace or a dump describes one run. It is not the original source.

### NEXUS (analysis above the recovery steps)

On by default (Settings → NEXUS analysis; `recoverSource(src, { nexus: true })`). Before recovery it reads the comments as data (a sentence cut into pieces and spread between the tokens is recognised, shown as text and removed after the program is shown to be the same without it; text in it that addresses AI tools is reported and never followed or copied into the output) and maps how variables and functions relate (names from what a value is assigned from, what is called on it, which URL a library came from, what a function returns); recovery then repeats while it still changes the text. After recovery every claim goes in a ledger as **verified** (a named check ran: same syntax tree without the comments, naming changed only names, no new globals, optional sandbox comparison), **inferred** (a rule concluded it, with its evidence) or **unresolved** (fetched code, control-flow shapes that are not rebuilt). It never removes a licence-key check; it describes it. See `docs/NEXUS.md` for the assessment, design, measured cost and limits.

### Research laboratory

`docs/RESEARCH-LAB.md`. A laboratory (`tools/lab/`, `npm run lab`) generates original test programs from seeds, applies 20 controlled transformations (existing mutators, comment confetti, three custom systems written for the laboratory, six nested combinations), runs seven reconstruction plans, and compares the result with the original by behaviour (in this project's own interpreter) and by closeness. One judge names every outcome; a technique cannot call itself successful. From the experiment records it derives the statements the **Research** tab shows (each with its rule and counts), evaluates new techniques by running the same experiments before and after (regressions are kept in the record), learns signatures for systems the engine has no rule for and registers them only if they hold on programs they were not learned from, and feeds the **advisor**: on Deobfuscate the page looks up what the verified experiments say works on inputs that show the same signs, and uses that plan (a plan that needs the sandbox is recommended, never applied until the sandbox is allowed). Export → *Analysis report (.md)* carries the plan, its evidence, and the verification ledger. Nothing is claimed for Luraph or any other tool the laboratory could not obtain output of.

**Reconstruction** (`docs/RECONSTRUCT.md`): the **Reconstruct** tab runs a supplied Luraph v14.7–v15 / IronBrew 1 devirtualisation engine (vendored under `api/_engine/luraph`, run in a limited process by a Python function, `POST /api/reconstruct`): automatic or manual engine, live stages, fallbacks that are labelled (a behaviour trace is never presented as a lift), a reconstruction viewer with copy and download, a report, deterministic diagnostics, an optional model-backed research assistant that only proposes hypotheses, and a compatibility table whose statuses are derived from recorded runs (`data/research/luraph-compat.json`). Measured so far: Luraph v15 and IronBrew 1 lift the archive's sample and compare identical with its original on Luau (*partially tested*); v14.7 ends as a trace-assisted result; v14.8 and v14.9 are not lifted (*experimental*); nothing is fully tested. **The engine archive carries no licence: confirm you may redistribute it before making this repository or a deployment public** (`api/_engine/luraph/NOTICE.md`).

**Commercial compatibility research** (`docs/COMPAT-RESEARCH.md`): behaviour is now decided on **real Lua runtimes** (PUC Lua 5.1–5.4, LuaJIT, through `lupa`; `npm run runtime:setup`; Luau through the Luau 0.739 build vendored with the reconstruction engine, or a binary named in `QS_LUAU_BIN`), kept apart from static checks and cross-checked against this project's interpreter. A **research service** reads permitted public sources under a host policy, keeps a record of each (failures included), extracts findings that quote their source, scores credibility, and optionally runs a grounded extraction through the Anthropic SDK (`api/research.js`, off unless `QS_RESEARCH_TOKEN` is set; never run against the real API in development). **Compatibility profiles** record what is known about each system version by version and enforce, in code, what may be claimed: nothing is "supported" because its output is recognised, a commercial tool cannot be marked verified from the lab's own tests, and authorised samples you supply (a package built in the page, differential-tested with `node tools/research/differential.mjs`) lift a version only past stated gates. `npm run research` rebuilds profiles, capabilities (each with a verifier) and each system's position in the research → classification → experiment → verification → profile → integration pipeline.

### AI check

A strip under the editors reads the script by itself (nothing leaves the page) and shows how likely it is to be AI-written or vibe-coded, and how likely it is to be copied (skidded). The AI percentage comes from style signals;
the copied percentage starts as clues in the text (credit lines, invites, library embeds, a change of style halfway) and becomes a measurement after the GitHub search. A local reading of coding style (comment habits, naming, structure, signs of copied credit lines or public libraries) gives a likelihood that code was AI-written and a separate likelihood that it was
copied. It is an estimate, not proof, and says so on the page. The optional online part sends up to a handful of distinctive lines, after a confirmation dialog, to this site's `/api/origin` function, which searches GitHub's public
code. It needs the `QS_ORIGIN_GITHUB_TOKEN` environment variable; without it the page says the search is not set up. The online path has been tested against recorded responses only.

## Run it

```
python3 -m http.server 8123       # any static server works; the page has no build step
```

Open `http://127.0.0.1:8123/`. `?sample=prometheus__s06_combined__Vmify.lua` opens a bundled example directly.

### Deploy on Vercel

The site is static (`outputDirectory: "."`) plus three small functions in `api/`: `fetch.js` (link import), `origin.js` (online origin search) and `license.js` (optional revocation list). `vercel.json` sets a strict
Content-Security-Policy (no inline script or style, no third-party origins) and the usual hardening headers. Environment variables:

| Variable | Used by | Purpose |
|---|---|---|
| `QS_ORIGIN_GITHUB_TOKEN` | `api/origin.js` | GitHub token (no scopes) for code search; unset = the online search reports it is not configured |
| `QS_ORIGIN_DISABLED=1` | `api/origin.js` | switch the online search off |
| `QS_REVOKED_IDS` | `api/license.js` | comma-separated licence ids to treat as revoked |

### Licensing

See `docs/LICENSING.md`. In short: ECDSA-signed keys checked offline in the browser; with no public key configured every feature is available and the page says so.

## Tests

```
npm test                              # unit + integration (Node >= 20); behavioural tests need QS_LUA_PYTHON
npm run test:e2e                      # real Chromium via Playwright (skipped with a message if unavailable)
QS_LUA_PYTHON=/path/to/python-with-lupa npm run scorecard     # re-measure every real-tool fixture
node tools/build-compat.mjs           # data/compat.json and docs/COMPATIBILITY.md from the scorecards
node tools/build-samples.mjs          # data/samples/ from the corpus and the scorecard
```

`tests/adaptive.test.mjs` holds what the structure reader must do, refuse and leave alone; `tests/adaptive-behaviour.test.mjs` obfuscates six programs with `tests/helpers/mutators.mjs` (flattening in three styles, string decoders, opaque predicates, proxies, junk, renamed locals, a wrapper; alone and together) and compares the recovered programs with the originals on real Lua; `tests/verify.test.mjs` covers the behaviour check.

`QS_LUA_PYTHON` points at a Python with [`lupa`](https://pypi.org/project/lupa/); it provides real Lua 5.1, LuaJIT and Lua 5.4 so recovered scripts can be compared with the originals **by what they print**.
Without it those tests are reported as skipped, not passed.

Output of tools whose licence does not allow committing it (Colisseum, Simple-Lua-Obfuscator, the AztupBrew sample) is generated into the git-ignored `tests/corpus/obfuscated-local/` with
`tests/corpus/tools/gen_external.py` (the tools are run through `run_isolated.py`, never through their own command lines; see `docs/ARCHITECTURE.md`). The tests that use it are skipped, with the reason, when it is absent.

## Layout

```
index.html, css/, src/app/     the interface (vanilla ES modules, no framework, no build)
src/core/                      lexer, parser, printer, scopes, diff, fidelity, metrics (the six categories)
src/passes/                    folding, simplification, dataflow, idioms, renaming, sandboxed decoder evaluation
src/detect/                    obfuscator signatures and dialect detection
src/recover/                   per-family recovery (Prometheus, Vmify, Hercules, IronBrew 2) and the pipeline
src/research/                  laboratory logic shared with the page: plans, judge, knowledge base, advisor, feature extraction, family registry, study; compatibility profiles and their claim gates, identification, pipeline gates, sample packages, grouping of unfamiliar systems
tools/runtime/, tools/research/ the real-Lua oracle, the source collector, the profile and capability builders, differential testing (Node only, not deployed)
src/nexus/                     NEXUS: comment and relation analysis, transformation profile, claims ledger, the 10-stage pipeline (docs/NEXUS.md)
src/adaptive/                  the structure reader: findings, strategies (dispatch loops, opaque predicates, call proxies, constant tables, decoders), the acceptance rules, the behaviour check
src/decompile/                 Lua bytecode lifting, control-flow structuring
src/sandbox/, src/trace/       a Lua interpreter written for this tool (with the Lua 5.4 features obfuscator output uses), and the behavioural trace
src/origin/                    the style reading behind the origin check
api/                           Vercel functions
data/                          samples and compat.json (generated); research/ is the laboratory's records and the knowledge base built from them
tests/                         unit, integration, e2e, and the fixture corpus
docs/                          RESEARCH.md, ARCHITECTURE.md, NEXUS.md, RESEARCH-LAB.md, COMPATIBILITY.md (generated), LICENSING.md
```

## Notices

Third-party notices and the licences of the tools whose output is in the test corpus are in `THIRD_PARTY_NOTICES.md`. Obfuscator names are used only to identify the software they belong to.
