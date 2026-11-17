# MoonVeil — progress record (all versions)

MoonVeil is closed and hosted; nothing can be generated. Evidence is public third-party scripts, read (not stored), with the SHA-256 of each in
`data/research/format-records.json`. Versions are the banner the script carries. The per-script measured numbers are in `docs/MATRIX.md`; the
version-difference synthesis is in `docs/VERSION-MATRIX.md`; the 2.1.0 handler work has its own deep record in `docs/targets/MOONVEIL-2.1.0.md`.

## Architecture by version (the central finding)

MoonVeil is not one obfuscator across versions — it changes its whole program representation:

| Version | Program representation | Package / loader | Status |
|---|---|---|---|
| 1.4.5 | control-flow flattening over a large string blob | — | identified; dispatchers + blob remain (KNOWN-ISSUES 19) |
| 2.0.25 / 2.0.26 | a **table of factory functions** that build each other (no bytecode) | base-85 text, string table, cells | strings/numbers/cells decoded; joined from the factory table, not fully recovered (names lost, register temporaries remain) |
| 2.1.0 | a **bytecode VM** again, with a per-build function reader and a 26-handler interpreter | base-85, LZSS, string table, function header | **rebuilt from its handlers** (Prompt XVI): both samples run in the sandbox like the originals |

So support for 2.1.0 says nothing about 2.0.26, and vice versa — the matrix keeps them separate on purpose.

## The eight metrics

| | 1.4.5 | 2.0.26 | 2.1.0 |
|---|---|---|---|
| 1 identification | ● | ● | ● |
| 2 version recognition | ● | ● | ● |
| 3 transformation stages | ◐ | ● | ● |
| 4 structural | ○ | ◐ | ● |
| 5 instruction/handler | — (not a VM) | — (factory table) | ● |
| 6 semantic | ○ | ◐ (34% vs a hand reconstruction) | ● |
| 7 runtime | n/a | n/a | ● (sandbox) |
| 8 behavioural equivalence | n/a | n/a | ◐ (matches the independent hand reconstruction; two builds only) |

n/a for metrics 7–8 on 1.4.5/2.0.26: the scripts need Roblox objects and their originals are not available.

## What is genuinely reconstructed vs partially understood

- **Reconstructed:** 2.1.0's two samples (handler-level, run-verified). The base-85/LZSS/string-table/function-header container for 2.0.26 and
  2.1.0. The cell layout and bootstrap permutation for 2.0.25/2.0.26.
- **Partial / open:** 2.0.26's factory-table join (readable but not named/structured like source); 1.4.5's flattened dispatchers and blob;
  2.1.0 handler kinds that do not occur in the two available samples (the lifter stops with a named reason and keeps the VM when it meets one).

## Next experiments (§III)

1. 2.1.0: more builds, ideally of a known tiny source, to cover handler kinds outside the two samples and to pin them by differential analysis.
2. 2.0.26: lift the factory table to structured source (names and control flow) rather than a joined program.
3. 1.4.5: unflatten the three dispatchers and read the blob.

Implementation: `src/recover/moonveil-join.js`, `src/recover/moonveil-vm/`, `src/recover/moonveil-cff.js`, `src/recover/moonveil.js`. Tests:
`tests/xvi-moonveil21.test.mjs`, `tests/xv-targets.test.mjs`, `tests/moonveil-vm.test.mjs`, `tests/moonveil-join.test.mjs`.
