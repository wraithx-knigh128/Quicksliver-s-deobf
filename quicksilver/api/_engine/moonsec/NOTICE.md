# MoonSec V3 engine: provenance, licence, changes, audit

## What this is

`src/` is **moonsec-deobfuscator-js**, a JavaScript port of
[tupsutumppu/MoonsecDeobfuscator](https://github.com/tupsutumppu/MoonsecDeobfuscator) by its author's credit line
("port of github.com/tupsutumppu/MoonsecDeobfuscator to js, all credit to the original author (tupsutumppu)"). It reached
QuickSilver in the archive the project owner supplied for Prompt XXIX (`MoonSec-Deobfuscator/`). It reads a script protected with
MoonSec V3: it parses the wrapper, decodes its constant table, evaluates the key expressions, deserializes the VM program and
devirtualizes it back to Lua 5.1 bytecode. It never runs the protected script.

## Licence

GPL-3.0. The port declares it (`"license": "GPL-3.0"` in its package.json) and the upstream project is published under it;
`LICENSE` here is the upstream repository's licence text, unchanged. The port's archive had no licence file of its own.

QuickSilver uses this code only as a separate program: `api/engine.js` starts `qs-driver.js` as its own process through
`api/_lib/isolate.js`, passes it a file and reads back a file. No QuickSilver module imports it. The modified source is
distributed with QuickSilver, in this directory, under the same licence. Every change is listed below and marked in the code
with a `QuickSilver (Prompt XXIX)` comment.

## What was left out

- `src/decompiler.js` and `tools/` (`luadec`, `luadec.exe`, `unluac.jar`): the port shells out to external decompiler
  binaries. No binary was brought in. QuickSilver decompiles the bytecode with its own decompiler (`src/decompile/`), in the page.
- `bin/` (the command-line front ends) and `instructions.txt`. `qs-driver.js` is the only entry point: it reads the input file,
  writes the bytecode file, and touches nothing else.
- The port's `package.json` dependencies are kept (`fengari` 0.1.5, `luaparse` 0.3.1, pinned in QuickSilver's package.json);
  fengari's own dependencies `readline-sync`, `sprintf-js` and `tmp` are copied with it into each run's directory.

## What was changed, and why

| File | Change | Evidence |
|---|---|---|
| `src/deobf/lua-eval.js` | Rewritten. The original evaluated each key expression in a fengari state with **every** library opened (`luaL_openlibs`). The expression is text from the script being analysed, and fengari's `os.execute` runs a shell command (`child_process.execSync`) while `io` reaches the file system. Now: only the base library (without `load`, `loadstring`, `dofile`, `loadfile`, `require`, `collectgarbage`, `print`, `getfenv`, `setfenv`), `math` and `string`; an instruction-count hook (1,000,000); the result must be a number. | Before: a four-line input whose second line is `local b = 1 + os.execute("id > .qs-output")` made the tool write `uid=65534(nobody)…` (inside the isolation runner, as `nobody`, with no network). After: "attempt to index a nil value (global 'os')", and the tool's output for real samples is byte-identical. Regression test: `tests/xxix-engines.test.mjs` with `tests/corpus/engine/evaluator-escape-probe.lua`. |
| `src/deobf/utils/string-decoding.js`, `src/deobf/deobfuscator.js` | `new TextDecoder().decode(…)` replaced by a latin-1 byte string. | Lua strings are bytes. A UTF-8 decode turned every byte that is not valid UTF-8 into U+FFFD, and the serializer then wrote that as three bytes. |
| `src/deobf/bytecode/serializer.js` | Strings are written as latin-1 bytes, not UTF-8. | Same: one char of the byte string is one byte of the chunk. |
| `src/deobf/utils/string-decoding.js` `decodeConstant`, `src/deobf/bytecode/deserializer.js` | The rule for string constants now depends on the kind of build. **Keyless** builds (one key expression): the constant is taken verbatim. **Keyed** builds (two key expressions, a constant key): a first byte above 0x7F is a marker; it is dropped and the key added to the rest (the port's rule, kept). | Measured on the 200 MoonSec V3 samples of the public collection that were checked (docs/REPORT-XXIX.md). Keyless: the runtime's string reader copies the bytes (`for i = 1 + 0, #s`); 132 of 16,639 constants start above 0x7F, and they are UTF-8 text the port's rule cut short (an emoji-led string lost its first byte and the run differed; with the bytes kept, the rebuilt program matched the original over 603 events). Keyed: 19,451 of 20,721 constants carry the marker; with the marker dropped and the key added, 19,308 of 19,324 read as text (the other 16 are emoji written as UTF-16 surrogate pairs, as their source had them); taken verbatim, none does. |

## Isolation

The engine is third-party code working on untrusted input, so it never runs in the server's process. `api/_lib/isolate.js` copies
this directory and the five npm packages into a fresh directory and starts `node qs-driver.js <in> <out>`:

- **namespaces** (a host where the server runs as root with util-linux: a self-hosted server or a container):
  `tools/isolate/run.sh`. No network namespace; a private mount namespace with empty `/home`, `/root` and `/tmp`; the user `nobody`
  with no new privileges; limits on CPU time, address space (4 GiB), file size (64 MiB), open files and processes; a wall-clock kill.
- **process** (Vercel functions, or any host without the above): a separate Node process with a memory cap, a wall-clock kill, an
  empty environment and a private working directory. This is weaker: the process can reach what the server's user can reach. It is
  used only because every path from this code to the host found in the audit (the evaluator above, the decompiler binaries) was removed.

Every answer says which isolation produced it.

## Audit of the rest

Read in full: the parser adapter (luaparse), the AST and pretty-printer, the walkers and rewriters (renamer, constant replacer and
folder, analyzer, control-flow solver), the deserializer, the devirtualizer and the serializer. None of them opens a file, a
socket, a child process or a timer. Inputs that are not MoonSec V3 make the tool throw (the driver exits 1); `api/engine.js` sends it
only input that QuickSilver's own detection recognises as MoonSec V3. `string.rep` in the evaluator can still ask for a large
string in one instruction; the isolated process's memory limit bounds it.

## What it does on the public collection

From docs/REPORT-XXIX.md (local/terrorlua, MoonSec V3, 792 files; every run through `tools/isolate/run.sh`):

- 786 rebuilt to Lua 5.1 bytecode; 6 not (4 crashes inside the tool, 2 killed at the memory limit).
- All 786 decompile to Lua that parses: 677 with every function decompiled, 109 with some functions left as marked, undecompiled
  blocks.
- Behaviour, on 120 sampled files run in QuickSilver's sandbox next to the protected original: the 73 keyless builds give 31
  identical runs, 40 different and 2 inconclusive. The 47 keyed builds have no usable reference: their originals stop in the
  sandbox before the program runs. Of the 40 differences, 29 are the same error at the same point named after a different variable.
  The rest are listed in the report: 5 originals that printed MoonSec's own message instead of running, 1 that wrote MoonSec's own
  globals, 3 equal values written differently in the trace, and 2 genuine differences in the order of calls.

MoonSec V2 is a different format: the tool reads none of the 883 V2 samples, and QuickSilver does not send V2 to it.
