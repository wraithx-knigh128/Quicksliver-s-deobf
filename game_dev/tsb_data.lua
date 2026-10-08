--[[
    tsb_data.lua - everything found in research, as plain data (see RESEARCH.md for sources).

    Token vocabulary used in combo steps:
      M1  Q (dash key)  FRONTDASH  SIDEDASH  BACKDASH  JUMP  JUMP_M1 (m1 in air)
      UPPERCUT  MINI_UPPERCUT  DOWNSLAM  + any move name in UPPER_SNAKE_CASE
    confidence: "high" | "medium" | "low"  (how many independent sources agree / how old they look)
    Names/numbers differ between fan guides and the game is patched often: tune these for your own game.
]]

local function rep(token, n) local t = {} for i = 1, n do t[i] = token end return t end
local function seq(...)
    local out = {}
    for _, part in ipairs({...}) do
        if type(part) == "table" then for _, v in ipairs(part) do out[#out + 1] = v end
        else out[#out + 1] = part end
    end
    return out
end
local M1x3, M1x4 = rep("M1", 3), rep("M1", 4)

local Data = {}

---------------------------------------------------------------- characters
Data.Characters = {
    ["The Strongest Hero"] = { alias = "Saitama",
        moves     = {"NORMAL_PUNCH", "CONSECUTIVE_PUNCHES", "SHOVE", "UPPERCUT"},
        ultimates = {"DEATH_COUNTER", "TABLE_FLIP", "SERIOUS_PUNCH", "OMNI_DIRECTIONAL_PUNCH"},
        counter = "DEATH_COUNTER", notes = "Serious Punch listed as ultimate by one guide, normal move by another. Death Counter window ~10s." },
    ["Hero Hunter"] = { alias = "Garou",
        moves     = {"FLOWING_WATER", "LETHAL_WHIRLWIND_STREAM", "HUNTERS_GRASP", "PREYS_PERIL", "SINGULARITY"},
        ultimates = {"WATER_STREAM_CUTTING_FIST", "THE_FINAL_HUNT", "ROCK_SPLITTING_FIST", "CRUSHED_ROCK", "NUCLEAR_FISSION"},
        counter = "PREYS_PERIL", notes = "Awakening ult called Rampage by one guide. Crushed Rock/Water Stream are lead-ins to Final Hunt. Grand Slam can dodge his awakening startup (needs grounded target)." },
    ["Hero Hunter (Monster form)"] = { alias = "Garou Monster",
        moves     = {"DOOM_DIVE", "CROWD_BUSTER", "HAMMER_HEEL", "BINDING_CLOTH"},
        ultimates = {"HUNTERS_MARK", "GREAT_FAJIN", "GOD_SLAYER", "SKYRIPPING_FIST"}, notes = "Added/changed in Cosmic Update (May 2026)." },
    ["Destructive Cyborg"] = { alias = "Genos",
        moves     = {"MACHINE_GUN_BLOWS", "IGNITION_BURST", "BLITZ_SHOT", "JET_DIVE"},
        ultimates = {"THUNDER_KICK", "SPEEDBLITZ_DROPKICK", "FLAMEWAVE_CANNON", "INCINERATE"},
        notes = "Highest raw damage per one guide. Saitama+Genos ultimates near each other trigger a duel cutscene." },
    ["Deadly Ninja"] = { alias = "Sonic",
        moves     = {"FLASH_STRIKE", "WHIRLWIND_KICK", "SCATTER", "EXPLOSIVE_SHURIKEN"},
        ultimates = {"TWINBLADE_RUSH"}, notes = "Ult list may be incomplete. Fourfold Rebound / Mach Wallcombo techs." },
    ["Brutal Demon"] = { alias = "Metal Bat",
        moves     = {"HOMERUN", "BEATDOWN", "GRAND_SLAM", "FOUL_BALL"},
        ultimates = {"SAVAGE_TORNADO", "BRUTAL_BEATDOWN", "STRENGTH_DIFFERENCE", "DEATH_BLOW"},
        counter = "DEATH_BLOW", notes = "Death Blow is the counter per one guide. Slightly nerfed in Cosmic Update (guide claim)." },
    ["Wild Psychic"] = { alias = "Tatsumaki",
        moves     = {"CRUSHING_PULL", "WINDSTORM_FURY", "STONE_COFFIN", "EXPULSIVE_PUSH"},
        ultimates = {"TERRIBLE_TORNADO"}, notes = "Sources conflict (another lists Psychic Push/Gravity Pull/Psychic Strike/Telekinesis). Skills hit ragdolled targets -> wall combo always possible. Windstorm Fury is not a true combo." },
    ["Blade Master"] = { alias = "Atomic Samurai",
        moves     = {"QUICK_SLICE", "ATMOS_CLEAVE", "PINPOINT_CUT", "DEADLY_CASCADE", "SPLIT_SECOND_COUNTER"},
        ultimates = {"SUNSET", "SOLAR_CLEAVE", "SUNRISE", "ATOMIC_SLASH"},
        counter = "SPLIT_SECOND_COUNTER", notes = "Quick Slice can catch ragdoll-cancelling players mid-air." },
    ["Tech Prodigy"] = { alias = "Child Emperor", gamepass = true,
        moves = {
            WEBOOM          = {dmg = 16.5, blocked = 8.6, cd = 18.3},
            PLASMA_CANNON   = {dmg = 10.1, charged = 35.2, cd = 20.7},
            TRINITY_TEAR    = {dmg = 20, aoe = 15, cd = 19.5},
            TWIN_BURST      = {dmg = 15.6, blocked = 7.1, cd = 21.5},
            DOUBLE_TROUBLE  = {dmg = 17.5},
            PINCER_BARRAGE  = {dmg = 12, cd = 6},
        },
        m1 = {name = "MECHANICAL_COMBAT", dmg = 14, hits = 4, note = "hit1 rolls, hit2 ragdolls; air m1 = uppercut, landing m1 = stomp"},
        awakening = {name = "IRON_GIANT", dmg = 25, hp = 115, moves = {
            PHOTON_EDGE = {dmg = 51.5, cd = 8}, PHOTON_DIVE = {dmg = 65, cd = 25},
            MISSILES = {dmg = 30.2, hits = 15, per = 2.2}, CONQUEST = {cd = 100, note = "one-time lethal grab"},
        }},
        notes = "Buffed in Cosmic Update (guide claim). Numbers vary by source/patch." },
    ["Undying Hero"] = { alias = "Zombie Man", moves = {"GRAVE_MAKER"}, notes = "Added May 2026: axe + guns, 119 Robux early access." },
    ["Martial Artist"] = { alias = "Suiryu",
        moves     = {"BULLET_BARRAGE", "VANISHING_KICK", "WHIRLWIND_DROP", "HEAD_FIRST"},
        ultimates = {"GRAND_FISSURE", "TWIN_FANGS", "EARTH_SPLITTING_STRIKE", "LAST_BREATH"},
        notes = "Added Dec 2024 (undated Techwiser table). Fast M1s + AoE; double-tap Vanishing Kick reportedly bypasses block. Slightly nerfed in Cosmic Update (guide claim)." },
    ["KJ"] = { alias = "KJ", counter = "SPIRALING_STORM",
        moves     = {},
        ultimates = {"FIVE_SEASONS", "COLLATERAL_RUIN", "STOIC_BOMB"},
        notes = "Only partial info found. Collateral Ruin reportedly cancels many ultimates/base/counter moves; also a '20-20-20 Dropkick'." },
}

---------------------------------------------------------------- game numbers
Data.Mechanics = {
    m1Chain               = {3, 3, 4, 5},
    wallComboDamage       = 12,
    wallComboCooldown     = 6,     -- now.gg, unverified
    sideDashCooldown      = 2,     -- another wiki says ~1
    frontDashCooldown     = 5,     -- shared with back dash
    ragdollCancelCooldown = 30,    -- sources say 20-30
    deathCounterWindow    = 10,
}

---------------------------------------------------------------- techs (non-linear descriptions)
Data.Techs = {
    {name = "Ragdoll Cancel", character = "Universal", confidence = "high",
     desc = "Side/back dash while ragdolled frees you. ~30s cooldown. Dodged by dashing as the 4th M1 lands; punish by dashing behind the opponent."},
    {name = "Wall Combo", character = "Universal", confidence = "high",
     desc = "4th M1 near a wall then forward dash: ~12%, cinematic, ragdoll. Not possible on duel-map invisible walls (except Tatsumaki)."},
    {name = "Wall Extend", character = "Universal", confidence = "medium",
     desc = "Cancel a move inside the wall-combo window; also extends backdash-cancel range."},
    {name = "Wall Tech (roll extend)", character = "Universal", confidence = "medium",
     desc = "3 M1 then forward dash the enemy into the wall so they roll, M1 them as they roll back."},
    {name = "True Downslam", character = "Universal", confidence = "medium",
     desc = "2 M1, jump, 3rd M1 in air, downslam: stun outlasts the slam so they cannot dash-cancel (no dash during M1 stun)."},
    {name = "Upside Down Ragdoll", character = "Universal", confidence = "medium",
     desc = "Downslam IMMEDIATELY when the opponent gets up."},
    {name = "M1 Shove", character = "Universal", confidence = "medium",
     desc = "M1 right after Shove only works after 0/1/2 M1s, else you get the ragdoll shove. Then back away and forward dash. Old patch: Flash Strike after shove was inescapable."},
    {name = "Delayed M1s", character = "Universal", confidence = "low", desc = "Delay M1 timing to bait/stop ragdoll cancels."},
    {name = "Backdash Cancel", character = "Universal", confidence = "medium",
     desc = "Cancel a backdash animation by using an ability immediately."},
    {name = "Side Dash Cancel", character = "Universal", confidence = "medium",
     desc = "Side dash then immediately use a move to shorten travel distance / change the angle."},
    {name = "Jump Cancel", character = "Universal", confidence = "low",
     desc = "Jump before a move to change trajectory / recover sooner from long ground recovery."},
    {name = "3M1 Reset", character = "Universal", confidence = "medium",
     desc = "After 3 M1s side dash then front dash immediately to continue the M1s."},
    {name = "Uppercut Dash", character = "Universal", confidence = "medium",
     desc = "Forward dash after a mini uppercut, loop under the target and front dash; reduced knockback so you can side-dash in."},
    {name = "Delayed M1 anti-cancel", character = "Universal", confidence = "low",
     desc = "3 M1, mini uppercut, side dash during it, forward dash toward opponent: reportedly prevents ragdoll cancel."},
    {name = "Saitama head-uppercut", character = "The Strongest Hero", confidence = "low",
     desc = "Jump onto the opponent's head then Uppercut to hit faster after the move."},
    {name = "Fourfold Rebound", character = "Deadly Ninja", confidence = "low",
     desc = "Get the opponent into a rolling state, jump, Flash Strike, side dash to catch."},
    {name = "Foul Ball > Homerun", character = "Brutal Demon", confidence = "low",
     desc = "Side dash right after Foul Ball then Homerun facing the player for a true Homerun."},
    {name = "Death Counter / counters", character = "Various", confidence = "high",
     desc = "5 counters: Death Counter, Prey's Peril, Death Blow, Split Second Counter, Spiraling Storm (KJ)."},
    {name = "Oreo Tech", character = "Universal", confidence = "low",
     desc = "Community TikTok description (unverified, timing windows not published): 3 M1, hold jump and release M1, press attack again while airborne and front dash, hold M1 again with another front dash, then flick the camera right and turn back to the opponent. There are separate low-ping and high-ping versions ('Oreo Dash') and a Garou variant. Not on the wiki's universal list."},
    {name = "Twisted Dash", character = "Universal", confidence = "medium",
     desc = "Dash at the opponent right after landing the 4th M1: they take less knockback so you can extend. Land the forward dash ASAP; usually you step back a little first. Hitting the legs shortens the knockback further (full hit = opponent spins in place)."},
    {name = "Instant / True Twisted", character = "Hero Hunter", confidence = "low",
     desc = "Faster Twisted: turn the camera left or right and then back into the twisted dash. Quicker and harder to predict a ragdoll cancel. The camera flick cannot be automated here, so the macro only does 4 M1 -> back dash -> front dash."},
    {name = "Garou full twisted combo", character = "Hero Hunter", confidence = "low",
     desc = "Nov 2025 fan guide: 4 M1, curved dash into Flowing Water, Hunter's Grasp catch, Grasp punch, Lethal Whirlwind Stream, downslam. ~90% (98.6% best); optional evade bait to waste their ragdoll cancel, ~84% without. Needs similar internet connections on both sides."},
    {name = "Micro Dash", character = "Universal", confidence = "medium",
     desc = "Use a move right after a side dash to cancel it and shorten its travel (a cancelled side dash goes ~2 blocks, a front dash ~5). Plain M1 does not cancel it."},
    {name = "Backdash Cancel extension", character = "Universal", confidence = "medium",
     desc = "Jump before backdashing: the momentum lasts longer in the air so the backdash goes further. Using a move during the backdash cancels it."},
    {name = "M1 Reset (Saitama bug)", character = "The Strongest Hero", confidence = "low",
     desc = "Do 1-3 M1, use Consecutive Punches while holding M1 through the animation: the M1 chain resets and you get 4 M1 again. Listed as a bug, may be patched."},
    {name = "M1 Reset (shove variant)", character = "Universal", confidence = "low",
     desc = "TikTok demonstrations of a reset built from delayed shoves and side dashes. No written inputs."},
    {name = "Mini uppercut + downslam", character = "Universal", confidence = "low",
     desc = "Mini uppercut then downslam (also taught for mobile). Used to waste or beat the opponent's ragdoll cancel."},
    {name = "Downslam > Weboom extend", character = "Tech Prodigy", confidence = "low",
     desc = "Downslam into Weboom to waste the opponent's ragdoll cancel or stall for cooldowns."},
    {name = "Ignition Burst Extension", character = "Destructive Cyborg", confidence = "low",
     desc = "Full M1 string, cast Ignition Burst to hit them while ragdolled, immediately dash toward where they landed and start another M1 string."},
    {name = "Genos Barrage", character = "Destructive Cyborg", confidence = "low",
     desc = "Cast Machine Gun Blows and turn around right before the punch + kick launcher. (Camera turn is not automated.)"},
    {name = "Genos 'Explosive Fart'", character = "Destructive Cyborg", confidence = "low",
     desc = "Turn around while casting Ignition Burst to burn the target, then very quickly turn back. An uppercut can be done first. (Camera turn not automated.)"},
    {name = "Uppercut > Blitz Shot", character = "Destructive Cyborg", confidence = "low",
     desc = "Fire Blitz Shot as an uppercutted opponent falls. A commenter said it is not new."},
    {name = "Flash Strike extension", character = "Deadly Ninja", confidence = "low",
     desc = "Forum proposal (unverified): 3 M1, side dash away into Flash Strike, come back and M1 while they are still stunned. Older patches allowed Flash Strike after M1 shove as an inescapable extend."},
    {name = "Foul Ball catch", character = "Brutal Demon", confidence = "low",
     desc = "After an M1, step forward and aim Foul Ball: it knocks them far enough to side dash in and catch them. Forum post (2024) says it can act weird."},
    {name = "Death Blow evasion", character = "Brutal Demon", confidence = "low",
     desc = "GINX guide: getting hit at the start of the Death Blow animation lets Metal Bat evade, then finish the opponent."},
    {name = "Grand Slam dodge", character = "Brutal Demon", confidence = "medium",
     desc = "A well-timed Grand Slam avoids the damage of Hero Hunter's and Blade Master's awakening startup (they need a grounded target)."},
    {name = "Quick Slice Spin", character = "Blade Master", confidence = "low",
     desc = "Land 3 M1, turn around, cast Quick Slice: you dash behind the target. (Camera turn not automated.)"},
    {name = "Pinpoint Cut extension", character = "Blade Master", confidence = "low",
     desc = "After Pinpoint Cut lands, dash toward where the opponent was knocked and catch them with M1s."},
    {name = "Stone Grave cancel", character = "Wild Psychic", confidence = "low",
     desc = "Dash into the stone grave rock just as the enemy emerges: cancels their roll animation and allows extra M1s."},
    {name = "Windstorm loop-dash", character = "Wild Psychic", confidence = "low",
     desc = "Loop-dash right after Windstorm Fury ends, uppercut shortly after: about 54% total per one guide. Windstorm Fury is not a true combo."},
    {name = "Windstorm Extend", character = "Wild Psychic", confidence = "low",
     desc = "Dash around to the opponent's back after Windstorm and M1 (lower damage). Listed on the wiki techs page."},
    {name = "Vanishing Kick double tap", character = "Martial Artist", confidence = "low",
     desc = "Double tapping Vanishing Kick can get past blocks (tier-list note)."},
    {name = "Collateral Ruin (ult cancel)", character = "KJ", confidence = "low",
     desc = "KJ's Collateral Ruin can cancel many ultimate, base and counter moves (Five Seasons, 20-20-20 Dropkick, Stoic Bomb)."},
    {name = "Cancel your own ultimate", character = "Universal", confidence = "none",
     desc = "A low-quality site claims you can cancel straight into an M1 string after the first ultimate strike. Unverified, not modelled."},
}

---------------------------------------------------------------- combos (token sequences)
Data.Combos = {
    -- Garou
    Kyoto            = {character = "Hero Hunter", confidence = "medium", steps = seq(M1x3, "SIDEDASH", "FLOWING_WATER", "LETHAL_WHIRLWIND_STREAM", "HUNTERS_GRASP", "M1", "SIDEDASH", "UPPERCUT", "Q")},
    Kyoto_Easy       = {character = "Hero Hunter", confidence = "medium", steps = seq("Q", M1x3, "FLOWING_WATER", "SIDEDASH", "HUNTERS_GRASP", "Q", M1x3, "LETHAL_WHIRLWIND_STREAM")},
    Kyoto_Core       = {character = "Hero Hunter", confidence = "medium", steps = seq(M1x3, "FLOWING_WATER", "SIDEDASH", "LETHAL_WHIRLWIND_STREAM")},
    Garou_Catch      = {character = "Hero Hunter", confidence = "low",    steps = {"DOWNSLAM", "HUNTERS_GRASP", "SIDEDASH", "M1"}},
    -- Saitama
    Saitama_Beginner = {character = "The Strongest Hero", confidence = "medium", steps = seq("Q", M1x3, "JUMP_M1", "UPPERCUT", "SIDEDASH", M1x3, "CONSECUTIVE_PUNCHES", "NORMAL_PUNCH")},
    Saitama_Basic    = {character = "The Strongest Hero", confidence = "medium", steps = seq(M1x3, "SHOVE", "FRONTDASH", M1x3, "DOWNSLAM", "CONSECUTIVE_PUNCHES", "UPPERCUT", "SIDEDASH", M1x3, "NORMAL_PUNCH")},
    Saitama_Quick    = {character = "The Strongest Hero", confidence = "medium", steps = seq(M1x3, "DOWNSLAM", "TABLE_FLIP")},
    Saitama_Advanced = {character = "The Strongest Hero", confidence = "medium", steps = seq(M1x3, "DOWNSLAM", "UPPERCUT", "SIDEDASH", M1x3, "CONSECUTIVE_PUNCHES", "SHOVE", "FRONTDASH", M1x3, "NORMAL_PUNCH")},
    Saitama_UppercutCatch = {character = "The Strongest Hero", confidence = "low", steps = {"UPPERCUT", "FRONTDASH", "M1"}},
    -- Genos
    Genos_Easy       = {character = "Destructive Cyborg", confidence = "medium", steps = seq("Q", M1x3, "MACHINE_GUN_BLOWS", "IGNITION_BURST", "JET_DIVE", "JUMP", "BLITZ_SHOT")},
    Genos_Ult        = {character = "Destructive Cyborg", confidence = "low", steps = seq(M1x3, "DOWNSLAM", "THUNDER_KICK", "SPEEDBLITZ_DROPKICK", "FLAMEWAVE_CANNON")},
    -- Sonic
    Sonic_Easy       = {character = "Deadly Ninja", confidence = "medium", steps = seq("Q", M1x3, "SCATTER", M1x3, "WHIRLWIND_KICK", "FLASH_STRIKE")},
    Sonic_Extended   = {character = "Deadly Ninja", confidence = "medium", steps = seq(M1x4, "JUMP", "EXPLOSIVE_SHURIKEN", M1x3, "SCATTER", M1x3, "DOWNSLAM", "WHIRLWIND_KICK", "FLASH_STRIKE")},
    Sonic_MachWall   = {character = "Deadly Ninja", confidence = "low", steps = seq(M1x4, "FLASH_STRIKE", "WALL_COMBO")},
    -- Metal Bat
    MetalBat_Starter = {character = "Brutal Demon", confidence = "low", steps = seq("FRONTDASH", M1x3, "BEATDOWN", "HOMERUN", "GRAND_SLAM", "FOUL_BALL")},
    MetalBat_Long    = {character = "Brutal Demon", confidence = "low", steps = seq(M1x3, "MINI_UPPERCUT", "GRAND_SLAM_AIR", M1x3, "MINI_UPPERCUT", "BEATDOWN", M1x3, "DOWNSLAM", "HOMERUN", "FOUL_BALL")},
    -- Atomic Samurai
    Samurai_Guide    = {character = "Blade Master", confidence = "medium", steps = seq(M1x3, "DOWNSLAM", "DEADLY_CASCADE", M1x3, "DOWNSLAM", "ATMOS_CLEAVE", M1x3, "DOWNSLAM")},
    Samurai_Wiki     = {character = "Blade Master", confidence = "medium", steps = seq("Q", "M1", "PINPOINT_CUT", "Q", "ATMOS_CLEAVE", "DOWNSLAM", "QUICK_SLICE")},
    Samurai_NowGG    = {character = "Blade Master", confidence = "low", steps = seq("Q", M1x3, "DOWNSLAM", "ATMOS_CLEAVE", "QUICK_SLICE", "Q", M1x4)},
    -- Tatsumaki
    Tatsu_1          = {character = "Wild Psychic", confidence = "medium", steps = seq(M1x4, "WINDSTORM_FURY", "CRUSHING_PULL", "DOWNSLAM")},
    Tatsu_2          = {character = "Wild Psychic", confidence = "medium", steps = seq(M1x3, "SIDEDASH", "Q", M1x4, "EXPULSIVE_PUSH", M1x3, "SIDEDASH", "Q", M1x3, "DOWNSLAM", "WINDSTORM_FURY", M1x4, "CRUSHING_PULL")},
    Tatsu_Safe       = {character = "Wild Psychic", confidence = "low", steps = {"STONE_COFFIN", "CRUSHING_PULL"}},
    -- Tech Prodigy
    TechProdigy_Det  = {character = "Tech Prodigy", confidence = "low", steps = seq(M1x4, "WEBOOM", "WALL_COMBO", "SIDEDASH", "M1")},
    -- Garou (more)
    Garou_Medium     = {character = "Hero Hunter", confidence = "medium", steps = seq("Q", M1x3, "LETHAL_WHIRLWIND_STREAM", M1x3, "JUMP_M1", "HUNTERS_GRASP", "Q", M1x3, "FLOWING_WATER", M1x3, "JUMP_M1")},
    Garou_InstantTwisted = {character = "Hero Hunter", confidence = "low", steps = seq(M1x4, "BACKDASH", "FRONTDASH")},
    Garou_TwistedFull = {character = "Hero Hunter", confidence = "low", steps = seq(M1x4, "SIDEDASH", "FLOWING_WATER", "HUNTERS_GRASP", "M1", "LETHAL_WHIRLWIND_STREAM", "DOWNSLAM")},
    -- Saitama (more)
    Saitama_Medium   = {character = "The Strongest Hero", confidence = "low", steps = seq(M1x3, "CONSECUTIVE_PUNCHES", "JUMP_M1", "SHOVE", "Q", M1x4, "NORMAL_PUNCH")},
    Saitama_M1ResetBug = {character = "The Strongest Hero", confidence = "low", steps = seq("M1", "M1", "CONSECUTIVE_PUNCHES", M1x4)},
    -- Genos (more)
    Genos_IgnitionExtend = {character = "Destructive Cyborg", confidence = "low", steps = seq(M1x4, "IGNITION_BURST", "FRONTDASH", M1x4)},
    Genos_UppercutBlitz = {character = "Destructive Cyborg", confidence = "low", steps = seq(M1x3, "UPPERCUT", "BLITZ_SHOT")},
    -- Sonic (more)
    Sonic_FlashExtend = {character = "Deadly Ninja", confidence = "low", steps = seq(M1x3, "SIDEDASH", "FLASH_STRIKE", "M1")},
    Sonic_Guide      = {character = "Deadly Ninja", confidence = "low", steps = seq(M1x3, "FLASH_STRIKE", "SCATTER", "UPPERCUT", "EXPLOSIVE_SHURIKEN", "WHIRLWIND_KICK")},
    -- Metal Bat (more)
    MetalBat_FoulBallCatch = {character = "Brutal Demon", confidence = "low", steps = {"M1", "FOUL_BALL", "SIDEDASH", "M1"}},
    -- Atomic Samurai (more)
    Samurai_QuickSliceSpin = {character = "Blade Master", confidence = "low", steps = seq(M1x3, "QUICK_SLICE")},
    Samurai_PinpointExtend = {character = "Blade Master", confidence = "low", steps = seq("PINPOINT_CUT", "FRONTDASH", M1x3)},
    -- Tatsumaki (more)
    Tatsu_WindstormLoop = {character = "Wild Psychic", confidence = "low", steps = {"WINDSTORM_FURY", "FRONTDASH", "UPPERCUT"}},
    Tatsu_StoneGraveCancel = {character = "Wild Psychic", confidence = "low", steps = {"STONE_COFFIN", "FRONTDASH", "M1", "M1"}},
    -- Universal
    TwistedDash      = {character = "Universal", confidence = "medium", steps = seq(M1x4, "FRONTDASH")},
    Oreo             = {character = "Universal", confidence = "low", steps = seq(M1x3, "JUMP", "JUMP_M1", "FRONTDASH", "M1", "FRONTDASH")},
    TrueDownslam     = {character = "Universal", confidence = "medium", steps = {"M1", "M1", "JUMP", "JUMP_M1", "DOWNSLAM"}},
    UppercutDash     = {character = "Universal", confidence = "medium", steps = {"MINI_UPPERCUT", "FRONTDASH", "SIDEDASH", "FRONTDASH"}},
    M1Reset          = {character = "Universal", confidence = "medium", steps = seq(M1x3, "SIDEDASH", "FRONTDASH", "M1")},
    WallTech         = {character = "Universal", confidence = "medium", steps = seq(M1x3, "FRONTDASH", "M1")},
    AntiCancel       = {character = "Universal", confidence = "low", steps = seq(M1x3, "MINI_UPPERCUT", "SIDEDASH", "FRONTDASH")},
}

return Data
