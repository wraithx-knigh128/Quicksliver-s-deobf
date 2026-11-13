# Research notes: Lua / Luau obfuscators

Written while building QuickSilver. Every statement below is tagged with how it is known:

| Tag | Meaning |
|---|---|
| **[source]** | The tool's own source code was cloned or fetched and read, and fixtures were generated or checked against it. |
| **[docs]** | A page published by the tool's author says it. |
| **[third-party]** | A forum post, write-up, package listing or similar says it. Not verified against the tool. |
| **[unverified]** | A name was seen in the task description or in a community thread; no usable information was found. |

If a family is not described here, it is because nothing reliable could be found, not because it was skipped.
`COMPATIBILITY.md` shows how each of these families is handled by the engine, with measured numbers.

## How the research was done, and what limited it

* Web search (snippets and result titles) for each name.
* `git clone` of public GitHub repositories (this worked from the build environment) and `raw.githubusercontent.com`.
* Direct fetches of vendor sites, forums and blogs did **not** work: the environment's network policy resolves only a small set of hosts.
  Pages such as `lura.ph`, `luaobfuscator.com`, `git.openpunk.com` (MoonVeil docs), `scrappey.com` and `birk.blog` could therefore not be read in full;
  where only a search snippet was available, that is stated.
* No output of any closed-source obfuscator could be generated. Commercial tools (Luraph, MoonSec, PSU, MoonVeil, ...) need accounts, keys or a vendor
  service; no sample files were supplied. Nothing about them was tested against real output.

## Tools whose source was read

### Prometheus **[source]**

* Repository: `https://github.com/prometheus-lua/Prometheus` (cloned; revision `a4efc5f`, Jul 2026). Written in Lua, targets Lua 5.1 and Luau.
* Licence: a custom MIT-style licence by Elias Oelschner that **requires attribution** ("Based on Prometheus by Elias Oelschner, https://github.com/prometheus-lua/Prometheus") from any product that uses or incorporates the software. See `THIRD_PARTY_NOTICES.md`; the attribution is shown in the application's About dialog.
* Steps found in `src/prometheus/steps`: `AddVararg`, `AntiTamper`, `ConstantArray`, `EncryptStrings`, `NumbersToExpressions`, `ProxifyLocals`, `SplitStrings`, `Vmify`, `WrapInFunction`.
  Presets: `Minify`, `Weak`, `Medium`, `Strong` (the last three include `Vmify`).
* How each step transforms code, as observed in the generated output and in the step sources:
  * `EncryptStrings`: strings are replaced by calls to a generated decryptor that seeds a PRNG-style stream cipher (2^45 modulus, 2^32 scaling); the key schedule is per file.
  * `ConstantArray`: constants move into a table that is rotated at start-up and read through an accessor with an offset.
  * `SplitStrings`: string literals become concatenations of pieces.
  * `NumbersToExpressions`: numeric literals become arithmetic that folds to the same value.
  * `ProxifyLocals`: locals become fields of proxy tables reached through metamethods (`__index`, `__newindex`, arithmetic metamethods) with a per-file operation protocol.
  * `AntiTamper`: a block that checks `string.dump`/function types and raises "Tamper Detected!".
  * `WrapInFunction`, `AddVararg`: the program is wrapped in `return (function(...) ... end)(...)`.
  * `Vmify`: the program is compiled to a register VM whose dispatcher is a `while` loop over a binary tree of comparisons on a block counter; closures, upvalues and globals go through helper tables.
* **What QuickSilver does:** detection (verified on real output for every step), static recovery for every step except `Vmify`
  (`src/recover/prometheus.js`, shared passes), sandboxed decoder evaluation for `EncryptStrings`/`ConstantArray`, and the behavioural trace for `Vmify`.
* **Limits:** the flattened VM's control flow is not reconstructed (see "What is not recoverable" below).

### Hercules **[source]**

* Repository: `https://github.com/zeusssz/hercules-obfuscator` (cloned; revision `ace084c`, Jun 2026), Apache-2.0, version 2.0.1 in the fixtures.
* Presets `light`, `balanced`, `heavy`, `maximum`, and modules: variable renaming, control-flow wrapper, string encoding (Caesar-style), string-to-expressions, opaque predicates,
  garbage code, function inlining, wrap-in-function, anti-tamper, dynamic code, bytecode encoding, virtual machine, compressor.
* The virtual-machine module embeds a Lua bytecode interpreter written in Lua and the program as bytecode; the bytecode-encoding module wraps `load(string.dump(...))` in a hex string with an offset.
  The bytecode is produced by the Lua that runs the obfuscator: Lua 5.4 chunks in the fixtures used here.
* **What QuickSilver does:** detection and static recovery for the source-level modules (`src/recover/hercules.js`), sandboxed evaluation for the string encoder,
  reading and executing Lua 5.1/5.4 chunks in the sandbox (`src/sandbox/bytecode.js`) and tracing VM and bytecode output.
* **Limits:** the embedded interpreter and compiled chunk are reported but not decompiled (see below).
* Hercules itself failed to produce equivalent output for some module/sample pairs (function inlining, a few others); those are marked "tool broken" in the measurements and excluded from behaviour claims.

### IronBrew 2 **[source]**

* Repository: `https://github.com/Trollicus/ironbrew-2` (cloned), MIT licence, "Copyright (c) 2019 DefCon42". C# obfuscator for Lua 5.1 that calls `luac`, rewrites the bytecode and emits a Lua VM.
* Output structure, read from `IronBrew2/Obfuscator/VM Generation/Generator.cs` and `VMStrings.cs`:
  * a preamble of local aliases (`string.byte`, `string.char`, `string.sub`, `table.concat`, `math.ldexp`, `getfenv or function() return _ENV end`, `select`, `unpack or table.unpack`, `tonumber`);
  * optionally a `decompress` function (LZW over a base-36 text encoding) and `ByteString`, the serialised chunk, otherwise a decimal-escaped string;
  * a deserialiser (`gBits8/16/32`, `gFloat`, `gString`) that XORs every byte with a per-file key and reads constants (bool/float/string with remapped type tags) and instructions;
  * `Wrap(Chunk, Upvalues, Env)`, a `while true do local Inst = Instr[pc]; local Enum = Inst[OP_ENUM] ...` dispatcher in which every VM opcode is a branch;
  * opcodes are shuffled and **mutated** (35-50 variants per opcode with permuted register fields), and runs of instructions are folded into "super operators";
  * optional control-flow rewriting on the bytecode (`Control Flow/Types`: bounce, eq-mutate, inlining, number-mutate, test-flip, test-preserve, test-spam) and a minifier pass.
* A third-party CTF write-up identifies IronBrew-style output by "a vm-like structure" and by a quirk in its OP_JMP handling **[third-party]**;
  another write-up says most obfuscators seen in the wild derive from it **[third-party]**.
* A public experimental deobfuscator exists (`Gork3m/IronBrew2-Deobfuscator`, C#, marked "still being worked on", no licence file). It was read only to confirm the general method:
  find the VM pieces in the text, emulate the deserialiser, recognise each opcode handler, rebuild bytecode. No code from it is used.
* **What QuickSilver does:** see `COMPATIBILITY.md` for the current state of the IronBrew 2 module.

## Closed-source tools

### Luraph **[third-party], [unverified]**

* Vendor: `https://lura.ph/`. The vendor's GitHub organisation `https://github.com/Luraph` exists and lists, among others, `luraph-node` (an API client), `macrosdk` and `luraph-vscode` **[third-party, from a search snippet]**; none of these is an obfuscator or deobfuscator.
* A lua-users wiki entry lists Luraph as supporting Lua 5.1-5.4 and Luau and calls it "advanced Lua code obfuscation and virtualization" **[third-party]**.
* A third-party write-up describes Luraph-class protectors as a stacked design: a "deserialisation VM" that decodes an encrypted blob and a second VM that runs the decoded instructions, plus anti-tamper traps; it says the blob is a long string starting with `LPH}` and points to a public blog series (birk.blog, "Lua Virtualization", part 4) that devirtualises Luraph as a case study **[third-party; none of it could be fetched or checked]**.
* MoonVeil's documentation maps Luraph's `LPH_ENCFUNC` macro to its own `MV_ENC_FUNC`, i.e. Luraph has selective function virtualisation through macros **[third-party, search snippet]**.
* **Versions, including 15.1:** no public technical description of v14 or v15 was found, and no sample output could be generated. Banner comments of the form
  `This file was protected using Luraph Obfuscator vX.Y.Z [https://lura.ph/]` are used for detection only.
* **What QuickSilver does:** banner detection, VM-shape heuristics, behavioural trace. It does **not** recover Luraph source and makes no claim to.
* **Update (Phase V, `COMPAT-RESEARCH.md`):** the vendor's `Luraph/macrosdk` repository could be read and its git history gives dated macro sets for four generations (v13-era 7 macros, v14 11, v15 12, v15.1 14); that is the evidence behind the page's generation estimates. `lura.ph` itself is still unreachable from the research environment. Still no sample output, so still no reconstruction and no claim of one.

### MoonSec V3 **[unverified]**

* Searches returned SEO filler pages ("Moonsec V3 Deobfuscator" with no method) and unofficial PyPI wrappers around the vendor's obfuscation service (`moonsectesting`, marked "NOT OFFICIAL"), whose option names mention a `maxsecurity` mode and an `antitamper` option that "uses loadstring or load" **[third-party]**.
* A directory listing mentions a Python "MoonSec V3 bytecode dumper" (`hemusuku86/GoonSec`); it could not be cloned and was not examined **[unverified]**.
* Banner used for detection: `This file was protected with MoonSec V3`.
* **What QuickSilver does:** banner detection and the behavioural trace.

### MoonVeil **[docs, partial]**

* Documentation repository: `https://git.openpunk.com/CPunch/MoonVeil-Docs`. Search snippets show macros `MV_VM` (virtualise a block), `MV_ENC_FUNC` (virtualise and encrypt a function, key evaluated at run time), `MV_CFF` (control-flow flattening) and `MV_OMIT` (exclude a block), and the advice to obfuscate only selected parts because virtualised code is slow **[docs, snippets]**.
* The pages could not be fetched, so MV_VM and MV_CFF behaviour is not known beyond their names.
* One real script (version 2.0.25, supplied by a user and not stored in this repository) was read in the fourth pass: a table of functions with a permutation bootstrap, base-85 + XOR strings, `bit32` constants, cell variables, and one function compiled to a private VM. See the fourth pass below.

### LuaObfuscator.com **[unverified]**

* No page from the site could be read. Search results were unrelated tools. Nothing is claimed about its protection levels.

### PSU **[third-party, thin]**

* Community threads mention "psu obfuscator"; one reply describes obfuscators of this kind in general as "compiling the script into bytecode, mixing it up, and running it through a Lua-in-Lua VM" **[third-party]**.
* Document titles on a file-sharing site list "PSU Obfuscator 4.0" and "4.5.A" **[third-party]**. No macros, options or format were found.

### XHider, Goofyscator, IronVeil, 77fuscator, Synapse Xen, WeAreDevs **[unverified]**

* No usable documentation or samples were found for any of these. They are registered so that a script naming them in a banner is reported accordingly, with the confidence capped at what a banner can justify.
  QuickSilver makes no recovery claim for them.

## Other obfuscators and tooling seen (not implemented)

* **PELock Lua Virtualizer** (commercial; claims polymorphic string encryption, anti-debugging and self-integrity checks) **[docs, listing]**.
* **obfuscate.lua**: encrypts scripts with a PRNG-based XOR and prepends the decryptor **[docs, snippet]**.
* **zynaa/LuaObfuscator**: small Python tool with levels 0-2 **[docs, snippet]**.
* **Anul** (paid, BuiltByBit), **LennyObf**, **PY44N/Lua-Obfuscator**, **Luarmor** (loader-style service): names only.
* **LuaPro**: a pure-Lua AST toolkit that lists deobfuscation (constant folding, dead-code elimination) as not yet implemented **[docs, snippet]**.

## Second research pass: more open-source obfuscators (October 2026)

A web search for open-source Lua / Luau obfuscators turned up the projects below. Each was shallow-cloned into its own directory and its README, file list and licence were read.
**None of them was executed to produce samples**, with one exception noted below: the session's permission policy declined to run further third-party code from the clones, and the
one attempt that did run (zynaa/LuaObfuscator, levels 0-3) ended in `Fatal error occurred.` with no output file each time, so there is no real output of any of them in the test corpus
and QuickSilver makes **no detection or recovery claim** for them. They are listed so the next pass knows where to start.

| Project | What the README / files say | Licence | Status here |
|---|---|---|---|
| **RealObfuscator** (linkoro57), v1.6.0, rev `bfcf28d` | Python CLI for Luau: identifier renaming, string and number encoding, control-flow transforms, dead code, integrity checks, and a VM mode that compiles to encrypted bytecode with per-build opcode shuffling and "positional whitening" of constants **[source: README]** | GPL-3.0 | not run. Output of a GPL tool can embed the tool's runtime template, so its output should not be bundled as a sample without a licence review. |
| **RBXLuaObfuscator** (kosuke14), last commit 2022-07 | single `obfuscator.lua` for Lua 5.1 / Luau, "no loadstring": embeds a Lua-to-bytecode compiler; the author's own README says the output "is too easy to read by using `print`" **[source: README, file list]** | none stated in the repository | not run |
| **zynaa/LuaObfuscator**, last commit 2018 | Python 3.4+: tokenises the script, strips strings and replaces them with ciphered ones decoded by a per-level `__decrypt_N.lua` template, rearranges code; levels 0-3 **[source: README, file list]** | not stated in the files read | run four times (levels 0-3) on `s06_combined.lua`: every run printed `Fatal error occurred.` and wrote nothing; not diagnosed (it needs "Python 3.4.3+ VERY IMPORTANT" per its README; this machine has 3.13) |
| **peardel/fusgato-v1** | Luvit project: compiles to Lua bytecode, applies obfuscations to it (`/bytecode`), emits a generated interpreter (`/vm`) and minifies with luasrcdiet; the author calls it half-working **[source: README]** | MIT | not run (needs Luvit) |
| **Micro-Scripting/LuaU-Obfuscator** | a Roblox ModuleScript (`main.luau`) that re-encodes source as ASCII, hex, binary, URL and Base64 strings **[docs, search snippet]** | see its `LICENSE` | not read in detail |
| **Obscura** | a Roblox DevForum post (MIT, Python, Luau, v1.1.0) appears in search results **[third-party, title only]**; the post could not be fetched and no repository URL was found | MIT (per the listing) | not located |
| **RBXCoreProtect** | fork of RBXLuaObfuscator whose usage example loads the obfuscator from a remote URL at run time | not checked | deliberately not cloned or run (code fetched at run time) |
| **Lua-Obfuscator** (fleecelolll / fleecewtf) | a Windows GUI that drives Hercules; one copy says "source-available, not open source" **[docs, search snippet]** | restricted | nothing to add beyond Hercules |

What this adds to the taxonomy below: the Python-side tools (zynaa, RealObfuscator) generate **loader-style** output (a decryptor template plus encoded strings), which the string-decoder
evaluation already handles in principle; RealObfuscator's VM mode and fusgato are **per-build bytecode VMs** in the same class as IronBrew 2, Luraph and MoonSec, for which each needs its own
handler-template work, which requires real output of the tool.

### How examples were made for tools that could not be run

Where running a tool was not possible or not permitted, the workflow was: read what the tool documents (README, file list, licence), identify the *technique class* it uses, write a small independent generator for that class
(`tests/corpus/tools/gen_loaders.mjs`: ASCII codes, hexadecimal, binary groups, URL escapes, base64, a XOR cipher, reversed text, decimal escapes, `string.char`, split pieces, and a two-layer combination), and measure the recovery
on it exactly as on real tool output (66 examples, each checked on real Lua 5.1 to print what the original program prints). These are labelled **synthetic** everywhere they appear (Examples tab, the obfuscator table, `docs/COMPATIBILITY.md`).
They show that the loader-unwrapping pass works on the technique class; they do **not** show that any particular third-party tool is handled, because none of those tools produced them.

## Third research pass: eight named candidates (October 2026)

Eight projects were named: Lua-Polymorph-VM-Forge, JokerObfuscator, Simple-Lua-Obfuscator, Zero-Lua-Roblox-Obfuscator, Zenfus, Colisseum, Fivem-Strong-Obfuscator and AztupBrew.
Each was cloned into its own empty directory (blobless clones for the small ones, so that files were read as text with `git show` and never checked out), and its README, file list and licence were read before anything else.
Only **three** of the eight contain an obfuscator that can be run (Colisseum, Zenfus, Simple-Lua-Obfuscator). One more (AztupBrew) is represented by a single public output. **Four contain no obfuscator code at all.**

| Candidate | Repository, revision | Licence | What is there | What was done |
|---|---|---|---|---|
| **Colisseum** | `de-TourLLC/colisseum` `5c76832` | AGPL-3.0 | pure-Lua obfuscator, six presets (easy, medium, hard, full, total, fortress) **[source]** | run through the isolated runner; 48 outputs; detection, recovery, tests |
| **Zenfus** | `Zaenalos/Zenfus` `94d4ae1` | MIT | pure-Lua obfuscator: luac 5.4 → instruction tree → passes → generated VM; "based on IB2" **[source]** | run through the isolated runner; 8 outputs (committed); detection, trace, tests |
| **Simple-Lua-Obfuscator** | `CloudHub111/Simple-Lua-Obfuscator` `e4e3d25` | none stated | one Lua file written as a Roblox script template that reads a global `script` **[source]** | run through the isolated runner; 8 outputs (local only); detection, loader unwrapping, tests |
| **AztupBrew** | `noahcoolboy/bad-aztupbrew-deobfuscator` `210e76a` (a third-party JavaScript deobfuscator with one `example.lua`) | none stated | one AztupBrew output (a script that prints "1"); the obfuscator itself is not public **[sample]** | detection (banner and prelude), trace; the JavaScript was not run |
| **Joker Obfuscator** | `0x3yte/JokerObfuscator` `0fb105e` | none | a README with screenshots and links to a website and a Discord server | name recognised only |
| **Zero Lua** | `FakeModz/Zero-Lua-Roblox-Obfuscator` `284d24c` | none | a README for a hosted web tool (zerolua.pages.dev), with a keyword list | name recognised only |
| **Strong FiveM Lua Obfuscator** | `Revuexz/fivem-strong-obfuscator` `7210104` | none | a README advertising a paid service, and `obf.lua` holding a Discord invite | name recognised only |
| **Lua-Polymorph-VM-Forge ("NeuroForge VM")** | `GRUPOMORAESIMOVEIS/Lua-Polymorph-VM-Forge` `7a814fd` | MIT badge, no licence file | **no Lua**: a marketing README, two SVG images, an `index.html`, an hourly workflow and a stamp file | read as text only, nothing run, **treated as untrusted** |

### How the three runnable tools were run

None of them was started through its own command line. Colisseum's `cli.lua` shells out to create directories and checks GitHub for updates; Zenfus's needs an external `luac` and temp files; Simple-Lua-Obfuscator is a Roblox script template.
`tests/corpus/tools/run_isolated.py` instead loads the tool's own `.lua` files into a [lupa](https://pypi.org/project/lupa/) Lua state (the same dev-only dependency the behavioural tests use) with:
a **virtual file system** (only the tool's `.lua`/`.json` files are visible, read-only; anything it writes is captured in memory); `io`, `os.execute`, `os.remove`, `package.loadlib` and the network removed;
`require`, `dofile` and `loadfile` resolved only inside that file system; an instruction-count hook and a CPU-time limit. A tiny driver per tool (`tests/corpus/tools/drivers/`) calls the same library entry point as the CLI, with a fixed seed.
No file of the tools is modified or copied into QuickSilver. `tests/corpus/tools/gen_external.py` writes the fixtures; `verify_fixtures.py` runs each against the original program on Lua 5.1, LuaJIT and Lua 5.4 and records which runtimes print the same thing.

Output is committed only where the licence allows (Zenfus, MIT). Colisseum (AGPL-3.0) and Simple-Lua-Obfuscator and the AztupBrew sample (no licence file) are generated or copied into `tests/corpus/obfuscated-local/`, which is git-ignored;
their tests skip with a reason when it is absent. Everything below that mentions them was measured on those local files.

### Colisseum

* **Presets.** `easy` minifies and renames (`coli_jLjLj` names, a credit line). `medium`, `hard` and `full` add a large tamper-guard block in front of the program (debug hook, executor globals, replaced standard functions, changed string metatable,
  line numbers of error messages; it raises an error with a four-digit code) and encrypt the strings with a keystream decryptor. `total` and `fortress` compile the program for a VM (native tree-walking VM, and a register VM with an encrypted blob) and
  bind the guard into the interpreter.
* **Generation and verification.** 48 outputs (6 presets × 8 programs). `easy` through `full` print what the original prints on Lua 5.4 (`easy` also on 5.1 and LuaJIT). On 5.1 and LuaJIT `medium`, `hard` and `full` print noise or stop inside `string.format` on it: the decryptor needs 5.4 integers.
  `total` and `fortress` were generated and run on LuaJIT, and **only equal the original when run without an instruction-count hook**: their anti-tamper treats the hook as an attack, so the first verification marked them as errored.
  `tests/corpus/tools/run_lua_nohook.py` runs them in a subprocess with a timeout instead; all 16 are then equivalent.
* **A real bug the fixtures found.** The first run of the pipeline on `medium` printed `"p\146ÏHn\169G"` where the program says `"primes: "`. The decryptor multiplies past 2^53 (`seed * 1103515245`). Lua 5.4 integers keep every bit; the sandbox, like Lua 5.1 and Luau, uses doubles and
  silently lost them. The wrong text was inlined as if it were right. The fix is in two parts (see "What changed in the engine"): arithmetic that leaves the range doubles hold exactly is now counted, and when there is any it is evaluated both ways and the reading that gives text is used.
* **Measured** (`tests/results/scorecard.json`, sandbox on): detection 48/48; `easy` 67% → 100% fidelity, `medium`/`hard`/`full` 9–11% → 100%, behaviour identical to the original 32/32; `total` and `fortress` 3% → 3% (reported as VM, confidence 35%, trace offered).
  Without the sandbox the strings of `medium` and above stay encoded.
* **Limits.** The VM presets are not lifted: the program exists only as data for the interpreter, and the register VM's blob is encrypted. The behavioural trace of a guarded preset stops at error `0x6B0C`
  because the trace's stand-in environment defines the executor functions the guard counts. Remove the guard first (Deobfuscate, then Trace). In the plain sandbox `total` runs to the end and `fortress` stops at `0x3E44` (its guard sees that the sandbox's `debug` library is not native).
  Trace identical to the original: 8/48 (the `easy` preset). That number is low because of the guard, and is reported as it is.

### Zenfus

* **What it does.** The README: compile with `luac5.4`, deserialise to an instruction tree, run passes (constant encryption, dead instructions, super-operators, control flow, byte compression), generate a VM around the result. The generated script is a wrapper
  `(function(pack, move, unpack, env, pCall, Err) ... end)(table.pack, table.move, table.unpack, _ENV, pcall, error)` holding `hexToString`, `lua_wrap_state` and `run_vm` and a hex string.
* **Generation.** 8 outputs, committed. The tool's own output runs correctly for **2 of the 8** programs on Lua 5.4; for the other six it fails with runtime errors of its own making (for example `attempt to perform arithmetic on a table value`). Those six are labelled *tool broken* and left out of behaviour claims.
* **Measured.** Detection 8/8 (confidence 0.99, flagged as a VM that is not recovered, confidence of the result 20%, trace offered). Static recovery: none, and none is claimed. Trace: the two correct outputs give exactly the trace of the original program.
* **What it took to trace it.** The sandbox could not run Zenfus at all: it had no Lua 5.4 bitwise operators, no `goto`, no `string.unpack`, no `_ENV`, no 64-bit integers (see below). Each missing piece was found by running the next fixture and reading the first error.
* **Limit.** No lifter for the instruction format was written. It would have to undo constant encryption, remove dead instructions, expand super-operators and then hand a Lua 5.4 chunk to the existing decompiler: a project of the size of the IronBrew 2 module, for a tool that breaks its own output for six programs in eight.

### Simple-Lua-Obfuscator

* **What it does.** Writes the program as a string of decimal escapes, base64-encodes it, cuts it into five-character pieces held in a table and runs `load("<escapes>")()` after decoding. The helper names are fixed in the template (`_0x38ndf`, `_0x93mdw`, `_0x47fjs`, `_0x62tdg`, `_0x29dke`), which is what detection uses.
* **Measured.** Detection 8/8; with the sandbox on, 6% → 100% fidelity and identical behaviour on 8/8. The loader is run alone to read the text it hands to `load`, as in the loader class; the generic layer pass needed one extension (a helper function the loader defines and uses is allowed; a global it only sets is not).
* **Limit.** Without the sandbox the layer is only detected. The licence is unknown, so its output is not committed.

### AztupBrew

Only one output exists in public: the example in a third-party deobfuscator's repository. Its banner `AztupBrew(Fork of IronBrew2): obfuscation; Version 2.7.2` and the eight library locals its VM starts with (IronBrew 2's has eleven) are now signatures.
The IronBrew 2 rebuild stops on it (the serialised layout differs), as it should. With one sample, no claim is made about other settings. The trace reproduces the output of the sample (`1`). The repository's JavaScript deobfuscator was not run and no code from it is used.

### The four repositories without an obfuscator

* **JokerObfuscator, Zero-Lua-Roblox-Obfuscator, fivem-strong-obfuscator**: README-only. They describe or advertise hosted or paid services (a website and Discord server in the first two, a paid licence and a Discord invite in the third). There is no code and no sample of their output, so nothing can be tested; QuickSilver recognises the names when a script mentions them and caps the confidence at 0.3.
  The feature lists they print ("anti-decompile", "28 layers", "Galois dynamic dispatch") are marketing text and are not treated as facts about the output.
* **Lua-Polymorph-VM-Forge**: the project is called "NeuroForge VM" in its README, but the repository holds no Lua. Its files are a README of generic prose, two large SVG images (one a "Download" button that links to a GitHub Pages site), an `index.html` whose body is a hidden `div` of
  base64 text and a script that XOR-decodes it with a key and `document.write`s the result, and a GitHub Actions workflow with randomised names that runs every hour and appends timestamps and random numbers to a stamp file (a way of making a repository look active).
  Nothing in it was run, the HTML was not opened in a browser and the hidden payload was not decoded: that is exactly what a page built to deliver something else would want a reader to do. What it contains cannot be established from the outside, so it is **recorded as untrusted** (in the family registry and here), and nothing from it is integrated.

### What changed in the engine, and why

Every change below was prompted by a fixture, not by an assumption, and each has a test (`tests/candidates.test.mjs`, `tests/sandbox.test.mjs`). The 336 pre-existing fixtures were re-measured afterwards: fidelity and behaviour are unchanged for all of them; one confidence figure rose (0.55 → 0.75).

* **Sandbox, Lua 5.3/5.4 features**: bitwise operators on 64-bit integers (strings are refused as in 5.4), `goto` and labels, `string.pack`/`unpack`/`packsize` (no alignment options), a free `_ENV`, `math.maxinteger`. Checked against a real Lua 5.4 on programs that print integers and strings.
* **Numeric modes** (`numMode`): `watch` counts `+ - *` results on whole numbers that doubles cannot hold exactly; `int64` computes them exactly (BigInt only where needed). The decoder evaluation and the trace use them together: where the readings agree nothing is decided, where they differ the one that gives text is used and the note says so,
  and if neither does the sites are left alone. A test with a decoder written for doubles checks that the doubles reading wins when it is the readable one.
* **Decoder evaluation**: a function containing a linear-congruential keystream (`1103515245` and `2147483648`) is a decoder from its first call (a script with two hidden strings has two call sites, below the threshold for machine-named functions). Calls to the program's own helpers
  that return numbers are no longer counted as decoders that failed.
* **Colisseum tamper guard** (`src/recover/colisseum.js`): removed when the block contains all three of the error brand, the hook global name and the key of its first check.
* **Layers**: a helper function the loader defines and uses is allowed; a global that is only assigned is not (the check used to count the assignment target as a use).
* **Dead code**: an empty `if` whose test is arithmetic over locals that only ever hold numbers is dropped (`if n * 0 ~= 0 then end`).
* **Printer**: a label was printed as `::undefined::`. Any Lua 5.4 output with `goto continue` was written back broken.
* **Confidence**: a VM that the input showed and no step rebuilt now lowers the score and offers the trace even when clean-up has rewritten the signature away (the AztupBrew prelude is gone after aliases are inlined; the score was 0.9 for a script that was still a VM).

### What was not done, and why

* No lifter for Zenfus, Colisseum `total`/`fortress` or AztupBrew. Each is a separate VM format and a project of its own; the fixtures show where the sizes lie.
* No attempt to make the trace hide that it is a sandbox from a tamper guard. The guard is removed where it can be (static), reported where it cannot.
* Nothing was fetched from the four README-only repositories' websites or Discord servers.

## Fourth research pass: two supplied scripts, and more open-source obfuscators (October 2026)

The request was to study two scripts a user supplied, to see how their obfuscation works and how it can be undone without running anything, to teach the engine what was learnt, and to find more open-source obfuscators so that scripts like these are easier to analyse.
The two scripts are **not part of this repository or of the site** (they live in the git-ignored `tests/corpus/user-local/`; the tests about them skip when the files are absent). What is recorded here is the technique, not the scripts.

### What the two scripts taught

| Script | What it is | What can be recovered |
|---|---|---|
| a wrapper around a MoonVeil script (about 300 KB) | a remote loader inside `pcall`, a print, and a zstd + base64 payload opened with Roblox's `EncodingService:DecompressBuffer(..., Enum.CompressionAlgorithm.Zstd)` | the payload (about 500 KB) expands to a **MoonVeil 2.0.25** script, which is read back to readable Lua, and its VM-compiled program (55 functions, about 10,650 instructions, behind an encrypted stub) is rebuilt from the VM's data |
| a Kirus script (about 640 KB) | one expression: **Kirus 1.5**, a bytecode VM with a custom base-85 container | detected and outlined (29 prototypes, entry 15, 60,433 bytes); see the notes below for how far the program inside was taken |

Verified by measurement: the zstd frame, the MoonVeil banner and structure, the decoded constants, the container outline of Kirus, the identifier strings it builds from XOR pairs, and that the two files share no plain string beyond standard-library names.
Established by the engine, statically: the layout of MoonVeil's VM data and the meaning of its interpreter's cells (read off the interpreter), the encrypted stub's key (a 32-byte value built from constants of the script plus the number 189112, found by search and confirmed because the plain text then parses to its last byte), and the program, rebuilt by partially evaluating the interpreter's handlers. Not established: that the rebuilt program behaves like the original (nothing was run); what the remote loader fetches (the host is denied by the environment's network policy and nothing was done to get around that); and who wrote either script.
Nothing in the files shows copying or a false ownership claim, and absence of a visible signal is not a finding of originality. The AI / skid check on the Origin tab was not used as evidence.

MoonVeil and Kirus are closed-source and hosted; no copy of either tool was available, so what is written about them comes from these two files only.

### Open-source obfuscators read and run in this pass

Each was cloned into its own directory with no checkout (files read with `git show`), its README, file list and licence read first, and then, where it was a pure-Lua or plain-JavaScript tool, run through an isolated runner. None was started through its own command line, installer or server.

| Tool | Repository, revision | Licence | What it is | What was done |
|---|---|---|---|---|
| **AzureVM** | `LionHub-Pino/AzureVM` `0e01e7a` | MIT | Lua 5.1 bytecode VM obfuscator **built on Prometheus** (it says so); presets Fast, Balanced, Luraph, Luraph14, AzureGod15, AzureGodUltra **[source]** | run in the isolated Lua runner (`tests/corpus/tools/drivers/azurevm.lua`); 48 outputs committed; detection by header, library prelude, `__az_retry_` locals and `[=[LPH` payload; VM presets flagged as not recovered; Balanced partly recovered |
| **simple-lua-obfuscator** (the page) | `iamsopotatoe-coder/simple-lua-obfuscator` `bd4d44e` | MIT | one `index.html`: comment stripping, regex renaming, strings as number lists for a `_D` decoder, numbers as sums, junk | the page's own JavaScript run unchanged under Node with no network and only the output folder writable (`gen_html_obfuscator.mjs`); 8 outputs committed; the `_D` strings are now computed statically |
| **Clyde** | `sfr-development/Lua-Obfuscator-Clyde-Protection` `61f86b6` | MIT | Luau obfuscator in TypeScript: AST passes, stack VM, register VM, LZSS and cipher layers (`max`); the README warns of rebrands | compiled with `tsc` and run under `node --permission` with only the output folder writable (`gen_clyde.mjs`); 25 outputs committed; rename and string/flow modes recovered, VM modes flagged |
| **Stealth-X** | `naells/Stealth-X-Obfuscator` `3771bca` | none | a README and five sample outputs of one 11-line program; the tool is a hosted web app | the samples read as text only, never run; a signature from the header, the `STX@` program string and the 32-bit handler table; nothing stored |
| **LennyObf** | `asstralnetwork/LennyObf` `c764942` | AGPL-3.0 | a fork of Prometheus | read only; not run; Prometheus signatures already apply to its steps |
| **PY44N/Lua-Obfuscator** | `PY44N/Lua-Obfuscator` `1ec634a` | none | archived; carries prebuilt IronBrew 2 binaries and a minifier | read only; binaries not run |
| **luaobfus** | `fxip/luaobfus` `653ada0` | MIT | a Windows C++ project with a bundled `lua.dll` | read only; not built |
| **Prometheus-DeobfuscatorV2** | `0x251/Prometheus-DeobfuscatorV2` `d06f1f5` | none | a Lua deobfuscator for Prometheus; its README says the repository was used to test an AI model on reverse-engineering help | read for methodology only; not run |

Findings worth recording:

* AzureVM's preset names contain "Luraph"; its README says they are historical compatibility names and that the project is not Luraph. Its payload is tagged `LPH`, the same three letters Luraph uses. That is a naming overlap, not evidence of shared code, and detection does not treat it as Luraph.
* The Clyde README lists two sites for "Clyde V3" and warns of "known skids rebranding Clyde". The header seen in the fixtures names a third address. A script carrying that header may come from the hosted service rather than from the open-source build; nothing here says who made any particular script.
* Before a signature existed, the Stealth-X VM presets were rated as plain minified code at 90% confidence. That was wrong; they are now named and flagged as not recoverable.
* Stealth-X's VM and Kirus share the outer shape `return setmetatable({ ... }, {}):name(...)` and nothing inside. This is recorded as a reason not to treat that shape as a fingerprint.

### How the isolated runners were set up

`tests/corpus/tools/run_isolated.py` (Lua tools) was extended so `require` follows the tool's `package.path`. For JavaScript and TypeScript tools, `node --permission` was used with `--allow-fs-read` for the tool's folder and `--allow-fs-write` for one fresh output folder only; no network, child process or worker permission was given. Output of the three MIT tools is committed (`tests/corpus/obfuscated/{azurevm,simple_html,clyde}`, with manifests that record the revision, the seed and which runtimes behave like the original); anything under a licence that does not allow it stays in the git-ignored `tests/corpus/obfuscated-local/`. `verify_fixtures.py` runs each output on Lua 5.1, LuaJIT, 5.2 (Clyde needs `bit32`) and 5.4 and records which of them print what the original prints; `vm-max` of Clyde runs on none of them here and is labelled.

### What changed in the engine, and why

Each change was prompted by a file, and has a test (`tests/zstd.test.mjs`, `tests/uploads.test.mjs`, `tests/opensource2.test.mjs`).

* **zstd decoder** (`src/core/zstd.js`, RFC 8878): frames, raw/RLE/compressed blocks, Huffman literals (one or four streams, FSE or direct weights, treeless), FSE sequences, repeat offsets, content checksum, an output cap. Compared with Node's own zstd on 11 kinds of data at four levels, multi-frame input and corrupted input.
* **Loader unwrapping**: `EncodingService:DecompressBuffer(buffer.fromstring(base64.decode"..."), Enum.CompressionAlgorithm.Zstd)` inside `loadstring(buffer.tostring(...))(...)` is read statically and replaced by the payload (spliced, or wrapped in a function called with the same arguments when a local could capture a name). Another compression algorithm is reported, not guessed at. Detection runs again on the payload, so that the report names the obfuscator inside.
* **MoonVeil 2.0.25** (`src/recover/moonveil.js`): base-85 text (RFC 1924 alphabet) plus XOR strings, `bit32` numbers, the permutation bootstrap of helper names, and cell variables read as fields. Detected by structure as well as by banner. A function compiled to its VM is rebuilt from the VM's data by `src/recover/moonveil-vm/` (see ARCHITECTURE.md); the confidence is medium and the report says the result was not compared with a run.
* **Kirus 1.5**: detected from the banner and from the entry call; flagged as not recoverable.
* **Single-page obfuscator**: the `_D` decoder is recognised only in the exact form the page writes and computed on the literal lists (`src/recover/simple_html.js`); static fidelity went from 49% to above 98% on the eight fixtures, with no sandbox.
* **Performance**: `simplify` used a tree walk per statement and took 84 s on the 517 KB payload; reference indexes make it 17 times faster there and 3 times faster on the Kirus file with byte-identical output.
* **Printer**: a synthesised parenthesis changed the column the next line was measured from, and a long array holding folded negative numbers was packed on the first print but not after being read back; both made "printing it again gives different text" and failed validation. Both are fixed and tested.
* **Detection rules** for AzureVM, the page obfuscator, Clyde (header on VM modes, escaped `string.char`, XOR decoder), Stealth-X, MoonVeil and Kirus, each checked against every original and every output of the already supported tools for false positives (none).

### What was not done, and why

* No lifter for the Kirus VM, AzureVM, Clyde's VMs or Stealth-X's (MoonVeil's is done, for one script). Each is a separate format and a project of its own; the Obfuscators tab shows where the size of the remaining work lies.
* The remote loader was not fetched and nothing was run: the task forbade executing untrusted payloads, and the loader's host is denied by the environment's network policy (the setting is *Network access* of the environment; the policy was not worked around).
* No claim about copying or false ownership. The files give no evidence either way, and absence of a visible signal is not a finding of originality.
* Hosted tools (Stealth-X, Clyde V3, MoonVeil, Kirus) were not used.

## Prompt IX: the open-source backlog, run in isolation (November 2026)

The tools below were read as text first (README, entry points, the code that writes output), then **run only in isolation**: pure-Lua tools in a Lua state with a virtual read-only file set, no `os`/`io` escape and an instruction budget (`tests/corpus/tools/run_isolated.py` and the drivers in `tests/corpus/tools/drivers/`), Python and Rust tools in a Linux user/mount/net/pid namespace with the host's directories masked, no network, every capability dropped and a wall-clock kill (`tests/corpus/tools/sandbox_run.py`, proved by `tests/sandbox.test.mjs`). Nothing was run on the host and no execution restriction was bypassed. Results (per revision, configuration and sample) are in `data/research/format-db.json`, generated from the measurements; this section is the reading behind them.

| Tool | Read | Run | What it writes | Result |
|---|---|---|---|---|
| **Obscura** (MIT, Python, Luau) 1.0.0 / 1.0.1 / 1.1.0 | README, git history, the layers | sandbox, `gen_obscura.py` | header `--!nocheck/--!nolint/-- Obscura [seed]`; renaming, string cipher, number wrappers, flattening with opaque predicates, dead code, table indirection, anti-tamper (executor probes), VM with encrypted constants | all non-VM configurations recovered at 89% to 100% on the three revisions and checked on Luau; VM builds identified, not recovered |
| **XFuscator** (efrederickson, 2013, no licence) | README, library | isolated Lua state, `drivers/xfuscator.lua` | constants pool, renamed locals, optional XOR strings, the program as an array of scaled character codes run by `loadstring`, a length check | step 2 read by finding the scale; 88% to 100% where names survive; precompile not generated (needs a 32-bit Lua) |
| **LuaXen** (MIT) | README, example | isolated, `drivers/luaxen.lua` | IronBrikked VM (LZW) and an AST stage: state loops on a fractional literal, numbers and strings behind metamethod arithmetic | AST stage 88% to 100%; IronBrikked identified, not recovered |
| **Zartha** (MIT, Lua 5.1) | README, pipeline, VM tree | isolated, `drivers/zartha.lua` | a generated VM with per-build opcodes, optional encryption, flattening, anti-tamper, minification | identified (watermark, prelude), not recovered |
| **FusGato v1** (MIT, Luvit) | README, source | isolated, `drivers/fusgato.lua` | an IronBrew-style VM behind the copied IronBrew watermark and its own credit line | identified (and no longer taken for IronBrew 2), not recovered; the tool's own output is wrong on 12 of 16 builds |
| **RealObfuscator** 2.2.1 (GPL, Rust) | README, docs, manifest | crates downloaded with `cargo vendor` (nothing of theirs ran on the host), built offline in the sandbox, run there | rename / lightweight pool / native (lazy strings, integer expressions, dispatch with decoys) / register-bytecode VM | rename, lightweight and native recovered (76% to 100%); VM identified, not recovered; fixtures kept local (GPL) |
| **zynaa/LuaObfuscator** (Python, 2016/2018, no licence) | README, source | sandbox, `gen_zynaa.py` (random seeded, clipboard off) | U+202A identifiers, XOR-ciphered strings, rearranged code | 76% to 98% where the tool's output is valid; some outputs are the tool's own failures |

Two things from the reading changed the code rather than the tables. First, the families overlap in what they print: FusGato prints IronBrew's watermark, so a watermark is a copied string and the credit line decides. Second, a recovery that was confidently wrong was found by the new fixtures (FusGato reported as recovered, confidence high) and fixed in the detector, not in the report.

The collection's **Unknown**, **VM Compressed** and **MinifiedLua** folders (and the Luraph files without a version banner) were looked at one by one. They are mostly not obfuscated by a tool with a signature: remote loaders, scripts that fetch a UI library, plain and minified scripts, a program stored as an array of numbers (a numeric-array encoding with a small permutation, run through an alias of `loadstring`), a spelled-out credit entry, and seven bootstraps of Luarmor (a key service that downloads its init script and caches it with `writefile`). They are now classified (`src/detect/classify.js`) instead of "unidentified", and the page says when the program is not in the file.

## Prompt X: audit, measurement, and what a derivative of a known tool showed (November 2026)

**Audit.** The status of every target named in the prompt is generated, not written: `node tools/formats/audit-status.mjs --write` produces `docs/AUDIT.md` from the measured database
(`data/research/format-db.json`), the public-sample records, the collection evaluation, the source tree (does the module a capability needs exist?) and `docs/KNOWN-ISSUES.md`. A target with no
measurement says so.

**Measurement.** A result is described in six categories that are never averaged into one (`src/core/metrics.js`, one definition each, shown on the dashboard and in `format-db.json`): identification,
structural recovery (F1 of the parent>child node-type edges of the two syntax trees), semantic recovery (the existing token-stream fidelity), runtime equivalence (counted only where the tool's own output
behaved like the original, so a tool defect is charged to nobody), completeness, and stability. Completeness was first defined by the detector alone and read 39 of 39 for Obscura VM builds that still hold
the VM; the first full run showed it, and the definition is now both "the output shows no obfuscation evidence, a leftover VM included (found by its function records and its interpreter, not by a name)"
and "the engine's own report lists nothing unresolved". Runtime equivalence is necessary, not sufficient: a VM left in place runs like the original.

**Tool-output verification, redone with bounds.** The earlier verification runs of LuaXen and Zartha hung (an instruction-count hook cannot interrupt a hang inside a C function); they were run again as
one subprocess per fixture with a wall-clock limit. LuaXen: 5 of 22 outputs equivalent; the IronBrikked and "both" outputs (14) do not run on any of the six reference runtimes (Lua 5.1/5.2/LuaJIT stop in the
generated VM with "attempt to compare nil with number", which the wrapper masks as "LuaXen: (internal)" until the message is read out of a copy; 5.3/5.4 have no `math.ldexp`; Luau stops with "attempt to call
a nil value"). Zartha: 16 of 54 equivalent; in s01 and s02 the compiled program prints a wrong list of primes and `nil` for booleans; `antitamper` runs do not finish in 15 s; `constants` and `all` fail with
"attempt to call field '?' (a nil value)". None of this is charged to the engine.

**A verification artefact fixed.** The isolated runner removed `os.exit`, `dofile` and `loadfile`, and Hercules' anti-tamper block (which only asks whether they are functions) read that as tampering, so all seven 1.6.2 `mod-antitamper` outputs counted as the tool's own errors. The runner now provides them as inert stubs that raise when called (the rest of the isolation is unchanged); the outputs are equivalent to the original on Lua 5.1 and 5.4, and the configuration is judged at runtime again.

**What a derivative showed.** LennyObf (a renamed copy of Prometheus with its own watermark and its own anti-tamper block) was run in isolation through the unmodified generator. It is found by structure
(Prometheus is named without the original's banner), yet recovery fell apart, which the original's fixtures could never have shown: Weak 4%, Medium and Strong 3%, AntiTamper 40% (the original tool: 58%, 54%, 44%, 96%).
Three causes, each a rule that was written for the exact text of the first tool, each now generalised and tested on synthetic inputs (and the negative cases): the outer-wrapper reader required the wrapper
to be the only statement (the fork puts a watermark statement before it; a preamble is now passed over only when it declares no local, which would otherwise capture names); the anti-tamper remover
required one writing of the block (it is now recognised by the marker message plus self-containment: it reads nothing of the program, so with the script untouched it changes nothing); the
ProxifyLocals reader required inline accessor functions and `name = value` fields (accessors declared apart and fields written as strings, which the evaluator produces, are now read). A compiled guard
(the program under `if flag then ... return end`, the failure path after it) is taken apart by the same assumption. After: Weak 50%, Medium and Strong 34%, AntiTamper 97%. Medium and Strong stay below the
original tool's numbers: the string decoder of the fork's EncryptStrings is still reached through objects the evaluator does not run (KNOWN-ISSUES 38).

**VM profile.** The Obscura VM (all three revisions, plain and hardened builds) is still not lifted, but what its data holds is now read without running the program: functions, bytes of instructions, and the
decrypted constants, by running only the statements that set the constants up (`src/recover/vmprofile.js`). The hardened 1.1.0 build keeps constants in per-function records opened by a function that
takes the record; its set-up includes a loop that salts each record with the hash of its code, without which the opener fails (found by running it). On all 39 Obscura VM fixtures every string of two or
more characters of the original program is among the constants read. It is reported in the output header as "NOT lifted". A lifter needs the per-build opcode aliases and operand layouts read out of the
generated interpreter, the rolling-XOR bytecode decode and the hardened record keys; Zartha, FusGato and IronBrikked need the same three things for their own formats.

**Not reachable or not done.** `kosuke14/ByteLuaObfuscator` could not be cloned (not a public repository from this environment); no other new obfuscator was found whose output is not already covered.

## Prompt XI: lifting what could be lifted, joining what was never bytecode (November 2026)

**Obscura plain VM, lifted.** The source of the tool (MIT, read as text) says the VM is a Lua-5.1-like register machine with boxes for captured locals, byte jumps, per-build opcode aliases and a rolling-XOR key. Nothing is a table of opcode numbers: each handler of the script's own interpreter is split into the operands it reads and a canonical body (names by first appearance, operands by first use), recognised against 46 templates, decoded with the script's own key, and the Lua 5.1 chunk goes to the decompiler that already reads IronBrew 2. All 13 plain builds read with no handler left over. Measured against the originals (structure / semantic / runtime): 1.1.0 vm 6%→98% / 4%→91% / 7 of 7 identical on Luau; 1.0.1 vm 3%→97% / 3%→89% / 2 of 2 judged identical (four of the six 1.0.1 outputs are wrong in the tool itself, see KNOWN-ISSUES 45). Confidence for these is high, because nothing is left unresolved and the output runs like the original; the hardened builds stay at low and say so.

**MoonVeil 2.0.26 was never a bytecode VM.** The reference sat at 21% because the three-step diagnosis stopped at the wrong place: the VM reader's first check failed ("the interpreter does not have the expected shape"), but the largest "interpreter" it picked was the script's own program, a table of control-flow-flattened factories `function(ctx, cells) return function(...) ... end end` that build each other through `ctx:NAME{cells}`. `src/recover/moonveil-join.js` puts them back: the names of the table's positions are read before the builder is rewritten, every site becomes the closure of its factory (cells become the enclosing variables, `ctx._.x` the global `x`), and boxed cells that closures do not share across loop iterations become variables. Reference: structure 0.2%→67%, fidelity 21%→34%, 77 of 81 of its literals found. MoonVeil 2.1.0 is a bytecode VM again (KNOWN-ISSUES 46), so the reference-less samples are unchanged.

**A generic bug found on the way.** The dataflow pass dropped the declaration of a variable whose first value it forwarded even when the next statement assigned it again, leaving an undeclared global (`value, d = Instance.new, "ScreenGui"`) in the output of every register-style recovery. It now keeps `local d`. No fixture row changed, which is why it had survived.

**Not done, and why.** Hardened Obscura (four obstacles, KNOWN-ISSUES 43), Obscura 1.0.0 (a stack machine), Zartha, FusGato, IronBrikked, RealObfuscator vm (each its own format), MoonVeil 2.1.0 (reader written for 2.0.25), SnowVeil (the key stream's seed depends on probed engine answers). Luraph: structure names the era (78% leave-one-out) and not the version (37%): no change to what the report claims. No new third-party tool was run this iteration; the Obscura source was read as text.

## Technique taxonomy and what each needs

| Technique | Seen in | Static recovery | Needs execution | Notes |
|---|---|---|---|---|
| Minification, name mangling | all | formatting + heuristic renaming | no | original names are not recoverable; names are guesses from usage |
| Numeric/arith rewriting | Prometheus, Hercules | constant folding | no | |
| String splitting, escapes | Prometheus, Hercules | folding | no | |
| Constant tables with accessor | Prometheus, Hercules | partial | decoder evaluation | |
| String encryption (stream cipher, Caesar) | Prometheus, Hercules, others | no | decoder evaluation (sandbox) | evaluated twice in different orders; only agreeing results are used |
| Opaque predicates, junk code, wrappers | Hercules, Prometheus | yes | no | |
| Anti-tamper blocks | Prometheus, Hercules | yes when separable | no | embedded inside a VM they cannot be removed statically |
| Proxy locals | Prometheus | yes | no | |
| Layered `loadstring` | many loaders | no | capture the payload | `Trace` records every chunk passed to `load` |
| Keystream string decryptor (linear-congruential) | Colisseum medium and above | no | decoder evaluation (sandbox), with Lua 5.4 integers | the multiplication passes 2^53; doubles give noise |
| Tamper guard block | Colisseum, Prometheus, Hercules | yes when the block is recognisable | no | removed by its strings, not run |
| Control-flow flattening / register VM | Prometheus Vmify, Hercules VM | Vmify only | trace | see below |
| Bytecode VM generated per script (Lua 5.4 stream) | Zenfus, Colisseum total / fortress | not implemented | trace (not for guarded presets) | detected and reported |
| Base64 pieces handed to `load` | Simple-Lua-Obfuscator | yes | the loader alone (sandbox) | |
| Custom bytecode VM with per-file keys | IronBrew 2, Luraph, MoonSec | needs per-VM work | trace | |
| Compiled Lua chunks | Hercules | reader and executor exist | trace | decompiling to source is a separate problem |

## What is not recoverable (and what is done instead)

* **Original names, comments, layout.** They are not in the output of any obfuscator that mangles names. The renamer guesses names from how variables are used; it is labelled a guess.
* **Virtual-machine protected code.** The program exists only as data interpreted by generated code. Recovering source means lifting the VM's instruction set back to Lua, which has to be done per VM
  (opcode tables and operand encodings change per file in Luraph and IronBrew-style VMs). Without sample output of the real tools this cannot be written or tested honestly, so it is not claimed.
  What is offered instead is the **behavioural trace**: the script runs in the sandbox against stand-in objects and the services it asks for, the objects it creates,
  the properties it sets, the URLs it tries to fetch and the code it loads are listed. On every Prometheus and Hercules fixture whose own output behaves like the original
  (190 files, including the VM and bytecode modules), the trace of the obfuscated script equals the trace of the original program (`tests/trace-scorecard.mjs`).
  A trace describes one run; it is not source.
* **Luraph v15.1.** No public description and no sample output were available. QuickSilver detects a Luraph banner and offers the trace; it does not claim more.

## Prompt XII: Zartha lifted, XFuscator's constants, and what the near-gate partials really were

**Zartha (MIT, Lua 5.1).** Read as text: `Vm/TreeGenerator.lua` (how each instruction becomes a leaf, how the constants are shuffled, padded with junk and encrypted, how closures carry an upvalue map, which instruction pairs are merged),
`Vm/OpCodes/*.lua` (one template per Lua 5.1 opcode, with random scratch-cell indirection in MOVE / LOADK / GETGLOBAL / SETGLOBAL / LOADBOOL), `Vm/Resources/ControlFlowFlattening.lua` (arithmetic predicates and a binary search of them around the leaves),
`Vm/Resources/ModifyInstructions.lua` (the `_CRASH()` macro, the blanked instruction in front of it) and `ConstantEncryption.lua` (a stub). The generated fixtures (isolated runner, seed 1337) were then read leaf by leaf.

*Technique.* The dispatch of each function is evaluated for every value of the counter (`src/recover/zartha-vm.js`): a test that depends on nothing but the counter is decided, which is all the flattening is; what is left is the code of instruction p. The
scratch cells that hold a number or a name of the machine are replaced by what they hold, names are replaced by their roles (`Stack`, `Temp`, `Constants`... whatever the build called them), and the text of what remains is recognised as one Lua 5.1 instruction
(or two, where the generator merged a pair). The upvalue map of a closure becomes the MOVE / GETUPVAL words after CLOSURE; the constants are decoded with the script's own decryptor, shift and tag bytes; the number of parameters is read from the registers
the code reads before it writes them. The chunk goes to the decompiler that already reads IronBrew 2, Obscura and Hercules. Nothing of the program runs.

*Measured.* 54 of 54 fixtures lifted and structured. The 39 builds whose strings are readable behave like the **original** program on Lua 5.1 (stdout equal, reference runtime); 16 of them are builds the tool's own output gets right, 8 are builds
where its output prints a wrong list of primes (the generator's SETGLOBAL stores the name, its LOADBOOL reads a cell it never wrote), and 15 are builds where its output errors or does not finish (the anti-tamper macro, s08). The 15 `constants` / `all` builds
mask each string with a key drawn per constant that is written nowhere; they are lifted with their strings masked, the masked constants are counted (identifiers that are not identifiers, control characters in text) and the confidence stays below high.
The comparison with the original is stronger than the audit's rule (runtime equivalence is judged only where the tool's own output is right): that rule is unchanged and keeps its numbers.

*What the work needed beyond the format:* the decompiler folds an open call chain (`tonumber(e:match("%d+"))`) into a condition; the results of a call nothing named are written out before a condition when the chunk has no local names; a global or a
method whose name is not an identifier is written as `_G["x"]` or with the object passed first; and a generic pass reads a table of constants that is only read as the constants (`constants.inline`). The new unit test of that pass caught a real fault
in its first version (a store into the table was treated as a read).

**Near-gate partials, one by one.** XFuscator default / uglify / nostep2 / notamper: the constants table was the residual (s02 fidelity 0.48 -> 0.76, s06 0.60 -> 1.00; the s02 remainder is names the tool drops by design). Hercules `mod-VirtualMachine` s06: the
tool's own output leaves two constants out (it measures the pool with `#`); the reader refuses rather than guess, which is the right answer. IronBrew 2 `strings`: the remainder is IronBrew's own inlining and constant folding plus the local names a stripped
chunk does not have; the output is the program that was compiled. None of the three is a recovery gap that more work on the recoverer would close.

**FusGato (investigated, not lifted).** An IronBrew 2 fork (it prints the credit line) with a bit-string container and an interpreter that switches on the instruction index, one handler per instruction, operands read from the decoded table. That is Zartha's
shape with the operands in data; the leaf reader plus a container reader would lift it. Recorded as `xii-fusgato-architecture` in `data/research/format-notes.json`.


**Before and after (`docs/AUDIT.md`, same fixtures, regenerated).**

| Target | Structure | Semantic | Complete (detector finds nothing, engine lists nothing unresolved) | Runtime same/judged (not judged) | Status |
|---|---|---|---|---|---|
| Zartha | 4% -> 92% | 4% -> 80% | 0/49 -> 39/54 | 16/16 (38), unchanged: the audit judges only builds whose own output is right; the lifted program matches the original on 39 | unsupported -> mixed (verified, partial) |
| XFuscator | 19% -> 100% (after of the previous audit: 90%) | 81% -> 96% | 38/40, unchanged | 32/32 (8) | partial -> mixed (verified, partial) |

The 15 Zartha builds that are not complete are the ones whose strings are masked with a key the generator never writes; they stay below high confidence on purpose.
