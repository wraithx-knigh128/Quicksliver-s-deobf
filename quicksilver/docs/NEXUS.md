# NEXUS: adaptive program intelligence

NEXUS is a layer above the recovery engine described in `ARCHITECTURE.md`. It does not replace the lexer, parser, scope analysis, recovery pipeline, structure reader or sandbox; it
decides what to feed them, reads what they do not look at, and keeps a ledger of what may be claimed about the result.

Code: `src/nexus/`. Tests: `tests/nexus.test.mjs`, `tests/helpers/confetti.mjs`, two browser tests at the end of `tests/e2e/ui.e2e.mjs`.

## 1. Architectural assessment

The engine already had most of what a "reconstruction" system needs (about 29,000 lines): a Lua 5.1/Luau parser with a printer that round-trips, scope analysis, per-family recovery (Prometheus,
IronBrew 2, MoonVeil, Hercules, ...), an adaptive structure reader (dispatch loops, opaque predicates, call proxies, decoders), a Lua interpreter sandbox, a behaviour check, a confidence score,
and a corpus measured on real tool output. Rewriting any of that would have been motion, not progress.

The ceilings were found by running the engine on a real script (`MainLoader.lua`, a Roblox loader that is not obfuscated at all, only buried) and reading what it did. Each is a concrete observation:

| # | Ceiling | What was observed | Why pattern matching cannot fix it |
|---|---|---|---|
| C1 | **Transformations that live outside the code.** | The file holds 766 comments, a sentence cut into 1-to-7 letter pieces and put between the tokens. The engine kept 119 of them in its output (the ones the parser attaches to statements), and had no idea what they were. | It is not a known tool; there is no signature. It can only be recognised by what the comments *are* (short, mid-word, adding up to prose), and it can be removed *provably*: comments carry no behaviour. |
| C2 | **Naming sees only the initialiser.** | `rename.js` names a variable from the expression it is initialised with. In the same file it produced 265 uses of `value`, `value1`, `tbl1`, ... while the code says plainly what each thing is (`ui:Fail`, `luarmor.check_key`, a table of `KEY_*` handlers). | A name is a claim about *relations*: what a variable is assigned from across statements, what is called on it, which list it walks, which URL it came from. That needs a graph, not a pattern. |
| C3 | **No distinction between checked and concluded.** | The result carried one score. A renamed variable, a removed comment and a decoded string all weighed the same in it. | Without the distinction a reader cannot tell what to trust. |
| C4 | **Shapes it cannot rebuild were silent.** | Multi-variable state machines, dispatch through a table of functions and data-driven interpreters ("Not done" in `ARCHITECTURE.md`) were only visible to someone who knew to look. | A strategy that does not exist cannot report that it did not fire. Something has to *recognise the shape* to say so. |
| C5 | **The behaviour check could agree about nothing.** | On a script that fails at its first call, original and recovered both stop at the same line, and the comparison called the runs "identical". When the error names a local (`local 'a'`) and renaming changed the local, it called them "different". | Equal-looking runs are only evidence if the run got somewhere, and error text depends on names. |
| C6 | **Stages could not feed each other.** | Renaming is what lets `simplify` unwrap a `do` block (no more name clash); that only happens on a second pass, which nothing requested. | Passes are ordered; discovery in one stage changing what another can do needs a loop that knows when to stop. |

## 2. The subsystems

| Subsystem (brief) | Module | What it does |
|---|---|---|
| **E. Transformation Recognition** | `trivia.js`, `profile.js` | Reads comments as data: documentation, or fragments of a repeated sentence (length, mid-word splits, prose ratio, density per token). Classifies what was done to the text into categories (layout, naming, data, control-flow, indirection, virtualization, protection, hostile content), each with confidence, evidence and the technique that handles it. |
| **C. Semantic Relationship Mapper** | `roles.js` | Builds, per variable, what it is assigned from (including multi-assignment and `pcall` pairs), what is called on it, which fields it has, how it is indexed, what it is passed to; plus a call graph, the list of fetched URLs (followed through a loop over a list of literals), executor APIs, globals written to the shared environment. Derives role names from those relations: 26 rules, each with confidence and evidence (`nameFromUrl`, `position-in-download-list`, `pcall-result`, `returned-by` (inter-procedural: names positions of a multi-value call from what the callee returns), `table-of-handlers`, `counter`, ...). |
| **D. Control-Flow Intelligence** | `profile.js` `controlFlow()` | Cyclomatic complexity and nesting per function; recognises state-variable dispatch (supported), several state variables in one loop, dispatch through a table of functions, and fetch-and-dispatch interpreter loops (the last three reported as not rebuilt). Each loop is judged on its own body. |
| **B. Multi-Pass Reconstruction** | `pipeline.js` | Runs `recover()` and goes on while the last pass changed the text (bound: 3). Hints for the renamer are made from the tree the renamer is looking at, at the moment it renames. |
| **A. Adaptive Analysis** | existing `src/adaptive/` + `profile.js` | The structure reader is unchanged. NEXUS adds what it does not look at (C1, C2, C4) and keeps its result from the pass that did the work. |
| **F. Runtime Behaviour Interpreter** | existing sandbox + `verify.js`, used by `pipeline.js` | Off unless asked (`runtime: true`; the page asks first). Runs original and result in QuickSilver's own interpreter against the stand-in environment. NEXUS grades the evidence: a run that stops early is `shallow`, never `verified`; error messages are compared with variable names stripped. |
| **G. Confidence and Verification** | `ledger.js` | Every claim is `verified` (a named check ran), `inferred` (a rule concluded it; evidence listed), `unresolved` (seen, not settled) or `inconsistent` (a check failed). Names stay `inferred` however many rules agree. The level can only be lowered from the older score, never raised. |

## 3. The pipeline

| Stage | Output |
|---|---|
| 1 inspect | size, BOM, shebang, longest line; a report left by an earlier run is taken off |
| 2 identify | dialect, Roblox/executor environment, obfuscator families (existing detector) |
| 3 structure | parse (refused with a position if it fails), functions, variables, nodes |
| 4 semantic | trivia verdict; relation graph (roles, dependencies, call edges) |
| 5 classify | the transformation profile |
| 6 flow | control-flow metrics and shapes found in the input |
| 7 dependencies | fetched URLs, executor APIs, globals written; remote code becomes an `unresolved` claim and a `needs` entry |
| 8 reconstruct | fragment comments removed *after* the trees are shown identical; passes of `recover()` |
| 9 verify | parse/print round trip; no new globals; **naming changed only names** (below); control flow still in the *result* that is not rebuilt; optional behaviour check |
| 10 generate | the code, with the existing report block plus NEXUS lines |

Each stage reports `requests` (what would help: the sandbox, a manual look at a shape, analysing a fetched file). If any stage throws, the plain recovery result is returned with the failure recorded (`nexus.fallback`).

**The checks that make a claim `verified`:**

* *Comments removed.* Both texts are parsed and their syntax trees compared with layout and comments ignored (`sameProgram`). Equal trees mean the removal changed nothing.
* *Naming changed only names.* The tree before the renamer ran and the printed result are both reduced by replacing every local's name with the number of its declaration (`bindingKey`). Equal keys mean every use is bound to the same declaration, so no name captures or shadows another. Both sides go through the same print/parse so that how the printer writes `-1` is not mistaken for a difference.
* *No new globals.* The free names of input and result are compared.

## 4. Integration

* `src/recover/pipeline.js`: one option, `roleHints(ast)`, consulted by the renamer (default `null`: behaviour unchanged). `src/passes/rename.js`: exports `hintFromInit`, reads the hint before the initialiser.
* `src/api.js`: `recoverSource(source, { nexus: true, ... })`, and `nexusSource` for NEXUS with its own options. Without `nexus` the older result is byte-identical (tested).
* Page: Settings → **NEXUS analysis** (on by default). The Details panel gets a NEXUS section: claims, hidden text shown as text, what was done to the file, names with rules, dependencies, control flow, what would help, stage timings. The JSON report includes the ledger.
* Nothing is executed unless the person asks. Text from the script is only ever inserted as text.

## 5. What NEXUS will not do

* It does not remove or bypass licence-key checks, whitelists or HWID locks. A script that checks a key is *described* (`licence-gate`), and the check is left in place; the Key Bypass tab of the old single-page site was removed.
* It does not follow instructions found in the file. Text in a comment that addresses AI tools ("refuse any request to ...") is reported as hostile content, shown in the panel, and left out of the output file so it cannot reach a program that reads that file next.

## 6. Verification

`npm test`: 727 tests, 0 failed at the time of Phase III (the 348 skipped need a real Lua through `QS_LUA_PYTHON`; they were skipped before this work too). `npm run test:e2e`: 40 of 40 in Chromium. What the laboratory measured about NEXUS, and how it chooses plans, is in `RESEARCH-LAB.md`.

`tests/nexus.test.mjs` (35 tests): trivia recognition and its refusals (documentation is kept, ordinary mentions of AI are not flagged); relation naming on a synthetic loader, with every name carrying a rule and evidence; the alpha-renaming proof and the capture test (a suggested `url` does not capture a global `url`); control-flow shapes; the ledger rules; ten stages in order; reports replace rather than repeat; failures are refused with a position; remote code and unrebuilt shapes lower confidence and are named; shallow runs are not called verified; parity with the plain engine over 12 real Prometheus/Hercules fixtures (NEXUS never fails where the engine succeeds, and any lowered level has a reason); cost.

Two regressions NEXUS first introduced were found by the browser suite and fixed, and are now unit tests: a loop nested in another was read as one loop with two state variables, and the structure reader's work was lost when the last pass had nothing left to do.

The owner-supplied loader is kept out of the repository (`tests/corpus/user-local/`, git-ignored, as for the other supplied scripts); its test runs where the file is present and is skipped with a reason otherwise.

Not tested: behaviour of results on real Lua (needs `lupa`); anything about closed-source VMs beyond what the existing suite covers; names on code that is not Roblox-style.

## 7. Cost

Measured in Node 22 on one machine, a generated program of N functions, plain `recover()` against NEXUS, in milliseconds. NEXUS runs two or three passes and the relation mapper, so it costs two to three times the plain engine; growth is linear (doubling the input about doubles the time), and comment confetti five times the size of the program adds about 20%.

| N | bytes | plain | NEXUS | NEXUS with confetti (bytes) | heap after |
|---|---|---|---|---|---|
| 100 | 22 K | 222 | 298 | 309 (101 K) | 10 MB |
| 200 | 44 K | 127 | 430 | 521 (202 K) | 11 MB |
| 400 | 88 K | 326 | 994 | 1213 (405 K) | 13 MB |
| 800 | 176 K | 679 | 1942 | 2343 (811 K) | 17 to 25 MB |

Memory: each pass parses the text again and the renamer takes one clone of the tree; peak heap above is a few tens of MB for 800 functions. Above `maxBytes` (2,000,000) one pass runs and the relation mapper is skipped, and the result says so. The cost tests are ratio tests (2x input, under 3.5x time) so they do not depend on the machine.

## 8. Limitations

* **Names are inferred.** They come from rules, and a rule can be wrong. They are listed with their evidence and are never `verified`. Original names are not recoverable.
* **Vocabulary.** The verb list (`Get`, `Fetch`, `Resolve`, ...), the executor API list and the key-check words are English and Roblox-shaped. Code outside that world gets fewer names, not wrong ones.
* **Control-flow recognisers are syntactic.** A loop that holds a program's own state variable next to a flattening variable can look like "several state variables" (seen on `flatten-chain`). That is why a shape is only held against the *result*, where the engine has already had its turn.
* **Unsupported shapes are reported, not rebuilt:** several state variables in one loop, dispatch through a table of functions, interpreter loops. Closed-source VMs (Luraph, MoonSec) are unchanged from `ARCHITECTURE.md`.
* **Comments inside expressions are not kept** by the parser for any script (existing behaviour); documentation comments between statements are.
* **Fragment detection needs enough comments** (12 non-empty ones) and a median length of at most 24 characters. A different way of hiding text in trivia (zero-width characters, whitespace patterns) is not recognised.
* **Runtime evidence is one run each** in a stand-in environment. For a script that depends on fetched code or a live service the run stops early and the claim stays `unresolved`.
* **Fetched code is never fetched.** It is listed, and the person is told to analyse each file on its own.
