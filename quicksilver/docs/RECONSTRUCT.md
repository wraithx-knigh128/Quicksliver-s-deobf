# Reconstruction: the engine inside the website

The **Reconstruct** tab runs a Luraph / IronBrew reconstruction engine on the server and shows what it produced, how it was produced, and how far that can be trusted.
The engine was supplied by the project owner as an archive and integrated at their request. This page says what is in it, how it is run, what was measured, and what is not known.

Code: `api/_engine/luraph/` (the vendored engine and `service.py`), `api/reconstruct.py` (HTTP), `src/reconstruct/` (catalogue, status gates, report, case file),
`src/app/reconstruct-view.js` (the tab), `tools/luraph/` (the registry builder), `api/assistant.js` (optional model). Data: `data/research/luraph-compat.json`,
`data/research/discoveries.json`. Tests: `tests/reconstruct.test.mjs`, `tests/assistant.test.mjs`, three browser tests at the end of `tests/e2e/ui.e2e.mjs`.

## 1. What the engine is

A **dynamic** deobfuscator: it runs the protected script in a Luau VM against a fake Roblox environment, with the protector's own VM closures instrumented, then lifts the
captured VM back into Luau (constants decoded on request, control flow restructured, names inferred from use). When lifting is refused or incomplete it falls back to a
**behaviour trace**: what the script did to the environment in one run, rendered as Luau. The two are different things, and the page labels which one you got.

| Engine | Front end | What the archive documents | Notes |
|---|---|---|---|
| `luraph_v15` | `deob.py` | Luraph v15 (banner, or the `return setmetatable({[n]=bit32.x,…` shape) | the reference plugin |
| `luraph_v14_7` / `_8` / `_9` | `cli.py` | Luraph v14.7 / v14.8 / v14.9 | **copies of the v15 engine** with small changes (`devirt.py` differs by 12 lines between them; `driver.py` by 12 and 85) |
| `ironbrew1` | `deob.py` | IronBrew 1 (header, or the VM shape) | |
| `generic` | `deob.py` | nothing | behaviour trace only |

The archive's own notes (`api/_engine/luraph/notes/`) describe the design at length (capture hooks, constant rounds, SCCP, structuring, the environment the keys depend on).
Its known limits, in its own words: VM compression is out of scope; scripts that fail the same way in real Studio are not environment problems; other Luraph versions "have not been tested".

## 2. How a request runs

1. **Identify** (`service.identify`): the banner in the first 4 KiB (a comment: it says what the file claims) and each engine's own detector. Nothing is executed.
2. **Choose** (`service.plan`, previewed by `src/reconstruct/engines.js` `plan()`; a test keeps the two in agreement): banner v14.7/8/9 → that engine; v14.x with no engine → the nearest engine,
   marked *nearest*; v15 → `luraph_v15`; IronBrew header or detector → `ironbrew1`; nothing recognised → a behaviour trace. You can force an engine.
3. **Run** each attempt in a **separate process** (`python -I deob.py|cli.py …`) with a wall clock, address-space/CPU/file-size limits (`resource.setrlimit`) and, where the host permits, no network
   namespace (`unshare -rn`). Fallbacks, in order: other v14 engines (labelled *nearest*), then a behaviour trace. The attempts and outcomes are listed in the result.
4. **Check**: syntax by Luau's own parser (`luau-ast`), and counts of what is visibly unresolved (free upvalues `upvN`, undecoded constants, `(nil)(` calls, Luraph runtime stubs, `LPH_CRASH()`).
5. **Verify** (only if you supplied the original): the original and the reconstruction run on the Luau runtime and their prints and return values are compared.
6. **Diagnose**: deterministic rules turn the engine log into named findings (`lift-failed`, `scaffolding-root`, `partial-lift`, `tamper-trap`, `env-api-missing`, `timeout`, `trace-only`, …) with a hint.

The service streams JSON lines (`stage`, `log`, `identification`, `plan`, `attempt`, `fallback`, then `result`), which the tab draws as the stages complete. On a host that buffers responses the lines arrive at the end instead.

### What the result may say

| Field | Meaning |
|---|---|
| `kind: devirtualized` | lifted from the VM |
| `kind: trace-assisted` | built from a behaviour trace after the lift was refused |
| `kind: trace` | a behaviour trace only; branches that did not run are absent |
| `verification.status: identical` | the original and the reconstruction printed and returned the same on Luau for this run. Not a proof of equivalence |
| `different` / `inconclusive` / `not-run` | a mismatch; nothing comparable (the original needs Roblox objects, prints nothing, or timed out); no original supplied |

**Readable output is never called verified.** Only `identical` against an original you supplied is called that, and only for scripts that run on plain Luau.

## 3. Compatibility: what has been measured

`node tools/luraph/verify.mjs` (`npm run luraph:verify`) runs the service three times on every fixture and writes `data/research/luraph-compat.json`: the fixture's SHA-256, which engine answered, the kind of
output, syntax, quality, the behaviour comparison, whether the three runs agree. **Statuses are not stored there**: `src/reconstruct/status.js` derives them from the records.

| Status | Rule |
|---|---|
| fully tested | ≥ 10 lifted runs (not traces) compared **identical** with their originals on Luau, none different (10 because the 95% lower bound of 9 of 9 is below 0.7) |
| partially tested | ≥ 1 such run identical, none different |
| experimental | the engine exists and ran, but no lifted run was compared with an original, or comparisons disagree |
| unsupported | no engine; or ≥ 3 inputs tried and none lifted |

A trace is never counted as a lift, an unverified lift is never counted as verified, and a neighbouring engine's success is not credited to the version it was not made for.

**Today's records** (Luau 0.739 built here, see §5):

| Version | Status | Evidence |
|---|---|---|
| Luraph v15.0 | **partially tested** | 1 fixture (the archive's 559-byte stack-machine program): lifted, compared identical with the original (returns 34) |
| IronBrew 1 | **partially tested** | the same program: lifted, identical |
| Luraph v14.7 | experimental | 1 fixture, no source: ends as a trace-assisted result (`print("hii!! luraph 14.7")`); not lifted, not verifiable |
| Luraph v14.8 | experimental | 1 fixture, no source: the engine lifts nothing; a behaviour trace is the best it gives |
| Luraph v14.9 | experimental | 1 fixture, no source: same; the trace stops on an API the emulated environment lacks |
| v13 and earlier, v14.0–14.6, v14.10+, v15.1+ | unsupported | no engine (the nearest is tried as an experiment and labelled so) |

Nothing is "fully tested". One program per engine is a start, not coverage.

**Not in the registry, on purpose:** the archive also carries ~2.5 MB of other people's protected scripts without sources. They were not redistributed and are not counted as evidence of anything.

### Adding a version or an engine

A version is a row in `src/reconstruct/engines.js` `VERSIONS`; an engine is a row in `ENGINES`, a row in `service.ENGINES`, and a plugin in `deobf/obfuscators/`. Add fixtures to `tools/luraph/fixtures.json` (with
their originals when you have them; protected scripts you do not own are not committed: put them in `local/luraph-fixtures/` and they are recorded by hash), run `npm run luraph:verify` then `npm run research`.
The status of the new row follows from the records, and the profile (`data/research/profiles.json`) and pipeline position follow from that.

## 4. What changed in the engine (and why it matters)

* **v15 root choice (verified, `data/research/discoveries.json` d-v15-root-choice).** The runtime picks the payload root from the statements the script emitted. A script that emits none leaves the last probe helper as the pick,
  so the archive's own regression sample produced Luraph's environment probes instead of the program. A script's main chunk has no upvalues; a root whose lift still names free upvalues is a probe or loader, so the other VM
  roots are tried and the first without free upvalues is used. The sample now reproduces the documented output and compares identical with its original.
* **The v14 engines** are v15 copies; their v14-specific parts (a probe-suite stripper, root candidates ranked from the trace, an allocation-fingerprint trap in v14.9) are untouched and did not make the v14.8/v14.9 fixtures lift.
* **Hypothesis refuted:** that the supplied stock Luau (frozen vector metatable) caused the v14.8/v14.9 failures. With the patched build the outcomes are the same.
* Removed: runtime download, the Studio bridge, advertising and joke text in outputs, and a `tidy.py` line that replaced a folded trace body with a joke string.

## 5. Dependencies, licences, security (audit)

See `api/_engine/luraph/NOTICE.md` for the full table. In short:

* **Licence: none found.** The archive has no licence file. It is vendored at the owner's direction; **confirm the right to redistribute before this repository or a deployment is made public.**
* **Binaries.** `luau` and `luau-ast` were **built here** from `luau-lang/luau` tag 0.739 (the first with the archive's one-line vector-metatable patch; static, portable). The archive's own `luau-ast` was replaced: its provenance
  could not be checked and it failed on Vercel's runtime. The same `luau` is the Luau reference runtime of the Phase V oracle (`tools/runtime/oracle.mjs`).
* **Executing untrusted scripts.** The engine runs the script. Mitigations: a separate process per attempt; wall clock, CPU, address-space and file-size limits; no network namespace where available; the Luau CLI has no `io`, `os.execute`
  or `os.getenv`; the output directory is a throwaway temp directory; the endpoint requires an attestation, is rate limited per client and per instance, caps input size and concurrency, and can be switched off or token-gated. On Vercel
  the host offers no `unshare`; the function sandbox and the limits above are what apply. Tests cover an endless loop (stopped at the limit), a memory bomb (stopped by the cap), and a script that tries to run a command (it cannot).
  This reduces risk; it is not a proof of isolation, and a flaw in the Luau VM or the harness is a flaw in the sandbox.
* **Static serving.** The engine lives under `api/_engine/`, which Vercel does not serve (verified: 404).

## 6. Running and configuring it

Locally: `npm run reconstruct:serve` (Python 3, the vendored binaries) serves `/api/reconstruct` on 8788; the browser tests start their own. On Vercel the Python function needs nothing but the repository
(`vercel.json`: 300 s, 2 GB, `api/_engine/**` included). `GET /api/reconstruct?check=1` measures the deployment: Python version, the Luau binary, isolation, and a self-test that lifts a bundled fixture.

| Variable | Default | Meaning |
|---|---|---|
| `QS_RECONSTRUCT_MODE` | `open` | `open` / `token` / `off` |
| `QS_RECONSTRUCT_TOKEN` | – | required in `x-reconstruct-token` when the mode is `token` |
| `QS_RECONSTRUCT_RPM` | 6 | requests per minute per client per instance |
| `QS_RECONSTRUCT_CONCURRENCY` | 2 | simultaneous jobs per instance |
| `QS_RECONSTRUCT_MAX_BYTES` / `_MAX_SECONDS` / `QS_ENGINE_MEM_MB` | 3 MiB / 240 s / 3072 | limits |
| `QS_LURAPH_BIN_DIR` | – | use binaries from this directory instead of the vendored ones |

**Limits that matter.** A serverless function has a time limit (set to 300 s; your plan may allow less). Large scripts take minutes in the archive's own timings; a script that does not finish is stopped and the answer says so.
For heavy use, run `api/reconstruct.py --serve` behind your own host and point the page at it.

## 7. The research assistant

Two layers, kept apart:

* **Always on, deterministic:** the diagnostics rules above. They read the engine log and name what happened. Not AI.
* **Optional, model-backed (`/api/assistant`):** reads a **case file** (what was identified, which engines ran and how, the engine log tail, the compatibility table; **never the script**) and returns *hypotheses*,
  *experiments*, *engine changes* and *comparisons*, all tagged `hypothesis`. Every hypothesis must quote the case file, and the quotes are checked against it; ungrounded ones are discarded and counted. It is switched off unless
  `QS_ASSISTANT_MODE` is `open` or `token` **and** `ANTHROPIC_API_KEY` is set (model `claude-opus-5-5`, override with `QS_RESEARCH_MODEL`); `QS_ASSISTANT_TOKEN`, `QS_ASSISTANT_RPM` as for the research endpoint.
  Like the research endpoint it has been tested against a local server that answers like the Messages API and **has not been run against the real API**.

Nothing it says is a finding. `data/research/discoveries.json` is the ledger: a `verified` entry needs a reproducing command and records in the registry; a `refuted` entry keeps the experiment that disproved it; a hypothesis cannot be the reason for a capability.

## 8. What this does not do

* No Luraph version is "fully tested", and v14.8 / v14.9 are not lifted. The engine's results on larger, real-world scripts are unmeasured here.
* "Identical" compares prints and return values on one runtime for scripts that run on plain Luau. A script that needs Roblox objects fails the same way in both and the result is *inconclusive*.
* The engine's environment emulation (Roblox API model, Path2D, Random) is what Luraph's keys depend on; where it diverges from Roblox the run diverges, and the result is a trace or nothing.
* Original names and comments are not recoverable; names are inferred from use.
* The reconstruction service executes scripts. It is guarded, not harmless.
