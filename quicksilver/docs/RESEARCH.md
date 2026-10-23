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

### MoonSec V3 **[unverified]**

* Searches returned SEO filler pages ("Moonsec V3 Deobfuscator" with no method) and unofficial PyPI wrappers around the vendor's obfuscation service (`moonsectesting`, marked "NOT OFFICIAL"), whose option names mention a `maxsecurity` mode and an `antitamper` option that "uses loadstring or load" **[third-party]**.
* A directory listing mentions a Python "MoonSec V3 bytecode dumper" (`hemusuku86/GoonSec`); it could not be cloned and was not examined **[unverified]**.
* Banner used for detection: `This file was protected with MoonSec V3`.
* **What QuickSilver does:** banner detection and the behavioural trace.

### MoonVeil **[docs, partial]**

* Documentation repository: `https://git.openpunk.com/CPunch/MoonVeil-Docs`. Search snippets show macros `MV_VM` (virtualise a block), `MV_ENC_FUNC` (virtualise and encrypt a function, key evaluated at run time), `MV_CFF` (control-flow flattening) and `MV_OMIT` (exclude a block), and the advice to obfuscate only selected parts because virtualised code is slow **[docs, snippets]**.
* The pages could not be fetched, so MV_VM and MV_CFF behaviour is not known beyond their names.

### LuaObfuscator.com **[unverified]**

* No page from the site could be read. Search results were unrelated tools. Nothing is claimed about its protection levels.

### PSU **[third-party, thin]**

* Community threads mention "psu obfuscator"; one reply describes obfuscators of this kind in general as "compiling the script into bytecode, mixing it up, and running it through a Lua-in-Lua VM" **[third-party]**.
* Document titles on a file-sharing site list "PSU Obfuscator 4.0" and "4.5.A" **[third-party]**. No macros, options or format were found.

### Clyde Protection, XHider, Goofyscator, IronVeil, 77fuscator, Synapse Xen, WeAreDevs **[unverified]**

* No usable documentation or samples were found for any of these. They are registered so that a script naming them in a banner is reported accordingly, with the confidence capped at what a banner can justify.
  QuickSilver makes no recovery claim for them.

## Other obfuscators and tooling seen (not implemented)

* **PELock Lua Virtualizer** (commercial; claims polymorphic string encryption, anti-debugging and self-integrity checks) **[docs, listing]**.
* **obfuscate.lua**: encrypts scripts with a PRNG-based XOR and prepends the decryptor **[docs, snippet]**.
* **zynaa/LuaObfuscator**: small Python tool with levels 0-2 **[docs, snippet]**.
* **Anul** (paid, BuiltByBit), **LennyObf**, **PY44N/Lua-Obfuscator**, **Luarmor** (loader-style service): names only.
* **LuaPro**: a pure-Lua AST toolkit that lists deobfuscation (constant folding, dead-code elimination) as not yet implemented **[docs, snippet]**.

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
| Control-flow flattening / register VM | Prometheus Vmify, Hercules VM | not implemented | trace | see below |
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
