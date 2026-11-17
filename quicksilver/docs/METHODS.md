# Deobfuscation methods — research turned into engineering (Prompt XVIII §III)

This document is about methods, not obfuscator names. Every method gets the same six answers:

- what it does;
- what it addresses;
- why it is useful here;
- its limitations;
- whether it can be integrated;
- how it is tested.

Each method is marked as one of:

- **in the repo**: implemented before this round; the evidence is the named module and tests.
- **added now**: implemented and tested in this round.
- **proposed**: not implemented; the reason is given.

The sources are primary papers, checked when this was written. A claim made only by a paper's authors is labelled as theirs.

## 1. Linear MBA simplification by truth-table evaluation — added now

- **Source.** B. Reichenwallner and P. Meerwald-Stadler, *Efficient Deobfuscation of Linear Mixed Boolean-Arithmetic Expressions*
  (CheckMATE @ ACM CCS 2022, arXiv:2209.06335). SiMBA is open source (GPLv3). The authors report that it handles all linear MBAs, and faster
  than MBA-Blast and MBA-Solver.
- **What it does.** A linear MBA is a sum of constant multiples of bitwise functions of the variables. It is fully determined by its values on
  the 2^t inputs where every variable is 0 or 1. Evaluate it there, invert into the basis of conjunctions, and pick the simplest equal
  expression. For example, `(x + y) - 2*bit32.band(x, y)` becomes `bit32.bxor(x, y)`.
- **Addresses.** Arithmetic identities that hide a bitwise operation, and opaque constants built from MBAs.
- **Implementation.** `src/passes/mba.js`, pipeline step `mba`, run after `fold`.
  - It rewrites only arguments of `bit32` calls. `bit32` reduces its operands mod 2^32, so the identity holds for every integer input.
  - It accepts at most 3 variables, integer literals, `+ - *` with one constant factor, unary minus, and `band`/`bor`/`bxor`/`bnot`.
  - A candidate is accepted only if it agrees with the original mod 2^32 on all 0/1 inputs and on 96 more inputs (edge values, negatives,
    random 32-bit values).
  - A budget caps the work per run.
- **Limitations.**
  - Only linear MBAs. Polynomial MBAs such as `x*y` terms are refused, because shape checking excludes them.
  - Constants inside bitwise operators, such as `band(x, 3)`, are refused by the agreement check.
  - At most 3 variables.
  - Nothing is rewritten outside a `bit32` context, since there the identity needs a value range the analysis does not have.
  - Native `&`/`|`/`~` (Lua 5.3) are not handled.
  - The random check is a guard, not a proof. Inside the linear class the reconstruction itself is exact.
- **Tests.** `tests/xviii-mba.test.mjs`:
  - textbook identities;
  - non-linear and unsupported refusals;
  - context restriction;
  - 40 generated MBAs that hide a random bitwise function behind 1–3 random identities, each reduced to no larger than the hidden form;
  - **behaviour on real Lua 5.1** (the reference oracle, with a pure-Lua `bit32`): 12 generated MBAs on 5 input triples, including negatives and
    values ≥ 2^31, print the same before and after;
  - a pipeline test.
- **Measured effect on the targets.** None. No committed or local fixture of the twelve targets uses linear MBAs inside `bit32`: a corpus scan
  for bitwise ± arithmetic found only Obscura's decoder arithmetic, which is not an identity. This is a capability for scripts that use the
  technique, and is honestly not an improvement on any current target metric.

## 2. Static loader analysis with source-to-sink flow — added now

- **Source.** Standard data-flow reasoning (a network result reaching an execution sink), applied to Lua loaders. The architecture taxonomy and
  the measurements are in `docs/LOADERS.md`.
- **What it does.**
  - Resolves request addresses without running anything, through locals, concatenation, `string.format`, `table.concat`, interpolation and
    constant `string.char`.
  - Follows each request to `loadstring`/`load`.
  - Names decoding steps, keys and device checks.
  - Decides one of six access cases.
- **Addresses.** Loader scripts, whose payload is not in the file.
- **Implementation.** `src/loader/analyze.js`, worker op `loader`, and the Loader tab.
- **Limitations.**
  - Addresses produced by code that would have to run stay templates.
  - Service recognition is only as good as the evidence: the hosts observed in real loaders, and public documentation.
- **Tests.** `tests/xviii-loader.test.mjs` (15 tests: every case, redaction, resolution, stages) and two e2e tests.

## 3. Devirtualization by recovering the interpreter's language — in the repo

- **Source.** R. Rolles, *Unpacking Virtualization Obfuscators*, USENIX WOOT 2009. Treat the embedded interpreter as an ordinary interpreter,
  recover its instruction set, and translate the bytecode back.
- **In the repo.** Per-family lifters read each VM's instruction encoding and handlers and translate them into Lua 5.1 prototypes. A shared
  decompiler then rebuilds the source:
  - `src/recover/ironbrew.js` and `ib2-templates.js`;
  - `obscura-vm`, `zartha-vm`, `fusgato-vm`, `ironbrikked-vm`, `azurevm`, `vault-vm`, `hercules-vm`, `realobfuscator-vm`;
  - `src/recover/moonveil-vm/`;
  - `prometheus-bvm.js`.
- **Limitations.**
  - A lifter is per VM design. A new handler kind stops the lifter with a named reason, for example MoonVeil 2.1.0 handler kinds that are not
    in the two samples.
  - LuaQ's VM is described, but its handler mapping needs a second sample of a known program (`docs/targets/LUAQ.md`).
- **Tests.** The per-family test files and the scorecard (`docs/MATRIX.md`).

## 4. Handler semantics by program synthesis — proposed

- **Source.**
  - T. Blazytko, M. Contag, C. Aschermann and T. Holz, *Syntia: Synthesizing the Semantics of Obfuscated Code*, USENIX Security 2017. It
    samples input/output pairs of a code window and synthesises an expression guided by Monte Carlo tree search. The authors report learning
    489 of 500 random MBAs and more than 94% of the arithmetic handlers in VMProtect and Themida.
  - A follow-up, *AI-based Blackbox Code Deobfuscation* (arXiv:2102.04805, Xyntia), reports outperforming Syntia on similar tasks.
- **What it would do here.** Map an unknown VM handler to a Lua opcode without reading its code. Run the handler body in the existing JS
  sandbox on random register and constant states, record what changes, and match the result against a catalogue of Lua 5.1 opcode semantics
  (MOVE, LOADK, ADD, GETTABLE, CALL, …).
- **Addresses.**
  - Handler kinds that template matching does not know: MoonVeil 2.1.0 kinds outside the two samples, and new builds of known VMs.
  - Fused handlers, given trace windows.
- **Why it is useful.** Template matching breaks when a VM is regenerated with different code for the same semantics. Input/output behaviour
  does not.
- **Limitations.**
  - It needs a handler that can be isolated and a register model; the per-family readers already provide both.
  - Handlers with side effects on the VM's own state (the instruction pointer, memoised operands as in LuaQ) need those modelled.
  - Synthesis is not a proof, so a mapping must be confirmed by running the lifted program against the original (§6).
  - For LuaQ it does **not** remove the main blocker: the program is not in the file.
- **Integration.** Possible, inside the sandbox that already exists (`src/sandbox`), with no new dependency.
- **How to test.** Use the research lab's program generator (`docs/RESEARCH-LAB.md`) to build VMs whose handlers are randomly permuted and rewritten. The synthesised
  mapping must equal the generator's ground truth, and the lifted program must pass the oracle comparison.
- **Why not now.** It is a multi-week component. The current blockers on the priority targets are missing samples (MoonVeil 2.1.0, LuaQ), not
  handler matching on the samples available.

## 5. Opaque predicates decided by proof — in the repo (proof by abstract values), SMT proposed and declined

- **Source.** J. Ming, D. Xu, L. Wang and D. Wu, *LOOP: Logic-Oriented Opaque Predicate Detection in Obfuscated Binary Code*, ACM CCS 2015.
  It runs symbolic execution over a trace and decides predicates with a constraint solver.
- **In the repo.** `src/adaptive/strategies/opaque.js` with `src/adaptive/absval.js` decides predicates by proof over abstract values, and
  removes the dead side only when the proof holds.
- **Proposal declined.** Adding an SMT solver (for example a z3 WebAssembly build) would decide more predicates. But it is a multi-megabyte
  dependency for a static, client-side page, and the corpus measurements show no target whose residual is undecided predicates. Prompt XVIII
  asks for no unnecessary dependencies, so this is not done.

## 6. Differential testing against a reference interpreter — in the repo

- **What it does.** It runs the original and the recovered program and compares what each one does:
  - a real PUC Lua 5.1, LuaJIT or 5.4 through `lupa`, in tests and tools only;
  - the JS sandbox, on the page, only when the user asks.
- **Implementation.** `tests/helpers/lua-oracle.mjs`, `src/adaptive/verify.js`, and the "Run both and compare" button.
- **Limitations.**
  - It shows equivalence on the inputs and environment it ran, which is evidence rather than proof.
  - Roblox-dependent scripts need a stand-in environment.
- **Tests.** The behavioural tests across the suite; metric 7 in `docs/MATRIX.md`.

## 7. Pattern-independent control-flow structuring — partly in the repo, proposed extension

- **Source.** K. Yakdan, S. Eschweiler, E. Gerhards-Padilla and M. Smith, *No More Gotos: Decompilation Using Pattern-Independent
  Control-Flow Structuring and Semantics-Preserving Transformations*, NDSS 2015 (DREAM). It structures regions by their reaching conditions
  rather than by matching templates. The authors report goto-free output on coreutils.
- **In the repo.** The decompiler structures reducible regions. Unflattening (`moonveil.cff`, `prometheus.vmify`, the adaptive state-machine
  strategy) falls back to `goto` (`gotoFallback`) where a region does not match.
- **Proposal.** Condition-based structuring for the regions that now fall back to `goto`.
- **Limitations.** Irreducible control flow still needs node duplication or a flag variable.
- **How to test.** Count the `goto` statements in recovered output across the scorecard fixtures before and after, with oracle equivalence
  kept.
- **Integrable.** Yes, in `src/decompile`.

## 8. Partial evaluation and decoder emulation — in the repo

- **What it does.**
  - Constant folding (`fold`, `consteval`, `regions`).
  - Evaluation of string decoders in the sandbox, only for decoders made of standard functions (`evaluate`).
  - Metamethod arithmetic (`metaarith`).
  - Container layers: base-N, LZSS, DEFLATE (`src/core/inflate.js`), LuaQ's LQZ1, MoonVeil's base-85.
- **Limitations.** A decoder that depends on the environment is not evaluated statically.

## Summary

| # | Method | Status | Module | Evidence |
|---|---|---|---|---|
| 1 | Linear MBA simplification | **added now** | `src/passes/mba.js` | 6 tests, including real-Lua equivalence |
| 2 | Loader source-to-sink analysis | **added now** | `src/loader/analyze.js` | 15 unit + 2 e2e tests; corpus measurement |
| 3 | Devirtualization (interpreter recovery) | in the repo | `src/recover/*-vm*`, `ironbrew.js`, … | scorecard |
| 4 | Handler synthesis | proposed | — | test plan above |
| 5 | Opaque predicates by proof | in the repo; SMT declined | `src/adaptive/strategies/opaque.js` | adaptive tests |
| 6 | Differential testing | in the repo | `tests/helpers/lua-oracle.mjs`, `src/adaptive/verify.js` | behavioural tests |
| 7 | Condition-based structuring | partial; extension proposed | `src/decompile` | goto count is the metric |
| 8 | Partial evaluation / decoders | in the repo | `src/passes/*`, `src/core/inflate.js` | pipeline tests |

---

# Prompt XIX: methods around loaders and payloads

## 9. Transport and serialization recovery: added

- **What it does.** Peels a retrieved body layer by layer:
  - gzip, with its CRC-32 checked;
  - zlib, with its Adler-32 checked;
  - base64 and hex text;
  - JSON with the code in one field;
  - Roblox models.

  Each layer is recorded. What is left is classified: Lua source, Lua or LuaJIT chunk, model, web page, JSON error, empty, or binary.
- **Addresses.** Loaders whose endpoint returns something other than plain Lua. An HTTP success is not treated as a payload.
- **Implementation.** `src/loader/payload.js`, which uses the project's own DEFLATE reader. No dependency was added.
- **Limitations.** Unknown ciphers stay encoded; that case is reported as binary. Luau bytecode is recognised only as a hint (see §12).
- **Tests.** The remote-loader fixtures `encoded-base64-gzip`, `encoded-json-field`, `encoded-hex-zlib`, `truncated-gzip`, `json-error-200`
  and `html-as-text` (`tests/xix-loader-intel.test.mjs`).

## 10. Container extraction: Roblox models — added

- **What it does.** Reads the Script, LocalScript and ModuleScript sources, with their tree paths, out of `.rbxm` and `.rbxmx` files. The binary
  reader handles LZ4 chunks, byte-interleaved zig-zag integers, delta-encoded referents and parent links.
- **Addresses.** `require(<id>)` and `GetObjects` loaders, whose payload is a model, not Lua text.
- **Implementation.** `src/loader/rbx.js`, written from the community format specification
  ([dom.rojo.space/binary](https://dom.rojo.space/binary)).
- **Verification.**
  - Real Roblox Studio output from rojo-rbx/rbx-test-files (MIT): all 108 files parse, and the binary and XML encodings of each model agree.
  - LZ4 matches the reference library (python `lz4`) on 33 vectors, including random and repetitive data.
- **Limitations.**
  - ZSTD-compressed chunks are reported, not decoded.
  - Property types other than strings are skipped.

## 11. Loader-level semantic validation: added

- **What it does.** For every retrieved payload that was reconstructed, the payload and the reconstruction are both run on the reference Lua,
  and their output is compared (`tools/loaders/score.mjs`).
- **Why.** A reconstruction's confidence is the pipeline's own estimate. Behaviour is an independent check.
- **Result.** 9 of 9 checked programs behave like the retrieved payload (`docs/LOADER-SCORECARD.md`).

## 12. Luau bytecode decompilation: proposed

- **Observed elsewhere.** Several open-source projects decompile Luau bytecode (`jte/lua-decompiler`: Luau versions 3–14; `PumbaaDev/luau-decompiler`;
  `luau-bytecode-lens`), most of them validated by round-trip testing.
- **Gap here.** A loader that returns Luau bytecode is classified, but not decompiled.
- **Feasibility.** A Luau bytecode reader is self-contained: a varint-encoded string table, protos and instructions. It could feed the
  existing structuring and decompiling back end after an opcode mapping.
- **Why not now.** No fixture or real loader in the corpus returns Luau bytecode, so nothing could measure the work. Generating such fixtures needs `luau-compile`, which is not installed in this environment (the project's Luau runner takes a `luau` binary through `QS_LUAU_BIN`); building it would be the first step.
- **How to test.** Compile the committed originals with `luau-compile`, decompile them, and run the result against the originals on Luau.

## 13. Static versus dynamic analysis for loaders

| | Static (this project's default) | Dynamic, in a controlled environment |
|---|---|---|
| What it reveals | Requests, address templates, decoding steps, keys and device checks, without running anything | Addresses computed at run time; what is actually loaded |
| Risk | None | Executes untrusted code. Contacting the real services would mean acting as their client |
| In the repo | `src/loader/analyze.js`, `payload.js`, `intel.js` | The sandbox `Trace` and `Dump` run a script with **no network**: they show the chunks a script builds, never fetched content |
| Decision | Used for every loader | Network-free only. A dynamic run never contacts a delivery service, because that would impersonate its client |
