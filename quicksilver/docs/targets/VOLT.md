# Voltfuscator (Voltils) — research report (Prompt XXII)

## 1. Identity and version

| | |
|---|---|
| Name | **Voltfuscator**, by Voltils ("Volt" in Prompt XXII) |
| Site | `voltils.cc` (dashboard, Discord bot, HTTP API `POST /v1/obfuscate`); not reachable from the build environment |
| Kind | Hosted, closed obfuscation service. The public repository holds documentation, examples, a demo GIF and a 1 KB file containing only an advert — **not** the obfuscator. |
| Latest verifiable version | **8.1**, per the repository README (`# Voltfuscator 8.1`, commit `9c7ae5c3`, 2026-11-17) and the banner in its examples. An earlier search snippet said v7.5; the repository supersedes it. |
| Presets | Normal (default; replaces the former Max) and Ultra |
| Runtimes | `lua51`, `luau`, `roblox`, `studio`, `executor` |
| Source macros (seen in the example) | `--!vlt:vm` (virtualise this function), `--!vlt:cff` (flatten its control flow), `VLT_OBFUSCATED` (true in protected builds), `VLT_LINE` |

**Not to be confused with** other similarly named tools: no other "Volt" Lua obfuscator was found.

**Sources:**

- `github.com/usernamethisorthat/Voltils-Voltfuscator` (README, read in full).
- Search results for `voltils.cc`.

## 2. Evidence used

Only the **vendor's own published paired sample** from the repository above was used:

- `example.source.lua` (687 bytes) is the original;
- `example-Normal.lua` (99,918 bytes) and `example-Ultra.lua` (201,153 bytes) are that source protected with v8.1, runtime "Luau/Executor".

The repository states no licence, so the files are kept git-ignored in `local/volt/` with a provenance note, and are not redistributed. They were read as text, and run only:

- in this project's sandbox interpreter;
- in the Lua oracle (real Luau 0.739) with a stand-in executor environment (`tools/volt/executor-prelude.lua`).

## 3. Architecture of an 8.1 output (measured on both presets)

```
-- Presets / -- Source / -- Runtime                         header comments
([[File protected by Voltfuscator v8.1]]):gsub(".+", function(v) __voltfuscator_<id> = v end)
return ({ EK = entry, Ed = runtime, ER = environment, EM = constant decoder, EI = index, Ei = data }):EK()
```

### Constant pool (`EM`, `EI`, `Ei`) — decoded, checksum-verified

**`EI`** is an index: pairs of base-42 varints, mapping key → (offset, length) in `Ei`. It carries guards:

- its own length, the number of entries (111) and the total length (3955) are checked;
- a running checksum covers the whole index;
- a failure raises `Voltfuscator: C052`.

**`Ei`** holds the constants as base-85 text. Each key's slice is deciphered by a byte stream seeded from `key + c + Fq`, where c is a per-build constant. Each decoded value carries:

- a 4-byte length;
- a 4-byte checksum.

A wrong key, or a wrong `Fq`, raises `C052`, so **a decode is self-verifying**.

**`Fq`** is 0 while the environment check in `EK` runs. Afterwards it is set to a value `EK` passes only if the check succeeded (60779 in both samples). The runtime's own constants decode only under that value.

**Implementation (`src/recover/volt.js`, step `volt.constants`).**

- The method table is compiled in the sandbox, without its trailing `:EK()` call. The decoder method is found by shape: the one that reads the data fields.
- Every `f(<integer>)` call site is decoded under each candidate `Fq`, which are 0 and the integers in the entry method.
- A value is accepted only if the file's own checksum accepted it.
- Text values replace their call sites. Binary values (key material) stay as calls.

**Measured.**

| | Normal | Ultra |
|---|---|---|
| Constants decoded | 111 / 111 | 111 / 111 |
| Decoded with `Fq` = 0 / 60779 | 31 / 80 | — |
| Call sites replaced | 563 | 416 |

A tampered data field decodes fewer constants and invents none (`tests/xxii-volt.test.mjs`).

### Environment checks (read)

The checks run in two places, and each raises a coded error:

- **`EK`** checks `typeof` answers for every basic type and that `game` is a `DataModel`. It also checks `workspace` (with `workspace.Parent == game`), `game:GetService` and `RunService` (`IsClient` true, not both client and server). It requires `getgenv()` and an executor name from `identifyexecutor` / `getexecutorname` (at most 128 characters, printable). A failure raises **`C094`**.
- **The runtime (`Ed`)** repeats a subset (**`C092`**) and the environment lookup (**`C014`**).

Plain Luau therefore stops at `C094`. With `tools/volt/executor-prelude.lua`, a minimal stand-in that answers only those questions, **both presets run and print `Voltfuscator example passed`** on real Luau.

The original prints one more line, "Running the source preview". It is guarded by `if not VLT_OBFUSCATED`, which the protected build compiles with `VLT_OBFUSCATED` set, so its absence is by design.

### The runtime and the program (observed; not lifted)

**The runtime.** `Ed` is itself control-flow flattened: a `while true` dispatch on a state variable, with junk states, opaque predicates such as `if 1 + 1 == 2`, and `bxor` noise. After constant decoding, the engine's generic passes leave readable helpers:

- a **ChaCha20** block function (constants `expand 32-byte k`; rotations 16/12/8/7; ten double rounds);
- a stream-XOR routine;
- authentication-tag helpers.

**What one run decrypts, in order** (recorded by a probe in a scratch copy, on real Luau):

- a 624-byte table of 156 distinct 32-bit values of the form `0x0032xxxx` (likely handler keys, not instructions);
- then, one at a time, the constants of an **anti-tamper prologue** (`Instance`, `ClassName`, `DataModel`, `GetService`, the banner and its global, …);
- a second **772-byte binary block**;
- the constants of a **byte-level decoder** (`byte`, `char`, `floor`, `concat`, `__index`, `__newindex`, …).

**The user's own strings** ("above zero", "Voltfuscator example passed") never pass through the ChaCha20 routine. They are assembled with `table.concat` from byte tables.

**Inference (not verified):** the VM program has two stages.

1. A ChaCha20-protected prologue and loader.
2. The user's program, unpacked from the second block and run with its constants stored as bytes.

## 4. What is not done, and exactly where it stops

| Stage | Status |
|---|---|
| Detection, version, preset, runtime | done (banner, global, header, method table) |
| Constant pool | done and checksum-verified |
| Environment checks | read; satisfied only by the analysis stand-in, never in shipped output |
| Behaviour of the decoded runtime | equal to the protected file on real Luau (both presets) |
| VM handler table, instruction format, stage-2 unpacking | **not done** — the 156-entry key table, the instruction encoding and the second block's format are not decoded |
| Lifting the program to source | **not done** — no lifter exists |

**Result class:** "Received but not successfully deobfuscated". The VM is still present, so a Volt result is never reported as reconstructed.

**The precise remaining stage:** recover the per-build handler semantics behind the 156 keys, decode the instruction stream and the second block, and write a lifter. One version (8.1) and one 30-line source program are available; a second program protected with the same build would be needed to tell per-build randomisation apart from the format.
