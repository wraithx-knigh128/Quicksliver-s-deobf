# AzureVM: research record

Source: github.com/LionHub-Pino/AzureVM at 0e01e7a (MIT), read as text. Built on Prometheus; its preset names that contain "Luraph" are,
by its own README, historical names, and nothing of Luraph's code is in it. The 48 committed builds (8 programs x 6 presets) were made in
`tests/corpus/tools/run_isolated.py`.

## How it works (from the source)

- `string.dump` of the script under the host Lua 5.1, read into a prototype tree (`azure_vm/reader.lua`): genuine Lua 5.1 bytecode.
- Opcodes: each standard opcode gets a build-random number in 1..250, then each prototype re-encodes it as `(op * mul + add) % 256`
  (mul odd, its inverse and `add` stored in the prototype's header) and picks one of three operand layouts per instruction from the
  previous encoded word. Every 40-bit word is offset by `(seed + i * 1664525 + 1013904223 + prev * 37) mod 2^34`.
- Strings: each byte offset by a state seeded by the string key and a per-constant nonce. Decoy strings are appended to every constant
  table.
- Container: the binary tree, a rolling three-key byte encoding (fed back by the ciphertext), Ascii85 with `z`, in `[=[LPH>...]=]`, with an
  Adler-style checksum.
- Runtime: one dispatch table `D[n] = function(R, a, b, c, bx, sbx) ... end` built from 38 fixed templates, plus 7 to 66 decoy handlers
  at unused numbers. Layered presets run Prometheus steps (SplitStrings, EncryptStrings, NumbersToExpressions; Ultra also MBA, opaque
  predicates, deep flattening) on the source before it is compiled.

## Status per layer

| Layer | Status | Evidence |
|---|---|---|
| 1. Recognition | done | the `LPH>` payload and the handler table |
| 2. Container decoding | done | Ascii85, rolling decode, checksum verified on every build |
| 3. Structure | done | prototype tree read exactly as the runtime reads it |
| 4. Instructions / handlers | done | the 38 handlers matched to the generator's templates (names renamed by order of appearance), decoys refused by shape, MOVE's code cross-checked against the CLOSURE handler |
| 5. Semantic reconstruction | done where the decompiler can structure the code | standard Lua 5.1 chunk rebuilt and decompiled |
| 6. Runtime | done | the rebuilt chunk runs on the reference Lua 5.1 exactly like the original (checked on three presets) |
| 7. Behavioural equivalence | measured | 36 of 48 builds run like the original at high confidence; 11 keep the VM (the decompiler cannot structure a function, or the self-check refuses) and say so; 1 runs like the tool's own diverging build |

## Two findings that apply beyond AzureVM

- **Decompiler: upvalue closing.** Without debug information a register was one variable for the whole function; a register a closure
  captured and the code then reused (after a CLOSE) overwrote the closure's variable. Each CLOSE now starts a new generation of the
  captured registers it covers (`src/decompile/decompile.js`). This moved the layered presets from 16 to 29 of 40 at the decompiler level.
- **Self-check against the decoded chunk.** The decoded chunk is the VM's own program, so the reconstruction is run against it in the
  sandbox (`src/recover/bytecode-check.js`); a reconstruction that prints something else is not reported as recovered. It caught one
  AzureGodUltra build that the decompiler had structured wrongly without noticing.

## Unresolved, next experiment

- Functions the decompiler cannot structure (AzureGodUltra: deep flattening and opaque predicates; some Luraph14/AzureGod15 functions).
  Next: run the Cff/Prometheus readers on the decompiler's partial output, or let the decompiler emit a dispatcher form the flattening
  readers already understand, instead of refusing the function.
- Loop-carried closures without debug information (a fresh variable per iteration) are still one variable per generation.
