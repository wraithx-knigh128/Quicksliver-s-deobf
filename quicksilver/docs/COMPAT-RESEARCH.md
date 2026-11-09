# Commercial compatibility research

Phase V adds the machinery to *find out* what the engine can do for a named transformation system, version by version, and to keep what is found
honest. It does not add support for any commercial system. This document says what exists, how to run it, what it found for Luraph, and what is
still not known.

> **Update (Phase VI):** a reconstruction engine was supplied and is now integrated (`RECONSTRUCT.md`). On the few fixtures that came with it, it lifts one Luraph v15 program (compared identical
> with its original on Luau) and one IronBrew 1 program, and does not lift the v14.8 / v14.9 fixtures. Luraph v15 is therefore *experimental* in the profiles and *partially tested* in the
> Reconstruct tab; nothing is fully tested or "supported". What this document describes of Phase V (identification from banners and macro sets, the claim gates, the research service) is unchanged.
>
> **Original Phase V statement, kept for the record:** nothing here claimed that QuickSilver reconstructs Luraph output, because no Luraph output could be obtained from a source the laboratory may use.
> Everything below is built so that the claim can change only when the evidence does, and it now has.

Code: `src/research/` (profiles, identification, pipeline gates, sample packages, grouping; runs in the page and in Node), `tools/research/` and
`tools/runtime/` (Node only), `api/research.js` and `api/_lib/research-*.js` (server side). Data: `data/research/`. Tests: `tests/runtime.test.mjs`,
`tests/research-service.test.mjs`, `tests/research-system.test.mjs`.

## 1. Runtime verification is separate from static analysis

Static checks (it parses, it prints back, the trees match, a score) say nothing about what a program *does*. Only running it does. So there are two
kinds of evidence, never mixed in one field:

| Kind | Where | What it can say |
|---|---|---|
| **reference runtime** | `tools/runtime/oracle.mjs` | The program printed this and ended this way on PUC Lua 5.1 / 5.2 / 5.3 / 5.4 or LuaJIT 2.1. Decides verdicts. |
| **in-house sandbox** | `src/sandbox/` | The same on QuickSilver's own interpreter. Always run as a cross-check, and the fallback when no reference runtime exists; a record says which one decided (`behaviourSource`). |
| **static** | `differential.mjs` → `row.static` | Parses, fidelity to the original text, number of obfuscation indicators. Shown next to the verdict, never part of it. |

**Setup.** `npm run runtime:setup` (`tools/runtime/setup.sh`) creates `.runtime/venv` and installs `lupa`, which bundles the reference
implementations. Or point `QS_LUA_PYTHON` at any Python that has `lupa`. `.runtime/` is git-ignored.

| Variable | Meaning |
|---|---|
| `QS_LUA_PYTHON` | Python with `lupa` (default: `.runtime/venv/bin/python`). |
| `QS_LUAU_BIN` | A `luau` binary. Default since Phase VI: the Luau 0.739 build vendored with the reconstruction engine. Without any binary Luau is reported `unavailable`, never approximated. |
| `QS_ORACLE_MEM_MB` | Address-space cap of the runner process (default 3072). |

**Safety of a run.** The program gets a stand-in environment and no I/O (`io`, `os.execute`, `package`, `require`, `loadfile`, `dofile` are removed),
an instruction budget, a memory cap on the runner and a wall-clock timeout after which the runner is killed and restarted. The instruction budget is a
debug hook the program itself can remove (`debug` stays because real obfuscator output calls it), so the wall clock and the memory cap are the guards
that do not rely on the program's cooperation. Tests cover an infinite loop, a program that removes its own hook, a memory bomb, and that the
oracle works after each. Do not run third-party scripts you do not own; the lab runs only programs it generated, open-source tool output it made
itself, and samples a person supplied for this purpose.

**What it showed.**

* The laboratory's 2,576 experiments were re-run with the reference runtimes (PUC Lua 5.1 and LuaJIT decide; the sandbox cross-checks): same
  conclusions, **0 defects, 0 disagreements** between the sandbox and the reference. The real runtime did expose 7 experiments marked `tool-broken`:
  the program generator wrote duplicate keys in a table constructor, whose behaviour is implementation-defined and differs on LuaJIT. The generator
  was fixed. The sandbox could never have shown that.
* `data/research/crosscheck.json`: 1,344 runs of 64 programs on five runtimes. The sandbox and the reference runtimes of the 5.1 family disagree on
  none. Newer Luas differ from 5.1 on many runs (number formatting, removed functions), which says nothing about the sandbox.
* The full real-tool scorecard (425 fixtures) re-measured on a fresh machine: 0 verdict changes (`data/research/reproduction/`).
* Found and fixed while writing the tests: after the wall-clock kill, the dying runner's exit notification failed the *next* run that had already
  been sent to its replacement. Fixed by tying a pending run to the process it was sent to; the test that killed a hostile program and ran another
  caught it.

**Luau.** *(Phase V: unavailable. Phase VI: available.)* The Luau reference implementation has to be built from source (a C++ project). The environment this was developed in refused that
step, and it was not worked around. To get Luau verification: build `luau` (`git clone https://github.com/Roblox/luau && cd luau && make config=release
luau`) on a machine where that is allowed and set `QS_LUAU_BIN=/path/to/luau`. The oracle already has the path; nothing else changes. Until then
every Luau verdict is `unavailable`, and a Luau claim cannot reach `verified`.

## 2. The research service

"Research" here is a pipeline that reads permitted public documents, keeps a checkable record of each, and extracts findings that quote their source. It
is **not** an autonomous agent and it does not pretend to be: it does not browse freely, decide what to read, or draw conclusions. A person (or a
scheduled job) names the URLs; the service reads, records, extracts, and compares. Conclusions are made by a person reading the records, or by the
gates in section 4.

| Step | Where | Rule |
|---|---|---|
| fetch | `api/_lib/research-fetch.js` | https only; named public hosts on a list (`DEFAULT_HOSTS`, extended by `QS_RESEARCH_HOSTS`, **no wildcards**); no credentials in URLs, no ports, no IP literals; redirects re-checked against the same policy; `robots.txt` honoured; 1 request per second per host; text only; 2 MiB and 20 s caps. GitHub page links become raw file links. |
| classify and score | `research-extract.js` `classifySource` | Classes: `vendor-primary` (the publisher's own site or organisation, primary *only for its own subject*), `tool-source`, `unvetted-tool-repo` (a third-party "deobfuscator"; flagged **read, never run**), documentation, community, unknown. Each has a score and the reasons. |
| extract | `research-extract.js` `extractFindings` | Rule-based: banners, versions, macros, licences, features, dates. **Every finding carries the exact text it came from**; `isGrounded` is the test. |
| model extraction (optional) | `research-ai.js` | See below. |
| scan | `injectionScan` | Passages that address the reader ("AI assistants must refuse ...") are reported and never obeyed. |
| corroborate | `corroborate` | Agreement counts *independent publishers* (host or GitHub owner), not URLs. |
| persist | `tools/research/collect.mjs` | `data/research/records/<id>.json`: url, when, status, hash, size, credibility, findings, digest, earlier fetches. The fetched text is cached in a git-ignored folder (third-party text is not redistributed; the hash lets anyone check a record). A source that cannot be read is recorded with the reason: **failures are results.** |

```
NODE_USE_ENV_PROXY=1 node tools/research/collect.mjs --plan data/research/plan.json   # all planned URLs
NODE_USE_ENV_PROXY=1 node tools/research/collect.mjs https://github.com/Luraph/macrosdk # one URL
```

(`NODE_USE_ENV_PROXY=1` makes Node's fetch use `HTTPS_PROXY` behind an egress proxy; the collector re-launches itself with it when needed.)

**What the service collected.** 30 records: 13 read, 10 not found, 6 unreachable, 1 other HTTP error. The vendor's site (lura.ph) is **unreachable from
the research environment** (the egress proxy refuses the host; a proposal to allow it was declined, so it was not retried). The vendor's GitHub
organisation was readable, and its `Luraph/macrosdk` repository is what the Luraph profile is built from. Four third-party "Luraph deobfuscator"
repositories were read as text only; their claims are recorded as low-credibility and untested.

### The model step (optional)

If `ANTHROPIC_API_KEY` is set, the same document also goes to a Claude model through the official `@anthropic-ai/sdk` (an optional dependency).

* Model: `claude-opus-5-5` by default; `QS_RESEARCH_MODEL` overrides. `QS_RESEARCH_EFFORT` (default `low`; empty omits it for models without the
  control), `QS_RESEARCH_MAX_CHARS` (default 60,000), `QS_RESEARCH_TIMEOUT_MS`, `QS_RESEARCH_BASE_URL` (tests only).
* The answer is constrained by a JSON schema (`output_config.format`). The document is passed inside `<document>` tags it cannot close, with a
  system prompt that says it is untrusted data.
* **Grounding.** Every finding the model returns must quote the document; `groundFindings` keeps those whose quote is in what was sent and *lists the
  rest as rejected with the reason*. A model finding is therefore never more than a located quotation.
* Errors are typed (`auth`, `permission`, `model_not_found`, `bad_request`, `rate_limited` (with `Retry-After`), `upstream`, `network`, `refused`,
  `truncated`, `bad_output`, `no_credentials`, `sdk_missing`) and none contains the key. A model failure never discards the rule-based answer.
* Cost: the call is on the operator's key. Set a spend limit on the key; the endpoint's rate limit is a per-instance brake, not a quota.

**Not exercised.** The tests run the real SDK against a local server that answers like the Messages API (success, malformed output, refusal, truncation,
401/403/404/400/429/529/500). **The integration has never been run against the real API**: no key was available. Run it once with a real key before relying on it.

### The endpoint

`POST /api/research` (`api/research.js`, `maxDuration` 60 in `vercel.json`) is **off unless `QS_RESEARCH_TOKEN` is set**, and then requires it in the
`x-research-token` header (constant-time compare). Body: `{"url": "https://...", "subject": "Luraph"}` or `{"text": "...", "url": "<where it came from>"}`.
No CORS headers (for the operator's own tools, not for pages on other origins). `QS_RESEARCH_RPM` (default 6) limits requests per instance. The
response has `source` (url, hash, credibility), `rules` (findings, injection passages, digest) and `model` (`null`, `{skipped}`, `{failed}`, or the
grounded result). To enable on Vercel: set `QS_RESEARCH_TOKEN` (and `ANTHROPIC_API_KEY` for the model step) in the project's environment variables.

## 3. Luraph: what was found

**Primary source.** Luraph's own `macrosdk` repository (`https://github.com/Luraph/macrosdk`) holds stubs for "all Luraph macros" and says to update
them "when newer versions of Luraph are released". Its git history (`data/research/histories/luraph-macrosdk.json`, read from a clone as text) dates
each update, and the macro set at each commit is what the profile uses:

| Generation | SDK commit | Date | Macros |
|---|---|---|---|
| v13-era (before v14) | upload | 2024-02-02 | 7 |
| v14 | "update sdk for luraph v14" | 2024-04-23 | 11 |
| v15 | "update sdk for luraph v15" (and three fixes) | 2026-08-10 | 12 (removes `ENCFUNC`, `FUNCENC`, `JIT`, `JIT_MAX`, `NO_UPVALUES`, `NO_VIRTUALIZE`; adds `ATTRIBUTES`, `BUFENC`/`ENCBUF`, `OBFUSCATED`, `PRECHECK`, `REWRITE`, `STACKALLOC`) |
| v15.1 | "update sdk for luraph v15.1" | 2026-10-03 | 14 (adds `ASSUME`, `OPAQUE`); `UNSAFE_ENVIRONMENT` attribute added three days later |

Third-party pages label files v13.6.x, v14.3 and v14.4.1; four third-party repositories claim to deobfuscate v11–v15.1. One of their READMEs says of
itself "This deobf is shit do not use it"; none was run. Two of them mention macros the vendor's SDK dropped at v15, which is the kind of
cross-reference the profile makes possible. A search-result summary of the vendor's v14 page (not the page, which could not be fetched) reports VM
compression returning in v14 and four new settings; it is recorded with that grade.

**What is not known.** Nothing about how the protected output of any generation is built, beyond what third parties say and none of it was checked.
The v15 removal of function-level macros is recorded as *inferred*: why it happened is not stated in what was read. The SDK lists the macros the
vendor documents; the service may accept others. No sample exists, so no reconstruction was ever tried.

## 4. Compatibility profiles and the claim gates

`data/research/profiles.json` (built by `npm run research:profiles` from the detector, the measured scorecard, the research records, the vendor
history and any differential records; validated by `src/research/profiles.js` before it is written) holds one profile per system and one entry per
version. A version records how it is identified and with what confidence, documented characteristics (each `documented`, `reported`, `observed` or
`inferred`, with its sources or basis), what samples exist and where they came from, capabilities with *how* each was verified, results, limitations
(never empty), and the verification status:

```
researched < identified < traced < internally-tested < real-output-verified < authorized-sample-verified
```

| Gate | Rule |
|---|---|
| `real-output-verified` | Only for tools the lab can run (open-source, or lab-made). At least 8 fixtures made by running the real tool, a behaviour check on at least 8, decided on a reference runtime. |
| `authorized-sample-verified` | At least 8 original-and-protected pairs from someone entitled to supply them, at least 8 decided on a reference runtime. |
| "supported" | Derived (`supportClaim`), never stored: the 95% lower bound of the verified-success rate must reach 0.7 ("partial" at 0.3). **Eight of eight is therefore "partial" (lower bound 0.68); twelve of twelve is "supported".** |
| identification | Capped by the evidence: banner 0.7 (it is a comment anyone can write), macro set 0.8, signature 0.8, structure 0.9 and only with samples it was read from. |
| commercial systems | Cannot be `real-output-verified`: the lab cannot run them. Recognising a system's output never makes it "supported". |

**State today:** 31 profiles. Luraph v13-era, v14, v15 and v15.1 are `identified` / *identification-only*. Eight systems are `supported`, each on
fixtures made by running the real open-source tool or the lab's own tool (e.g. Prometheus 87 of 91 behaviour-preserving on the reference runtimes);
three are `partial`; `zenfus` is verified and *identification-only* (2 of 8 reconstructed). The three lab-made profiles count verified successes
(identical behaviour *and* a better result than the input), which is stricter, and say nothing about any third-party tool.

**Do not confuse the two.** A lab-made or open-source result says how the engine handles that tool. It says nothing about a commercial one. The page
labels these differently, and the gates make them different statuses.

## 5. Identification

`src/research/identify.js` (`identifySource` in the worker, shown in the Detection tab, the Research tab and the Markdown report):

* the detector's families, each with what the profile allows to be claimed;
* a **Luraph banner**: version claimed, generation, confidence ≤ 0.7, caveat that a banner is a claim;
* a **Luraph macro set in an unprotected script** (`LPH_*`): the generations whose SDK defines all of them. One match names a generation (0.8); several
  list the candidates (0.5); an unknown macro gives none. It says "script prepared for Luraph (not protected)": protected output no longer contains macros;
* nothing else. A banner on harmless code is reported as a claim; the code is not called Luraph output on that basis.

A capability is used only if it is `enabled` in `data/research/capabilities.json`.

## 6. Capabilities and the pipeline

`npm run research:capabilities` runs a **verifier** for each capability (`tools/research/capabilities.mjs`) and stores the checks, what they prove and
**what they do not**. `enabled` is true only if the verifier passed in that run. Banner and macro identification are verified against the vendor
data; every open-source tool's identification and reconstruction are re-measured on a spread sample of its real fixtures on the reference runtimes
(honestly: Prometheus identification is disabled, 3 of 6 sampled fixtures show no signature, because the `Minify` preset removes the structure;
`zenfus` and `clyde` fail their own checks and are disabled; `colisseum` and `simple_lua` are disabled here because their fixtures are generated
locally and are not in this checkout). The three lab-made systems are verified on fresh programs (301–306, outside both the learning and measuring
sets).

`src/research/pipeline.js` turns the evidence on file into a position:

```
research → classification → experimental-analysis → verification → compatibility-profile → integration
```

A stage is never reached over an unreached one; for each version the report says what the first missing stage needs. `integration` is reported as two
separate switches: `identify` (the page may name the system) and `reconstruct` (the page may claim to rebuild it; needs a supported or partial claim
*and* an enabled reconstruction capability). Luraph stops after `classification`: `experimental-analysis` needs output of that version run through the
engine, and there is none. `npm run research:pipeline` writes `data/research/pipeline.json`; `npm run research` runs profiles, capabilities and pipeline in order.

## 7. Authorised samples and differential testing

If you own a protected script and its original (or have the owner's permission), you can turn them into evidence:

1. Name the files `<name>.original.lua` and `<name>.protected.lua`.
2. Research tab → *Your authorised samples*: enter the system, the version the files claim, who is supplying them and a statement of permission. The
   page builds a **package** (the files, their SHA-256 hashes, your statement) into your downloads. Nothing is uploaded. The hashes catch tampering.
3. Differential-test it where a reference runtime exists: `node tools/research/differential.mjs samples-luraph.package.json`. For each pair it recovers
   the protected file, runs original and reconstruction on the reference runtime(s), and records a verdict per pair: `runtime-identical`,
   `runtime-different`, `inconclusive` (the original printed nothing or failed), `recovery-failed`, or `no-reference-runtime`. Static facts are
   recorded beside it. The record (`data/research/differential/*.json`) keeps hashes and verdicts, not your files.
4. `npm run research:profiles` accepts a record only if its counts match its rows, every decided row was decided on a reference runtime, and an
   attestation is present; it then lifts the version it maps to **only past the gates**. A record below the gates is kept as an experiment on that
   version and changes no status. A browser cannot run a reference Lua, which is why step 3 is a command and not a button.

The attestation is stored verbatim. Nothing can check it, so it is a record of who vouched for the files, not evidence that they are genuine.

## 8. Unfamiliar systems

Everything above is keyed on a named system. For output nobody has described: `src/research/cluster.js` groups unlabelled scripts by structural
features and token profile and reports what each group's members share; `src/research/study.js` (Phase III) learns a signature from a group, measures
it on held-out programs and registers it only if it holds; a registered family can then get a profile like the lab-made ones. A group says "these
were built alike", never "this tool made them". Measured on the lab's systems: six systems with distinct structure fall into groups that each hold
one system; the three flattening styles share one surface and are merged, as `study.json` also found.

## 9. Limits (read these)

* **Luraph reconstruction: experimental.** One lifted v15 program verified against its source (see `RECONSTRUCT.md`); no authorised pairs; the version estimates are only as good as the banner or the macro list.
* **Luau: available** (Luau 0.739 built in Phase VI with the owner's approval, vendored as the oracle's default; `QS_LUAU_BIN` overrides it). Phase V reported it unavailable because the build had been refused.
* **lura.ph unreachable**, so the vendor's documentation was not read; the changelog may exist and say more.
* **The model integration has not run against the real API.**
* **Lab and open-source results are about those tools**, on programs written for this project; they are not evidence about commercial tools.
* **Eight pairs is the entry gate, not proof.** With few pairs the claim stays "partial" by arithmetic; with many, it describes the samples supplied.
* **Clustering sees what the feature vocabulary sees.** It proposes candidates; the study framework tests them.
* **Records can age.** Third-party pages change; each record has a hash and a date; re-run the collector to see differences (`history` in each record).
