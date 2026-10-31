# OOF FIGHTERS 1 — The Great Server Reset

A Roblox parody of modern kombat-style fighting games: "Mortal Kombat 1... but in
Roblox." Full dark, over-the-top 2.5D fighter presentation (towers, story chapter
with cinematics, supers, finishers, an announcer that will not stop yelling)
starring Roblox-meme fighters instead of ninjas and thunder gods.

![Roster](docs/roster_preview.png)

*Roster and Friends rendered offline from the real rig code (`tools/rig_dump.luau`).
In Roblox they're lit, shadowed and animated.*

## The roster

| Fighter | Bit | Style |
| --- | --- | --- |
| **The Noob** | Default avatar since 2006. Possessed by storm spirits while AFK. | Katana rushdown: Ping Spike, Lag Dash, Rage Jump, AFK Parry |
| **Bacon Hair** | Saved three years for 400-Robux wings. Will stab you about it. | Spear control: Free Halo, Skewer Run, Report Button |
| **Studzilla** | 2008 kaiju built from free bricks and never anchored. | Grappler: Unanchored Hug, Brick Wave, Anchored Mode |
| **Guest 666** | The guest account that should not exist. Always behind you. | Teleport mix-ups: Behind You, Jumpscare, Spam Click |
| **Frosty** | "cool ice guy no virus" from the toolbox. Has four viruses. | Hammer zoner: Ice Cube Toss, Hammer Time, Anti-Exploit Wall |
| **Emote Queen** | Owns every dance, paid for none. Fights in choreography. | Rushdown: Hula Hoop Toss, Moonwalk Slide, Spin Emote |
| **The Camper** | Hasn't moved from her bush in six days. | Crossbow zoner: Bush Shot, Yoink Hook, Hide In Bush |
| **The Admin** *(boss)* | Bought admin for 25 Robux. Typing ;shutdown. | Power boss: ;fire all, ;speed 100, ;tp me, ;explode all |

**Friends** (call one in mid-fight): Grandpa Studs, Dog Walker Dana (and Biscuit),
The Night Guard and Pigeon Lady.

**Arenas:** Anime Dojo Simulator, The Spooky Obby Forest, Flooded Church Escape,
The Admin's Lava Throne and The Baseplate.

Finishers end with the classic Roblox break-apart: every part pops loose and
clatters across the floor with a big **OOF**.

## Play it

1. Open **`build/OofFighters1.rbxlx`** in Roblox Studio (File → Open from File).
2. Press **Play** (F5). Fights run on your client against the CPU, so solo
   playtesting is the full experience.
3. Optional: **File → Publish to Roblox** to play it on phone, tablet, console or PC.

The images (key art, emblem, stage backdrops) are already uploaded and approved on
Roblox. To hear the full soundtrack and SFX, follow the **Audio** step below.
Until then the game uses a handful of built-in Roblox sounds and is otherwise silent.

## Audio (one-time, 4 uploads)

The complete sound pack (≈80 SFX, voice grunts and an "oof", 4 ambience beds and 7 music tracks)
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
| **Story** | *Chapter I — The Great Server Reset.* The Admin typed ;shutdown. 9 letterboxed, subtitled scenes and 4 fights, ending with the Admin. |
| **Tower** | Seven tryhards in a row, ramping difficulty, with the Admin waiting at the top. Every fighter has a (dumb) three-card ending. |
| **Versus** | Pick your fighter, your Friend, the opponent, the server and the CPU difficulty (Noob, Pro, Tryhard, Sweat). |
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
| Call a Friend (+ down for variant) | O | LB | **FRIEND** |
| Super (2 bars) / Rage Quit (in a combo) | P | RT | **SUPER** |
| Throw (Block + Light) | H | LT | **THROW** |
| Dash / backdash | double-tap → / ← | double-tap | double-flick the stick |
| Pause | Tab | Start / Select | **II** |
| Finisher (at *DELETE THEM*) | hold S + I | hold ↓ + B | hold ↓ + **SP** |

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
- **Friends** (internally "Echoes"): each fighter brings an ally with a neutral and
  a down variant on a cooldown, usable mid-combo. Your Friend leaves if you get hit
  before they strike.
- **Rage meter (3 bars):** a 2-bar cinematic **Super** that's invulnerable on
  startup, or a 1-bar **Rage Quit** to burst out of a combo.
- **Throw escapes**, dashes and backdashes, wake-up invulnerability, chip damage
  that can't KO, time-out decisions and sudden death.
- **Finishers:** win the final round, then hold down + Special during *DELETE THEM*
  for your fighter's finisher cinematic (Factory Reset, Extra Crispy, ;kill...). It
  ends with the classic Roblox break-apart and an OOF instead of gore.

## The CPU

`src/shared/Combat/AI.luau` drives the same input table a player does. It sees the
fight through a reaction delay and rolls difficulty-scaled chances to block (and
read high, low or overhead), punish unsafe moves, anti-air, tech throws, break
combos and use parry stances. It runs authored per-fighter combo routes, zones
with projectiles, keeps each archetype's preferred range, and calls Friends and
Supers.

## Project layout

```
default.project.json         Rojo project (Lighting = Future, no auto characters)
build/OofFighters1.rbxlx     ready-to-open place file
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
rojo build -o build/OofFighters1.rbxlx   # place file
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

## Previews

`tools/rig_preview.py` and `tools/ui_preview.py` render offline previews from the
real code: `docs/attacks_preview.png` shows heavy-attack poses, and
`docs/hud_layout.png` / `docs/hud_touch_layout.png` show the HUD layout for desktop
and touch. These are layout mock-ups, not in-engine screenshots.

## Asset credits

- Key art, logo emblem and three stage backdrops: generated with ForgeGUI for this
  project and published to Roblox.
- Characters, weapons, armor, stages and effects: built procedurally from Roblox
  parts, materials and built-in particle textures.
- Music, SFX, voices, the oof and ambience: procedurally synthesised by
  `tools/synth_audio.py`.
