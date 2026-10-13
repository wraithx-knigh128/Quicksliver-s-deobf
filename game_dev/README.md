# game_dev

## Wraith's Hub - Murder Mystery 2 (`dist/wraiths_hub.min.txt`)

One-line loader (pinned to a build; the SHA is updated after every build):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wraithx-knigh128/Quicksliver-s-deobf/d2e59adad420f118b93afef63a2f438097da9878/dist/wraiths_hub.min.txt"))()
```
The menu is the real **[WindUI](https://github.com/Footagesus/WindUI)** library (Footagesus, MIT licence - the full source is embedded in the script, see `mm2/vendor/`),
made small and clean: a Mac-style close dot only (no minimise / fullscreen) - our own, not WindUI's built-in one, which opens a "you will not be able to open it again" dialog
and then permanently destroys the window; ours just hides it, the same reversible way the toggle key does - no search bar, version tag or user card, five tabs (Main, ESP,
Combat, Player, Misc), a monospace
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
link now*). The file is downloaded **once** into `WraithsHub/assets/` of your executor's workspace (needs `request`/`HttpGet`, `writefile`, `getcustomasset`). Pixabay is blocked in
the build environment, so the Pixabay path is tested with a stand-in page and file, not with the real site.

**Licensed animated anime-girl background - not shipped, and why.** I searched (Pixabay, Pexels, Wikimedia Commons, Internet Archive, itch.io, OpenGameArt). The build environment can
only reach GitHub, so I could not open a licence page or download a single candidate to check it, and what the searches turned up was either AI-generated (Pixabay's anime-girl
"loop" clips mostly are - they say so), paid / "free with credit" Gumroad and itch.io packs whose licence text I could not read, or still images and sprites rather than a looping
video. I will not ship a clip I could not verify, and I will not draw or generate one. The slot is ready: find a clip whose page says it may be used and redistributed (and is not
AI-made, if that matters to you), paste its direct `.mp4` / `.webm` link (or its Pixabay page) into the box, and credit the author as the licence asks.

- **Floating buttons**: rounded squares with a **transparent inside** and a glowing grey outline that carries the flowing water. **SHOOT** (a turning, pulsing crosshair),
  **THROW** (a knife that travels round a circle) - both licensed [Lucide](https://lucide.dev) icons (MIT) - **GRAB GUN** (there is no licensed gun icon in Lucide, so this one stays
  a small hand-drawn pistol shape), SPEED / JUMP toggles (a licensed bolt / the hand-drawn chevron, brighter outline = on). Tap = fire, drag = move, size slider, lock,
  fainter without that weapon, positions saved with *Save config*. Each one is a small live readout too: a **status line** under it (the target and its distance - `Alice  42m` -,
  `RELOADING`, `NO GUN`, `MURDERER?`, `GUN  36m`), a **pip** in the corner (green = a tap will fire, grey = waiting, red = cannot), a thin **reload bar** that fills over the cooldown
  and a swell of the outline when it is ready again, a **ring** that spreads from every tap, a small recoil when it fires, and **HIT** / **MISS** after the shot (see below).
- **Auto targets by role**: Sheriff / hero -> the **murderer**, aimed ahead by your ping (innocents are never shot; if the murderer is not known yet it says so). Murderer -> the
  **closest player**. Either button does what your weapon can do (SHOOT as murderer throws, THROW as sheriff shoots). Shots use the shot you recorded once by hand; with nothing
  recorded it goes straight to really using the tool (aim + `Activate()` / the throw key - the same thing a manual click does). Combat also has a *Try known game remotes*
  toggle (**off by default**) for the remote layouts other MM2 scripts report (`Gun.KnifeLocal.CreateBeam.RemoteFunction`, `Knife.Events.KnifeThrown`, `Knife.Throw`) - these are
  unverified guesses, and `FireServer` never tells you whether the server actually did anything with a call, so a wrong guess can report "fired" / "thrown" while doing nothing;
  that's why it isn't on by default.
- **ESP**: murderer **red**, sheriff / hero **blue**, innocents green, the dropped gun **orange** (highlight, label, tracer, HUD). Event driven: a knife or gun appearing, a spawn, a
  death, new role data, a gun drop all refresh the ESP the same frame; new highlights fade in and colour changes blend.
- **Perfect aim by ping**: the aim point is where the target will be when the shot arrives = measured ping (median + EMA, lag spikes ignored) x compensation
  + the render delay of other players (default 100 ms) + trim, using engine velocity or - when the engine reports none - the position history (teleports are not velocity).
  A target in the air is led along a real **jump arc** (gravity, back down to the height it stands at) instead of a straight line. It aims at the **torso** by default (any hit
  kills, and it is the biggest part of a runner). Live "Ping 60 ms -> aim 110 ms ahead" readout.
- **The aim is held for the shot**: Roblox's own camera script rewrites the camera every frame, so a camera aim set once is gone before the weapon's script reads it. A shot now holds
  the camera and cursor on the target (a render step right after the camera script, re-leading the target every frame) until the weapon has fired, then lets go.
- **Did it hit?** `FireServer` / `Activate` never say, so the hub looks: a toast and the button show **HIT** when the target's health drops (or it goes down) within the shot's
  flight time, **MISS** otherwise - not "Shot fired" and silence. A **thrown knife's speed is measured** from the real projectile (a part that appears and flies away from you in a
  straight line) and used for the next throw; Combat > *Knife speed* sets it by hand. A gun is treated as instant unless *Bullet speed* is set.
- **Walk speed** that the game keeps resetting (a script puts `WalkSpeed` back): the hub notices the value never sticks and moves the character itself instead.
- **Moving aim reticle**: a ring with spinning ticks that glides onto the predicted point, labelled with name, distance and lead.
- gun finder (toast, HUD compass), aim assist, auto shoot / throw, silent aim, slash aura, hitbox expander (experimental), player mods.
- nothing is saved unless you press **Save config** (`wraiths_hub_config.json`).

How the game works, what is known vs. assumed, and how the hub discovers the private parts at run time: [`mm2/MM2_NOTES.md`](mm2/MM2_NOTES.md).
Source: `mm2/` (`windui_ui.lua` the WindUI adapter, `ui_lib.lua` the Classic menu + the water skins and floating buttons, `logic.lua` pure logic, `wraiths_hub.lua` the script,
`vendor/` WindUI + its licence + the three small patches + the Lucide icon subset); build with `python3 game_dev/mm2/build_mm2.py`.

## Played in a simulated Murder Mystery 2 round

`tests/mm2_sim.lua` is my own small MM2: players with full **R6 and R15 rigs** (root, head, torso / upper + lower torso, arms, legs, hands, feet - every part moves as one body), a
server that assigns a murderer and a sheriff, gives them the knife and the gun, decides every hit and drops the gun when the sheriff dies, a network with a **ping and an
interpolation delay** (other players are drawn in the past, exactly as Roblox does), bots that run in lines / circles / zig-zags / stop-and-go / bunny hops, walls, a camera script
that rewrites the camera every frame, `Tool.Enabled` as the reload, and the game's own tool scripts (they read the mouse, then call the weapon's remote). The hub is run in it
unmodified: tap a button -> the hub picks the target, aims, equips, fires -> the "game" sends the remote -> the "server" decides.

**This is a model, not the real game.** Bullet speed, knife speed, reload times, hit boxes, remote layouts and "the sheriff dies for shooting an innocent" are my assumptions (the
real numbers are not published - see `mm2/MM2_NOTES.md`). What passing proves is that the hub behaves in a world like this one, and in a family of worlds around it (hitscan or
travelling bullet, three remote layouts, 40-160 ms real render delay, engine velocity on or off). It does **not** prove anything about the real server. Sheriff, one tap, 10 starts per cell:

| hits / 10 | ping 30 | 80 | 150 | 250 | 400 |
|---|---|---|---|---|---|
| runs in a line | 10 | 10 | 10 | 10 | 10 |
| runs in a circle | 10 | 10 | 10 | 10 | 5 |
| zig-zag (flips every 0.7 s) | 10 | 10 | 10 | 10 | 0 |
| stop and go | 10 | 10 | 10 | 0 | 0 |
| bunny hops | 10 | 10 | 10 | 10 | 10 |

The zeros are not bugs to fix: nobody can aim at a player who changes direction after the shot has left. With the lead switched off the same line at 150 ms is 0/10. What the
simulation found in the hub, and what changed because of it: the one-off camera aim (0 hits in 250 once the camera script was modelled), jumping targets (linear lead missed them),
the head as a default aim part (203 vs 179 hits), the thrown knife's unknown speed, a WalkSpeed that the game resets, and a "fired" toast that said nothing about the result.

Checks (from `game_dev/`; `logic` needs `pip install lupa`, the rest need real Luau: `LUAU=/path/to/luau` or `luau` on PATH, because WindUI is Luau code):
- `python3 tests/run_mm2.py logic`                          unit tests of `mm2/logic.lua` (ping model, lead solver incl. the jump arc, velocity, targeting, shot planner ...)
- `python3 tests/run_mm2.py game`                           ~270 checks, the hub played end to end in the simulated round above (about 45 s): rigs, roles + ESP, hit rates by motion and
  ping, what it will not shoot (unknown murderer, innocent in the line, wall, dead murderer, innocent beside the murderer), knife throws + speed measurement + stab aura, gun drop and
  pickup, recorded shots and silent aim, HIT / MISS, the button status lines, walk speed (also when the game resets it) and jump power
- `python3 tests/run_mm2.py windui`                         ~230 checks of the hub on the REAL WindUI inside the fake world: the library builds the whole menu without touching a member
  the Roblox API lacks, real taps on its toggles and dropdown options and key presses change the hub's settings, outline water / transparency / compact layout, background download / dim / removal, request() vs HttpGet, staggered build,
  fallback to Classic (library fails to load / window fails half way), saved menu style, unload leaves nothing behind, and a short simulated round played on it.
- `python3 tests/run_mm2.py smoke [../dist/wraiths_hub.lua]`  ~940 checks (Classic menu, ESP colours / speed, role targets, known remotes, floating buttons) against a fake Roblox world (`tests/mm2_env.lua`): real instance tree / events / Vector3 / CFrame math,
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
