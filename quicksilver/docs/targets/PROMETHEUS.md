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
| step-Vmify | partial | 6/6 judged | the VM interpreter is the residual |
| Weak / Medium / Strong (current) | partial | 6/6 judged | these layer Vmify on the other passes; the judged subset runs like the original |
| Weak / Medium / Strong (2026-11) | partial | 8/8 | the rewrite's `Cff` + register `Vmify` are both lifted (`src/recover/vmify.js`, `src/recover/prometheus-bvm.js`); 8/8 run like the original |
| lennyobf presets | verified/partial | measured | same passes, separate source; measured on the fork's own fixtures |

## The eight metrics (summary)

| | non-VM passes | VM presets (current) | 2026-11 presets |
|---|---|---|---|
| 1 identification | ● | ● | ● |
| 2 version recognition | ● | ● | ● |
| 3 transformation stages | ● | ● | ● |
| 4 structural | ● | ● | ● |
| 5 instruction/handler | — (not a VM) | ◐ (Vmify residual) | ● (both lifters) |
| 6 semantic | ● | ◐ | ● |
| 7 runtime | ● | ● | ● |
| 8 behavioural equivalence | ● | ◐ | ● |

## What is genuinely reconstructed vs partially understood

- **Reconstructed:** every non-VM pass, alone and in presets; the 2026-11 rewrite's `Cff` and register-bytecode `Vmify` (both lifted, run-verified);
  the `lennyobf` fork's passes.
- **Partial:** the *current* mainline's `Vmify` VM in the Weak/Medium/Strong presets — the program runs like the original on the judged subset, but
  the VM interpreter is the residual rather than fully source-reconstructed. (The newer 2026-11 Vmify, which is a different design, *is* fully lifted.)

## Next experiments (§V)

1. Bring the current mainline `Vmify` presets up to the 2026-11 result (apply the register-VM lifter path where the mainline VM matches it).
2. More layered combinations beyond Weak/Medium/Strong, as authorized fixtures allow.
3. Keep the committed scorecard as the regression guard so fork/preset changes cannot silently regress.

Implementation: `src/recover/prometheus.js`, `src/recover/vmify.js`, `src/recover/prometheus-bvm.js`, `src/passes/evaluate.js`. Tests:
`tests/xvi-prometheus-vm.test.mjs`, the per-step/preset fixtures, and the scorecard.
