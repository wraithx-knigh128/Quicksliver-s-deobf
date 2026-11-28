# Prompt XXXI measurement scripts

The scripts behind the numbers in `docs/REPORT-XXXI.md`; their results are in `data/research/xxxi-reconstruction.json`. `Q` is this
checkout; `S` is the Prompt XXIX work directory (`$S/ms-bc/*.luac`: the 786 chunks the MoonSec V3 engine rebuilt, unchanged since XXIX,
from the git-ignored `local/terrorlua` collection); `D` is a source tree to measure (this one, or a worktree of `534bb94` for the baseline).
Only QuickSilver's own code runs; no third-party code is run by these scripts.

| Script | Measures |
|---|---|
| `msafter.mjs Q S batch\|behaviour` | the MoonSec tables with the dialect the adapter passes (Luau): decompiled, parses, shared subtrees, `continue` count; the 120-file behaviour set with the adapter's verify options |
| `doubleread.mjs D dir` | `if E then x = E` sites in the decompiled chunks of `dir` (`DIALECT=luau` as the product) |
| `evalorder.mjs Q D` | the #114 property counted on a given decompiler: same reads and calls / different / shared subtrees / undecompiled |

Also used, unchanged: `tools/engines/xxx/protos.mjs` (per-function census), `tools/engines/xxx/propmeasure.mjs` (the decompiler property
seeds), `tools/engines/xxix/integ.mjs` with `tools/engines/xxx/prom-sum.py` (Prometheus, row by row), `tools/regress/records.mjs --check`.
