# Prompt XXI — Luarmor API reconstruction and zero false success: report

The standard asked for is engineering evidence. Every number below was measured in this round, and its source file is named. The work is in
the commits on `ccr-17f6469c-lf3p64` after `ad22abd`.

## 1. What was found about the Luarmor loader architecture

Sources: the corpus loaders, read as text and never run; Luarmor's documentation, re-verified in this round (see §2);
`docs/targets/LUARMOR.md`.

Luarmor is a licensing service. **The protected script is never in the loader.**

1. The owner uploads a script through the API or the dashboard.
2. Users run a one-line loader: `script_key = …`, then `loadstring(game:HttpGet(".../files/v3|v4/loaders/<id>.lua"))()`.
3. Alternatively, a bootstrap caches the service's client runtime, or an SDK library calls `check_key` and `load_script`.
4. The service delivers the script to its own client after a key and device check.

**What the loader file contains:**

| Content | Status |
|---|---|
| The loader's own logic (cache, key flow, status handling, UI) | Recovered in full. When the logic is itself obfuscated, it goes through the Deobfuscator. |
| The bootstrap data table | Opaque. Its only consumer is the service's runtime, which was neither fetched nor analysed, on purpose. |
| The delivered script | Absent. |

The prompt also asks how the loader executes the retrieved content and how API communication works. **Only what the documentation and the
loader text show is described.** The client runtime that performs the delivery is the service's protection mechanism, and it was not examined.

## 2. Which retrieval methods are officially supported

Re-verified in this round:

- `docs.luarmor.net` (through search; the host does not resolve from this environment);
- the documentation repository `github.com/Stefanuk12/luarmor` and its `openapi.json` (third-party, so treated as a lead and corroborated);
- the README of a deploy action.

| Interface | What it does | Returns a script's contents? |
|---|---|---|
| `GET /v3/keys/{api_key}/details` | the owner's projects, and their scripts as metadata (id, name, version) | **no** |
| `GET /v3/keys/{api_key}/stats`, `GET /status` | statistics, service status | no |
| users and keys (`/v3/projects/{id}/users`, plus resethwid, linkdiscord, blacklist, unban) | key management | no |
| `PUT /v3/projects/{id}/scripts/{script_id}` (+ `…/progress/{track_id}`) | **uploads** a new version | no: the upload direction only |
| third-party key-check API | checks a key for an approved platform | no |
| `/files/v3|v4/loaders/…` | the service's delivery route to its own client, after a key and device check | not an owner interface; **not called** by this project |

Conditions that apply to the whole HTTP API:

- it answers only from **owner-whitelisted IP addresses** (anything else gets 403);
- about 60 requests a minute (over the limit, 429);
- errors are JSON `{success, message}`;
- an upload may additionally require a Cloudflare Turnstile token.

The documentation also states: "Luarmor does not store your source code by default".

**Conclusion.** No officially supported interface returns the protected payload. The only authorised sources of that script are its owner, who
holds it, and an owner-side **metadata** check.

## 3. Which source components can be recovered

| Component | Recoverable | How |
|---|---|---|
| The loader's own code | yes | `src/loader/luarmor.js` (since Prompt XX) |
| Whether the loader's script belongs to the key owner | yes, with the owner's key, from a whitelisted IP | new owner check: provider `luarmor`, metadata only |
| The protected script | **only when its owner supplies it** | new owner-supplied route: the same validated chain as a retrieved payload |
| The bootstrap data table, the service's runtime | no (on purpose) | — |

## 4. The defects found and corrected

Each defect was reproduced first, its root cause identified, then fixed, and it has a regression test.

| # | Defect (root cause) | Fix | Regression test |
|---|---|---|---|
| D1 | **A non-code or truncated payload was passed to the deobfuscator as "retrieved code".** The payload stage forwarded any text that failed to parse. | Payload validation in `processPayload` (`src/loader/intel.js`). Lua text that is cut off is classed `invalid-input`. A message ("Key required…", "Bad API request") is `payload-unavailable`. Neither reaches the pipeline. | `tests/xix-loader-intel.test.mjs` (cases truncated-lua, key-required-text), `tests/xxi-outcome.test.mjs` |
| D2–D4 | **A high confidence was the only measure of success.** The deobfuscator's static estimate rated four VM lifts "high" although they behave differently (Obscura 1.0.1 vm s04/s06; lennyobf s08 Medium/Strong), and nothing turned "high" into "validated" or "partial" by evidence. | One outcome classifier (`src/validate/outcome.js`, eight classes with written criteria). Every recovery carries its class. "Validated" needs a behaviour comparison. | `tests/xxi-outcome.test.mjs`; corpus measurement §7 |
| D5 | **Loader Intelligence counted "Reconstructed" from the confidence alone.** It had no syntax check of the output and no behaviour check. | Each stage gets its class from evidence. Behaviour validation (`verify`) is part of the chain, with consent asked in the same dialog. | `tests/xix-loader-intel.test.mjs`, e2e |
| D7 | **A Luarmor loader dead-ended**, with no authorised path for the owner's own payload. | "Supply the payload" runs the owner's file through the whole chain. "Check ownership" uses the documented details endpoint with the owner's key. | `tests/xxi-outcome.test.mjs`, `tests/xxi-fetcher.test.mjs`, e2e |
| D8 | **A transfer that ended early was accepted as a complete, smaller file.** The body length was never compared with `Content-Length`. | Both transports (`safeGet`, `providerRequest`) reject a short unencoded body. | `tests/xxi-fetcher.test.mjs`, intel case short-transfer |
| D9 | **An upstream 401/403 was reported as 502**, so an authorisation failure looked like an unavailable service. | `/api/fetch` keeps 401/403 as 403 and names it. Loader Intelligence then classes it `authorization-unavailable`. | `tests/xxi-fetcher.test.mjs`, intel case auth-failure |
| D10 | **A numbered Roblox asset with no Open Cloud key was reported as unretrievable.** In fact it has a documented owner route; only the key is missing. | Route `owner` with the reason (`src/loader/analyze.js`), so the class is `authorization-unavailable`. | intel case owner-provider-not-configured |
| D11 | **The deobfuscator ran a call twice.** `undoProxifyLocals` copied a stored call expression into the proxy's declaration while the table that held it stayed in place. Found by the behaviour check on lennyobf. | Effect-free values are copied; anything else is read from the table (`t.K`). | `tests/xxi-outcome.test.mjs` (D11) |
| D12 | **Correctly repaired inputs were classed as invalid.** The new input check called inputs "invalid" that the pipeline repairs in a documented way (Hercules 1.6 renamed keyword, Zartha line breaks). Found by the corpus measurement in this round. | A recorded repair step makes the input "repaired", not invalid, and the result says so. | corpus measurement |
| D13 | **A gzip stream with a failed checksum was reported as "not code"** (and, in the first draft of the classifier, as an unsupported format). It is a cut-off transfer. | Such a stream is now `corrupt`, classed as `invalid-input` (cut off). | intel case truncated-gzip |
| — | **On a phone-width screen, the Luarmor operations table and long loader addresses were wider than the screen.** | They scroll or wrap. | checked at 390 px |

## 5. The connected workflow

**Loader input → loader analysis → authorisation check → supported retrieval → payload validation → obfuscator detection → deobfuscation →
syntax validation → behavioural validation → Lua output.**

- **Shared code.** Retrieved payloads and owner-supplied ones go through the same code path (`processPayload`). The Deobfuscator tab uses the
  same classifier.
- **Every stage records its result.** The page shows the chain per stage: done (✓), failed (✗), or not reached (–), with the reason. A stage
  that fails decides the result; nothing invalid, empty, truncated or wrongly decoded is passed on.
- **Outcome classes.** The eight classes the prompt lists, each with a written criterion in `CRITERIA`:
  - validated;
  - syntax-valid but unverified;
  - partial;
  - retrieved but not deobfuscated;
  - payload unavailable;
  - authorisation unavailable;
  - unsupported format;
  - invalid input.

  Only one of them counts as success.

## 6. Website

- **Deobfuscator tab.** An outcome badge in the status strip. An "Outcome" section listing the criteria met (✓) and what is missing (✗), with
  **Compare behaviour…** whenever a result is still unverified. The engine's confidence is still shown, but it is labelled as an estimate and
  never decides the result.
- **Loader tab (Loader Intelligence).** The metrics read validated / unverified-or-partial / not recovered. The outcome column carries the class,
  its reasons, and the step-by-step chain. A checkbox for behaviour validation sits in the existing confirmation dialog.
- **Loader tab (Luarmor section).** The owner route: **Supply the payload…**, and **Check ownership** when the owner's key is configured. A card
  shows the SHA-256, class, chain and result for the supplied payload. The operations table points at both routes.
- **Layout.** Checked at 1440 and 390 px: no element wider than the screen, no console errors.

## 7. Measured results

### API fetcher

`tests/xxi-fetcher.test.mjs` (9 tests) and `tests/xix-retrieve.test.mjs` (6 tests): **all pass**. Upstream services are mocks; no network is
used. They cover:

- short transfers in both transports, and the content-encoding exception;
- upstream 401/403/404/500 mapping;
- the Luarmor owner check: owned and not owned; the documented 403 (IP whitelist) and 400 (invalid key); `success:false`; a non-JSON answer;
  the key never echoed; no personal data returned; input validated before any request; not configured without the key; nothing under
  `/files/` ever requested.

### Loader → payload → reconstruction integration

`tests/xix-loader-intel.test.mjs`: **27 of 27 pass.** There are 26 fixture cases, run through the real `/api/fetch` and `/api/retrieve`
handlers in front of a mock service, plus one test that checks the fixture set covers every category. Each stage must reach the transport outcome and the **outcome class**
decided for it in advance. **Classification accuracy: 26 / 26.**

In the first run 3 cases disagreed. Two were fixed in the code (D9, D10). One was my own expectation, corrected: a model whose only script
does nothing observable cannot be validated.

Coverage of the twelve scenarios in Prompt XXI §7:

| # | Scenario | Covered by |
|---|---|---|
| 1 | Valid authorised Luarmor loader | intel case `luarmor`; `tests/xx-luarmor.test.mjs`; e2e (Luarmor) |
| 2 | Locally embedded content | Luarmor local logic (`xx-luarmor`); case-1 loaders (`tests/xviii-loader.test.mjs`) |
| 3 | Remote payload | `public-ironbrew2`, `public-prometheus`, `multi-stage` |
| 4 | Owner-authorised API retrieval | `owner-roblox-model-*` (Roblox Open Cloud provider); Luarmor owner check (metadata) |
| 5 | Missing or invalid credentials | `auth-failure`, `keyed-url`, `owner-provider-not-configured`; Luarmor 403 / 400 |
| 6 | Unavailable payload | `invalid-endpoint`, `service-unavailable`, `luarmor` |
| 7 | Malformed API response | `html-instead-of-script`, `html-as-text`, `json-error-200`, `empty-200`, `key-required-text`; Luarmor non-JSON |
| 8 | Compressed or encoded | `encoded-base64-gzip`, `encoded-json-field`, `encoded-hex-zlib`, gzip'd model |
| 9 | Truncated source | `truncated-lua`, `truncated-gzip`, `short-transfer`; D8 tests |
| 10 | Retrieved but unsupported | `retrieved-unrecoverable` (VM kept → not deobfuscated), `luau-bytecode` (unsupported format) |
| 11 | Reconstructed | the validated cases above; the owner-supplied IronBrew 2 payload |
| 12 | Regressions of the existing deobfuscator | full suite and e2e, below |

### Deobfuscator: zero false success on the whole corpus

**Method.** `tools/validate/outcome-eval.mjs` → `data/research/outcome-eval.json`. Every real-tool fixture with an original is processed as
follows:

1. Recover with the sandbox on, and classify.
2. Compare the behaviour of the output with the **submitted (obfuscated) program** on a real Lua runtime (PUC Lua / LuaJIT / Luau through the
   oracle), and classify again.
3. Independently, run the output next to the **authorised original**, which the classifier never sees. A "validated" result that does not
   behave like the original is a **false success**. This is counted only where the original is a valid reference, that is, where the
   obfuscator itself preserved the original's behaviour.

| Measure | Result |
|---|---|
| Fixtures | 1643 (0 crashes) |
| **Validated** | **1269** |
| — checked against the authorised original | 1121: **all 1121 behave like the original** |
| — no valid reference (the obfuscator itself changed the program) | 148 |
| **False successes** | **0** |
| Syntax-valid but unverified | 136. The behaviour comparison could not settle it: the submitted program fails on the runtime, or prints nothing. |
| Partial | 150: 130 with obfuscation still in the output; 20 whose behaviour differs from the submitted program |
| Not deobfuscated | 9 (the VM is kept) |
| Invalid input | 79 (fixtures that do not parse, as their generators shipped them) |
| Results the engine rates "high" that are **not** validated | **165** (136 unverified, 29 partial). Under the old reading of confidence alone, each would have looked like a success. |
| Conservative: not validated although the output behaves like the original | 43. A VM still runs the program (behaviour equal, program not rebuilt), or places the engine lists as unresolved. |

The four high-confidence lifts found in the audit:

| Fixture | Class |
|---|---|
| Obscura 1.0.1 vm s04 | unverified (its input prints nothing) |
| Obscura 1.0.1 vm s06 | partial |
| lennyobf s08 Medium | partial |
| lennyobf s08 Strong | partial |

### Full suites

- **`npm test`:** 1169 tests; 1162 passed and 6 were skipped in the full run. The 1 failure was the XIX assertion "no Luarmor provider
  exists". It was restated to the guarantee it protects (the `luarmor` provider is metadata-only and never returns a script) and now passes.
- **`npm run test:e2e`:** **79 of 79 pass** (including the Reconstruct test that failed intermittently in Prompt XX).

New browser tests:

- Loader Intelligence with and without behaviour validation;
- the Deobfuscator's outcome, upgraded only by "Compare behaviour";
- the Luarmor owner-supplied payload, through the whole chain;
- the Luarmor ownership check (only the loader id is sent, never the key).

## 8. Remaining limitations and unresolved cases

- **The protected Luarmor script cannot be retrieved.** No authorised interface exists. The workflow says so at the retrieval stage and offers
  the owner's route instead (KNOWN-ISSUES 72, 76).
- **The Luarmor owner check is untested against the live service.** No owner key was supplied. It needs a whitelisted static IP, and it
  assumes the loader id is the `script_id` (KNOWN-ISSUES 79).
- **Four VM lifts that the engine rates "high" are wrong or unverifiable.** They are now classified honestly, but are not fixed.
  - For lennyobf, the duplicated call (D11) was fixed. A reference to the fork's nil stand-in remains.
  - For Obscura 1.0.1, the obfuscated input itself does nothing observable, so a lift cannot be validated (KNOWN-ISSUES 77).
- **Behaviour validation in the page uses the project's own interpreter.** Programs that need the real Roblox runtime, or do nothing
  observable, stay "unverified" (KNOWN-ISSUES 78).
- **A static estimate is still shown.** The engine's confidence remains next to the outcome class. It is no longer what decides success.
