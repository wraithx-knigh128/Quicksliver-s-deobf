# Vault-Obf: research record

Source: github.com/polarr-is67/Vault-Obfuscator, commit 4cf9664, read as text. Licence: Vault Source-Available License 1.0 (research and internal use;
no redistribution), so every build of it stays in the git-ignored `tests/corpus/obfuscated-local/vault*` and the committed tests skip without them.
The tool was run only in `tests/corpus/tools/sandbox_run.py` (no network, no host files, no privileges).

## Status per layer

| Layer | Status | Evidence |
|---|---|---|
| 1. Format recognition | done | the payload table shape (decode parameters, integrity record, two counted records, metadata, one record per prototype); `looksLikeVault` |
| 2. Container / package decoding | done | base-45 printable blobs over the per-build alphabet the decoder carries, the `\206` binary container (LEB128, 2- and 4-byte fields), plain tables; scattered blobs read through the locals they are split into. Constants of all 175 builds decode to the programs' strings |
| 3. Structural reconstruction | done | prototypes decoded exactly as the runtime does: per-record LCG deltas, the per-field step, the grouped operand order, the tag permutation, three constant modes, the `scrambled` physical order |
| 4. Instruction and handler recovery | done | the 41 opcodes read off the handlers in all four dispatch strategies (cascade, tree, table, indirect through a remap blob) and both field layouts; arithmetic helpers identified by the operator their own body computes; two handlers with one meaning refuse the lift (except MARK/NOP, both empty) |
| 5. Semantic reconstruction | done | each prototype lifted to a Lua function (registers as locals, upvalues as the parent's locals, result lists as argument lists, `local a, b = f()`), structured by the CFG structurer, cleaned by the usual passes |
| 6. Runtime execution | done | every lifted program runs on Lua 5.1 |
| 7. Behavioural equivalence | measured | 175 local builds (21 at seed 1337, 112 covering every preset x family x dispatch, 42 Luau-target): see below |

## Measured (lua51 reference runtime)

- Programs whose Vault build runs like the original: every recovered program runs like the original too.
- Programs whose Vault build does not: Vault miscompiles them, and the recovered program behaves exactly like Vault's build (same output, same error),
  except where the defect below could be undone on evidence.
- Strong builds abort in the reference runtime ("execution aborted by integrity guard": the self-check reads the script's own source); their
  recovered programs run like the originals.

## A defect of the tool, and what can be undone

`bytecode/generator.py` shuffles each prototype's upvalue descriptors (`upval_shuffle`, on in every preset) and builds `upval_remap`
"for SETUPVAL/GETUPVAL", but `_emit_instruction` never applies it. A closure with two or more upvalues therefore reads the wrong variables
(s02, s05, s07 at seed 1337). The original numbering is not stored anywhere in the build.

The lifter restores the order only on evidence: what the closure does with each upvalue (calls, indexes, arithmetic, concatenation,
comparison) against what the captured variable holds when the closure is made (a table, a function, a number or string constant, followed
through moves to the reaching definition). The build's order is kept unless exactly one order fits. Every closure with two or more upvalues
whose order is not determined is counted and lowers confidence below high, because the program may then differ from the original.

Result: s07 (low) runs like the original after the repair, s05's memoiser is repaired, s05's counter and s02's `addItem` stay undetermined
(two numbers captured: no evidence distinguishes them) and are reported as such.

## Confidence and evidence quality

High for layers 1-6 (exact decoding, 175 builds, all shapes, two targets). Layer 7 is limited by the tool's own defect; the limit is measured,
not assumed.

## Approaches tried

- Running the payload decoder of the script in a sandbox: not needed and not used. The decode is pure arithmetic on literals given in the
  build, re-implemented from the runtime template and checked on every build.
- Classifying handlers by printed text with identifiers removed: not enough (the six arithmetic handlers differ only in which helper they
  call). Identifying the helpers by the operator in their own body settled it.
- Flow-insensitive type inference for the upvalue repair: wrong (registers are reused for other values). Replaced by the reaching
  definition at the CLOSURE instruction.

## Unresolved, next experiment

- Closures capturing several values of the same kind (two numbers): undetermined. A next experiment would combine several closures of one
  parent that capture the same register (their own evidence is independent), and writes (SETUPVAL) against variables the parent treats as
  constants; it must stay evidence-only.
- s06 is rejected by Vault's own parser (`function a:b()`); nothing to recover.
