# LuaQ: status record

## Identification

"LuaQ" / "Luaq" is a commercial, closed-source obfuscation service (obfuscator.cfd). Public descriptions found in Prompt XV and XVI name these
features:

- a custom VM;
- Roblox, Luau and Lua 5.2 targets;
- in-source macros `LUAQ_NO_VIRTUALIZE` and `LUAQ_ATTRIBUTES(INLINE)`.

No source code, generator or documentation of its output format is public.

## What blocked further work

- **The site.** Requests to obfuscator.cfd fail inside this environment with DNS `ENOTFOUND`. This was not worked around.
- **Samples.** There are no authorized samples. The tool cannot be run here: it is a hosted service, and using it to produce samples would mean
  creating an account on a third-party service, which this project does not do on its own.

## What would unblock it (permission needed)

1. **Samples:** LuaQ outputs that the user is authorized to share, ideally with the source each was made from, at the settings the user cares about.
   They would go in the git-ignored `tests/corpus/obfuscated-local/luaq/` with a manifest.
2. **Documentation:** network access to obfuscator.cfd for this environment, if its documentation is wanted. This is an environment setting the user
   approves; it would give documentation, not samples.

With samples, the path is the one used for MoonVeil 2.1.0 and RealObfuscator:

1. identify the runtime by shape (`src/custom/probes.js` already reports unknown VMs with their structure);
2. read the dispatcher and handlers of each build;
3. decode the program data statically;
4. partially evaluate the instructions through their handlers;
5. check the result against the original in the sandbox.

## Status per layer

| Layer | Status |
|---|---|
| 1. Recognition | not possible without samples (no signature can be verified) |
| 2–7 | not started (no samples) |

Unknown scripts are still analysed by the custom-format engine, which reports a VM by its shape. They are never reported as recovered.
