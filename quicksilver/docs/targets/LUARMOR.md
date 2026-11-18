# Luarmor loaders: what the file contains, what is recoverable, and what is not in it (Prompt XX)

Implementation: `src/loader/luarmor.js`, the Loader tab ("Luarmor loader" section). Tests: `tests/xx-luarmor.test.mjs`. Evidence: the real
loaders in the local corpus, read as text and never executed: 8 unique bootstraps, 2 SDK loaders (one of them the user's own `MainLoader.lua`),
and 1 key-link script.

## The central question

> When a user supplies a Luarmor loader, how much of the actual Lua/Luau implementation can OMEGA NEXUS recover from the loader itself, and
> what additional authorised information is required for the rest?

**Recoverable from the loader itself:** all of the loader's own logic.

- For a bootstrap, that means the cache-or-download logic.
- For an SDK loader, the key-entry flow, the handling of each status code, and any UI.
- When that code is itself obfuscated (one corpus loader is Luraph-wrapped), it goes through the Deobfuscator, and that result is measured
  there, not assumed.

**Not recoverable from the loader:** the protected script. It is not in the file. The service delivers it after a key check.

- Luarmor documents no interface that returns it (`docs/API-CATALOGUE.md`).
- What is needed is the script itself, which its owner already holds: they uploaded it.
- Pasted into the Deobfuscator, it goes through the normal pipeline like any script.

**Opaque:** the bootstrap's data table (`_bsdata0`). Its only consumer is the service's init runtime, which is not in the file, so what the
values mean cannot be determined from the loader. The analysis describes its shape:

- the number of values;
- the numbers it holds;
- each string's form: raw bytes, hex digits (with the bit length a hex string of that size represents), or a token.

It does not decode them.

## Variants (observed)

| Variant | What the file shows | Local logic | Not in the file |
|---|---|---|---|
| bootstrap | `_bsdata0 = {…}` (numbers, raw-byte strings, a hex string, a token), then: run a cached init script if `readfile` finds one; otherwise download `cdn.luarmor.net/v4_init_<tag>.lua`, cache it with `writefile`, delete older cached copies, run it | recovered in full | the init runtime (the service's client code); the protected script |
| sdk | downloads the SDK library (`sdkapi-public.luarmor.net/library.lua`), sets `script_key`, calls `check_key`, handles `KEY_VALID`, `KEY_HWID_LOCKED`, `KEY_INCORRECT`, `KEY_EXPIRED`, `KEY_BANNED` (…), then calls `load_script`; often with a hub's own UI | recovered in full, or through the Deobfuscator when obfuscated | the SDK library; the protected script |
| loader-url | `loadstring(game:HttpGet("https://api.luarmor.net/files/v3|v4/loaders/<id>.lua"))()` after `script_key = …` | the one statement | the protected script |
| key-link | a link to `ads.luarmor.net/get_key` (the user is sent to get a key); no loader | recovered in full | — |

## The five operations, kept apart

| # | Operation | Bootstrap | SDK | Loader-url |
|---|---|---|---|---|
| 1 | Analyse the loader | done | done | done |
| 2 | Recover code present in the loader | partial: logic in full, data opaque | done, or via the Deobfuscator when obfuscated | done |
| 3 | Retrieve the delivered payload | not available: no documented interface | not available | not available |
| 4 | Deobfuscate the retrieved payload | needs input (the owner's script) | needs input | needs input |
| 5 | Validate behaviour | needs the original | needs the original | needs the original |

## Boundaries, on purpose

- The service's client code (the init runtime and the SDK library) is not fetched, deobfuscated or analysed.
- The data table is not decoded.
- Interpreting either would mean working on the protection mechanism itself. That would not recover anything the owner does not already have.
- Key values are redacted. In the recovered loader logic, a `script_key` literal is replaced by a placeholder, and the analysis says so.
