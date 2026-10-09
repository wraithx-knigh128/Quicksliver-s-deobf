# TSB mechanics research notes

**Limits:** the sandbox cannot open the fandom wiki or any other site directly (DNS blocked), so everything
below comes from web-search result summaries, not full page reads. Many sources are fan guides/videos and
disagree on numbers. Treat all values as unverified defaults for your own game, and re-check in-game.
Most recent update found: "Cosmic Update" (May 2026) - new Undying Hero character, Hero Hunter Monster form,
Character Creator V1 / skill builder; Tech Prodigy buffed, Brutal Demon & Martial Artist slightly nerfed
(guide claims, conflicting dates). A late-Sep 2026 teaser mentions Zombie Man early access; no official patch notes found.

## Basics
- M1 chain: 4 hits, ~3/3/4/5 % damage, 4th launches; airborne M1 = uppercut-style 4th hit. (games.gg guide)
- Block = hold F; frontal only, back attacks always hit; some moves unblockable. Perfect block = block at the
  moment of the hit, then crit. (games.gg)
- Q = dash; direction from held movement key. Side dash cooldown ~2s, forward dash ~5s (shared with back dash)
  per community wiki; another wiki says ~1s (conflict).
- Counters: Saitama Death Counter, Garou Prey's Peril, Metal Bat Death Blow, Atomic Samurai Split Second
  Counter, KJ Spiraling Storm.

## Ragdoll cancel (the real "tech" recovery)
- Side or back dash while ragdolled frees you; cooldown reported 20-30s (30s most common). Opponent may get
  an M1 in return. Fandom thread: "How long is ragdoll cancel cooldown?"
- Counters to it: Atomic Samurai Quick Slice mid-air; time uppercuts after they burn the cancel; delayed-M1 tech
  (3 M1 -> mini uppercut -> side dash during it -> forward dash) reportedly prevents cancels.

## Techs / combos named in sources
| Name | Summary | Confidence |
|---|---|---|
| Wall combo | 4th M1 near a wall, then forward dash; ~12% dmg, char-specific cinematic, ragdolls; ~6s cooldown (now.gg, unverified); impossible on duel map walls w/o Tatsumaki | medium |
| Uppercut Dash | forward dash right after mini uppercut, loop under target to front-dash; low knockback | medium |
| 3M1 reset | side dash after 3 hits, then front dash to keep chaining M1s | medium |
| Side-dash cancel | side dash then immediately use a move to shorten travel / change angle | medium |
| Backdash cancel / jump cancel | cancel recovery by using an ability immediately / jumping first | low |
| Kyoto combo (Garou) | Flowing Water (M1) -> side dash (A+Q) -> Lethal Whirlwind Stream (M2); hardest link is the middle; 3 M1 opener; easy variant (Gamezebo): Q, M1x3, Flowing Water, side dash, Hunter's Grasp, Q, M1x3, Lethal Stream | medium |
| Twisted combo | hit the legs, dash-catch the legdoll; "Instant Twisted" is the newer easier version; no written inputs found | low |
| Brutal Demon | side dash after Foul Ball -> Homerun | low |
| Deadly Ninja | Fourfold Rebound; Mach Wallcombo (4 M1 at wall -> Flash Strike -> wall combo, ~40%); uppercut into shuriken cancels ragdoll+stuns | low |
| Tech Prodigy | Detonant Assault: 4 M1 at wall -> Weboom -> wall combo -> back side dash + M1 | low |
| **Oreo tech** | Only short videos/TikToks found (a Saitama-labelled tutorial, "blade master" variant). **No written inputs found** - not modelled. Use `Engine.define("Oreo", {...})` once you have them. | none |

## Sources (search results; pages not opened)
- https://the-strongest-battlegrounds-rblx.fandom.com/wiki/Techniques , /wiki/Basic_Combat , /wiki/Combos , /wiki/Updates
- https://itemlevel.net/the-strongest-battlegrounds-list-of-all-best-combos-how-to-do-them/
- https://itemlevel.net/saitama-battlegrounds-how-to-do-the-kyoto-combo-guide/
- https://www.gamezebo.com/walkthroughs/the-strongest-battlegrounds-combos/
- https://games.gg/roblox/guides/the-strongest-battlegrounds-combat-guide/
- https://thenerdstash.com/how-to-do-all-crazy-techs-in-the-strongest-battlegrounds/
- https://now.gg/blog/game-guides/combat-techniques-the-strongest-battlegrounds-en.html
- https://en.namu.wiki/w/The%20Strongest%20Battlegrounds/%ED%8C%81%20%EB%B0%8F%20%EC%BD%A4%EB%B3%B4
- https://earnaldo.com/blog/the-strongest-battlegrounds-update-may-2026
- YouTube: "How to Do Oreo Tech in The Strongest Battlegrounds (Easy Tutorial)" BhaNF2-v8N0; "GAROU ALL TECHS TUTORIAL + KYOTO COMBO AND TWISTED COMBO" mVbSgpfVkQ0

---
## Round 3 additions (all now encoded in `tsb_data.lua`)
Same limit applies: search-result summaries only, no full page reads; fan guides disagree.

**Rosters** (names differ between guides): Saitama/The Strongest Hero, Garou/Hero Hunter (+Monster form), Genos/Destructive Cyborg,
Sonic/Deadly Ninja, Metal Bat/Brutal Demon, Tatsumaki/Wild Psychic, Atomic Samurai/Blade Master, Tech Prodigy (gamepass),
Undying Hero (May 2026). Suiryu: nothing verified. Child Emperor = Tech Prodigy's source character.
Tech Prodigy numbers (Deltia's/games.gg/wiki): Weboom 16.5% 18.3s, Plasma Cannon 10.1/35.2% 20.7s, Trinity Tear 20% 19.5s,
Twin Burst 15.6% 21.5s, M1 "Mechanical Combat" 14% 4 hits; Iron Giant awakening 25%, +115 HP, Photon Edge 51.5% 8s,
Photon Dive 65% 25s, Missiles 15x2.2%, Conquest 100s cd.

**Per-character combos found:** Saitama (beginner/basic/quick/advanced), Genos (easy, ult string), Sonic (easy/extended),
Metal Bat (2 fan routes), Atomic Samurai (3 variants), Tatsumaki (2 + safer Stone Coffin route), Garou (Kyoto variants).
**Universal techs found:** Ragdoll Cancel, Wall Combo/Extend/Tech, True Downslam, Upside Down Ragdoll, M1 Shove, Delayed M1s,
Backdash/Side-dash/Jump cancels, 3M1 reset, Uppercut Dash, anti-cancel string, Saitama/Garou catches.
**Mechanic insights used for prediction:** (1) M1 stun blocks dashing - so true combos are those ending in an M1 stun;
(2) ragdoll cancel is once per ~30s, so predict a cancel attempt on the first ragdoll and a true punish on the second;
(3) many combos share the "M1 x3 -> X" prefix, so the predictor tracks all candidates and weights next inputs.
**Unreliable/ignored:** a wiki page claiming a 25% meter ult-cancel and "40% frame reduction" ragdoll cancel; exploit-script pages.
**Still missing:** Oreo tech inputs, Twisted combo inputs, Suiryu kit, Genos/Sonic/Suiryu-specific techs, official patch notes.

---
## Round 4 (all encoded in `tsb_data.lua`, shown in the Techs tab and as combo cards)
Same limits: search-result summaries only, many sources old/unverified, game patched often.

**Oreo tech** (still no wiki entry): TikTok caption says 3 M1 -> hold jump + release M1 -> press attack again airborne and front dash ->
hold M1 + front dash -> flick camera right and turn back. Separate low-ping / high-ping "Oreo Dash" tutorials exist; a Garou 6.2 variant.
Modelled as a low-confidence combo `Oreo` (camera flick not automated).
**Twisted**: "Twisted Dash" = dash at the opponent right after the 4th M1 (often a small step back first); hitting the legs shortens
knockback. "Instant / True Twisted" = camera flick left/right and back into the twist (not automatable). Nov 2025 fan guide: 4 M1, curved dash,
Flowing Water, Hunter's Grasp catch, grasp punch, Lethal Whirlwind Stream, downslam (~90%, 98.6% best, ~84% without evade bait); needs similar
connections on both sides.
**Per-character techs added:** Genos (Ignition Burst extension, Barrage, "Explosive Fart", uppercut > Blitz Shot), Sonic (Flash Strike extension),
Metal Bat (Foul Ball catch, Death Blow evasion, Grand Slam dodge), Atomic Samurai (Quick Slice Spin, Pinpoint Cut extension),
Tatsumaki (Stone Grave cancel, Windstorm loop-dash / extend), Suiryu (Martial Artist: Bullet Barrage, Vanishing Kick, Whirlwind Drop, Head First;
ults Grand Fissure, Twin Fangs, Earth Splitting Strike, Last Breath; double-tap Vanishing Kick bypasses block), KJ (Collateral Ruin cancels ults).
**Universal:** Micro Dash (move right after a side dash; cancelled side dash ~2 blocks vs front dash ~5), backdash-cancel extension (jump first),
Saitama M1-reset bug (Consecutive Punches while holding M1), mini uppercut > downslam, downslam > Weboom to waste ragdoll cancel.
**Not found / unverified:** exact timing windows for Oreo/Twisted, official per-character tech lists, a real "jump cancel" definition,
"cancel your own ultimate" (single low-quality source), Genos/Sonic tech frame data.
**Timing note:** with a fixed open-loop macro, ping mostly shifts everything equally; it matters for steps that react to what you SEE
(a move ending, the opponent landing). Auto timing shortens only those gaps by ~ping (capped at 40% of the gap) and has a fine-tune offset.

---
## Round 5 - block mechanics, more techs, UI library
(Search-result summaries only; many sources are fan posts. Encoded in `tsb_data.lua`.)

**Block / perfect block** (games.gg, fandom Basic Combat, bloxspot): hold F = arms up, 180 degrees in front, stops all M1s and
many specials, you move slowly and cannot act. ~0.2 s lockout after your own M1. Charged (held) hits break block, grabs ignore it,
attacks from behind always connect. Blocking an M1 at the last moment = a Critical Hit on your next basic (about triple, cracking
sound, lasts until you are ragdolled - one source says ~4 s). A perfect block while a crit is active = Black Flash (about double a
crit, can be passed to another target). Only works on real players. Exact frame windows ("3-frame") are unsourced - ignored.
-> Auto block only answers attacks that can be blocked (in range, aimed at you, in front of you) and shortens its delay by ping.

**More techs found:** Tech Prodigy Weboom Extend V2 (downslam, turn, Weboom, side dash ASAP, forward dash; range nerfed later),
"Child combo" (3 M1, uppercut, 4th move, 2nd move, side dash, front dash - unverified), Metal Bat Homerun > Grand Slam and two
Foul Ball extensions, Genos Longer Jet Dive, Saitama uppercut-shove reset and Uppercut > Shove > M1, Ground Punch tech, Garou
Monster Hammer Heel launch, Suiryu two-skill combo, Sonic "unpunishable" strings, universal Uppercut Jump / Flick / Stun Negation (no steps).

**UI:** the screenshot style matches script-hub libraries (WindUI, Fluent, Rayfield, Luna); WindUI is the best documented. See `UI_GUIDE.md`.

---
## Round 6 - block timing, "predicting" the punch, floater
(Search-result summaries only; fan wikis / guides / forum posts, not game code. Encoded as constants in `tsb_data.lua` Mechanics and as
the learning logic in `block_predict.lua`.)

**What is known about block timing**
* Block (F) is 180 degrees in front; M1s are stopped, charged hits break it, grabs ignore it, hits from behind always connect.
* M1 start-up is roughly 11-12 frames (~0.18-0.2 s at 60 fps). You cannot block for ~0.2 s after your own M1.
* A blocked / missed 4th M1 leaves the attacker stunned ~1 s, which is why "hold block forever" and "hold block never" both lose.
* A well-timed block (right before contact) gives the Critical Hit -> Black Flash chain; a "3-frame perfect block window" is claimed in
  places but unsourced, so the script does not rely on it.
* Damage and block are server-authoritative: the server decides if the F key was down when the hit was evaluated. What the client can
  control is only WHEN the key goes down, and your own ping decides how early that must be.
* **No public per-move hit-frame table exists** (animation ids / hit frames are not on any wiki). Hard-coding hit times would be invented data.

**Design consequence: learn instead of guess.** Each time you lose health the script finds the enemy attack animation that started
shortly before (0.03-1.3 s), and EWMA-averages "animation start -> damage" per animation id (outliers beyond 3x spread are ignored).
That offset already contains network delay in both directions, so it is the number that actually matters. Once an animation has >= 2
samples, F goes down at `offset - lead - ping` (lead default 0.05 s, ping share capped at 80% of the wait) and is held through the hit plus
the "let go" grace. Unknown animations still use the fixed Delay slider. "Predict chain hits" remembers which animation follows which
(M1 1 -> 2 -> 3, seen >= 3 times) and covers the next punch before it shows up. Everything is saved between sessions (max 120 animations).
* Limits: damage from poison / falls / ults can be mis-attributed (an outlier filter and a distance + aim gate reduce this); a move whose
  hit time varies (charged) will learn an average; the first 2 hits per animation are always taken because nothing is known yet.

**"Floater":** no feature called "floater" was found for TSB (searches return only unrelated results). It was implemented as a small round
draggable Auto-block indicator button (grey = off, green = armed, pink = holding; tap = on/off; the Lock button freezes it). If a
hover / float MOVEMENT feature was meant, that is a different thing and was not built.

**Platform note:** the instant "drop block when I punch" works on keyboard/mouse (M1 / move keys). On a phone the quick-release timing
(~1 s cap) is what frees you, because touch buttons cannot be observed the same way.

**Round 6b - what blocks cannot stop (third-party guides, unverified)**
* Unblockable / guard-ignoring according to guides: Downslam (aerial M1 finisher), Ragdoll Cancel's direct hit, Martial Artist's Vanishing Kick,
  Head First (damage only reduced), Grand Fissure / Twin Fangs / Earth Splitting Strike / Last Breath, Whirlwind Drop (hits through guard without
  breaking it), Brutal Demon Homerun / Grand Slam / Foul Ball unblockable options (mostly at M1 range), charged hits, grabs, anything from behind.
* Side dashes are the usual answer to linear attacks, which is why Auto block can optionally side dash instead of holding F.
* **Design consequence:** no animation ids for these moves are public, so the script finds them itself: if you take damage while F had already been
  down for `ping + 60 ms` (so the server must have seen it), that animation is counted; after 2 sightings it is "ignores block" and Auto block can
  Block anyway (default, safest) / Do nothing / Side dash. A false flag can only cost you a skipped block, which is why the default never skips.
* **What learning cannot see:** a blocked hit deals no damage, so it teaches nothing. Learned timings therefore come from hits that reach you
  (Auto block off, or attacks that ignore block). That is why the Tech tab tells you to spar with Auto block OFF for a while to teach it.
* Searches found no frame data, no perfect-block window length and no published hit offsets - none of these numbers are invented.
* The Fandom wiki was not reachable from the build environment this round, so its pages were not read directly.

---
## Round 7 - why Auto block was hit-and-miss, which moves block can stop, going behind a player, a brighter menu
(Search-result summaries and raw theme files only. The Fandom wiki could not be opened from the build environment, so its pages were
not read directly - what is quoted below comes from the search summaries of those pages.)

**Which moves ignore block (names only; encoded in `block_info.lua`, shown per character in the menu)**
* Wiki "Basic Combat" (via search summary): block protects against basic attacks and some moves from a 180 degree angle; attacks that break
  through it include Normal Punch (up close), Shove, Uppercut, Flowing Water and Hunter's Grasp.
* The Strongest Hero (Saitama): Normal Punch is unblockable on a direct hit; Uppercut unblockable. No blockability note found for Consecutive Punches,
  Serious Punch, Table Flip, Death Counter.
* Hero Hunter (Garou): "7 block-bypassing moves" (more than any character). Flowing Water - unblockable / guardbreak (several guides);
  Hunter's Grasp - armoured grab, unblockable; Crushed Rock (rampage) - advancing grab, unblockable. **Lethal Whirlwind Stream: guides contradict**
  (one says guardable, others say its AoE cannot be blocked) -> kept as "disputed" and never skipped.
* Brutal Demon (Metal Bat): Homerun, Grand Slam, Foul Ball are the block-breakers (punishable end lag).
* Destructive Cyborg (Genos): most base moves blockable, chip damage still gets through. Blade Master: Pinpoint Cut blockable.
* Martial Artist: Vanishing Kick, Head First (damage only reduced), Grand Fissure, Twin Fangs, Earth Splitting Strike, Last Breath unblockable;
  Whirlwind Drop hits through guard without breaking it. Event characters: Grave Maker, Pincer Barrage unblockable.
* Nothing usable was found for Sonic, Wild Psychic (Tatsumaki) or Tech Prodigy blockability -> they are treated as blockable.
* Perfect-block window / hit frames: still nothing public ("the window is short, worth practicing" is all any guide says). No numbers invented.
  The script learns hit times from the hits you take instead (Round 6) and now reads the animation's NAME so known moves are recognised.

**Why Auto block worked "sometimes" - found by auditing the code, each one fixed**
1. It only listened to `AnimationPlayed`. Now it ALSO polls every enemy Animator 10x a second and answers tracks the event missed (one track is never answered twice).
2. It tested "is he looking at me" at the exact frame the swing started - TSB M1s snap onto the target, so real attacks were thrown away.
   Now: 90 degree half-cone by default, no aim test when he is within 4 studs, and a fast attacker running at you counts as aimed.
3. It tested distance at the first frame - a dashing attacker starts far away. Now it predicts both positions at the moment of the hit.
4. Idle / movement-layer animations were dropped even when they were real attacks. Now a known attack NAME or an animation that hurt you before overrides the priority filter.
5. A hit that lands after your own M1 (the game's ~0.2 s block lockout) was discarded. Now F goes down the moment the lockout ends if the hit is still coming.
6. Defaults were tight (0.10 s delay, "just before the hit"). Now 0.05 s delay and the "Safe" style (F ~0.12 s before a learned hit).
7. Nothing told you WHY a swing was ignored. The Tech tab now shows the last decision and counters ("2x too far away, 1x not aimed at you").
Honest limit: none of this could be run against the real game here; the readout exists so a remaining miss can be explained from what it prints.

**Dash behind a player (the "side dash from the back")**
* Hits from behind always connect (block covers only the front 180 degrees), so the goal is to end up behind the closest player. Guides also describe
  "dashing behind the opponent" as the answer to a ragdoll cancel. Nothing is teleported: the script only picks WHICH key goes with Q.
* Maths (`combat_math.lua`): angle of me around him (0 = in front, 180 = behind, "behind" from 120), the next step along the circle (the tangent that
  turns me away from his front, pulled inwards when far), then the movement key closest to that direction in CAMERA space (movement keys are
  camera relative). One key per dash, because a dash goes the way of one key.
* Caveats: dash distance and cooldowns are not public (guides: side dash ~1-2 s, front/back dash ~5 s shared), so a second dash of the same kind may
  be on cooldown; "most dashes" (1-3) and the wait between them are adjustable and the loop stops as soon as you are behind him.

**Menu**: measured luminance of the old window 0.03 -> new ~0.16 with text contrast >= 4.5 : 1 (details and references in `UI_GUIDE.md`).

---
## Round 8 - the "side dash to the back" (what the guides say) and what changed
(Search summaries only; the Fandom / Bloxodes / NamuWiki pages are blocked from the build environment, so they could not be read directly.
Several sources are TikTok-style tips or SEO guides - treat them as unverified. The YouTube video titled "SIDE DASH TRICKS PRO PLAYERS DONT TELL
YOU ABOUT" has no written source; only its thumbnail (an arrow curving round a dummy) was seen.)
* The inputs are plain: **Q + A = side dash left, Q + D = side dash right** (itemlevel combo guide). There is no separate "behind" input.
* **Cooldowns:** a side dash ~**2 s**, a forward dash ~**5 s** (back dash shares the forward one); Ragdoll Cancel (side / back dash while ragdolled) ~20-30 s.
* **Why the back:** block covers only the 180 degrees in front; a player who keeps blocking is beaten by "hit them once or twice, then side dash to
  their back" (games.gg-based summary). Everyone side dashes, so speed and mixing up the direction matter.
* **Side dash cancel:** side dash, then use a move / M1 immediately - the dash is cut short and you hit from an unexpected angle.
* Also described: side dash on the 4th M1 to escape its stun; Sonic orbits an opponent with side dashes; "long arm" / "hook dash" are named
  advanced side dashes (one unverified coaching listing); Deadly Ninja is the only character with special side dashes.
* **What this means for the button:** it must be a real SIDE dash (A or D) - round 7 could also pick W / S (front / back dash) when the camera was turned
  away from the player. Now it only ever chooses between A and D: the one whose direction (round him toward his back, pulled in when far)
  has the larger sideways part for the current camera. Because the side dash cooldown is ~2 s, the default wait before a second dash is 2.1 s and
  the default is a single dash; the stop test counts "behind" from 105 degrees (his block ends at 90). After the dash it waits for the dash to finish
  (0.3 s) and only then hits, and only if it really ended up behind him (it never punches from the front by mistake).
* Not known: whether TSB's side dash curves round a target by itself (the thumbnail arrow suggests a hook) or is camera-lateral only. The maths assumes
  camera-lateral, which is also the best case when your camera looks at him (then A / D is exactly "round him").
