# Prometheus VM engine: provenance, licence, change, audit, use

## What this is

`src/` is the **Prometheus Deobfuscator** by LeakD ("supports wearedevs fork + latest version · MIT"; README:
`git clone https://github.com/prostone4/Prometheus-Deobfuscator`). It reached QuickSilver as `Prometheus-Deobfuscator-Fixed/` in
the archive the project owner supplied for Prompt XXIX. It is pure JavaScript (about 16,500 lines): a Lua 5.1 parser, a set of passes
that undo Prometheus' steps (string encryption, constant arrays, number expressions, proxified locals, wrappers), a lifter for the
Vmify bytecode VM, and a small Lua interpreter it uses to fold expressions.

## Licence

MIT. `LICENSE` here is the project's licence file, unchanged (Copyright (c) 2026 LeakD).

## What was brought in, and what was left out

- In: `src/` and `LICENSE`. `qs-driver.js` (QuickSilver's) is the only entry point: it reads the input file, runs the tool's
  `deobfuscate()` with its own identification switched off (QuickSilver's detection decides what is sent), and writes the Lua it
  produces. `package.json` is QuickSilver's (no dependencies).
- Out: `bin/pdeobf.js` (the command line), the original `package.json` and README.

## What was changed, and why

| File | Change | Evidence |
|---|---|---|
| `src/lua/parser.js` `blockEnds()` | `BLOCK_TERMINATORS.has(…)` → `TERMINATORS.has(…)`. The set of block-ending keywords is declared as `TERMINATORS` (line 28); the other name is never defined, so every parse that reached this line threw "BLOCK_TERMINATORS is not defined". | On QuickSilver's 131 Prometheus fixtures, 55 runs ended with that error (51 of them after the tool's own identification had refused the build and `--force` was used). After the fix those builds parse and are lifted. Regression test: `tests/xxix-engines.test.mjs` (a Weak build). |

## Audit

Read: the driver path (`src/index.js`, `src/pipeline.js`), the parser, the interpreter (`src/interp/`) and the files that reach Node.
The only Node module the code uses is `fs`/`path`, in `pipeline.js`, and only when a `trace` option asks it to write each step's text
to a directory; the driver never passes it. The interpreter's standard library is its own: `print`, `type`, `pairs`, `pcall`,
`setmetatable`, `string`, `table`, `math` and the like, `require` returning nothing, and no `os` or `io` — the script it folds cannot
reach the host through it. No network, no child processes, no timers. It still runs only as a separate process through
`api/_lib/isolate.js` (`tools/isolate/run.sh` where the host allows namespaces), like the MoonSec engine.

## How QuickSilver uses it, and why only that way

Measured on QuickSilver's 131 Prometheus fixtures (its own test programs, obfuscated by Prometheus; docs/REPORT-XXIX.md), every run
isolated, every output compared in QuickSilver's sandbox:

- On the 53 Medium, Strong and Vmify builds, the engine lifts 31 to a program that behaves like the protected script (26 like the original; the other 5 are
  builds the manifest records as diverging from their original on real Lua, which the engine reproduces faithfully), is **wrong on 6**
  (a program that runs, parses and behaves differently), and, as supplied, crashed on 16 (the undefined name fixed above). QuickSilver's own passes leave the VM in place in 40 of them.
- A behaviour comparison **with the script itself** — the only reference a real user has — accepts all 31 faithful programs and none
  of the 6 wrong ones.

Through the whole pipeline (QuickSilver's passes first, then the engine, then the gate), the share of the 131 fixtures that come out
behaving like the reference with nothing left goes from 59 to 94, with no result that behaves differently and no "validated" result
that is not clean (68 builds use Vmify: 10 → 45; the engine was asked 58 times, its program used 35 times, rejected by the gate 23
times).

So the adapter (`src/pipeline/engines.js`, `prometheus-vm`) runs only when QuickSilver's own result still carries Prometheus
protection, only when the person has the behaviour check on, after they confirm they may send the script, and its program is the
result only when that comparison is identical and reaches at least half of the program's lines. Otherwise QuickSilver's own result is
kept, and the report says why.
