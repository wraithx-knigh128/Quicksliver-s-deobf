# Prompt XXX: reconstruction integrity and unfinished engine recovery

Every number here was measured in this prompt; the raw results are in `data/research/xxx-reconstruction.json`, the per-fixture records in
`data/regression/records.json`, and the scripts in `tools/engines/xxx/` (`README.md` there says which produced what). "XXIX" is the state at
commit `d918a23`; the MoonSec V3 engine's output (786 rebuilt chunks) is unchanged, so every MoonSec difference below is QuickSilver's own.

## 1. Issues investigated

| # | Issue (as XXIX left it) | Investigated how |
|---|---|---|
| 1 | MoonSec V3: 109 of 786 rebuilt programs keep functions that were not decompiled (172 functions) | per-function census of all 786 chunks after every change (`protos.mjs`); each failing shape reduced to a plain Lua 5.1 program |
| 2 | MoonSec V3 `c0263d72…`: calls in a different order | reduced to six lines of Lua; compiled by reference Lua 5.1, decompiled, run |
| 3 | MoonSec V3 `3fed8cb5…`: calls in a different order | event traces of both programs; the rebuilt chunk disassembled; the tracer's wait budget varied |
| 4 | REPORT-XXIX: "31 identical" of the keyless MoonSec sample | the same 120 files through the product's own comparison (`verifyRecovery` with the adapter's options) instead of the batch script |
| 5 | Prometheus: 94 / 131 clean, partials, the gate | the integrated run and the XXIX scoring repeated, row by row |
| 6 | Luraph v15.2: "devirtualization failed: YieldSig" | the research tool's own traceback (isolated run), then its code and the captured chunk read as text |
| 7 | Results are one class; the person cannot see which parts were established | the outcome classifier and the result page |
| 8 | No regression record per fixture | — |

## 2. Root causes

**Decompiler (each found by a reduced program; all reproduce on plain Lua 5.1 output too, so they were general gaps, not MoonSec quirks):**

1. *Order of impure values.* `define()` stored a value computed from an impure one (a call) as pure, so it could be inlined past a later call: the cause of `c0263d72…` (`GetService("Players")` evaluated after `HttpService`). Method lookups (`SELF`), constructor fields and list items that could not stay in order abandoned the whole function.
2. *Short-circuit expressions whose value is used* (`return a ~= b and c and c.x > 0`, `local ok = m == "A" or m == "B" and b or …`): compiled to jumps ending at a `false` load, a `true` load and a join where TESTSETs deliver values; the structurer read them as statements and abandoned the function ("unstructured jump", "leaves its block").
3. *A merge bug in condition groups*: two TESTSET nodes were merged as `a or c` when the first was compound (`b and a`) — a wrong result, found by the property test below (the only wrong decompilation it found).
4. *Loops whose body ends without a closing jump* (return or break inside), *closure-capture analysis* that stopped at the first branch, and *a generic-`for` prep* recognised on any jump to a `TFORCALL`.
5. *A condition read across a loop head*: `if on then while on do … end end` jumps to the same place from both tests, so they were read as one condition (`on and on`) with the loop's head inside it.
6. *Jump threading by Lua's code generator*: `luaK_jump` concatenates the pending "jumps to here" list into every new `JMP` (Lua 5.1 `lcode.c`, verified), so `while a do … while b do … end break end` sends the inner loop's exit straight past the `break`.
7. *TESTSET liveness*: a TESTSET writes its destination only on the jump edge (`if (R(B) <=> C) then R(A) := R(B) else pc++`, `lopcodes.h`), but liveness treated the destination as live through it on both edges, so a temporary in that register (`M.V` of `M.V == "Boss" and isBoss`) looked live after its single use.
8. *Table constructors inside a condition* (`#f({ a, b }) > 0`) were not accepted as condition setup.
9. *Copy-on-write*: constructor fields were added to the pending table in place. When condition parsing (speculative, restored on failure) included a constructor, a failed attempt's fields survived the restore and the retry added them again — the same subtrees twice in the output. It was introduced by fix 8 during this prompt, found by the MoonSec batch (one file never finished: an AST walk over the duplicated tree), fixed, and is now a test invariant (no interior AST node may appear twice).
10. *Performance*: liveness was a byte-per-register fixed point; with the restored loop ends it took seconds on the largest functions.

**Comparison (src/adaptive/verify.js):**

11. `3fed8cb5…` is **not a reconstruction difference**. MoonSec's runtime calls `wait()` once before the program starts; the comparison already left that event out, but the wait still spent one of the original's 400 sandbox waits. The program ends in `while true do wait(…) … end` (in the rebuilt chunk too; its spawned function is empty in both), so the original's loop ran one round fewer before the sandbox stopped it and every later event moved. Given one more wait, the original's run is identical to the rebuilt program's, event for event, at 400, 200 and 50 waits (`waitbudget.mjs`).
12. The product's comparison counted two globals of MoonSec's runtime — the name its banner line assigns (`([[This file was protected with MoonSec V3…]]):gsub('.+', (function(a) _xxxx = a; end))`, readable in all 792 files) and `MoonSec_StringsHiddenAttr` — as a difference. **Through XXIX's product path, none of the 120 sampled MoonSec results could be behaviourally verified** (32 "wrote globals", 10 event differences). REPORT-XXIX's "31 identical" came from a batch script that did not compare globals; the report overstated what the product established.

**Recovery pipeline (found by the full unit suite after the decompiler work):**

13. *A clean-up pass broke a correctly lifted program.* AzureVM `s04_control_flow__AzureGodUltra`: XXIX could not decompile one of its
    functions, so the VM was kept. Now the whole chunk decompiles, and the decompiled program behaves exactly like the VM's decoded bytecode
    on reference Lua 5.1 — but one round of the decoder evaluation (`src/passes/evaluate.js`) then read one of two identical
    `pool[decode(...)]` sites as `""`, and the result, reported "recovered, confidence high", printed something else than the original.
    The lift's self-check (the program against the VM's decoded bytecode) ran only right after decompiling; the passes after it were
    trusted. (While tracing it, dumps written as UTF-8 by the diagnostic script showed garbage strings; that was the script, not the
    pipeline — dumps are now written byte for byte.)

**Luraph v15.2:** see §6. **Prometheus:** nothing to fix was found (§5).

## 3. Fixes

| Fix | Where | Test |
|---|---|---|
| impure values keep their place (`define`, `SELF`, set-index / set-list order repair instead of abandoning) | `src/decompile/decompile.js` | snippet `orderedEffects`; property tests |
| value regions: short-circuit values rebuilt from the jump graph by exact rules (`iteValue`, including "one alternative ends in the other") | same | snippet `valueExpressions`; property tests |
| testset-merge restricted to a plain TESTSET | same | property test (the case it found) |
| restored loop ends; capture reachability by paths; generic-`for` prep | same, `lift.js` | snippets `loopIfBreakElse`, `nestedForBreak` |
| a condition ends before a loop head | `parseGroup` | snippet `ifThenWhileSameExit` |
| loop exits de-threaded | `dethreadLoopExits` | snippet `innerLoopThenBreak` |
| TESTSET liveness exact on its jump edge; liveness over word bitsets | `liveness` | snippet `valueThenTest` (Lua 5.1); identical output on 123 chunks before/after the bitset change |
| constructors allowed in conditions; copy-on-write tables | `parseCondNode`, `extendTable` | snippet `conditionWithTable`; `sharedSubtrees` invariant in both decompiler test files |
| prelude waits not charged to the original | `verify.js` | `tests/xxix-engines.test.mjs` (old comparison: "different" at event 799; now identical) |
| the runtime's own globals not compared (exact names; the banner pattern) | `verify.js`, `src/pipeline/engines.js` | same file; a program's own globals are still compared |
| result facets | `src/validate/outcome.js`, `evidence.js`, `deob-page.js` | `tests/xxx-facets.test.mjs`; browser test |
| after a lift verified against the VM's decoded bytecode, every later step that changes the program is checked against it again and undone if it changes what the program does; the output header says "Undone: …" | `src/recover/pipeline.js` (`Run.guard`), `annotate.js` | `tests/xvi-azurevm.test.mjs` (every lifted AzureVM fixture still behaves like its bytecode after the clean-up passes) |
| "MoonSec V3 V3" on the result page | `deob-page.js` | browser test |

Property tests (`tests/decompile-property.test.mjs`, new): random programs compiled by reference Lua 5.1, stripped, decompiled, both run on
the same inputs (4,096 input combinations for expressions). The invariant is **zero programs that decompile but behave differently**; the
share left undecompiled is a floor that may only go down.

| Seed set | XXIX: identical / DIFFERENT / undecompiled | XXX |
|---|---|---|
| expressions, seed 11, 200 | 187 / **1** / 12 | 200 / 0 / 0 |
| expressions, seed 7, 200 | 189 / 0 / 11 | 199 / 0 / 1 |
| statements, seed 5, 120 | 113 / 0 / 7 | 120 / 0 / 0 |
| statements, seed 23, 120 | 109 / 0 / 11 | 120 / 0 / 0 |
| statements, seed 41, 120 | 115 / 0 / 5 | 120 / 0 / 0 |

## 4. MoonSec V3 results (the public collection, 792 files; engine output unchanged)

| | XXIX | XXX |
|---|---|---|
| Rebuilt to bytecode | 786 | 786 (engine unchanged) |
| Programs with a function not decompiled | **109** | **6** |
| Functions not decompiled | **172** | **6** |
| Output parses | 786 | 786 |
| A file worse than before | — | none |
| 25 largest chunks, decompile time (measured alone) | 65.5 s | 5.8 s |

Census after each step (functions / files): 172/109 → order repair 120/82 → value regions 80/64 → loop ends 78/62 → capture reachability 41/30 → generic-for prep 26/23 → loop heads 10 → loop exits 9 → TESTSET liveness 7 → constructors in conditions 6/6.

Behaviour, the 120 sampled files, **through the product's own comparison** (the adapter's verify options):

| | XXIX product path | XXX |
|---|---|---|
| identical (behaviourally verified) | **0** | **34** |
| different: "wrote globals" (MoonSec's runtime globals) | 32 | 0 |
| different: events | 10 | 8 |
| different: the same error naming another variable | 29 | 29 |
| no usable reference (keyed builds: the original only calls a stand-in) | 47 | 47 |
| inconclusive | 2 | 2 |

The 8 event differences: 5 originals printed MoonSec's own anti-debug message instead of running (no reference); 3 are the same value
written differently in the trace text (`" " .. 1` / `" 1"`, a stand-in's name, concatenation grouping). They stay "different": the
comparison was not loosened for them. Both "unexplained" differences of XXIX are explained (§2, items 1 and 11) and gone.

The 6 functions left: 1 Luau `continue` (MoonSec scripts are Luau; `continue` compiles to a jump to the loop's continue point, which plain
Lua 5.1 cannot produce, and the decompiler does not emit `continue`); 2 whose loop condition jumps past the loop's own exit (not yet
reduced); 3 `if/else` whose shared tail exceeds the 80-instruction duplication cap (deliberate). They are marked in the output and make the
result "partial".

## 5. Prometheus regression results (QuickSilver's 131 fixtures with originals)

The integrated run (QuickSilver's passes, the gated engine, the comparison) and XXIX's scoring were repeated: **all 131 rows are identical
to XXIX** — the same outcome and the same class for every fixture. QuickSilver alone: 59 right with nothing left, 71 right with protection
left, 1 wrong (unchanged). Integrated: 92 right with nothing left, 36 with protection left, 3 re-scored against the protected script
(Prometheus' own miscompile, as in XXIX: 94 clean in XXIX's summary). The engine is asked 35 times, as before. The two `s03_encoded_strings`
seed builds score "different" against the original only because their manifest records no behaviour while the protected build itself
diverges in the sandbox; against the protected script they agree (as XXIX recorded). No validated output behaves differently. The gate, the
half-program rule and the adapter selection were left as they are: nothing measured here argues for changing them.

## 6. Luraph v15.2 findings

Reproduced once, unmodified, on the research repository's own sample, inside the isolation runner, with its driver's `DEVIRT_TB` switch
(`tools/engines/xxx/v152-traceback.sh`). The traceback:
`collect_requests → _walk_one → make_stepper → Stepper.__init__ → _stack_pointer_candidates → _fresh_scopes → exec_block(inner_body[:first_inner]) → … → raise YieldSig`.

`YieldSig` is the tool's internal signal for "reached a dispatch loop"; it escaped because the tool's VM model takes a top-level `if` as a
mode branch only when the dispatch `while` is its first statement, and in this build the branch begins with a state assignment
(`if M then W,Q,Wh,mh=m,J,Z,E; while true do local ah=F[W] …`, read in the captured chunk). The branch is then run as prologue and the
signal escapes. **Category: a research-implementation limitation (its VM shape model)** — not an unsupported instruction, not a protection
check. Nothing was implemented: the repository has no licence (nothing of it can be used), and nothing a fixed lifter produced could be
validated — the source/sample pairing is unverified and the protected script's own run ends in its tamper loop, so there is no behaviour
reference (an evidence limit). Luraph v15.2 stays unsupported, and the site does not say otherwise.

## 7. Shared engine changes

- **Decompiler** (`src/decompile/`): items 1–10 of §2; every change is exact by construction (a stated Lua semantics rule) and checked by
  reference-Lua runs, never by "looks right".
- **Behaviour comparison** (`src/adaptive/verify.js`): prelude waits, runtime globals (declared per adapter, `src/pipeline/engines.js`).
- **Result facets** (`src/validate/outcome.js`): *Detected, Retrieved, Partially reconstructed, Syntax-valid, Structurally reconstructed,
  Behaviourally verified, Unverified, Failed*, each true / false / not applicable with its reason, computed from the same evidence as the
  class. None comes from a confidence score: "behaviourally verified" only from a comparison that reached at least half the program;
  "structurally reconstructed" only from the output (it parses; no residual protection, unresolved place, missing constant or empty body).
- **The Deobfuscate page** (single workspace, unchanged otherwise) shows next to the verdict: the protection detected, the engine that
  produced the result, the stages completed, functions reconstructed of the total, and the eight facets (`docs/assets/result-facets-xxx.webp`);
  "Why this verdict" lists each facet with its reason.
- Website-first: no bot was built.

## 8. Before/after fixture results

`tools/regress/records.mjs` writes one record per fixture of the committed corpus (`data/regression/records.json`): input identification
(id, SHA-256 prefix, configuration), detection, engine, stages applied / skipped / failed, functions reconstructed, unresolved places, the
facets, the class and its stated limitations; `--check` fails on any difference.

| Set | fixtures | validated | partial | syntax-valid unverified | not deobfuscated | invalid input |
|---|---|---|---|---|---|---|
| azurevm | 48 | 14 | 34 | 0 | 0 | 0 |
| clyde | 25 | 15 | 1 | 0 | 9 | 0 |
| fusgato | 4 | 0 | 4 | 0 | 0 | 0 |
| hercules | 115 | 76 | 26 | 0 | 9 | 4 |
| hercules-1.5 | 84 | 52 | 16 | 2 | 7 | 7 |
| hercules-1.5-early | 70 | 34 | 0 | 3 | 0 | 33 |
| hercules-1.6 | 84 | 50 | 19 | 0 | 0 | 15 |
| hercules-1.6.2 | 91 | 67 | 11 | 0 | 7 | 6 |
| hercules-2.0.0 | 93 | 70 | 12 | 0 | 7 | 4 |
| ironbrew2 | 64 | 52 | 12 | 0 | 0 | 0 |
| loaders | 66 | 24 | 42 | 0 | 0 | 0 |
| luaxen | 22 | 5 | 9 | 1 | 7 | 0 |
| mixed | 105 | 13 | 83 | 0 | 7 | 2 |
| obscura-1.0.0 | 30 | 0 | 24 | 0 | 6 | 0 |
| obscura-1.0.1 | 36 | 0 | 24 | 0 | 12 | 0 |
| obscura-1.1.0 | 63 | 7 | 35 | 0 | 21 | 0 |
| panda | 32 | 8 | 24 | 0 | 0 | 0 |
| prometheus | 91 | 49 | 38 | 0 | 4 | 0 |
| prometheus-2026-11 | 24 | 0 | 24 | 0 | 0 | 0 |
| prometheus-seeds | 10 | 2 | 8 | 0 | 0 | 0 |
| simple_html | 8 | 7 | 1 | 0 | 0 | 0 |
| zartha | 54 | 16 | 23 | 15 | 0 | 0 |
| zenfus | 8 | 0 | 0 | 0 | 8 | 0 |
| **all** | **1227** | **561** | **470** | **21** | **104** | **71** |

Facets over all 1227 records: structurally reconstructed 608, not 548, no parsing output 71; behaviourally verified 1011, behaved differently 75, not settled 141. Every `validated` record has both a behaviour verification and a structural reconstruction (checked by `tests/xxx-records.test.mjs`).

The same records measured with XXIX's source tree (for a per-fixture before/after) are being run; this section is updated with them.

## 9. Unit and browser results

First full runs (with every fix of this prompt except the clean-up guard): unit 1,329 tests — 1,319 pass, 3 fail, 7 skipped. The 3 failures:
the AzureVM regression (§2 item 13, fixed) and the two records tests, which ran against a 10-record trial file before the full records
existed. The 7 skips are the same as in XXIX (local-only corpora not in the repository, and the opt-in live GitHub test). Browser: 91 tests,
90 pass; the failing one (Reconstruct: "Identical to the original" read as "Not verified") ran while the unit suite loaded the machine
and passes 3 of 3 times alone — its behaviour check has a wall-clock limit. Final runs after the guard: being run; this section is updated
with them.

## 10. Remaining limitations and priorities

1. **Luau `continue` in rebuilt MoonSec chunks** (1 function): emit `continue` for a jump to the loop's continue point that is not a block
   end. The output would then be Luau, which reference Lua 5.1 cannot run; the check would rest on QuickSilver's sandbox alone.
2. **Two loop shapes whose condition jumps past the loop's own exit** (2 functions): to be reduced to plain-Lua reproductions first.
3. **Shared tails over 80 instructions** (3 functions): duplicating them is exact but makes the output much longer; a goto-free alternative
   would need a different structuring.
4. **TESTSET as a statement duplicates a pure read**: `x = a.b or …` is written `if a.b then x = a.b … end`, so `a.b` is read twice (calls
   are refused there; field reads are not — a second `__index` on a Roblox instance). 5 MoonSec outputs contain it (3 already did in XXIX).
5. **Lua 5.4 with debug information**: `local ok = <value expression>; if ok then` (snippet `valueThenTest`) is still not decompiled there.
6. **MoonSec keyed builds** (47 of 120) still have no behaviour reference; their string rule rests on text evidence (KNOWN-ISSUES #104).
7. **Luraph v15.2**: unsupported (§6).
