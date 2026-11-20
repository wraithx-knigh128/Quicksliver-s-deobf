# Prompts XXIV–XXVI: sample-collection audit, false success, and the Luraph case — engineering report

Sample collection: github.com/terrorlua/obfuscator-samples (43,288 files, 15 folders). It states no licence, so the files stay outside the
repository (local/terrorlua, git-ignored). Only measurements are committed (`data/research/samples-terrorlua.json`). Every number below was
measured in this round; the tool that measured it is named.

## 1. What was asked, and what was done

| Requirement | State |
|---|---|
| Inventory of every sample (label, version, structure, detection, compatibility) | **Done**, 43,288 files, before and after (`tools/samples/inventory.mjs`) |
| Recovery baseline on a stratified sample | **Done**, 334 files (4 per folder), before and after (`tools/samples/baseline.mjs`) |
| False-success investigation and fixes | **Done** for the cases below |
| Luraph case (Test 8): explain the failure, compare to the other tool | **Done** for the diagnosis; the reconstruction itself is **not done** |
| Static Luraph 14.x handler-table reader | **Not built** |
| LuaObfuscator VM: rebuild instructions to source | **Not built**; constants and listing only |
| Website integration and e2e re-run for this round | **Not done**; the site runs the same `recoverSource` pipeline, so the changes flow through, but the e2e suite was not re-run for them |
| Internet research beyond what earlier rounds recorded | **Not done** this round |

## 2. Inventory (43,288 files)

Detection and parsing, before → after (before = commit 3de654e, the code before Prompts XXIV–XXVI):

| | Before | After |
|---|---|---|
| Detected as some obfuscator | 86.2% | 99.7% |
| Detected family agrees with the folder label | 86.1% | 99.6% |
| Parses as Luau | 98.0% | 99.4% |

Per folder (after): 77fuscator, Hercules, IronBrew 2, Luraph, MoonSec, MoonVeil, Prometheus, PSU, wYnFuscate agree 99.5–100%.
Changed: Boronide/herrtt 0.2% → 100%; SynapseXen 0% → 100%; IronBrew 3 0% → 100%; LPS 3% → 100%; LuaObfuscator 80% → 99%.

Regression check (file by file): **0** files lost their detection; **0** stopped parsing; **9** changed family (8 Boronide files from a wrong
Prometheus guess to Boronide, 1 LPS v2 file from Luraph to LPS), all matching their folder labels. Three Prometheus/Strong files (33–50 MB)
time out in the inventory's 30-second limit both before and after.

Still not identified correctly: 85 Boronide scripts that exceed Luau's own nesting limit (Luau refuses them too: reported as invalid input);
a few parse failures in Luraph, Prometheus and LuaObfuscator folders (listed by `summarize.mjs`).

## 3. Recovery baseline (334 files, same pick before and after)

| Outcome | Before | After |
|---|---|---|
| partial | 175 | 47 |
| not-deobfuscated | 123 | 264 |
| syntax-valid-unverified | 27 | 20 |
| invalid-input | 7 | 1 |
| parses | 325 | 331 |
| crashes | 0 | 0 |
| timeouts | 2 | 2 |

**The shift is a stricter verdict, not better recovery.** 128 results moved from "partial" to "not-deobfuscated", 7 from "syntax-valid" to
"not-deobfuscated", 6 from "invalid input" to "not-deobfuscated" (those now parse). The cause is one rule: a virtual machine that no step
rebuilt holds the program as its data, so the output's protection is essentially all still present, and confidence is capped at minimal.
Affected families: Luraph static outputs (75, the VM is still in the output), herrtt/Boronide (16), MoonVeil 1.x (12), 77fuscator (9), Synapse
Xen (7), IronBrew 3 (6), LPS (6), Hercules (4), MoonSec (5).

Two things must be checked before trusting this shift:
- **77fuscator (9 files)** is classed by the structure probe, which found an interpreter dispatching 95 handlers in the output. That is a
  finding of the probe, not of a lifter, and nothing in the project has yet verified that 77fuscator is a VM.
- **Luraph static outputs** lost "partial" because their VM is still present. That is the honest reading, but it means the static pipeline's
  cleanup is not counted as progress by the verdict.

No recovered program grew in fidelity in this round. The measured gains are in detection, parsing and honesty of the verdict.

## 4. False successes and false classifications found and fixed

1. **Luraph v15.1 / v15.2 (13 files) and one v15.0 file were reported "ok, trace-assisted, clean".** The output was only Luraph's environment
   probe; the run had failed or observed nothing. Now `no_program_observed`. Cause: no check that a trace observed the program. Fixed in
   `api/_engine/luraph/service.py` (`trace_facts`). Test: `tests/xxiv-samples.test.mjs`.
2. **The v14 engines (14.7, 14.8, 14.9) hid their run status in their log**, so a failed run read as finished. The status is now read from the
   log, and the v14 probe is recognised. Test 8 (below) was reported "ok, clean" by all three before this.
3. **Output size decided the verdict.** A 759 KB Luraph VM output was "partial, medium 0.80" because the structure probe skipped outputs over
   600 KB. The VM rule now applies at any size (`src/recover/confidence.js`).
4. **A VM nothing rebuilt was graded partial.** Now capped at minimal ("not deobfuscated"), and labelled with the architecture where it is
   known: "Architecture identified (Boronide); source unresolved".
5. **Signatures without bodies and `(nil)[k]` holes** could be presented as code. An output whose functions are mostly signatures, or that
   holds missing constants, is held at "partial" (`src/validate/evidence.js`, `src/validate/outcome.js`).
6. **Detection gaps that gave false negatives**: Boronide/herrtt (4503 files), LuaObfuscator VM without its banner (1143), LuaObfuscator
   ChaoticGood with a custom message in its art (108 of 111), IronBrew 3 (17), LPS (30), Synapse Xen (88).
7. **Parser limits that rejected valid code**: the nesting limit was 200 (Lua 5.1's). Luau's is 1000, and 650 Boronide scripts parse under it.
   Luau also reads numbers such as `0_b11_01` (13) and `0_x1F` (31), which the lexer refused (13 LPS scripts).
8. **Padding obfuscation hid state machines**: `<comparison> or false` and `<comparison> and true` now fold to the comparison, and only when
   the left side is always boolean (`src/passes/fold.js`).

## 5. The Luraph case (Test 8) — diagnosis

The file: 880,753 bytes, a Luraph 14.x handler table (`return({ name = function ... }):D()(...)`), banner stripped. The version cannot be narrowed
further: the form appears under v14.4–v14.8 in the collection.

**What failed, exactly.** Our reconstruction ran the script inside an emulated Roblox and expected the VM to decrypt its program there. The
run stopped at Luraph's environment checks (a "buffer access out of bounds" in v14.7 and v14.8, "attempt to call a nil value" in v14.9), so
the program was never decrypted. The engine then emitted the environment probe as the "reconstruction", and its verdict said "readable",
which was a false success (fixed as item 1–2 above). The only functions recovered were 21 plain-Lua closures Luraph does not virtualise
(`tools/luraph/natives.mjs`), and those are fragments, not the program.

**The other tool's output (your comparison file).** It recovers the program's structure: UI, services, the 26 remote scripts it loads, 452
strings. It does not recover the constants (401 missing, written `(nil)[k]`, 273 distinct, the first being the window title), one function
body is encrypted, and it does not compile (Luau stops at line 7683). All 20 strings in our 21 fragments appear in it.

**What this shows.** The other tool reads the VM's instruction stream statically, without the run-time key. Only the constants need the key.
Our assumption that the whole program sat behind the run-time key was wrong for the instructions; that is the precise point where our
reconstruction stopped. The next step is a static reader of the 14.x handler table (decode the `LPH@` payload, read the handlers, rebuild
Lua 5.1 bytecode, and report each constant as recovered or missing). **That reader has not been written.**

## 6. What was built and where

- `src/recover/luaobf-vm.js` (new): LuaObfuscator VM reader. The script's own deserialiser runs in the sandbox; roles, dispatch tree (also
  when split over a state machine), fused handlers and single-path state machines are read; `readProgram` reports functions, instructions and
  constants. **No source is emitted** (the opcode-to-handler mapping is not proven for every build; about 1% of forms read an operand the
  instruction does not have). Step `luaobf.program` in the pipeline.
- `tools/samples/` (new): `collection.mjs` (walker), `inventory.mjs` (per-file measurements, resumable, worker pool with watchdog),
  `baseline.mjs` (stratified recovery), `summarize.mjs` (writes `data/research/samples-terrorlua.json`; no third-party text recorded).
- `tools/luraph/natives.mjs` (new): plain-Lua closures of a 14.x handler table, with upvalue boxes shown as `upvalueK`; labelled as a view.
- `src/detect/detect.js`, `families.js`: Boronide/herrtt, LuaObfuscator VM prelude and ChaoticGood art, IronBrew 3, LPS v1/v2, Synapse Xen,
  Luraph VM output.
- `src/core/parser.js` (nesting limit), `src/core/lexer.js` (Luau number prefixes), `src/passes/fold.js` (boolean padding).
- `src/recover/confidence.js`, `src/validate/evidence.js`, `src/validate/outcome.js`: VM caps, body and hole checks, architecture label.
- `src/recover/pipeline.js`: step `luaobf.program`.
- `api/_engine/luraph/service.py`: run status from the log, `attempt_budget`, v14 probe, `no_program_observed`.
- `tools/compat-notes.mjs`, `data/compat.json`, `data/research/*`: regenerated from measurements; the stale labelled-collection evaluation
  and format database were regenerated after the detector changes (commit 0df52de).
- Tests: `tests/xxiv-samples.test.mjs` (20 tests, several need the local samples and skip without them).
- `docs/KNOWN-ISSUES.md` 81–90 record what remains.

## 7. Remaining unsupported and open

- **Luraph 14.x handler-table VM**: no static reader; the dynamic engines fail with a wrong-key symptom. Next step: the static reader (§5).
- **Luraph v15.1 / v15.2**: 13 samples, no program observed. The divergence is not visible offline; comparison with Roblox Studio is needed.
- **LuaObfuscator VM**: constants and listing only; instructions not lifted. Next step: prove the mapping per build.
- **LPS v2**: Roblox's buffer decompression (Zstandard/LZ4) is not implemented, so the stage is identified only.
- **Boronide, IronBrew 3, LPS v1, PSU, MoonSec V3, Synapse Xen**: identified, not rebuilt; reported "not deobfuscated".
- **85 Boronide scripts**: invalid input (Luau refuses them).
- **Timeouts**: three Prometheus/Strong files (33–50 MB) in the inventory; two in the recovery baseline.
- **Verdict shift** (§3): 77fuscator needs a verified structure before its class is trusted.

## 8. Tests

- Last full run before the derived-data regeneration: 1206 tests, 2 failing (`format-db`, labelled-collection), both caused by stale generated
  data; regenerated in commit 0df52de; both files now pass (33 of 33).
- Full clean run on the current code (commit c339755): **1206 tests, 1200 pass, 0 fail, 6 skipped** (the skips need the local sample collection). Duration about 14 minutes.

## 9. Commits (this round)

1ee503c (XXIV part 1) · 3a4078d (Test 8: v14 status, natives tool) · bde3a23 (XXV part 1: LuaObfuscator reader, IronBrew 3 / LPS, fold) ·
c22b9f8 (Synapse Xen, Luau numbers) · 0ad7bbf (ChaoticGood) · e5c8893 (re-measured records) · e274c26 (XXVI: verdicts, Test 8 regression) ·
0df52de (regenerated derived data)

## 10. Honesty notes

- No percentage of universal recovery is claimed. The verdict shift in §3 is a stricter definition, not a loss of recovered code.
- The 21 recovered Luraph functions are fragments of the program, not the program.
- The LuaObfuscator listing is a reading aid; nothing in it is emitted as source.
- The other tool's output is a comparison reference, used only to diagnose our failure; its output was not treated as correct.
