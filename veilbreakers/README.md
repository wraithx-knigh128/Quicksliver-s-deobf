# VEILBREAKERS — The Sundered Realms

An original dark-fantasy 2.5D fighting game for Roblox. Eight fighters, four
spectral Echo assists, a story chapter with in-engine cinematics, an arcade tower
with per-fighter endings, versus and practice modes, finishers, supers and full
mobile / gamepad / keyboard support.

> This is an original game in the fighting-game genre. Its characters, story,
> arenas, UI and audio were made for this project. It is not a recreation of any
> existing game.

## Play it

1. Open **`build/Veilbreakers.rbxlx`** in Roblox Studio (File → Open from File).
2. Press **Play** (F5). Fights run on your client against the CPU, so solo
   playtesting is the full experience.
3. Optional: **File → Publish to Roblox** to play it on phone, tablet, console or PC.

The images (key art, emblem, stage backdrops) are already uploaded and approved on
Roblox. To hear the full soundtrack and SFX, follow the **Audio** step below.
Until then the game uses a handful of built-in Roblox sounds and is otherwise silent.

## Audio (one-time, 4 uploads)

The complete sound pack (≈80 SFX, voice grunts, 4 ambience beds and 7 music tracks)
is synthesised by `tools/synth_audio.py` and packed into four "atlas" files:

```
audio/atlas/veil_sfx.ogg        SFX + voices
audio/atlas/veil_ambience.ogg   looping ambience beds
audio/atlas/veil_music_a.ogg    menu / select / story / victory themes
audio/atlas/veil_music_b.ogg    battle themes
```

1. In Studio open **Window → Asset Manager → Bulk Import**, or use the Creator
   Dashboard (Development Items → Audio), and upload those four files.
2. Copy each audio asset id and paste it into `Assets.AudioAtlas` in
   `src/shared/Assets.luau` (in Studio: `ReplicatedStorage.Veil.Assets`):

```lua
Assets.AudioAtlas = {
	sfx = "1234567890",
	ambience = "1234567891",
	music_a = "1234567892",
	music_b = "1234567893",
}
```

Every sound then plays from its region of the atlas
(`src/shared/AudioAtlas.luau`, generated). Uploading 4 files instead of 80 keeps you
well inside Roblox's monthly audio upload limit.

## Modes

| Mode | What it is |
| --- | --- |
| **Story** | *Chapter I — The Sundered Veil.* 9 letterboxed in-engine scenes with subtitles and 4 fights across all four arenas, ending with the Hollow King. |
| **Ascent** | A seven-challenger tower that ramps difficulty and ends with a boss. Each fighter has a three-card ending. |
| **Versus** | Pick your fighter, your Echo, the opponent, the arena and the CPU difficulty (Novice, Adept, Veteran, Veilbreaker). |
| **Practice** | Infinite health and meter, a dummy that stands, blocks or fights back (switch with F / Y / the DUMMY button), and live frame data for every move. |
| **Move List** | Every special, super, finisher, string and system mechanic for the whole roster, with frame data. |
| **Settings** | Music, effects and voice volume, subtitles, camera shake, default difficulty, touch controls. Saved per player. |

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move / crouch / jump | A D / S / W (or arrows, Space) | Stick / D-pad | Left thumbstick |
| Light | J | X | **L** |
| Heavy | K | Y | **H** |
| Kick | L | A | **K** |
| Special (+ direction) | I | B | **SP** |
| Block (hold, + down to block low) | U or Left Shift | RB | **BLOCK** |
| Echo (+ down for variant) | O | LB | **ECHO** |
| Super (2 bars) / Breaker (in a combo) | P | RT | **SUPER** |
| Throw (Block + Light) | H | LT | **THROW** |
| Dash / backdash | double-tap → / ← | double-tap | double-flick the stick |
| Pause | Tab | Start / Select | **II** |
| Finisher (at *SEAL THEIR FATE*) | hold S + I | hold ↓ + B | hold ↓ + **SP** |

## Combat system

- **60 Hz deterministic engine** (`src/shared/Combat/Engine.luau`). Every move has
  real startup, active and recovery frames, on-hit and on-block advantage, and
  hitboxes against standing, crouching and airborne hurtboxes.
- **Guard levels:** highs whiff on crouchers, lows must be blocked crouching,
  overheads must be blocked standing, and throws beat block.
- Target-combo **strings**, **special cancels**, launchers and **juggles** with
  gravity scaling, combo damage scaling, hitstop, pushback and corner pushback.
- **Specials:** projectiles (including boomerang, ground-travel, stationary and
  absorbing), teleports, command grabs, parries, armor, dive kicks and multi-hit
  flurries.
- **Echoes:** each fighter brings a spectral ally with a neutral and a down variant
  on a cooldown, usable mid-combo. The Echo is dispelled if you're hit before it strikes.
- **Veil meter (3 bars):** a 2-bar cinematic **Super** that's invulnerable on
  startup, or a 1-bar **Breaker** to burst out of a combo.
- **Throw escapes**, dashes and backdashes, wake-up invulnerability, chip damage
  that can't KO, time-out decisions and sudden death.
- **Finishers:** win the final round, then hold down + Special during *SEAL THEIR
  FATE* to banish your opponent in a cinematic. The effect is a stylised shatter
  into light, not gore.

## The CPU

`src/shared/Combat/AI.luau` drives the same input table a player does. It sees the
fight through a reaction delay and rolls difficulty-scaled chances to block (and
read high, low or overhead), punish unsafe moves, anti-air, tech throws, break
combos and use parry stances. It runs authored per-fighter combo routes, zones
with projectiles, keeps each archetype's preferred range, and calls Echoes and
Supers.

## Project layout

```
default.project.json         Rojo project (Lighting = Future, no auto characters)
build/Veilbreakers.rbxlx     ready-to-open place file
src/shared/                  ReplicatedStorage.Veil
  Config, Assets, AudioAtlas
  Data/   Fighters, Echoes, Stages, Story, MoveKit
  Combat/ Engine, AI, Rng
src/client/                  StarterPlayerScripts.VeilClient
  Main.client                game flow
  Core/   Input, Audio
  Render/ RigMath (FK + leg IK), Poses (60+ animations), Looks, Rig,
          StageBuilder, VFX, FightCamera, FightView, Cutscene
  UI/     Theme, Screens, HUD, Portrait, Subtitles, MobileControls
src/server/Main.server        DataStore profiles (settings + stats), validated remotes
tests/                       Lune test-suites + headless Roblox runtime mock
tools/                       audio synth, atlas packer, pose / rig / UI layout preview renderers
audio/atlas/                 the four audio files to upload
```

## Building and testing

The tools are [Rojo](https://rojo.space) 7, [Lune](https://lune-org.github.io/docs)
0.11 and [Selene](https://github.com/Kampfkarren/selene).

```sh
rojo build -o build/Veilbreakers.rbxlx   # place file
lune run tests/run                       # engine + AI: every input, 128 CPU matches, determinism
lune run tests/client_smoke              # whole client in a mock Roblox runtime
selene src                               # lint (custom std: veil.yml)
python3 tools/synth_audio.py && python3 tools/build_atlas.py   # regenerate audio
```

`tests/client_smoke` loads the real client modules inside a headless Roblox
runtime. Instances come from `@lune/roblox`, so every property name, type and enum
is checked against Roblox's API. It then:

- builds every stage, rig and projectile;
- plays four full CPU matches through the renderer, HUD, VFX, supers and finishers;
- drives every menu screen and every story cutscene;
- walks the real game flow: title → Practice → pause → quit → Versus → results.

It fails on any error raised in any handler.

## Asset credits

- Key art, logo emblem and three stage backdrops: generated with ForgeGUI for this
  project and published to Roblox.
- Characters, weapons, armor, stages and effects: built procedurally from Roblox
  parts, materials and built-in particle textures.
- Music, SFX, voices and ambience: procedurally synthesised by `tools/synth_audio.py`.
