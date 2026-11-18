# Prompt XX — Custom-Format & Luarmor Reconstruction Initiative: report

The report keeps four things apart: completed improvements, partial recoveries, unsupported cases, and what still needs research. Every claim
names its evidence. The work is in the commits on `ccr-17f6469c-lf3p64` after `0418b89`.

## Audit first (Phase IX)

The existing **Custom Obfuscator module** (`src/custom/analyze.js` with `probes.js`) already ran a probe → plan → try-the-VM-readers →
recover → explain pipeline over 12 kinds of transformation. It was measured on the real third-party scripts in `local/corpus` that no detector
recognises (24 unique scripts in the first pass). Three weaknesses stood out:

| # | Weakness | Evidence |
|---|---|---|
| 1 | An unknown VM ended as "bytecode-vm: unresolved"; the only explanation was that the known readers refused it. | 10 of 24 scripts |
| 2 | Luarmor bootstraps ended as "minimal; wrapper unresolved", with no account of what the file contains. | 7 of 24 |
| 3 | "minified-layout" was reported unresolved after recovery even when the output was laid out: any line holding a long string literal counted. | 18 of 24 |

The **loader analysis** (Prompts XVIII–XIX) recognised Luarmor only as a family with case 6. The **pipeline's integration point** for new
analysis is `analyzeCustom` (the Custom format tab) and the `loader` op (the Loader tab). Both were extended, not duplicated.

## Completed improvements

### 1. Custom Obfuscator Intelligence: the anatomy engine (`src/custom/anatomy.js`)

It explains the structure of a script without needing a tool name:

- **Function roles**, each with evidence:
  - string decoder;
  - base-N decoder (including an alphabet held outside the function);
  - LZW-style decompressor;
  - byte, varint or float deserializer;
  - keyed XOR;
  - interpreter;
  - environment manipulation;
  - anti-analysis.
- **Encoded regions:** charset, entropy and share of the file, linked to the function that consumes them by data flow.
- **Stage boundaries:** runtime compilation (including `(loadstring or load)(…)`), VM entry points grouped per interpreter, wrappers.
- **VM anatomy:** register or stack machine, instruction encoding (tables and the fields read, or packed numbers and their bit widths),
  handler count and shape, closures, varargs, jumps.
- **Hypotheses, each with a confidence and a test:**

  | Hypothesis | Confirmed by |
  |---|---|
  | decoder | **call sites that the sandboxed evaluator actually replaced** — a site the evaluator rejected does not count |
  | VM | a known reader that reads its program |
  | layer | the pipeline unwrapping it |

  A refuted hypothesis loses confidence and is shown as refuted.

What this changed:

- The 10 unknown VMs of the first audit are now described, by machine type, instruction format and handler count, instead of only
  "unresolved".
- On the real Luau VM script `Unknown/0030800e…`: a register machine with 47 handlers; instructions read as table fields `[1]`–`[4]`; a
  12,984-byte custom-alphabet string consumed by `VMCall`; one VM entry per function the VM runs.

The measured counts are in "Measured on the unfamiliar corpus" below.

### 2. Learned rules (`src/custom/rules.js`, `tools/custom/learn.mjs`, `data/research/learned-rules.json`)

- **What a rule is.** A structural fingerprint of a function whose role was **confirmed** by a test on an authorised sample. Names and
  constants are abstracted away; the shape is kept.
- **What is kept.** 1341 samples were tested; 28 fingerprints were kept. A fingerprint is dropped if it was ever refuted (131), confirmed
  for two roles (3), or seen on only one sample (173).
- **Effect.** An exact match raises a hypothesis, but the hypothesis is still tested. A near match (shape similarity ≥ 0.85) is reported as
  "resembles" and **never treated as the same format** (Phase II item 9).

### 3. Multi-layer identification

After the pipeline peels a layer it identifies the tool underneath, and the custom analysis now reports this as
`identifiedAfterPeeling`. Example: Hercules under the project's XOR packer is now named; before, it was "missed".

### 4. Probe fix

A long string literal no longer counts as minified layout (`probes.js`). There is a regression test.

### 5. Dedicated Luarmor analysis module (`src/loader/luarmor.js`; `docs/targets/LUARMOR.md`)

Recognised variants, each observed in real loaders: **bootstrap**, **sdk**, **loader-url** and **key-link**.

The five operations are answered separately:

| # | Operation | Result |
|---|---|---|
| 1 | Analyse the loader | done |
| 2 | Recover code present in the loader | The loader's own logic is recovered in full. When it is obfuscated, it goes to the Deobfuscator and is measured there. |
| 3 | Retrieve the delivered payload | Not available: no documented interface returns a protected script. |
| 4 | Deobfuscate the retrieved payload | Needs the owner's script. |
| 5 | Validate behaviour | Needs the original. |

What else it does:

- The bootstrap data table is reported as **opaque**, with its shape described. Its consumer is the service's runtime, which is deliberately
  neither fetched nor analysed.
- Keys are redacted. In the recovered loader logic, a `script_key` literal becomes a placeholder.
- It is integrated into the Loader op and the Loader tab, not built as a second deobfuscator.

**Answer to the central question.** From a Luarmor loader, OMEGA NEXUS recovers all of the loader's own code: cache logic, key flow, status
handling and UI. When that code is itself obfuscated, it recovers it through the existing pipeline. **None of the protected script is in the
loader.** Reconstructing it requires the script itself, from its owner. No authorised service route returns it.

### 6. Evidence collection (`tools/custom/collection.mjs` → `docs/COLLECTION.md`)

20 samples across every category Phase VII lists, each measured on detection, recovered stages, completeness, syntax, behaviour (on the
runtime the tool targets), confidence and remaining limitations.

| Measure | Result |
|---|---|
| Detection | **15 / 15** correct |
| False or wrong tool claims | **0** |
| Outputs that parse | 18 (the 2 malformed inputs are reported, not crashed on) |
| Behaviour equal to the original | **13 / 13** where checked |
| Hypotheses confirmed by their tests | 18 |

Behaviour equality is not counted as reconstruction. ZenFus keeps its VM, runs the same, and is reported at **minimal** confidence with its
limitation named.

### 7. Website

- **Custom format tab:** an Anatomy section showing the architecture, the VM anatomy, and a hypothesis table with confidence and test result.
  It loads the learned rules.
- **Loader tab:** a Luarmor section showing the five operations, the loader's own code (which can be opened), embedded data, and what is not
  in the file.
- Verified at 1440 and 390 px, with no overflow and no console errors.

## Partial recoveries

- **Unknown VMs: described, not lifted.** The anatomy says what the VM is; a lifter still needs per-format handler templates, or handler
  synthesis (`docs/METHODS.md` §4).
  - Example: ZenFus is minimal (VM kept).
  - Example: AzureVM AzureGodUltra is low.
- **Clyde VM: low confidence.** It runs like the original on Lua 5.2.
- **Decoders the evaluator cannot run:** these are inconclusive rather than confirmed. This covers decoders called fewer than four times,
  decoders that are not top-level, and any decoder when the sandbox is off (KNOWN-ISSUES 74).

## Unsupported cases

- **The protected Luarmor script.** It is not in the loader, and no authorised interface returns it (KNOWN-ISSUES 76).
- **Truncated or syntactically broken input.** It is reported, not reconstructed.

## Still requires research

- **Handler-level fingerprints.** Whole-interpreter fingerprints rarely repeat across builds (KNOWN-ISSUES 75).
- **Handler synthesis**, to lift VMs the anatomy describes but no reader accepts.
- **Per-site evaluation** of single-use decoders.

## Measured on the unfamiliar corpus

The numbers are filled in after the audit completes (see below).

## Phase VI research

The anatomy engine applies two ideas from earlier research rounds (`docs/METHODS.md`):

- **Testing semantic hypotheses by execution on controlled inputs.** This is the idea behind Syntia, here applied conservatively: the
  project's own sandboxed evaluator, run on decoder slices.
- **Treating an interpreter as an interpreter to recover its language.** This follows Rolles (WOOT 2009), here as anatomy before lifting.

The Roblox model and LZ4 work of Prompt XIX supplies the container side.

No new external code was used.

## Tests

- `tests/xx-anatomy.test.mjs`: 8 tests.
- `tests/xx-luarmor.test.mjs`: 6 tests.
- `tests/xx-collection.test.mjs`: 5 tests.

The full-suite and e2e results are added below when they finish.
