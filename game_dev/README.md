# game_dev

## Murder Mystery 2 hub (`dist/mm2_hub.min.txt`)

One-line loader (pinned to a build; the SHA is updated after every build):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wraithx-knigh128/Quicksliver-s-deobf/<SHA>/dist/mm2_hub.min.txt"))()
```
WindUI / RuzHub-style window (sidebar tabs + search, toggles, sliders, dropdowns, keybinds, toasts, 5 themes, round avatar, minimise / maximise / hide,
floating **M** button for phones; RightShift hides the menu). Tabs: Main, ESP, Combat, Player, Misc, Settings, Debug.

- role ESP (red murderer / blue sheriff / gold hero / green innocent), names, distance, health, tracers; **gun ESP + gun finder HUD + toast saying where the gun is**
- aim assist with velocity + ping prediction (camera / cursor), "Shoot the murderer", auto shoot, throw knife, slash aura, **silent aim** (rewrites your own shots)
- hitbox expander (experimental), walk speed / jump / noclip / FOV, anti-AFK, rejoin / server hop
- nothing is saved unless you press **Save config** (`mm2_hub_config.json`)

How the game works, what is known vs. assumed, and how the hub discovers the private parts at run time: [`mm2/MM2_NOTES.md`](mm2/MM2_NOTES.md).
Source: `mm2/` (`ui_lib.lua` window library, `logic.lua` pure logic, `mm2_hub.lua` the script); build with `python3 game_dev/mm2/build_mm2.py`.

MM2 checks (from `game_dev/`, needs `pip install lupa`; add `LUAU=/path/to/luau` to run on real Luau):
- `python3 tests/run_mm2.py logic`                       unit tests of `mm2/logic.lua`
- `python3 tests/run_mm2.py smoke [../dist/mm2_hub.lua]`  ~350 checks against a fake Roblox world (`tests/mm2_env.lua`): real instance tree / events / Vector3 / CFrame math,
  coroutine scheduler, executor-style `__namecall` hook, and **strict member checking from Roblox's API dump** (`tools/gen_mm2_types.sh` regenerates `tests/prop_types_mm2.lua`):
  a misspelled property, a wrong value type or a method the class does not have throws and fails the test even if the script swallowed it with `pcall`.

# Animation Hub (The Strongest Battlegrounds)

Single-file executor script: `dist/tsb_hub_executor.min.txt` (built by `python3 game_dev/build_executor.py`).

Short loader (no pasting a 77 KB file):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wraithx-knigh128/Quicksliver-s-deobf/6667162e1b9f7c78923983db9bdfac9360276263/dist/tsb_hub_executor.min.txt"))()
```

Nothing is saved automatically (that includes your own menu picture: Save config keeps it). The Config tab has Save config / Reload / Delete; the only file is `animation_hub_config.json`, loaded when
the hub starts (an old `animation_hub_settings.json` from earlier versions is ignored).

Checks (from `game_dev/`):
- `python3 tests/run_tests.py`           logic tests (needs `pip install lupa`)
- `python3 tests/run_smoke.py [file]`    UI smoke test on Lua 5.x via lupa
- `LUAU=/path/to/luau python3 tests/run_smoke_luau.py [file]`   same smoke test on real Luau (what Roblox runs)
- `python3 tests/check_palette.py`        the menu themes must stay bright (window luminance) and readable (WCAG contrast)
- `tools/validate_api.py`                every Roblox property/enum/service used vs Roblox's real API dump
- `tools/gen_prop_types.py`              regenerates `tests/prop_types.lua` (real property VALUE types); the smoke test rejects wrong-typed assignments and tweens like Roblox does

Also here: `UI_GUIDE.md` (how to build this kind of menu, where), `examples/mini_ui.lua` (a small complete menu for Roblox Studio),
`tools/validate_api.py` (checks Roblox property / enum / event names against the real API list).
