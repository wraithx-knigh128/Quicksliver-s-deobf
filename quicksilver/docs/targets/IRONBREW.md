# IronBrew — progress record (architecture and version-wide)

Two related families: **IronBrew 2** (the open-source Lua VM obfuscator) and **IronBrikked** (LuaXen's IronBrew-derived backend). They share a
lineage but are different compilers, so they are reconstructed separately. Measured numbers are in `docs/MATRIX.md`; the per-config statuses are
generated from the committed scorecard, so they cannot drift from the fixtures.

## IronBrew 2

Eight build options, all generated into committed fixtures (`tests/corpus/obfuscated/ironbrew2`, 8 samples each):

| Config | What it adds | Status | Runtime |
|---|---|---|---|
| default, plain | the base VM | verified | 8/8 run like the original |
| mutate | control-flow mutation | verified | 8/8 |
| super | super-operators (fused handlers) | verified | 8/8 |
| flow | heavier control flow | verified | judged subset runs like the original |
| lineinfo | line info kept | verified | 8/8 |
| nocompress | no payload compression | verified | 8/8 |
| strings | string encryption | partial | 8/8 run; a textual-fidelity residual is noted |

**Approach:** the program is read out of the VM data and rebuilt (`src/recover/ironbrew.js`, `src/recover/ib2-templates.js`), then decompiled; the
result is run against the original on the reference interpreter.

## IronBrikked (LuaXen)

Configs `ironbrikked` and `both` (`tests/corpus/obfuscated/luaxen`, 7 samples each). Status **partial**; runtime pairs are 0/0 because these are
Luau builds with no oracle pairs in the committed set.

**The key distinction (§IV).** IronBrikked's compiler has its own defects — it puts temporaries over live registers, and compiles assignments to
globals/upvalues as a move into register 0 (it has no SETGLOBAL/SETUPVAL). The lifter reads the program **as the compiler emitted it**, repairing the
faults that are only encodings (the parameter count it never stores, upvalue links after a closure, return counts written as registers, a loop body
that reads its own counter). A program *inside what the compiler handles correctly* is recovered exactly — proven on the controlled
`tests/corpus/controlled/luaxen-subset`. The shipped fixtures sit **outside** that subset, so the result follows the compiled instructions and can
differ from the original source. That is why metric 8 is only ◐ for IronBrikked and ● for IronBrew 2.

This is the §IV requirement made concrete: a reference program (`luaxen-subset`) separates **compiler defects** (IronBrikked's own) from **engine
defects** (ours). Where the two agree, the lift is exact; where IronBrikked itself miscompiles, the honest result is the compiled program.

## The eight metrics (summary)

| | IronBrew 2 | IronBrikked |
|---|---|---|
| 1 identification | ● | ● |
| 2 version recognition | ● | ● |
| 3 transformation stages | ● | ● |
| 4 structural | ● | ◐ |
| 5 instruction/handler | ● | ◐ |
| 6 semantic | ● (◐ for `strings`) | ◐ |
| 7 runtime | ● | n/a (no Luau oracle pairs) |
| 8 behavioural equivalence | ● | ◐ (exact on the `luaxen-subset`; the shipped fixtures are outside it) |

## Next experiments

1. IronBrew 2 `strings`: close the textual-fidelity residual (the strings run correctly; the gap is in how the decoded strings are presented).
2. IronBrikked: widen the controlled `luaxen-subset` so more of the compiler's correct-output surface is covered, and add Luau oracle pairs so
   metric 7 can be measured on the shipped fixtures.

Implementation: `src/recover/ironbrew.js`, `src/recover/ib2-templates.js`, `src/recover/ironbrikked-vm.js`. Tests: `tests/opensource*.test.mjs`,
the scorecard, and the controlled reference tests.
