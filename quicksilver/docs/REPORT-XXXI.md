# Prompt XXXI — root-cause elimination and reconstruction accuracy

Every number here was measured in this session; where it compares with Prompt XXX, the XXX figure was measured again on a git worktree of
`534bb94` (not copied from `docs/REPORT-XXX.md`). The scripts are listed in `tools/engines/xxxi/README.md`, the figures are in
`data/research/xxxi-reconstruction.json`. The MoonSec V3 engine's output is unchanged since XXIX (the same 786 rebuilt chunks), so every
MoonSec difference below is QuickSilver's own.

## 1. Starting commit and verified baseline

Starting commit: `534bb94` ("Prompt XXX report: restore the fixture names…"), clean tree. Each figure of `docs/REPORT-XXX.md` was measured
again on a worktree of that commit before anything was changed:

| Claim in REPORT-XXX | Measured on `534bb94` |
|---|---|
| unit 1,330 / 1,323 pass / 0 fail / 7 skipped | 1,330 / 1,323 / 0 / 7 (the 7: two licence-restricted local corpora, four user-supplied scripts not stored in the repository, one live-network test that runs only with `QS_LIVE_GITHUB=1`) |
| browser 91 / 91 | 91 / 91 |
| 1,227 regression records | `records.mjs --check`, both shards: 1,227 checked, 0 differ |
| MoonSec V3: 786 programs, 6 functions not decompiled | 786 decompiled, 6 programs with 6 functions not decompiled, 786 parse |
| MoonSec V3 behaviour: 34 / 120 identical | 34 identical, 8 event, 29 same error naming another variable, 47 no reference, 2 inconclusive |
| Prometheus: XXX identical to XXIX row by row | integrated run repeated on the worktree: 0 rows changed against XXX's recorded run |

## 2. Every investigated issue

| # | Issue | Outcome |
|---|---|---|
| A | KNOWN-ISSUES #118: the decoder evaluation replaced a `pool[decode(...)]` site of AzureVM `s04_control_flow__AzureGodUltra` with `""` | **root cause found and fixed** in `src/passes/evaluate.js`; affects ordinary Lua too; the VM guard is kept and tested on its own |
| B | #118, second form found while testing A: two decoders sharing one cache | **fixed** by the same change (a per-decoder rule was not enough) |
| C | #114: a TESTSET used as a statement evaluates its value twice (`x = t.a or x`) | **fixed**; also present in plain Lua 5.1/5.4 output, with and without debug information |
| D | #114, guarded form found by the MoonSec re-measurement: `x = A and B or c` | **fixed** |
| E | MoonSec `08010afe` main/35/0/0 ("conditional jump leaves its block") | **fixed**: inner for loop's break threaded through the outer break |
| F | MoonSec `424517eb` main/0 ("conditional jump leaves its block") | **fixed**: a `while` condition leaving for a second, identical `return` |
| G | MoonSec `6aaee086` main/7/14/3, `ce3faecf` main/1 ("shared tail too large") | **fixed without raising the limit**: a jump to a `return` of nothing from inside a split condition |
| H | MoonSec `ddc9c42c` main/5 ("shared tail too large"), `c2f0c41b` main/11 (Luau `continue`) | **fixed**: Luau `continue` (#112), written only for the MoonSec adapter's Luau output |
| I | Regression found by the re-measurement: MoonSec `ab5c20be` (decompiled by XXX) refused by the first `continue` rules | **fixed** before the final measurement |
| J | #115: Lua 5.4 with debug information, `local ok = <value expression>; if ok` | **root cause found and fixed** (not "pending values", as XXX suspected) |
| K | Evaluation count and order in general (short-circuit, calls, indexing, metamethods, conditionals, temporaries) | property test added; 0 differences in 480 generated programs (XXX: 282) |
| L | MoonSec verification coverage (34 / 120) | 35 / 120; the rest examined case by case, no reference manufactured (§10, §11) |
| M | #116, trace text: equal strings built in two groupings traced differently | **fixed for string constants**; numbers and stand-in names left (§11) |
| N | Reproducibility of the fix for A: its rerun budget was wall-clock time | **changed to fuel**, which is the same on every machine |
| O | Two AzureVM records whose stage list changed (`dataflow` now applies) | examined: a consequence of C, output shorter and behaviour unchanged on reference Lua 5.1 (§8) |

## 3. Minimal reproductions

All are programs written for the purpose (no third-party script content); each is a committed fixture with a test.

| Issue | Reproduction | Before (XXX) | After |
|---|---|---|---|
| A | `tests/corpus/regress/xxxi-memo-decoder.lua`: a memoising decoder whose character table is filled inside the loop that also calls it | `print(d("tubsu", 1), "")`: prints `start` then an empty string | nothing replaced; same output |
| B | `tests/corpus/regress/xxxi-shared-cache.lua`: `d` and `e` over one cache | six calls replaced by `""` | nothing replaced; same output |
| C | `local t, x = ...; x = t.a or x` (`tests/xxxi-evaluation-order.test.mjs`) | `if t.a then x = t.a end` | `x = t.a or x` |
| D | `x = t.d and t.d[1] or nil` with `x` read later | `if t.d and t.d[1] then x = t.d[1] else x = nil end` | `x = t.d and t.d[1] or nil` |
| E | `tests/corpus/regress/xxxi-for-break.lua` | Lua 5.1: "unstructured jump at 42 to 51" | decompiled, same output (5.1/5.4, stripped/debug) |
| F | `while i < n do … if i == 5 then break end … end return`, the condition's jump moved to the identical final `return` (one word patched in the test) | "conditional jump at 1 leaves its block" | `while _r1_1 < a1_1 do`, same output as the patched bytecode on reference Lua 5.1 |
| G | `tests/corpus/regress/xxxi-or-commands.lua`: `if s == o.Name or s == (h and h.Name) then <24 commands> end` | "shared tail at 13 is too large to duplicate" (all four builds) | decompiled, same output |
| H | `tests/corpus/regress/xxxi-continue.lua` (Lua 5.4 `goto continue`, the same jump as Luau `continue`) | "shared tail at 24 is too large to duplicate" | as Luau: two `continue`, same output; as Lua: still refused |
| I | `tests/corpus/regress/xxxi-testset-continue-point.lua`: `n = n and n:FindFirstChild(seg) or nil` in a generic for | (decompiled) | decompiled as Luau and as Lua |
| J | `localAtSplitRead` in `tests/corpus/decompile/snippets.mjs` | Lua 5.4 debug: "conditional jump at 21 leaves its block" | decompiled, same output |
| M | `tests/xxxi-trace.test.mjs`: `"…?key=" .. n .. "&v=1"` against `"…" .. "?key=" .. n .. "&v=" .. "1"` | "different" | "identical"; `.. "a"` against `.. "b"` still different |

## 4. Root causes

**A, B (#118).** AzureVM's string decoder memoises: it stores the placeholder `""` under its key before decoding and the text after. The
table it decodes with (`_r5_1`) is filled inside the program's top-level `while` loop, and that statement also calls the decoder, so it
is a consumer, not part of the slice the evaluator runs. In the sandbox the first call with key `k` failed half-way ("attempt to
concatenate a nil value") and left the placeholder. Every later call with `k` returned `""` without failing, in the forward order and in
the reverse one, so the two orders agreed and the result was accepted. The forward/reverse check cannot see this: both orders run in one
machine, after the failure. It is not specific to AzureVM (the reduction is plain Lua), and the poisoned state is not limited to the
failing decoder: a second decoder over the same cache, under the same name or an alias, returns the placeholder too (B). The bytecode
guard caught A only because AzureVM has a decoded chunk to check against; nothing else has one.

**C, D (#114).** The decompiler's condition reader inlines the value a TESTSET tests (`E`) into the condition and into the assignment of
the stored value, so `if E then x = E` is one bytecode evaluation written twice. Calls were refused there, field reads were not, so each
`__index` ran twice (and a chain `t.a or t.b or x` read every field twice). D is the same with a guard in front: the condition is
`A and <E's own test>`.

**E.** Lua 5.1's code generator chains pending jumps into the next JMP (`luaK_jump` concatenates `fs->jpc`), so an inner for loop's break
goes straight to the outer loop's exit through the `break` that follows the inner loop. XXX undid this for loops closed by `jmp`/`cjmp`,
not for FORLOOP/TFORLOOP.

**F.** MoonSec's rebuilt `while` leaves through its condition for a second `return` right after the first (the loop's natural exit). The
two instructions are identical and nothing runs between them.

**G.** `s == o.Name or s == (h and h.Name)`: the value `h and h.Name` sits between the two tests, so the condition is read as two groups.
The second test jumps straight to the function's final `return` from inside the first group's body, which made everything between the
first group and that return (the whole command chain) look like a tail both branches share.

**H (#112).** Luau `continue` compiles to a jump to the loop's continue point (the closing `jmp` of a `while`, FORLOOP, TFORCALL) from
mid-body. Lua 5.1 has no such statement, and the structurer saw a jump leaving its block or a shared tail.

**I.** My first `continue` rules took every jump to the continue point for a `continue`, including a TESTSET's, which delivers a value
there (`n = n and f(n) or nil` at the end of a loop body). That jump is a value join.

**J (#115).** Lua 5.4's GETTABUP (`Mode.Value` with `Mode` an upvalue) is lifted to two IR operations with one pc. A local beginning at
that pc (`local isBoss = e.b` just before) made the condition reader refuse the second operation as "a local begins inside the
condition", although the local had been declared before the first. Lua 5.1 compiles the read to two instructions with two pcs.

**M (#116, part).** The trace writes a concatenation with a stand-in as text. MoonSec's VM concatenates left to right and the rebuilt
program keeps the obfuscator's split constants (`"a" .. "?b="` where the original has `"a?b="`), so equal strings came out as different text.

**N.** The fix for A ran the evaluation again only if the first run took under 4 s: on a slower machine the same script could be
evaluated differently.

## 5. Exact code changes

| File | Change |
|---|---|
| `src/passes/evaluate.js` | The synthetic chunk is built by `build(list)` (sites, ids, forward positions). When a site fails, the failed sites are left out and the rest runs again in a fresh machine, at most twice, only while successful sites follow the first failure, no precision loss is pending and the first run used at most a quarter of its fuel; only a run without a failure is used, otherwise no forward result after the first failure. Identical site expressions must give one result in both orders. `result.reruns`, `afterFailure`, `inconsistent` report it. |
| `src/recover/pipeline.js` | `Run` is exported and the guard can be switched off (`vmGuard: false`) so the evaluation can be tested without it; the site never switches it off. |
| `src/decompile/decompile.js` | `ownTest()`; `branch()` writes `x = E or x`, `x = E or c`, `x = A and E or c`, or `valueChain()` (each impure part stored in its tested register, in order); TESTSET parts are kept per register through `reduce()`. `dethreadLoopExits()` covers FORLOOP/TFORLOOP and an identical-`return` exit. `plainReturn()`: a jump to a `return` of nothing is written `return` where the structure would otherwise give up (no new duplication). Luau `continue` (`ctx.cont` for while/for/generic-for loops; `if c then continue end`, a then-block ending in `continue`, no shared-tail or closing-jump treatment for jumps to the continue point except TESTSET's). `parseCondNode()`: locals already declared do not block a condition. `decompile(chunk, { dialect })`. |
| `src/pipeline/engines.js`, `src/pipeline/unified.js`, `src/api.js` | The MoonSec V3 adapter declares `dialect: 'luau'`; the unified pipeline passes it to `recoverFromBytecode`, which passes it to the decompiler. No other adapter, and no Lua 5.1 output, gets `continue`. |
| `src/trace/trace.js` | `__concat` on a stand-in keeps its parts: the chain is flattened and neighbouring string constants are joined (numbers are not). |
| `tests/corpus/decompile/snippets.mjs` | `valueThenTest` moved to the snippets run on Lua 5.1 and 5.4; `localAtSplitRead` added; `SNIPPETS_51` is empty. |
| `tests/helpers/decompile-props.mjs` | `evaluationCase` / `evaluationHarness` (logging proxies). |

The single Deobfuscate option, the UI and the engines are unchanged.

## 6. Tests added

| File | Tests | What fails without the change |
|---|---|---|
| `tests/xxxi-evaluate.test.mjs` | 8: the #118 reduction; two decoders over one cache; the rerun; two controls (set-up visible: still evaluated; a call counter: still refused); a property over 36 random memoising-decoder programs (one decoder, a shared cache, an aliased cache; set-up visible or hidden; sites inside functions; never-run failing sites); the AzureVM fixture with the guard off; the guard on its own | with XXX's `evaluate.js`, the 5 #118 tests fail and the 3 others pass |
| `tests/xxxi-evaluation-order.test.mjs` | 5: the reduction; 4 × 120 random value-condition statements (2 seeds, stripped and with debug information) through proxies that log every read and call, compared with the original on reference Lua 5.1 | all 5 fail with XXX's decompiler |
| `tests/xxxi-structure.test.mjs` | 6: for-break and or-commands (5.1/5.4, stripped/debug); TESTSET to the continue point (both dialects); the two-return chunk; the continue fixture; a property over 60 random Lua 5.4 `goto continue` programs, decompiled as Luau (each `continue` written back as a goto, run on reference Lua 5.4) and as Lua (never a `continue`) | for-break, or-commands, the two-return chunk and the continue fixture fail with XXX's decompiler (§3); the TESTSET fixture guards a regression of this prompt's own first `continue` rules (XXX, without a Luau mode, decompiles it) |
| `tests/xxxi-trace.test.mjs` | 3: grouping does not change the trace; different strings and numbers still differ; the comparison | — |
| `tests/decompile.test.mjs` (existing) | `valueThenTest` and `localAtSplitRead` now on Lua 5.1 and 5.4, stripped and with debug information | `localAtSplitRead` on Lua 5.4 with debug information |

## 7. Before/after measurements

**MoonSec V3 (786 rebuilt chunks; the product's path, Luau for this adapter).**

| | XXX | XXXI |
|---|---|---|
| programs with a function not decompiled | 6 | **0** |
| functions not decompiled | 6 | **0** |
| output parses | 786 | 786 |
| shared subtrees (one evaluation written twice) | 7 in 5 programs | **0** |
| `if E then x = E` sites | 46 in 24 programs (2 field reads) | 5 in 2 programs (all plain locals) |
| `continue` written | — | 162 in 61 programs |
| a program worse than before | — | none |

**MoonSec V3 behaviour, 120 sampled files, the adapter's own comparison.**

| | XXX | XXXI |
|---|---|---|
| identical (behaviourally verified) | 34 | **35** (`a110bb69`, by M, 70% of its lines) |
| different: events | 8 | 7 |
| different: same error naming another variable | 29 | 29 |
| no usable reference (keyed builds) | 47 | 47 |
| inconclusive | 2 | 2 |

**Evaluation count and order (480 generated programs, `tools/engines/xxxi/evalorder.mjs`).** XXX: 282 programs read or call differently
(count or order), 299 share a subtree. XXXI: 0 and 0, none left undecompiled.

**Decoder evaluation on the AzureVM program before `evaluate` (§4 A).** XXX replaced 2 sites (one of them wrongly, the program then
behaved differently on reference Lua 5.1). XXXI: 1 site (`_r1_19("", k)` → `""`, the empty input's text, computed before any failure),
after 2 reruns; the program behaves like the original.

**Decompiler property seeds of `tests/decompile-property.test.mjs`** (identical / different / undecompiled): unchanged, 200/0/0,
199/0/1, 120/0/0, 120/0/0, 120/0/0 on both.

## 8. Full regression comparison

**Per-fixture records (1,227, `tools/regress/records.mjs --check` on the final tree, both shards).** 1,224 reproduce their record exactly.
3 differ, each examined before it was re-recorded (`--sets azurevm,zartha`, which re-measures those sets and keeps every other record):

| Fixture | Field | XXX → XXXI | Why |
|---|---|---|---|
| `azurevm/s04_control_flow__AzureGod15.lua` | stages | `dataflow` now applies | C: `if value then x = value else x = obj[…] end` (a temporary and an if/else) became `x = fn2(…) or obj[…]`; output 207 → 200 lines; same output as the original on reference Lua 5.1, before and after |
| `azurevm/s04_control_flow__Luraph14.lua` | stages | the same | the same program behind another wrapper |
| `zartha/s04_control_flow__constants.lua` | unresolved, limitations | 3 → 1 place unresolved | D: `if value == "m" and "accept" then str = "accept" else str = "start" end` became `str = value == "m" and "accept" or "start"`; the old shape was counted as unresolved |

No record lost a facet: syntax-valid, structural, behavioural, unverified and the outcome class are unchanged for all 1,227. No previously
verified reconstruction changed its verdict.

**MoonSec V3** (§7): no program worse, 6 better; behaviour 34 → 35 identical, no program left a category it was in except `a110bb69`
(event → identical).

**Prometheus** (131 fixtures with originals, the integrated run with the gated engine, XXIX's scoring, `prom-sum.py`): **0 rows changed**
against XXX (92 right with nothing left, 37 with protection left, 2 scored "different" against the original because the protected build
itself diverges, as before; the engine asked 35 times; the same two `s03_encoded_strings` builds validated against the protected script).

**AzureVM guard** (tested on its own, `tests/xxxi-evaluate.test.mjs`): a step that changes what the program does is undone and recorded; on
`s04_control_flow__AzureGodUltra` the lifted program now stays right with the guard switched off, and with it on nothing is undone.

**Reference Lua 5.1 / 5.4:** every new test that compares behaviour runs both programs on reference PUC Lua through `lupa`
(`tests/helpers/lua-oracle.mjs`); `continue` is checked on Lua 5.4 through `goto`.

## 9. Unit and browser results

Final tree, idle machine apart from the measurements of §8:

| Suite | XXX (`534bb94`, measured) | XXXI |
|---|---|---|
| unit (`npm test`, reference Lua through `QS_LUA_PYTHON`) | 1,330 tests: 1,323 pass, 0 fail, 7 skipped | **1,358 tests: 1,351 pass, 0 fail, 7 skipped** |
| browser (`npm run test:e2e`) | 91 / 91 | **91 / 91** |

The 28 new unit tests (compared name by name with the XXX run; none disappeared) are the 22 of §6 (8 + 5 + 6 + 3) and 6 decompiler snippet runs: `localAtSplitRead` on Lua 5.1 and 5.4, stripped and with debug information (4), and `valueThenTest` now also on Lua 5.4 (2). The 7 skipped tests
are the same 7 as before, each for a reason stated in the test: two need licence-restricted corpora that may not be committed
(`tests/corpus/obfuscated-local/colisseum`, `aztupbrew`; generated locally by `tests/corpus/tools/gen_external.py`), four need scripts
supplied for analysis that are not stored in the repository (`tests/corpus/user-local/RideAPet.lua`, `Tech-hub.lua`, two tests each),
and one reads a live public GitHub file and runs only with `QS_LIVE_GITHUB=1`. No test was deleted, weakened or skipped to obtain these
results; one test written during this prompt failed first because of a defect in the test itself (it mutated a literal's `value`, which
the printer ignores in favour of `raw`), and was corrected, not loosened.

## 10. Remaining limitations

- **47 MoonSec V3 keyed builds have no reference.** Their first act is to call the first argument their loader passes (`arg1(…)`);
  run without it they do nothing a rebuilt program can be compared with. Supplying it would mean imitating MoonSec's loader; they stay
  "no reference", unverified.
- **29 MoonSec programs end in the same error, naming another variable.** They stay "different". The name can mark a real difference that
  the stand-ins hide (§11), and none of them reaches the 50% coverage a verification needs (1% to 40%).
- **`continue` is written only for MoonSec V3.** Other Luau sources (none of QuickSilver's other lifters produce bytecode with it) would
  still be refused; Lua 5.1/5.4 output never contains it, by design.
- **The 80-instruction duplication limit is unchanged**; a real shared tail above it is still refused.
- **The `continue` check rests on reference Lua 5.4's `goto`.** Reference Lua cannot run Luau; the 60 property programs and the fixtures
  check the jump through Lua 5.4, where `goto continue` compiles to the same jump.
- **The decoder evaluation reruns at most twice**; a decoder whose sites keep failing one after another is left with the conservative rule
  (no forward result after the first failure), i.e. fewer strings decoded, never a wrong one.

## 11. Issues not conclusively resolved

- **MoonSec `42efca66`: a local in the VM against a global in the rebuilt program.** The error names `local 'b'` (a variable of the VM)
  in the original and a global in the rebuilt program. The rebuilt bytecode itself reads that global (`GETGLOBAL`, pc 30) after storing
  the result of a downloaded library's loader in a register it never reads. Whether the original
  read that local (the engine's rebuild would then be wrong) or a global cannot be told without the original source; in the sandbox both
  are nil. Left as "different".
- **#116, the rest:** a number joined to text (`n .. " " .. 1` from MoonSec's left-to-right concatenation against `n .. " 1"`) and a
  stand-in object's generated name (`60d82e8f`, which also differs by one event). Not normalised: the number's text
  depends on the Lua version, and the names are counted.
- **5 `if E then x = E` sites remain in 2 MoonSec programs**, all with `E` a plain local of the function (no evaluation is repeated); they
  are left as the compiler's shape.

## 12. Next priorities

1. The decoder-evaluation guard for lifters other than AzureVM: those with a decoded chunk (Obscura, Zartha, Vault) could be checked the
   same way after each step.
2. The 29 same-error MoonSec programs: stand-ins that let the programs run further (more of the Roblox API surface the scripts touch),
   so that their runs reach the coverage a verification needs, rather than any change to how errors are compared.
3. #116: the number's text from the run's dialect, and stand-in names by creation order.
4. Luau `continue` for any further Luau-producing lifter, declared per adapter as for MoonSec.
