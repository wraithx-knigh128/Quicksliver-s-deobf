# Prompt XXII: Luraph 15.1 / 15.2, LuaQ and Volt — compatibility report

Every number below was measured in this round, and its source is named. No original source code was invented, and no percentage was
estimated. Where something could not be measured, this report says so and gives the reason. The work is in the commits on
`ccr-17f6469c-lf3p64` after `a5ade6d`.

## 1. Summary

| Target | Identity / version established | Detection | Recovery | Result class reported |
|---|---|---|---|---|
| **Luraph v15.0** | yes (banner; vendor SDK history) | banner → `luraph-15.0` row | dynamic engine lifts to Lua: 8 of 8 local scripts give Lua that parses (2 of them only after defect L1 was fixed) | **syntax-valid, behaviourally unverified** (no originals); the one reference pair is identical |
| **Luraph v15.1** | **exists** (vendor SDK update, 2026-10-03) | banner → its own `luraph-15.1` row | no sample available; the nearest engine (v15.0) is tried as an experiment | **detected but unsupported** (nearest engine named) |
| **Luraph v15.2** | **not confirmed**: no source shows it | banner → `luraph-15.2` row | nothing is inherited from 15.1 | **version uncertain** |
| **LuaQ** | v2.7 only; the latest version cannot be established | banner; version marked verified only for 2.7 | outer layers decoded (606,561-byte VM runtime, 202 handlers) | **payload unavailable**: the program is delivered from outside the file |
| **Volt (Voltfuscator)** | **8.1** (vendor repository, 2026-11-17) | banner, marker global, header comments, method table | constant pool 111/111 on both presets, checksum-verified; behaviour equal on real Luau; VM not lifted | **received, not deobfuscated** |

No target is reported as "fully reconstructed and behaviourally validated" in this round. Only the Luraph v15.0 reference pair that came
with the engine (`001_vm_like_dispatch`, verified in Prompt VI) reached that class, and it is not new evidence.

## 2. Phase I — research and version verification

Each finding is labelled **verified**, meaning a primary source was read, or **unverified**, meaning only secondary sources or an inference.

### Luraph

- **Verified:** the vendor's macro SDK (`github.com/Luraph/macrosdk`). Its commit history shows:
  - the v15 update on 2026-08-10;
  - the **v15.1** update on 2026-10-03, adding `LPH_ASSUME` and `LPH_OPAQUE`;
  - an `UNSAFE_ENVIRONMENT` fix on 2026-10-06.

  Nothing later was there when it was checked on 2026-11-20.
- **Secondary:** third-party version trackers name v15.1 (2026-10-16) at most.
- **Unverified:** whether v15.2 exists. No source shows it. A file that claims 15.2 is therefore reported as version-uncertain, never as 15.1.
- **Not verified:** what v15.1 changed inside the VM. The SDK shows only the macro surface.

### LuaQ

- **Verified:** v2.7, from the banner of the one user-supplied sample, decoded in Prompts XVI and XVII (`docs/targets/LUAQ.md`).
- **Not established:** the latest version. The vendor site was not reachable from the build environment. Under the standing restriction,
  LuaQ's delivery mechanism was not examined and the program was not retrieved.

### Volt

- **Identity verified:** "Volt" is **Voltfuscator** by Voltils, a hosted and closed obfuscation service. No other Lua obfuscator named Volt was found.
- **Version:** 8.1, verified from the vendor repository README and the banner of its examples (`github.com/usernamethisorthat/Voltils-Voltfuscator`,
  commit `9c7ae5c3`, 2026-11-17). An older search result said v7.5; the repository supersedes it.
- **Repository contents:** documentation and a paired example (the source plus its Normal and Ultra outputs). It does not contain the obfuscator.

Full report: `docs/targets/VOLT.md`.

## 3. Phase V — samples used and their provenance

| Sample | Source | Permission basis | Where kept |
|---|---|---|---|
| Volt 8.1 `example.source.lua`, `example-Normal.lua`, `example-Ultra.lua` | the vendor's own published example | published by the vendor for demonstration; no licence stated, so not redistributed | `local/volt/` (git-ignored, with `PROVENANCE.md`) |
| Luraph v15.0, 8 scripts | public collections (Prompt XV) | read and run in isolation only; no originals | git-ignored corpus |
| Luraph v15.0 reference pair | supplied with the engine | in the engine's fixtures | `api/_engine/luraph/fixtures` |
| LuaQ v2.7, 1 script | supplied by the user | user-authorised | `local/luaq/` (git-ignored) |
| Luraph v15.1 / v15.2 | **none found** | — | — |

Random scripts found online were not used as test material for v15.1 or v15.2. Neither Luraph nor LuaQ output can be generated here without a
licence, so no new samples could be produced.

## 4. Experiments (ten steps per sample, condensed)

For each sample the steps were:

1. identify;
2. read the version;
3. decode the layers;
4. reconstruct;
5. check the syntax;
6. run the input;
7. run the output;
8. compare the two runs;
9. classify;
10. record.

Steps 6 to 8 ran on real Luau 0.739 through the Lua oracle, or in the engine's sandbox. Nothing was run on the host.

### Volt 8.1 (`tests/xxii-volt.test.mjs`)

| | Normal | Ultra |
|---|---|---|
| Constants decoded / keys | 111 / 111 | 111 / 111 |
| Decoded under key state `Fq` = 0 / 60779 | 31 / 80 | measured, two states |
| Call sites replaced with text | 563 | 416 |
| Output parses | yes | yes |
| Input on Luau with the executor stand-in | `Voltfuscator example passed` | same |
| Output on Luau with the executor stand-in | identical | identical |
| Tampered data field | fewer decodes, none invented | — |
| Class | not deobfuscated (VM present) | same |

The original also prints `Running the source preview`. That line is guarded by `if not VLT_OBFUSCATED`, so its absence from the protected
build is by design.

### Luraph v15.0 (8 scripts, through the engine service)

| Script | Result | Lines | Seconds | Observable strings found in a behaviour trace |
|---|---|---|---|---|
| 029e88ac | devirtualised | 1 | 10 | 1 / 1 |
| 175af012 | devirtualised | 23 | 14 | 2 / 4 |
| 28aaf8a3 | **no output** at the old budget; 1490 lines after the L1 fix | 1490 | 204 | — |
| 5f4bbfd4 | trace-assisted | 246 | 2 | 33 / 33 |
| 7412d055 | devirtualised | 83 | 24 | 0 / 0 |
| c8daf1c5 | devirtualised | 170 | 5 | 4 / 14 |
| fe09a66a | **no output** at the old budget; 109 lines after the L1 fix | 109 | 132 | — |
| fef2cdee | devirtualised | 2048 | 25 | 21 / 40 |

All outputs parse. None of the scripts has an original, so none is behaviourally validated: the class is "syntax-valid, behaviourally
unverified". The trace column shows only partial corroboration. Where fewer strings are found than exist, the reason is either that the
traced run did not reach them, or that the lift is incomplete. These data cannot tell the two apart.

### LuaQ v2.7

The outer layers decode as before, and the program is not in the file. The class changed from **partial** to **payload unavailable** (see L3 below).

## 5. Phase VII — defects found and fixed

Each defect has a root cause and a regression test.

| # | Defect | Root cause | Fix | Test |
|---|---|---|---|---|
| L1 | Two v15.0 scripts produced no output at all | Every engine attempt was capped at 120 s, even when the job allowed 240 s, so large lifts were cut off and the hint to request a longer limit could not help | `attempt_budget()` in `api/_engine/luraph/service.py`: an attempt may use the job's remaining time, less a reserve for a following fallback step | `tests/xxii-versions.test.mjs` (engine service) |
| L2 | A v15.2 banner would have been treated as 15.1 | `generationForVersion` mapped every 15.x with x ≥ 1 to the v15.1 profile, and the version table had one row for "15.1 and later" | separate `luraph-15.1` and `luraph-15.2` rows; 15.2 and later are `uncertain` → status `version-uncertain`; no profile is inherited | `tests/xxii-versions.test.mjs` |
| L3 | LuaQ was classed **partial** although its program is not in the file | The outcome classifier knew only remote loaders as "the code is elsewhere" | the LuaQ step records `programInFile: false`, and `remoteEvidence` turns that into "payload unavailable" with the reason | `tests/xxii-versions.test.mjs` (local sample) |
| L4 | Volt output was not detected at all | no rules existed | detection rules (banner 0.97 with version, marker global, integrity codes, method table) and a family entry | `tests/xxii-volt.test.mjs` |
| L5 | Behaviour tests that use the Lua oracle hung when run together | each test stopped the shared oracle, so the next test received empty output | the oracle is stopped once, in an `after()` hook | `tests/xxii-volt.test.mjs` |

No validation check was weakened. The coverage gate (`MIN_COVERAGE`), the remote-evidence rules and the profile basis rules are unchanged.
For Volt and LuaQ, the profiles use basis "signature", because those tools are closed and could not be run here.

## 6. Phase VIII and IX — what was integrated, and where the site uses it

| Module | Where | Used by |
|---|---|---|
| Volt detection and version | `src/detect/detect.js`, `src/detect/families.js` | the Deobfuscator's identification panel, `/api` detection, `data/compat.json` (shown in the compatibility list) |
| Volt constant decoder | `src/recover/volt.js`; pipeline step `volt.constants` | every recovery of a Volt file, in the page and the API, when sandboxed evaluation is on (the step shows "skipped" when it is off) |
| Luraph version rows | `src/reconstruct/engines.js`, `src/reconstruct/status.js` | the Reconstruct tab's version table, which shows the "Version uncertain" badge from `src/app/reconstruct-view.js`, and the engine plan |
| Version-aware profiles | `src/research/identify.js` | identification and version estimate |
| Outcome class for LuaQ | `src/validate/evidence.js`, `src/validate/outcome.js` | the outcome shown with every recovery |
| Engine time budget | `api/_engine/luraph/service.py` | the Reconstruct service jobs |

## 7. Phase X — the strict test suite

New tests:

- `tests/xxii-volt.test.mjs` (6 tests);
- `tests/xxii-versions.test.mjs` (5 tests).

The tests that need git-ignored samples skip with the reason when the samples are absent. The full `npm test` and the end-to-end site tests
were run sequentially; their results are recorded in the commit that adds this report.

The result classes asked for in the prompt map onto the engine's outcome classes:

| Prompt XXII class | Engine outcome |
|---|---|
| Fully reconstructed and behaviourally validated | `validated` |
| Syntax-valid but behaviourally unverified | `syntax-valid-unverified` |
| Partially reconstructed | `partial` |
| Detected but unsupported | `not-deobfuscated` / registry `unsupported` |
| Version uncertain | registry `version-uncertain` |
| Invalid input | `invalid-input` |
| Insufficient evidence | `payload-unavailable`, `authorization-unavailable` (the evidence needed is not in the file) |

## 8. Phase XI — what remains, and what would resolve it

These are also entries 81–85 in `docs/KNOWN-ISSUES.md`.

| Target | Remaining stage | What would resolve it |
|---|---|---|
| Volt 8.1 | The handler table (156 keys), the instruction encoding and the 772-byte second block; then a lifter | a second program protected with the same build, to separate per-build randomisation from the format |
| Luraph v15.0 | behavioural validation of lifts | v15.0 outputs of known programs |
| Luraph v15.1 | any measurement at all | one v15.1 output of a known program (owner-supplied, or generated under a licence) |
| Luraph v15.2 | confirmation that it exists | a vendor release note or SDK commit |
| LuaQ | the latest version | a second, owner-supplied sample |

Universal recovery is **not** claimed for any of the four targets.
