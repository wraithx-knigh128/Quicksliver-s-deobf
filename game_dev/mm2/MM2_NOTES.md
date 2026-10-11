# Murder Mystery 2 - what is known, what is assumed, how Wraith's Hub copes

This file separates **facts I could find**, **common knowledge I could not verify**, and **things nobody publishes**
(bullet speed, knife speed, hitbox sizes, remote names). Wraith's Hub is built so that nothing in the third group is hard-coded:
it discovers it while you play (see "How the hub copes").

## 1. The game

Murder Mystery 2 (place id `142823291`) is a social-deduction round game. A round has three kinds of player:

| Role | What they have | Goal |
|---|---|---|
| **Innocent** | nothing (they can run, hide, pick up coins) | survive until the timer ends |
| **Sheriff** | a **gun** that must reload after every shot | find and shoot the murderer |
| **Murderer** | a **knife**: stab up close, or **throw** it from a distance | kill everyone (innocents and the sheriff) before the timer ends |

- Everyone starts as an innocent; the server secretly picks one murderer and one sheriff per round. The pick is weighted so players who
  have not been murderer for a while are more likely to get it.
- If the **sheriff dies, the gun drops** where they fell. Any innocent can pick it up and becomes the **hero** (Roblox wiki name for that
  situation; the hub colours it gold).
- Win conditions: murderer wins by killing everyone, sheriff/innocents win when the murderer dies or the time runs out.
- Other round modes exist: Classic, Disguises, Assassin, Infection, Double Up, Freeze Tag. Some change who has which weapon
  (Infection: the infected are the "murderers"; the hub calls them `Infected` and colours them orange).
- Extras: weapon skins ("Godly", "Ancient", "Chroma" rarities), crates opened with coins/gems, pets, emotes, and **powers** bought for
  the murderer / sheriff (community lists mention Ghost and Sprint with ~30 s cooldowns, X-Ray ~26 s, Haste = +10 % speed while holding the knife).
  Powers are not touched by this hub.

Sources consulted (public fan wikis and guides; none of them publish numbers):
[MM2 wiki - Sheriff](https://murder-mystery-2.fandom.com/wiki/Sheriff) (the gun must reload after each shot and is described as
"inaccurate", best at mid/close range), [MM2 wiki - Murder Mystery](https://murder-mystery-2.fandom.com/wiki/Murder_Mystery),
a [powers/cooldowns list](https://www.mmoexp.com/News/murder-mystery-2-powers-tier-list-best-abilities-costs-what-to-buy-first.html).

## 2. How shooting and knife throwing work (what is actually known)

**Not published:** bullet speed, whether the gun is hitscan or a travelling bullet, reload time, knife throw speed / range / cooldown,
the size of any hitbox, and the names of the RemoteEvents the tools use. The developers do not document them and I could not fetch
the wikis' numeric pages from this environment, so **I do not claim any of those numbers**.

What is true of almost every Roblox murder-style game (and what the DevForum threads about "knife + revolver" systems describe):

1. The tool's **local script** runs on your client. When you click / tap it reads where you are aiming (mouse hit, or a ray through the
   tapped screen point) and **fires a RemoteEvent** to the server with something like *(origin, aim point)*.
2. The **server decides** whether it hit (a raycast or a projectile simulated on the server) and applies the kill.
3. The server tells other clients to draw the shot/knife so everyone sees it.

Consequences for this hub:

- **Aiming** works because step 1 trusts *your* client: whatever aim point your client sends is the one the server evaluates.
  So the reliable trick is to make the aim point right (camera lock / cursor lock / silent aim).
- A **thrown knife or bullet that travels** needs a *lead*: the hub predicts with the target's velocity, your ping and an optional
  projectile speed. Leave "Bullet speed" at 0 if the shot is instant, set it if you measure that it is not.
- **Hitbox expander**: growing another player's `HumanoidRootPart` on *your* screen only helps if hit detection uses what *your
  client* sees (client raycast / `Touched`). If the server raycasts against its own copy of the characters (the usual, safer design),
  it does nothing at all. It is shipped as "experimental" for that reason, with a toggle and a restore-on-off.
- The **sheriff dies if they shoot an innocent** in normal Classic play (check in game). That is why the default target mode for the gun
  is *Murderer only*: with the murderer unknown, the hub fires at nobody instead of guessing.

## 3. How the hub copes with the unknown parts

| Need | What the hub does |
|---|---|
| Who is the murderer / sheriff? | (a) reads `Knife` / `Gun` tools in everybody's character (and your backpack), (b) listens to `PlayerDataChanged` and polls `GetPlayerData` under `ReplicatedStorage` **if they exist** (names taken from long-standing community scripts - unverified, so every step is guarded), (c) expires stale data when the map disappears. |
| Where did the gun fall? | `workspace.DescendantAdded` for a part/model called `GunDrop` (exact match; `Gun*` names only for 6 s after a sheriff dies), plus a start-up scan, plus a fallback "Sheriff down near ..." when no drop object shows up. Direction is worded relative to where your camera looks ("37 studs ahead-left, 6 higher"). |
| Which remote fires the gun / knife? | A `__namecall` hook records the **real** `FireServer` / `InvokeServer` call when *you* shoot or throw: remotes inside the equipped tool, or (within 0.6 s of your click) any remote whose name looks like shoot/fire/throw/knife/gun/stab/slash. It stores the argument list, classifies which `Vector3` / `CFrame` is the *origin* (closest to your head) and which is the *aim point*, and remembers the remote's **path inside the tool**, so it still works after the tool is re-created next round. |
| Perfect aim | **Replay** the recorded call with the aim point replaced by the predicted position (see "Aiming by ping" below) (and hit-part / humanoid / character arguments swapped to the new target), or **Silent aim**: do the same swap on your own shots as they leave. If no shot has been recorded the hub falls back to *aim + `Tool:Activate()`* (or your configured throw key). |
| Hook safety | The hook only reads properties (no method calls - those can corrupt the pending method name in some executors), never yields, restores `setnamecallmethod`, and is inert after you unload. |

If something does not work, open **Debug**: it lists what your executor supports, which shots were recorded (remote, method, argument
shape such as `cf=origin,cf=target`) and the script's own log, and **Copy diagnostics** puts all of it on your clipboard.


## 3b. Aiming by ping

The server judges a shot against where the target IS when the shot arrives, not where your screen shows it. Your screen is behind by the render delay
of other players plus half the round trip, and the shot needs another half round trip to get there, so the aim point is

    target position  +  velocity x ( ping x compensation + render delay + trim [+ bullet flight] )

- **ping**: `Stats.Network.ServerStatsItem["Data Ping"]` sampled every 0.25 s; the value used is the EMA of the median of the last five samples, so a single lag
  spike cannot throw the aim off, while a real change in connection is followed within a second or two.
- **render delay** (default 50 ms, slider 0-200) and **trim** (-100..+200 ms) exist because that part is an estimate - tune them if your shots land consistently
  ahead of or behind a runner. **Ping compensation** (0-1.5x) scales the ping part.
- **velocity**: the engine's `AssemblyLinearVelocity` when it reports one; otherwise the displacement over the last 0.18 s of recorded positions. A jump faster
  than 90 studs/s is a teleport / respawn and is never treated as running, and no speed above 90 studs/s is ever used.
- the aim is **recomputed after the weapon is equipped** and one frame before it fires, because the target keeps moving during those frames.
- limits: the lead is capped at 0.8 s; if the game rewinds players for lag compensation, "Ping compensation" 0 is the right setting.

## 3c. On-screen buttons, waves, reticle

- The **SHOOT / THROW / GRAB GUN** buttons live in their own ScreenGui, so they stay when the menu is hidden. A tap fires, moving more than 8 px drags (never fires),
  *Lock* turns dragging off (and a long swipe is then not a tap either), the icon dims when you do not hold the weapon, and the ring flashes green / red.
  SHOOT / THROW / SPEED draw licensed [Lucide](https://lucide.dev) icons (MIT, `ICON_ASSETS` in `ui_lib.lua`, same `vendor/lucide_subset.json` ids WindUI uses) - crosshair, sword
  (no plain "knife" exists in Lucide) and bolt; GRAB GUN / JUMP stay the small hand-drawn vector shapes, since Lucide has no gun icon to use instead.
- Every button wears a **wave skin**: three transparent frames over the button, each with a `UIGradient` whose colour / transparency sequence is a sharpened sine
  (20 keypoints: thin grey-white crests on transparent) at a different angle, whose `Offset` slides with a different speed and phase. One Heartbeat connection
  moves them all (30 fps on High, 15 fps and one layer on Low); skins on hidden pages or a hidden window are skipped.
- The **reticle** follows the same target and predicted point the shot uses and glides onto it with exponential smoothing.

## 3d. The menu (WindUI), outlines, the picture, the fallback

- The window is **WindUI** (Footagesus/WindUI release, MIT). `mm2/vendor/windui.lua` is the release file, unchanged; `vendor/patch_windui.py` applies three exact-string patches when
  the script is built: the library always uses its icon module with a built-in set of 76 Lucide icons (`vendor/lucide_subset.json`: name -> Roblox asset id from Footagesus/Icons)
  instead of downloading six icon packs and, when that fails, waiting forever for a Studio-only server remote. `mm2/windui_ui.lua` adapts it to the hub's small window API (`Tab` /
  `Toggle` / `Slider` / `Dropdown` / `Keybind` / `Input` / `Button` / `Label`, `Notify`, `GetState` / `SetState`), so the hub's code does not care which menu is in use.
  The floating buttons and the outline water always come from `ui_lib.lua` (a "headless" instance of it), so they live in their own ScreenGui.
- WindUI never selects a tab by itself (the official example does not either), so the hub selects "Main" once the tabs exist.
- **Outlines**: `win:Outline(host)` = a `UIStroke` (plus a wider, fainter glow stroke) whose `UIGradient` is a 20-keypoint sharpened sine of greys and whites; the gradient's `Rotation`
  turns, so the bands run round the border. It is used on the window (a transparent frame with only a border), on WindUI's buttons (only while their tab is open) and on the floating
  buttons. The wave mode sets the update rate (High 30 / Low 15 / Off still); nothing runs while the window is closed. Nothing is drawn INSIDE any of them.
- **Cards** are made translucent (every theme's `ElementBackgroundTransparency` is raised to at least 0.42) and each carries a static fade-out gradient to the right.
- WindUI is embedded as a function that is only called inside a protected call. If it fails to load or to build its window, whatever it made is removed and the **Classic** menu starts
  (toast + Debug > Log). A WindUI toggle / slider / dropdown reports the value the hub itself just set; the adapter compares with its own copy and ignores that echo, so `Set(v, true)`
  is silent and `Set(v)` behaves like a tap.
- **The topbar "x" is NOT WindUI's own Close button.** WindUI's native one opens a confirmation dialog ("you will not be able to open it again") and, if confirmed (or if
  `IgnoreAlerts` is set, immediately with no confirmation), calls `Window:Destroy()` - a one-way teardown, never a hide. We hide all three native topbar buttons
  (`Window:DisableTopbarButtons{"Close", "Minimize", "Fullscreen"}`) and add our own small dot in their place, wired to `Window:Close()` (the *method* on the window object, a
  different thing from the topbar button despite the name) - that is the reversible hide WindUI's own `ToggleKey` / `win:SetVisible(false)` already use, leaving the open button on
  screen to bring it back. (This was the "I can't close the hub or minimise it" bug: tapping WindUI's real close button either showed a dialog the player didn't expect, or - with
  no dialog - destroyed the whole window outright, with no way back short of re-running the script.)
- **Smooth start**: the floating buttons are created before the menu; the menu is built a few controls per frame (6, or as many as fit in ~12 ms), and the ESP is already running
  (`Roles.scan()` + `ESP.update()` are called before the menu is built).
- **Picture / video**: `win:SetBackground(link)`. A link is a direct `.mp4` / `.webm` / `.png` / `.jpg`, or a pixabay.com video page (the page is read and its `cdn.pixabay.com/...mp4`
  link used, medium size preferred). The file is fetched with `request` (browser-like headers) and `HttpGet` as the fallback, saved to `WraithsHub/assets/bg_<hash>.<ext>` and shown with
  `getcustomasset` in a `VideoFrame` / `ImageLabel` in WindUI's window-background layer, plus a dimming frame. Not verified against the real Pixabay site (not reachable from the
  build environment), and `VideoFrame` with a custom file depends on the executor - WindUI's own docs say it "may not work".

## 3e. ESP, role detection speed, auto targets

- Colours: murderer / infected red, sheriff / hero blue, innocent green, dropped gun orange. Highlights fade in (0.2 s) and colour changes are tweened (0.15 s); a removed player is
  removed at once.
- Roles are re-read the frame something changes: `ChildAdded` / `ChildRemoved` of a character or the backpack (a knife or gun appears), `CharacterAdded` (spawn), `Humanoid.Died`,
  `PlayerAdded` / `PlayerRemoving`, `PlayerDataChanged`, a gun drop appearing or disappearing; a periodic scan (0.3 s) stays as the safety net. Only changed properties are written.
- Targets in "Auto (by my role)": the gun's target is the murderer (nobody else, ever); the knife's target is the nearest player in range and in line of sight. Either floating button
  uses whichever weapon you actually have.
- Firing order: the shot you recorded by hand -> the known remote layouts below (**off by default**, only if switched on in Combat and the remote exists under the weapon) -> the
  tool's `Activate` / the game's throw key. Known layouts (UNVERIFIED, from other MM2 scripts): `Gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, aimPoint, "AH2")`,
  `Knife.Events.KnifeThrown:FireServer(CFrame(origin), CFrame(aim))`, `Knife.Throw:FireServer(CFrame(origin), CFrame(aim))`.
  **Why off by default:** `FireServer` never reports whether the server did anything with the call - a wrong guess among the layouts above can "work" from the client's point of
  view (no error, so the hub says "Shot fired" / "Knife thrown") while the server silently ignores it, because the remote exists under the weapon but isn't actually what it does, or
  takes different arguments. That is indistinguishable from a real success without seeing the round actually react, so defaulting this off means a weapon with nothing recorded yet
  goes straight to `Activate()` / the throw key instead - the same call a manual click makes, which is the only one of the three paths that is not a guess.

## 4. Feature map

- **Main** - live round info (you / murderer / sheriff), gun finder status, announcements (murderer, sheriff, gun drops, murderer nearby),
  quick actions (Perfect shoot, Perfect throw, Grab the gun).
- **ESP** - role-coloured chams, names, distance, health, tracers (needs the executor's `Drawing`), gun ESP + tracer.
- **Combat** - target rules (role-aware), prediction, aim assist (camera / cursor / both, smoothing), gun and knife tools, auto shoot / auto
  throw / slash aura, silent aim, hitbox expander.
- **Buttons** - the floating SHOOT / THROW / GRAB GUN buttons and the wave skin.
- **Player** - walk speed, jump power, infinite jump, noclip, field of view, anti-AFK, rejoin, server hop.
- **Settings / Debug** - themes, menu style (WindUI / Classic), window background (video link, dimming), config (saved **only** when you press *Save config*), unload; executor support, recorded shots, log, diagnostics.

## 5. Honest limits

- Everything above runs on **your client**. Servers can and do reject impossible shots; anything the server validates is out of my reach.
- The roles are only as good as what the client can see. Without the data remote, an unarmed murderer looks like an innocent until the
  knife is out.
- Using scripts in Roblox games breaks the Terms of Use and can get an account banned. There is deliberately **no anti-detection**,
  no obfuscation and no humanisation in this hub.
