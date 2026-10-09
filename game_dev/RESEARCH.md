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
