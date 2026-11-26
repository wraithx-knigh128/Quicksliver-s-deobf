# Prompt XXIX measurement scripts

The scripts behind the numbers in `docs/REPORT-XXIX.md`; their results are in `data/research/xxix-engines.json`. They were run from a
work directory `S` (with these scripts copied into it; the first argument of the shell scripts, `$S` / the second argument of the `.mjs` scripts) that holds the staged
tools (`$S/tools/moonsec`, `$S/tools/prometheus`, `$S/tools/unprom`: copies of the projects, never run outside
`tools/isolate/run.sh`), the pair list `$S/pm-pairs.tsv` (obfuscated fixture, original, set, preset) and the outputs. The MoonSec and
LuaObfuscator scripts read the git-ignored `local/terrorlua` collection. Every third-party tool run goes through `tools/isolate/run.sh`
(`run.sh` needs root and util-linux); QuickSilver's own code and its sandbox run in-process.

| Script | Measures |
|---|---|
| `ms-one.sh`, `ms-eval.mjs` | one MoonSec V3 file: isolated engine → bytecode → QuickSilver decompile → parses? |
| `ms-verify2.mjs`, `ms-diff2.mjs` | rebuilt program vs protected original in the sandbox; the differences, classified |
| `keys-batch.sh`, `strstat2.mjs` | keyed vs keyless builds; the string-constant statistics |
| `ms-kinds.mjs` | what the rebuilt programs call (executor-only APIs, HttpGet / loadstring) |
| `pm-batch.sh`, `pm-force.sh`, `up-batch.sh`, `tool-eval.mjs` | Prometheus-Deobfuscator-Fixed (as supplied, `--force`) and unprom on the 131 Prometheus fixtures |
| `gate.mjs` | would a comparison with the script accept the engine's good programs and reject its wrong ones |
| `integ.mjs`, `baseline.mjs` | the one Deobfuscate with the gated engines vs QuickSilver alone, scored against the right reference |
| `lo-one.sh`, `lo-eval.mjs`, `qs-eval.mjs` | LuaObfuscator-Deobfuscator and QuickSilver on the LuaObfuscator collection |
