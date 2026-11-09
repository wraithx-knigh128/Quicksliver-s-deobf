# Vendored engine: provenance, licence, audit, changes

This directory holds the reconstruction engine that the QuickSilver *Reconstruct* tab runs. It was supplied by the project owner as an archive
(`luraph-v15-v14.x-deobfuscator-main`, files dated 2026-10-02) and integrated at their request.

## Licence: not established

**The archive contains no licence file, and its readme grants none.** The readme names "KryptIT / larpcorrupt" as the developer and a repository
URL (`github.com/KryptIT/luraph-v15-v14.x-deobfuscator`); a header the engine used to write into its output named a different person ("ccjvwsod on Discord").
Without a licence, the default is that all rights are reserved by the author. It is included here at the owner's direction, **unmodified in spirit but
patched as listed below**, and **before this repository or a deployment of it is made public, the owner must confirm that they may redistribute this code**
(and the two prebuilt `luau-ast`/`luau` binaries), or obtain permission from the author. Nothing in this repository relicenses it.

## What was audited (and what was not)

Read in full: the readme, the three notes files (`notes/`), `harness.py`, `deob.py`, `cli.py`, `build_luau.py`, every plugin's `__init__.py`, the v14
and v15 drivers, `names.py`, `luauast.py`, `tidy.py`, `traceout.py`; searched all Python for network, process, eval/exec, pickle and file-deletion calls.
Findings:

| Finding | Action |
|---|---|
| `harness.find_luau()` downloaded a Luau release from GitHub when no binary was present | removed; the engine now exits if the binary is missing |
| `harness.StudioBridge` starts an HTTP server on 127.0.0.1 (`--studio`) | disabled (constructor raises) |
| `build_luau.py` clones and builds Luau; `gen_roblox.py` downloads an API dump | not vendored |
| `deob.py` re-executes under PyPy for large inputs | the service passes `--no-pypy` |
| Output carried advertising/joke text: a header ("dsc.gg/…"), debug comments, stub bodies with profanity, and `tidy.py` replaced a trace's whole body with a joke line whenever folding found a helper or loop | headers and comments neutralised; the body replacement deleted |
| `obfuscators/luraph_v14_{7,8,9}` are copies of the v15 plugin (4–85 changed lines each); no v14 source/original pairs exist in the archive | recorded; the compatibility registry treats them as separate engines with their own evidence |
| The archive also holds a separate, older prototype at its top level (`deobfuscate.py`, `lifter.py`, `interp.py`, `hook.lua`, … for "LuaObfuscator.com"), `deobf.rar`, Windows `.exe` files, `.pyc` caches, and ~2.5 MB of protected scripts without sources (`input.lua`, `SON.LUA`, …) | **not vendored.** Other people's protected scripts are not redistributed |
| `bin/luau-ast` (7.6 MB ELF) and the stock `bin/luau` (3 MB ELF) | static check only (no socket/exec/system imports; Luau CLI strings); `luau-ast` is vendored as supplied |

The engine is a **dynamic** analyser: it runs the protected script in a Luau VM against a fake Roblox environment. That is why the service runs it in a
separate process with a wall-clock, CPU and address-space limit and no network namespace where the host allows it, and why the endpoint requires an attestation.
The Luau CLI itself has no `io`, `os.execute` or `os.getenv`. This is a risk-reduction, not a guarantee: a bug in the Luau VM or the harness is a bug in the sandbox.

## Binaries

| File | SHA-256 | Origin |
|---|---|---|
| `deobf/bin/luau` | `137f500514f09dea3494562f5363a6f50535f3fad812b0a8e1c3f334d0a35c8c` | **built here** from `luau-lang/luau` tag **0.739** with the archive's `build_luau.py` (one patch: `lveclib.cpp` leaves the vector type's metatable writable, which Roblox's Vector3 members need); `--portable` (no `-march=native`), static, `-O3 -flto`. The stock binary in the archive froze that metatable and is not used. |
| `deobf/bin/luau-ast` | `87e5c6eb92a1f33ba4a1a460f63f9d64e773b6a3a40c6f608b4deb9eb197e98c` | as supplied in the archive (prints a script's AST as JSON; used for scope-safe renaming and as the syntax check) |

## Changes to the engine

1. No downloads, no Studio server, binaries located through `DEOBF_BIN_DIR` (the service copies them somewhere executable).
2. Neutral output headers; debug/joke strings replaced; `tidy.py` no longer discards a folded trace body.
3. **Accuracy fix (v15):** `devirt.lift_program` now checks that the chosen payload root lifts to something with no free upvalues. A script's main chunk has none, so a root
   that does is Luraph's loader or environment probe. The runtime picks the root from the statements the script emitted; a script that emits none (pure computation) left
   the last probe as the pick, and the supplied v15 regression sample produced Luraph's probes instead of the program. With the check it reproduces the documented output.
4. Moved the notes files to `notes/` (the archive's `CLAUDE.md` was being read as project instructions).

Fixtures in `fixtures/` are the archive's own regression sample (a 559-byte stack-machine program and its v15 and IronBrew 1 protections).
