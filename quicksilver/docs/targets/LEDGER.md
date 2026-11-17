# Prompt XVI research ledger

The status levels are: recognition, container decoding, structure, instructions/handlers, semantic reconstruction, runtime, behavioural
equivalence. "SAME" means the recovered script printed the same output and succeeded or failed the same way as the original program, on the
reference interpreter (lupa Lua 5.1 / Luau oracle) or in the JS sandbox where said.

## Status records

### Vault-Obf (docs/targets/VAULT.md)
- **Status:** lifted (`vault.vm`). Every level reached on the builds the tool itself runs correctly.
- **Discoveries:** the payload uses three containers (base-45 printable, `\206` binary, raw tables); there are four dispatch strategies and two
  layouts; the generator computes an upvalue remap and never applies it (a defect in the tool).
- **Improvements:** the decoder and the lifter; the upvalue order is restored where evidence decides it.
- **Tests:** `tests/xvi-vault.test.mjs`; 175 local builds.
- **Blockers:** builds the tool itself breaks (upvalue order) are reproduced as the tool runs them unless evidence repairs them.
- **Sources:** Vault-Obf source read as text (licence forbids redistribution; fixtures local).
- **Confidence:** high where SAME; lowered where the order is unresolved.
- **Next experiment:** none pending.

### MoonVeil 2.1.0 (docs/targets/MOONVEIL-2.1.0.md)
- **Status:** rebuilt from its handlers (`moonveil.vm21`). Both samples run like the originals in the sandbox, and their structure matches the
  independent hand reconstruction.
- **Discoveries:** per-build permutation of fusion, operand slots and offsets, argument and result order, frame layout and cell layout; natives
  looked up by name; blocks laid out out of source order; loops stepped at head and tail.
- **Improvements:** handler partial evaluation (`lift21.js`), layout normalisation, a join with the container runner replaced.
- **Tests:** `tests/xvi-moonveil21.test.mjs`.
- **Blockers:** only two builds of one program exist.
- **Sources:** samples from github.com/Nonition/MoonveilDeobfuscator (MIT), kept local.
- **Confidence:** high with the sandbox check, medium without it.
- **Next experiment:** more builds; turn natives' `repeat` loops back into `for` loops.

### AzureVM (docs/targets/AZUREVM.md)
- **Status:** lifted (`azurevm.vm`). 36 of 48 builds are SAME at high confidence; 11 keep the VM, and so say; 1 matches the tool's own diverging build.
- **Discoveries:** real Lua 5.1 bytecode behind a 2^34 keystream, affine opcode maps and three operand layouts.
- **Improvements:** the lifter; the decompiler's CLOSE generations; a sandbox self-check of a reconstruction against its chunk.
- **Tests:** `tests/xvi-azurevm.test.mjs`.
- **Blockers:** functions the decompiler cannot structure (AzureGodUltra).
- **Sources:** github.com/LionHub-Pino/AzureVM (MIT).
- **Confidence:** high where checked.
- **Next experiment:** structure the remaining flattened functions.

### RealObfuscator (docs/targets/REALOBFUSCATOR.md)
- **Status:** VM lifted (`realobfuscator.vm`). 20 of 20 VM builds are SAME on Luau, at high confidence.
- **Discoveries:** a register machine with cells and argument lists, plain-Lua factories for closures, methods and generic `for`; checksummed records
  linked in shuffled order.
- **Improvements:** the lifter, which writes straight to source with temporaries folded in evaluation order.
- **Tests:** `tests/xvi-realobfuscator.test.mjs`.
- **Blockers:** none on the fixtures.
- **Sources:** github.com/linkoro57/RealObfuscator (GPL-3.0; fixtures local).
- **Confidence:** high.
- **Next experiment:** re-raise numeric `for` loops.

### Hardened Obscura (docs/targets/HARDENED-OBSCURA.md)
- **Status:** recognised and profiled; not lifted.
- **Discoveries:** the eleven hardening features and what each requires, read from the v1.1.0 source.
- **Improvements:** none in code this round.
- **Tests:** the existing ones (hardened builds stay not lifted and are not rated recovered).
- **Blockers:** fused superinstructions and per-opcode operand and byte order.
- **Sources:** github.com/vo3pal/obscura at 5657a73 (MIT).
- **Confidence:** n/a.
- **Next experiment:** handler partial evaluation as for MoonVeil 2.1.0.

### LuaQ (docs/targets/LUAQ.md)
- **Status:** recognised; stage 1 decoded to the VM runtime (`luaq.layers`). The program itself is not in the file.
- **Discoveries:** base-93 + LQZ1 + DEFLATE outer layer; a 606 kB Luau VM runtime with environment checks and an encrypted loader program.
- **Improvements:** the stage-1 decoder, a dependency-free DEFLATE inflater, a detection family, a confidence note.
- **Tests:** `tests/xvi-luaq.test.mjs` (codec tests on data built in the test; the sample test skips without the local file).
- **Blockers:** the program is delivered to the script at run time from outside the file; recovering it is out of scope.
- **Sources:** one v2.7 sample supplied by the user (local only).
- **Confidence:** minimal for this format, by design.
- **Next experiment:** none planned.

## Abandoned approaches

| Target | Approach | Why it was dropped |
|---|---|---|
| MoonVeil 2.1.0 | handler templates taken from the two builds | fusion, operand offsets and argument orders differ per build: overfitted |
| MoonVeil 2.1.0 | probing handlers with instrumented tables in the sandbox | `__eq` coerces to boolean, `__len` is ignored on 5.1 tables, branches on a probe see one side: partial evaluation covers the same ground without the gaps |
| MoonVeil 2.1.0 | writing the program as Lua 5.1 in MoonVeil's own block order | the decompiler reads compiler layout; blocks are laid out again instead |
| RealObfuscator | lifting through Lua 5.1 bytecode | argument lists, cells and method/iteration bridges have no natural 5.1 form; straight to source instead |
| RealObfuscator | one local per register | hundreds of registers per function would pass Lua's 200-local limit; single-use temporaries are folded |
| AzureVM | trusting the decompiler's output without a check | one AzureGodUltra build was mis-structured and rated high; the sandbox self-check against the chunk catches it |
| Vault | accepting the tool's upvalue order | the tool's own builds compute the wrong upvalue; the order is restored on evidence instead |
| LuaQ | fetching the vendor site | DNS failure in this environment; not worked around |
| LuaQ | recovering the program from the file | it is not in the file |
