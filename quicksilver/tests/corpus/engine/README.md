# Server-engine fixtures (Prompt XXIX)

Everything here was written for QuickSilver's tests; none of it comes from a third party.

- `rebuilt-program.lua` — a small Roblox-style program. `rebuilt-program.luac.hex` is that program compiled by the reference Lua 5.1
  (`string.dump` of `loadstring(source, "=fixture")`, through tests/helpers/lua-oracle.mjs), written as hex. It stands in for what the
  MoonSec V3 engine returns (a Lua 5.1 chunk), so the page's half of the adapter — decompile, recover, classify, report — is tested
  without the engine and without a third-party sample. It includes a global whose name is not an identifier and holds a control byte
  (`_G["odd\29name"]`), which the decompiler once wrote as a JSON escape that Lua cannot read.
- `evaluator-escape-probe.lua` — four lines whose second line is shaped like a MoonSec key expression (`1 + <call>`), the call being
  `os.execute`. The engine evaluates such expressions to find its keys; before QuickSilver's audit its evaluator ran them with the
  whole Lua standard library, so this file ran a shell command. The test runs it through the same isolated path as the server
  (api/_lib/isolate.js) and requires the engine to refuse it.
