# LuaQ: status record

LuaQ ("Luaq Obfuscator", obfuscator.cfd) is closed and commercial. One v2.7 build was supplied by the user in Prompt XVI, test 5. It is kept in
the git-ignored `local/luaq/` and is not in the repository. Nothing was run on the host and nothing was sent over the network.

## What the file contains

| Stage | What it is | Status |
|---|---|---|
| 1. The file (294 kB) | a loader around one argument `"LUAQ!<text>"`: base-93 text → `LQZ1` header (size, Adler-32) → raw DEFLATE → loaded as `=LUAQ_VM` | decoded statically (`src/recover/luaq.js`, `src/core/inflate.js`), checksum verified |
| 2. The VM runtime (606 kB of Luau) | an interpreter, a deserializer, Roblox environment checks and an encrypted loader program for the VM | decoded to readable Luau; it is the output of the pipeline for this format |
| 3. The program | not in the file: it is delivered to the script at run time from outside it | not recovered; out of scope |

## Status per layer

| Layer | Status |
|---|---|
| 1. Recognition | done (banner and the stage-1 container) |
| 2. Container decoding | done for stage 1 |
| 3–7 | not applicable to the file: the program is not in it |

The pipeline reports the result as PARTIAL with minimal confidence and says why in the file's report.
