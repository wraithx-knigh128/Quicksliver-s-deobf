# MoonVeil 2.1.0: research record (handler-level reconstruction)

MoonVeil is closed and commercial. The only builds available are the two samples published with an independent analysis
(github.com/Nonition/MoonveilDeobfuscator, MIT, `moonveil-2.1.0/samples`). They are kept in the git-ignored `local/moonveil/` and are not in the
repository. That project rebuilt both programs by hand; its README says it is not an automatic decompiler. Its reconstructions are used here only to
compare structure.

## What earlier prompts reached

- Prompt XIV: the container (base 85 with RFC 1924 digits, LZSS, string table).
- Prompt XV: the program data read to its last byte with a schema derived from each build's own function reader (`schema21.js`): 3 functions and
  40 instructions in sample 6, 2 functions and 28 instructions in sample 7.
- Not reached: what any opcode does.

## The obstacle, and why package decoding could not go further

The interpreter is a loop `H[ins[op]](...)`. `H` is filled by a builder through two shuffled tables. Each build shuffles everything a fixed reader
could anchor on:

- the opcode numbers;
- which handlers are fused (sample 6 fuses GETGLOBAL+NEWTABLE, GETGLOBAL+MOVE, CALL+MOVE, CALL+RETURN, GETUPVAL+RETURN, LEN+LOADN and CLOSE+LOADN);
- the instruction slot of each operand, and a constant added to every operand, both per handler;
- the order of the handler's arguments and of its five results;
- the frame slots a function runs with;
- the cell layout (`{ [1] = 2, [2] = v }` in one build, `{ [2] = 1, [1] = v }` in the other).

A table of handler shapes, the approach used for AzureVM and Vault, would fit one build at best.

## The approach taken: read the build, then partially evaluate each instruction

`src/recover/moonveil-vm/lift21.js`:

1. **Read the build:**
   - Builder: the loop `H[T[P[i]]] = F[i]` (either operand order); T, P and F are filled by constant assignments, which gives opcode → factory site → library function per cell.
   - Dispatcher: the roles of the handler's arguments (instruction, registers, frame, open upvalues, top, pc) and of its results (count, done, next pc, first result, new top).
   - Closure builder: the frame layout (`table.unpack`, `table.pack`, `table.move` and `table.create` slots, the environment, the upvalues, the prototype fields).
   - Context helpers: pack, unpack and generalised iteration, recognised by what they do.
2. **Partially evaluate every instruction through its handler:**
   - The instruction's fields are known; registers, upvalues, globals and the top are symbolic.
   - Tests on fields are decided, loops on them unrolled, and library calls on known values computed. The string decryptor that rewrites a later instruction's constant, then turns itself into a NOP, runs here.
   - A test on a run-time value (the generic `for` exit) forks; both ways must do the same apart from the next pc.
3. **Read three idioms by shape**, because they walk run-time state:
   - closing upvalues (a loop over the open-upvalue table);
   - a closure's capture list (get-or-create a cell per register);
   - Luau's generalised-iteration prep in front of a generic `for`.
4. **Write Lua 5.1 and decompile it.** MoonVeil lays blocks out of source order: a loop's tail comes after the code that follows the loop, and the loop is stepped at both head and tail. So the instructions are laid out again (loop body, then step), and the head step becomes a jump to the tail step.
5. **Join.** The factory that runs the container is replaced by the rebuilt function; natives (functions MoonVeil compiled to plain Lua) become sites of their factories; the table is joined by `moonveil-join.js`.
6. **Check.** With the sandbox on, the rebuilt script and the original are both run (same success, output and number of results), or the interpreter stays.

## Status per layer

| Layer | Sample 6 | Sample 7 |
|---|---|---|
| 1. Recognition | done | done |
| 2. Container decoding | done (XIV) | done (XIV) |
| 3. Structure (functions, instructions) | done (XV) | done (XV) |
| 4. Instructions / handlers | 24 handlers, 40 instructions read | 21 handlers, 28 instructions read |
| 5. Semantic reconstruction | done: VM functions decompiled, native `l` joined | done: VM function decompiled, native glue (`k`) and native sum joined |
| 6. Runtime | runs in the sandbox like the original | runs in the sandbox like the original |
| 7. Behavioural equivalence | same structure as the independent hand reconstruction; the checks are real (comparing against 16 instead of 15 fails) | same |

## Evidence and its limits

- **Coverage.** Two builds of the same small program (closures over `ipairs` indices, summed with `pairs`, checked against 15). That exercises
  about 26 of the handler kinds. A handler kind not in these programs (arithmetic other than ADD, comparisons as jumps, VARARG, SETUPVAL, numeric
  `for`, ...) may have a shape the evaluator does not follow. It then stops with a named reason, and the interpreter stays.
- **The negative control.** In a variant of the rebuilt code where every closure shares one variable, the assertion fails. A capture lifted wrongly
  would therefore be caught by the run comparison.
- **Natives with upvalues.** Natives that capture variables of a VM function are not rebuilt; the evaluator says so.

## Abandoned approaches (research ledger)

- **Templates from the two builds.** Abandoned: fusion, offsets and argument orders differ between the two builds, so a template set would be
  overfitted.
- **Probing handlers dynamically with instrumented tables in the sandbox.** Considered, not taken. Lua's `__eq` coerces to a boolean, `__len` is not
  honoured for tables in 5.1, and a branch on a probe value explores one side only. Partial evaluation covers the same ground without those gaps.

## Next experiment

- Turn the generalised-iteration helper and the `repeat` loops in native code back into `for` loops.
- More builds are needed: a third build with a different program would test the handler kinds above.
