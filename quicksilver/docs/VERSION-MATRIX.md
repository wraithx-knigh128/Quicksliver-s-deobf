# Version-wide research matrix — MoonVeil, IronBrew, Prometheus, LuaQ

The Prompt XVII deliverable: a version-by-version view of the four primary targets against the eight metrics of §IX, so that support for one
release is never read as support for a whole family. The per-fixture numbers behind each row are generated into `docs/MATRIX.md` by
`node tools/formats/build-matrix.mjs`; this file is the synthesis and the version-difference notes. The per-target detail is in
`docs/targets/` (LUAQ.md, MOONVEIL-2.1.0.md) and `docs/KNOWN-ISSUES.md`.

The eight metrics (§IX):

1. identification · 2. version recognition · 3. transformation-stage understanding · 4. structural reconstruction · 5. instruction/handler recovery
· 6. semantic reconstruction · 7. runtime execution · 8. behavioural equivalence

Legend: **●** done / verified · **◐** partial · **○** not reached · **—** not applicable to this target. "n/a" for metrics 7–8 means there is no
original program to run or compare against (a read third-party script, or a server-delivered program).

---

## MoonVeil

Closed and hosted; no builds can be generated. Evidence is public third-party scripts, read (not stored); where a hand reconstruction of a script
exists it is used as the comparison. Versions are the banner the script carries.

| Version | 1 id | 2 ver | 3 stages | 4 struct | 5 instr/handler | 6 semantic | 7 runtime | 8 behav | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1.4.5 | ● | ● | ◐ | ○ | — (not a VM) | ○ | n/a | n/a | flattened dispatchers + a large blob remain (KNOWN-ISSUES 19) |
| 2.0.26 | ● | ● | ● | ◐ | — (table of factories) | ◐ | n/a | n/a | joined from a factory table; names lost, register temporaries remain (34% vs a hand reconstruction) |
| 2.1.0 | ● | ● | ● | ● | ● | ● | ● (sandbox) | ◐ | **rebuilt from its handlers** (Prompt XVI): both samples run in the sandbox like the originals and match the independent hand reconstruction; only two builds of one program exist |

**Version differences.** 1.4.5 is control-flow flattening over a blob. 2.0.25/2.0.26 move to a *table of factories* that build each other (no
bytecode); the bootstrap permutation and cell layout differ between 2.0.25 and 2.0.26. 2.1.0 returns to a *bytecode VM* with a per-build function
reader (marker byte, section order, operand layouts all per build) and a 26-handler interpreter whose fusion, operand slots, argument/result order
and cell layout are all permuted per build — which is why 2.1.0 needed the per-instruction partial-evaluation approach rather than package decoding.
Central open objective (§III): handler/instruction understanding for the earlier, non-2.1.0 shapes and for 2.1.0 handler kinds outside the two
samples.

## IronBrew

| Version / family | 1 id | 2 ver | 3 stages | 4 struct | 5 instr/handler | 6 semantic | 7 runtime | 8 behav | Notes |
|---|---|---|---|---|---|---|---|---|---|
| IronBrew 2 — default, plain, mutate, super, lineinfo, nocompress | ● | ● | ● | ● | ● | ● | ● | ● | rebuilt from the VM data; 8/8 run like the original |
| IronBrew 2 — flow | ● | ● | ● | ● | ● | ● | ● | ● | control-flow variant; the judged subset runs like the original |
| IronBrew 2 — strings | ● | ● | ● | ● | ● | ◐ | ● | ◐ | string-encryption variant: a residual noted in KNOWN-ISSUES |
| IronBrikked (LuaXen) — ironbrikked, both | ● | ● | ● | ◐ | ◐ | ◐ | n/a (Luau, no oracle pairs) | ◐ | lifted as the compiler emits it; the compiler's own defects are read back, so it follows the compiled program, not always the original (KNOWN-ISSUES 28, 57) |

**Version differences.** "IronBrew 2" is the open-source VM with eight build options (compression, string encryption, control-flow mutation,
super-operators, line info). IronBrikked is LuaXen's IronBrew-derived backend: a different compiler whose register allocation and lowering have
their own faults, so a structurally correct lift can still differ from the original source — the reason metric 8 is only ◐ there. §IV's objective:
distinguish compiler defects from engine defects with authorized reference programs (done for the controlled `luaxen-subset`; the shipped fixtures
sit outside it).

## Prometheus

| Version | Configs | 1 id | 2 ver | 3 stages | 4 struct | 5 instr/handler | 6 semantic | 7 runtime | 8 behav | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| current | Minify, and each single step (EncryptStrings, ConstantArray, SplitStrings, NumbersToExpressions, ProxifyLocals, WrapInFunction, AddVararg, AntiTamper) | ● | ● | ● | ● | ● (non-VM) | ● | ● | ● | per-step fixtures all run like the original |
| current | Weak, Medium, Strong | ● | ● | ● | ● | ◐ (Vmify) | ◐ | ● | ◐ | the Vmify interpreter is the residual; 6/6 of the judged subset run like the original |
| 2026-11 | Weak, Medium, Strong | ● | ● | ● | ● | ● | ● | ● | ● | the upstream rewrite (old Vmify → `Cff`; new `Vmify` = a register bytecode VM); 8/8 run like the original (Prompt XV) |
| lennyobf (fork) | Minify, Weak, Medium, Strong, per-step | ● | ● | ● | ● | ◐ | ◐ | ● | ◐ | a public fork; same passes, measured on local fixtures |

**Version differences.** Prometheus's pipeline is a set of independent passes; "current" exercises each pass alone and in the Weak/Medium/Strong
presets. The **2026-11** upstream renamed the old `Vmify` to `Cff` and added a new register-bytecode `Vmify`; both are handled (two lifters:
`vmify.js` for Cff, `prometheus-bvm.js` for the register VM). The **lennyobf** fork keeps the passes but is built from a separate source; it is
measured on its own local fixtures. §V's objective: layered combinations and fork differences — covered by the per-step and preset fixtures;
regressions guarded by the committed scorecard.

## LuaQ

| Version | 1 id | 2 ver | 3 stages | 4 struct | 5 instr/handler | 6 semantic | 7 runtime | 8 behav | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 2.7 | ● | ● | ● | ◐ (container exact; VM program read, not rebuilt) | ◐ (architecture characterised; 202 fused handlers not individually lifted) | ○ | n/a | n/a | the user program is delivered at run time from LuaQ's server or an in-game seal, so it is not in the file (docs/targets/LUAQ.md) |

**Version differences.** Only v2.7 has been seen. The architecture is a four-layer design (base-93 / LQZ1 / DEFLATE → a 606 kB Luau VM runtime →
an encrypted loader program → the server/seal-delivered user program). Going further needs a second authorized sample of a known source to map the
202 handlers differentially; that is the recorded next experiment (§II, §VI).

---

## How to read this against "complete support"

A row is only **●** across metrics 7–8 when the rebuilt program was actually run and matched the original (or the tool's own build where the tool
itself diverges). Where metrics 7–8 are **n/a**, there is no in-file original to compare against, and the result is reported partial — never
"recovered". This is the distinction §IX and §X ask for: passing through the pipeline is not support; running like the original is.
