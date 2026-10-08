--[[
    Animation Hub - The Strongest Battlegrounds
    Smooth sidebar UI + Auto Tech

    Setup:
      * Background: a random SFW anime image is fetched from waifu.pics / nekos.best.
        NOTE: those are community fan-art images, NOT copyright-free. For art you may
        legally redistribute, set BACKGROUND_URL to your own / CC0 image.
      * Needs request + writefile + getcustomasset for the image; everything else works without them.

    Auto Tech: when you get knocked down / ragdolled it waits a short delay and
    presses the dash key in the chosen direction so you recover instantly.
    Delay / cooldown / direction are adjustable in the "Auto Tech" tab.
]]

local BACKGROUND_URL = ""   -- optional fixed image (direct link). "" = pick one from the waifu API below
local BACKGROUND_SOURCE = "waifu.pics"   -- "waifu.pics" or "nekos.best" (SFW endpoints only)
local BACKGROUND_TRANSPARENCY = 0.55
local GUI_PARENT = "auto"   -- "auto" (gethui, CoreGui, PlayerGui) | "coregui" | "playergui". If the menu never shows, try "playergui".
-- ...or set it before running without editing anything:  getgenv().AH_GUI_PARENT = "playergui"
pcall(function() if getgenv and getgenv().AH_GUI_PARENT then GUI_PARENT = getgenv().AH_GUI_PARENT end end)

-- Your own combos, shown as cards in the character tab. "Instant Twisted" has no published inputs, so
-- add it here once you know them. Tokens: M1 Q FRONTDASH SIDEDASH BACKDASH JUMP or a move name such as
-- FLOWING_WATER / HUNTERS_GRASP (see tsb_data.lua). Example:
--   {name = "Instant Twisted", character = "Hero Hunter", steps = {"M1", "M1", "SIDEDASH", "HUNTERS_GRASP"}},
local CUSTOM_COMBOS = {
}

-- Feedback so you always know how far it got: "Loading" = the script started, "Ready" = the menu was built,
-- a red "error" notification = it failed (and says why). Seeing nothing at all means the executor never ran it
-- (pasted text cut off, or too long) - use the short loadstring link instead of pasting.
local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 4})
    end)
end
print("[Animation Hub] starting")
notify("Animation Hub", "Loading...", 3)

local DragTracker = (function()


local M = {}

function M.new(threshold)
    local self = {threshold = threshold or 8, locked = false, active = false, moved = false, lastDragEnd = nil}
    local sx, sy, ox, oy = 0, 0, 0, 0

    function self:setLocked(v)
        self.locked = v and true or false
        if self.locked then self.moved = false end
    end

    function self:begin(px, py, originX, originY)
        self.active, self.moved = true, false
        sx, sy, ox, oy = px, py, originX, originY
    end

    function self:move(px, py)
        if not self.active or self.locked then return nil end
        local dx, dy = px - sx, py - sy
        if not self.moved then
            if dx * dx + dy * dy < self.threshold * self.threshold then return nil end
            self.moved = true
        end
        return ox + dx, oy + dy
    end

    function self:finish(now)
        if self.active and self.moved then self.lastDragEnd = now end
        self.active, self.moved = false, false
    end

    -- The Click event of a released drag can arrive before OR after the pointer-up event, so both
    -- orders are handled: still dragging now, or a drag ended a moment ago.
    function self:suppressClick(now)
        if self.active and self.moved then return true end
        return self.lastDragEnd ~= nil and (now - self.lastDragEnd) < 0.25
    end

    return self
end

function M.clamp(x, y, w, h, vw, vh, margin)
    margin = margin or 0
    local maxX = math.max(margin, vw - w - margin)
    local maxY = math.max(margin, vh - h - margin)
    return math.min(math.max(x, margin), maxX), math.min(math.max(y, margin), maxY)
end

return M

end)()
local PingModel = (function()


local M = {}

function M.new(alpha)
    local self = {alpha = alpha or 0.2, ping = nil, jit = 0, n = 0}

    function self:sample(ms)
        if type(ms) ~= "number" or ms ~= ms or ms < 0 or ms > 5000 then return end   -- NaN / garbage
        if not self.ping then
            self.ping = ms
        else
            self.jit = self.jit + self.alpha * (math.abs(ms - self.ping) - self.jit)
            self.ping = self.ping + self.alpha * (ms - self.ping)
        end
        self.n = self.n + 1
    end

    function self:value() return self.ping end
    function self:jitter() return self.jit end

    -- enough samples and the connection is not swinging wildly
    function self:stable()
        return self.n >= 5 and self.jit <= math.max(10, 0.35 * (self.ping or 0))
    end

    return self
end

-- Seconds. base = planned gap after a step.
--   opts.dependent  true/false: does this gap wait for a visible cue (after a move or dash)? When nil it is
--                   guessed from the size of the gap (>= minDependent, default 0.3 s).
--   opts.offsetMs   manual fine-tune added to dependent gaps (+ later / - earlier).
--   opts.maxFraction / opts.minDelay  bounds: never shorten by more than 40% of the gap, never below 0.05 s.
-- Independent gaps (M1 spacing, jump) are returned unchanged.
function M.adjustDelay(base, pingMs, strength, opts)
    opts = opts or {}
    if type(base) ~= "number" then return base end
    local dependent = opts.dependent
    if dependent == nil then dependent = base >= (opts.minDependent or 0.3) end
    if not dependent then return base end

    local d = base
    if type(pingMs) == "number" and pingMs > 0 and type(strength) == "number" and strength > 0 then
        d = base - math.min((pingMs / 1000) * strength, base * (opts.maxFraction or 0.4))
    end
    if type(opts.offsetMs) == "number" then d = d + opts.offsetMs / 1000 end
    if d == base then return base end
    return math.max(d, opts.minDelay or 0.05)
end

return M

end)()
local ComboOptions = (function()


local M = {}

M.DEFAULTS = {auto = "global", speed = 1, m1 = 0, dash = 0, move = 0, jump = 0, offsetMs = 0, side = "Left"}

local RANGES = {
    speed = {0.5, 2}, m1 = {0, 0.6}, dash = {0, 0.8}, move = {0, 1.2}, jump = {0, 0.6}, offsetMs = {-100, 100},
}
M.RANGES = RANGES

local AUTO = {global = true, on = true, off = true}
local SIDE = {Left = true, Right = true}

local function clamp(v, lo, hi, default)
    if type(v) ~= "number" or v ~= v then return default end      -- not a number / NaN
    return math.min(math.max(v, lo), hi)
end

-- Always returns a complete, valid options table, whatever garbage (e.g. a hand-edited save file) goes in.
function M.sanitize(src)
    src = type(src) == "table" and src or {}
    local o = {}
    for key, range in pairs(RANGES) do
        o[key] = clamp(src[key], range[1], range[2], M.DEFAULTS[key])
    end
    o.auto = AUTO[src.auto] and src.auto or M.DEFAULTS.auto
    o.side = SIDE[src.side] and src.side or M.DEFAULTS.side
    return o
end

function M.new() return M.sanitize(nil) end

function M.isDefault(o)
    for key, def in pairs(M.DEFAULTS) do
        if o[key] ~= def then return false end
    end
    return true
end

-- is auto (ping) timing active for this combo?
function M.autoOn(globalOn, o)
    if o.auto == "on" then return true end
    if o.auto == "off" then return false end
    return globalOn and true or false
end

-- gap in seconds for a step kind ("m1"|"dash"|"move"|"jump") before the ping adjustment:
-- the combo's own override if set, else the global gap; then global speed x combo speed
function M.gap(kind, timing, o, globalSpeed)
    local own = o[kind]
    local base = (type(own) == "number" and own > 0) and own or timing[kind]
    return base * (globalSpeed or 1) * o.speed
end

return M

end)()
local Data = (function()


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

end)()
local Engine = (function()


local Engine = {}

Engine.Combos = {}
Engine.Mechanics = {}
Engine.Techs = {}
Engine.Characters = {}

local function validSteps(steps)
    if type(steps) ~= "table" or #steps == 0 then return false end
    for i = 1, #steps do
        if type(steps[i]) ~= "string" or steps[i] == "" then return false end
    end
    return true
end

-- Load tsb_data.lua (or your own table with the same shape).
-- Malformed combos are skipped; the names of skipped ones are returned as a list.
function Engine.loadData(data, defaultGap)
    local skipped = {}
    for name, c in pairs(data.Combos or {}) do
        if type(name) == "string" and type(c) == "table" and validSteps(c.steps) then
            Engine.Combos[name] = {
                steps = c.steps, maxGap = c.maxGap or defaultGap or 1.2,
                character = c.character, confidence = c.confidence,
            }
        else
            skipped[#skipped + 1] = tostring(name)
        end
    end
    for k, v in pairs(data.Mechanics or {}) do Engine.Mechanics[k] = v end
    Engine.Techs, Engine.Characters = data.Techs or {}, data.Characters or {}
    table.sort(skipped)
    return Engine, skipped
end

-- Register / replace a combo (this is where "Oreo" and your own combos go).
function Engine.define(name, steps, maxGap)
    assert(type(name) == "string" and name ~= "", "define: name must be a non-empty string")
    assert(validSteps(steps), "define: steps must be a non-empty list of non-empty strings")
    assert(maxGap == nil or (type(maxGap) == "number" and maxGap > 0), "define: maxGap must be a positive number")
    Engine.Combos[name] = {steps = steps, maxGap = maxGap or 1.2}
end

----------------------------------------------------------------- predictor
-- For every combo we keep ALL alignments that are still alive (not just one counter), so a combo
-- is found even when it starts in the middle of a longer run of the same input
-- (e.g. M1 M1 M1 SIDEDASH still matches a combo that is "M1 M1 SIDEDASH").
local Predictor = {}
Predictor.__index = Predictor

function Engine.newPredictor(combos)
    return setmetatable({
        combos = combos or Engine.Combos,
        state = {},          -- name -> {t = time of last matched input, at = {[stepIndex] = true}}
        onComplete = nil,
    }, Predictor)
end

function Predictor:reset()
    self.state = {}
end

function Predictor:feed(token, now)
    if type(token) ~= "string" or type(now) ~= "number" then return end
    for name, combo in pairs(self.combos) do
        local steps = combo.steps
        local st = self.state[name]
        local live = (st and now - st.t <= combo.maxGap) and st.at or nil   -- window expired -> nothing alive

        local nextAt, any, completed = {}, false, false
        if live then
            for idx in pairs(live) do
                if steps[idx + 1] == token then
                    if idx + 1 == #steps then completed = true else nextAt[idx + 1] = true; any = true end
                end
            end
        end
        if steps[1] == token then                      -- a fresh start is always possible
            if #steps == 1 then completed = true else nextAt[1] = true; any = true end
        end

        self.state[name] = any and {t = now, at = nextAt} or nil
        if completed and self.onComplete then self.onComplete(name) end
    end
end

-- Likely combos right now, best first. One entry per combo (its furthest alignment).
function Predictor:predict(now)
    local out = {}
    for name, st in pairs(self.state) do
        local combo = self.combos[name]
        if combo and now - st.t <= combo.maxGap then
            local best = 0
            for idx in pairs(st.at) do if idx > best then best = idx end end
            if best > 0 then
                out[#out + 1] = {
                    name       = name,
                    progress   = best,
                    total      = #combo.steps,
                    confidence = best / #combo.steps,
                    next       = combo.steps[best + 1],
                    expiresIn  = combo.maxGap - (now - st.t),
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.confidence ~= b.confidence then return a.confidence > b.confidence end
        return a.name < b.name
    end)
    return out
end

-- Aggregate "what input comes next?" over every live candidate: {token -> weight}, plus best token.
function Predictor:nextInputs(now)
    local weights, best, bestW = {}, nil, 0
    for _, r in ipairs(self:predict(now)) do
        if r.next then
            local w = (weights[r.next] or 0) + r.confidence
            weights[r.next] = w
            if w > bestW or (w == bestW and best and r.next < best) then best, bestW = r.next, w end
        end
    end
    return weights, best
end

----------------------------------------------------------------- tech recovery
-- state = {knockback = {x, z}, facing = {x, z}, wallAhead = bool}
-- returns "Back" | "Forward" | "Left" | "Right"
function Engine.chooseTechDirection(state)
    local kb, f = state and state.knockback, state and state.facing
    if type(kb) ~= "table" or type(f) ~= "table" then return "Back" end
    local kx, kz, fx, fz = kb.x or 0, kb.z or 0, f.x or 0, f.z or 0
    local kmag = math.sqrt(kx * kx + kz * kz)
    local fmag = math.sqrt(fx * fx + fz * fz)
    if kmag < 1e-6 then return "Back" end
    if state.wallAhead then return "Left" end   -- slide off the wall instead of into it
    if fmag < 1e-6 then return "Back" end

    local dot   = (kx * fx + kz * fz) / (kmag * fmag)       -- both vectors normalised
    local cross = (fx * kz - fz * kx) / (kmag * fmag)
    if math.abs(dot) >= math.abs(cross) then
        -- thrown backwards relative to facing -> dash forward to close, else back away
        return dot < 0 and "Forward" or "Back"
    end
    return cross > 0 and "Left" or "Right"   -- dash against the knockback, like Forward/Back
end

return Engine

end)()

if not game:IsLoaded() then game.Loaded:Wait() end

local function __run()
    ---------------------------------------------------------------- services
    local Players           = game:GetService("Players")
    local RunService        = game:GetService("RunService")
    local TweenService      = game:GetService("TweenService")
    local UserInputService  = game:GetService("UserInputService")
    local VirtualInput      = game:GetService("VirtualInputManager")
    local CoreGui           = game:GetService("CoreGui")

    local LocalPlayer = Players.LocalPlayer
    local Camera      = workspace.CurrentCamera

    ---------------------------------------------------------------- helpers
    local function safe(fn, ...)
        local ok, res = pcall(fn, ...)
        if ok then return res end
    end

    local function guiParent()
        if GUI_PARENT == "playergui" then return LocalPlayer:WaitForChild("PlayerGui") end
        if GUI_PARENT == "coregui" then return CoreGui end
        local p = safe(function() return gethui() end)
        if p then return p end
        p = safe(function() return CoreGui end)
        if p and safe(function() return #p:GetChildren() end) then return p end
        return LocalPlayer:WaitForChild("PlayerGui")   -- always allowed, works on any executor
    end

    local function tween(obj, props, t, style, dir)
        local tw = TweenService:Create(obj, TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
        tw:Play()
        return tw
    end

    local function new(class, props, children)
        local inst = Instance.new(class)
        for k, v in pairs(props or {}) do inst[k] = v end
        for _, c in ipairs(children or {}) do c.Parent = inst end
        return inst
    end

    local function corner(r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}) end
    local function stroke(color, thick, trans)
        return new("UIStroke", {Color = color, Thickness = thick or 1, Transparency = trans or 0})
    end

    local httpRequest = request or http_request or (syn and syn.request)
    local function httpGet(url)
        if httpRequest then
            local res = safe(httpRequest, {Url = url, Method = "GET"})
            if res and (res.StatusCode == 200 or (res.StatusCode == nil and res.Success)) and type(res.Body) == "string" then
                return res.Body
            end
        end
        local body = safe(function() return game:HttpGet(url) end)
        if type(body) == "string" then return body end
    end

    local BgSources = {
        ["waifu.pics"] = {api = "https://api.waifu.pics/sfw/waifu", parse = function(j) return j.url end},
        ["nekos.best"] = {api = "https://nekos.best/api/v2/waifu", parse = function(j) return j.results and j.results[1] and j.results[1].url end},
    }
    local bgCounter = 0

    -- identify the real file type from its first bytes (Roblox can only show png/jpg; this also
    -- rejects gif/webp and HTML error pages that would otherwise be saved as "images")
    local function imageKind(body)
        if type(body) ~= "string" or #body < 16 or #body > 12 * 1024 * 1024 then return nil end
        if body:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
        if body:sub(1, 3) == "\255\216\255" then return "jpg" end
    end

    -- download one image url -> executor asset id
    local function imageToAsset(url)
        if type(url) ~= "string" or url:sub(1, 4) ~= "http" then return nil end
        local body = httpGet(url)
        local kind = imageKind(body)
        if not kind then return nil end
        bgCounter = bgCounter + 1
        local path = ("animation_hub_bg_%d.%s"):format(bgCounter, kind)
        -- writefile returns nothing on success, so test with pcall (NOT safe(), which returns the value)
        if not pcall(writefile, path, body) then return nil end
        return safe(getcustomasset, path)
    end

    local function loadBackground(sourceName)
        if not (getcustomasset and writefile) then return nil end   -- executor cannot show downloaded files
        if BACKGROUND_URL ~= "" and not sourceName then
            local fixed = imageToAsset(BACKGROUND_URL)
            if fixed then return fixed end                            -- else fall through to the API
        end
        local src = BgSources[sourceName or BACKGROUND_SOURCE] or BgSources["waifu.pics"]
        for _ = 1, 4 do                                               -- retry: the API may hand back a gif/webp
            local raw = httpGet(src.api)
            local data = raw and safe(function() return game:GetService("HttpService"):JSONDecode(raw) end)
            local url = type(data) == "table" and safe(src.parse, data)
            local asset = imageToAsset(url)
            if asset then return asset end
        end
    end

    ---------------------------------------------------------------- theme
    local Theme = {
        Back     = Color3.fromRGB(24, 18, 26),
        Panel    = Color3.fromRGB(38, 28, 42),
        Item     = Color3.fromRGB(52, 38, 58),
        Accent   = Color3.fromRGB(255, 120, 180),
        Text     = Color3.fromRGB(245, 235, 245),
        SubText  = Color3.fromRGB(190, 170, 190),
    }

    ---------------------------------------------------------------- cleanup old
    -- re-running the script must not leave the old copy's listeners (Auto Tech, predictor...) alive
    local genv = safe(function() return getgenv() end) or _G
    if type(genv.__AnimationHubCleanup) == "function" then pcall(genv.__AnimationHubCleanup) end
    local old = guiParent():FindFirstChild("AnimationHubTSB")
    if old then old:Destroy() end

    ---------------------------------------------------------------- window
    local Gui = new("ScreenGui", {
        Name = "AnimationHubTSB", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
    })
    Gui.DisplayOrder = 999999          -- above the game's own UI
    Gui.Parent = guiParent()
    if not Gui.Parent then Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end   -- the chosen container refused it

    -- every global listener goes through connect() so cleanup() can remove it
    local alive, conns, onCleanup = true, {}, {}
    local function connect(signal, fn)
        local c = signal:Connect(fn)
        conns[#conns + 1] = c
        return c
    end
    local function cleanup()
        if not alive then return end
        alive = false
        for _, f in ipairs(onCleanup) do pcall(f) end
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        pcall(function() Gui:Destroy() end)
        if genv.__AnimationHubCleanup == cleanup then genv.__AnimationHubCleanup = nil end
    end
    genv.__AnimationHubCleanup = cleanup

    -- fit small phone screens: never taller/wider than the viewport
    local function viewport()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize
        if vp and type(vp.X) == "number" and type(vp.Y) == "number" and vp.X > 0 and vp.Y > 0 then return vp.X, vp.Y end
    end
    local WIN_W, WIN_H = 580, 380
    do
        local vw, vh = viewport()
        if vw then
            WIN_W = math.max(360, math.min(WIN_W, vw - 24))
            WIN_H = math.max(240, math.min(WIN_H, vh - 24))
        end
    end

    local Main = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),     -- top edge stays put when minimising / opening
        Size = UDim2.fromOffset(WIN_W, WIN_H), Position = UDim2.new(0.5, 0, 0.5, -WIN_H / 2),
        BackgroundColor3 = Theme.Back, BorderSizePixel = 0, ClipsDescendants = true,
        Parent = Gui,
    }, {corner(14), stroke(Theme.Accent, 1.5, 0.6)})

    -- background image (optional, loaded in the background so the UI never freezes)
    new("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(60, 36, 70), Color3.fromRGB(24, 18, 26)),
        Rotation = 45, Parent = Main,
    })
    local Background = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "",
        ScaleType = Enum.ScaleType.Crop, ImageTransparency = BACKGROUND_TRANSPARENCY,
        ZIndex = 0, Parent = Main,
    }, {corner(14)})
    local bgGen = 0
    local function refreshBackground(sourceName)
        bgGen = bgGen + 1
        local mine = bgGen                       -- only the newest request may set the image
        task.spawn(function()
            local asset = loadBackground(sourceName)
            if asset and mine == bgGen and alive then Background.Image = asset end
        end)
    end
    refreshBackground()

    -- title bar
    local TopBar = new("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = Main})
    new("TextLabel", {
        Text = "Animation Hub", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 8), Size = UDim2.new(1, -140, 0, 20), Parent = TopBar,
    })
    new("TextLabel", {
        Text = "The Strongest Battlegrounds", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 28), Size = UDim2.new(1, -140, 0, 16), Parent = TopBar,
    })

    local function topButton(text, xOff, cb)
        local b = new("TextButton", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.Accent,
            BackgroundTransparency = 1, Size = UDim2.fromOffset(36, 36),
            Position = UDim2.new(1, xOff, 0, 8), AutoButtonColor = false, Parent = TopBar,
        })
        b.MouseEnter:Connect(function() tween(b, {TextColor3 = Theme.Text}, 0.15) end)
        b.MouseLeave:Connect(function() tween(b, {TextColor3 = Theme.Accent}, 0.15) end)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    local minimized = false
    local fullSize = UDim2.fromOffset(WIN_W, WIN_H)
    topButton("-", -88, function()
        minimized = not minimized
        tween(Main, {Size = minimized and UDim2.fromOffset(WIN_W, 52) or fullSize}, 0.3)
    end)
    topButton("X", -46, function()
        tween(Main, {Size = UDim2.fromOffset(WIN_W, 0)}, 0.25)
        task.spawn(function() task.wait(0.27); cleanup() end)
    end)

    -- dragging (keeps the title bar on screen)
    do
        local dragging, dragStart, startPos = false, nil, nil
        local function isPointer(i)
            return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
        end
        TopBar.InputBegan:Connect(function(i)
            if isPointer(i) then
                dragging, dragStart, startPos = true, i.Position, Main.Position
            end
        end)
        connect(UserInputService.InputEnded, function(i)
            if isPointer(i) then dragging = false end
        end)
        connect(UserInputService.InputChanged, function(i)
            if not dragging then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local d = i.Position - dragStart
            local ox, oy = startPos.X.Offset + d.X, startPos.Y.Offset + d.Y
            local vw, vh = viewport()
            if vw then
                local mx = vw / 2 + WIN_W / 2 - 60
                ox = math.clamp(ox, -mx, mx)
                oy = math.clamp(oy, -vh / 2, vh / 2 - 52)       -- title bar always reachable
            end
            Main.Position = UDim2.new(startPos.X.Scale, ox, startPos.Y.Scale, oy)
        end)
    end

    -- show / hide the menu (RightShift on PC, the floating bar on touch devices)
    local renderFab   -- assigned by the floating bar further down
    local function toggleMenu()
        Main.Visible = not Main.Visible
        if renderFab then renderFab() end
    end
    connect(UserInputService.InputBegan, function(i, gp)
        if not gp and i.KeyCode == Enum.KeyCode.RightShift then toggleMenu() end
    end)

    ---------------------------------------------------------------- sidebar / pages
    local Sidebar = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 56), Size = UDim2.new(0, 160, 1, -112),
        BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Main,
    }, {
        new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
        new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}),
    })

    local Content = new("Frame", {
        Position = UDim2.fromOffset(170, 56), Size = UDim2.new(1, -184, 1, -70),
        BackgroundTransparency = 1, Parent = Main,
    })

    -- footer: player card
    local Card = new("Frame", {
        Position = UDim2.new(0, 10, 1, -50), Size = UDim2.fromOffset(140, 40),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.25, Parent = Main,
    }, {corner(10)})
    new("TextLabel", {
        Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text,
        BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(46, 4), Size = UDim2.new(1, -52, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Card,
    })
    new("TextLabel", {
        Text = "@" .. LocalPlayer.Name, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Theme.SubText,
        BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(46, 20), Size = UDim2.new(1, -52, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Card,
    })
    local avatar = new("ImageLabel", {
        Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(8, 5),
        BackgroundColor3 = Theme.Item, Parent = Card,
    }, {corner(15)})
    task.spawn(function()
        local img = safe(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if img then avatar.Image = img end
    end)

    local Tabs, currentTab = {}, nil

    local function createTab(name, icon)
        local btn = new("TextButton", {
            Text = "   " .. icon .. "  " .. name, Font = Enum.Font.GothamMedium, TextSize = 14,
            TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = Theme.Panel, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 36), AutoButtonColor = false, Parent = Sidebar,
        }, {corner(8)})
        local bar = new("Frame", {
            Size = UDim2.fromOffset(3, 0), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = btn,
        }, {corner(2)})

        local page = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
            Parent = Content,
        }, {
            new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
            new("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2)}),
        })

        local tab = {Btn = btn, Bar = bar, Page = page}
        function tab:Select()
            if currentTab then
                local c = currentTab
                c.Page.Visible = false
                tween(c.Btn, {BackgroundTransparency = 1, TextColor3 = Theme.SubText}, 0.2)
                tween(c.Bar, {Size = UDim2.fromOffset(3, 0)}, 0.2)
            end
            currentTab = tab
            page.Visible = true
            tween(btn, {BackgroundTransparency = 0.35, TextColor3 = Theme.Text}, 0.2)
            tween(bar, {Size = UDim2.fromOffset(3, 20)}, 0.25)
        end
        btn.MouseButton1Click:Connect(function() tab:Select() end)
        btn.MouseEnter:Connect(function() if currentTab ~= tab then tween(btn, {BackgroundTransparency = 0.7}, 0.15) end end)
        btn.MouseLeave:Connect(function() if currentTab ~= tab then tween(btn, {BackgroundTransparency = 1}, 0.15) end end)

        -- elements ------------------------------------------------------
        local function row(height, parent)
            return new("Frame", {
                Size = UDim2.new(1, 0, 0, height or 40), BackgroundColor3 = Theme.Item,
                BackgroundTransparency = 0.25, Parent = parent or page,
            }, {corner(8)})
        end
        local function label(parent, text, size, color, pos, font)
            return new("TextLabel", {
                Text = text, Font = font or Enum.Font.GothamMedium, TextSize = size or 13,
                TextColor3 = color or Theme.Text, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = pos or UDim2.fromOffset(12, 0), Size = UDim2.new(1, -80, 1, 0), Parent = parent,
            })
        end

        -- wrapped text that grows with its content (the old fixed-height rows clipped long lines)
        function tab:Label(text)
            return new("TextLabel", {
                Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = page,
            }, {new("UIPadding", {
                PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2),
            })})
        end

        function tab:Toggle(text, default, cb, parent)
            local r = row(40, parent)
            label(r, text)
            local track = new("Frame", {
                Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10), BackgroundColor3 = Theme.Panel, Parent = r,
            }, {corner(10)})
            local knob = new("Frame", {
                Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3),
                BackgroundColor3 = Theme.Text, Parent = track,
            }, {corner(7)})
            local state = default and true or false
            local function render(animate)
                local t = animate and 0.2 or 0
                tween(track, {BackgroundColor3 = state and Theme.Accent or Theme.Panel}, t)
                tween(knob, {Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)}, t)
            end
            render(false)
            -- the whole row is the hit area (the 40x20 switch alone is too small for a finger)
            local hit = new("TextButton", {Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromScale(1, 1), Parent = r})
            local api = {}
            function api:Get() return state end
            function api:Set(v)
                v = v and true or false
                if v == state then return end
                state = v
                render(true)
                task.spawn(cb, state)
            end
            hit.MouseButton1Click:Connect(function() api:Set(not state) end)
            task.spawn(cb, state)
            return api
        end

        function tab:Button(text, cb)
            local r = row(40)
            local b = new("TextButton", {
                Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AutoButtonColor = false, Parent = r,
            })
            b.MouseEnter:Connect(function() tween(r, {BackgroundTransparency = 0.05}, 0.15) end)
            b.MouseLeave:Connect(function() tween(r, {BackgroundTransparency = 0.25}, 0.15) end)
            b.MouseButton1Click:Connect(function()
                tween(r, {BackgroundColor3 = Theme.Accent}, 0.1).Completed:Connect(function()
                    tween(r, {BackgroundColor3 = Theme.Item}, 0.25)
                end)
                task.spawn(cb)
            end)
        end

        function tab:Slider(text, min, max, default, step, cb, parent)
            assert(max > min and step > 0, "Slider: need max > min and step > 0")
            local r = row(54, parent)
            label(r, text, 13, Theme.Text, UDim2.fromOffset(12, 4)).Size = UDim2.new(1, -80, 0, 20)
            local val = new("TextLabel", {
                Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Accent, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -72, 0, 4),
                Size = UDim2.fromOffset(60, 20), Parent = r,
            })
            local rail = new("TextButton", {
                Text = "", AutoButtonColor = false, Position = UDim2.new(0, 12, 1, -18),
                Size = UDim2.new(1, -24, 0, 10), BackgroundColor3 = Theme.Panel, Parent = r,
            }, {corner(5)})
            local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = rail}, {corner(5)})
            local function set(v, fire)
                v = math.floor((v - min) / step + 0.5) * step + min       -- snap relative to min
                v = math.clamp(tonumber(string.format("%.4f", v)), min, max)   -- no float noise in callbacks
                val.Text = tostring(v)
                tween(fill, {Size = UDim2.fromScale((v - min) / (max - min), 1)}, 0.08, Enum.EasingStyle.Linear)
                if fire then task.spawn(cb, v) end
            end
            set(default, true)
            local dragging = false
            local function fromInput(i)
                local w = rail.AbsoluteSize.X
                if w <= 0 then return end
                set(min + (max - min) * math.clamp((i.Position.X - rail.AbsolutePosition.X) / w, 0, 1), true)
            end
            local function isPointer(i)
                return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
            end
            rail.InputBegan:Connect(function(i)
                if isPointer(i) then dragging = true; fromInput(i) end
            end)
            connect(UserInputService.InputEnded, function(i) if isPointer(i) then dragging = false end end)
            connect(UserInputService.InputChanged, function(i)
                if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
            end)
            local api = {}
            function api:Set(v) set(v, true) end
            return api
        end

        function tab:Dropdown(text, options, default, cb, parent)
            local r = row(40, parent)
            label(r, text)
            local i = table.find(options, default) or 1        -- unknown default -> first option (and show it)
            local b = new("TextButton", {
                Text = options[i], Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Accent,
                BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
                Size = UDim2.fromOffset(110, 30), Position = UDim2.new(1, -122, 0.5, -15), Parent = r,
            }, {corner(6)})
            b.MouseButton1Click:Connect(function()
                i = i % #options + 1
                b.Text = options[i]
                task.spawn(cb, options[i])
            end)
            task.spawn(cb, options[i])
            local api = {}
            function api:Set(v)
                local idx = table.find(options, v)
                if not idx then return end
                i = idx
                b.Text = options[i]
                task.spawn(cb, options[i])
            end
            return api
        end

        -- collapsible section with card buttons / toggles (like the reference UI)
        function tab:Section(title)
            local holder = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Parent = page,
            }, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
            local head = new("TextButton", {
                Text = title, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30), AutoButtonColor = false, LayoutOrder = 0, Parent = holder,
            })
            local arrow = new("TextLabel", {
                Text = "^", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent,
                BackgroundTransparency = 1, Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(20, 30), Parent = head,
            })
            local body = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, LayoutOrder = 1, Parent = holder,
            }, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
            local open = true
            head.MouseButton1Click:Connect(function()
                open = not open
                body.Visible = open
                arrow.Text = open and "^" or "v"
            end)

            local sec = {}
            -- cb = what a tap does; buildOptions(drawer) (optional) fills an options drawer that opens with "Opt"
            function sec:Button(name, desc, cb, buildOptions)
                local holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1, Parent = body,
                }, {new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})})
                local card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = Theme.Item,
                    BackgroundTransparency = 0.35, LayoutOrder = 0, Parent = holder,
                }, {corner(10)})
                new("TextLabel", {
                    Text = name, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -70, 0, 18), Parent = card,
                })
                new("TextLabel", {
                    Text = desc or "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
                    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                    TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -70, 0, 42), Parent = card,
                })
                new("TextLabel", {
                    Text = ">", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.Accent,
                    BackgroundTransparency = 1, Position = UDim2.new(1, -50, 0, 0), Size = UDim2.fromOffset(36, 44), Parent = card,
                })
                local hit = new("TextButton", {
                    Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), AutoButtonColor = false, Parent = card,
                })
                hit.MouseEnter:Connect(function() tween(card, {BackgroundTransparency = 0.15}, 0.15) end)
                hit.MouseLeave:Connect(function() tween(card, {BackgroundTransparency = 0.35}, 0.15) end)
                hit.MouseButton1Click:Connect(function()
                    tween(card, {BackgroundColor3 = Theme.Accent}, 0.1).Completed:Connect(function()
                        tween(card, {BackgroundColor3 = Theme.Item}, 0.25)
                    end)
                    task.spawn(cb)
                end)

                if buildOptions then
                    local drawer = new("Frame", {
                        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundTransparency = 1, Visible = false, LayoutOrder = 1, Parent = holder,
                    }, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
                    local built, open = false, false
                    local optBtn = new("TextButton", {   -- sits above the hit area so it gets its own tap
                        Text = "Opt", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent,
                        BackgroundColor3 = Theme.Panel, AutoButtonColor = false, ZIndex = 3,
                        Size = UDim2.fromOffset(44, 26), Position = UDim2.new(1, -54, 1, -34), Parent = card,
                    }, {corner(8)})
                    optBtn.MouseButton1Click:Connect(function()
                        open = not open
                        if open and not built then       -- build lazily: hundreds of sliders up front would be slow on phones
                            built = true
                            buildOptions(drawer)
                        end
                        drawer.Visible = open
                        optBtn.Text = open and "Close" or "Opt"
                        optBtn.BackgroundColor3 = open and Theme.Accent or Theme.Panel
                        optBtn.TextColor3 = open and Theme.Back or Theme.Accent
                    end)
                end
            end
            -- read-only card with wrapped text (used for the tech library)
            function sec:Info(name, desc)
                local card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Item, BackgroundTransparency = 0.35, Parent = body,
                }, {
                    corner(10),
                    new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}),
                    new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}),
                })
                new("TextLabel", {
                    Text = name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 0, Parent = card,
                })
                new("TextLabel", {
                    Text = desc or "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
                    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                    TextWrapped = true, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card,
                })
            end
            function sec:Toggle(name, default, cb) return tab:Toggle(name, default, cb, body) end
            function sec:Clear()
                for _, ch in ipairs(body:GetChildren()) do
                    if not ch:IsA("UIListLayout") then ch:Destroy() end
                end
            end
            return sec
        end

        Tabs[#Tabs + 1] = tab
        return tab
    end

    ---------------------------------------------------------------- state
    local Settings = {
        AutoTech      = false,
        TechKey       = Enum.KeyCode.Q,
        TechDelay     = 0.05,
        TechCooldown  = 0.6,
        TechDirection = "Back",
    }

    ---------------------------------------------------------------- Auto Tech
    local lastTech = 0

    local DirectionKeys = {
        Forward = Enum.KeyCode.W, Back = Enum.KeyCode.S,
        Left    = Enum.KeyCode.A, Right = Enum.KeyCode.D,
    }

    local function keyEvent(down, key) VirtualInput:SendKeyEvent(down, key, false, game) end
    local function press(key, hold)
        keyEvent(true, key)
        task.wait(hold or 0.03)
        keyEvent(false, key)
    end

    local function isKnocked(char)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Ragdoll
            or st == Enum.HumanoidStateType.FallingDown
            or st == Enum.HumanoidStateType.PlatformStanding then
            return true
        end
        -- the game may flag knockdown with attributes / values
        return char:GetAttribute("Ragdolled") == true or char:GetAttribute("Stunned") == true
            or char:FindFirstChild("Ragdolled") ~= nil
    end

    local macroRunning = false   -- set by the macro runner below; Auto Tech stays quiet while a macro plays

    local function doTech()
        if macroRunning then return end
        local now = os.clock()
        if now - lastTech < Settings.TechCooldown then return end
        lastTech = now
        task.spawn(function()
            task.wait(Settings.TechDelay)
            -- the world may have changed during the delay: toggled off, UI closed, or already recovered
            if not (alive and Settings.AutoTech and isKnocked(LocalPlayer.Character)) then return end
            local dir = DirectionKeys[Settings.TechDirection]
            if dir then keyEvent(true, dir) end
            pcall(press, Settings.TechKey, 0.04)
            if dir then task.wait(0.05); keyEvent(false, dir) end   -- always release the direction key
        end)
    end

    local wasKnocked = false
    connect(RunService.Heartbeat, function()
        if not Settings.AutoTech then wasKnocked = false return end
        local knocked = isKnocked(LocalPlayer.Character)
        if knocked and not wasKnocked then doTech() end
        wasKnocked = knocked
    end)

    ---------------------------------------------------------------- timing + ping
    -- Gaps (seconds) after each kind of step. Adjustable in the Timing tab. With "Auto timing" on, the gaps
    -- that wait for a visible cue (after a move or dash) are additionally shortened by about your ping
    -- (see ping_model.lua). Heuristic: it cannot read other players' ping and cannot guarantee a hit.
    local TimingDefaults = {m1 = 0.2, dash = 0.3, move = 0.5, jump = 0.25}
    local Timing = {m1 = 0.2, dash = 0.3, move = 0.5, jump = 0.25}
    local Auto = {on = true, strength = 1, offsetMs = 0, manualPing = 0}
    local macroSpeed = 1
    local PingState = {model = PingModel and PingModel.new(0.2)}

    -- saved settings (global timing + every combo's own options) survive leaving the game when the executor has files
    local SETTINGS_FILE = "animation_hub_settings.json"
    local function loadSaved()
        if not (isfile and readfile) then return {} end
        local raw = safe(function() if isfile(SETTINGS_FILE) then return readfile(SETTINGS_FILE) end end)
        if type(raw) ~= "string" or raw == "" then return {} end
        local data = safe(function() return game:GetService("HttpService"):JSONDecode(raw) end)
        return type(data) == "table" and data or {}
    end
    local function num(v, lo, hi, default)
        if type(v) ~= "number" or v ~= v then return default end
        return math.min(math.max(v, lo), hi)
    end
    local Saved = loadSaved()
    local ComboOpts = {}                                   -- combo name -> options table (see combo_options.lua)
    if type(Saved.timing) == "table" then
        Timing.m1   = num(Saved.timing.m1,   0.08, 0.6, Timing.m1)
        Timing.dash = num(Saved.timing.dash, 0.08, 0.8, Timing.dash)
        Timing.move = num(Saved.timing.move, 0.15, 1.2, Timing.move)
        Timing.jump = num(Saved.timing.jump, 0.08, 0.6, Timing.jump)
    end
    if type(Saved.auto) == "table" then
        Auto.on = Saved.auto.on ~= false
        Auto.strength = num(Saved.auto.strength, 0, 1.5, Auto.strength)
        Auto.offsetMs = num(Saved.auto.offsetMs, -100, 100, Auto.offsetMs)
        Auto.manualPing = num(Saved.auto.manualPing, 0, 400, Auto.manualPing)
    end
    macroSpeed = num(Saved.speed, 0.5, 2, macroSpeed)
    if ComboOptions and type(Saved.combos) == "table" then
        for name, o in pairs(Saved.combos) do
            if type(name) == "string" then ComboOpts[name] = ComboOptions.sanitize(o) end
        end
    end
    local function getOpts(name)
        if not ComboOptions then return nil end
        if not ComboOpts[name] then ComboOpts[name] = ComboOptions.new() end
        return ComboOpts[name]
    end

    local dirty, ready = false, false
    local function markDirty() if ready then dirty = true end end
    local function saveNow()
        dirty = false
        if not (writefile and ComboOptions) then return end
        local combos = {}
        for name, o in pairs(ComboOpts) do
            if not ComboOptions.isDefault(o) then combos[name] = o end    -- only what differs from the defaults
        end
        local data = {version = 1, timing = Timing, speed = macroSpeed, auto = Auto, combos = combos}
        local json = safe(function() return game:GetService("HttpService"):JSONEncode(data) end)
        if type(json) == "string" then pcall(writefile, SETTINGS_FILE, json) end
    end
    onCleanup[#onCleanup + 1] = function() if dirty then saveNow() end end
    do
        local acc = 0
        connect(RunService.Heartbeat, function(dt)
            acc = acc + dt
            if acc < 2 then return end                  -- write at most every 2 s, only when something changed
            acc = 0
            if dirty then saveNow() end
        end)
    end
    local pingLabel, gapsLabel

    local function readPing()
        local item = safe(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"] end)
        local v = item and safe(function() return item:GetValue() end)
        if type(v) == "number" then return v end
    end
    local function currentPing()                       -- ms, or nil when unknown
        if Auto.manualPing > 0 then return Auto.manualPing end
        return PingState.model and PingState.model:value()
    end
    -- final wait for one step. o = that combo's options (nil = defaults): own gap or global gap, x speeds, then
    -- (auto timing on for this combo) the ping adjustment for gaps that wait for a visible cue
    local DefaultOpts = ComboOptions and ComboOptions.new()
    local function stepDelay(kind, dependent, o)
        o = o or DefaultOpts
        local gap
        if o and ComboOptions then gap = ComboOptions.gap(kind, Timing, o, macroSpeed)
        else gap = Timing[kind] * macroSpeed end
        local autoOn = (o and ComboOptions) and ComboOptions.autoOn(Auto.on, o) or Auto.on
        if not (autoOn and PingModel) then return gap end
        return PingModel.adjustDelay(gap, currentPing(), Auto.strength, {dependent = dependent, offsetMs = Auto.offsetMs + (o and o.offsetMs or 0)})
    end

    do
        local acc = 0
        connect(RunService.Heartbeat, function(dt)
            acc = acc + dt
            if acc < 0.25 then return end              -- 4 samples per second is plenty
            acc = 0
            if PingState.model then
                local v = readPing()
                if v then PingState.model:sample(v) end
            end
            if pingLabel then
                local p = currentPing()
                if p then
                    local j = PingState.model and PingState.model:jitter() or 0
                    local note = (PingState.model and Auto.manualPing <= 0 and not PingState.model:stable()) and "  (unstable)" or ""
                    pingLabel.Text = string.format("Ping: %d ms   jitter: %d ms%s", math.floor(p + 0.5), math.floor(j + 0.5), note)
                else
                    pingLabel.Text = "Ping: unknown - set Manual ping below"
                end
            end
            if gapsLabel then
                gapsLabel.Text = string.format("Gaps now  M1 %.2fs  dash %.2fs  move %.2fs  jump %.2fs%s",
                    stepDelay("m1", false), stepDelay("dash", true), stepDelay("move", true), stepDelay("jump", false),
                    Auto.on and "   (auto)" or "   (manual)")
            end
        end)
    end

    ---------------------------------------------------------------- macro runner
    -- Plays a combo from tsb_data as real inputs. Move slots assume the hotbar order = the move list
    -- order in tsb_data (1..4). That order is UNVERIFIED: if a move fires the wrong skill, edit MoveSlots.
    local MoveSlots = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
    local macroId = 0

    local function click()
        local vw, vh = viewport()
        vw, vh = vw or 400, vh or 300
        VirtualInput:SendMouseButtonEvent(vw / 2, vh / 2, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(vw / 2, vh / 2, 0, false, game, 0)
    end
    local function dash(dirKey)
        if dirKey then keyEvent(true, dirKey) end
        pcall(press, Enum.KeyCode.Q, 0.04)
        if dirKey then task.wait(0.03); keyEvent(false, dirKey) end
    end

    -- which timing category a generic token belongs to
    local KIND = {M1 = "m1", JUMP_M1 = "m1", JUMP = "jump", Q = "dash", FRONTDASH = "dash", BACKDASH = "dash", SIDEDASH = "dash"}
    local function moveKey(tok, charName)
        local char = Data and Data.Characters[charName]
        if char and type(char.moves) == "table" then
            for i, mv in ipairs(char.moves) do
                if mv == tok then return MoveSlots[i] end
            end
        end
    end
    local function canPlay(tok, charName) return KIND[tok] ~= nil or moveKey(tok, charName) ~= nil end

    -- plays one step; returns (kind of gap that follows it, whether that gap waits for a visible cue),
    -- or nil if the token cannot be played. o = this combo's options.
    local function playToken(tok, charName, o)
        local kind = KIND[tok]
        if tok == "M1" then click()
        elseif tok == "Q" then dash(nil)
        elseif tok == "FRONTDASH" then dash(Enum.KeyCode.W)
        elseif tok == "BACKDASH" then dash(Enum.KeyCode.S)
        elseif tok == "SIDEDASH" then dash((o and o.side == "Right") and Enum.KeyCode.D or Enum.KeyCode.A)
        elseif tok == "JUMP" then press(Enum.KeyCode.Space, 0.05)
        elseif tok == "JUMP_M1" then press(Enum.KeyCode.Space, 0.05); task.wait(0.12); click()
        else
            local key = moveKey(tok, charName)
            if not key then return nil end
            press(key, 0.05)
            return "move", true
        end
        return kind, kind == "dash"
    end

    local function stopMacro()
        macroId = macroId + 1          -- any running macro thread notices the new id and exits
        macroRunning = false
    end
    onCleanup[#onCleanup + 1] = stopMacro

    local function runMacro(steps, charName, comboName)
        if macroRunning then stopMacro() return end        -- tapping again stops it
        macroId = macroId + 1
        local myId = macroId
        macroRunning = true
        local opts = comboName and getOpts(comboName) or nil
        task.spawn(function()
            local ok, err = pcall(function()
                for _, tok in ipairs(steps) do
                    if myId ~= macroId then return end       -- stopped, or replaced by a newer macro
                    local kind, dependent = playToken(tok, charName, opts)
                    if kind then task.wait(stepDelay(kind, dependent, opts)) end
                end
            end)
            if myId == macroId then macroRunning = false end  -- never clobber a newer macro's flag
            if not ok then warn("[Animation Hub] macro failed: " .. tostring(err)) end
        end)
    end

    -- "M1 x3 > SIDEDASH > FLOWING WATER ...", plus how many steps cannot be played automatically
    local function describe(steps, charName)
        local out, i, skipped = {}, 1, 0
        while i <= #steps do
            local j = i
            while steps[j + 1] == steps[i] do j = j + 1 end
            local name = steps[i]:gsub("_", " ")
            local playable = canPlay(steps[i], charName)
            if not playable then skipped = skipped + (j - i + 1); name = name .. "*" end
            out[#out + 1] = (j > i) and (name .. " x" .. (j - i + 1)) or name
            i = j + 1
        end
        local text = table.concat(out, " > ")
        if skipped > 0 then text = text .. "   (* " .. skipped .. " step(s) skipped: no key mapped)" end
        return text
    end

    ---------------------------------------------------------------- tabs
    local Main_  = createTab("Main", "#")
    local Credit = createTab("Credit", "+")
    local CharList = {
        {"The Strongest Hero", "Saitama"}, {"Hero Hunter", "Garou"}, {"Destructive Cyborg", "Genos"},
        {"Deadly Ninja", "Sonic"}, {"Brutal Demon", "Metal Bat"}, {"Wild Psychic", "Tatsumaki"},
        {"Blade Master", "Atomic Samurai"}, {"Tech Prodigy", "Tech Prodigy"},
    }
    local CharTabs = {}
    if Data then
        for _, ch in ipairs(CharList) do
            CharTabs[#CharTabs + 1] = {tab = createTab(ch[2], ch[2]:sub(1, 1)), full = ch[1], short = ch[2]}
        end
    end
    local Timing_ = createTab("Timing", "T")
    local TechLib = Data and createTab("Techs", "?")
    local Tech   = createTab("Auto Tech", "*")
    local Tele   = createTab("Teleports", "@")
    local Effects = createTab("Effects Preset", "~")

    -- Main
    Main_:Label("General utilities")
    local wantSpeed
    local function applySpeed()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and wantSpeed then hum.WalkSpeed = wantSpeed end
    end
    Main_:Slider("WalkSpeed", 16, 120, 16, 1, function(v)
        if v ~= 16 or wantSpeed then wantSpeed = v; applySpeed() end   -- leave the game's own speed alone until touched
    end)
    connect(LocalPlayer.CharacterAdded, function(char)
        char:WaitForChild("Humanoid", 5)
        if alive then applySpeed() end                                  -- survive respawns
    end)
    local antiAfk = true
    connect(LocalPlayer.Idled, function()          -- one listener for the whole session; the toggle just gates it
        if not antiAfk then return end
        local vu = safe(function() return game:GetService("VirtualUser") end)
        if vu then
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        else
            pcall(press, Enum.KeyCode.Space, 0.03)
        end
    end)
    Main_:Toggle("Anti AFK", true, function(on) antiAfk = on end)
    Main_:Button("Reset Character", function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end)

    -- character tabs built from tsb_data (only when bundled in)
    local function buildCharacter(tab, fullName, label)
        if not tab then return end
        local sec = {}
        local function get(key, title)
            if not sec[key] then sec[key] = tab:Section(title) end
            return sec[key]
        end
        local names = {}
        for name, c in pairs(Data.Combos) do
            if c.character == fullName then names[#names + 1] = name end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            local c = Data.Combos[name]
            local key, title = "combos", label .. " combos"
            if name:find("Kyoto") then key, title = "kyoto", label .. " kyoto"
            elseif name:find("Catch") then key, title = "tech", label .. " tech" end
            local o = getOpts(name)
            local function drawer(parent)                       -- this combo's own options
                local function set(key) return function(v) if o[key] ~= v then o[key] = v; markDirty() end end end
                local pickers, sliders = {}, {}
                pickers.auto = tab:Dropdown("Auto timing", {"global", "on", "off"}, o.auto, set("auto"), parent)
                sliders.speed = tab:Slider("Speed (higher = slower)", 0.5, 2, o.speed, 0.05, set("speed"), parent)
                sliders.m1 = tab:Slider("M1 gap (0 = global)", 0, 0.6, o.m1, 0.01, set("m1"), parent)
                sliders.dash = tab:Slider("Dash gap (0 = global)", 0, 0.8, o.dash, 0.01, set("dash"), parent)
                sliders.move = tab:Slider("Move gap (0 = global)", 0, 1.2, o.move, 0.01, set("move"), parent)
                sliders.jump = tab:Slider("Jump gap (0 = global)", 0, 0.6, o.jump, 0.01, set("jump"), parent)
                sliders.offsetMs = tab:Slider("Fine-tune (ms, + = later)", -100, 100, o.offsetMs, 5, set("offsetMs"), parent)
                pickers.side = tab:Dropdown("Side dash key", {"Left", "Right"}, o.side, set("side"), parent)
                local reset = new("TextButton", {
                    Text = "Reset this combo", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
                    BackgroundColor3 = Theme.Panel, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), Parent = parent,
                }, {corner(8)})
                reset.MouseButton1Click:Connect(function()
                    for key, sl in pairs(sliders) do sl:Set(ComboOptions.DEFAULTS[key]) end
                    for key, dd in pairs(pickers) do dd:Set(ComboOptions.DEFAULTS[key]) end
                end)
            end
            get(key, title):Button(name:gsub("_", " ") .. "  [" .. tostring(c.confidence or "?") .. "]", describe(c.steps, fullName), function()
                runMacro(c.steps, fullName, name)
            end, o and drawer or nil)
        end
        tab:Label("Tap a card to play the combo as inputs, tap again to stop. Moves use hotbar slots 1-4 (unverified order). Steps marked * have no key mapped and are skipped. Gaps: Timing tab.")
    end
    if Data then
        for _, c in ipairs(CUSTOM_COMBOS) do
            if type(c) == "table" and type(c.name) == "string" and type(c.steps) == "table" and #c.steps > 0 then
                Data.Combos[c.name] = {character = c.character or "Hero Hunter", confidence = c.confidence or "custom", steps = c.steps}
            end
        end
    end
    buildCharacter(Main_, "Universal", "Universal")
    for _, ct in ipairs(CharTabs) do buildCharacter(ct.tab, ct.full, ct.short) end

    -- Timing tab
    pingLabel = Timing_:Label("Ping: measuring...")
    gapsLabel = Timing_:Label("Gaps now ...")
    local function changed(tbl, key) return function(v) if tbl[key] ~= v then tbl[key] = v; markDirty() end end end
    Timing_:Toggle("Auto timing from ping", Auto.on, changed(Auto, "on"))
    Timing_:Slider("Auto strength", 0, 1.5, Auto.strength, 0.05, changed(Auto, "strength"))
    Timing_:Slider("Fine-tune (ms, + = later)", -100, 100, Auto.offsetMs, 5, changed(Auto, "offsetMs"))
    Timing_:Slider("Manual ping ms (0 = measured)", 0, 400, Auto.manualPing, 5, changed(Auto, "manualPing"))
    Timing_:Label("These are the global values. Every combo card also has an Opt button with its own overrides (speed, gaps, fine-tune, auto mode, side-dash key).")
    Timing_:Label("Auto timing shortens the gaps that wait for a visible cue (after moves and dashes) by about your ping. Your own ping only: other players' ping can't be read, and the server decides if a hit lands, so tune Fine-tune until it lands for you.")
    Timing_:Label("Base gaps (seconds between steps)")
    local gapSliders = {
        m1   = Timing_:Slider("M1 gap",   0.08, 0.6, Timing.m1,   0.01, changed(Timing, "m1")),
        dash = Timing_:Slider("Dash gap", 0.08, 0.8, Timing.dash, 0.01, changed(Timing, "dash")),
        move = Timing_:Slider("Move gap", 0.15, 1.2, Timing.move, 0.01, changed(Timing, "move")),
        jump = Timing_:Slider("Jump gap", 0.08, 0.6, Timing.jump, 0.01, changed(Timing, "jump")),
    }
    Timing_:Slider("Overall speed (higher = slower)", 0.5, 2, macroSpeed, 0.05, function(v)
        if macroSpeed ~= v then macroSpeed = v; markDirty() end
    end)
    Timing_:Button("Reset timing to defaults", function()
        for k, sl in pairs(gapSliders) do sl:Set(TimingDefaults[k]) end
    end)

    -- Tech library: every tech found in research, with how sure the sources are
    if TechLib then
        local byChar, order = {}, {}
        for _, t in ipairs(Data.Techs or {}) do
            local who = t.character or "Universal"
            if not byChar[who] then byChar[who] = {}; order[#order + 1] = who end
            table.insert(byChar[who], t)
        end
        table.sort(order, function(a, b)
            if a == "Universal" then return b ~= "Universal" end
            if b == "Universal" then return false end
            return a < b
        end)
        TechLib:Label("Everything found in research (fan wikis, guides, forum posts, videos). Confidence shows how well sourced it is; a lot of it is unverified and the game is patched often.")
        for _, who in ipairs(order) do
            local sec = TechLib:Section(who .. " (" .. #byChar[who] .. ")")
            for _, t in ipairs(byChar[who]) do
                sec:Info(t.name .. "  [" .. tostring(t.confidence or "?") .. "]", t.desc)
            end
        end
    end

    -- Auto Tech
    Tech:Label("Recovers automatically when you get knocked down.")
    local techToggle = Tech:Toggle("Auto Tech", false, function(on)
        Settings.AutoTech = on
        if renderFab then renderFab() end
    end)
    Tech:Dropdown("Direction", {"Back", "Forward", "Left", "Right"}, "Back", function(v) Settings.TechDirection = v end)
    Tech:Slider("Reaction Delay (s)", 0, 0.5, 0.05, 0.01, function(v) Settings.TechDelay = v end)
    Tech:Slider("Cooldown (s)", 0.1, 3, 0.6, 0.05, function(v) Settings.TechCooldown = v end)
    Tech:Label("Dash key defaults to Q - change Settings.TechKey if you rebound it.")

    -- Teleports (list follows players joining / leaving)
    local playerSec = Tele:Section("Players")
    local function teleportTo(p)
        local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local theirs = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if mine and theirs then mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 4) end
    end
    local function refreshPlayers(leaving)
        playerSec:Clear()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p ~= leaving then list[#list + 1] = p end
        end
        table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
        for _, p in ipairs(list) do
            playerSec:Button(p.DisplayName, "@" .. p.Name, function() teleportTo(p) end)
        end
    end
    refreshPlayers()
    connect(Players.PlayerAdded, function() refreshPlayers() end)
    connect(Players.PlayerRemoving, function(p) refreshPlayers(p) end)
    Tele:Button("Teleport to Spawn", function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
        if hrp and spawn then hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0) end
    end)

    -- Credit
    Credit:Label("Animation Hub UI")
    Credit:Label("Toggle menu: RightShift, or the floating bar: Menu = show/hide, Tech = Auto Tech on/off, Lock = pin it in place, - = shrink it to a dot. Drag it anywhere.")
    Credit:Label("Background: random SFW image from waifu.pics / nekos.best (fan art, not copyright-free).", 40)

    -- Effects Preset
    Effects:Label("Background image", 24)
    Effects:Slider("Image opacity", 0.1, 1, 1 - BACKGROUND_TRANSPARENCY, 0.05, function(v)
        Background.ImageTransparency = 1 - v
    end)
    Effects:Dropdown("Source", {"waifu.pics", "nekos.best"}, BACKGROUND_SOURCE, function(v) BACKGROUND_SOURCE = v end)
    Effects:Button("New random background", function() refreshBackground(BACKGROUND_SOURCE) end)
    Effects:Label("Images come from public waifu APIs (SFW endpoints). They are community fan art, so the artists keep the copyright - use your own CC0 image via BACKGROUND_URL if you need that.", 60)

    -- Predictor tab: only when combo_engine/tsb_data were bundled in (see game_dev/build_executor.py)
    if Engine and Data then
        Engine.loadData(Data)
        local Pred = createTab("Predictor", "?")
        Pred:Label("Guesses which combo you are doing from your M1 / dash / jump inputs and what usually comes next.", 40)
        local out = Pred:Label("Waiting for input...")
        out.TextSize = 13
        out.TextColor3 = Theme.Text
        local predictor = Engine.newPredictor()
        local function token(input)
            local k = input.KeyCode
            if input.UserInputType == Enum.UserInputType.MouseButton1 then return "M1" end
            if k == Enum.KeyCode.Space then return "JUMP" end
            if k == Enum.KeyCode.Q then
                local down = function(key) return UserInputService:IsKeyDown(key) end
                if down(Enum.KeyCode.W) then return "FRONTDASH" end
                if down(Enum.KeyCode.S) then return "BACKDASH" end
                if down(Enum.KeyCode.A) or down(Enum.KeyCode.D) then return "SIDEDASH" end
                return "Q"
            end
        end
        connect(UserInputService.InputBegan, function(input, gp)
            if gp then return end
            local t = token(input)
            if t then predictor:feed(t, os.clock()) end
        end)
        local acc = 0
        connect(RunService.Heartbeat, function(dt)
            acc = acc + dt
            if acc < 0.1 then return end
            acc = 0
            local now = os.clock()
            local list = predictor:predict(now)
            if #list == 0 then out.Text = "No combo detected." return end
            local lines = {}
            for i = 1, math.min(4, #list) do
                local r = list[i]
                lines[#lines + 1] = string.format("%s  %d/%d  (%d%%)  next: %s", r.name, r.progress, r.total, math.floor(r.confidence * 100), tostring(r.next))
            end
            local _, best = predictor:nextInputs(now)
            lines[#lines + 1] = "Best guess next: " .. tostring(best)
            out.Text = table.concat(lines, "\n")
        end)
    end

    ---------------------------------------------------------------- floating bar (touch "keybind")
    -- [Menu] [Tech] [Lock] [-]  - drag to move, Lock pins it, "-" shrinks it to a dot (tap the dot to expand).
    -- Position / lock / minimised state survive re-running the script in the same game session.
    do
        local BAR_W, BAR_H, DOT = 196, 44, 36
        local saved = genv.__AnimationHubFab or {}
        local fabState = {x = saved.x, y = saved.y, locked = saved.locked == true, minimized = saved.minimized == true}
        local vw0, vh0 = viewport()
        fabState.x = fabState.x or 12
        fabState.y = fabState.y or ((vh0 or 450) / 2 - BAR_H / 2)

        local tracker = DragTracker and DragTracker.new(8)    -- no tracker (unbundled file): bar is simply fixed
        if tracker then tracker:setLocked(fabState.locked) end

        local fab = new("Frame", {
            Size = UDim2.fromOffset(BAR_W, BAR_H), Position = UDim2.fromOffset(fabState.x, fabState.y),
            BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.1, ZIndex = 10, Parent = Gui,
        }, {corner(22), stroke(Theme.Accent, 1.5, 0.3)})

        local function isPointer(i)
            return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
        end
        local function attachDrag(obj)
            if not tracker then return end
            obj.InputBegan:Connect(function(i)
                if isPointer(i) then tracker:begin(i.Position.X, i.Position.Y, fabState.x, fabState.y) end
            end)
        end
        local function paint(btn, on)
            btn.BackgroundColor3 = on and Theme.Accent or Theme.Item
            btn.TextColor3 = on and Theme.Back or Theme.Text
        end
        local function tappable(onTap)
            return function()
                if tracker and tracker:suppressClick(os.clock()) then return end   -- that "click" was the end of a drag
                onTap()
            end
        end
        local function barButton(text, x, w, onTap)
            local b = new("TextButton", {
                Text = text, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Text,
                BackgroundColor3 = Theme.Item, AutoButtonColor = false,
                Size = UDim2.fromOffset(w, BAR_H - 8), Position = UDim2.fromOffset(x, 4), ZIndex = 11, Parent = fab,
            }, {corner(14)})
            b.MouseButton1Click:Connect(tappable(onTap))
            attachDrag(b)
            return b
        end

        local menuBtn, techBtn, lockBtn, minBtn, dot
        local function place()
            local w, h = BAR_W, BAR_H
            if fabState.minimized then w, h = DOT, DOT end
            local vw, vh = viewport()
            if DragTracker and vw then
                fabState.x, fabState.y = DragTracker.clamp(fabState.x, fabState.y, w, h, vw, vh, 4)
            end
            fab.Size = UDim2.fromOffset(w, h)
            fab.Position = UDim2.fromOffset(fabState.x, fabState.y)
            genv.__AnimationHubFab = fabState
        end
        renderFab = function()
            paint(menuBtn, Main.Visible)
            paint(techBtn, Settings.AutoTech)
            techBtn.Text = Settings.AutoTech and "Tech ON" or "Tech OFF"
            paint(lockBtn, fabState.locked)
            lockBtn.Text = fabState.locked and "Locked" or "Lock"
            for _, b in ipairs({menuBtn, techBtn, lockBtn, minBtn}) do b.Visible = not fabState.minimized end
            dot.Visible = fabState.minimized
            place()
        end

        menuBtn = barButton("Menu", 4, 46, toggleMenu)
        techBtn = barButton("Tech OFF", 54, 54, function() techToggle:Set(not techToggle:Get()) end)
        lockBtn = barButton("Lock", 112, 48, function()
            fabState.locked = not fabState.locked
            if tracker then tracker:setLocked(fabState.locked) end
            renderFab()
        end)
        minBtn = barButton("-", 164, 28, function() fabState.minimized = true; renderFab() end)
        dot = new("TextButton", {
            Text = "AH", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Back,
            BackgroundColor3 = Theme.Accent, AutoButtonColor = false, Visible = false,
            Size = UDim2.fromOffset(DOT - 8, DOT - 8), Position = UDim2.fromOffset(4, 4), ZIndex = 11, Parent = fab,
        }, {corner(14)})
        dot.MouseButton1Click:Connect(tappable(function() fabState.minimized = false; renderFab() end))
        attachDrag(dot)
        attachDrag(fab)

        if tracker then
            connect(UserInputService.InputChanged, function(i)
                if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
                local nx, ny = tracker:move(i.Position.X, i.Position.Y)
                if nx then fabState.x, fabState.y = nx, ny; place() end
            end)
            connect(UserInputService.InputEnded, function(i)
                if isPointer(i) then tracker:finish(os.clock()) end
            end)
        end

        -- keep it on screen when the screen rotates / resizes
        local cam = workspace.CurrentCamera
        local sig = cam and safe(function() return cam:GetPropertyChangedSignal("ViewportSize") end)
        if sig then connect(sig, place) end

        renderFab()
    end

    ready = true                       -- from here on, changing a slider marks the settings as unsaved
    dirty = next(Saved) ~= nil         -- a loaded file is re-written once in its cleaned-up form
    Main_:Select()
    notify("Animation Hub", "Ready - tap the Menu button on the left (or press RightShift)", 6)
    print("[Animation Hub] ready, UI parent: " .. tostring(Gui.Parent and Gui.Parent.Name))

    -- open animation
    Main.Size = UDim2.fromOffset(fullSize.X.Offset, 0)
    tween(Main, {Size = fullSize}, 0.45, Enum.EasingStyle.Back)

    -- soft game check: warn (never block) if this is not The Strongest Battlegrounds
    task.spawn(function()
        local ok, info = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        end)
        if ok and info and not info:lower():find("strongest battlegrounds") then
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Animation Hub", Text = "This place is '" .. info .. "', not TSB. Auto Tech is tuned for TSB.", Duration = 6,
                })
            end)
        end
    end)

end

-- run guarded so a failure shows a message instead of silently doing nothing (common on mobile executors)
local ok, err = pcall(__run)
if not ok then
    warn("[Animation Hub] failed to start: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Animation Hub error", Text = tostring(err):sub(1, 180), Duration = 15,
        })
    end)
end
