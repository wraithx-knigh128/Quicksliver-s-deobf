# Architecture

Everything runs in the browser. The page (`src/app/`) talks to **one web worker** (`src/engine.worker.js`) that wraps the engine API (`src/api.js`). One operation runs at a time;
Cancel terminates the worker (the only reliable way to stop a pass that is stuck) and the next call starts a fresh one. Every operation also has a time limit.

```
 page (src/app)  ──postMessage──▶  engine.worker.js ──▶ api.js ──▶ inspect · detect · beautify · analyze · recover · rename
                                                                    · luast · diff · trace · dump · origin
```

Bytes stay bytes: a script is carried as a *binary string* (one char per byte) so non-UTF-8 files survive untouched. The editor shows decoded text, but the engine receives the file's exact bytes
until the person edits the text.

## The recovery pipeline (`src/recover/pipeline.js`)

1. **Parse** (`src/core/parser.js`, Lua 5.1 + Luau extensions) into an AST. A script that does not parse is reported with a position; Beautify can still repair layout.
2. **Detect** (`src/detect/`): signatures per obfuscator family, a dialect guess (Lua, Luau, Lua 5.4 features) and structural traits. Confidence is capped by the kind of evidence (a banner proves less than structure).
3. **Family steps**, in the order the evidence says they were applied:
   * Hercules wrappers and anti-tamper (`recover/hercules.js`);
   * Prometheus: proxied locals, wrap-in-function, vararg, number and string rewriting (`recover/prometheus.js`);
   * **Vmify unflattening** (`recover/vmify.js`, `vmify-locate.js`): find the dispatcher, symbolically evaluate each block's `pos` writes, rebuild the block graph, merge registers into variables (reaching-definition webs), remove the
     anti-tamper that Prometheus compiles into the VM by taint analysis, structure the graph back into `if`/`while`/`repeat`, place declarations (`recover/decls.js`). Runs once per layer (the Strong preset has two);
   * **IronBrew 2** (`recover/ironbrew.js`): read the embedded chunk without running the VM, identify handlers by alpha-equivalent templates (`ib2-templates.js`), solve operand transforms symbolically, rebuild a Lua 5.1 chunk
     and decompile it (`src/decompile/`: lift → CFG → structuring → AST).
4. **Generic passes**, repeated until nothing changes or the round limit is reached: constant folding, simplification and dead-code removal, dataflow (copy propagation, dead stores, temporaries), idiom recovery
   (multi-results, `for` loops, short-circuit forms), renaming of machine-made names, and **decoder evaluation**.
5. **Decoder evaluation** (`passes/evaluate.js`), only when the sandbox is switched on: calls to a decoder (`decode(12)`, `list[n + 52430]`) with constant arguments are evaluated together with the slice of top-level code the decoder depends on, in
   QuickSilver's own Lua interpreter. A result is used only if it comes out the same when evaluated twice in different orders; if the decoder is spent afterwards it is removed. Nothing is handed to the browser's JavaScript engine.
6. **Validate and score** (`recover/confidence.js`): the output must parse; confidence is derived from what is still visible in the output (leftover decoders, VM shapes), not from how many passes ran.

## The sandbox and the trace (`src/sandbox/`, `src/trace/`)

A Lua 5.1/Luau interpreter written for this project (tree-walking over the AST, plus a bytecode reader/executor for compiled chunks). It has instruction, time, recursion and output limits, exposes no host function, and
`loadstring`d code is captured rather than trusted. **Trace** runs a whole script against stand-in Roblox objects and lists what it does (services, instances, properties, URLs it tried to fetch, chunks it loaded); **Dump** keeps the text
a script builds before loading it. Both ask for consent every time, and both describe *one run*: they are not source recovery.

## Testing against reality

`tests/corpus/originals` are programs written for this project. `tests/corpus/tools/gen_*.py` drive the real obfuscators on them (the checkouts are not part of this repository; see each `manifest.json` for seed and revision).
`tests/helpers/lua-oracle.mjs` runs scripts on real Lua through `lupa`, so the strongest assertion in the suite is behavioural: **the recovered program prints what the obfuscated one prints**.
`tests/tools-scorecard.mjs` measures fidelity and behaviour over all fixtures; `tools/build-compat.mjs` turns the results into `data/compat.json` and `docs/COMPATIBILITY.md`; `tools/build-samples.mjs` carries the measurements to the
Examples tab. `tests/e2e/` drives the real page in Chromium.

## The interface (`src/app/`)

Plain ES modules, a strict CSP (no inline script or style), no framework, no build. `main.js` owns state and wiring; `viewer.js` and `diffview.js` are virtual row lists (only visible rows exist in the DOM);
`highlight.js` is a tolerant line-oriented Lua tokenizer shared by the output viewer, the diff and the input editor; `hl-layer.js` draws that colouring *under* the transparent input `<textarea>` so typing, selection and undo stay native
(very long lines are coloured by the visible columns only); `examples.js` is the timing board. Text that came from a script is only ever put in the page with `textContent`.

## Known limits that shape the design

* Original identifiers are not recoverable from any obfuscator that mangles them; renaming is guesswork from use and is labelled so.
* Per-script virtual machines (Luraph, MoonSec, MoonVeil, IronBrew-style) need handler-template work **per family, from real output of that family**. Without real output nothing is claimed.
* Vmify recovery is correct for the shapes Prometheus emits (verified on 21 corpus fixtures and 126 extra seeds); an unfamiliar flattener will be reported as not recognised rather than guessed at.
* The Strong preset takes several seconds in the browser (two layers, then string decoding); Cancel works throughout.
