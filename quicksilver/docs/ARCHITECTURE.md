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
     and decompile it (`src/decompile/`: lift → CFG → structuring → AST);
   * **Colisseum tamper guard** (`recover/colisseum.js`): the large first `do` block of its medium, hard and full presets is recognised by three strings (its error brand, its hook global, the key of its first check) and removed; nothing is run;
   * **Single-page obfuscator strings** (`recover/simple_html.js`): the `_D({numbers})` calls of the page obfuscator are computed on the literal lists, in the one form the page writes, and the decoder is removed when nothing calls it;
   * **Loadstring layers** (`passes/layers.js`): `loadstring(<text>)()` is replaced by the text. A literal or folded payload needs no execution; a payload a decoder computes is read in the sandbox, and only when the script is
     nothing but that loader (helper functions it defines and uses are allowed; any other global it touches is not).
     The same step opens a payload that sits in `EncodingService:DecompressBuffer(buffer.fromstring(base64.decode"..."), Enum.CompressionAlgorithm.Zstd)` with the in-house zstd decoder (`core/zstd.js`, RFC 8878); another algorithm is reported, not guessed at.
     Detection runs again on a payload that came out of a layer, so that the report names the obfuscator inside (`refreshDetection`);
   * **MoonVeil 2.0.25** (`recover/moonveil.js`): base-85 (RFC 1924 alphabet) + XOR string wrappers and `bit32` number wrappers are decoded from the tables in the file itself, and the nested-table "cell" variables are read as fields. A function MoonVeil compiled to its VM is read back by the VM reader below, and flagged (with a low confidence) only when that does not apply;
   * **MoonVeil VM reader** (`recover/moonveil-vm/`, run from the pipeline as the step `moonveil.vm` once the strings and cells are read; on success its result replaces the interpreter and the generic passes that follow are skipped):
     `profile.js` reads, from the interpreter and deserializer as the script wrote them, the field ids of an instruction, the opcode map (a decision tree of 65,536 ids onto about fifteen classes), each class's layout, the fields that index the constants, the magic number of a prototype,
     which cell of the interpreter is which builtin (by following the lists the factories hand each other), what the VM object's helper methods are (by their code), and the variables the interpreter's first block sets up; `blob.js` parses the data with those layouts; `stub.js` opens the encrypted prototype (ChaCha20 under a key of SHA-256 over 32-byte constants and one small number, searched for
     at about a million trials a second; the first block's plain text must start with a compression control byte and the magic number, and the result must parse to its last byte); `ops.js` fixes an op in the interpreter's block graph and applies the handlers that rewrite the program; `lift.js` partially evaluates the graph for each instruction (`recover/block-pe.js`, with the runtime model in `model.js`), joins the pieces
     and tidies them (`recover/cfg-opt.js`, `moonveil-idioms.js`); `assemble.js` structures the graph (`decompile/cfg.js`), names registers by nesting depth, and writes closures in place (child prototypes as nested functions, natives from their factories by `natives.js`). Progress is reported by instruction.
     Speed: an instruction is lifted once per kind (its op and fields, and the following words if its handler reads them) at a program counter no function has, and every other one like it is that result with the places it can go to moved (`lift.js`); an instruction that only goes on to another is not a block at all. The liveness the clean-up passes ask for is a bit-set over the names a graph mentions (`cfg-opt.js`), statements keep their identity when nothing in them changed so what is known about them is kept, handlers that rewrite the program are run against the real row and the changes are read off the tables, and the key search tries the combination the program's own use of its constants points to first. The result is the same as lifting every instruction (`reuseInstructions: false`), which a test compares.
     It reads only the file's own data and code: no environment probe is evaluated and no script code is run. The key search is bounded; when it finds nothing, or any part of the interpreter does not have the shape the reader knows, `VmUnsupported` says which and the general passes take over.
4. **Generic passes**, repeated until nothing changes or the round limit is reached: constant folding, simplification and dead-code removal, dataflow (copy propagation, dead stores, temporaries), idiom recovery
   (multi-results, `for` loops, short-circuit forms), renaming of machine-made names, and **decoder evaluation**.
5. **Decoder evaluation** (`passes/evaluate.js`), only when the sandbox is switched on: calls to a decoder (`decode(12)`, `list[n + 52430]`) with constant arguments are evaluated together with the slice of top-level code the decoder depends on, in
   QuickSilver's own Lua interpreter. A result is used only if it comes out the same when evaluated twice in different orders; if the decoder is spent afterwards it is removed. Nothing is handed to the browser's JavaScript engine.
   The interpreter computes with doubles, as Lua 5.1 and Luau do; Lua 5.4 has 64-bit integers, and a keystream decryptor that multiplies past 2^53 gives different text on the two. The evaluation therefore counts such results
   (`numMode: 'watch'`), and when there are any it runs the slice again with exact integers (`'int64'`, BigInt only where a result leaves the range doubles hold). Where the two agree nothing is decided; where they differ the reading that
   produces text is kept (`sandbox/numeric.js`), and if neither does the sites are left alone and the step says so. The trace does the same for a whole script.
6. **Validate and score** (`recover/confidence.js`): the output must parse; confidence is derived from what is still visible in the output (leftover decoders, VM shapes), not from how many passes ran.

## The adaptive engine (`src/adaptive/`)

The family steps above know their protectors by name. The adaptive engine does not: it treats every input as a new case and works from what the code is made of. It runs once the family steps and the generic rounds are done (`recover()` option `adaptive`, on by default; the page has a switch in Settings), and also on its own (`new AdaptiveEngine().run(ast)`).

```
 survey ──▶ findings (kind, line, evidence, weight) ──▶ opacity score = sum of the weights
    ▲                                                       │
    │          a strategy whose findings are open runs on a snapshot
    │                                                       ▼
    └── re-survey ◀── keep if it parses and prints back, introduces no new name, and weighs less than before; otherwise restore and say why
```

* **Strategies** are objects: `id`, `title`, `order`, `observe(ast, analysis)` (what is here: findings with a weight, how much obscurity each stands for), `run(ast, context, findings)` (what to do about it; returns `{changed, ...}`), optionally `needs: ['sandbox']`. `strategies/index.js` lists them; `engine.register(s)` adds one; nothing else changes. The ones that exist:
  `dispatch.recover` (flattened control flow), `opaque.resolve`, `proxies.inline`, `tables.resolve`, `decoders.evaluate` (the existing sandboxed decoder evaluation, chosen by structure), `layers.unwrap` (loadstring layers), the older passes as clean-ups (`fold`, `simplify`, `dataflow`, loop idioms, `tidy`), a clean-up that reads copies of values that never change as the values (`passes/stable.js`: `local d = decode` read through, a short literal put where it is read; a rebuilt virtual machine reaches its decoder through such copies, and the decoder is only recognised once they are gone), and three observers that only report: `vm.shape` (a loop that fetches instructions from a table and selects handlers by opcode), `payload.blob` (a long string that is not text) and `remote.loader` (`loadstring(game:HttpGet(url))()`: the program runs code fetched when it runs; that is what the script does, not a disguise on it, so it is listed as what is left and adds nothing to the opacity score).
* **Acceptance.** A strategy is judged by the findings it was called for: they must weigh less afterwards. The total score may rise when taking one disguise off shows another (an opaque test behind a proxy), so it is reported and not used to decide. A change that does not print and parse, introduces a global name the script did not use, or grows the program by more than half is undone. A strategy that throws is reported as failed and the program is untouched. All of it is in the decision log (`result.adaptive.decisions`).
* **Code a person wrote is left alone.** A readable helper function, a settings table or a flag the author named is the program’s own; `analysis.machine(name)` (machine-made names, or a script whose names are mostly machine-made, or several tiny wrappers called many times) is what lets a strategy act on helpers and tables. Decoders are found by what they do (a closed function returning text built by a loop from constants that are numbers, byte lists or non-text), never by how often they are called alone.
* **Dispatch loops** (`strategies/dispatch.js`). The state is the variable the loop’s selections test; the selection is *evaluated* for a concrete state (equality, ranges, any arithmetic over constants and constant tables) and the next state is *evaluated* from what a block writes (`s = 7`, `s = s + 5`, `s = bit32.bxor(s, 19)`, `s = NEXT[s]`, `s = c and A or B`, `if c then s = A else s = B end`), so no particular encoding is matched. Blocks are named by the state *and the place in the loop body*, so several selections one after the other make one block per leaf and loops stay loops. Only what can happen is followed: blocks no state reaches are dropped. The graph is cleaned (empty blocks, single-predecessor chains) and structured by `decompile/cfg.js`. A loop is refused, with the reason, when the state is used outside the loop, when it is computed from the program’s data, when a closure reads it, when the loop is driven by data (a state machine consuming input is the program’s own), or when the blocks cannot be structured. Locals a block declares are renamed first if another variable has the same name.
* **Opaque predicates** (`absval.js`): decided by constant evaluation, by comparing an expression with itself over finite numbers, by intervals, or by checking every residue mod m for whole-number ring expressions reduced by `% m`. A variable counts as a whole (or finite) number only if every write to it is; a parameter or a value from a call is unknown and the condition is left.
* **Behaviour check** (`verify.js`, `verifySource`): the original and the recovered program run in the sandbox against the stand-in Roblox environment of the trace, and the recorded calls, property sets, printed output, ending and written globals are compared. Equal runs are evidence, not proof; limits cut a run short and the verdict then says *inconclusive*. The page asks first, like Trace.
* **Not done.** Dispatch by calling a function out of a table, several state variables, an interpreter whose program is data (reported as `interpreter`, not attempted), a state computed from the program’s data, and everything a closed-source virtual machine does. Luraph is not recovered.
* **Known gap, measured.** On real Prometheus output (`tests/corpus/obfuscated/prometheus-nested`, three seeds of the Medium preset and one of Strong, made from a program whose functions leave nested loops early) the Medium preset is rebuilt to about 120 lines that print what the original prints. The Strong preset's second VM layer is not read for that program (`not a Vmify script (2 candidates for the environment table)`): the output still behaves as the original but a VM is left in it, and the confidence says so.

## The sandbox and the trace (`src/sandbox/`, `src/trace/`)

A Lua 5.1/Luau interpreter written for this project (tree-walking over the AST, plus a bytecode reader/executor for compiled chunks) with the Lua 5.3/5.4 features that obfuscator output uses: bitwise operators on 64-bit integers,
`goto` and labels, `string.pack`/`unpack`/`packsize` (no alignment options), a free `_ENV`, `math.maxinteger`. It has instruction, time, recursion and output limits, exposes no host function, and
`loadstring`d code is captured rather than trusted. **Trace** runs a whole script against stand-in Roblox objects and lists what it does (services, instances, properties, URLs it tried to fetch, chunks it loaded); **Dump** keeps the text
a script builds before loading it. Both ask for consent every time, and both describe *one run*: they are not source recovery.

## Testing against reality

`tests/corpus/originals` are programs written for this project. `tests/corpus/tools/gen_*.py` drive the real obfuscators on them (the checkouts are not part of this repository; see each `manifest.json` for seed and revision).
`tests/helpers/lua-oracle.mjs` runs scripts on real Lua through `lupa`, so the strongest assertion in the suite is behavioural: **the recovered program prints what the obfuscated one prints**.
Third-party obfuscators that are plain Lua programs are never started through their own command lines: `tests/corpus/tools/run_isolated.py` loads their `.lua` files into a lupa Lua state with a virtual file system (the tool's own
files in, captured writes out), no `io`, `os.execute`, `package.loadlib` or network, and instruction and CPU budgets; a small driver per tool (`tests/corpus/tools/drivers/`) calls the same library entry point the tool's CLI calls, with a fixed seed.
`tests/corpus/tools/gen_external.py` writes the manifests; the output of tools whose licence does not allow committing it goes to the git-ignored `tests/corpus/obfuscated-local/`, and the tests that need it skip with a reason when it is absent.
Outputs whose anti-tamper treats a debug hook as an attack are verified without the instruction-count hook, in a subprocess with a timeout (`run_lua_nohook.py`).
Tools written in JavaScript or TypeScript are run under `node --permission` with read access to their own folder and write access to one fresh output folder, no network and no child process (`tests/corpus/tools/gen_html_obfuscator.mjs`, `gen_clyde.mjs`).
Two scripts a user supplied for analysis are kept out of the repository and out of the site (git-ignored `tests/corpus/user-local/`); they are read statically only, and the tests about them skip with a reason when the files are absent (`tests/uploads.test.mjs`).
`tools/build-reports.mjs` writes measurements on them as a local Markdown report in the git-ignored `local/`.
`tests/tools-scorecard.mjs` measures fidelity and behaviour over all fixtures; `tools/build-compat.mjs` turns the results into `data/compat.json` and `docs/COMPATIBILITY.md`; `tools/build-samples.mjs` carries the measurements to the
Examples tab. `tests/e2e/` drives the real page in Chromium.

## The interface (`src/app/`)

Plain ES modules, a strict CSP (no inline script or style), no framework, no build. `main.js` owns state and wiring; `viewer.js` and `diffview.js` are virtual row lists (only visible rows exist in the DOM);
`highlight.js` is a tolerant line-oriented Lua tokenizer shared by the output viewer, the diff and the input editor; `hl-layer.js` draws that colouring *under* the transparent input `<textarea>` so typing, selection and undo stay native
(very long lines are coloured by the visible columns only); `examples.js` is the timing board. Text that came from a script is only ever put in the page with `textContent`.

## Known limits that shape the design

* Original identifiers are not recoverable from any obfuscator that mangles them; renaming is guesswork from use and is labelled so.
* Per-script virtual machines (Luraph, MoonSec, IronBrew-style) need handler-template work **per family, from real output of that family**. Without real output nothing is claimed. MoonVeil's is read from the script's own interpreter instead of from templates, tested on one real script.
* Vmify recovery is correct for the shapes Prometheus emits (verified on 21 corpus fixtures and 126 extra seeds); an unfamiliar flattener will be reported as not recognised rather than guessed at.
* The Strong preset takes several seconds in the browser (two layers, then string decoding); Cancel works throughout.
