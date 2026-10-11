# game_dev

## Wraith's Hub - Murder Mystery 2 (`dist/wraiths_hub.min.txt`)

One-line loader (pinned to a build; the SHA is updated after every build):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wraithx-knigh128/Quicksliver-s-deobf/5a2c2214448d23e3f0af901c24fda0de159340ba/dist/wraiths_hub.min.txt"))()
```
The menu is the real **[WindUI](https://github.com/Footagesus/WindUI)** library (Footagesus, MIT licence - the full source is embedded in the script, see `mm2/vendor/`),
made small and clean: a Mac-style close button only (no minimise / fullscreen), no search bar, version tag or user card, five tabs (Main, ESP, Combat, Player, Misc), a monospace
font, frosted cards that fade out to the right, WindUI's draggable open button, 10 themes (default **Dark**). The **inside stays transparent** (Settings > *Window see-through*);
the grey **water-flow texture lives only on outlines**: the window's border, WindUI's buttons and the floating buttons - a thin grey / white gradient that runs round the border
(*Button waves* High = 30 updates a second, Low = 15, Off = still). If WindUI cannot start on an executor (a blocked class, ...) the script falls back to the small built-in
**Classic** menu and says why in the Log; Settings > *Menu style* picks one for the next run. No icon pack is downloaded (a built-in set of 76 licensed [Lucide](https://lucide.dev)
icons is used, MIT, via Footagesus/Icons), and the menu
is built a few controls per frame, so loading does not freeze the game; the SHOOT / THROW buttons appear first.

![Classic menu on a phone](../preview/mm2/phone_main.png)

(Layout preview of the **Classic fallback** menu, rendered from the test world - not a Roblox screenshot. WindUI's own 9-slice artwork cannot be rendered offline, so the WindUI
menu has no preview image; it is tested by running the real library in the fake world - see below.)

**Optional picture / video behind the menu** (Settings > *Video or picture link*, off by default): a looping video or a picture shown behind the transparent window with a dimming
slider. The link can be a direct `.mp4` / `.webm` / `.png` / `.jpg`, or a pixabay.com video page (the box is pre-filled with the lake-sunset clip you asked for: press *Load this
link now*). The file is downloaded **once** into `WraithsHub/assets/` of your executor's workspace (needs `request`/`HttpGet`, `writefile`, `getcustomasset`). I cannot find or
ship the exact picture from your reference photo (it is somebody's artwork and I have no way to search for it), and pixabay.com is blocked in the build environment, so the
Pixabay path is tested with a stand-in page and file, not with the real site; paste the direct link of the image / video you want.

- **Floating buttons**: rounded squares with a **transparent inside** and a glowing grey outline that carries the flowing water. **SHOOT** (a turning, pulsing crosshair),
  **THROW** (a knife that travels round a circle) - both licensed [Lucide](https://lucide.dev) icons (MIT) - **GRAB GUN** (there is no licensed gun icon in Lucide, so this one stays
  a small hand-drawn pistol shape), SPEED / JUMP toggles (a licensed bolt / the hand-drawn chevron, brighter outline = on). Tap = fire, drag = move, size slider, lock,
  fainter without that weapon, a solid green / red flash for fired / could not, positions saved with *Save config*.
- **Auto targets by role**: Sheriff / hero -> the **murderer**, aimed ahead by your ping (innocents are never shot; if the murderer is not known yet it says so). Murderer -> the
  **closest player**. Either button does what your weapon can do (SHOOT as murderer throws, THROW as sheriff shoots). Shots use the shot you recorded once by hand; with nothing recorded
  the hub also tries the remote layouts other MM2 scripts report (`Gun.KnifeLocal.CreateBeam.RemoteFunction`, `Knife.Events.KnifeThrown`, `Knife.Throw`; unverified guesses, switchable)
  and finally the tool / throw key.
- **ESP**: murderer **red**, sheriff / hero **blue**, innocents green, the dropped gun **orange** (highlight, label, tracer, HUD). Event driven: a knife or gun appearing, a spawn, a
  death, new role data, a gun drop all refresh the ESP the same frame; new highlights fade in and colour changes blend.
- **Perfect aim by ping**: the aim point is where the target will be when the shot arrives = measured ping (median + EMA, lag spikes ignored) x compensation
  + the render delay of other players + trim, using engine velocity or - when the engine reports none - the position history (teleports are not velocity).
  The aim is re-computed after the weapon is equipped, because the target keeps moving. Live "Ping 60 ms -> aim 110 ms ahead" readout.
- **Moving aim reticle**: a ring with spinning ticks that glides onto the predicted point, labelled with name, distance and lead.
- gun finder (toast, HUD compass), aim assist, auto shoot / throw, silent aim, slash aura, hitbox expander (experimental), player mods.
- nothing is saved unless you press **Save config** (`wraiths_hub_config.json`).

How the game works, what is known vs. assumed, and how the hub discovers the private parts at run time: [`mm2/MM2_NOTES.md`](mm2/MM2_NOTES.md).
Source: `mm2/` (`windui_ui.lua` the WindUI adapter, `ui_lib.lua` the Classic menu + the water skins and floating buttons, `logic.lua` pure logic, `wraiths_hub.lua` the script,
`vendor/` WindUI + its licence + the three small patches + the Lucide icon subset); build with `python3 game_dev/mm2/build_mm2.py`.

Checks (from `game_dev/`; `logic` needs `pip install lupa`, the rest need real Luau: `LUAU=/path/to/luau` or `luau` on PATH, because WindUI is Luau code):
- `python3 tests/run_mm2.py logic`                          unit tests of `mm2/logic.lua` (ping model, lead solver, velocity, targeting, shot planner ...)
- `python3 tests/run_mm2.py windui`                         ~200 checks of the hub on the REAL WindUI inside the fake world: the library builds the whole menu without touching a member
  the Roblox API lacks, real taps on its toggles and dropdown options and key presses change the hub's settings, outline water / transparency / compact layout, background download / dim / removal, request() vs HttpGet, staggered build,
  fallback to Classic (library fails to load / window fails half way), saved menu style, unload leaves nothing behind.
- `python3 tests/run_mm2.py smoke [../dist/wraiths_hub.lua]`  ~930 checks (Classic menu, ESP colours / speed, role targets, known remotes, floating buttons) against a fake Roblox world (`tests/mm2_env.lua`): real instance tree / events / Vector3 / CFrame math,
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
