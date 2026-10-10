# game_dev

## Wraith's Hub - Murder Mystery 2 (`dist/wraiths_hub.min.txt`)

One-line loader (pinned to a build; the SHA is updated after every build):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wraithx-knigh128/Quicksliver-s-deobf/56404a42f99209609e8c4ad224ffb3298d3622c1/dist/wraiths_hub.min.txt"))()
```
![Wraith's Hub on a phone](../preview/mm2/phone_main.png)

(Layout preview rendered from the test world - not a Roblox screenshot. More in `preview/mm2/`.)

A RuzHub / WindUI-style window: logo header, red minimise / maximise / close glyphs, search box, collapsible tab group with icons
(Main, ESP, Combat, Buttons, Player, Settings, Debug), wrapping rows (toggle, slider, dropdown, keybind, button), round avatar, toasts, 5 themes.
Hiding it leaves a floating **Wraith's Hub** pill (tap = open, drag the handle = move; RightShift also toggles).

- **Floating buttons** (Buttons tab): **SHOOT** (perfect shoot), **THROW** (perfect throw) and **GRAB GUN**. Tap = fire, hold and drag = move, size slider, lock,
  dimmed when you do not hold that weapon, flash green / red for fired / could not, positions saved with *Save config*.
- **Perfect aim by ping**: the aim point is where the target will be when the shot arrives = measured ping (median + EMA, lag spikes ignored) x compensation
  + the render delay of other players + trim, using engine velocity or - when the engine reports none - the position history (teleports are not velocity).
  The aim is re-computed after the weapon is equipped, because the target keeps moving. Live "Ping 60 ms -> aim 110 ms ahead" readout.
- **Moving aim reticle**: a ring with spinning ticks that glides onto the predicted point, labelled with name, distance and lead.
- **Water-wave skin on every button**: layered grey-white wave gradients that drift (menu buttons, tabs, controls, pill, rows, keybinds, options, floating buttons)
  plus a ripple where you press; *Button waves* High / Low / Off for weak phones. Windowed skins only animate while the window is open.
- role ESP, gun ESP + gun finder (toast, HUD compass), aim assist, auto shoot / throw, silent aim, slash aura, hitbox expander (experimental), player mods.
- nothing is saved unless you press **Save config** (`wraiths_hub_config.json`).

How the game works, what is known vs. assumed, and how the hub discovers the private parts at run time: [`mm2/MM2_NOTES.md`](mm2/MM2_NOTES.md).
Source: `mm2/` (`ui_lib.lua` window library, `logic.lua` pure logic, `wraiths_hub.lua` the script); build with `python3 game_dev/mm2/build_mm2.py`.

Checks (from `game_dev/`, needs `pip install lupa`; add `LUAU=/path/to/luau` to run on real Luau):
- `python3 tests/run_mm2.py logic`                          unit tests of `mm2/logic.lua` (ping model, lead solver, velocity, targeting, shot planner ...)
- `python3 tests/run_mm2.py smoke [../dist/wraiths_hub.lua]`  ~780 checks against a fake Roblox world (`tests/mm2_env.lua`): real instance tree / events / Vector3 / CFrame math,
  coroutine scheduler, executor-style `__namecall` hook, and **strict member checking from Roblox's API dump** (`tools/gen_mm2_types.sh` regenerates `tests/prop_types_mm2.lua`):
  a misspelled property, a wrong value type or a method the class does not have throws and fails the test even if the script swallowed it with `pcall`.
- `python3 tests/run_mm2.py preview [script]`               lays the UI out like Roblox does (`tests/mm2_layout.lua`: UDim sizing, UIListLayout, UIPadding, AutomaticSize, wrapped text),
  reports layout problems (text that does not fit, default "Label" text, visible borders ...) and writes JSON; `python3 tools/render_preview.py scene.json out.png` paints it.

# Animation Hub (The Strongest Battlegrounds)

Single-file executor script: `dist/tsb_hub_executor.min.txt` (built by `python3 game_dev/build_executor.py`).

**Start techs with your M1** (Main tab, on by default): arm a tech (pinned button / Assist switch / "Flowing Water -> Kyoto"), throw 1-3 M1s, and when you stop - or reach the
tech's own M1 count - the script plays the rest, casting the tech's first move itself when it does not begin with M1s. Pressing a move key between M1s cancels the
take-over, clicks the game already consumed are ignored, and touch players teach their M1 animations once with *Teach my M1*. Switch it off to go back to
"cast the first move yourself". Options: wait after your last M1 (0.15-0.8 s), most M1s to wait for (1-4); saved with *Save config*.

Short loader (no pasting a 77 KB file):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wraithx-knigh128/Quicksliver-s-deobf/715b666948a9aab6ab57f8b181b6dfd3cbb87b70/dist/tsb_hub_executor.min.txt"))()
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
