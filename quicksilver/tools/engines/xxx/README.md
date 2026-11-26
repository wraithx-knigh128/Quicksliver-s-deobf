# Prompt XXX measurement scripts

The scripts behind the numbers in `docs/REPORT-XXX.md`; their results are in `data/research/xxx-reconstruction.json`. `Q` is this
checkout; `S` is the Prompt XXIX work directory (`$S/ms-bc/*.luac`: the 786 chunks the MoonSec V3 engine rebuilt, unchanged since XXIX,
from the git-ignored `local/terrorlua` collection). QuickSilver's own code runs in-process; the only third-party code run is the Luraph v15.2
research pipeline, once, inside `tools/isolate/run.sh`.

| Script | Measures |
|---|---|
| `msafter.mjs Q S batch\|behaviour` | the XXIX MoonSec tables again with the current decompiler and comparison (decompiles, parses, shared subtrees; the 120-file behaviour set with the adapter's own verify options) |
| `protos.mjs Q dir out.json` | per-function census: every function of every chunk decompiled on its own, failures grouped by reason with the smallest example |
| `snipcheck.mjs Q DQ name…` | a decompile snippet (or a .lua file) through a given source tree (`DQ`: current or XXIX), Lua 5.1/5.4, with and without debug information |
| `propmeasure.mjs Q DQ` | the property-test seeds of `tests/decompile-property.test.mjs` through a given source tree: identical / different / undecompiled |
| `waitbudget.mjs Q S name` | the 3fed8cb5 experiment: the original traced with one more wait than the rebuilt program |
| `prom-sum.py xxix.jsonl xxx.jsonl` | the integrated Prometheus run (`tools/engines/xxix/integ.mjs`), row by row against XXIX |
| `v152-traceback.sh repo work` | the Luraph v15.2 research lifter's own traceback, isolated |
