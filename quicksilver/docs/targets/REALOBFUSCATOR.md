# RealObfuscator 2.2.1: research record (function VM)

Source: github.com/linkoro57/RealObfuscator at 9ec569f (GPL-3.0-only), read as text; nothing of it is copied into this repository. The 20 VM
builds (7 programs at `vm`, `vm-max` and `vm-cached`, one omitted for size) were made with the Rust binary built offline and run in
`tests/corpus/tools/sandbox_run.py`. They stay in the git-ignored `tests/corpus/obfuscated-local/realobfuscator-2.2.1`.

## How the VM works (from src/function_vm.rs and its runtime)

- **Where it applies.** Every function body the compiler supports becomes `return RUNNER(BANK[id], { externals }, { parameters }, ...)`. A body it does
  not support stays plain Lua, and so does the chunk when it uses `getfenv`, `setfenv` or `debug`.
- **The instruction set.** A register machine of about 30 operations. Every source local is a one-slot cell. Argument and result lists are tables with
  a count. Names that are not locals are reached through accessor closures. Closures, method calls and generic `for` loops are written as plain-Lua
  factories that reach the function's cells as `P[register][1]`; a generic `for` calls back into the VM for its body, which ends in a signal.
- **Records.** Five 32-bit words (op, a, b, c, next) in a byte order shuffled per function, plus a checksum, optionally run-length packed. Each
  record is encoded with a 32-bit xorshift stream keyed by the function's seed, salt and step and by the record's position. Instructions are stored in
  shuffled order and linked by their `next` word.
- **Opcodes.** Two to four random aliases per operation (`vm-max` four), dispatched by a balanced tree of `op < N` tests whose leaves are fixed handler
  templates.

## The approach

`src/recover/realobfuscator-vm.js`:

1. **Read the runtime.** The slots of a bank record come from the runtime's own uses of them (key mixing, step, count, constants, byte layout,
   payload, entry). Every leaf of the dispatch tree is classified by what it does once the runtime's names are put back.
2. **Decode every record statically.** The checksum must hold, so a key read wrong fails loudly instead of giving wrong instructions.
3. **Write each basic block as statements.** The control flow comes from the linked list and the jumps.
   - Temporaries used once are folded into their use, only in evaluation order.
   - Lists become argument lists, or one local per item when only read item by item (multiple assignment, numeric `for` state).
   - Cells become locals, named per function so a closure's locals do not shadow the cells it reaches.
   - Factories become the closure, method call or generic `for` they stand for.
4. **Structure and finish.** The graph is structured by `src/decompile/cfg.js`. Call sites are lifted innermost first. The bank and the runtime are
   removed.
5. **Check.** With the sandbox on, the rebuilt script must run like the original or the VM stays.

## Status per layer

| Layer | Status |
|---|---|
| 1. Recognition | done (header, record pool) |
| 2. Container decoding | done: all records of all 20 builds decode with their checksums verified |
| 3. Structure | done: linked list and jumps to basic blocks |
| 4. Instructions / handlers | done: 120 to 140 aliases per build, all classified |
| 5. Semantic reconstruction | done: source with locals, calls, closures, method calls and loops |
| 6. Runtime | 20 of 20 run in the sandbox like the original |
| 7. Behavioural equivalence | 20 of 20 match the original program's output on the reference Luau; confidence high |

## Limits

- Numeric `for` loops come back as `while` loops over three locals when the clean-up passes do not re-raise them.
- One `vm-cached` build keeps three strings encoded: the tool's string decoder was refused by the evaluation sandbox for that build, before and
  after the VM is lifted.
- A `break` that leaves a generic `for` body from inside a nested loop of that body is refused rather than guessed (none occurs in the fixtures).
