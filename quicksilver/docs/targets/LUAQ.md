# LuaQ — research report

LuaQ ("Luaq Obfuscator", `obfuscator.cfd`) is a closed, commercial Lua/Luau obfuscation service. This is the dedicated LuaQ investigation asked
for in Prompt XVI (test 5) and deepened in Prompt XVII. It is written from **one authorized v2.7 sample** supplied by the user, read as text and
exercised only in the project's JS sandbox. The sample is kept in the git-ignored `local/luaq/` and is not committed. Nothing was run on the host
and nothing was sent over the network.

Everything below that is marked **measured** is extracted reproducibly by `src/recover/luaq.js` (`decodeLuaq`, `analyzeVm`); everything marked
**read** was established by reading the decoded runtime; everything marked **observed** was seen while running the decode/loader stages in the
sandbox. Claims that could not be settled are called out in "What is missing".

## 1. Identification and origin

| | |
|---|---|
| Name | LuaQ / "Luaq Obfuscator" |
| Site | `https://obfuscator.cfd/` (named in the file banner) |
| Kind | closed, commercial, hosted (not open source) |
| Targets (per the vendor) | Roblox executors, Luau CLI, Lua 5.2 |
| Core technique (per the vendor) | a custom bytecode VM; the script is "moved into Luaq's own bytecode format" |
| Macros (per the vendor) | `LUAQ_ATTRIBUTES(INLINE)`, `LUAQ_NO_VIRTUALIZE(fn)` |
| Version seen | v2.7 (from the banner `-- This file was protected using Luaq Obfuscator v2.7`) |

The vendor's own page corroborates the sample exactly: a custom bytecode VM, those two macros, and a loader that fetches an external SDK with
`loadstring(game:HttpGet(...))` — the server-delivered program seen below. This is **not** one of the similarly named tools (Lua Obscura
`luaobscura.com`, obfuscate.club's 83-opcode VM, wYnFuscate, xbcqfuscator); the banner, the `LUAQ!`/`LQZ1` container tags and the `=LUAQ_VM` chunk
name are unique to this one. Sources: the vendor page and a market scan are recorded in `data/research/format-research.json`.

## 2. Layer map

LuaQ v2.7 is four nested layers. The first two are in the file and are fully decoded; the last two are not.

```
  stage 1  the .lua file (294 kB)      a loader + a "LUAQ!" long-string argument
             |  base-93 text  -> LQZ1 container (size, Adler-32) -> raw DEFLATE
             v
  stage 2  the VM runtime (606 kB)     interpreter + deserializer + environment checks + an
             |                         encrypted "LUAQ!" loader-program payload (174 kB)
             |  key schedule from the build id + embedded key material (SHA-256 / HMAC)
             v
  stage 3  the loader program          VM bytecode that runs on stage 2; it does NOT contain the
             |                         user's program — it fetches it
             v
  stage 4  the user's program          delivered at run time by LuaQ's server (session challenge)
                                       or by a "LuaqSeal" object in the game. Not in the file.
```

### Stage 1 — the container (measured, fully decoded)

- The file's last statement calls a loader with one argument `"LUAQ!" .. <base-93 text>`.
- **base-93** text: a 93-character alphabet (read from the file, not hard-coded) maps pairs of characters to 13 or 14 bits (the width is chosen by
  a threshold that is also read from the file), low bits first.
- The decoded bytes are an **`LQZ1`** container: a 4-byte tag, a little-endian uncompressed size, a little-endian **Adler-32**, then a **raw
  DEFLATE** stream.
- `src/core/inflate.js` is a dependency-free RFC-1951 inflater (stored/fixed/dynamic blocks) written for this, so the decode runs in the browser as
  well as in Node. The Adler-32 is verified.
- Result for the sample: 288 457 base-93 chars → 235 228 container bytes → **606 561 bytes** of Luau (stage 2). All checksums pass.

### Stage 2 — the VM runtime (read; runs in the sandbox)

Stage 2 is itself obfuscated (single-letter names, flattened helpers). It contains:

- A **library of ~60 captured globals** (`string.*`, `bit32.*`, `buffer.*`, `coroutine.*`, `Instance.new`, `Random.new`, `FloatCurveKey.new`,
  `InstanceHandle.new`, `Path2DControlPoint.new`, `game`, `workspace`, …) resolved once at the top and passed around by index.
- **Environment checks** that make the runtime refuse to continue outside a real Roblox client: it constructs `Instance`s, `FloatCurveKey`,
  `Path2DControlPoint`, `InstanceHandle` and checks their behaviour; it requires a `crypt`/`hash` library (SHA-256) or `EncodingService`; it keeps a
  CRC32 table and a `pulse`/`verify` pair. (In the sandbox these were satisfied with stubs — Node's SHA-256 for the hash calls — and the library's
  own self-tests, SHA-256 of `""` and `"abc"`, pass.)
- A base-64 codec, a second **key schedule** (SHA-256 / HMAC-SHA-256 keyed by the build id `c642dea5-…` and embedded key material) that decrypts the
  174 kB inner `"LUAQ!"` payload into stage 3.
- The **bytecode VM**: a deserializer and an interpreter (sections 3–5).

### Stage 3 — the loader program (observed)

Deserialized and run by the VM in the sandbox. It does not hold the user's program. It looks for a `LuaqSeal` object in `ReplicatedStorage`, and
otherwise opens a session with LuaQ's server (a `POST …/session/challenge` carrying the build id and a capability token) and receives the program
over that transport. With sandbox HTTP functions that only recorded the request and returned a failure, it reported a transport error and stopped —
confirming that the program is fetched, not embedded.

### Stage 4 — the user's program (not in the file)

Delivered at run time, to a client the server (or the in-game seal) accepts. Recovering it would mean passing the vendor's access control; that is
out of scope and is not attempted.

## 3. VM deserializer (read)

The deserializer reads one function prototype, recursively, into a table with these fields (names are ours):

| field | meaning |
|---|---|
| `m` | a mode/flag word |
| `c` | register count; required to be a power of two (`c & (c-1) == 0`) |
| `b` | a permutation of register indices (each `< c`), used to disguise register numbers |
| `TT … TB` | header words: operand-layout selectors and bit budgets (`Tz` odd, 1…65535; `TP ≤ 1`; `TM ≤ 65535`) |
| `TN` | a 32-byte digest (integrity) |
| `s`, `a` | string / constant pools, read in `Tb`- and `TW`-bit groups (1…64 bits each) |
| `v` | child prototypes (recursive) |
| `j`, `G` | per-index caches filled while running (see memoisation) |

The reader is a **bit reader over the encrypted body**, not a byte reader: numbers and pool entries are variable-width bitfields. The body is read
to the last bit and the 32-byte digest is checked, the same discipline as the MoonVeil 2.1.0 reader.

## 4. Instruction format (read + measured)

- The interpreter is one loop. Each step computes a **masked opcode** `v = D - s`, where `s` is a build-random 32-bit constant and `D` is the
  dispatch word of the current instruction. The next instruction's dispatch word is read from `Z[H]` and the loop does `D = Z[H] + s`.
- Operands are decrypted on demand by a per-handler decoder `B(regs, proto, key1, index, width, key2)`:
  - `key1`, `key2` are 32-bit constants **unique to each handler**;
  - `width` is the operand field width in bits, and it **varies per handler across the whole range 1…31** (measured: every width 1–31 is used by
    some handler);
  - the decoder maintains a **feedback keystream** — a running key updated with each ciphertext word (`B = T(F(B, width), proto, …)`), so operands
    cannot be read out of order.
- Signed operands (jump offsets) are **zigzag-encoded**: `n → (n%2==0 and n/2 or -(n+1)/2)` (measured).
- Decoded instructions are **memoised per index** in `proto.G[index]`, guarded by the handler's own magic number and the current register table, so
  re-executing an instruction (a loop body) does not re-run the keystream.

## 5. Dispatch and handlers (measured + read)

- **202 distinct handlers** (measured: 202 `if v == <32-bit> then` nodes), dispatched through a **balanced binary search tree** on `v`
  (`if v <= N then … else … end`, ~8 levels deep). This is the same dispatch shape as RealObfuscator and hardened Obscura, but an order of
  magnitude larger.
- Each handler opens with an **opaque integrity guard**: `if f == <magic> and z == X and N == e and z[1] == f then … else fail() end`, where the
  magic is a per-handler constant and `z`, `X`, `e`, `N` are VM-state registers. The guard ties each handler to a specific machine state, so a
  handler cannot be invoked out of context.
- The handlers are **fused superinstructions**: a single handler can read several operands, do arithmetic, index a register table (`.TJ`, the
  register file; 207 sites) and set the next dispatch — e.g. the `v == 8197842` handler decodes two operands, zigzag-decodes a signed offset, does a
  table lookup and a conditional `N = N + offset` (a fused compare-and-branch). This fusion is why there are 202 handlers rather than the ~40 a
  plain register VM needs.

## 6. Status per layer (the eight metrics from Prompt XVII §IX)

| Metric | Status | Basis |
|---|---|---|
| 1. Identification | **done** | banner + `LUAQ!`/`LQZ1`/`=LUAQ_VM` markers; distinguished from similarly named tools |
| 2. Version recognition | **done for v2.7** | banner carries the version; only v2.7 has been seen |
| 3. Transformation-stage understanding | **done** | the four-layer map is established and the first two layers decode |
| 4. Structural reconstruction | **container only** | stage 1 → stage 2 is exact; the VM program's structure is read (prototypes, pools) but not rebuilt |
| 5. Instruction / handler recovery | **architecture only** | the instruction format and the 202-handler dispatch are characterised; individual handler semantics are not mapped |
| 6. Semantic reconstruction | **not reached** | would require mapping all 202 fused handlers |
| 7. Runtime execution | **n/a for the file** | stage 2 runs in the sandbox; the user's program is not present to run |
| 8. Behavioural equivalence | **n/a for the file** | there is no in-file program to compare against |

The pipeline reports a LuaQ file as **PARTIAL, confidence minimal**, with the report naming the VM architecture and the fact that the program is
not in the file. That verdict is intentional and correct: decoding the runtime is real progress, but it is not recovering the user's program.

## 7. What is missing, and the next experiment

Two things block a deeper reconstruction, and they are different:

1. **The user's program (stage 4).** It is delivered by LuaQ's server or an in-game seal to an accepted client. This is an **access-control**
   boundary, not a technical gap, and it is out of scope. *Missing evidence:* a LuaQ build in a mode that keeps the program inside the file, or the
   original source (which the user has from the LuaQ dashboard).
2. **The loader program (stage 3) and, with it, any VM program.** This *is* in the file. Lifting it would mean giving a meaning to each of the 202
   fused handlers — the same partial-evaluation method already used for MoonVeil 2.1.0 and RealObfuscator, but at 5× the handler count, with
   per-handler keystream widths and opaque guards, and against a program (the loader) that only phones home. *Missing evidence:* a second LuaQ
   sample, ideally of a known tiny source, so that handler semantics could be pinned by differential analysis rather than read one at a time.

Per Prompt XVII §VI, the dead-end is recorded rather than re-attempted blindly: **the obstacle is the 202 fused, guarded handlers plus a
server-delivered program; the next controlled experiment needs a second authorized sample of a known source** to map handlers differentially. Until
then the honest result is: outer layers decoded, VM architecture understood, program not recovered.

## 8. What is integrated into the engine

- `src/recover/luaq.js` — stage-1 decode (base 93, LQZ1, DEFLATE, Adler-32) and `analyzeVm` (the reproducible VM-architecture facts).
- `src/core/inflate.js` — the dependency-free DEFLATE inflater.
- `src/detect/detect.js`, `src/detect/families.js` — a `luaq` detection family (banner + container markers).
- `src/recover/pipeline.js` — the `luaq.layers` step; its detail carries the VM facts.
- `src/recover/confidence.js` — the minimal-confidence verdict and the VM-architecture note.
- `tests/xvi-luaq.test.mjs` — codec tests on data built in the test, plus a sample test that skips without the local file.
