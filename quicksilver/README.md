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
| Luraph · IronBrew · MoonVeil | Say plainly what is and is not possible for that family, then run the matching path (IronBrew 2: rebuild; Luraph and MoonVeil: sandbox dump). |
| Detect · Beautify · Rename · Dump · Origin check | Identify the obfuscator; re-indent only; give machine-made names readable ones; capture what a script loads when it runs in the sandbox; estimate whether code reads as AI-written or copied. |
| Analyze · Trace · Compare · Export | Static report; behavioural trace in the sandbox; side-by-side diff of input and result; save the result, a JSON report or a zip bundle. |
| Tabs | Deobfuscator · Compare · Detection · Analysis · Origin · Luast (syntax tree) · Examples · Compatibility. |
| Timer | The pill in the title bar counts while an operation runs and keeps the time it took; its tooltip lists the last few. The **Examples** tab times every bundled example. |

### What it can recover, measured

Numbers are measured on output of the real tools (Prometheus, Hercules, IronBrew 2) generated from programs written for this project, not on hand-written look-alikes. The full table is
`docs/COMPATIBILITY.md` (generated); the same data is the **Compatibility** tab. In short:

* **IronBrew 2**: the embedded chunk is read (not run), the handlers are identified by shape, the Lua 5.1 chunk is rebuilt and decompiled. Supported.
* **Prometheus**: formatting, name mangling, string splitting, number rewriting, proxied locals, anti-tamper, wrappers, and (with the sandbox switched on) EncryptStrings and ConstantArray. The Vmify
  register VM, including the two layers of the Strong preset, is unflattened back into statements and control flow. The recovered program prints what the obfuscated one prints, on a real Lua 5.1.
  Original variable and function names are not in the output and cannot be recovered; names are guesses from use.
* **Hercules**: the module and preset outputs except its virtual-machine and bytecode modules, which are detected and reported but not recovered.
* **Luraph (v14 / v15 / v15.1), MoonSec V3, MoonVeil, PSU and the rest**: detected from banners and structure where that is possible. The original source of a Luraph or MoonVeil script **cannot** be
  recovered statically and the tool does not pretend to; the sandbox dump and trace describe what one run does. No real output of any closed-source obfuscator was available, so nothing about them is tested
  beyond detection signatures.
* A trace or a dump describes one run. It is not the original source.

### Origin check

A local reading of coding style (comment habits, naming, structure, signs of copied credit lines or public libraries) gives a likelihood that code was AI-written and a separate likelihood that it was
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

`QS_LUA_PYTHON` points at a Python with [`lupa`](https://pypi.org/project/lupa/); it provides real Lua 5.1, LuaJIT and Lua 5.4 so recovered scripts can be compared with the originals **by what they print**.
Without it those tests are reported as skipped, not passed.

## Layout

```
index.html, css/, src/app/     the interface (vanilla ES modules, no framework, no build)
src/core/                      lexer, parser, printer, scopes, diff, fidelity
src/passes/                    folding, simplification, dataflow, idioms, renaming, sandboxed decoder evaluation
src/detect/                    obfuscator signatures and dialect detection
src/recover/                   per-family recovery (Prometheus, Vmify, Hercules, IronBrew 2) and the pipeline
src/decompile/                 Lua bytecode lifting, control-flow structuring
src/sandbox/, src/trace/       a Lua interpreter written for this tool, and the behavioural trace
src/origin/                    the style reading behind the origin check
api/                           Vercel functions
data/                          samples and compat.json (generated)
tests/                         unit, integration, e2e, and the fixture corpus
docs/                          RESEARCH.md, ARCHITECTURE.md, COMPATIBILITY.md (generated), LICENSING.md
```

## Notices

Third-party notices and the licences of the tools whose output is in the test corpus are in `THIRD_PARTY_NOTICES.md`. Obfuscator names are used only to identify the software they belong to.
