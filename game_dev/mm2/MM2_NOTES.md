# Murder Mystery 2 - what is known, what is assumed, how the hub copes

This file separates **facts I could find**, **common knowledge I could not verify**, and **things nobody publishes**
(bullet speed, knife speed, hitbox sizes, remote names). The hub is built so that nothing in the third group is hard-coded:
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
| Perfect aim | **Replay** the recorded call with the aim point replaced by the predicted position (and hit-part / humanoid / character arguments swapped to the new target), or **Silent aim**: do the same swap on your own shots as they leave. If no shot has been recorded the hub falls back to *aim + `Tool:Activate()`* (or your configured throw key). |
| Hook safety | The hook only reads properties (no method calls - those can corrupt the pending method name in some executors), never yields, restores `setnamecallmethod`, and is inert after you unload. |

If something does not work, open **Debug**: it lists what your executor supports, which shots were recorded (remote, method, argument
shape such as `cf=origin,cf=target`) and the script's own log, and **Copy diagnostics** puts all of it on your clipboard.

## 4. Feature map

- **Main** - live round info (you / murderer / sheriff), gun finder status, announcements (murderer, sheriff, gun drops, murderer nearby),
  quick actions (Shoot the murderer, Throw knife, Grab gun).
- **ESP** - role-coloured chams, names, distance, health, tracers (needs the executor's `Drawing`), gun ESP + tracer.
- **Combat** - target rules (role-aware), prediction, aim assist (camera / cursor / both, smoothing), gun and knife tools, auto shoot / auto
  throw / slash aura, silent aim, hitbox expander.
- **Player** - walk speed, jump power, infinite jump, noclip, field of view.
- **Misc / Settings / Debug** - anti-AFK, rejoin, server hop, themes, config (saved **only** when you press *Save config*), unload.

## 5. Honest limits

- Everything above runs on **your client**. Servers can and do reject impossible shots; anything the server validates is out of my reach.
- The roles are only as good as what the client can see. Without the data remote, an unarmed murderer looks like an innocent until the
  knife is out.
- Using scripts in Roblox games breaks the Terms of Use and can get an account banned. There is deliberately **no anti-detection**,
  no obfuscation and no humanisation in this hub.
