# Prometheus — progress record (versions, configs, forks)

Prometheus is an open-source, pure-Lua obfuscator built from independent passes. Reconstruction is measured on committed, generated fixtures, so the
statuses cannot drift. Numbers are in `docs/MATRIX.md`; this record is the version/fork synthesis.

## Releases and forks covered

| Release | What it is | Fixtures |
|---|---|---|
| current | the mainline pipeline | `tests/corpus/obfuscated/prometheus` (7 samples × preset/step) |
| 2026-11 | the upstream rewrite: old `Vmify` renamed `Cff`, a new register-bytecode `Vmify` | `tests/corpus/obfuscated/prometheus-2026-11` (8 samples) |
| lennyobf | a public fork | `tests/corpus/obfuscated-local/prometheus-lennyobf` (8 samples, local) |

## Passes and presets

The strength of Prometheus is a *combination* of passes. Each pass is exercised alone (a `step-` fixture) and in the Weak/Medium/Strong presets:

| Pass / preset | Status | Runtime | Note |
|---|---|---|---|
| Minify, and single steps: EncryptStrings, ConstantArray, SplitStrings, NumbersToExpressions, ProxifyLocals, WrapInFunction, AddVararg, AntiTamper | verified | 7/7 each | each pass is fully undone and the result runs like the original |
| step-Vmify | partial | 6/6 judged | the VM is lifted; the gate is semantic form (loops, expressions), not a VM residual (Prompt XVIII) |
| Weak / Medium / Strong (current) | partial | 21/21 like the obfuscated program | Vmify fully lifted; 18/21 run like the original, the 3 s03 builds diverge inside Prometheus itself (a dropped truncating `( )`); generic `for` loops re-raised in Prompt XVIII except over `pairs` |
| Weak / Medium / Strong (2026-11) | partial | 8/8 | the rewrite's `Cff` + register `Vmify` are both lifted (`src/recover/vmify.js`, `src/recover/prometheus-bvm.js`); 8/8 run like the original |
| lennyobf presets | verified/partial | measured | same passes, separate source; measured on the fork's own fixtures |

## The eight metrics (summary)

| | non-VM passes | VM presets (current) | 2026-11 presets |
|---|---|---|---|
| 1 identification | ● | ● | ● |
| 2 version recognition | ● | ● | ● |
| 3 transformation stages | ● | ● | ● |
| 4 structural | ● | ● | ● |
| 5 instruction/handler | — (not a VM) | ● (Vmify lifted) | ● (both lifters) |
| 6 semantic | ● | ◐ | ● |
| 7 runtime | ● | ● | ● |
| 8 behavioural equivalence | ● | ● (equal to the obfuscated program; s03 diverges in the tool) | ● |

## What is genuinely reconstructed vs partially understood

- **Reconstructed:** every non-VM pass, alone and in presets; the 2026-11 rewrite's `Cff` and register-bytecode `Vmify` (both lifted, run-verified);
  the `lennyobf` fork's passes.
- **Partial (semantic form only):** the *current* mainline's Weak/Medium/Strong. Prompt XVIII re-checked them: the Vmify VM is fully lifted and every
  build prints what the obfuscated program prints; what keeps the semantic score below the gate is form — generic `for` loops over `pairs` stay
  `while` loops (a `not k` test also stops on a `false` key, so raising them needs a proof) and expressions are written differently.

## Next experiments (§V)

1. Raise the remaining `pairs` loops once a table can be shown to have no `false` key; close the remaining expression-form gap.
2. More layered combinations beyond Weak/Medium/Strong, as authorized fixtures allow.
3. Keep the committed scorecard as the regression guard so fork/preset changes cannot silently regress.

Implementation: `src/recover/prometheus.js`, `src/recover/vmify.js`, `src/recover/prometheus-bvm.js`, `src/passes/evaluate.js`. Tests:
`tests/xvi-prometheus-vm.test.mjs`, the per-step/preset fixtures, and the scorecard.
