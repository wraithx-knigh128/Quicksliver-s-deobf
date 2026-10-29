--[[
    Wraith Hub v1.5 - The Strongest Battlegrounds
    Smooth sidebar UI + Auto Tech

    Setup:
      * The menu is WindUI in the Wraith Hub v1.5 white-water look (game_dev/classic_wind.lua answers this file's menu calls).
        If WindUI cannot start, the built-in menu below opens instead; getgenv().AH_LEGACY_UI = true forces it.
      * Background of the BUILT-IN menu: a random SFW anime image is fetched from waifu.pics / nekos.best.
        NOTE: those are community fan-art images, NOT copyright-free. For art you may
        legally redistribute, set BACKGROUND_URL to your own / CC0 image.
        (The WindUI menu has the white water instead, and an optional picture / video link of your own in the Look tab.)
      * Needs request + writefile + getcustomasset for any picture; everything else works without them.

    Auto Tech: when you get knocked down / ragdolled it waits a short delay and
    presses the dash key in the chosen direction so you recover instantly.
    Delay / cooldown / direction are adjustable in the "Auto Tech" tab.
]]

local BACKGROUND_URL = ""   -- optional fixed image (direct link). "" = pick one from the waifu API below
local BACKGROUND_SOURCE = "waifu.pics"   -- "waifu.pics" or "nekos.best" (SFW endpoints only)
local BACKGROUND_TRANSPARENCY = 0.42
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
print("[Wraith Hub v1.5] starting")
notify("Wraith Hub v1.5", "Loading...", 3)

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

M.DEFAULTS = {auto = "global", speed = 1, m1 = 0, dash = 0, move = 0, jump = 0, offsetMs = 0, side = "Behind",
    trigger = 0, pinMode = "assist", trigAnim = ""}

local RANGES = {
    speed = {0.5, 2}, m1 = {0, 0.6}, dash = {0, 0.8}, move = {0, 1.2}, jump = {0, 0.6}, offsetMs = {-100, 100},
}
M.RANGES = RANGES

local AUTO = {global = true, on = true, off = true}
local SIDE = {Behind = true, Toward = true, Left = true, Right = true}
local PINMODE = {assist = true, run = true}

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
    o.side = SIDE[src.side] and src.side or (src.side == "Closest" and "Toward" or M.DEFAULTS.side)
    o.pinMode = PINMODE[src.pinMode] and src.pinMode or M.DEFAULTS.pinMode
    o.trigger = math.floor(clamp(src.trigger, 0, 64, M.DEFAULTS.trigger))
    -- an animation id is plain text like "rbxassetid://123"; anything odd or huge is thrown away
    local anim = src.trigAnim
    if type(anim) == "string" and #anim <= 120 and not anim:find("[%c]") then o.trigAnim = anim else o.trigAnim = M.DEFAULTS.trigAnim end
    return o
end

function M.new() return M.sanitize(nil) end

-- Which adjustments make sense for a combo? Only the ones that change what it actually does.
--   steps   the combo's tokens
--   kindOf  function(token) -> "m1" | "jump" | "dash" | "move" | nil (nil = cannot be played, so it has no timing)
-- Returns {m1, jump, dash, move = bool (a gap of that kind is waited between steps), dependent = bool (some gap waits for a
-- visible cue, so Auto timing / fine-tune matter), side = bool (has a SIDEDASH), played = playable step count, choosable = trigger can be picked}.
-- The wait after the LAST step changes nothing, so it does not count.
function M.needs(steps, kindOf)
    local n = {m1 = false, jump = false, dash = false, move = false, dependent = false, side = false, played = 0, choosable = false}
    if type(steps) ~= "table" then return n end
    for i, tok in ipairs(steps) do
        local kind = kindOf(tok)
        if kind then n.played = n.played + 1 end
        if tok == "SIDEDASH" then n.side = true end
        if kind and i < #steps then
            n[kind] = true
            if kind == "dash" or kind == "move" then n.dependent = true end
        end
    end
    n.choosable = #steps >= 3 and n.played >= 3        -- a trigger step only has a choice to make when there are several
    return n
end

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
local Assist = (function()


local M = {}

-- override >= 1 wins (clamped to the combo length); otherwise the first step that is a character move
-- (that is the thing you do yourself); a combo without any move starts after step 1.
function M.triggerIndex(steps, isMove, override)
    if type(steps) ~= "table" or #steps == 0 then return nil end
    if type(override) == "number" and override >= 1 then return math.min(math.floor(override), #steps) end
    for i, tok in ipairs(steps) do
        if isMove and isMove(tok) then return i end
    end
    return 1
end

-- steps after the trigger, or nil when there is nothing left to play
function M.remaining(steps, index)
    if type(steps) ~= "table" or type(index) ~= "number" or index >= #steps then return nil end
    local out = {}
    for i = index + 1, #steps do out[#out + 1] = steps[i] end
    return out
end

-- armedOrder: names, oldest first. Returns the most recently armed name that matches.
function M.pick(armedOrder, matches)
    for i = #armedOrder, 1, -1 do
        if matches(armedOrder[i]) then return armedOrder[i] end
    end
    return nil
end

-- "Left"/"Right" are fixed; "Alternate" flips from the side used last time (starting with Left)
function M.nextSide(direction, last)
    if direction == "Right" then return "Right" end
    if direction == "Alternate" then return last == "Left" and "Right" or "Left" end
    return "Left"
end

-- ---- "Start with M1" ---------------------------------------------------------------------------------------------------------
function M.leadingM1(steps)
    if type(steps) ~= "table" then return 0 end
    local k = 0
    for _, tok in ipairs(steps) do
        if tok ~= "M1" then break end
        k = k + 1
    end
    return k
end

-- returns rest, k : rest = the steps after your k M1s (nil when nothing is left)
function M.afterM1(steps)
    if type(steps) ~= "table" or #steps == 0 then return nil, 0 end
    local k = M.leadingM1(steps)
    if k >= #steps then return nil, k end
    local rest = {}
    for i = k + 1, #steps do rest[#rest + 1] = steps[i] end
    return rest, k
end

function M.m1Cap(steps, most)
    local k = M.leadingM1(steps)
    if k > 0 then return k end
    local m = tonumber(most)
    return (m and m >= 1) and math.floor(m) or 3
end

function M.m1Count(count, last, now, window)
    if type(count) == "number" and count > 0 and type(last) == "number" and type(now) == "number" and now - last <= (window or 0.8) then
        return count + 1
    end
    return 1
end

function M.m1Ready(count, last, now, cap, settle)
    if type(count) ~= "number" or count < 1 or type(last) ~= "number" or type(now) ~= "number" then return false end
    if count >= cap then return true end
    return now - last >= settle - 1e-9                                  -- (floating point: 10.35 - 10 is a hair under 0.35)
end

return M

end)()
local CombatMath = (function()


local M = {}

-- his block covers the 180 degrees in front of him (+-90); past that, plus a margin because he turns while I dash, a hit cannot be blocked
M.BEHIND_ANGLE = 105

local function num(v) return type(v) == "number" and v == v end
local function valid(p) return type(p) == "table" and num(p.x) and num(p.y) and num(p.z) end

function M.distance(a, b)
    if not (valid(a) and valid(b)) then return nil end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- list: array of {x=, y=, z=, ...anything else...}. Returns the nearest entry within maxDist (default: no limit).
function M.closest(myPos, list, maxDist)
    if not valid(myPos) or type(list) ~= "table" then return nil end
    local best, bestD = nil, nil
    for _, item in ipairs(list) do
        local d = M.distance(myPos, item)
        if d and d > 0.001 and (not maxDist or d <= maxDist) and (not bestD or d < bestD) then   -- ignore "myself" at distance 0
            best, bestD = item, d
        end
    end
    return best, bestD
end

-- rightVec = the direction your RIGHT key moves you (camera right). Target on that side -> "Right".
-- Straight ahead / behind (no clear side) returns nil so the caller picks its own default.
function M.sideToward(myPos, rightVec, targetPos)
    if not (valid(myPos) and valid(rightVec) and valid(targetPos)) then return nil end
    local rx, rz = rightVec.x, rightVec.z                       -- movement is horizontal: ignore height
    local rlen = math.sqrt(rx * rx + rz * rz)
    if rlen < 1e-6 then return nil end
    local dx, dz = targetPos.x - myPos.x, targetPos.z - myPos.z
    local dlen = math.sqrt(dx * dx + dz * dz)
    if dlen < 1e-6 then return nil end
    local side = (dx * rx + dz * rz) / (dlen * rlen)             -- cosine between "to target" and "right"
    if math.abs(side) < 0.05 then return nil end                  -- within ~3 degrees of straight ahead/behind
    return side > 0 and "Right" or "Left"
end

-- is `from` (at fromPos, looking along lookVec) pointing at `toPos`, within +-halfAngleDeg?
function M.facing(fromPos, lookVec, toPos, halfAngleDeg)
    if not (valid(fromPos) and valid(lookVec) and valid(toPos) and num(halfAngleDeg)) then return false end
    local lx, lz = lookVec.x, lookVec.z
    local llen = math.sqrt(lx * lx + lz * lz)
    local dx, dz = toPos.x - fromPos.x, toPos.z - fromPos.z
    local dlen = math.sqrt(dx * dx + dz * dz)
    if llen < 1e-6 or dlen < 1e-6 then return false end
    local cosAngle = (lx * dx + lz * dz) / (llen * dlen)
    return cosAngle >= math.cos(math.rad(math.min(math.max(halfAngleDeg, 0), 180)))
end

-- Block only attacks that can actually be blocked: the attacker is within range, is aimed at me, and is in
-- FRONT of me (blocking covers a 180 degree arc in front; hits from behind always connect, so don't bother).
function M.shouldBlock(myPos, myLook, attackerPos, attackerLook, range, aimHalfAngleDeg)
    local d = M.distance(myPos, attackerPos)
    if not d or not num(range) or d > range then return false end
    if not M.facing(attackerPos, attackerLook, myPos, aimHalfAngleDeg) then return false end   -- not aimed at me
    return M.facing(myPos, myLook, attackerPos, 90)                                             -- in front of me
end

-- A smarter version of shouldBlock for the live game. It looks ahead because an attacker is usually still running in when the
-- swing starts and, in TSB, M1s snap toward their target, so "where is he looking right now" is a poor test on its own.
--   o = {mp, ml, mv, tp, tl, tv, range, aim, hitIn, close}   (positions / looks / velocities are {x=,y=,z=}; mv / tv / hitIn / close optional)
--   range  reach in studs; aim  half-angle (deg) of the cone he must be aimed at me; hitIn  seconds until the hit (default 0.2);
--   close  inside this many studs the aim test is skipped (default 4)
-- returns "block", or why not: "far" | "unaimed" | "behind" | "unknown"
function M.assess(o)
    if type(o) ~= "table" then return "unknown" end
    local d = M.distance(o.mp, o.tp)
    if not d or not num(o.range) or not valid(o.ml) or not valid(o.tl) then return "unknown" end
    local hitIn = num(o.hitIn) and math.min(math.max(o.hitIn, 0), 1) or 0.2
    local predMine, predTheirs = o.mp, o.tp
    if valid(o.tv) then predTheirs = {x = o.tp.x + o.tv.x * hitIn, y = o.tp.y, z = o.tp.z + o.tv.z * hitIn} end
    if valid(o.mv) then predMine = {x = o.mp.x + o.mv.x * hitIn, y = o.mp.y, z = o.mp.z + o.mv.z * hitIn} end
    local pd = M.distance(predMine, predTheirs) or d
    if math.min(d, pd) > o.range then return "far" end
    local close = num(o.close) and o.close or 4
    local aimed = d <= close or M.facing(o.tp, o.tl, o.mp, o.aim) or M.facing(o.tp, o.tl, predMine, o.aim)
    if not aimed and valid(o.tv) then                                  -- running at me counts as aimed at me
        local sp = math.sqrt(o.tv.x * o.tv.x + o.tv.z * o.tv.z)
        local dx, dz = o.mp.x - o.tp.x, o.mp.z - o.tp.z
        local dl = math.sqrt(dx * dx + dz * dz)
        if sp >= 8 and dl > 1e-6 and (o.tv.x * dx + o.tv.z * dz) / (sp * dl) >= 0.7 then aimed = true end
    end
    if not aimed then return "unaimed" end
    if not M.facing(o.mp, o.ml, o.tp, 90) then return "behind" end             -- where he IS (a runner that will pass through me is no help)
    return "block"
end

-- Going round a player to reach his back. How far round am I already, and which way along the circle is next?
--   returns {angle = 0..180 (0 = right in front of him, 180 = exactly behind), behind = angle >= 105, dx, dz = unit direction of the
--            next dash (along the circle, pulled in when far away), radius}
--   prefer ("Left" | "Right" | nil) + camRight only decide which way to start when I am exactly in front of him.
function M.orbitStep(myPos, theirPos, theirLook, camRight)
    if not (valid(myPos) and valid(theirPos) and valid(theirLook)) then return nil end
    local vx, vz = myPos.x - theirPos.x, myPos.z - theirPos.z
    local r = math.sqrt(vx * vx + vz * vz)
    local ll = math.sqrt(theirLook.x * theirLook.x + theirLook.z * theirLook.z)
    if r < 1e-6 or ll < 1e-6 then return nil end
    vx, vz = vx / r, vz / r
    local lx, lz = theirLook.x / ll, theirLook.z / ll
    local function angleOf(x, z)
        local l = math.sqrt(x * x + z * z)
        local c = math.min(math.max((x * lx + z * lz) / l, -1), 1)
        return math.deg(math.acos(c))
    end
    local angle = angleOf(vx, vz)
    -- the two tangents; keep the one that turns me further from his front
    local t1x, t1z, t2x, t2z = -vz, vx, vz, -vx
    local a1, a2 = angleOf(vx + 0.15 * t1x, vz + 0.15 * t1z), angleOf(vx + 0.15 * t2x, vz + 0.15 * t2z)
    local tx, tz
    if math.abs(a1 - a2) < 1e-6 then                                   -- exactly in front / behind: no preferred way round
        tx, tz = t1x, t1z
        if valid(camRight) and (t2x * camRight.x + t2z * camRight.z) > (t1x * camRight.x + t1z * camRight.z) then tx, tz = t2x, t2z end
    elseif a1 > a2 then tx, tz = t1x, t1z else tx, tz = t2x, t2z end
    local px, pz = tx, tz
    if r > 8 then px, pz = tx - vx * 0.8, tz - vz * 0.8                 -- far away: close in while going round
    elseif r < 3 then px, pz = tx + vx * 0.3, tz + vz * 0.3 end         -- very close: do not run into him
    local pl = math.sqrt(px * px + pz * pz)
    return {angle = angle, behind = angle >= M.BEHIND_ANGLE, dx = px / pl, dz = pz / pl, radius = r}
end

-- Which SIDE dash key (A or D, the only keys a side dash uses) goes furthest toward the world direction (dx, dz), given the camera's
-- right vector (movement keys are camera relative). Returns the key and how sideways that direction is (-1 .. 1; near 0 means a
-- side dash is a poor way to go there, e.g. the camera is turned away from him).
function M.sideKey(dx, dz, camRight)
    if not (num(dx) and num(dz) and valid(camRight)) then return nil end
    local rl = math.sqrt(camRight.x * camRight.x + camRight.z * camRight.z)
    local dl = math.sqrt(dx * dx + dz * dz)
    if rl < 1e-6 or dl < 1e-6 then return nil end
    local lateral = (dx * camRight.x + dz * camRight.z) / (dl * rl)
    return lateral >= 0 and "D" or "A", lateral
end

-- Is the other player closing in fast enough that a punch is about to follow? Positions / his velocity are {x=,y=,z=} (horizontal only).
--   opts = {range = studs he must be within (default 12), speed = closing speed needed in studs/s (default 9), reach = striking distance (default 4.5)}
-- returns nil (no) or the seconds until he is within striking distance (0 when he already is)
function M.rushing(mp, tp, tv, opts)
    if not (valid(mp) and valid(tp) and valid(tv)) then return nil end
    opts = type(opts) == "table" and opts or {}
    local range, need, reach = opts.range or 12, opts.speed or 9, opts.reach or 4.5
    local dx, dz = mp.x - tp.x, mp.z - tp.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 1e-6 or d > range then return nil end
    local closing = (tv.x * dx + tv.z * dz) / d                    -- his velocity along the line to me: positive = coming at me
    if closing < need then return nil end
    return math.max(d - reach, 0) / closing
end

return M

end)()
local BlockState = (function()


local M = {}

function M.new(cfg)
    cfg = cfg or {}
    local self = {holding = false, pressAt = nil, pendingRelease = nil, releaseAt = nil, holdStart = nil, pausedUntil = -math.huge}

    local function grace() return cfg.grace or 0.15 end
    local function maxHold() return math.max(cfg.maxHold or 1.0, cfg.minHold or 0.12) end
    local function minHold() return cfg.minHold or 0.12 end

    function self:threat(now, delay, duration, graceOverride)
        if type(now) ~= "number" then return end
        delay = math.max(tonumber(delay) or 0, 0)
        duration = math.max(tonumber(duration) or 0, 0)
        if now < self.pausedUntil then
            -- you just punched, so the game will not let you block before the lockout ends. A hit that is over by then is
            -- lost anyway; one that lands after it is still blocked - the press just waits for the lockout.
            local attackEnds = now + delay + duration
            if attackEnds <= self.pausedUntil then return end
            delay = math.max(delay, self.pausedUntil - now)
            duration = math.max(attackEnds - (now + delay), 0.1)           -- the attack still ends when it ends
        end
        local hitEnd = now + delay + duration + (type(graceOverride) == "number" and math.max(graceOverride, 0) or grace())
        if self.holding then
            -- keep blocking through the next hit, but never longer than maxHold from the start of this block
            self.releaseAt = math.min(math.max(self.releaseAt, hitEnd), self.holdStart + maxHold())
        else
            local at = now + delay
            if not self.pressAt or at < self.pressAt then self.pressAt = at end        -- earliest attack decides the press
            self.pendingRelease = math.max(self.pendingRelease or 0, hitEnd)
        end
    end

    function self:punch(now)
        self.pausedUntil = now + (cfg.punchPause or 0.4)
        self.pressAt, self.pendingRelease = nil, nil
        if self.holding then
            self.holding, self.releaseAt = false, nil
            return "release"
        end
    end

    function self:tick(now)
        if self.holding then
            if now >= self.releaseAt then
                self.holding, self.releaseAt = false, nil
                return "release"
            end
        elseif self.pressAt and now >= self.pressAt then
            local release = self.pendingRelease or 0
            self.pressAt, self.pendingRelease = nil, nil
            if now < self.pausedUntil then return nil end
            self.holding, self.holdStart = true, now
            self.releaseAt = math.min(math.max(release, now + minHold()), now + maxHold())
            return "press"
        end
    end

    function self:reset()
        local was = self.holding
        self.holding, self.pressAt, self.pendingRelease, self.releaseAt = false, nil, nil, nil
        if was then return "release" end
    end

    return self
end

return M

end)()
local BlockPredict = (function()


local M = {}

local MAX_OFFSET = 1.3          -- a hit later than this after the swing started is not attributed to it
local MIN_OFFSET = 0.03

local function validId(id) return type(id) == "string" and id ~= "" and #id <= 120 and not id:find("%c") end
local function num(v, lo, hi, default)
    if type(v) ~= "number" or v ~= v then return default end
    return math.min(math.max(v, lo), hi)
end

function M.new(opts)
    opts = opts or {}
    local alpha = opts.alpha or 0.3
    local minSamples = opts.minSamples or 2
    local pierceNeeded = opts.pierceNeeded or 2
    local self = {anims = {}, trans = {}, last = {}, pending = {}, hits = 0}

    local function entry(id)
        local a = self.anims[id]
        if not a then a = {n = 0, offset = 0, spread = 0, length = nil, pierce = 0}; self.anims[id] = a end
        return a
    end

    function self:swing(key, id, now, length)
        if not validId(id) or type(now) ~= "number" then return end
        local prev = self.last[key]
        if prev and now - prev.t >= 0.05 and now - prev.t <= 1.2 then            -- same enemy, within one chain
            local row = self.trans[prev.id]
            if not row then row = {}; self.trans[prev.id] = row end
            local e = row[id]
            if not e then e = {n = 0, dt = now - prev.t}; row[id] = e end
            e.n = e.n + 1
            e.dt = e.dt + alpha * ((now - prev.t) - e.dt)
        end
        self.last[key] = {id = id, t = now}
        local a = entry(id)
        if type(length) == "number" and length > 0 and length < 10 then a.length = length end
        local keep = {}                                                           -- remember swings from the last 1.5 s
        for _, s in ipairs(self.pending) do if now - s.t <= 1.5 then keep[#keep + 1] = s end end
        keep[#keep + 1] = {id = id, t = now, key = key}
        self.pending = keep
    end

    -- you lost health at `now`. Pick the swing it most plausibly belongs to and learn its hit offset.
    function self:damage(now)
        if type(now) ~= "number" then return nil end
        local best, bestScore
        for i, s in ipairs(self.pending) do
            local dt = now - s.t
            if dt >= MIN_OFFSET and dt <= MAX_OFFSET then
                local known = self.anims[s.id]
                -- a swing whose offset we already know competes by how well it fits; an unknown one prefers the newest
                local score
                if known and known.n >= minSamples then score = math.abs(dt - known.offset) else score = dt + 0.0001 end
                if not bestScore or score < bestScore then best, bestScore = i, score end
            end
        end
        if not best then return nil end
        local s = table.remove(self.pending, best)
        local dt = now - s.t
        local a = entry(s.id)
        if a.n >= 3 and math.abs(dt - a.offset) > math.max(0.25, 3 * a.spread) then return nil end   -- an outlier (ult, poison...)
        if a.n == 0 then
            a.offset, a.spread = dt, 0
        else
            a.spread = a.spread + alpha * (math.abs(dt - a.offset) - a.spread)
            a.offset = a.offset + alpha * (dt - a.offset)
        end
        a.n = a.n + 1
        self.hits = self.hits + 1
        return s.id, a.offset
    end

    function self:offset(id)
        local a = self.anims[id]
        if a and a.n >= minSamples then return a.offset, a.spread, a.n end
    end

    function self:pierced(id)
        if not validId(id) then return 0 end
        local a = entry(id)
        a.pierce = math.min(a.pierce + 1, 50)
        return a.pierce
    end

    function self:isPierce(id)
        local a = self.anims[id]
        return a ~= nil and a.pierce >= pierceNeeded
    end

    function self:length(id)
        local a = self.anims[id]
        return a and a.length or nil
    end

    -- the animation that usually follows `id` (seen at least twice), and the usual gap between the two starts
    function self:next(id)
        local row = self.trans[id]
        if not row then return nil end
        local bestId, best
        for nid, e in pairs(row) do
            if e.n >= 2 and (not best or e.n > best.n or (e.n == best.n and nid < bestId)) then bestId, best = nid, e end
        end
        if bestId then return bestId, best.dt, best.n end
    end

    function self:stats()
        local learned, piercing = 0, 0
        for _, a in pairs(self.anims) do
            if a.n >= minSamples then learned = learned + 1 end
            if a.pierce >= pierceNeeded then piercing = piercing + 1 end
        end
        return learned, self.hits, piercing
    end

    function self:forget()
        self.anims, self.trans, self.last, self.pending, self.hits = {}, {}, {}, {}, 0
    end

    -- keep the 120 best-sampled animations; saved as plain numbers
    function self:export()
        local list = {}
        for id, a in pairs(self.anims) do if a.n > 0 or a.pierce > 0 then list[#list + 1] = {id = id, a = a} end end
        table.sort(list, function(x, y) if x.a.n ~= y.a.n then return x.a.n > y.a.n end return x.id < y.id end)
        local out = {}
        for i = 1, math.min(#list, 120) do
            local a = list[i].a
            out[list[i].id] = {n = a.n, offset = a.offset, spread = a.spread, length = a.length, pierce = a.pierce}
        end
        return out
    end

    function self:import(saved)
        if type(saved) ~= "table" then return end
        local count = 0
        for id, a in pairs(saved) do
            if count >= 120 then break end
            if validId(id) and type(a) == "table" then
                local e = entry(id)
                e.n = math.floor(num(a.n, 0, 500, 0))
                e.offset = num(a.offset, MIN_OFFSET, MAX_OFFSET, 0.2)
                e.spread = num(a.spread, 0, 1, 0)
                e.length = type(a.length) == "number" and num(a.length, 0.05, 10, 1) or nil
                e.pierce = math.floor(num(a.pierce, 0, 50, 0))
                count = count + 1
            end
        end
    end

    return self
end

return M

end)()
local BlockInfo = (function()


local M = {}

-- {name, kind, who, confidence}
M.entries = {
    -- universal
    {"Downslam", "unblockable", "Universal", "medium"},               -- aerial M1 finisher bypasses block
    {"Ragdoll Cancel", "unblockable", "Universal", "medium"},          -- the direct hit, ~20%, no cooldown, large range
    {"Shove", "unblockable", "Universal", "medium"},                   -- wiki: breaks through block
    {"Uppercut", "unblockable", "Universal", "medium"},                -- wiki: breaks through block
    -- The Strongest Hero (Saitama)
    {"Normal Punch", "unblockable", "The Strongest Hero", "medium"},   -- unblockable on a direct hit / up close
    {"Consecutive Punches", "blockable", "The Strongest Hero", "low"},
    -- Hero Hunter (Garou)
    {"Flowing Water", "guardbreak", "Hero Hunter", "medium"},          -- guardbreak / unblockable advancing rush
    {"Hunter's Grasp", "unblockable", "Hero Hunter", "medium"},        -- armoured grab
    {"Lethal Whirlwind Stream", "disputed", "Hero Hunter", "low"},     -- guides contradict (unblockable AoE vs guardable)
    {"Crushed Rock", "unblockable", "Hero Hunter", "medium"},          -- rampage move, advancing grab
    -- Brutal Demon (Metal Bat): the block-breakers
    {"Homerun", "guardbreak", "Brutal Demon", "medium"},
    {"Grand Slam", "guardbreak", "Brutal Demon", "medium"},
    {"Foul Ball", "guardbreak", "Brutal Demon", "medium"},
    -- Blade Master (Atomic Samurai)
    {"Pinpoint Cut", "blockable", "Blade Master", "medium"},
    -- Destructive Cyborg (Genos): most base moves are blockable, chip damage still gets through
    {"Machine Gun Blows", "chip", "Destructive Cyborg", "low"},
    {"Blitz Shot", "blockable", "Destructive Cyborg", "low"},
    -- Martial Artist (Suiryu)
    {"Vanishing Kick", "unblockable", "Martial Artist", "medium"},
    {"Head First", "unblockable", "Martial Artist", "medium"},         -- damage only reduced by blocking
    {"Grand Fissure", "unblockable", "Martial Artist", "medium"},
    {"Twin Fangs", "unblockable", "Martial Artist", "medium"},
    {"Earth Splitting Strike", "unblockable", "Martial Artist", "medium"},
    {"Last Breath", "unblockable", "Martial Artist", "medium"},
    {"Whirlwind Drop", "chip", "Martial Artist", "medium"},            -- hits through guard without breaking it
    -- event characters
    {"Grave Maker", "unblockable", "Undying Hero", "low"},
    {"Pincer Barrage", "unblockable", "Crab Boss", "low"},
}

local function normalize(s)
    if type(s) ~= "string" then return nil end
    local n = s:lower():gsub("[^a-z]", "")
    return n ~= "" and n or nil
end
M.normalize = normalize

-- longest key first, so "ragdoll cancel" is not shadowed by a shorter one
local index
local function build()
    index = {}
    for _, e in ipairs(M.entries) do
        local key = normalize(e[1])
        if key then index[#index + 1] = {key = key, entry = {name = e[1], kind = e[2], who = e[3], confidence = e[4]}} end
    end
    table.sort(index, function(a, b)
        if #a.key ~= #b.key then return #a.key > #b.key end
        return a.key < b.key
    end)
end

function M.classify(label)
    local n = normalize(label)
    if not n then return nil end
    if not index then build() end
    for _, it in ipairs(index) do
        if n:find(it.key, 1, true) then return it.entry.kind, it.entry end
    end
    return nil
end

-- kinds that make holding F pointless (or worse)
function M.ignoresBlock(kind) return kind == "unblockable" or kind == "guardbreak" end

return M

end)()
local KyotoPlan = (function()


local M = {}

M.DEFAULTS = {m1 = 3, wait = 0.30, whirl = true, twisted = true, side = "Toward"}
local SIDES = {Behind = true, Toward = true, Left = true, Right = true}

-- timings of the fixed parts (seconds)
M.CATCH = 0.12       -- after the side dash: Lethal Whirlwind Stream right away (it is what catches them)
M.WHIRL = 0.12       -- after the Stream: the whirlwind dash "as early as possible"
M.LAND = 0.30        -- after the whirlwind dash: let it land before the first M1
M.STEP_BACK = 0.14   -- the small step back before the twisted dash

function M.clean(src)
    src = type(src) == "table" and src or {}
    local o = {}
    local m1 = tonumber(src.m1)
    o.m1 = (m1 and m1 == m1) and math.min(math.max(math.floor(m1), 1), 3) or M.DEFAULTS.m1
    local wait = tonumber(src.wait)
    o.wait = (wait and wait == wait) and math.min(math.max(wait, 0.05), 1.0) or M.DEFAULTS.wait
    o.whirl = src.whirl == nil and M.DEFAULTS.whirl or src.whirl == true
    o.twisted = src.twisted == nil and M.DEFAULTS.twisted or src.twisted == true
    o.side = SIDES[src.side] and src.side or (src.side == "Closest" and "Toward" or M.DEFAULTS.side)
    return o
end

function M.build(opts)
    local o = M.clean(opts)
    local steps, gaps = {"FLOWING_WATER", "SIDEDASH", "LETHAL_WHIRLWIND_STREAM"}, {}
    gaps[1] = o.wait
    gaps[2] = M.CATCH
    if o.whirl then
        gaps[3] = M.WHIRL
        steps[#steps + 1] = "FRONTDASH"
        gaps[#steps] = M.LAND
    end
    for _ = 1, o.m1 do steps[#steps + 1] = "M1" end                  -- gaps after M1: the normal M1 gap of the Timing tab
    if o.twisted then
        steps[#steps + 1] = "BACKDASH"
        gaps[#steps] = M.STEP_BACK
        steps[#steps + 1] = "FRONTDASH"
    end
    return steps, gaps, o
end

return M

end)()
local BlockSense = (function()


local M = {}

local MAX_FEATURES, MAX_LEN = 12, 100

local function ok(str) return type(str) == "string" and #str > 0 and #str <= MAX_LEN and not str:find("%c") end

-- the set of facts one snapshot is made of
function M.features(snap)
    local out = {}
    if type(snap) ~= "table" then return out end
    if type(snap.ws) == "number" and snap.ws == snap.ws then out["ws:" .. math.floor(snap.ws + 0.5)] = true end
    if type(snap.attrs) == "table" then
        for name, v in pairs(snap.attrs) do
            local t = type(v)
            if type(name) == "string" and (t == "boolean" or t == "number" or t == "string") then
                local f = "attr:" .. name .. "=" .. tostring(v)
                if ok(f) then out[f] = true end
            end
        end
    end
    if type(snap.tracks) == "table" then
        for id in pairs(snap.tracks) do
            local f = "anim:" .. tostring(id)
            if type(id) == "string" and ok(f) then out[f] = true end
        end
    end
    return out
end

function M.new()
    local self = {samples = {}, sig = nil}

    local function recompute()
        local n = #self.samples
        if n < 2 then self.sig = nil return end
        local sig
        for _, set in ipairs(self.samples) do
            if not sig then
                sig = {}
                for f in pairs(set) do sig[f] = true end
            else
                for f in pairs(sig) do if not set[f] then sig[f] = nil end end
            end
        end
        self.sig = next(sig) ~= nil and sig or nil
    end

    -- what appeared while blocking and was not there before; returns true when the signature is ready
    function self:observe(rest, blocking)
        local before, after = M.features(rest), M.features(blocking)
        local news = {}
        for f in pairs(after) do if not before[f] then news[f] = true end end
        if next(news) == nil then return self:ready() end                    -- nothing changed: the press did not take, learn nothing
        self.samples[#self.samples + 1] = news
        while #self.samples > 4 do table.remove(self.samples, 1) end
        recompute()
        if not self.sig and #self.samples >= 2 then self.samples = {news} end   -- the samples disagree: start over from the newest
        return self:ready()
    end

    function self:ready() return self.sig ~= nil end

    function self:isUp(snap)
        if not self.sig then return nil end
        for f in pairs(M.features(snap)) do
            if self.sig[f] then return true end
        end
        return false
    end

    function self:describe()
        if not self.sig then return "not learned yet (" .. #self.samples .. " sample(s))" end
        local list = {}
        for f in pairs(self.sig) do list[#list + 1] = f end
        table.sort(list)
        return table.concat(list, ", ")
    end

    function self:forget() self.samples, self.sig = {}, nil end

    function self:export()
        if not self.sig then return nil end
        local list = {}
        for f in pairs(self.sig) do list[#list + 1] = f end
        table.sort(list)
        while #list > MAX_FEATURES do table.remove(list) end
        return list
    end

    function self:import(list)
        if type(list) ~= "table" then return end
        local sig, n = {}, 0
        for _, f in ipairs(list) do
            if n < MAX_FEATURES and ok(f) and (f:sub(1, 3) == "ws:" or f:sub(1, 5) == "attr:" or f:sub(1, 5) == "anim:") then sig[f] = true; n = n + 1 end
        end
        if next(sig) ~= nil then self.sig, self.samples = sig, {sig, sig} end
    end

    return self
end

return M

end)()
local TechMath = (function()


local M = {}

local sqrt, abs, sin, cos, atan2, pi, exp, max, min, rad = math.sqrt, math.abs, math.sin, math.cos, math.atan2 or math.atan, math.pi, math.exp, math.max, math.min, math.rad

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
function M.valid(p) return type(p) == "table" and num(p.x) and num(p.y) and num(p.z) end
local function v3(x, y, z) return {x = x, y = y, z = z} end
M.v3 = v3
local function add(a, b) return v3(a.x + b.x, a.y + b.y, a.z + b.z) end
local function sub(a, b) return v3(a.x - b.x, a.y - b.y, a.z - b.z) end
local function scale(a, k) return v3(a.x * k, a.y * k, a.z * k) end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function len(a) return sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
local function flat(a) return v3(a.x, 0, a.z) end
local function unit(a, fallback)
    local l = len(a)
    if l < 1e-9 then return fallback or v3(0, 0, -1) end
    return v3(a.x / l, a.y / l, a.z / l)
end
M.add, M.sub, M.scale, M.dot, M.len, M.flat, M.unit = add, sub, scale, dot, len, flat, unit
function M.clamp(v, lo, hi) return max(lo, min(hi, v)) end
function M.lerp(a, b, t) return v3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t) end
function M.dist(a, b) return len(sub(a, b)) end
function M.flatDist(a, b) return len(flat(sub(a, b))) end

local EASE = {
    linear = function(t) return t end,
    quad_out = function(t) return 1 - (1 - t) * (1 - t) end,
    sine_out = function(t) return sin(t * pi / 2) end,
}
function M.ease(kind, t)
    t = max(0, min(1, num(t) and t or 0))
    return (EASE[kind] or EASE.linear)(t)
end

function M.nearest(from, list, radius)
    if not M.valid(from) or type(list) ~= "table" then return nil end
    local best, bestD = nil, radius or math.huge
    for _, e in ipairs(list) do
        if M.valid(e) then
            local d = len(sub(e, from))
            if d <= bestD then best, bestD = e, d end
        end
    end
    if best then return best, bestD end
end

-- direction (flat) from a to b, never zero
local function approach(a, b) return unit(flat(sub(b, a)), v3(0, 0, -1)) end

-- Hook dash. me / target: positions; vel: the target's velocity; look: the target's look vector.
-- o = {range, prediction, reach, side, dir}   dir = freeze the line of approach (flat vector); side: "Left" | "Right" (as seen from me) | "Closest" | "Behind" (the side that ends up behind them)
-- The dash passes the target on one side, `range` studs from where it will be (prediction seconds ahead) and overshoots by `reach`.
function M.hookPoint(me, target, vel, look, o)
    o = o or {}
    local range, prediction, reach = o.range or 2, o.prediction or 0.3, o.reach or 6.5
    local pred = add(target, scale(vel or v3(0, 0, 0), prediction))
    -- o.dir freezes the geometry (the line of approach is the one I started with): the point still follows the target, but it no longer swings round
    -- while I pass it - re-deriving the direction from where I am NOW is unstable close to the target
    local frozen = M.valid(o.dir) and abs(o.dir.x) + abs(o.dir.z) > 1e-6
    local dir = frozen and unit(flat(o.dir)) or approach(me, pred)
    local right = v3(-dir.z, 0, dir.x)                         -- right of my line of approach (Roblox: -Z is forward, +X is right)
    local function endFor(sign)
        local pass = add(pred, scale(right, range * sign))
        local e = add(pass, scale(frozen and dir or approach(me, pass), reach))
        return v3(e.x, me.y, e.z), pass
    end
    local eR, pR = endFor(1)
    local eL, pL = endFor(-1)
    local side = o.side
    if side ~= "Left" and side ~= "Right" then
        if side == "Behind" and M.valid(look) then
            local lf = unit(flat(look), v3(0, 0, -1))
            local sR, sL = dot(flat(sub(eR, pred)), lf), dot(flat(sub(eL, pred)), lf)
            if abs(sR - sL) > 0.25 then side = sR < sL and "Right" or "Left" end
        end
        if side ~= "Left" and side ~= "Right" then side = M.dist(me, eR) <= M.dist(me, eL) and "Right" or "Left" end
    end
    if side == "Right" then return {point = eR, pass = pR, side = "Right", right = right, dir = dir} end
    return {point = eL, pass = pL, side = "Left", right = right, dir = dir}
end

-- flat velocity that covers the way to `point` in `seconds` (the whole duration every frame: it slows down as it arrives)
function M.steer(me, point, seconds, maxSpeed)
    local d = flat(sub(point, me))
    local v = scale(d, 1 / max(seconds or 0.15, 0.01))
    local l = len(v)
    local cap = maxSpeed or 300
    if l > cap then v = scale(v, cap / l) end
    return v
end

-- Supa: o = {under, behind (bool), behindOffset, targetLook, lock (0..100), jitter, random = function() -> 0..1}
-- under = below their feet, looking at a point near them (lock 100 = exactly at them); behind = `behindOffset` studs behind their back (o.targetLook), or
-- on the far side of them from where I came when their look vector is not given
function M.supaPoints(me, target, o)
    o = o or {}
    local rnd = o.random or math.random
    local under = v3(target.x, target.y - (o.under or 3), target.z)
    local jitter = o.jitter or 6
    local rx, rz = rnd() - 0.5, rnd() - 0.5
    local rv = unit(v3(rx, 0, rz), v3(0.1, 0, 0))
    local randomPoint = add(target, scale(rv, jitter))
    local lock = M.clamp((o.lock or 100) / 100, 0, 1)
    local look = M.lerp(randomPoint, target, lock)
    local out = {under = under, look = look}
    if o.behind ~= false then
        local off = o.behindOffset or 5
        local b
        local tl = o.targetLook
        if M.valid(tl) and abs(tl.x) + abs(tl.z) > 1e-6 then
            b = sub(target, scale(unit(flat(tl)), off))                 -- behind THEIR back
        else
            b = add(target, scale(approach(me, target), off))           -- their look is unknown: the far side of them, as seen from where I came
        end
        out.behind = v3(b.x, me.y, b.z)
    end
    return out
end

-- Loop dash, one frame. t01 = 0..1 through the orbit; o = {radius, steps, seed, height, turns}
function M.orbitPose(center, startAngle, t01, o)
    o = o or {}
    local seed = o.seed or 0
    local radius = (o.radius or 6) + sin((t01 * 6 + seed) * 1.7) * 0.35
    local wx = sin((t01 * 12 + seed) * pi * 2) * 0.12
    local wz = cos((t01 * 9 + seed * 0.7) * pi * 2) * 0.09
    local a = startAngle + 2 * pi * (o.turns or 1) * t01
    local y = o.height or center.y
    local pos = v3(center.x + cos(a) * radius + wx, y, center.z + sin(a) * radius + wz)
    local a2 = a + 2 * pi * (o.turns or 1) / (o.steps or 100)
    local nxt = v3(center.x + cos(a2) * radius + wx, y, center.z + sin(a2) * radius + wz)
    return pos, nxt
end

function M.heightAbove(floorY, y, maxHeight)
    local h = min((y or 0) - (floorY or 0), maxHeight or 10)
    if h < 0.5 then h = 2 end
    return h
end

function M.smoothAlpha(smoothness, dt)
    local s = M.clamp(num(smoothness) and smoothness or 300, 1, 10000)
    if s >= 1000 then return 1 end
    return M.clamp(1 - exp(-0.02 * s * (dt or 1 / 60)), 0, 1)
end

-- heading of the direction from -> to, 0 = looking down -Z, positive turns left (the same convention as CFrame.Angles(0, yaw, 0))
function M.yawTo(from, to)
    local d = sub(to, from)
    if abs(d.x) + abs(d.z) < 1e-9 then return nil end
    return atan2(-d.x, -d.z)
end
function M.lerpAngle(a, b, t)
    local d = (b - a + pi) % (2 * pi) - pi
    return a + d * M.clamp(t, 0, 1)
end

-- the box in front of me: forward `range`, `halfWidth` to each side, `halfHeight` up / down; them is led by vel * lead
function M.inFrontBox(me, look, them, vel, o)
    o = o or {}
    if not (M.valid(me) and M.valid(look) and M.valid(them)) then return false end
    local p = add(them, scale(vel or v3(0, 0, 0), o.lead or 0))
    local rel = sub(p, me)
    local f = unit(flat(look), v3(0, 0, -1))
    local fwd = dot(flat(rel), f)
    local side = flat(rel).x * -f.z + flat(rel).z * f.x
    return fwd > 0 and fwd <= (o.range or 13) and abs(side) <= (o.halfWidth or 2) and abs(rel.y) <= (o.halfHeight or 2)
end

function M.flipAngle(percent, lookUp)
    local a = rad(90 * M.clamp(num(percent) and percent or 0, 0, 100) / 100)
    return lookUp == false and -a or a
end

-- the Kitty / Kiba wait after a dash: scales with ping (ms), clamped
function M.pingWait(ms, mult, lo, hi)
    local p = M.clamp(num(ms) and ms or 60, 10, 600)
    return M.clamp(p / 1000 * (mult or 1.3), lo or 0.03, hi or 0.22)
end

-- Dash cooldowns: a forward / back dash and a side dash have their own. cfg = {forward = 4.8, side = 2.0}
-- The server starts the cooldown when it GETS my dash, and my animation arrives `lag` seconds after I sent it (0 when the client plays it at once, about a
-- ping when the server plays it), so the cooldown began `lag` seconds before I saw the animation. margin = extra safety (jitter) added to the cooldown.
function M.dashClock(cfg)
    cfg = cfg or {}
    local self = {readyAt = {}}
    local cd = {forward = cfg.forward or 4.8, side = cfg.side or 2.0}
    function self:seen(kind, now, lag, margin)
        if cd[kind] and num(now) then
            local l = M.clamp(num(lag) and lag or 0, 0, 1)
            self.readyAt[kind] = now - l + cd[kind] + M.clamp(num(margin) and margin or 0, 0, 0.5)
        end
    end
    function self:left(kind, now)
        local r = self.readyAt[kind]
        if not r or not num(now) then return 0 end
        return max(0, r - now)
    end
    function self:ready(kind, now) return self:left(kind, now) <= 0 end
    function self:reset() self.readyAt = {} end
    return self
end

-- ---------------------------------------------------------------------------------------------------------------- latency
-- What I see of another player is old: his state left the server about ping / 2 ago, and Roblox draws other characters a little in the past on top of that
-- (interpMs, about 80-100 ms). A command I send reaches the server another ping / 2 later, so for an action that depends on where HE is, he has moved by
-- about (ping / 2 + interp) since the frame I looked at (my own movement is sent too, which is why this is a half ping and not a whole one).
function M.leadSeconds(pingMs, interpMs, strength)
    local p = M.clamp(num(pingMs) and pingMs or 60, 0, 1500)
    local i = M.clamp(num(interpMs) and interpMs or 80, 0, 400)
    local k = M.clamp(num(strength) and strength or 1, 0, 2)
    return M.clamp((p / 2 + i) / 1000 * k, 0, 0.6)
end

-- A number somebody tuned by hand at `refPingMs` (their own connection), scaled so it keeps working at the current ping:
-- the lead is (ping / 2 + interp), so the number grows and shrinks with it. strength 0 = leave it alone, 1 = fully scaled.
function M.scaleByPing(base, pingMs, interpMs, strength, refPingMs)
    if not num(base) then return base end
    local ref = M.leadSeconds(refPingMs or 60, interpMs, 1)
    if ref <= 1e-6 then return base end
    local now = M.leadSeconds(pingMs, interpMs, 1)
    local k = M.clamp(num(strength) and strength or 1, 0, 2)
    return base * M.clamp(1 + (now / ref - 1) * k, 0.3, 3)
end

-- A wait that starts at one of MY animations. If that animation reaches me `lag` seconds after I pressed the button (the server plays it and sends it back), the
-- action that was meant to happen `base` seconds after the press has to start `lag` earlier than `base` after the animation. Never shortened by more than
-- maxCut of the wait (default 60 %), never below 0; strength scales the shift (0 = off).
function M.shiftWait(base, lagSec, strength, o)
    if not num(base) then return base end
    o = o or {}
    local shift = M.clamp(num(lagSec) and lagSec or 0, 0, 1) * M.clamp(num(strength) and strength or 1, 0, 2)
    shift = min(shift, base * (o.maxCut or 0.6))
    return max(0, base - shift)
end

function M.predict(pos, vel, seconds)
    if not (M.valid(pos) and M.valid(vel)) then return pos end
    return add(pos, scale(vel, num(seconds) and seconds or 0))
end

-- How late do my own animations arrive after my input? Every time I send a dash (the lab sends it, or I press Q myself) :sent("dash", t); when a dash
-- animation shows up :seen("dash", t) pairs it with the newest unmatched send of that kind in the last `window` seconds (default 1.0) and records the gap.
-- value() = the median of the last `cap` gaps (default 9), nil until there are `need` (default 3). Pairs that are too slow or negative are ignored.
function M.lagLearner(o)
    o = o or {}
    local self = {pending = {}, gaps = {}}
    local window, cap, need = o.window or 1.0, o.cap or 9, o.need or 3
    function self:sent(kind, t)
        if not num(t) then return end
        local list = self.pending[kind]
        if not list then list = {}; self.pending[kind] = list end
        list[#list + 1] = t
        while #list > 4 do table.remove(list, 1) end
    end
    function self:seen(kind, t)
        local list = self.pending[kind]
        if not (list and num(t)) then return nil end
        for i = #list, 1, -1 do
            local gap = t - list[i]
            if gap >= 0 and gap <= window then
                for j = #list, i, -1 do table.remove(list, j) end      -- this send and everything after it is used up
                self.gaps[#self.gaps + 1] = gap
                while #self.gaps > cap do table.remove(self.gaps, 1) end
                return gap
            end
        end
        return nil
    end
    function self:count() return #self.gaps end
    function self:value()
        local n = #self.gaps
        if n < need then return nil end
        local sorted = {}
        for i, g in ipairs(self.gaps) do sorted[i] = g end
        table.sort(sorted)
        if n % 2 == 1 then return sorted[(n + 1) / 2] end
        return (sorted[n / 2] + sorted[n / 2 + 1]) / 2
    end
    function self:reset() self.pending, self.gaps = {}, {} end
    return self
end

-- ---------------------------------------------------------------------------------------------------------------- targets and safe moves
-- list: entries with x, y, z, dist (from me) and health. o = {camPos, camLook (unit), preferred = an entry of the list}
M.TARGET_MODES = {"Nearest", "Crosshair", "Lowest health", "Hook target first"}
function M.pickTarget(list, mode, o)
    o = o or {}
    if type(list) ~= "table" or #list == 0 then return nil end
    local best, bestKey
    local function consider(e, key)
        if bestKey == nil or key < bestKey - 1e-9 or (math.abs(key - bestKey) <= 1e-9 and e.dist < best.dist) then best, bestKey = e, key end
    end
    if mode == "Hook target first" and o.preferred then
        for _, e in ipairs(list) do if e == o.preferred then return e end end
    end
    for _, e in ipairs(list) do
        if mode == "Crosshair" and M.valid(o.camPos) and M.valid(o.camLook) then
            local d = unit(sub(e, o.camPos))
            consider(e, 1 - dot(d, unit(o.camLook)))                   -- 0 = straight ahead of the camera
        elseif mode == "Lowest health" and num(e.health) then
            consider(e, e.health)
        else
            consider(e, num(e.dist) and e.dist or math.huge)
        end
    end
    return best
end

-- the point `margin` studs before `hit` on the way from `from` to `to` (never behind `from`); `to` itself when there is no hit
function M.stopShort(from, to, hit, margin)
    if not M.valid(hit) then return to end
    local d = sub(hit, from)
    local l = len(d)
    if l < 1e-6 then return v3(from.x, from.y, from.z) end
    local keep = max(0, l - (margin or 2))
    return add(from, scale(d, keep / l))
end

function M.aboveFloor(p, floorY, minAbove)
    if not (M.valid(p) and num(floorY)) then return p end
    return v3(p.x, max(p.y, floorY + (minAbove or 2.5)), p.z)
end

return M

end)()
local TechData = (function()


local M = {}

M.ANIM = {
    uppercut        = {"10503381238", "13379003796"},          -- the uppercut: Supa / Loop Dash / Kiba start from it
    forwardDash     = {"10479335397", "13380255751"},          -- the forward dash (also what Dash Flip and Mouse Dash react to)
    sideRight       = {"10480793962"},                          -- side dash to the right
    sideLeft        = {"10480796021"},                          -- side dash to the left
    flowingWater    = {"12273188754"},                          -- Garou's Flowing Water (Kyoto starts from it)
    lethalWhirlwind = {"12296113986"},                          -- Lethal Whirlwind Stream (Lethal Dash / Lethal Dunk start from it)
    twisted         = {"13294471966"},                          -- the move Twisted starts from
    block           = {"10471478869"},                          -- somebody is blocking
    downslamWarning = {"10470389827"},                          -- the telegraph of the unblockable down slam
    surf            = {"12309835105"},                          -- Hunter's surf
    counterDash     = {"10479335397", "13380255751", "134775406437626"},     -- dashes Auto Counter answers
    counterM1       = {"10469493270", "10469630950", "10469639222", "10469643643"},   -- M1 swings Auto Counter answers
    counterMove     = {"12351854556", "15311685628", "78521642007560"},     -- the animations of the counter moves (Counter ESP; your script listed three more that are no valid ids)
    slam            = {"10469639222", "13532604085", "13295919399", "13378751717", "14001963401", "15240176873", "16515448089", "17889471098", "104895379416342"},
    m1 = {"10469493270", "10469630950", "10469639222", "10469643643", "13532562418", "13532600125", "13532604085", "13294471966", "13491635433", "13296577783",
          "13295919399", "13295936866", "13370310513", "13390230973", "13378751717", "13378708199", "14004222985", "13997092940", "14001963401", "14136436157",
          "15259161390", "15240216931", "15240176873", "15162694192", "16515503507", "16515520431", "16515448089", "16552234590", "17889458563", "17889461810",
          "17889471098", "17889290569", "123005629431309", "100059874351664", "104895379416342"},
}

M.TOOLS = {
    lethal = {"Lethal Whirlwind Stream"},
    counters = {"Prey's Peril", "Split Second Counter"},
    grasp = {"Hunter's Grasp", "Hunterzzzzz's Grasp"},
    shove = {"Shove"},
}

-- hotbar slots 1-4 are the four moves (Enum.KeyCode names)
M.HOTBAR = {"One", "Two", "Three", "Four"}

-- named highlight colours for the Awareness techs (0-255)
M.COLORS = {Red = {255, 60, 60}, Orange = {255, 150, 40}, Yellow = {255, 220, 60}, Green = {80, 220, 120}, Cyan = {60, 220, 255}, Blue = {70, 130, 255},
            Purple = {170, 100, 255}, White = {240, 240, 240}}
M.COLOR_NAMES = {"Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "White"}

-- dash cooldowns in seconds (from the script: forward 4.8; the side dash figure is the community number and unverified)
M.DASH_COOLDOWN = {forward = 4.8, side = 2.0}

function M.set(list)
    local out = {}
    for _, id in ipairs(list or {}) do out[tostring(id)] = true end
    return out
end

function M.idOf(animationId)
    if type(animationId) ~= "string" then return nil end
    return animationId:match("%d+")
end

local DASH = {}
for _, id in ipairs(M.ANIM.forwardDash) do DASH[id] = "forward" end
for _, id in ipairs(M.ANIM.sideRight) do DASH[id] = "side" end
for _, id in ipairs(M.ANIM.sideLeft) do DASH[id] = "side" end
function M.dashKind(id) return DASH[id] end

-- the Communicate remote (a RemoteEvent inside your character). K = Enum.KeyCode
function M.dashArgs(K, dir) return {Dash = K[dir], Key = K.Q, Goal = "KeyPress"} end
function M.clickArgs(down) return {Mobile = true, Goal = down and "LeftClick" or "LeftClickRelease"} end
function M.blockArgs(K, down) return {Goal = down and "KeyPress" or "KeyRelease", Key = K.F} end
function M.moveArgs(tool) return {Tool = tool, Goal = "Console Move"} end

local function letters(s) return (tostring(s or ""):lower():gsub("[^%a]", "")) end
function M.toolMatches(name, wanted) return letters(name) ~= "" and letters(name) == letters(wanted) end

return M

end)()
local TechOptions = (function()


local M = {}

local function isnum(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

local function cleanOne(def, v)
    local kind = def.kind or "number"
    if kind == "bool" then
        if type(v) == "boolean" then return v end
        return def.default == true
    elseif kind == "choice" then
        for _, c in ipairs(def.choices or {}) do if v == c then return v end end
        return def.default
    elseif kind == "key" then                                       -- a Roblox KeyCode name: "R", "Four", "LeftShift", "F5" (the engine looks it up safely)
        if type(v) == "string" and #v <= 16 and v:match("^%a[%w]*$") then return #v == 1 and v:upper() or v end
        return def.default
    elseif kind == "string" then
        if type(v) == "string" and #v <= 60 and not v:find("%c") then return v end
        return def.default or ""
    end
    if not isnum(v) then return def.default end
    local lo, hi = def.min or -math.huge, def.max or math.huge
    v = math.max(lo, math.min(hi, v))
    local step = def.step
    if isnum(step) and step > 0 then
        v = math.floor((v - (isnum(def.min) and def.min or 0)) / step + 0.5) * step + (isnum(def.min) and def.min or 0)
        v = math.max(lo, math.min(hi, v))
        v = tonumber(string.format("%.6g", v))
    end
    return v
end

function M.valid(def, v)
    local kind = def.kind or "number"
    if kind == "bool" then return type(v) == "boolean" end
    if kind == "choice" then
        for _, c in ipairs(def.choices or {}) do if v == c then return true end end
        return false
    end
    if kind == "string" then return type(v) == "string" and #v <= 60 and not v:find("%c") end
    if kind == "key" then return type(v) == "string" and #v <= 16 and v:match("^%a[%w]*$") ~= nil end
    return isnum(v)
end

function M.defaults(defs)
    local out = {}
    for _, d in ipairs(defs or {}) do out[d.key] = d.default end
    return out
end

function M.clean(defs, saved)
    local out = {}
    saved = type(saved) == "table" and saved or {}
    for _, d in ipairs(defs or {}) do
        local v = saved[d.key]
        if v == nil then out[d.key] = d.default else out[d.key] = cleanOne(d, v) end
    end
    return out
end

function M.isDefault(defs, o)
    o = o or {}
    for _, d in ipairs(defs or {}) do
        if o[d.key] ~= nil and o[d.key] ~= d.default then return false end
    end
    return true
end

function M.diff(defs, o)
    local out = {}
    o = o or {}
    for _, d in ipairs(defs or {}) do
        if o[d.key] ~= nil and o[d.key] ~= d.default then out[d.key] = o[d.key] end
    end
    return out
end

return M

end)()
local TechLab = (function()


local M = {}

local atan2 = math.atan2 or math.atan

local function N(key, label, min, max, step, default, tip) return {key = key, label = label, kind = "number", min = min, max = max, step = step, default = default, tip = tip} end
local function B(key, label, default, tip) return {key = key, label = label, kind = "bool", default = default, tip = tip} end
local function C(key, label, choices, default, tip) return {key = key, label = label, kind = "choice", choices = choices, default = default, tip = tip} end
local KEYS = {"V", "C", "X", "Z", "B", "G", "H", "J", "K", "L", "R", "T"}          -- what a plain dropdown offers; the WindUI hub lets you bind any key
local function K(key, label, default, tip) return {key = key, label = label, kind = "key", default = default, tip = tip, choices = KEYS} end
local function S(key, label, default, tip) return {key = key, label = label, kind = "string", default = default, tip = tip} end

local TD_COLORS = {"Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "White"}      -- = TechData.COLOR_NAMES (a test keeps them equal)

----------------------------------------------------------------------------------------------------------------- the tech catalogue (definitions only)
-- group, title, desc, when = text shown as "starts: ...", needsDash = "forward" | "side" | nil, ids = trigger animation list name in TechData.ANIM (or nil)
local DEFS = {
    {id = "supa", group = "Dash techs", title = "Supa Tech", needsDash = "forward", ids = "uppercut", when = "after your uppercut",
     desc = "Dash in on them: after your uppercut it dashes, snaps under them, finishes behind them and dashes again.",
     opts = {N("delay", "Delay after the uppercut (ms)", 0, 600, 5, 320), N("speed", "Dash-in speed (x)", 0.5, 2.5, 0.1, 1), N("radius", "Search radius (studs)", 10, 100, 5, 50),
             N("under", "Depth under them (studs)", 0, 8, 0.5, 3), N("lock", "Look-at lock (%)", 0, 100, 5, 100), N("jitter", "Random look offset (studs)", 0, 12, 1, 6),
             B("behind", "Finish behind them (teleport)", true, "Ends a few studs behind their back and dashes again."), N("behindOffset", "Finish distance (studs)", 1, 12, 0.5, 5),
             N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1)}},
    {id = "hook", group = "Dash techs", title = "Hook Dash", needsDash = "side", manual = true, when = "V = pick a target, C = go (phone: double tap them, then the button)",
     desc = "A side dash that passes the target on its side and overshoots, then throws an M1 and holds your camera on them. Pick the target with V (the player nearest your cursor), go with C.",
     opts = {N("maxDist", "Max distance (studs)", 10, 80, 1, 35), N("range", "Pass range (studs)", 0, 8, 0.5, 2), N("prediction", "Prediction (s)", 0, 1, 0.05, 0.3),
             N("reach", "Overshoot (studs)", 0, 15, 0.5, 6.5), N("duration", "Dash time (s)", 0.05, 0.4, 0.01, 0.15), N("m1Delay", "M1 after (s)", 0, 0.4, 0.01, 0.11),
             C("side", "Pass them on", {"Closest", "Behind them", "Left", "Right"}, "Closest"), C("face", "Body while dashing", {"Side-on", "Face target"}, "Side-on"),
             N("smooth", "Turn smoothness", 0.05, 1, 0.05, 0.4), B("m1After", "M1 at the end", true), N("aimAfter", "Aim lock after (s)", 0, 1, 0.05, 0.5),
             N("maxY", "Ignore above height (0 = off)", 0, 1000, 1, 442), B("highlight", "Highlight the target", true), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1),
             K("selectKey", "Select key", "V"), K("goKey", "Go key", "C")}},
    {id = "loop", group = "Dash techs", title = "Loop Dash", needsDash = "forward", ids = "uppercut", when = "after your uppercut",
     desc = "A loop round the target while dashing, then you settle above them.",
     opts = {N("delay", "Delay (ms)", 0, 500, 5, 160), N("radius", "Loop radius (studs)", 2, 10, 0.5, 6), N("targetRadius", "Target within (studs)", 5, 40, 1, 15),
             N("maxHeight", "Max height (studs)", 2, 20, 1, 10), N("orbitTime", "Loop time (s)", 0.2, 1, 0.05, 0.5), N("dashEvery", "Dash every (ms)", 20, 300, 10, 80),
             N("settle", "Settle time (ms)", 0, 500, 10, 120), N("hold", "Settle hold (ms)", 100, 1500, 50, 600), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1)}},
    {id = "loop2", group = "Dash techs", title = "Loop Dash 2", needsDash = "forward", ids = "uppercut", template = "jumpLock", when = "after your uppercut",
     desc = "Better loop dash (also for oreo tech): jump, dash, then lock your body on the target. Pauses while someone is blocking.",
     opts = {N("detect", "Delay (s)", 0, 2, 0.05, 0.3), B("jump", "Jump assist", true, "Forces the jump (use it for oreo tech)."), N("jumpPower", "Jump height", 10, 100, 1, 52),
             N("flick", "First flick delay (s)", 0, 1, 0.05, 0.1), N("smooth", "Smoothness", 1, 1000, 1, 600), N("lock", "Lock time (s)", 0, 3, 0.1, 1.5),
             N("radius", "Target within (studs)", 5, 100, 1, 50), B("pauseOnBlock", "Pause while someone blocks", true), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1)}},
    {id = "lethal", group = "Dash techs", title = "Lethal Dash", needsDash = "forward", ids = "lethalWhirlwind", template = "jumpLock", when = "after Lethal Whirlwind Stream",
     desc = "Lethal water into a dash: jump, dash and lock on to the target once the move is over.",
     opts = {N("detect", "Delay (s)", 0, 3, 0.05, 1.6), B("jump", "Jump assist", true), N("jumpPower", "Jump height", 10, 100, 1, 52), N("flick", "First flick delay (s)", 0, 1, 0.05, 0.1),
             N("smooth", "Smoothness", 1, 1000, 1, 300), N("lock", "Lock time (s)", 0, 3, 0.1, 1.6), N("radius", "Target within (studs)", 5, 100, 1, 25),
             B("pauseOnBlock", "Pause while someone blocks", true), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 0)}},
    {id = "kiba", group = "Dash techs", title = "Kiba / Kitty Tech", needsDash = "forward", ids = "uppercut", when = "after your uppercut",
     desc = "After the uppercut: dash and hang on the target head-down (Kiba), or circle them (Kitty Tech, idea by ItzSoph).",
     opts = {C("mode", "Style", {"Hang (Kiba)", "Orbit (Kitty)"}, "Hang (Kiba)"), N("delay", "Delay (ms)", 0, 600, 5, 320), N("radius", "Target within (studs)", 3, 30, 1, 10),
             N("hold", "Hold time (s)", 0.2, 1.5, 0.05, 0.5), N("pitch", "Hang angle (deg)", 0, 120, 5, 85), N("orbitRadius", "Orbit radius", 1, 8, 0.5, 3), N("orbitHeight", "Orbit height", 0, 5, 0.5, 1),
             N("spin", "Orbit lap time (s)", 0.3, 2, 0.1, 0.6), B("pingWait", "Wait for my ping before the dash (Orbit)", true), N("cooldown", "Cooldown (s)", 0, 8, 0.1, 0.5)}},
    {id = "twisted", group = "Dash techs", title = "Twisted (4 M1 into a dash)", needsDash = "forward", ids = "twisted", when = "after the M1 string's last move",
     desc = "A small step back, then a dash at them. 'Instant' also turns you to face them during the dash.",
     opts = {N("wait", "Wait before the step (ms)", 0, 600, 5, 230), N("stepBack", "Step back (studs)", 0, 10, 0.1, 3.4), C("dashKey", "Dash direction", {"W", "A", "S", "D"}, "W"),
             B("instant", "Instant: face them while dashing", false), N("cooldown", "Cooldown (s)", 0, 10, 0.1, 5)}},
    {id = "kyoto", group = "Combos", title = "Auto Kyoto", ids = "flowingWater", when = "after Flowing Water",
     desc = "Flowing water into lethal: casts Lethal Whirlwind Stream for you, then hops sideways.",
     opts = {N("wait", "Wait after Flowing Water (s)", 0.3, 3, 0.05, 1.5), N("startDelay", "Extra delay (ms)", 0, 1000, 10, 0), N("distance", "Hop distance (studs)", 0, 50, 1, 20),
             N("hopTime", "Hop time (ms)", 50, 500, 10, 150), B("hotbar", "Press hotbar 1 and 2 around the hop", true), S("moveName", "Move to cast (empty = Lethal Whirlwind Stream)", ""),
             N("cooldown", "Cooldown (s)", 0, 8, 0.1, 3)}},
    {id = "dunk", group = "Combos", title = "Lethal Dunk", ids = "lethalWhirlwind", when = "after Lethal Whirlwind Stream",
     desc = "Lifts you above them a moment after Lethal Whirlwind Stream.",
     opts = {N("wait", "Wait (s)", 0, 3, 0.05, 1), N("height", "Lift (studs)", 0, 150, 5, 70), N("cooldown", "Cooldown (s)", 0, 8, 0.1, 1)}},
    {id = "surf", group = "Combos", title = "Auto Hunter Surf", ids = "surf", when = "when the surf starts",
     desc = "Carries you forward on the surf.",
     opts = {N("wait", "Wait (s)", 0, 2, 0.05, 0.6), N("distance", "Distance (studs)", 0, 120, 5, 50), N("time", "Time (s)", 0.2, 2, 0.02, 0.78), N("cooldown", "Cooldown (s)", 0, 8, 0.1, 2)}},
    {id = "counter", group = "Defence", title = "Auto Counter", observer = true, watches = true, when = "when somebody dashes / M1s at you",
     desc = "Casts your counter (Prey's Peril / Split Second Counter) when a close player starts a dash or an M1 at you.",
     opts = {N("distance", "Counter distance (studs)", 5, 30, 1, 13), B("facing", "Only when they face me", true), B("answerDashes", "Answer dashes", true), B("answerM1", "Answer M1s", true),
             N("dashDelay", "Delay after a dash (ms)", 0, 300, 5, 0), S("moveName", "Move to cast (empty = automatic)", ""), N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0.6)}},
    {id = "flip", group = "Helpers", title = "Dash Flip", ids = "forwardDash", when = "after your forward dash",
     desc = "Pitches you up a little while you dash (the tech helper's flip).",
     opts = {N("delay", "Delay (ms)", 0, 600, 5, 300), N("hold", "Hold (ms)", 50, 500, 10, 150), N("lock", "Flip (%)", 0, 100, 5, 50), B("lookUp", "Look up (off = look down)", true),
             N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0.5)}},
    {id = "catch", group = "Helpers", title = "M1 Catch", poll = true, when = "while somebody is in front of you",
     desc = "Holds M1 for you when somebody steps into the box in front of you.",
     opts = {N("range", "Range (studs)", 2, 20, 1, 13), N("halfWidth", "Half width (studs)", 1, 6, 0.5, 2), N("hold", "Hold (ms)", 10, 1000, 10, 200), N("lead", "Prediction (%)", 0, 100, 5, 0)}},
    {id = "mousedash", group = "Helpers", title = "Mouse Dash", ids = "forwardDash", when = "after your forward dash",
     desc = "Turns you toward your cursor for a moment after a forward dash, so the dash goes where you point.",
     opts = {N("window", "How long (ms)", 100, 3000, 50, 500)}},
    {id = "sidem1", group = "Helpers", title = "Side M1 (hitbox abuse)", mouse = true, when = "when you click",
     desc = "Swings your body to the side for a moment when you M1, then back. PC only.",
     opts = {N("angle", "Angle (deg)", 0, 180, 5, 45), N("duration", "Duration (ms)", 10, 500, 10, 50), N("delay", "Delay (ms)", 0, 200, 5, 0), B("silent", "Only turn the body (not the camera)", false)}},
    {id = "noendlag", group = "Helpers", title = "No End Lag", key = "Q", when = "Q right after a side dash",
     desc = "Press Q within a moment of a side dash and the forward dash goes out at once.",
     opts = {N("window", "Window (s)", 0.3, 1.5, 0.05, 0.85), C("dashKey", "Dash direction", {"W", "A", "S", "D"}, "W")}},
    {id = "slidem1", group = "Helpers", title = "M1 Slide", ids = "sideDash", when = "after a side dash",
     desc = "Throws an M1 for you right after every side dash.",
     opts = {N("cooldown", "Cooldown (s)", 0.3, 3, 0.1, 1.5)}},
    {id = "downslam", group = "Helpers", title = "True Down Slam", ids = "slam", when = "when your down slam starts",
     desc = "Lifts you when your down slam starts with somebody close, so it lands as the aerial one.",
     opts = {N("radius", "Somebody within (studs)", 5, 40, 1, 15), N("lift", "Lift (studs)", 0, 15, 1, 6), N("liftTime", "Lift time (s)", 0.1, 1, 0.05, 0.35)}},
    {id = "m1reset", group = "Actions", title = "M1 Reset", manual = true, key = "R", when = "key / button",
     desc = "Side step, turn and dash - resets your M1 chain.",
     opts = {N("distance", "Step (studs)", 0, 60, 0.5, 25.5), N("duration", "Step time (s)", 0.1, 0.6, 0.01, 0.22), N("rotation", "Turn (deg)", 0, 180, 5, 65),
             C("dashAfter", "Dash after", {"W", "A", "S", "D", "None"}, "W"), N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0.2), K("key", "Key", "R")}},
    {id = "emotedash", group = "Actions", title = "Emote Dash", manual = true, key = "T", when = "key / button",
     desc = "Turns and throws you sideways in an arc.",
     opts = {N("rotation", "Turn (deg)", 0, 180, 5, 90), N("distance", "Distance", 0, 80, 1, 38), N("height", "Height", 0, 30, 1, 8), N("power", "Power", 20, 200, 5, 95),
             N("duration", "Duration (s)", 0.1, 0.6, 0.01, 0.27), N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0.2), K("key", "Key", "T")}},

    -- ------------------------------------------------------------------------------------- added from the wiki descriptions (community-sourced, steps and windows unverified)
    {id = "backdash", group = "Actions", title = "Backdash Cancel", manual = true, needsDash = "forward", key = "B", when = "key (B) / button",
     desc = "Back dash, then a move right away: the move cancels the back dash. 'Aerial' jumps first so the back dash carries further. The window is short - tune the delay.",
     opts = {N("delay", "Delay before the move (ms)", 0, 400, 5, 90), B("aerial", "Aerial: jump first", false), N("aerialDelay", "Delay after the jump (ms)", 0, 300, 5, 120),
             N("jumpPower", "Jump height", 10, 100, 1, 52), C("slot", "Move (hotbar slot)", {"1", "2", "3", "4"}, "1"), S("moveName", "Move by name (empty = the slot)", ""),
             N("cooldown", "Cooldown (s)", 0, 5, 0.1, 0.8), K("key", "Key", "B")}},
    {id = "microdash", group = "Actions", title = "Micro Dash", manual = true, needsDash = "side", key = "X", when = "key (X) / button",
     desc = "Side dash, then a move at once (an M1 does not cancel the dash, a move does).",
     opts = {C("side", "Side", {"Toward target", "Left", "Right"}, "Toward target"), N("delay", "Delay before the move (ms)", 0, 400, 5, 60), C("slot", "Move (hotbar slot)", {"1", "2", "3", "4"}, "1"),
             S("moveName", "Move by name (empty = the slot)", ""), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 0.8), K("key", "Key", "X")}},
    {id = "shovedash", group = "Actions", title = "Shove Dash", manual = true, needsDash = "forward", key = "Z", when = "key (Z) / button",
     desc = "Shove, an instant M1, a step back and a forward dash (the M1 after the shove should be your 1st-3rd).",
     opts = {S("moveName", "Shove move name", "Shove"), N("m1Delay", "M1 after the shove (ms)", 0, 400, 5, 40), N("stepBack", "Step back (studs)", 0, 10, 0.5, 3), N("dashDelay", "Dash after the M1 (ms)", 0, 500, 5, 120),
             N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1.2), K("key", "Key", "Z")}},
    {id = "uppercutcatch", group = "Combos", title = "Uppercut Catch", ids = "uppercut", when = "after your uppercut",
     desc = "After the uppercut: forward dash and an M1 at the right moment - or, if he falls close to you, just walk into him (hold W) and M1.",
     opts = {N("delay", "Delay after the uppercut (ms)", 0, 900, 5, 450), N("radius", "Target within (studs)", 5, 80, 1, 40), N("holdRange", "Walk instead of dash within (studs)", 0, 20, 0.5, 6),
             N("holdTime", "Walk for (ms)", 50, 800, 10, 300), N("m1Delay", "M1 after the dash / walk (ms)", 0, 500, 5, 120), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1)}},
    {id = "uppercutgrasp", group = "Combos", title = "Uppercut Grasp", ids = "uppercut", when = "after your uppercut",
     desc = "3 M1s, jump, mini uppercut - then Hunter's Grasp is cast for you.",
     opts = {N("delay", "Delay after the uppercut (s)", 0, 2, 0.05, 0.3), N("count", "Casts", 1, 5, 1, 1), N("gap", "Gap between casts (ms)", 50, 600, 10, 150), S("moveName", "Move by name (empty = Hunter's Grasp)", ""),
             N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1)}},
    {id = "lethalgrasp", group = "Combos", title = "Lethal Grasp", ids = "lethalWhirlwind", when = "after Lethal Whirlwind Stream",
     desc = "Right after Lethal Whirlwind Stream: Hunter's Grasp.",
     opts = {N("delay", "Delay after Lethal Whirlwind Stream (s)", 0, 3, 0.05, 0.9), N("count", "Casts", 1, 5, 1, 1), N("gap", "Gap between casts (ms)", 50, 600, 10, 150), S("moveName", "Move by name (empty = Hunter's Grasp)", ""),
             N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1)}},
    {id = "flowinggrasp", group = "Combos", title = "Flowing Grasp", ids = "flowingWater", when = "after Flowing Water",
     desc = "After Flowing Water ends, Hunter's Grasp is cast (spammed a few times). Turn on shift lock yourself.",
     opts = {N("delay", "Delay after Flowing Water (s)", 0, 3, 0.05, 1.4), N("count", "Casts", 1, 5, 1, 3), N("gap", "Gap between casts (ms)", 50, 600, 10, 150), S("moveName", "Move by name (empty = Hunter's Grasp)", ""),
             N("cooldown", "Cooldown (s)", 0, 5, 0.1, 2)}},
    {id = "fastdash", group = "Helpers", title = "Fast Dash", ids = "sideDash", when = "when you side dash",
     desc = "Throws you along the side dash with a burst and cuts the dash animation short. Not compatible with most other techs (only one moving tech runs at a time).",
     opts = {N("hop", "Hop (studs)", 0, 12, 0.5, 5), N("speed", "Burst speed (studs/s)", 20, 300, 5, 250), N("time", "Burst time (s)", 0.05, 0.5, 0.01, 0.25), N("stopAt", "Cut the animation at (s)", 0.05, 0.6, 0.01, 0.22),
             N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0)}},
    {id = "dashclip", group = "Helpers", title = "DashClip", ids = "anyDash", when = "when you dash",
     desc = "Noclip for a moment while you dash (your own character only).",
     opts = {N("duration", "Noclip for (s)", 0.05, 1, 0.01, 0.35), N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0)}},
    {id = "counteresp", group = "Awareness", title = "Counter ESP", observer = true, watches = true, when = "when a player uses a counter",
     desc = "Highlights a player for a few seconds when he starts a counter move, so you know not to hit him.",
     opts = {C("color", "Colour", TD_COLORS, "Cyan"), N("seconds", "Highlight for (s)", 1, 10, 0.5, 3)}},
    {id = "deathcounter", group = "Awareness", title = "Death Counter ESP", observer = true, watches = true, when = "when a player gets a Death Counter",
     desc = "Highlights a player while a Death Counter is on him (it is a child called 'Death Counter' in his character).",
     opts = {C("color", "Colour", TD_COLORS, "Red"), N("seconds", "Highlight for (s)", 1, 30, 1, 12)}},
    {id = "blockwarn", group = "Awareness", title = "Unblockable Warning", observer = true, watches = true, when = "when a player winds up the unblockable down slam",
     desc = "A red arrow above a player while he telegraphs the unblockable down slam: dodge it, do not block it.",
     opts = {N("seconds", "Longest time (s)", 0.5, 5, 0.5, 3)}},
    {id = "blockesp", group = "Awareness", title = "Block ESP", observer = true, watches = true, when = "while a player blocks",
     desc = "Highlights a player for as long as he is blocking.",
     opts = {C("color", "Colour", TD_COLORS, "Yellow"), N("seconds", "Longest time (s)", 1, 15, 1, 6)}},
}
M.DEFS = DEFS

local GROUPS = {"Dash techs", "Combos", "Defence", "Helpers", "Actions", "Awareness"}
M.GROUPS = GROUPS

-- techs that wait on one of my own animations or aim at another player: they get an "Adjust for ping" switch (the latency model below)
local PING_AWARE = {supa = true, hook = true, loop = true, loop2 = true, lethal = true, kiba = true, twisted = true, kyoto = true, dunk = true, surf = true, flip = true,
                    catch = true, noendlag = true, uppercutcatch = true, uppercutgrasp = true, lethalgrasp = true, flowinggrasp = true}

-- what a tech can hand over to when it finished (a "chain"): the manual techs and a plain M1
local NEXT_IDS = {M1 = "m1", ["Backdash Cancel"] = "backdash", ["Micro Dash"] = "microdash", ["Shove Dash"] = "shovedash", ["M1 Reset"] = "m1reset", ["Emote Dash"] = "emotedash",
                  ["Uppercut Catch"] = "uppercutcatch"}
local NEXT_CHOICES = {"None", "M1", "Backdash Cancel", "Micro Dash", "Shove Dash", "M1 Reset", "Emote Dash", "Uppercut Catch"}
M.NEXT_CHOICES = NEXT_CHOICES

-- techs that move or turn my character: only one of them runs at a time (two of them at once would fight over the root part)
local MOVES = {supa = true, hook = true, loop = true, loop2 = true, lethal = true, kiba = true, twisted = true, kyoto = true, dunk = true, surf = true, flip = true,
               mousedash = true, sidem1 = true, downslam = true, m1reset = true, emotedash = true, backdash = true, microdash = true, shovedash = true, uppercutcatch = true,
               fastdash = true}

----------------------------------------------------------------------------------------------------------------- the engine
function M.new(env)
    local Players, RunService, UIS, Workspace, LocalPlayer = env.Players, env.RunService, env.UserInputService, env.Workspace, env.LocalPlayer
    local TM, TD, TO = env.TechMath, env.TechData, env.TechOptions
    local clock = env.clock or os.clock
    local connect = env.connect or function(sig, fn) return sig:Connect(fn) end
    local safe = env.safe or function(fn, ...) local ok, r = pcall(fn, ...) if ok then return r end end
    local log = env.log or function() end

    local lab = {techs = {}, order = {}, byId = {}, alive = true, master = true, input = "Auto", dashGuard = true, releaseBlock = true,
                 dashClock = TM.dashClock(TD.DASH_COOLDOWN), hook = {}, conns = {}, lastOwn = {},
                 -- the latency model: strength scales every ping correction (0 = off), manual = a ping I typed (0 = measure it), interp = how far in the past Roblox draws
                 -- other players, learn = measure how late my own animations arrive, ref = the ping the default numbers were tuned at
                 net = {strength = 1, manual = 0, interp = 80, learn = true, ref = 60}, lagger = TM.lagLearner(),
                 -- who the techs go for, stop teleports at walls / the floor, no techs while knocked down, how long a key press waits for a running tech (ms),
                 -- how long after a tech the target's health is watched for a hit (s)
                 targetMode = "Nearest", skipBlocking = false, safeMoves = true, guardKnocked = true, bufferMs = 250, hitWindow = 0.8}
    local charConns = {}
    local watched = setmetatable({}, {__mode = "k"})              -- enemy model -> its connections
    local animCache = {}
    local ownTracks = setmetatable({}, {__mode = "k"})             -- tracks the Tech Lab played itself: they must not trigger techs or the dash clock
    local blockSet = TD.set(TD.ANIM.block)
    local SIDE_ID = {Right = TD.ANIM.sideRight[1], Left = TD.ANIM.sideLeft[1]}

    local function num(x) return type(x) == "number" and x == x and x or 0 end
    local function vec(p) return TM.v3(num(p.X), num(p.Y), num(p.Z)) end
    local function healthy(hum) local h = hum.Health; return type(h) == "number" and h > 0 end
    -- a signal that may be missing (an unusual character): nothing to listen to, nothing to break
    local function listen(sig, fn)
        if sig == nil then return nil end
        local ok, conn = pcall(connect, sig, fn)
        return ok and conn or nil
    end
    local function V3(p) return Vector3.new(p.x, p.y, p.z) end

    -------------------------------------------------------------------------------------------------------- techs from the catalogue
    for _, d in ipairs(DEFS) do
        local has = {}
        for _, od in ipairs(d.opts) do has[od.key] = true end
        if not (d.watches and d.id ~= "counter") and not d.poll and not has.next then
            d.opts[#d.opts + 1] = C("next", "Then run (a chain)", NEXT_CHOICES, "None", "When this tech finished without aborting, the chosen one runs next")
            d.opts[#d.opts + 1] = N("nextDelay", "...after (ms)", 0, 1500, 10, 0)
        end
        if PING_AWARE[d.id] and not has.ping then
            d.opts[#d.opts + 1] = B("ping", "Adjust for ping", true, "Waits that start at one of my animations start earlier by the lag I measured, and aim at other players is led by their latency.")
        end
        local tech = {id = d.id, group = d.group, title = d.title, desc = d.desc, when = d.when, defs = d.opts, needsDash = d.needsDash, manual = d.manual, template = d.template,
                      observer = d.observer, watches = d.watches, poll = d.poll, mouse = d.mouse, key = d.key, idList = d.ids, moves = MOVES[d.id] == true, enabled = false, token = 0, running = false, cooldownUntil = 0,
                      status = "off", stats = {runs = 0, aborts = 0, errors = 0}, extra = {}, ids = {}}
        tech.opt = TO.defaults(d.opts)
        lab.techs[d.id] = tech
        lab.byId[d.id] = tech
        lab.order[#lab.order + 1] = tech
    end

    local function rebuildIds(tech)
        local set = {}
        if tech.idList == "sideDash" or tech.idList == "anyDash" then
            for _, id in ipairs(TD.ANIM.sideRight) do set[id] = true end
            for _, id in ipairs(TD.ANIM.sideLeft) do set[id] = true end
            if tech.idList == "anyDash" then for _, id in ipairs(TD.ANIM.forwardDash) do set[id] = true end end
        elseif tech.idList then
            for _, id in ipairs(TD.ANIM[tech.idList] or {}) do set[tostring(id)] = true end
        end
        for id in pairs(tech.extra) do set[id] = true end
        tech.ids = set
    end
    for _, tech in ipairs(lab.order) do rebuildIds(tech) end

    local function setStatus(tech, text)
        tech.baseStatus = text
        tech.status = text .. (tech.hitText and ("   |   " .. tech.hitText) or "")
        if env.onStatus then pcall(env.onStatus, tech) end
    end
    lab.setStatus = setStatus

    -------------------------------------------------------------------------------------------------------- latency
    function lab:pingMs()
        if lab.net.manual > 0 then return lab.net.manual end
        local p = env.pingMs and safe(env.pingMs)
        return type(p) == "number" and p == p and p >= 0 and p or nil
    end
    function lab:jitterMs()
        local j = env.jitterMs and safe(env.jitterMs)
        return type(j) == "number" and j == j and j >= 0 and j or 0
    end
    -- seconds my own animations arrive after my input (0 until it was measured, or when learning is off)
    function lab:lag()
        if not lab.net.learn then return 0 end
        return lab.lagger:value() or 0
    end
    function lab:lead() return TM.leadSeconds(lab:pingMs(), lab.net.interp, lab.net.strength) end
    function lab:netInfo()
        return {ping = lab:pingMs(), jitter = lab:jitterMs(), lag = lab.lagger:value(), samples = lab.lagger:count(), lead = lab:lead(), strength = lab.net.strength}
    end
    local NET_RANGE = {strength = {0, 2}, manual = {0, 1000}, interp = {0, 250}, ref = {10, 300}}
    function lab:setNet(key, value)
        if key == "learn" then
            if type(value) == "boolean" then lab.net.learn = value end
        elseif NET_RANGE[key] and type(value) == "number" and value == value then
            lab.net[key] = math.max(NET_RANGE[key][1], math.min(NET_RANGE[key][2], value))
        end
    end
    local function pingOn(tech) return tech.opt.ping ~= false end

    -------------------------------------------------------------------------------------------------------- the character and the people around me
    local function myParts()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if hum and root then return char, hum, root end
    end
    lab.myParts = myParts

    local function validEnemy(model, char)
        if model == char or not model:IsA("Model") then return nil end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
        if not (hum and root) or not healthy(hum) then return nil end
        local plr = Players:GetPlayerFromCharacter(model)
        if not (plr or model.Name == "Weakest Dummy") then return nil end
        return {model = model, hum = hum, root = root, player = plr, name = plr and plr.Name or model.Name}
    end
    -- everybody I could fight (players and the dummy in Workspace.Live), nearest first when a radius is given
    function lab:enemies(radius)
        local list = {}
        local char, _, myRoot = myParts()
        if not myRoot then return list end
        local live = Workspace:FindFirstChild("Live")
        local pool = live and live:GetChildren() or {}
        if not live then for _, p in ipairs(Players:GetPlayers()) do if p.Character then pool[#pool + 1] = p.Character end end end
        local origin = myRoot.Position
        for _, model in ipairs(pool) do
            local e = validEnemy(model, char)
            if e then
                local p = e.root.Position
                e.x, e.y, e.z = p.X, p.Y, p.Z
                e.dist = (p - origin).Magnitude
                if e.dist <= (radius or math.huge) then list[#list + 1] = e end
            end
        end
        table.sort(list, function(a, b) return a.dist < b.dist end)
        return list
    end
    function lab:nearestEnemy(radius)
        local list = lab:enemies(radius)
        return list[1]
    end
    local function isBlocking(model)
        local hum = model:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        local tracks = animator and safe(function() return animator:GetPlayingAnimationTracks() end) or {}
        for _, tr in ipairs(tracks) do
            local id = TD.idOf(safe(function() return tr.Animation.AnimationId end))
            if id and blockSet[id] then return true end
        end
        return false
    end
    -- the target a tech goes for, by the chosen mode (and without blockers when that is asked for)
    function lab:pickTarget(radius)
        local list = {}
        for _, e in ipairs(lab:enemies(radius)) do
            if not (lab.skipBlocking and isBlocking(e.model)) then
                e.health = e.hum.Health
                list[#list + 1] = e
            end
        end
        local cam = Workspace.CurrentCamera
        local o = {}
        if cam then o.camPos, o.camLook = vec(cam.CFrame.Position), vec(cam.CFrame.LookVector) end
        local hooked = lab.hook.target
        if hooked then for _, e in ipairs(list) do if e.model == hooked.model then o.preferred = e end end end
        return TM.pickTarget(list, lab.targetMode, o)
    end
    function lab:setTargetMode(mode) for _, m in ipairs(TM.TARGET_MODES) do if m == mode then lab.targetMode = mode end end end

    -- am I knocked down / ragdolled / stunned? (states, and the attributes / values games commonly use for it)
    local KNOCKED_STATES = {Ragdoll = true, FallingDown = true, PlatformStanding = true}
    function lab:knocked()
        local char, hum = myParts()
        if not char then return false end
        local state = safe(function() return hum:GetState() end)
        if state and KNOCKED_STATES[state.Name] then return true end
        for _, name in ipairs({"Ragdolled", "Ragdoll", "Stunned"}) do
            if safe(function() return char:GetAttribute(name) end) == true then return true end
        end
        return char:FindFirstChild("Ragdolled") ~= nil
    end

    local function tracksOf(model)
        local hum = model:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if not animator then return {} end
        return safe(function() return animator:GetPlayingAnimationTracks() end) or {}
    end
    local function playingAny(model, set)
        for _, tr in ipairs(tracksOf(model)) do
            local id = TD.idOf(safe(function() return tr.Animation.AnimationId end))
            if id and set[id] then return true end
        end
        return false
    end

    -------------------------------------------------------------------------------------------------------- input: the game's remote first, keys as the fallback
    local function communicate()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("Communicate")
    end
    function lab:fireRemote(args)
        local remote = communicate()
        if not remote then return false end
        return pcall(function() remote:FireServer(args) end)
    end
    local function keyEvent(down, name)
        local vim = env.VirtualInput
        if not (vim and Enum.KeyCode[name]) then return false end
        return pcall(function() vim:SendKeyEvent(down, Enum.KeyCode[name], false, game) end)
    end
    function lab:tapKey(name)
        if not keyEvent(true, name) then return false end
        task.wait(0.03)
        keyEvent(false, name)
        return true
    end
    -- dir = "W" | "A" | "S" | "D" (the dash goes that way, relative to the camera, like holding the key)
    function lab:dash(dir)
        lab.lagger:sent("dash", clock())                              -- (so the animation that answers it tells me how late my animations arrive)
        if lab.input ~= "Keys" and lab:fireRemote(TD.dashArgs(Enum.KeyCode, dir)) then return true end
        if lab.input == "Remote" then return false end
        keyEvent(true, dir)
        keyEvent(true, "Q"); task.wait(0.03); keyEvent(false, "Q")
        task.wait(0.03); keyEvent(false, dir)
        return true
    end
    function lab:m1(hold)
        hold = hold or 0.03
        if lab.input ~= "Keys" and communicate() then
            if lab.releaseBlock then lab:fireRemote(TD.blockArgs(Enum.KeyCode, false)) end
            if lab:fireRemote(TD.clickArgs(true)) then
                task.delay(hold, function() lab:fireRemote(TD.clickArgs(false)) end)
                return true
            end
        end
        if lab.input == "Remote" then return false end
        local vim, cam = env.VirtualInput, Workspace.CurrentCamera
        if not (vim and cam) then return false end
        local mid = cam.ViewportSize / 2
        local ok = pcall(function() vim:SendMouseButtonEvent(mid.X, mid.Y, 0, true, game, 0) end)
        task.delay(hold, function() pcall(function() vim:SendMouseButtonEvent(mid.X, mid.Y, 0, false, game, 0) end) end)
        return ok
    end
    -- cast a move by tool name (the Console Move remote); names = list of acceptable names
    function lab:findTool(names)
        local sources = {LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}
        for _, src in ipairs(sources) do
            if src then
                for _, t in ipairs(src:GetChildren()) do
                    if t:IsA("Tool") then
                        for _, n in ipairs(names) do if TD.toolMatches(t.Name, n) then return t end end
                    end
                end
            end
        end
    end
    function lab:useMove(names)
        local tool = lab:findTool(names)
        if not tool then return false, "you do not have " .. tostring(names[1]) end
        if not lab:fireRemote(TD.moveArgs(tool)) then return false, "no Communicate remote" end
        return true
    end

    -------------------------------------------------------------------------------------------------------- the context every sequence receives
    local function newCtx(tech, token, info)
        local char, hum, root = myParts()
        if not char then return nil end
        local c = {tech = tech, opt = tech.opt, info = info, char = char, hum = hum, root = root, lab = lab}
        local cleanups = {}
        local function alive()
            return lab.alive and tech.token == token and char.Parent ~= nil and healthy(hum) and (info.manual or (lab.master and tech.enabled))
        end
        c.alive = alive
        function c.onFinish(fn) cleanups[#cleanups + 1] = fn end
        function c.instance(inst) cleanups[#cleanups + 1] = function() if inst.Parent then inst:Destroy() end end; return inst end
        function c.conn(conn) cleanups[#cleanups + 1] = function() conn:Disconnect() end; return conn end
        function c.finish()
            for i = #cleanups, 1, -1 do pcall(cleanups[i]) end
            cleanups = {}
        end
        function c.commit()                                           -- from here the run counts: the cooldown starts and the stats go up
            if not c.committed then c.committed = true; tech.stats.runs = tech.stats.runs + 1 end
        end
        function c.abort(text) c.result = text; c.aborted = true; tech.stats.aborts = tech.stats.aborts + 1 end
        function c.say(text) c.result = text end

        function c.wait(sec)
            sec = tonumber(sec) or 0
            local t0 = clock()
            while clock() - t0 < sec do
                if not alive() then return false end
                task.wait()
            end
            return alive()
        end
        -- fn(a) every frame for `seconds`, a = 0..1 (a = 1 on the last call); false when cancelled
        function c.frames(seconds, fn)
            local t0 = clock()
            while true do
                local a = (clock() - t0) / math.max(seconds, 0.001)
                if a >= 1 then fn(1); return alive() end
                if not alive() then return false end
                fn(a)
                task.wait()
            end
        end

        -- the first target a run picks is its focus: its health is watched after the run to see whether the tech landed
        function c.setFocus(entry)
            if entry and not c.focus then c.focus = entry; c.focusHealth = entry.hum.Health end
        end
        function c.target(radius)
            local e = lab:pickTarget(radius)
            c.setFocus(e)
            return e
        end
        function c.dash(dir) return lab:dash(dir) end
        function c.m1(hold) return lab:m1(hold) end
        function c.key(name) return lab:tapKey(name) end
        function c.useMove(names) return lab:useMove(names) end
        function c.enemyBlocking(radius)
            for _, e in ipairs(lab:enemies(radius)) do if playingAny(e.model, blockSet) then return e end end
        end
        function c.dashReady(kind) return lab.dashClock:ready(kind, clock()) end

        -- latency: a wait that starts at one of MY animations starts earlier by the lag measured for them; another player is where he will be by the time my
        -- command reaches the server (his velocity times the lead); a number tuned at the reference ping scales with the ping. All off with "Adjust for ping".
        function c.shift(sec)
            if not (info.anim and pingOn(tech)) then return sec end
            return TM.shiftWait(sec, lab:lag(), lab.net.strength)
        end
        function c.lead() return pingOn(tech) and lab:lead() or 0 end
        function c.predicted(entry)
            return TM.predict(vec(entry.root.Position), vec(entry.root.AssemblyLinearVelocity), c.lead())
        end
        function c.scaled(base)
            if not pingOn(tech) then return base end
            return TM.scaleByPing(base, lab:pingMs(), lab.net.interp, lab.net.strength, lab.net.ref)
        end

        function c.stopAnims()
            local animator = hum:FindFirstChildOfClass("Animator")
            local list = animator and safe(function() return animator:GetPlayingAnimationTracks() end) or {}
            for _, tr in ipairs(list) do pcall(function() tr:Stop() end) end
        end
        function c.play(id, speed)
            local animator = hum:FindFirstChildOfClass("Animator")
            if not animator then return nil end
            local anim = animCache[id]
            if not anim then
                anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://" .. id
                animCache[id] = anim
            end
            local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
            if not (ok and track) then return nil end
            ownTracks[track] = true
            pcall(function() track:Play() end)
            if speed then pcall(function() track:AdjustSpeed(speed) end) end
            return track
        end

        function c.lockRotation()
            if c.rotLocked then return end
            c.rotLocked = true
            local prev = hum.AutoRotate
            hum.AutoRotate = false
            local conn = hum:GetPropertyChangedSignal("AutoRotate"):Connect(function() if hum.AutoRotate then hum.AutoRotate = false end end)
            c.onFinish(function() conn:Disconnect(); if hum.Parent then hum.AutoRotate = prev end end)
        end

        local function place(pos, lookAt)
            if lookAt and (lookAt - pos).Magnitude > 1e-3 then
                root.CFrame = CFrame.lookAt(pos, lookAt)
            else
                root.CFrame = CFrame.new(pos) * (root.CFrame - root.CFrame.Position)
            end
        end
        -- slide the root to `point` ({x,y,z}) in `seconds`, looking at `lookAt` ({x,y,z}) when given; false when cancelled
        function c.moveTo(point, seconds, lookAt, ease)
            local start = root.Position
            local goal = V3(c.safePoint and c.safePoint(point) or point)
            local look = lookAt and V3(lookAt) or nil
            if seconds <= 0.03 then place(goal, look); return alive() end
            return c.frames(seconds, function(a)
                place(start:Lerp(goal, TM.ease(ease or "quad_out", a)), look)
            end)
        end
        -- a velocity that is always removed again: returns {set = function(v3), stop = function()}
        function c.push(v)
            local att = c.instance(Instance.new("Attachment"))
            att.Parent = root
            local lv = c.instance(Instance.new("LinearVelocity"))
            lv.Attachment0 = att
            lv.MaxForce = math.huge
            lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
            lv.RelativeTo = Enum.ActuatorRelativeTo.World
            lv.VectorVelocity = Vector3.new(v.x, v.y, v.z)
            lv.Parent = root
            return {
                set = function(nv) if lv.Parent then lv.VectorVelocity = Vector3.new(nv.x, nv.y, nv.z) end end,
                stop = function() if lv.Parent then lv:Destroy() end; if att.Parent then att:Destroy() end end,
            }
        end
        local function myYaw()
            local look = root.CFrame.LookVector
            return atan2(-look.X, -look.Z)
        end
        -- turn the root toward getPoint() ({x,y,z} or nil) every frame; alpha = how fast (0..1 per frame), or smooth = the 1..1000 slider
        function c.faceLoop(getPoint, seconds, smooth, offsetRad, alphaFixed)
            local t0 = clock()
            local conn
            conn = RunService.RenderStepped:Connect(function(dt)
                if not alive() or clock() - t0 >= seconds then conn:Disconnect(); return end
                local p = getPoint()
                if not p then return end
                local want = TM.yawTo(vec(root.Position), p)
                if not want then return end
                local alpha = alphaFixed or TM.smoothAlpha(smooth, dt)
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, TM.lerpAngle(myYaw(), want + (offsetRad or 0), alpha), 0)
            end)
            c.conn(conn)
            return conn
        end
        -- Roblox's camera script rewrites the camera every frame, so a camera aim has to be put back by a render step that runs right after it
        function c.aimCamera(getPoint, seconds)
            local name = "TechLabAim_" .. tech.id
            local t0 = clock()
            local bound = true
            local function unbind() if bound then bound = false; pcall(function() RunService:UnbindFromRenderStep(name) end) end end
            c.onFinish(unbind)
            local ok = pcall(function()
                RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
                    local cam = Workspace.CurrentCamera
                    local p = getPoint()
                    if not (cam and p) or clock() - t0 >= seconds or not alive() then unbind(); return end
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, V3(p))
                end)
            end)
            if not ok then bound = false end
        end
        -- hold a key down for `seconds` (released when the tech ends whatever happens)
        function c.holdKey(name, seconds)
            if not keyEvent(true, name) then return false end
            local released = false
            local function release() if not released then released = true; keyEvent(false, name) end end
            cleanups[#cleanups + 1] = release
            task.delay(seconds, release)
            return true
        end
        -- my own character does not collide for the rest of the run (Humanoids switch collisions back on every frame, so it is re-applied each Stepped)
        function c.noclip()
            local parts = {}
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then parts[#parts + 1] = part end
            end
            local function apply() for _, part in ipairs(parts) do if part.Parent then part.CanCollide = false end end end
            apply()
            cleanups[#cleanups + 1] = function() for _, part in ipairs(parts) do if part.Parent then part.CanCollide = true end end end
            local conn = listen(RunService.Stepped, apply)
            if conn then cleanups[#cleanups + 1] = function() conn:Disconnect() end end
        end
        -- jump to `point` at once, keeping my rotation (stopped short of walls, never under the floor)
        function c.teleport(point, o)
            local p = c.safePoint(point, o)
            root.CFrame = CFrame.new(V3(p)) * (root.CFrame - root.CFrame.Position)
            return p
        end
        -- like push, but sideways only (gravity and jumps keep working)
        function c.pushFlat(v)
            local bv = c.instance(Instance.new("BodyVelocity"))
            bv.MaxForce = Vector3.new(1e5, 0, 1e5)
            bv.Velocity = Vector3.new(v.x, 0, v.z)
            bv.Parent = root
            return {stop = function() if bv.Parent then bv:Destroy() end end}
        end
        -- rays see the map only: not me, not the other characters (a ray from above a player would otherwise call his head the floor)
        local function mapParams()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local list = {char}
            local live = Workspace:FindFirstChild("Live")
            if live then list[#list + 1] = live end
            params.FilterDescendantsInstances = list
            return params
        end
        c.mapParams = mapParams
        function c.floorY(pos)
            local params = mapParams()
            local hit = Workspace:Raycast(Vector3.new(pos.x, pos.y + 3, pos.z), Vector3.new(0, -300, 0), params)      -- the surface right under the point
            if not hit then hit = Workspace:Raycast(Vector3.new(pos.x, pos.y + 80, pos.z), Vector3.new(0, -300, 0), params) end   -- (the point is under the map)
            return hit and hit.Position.Y or pos.y
        end
        -- where a teleport / slide to `p` may really end: `margin` studs before a wall on the way, and (floor ~= false) not below the floor
        function c.safePoint(p, o)
            o = o or {}
            if not lab.safeMoves then return p end
            local from = root.Position
            local out = p
            local dir = V3(p) - from
            if dir.Magnitude > 0.05 then
                local hit = Workspace:Raycast(from, dir, mapParams())
                if hit then out = TM.stopShort(vec(from), p, vec(hit.Position), o.margin or 2) end
            end
            if o.floor ~= false then out = TM.aboveFloor(out, c.floorY(out), o.minAbove or 2.5) end
            return out
        end
        function c.jump(power)
            pcall(function()
                hum.PlatformStand = false
                hum.Jump = true
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
            local v = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
        end
        return c
    end

    -------------------------------------------------------------------------------------------------------- running a tech
    -- the hit check: did the focus lose health during the run (or within hitWindow after it)?
    local function checkHit(tech, focus, before)
        task.delay(lab.hitWindow, function()
            if not lab.alive or not focus or type(before) ~= "number" then return end
            local now = focus.hum.Health
            local landed = type(now) == "number" and (now < before - 0.5 or not focus.model.Parent)
            tech.stats.checked = (tech.stats.checked or 0) + 1
            if landed then tech.stats.hits = (tech.stats.hits or 0) + 1 end
            tech.lastHit = landed
            tech.hitText = string.format("hits %d/%d", tech.stats.hits or 0, tech.stats.checked)
            setStatus(tech, tech.baseStatus or "")
        end)
    end

    function lab:fire(id, info)
        local tech = type(id) == "table" and id or lab.byId[id]
        if not tech then return false, "unknown tech" end
        info = info or {}
        info.manual = info.manual or tech.manual or nil           -- a key / button press (the keys and the UI call lab:fire with manual = true)
        if not lab.alive then return false, "off" end
        if not info.manual and not (lab.master and tech.enabled) then return false, "off" end
        local now = clock()
        -- a key press while another tech is still going waits a moment for it instead of being lost (an input buffer)
        local function buffer(why)
            if info.manual and not info.fromBuffer and lab.bufferMs > 0 then
                lab.buffered = {tech = tech, info = info, expires = now + lab.bufferMs / 1000}
                setStatus(tech, "queued: " .. why)
                return false, "queued"
            end
            return nil
        end
        if tech.running then
            local q, why = buffer("it is still running")
            if q ~= nil then return q, why end
            return false, "running"
        end
        if tech.moves then
            for _, other in ipairs(lab.order) do
                if other ~= tech and other.moves and other.running then
                    local q, why = buffer("after " .. other.title)
                    if q ~= nil then return q, why end
                    if info.manual then setStatus(tech, "not now: " .. other.title .. " is running") end
                    return false, "exclusive"
                end
            end
        end
        if not info.manual and env.busy and env.busy() then return false, "busy" end
        if lab.guardKnocked and lab:knocked() then
            setStatus(tech, "not while you are knocked down")
            return false, "knocked"
        end
        if now < tech.cooldownUntil and not info.force then return false, "cooldown" end
        if tech.needsDash and lab.dashGuard and not lab.dashClock:ready(tech.needsDash, now) and not info.force then
            setStatus(tech, string.format("waiting: the %s dash is on cooldown (%.1f s)", tech.needsDash, lab.dashClock:left(tech.needsDash, now)))
            return false, "dash cooldown"
        end
        tech.token = tech.token + 1
        local token = tech.token
        local ctx = newCtx(tech, token, info)
        if not ctx then setStatus(tech, "no character"); return false, "no character" end
        tech.running = true
        setStatus(tech, "running...")
        task.spawn(function()
            local startedAt = clock()
            local ok, err = pcall(tech.run, ctx)
            ctx.finish()
            if tech.token ~= token then return end                  -- cancelled from outside (Panic, switched off, died, respawned): that already wrote the status
            tech.running = false
            if not ok then
                tech.stats.errors = tech.stats.errors + 1
                setStatus(tech, "error: " .. tostring(err):sub(1, 90))
                log("[" .. tech.id .. "] " .. tostring(err))
            elseif ctx.result then
                setStatus(tech, ctx.result)
            elseif ctx.committed then
                setStatus(tech, string.format("done in %.2f s (%d runs)", clock() - startedAt, tech.stats.runs))
            else
                setStatus(tech, "ready")
            end
            if ok and ctx.committed then
                tech.cooldownUntil = clock() + (tech.opt.cooldown or 0)
                if ctx.focus then checkHit(tech, ctx.focus, ctx.focusHealth) end
                -- a chain: the follow-up starts once this one is over (at most three links, so two techs cannot call each other for ever)
                local nxt = tech.opt.next
                if not ctx.aborted and nxt and nxt ~= "None" and NEXT_IDS[nxt] and (info.depth or 0) < 3 then
                    task.delay((tech.opt.nextDelay or 0) / 1000, function()
                        if not lab.alive then return end
                        if NEXT_IDS[nxt] == "m1" then lab:m1() return end
                        lab:fire(NEXT_IDS[nxt], {manual = true, depth = (info.depth or 0) + 1, chainedFrom = tech.id})
                    end)
                end
            end
            -- a key press that was waiting for this tech goes now
            local b = lab.buffered
            if b and tech.moves then
                lab.buffered = nil
                if clock() <= b.expires then
                    b.info.fromBuffer = true
                    lab:fire(b.tech, b.info)
                else
                    setStatus(b.tech, "ready")
                end
            end
        end)
        return true
    end

    function lab:cancel(id, why)
        local tech = lab.byId[id]
        if not tech then return end
        tech.token = tech.token + 1
        tech.running = false
        if why then setStatus(tech, why) end
    end
    function lab:cancelAll(why)
        local b = lab.buffered
        lab.buffered = nil
        if b then setStatus(b.tech, why or "cancelled") end
        for _, tech in ipairs(lab.order) do
            if tech.running then lab:cancel(tech.id, why or "cancelled") end
        end
    end

    -------------------------------------------------------------------------------------------------------- triggers: my own animations, enemy animations, the mouse, keys, a poll
    local function learnedTrigger(id, track)
        local L = lab.learning
        if not L then return false end
        if clock() > L.expires then lab.learning = nil; return false end   -- nobody played anything in time: stop listening
        if safe(function() return track.Looped end) == true then return false end
        lab.learning = nil
        local n = 0
        for _ in pairs(L.tech.extra) do n = n + 1 end
        if n < 6 then L.tech.extra[id] = true; rebuildIds(L.tech) end
        if env.toast then env.toast("Learned " .. id .. " as a trigger for " .. L.tech.title) end
        if L.cb then pcall(L.cb, id) end
        return true
    end
    function lab:learnTrigger(id, cb)
        local tech = lab.byId[id]
        if tech then lab.learning = {tech = tech, cb = cb, expires = clock() + 15} end
    end
    function lab:forgetTriggers(id)
        local tech = lab.byId[id]
        if tech then tech.extra = {}; rebuildIds(tech) end
    end

    local function onOwnAnim(track)
        if ownTracks[track] then return end
        local id = TD.idOf(safe(function() return track.Animation.AnimationId end))
        if not id then return end
        local now = clock()
        local kind = TD.dashKind(id)
        if kind then
            lab.lagger:seen("dash", now)
            local lag = lab:lag()
            lab.dashClock:seen(kind, now, lag, lab:jitterMs() / 1000)
            lab.lastOwn[kind] = now - lag                            -- when I SENT it (the animation comes later)
        end
        lab.lastOwn.id, lab.lastOwn.t = id, now
        if learnedTrigger(id, track) then return end
        for _, tech in ipairs(lab.order) do
            if tech.enabled and tech.ids[id] and not tech.observer then lab:fire(tech, {anim = id, track = track}) end
        end
    end

    -------------------------------------------------------------------------------------------------------- marks: highlights and arrows on other players
    lab.marks = {}
    local function colorOf(name)
        local c = TD.COLORS[name] or TD.COLORS.Cyan
        return Color3.fromRGB(c[1], c[2], c[3])
    end
    local function killMark(kind, model)
        local list = lab.marks[kind]
        local mark = list and list[model]
        if mark then
            list[model] = nil
            pcall(function() if mark.Parent then mark:Destroy() end end)
        end
    end
    -- a highlight on `model` (kind = which tech owns it), gone after `seconds` or when the tech is switched off
    function lab:mark(model, kind, colorName, seconds)
        killMark(kind, model)
        local light = Instance.new("Highlight")
        light.Name = "TechLabMark"
        light.Adornee = model
        light.FillColor = colorOf(colorName)
        light.OutlineColor = colorOf(colorName)
        light.FillTransparency = 0.5
        light.OutlineTransparency = 0
        light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        light.Parent = Workspace
        lab.marks[kind] = lab.marks[kind] or {}
        lab.marks[kind][model] = light
        if seconds then
            task.delay(seconds, function() if lab.marks[kind] and lab.marks[kind][model] == light then killMark(kind, model) end end)
        end
        return light
    end
    -- a red arrow above `model` for as long as `track` plays (or `seconds`)
    function lab:arrow(model, kind, track, seconds)
        killMark(kind, model)
        local part = model:FindFirstChild("HumanoidRootPart")
        if not part then return nil end
        local gui = Instance.new("BillboardGui")
        gui.Name = "TechLabArrow"
        gui.Adornee = part
        gui.Size = UDim2.new(4, 0, 2, 0)
        gui.StudsOffset = Vector3.new(0, 5, 0)
        gui.AlwaysOnTop = true
        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        text.Text = "VV"
        text.Font = Enum.Font.GothamBold
        text.TextScaled = true
        text.TextColor3 = Color3.fromRGB(255, 0, 0)
        text.Parent = gui
        gui.Parent = part
        lab.marks[kind] = lab.marks[kind] or {}
        lab.marks[kind][model] = gui
        if track then listen(track.Stopped, function() if lab.marks[kind] and lab.marks[kind][model] == gui then killMark(kind, model) end end) end
        task.delay(seconds or 3, function() if lab.marks[kind] and lab.marks[kind][model] == gui then killMark(kind, model) end end)
        return gui
    end
    function lab:clearMarks(kind)
        for k, list in pairs(lab.marks) do
            if kind == nil or k == kind then
                for model in pairs(list) do killMark(k, model) end
            end
        end
    end
    local function markStat(tech, text)
        tech.stats.runs = tech.stats.runs + 1
        setStatus(tech, string.format("%s (%d)", text, tech.stats.runs))
    end

    -------------------------------------------------------------------------------------------------------- somebody else's animations
    -- every enabled tech that watches other players gets (model, track, id); it decides for itself
    local function onEnemyAnim(model, track)
        if not lab.master then return end
        local id = TD.idOf(safe(function() return track.Animation.AnimationId end))
        if not id then return end
        for _, tech in ipairs(lab.order) do
            if tech.enabled and tech.onEnemy then
                local ok, err = pcall(tech.onEnemy, model, track, id)
                if not ok then tech.stats.errors = tech.stats.errors + 1; log("[" .. tech.id .. "] " .. tostring(err)) end
            end
        end
    end

    -- Auto Counter answers dashes and M1s aimed at me
    lab.techs.counter.onEnemy = function(model, track, id)
        local tech = lab.techs.counter
        local o = tech.opt
        local isDash = o.answerDashes and tech.dashSet[id]
        local isM1 = o.answerM1 and tech.m1Set[id]
        if not (isDash or isM1) then return end
        local char, _, root = myParts()
        local eroot = model:FindFirstChild("HumanoidRootPart")
        if not (root and eroot) or model == char then return end
        local d = (eroot.Position - root.Position).Magnitude
        if d > o.distance then return end
        if o.facing then
            local to = TM.unit(TM.flat(TM.sub(vec(root.Position), vec(eroot.Position))))
            if TM.dot(TM.unit(TM.flat(vec(eroot.CFrame.LookVector))), to) < -0.2 then return end
        end
        tech.pending = {isDash = isDash, name = model.Name}
        lab:fire(tech, {anim = id, enemy = model.Name, focus = validEnemy(model, char)})
    end

    local function notMe(model) local char = LocalPlayer.Character; return model ~= char end
    lab.techs.counteresp.onEnemy = function(model, track, id)
        local tech = lab.techs.counteresp
        if notMe(model) and tech.counterSet[id] then
            lab:mark(model, "counteresp", tech.opt.color, tech.opt.seconds)
            markStat(tech, "counter: " .. model.Name)
        end
    end
    lab.techs.blockwarn.onEnemy = function(model, track, id)
        local tech = lab.techs.blockwarn
        if notMe(model) and tech.warnSet[id] then
            lab:arrow(model, "blockwarn", track, tech.opt.seconds)
            markStat(tech, "warning: " .. model.Name)
        end
    end
    lab.techs.blockesp.onEnemy = function(model, track, id)
        local tech = lab.techs.blockesp
        if notMe(model) and blockSet[id] then
            lab:mark(model, "blockesp", tech.opt.color, tech.opt.seconds)
            listen(track.Stopped, function() killMark("blockesp", model) end)
            markStat(tech, "blocking: " .. model.Name)
        end
    end
    lab.techs.deathcounter.onEnemy = function() end                   -- (it watches the character, not an animation: see watchEnemy)
    do
        lab.techs.counteresp.counterSet = TD.set(TD.ANIM.counterMove)
        lab.techs.blockwarn.warnSet = TD.set(TD.ANIM.downslamWarning)
    end

    local function deathCounterOn(model)
        local tech = lab.techs.deathcounter
        if tech.enabled and lab.master and notMe(model) then
            lab:mark(model, "deathcounter", tech.opt.color, tech.opt.seconds)
            markStat(tech, "death counter: " .. model.Name)
        end
    end

    local function watchEnemy(model)
        if watched[model] or not model:IsA("Model") then return end
        local hum = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 3)
        local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 3))
        if not animator then return end
        watched[model] = {
            listen(animator.AnimationPlayed, function(track) onEnemyAnim(model, track) end),
            listen(model.ChildAdded, function(child) if child.Name == "Death Counter" then deathCounterOn(model) end end),
        }
        if model:FindFirstChild("Death Counter") then deathCounterOn(model) end
    end
    local function unwatch(model)
        for _, conn in pairs(watched[model] or {}) do pcall(function() conn:Disconnect() end) end
        watched[model] = nil
    end
    local function unwatchEnemies()
        for model in pairs(watched) do unwatch(model) end
    end
    local function startEnemyWatch()
        if lab.liveConns then return end
        lab.liveConns = {}
        local live = Workspace:FindFirstChild("Live")
        if not live then return end
        for _, m in ipairs(live:GetChildren()) do task.spawn(watchEnemy, m) end
        lab.liveConns[#lab.liveConns + 1] = listen(live.ChildAdded, function(m) task.spawn(watchEnemy, m) end)
        lab.liveConns[#lab.liveConns + 1] = listen(live.ChildRemoved, function(m) unwatch(m) end)
    end
    local function stopEnemyWatch()
        for _, c in ipairs(lab.liveConns or {}) do pcall(function() c:Disconnect() end) end
        lab.liveConns = nil
        unwatchEnemies()
    end

    local function hookCharacter(char)
        for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
        charConns = {}
        task.spawn(function()
            local hum = char:WaitForChild("Humanoid", 10)
            if not (hum and lab.alive and LocalPlayer.Character == char) then return end
            local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 10)
            charConns[#charConns + 1] = listen(animator and animator.AnimationPlayed or hum.AnimationPlayed, onOwnAnim)
            charConns[#charConns + 1] = listen(hum.Died, function() lab:cancelAll("cancelled: you died") end)
        end)
    end

    -------------------------------------------------------------------------------------------------------- mouse / key / poll triggers and the hook dash selection
    -- Enum.KeyCode["Nope"] throws, a name typed into a config must not be able to break the input handler
    local function keyCode(name)
        local ok, code = pcall(function() return Enum.KeyCode[name] end)
        return ok and code or nil
    end

    local function hookClear()
        local h = lab.hook
        if h.light then pcall(function() h.light:Destroy() end) end
        h.light, h.target = nil, nil
        local tech = lab.techs.hook
        if tech and not tech.running then setStatus(tech, "no target selected") end
    end
    local function hookSelect(entry)
        local h, tech = lab.hook, lab.techs.hook
        if h.target and entry and h.target.model == entry.model then hookClear(); return end          -- the same one again: deselect
        hookClear()
        if not entry then return end
        h.target = entry
        if tech.opt.highlight then
            local light = Instance.new("Highlight")
            light.Name = "TechLabHook"
            light.FillColor = Color3.fromRGB(173, 216, 230)
            light.OutlineColor = Color3.fromRGB(173, 216, 230)
            light.FillTransparency = 0.8
            light.OutlineTransparency = 0.3
            light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            light.Adornee = entry.model
            light.Parent = entry.model
            h.light = light
        end
        setStatus(tech, "target: " .. entry.name)
    end
    -- the enemy nearest to a world point (the cursor's hit)
    function lab:hookSelectNear(point)
        local best, bestD = nil, 30                                   -- nobody within 30 studs of the cursor: nothing is selected
        for _, e in ipairs(lab:enemies()) do
            local d = (e.root.Position - point).Magnitude
            if d < bestD then best, bestD = e, d end
        end
        if not best then setStatus(lab.techs.hook, "no player near your cursor") return nil end
        hookSelect(best)
        return best
    end
    -- the model under a screen point (a tap on a phone)
    function lab:hookSelectAt(x, y)
        local cam = Workspace.CurrentCamera
        local char = LocalPlayer.Character
        if not (cam and char) then return nil end
        local ray = cam:ScreenPointToRay(x, y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
        local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
        local entry = model and validEnemy(model, char)
        if entry then hookSelect(entry) end
        return entry
    end
    function lab:hookClear() hookClear() end
    function lab:hookTarget() return lab.hook.target end

    local lastTap = 0
    local function onInput(input, processed)
        if processed or not lab.alive or not lab.master then return end
        local ut = input.UserInputType
        local now = clock()
        if ut == Enum.UserInputType.Touch then
            local hook = lab.techs.hook
            if hook.enabled then
                if now - lastTap < 0.35 then lab:hookSelectAt(input.Position.X, input.Position.Y) end
                lastTap = now
            end
            return
        end
        if ut == Enum.UserInputType.MouseButton1 then
            local tech = lab.techs.sidem1
            if tech.enabled then lab:fire(tech, {mouse = true}) end
            return
        end
        if ut ~= Enum.UserInputType.Keyboard then return end
        local code = input.KeyCode
        if code == Enum.KeyCode.Q then lab.lagger:sent("dash", now) end
        local hook = lab.techs.hook
        if hook.enabled then
            if code == keyCode(hook.opt.selectKey) then
                local mouse = safe(function() return LocalPlayer:GetMouse() end)
                local p = mouse and safe(function() return mouse.Hit.Position end)
                if p then lab:hookSelectNear(p) end
                return
            elseif code == keyCode(hook.opt.goKey) then
                if lab.hook.target then lab:fire(hook, {manual = true}) else setStatus(hook, "no target selected (press the select key near them)") end
                return
            end
        end
        for _, tech in ipairs(lab.order) do
            if tech.manual and tech.opt.key and tech.enabled and code == keyCode(tech.opt.key) then lab:fire(tech, {manual = true}) end
        end
        local nel = lab.techs.noendlag
        if nel.enabled and code == Enum.KeyCode.Q and lab.lastOwn.side and now - lab.lastOwn.side <= nel.opt.window then
            lab.lastOwn.side = nil
            lab:fire(nel, {key = true})
        end
    end

    local pollAcc, catching = 0, false
    local function onHeartbeat(dt)
        if not lab.alive then return end
        -- the hook target is dropped the moment it dies or leaves
        local t = lab.hook.target
        if t and (not t.model.Parent or not healthy(t.hum)) then hookClear() end
        local tech = lab.techs.catch
        if not (lab.master and tech.enabled) then catching = false; return end
        pollAcc = pollAcc + dt
        if pollAcc < 0.03 then return end
        pollAcc = 0
        local _, _, root = myParts()
        if not root then return end
        local o = tech.opt
        local me, look = vec(root.Position), vec(root.CFrame.LookVector)
        local extraLead = pingOn(tech) and lab:lead() or 0                 -- he is already in the box by the time I see him walk into it
        local inside = false
        for _, e in ipairs(lab:enemies(o.range + 6)) do
            local v = vec(e.root.AssemblyLinearVelocity)
            if TM.inFrontBox(me, look, vec(e.root.Position), v, {range = o.range, halfWidth = o.halfWidth, halfHeight = 3, lead = o.lead / 100 + extraLead}) then inside = true; break end
        end
        if inside and not catching and not (env.busy and env.busy()) then
            catching = true
            tech.stats.runs = tech.stats.runs + 1
            lab:m1(o.hold / 1000)
            setStatus(tech, "caught somebody (" .. tech.stats.runs .. ")")
        elseif not inside then
            catching = false
        end
    end

    -------------------------------------------------------------------------------------------------------- the techs (sequences)
    local function sideKeyFor(dir)                                    -- the side-dash key whose camera-relative direction fits `dir` best
        local cam = Workspace.CurrentCamera
        local right = cam and cam.CFrame.RightVector or Vector3.new(1, 0, 0)
        return (dir.x * right.X + dir.z * right.Z) >= 0 and "D" or "A"
    end

    lab.techs.supa.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.delay / 1000)) then return end
        local entry = ctx.target(o.radius)
        if not entry then return ctx.abort("no target within " .. o.radius .. " studs") end
        ctx.commit()
        ctx.dash("W")
        if not ctx.wait(0.02) then return end
        local me, tp = vec(ctx.root.Position), ctx.predicted(entry)
        local pts = TM.supaPoints(me, tp, {under = o.under, lock = o.lock, jitter = o.jitter, behind = false})
        if not ctx.moveTo(pts.under, 0.2 / o.speed, pts.look, "quad_out") then return end
        if o.behind and entry.root.Parent then
            local now = ctx.predicted(entry)
            -- the finishing spot is worked out from where I STARTED (standing under them there is no direction left to work from)
            local end2 = TM.supaPoints(me, now, {behind = true, behindOffset = o.behindOffset, targetLook = vec(entry.root.CFrame.LookVector)})
            if not ctx.moveTo(end2.behind, 0.1, now, "quad_out") then return end
        end
        ctx.dash("W")
    end

    lab.techs.hook.run = function(ctx)
        local o, h = ctx.opt, lab.hook
        local entry = h.target
        if not entry or not healthy(entry.hum) or not entry.model.Parent then return ctx.abort("no target selected") end
        if o.maxY > 0 and (ctx.root.Position.Y > o.maxY or entry.root.Position.Y > o.maxY + 6) then return ctx.abort("too high up for a hook dash") end
        local dist = (entry.root.Position - ctx.root.Position).Magnitude
        if dist > o.maxDist then return ctx.abort(string.format("too far (%.0f > %.0f studs)", dist, o.maxDist)) end
        ctx.setFocus(entry)
        ctx.commit()
        local sideMode = ({["Behind them"] = "Behind", Closest = "Closest", Left = "Left", Right = "Right"})[o.side] or "Closest"
        local function plan(side, dir)
            return TM.hookPoint(vec(ctx.root.Position), vec(entry.root.Position), vec(entry.root.AssemblyLinearVelocity), vec(entry.root.CFrame.LookVector),
                {range = o.range, prediction = ctx.scaled(o.prediction), reach = o.reach, side = side or sideMode, dir = dir})
        end
        local first = plan()
        local toEnd = TM.sub(first.point, vec(ctx.root.Position))
        local key = sideKeyFor(toEnd)
        local sign = key == "D" and 1 or -1
        ctx.lockRotation()
        local before = lab.lastOwn.t or 0
        ctx.dash(key)
        task.delay(0.08, function()                                    -- the server's dash animation did not show up: play the side dash myself
            if ctx.alive() and (lab.lastOwn.t or 0) <= before then ctx.play(SIDE_ID[key == "D" and "Right" or "Left"], 1) end
        end)
        local lv = ctx.push({x = 0, y = 0, z = 0})
        local fixedSide = first.side
        local t0 = clock()
        local blocked = false
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not ctx.alive() then conn:Disconnect(); return end
            local p = plan(fixedSide, first.dir)
            -- the velocity that arrives exactly when the dash time is up (a fixed time constant would only ever cover 63 % of the way)
            local left = math.max(o.duration - (clock() - t0), 1 / 60)
            local v = TM.steer(vec(ctx.root.Position), p.point, left, 300)
            if lab.safeMoves and not blocked then                     -- a wall in the way: stop there instead of dashing into (or through) it
                local step = V3(v) * (1 / 20)
                if step.Magnitude > 0.05 and Workspace:Raycast(ctx.root.Position, step + step.Unit * 1.5, ctx.mapParams()) then blocked = true end
            end
            if blocked then v = TM.v3(0, 0, 0) end
            lv.set(v)
            local want = TM.yawTo(vec(ctx.root.Position), vec(entry.root.Position))
            if want then
                if o.face == "Side-on" then want = want + sign * math.rad(140) end
                local look = ctx.root.CFrame.LookVector
                local cur = atan2(-look.X, -look.Z)
                ctx.root.CFrame = CFrame.new(ctx.root.Position) * CFrame.Angles(0, TM.lerpAngle(cur, want, o.smooth), 0)
            end
        end)
        ctx.conn(conn)
        if o.m1After then
            task.delay(o.m1Delay, function() if ctx.alive() then lab:m1() end end)
        end
        if not ctx.wait(o.duration) then return end
        lv.stop()
        conn:Disconnect()
        if blocked then ctx.say("stopped at a wall") end
        if o.aimAfter > 0 then ctx.aimCamera(function() return vec(entry.root.Position) end, o.aimAfter) end
        ctx.wait(o.aimAfter)
    end

    lab.techs.loop.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.delay / 1000) + 0.065) then return end
        if ctx.info.track and ctx.info.track.IsPlaying == false and not ctx.info.manual then return ctx.abort("uppercut cancelled") end
        local entry = ctx.target(o.targetRadius)
        if not entry then return ctx.abort("no target within " .. o.targetRadius .. " studs") end
        ctx.commit()
        local me = vec(ctx.root.Position)
        local h = TM.heightAbove(ctx.floorY(me), me.y, o.maxHeight)
        ctx.dash("W")
        local c0 = ctx.predicted(entry)
        local startAngle = atan2(me.z - c0.z, me.x - c0.x)
        local seed = math.random() * 1000
        local lastDash = clock() - o.dashEvery / 1000
        local ok = ctx.frames(o.orbitTime, function(a)
            local tp = ctx.predicted(entry)
            local y = ctx.floorY(tp) + math.min(h, o.maxHeight)
            local pos, nxt = TM.orbitPose(tp, startAngle, a, {radius = o.radius, steps = 100, seed = seed, height = y})
            ctx.root.CFrame = CFrame.lookAt(V3(pos), V3(nxt))
            if clock() - lastDash >= o.dashEvery / 1000 then lastDash = clock(); lab:dash("W") end
        end)
        if not ok then return end
        local tp = ctx.predicted(entry)
        local hover = TM.v3(tp.x, ctx.floorY(tp) + math.min(h, o.maxHeight), tp.z)
        if not ctx.moveTo(hover, o.settle / 1000, TM.add(tp, TM.v3(0, 0.1, 0)), "quad_out") then return end
        local bp = ctx.instance(Instance.new("BodyPosition"))
        bp.MaxForce = Vector3.new(1e5, 1e5, 1e5); bp.P = 10000; bp.D = 100; bp.Position = V3(hover); bp.Parent = ctx.root
        local bg = ctx.instance(Instance.new("BodyGyro"))
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5); bg.P = 5000; bg.D = 100; bg.CFrame = ctx.root.CFrame; bg.Parent = ctx.root
        ctx.frames(o.hold / 1000, function()
            if not (bg.Parent and entry.root.Parent) then return end
            local mine, theirs = ctx.root.Position, entry.root.Position
            local look = ctx.root.CFrame.LookVector
            local toward = (theirs - mine)
            local mix = look + (toward.Magnitude > 0 and toward.Unit or Vector3.new(0, 0, 0))
            if mix.Magnitude > 0 then bg.CFrame = CFrame.new(mine, mine + mix.Unit) end
        end)
    end

    local function jumpLock(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.detect)) then return end
        if o.pauseOnBlock and ctx.enemyBlocking(o.radius) then return ctx.abort("paused: somebody is blocking") end
        ctx.commit()
        ctx.lockRotation()
        if o.jump then ctx.jump(o.jumpPower) end
        ctx.dash("W")
        if not ctx.wait(o.flick) then return end
        local entry = ctx.target(o.radius)
        if entry then ctx.faceLoop(function() return entry.root.Parent and ctx.predicted(entry) or nil end, o.lock, o.smooth) end
        ctx.wait(math.max(o.lock, 1.2))
    end
    lab.techs.loop2.run = jumpLock
    lab.techs.lethal.run = jumpLock

    lab.techs.kiba.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.delay / 1000)) then return end
        local entry = ctx.target(o.radius)
        if not entry then return ctx.abort("no target within " .. o.radius .. " studs") end
        ctx.commit()
        if o.mode == "Orbit (Kitty)" and o.pingWait then
            if not ctx.wait(TM.pingWait(lab:pingMs() or 60, 1.3, 0.03, 0.22)) then return end
        end
        ctx.dash("W")
        -- a part that follows the target (hanging on it / circling it), and the root is held to it by constraints that are always removed
        local follow = ctx.instance(Instance.new("Part"))
        follow.Size = Vector3.new(0.5, 0.5, 0.5); follow.Transparency = 1; follow.Anchored = true; follow.CanCollide = false; follow.Name = "TechLabFollow"; follow.Parent = Workspace
        local a0, a1 = ctx.instance(Instance.new("Attachment")), ctx.instance(Instance.new("Attachment"))
        a0.Parent = ctx.root; a1.Parent = follow
        local b0, b1 = ctx.instance(Instance.new("Attachment")), ctx.instance(Instance.new("Attachment"))
        b0.Parent = ctx.root; b1.Parent = follow
        local ap = ctx.instance(Instance.new("AlignPosition"))
        ap.Attachment0 = a0; ap.Attachment1 = a1; ap.RigidityEnabled = true; ap.Responsiveness = 200; ap.MaxForce = math.huge; ap.Parent = ctx.root
        local ao = ctx.instance(Instance.new("AlignOrientation"))
        ao.Attachment0 = b0; ao.Attachment1 = b1; ao.RigidityEnabled = true; ao.Responsiveness = 200; ao.MaxTorque = math.huge; ao.Parent = ctx.root
        local snapped = false
        ctx.frames(o.hold, function(a)
            if not entry.root.Parent then return end
            local t = entry.root
            local ahead = V3(TM.sub(ctx.predicted(entry), vec(t.Position)))      -- how far ahead of the picture he already is
            if o.mode == "Orbit (Kitty)" then
                local lap = (a * o.hold) / o.spin
                local center = t.Position + ahead + Vector3.new(0, o.orbitHeight, 0)
                local ang = 2 * math.pi * lap
                local pos = center + Vector3.new(math.cos(ang) * o.orbitRadius, 0, math.sin(ang) * o.orbitRadius)
                follow.CFrame = CFrame.lookAt(pos, t.Position + ahead)
            else
                follow.CFrame = (t.CFrame + ahead) * CFrame.Angles(math.rad(o.pitch), 0, 0)
            end
            if not snapped then snapped = true; ctx.root.CFrame = follow.CFrame end
        end)
    end

    lab.techs.twisted.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.wait / 1000)) then return end
        ctx.commit()
        ctx.teleport(vec((ctx.root.CFrame * CFrame.new(0, 0, o.stepBack)).Position))
        ctx.dash(o.dashKey)
        if o.instant then
            local entry = ctx.target(30)
            if entry then
                ctx.lockRotation()
                ctx.faceLoop(function() return entry.root.Parent and ctx.predicted(entry) or nil end, 0.3, 1000)
                ctx.wait(0.3)
            end
        end
    end

    lab.techs.kyoto.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.wait) + o.startDelay / 1000) then return end
        ctx.commit()
        local names = o.moveName ~= "" and {o.moveName} or TD.TOOLS.lethal
        local ok, why = ctx.useMove(names)
        if not ok then ctx.say("cast failed: " .. tostring(why)) end
        if o.hotbar then ctx.key("One") end
        ctx.stopAnims()
        ctx.play(SIDE_ID.Right, 1)
        ctx.lockRotation()
        local look = TM.unit(TM.flat(vec(ctx.root.CFrame.LookVector)), TM.v3(0, 0, -1))
        local right = TM.v3(-look.z, 0, look.x)
        local here = vec(ctx.root.Position)
        local dest = TM.add(here, TM.scale(look, o.distance))
        if not ctx.moveTo(dest, o.hopTime / 1000, TM.add(dest, right), "linear") then return end
        if o.hotbar then ctx.key("Two") end
        ctx.wait(0.25)
    end

    lab.techs.dunk.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.wait)) then return end
        ctx.commit()
        ctx.teleport(TM.add(vec(ctx.root.Position), TM.v3(0, o.height, 0)), {floor = false})        -- (a ceiling stops the lift)
    end

    lab.techs.surf.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.wait)) then return end
        ctx.commit()
        local look = TM.unit(TM.flat(vec(ctx.root.CFrame.LookVector)), TM.v3(0, 0, -1))
        local dest = TM.add(vec(ctx.root.Position), TM.scale(look, o.distance))
        ctx.moveTo(dest, o.time, nil, "linear")
    end

    lab.techs.counter.run = function(ctx)
        local o = ctx.opt
        ctx.setFocus(ctx.info.focus)
        local p = lab.techs.counter.pending or {}
        ctx.commit()
        if p.isDash and o.dashDelay > 0 then if not ctx.wait(o.dashDelay / 1000) then return end end
        local names = o.moveName ~= "" and {o.moveName} or TD.TOOLS.counters
        local ok, why = ctx.useMove(names)
        if ok then ctx.say("countered " .. tostring(p.name or "?")) else ctx.abort("no counter: " .. tostring(why)) end
    end

    lab.techs.flip.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.delay / 1000)) then return end
        ctx.commit()
        local keepVel = ctx.root.AssemblyLinearVelocity
        ctx.lockRotation()
        local bg = ctx.instance(Instance.new("BodyGyro"))
        bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9); bg.P = 20000; bg.D = 100
        bg.CFrame = ctx.root.CFrame * CFrame.Angles(TM.flipAngle(o.lock, o.lookUp), 0, 0)
        bg.Parent = ctx.root
        local bv = ctx.instance(Instance.new("BodyVelocity"))
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9); bv.Velocity = keepVel; bv.Parent = ctx.root
        ctx.wait(o.hold / 1000)
    end

    lab.techs.mousedash.run = function(ctx)
        local o = ctx.opt
        ctx.commit()
        local mouse = safe(function() return LocalPlayer:GetMouse() end)
        if not mouse then return ctx.abort("no mouse") end
        ctx.frames(o.window / 1000, function()
            local p = safe(function() return mouse.Hit.Position end)
            if not p then return end
            local pos = ctx.root.Position
            local at = Vector3.new(p.X, pos.Y, p.Z)
            if (at - pos).Magnitude > 1e-3 then ctx.root.CFrame = CFrame.lookAt(pos, at) end
        end)
    end

    lab.techs.sidem1.run = function(ctx)
        local o = ctx.opt
        if o.delay > 0 and not ctx.wait(o.delay / 1000) then return end
        ctx.commit()
        ctx.lockRotation()
        local ang = math.rad(o.angle)
        ctx.root.CFrame = ctx.root.CFrame * CFrame.Angles(0, ang, 0)
        local cam = Workspace.CurrentCamera
        local camBefore = cam and cam.CFrame
        if cam and not o.silent then
            local rel = cam.CFrame.Position - ctx.root.Position
            local flat = Vector3.new(rel.X, 0, rel.Z)
            local rotated = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), ang) * flat
            cam.CFrame = CFrame.lookAt(Vector3.new(ctx.root.Position.X + rotated.X, cam.CFrame.Position.Y, ctx.root.Position.Z + rotated.Z), ctx.root.Position)
        end
        ctx.wait(o.duration / 1000)
        if ctx.root.Parent then ctx.root.CFrame = ctx.root.CFrame * CFrame.Angles(0, -ang, 0) end
        if cam and camBefore and not o.silent then cam.CFrame = camBefore end
    end

    lab.techs.noendlag.run = function(ctx)
        ctx.commit()
        ctx.dash(ctx.opt.dashKey)
    end

    lab.techs.slidem1.run = function(ctx)
        ctx.commit()
        lab:m1()
    end

    lab.techs.downslam.run = function(ctx)
        local o = ctx.opt
        local near = ctx.target(o.radius)
        if not near then return ctx.abort("nobody within " .. o.radius .. " studs") end
        ctx.commit()
        local up = TM.add(vec(ctx.root.Position), TM.v3(0, o.lift, 0))
        ctx.moveTo(up, o.liftTime, nil, "quad_out")
        pcall(function()
            for _, st in ipairs({Enum.HumanoidStateType.PlatformStanding, Enum.HumanoidStateType.Freefall, Enum.HumanoidStateType.GettingUp}) do
                if ctx.hum:GetState() == st then ctx.hum:ChangeState(Enum.HumanoidStateType.Physics); task.wait() end
            end
            ctx.hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end

    lab.techs.m1reset.run = function(ctx)
        local o = ctx.opt
        ctx.commit()
        ctx.stopAnims()
        ctx.play(SIDE_ID.Right, 1.2)
        local right = TM.unit(TM.flat(vec(ctx.root.CFrame.RightVector)), TM.v3(1, 0, 0))
        local dest = TM.add(vec(ctx.root.Position), TM.scale(right, o.distance))
        if not ctx.moveTo(dest, o.duration, nil, "sine_out") then return end
        local ang = math.rad(o.rotation)
        ctx.root.CFrame = ctx.root.CFrame * CFrame.Angles(0, ang, 0)
        local cam = Workspace.CurrentCamera
        if cam then
            local rel = cam.CFrame.Position - ctx.root.Position
            local rotated = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), ang) * Vector3.new(rel.X, 0, rel.Z)
            cam.CFrame = CFrame.lookAt(Vector3.new(ctx.root.Position.X + rotated.X, cam.CFrame.Position.Y, ctx.root.Position.Z + rotated.Z), ctx.root.Position)
        end
        ctx.wait(0.003)
        if o.dashAfter ~= "None" then ctx.dash(o.dashAfter) end
    end

    lab.techs.emotedash.run = function(ctx)
        local o = ctx.opt
        ctx.commit()
        ctx.stopAnims()
        ctx.play(SIDE_ID.Right, 1.2)
        ctx.root.CFrame = ctx.root.CFrame * CFrame.Angles(0, math.rad(o.rotation), 0)
        local dir = ctx.root.CFrame.RightVector * o.distance + Vector3.new(0, o.height, 0)
        if dir.Magnitude == 0 then dir = Vector3.new(0, 1, 0) end
        local bv = ctx.instance(Instance.new("BodyVelocity"))
        bv.Velocity = dir.Unit * o.power
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Parent = ctx.root
        ctx.wait(o.duration)
    end

    -- cast a move for the new combo techs: by name (Console Move remote), or by hotbar slot
    local function castMove(ctx, o, defaultNames)
        local names = (o.moveName and o.moveName ~= "") and {o.moveName} or defaultNames
        if names then return ctx.useMove(names) end
        return ctx.key(TD.HOTBAR[tonumber(o.slot) or 1] or "One")
    end

    lab.techs.backdash.run = function(ctx)
        local o = ctx.opt
        ctx.commit()
        if o.aerial then
            ctx.jump(o.jumpPower)
            if not ctx.wait(o.aerialDelay / 1000) then return end
        end
        ctx.dash("S")
        if not ctx.wait(o.delay / 1000) then return end
        local ok, why = castMove(ctx, o)
        if not ok then ctx.say("cast failed: " .. tostring(why)) end
    end

    lab.techs.microdash.run = function(ctx)
        local o = ctx.opt
        local key = (o.side == "Left" and "A") or (o.side == "Right" and "D") or nil
        if not key then
            local entry = ctx.target(60)
            key = entry and sideKeyFor(TM.sub(vec(entry.root.Position), vec(ctx.root.Position))) or "D"
        end
        ctx.commit()
        ctx.dash(key)
        if not ctx.wait(o.delay / 1000) then return end
        local ok, why = castMove(ctx, o)
        if not ok then ctx.say("cast failed: " .. tostring(why)) end
    end

    lab.techs.shovedash.run = function(ctx)
        local o = ctx.opt
        local names = {o.moveName ~= "" and o.moveName or TD.TOOLS.shove[1]}
        if not lab:findTool(names) then return ctx.abort("you do not have " .. names[1]) end
        ctx.commit()
        ctx.useMove(names)
        if not ctx.wait(o.m1Delay / 1000) then return end
        ctx.m1()
        if not ctx.wait(o.dashDelay / 1000) then return end
        ctx.teleport(vec((ctx.root.CFrame * CFrame.new(0, 0, o.stepBack)).Position))
        ctx.dash("W")
    end

    lab.techs.uppercutcatch.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.delay / 1000)) then return end
        local entry = ctx.target(o.radius)
        if not entry then return ctx.abort("no target within " .. o.radius .. " studs") end
        local close = TM.flatDist(vec(ctx.root.Position), ctx.predicted(entry)) <= o.holdRange
        if not close and not ctx.dashReady("forward") then return ctx.abort("the forward dash is on cooldown") end
        ctx.commit()
        if close then ctx.holdKey("W", o.holdTime / 1000) else ctx.dash("W") end
        if not ctx.wait(o.m1Delay / 1000) then return end
        ctx.m1()
        if close then ctx.wait(math.max(0, o.holdTime - o.m1Delay) / 1000) end     -- keep walking for the whole time: a finished run lets go of W
    end

    local function graspRun(ctx)
        local o = ctx.opt
        if not ctx.wait(ctx.shift(o.delay)) then return end
        local names = o.moveName ~= "" and {o.moveName} or TD.TOOLS.grasp
        if not lab:findTool(names) then return ctx.abort("you do not have " .. names[1]) end
        ctx.commit()
        for i = 1, o.count do
            local ok, why = ctx.useMove(names)
            if not ok then ctx.say("cast failed: " .. tostring(why)); break end
            if i < o.count and not ctx.wait(o.gap / 1000) then return end
        end
    end
    lab.techs.uppercutgrasp.run = graspRun
    lab.techs.lethalgrasp.run = graspRun
    lab.techs.flowinggrasp.run = graspRun

    lab.techs.fastdash.run = function(ctx)
        local o = ctx.opt
        local sign = (ctx.info.anim and lab.techs.fastdash.leftSet[ctx.info.anim]) and -1 or 1
        ctx.commit()
        local right = TM.unit(TM.flat(vec(ctx.root.CFrame.RightVector)), TM.v3(1, 0, 0))
        local dir = TM.scale(right, sign)
        ctx.teleport(TM.add(vec(ctx.root.Position), TM.scale(dir, o.hop)))
        local burst = ctx.pushFlat(TM.scale(dir, o.speed))
        local track = ctx.info.track
        if track then
            task.delay(o.stopAt, function()
                if ctx.alive() and safe(function() return track.IsPlaying end) then pcall(function() track:Stop() end) end
            end)
        end
        if not ctx.wait(o.time) then return end
        burst.stop()
    end

    lab.techs.dashclip.run = function(ctx)
        ctx.commit()
        ctx.noclip()
        ctx.wait(ctx.opt.duration)
    end

    do   -- animation sets of the new techs
        lab.techs.fastdash.leftSet = TD.set(TD.ANIM.sideLeft)
    end

    do   -- Auto Counter's animation sets (built once, they depend on the data only)
        local c = lab.techs.counter
        c.dashSet, c.m1Set = TD.set(TD.ANIM.counterDash), TD.set(TD.ANIM.counterM1)
    end

    -------------------------------------------------------------------------------------------------------- switching, config, lifecycle
    local function refreshHooks()
        local needEnemies = false
        for _, tech in ipairs(lab.order) do
            if tech.watches and tech.enabled and lab.master then needEnemies = true end
        end
        if needEnemies then startEnemyWatch() else stopEnemyWatch() end
        if not lab.master then lab:clearMarks() end
    end
    function lab:setEnabled(id, on)
        local tech = lab.byId[id]
        if not tech then return end
        tech.enabled = on == true
        if not tech.enabled then lab:cancel(id, "off") else setStatus(tech, tech.manual and (tech.key and ("ready (" .. tech.key .. ")") or "ready") or "armed") end
        if id == "hook" and not tech.enabled then hookClear() end
        if tech.watches and not tech.enabled then lab:clearMarks(id) end
        refreshHooks()
        if id == "deathcounter" and tech.enabled then
            for model in pairs(watched) do if model:FindFirstChild("Death Counter") then deathCounterOn(model) end end     -- one that is already on somebody
        end
    end
    function lab:setMaster(on)
        lab.master = on == true
        if not lab.master then lab:cancelAll("off") end
        refreshHooks()
    end
    function lab:setOption(id, key, value)
        local tech = lab.byId[id]
        if not tech then return false end
        for _, d in ipairs(tech.defs) do
            if d.key == key then
                if not TO.valid(d, value) then return false end                  -- a value that makes no sense changes nothing
                tech.opt[key] = TO.clean(tech.defs, {[key] = value})[key]
                return true
            end
        end
        return false
    end
    function lab:setInput(mode) if mode == "Auto" or mode == "Remote" or mode == "Keys" then lab.input = mode end end
    function lab:dashLeft(kind) return lab.dashClock:left(kind, clock()) end

    function lab:export()
        local out = {enabled = {}, opts = {}, triggers = {}, input = lab.input, dashGuard = lab.dashGuard, releaseBlock = lab.releaseBlock, master = lab.master,
                     net = {strength = lab.net.strength, manual = lab.net.manual, interp = lab.net.interp, learn = lab.net.learn, ref = lab.net.ref},
                     targetMode = lab.targetMode, skipBlocking = lab.skipBlocking, safeMoves = lab.safeMoves, guardKnocked = lab.guardKnocked, bufferMs = lab.bufferMs}
        for _, tech in ipairs(lab.order) do
            if tech.enabled then out.enabled[tech.id] = true end
            local diff = TO.diff(tech.defs, tech.opt)
            if next(diff) then out.opts[tech.id] = diff end
            local ids = {}
            for id in pairs(tech.extra) do ids[#ids + 1] = id end
            if #ids > 0 then table.sort(ids); out.triggers[tech.id] = ids end
        end
        return out
    end
    function lab:import(saved)
        if type(saved) ~= "table" then return end
        if saved.input == "Auto" or saved.input == "Remote" or saved.input == "Keys" then lab.input = saved.input end
        if type(saved.dashGuard) == "boolean" then lab.dashGuard = saved.dashGuard end
        if type(saved.releaseBlock) == "boolean" then lab.releaseBlock = saved.releaseBlock end
        if type(saved.master) == "boolean" then lab.master = saved.master end
        if type(saved.net) == "table" then
            for _, key in ipairs({"strength", "manual", "interp", "ref", "learn"}) do lab:setNet(key, saved.net[key]) end
        end
        if type(saved.targetMode) == "string" then lab:setTargetMode(saved.targetMode) end
        for _, key in ipairs({"skipBlocking", "safeMoves", "guardKnocked"}) do
            if type(saved[key]) == "boolean" then lab[key] = saved[key] end
        end
        if type(saved.bufferMs) == "number" and saved.bufferMs == saved.bufferMs then lab.bufferMs = math.max(0, math.min(1000, saved.bufferMs)) end
        for _, tech in ipairs(lab.order) do
            tech.opt = TO.clean(tech.defs, type(saved.opts) == "table" and saved.opts[tech.id] or nil)
            local ids = type(saved.triggers) == "table" and saved.triggers[tech.id]
            tech.extra = {}
            if type(ids) == "table" then
                for i, id in ipairs(ids) do
                    if i <= 6 and type(id) == "string" and id:match("^%d+$") and #id <= 20 then tech.extra[id] = true end
                end
            end
            rebuildIds(tech)
            if type(saved.enabled) == "table" and saved.enabled[tech.id] == true then lab:setEnabled(tech.id, true) end
        end
    end

    function lab:destroy()
        lab.alive = false
        lab:cancelAll("off")
        hookClear()
        stopEnemyWatch()
        lab:clearMarks()
        for _, c in ipairs(lab.conns) do pcall(function() c:Disconnect() end) end
        for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
        lab.conns, charConns = {}, {}
        for _, a in pairs(animCache) do pcall(function() a:Destroy() end) end
        animCache = {}
    end

    -- start listening
    lab.conns[#lab.conns + 1] = listen(UIS.InputBegan, onInput)
    lab.conns[#lab.conns + 1] = listen(RunService.Heartbeat, onHeartbeat)
    if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
    lab.conns[#lab.conns + 1] = listen(LocalPlayer.CharacterAdded, function(char) lab:cancelAll("cancelled: respawned"); hookCharacter(char) end)
    return lab
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
        moveList = {"WEBOOM", "PLASMA_CANNON", "TRINITY_TEAR", "TWIN_BURST"},   -- hotbar order (unverified)
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
    -- combat timing facts used by Auto block (fan wikis / guides; the perfect-block window is an unverified blog claim)
    m1StartupFramesSaitama = 11,   -- The Strongest Hero wiki entry
    m1StartupFramesMartialArtist = 12,
    blockLockoutAfterM1   = 0.2,   -- cannot block for ~0.2 s after throwing an M1 (two sources agree)
    blockedFourthM1Stun   = 1.0,   -- a blocked / missed 4th punch stuns you ~1 s (games.gg)
    perfectBlockFramesClaim = 3,   -- ~50 ms at 60 fps (dungeonpath blog, unverified)
    critWindow            = 4,     -- Black Flash needs the 2nd perfect block within ~4 s of the 1st
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
    {name = "Block (F) basics", character = "Universal", confidence = "medium",
     desc = "Hold F: arms up, covers 180 degrees in front, stops all M1s and many specials. You move slowly and cannot act. ~0.2s block lockout after your own M1. Charged (held) hits break block, grabs ignore it, attacks from behind always connect. Tap block, do not hold."},
    {name = "Perfect Block -> Critical Hit", character = "Universal", confidence = "medium",
     desc = "Blocking an M1 at the last moment gives your next basic attack a Critical Hit (about triple damage, cracking sound). It stays until you are ragdolled (one source says ~4 s). Only works on real players, not dummies."},
    {name = "M1 timing facts (for blocking)", character = "Universal", confidence = "low",
     desc = "Saitama's M1 starts up in ~11 frames, Martial Artist's ~12 (about 0.18-0.2 s at 60 fps). After throwing an M1 you cannot block for ~0.2 s - opponents dash in then. A blocked or missed 4th punch stuns you ~1 s. A blog claims the perfect-block window is only ~3 frames (~50 ms) - unverified; nothing found gives per-move hit frames, which is why Auto block LEARNS the hit time from the damage you take."},
    {name = "M1 Hold vs Tap", character = "Universal", confidence = "low",
     desc = "Settings > M1 Mode: Hold keeps punching while held, Tap = one punch per press. Tap gives control over when the 4th punch lands. Delayed M1s use the M1 stun to space hits."},
    {name = "Latency and blocking", character = "Universal", confidence = "low",
     desc = "Block and damage are decided by the server, so what you see is already late by about your ping and your key press arrives a ping later. That is why the script presses F earlier by roughly your ping and why timings are learned per animation."},
    {name = "Black Flash", character = "Universal", confidence = "low",
     desc = "A perfect block while a Critical Hit is active, before you ragdoll: the next hit is a Black Flash (about double a Critical Hit; sources say up to 18%). It can be passed to a different target with your next hit."},
    {name = "Uppercut-shove reset", character = "The Strongest Hero", confidence = "low",
     desc = "3 M1, jump + uppercut, time the shove, then dash: M1 reset. Being airborne makes the shove knock back less - just enough for a front dash."},
    {name = "Uppercut > Shove > M1", character = "The Strongest Hero", confidence = "low",
     desc = "Hit Uppercut, then Shove as the target hits the ground, then M1."},
    {name = "Ground Punch tech", character = "Universal", confidence = "low",
     desc = "Use the 4th M1 to ragdoll an opponent again the moment they get up from their ragdoll."},
    {name = "Consecutive Punches vs side dash", character = "The Strongest Hero", confidence = "low",
     desc = "If the enemy side dashes toward you, Consecutive Punches catches them (forum tip)."},
    {name = "Hammer Heel launch", character = "Hero Hunter (Monster form)", confidence = "low",
     desc = "Aim Hammer Heel upward to launch them; when they land, loop-dash under them for a free M1 extend."},
    {name = "Longer Jet Dive", character = "Destructive Cyborg", confidence = "low",
     desc = "Turn around before the Jet Dive jump to get more range. (Camera turn is not automated.)"},
    {name = "Homerun > Grand Slam", character = "Brutal Demon", confidence = "low",
     desc = "After a Homerun knock-up, land a well-aimed Grand Slam in mid-air to push them back down."},
    {name = "Foul Ball extension", character = "Brutal Demon", confidence = "low",
     desc = "Land the Foul Ball grab variant and quickly dash into the ragdoll for M1s. Variant 2: downslam, dash away to land a normal Foul Ball, then dash to the ragdoll for more M1s."},
    {name = "Weboom Extend V2", character = "Tech Prodigy", confidence = "low",
     desc = "Downslam, turn back, Weboom so they roll forward, side dash ASAP (not too far behind them), then a forward dash to extend. A later patch reduced Weboom's range, which hurt this."},
    {name = "Twin Burst rebound", character = "Tech Prodigy", confidence = "none",
     desc = "A video tutorial exists for extending with Twin Burst; no written inputs found."},
    {name = "Child combo (forum)", character = "Tech Prodigy", confidence = "low",
     desc = "3 M1, uppercut, 4th move, 2nd move, side dash, front dash. Unverified single post - test in the lab first."},
    {name = "Suiryu two-skill combo", character = "Martial Artist", confidence = "low",
     desc = "A tip says Suiryu can chain two skills in one combo with the Uppercut Dash technique."},
    {name = "Unpunishable Sonic strings", character = "Deadly Ninja", confidence = "low",
     desc = "Fan guide: in a Sonic combo 3 of 4 moves cannot be punished with an evasive."},
    {name = "Uppercut Jump / Uppercut Flick / Stun Negation", character = "Universal", confidence = "none",
     desc = "Listed on the wiki's universal techs page; no written steps found."},
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
    -- research round 5
    TechProdigy_WeboomExtend = {character = "Tech Prodigy", confidence = "low", steps = {"DOWNSLAM", "WEBOOM", "SIDEDASH", "FRONTDASH"}},
    TechProdigy_Child = {character = "Tech Prodigy", confidence = "low", steps = seq(M1x3, "UPPERCUT", "TWIN_BURST", "PLASMA_CANNON", "SIDEDASH", "FRONTDASH")},
    MetalBat_HomerunSlam = {character = "Brutal Demon", confidence = "low", steps = {"HOMERUN", "GRAND_SLAM"}},
    MetalBat_FoulBallExtend = {character = "Brutal Demon", confidence = "low", steps = seq("FOUL_BALL", "FRONTDASH", M1x3)},
    MetalBat_FoulBallExtend2 = {character = "Brutal Demon", confidence = "low", steps = seq("DOWNSLAM", "BACKDASH", "FOUL_BALL", "FRONTDASH", M1x3)},
    Saitama_UppercutShoveReset = {character = "The Strongest Hero", confidence = "low", steps = seq(M1x3, "JUMP", "UPPERCUT", "SHOVE", "FRONTDASH")},
    Saitama_UppercutShoveM1 = {character = "The Strongest Hero", confidence = "low", steps = {"UPPERCUT", "SHOVE", "M1"}},
    GarouMonster_HammerHeel = {character = "Hero Hunter (Monster form)", confidence = "low", steps = {"HAMMER_HEEL", "FRONTDASH", "M1"}},
    -- Universal
    TwistedDash      = {character = "Universal", confidence = "medium", steps = seq(M1x4, "FRONTDASH")},
    Oreo             = {character = "Universal", confidence = "low", steps = seq(M1x3, "JUMP", "JUMP_M1", "FRONTDASH", "M1", "FRONTDASH")},
    TrueDownslam     = {character = "Universal", confidence = "medium", steps = {"M1", "M1", "JUMP", "JUMP_M1", "DOWNSLAM"}},
    UppercutDash     = {character = "Universal", confidence = "medium", steps = {"MINI_UPPERCUT", "FRONTDASH", "SIDEDASH", "FRONTDASH"}},
    M1Reset          = {character = "Universal", confidence = "medium", steps = seq(M1x3, "SIDEDASH", "FRONTDASH", "M1")},
    WallTech         = {character = "Universal", confidence = "medium", steps = seq(M1x3, "FRONTDASH", "M1")},
    AntiCancel       = {character = "Universal", confidence = "low", steps = seq(M1x3, "MINI_UPPERCUT", "SIDEDASH", "FRONTDASH")},
}

---------------------------------------------------------------- tech assists (the on/off toggles)
-- Same engine as the combos: switch one on, cast the FIRST move yourself, the script plays the rest.
-- steps[1] is normally the move you cast; everything after it is played for you.
Data.TechAssists = {
    -- Garou
    {name = "Flowing + Grasp", character = "Hero Hunter", confidence = "medium", steps = {"FLOWING_WATER", "SIDEDASH", "HUNTERS_GRASP"},
     desc = "You cast Flowing Water -> side dash -> Hunter's Grasp"},
    {name = "Flowing Water -> Kyoto", character = "Hero Hunter", confidence = "medium", kyoto = true,
     steps = {"FLOWING_WATER", "SIDEDASH", "LETHAL_WHIRLWIND_STREAM", "FRONTDASH", "M1", "M1", "M1", "BACKDASH", "FRONTDASH"},
     desc = "You cast Flowing Water -> side dash (Kyoto) -> Lethal Whirlwind Stream -> whirlwind dash -> 1-3 M1 -> instant twisted. The steps and waits come from the options below."},
    {name = "Grasp catch", character = "Hero Hunter", confidence = "low", steps = {"HUNTERS_GRASP", "SIDEDASH", "M1"},
     desc = "You cast Hunter's Grasp -> side dash -> M1"},
    {name = "Lethal + Grasp", character = "Hero Hunter", confidence = "low", steps = {"LETHAL_WHIRLWIND_STREAM", "HUNTERS_GRASP"},
     desc = "You cast Lethal Whirlwind -> Hunter's Grasp"},
    -- Saitama
    {name = "Shove + M1", character = "The Strongest Hero", confidence = "medium", steps = {"SHOVE", "M1"},
     desc = "You Shove -> instant M1 (works after 0-2 M1s)"},
    {name = "Uppercut catch", character = "The Strongest Hero", confidence = "low", steps = {"UPPERCUT", "FRONTDASH", "M1"},
     desc = "You Uppercut -> front dash -> M1"},
    {name = "Consecutive + Uppercut", character = "The Strongest Hero", confidence = "low", steps = {"CONSECUTIVE_PUNCHES", "UPPERCUT"},
     desc = "You cast Consecutive Punches -> Uppercut"},
    -- Genos
    {name = "Machine Gun + Ignition", character = "Destructive Cyborg", confidence = "medium", steps = {"MACHINE_GUN_BLOWS", "IGNITION_BURST"},
     desc = "You cast Machine Gun Blows -> Ignition Burst"},
    {name = "Ignition + dash", character = "Destructive Cyborg", confidence = "low", steps = {"IGNITION_BURST", "FRONTDASH", "M1", "M1", "M1"},
     desc = "You cast Ignition Burst -> dash to the ragdoll -> M1 string"},
    -- Sonic
    {name = "Scatter + Whirlwind", character = "Deadly Ninja", confidence = "medium", steps = {"SCATTER", "M1", "M1", "M1", "WHIRLWIND_KICK"},
     desc = "You cast Scatter -> 3 M1 -> Whirlwind Kick"},
    {name = "Flash Strike + M1", character = "Deadly Ninja", confidence = "low", steps = {"FLASH_STRIKE", "M1"},
     desc = "You cast Flash Strike -> M1 while they are stunned"},
    -- Metal Bat
    {name = "Foul Ball catch", character = "Brutal Demon", confidence = "low", steps = {"FOUL_BALL", "SIDEDASH", "M1"},
     desc = "You cast Foul Ball -> side dash -> M1"},
    {name = "Beatdown + Homerun", character = "Brutal Demon", confidence = "low", steps = {"BEATDOWN", "HOMERUN"},
     desc = "You cast Beatdown -> Homerun"},
    -- Atomic Samurai
    {name = "Pinpoint extend", character = "Blade Master", confidence = "low", steps = {"PINPOINT_CUT", "FRONTDASH", "M1", "M1", "M1"},
     desc = "You cast Pinpoint Cut -> dash after them -> M1s"},
    -- Tatsumaki
    {name = "Windstorm loop", character = "Wild Psychic", confidence = "low", steps = {"WINDSTORM_FURY", "FRONTDASH", "UPPERCUT"},
     desc = "You cast Windstorm Fury -> loop dash -> uppercut"},
    {name = "Coffin + Pull", character = "Wild Psychic", confidence = "low", steps = {"STONE_COFFIN", "CRUSHING_PULL"},
     desc = "You cast Stone Coffin -> Crushing Pull"},
    -- Tech Prodigy
    {name = "Weboom + dashes", character = "Tech Prodigy", confidence = "low", steps = {"WEBOOM", "SIDEDASH", "FRONTDASH"},
     desc = "You cast Weboom -> side dash -> front dash"},
    -- Universal
    {name = "Twisted dash", character = "Universal", confidence = "medium", steps = {"M1", "FRONTDASH"},
     desc = "After your 4th M1 -> front dash right away (set Opt > Trigger step to your M1)"},
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
local UILib = (function()

local UILib = {}

local THEMES = {
    Crimson = {bg = {9, 5, 6}, side = {9, 5, 6}, row = {21, 15, 16}, rowHover = {33, 24, 25}, stroke = {47, 32, 34}, text = {240, 236, 236}, sub = {152, 140, 142},
               accent = {236, 52, 64}, accent2 = {255, 110, 118}, ring = {146, 98, 255}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {60, 47, 49}},
    Ocean = {bg = {5, 8, 13}, side = {5, 8, 13}, row = {14, 21, 32}, rowHover = {22, 33, 49}, stroke = {32, 47, 69}, text = {232, 240, 250}, sub = {131, 150, 176},
             accent = {52, 152, 255}, accent2 = {120, 195, 255}, ring = {120, 195, 255}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {52, 66, 90}},
    Emerald = {bg = {5, 10, 8}, side = {5, 10, 8}, row = {14, 25, 21}, rowHover = {22, 38, 32}, stroke = {32, 56, 48}, text = {232, 247, 240}, sub = {128, 160, 146},
               accent = {46, 204, 113}, accent2 = {120, 235, 170}, ring = {120, 235, 170}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {50, 76, 66}},
    Violet = {bg = {9, 6, 15}, side = {9, 6, 15}, row = {21, 15, 34}, rowHover = {32, 23, 52}, stroke = {50, 36, 78}, text = {242, 236, 252}, sub = {154, 138, 184},
              accent = {155, 89, 255}, accent2 = {196, 150, 255}, ring = {196, 150, 255}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {70, 56, 98}},
    Gold = {bg = {10, 8, 4}, side = {10, 8, 4}, row = {24, 19, 11}, rowHover = {37, 30, 17}, stroke = {62, 51, 31}, text = {250, 244, 230}, sub = {171, 158, 128},
            accent = {240, 178, 40}, accent2 = {255, 214, 100}, ring = {255, 214, 100}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {82, 70, 46}},
}
UILib.ThemeNames = {"Crimson", "Ocean", "Emerald", "Violet", "Gold"}
UILib.IconNames = {"spark", "grid", "eye", "crosshair", "user", "dots", "gear", "terminal", "bolt", "knife", "pistol", "search", "chevron_up", "chevron_down", "close", "minus", "maximize", "move"}

local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

-- wave skins: layers of travelling grey-white bands (a UIGradient whose Offset moves) over the button's own fill
local WAVE_LAYERS = {
    {rot = 24, periods = 2.0, speed = 0.7, amp = 0.30, phase = 0.0},
    {rot = -20, periods = 2.6, speed = 1.15, amp = 0.24, phase = 2.1},
    {rot = 76, periods = 1.6, speed = 0.45, amp = 0.34, phase = 4.0},
}
local WAVE_LOOKS = {
    ui = {lo = {150, 154, 162}, hi = {236, 240, 248}, alpha = {1.0, 0.86}},        -- rows and small controls: faint light ripples on the dark fill
    float = {lo = {140, 144, 154}, hi = {240, 244, 252}, alpha = {0.97, 0.52}},    -- floating buttons: clearly visible grey-white waves
    pill = {lo = {150, 154, 162}, hi = {236, 240, 248}, alpha = {1.0, 0.78}},
}
-- one layer = 20 keypoints of a sharpened sine: thin bright crests on a transparent background, which reads as ripples on water
local function waveSequences(look, layer, strength)
    local n = 19
    local colors, alphas = {}, {}
    for i = 0, n do
        local t = i / n
        local s = (0.5 + 0.5 * math.sin(2 * math.pi * layer.periods * t + layer.phase)) ^ 2.2
        colors[#colors + 1] = ColorSequenceKeypoint.new(t, Color3.fromRGB(
            math.floor(look.lo[1] + (look.hi[1] - look.lo[1]) * s), math.floor(look.lo[2] + (look.hi[2] - look.lo[2]) * s), math.floor(look.lo[3] + (look.hi[3] - look.lo[3]) * s)))
        alphas[#alphas + 1] = NumberSequenceKeypoint.new(t, look.alpha[1] + (look.alpha[2] - look.alpha[1]) * s * (strength or 1))
    end
    return ColorSequence.new(colors), NumberSequence.new(alphas)
end

UILib.WaveLayers = WAVE_LAYERS
UILib.WaveSequences = waveSequences

function UILib.new(cfg)
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")

    local win = {Flags = {}, Tabs = {}, Elements = {}, Connections = {}, Alive = true, Floats = {}, Tickers = {}}
    local themeName = THEMES[cfg.Theme] and cfg.Theme or "Crimson"
    local T = THEMES[themeName]
    local themed = {}                                                    -- {inst, prop, key}: re-coloured by SetTheme
    local onError = cfg.OnError or function() end

    local function connect(signal, fn)
        local c = signal:Connect(fn)
        win.Connections[#win.Connections + 1] = c
        return c
    end
    win.Connect = connect
    local function safe(where, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then onError(where, err) end
        return ok
    end
    win.Safe = safe

    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end
    local function bind(inst, prop, key)                                 -- colour from the theme, now and after SetTheme
        inst[prop] = rgb(T[key])
        themed[#themed + 1] = {inst, prop, key}
    end
    local function corner(inst, px) return mk("UICorner", {CornerRadius = px == "full" and UDim.new(1, 0) or UDim.new(0, px or 8)}, inst) end
    local function stroke(inst, key, thickness)
        local s = mk("UIStroke", {Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst)
        bind(s, "Color", key or "stroke")
        return s
    end
    local function tween(inst, props, secs)
        local ok = pcall(function()
            TweenService:Create(inst, TweenInfo.new(secs or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
        end)
        if not ok then for k, v in pairs(props) do pcall(function() inst[k] = v end) end end
    end
    local function viewport()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize
        if not vp or vp.X < 100 then return Vector2.new(1280, 720) end
        return vp
    end

    ---------------------------------------------------------------------------------------------- icons
    -- Licensed raster icons (Lucide, via Footagesus/Icons, MIT - same pack WindUI itself uses: mm2/vendor/lucide_subset.json) for the shapes that have a
    -- real equivalent in that set. Everything else (no licensed match exists - there is no gun/pistol icon in Lucide) stays the small hand-drawn vector
    -- shape below. `icon()` returns a holder the same way either way, so callers (and the floating-button animations) do not care which one they got.
    local ICON_ASSETS = {
        crosshair = "rbxassetid://134242818164054", knife = "rbxassetid://124448418211665",  -- "sword" (Lucide has no knife icon)
        bolt = "rbxassetid://130551565616516",                                                -- "zap"
    }
    local function paintImage(img, color)
        if type(color) == "string" then bind(img, "ImageColor3", color) else img.ImageColor3 = color end
    end

    -- every vector icon is a handful of Frames drawn on a 20x20 grid; `color` is a theme key or a Color3
    local function icon(kind, parent, size, color, pos)
        size = size or 18
        if ICON_ASSETS[kind] then
            local img = mk("ImageLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(size, size), Name = "Icon_" .. kind,
                Image = ICON_ASSETS[kind]}, parent)
            if pos then img.Position = pos end
            paintImage(img, color)
            return img
        end
        local k = size / 20
        local holder = mk("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(size, size), Name = "Icon_" .. kind}, parent)
        if pos then holder.Position = pos end
        local function paint(inst, prop)
            if type(color) == "string" then bind(inst, prop, color) else inst[prop] = color end
        end
        local function bar(x, y, w, h, rot, round)
            local f = mk("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x + w / 2) * k, (y + h / 2) * k),
                Size = UDim2.fromOffset(math.max(1, w * k), math.max(1, h * k)), Rotation = rot or 0}, holder)
            paint(f, "BackgroundColor3")
            if round then corner(f, round == true and "full" or round * k) end
            return f
        end
        local function ring(x, y, w, h, thick)
            local f = mk("Frame", {BorderSizePixel = 0, BackgroundTransparency = 1, Position = UDim2.fromOffset(x * k, y * k),
                Size = UDim2.fromOffset(w * k, h * k)}, holder)
            corner(f, "full")
            local s = mk("UIStroke", {Thickness = math.max(1, thick * k), ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, f)
            paint(s, "Color")
            return f
        end
        if kind == "spark" then
            bar(9, 1, 2, 18, 0, true); bar(1, 9, 18, 2, 0, true); bar(4.5, 9, 11, 2, 45, true); bar(4.5, 9, 11, 2, -45, true)
        elseif kind == "grid" then
            bar(2, 2, 7, 7, 0, 2); bar(11, 2, 7, 7, 0, 2); bar(2, 11, 7, 7, 0, 2); bar(11, 11, 7, 7, 0, 2)
        elseif kind == "eye" then
            ring(1, 5, 18, 10, 2); bar(7.5, 7.5, 5, 5, 0, true)
        elseif kind == "crosshair" then
            ring(3, 3, 14, 14, 2); bar(9, 0, 2, 6, 0, true); bar(9, 14, 2, 6, 0, true); bar(0, 9, 6, 2, 0, true); bar(14, 9, 6, 2, 0, true); bar(9, 9, 2, 2, 0, true)
        elseif kind == "user" then
            bar(6, 1.5, 8, 8, 0, true); bar(3, 11, 14, 7, 0, 3.5)
        elseif kind == "dots" then
            bar(2, 8.5, 3.5, 3.5, 0, true); bar(8.25, 8.5, 3.5, 3.5, 0, true); bar(14.5, 8.5, 3.5, 3.5, 0, true)
        elseif kind == "gear" then
            bar(9, 0.5, 2, 19, 0, true); bar(0.5, 9, 19, 2, 0, true); bar(1.5, 9, 17, 2, 45, true); bar(1.5, 9, 17, 2, -45, true); ring(4.5, 4.5, 11, 11, 3)
        elseif kind == "terminal" then
            bar(3, 5.5, 8, 2.2, 38, true); bar(3, 11.5, 8, 2.2, -38, true); bar(11, 15, 7, 2.2, 0, true)
        elseif kind == "bolt" then
            bar(8, 1, 3, 10, 18, 1); bar(9, 9, 3, 10, 18, 1); bar(5, 9, 9, 2.4, 0, 1)
        elseif kind == "knife" then
            bar(8.5, 0, 4, 12, 40, 1.5); bar(3.5, 11.5, 9, 2, 40, true); bar(2, 13, 3, 7, 40, 1)
        elseif kind == "pistol" then
            bar(2, 4, 16, 5.5, 0, 1.5); bar(9, 9, 5, 9, 14, 1.5); bar(5.5, 9.5, 3.5, 3, 0, 1)
        elseif kind == "search" then
            ring(1.5, 1.5, 11, 11, 2); bar(11.2, 14.2, 2.2, 6.5, -45, true)
        elseif kind == "chevron_up" then
            bar(3, 9, 8, 2.2, -42, true); bar(9, 9, 8, 2.2, 42, true)
        elseif kind == "chevron_down" then
            bar(3, 9, 8, 2.2, 42, true); bar(9, 9, 8, 2.2, -42, true)
        elseif kind == "close" then
            bar(2, 9, 16, 2.2, 45, true); bar(2, 9, 16, 2.2, -45, true)
        elseif kind == "minus" then
            bar(3, 9, 14, 2.2, 0, true)
        elseif kind == "maximize" then
            bar(3, 3, 6, 2, 0, 1); bar(3, 3, 2, 6, 0, 1); bar(11, 3, 6, 2, 0, 1); bar(15, 3, 2, 6, 0, 1)
            bar(3, 15, 6, 2, 0, 1); bar(3, 11, 2, 6, 0, 1); bar(11, 15, 6, 2, 0, 1); bar(15, 11, 2, 6, 0, 1)
        elseif kind == "move" then
            bar(9, 1, 2, 18, 0, true); bar(1, 9, 18, 2, 0, true); bar(6.5, 1, 7, 2, 0, true); bar(6.5, 17, 7, 2, 0, true); bar(1, 6.5, 2, 7, 0, true); bar(17, 6.5, 2, 7, 0, true)
        end
        return holder
    end
    win.Icon = icon

    ---------------------------------------------------------------------------------------------- water-wave skins
    -- A skin is a clipped holder with 1-3 gradient layers sitting under the button's text. One Heartbeat connection moves all of them.
    local skins = {}
    win.WaveMode = cfg.WaveMode or "High"
    local function layersFor(mode) return mode == "High" and 3 or mode == "Low" and 1 or 0 end

    function win:Skin(host, o)
        o = o or {}
        local look = WAVE_LOOKS[o.Look or "ui"]
        local holder = mk("Frame", {Name = "Waves", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ClipsDescendants = true,
            Active = false, ZIndex = o.ZIndex or 1}, host)
        local skin = {host = host, holder = holder, layers = {}, page = o.Page, global = o.Global, active = o.Active, look = look, radius = o.Radius or 8, corners = {}}
        skin.corners[1] = corner(holder, o.Radius or 8)
        for i, layer in ipairs(WAVE_LAYERS) do
            local f = mk("Frame", {Name = "Wave" .. i, BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0)}, holder)
            skin.corners[#skin.corners + 1] = corner(f, o.Radius or 8)
            local colorSeq, alphaSeq = waveSequences(look, layer, o.Strength)
            local g = mk("UIGradient", {Color = colorSeq, Transparency = alphaSeq, Rotation = layer.rot, Offset = Vector2.new(0, 0)}, f)
            skin.layers[i] = {frame = f, grad = g, def = layer}
        end
        local n = layersFor(win.WaveMode)
        holder.Visible = n > 0
        for i, l in ipairs(skin.layers) do l.frame.Visible = i <= n end
        skins[#skins + 1] = skin
        function skin:SetRadius(px)                                       -- a resized round button keeps round waves
            skin.radius = px
            for _, c in ipairs(skin.corners) do c.CornerRadius = UDim.new(0, px) end
        end
        function skin:Ripple(x, y)                                        -- a ring of water spreading from the press point
            if win.WaveMode == "Off" or not skin.host.Parent then return end
            local size = math.max(skin.host.AbsoluteSize.X, skin.host.AbsoluteSize.Y, 20)
            local px = clamp((x or skin.host.AbsolutePosition.X + skin.host.AbsoluteSize.X / 2) - skin.host.AbsolutePosition.X, 0, math.max(1, skin.host.AbsoluteSize.X))
            local py = clamp((y or skin.host.AbsolutePosition.Y + skin.host.AbsoluteSize.Y / 2) - skin.host.AbsolutePosition.Y, 0, math.max(1, skin.host.AbsoluteSize.Y))
            local r = mk("Frame", {Name = "Ripple", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(6, 6),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.55, BorderSizePixel = 0}, holder)
            corner(r, "full")
            tween(r, {Size = UDim2.fromOffset(size * 2.2, size * 2.2), BackgroundTransparency = 1}, 0.55)
            task.delay(0.6, function() if r.Parent then r:Destroy() end end)
        end
        return skin
    end

    -- Outlines: the water-flow texture lives ONLY on borders. A UIStroke (plus a wider, fainter glow stroke) whose UIGradient is a sharpened sine of grey and white; the gradient's
    -- Rotation turns, so the bands run round the border like moving water. The inside of the host stays as it was (transparent).
    local outlines = {}
    local OUTLINE_LOOK = {lo = {96, 100, 112}, hi = {250, 252, 255}, alpha = {0.62, 0.0}}
    local OUTLINE_LAYER = {periods = 1.5, phase = 0.4}
    function win:Outline(host, o)
        o = o or {}
        local colors, alphas = waveSequences(OUTLINE_LOOK, OUTLINE_LAYER, 1)
        local ol = {host = host, grads = {}, page = o.Page, global = o.Global, active = o.Active, speed = o.Speed or 34, phase = (#outlines * 53) % 360, base = {}}
        local function addStroke(name, thickness, transparency)
            local st = mk("UIStroke", {Name = name, Thickness = thickness, Color = Color3.fromRGB(255, 255, 255), Transparency = transparency,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, host)
            ol.grads[#ol.grads + 1] = mk("UIGradient", {Name = "Flow", Color = colors, Transparency = alphas, Rotation = ol.phase}, st)
            return st
        end
        ol.stroke = addStroke("Outline", o.Thickness or 2.5, o.Transparency or 0)
        if o.Glow ~= false then ol.glow = addStroke("Glow", (o.Thickness or 2.5) * 2.8, 0.8) end
        function ol:Flash(color)                                          -- a short solid colour (fired / could not): the flow stands aside
            ol.flashing = true
            for _, g in ipairs(ol.grads) do g.Enabled = false end
            ol.stroke.Color = color
            if ol.glow then ol.glow.Color = color end
        end
        function ol:Reset()
            ol.flashing = false
            for _, g in ipairs(ol.grads) do g.Enabled = true end
            ol.stroke.Color = Color3.fromRGB(255, 255, 255)
            if ol.glow then ol.glow.Color = Color3.fromRGB(255, 255, 255) end
        end
        function ol:SetStrength(a)                                        -- 1 = full, 0 = faint (a dimmed / switched-off button)
            ol.stroke.Transparency = 1 - a * (1 - (o.Transparency or 0))
            if ol.glow then ol.glow.Transparency = 1 - a * 0.2 end
        end
        outlines[#outlines + 1] = ol
        return ol
    end

    function win:SetWaveMode(mode)
        if mode ~= "High" and mode ~= "Low" and mode ~= "Off" then return end
        win.WaveMode = mode
        local n = layersFor(mode)
        for _, s in ipairs(skins) do
            if s.holder.Parent then
                s.holder.Visible = n > 0
                for i, l in ipairs(s.layers) do l.frame.Visible = i <= n end
            end
        end
    end

    local waveClock, lastWave = 0, 0
    connect(RunService.Heartbeat, function(dt)
        if win.WaveMode == "Off" then return end
        waveClock = waveClock + dt
        local step = win.WaveMode == "High" and 1 / 30 or 1 / 15
        if waveClock - lastWave < step * 0.9 then return end                -- (a little slack: 60 fps then updates every 2nd frame, not sometimes every 3rd)
        lastWave = waveClock
        local n = layersFor(win.WaveMode)
        local shown = win.Main and win.Main.Visible
        local i = 1
        while i <= #skins do
            local s = skins[i]
            if not s.host.Parent then
                table.remove(skins, i)
            else
                local active = s.global and s.host.Visible or (shown and s.host.Visible and (not s.page or s.page.Visible))
                if active and s.active then active = s.active() end
                if active then
                    for li = 1, n do
                        local l = s.layers[li]
                        l.grad.Offset = Vector2.new(l.def.amp * math.sin(waveClock * l.def.speed + l.def.phase), 0)
                    end
                end
                i = i + 1
            end
        end
        for i = #outlines, 1, -1 do                                        -- the water runs round every outline that is on screen
            local ol = outlines[i]
            if not ol.host.Parent then
                table.remove(outlines, i)
            elseif not ol.flashing then
                local active = ol.global and ol.host.Visible or (shown and ol.host.Visible and (not ol.page or ol.page.Visible))
                if active and ol.active then active = ol.active() end
                if active then
                    local r = (waveClock * ol.speed + ol.phase) % 360
                    for _, g in ipairs(ol.grads) do g.Rotation = r end
                end
            end
        end
        for _, f in ipairs(win.Floats) do                                  -- the crosshair turns, the knife circles ...
            if f.anim and f.Button.Visible and f.Button.Parent then f.anim(waveClock) end
        end
        for i = #win.Tickers, 1, -1 do                                     -- other things that move with the waves (a window background): dropped if they ever error
            local ok, err = pcall(win.Tickers[i], waveClock)
            if not ok then table.remove(win.Tickers, i); onError("ticker", err) end
        end
    end)

    ---------------------------------------------------------------------------------------------- floating action buttons
    -- A rounded-square glass button: the inside is transparent (only the icon and the label are drawn), the OUTLINE glows and carries the flowing grey water.
    -- The icon moves: the crosshair turns and pulses, the knife circles, the pistol bobs and kicks. It lives outside the window (it stays when the menu is hidden).
    -- Tap = OnPress, drag = move it.
    local floatGui
    local function ensureFloatGui()
        if floatGui then return floatGui end
        floatGui = mk("ScreenGui", {Name = (cfg.GuiName or "WraithUI") .. "_Buttons", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
            DisplayOrder = 45}, nil)
        floatGui.Parent = cfg.Parent
        win.FloatGui = floatGui
        return floatGui
    end

    -- t = seconds, size = the button's side in px; holder = the icon (anchored at its centre), scale = its UIScale
    local ICON_ANIM = {
        crosshair = function(holder, scale, t, size)
            holder.Rotation = (t * 42) % 360
            scale.Scale = 1 + 0.07 * math.sin(t * 3.1)
            holder.Position = UDim2.new(0.5, 0.025 * size * math.cos(t * 1.7), 0.5, 0.025 * size * math.sin(t * 2.3))     -- the aim drifts a little, as if it was searching
        end,
        knife = function(holder, scale, t, size)                                   -- the knife travels round a circle, pointing the way it moves (plain white, no colour)
            local a = t * 2.4
            local r = 0.1 * size
            holder.Position = UDim2.new(0.5, r * math.cos(a), 0.5, r * math.sin(a))
            holder.Rotation = (math.deg(a) + 140) % 360
        end,
        pistol = function(holder, scale, t)
            local k = t % 3.4
            holder.Rotation = k < 0.28 and -12 * math.sin(k / 0.28 * math.pi) or 0                    -- a small kick every few seconds
            holder.Position = UDim2.new(0.5, 0, 0.5, 1.4 * math.sin(t * 2.2))
        end,
        bolt = function(holder, scale, t) holder.Rotation = 7 * math.sin(t * 8); scale.Scale = 1 + 0.06 * math.sin(t * 4) end,
        chevron_up = function(holder, scale, t) holder.Position = UDim2.new(0.5, 0, 0.5, -3 * math.abs(math.sin(t * 3))) end,
    }

    function win:Floating(o)
        local g = ensureFloatGui()
        local f = {Id = o.Id, Locked = o.Locked == true, Size = o.Size or 72, State = o.State == true}
        local vp = viewport()
        local fx, fy = (o.Pos and o.Pos[1]) or 0.8, (o.Pos and o.Pos[2]) or 0.25
        local btn = mk("TextButton", {Name = "Float_" .. tostring(o.Id), Text = "", AutoButtonColor = false, BorderSizePixel = 0, Size = UDim2.fromOffset(f.Size, f.Size),
            Position = UDim2.fromOffset(fx * vp.X, fy * vp.Y), BackgroundColor3 = Color3.fromRGB(8, 8, 12), BackgroundTransparency = 0.82, Visible = o.Visible ~= false}, g)
        mk("UICorner", {CornerRadius = UDim.new(0.24, 0)}, btn)
        local outline = win:Outline(btn, {Thickness = 2.5, Global = true})
        local iconBox = mk("CanvasGroup", {Name = "IconBox", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.fromOffset(f.Size, f.Size * 0.7), ZIndex = 3}, btn)
        local label = mk("TextLabel", {Name = "Label", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -math.floor(f.Size * 0.09)), Size = UDim2.new(0.9, 0, 0, 12),
            Text = o.Title or "", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Color3.fromRGB(250, 250, 252), TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.fromRGB(10, 10, 14),
            ZIndex = 3}, btn)
        local shade = mk("Frame", {Name = "Cooldown", BackgroundColor3 = Color3.fromRGB(10, 10, 14), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = 6}, btn)
        mk("UICorner", {CornerRadius = UDim.new(0.24, 0)}, shade)
        local pressScale = mk("UIScale", {Scale = 1}, btn)
        f.Button, f.Gui, f.Outline = btn, g, outline

        -- the "advanced" extras, none of them filled: a status line under the button (what a tap would do right now), a small pip in the corner (green = ready, grey = waiting,
        -- red = cannot), a thin progress bar for the reload / cooldown, a ring that spreads from a tap, and HIT / MISS after a shot
        local WHITE = Color3.fromRGB(255, 255, 255)
        local caption = mk("TextLabel", {Name = "Status", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 5), Size = UDim2.new(1.9, 0, 0, 13),
            Text = "", Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = Color3.fromRGB(236, 237, 241), TextTransparency = 0.12, TextStrokeTransparency = 0.45,
            TextStrokeColor3 = Color3.fromRGB(10, 10, 14), ZIndex = 4, Visible = false}, btn)
        local pip = mk("Frame", {Name = "Pip", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 9), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Color3.fromRGB(170, 172, 180),
            BorderSizePixel = 0, ZIndex = 5, Visible = false}, btn)
        corner(pip, "full")
        local track = mk("Frame", {Name = "ProgressTrack", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(0.56, 0, 0, 3), BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 4, Visible = false}, btn)
        corner(track, "full")
        local fill = mk("Frame", {Name = "Progress", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 5}, track)
        corner(fill, "full")

        local ic, iconScale
        local function buildIcon()
            if ic then ic:Destroy() end
            local isz = math.floor(f.Size * (o.Icon == "knife" and 0.36 or 0.4))
            ic = icon(o.Icon or "crosshair", iconBox, isz, Color3.fromRGB(246, 247, 250), UDim2.new(0.5, 0, 0.5, 0))
            ic.AnchorPoint = Vector2.new(0.5, 0.5)
            iconScale = mk("UIScale", {Scale = 1}, ic)
        end
        buildIcon()
        local step = ICON_ANIM[o.Icon or "crosshair"]
        f.anim = step and function(t) step(ic, iconScale, t, f.Size) end or nil

        local function place(px, py)
            local v = viewport()
            px = clamp(px, 0, math.max(0, v.X - f.Size)); py = clamp(py, 0, math.max(0, v.Y - f.Size))
            btn.Position = UDim2.fromOffset(px, py)
            return px, py
        end
        function f:GetPos()
            local v = viewport()
            return btn.Position.X.Offset / v.X, btn.Position.Y.Offset / v.Y
        end
        function f:SetPos(x, y) local v = viewport(); place(x * v.X, y * v.Y) end
        function f:SetVisible(b) btn.Visible = b == true end
        function f:SetLocked(b) f.Locked = b == true end
        function f:SetSize(px)
            f.Size = clamp(px, 56, 140)
            label.TextSize = clamp(math.floor(f.Size * 0.125), 8, 12)
            label.Position = UDim2.new(0.5, 0, 1, -math.floor(f.Size * 0.09))
            btn.Size = UDim2.fromOffset(f.Size, f.Size)
            iconBox.Size = UDim2.fromOffset(f.Size, f.Size * 0.7)
            buildIcon()
            local fx2, fy2 = f:GetPos()
            f:SetPos(fx2, fy2)
        end
        local function strength()                                         -- how bright the outline is: dimmed (no weapon) and switched-off toggles are fainter
            outline:SetStrength((f.Dim and 0.45 or 1) * ((o.Toggle and not f.State) and 0.6 or 1))
        end
        function f:SetState(on)                                           -- toggle buttons (SPEED ON / SPEED OFF): the label says it and the outline brightens
            f.State = on == true
            if o.Toggle then
                label.Text = f.State and (o.LabelOn or o.Title or "") or (o.LabelOff or o.Title or "")
                strength()
            end
        end
        function f:SetDim(b)                                              -- e.g. you do not hold the weapon right now
            f.Dim = b == true
            iconBox.GroupTransparency = b and 0.55 or 0
            label.TextTransparency = b and 0.45 or 0
            strength()
        end
        function f:Flash(ok)                                              -- green = fired, red = nothing happened (the water stands aside for a moment)
            outline:Flash(rgb(ok and T.good or T.bad))
            tween(outline.stroke, {Thickness = 4.5}, 0.08)
            if ok then                                                    -- a small kick, like a recoil
                tween(pressScale, {Scale = 1.08}, 0.06)
                task.delay(0.07, function() if btn.Parent then tween(pressScale, {Scale = 1}, 0.16) end end)
            end
            task.delay(0.35, function()
                if not btn.Parent then return end
                outline:Reset(); tween(outline.stroke, {Thickness = 2.5}, 0.2)
            end)
        end
        function f:Pulse()                                                -- ready again: the outline swells once
            if not btn.Parent then return end
            tween(outline.stroke, {Thickness = 4}, 0.12)
            task.delay(0.14, function() if btn.Parent then tween(outline.stroke, {Thickness = 2.5}, 0.3) end end)
        end
        function f:Cooldown(seconds)                                      -- the bar fills over the reload; the inside is only veiled very lightly
            if not seconds or seconds <= 0.05 then return end
            f.cdToken = (f.cdToken or 0) + 1
            local token = f.cdToken
            shade.BackgroundTransparency = 0.8
            tween(shade, {BackgroundTransparency = 1}, seconds)
            track.Visible = true
            fill.Size = UDim2.new(0, 0, 1, 0)
            tween(fill, {Size = UDim2.new(1, 0, 1, 0)}, seconds)
            task.delay(seconds, function()
                if f.cdToken ~= token or not btn.Parent then return end
                track.Visible = false
                f:Pulse()
            end)
        end
        function f:SetStatus(text, kind)                                  -- kind: "ready" | "wait" | "off"
            f.status = {text, kind}
            if f.resultUntil and os.clock() < f.resultUntil then return end            -- HIT / MISS is on show: the status comes back after it
            caption.Text = text or ""
            caption.Visible = text ~= nil and text ~= ""
            pip.Visible = kind ~= nil
            pip.BackgroundColor3 = kind == "ready" and rgb(T.good) or kind == "off" and rgb(T.bad) or Color3.fromRGB(170, 172, 180)
        end
        function f:Result(hit)                                            -- after a shot: HIT (green) / MISS (red) for a moment
            f.resultUntil = os.clock() + 1.4
            caption.Text = hit and "HIT" or "MISS"
            caption.Visible = true
            caption.TextColor3 = rgb(hit and T.good or T.bad)
            task.delay(1.45, function()
                if not btn.Parent then return end
                f.resultUntil = nil
                caption.TextColor3 = Color3.fromRGB(236, 237, 241)
                if f.status then f:SetStatus(f.status[1], f.status[2]) else caption.Visible = false end
            end)
        end
        local function ripple()                                           -- a ring that spreads from the middle on every tap
            local r = mk("Frame", {Name = "Ripple", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(f.Size * 0.45, f.Size * 0.45),
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 7}, btn)
            corner(r, "full")
            local st = mk("UIStroke", {Thickness = 2, Color = WHITE, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, r)
            tween(r, {Size = UDim2.fromOffset(f.Size * 1.05, f.Size * 1.05)}, 0.35)
            tween(st, {Transparency = 1}, 0.35)
            task.delay(0.4, function() pcall(function() r:Destroy() end) end)
        end
        function f:Destroy() f.anim = nil; pcall(function() btn:Destroy() end) end
        f:SetSize(f.Size)
        if o.Toggle then f:SetState(f.State) end

        -- press / drag: a tap fires OnPress, moving more than 8 px drags the button (unless it is locked)
        local pressed, dragging, cancelled, sx, sy, bx, by = false, false, false, 0, 0, 0, 0
        connect(btn.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                pressed, dragging, cancelled = true, false, false
                sx, sy = input.Position.X, input.Position.Y
                bx, by = btn.Position.X.Offset, btn.Position.Y.Offset
                tween(pressScale, {Scale = 0.92}, 0.08)
                ripple()
            end
        end)
        connect(UIS.InputChanged, function(input)
            if not pressed then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local dx, dy = input.Position.X - sx, input.Position.Y - sy
                if not dragging and not f.Locked and (dx * dx + dy * dy) > 64 then dragging = true end
                if f.Locked and (dx * dx + dy * dy) > 576 then cancelled = true end        -- locked: a long swipe is not a tap either
                if dragging then place(bx + dx, by + dy) end
            end
        end)
        connect(UIS.InputEnded, function(input)
            if not pressed then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                pressed = false
                tween(pressScale, {Scale = 1}, 0.12)
                if dragging then
                    dragging = false
                    if o.OnMoved then safe("float moved", o.OnMoved, f:GetPos()) end
                elseif o.OnPress and not cancelled then
                    local ok, ret = pcall(o.OnPress)
                    if not ok then onError("float press", ret); f:Flash(false)
                    elseif ret == "async" or o.Toggle then                    -- the caller flashes / cools down when it knows the result (toggles show their state instead)
                    else
                        if ret == nil then ret = true end
                        f:Flash(ret ~= false)
                        if type(o.Cooldown) == "number" and ret ~= false then f:Cooldown(o.Cooldown) end
                    end
                end
            end
        end)
        win.Floats[#win.Floats + 1] = f
        return f
    end


    if cfg.Headless then
        -- the pieces other window libraries borrow (wave skins, floating buttons, theme names): no window of its own
        function win:SetTheme(name) if THEMES[name] then themeName, T = name, THEMES[name] end end
        function win:GetTheme() return themeName end
        function win:Destroy()
            if not win.Alive then return end
            win.Alive = false
            for _, c in ipairs(win.Connections) do pcall(function() c:Disconnect() end) end
            win.Connections = {}
            skins = {}
            if floatGui then pcall(function() floatGui:Destroy() end) end
        end
        return win
    end

    ---------------------------------------------------------------------------------------------- window frame
    local TOP = 44
    local W, H, SIDE, bigW, bigH
    local function metrics()
        local vp = viewport()
        W = clamp(math.floor(vp.X * 0.52), 380, 680)
        H = clamp(math.floor(vp.Y * 0.88), 290, 480)
        SIDE = clamp(math.floor(W * 0.30), 120, 190)
        bigW, bigH = clamp(math.floor(vp.X * 0.92), 380, 980), clamp(math.floor(vp.Y * 0.92), 280, 640)
    end
    metrics()

    local gui = mk("ScreenGui", {Name = cfg.GuiName or "WraithUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true, DisplayOrder = 50}, nil)
    win.Gui = gui

    local main = mk("Frame", {Name = "Window", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
        BorderSizePixel = 0, ClipsDescendants = true}, gui)
    bind(main, "BackgroundColor3", "bg")
    corner(main, 12); stroke(main)
    win.Main = main

    -- header: logo, title, subtitle on the left; minimise / maximise / close on the right
    local top = mk("Frame", {Name = "Header", Size = UDim2.new(1, 0, 0, TOP), BackgroundTransparency = 1, BorderSizePixel = 0}, main)
    icon("spark", top, 22, "accent", UDim2.fromOffset(14, 11))
    local logo = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(44, 6), Size = UDim2.new(1, -230, 0, 18), Text = cfg.Title or "Hub",
        Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, top)
    bind(logo, "TextColor3", "text")
    local subtitle = mk("TextLabel", {Name = "Subtitle", BackgroundTransparency = 1, Position = UDim2.fromOffset(44, 24), Size = UDim2.new(1, -230, 0, 14), Text = cfg.Subtitle or "",
        Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, top)
    bind(subtitle, "TextColor3", "sub")

    local function ctlButton(kind, offsetFromRight, name)
        local b = mk("TextButton", {Name = name, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -offsetFromRight, 0.5, 0), Size = UDim2.fromOffset(30, 30),
            Text = "", AutoButtonColor = false, BorderSizePixel = 0}, top)
        bind(b, "BackgroundColor3", "row"); corner(b, 8); stroke(b)
        local sk = win:Skin(b, {Radius = 8, Look = "ui", Strength = 0.8})
        icon(kind, b, 16, "accent", UDim2.fromOffset(7, 7))
        return b, sk
    end
    local btnClose, skClose = ctlButton("close", 10, "Close")
    local btnMax, skMax = ctlButton("maximize", 46, "Maximize")
    local btnMin, skMin = ctlButton("minus", 82, "Minimize")

    -- body: sidebar + content
    local body = mk("Frame", {Name = "Body", Position = UDim2.new(0, 0, 0, TOP), Size = UDim2.new(1, 0, 1, -TOP), BackgroundTransparency = 1, BorderSizePixel = 0}, main)
    local side = mk("Frame", {Name = "Sidebar", Size = UDim2.new(0, SIDE, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0}, body)

    local searchBox = mk("Frame", {Name = "SearchBox", Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(1, -18, 0, 32), BorderSizePixel = 0}, side)
    bind(searchBox, "BackgroundColor3", "row"); corner(searchBox, 9); stroke(searchBox)
    icon("search", searchBox, 16, "accent", UDim2.fromOffset(9, 8))
    local search = mk("TextBox", {Name = "Search", BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), Text = "", PlaceholderText = "Search",
        ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, searchBox)
    bind(search, "TextColor3", "text"); bind(search, "PlaceholderColor3", "sub")

    local groupRow = mk("TextButton", {Name = "Group", Position = UDim2.new(0, 10, 0, 42), Size = UDim2.new(1, -18, 0, 24), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, BorderSizePixel = 0}, side)
    win:Skin(groupRow, {Radius = 8, Look = "ui", Strength = 0.4})
    local groupLabel = mk("TextLabel", {Name = "GroupName", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -30, 1, 0), Text = cfg.Group or "Menu",
        Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, groupRow)
    bind(groupLabel, "TextColor3", "sub")
    local chevUp = icon("chevron_up", groupRow, 14, "sub", UDim2.new(1, -18, 0.5, -7))
    local chevDown = icon("chevron_down", groupRow, 14, "sub", UDim2.new(1, -18, 0.5, -7))
    chevDown.Visible = false

    local tabList = mk("ScrollingFrame", {Name = "Tabs", Position = UDim2.new(0, 0, 0, 68), Size = UDim2.new(1, 0, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0}, side)
    mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, tabList)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8)}, tabList)
    local groupOpen = true
    connect(groupRow.MouseButton1Click, function()
        groupOpen = not groupOpen
        tabList.Visible = groupOpen
        chevUp.Visible = groupOpen
        chevDown.Visible = not groupOpen
    end)

    local content = mk("Frame", {Name = "Content", Position = UDim2.new(0, SIDE, 0, 0), Size = UDim2.new(1, -SIDE, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true,
        BorderSizePixel = 0}, body)
    local scroll = mk("ScrollingFrame", {Name = "Pages", Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(1, -12, 1, -8), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y}, content)
    bind(scroll, "ScrollBarImageColor3", "accent")
    mk("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
    mk("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, scroll)
    win.Scroll = scroll

    -- round avatar with a ring, floating over the top right of the content
    local avatar = mk("ImageLabel", {Name = "Avatar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, TOP - 4), Size = UDim2.fromOffset(38, 38),
        BorderSizePixel = 0, Image = "", ZIndex = 5}, main)
    bind(avatar, "BackgroundColor3", "row"); corner(avatar, "full")
    local avatarRing = stroke(avatar, "ring"); avatarRing.Thickness = 2

    -- the floating hub pill: shows while the window is hidden; tap = open, drag the handle = move it
    local pill = mk("Frame", {Name = "Pill", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(190, 36), BorderSizePixel = 0,
        Visible = false}, gui)
    bind(pill, "BackgroundColor3", "bg"); corner(pill, "full")
    local pillStroke = stroke(pill, "accent", 2)
    local pillSkin = win:Skin(pill, {Radius = 18, Look = "pill", Global = true})
    local pillHandle = mk("Frame", {Name = "Handle", Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, BorderSizePixel = 0}, pill)
    icon("move", pillHandle, 18, "accent", UDim2.fromOffset(4, 4))
    local pillOpen = mk("TextButton", {Name = "OpenButton", Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, BorderSizePixel = 0}, pill)
    icon("spark", pillOpen, 18, "accent", UDim2.fromOffset(2, 9))
    local pillText = mk("TextLabel", {Name = "PillTitle", BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -30, 1, 0), Text = cfg.Title or "Hub",
        Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, pillOpen)
    bind(pillText, "TextColor3", "text")

    ---------------------------------------------------------------------------------------------- dragging
    local function makeDraggable(handle, target, onEnd)
        local dragging, startX, startY, basePos = false, 0, 0, nil
        connect(handle.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, startX, startY, basePos = true, input.Position.X, input.Position.Y, target.Position
            end
        end)
        connect(UIS.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                target.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset + (input.Position.X - startX), basePos.Y.Scale, basePos.Y.Offset + (input.Position.Y - startY))
            end
        end)
        connect(UIS.InputEnded, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                if onEnd then onEnd() end
            end
        end)
    end
    makeDraggable(top, main)
    makeDraggable(side, main)
    makeDraggable(pillHandle, pill)

    ---------------------------------------------------------------------------------------------- tabs, search
    local currentTab
    local function selectTab(tab)
        currentTab = tab
        for _, t in ipairs(win.Tabs) do
            local on = t == tab
            t.page.Visible = on
            t.bar.Visible = on
            t.button.BackgroundTransparency = on and 0 or 1
            t.label.TextColor3 = rgb(on and T.text or T.sub)
        end
        scroll.CanvasPosition = Vector2.new(0, 0)
    end

    local function applySearch()
        local q = (search.Text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if q == "" then
            for _, t in ipairs(win.Tabs) do
                for _, e in ipairs(t.entries) do e.frame.Visible = true end
                t.heading.Visible = false
            end
            selectTab(currentTab or win.Tabs[1])
            return
        end
        for _, t in ipairs(win.Tabs) do
            local section, any = nil, false
            for _, e in ipairs(t.entries) do
                if e.isSection then
                    section = e; e.hits = 0; e.frame.Visible = false
                else
                    local hit = e.key:find(q, 1, true) ~= nil
                    e.frame.Visible = hit
                    if hit then any = true; if section then section.hits = section.hits + 1; section.frame.Visible = true end end
                end
            end
            t.page.Visible = any
            t.heading.Visible = any
            t.bar.Visible = false
            t.button.BackgroundTransparency = 1
        end
    end
    connect(search:GetPropertyChangedSignal("Text"), function() safe("search", applySearch) end)

    function win:Tab(name, iconKind)
        local tab = {name = name, entries = {}, order = 0}
        local button = mk("TextButton", {Name = name, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
            LayoutOrder = #win.Tabs + 1}, tabList)
        bind(button, "BackgroundColor3", "row"); corner(button, 9)
        local tabSkin = win:Skin(button, {Radius = 9, Look = "ui", Strength = 0.55, Active = function() return groupOpen end})
        local bar = mk("Frame", {Name = "Bar", Position = UDim2.new(0, 0, 0.5, -8), Size = UDim2.new(0, 3, 0, 16), BorderSizePixel = 0, Visible = false}, button)
        bind(bar, "BackgroundColor3", "accent"); corner(bar, "full")
        icon(iconKind or "dots", button, 16, "accent", UDim2.fromOffset(12, 7))
        local label = mk("TextLabel", {Name = "Name", BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), Text = name,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, button)
        bind(label, "TextColor3", "sub")
        local page = mk("Frame", {Name = name, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
            Visible = false, LayoutOrder = #win.Tabs + 1}, scroll)
        mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, page)
        local heading = mk("TextLabel", {Name = "SearchHeading", Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = string.upper(name), Font = Enum.Font.GothamBold,
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, LayoutOrder = 0}, page)
        bind(heading, "TextColor3", "accent")
        tab.button, tab.bar, tab.page, tab.heading, tab.label, tab.skin = button, bar, page, heading, label, tabSkin
        win.Tabs[#win.Tabs + 1] = tab
        connect(button.MouseButton1Click, function()
            if (search.Text or "") ~= "" then search.Text = "" end
            selectTab(tab)
        end)
        connect(button.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then tabSkin:Ripple(input.Position.X, input.Position.Y) end
        end)
        if #win.Tabs == 1 then selectTab(tab) end

        local function nextOrder() tab.order = tab.order + 1; return tab.order end
        local function register(frame, key, isSection)
            local entry = {frame = frame, key = (key or ""):lower(), isSection = isSection, hits = 0}
            tab.entries[#tab.entries + 1] = entry
            return entry
        end
        local function fire(cb, ...) if cb then safe("callback", cb, ...) end end

        -- a row: dark rounded card; text column on the left (wraps, so long descriptions never get cut), a control reserved on the right
        local function newRow(title, desc, controlW, o)
            o = o or {}
            local row = mk("Frame", {Size = UDim2.new(1, 0, 0, o.MinHeight or 40), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            bind(row, "BackgroundColor3", "row"); corner(row, 10); stroke(row)
            local rowSkin
            if o.Skin then rowSkin = win:Skin(row, {Radius = 10, Look = "ui", Strength = 0.5, Page = page}) end
            local col = mk("Frame", {Name = "Text", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, row)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, (controlW or 0) + 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}, col)
            mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, col)
            local t = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = title or "",
                Font = o.Bold and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1}, col)
            bind(t, "TextColor3", "text")
            if desc then
                local d = mk("TextLabel", {Name = "Desc", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = desc,
                    Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2}, col)
                bind(d, "TextColor3", "sub")
            end
            local entry = register(row, (title or "") .. " " .. (desc or ""))
            return row, t, rowSkin, entry
        end
        local function addElement(el, flag)
            win.Elements[#win.Elements + 1] = el
            if flag then win.Flags[flag] = el; el.Flag = flag end
            return el
        end
        local function hitOver(row, skin)
            local hit = mk("TextButton", {Name = "Hit", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 4}, row)
            if skin then
                connect(hit.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then skin:Ripple(input.Position.X, input.Position.Y) end
                end)
            end
            return hit
        end

        function tab:Section(title)
            local row, _, _, entry = newRow(title, nil, 54, {Bold = true, MinHeight = 38})
            entry.isSection = true
            return row
        end

        function tab:Paragraph(o) return tab:Label(((o.Title and o.Title ~= "") and (o.Title .. ": ") or "") .. (o.Desc or "")) end

        function tab:Label(text)
            local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            bind(row, "BackgroundColor3", "row"); corner(row, 10); stroke(row)
            mk("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, row)
            local lbl = mk("TextLabel", {Name = "Text", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text or "",
                Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, row)
            bind(lbl, "TextColor3", "sub")
            local entry = register(row, text)
            local el = {Value = text}
            function el:Set(v) el.Value = tostring(v); lbl.Text = el.Value; entry.key = el.Value:lower() end
            return el
        end

        function tab:Button(o)
            local row, _, rowSkin = newRow(o.Title, o.Desc, 66, {Skin = true})
            local pill = mk("Frame", {Name = "RunPill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(52, 24), BorderSizePixel = 0}, row)
            bind(pill, "BackgroundColor3", "accent"); corner(pill, 7)
            win:Skin(pill, {Radius = 7, Look = "pill", Page = page})
            local pl = mk("TextLabel", {Name = "PillText", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = o.Label or "Run", Font = Enum.Font.GothamBold, TextSize = 11,
                TextStrokeTransparency = 0.6, ZIndex = 3}, pill)
            bind(pl, "TextColor3", "text")
            local hit = hitOver(row, rowSkin)
            connect(hit.MouseButton1Click, function()
                tween(row, {BackgroundColor3 = rgb(T.rowHover)}, 0.08)
                task.delay(0.12, function() if row.Parent then tween(row, {BackgroundColor3 = rgb(T.row)}, 0.15) end end)
                fire(o.Callback)
            end)
            local el = {Value = nil, Click = function() fire(o.Callback) end}
            function el:Set() end
            return addElement(el)
        end

        function tab:Toggle(o)
            local row = newRow(o.Title, o.Desc, 56)
            local sw = mk("Frame", {Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(44, 24), BorderSizePixel = 0}, row)
            corner(sw, "full")
            local swStroke = mk("UIStroke", {Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, sw)
            bind(swStroke, "Color", "stroke")
            local knob = mk("Frame", {Name = "Knob", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18), BorderSizePixel = 0}, sw)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); corner(knob, "full")
            local hit = hitOver(row)
            local el = {Value = o.Default == true}
            local function render()
                tween(sw, {BackgroundColor3 = rgb(el.Value and T.accent or T.off)}, 0.12)
                tween(knob, {Position = UDim2.new(0, el.Value and 23 or 3, 0.5, 0)}, 0.12)
            end
            el.render = render
            function el:Set(v, silent)
                v = v == true
                local changed = v ~= el.Value
                el.Value = v; render()
                if not silent and (changed or o.FireSame) then fire(o.Callback, v) end
            end
            sw.BackgroundColor3 = rgb(el.Value and T.accent or T.off)
            knob.Position = UDim2.new(0, el.Value and 23 or 3, 0.5, 0)
            connect(hit.MouseButton1Click, function() el:Set(not el.Value) end)
            addElement(el, o.Flag)
            if el.Value and o.Callback and not o.NoInitialCallback then fire(o.Callback, true) end
            return el
        end

        function tab:Slider(o)
            local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
            local row = mk("Frame", {Name = "SliderRow", Size = UDim2.new(1, 0, 0, 58), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            bind(row, "BackgroundColor3", "row"); corner(row, 10); stroke(row)
            register(row, o.Title)
            local col = mk("Frame", {Name = "Text", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, row)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 104), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 30)}, col)
            local t = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Title or "",
                Font = Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, col)
            bind(t, "TextColor3", "text")
            local valueLabel = mk("TextLabel", {Name = "Value", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.fromOffset(92, 18),
                Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Text = ""}, row)
            bind(valueLabel, "TextColor3", "accent2")
            local track = mk("Frame", {Name = "Track", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(1, -28, 0, 6), BorderSizePixel = 0}, row)
            bind(track, "BackgroundColor3", "off"); corner(track, "full")
            local fill = mk("Frame", {Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0}, track)
            bind(fill, "BackgroundColor3", "accent"); corner(fill, "full")
            local knob = mk("Frame", {Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0}, track)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); corner(knob, "full")
            local hit = mk("TextButton", {Name = "Hit", AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 34), Text = "",
                AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 4}, row)
            local el = {Value = o.Default or min}
            local decimals = step < 1 and (step < 0.1 and 2 or 1) or 0
            local function snap(v)
                v = clamp(v, min, max)
                v = min + math.floor((v - min) / step + 0.5) * step
                return clamp(tonumber(string.format("%." .. decimals .. "f", v)), min, max)
            end
            local function render()
                local f = max > min and (el.Value - min) / (max - min) or 0
                fill.Size = UDim2.new(f, 0, 1, 0)
                knob.Position = UDim2.new(f, 0, 0.5, 0)
                valueLabel.Text = string.format("%." .. decimals .. "f", el.Value) .. (o.Suffix or "")
            end
            el.Value = snap(el.Value); render()
            function el:Set(v, silent)
                if type(v) ~= "number" then return end
                v = snap(v)
                local changed = v ~= el.Value
                el.Value = v; render()
                if not silent and changed then fire(o.Callback, v) end
            end
            local dragging = false
            local function fromX(x)
                local w = track.AbsoluteSize.X
                el:Set(min + clamp((x - track.AbsolutePosition.X) / (w > 0 and w or 1), 0, 1) * (max - min))
            end
            connect(hit.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true; scroll.ScrollingEnabled = false; fromX(input.Position.X)
                end
            end)
            connect(UIS.InputChanged, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromX(input.Position.X) end
            end)
            connect(UIS.InputEnded, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                    dragging = false; scroll.ScrollingEnabled = true
                end
            end)
            addElement(el, o.Flag)
            return el
        end

        function tab:Dropdown(o)
            local holder = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, holder)
            -- the head stacks the title over the current value, so a long value never gets cut on a narrow phone window
            local head = mk("Frame", {Name = "Head", Size = UDim2.new(1, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = 1}, holder)
            bind(head, "BackgroundColor3", "row"); corner(head, 10); stroke(head)
            local col = mk("Frame", {Name = "Text", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, head)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 40), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9)}, col)
            mk("UIListLayout", {Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder}, col)
            local title = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Title or "",
                Font = Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1}, col)
            bind(title, "TextColor3", "text")
            local current = mk("TextLabel", {Name = "Value", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "",
                Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2}, col)
            bind(current, "TextColor3", "accent2")
            local chevron = icon("chevron_down", head, 14, "sub", UDim2.new(1, -26, 0.5, -7))
            local hit = mk("TextButton", {Name = "Hit", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 4}, head)
            local list = mk("Frame", {Name = "Options", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
                Visible = false, LayoutOrder = 2}, holder)
            mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, list)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 10)}, list)
            register(holder, (o.Title or "") .. " " .. table.concat(o.Values or {}, " "))
            local el = {Value = o.Default, Values = o.Values or {}}
            local buttons = {}
            local function paint()
                current.Text = tostring(el.Value or "-")
                for _, b in ipairs(buttons) do
                    b.label.TextColor3 = rgb(b.value == el.Value and T.accent2 or T.text)
                end
            end
            local function rebuild()
                for _, b in ipairs(buttons) do b.inst:Destroy() end
                buttons = {}
                for i, v in ipairs(el.Values) do
                    local b = mk("TextButton", {Name = "Option", Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i}, list)
                    bind(b, "BackgroundColor3", "rowHover"); corner(b, 8)
                    win:Skin(b, {Radius = 8, Look = "ui", Page = page, Active = function() return list.Visible end})
                    local lb = mk("TextLabel", {Name = "Text", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -16, 1, 0), Text = tostring(v),
                        Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3}, b)
                    buttons[#buttons + 1] = {inst = b, value = v, label = lb}
                    connect(b.MouseButton1Click, function() el:Set(v); list.Visible = false; chevron.Rotation = 0 end)
                end
                paint()
            end
            function el:Set(v, silent)
                local changed = v ~= el.Value
                el.Value = v; paint()
                if not silent and changed then fire(o.Callback, v) end
            end
            function el:SetValues(values) el.Values = values; rebuild() end
            if el.Value == nil then el.Value = el.Values[1] end
            rebuild()
            connect(hit.MouseButton1Click, function() list.Visible = not list.Visible; chevron.Rotation = list.Visible and 180 or 0 end)
            addElement(el, o.Flag)
            return el
        end

        -- a text box on the right of the row (the WindUI menu has one too); Callback(text) runs when the box loses focus with a new text
        function tab:Input(o)
            local row = newRow(o.Title, o.Desc, 150, {})
            local box = mk("TextBox", {Name = "Box", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(136, 26), Text = o.Default or "",
                PlaceholderText = o.Placeholder or "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12, BorderSizePixel = 0, TextTruncate = Enum.TextTruncate.AtEnd}, row)
            bind(box, "BackgroundColor3", "rowHover"); bind(box, "TextColor3", "text"); bind(box, "PlaceholderColor3", "sub"); corner(box, 7); stroke(box)
            local el = {Value = o.Default or "", Title = o.Title}
            function el:Set(v, silent)
                v = tostring(v or "")
                el.Value = v
                box.Text = v
                if not silent and o.Callback then fire(o.Callback, v) end
            end
            connect(box.FocusLost, function()
                local v = box.Text
                if v ~= el.Value then
                    el.Value = v
                    if o.Callback then fire(o.Callback, v) end
                end
            end)
            addElement(el, o.Flag)
            return el
        end

        function tab:Keybind(o)
            local row, _, rowSkin = newRow(o.Title, o.Desc, 100, {})
            local btn = mk("TextButton", {Name = "Key", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(84, 26), Text = "",
                AutoButtonColor = false, BorderSizePixel = 0}, row)
            bind(btn, "BackgroundColor3", "rowHover"); corner(btn, 7); stroke(btn)
            win:Skin(btn, {Radius = 7, Look = "ui", Page = page})
            local keyText = mk("TextLabel", {Name = "KeyText", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", Font = Enum.Font.GothamBold, TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3}, btn)
            bind(keyText, "TextColor3", "accent2")
            local el = {Value = o.Default or "None", Down = false}
            local capturing = false
            local function nameOf(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then return input.KeyCode.Name end
                if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MouseButton2" end
                if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MouseButton3" end
                return nil
            end
            function el:Set(v, silent)
                el.Value = type(v) == "string" and v or "None"
                keyText.Text = el.Value
                if not silent and o.Changed then fire(o.Changed, el.Value) end
            end
            keyText.Text = el.Value
            connect(btn.MouseButton1Click, function() capturing = true; keyText.Text = "press a key" end)
            connect(UIS.InputBegan, function(input, processed)
                local n = nameOf(input)
                if not n then return end
                if capturing then
                    capturing = false
                    el:Set(n == "Escape" and "None" or n)
                    return
                end
                if n == el.Value and (not processed or o.IgnoreProcessed) then
                    el.Down = true
                    if o.Callback then fire(o.Callback) end
                end
            end)
            connect(UIS.InputEnded, function(input)
                if nameOf(input) == el.Value then el.Down = false end
            end)
            addElement(el, o.Flag)
            return el
        end

        return tab
    end

    ---------------------------------------------------------------------------------------------- notifications
    local toasts = mk("Frame", {Name = "Toasts", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 10, 0, 58), Size = UDim2.new(0, 200, 1, -70),
        BackgroundTransparency = 1, BorderSizePixel = 0}, gui)
    mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Left}, toasts)
    local toastCount, liveToasts = 0, {}
    -- what the WindUI window offers on top (the classic menu answers them simply, so a hub can call them on either)
    local function plain(t) return (tostring(t or ""):gsub("<[^>]+>", "")) end
    function win:Popup(o) win:Notify{Title = plain(o.Title), Content = plain(o.Content), Type = "info", Duration = 6} end
    function win:Dialog(o) win:Notify{Title = plain(o.Title), Content = plain(o.Content), Type = "info", Duration = 8} end
    function win:SetWater() end
    function win:GetWater() return {Enabled = false, Strength = 0, Speed = 0, Layers = 0} end
    function win:SetFont() return false end

    function win:Notify(o)
        if not win.Alive then return end
        toastCount = toastCount + 1
        local tw = clamp(math.floor(viewport().X * 0.235), 180, 280)
        toasts.Size = UDim2.new(0, tw, 1, -70)
        local kind = o.Type == "good" and "good" or o.Type == "warn" and "warn" or o.Type == "bad" and "bad" or "accent"
        local card = mk("Frame", {Name = "Toast", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, BackgroundTransparency = 1,
            LayoutOrder = toastCount}, toasts)
        bind(card, "BackgroundColor3", "row"); corner(card, 10)
        local edge = stroke(card, kind)
        local bar = mk("Frame", {Name = "Bar", Position = UDim2.fromOffset(7, 7), Size = UDim2.new(0, 3, 1, -14), BorderSizePixel = 0}, card)
        bind(bar, "BackgroundColor3", kind); corner(bar, "full")
        local col = mk("Frame", {Name = "Text", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, card)
        mk("UIPadding", {PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, col)
        mk("UIListLayout", {Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder}, col)
        local t = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Title or "",
            Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1}, col)
        bind(t, "TextColor3", "text")
        local c
        if o.Content then
            c = mk("TextLabel", {Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Content, Font = Enum.Font.Gotham,
                TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2}, col)
            bind(c, "TextColor3", "sub")
        end
        liveToasts[#liveToasts + 1] = card
        while #liveToasts > 3 do                                           -- never more than three at once
            local old = table.remove(liveToasts, 1)
            if old.Parent then old:Destroy() end
        end
        tween(card, {BackgroundTransparency = 0}, 0.2)
        task.delay(o.Duration or 3, function()
            if not card.Parent then return end
            tween(card, {BackgroundTransparency = 1}, 0.25)
            tween(t, {TextTransparency = 1}, 0.25)
            if c then tween(c, {TextTransparency = 1}, 0.25) end
            tween(bar, {BackgroundTransparency = 1}, 0.25)
            tween(edge, {Transparency = 1}, 0.25)
            task.delay(0.3, function()
                if card.Parent then card:Destroy() end
                for i, x in ipairs(liveToasts) do if x == card then table.remove(liveToasts, i) break end end
            end)
        end)
    end

    ---------------------------------------------------------------------------------------------- window state
    local expanded, minimized = false, false
    local function layoutSize()
        local w, h = expanded and bigW or W, expanded and bigH or H
        if minimized then h = TOP end
        local keep = main.Position
        main.Size = UDim2.fromOffset(w, h)
        body.Visible = not minimized
        side.Size = UDim2.new(0, SIDE, 1, 0)
        content.Position = UDim2.new(0, SIDE, 0, 0)
        content.Size = UDim2.new(1, -SIDE, 1, 0)
        avatar.Visible = not minimized
        return keep
    end
    local function recenter()
        local w, h = main.Size.X.Offset, main.Size.Y.Offset
        main.Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2)
    end
    function win:Relayout()
        metrics()
        layoutSize()
        recenter()
    end
    function win:SetVisible(v)
        main.Visible = v
        pill.Visible = not v
    end
    function win:Toggle() win:SetVisible(not main.Visible) end
    function win:Minimize() minimized = not minimized; layoutSize() end
    function win:Maximize() expanded = not expanded; if expanded then minimized = false end; layoutSize(); recenter() end
    connect(btnClose.MouseButton1Click, function()
        win:SetVisible(false)
        win:Notify{Title = "Menu hidden", Content = "Tap the pill at the top" .. (win.ToggleKey and (" or press " .. win.ToggleKey.Name) or "") .. " to open it again.", Duration = 3}
    end)
    connect(btnMin.MouseButton1Click, function() win:Minimize() end)
    connect(btnMax.MouseButton1Click, function() win:Maximize() end)
    connect(pillOpen.MouseButton1Click, function() win:SetVisible(true) end)
    for _, pair in ipairs({{btnClose, skClose}, {btnMax, skMax}, {btnMin, skMin}, {pillOpen, pillSkin}}) do
        connect(pair[1].InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pair[2]:Ripple(input.Position.X, input.Position.Y) end
        end)
    end
    win.ToggleKey = cfg.ToggleKey
    connect(UIS.InputBegan, function(input, processed)
        if not processed and win.ToggleKey and input.KeyCode == win.ToggleKey then win:Toggle() end
    end)
    do   -- a phone turned sideways changes the viewport: keep the window inside it
        local cam = workspace.CurrentCamera
        if cam then connect(cam:GetPropertyChangedSignal("ViewportSize"), function() safe("viewport", function() win:Relayout() end) end) end
    end

    function win:SetTheme(name)
        if not THEMES[name] then return end
        themeName, T = name, THEMES[name]
        for _, b in ipairs(themed) do
            if b[1].Parent ~= nil or b[1] == gui then pcall(function() b[1][b[2]] = rgb(T[b[3]]) end) end
        end
        for _, el in ipairs(win.Elements) do if el.render then el.render() end end
        if currentTab then selectTab(currentTab) end
    end
    function win:GetTheme() return themeName end
    function win:SelectTab(name) for _, t in ipairs(win.Tabs) do if t.name == name then selectTab(t) end end end

    function win:SetAvatar(userId)
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and type(img) == "string" and img ~= "" then avatar.Image = img end
        end)
    end

    function win:GetState()
        local out = {}
        for flag, el in pairs(win.Flags) do out[flag] = el.Value end
        return out
    end
    function win:SetState(state, silent)
        if type(state) ~= "table" then return end
        for flag, v in pairs(state) do
            local el = win.Flags[flag]
            if el and el.Set and type(v) == type(el.Value) then el:Set(v, silent) end
        end
    end

    function win:Destroy()
        if not win.Alive then return end
        win.Alive = false
        for _, c in ipairs(win.Connections) do pcall(function() c:Disconnect() end) end
        win.Connections = {}
        skins = {}
        pcall(function() gui:Destroy() end)
        if floatGui then pcall(function() floatGui:Destroy() end) end
    end

    layoutSize()
    gui.Parent = cfg.Parent
    return win
end

return UILib

end)()
local WindAdapter = (function()

local Adapter = {}

Adapter.ThemeNames = {"Dark", "Crimson", "Violet", "Sky", "Emerald", "Amber", "Midnight", "Rose", "Monokai Pro", "Cotton Candy"}
local OLD_THEMES = {Ocean = "Sky", Gold = "Amber"}                       -- names the classic menu used

-- A hub can add themes of its own (hex strings, WindUI's theme fields: Accent, Dialog, Outline, Text, Placeholder, Background, Button, Icon, Toggle, Slider, Checkbox,
-- Primary, ElementBackground ...; numbers such as ElementBackgroundTransparency pass through). Call before Adapter.new; the names join Adapter.ThemeNames.
Adapter.ExtraThemes = {}
function Adapter.addThemes(list)
    for _, t in ipairs(list) do
        local known = false
        for _, n in ipairs(Adapter.ThemeNames) do if n == t.Name then known = true end end
        if not known then Adapter.ThemeNames[#Adapter.ThemeNames + 1] = t.Name end
        Adapter.ExtraThemes[t.Name] = t
    end
end

-- The Wraith white-water look the TSB hubs share: two themes (the first is the default: white controls on a dark slate window; the second is a light one), the water tint that suits
-- a theme (white on a white window would not show), and a short list of fonts. A hub registers the themes with Adapter.addThemes(Adapter.WraithThemes).
Adapter.WraithThemes = {
    {Name = "Wraith White", Accent = "#10141b", Dialog = "#121822", Outline = "#f2f6fb", Text = "#f5f8fc", Placeholder = "#9aa6b5", Background = "#0b0f15", Button = "#3a4656", Icon = "#e6edf6",
     Toggle = "#e9f1fb", Slider = "#dfe9f5", Checkbox = "#e9f1fb", Primary = "#f2f7ff", SliderIcon = "#c9d4e2", PanelBackground = "#ffffff", PanelBackgroundTransparency = 0.95,
     LabelBackground = "#000000", LabelBackgroundTransparency = 0.8, ElementBackground = "#1a212c", ElementBackgroundTransparency = 0},
    {Name = "Wraith Pearl", Accent = "#e8edf4", Dialog = "#f1f4f8", Outline = "#ffffff", Text = "#101826", Placeholder = "#5b6778", Background = "#e9eef5", Button = "#c3ccd8", Icon = "#3b4a5e",
     Toggle = "#5b7fa6", Slider = "#5b7fa6", Checkbox = "#5b7fa6", Primary = "#4a6f99", SliderIcon = "#5b6778", PanelBackground = "#ffffff", PanelBackgroundTransparency = 0.6,
     LabelBackground = "#ffffff", LabelBackgroundTransparency = 0.5, ElementBackground = "#ffffff", ElementBackgroundTransparency = 0},
}
function Adapter.waterTint(theme) return theme == "Wraith Pearl" and Color3.fromRGB(110, 130, 158) or Color3.fromRGB(255, 255, 255) end
Adapter.Fonts = {Default = "rbxassetid://12187365364", Gotham = "Gotham", Code = "Code", Fredoka = "FredokaOne", Arcade = "Arcade"}
Adapter.FontNames = {"Default", "Gotham", "Code", "Fredoka", "Arcade"}
function Adapter.fontFamily(name)                                          -- the font family WindUI:SetFont wants, or nil
    local f = Adapter.Fonts[name]
    if not f or f:find("^rbxassetid://") then return f end
    local ok, family = pcall(function() return Font.fromEnum(Enum.Font[f]).Family end)
    return ok and family or nil
end

local ICONS = {grid = "layout-grid", eye = "eye", crosshair = "crosshair", bolt = "zap", user = "user", gear = "settings", terminal = "terminal", dots = "ellipsis",
    knife = "sword", pistol = "crosshair", spark = "sparkles", search = "search"}
local TAB_COLORS = {grid = "#7775F2", eye = "#10C550", crosshair = "#EF4F1D", bolt = "#257AF7", user = "#ECA201", gear = "#83889E", terminal = "#83889E"}
local NOTE_ICONS = {good = "check", warn = "triangle-alert", bad = "circle-x", info = "info"}

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

function Adapter.themeFor(name)
    name = OLD_THEMES[name] or name
    for _, n in ipairs(Adapter.ThemeNames) do if n == name then return n end end
    return "Dark"
end

-- tiny string hash for cache file names
local function hashOf(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end

local VIDEO_EXT = {mp4 = true, webm = true, mov = true}
local IMAGE_EXT = {png = true, jpg = true, jpeg = true, webp = true}
local function extensionOf(url)
    local path = url:match("^([^?#]+)") or url
    local e = path:match("%.(%w+)$")
    return e and e:lower() or nil
end

-- the hub asks for a link; a pixabay.com video PAGE is turned into the file link inside it (best effort: the site may refuse automated requests)
local function pickPixabayFile(html)
    local found = {}
    for url in html:gmatch("https://cdn%.pixabay%.com/[%w%-%._/%%]+%.mp4") do found[#found + 1] = url end
    for _, size in ipairs({"_medium", "_small", "_large", "_tiny"}) do
        for _, url in ipairs(found) do if url:find(size, 1, true) then return url end end
    end
    return found[1]
end

local function build(win, WindUI, UILib, cfg)
    local UIS = game:GetService("UserInputService")
    local coreDestroy = win.Destroy
    local connect, safe = win.Connect, win.Safe
    win.Flags, win.Tabs, win.Elements = {}, {}, {}
    win.Backend = "WindUI"
    local onError = cfg.OnError or function() end

    local function viewport()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize
        if not vp or vp.X < 100 then return Vector2.new(1280, 720) end
        return vp
    end

    ---------------------------------------------------------------------------------------------- the window
    -- Small and clean, like the reference: Mac-style close button, no search bar / version tag / user card / minimise / fullscreen, tabs straight in the sidebar.
    local themeName = Adapter.themeFor(cfg.Theme)
    local vp = viewport()
    local size = UDim2.fromOffset(clamp(math.floor(vp.X * 0.6), 440, 560), clamp(vp.Y - 70, 250, 380))      -- WindUI scales the window down by itself if it does not fit
    if type(cfg.Size) == "table" then size = UDim2.fromOffset(clamp(cfg.Size[1], 380, math.max(380, vp.X - 40)), clamp(cfg.Size[2], 250, math.max(250, vp.Y - 60))) end
    win.Tickers = win.Tickers or {}
    local glassTouched = {}

    -- frosted cards: every theme's element background becomes translucent grey (the backdrop shows through), and each card fades out towards the right
    local function glass(name)
        local t = WindUI.Themes and WindUI.Themes[name]
        if t and not glassTouched[name] then
            glassTouched[name] = true
            t.ElementBackgroundTransparency = math.max(t.ElementBackgroundTransparency or 0, 0.42)
        end
    end
    glass(themeName)

    for name, t in pairs(Adapter.ExtraThemes) do
        local built = {}
        for k, v in pairs(t) do built[k] = (type(v) == "string" and k ~= "Name") and Color3.fromHex(v) or v end
        pcall(function() WindUI:AddTheme(built) end)
    end
    glass(themeName)
    local Window = WindUI:CreateWindow{
        Title = cfg.Title or "Hub", Author = cfg.Subtitle, Folder = cfg.Folder or "WraithsHub", Icon = cfg.WindowIcon or "swords", NewElements = true, Theme = themeName,
        Size = size, MinSize = Vector2.new(380, 230), SideBarWidth = cfg.SideBarWidth or (vp.X < 900 and 124 or 150), HideSearchBar = not cfg.SearchBar,
        Transparent = true, HidePanelBackground = true, ElementsRadius = 14, Radius = 16, ToggleKey = cfg.ToggleKey,
        Topbar = {Height = 38, ButtonsType = cfg.TopbarStyle or "Mac"},
        User = {Enabled = cfg.UserCard == true, Anonymous = false},
        OpenButton = {Title = cfg.Title or "Hub", CornerRadius = UDim.new(1, 0), StrokeThickness = 2, Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.7,
            Color = ColorSequence.new(Color3.fromHex((cfg.OpenColors or {})[1] or "#9aa0b4"), Color3.fromHex((cfg.OpenColors or {})[2] or "#e84a8a"))},
    }
    win.Window, win.WindUI = Window, WindUI
    if cfg.Parent and WindUI.SetParent then pcall(function() WindUI:SetParent(cfg.Parent) end) end
    -- WindUI's own topbar "x" does not hide the window: it opens a confirmation dialog ("you will not be able to open it again") and, if confirmed
    -- (or if IgnoreAlerts is set), permanently DESTROYS the window - there is no built-in way to make it a reversible hide. So all three native buttons
    -- are hidden and replaced with one small dot of our own that calls Window:Close() (the *method*, not the topbar button): that hides the window and
    -- leaves WindUI's own open button on screen to bring it back, exactly like tapping the pill in the Classic menu or pressing the toggle key.
    pcall(function() Window:DisableTopbarButtons{"Close", "Minimize", "Fullscreen"} end)
    if cfg.TopbarStyle == "Default" then                                  -- icon buttons: our own "x" that HIDES the window (WindUI's would destroy it)
        pcall(function() Window:CreateTopbarButton("WraithClose", "x", function() Window:Close() end, 999) end)
    else
        pcall(function()
            local right = Window.UIElements.Main.Main.Topbar.Right
            local dot = Instance.new("TextButton")
            dot.Name = "WraithClose"
            dot.Text = ""
            dot.AutoButtonColor = false
            dot.BackgroundColor3 = Color3.fromHex("#F4695F")
            dot.BorderSizePixel = 0
            dot.Size = UDim2.fromOffset(14, 14)
            dot.LayoutOrder = 999
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = dot
            dot.Parent = right
            connect(dot.MouseButton1Click, function() Window:Close() end)
        end)
    end
    -- a small label next to the title (a version, a live ping); the result has :Set(title, hexColor) to change it later
    function win:Tag(o)
        o = o or {}
        local ok, tagObj = pcall(function() return Window:Tag{Title = o.Title or "", Color = Color3.fromHex(o.Color or "#ffffff")} end)
        local handle = {}
        function handle:Set(title, color)
            if not (ok and tagObj) then return end
            if title ~= nil then pcall(function() tagObj:SetTitle(tostring(title)) end) end
            if color then pcall(function() tagObj:SetColor(Color3.fromHex(color)) end) end
        end
        return handle
    end
    if type(cfg.Tag) == "table" then win:Tag(cfg.Tag) end
    for i, b in ipairs(type(cfg.TopbarButtons) == "table" and cfg.TopbarButtons or {}) do
        pcall(function() Window:CreateTopbarButton(b.Name or ("Button" .. i), b.Icon or "circle", function() safe("topbar " .. tostring(b.Name), b.Callback) end, 900 + i) end)
    end
    pcall(function() Window:SetUIScale(clamp(cfg.Scale or 0.9, 0.55, 1.2)) end)
    if cfg.Mono ~= false then                                                -- the reference menu uses a monospace face
        pcall(function()
            local family = Font.fromEnum(Enum.Font.Code).Family
            if type(family) == "string" and family ~= "" then WindUI:SetFont(family) end
        end)
    end
    pcall(function() WindUI:SetTheme(themeName) end)                           -- (re-applies the theme with the frosted element background)

    -- the hub reads win.Main.Visible and sets win.ToggleKey, like with the classic menu
    local toggleKey = cfg.ToggleKey
    local mainProxy = setmetatable({}, {__index = function(_, k) if k == "Visible" then return not Window.Closed end end})
    setmetatable(win, {
        __index = function(_, k)
            if k == "Main" then return mainProxy elseif k == "ToggleKey" then return toggleKey end
        end,
        __newindex = function(t, k, v)
            if k == "ToggleKey" then
                toggleKey = v
                pcall(function() Window:SetToggleKey(v) end)
            else rawset(t, k, v) end
        end,
    })

    ---------------------------------------------------------------------------------------------- elements
    local function addElement(el, flag)
        win.Elements[#win.Elements + 1] = el
        if flag then win.Flags[flag] = el; el.Flag = flag end
        return el
    end
    local function fire(cb, ...) if cb then safe("callback", cb, ...) end end

    local FADE = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.12), NumberSequenceKeypoint.new(1, 0.78)})
    local function decorate(p, ui)                                           -- a card fades out to the right
        pcall(function()
            local host = p.ElementFrame
            if not (host and host:IsA("GuiObject")) then return end
            local g = Instance.new("UIGradient")
            g.Name = "WraithFade"
            g.Transparency = FADE
            g.Parent = host
        end)
    end

    local function unregister(el)
        for i = #win.Elements, 1, -1 do if win.Elements[i] == el then table.remove(win.Elements, i) end end
        if el.Flag and win.Flags[el.Flag] == el then win.Flags[el.Flag] = nil end
    end

    -- The element constructors of a tab AND of a group (a WindUI Section that holds elements and folds open / shut). `ui` is the WindUI object the elements are
    -- built into; `page` is the tab's scrolling container (a button's water outline only runs while that page is showing).
    local attach
    function attach(host, ui, page)
        host.items = {}
        local function keep(el)                                                  -- what a group holds, so Clear() / Destroy() can take it out again
            host.items[#host.items + 1] = el
            if el.Ui == nil then return el end
            function el:SetVisible(v) pcall(function() el.Ui.ElementFrame.Visible = v ~= false end) end
            function el:Destroy()
                pcall(function() el.Ui:Destroy() end)
                unregister(el)
            end
            return el
        end
        local function addEl(el, flag) return keep(addElement(el, flag)) end

        function host:Section(title)
            return ui:Section{Title = title, TextSize = 18}
        end

        function host:Label(text)                                          -- body text, the way the official WindUI example writes it: a Section with a small, softer title
            local el = {Value = tostring(text or "")}
            local p = ui:Section{Title = el.Value ~= "" and el.Value or " ", TextSize = 14, TextTransparency = 0.25, FontWeight = Enum.FontWeight.Medium}
            el.Ui = p
            function el:Set(v)
                v = tostring(v)
                if v == el.Value then return end
                el.Value = v
                pcall(function() p:SetTitle(v ~= "" and v or " ") end)
            end
            return keep(el)
        end

        -- a card with a title, a body text and an icon on the left (the way the reference hub opens each tab)
        function host:Paragraph(o)
            local el = {Title = o.Title, Value = o.Desc or ""}
            local p = ui:Paragraph{Title = o.Title or "", Desc = o.Desc, Image = o.Image, ImageSize = o.ImageSize or 20, Color = o.Color}
            function el:Set(v)
                v = tostring(v or "")
                if v == el.Value then return end
                el.Value = v
                pcall(function() p:SetDesc(v) end)
            end
            el.Ui = p
            decorate(p, ui)
            return addEl(el)
        end

        function host:Button(o)
            local el = {Value = nil, Title = o.Title, Click = function() fire(o.Callback) end}
            el.Ui = ui:Button{Title = o.Title or "Button", Desc = o.Desc, Icon = "mouse-pointer-click", Callback = function() fire(o.Callback) end}
            decorate(el.Ui, ui)
            function el:Set() end
            -- the grey water flows round the button's OUTLINE (nothing is drawn inside it); it runs while this tab is open. `Outline = false` skips it (long lists of buttons)
            if o.Outline ~= false then
                local okSkin, skinErr = pcall(function()
                    local frame = el.Ui.ElementFrame
                    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = frame
                    el.Outline = win:Outline(frame, {Thickness = 1.5, Glow = false, Page = page})
                end)
                if not okSkin then onError("button outline", skinErr) end
            end
            return addEl(el)
        end

        function host:Toggle(o)
            local el = {Value = o.Default == true}
            local p = ui:Toggle{Title = o.Title or "Toggle", Desc = o.Desc, Value = el.Value, Callback = function(v)
                if v == el.Value then return end                      -- WindUI also reports the value we just set ourselves
                el.Value = v == true
                fire(o.Callback, el.Value)
            end}
            function el:Set(v, silent)
                v = v == true
                local changed = v ~= el.Value
                el.Value = v
                pcall(function() p:Set(v) end)
                if not silent and (changed or o.FireSame) then fire(o.Callback, v) end
            end
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            addEl(el, o.Flag)
            if el.Value and o.Callback and not o.NoInitialCallback then fire(o.Callback, true) end
            return el
        end

        function host:Slider(o)
            local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
            local decimals = step < 1 and (step < 0.1 and 2 or 1) or 0
            local function snap(v)
                v = clamp(v, min, max)
                v = min + math.floor((v - min) / step + 0.5) * step
                return clamp(tonumber(string.format("%." .. decimals .. "f", v)), min, max)
            end
            local el = {Value = snap(o.Default or min)}
            local unit = o.Suffix and o.Suffix:match("%S") and o.Suffix:gsub("^%s+", "") or nil
            local p = ui:Slider{Title = o.Title or "Slider", Desc = unit and ("in " .. unit) or nil, Step = step, IsTooltip = true,
                Value = {Min = min, Max = max, Default = el.Value}, Callback = function(v)
                    if type(v) ~= "number" then return end
                    v = snap(v)
                    if v == el.Value then return end
                    el.Value = v
                    fire(o.Callback, v)
                end}
            function el:Set(v, silent)
                if type(v) ~= "number" then return end
                v = snap(v)
                local changed = v ~= el.Value
                el.Value = v
                pcall(function() p:Set(v) end)
                if not silent and changed then fire(o.Callback, v) end
            end
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            return addEl(el, o.Flag)
        end

        function host:Dropdown(o)
            local el = {Value = o.Default, Values = o.Values or {}}
            if el.Value == nil then el.Value = el.Values[1] end
            local p
            p = ui:Dropdown{Title = o.Title or "Dropdown", Desc = o.Desc, Values = el.Values, Value = el.Value, AllowNone = false,
                SearchBarEnabled = o.Search == true, MenuWidth = o.MenuWidth, Callback = function(v)
                if type(v) == "table" then v = v.Title end
                if v == nil or v == el.Value then return end
                el.Value = v
                fire(o.Callback, v)
            end}
            function el:Set(v, silent)
                local changed = v ~= el.Value
                el.Value = v
                pcall(function() p:Select(v) end)
                if not silent and changed then fire(o.Callback, v) end
            end
            function el:SetValues(values)
                el.Values = values
                pcall(function() p:Refresh(values) end)
            end
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            return addEl(el, o.Flag)
        end

        function host:Input(o)
            local el = {Value = o.Default or ""}
            local p = ui:Input{Title = o.Title or "Input", Desc = o.Desc, Value = el.Value, Placeholder = o.Placeholder or "", Type = "Input", Callback = function(v)
                v = tostring(v or "")
                if v == el.Value then return end
                el.Value = v
                fire(o.Callback, v)
            end}
            function el:Set(v, silent)
                v = tostring(v or "")
                local changed = v ~= el.Value
                el.Value = v
                pcall(function() p:Set(v) end)
                if not silent and changed then fire(o.Callback, v) end
            end
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            return addEl(el, o.Flag)
        end

        function host:Keybind(o)
            local el = {Value = o.Default or "None", Down = false}
            local p = ui:Keybind{Title = o.Title or "Keybind", Desc = o.Desc, Value = el.Value ~= "None" and el.Value or "F", Callback = function() end}
            local label
            pcall(function() label = p.UIElements.Keybind.Frame.Frame.TextLabel end)
            if label then
                connect(label:GetPropertyChangedSignal("Text"), function()
                    local t = label.Text
                    if t ~= "..." and t ~= el.Value then
                        el.Value = t
                        if o.Changed then fire(o.Changed, t) end
                    end
                end)
            end
            function el:Set(v, silent)
                el.Value = type(v) == "string" and v or "None"
                pcall(function() p:Set(el.Value == "None" and "F" or el.Value) end)
                if not silent and o.Changed then fire(o.Changed, el.Value) end
            end
            -- WindUI only reports presses; the hub also needs "is it held" (aim assist), so it listens for the key itself
            connect(UIS.InputBegan, function(input, processed)
                if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                if input.KeyCode.Name == el.Value and not UIS:GetFocusedTextBox() then
                    el.Down = true
                    if o.Callback and (not processed or o.IgnoreProcessed) then fire(o.Callback) end
                end
            end)
            connect(UIS.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == el.Value then el.Down = false end
            end)
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            return addEl(el, o.Flag)
        end

        -- a group: a WindUI Section with a title (and a body text) that folds open / shut and holds more elements of every kind above (and more groups).
        -- o = {Title, Desc, Opened = bool, Box = bool}; the result has the same constructors plus :Open / :Close / :IsOpen / :SetTitle / :SetDesc / :Clear / :Destroy.
        function host:Group(o)
            o = o or {}
            local sec = ui:Section{Title = o.Title or " ", Desc = o.Desc, Box = o.Box == true, BoxBorder = o.Box == true, Opened = o.Opened == true,
                TextSize = o.TextSize or 17, DescTextSize = o.DescTextSize or 13}
            local group = {Title = o.Title, Ui = sec}
            attach(group, sec, page)
            function group:Open() pcall(function() sec:Open() end) end
            function group:Close() pcall(function() sec:Close() end) end
            function group:IsOpen() return sec.Opened == true end
            function group:SetTitle(v) pcall(function() sec:SetTitle(v ~= "" and v or " ") end) end
            function group:SetDesc(v) pcall(function() sec:SetDesc(v) end) end
            function group:Clear()
                for i = #group.items, 1, -1 do
                    local it = group.items[i]
                    if it.Clear then it:Clear() end
                    if it.Destroy then it:Destroy() end
                    group.items[i] = nil
                end
            end
            keep(group)
            return group
        end
    end

    -- a folding group of tabs in the sidebar ("MENU", "CHARACTERS" ...); pass it to win:Tab as the third argument
    function win:SideSection(title, opened)
        local ui = Window:Section{Title = title, Opened = opened ~= false}
        return {title = title, ui = ui}
    end

    function win:Tab(name, iconKind, side)
        local parent = side and side.ui or Window
        local ui = parent:Tab{Title = name, Icon = ICONS[iconKind or "dots"] or iconKind or "circle"}        -- (a name that is not one of ours is passed on as a Lucide icon name)
        local tab = {name = name, ui = ui}
        win.Tabs[#win.Tabs + 1] = tab
        attach(tab, ui, ui.ContainerFrame)
        return tab
    end

    ---------------------------------------------------------------------------------------------- notifications, theme, state
    function win:Notify(o)
        if not win.Alive then return end
        safe("notify", function()
            WindUI:Notify{Title = o.Title or "", Content = o.Content or "", Duration = o.Duration or 3, Icon = NOTE_ICONS[o.Type or "info"] or "info"}
        end)
    end
    function win:SetTheme(name)
        name = Adapter.themeFor(name)
        themeName = name
        glass(name)
        pcall(function() WindUI:SetTheme(name) end)
    end
    function win:GetTheme() return themeName end
    local function buttonsOf(list, default)
        local out = {}
        for _, b in ipairs(list or {{Title = default}}) do
            out[#out + 1] = {Title = b.Title or "OK", Icon = b.Icon, Variant = b.Variant or "Primary", Callback = function() if b.Callback then safe("dialog button", b.Callback) end end}
        end
        return out
    end
    -- a centred card over the game (welcome message); Buttons = {{Title, Icon, Variant, Callback}}
    function win:Popup(o)
        safe("popup", function() WindUI:Popup{Title = o.Title or "", Icon = o.Icon, Content = o.Content, Buttons = buttonsOf(o.Buttons, "OK")} end)
    end
    -- a dialog inside the window (a changelog, a question)
    function win:Dialog(o)
        safe("dialog", function() Window:Dialog{Title = o.Title or "", Content = o.Content, Buttons = buttonsOf(o.Buttons, "Close")} end)
    end
    function win:SetFont(family) return pcall(function() WindUI:SetFont(family) end) end
    function win:SetAvatar() end                                           -- WindUI shows the player's own avatar and name (User option)
    function win:SelectTab(name)                                              -- WindUI shows no tab until one is selected, so the hub selects the first one
        for i, t in ipairs(win.Tabs) do
            if t.name == name or i == name then pcall(function() Window:SelectTab(i) end); return end
        end
    end
    function win:SetVisible(v) if v then Window:Open() else Window:Close() end end
    function win:Toggle() Window:Toggle() end
    function win:GetState()
        local out = {}
        for flag, el in pairs(win.Flags) do out[flag] = el.Value end
        return out
    end
    function win:SetState(state, silent)
        if type(state) ~= "table" then return end
        for flag, v in pairs(state) do
            local el = win.Flags[flag]
            if el and el.Set and type(v) == type(el.Value) then el:Set(v, silent) end
        end
    end
    win.SetTheme(win, themeName)

    ---------------------------------------------------------------------------------------------- window background (video / picture)
    local function folder() return (cfg.Folder or "WraithsHub") .. "/assets" end

    -- executors' request() looks like a browser (some sites turn Roblox's own HttpGet away); HttpGet is the fallback
    local function httpGet(url)
        local req = request or http_request or (syn and syn.request)
        local lastErr
        if req then
            local headers = {["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36", ["Accept"] = "*/*"}
            if url:find("pixabay.com", 1, true) then headers["Referer"] = "https://pixabay.com/" end
            local ok, res = pcall(req, {Url = url, Method = "GET", Headers = headers})
            if ok and type(res) == "table" and (res.StatusCode == nil or res.StatusCode == 200) and type(res.Body) == "string" and res.Body ~= "" then return res.Body end
            lastErr = ok and ("HTTP " .. tostring(type(res) == "table" and res.StatusCode or res)) or tostring(res)
        end
        if game.HttpGet then return game:HttpGet(url) end
        error(lastErr or "no HttpGet / request in this executor")
    end

    -- resolves a link to something a VideoFrame / ImageLabel can show: returns kind ("video" | "image"), asset
    local function resolveMedia(url)
        if url:find("^rbxassetid://") or url:find("^rbxasset://") then return "image", url end
        local ext = extensionOf(url)
        local kind = VIDEO_EXT[ext] and "video" or IMAGE_EXT[ext] and "image" or nil
        if url:find("^https?://[%w%.]*pixabay%.com/videos/") then
            local html = httpGet(url)
            local file = pickPixabayFile(html)
            if not file then error("no video file link found on that Pixabay page (the site may block automated requests) - paste the direct .mp4 link instead") end
            url, ext, kind = file, "mp4", "video"
        end
        if not kind then error("unsupported link: it must end in .mp4 / .webm / .png / .jpg") end
        if not (writefile and isfile and getcustomasset) then error("this executor has no writefile / getcustomasset, so a downloaded background cannot be shown") end
        if makefolder and isfolder then
            for _, dir in ipairs({cfg.Folder or "WraithsHub", folder()}) do
                if not isfolder(dir) then pcall(makefolder, dir) end
            end
        end
        local path = string.format("%s/bg_%s.%s", folder(), hashOf(url), ext)
        if not isfile(path) then writefile(path, httpGet(url)) end
        return kind, getcustomasset(path)
    end

    ---------------------------------------------------------------------------------------------- outline water, transparent inside
    -- The inside of the window stays transparent. The grey water-flow texture lives only on OUTLINES: the window's border (here) and the borders of the buttons (above).
    local bgLayer = Window.UIElements and Window.UIElements.Main and Window.UIElements.Main:FindFirstChild("Background")
    local radius = Window.UICorner or 16
    local function rounded(f, r) local c = Instance.new("UICorner"); c.CornerRadius = r or UDim.new(0, radius); c.Parent = f; return c end
    do
        local frame = Instance.new("Frame")
        frame.Name = "WraithOutline"
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Active = false
        frame.ZIndex = 100
        rounded(frame)
        frame.Parent = Window.UIElements.Main
        win.WindowOutline = win:Outline(frame, {Thickness = 2, Global = true, Speed = 24, Active = function() return not Window.Closed end})
    end
    pcall(function() Window:SetBackgroundTransparency(clamp(cfg.WindowAlpha or 0.5, 0, 0.9)) end)      -- a see-through window
    function win:SetBackgroundTransparency(v) pcall(function() Window:SetBackgroundTransparency(clamp(tonumber(v) or 0.5, 0, 0.9)) end) end

    local dimFrame
    if bgLayer then
        dimFrame = Instance.new("Frame")
        dimFrame.Name = "WraithDim"
        dimFrame.Size = UDim2.new(1, 0, 1, 0)
        dimFrame.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
        dimFrame.BackgroundTransparency = 1
        dimFrame.BorderSizePixel = 0
        dimFrame.Active = false
        dimFrame.ZIndex = 9
        dimFrame.Visible = false
        rounded(dimFrame)
        dimFrame.Parent = bgLayer
    end
    local backdrop = {media = nil, Dim = clamp(cfg.BackgroundDim or 0.35, 0, 0.9), Url = nil, Token = 0}
    local function refreshBackdrop()                                          -- the dim layer only exists while a picture / video is showing
        if dimFrame then
            dimFrame.Visible = backdrop.media ~= nil
            dimFrame.BackgroundTransparency = 1 - clamp(backdrop.Dim, 0, 0.9)
        end
    end
    refreshBackdrop()

    ---------------------------------------------------------------------------------------------- animated white water behind the content
    -- Self-made: no download, no asset id, nothing that can fail to load. A few full-size layers, each a white fill whose UIGradient only lets thin bright
    -- bands through (the crests of a sharpened sine); every layer drifts and sways at its own pace, so the bands cross and part like light on moving water.
    -- It only animates while the window is open, at most `Fps` times a second, and it sits under the controls (and over a video / picture, if one is set).
    local WATER_LAYERS = {
        {rot = 18, periods = 2.2, speed = 0.55, amp = 0.32, phase = 0.0, sharp = 2.6, alpha = 0.80},
        {rot = -24, periods = 3.1, speed = 0.85, amp = 0.26, phase = 2.2, sharp = 3.2, alpha = 0.84},
        {rot = 82, periods = 1.7, speed = 0.35, amp = 0.36, phase = 4.1, sharp = 2.2, alpha = 0.88},
        {rot = 8, periods = 5.0, speed = 1.40, amp = 0.18, phase = 1.3, sharp = 7.0, alpha = 0.70},     -- (the glints on the crests)
    }
    local water = {On = false, Strength = 0.7, Speed = 1, Tint = Color3.fromRGB(255, 255, 255), Layers = {}, Fps = 30, T = 0, Acc = 0}
    win.Water = water
    local function waterSequences(L)
        local lo = water.Tint:Lerp(Color3.fromRGB(140, 152, 170), 0.45)                     -- the trough tone: silver
        local cols, alphas = {}, {}
        for i = 0, 19 do
            local t = i / 19
            local s = (0.5 + 0.5 * math.sin(2 * math.pi * L.periods * t + L.phase)) ^ L.sharp
            cols[#cols + 1] = ColorSequenceKeypoint.new(t, lo:Lerp(water.Tint, s))
            alphas[#alphas + 1] = NumberSequenceKeypoint.new(t, 1 - (1 - L.alpha) * s * water.Strength)
        end
        return ColorSequence.new(cols), NumberSequence.new(alphas)
    end
    local function buildWater()
        for _, l in ipairs(water.Layers) do pcall(function() l.frame:Destroy() end) end
        water.Layers = {}
        if not (water.On and bgLayer) then return end
        for i, L in ipairs(WATER_LAYERS) do
            local f = Instance.new("Frame")
            f.Name = "WraithWater" .. i
            f.Size = UDim2.new(1, 0, 1, 0)
            f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            f.BackgroundTransparency = 0
            f.BorderSizePixel = 0
            f.Active = false
            f.ZIndex = 10 + i
            rounded(f)
            local g = Instance.new("UIGradient")
            g.Rotation = L.rot
            g.Color, g.Transparency = waterSequences(L)
            g.Parent = f
            f.Parent = bgLayer
            water.Layers[i] = {frame = f, grad = g, def = L}
        end
    end
    local function stepWater(dt)
        if not water.On or #water.Layers == 0 or Window.Closed then return end
        water.Acc = water.Acc + dt
        if water.Acc < 1 / water.Fps then return end
        water.T = water.T + water.Acc * water.Speed
        water.Acc = 0
        local t = water.T
        for _, l in ipairs(water.Layers) do
            local L = l.def
            l.grad.Offset = Vector2.new(L.amp * math.sin(t * L.speed + L.phase), L.amp * 0.45 * math.cos(t * L.speed * 0.8 + L.phase))
            l.grad.Rotation = L.rot + 7 * math.sin(t * L.speed * 0.5 + L.phase)
        end
    end
    connect(game:GetService("RunService").Heartbeat, function(dt) safe("water", stepWater, dt) end)
    -- o = {Enabled = bool, Strength = 0..1, Speed = 0..3, Tint = Color3}; anything left out keeps its value
    function win:SetWater(o)
        o = o or {}
        local rebuild = false
        if o.Enabled ~= nil and (o.Enabled == true) ~= water.On then water.On = o.Enabled == true; rebuild = true end
        if type(o.Strength) == "number" and o.Strength == o.Strength then water.Strength = clamp(o.Strength, 0, 1); rebuild = true end
        if type(o.Speed) == "number" and o.Speed == o.Speed then water.Speed = clamp(o.Speed, 0, 3) end
        if typeof(o.Tint) == "Color3" then water.Tint = o.Tint; rebuild = true end
        if rebuild then buildWater() end
    end
    function win:GetWater() return {Enabled = water.On, Strength = water.Strength, Speed = water.Speed, Layers = #water.Layers} end
    if type(cfg.Water) == "table" then win:SetWater(cfg.Water) end

    local function clearMedia()
        if backdrop.media then pcall(function() backdrop.media:Destroy() end); backdrop.media = nil end
    end
    function win:SetBackgroundDim(v) backdrop.Dim = clamp(tonumber(v) or backdrop.Dim, 0, 0.9); refreshBackdrop() end
    function win:SetScale(v) pcall(function() Window:SetUIScale(clamp(tonumber(v) or 0.9, 0.55, 1.2)) end) end

    -- url == nil or "" removes the picture / video. Async: the download happens in a task; `done(ok, message)` is called when it is over.
    function win:SetBackground(url, done)
        backdrop.Token = backdrop.Token + 1
        local token = backdrop.Token
        url = type(url) == "string" and url:gsub("^%s+", ""):gsub("%s+$", "") or ""
        if url == "" then
            clearMedia(); backdrop.Url = nil; refreshBackdrop()
            if done then done(true, "removed") end
            return
        end
        task.spawn(function()
            local ok, kindOrErr, asset = pcall(resolveMedia, url)
            if token ~= backdrop.Token or not win.Alive then return end
            if not ok then
                onError("background", tostring(kindOrErr))
                if done then done(false, tostring(kindOrErr)) end
                return
            end
            if not bgLayer then if done then done(false, "the window has no background layer") end return end
            clearMedia()
            if kindOrErr == "video" then
                backdrop.media = Instance.new("VideoFrame")
                backdrop.media.Name = "WraithVideo"
                backdrop.media.Video = asset
                backdrop.media.Looped = true
                backdrop.media.Volume = 0
            else
                backdrop.media = Instance.new("ImageLabel")
                backdrop.media.Name = "WraithPicture"
                backdrop.media.Image = asset
                backdrop.media.ScaleType = Enum.ScaleType.Crop
            end
            backdrop.media.BackgroundTransparency = 1
            backdrop.media.BorderSizePixel = 0
            backdrop.media.Size = UDim2.new(1, 0, 1, 0)
            backdrop.media.ZIndex = 2
            rounded(backdrop.media)
            backdrop.media.Parent = bgLayer
            backdrop.Url = url
            if kindOrErr == "video" then pcall(function() backdrop.media:Play() end) end
            refreshBackdrop()
            if done then done(true, kindOrErr) end
        end)
    end
    if cfg.Background and cfg.Background ~= "" then win:SetBackground(cfg.Background, cfg.OnBackground) end

    ---------------------------------------------------------------------------------------------- teardown
    function win:Destroy()
        if not win.Alive then return end
        backdrop.Token = backdrop.Token + 1
        coreDestroy()                                                       -- (also marks the window dead and removes the floating buttons)
        clearMedia()
        pcall(function() Window:Destroy() end)
        for _, key in ipairs({"ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui"}) do
            local g = WindUI[key]
            if g then pcall(function() g:Destroy() end) end
        end
    end

    return win
end

-- builds the window; if anything goes wrong half way, what was already made is removed again and the error is raised (the hub then falls back to the classic menu)
function Adapter.new(WindUI, UILib, cfg)
    -- the headless core brings the water-wave skin and the floating buttons (and the Connect / Safe helpers)
    local win = UILib.new{Headless = true, Parent = cfg.Parent, GuiName = cfg.GuiName, Theme = "Crimson", WaveMode = cfg.WaveMode, OnError = cfg.OnError}
    local ok, err = pcall(build, win, WindUI, UILib, cfg)
    if not ok then
        pcall(function() if rawget(win, "Window") then win.Window:Destroy() end end)
        pcall(function() win.Alive = true; win:Destroy() end)
        for _, key in ipairs({"ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui"}) do
            local g = WindUI[key]
            if g then pcall(function() g:Destroy() end) end
        end
        error(err, 0)
    end
    return win
end

return Adapter

end)()
local ClassicWind = (function()

local M = {}

-- Lucide icon of each tab (the characters' tabs all get "user")
local TAB_ICONS = {Main = "layout-dashboard", Credit = "heart", Timing = "timer", Techs = "list", ["Tech Lab"] = "wrench", ["Auto Tech"] = "shield",
    Teleports = "map-pin", Look = "palette", ["Effects Preset"] = "palette", Config = "settings", Predictor = "target"}

-- the card that opens each tab, the way the other Wraith Hub v1.5 does (a character's tab gets the generic one)
local TAB_BLURBS = {
    Main = "Start techs with your M1, utilities (WalkSpeed, Anti AFK), the universal combos and the side dash cards.",
    Credit = "Who made what, and how to open and close this menu.",
    Timing = "How long the hub waits between the steps of a combo, and how your ping changes that.",
    Techs = "Every tech found in research, with how well sourced it is.",
    ["Tech Lab"] = "Small, cancellable tech sequences: each has its own switch, options and status line.",
    ["Auto Tech"] = "Recover when you are knocked down, and Auto block.",
    Teleports = "Go next to a player, or to the spawn.",
    Look = "The look of this menu: theme, font, size, the white water, your own picture or video.",
    Config = "The only way anything is remembered: save, reload or delete your config.",
    Predictor = "Guesses which combo you are doing from your inputs.",
}
local CHARACTER_BLURB = "Combo cards for %s: Run plays the whole combo, On screen puts a button on your screen, Assist plays what follows the move you cast, Show options tunes one combo."

local function hexOf(c)
    local function byte(v) return math.max(0, math.min(255, math.floor(v * 255 + 0.5))) end
    return string.format("#%02x%02x%02x", byte(c.R), byte(c.G), byte(c.B))
end

-- d = {Adapter, WindUI, UILib, cfg = the adapter's window options, onError = fn(where, err), budget = seconds of building per frame, perFrame = most controls per frame,
--      cards = false leaves out the card that opens each tab}
-- Raises when the window cannot be made: the hub then keeps its own menu.
function M.new(d)
    local win = d.Adapter.new(d.WindUI, d.UILib, d.cfg)
    local B = {win = win, alive = true, elements = {}}                       -- B.elements["Tech Lab/Supa Tech/On"] = the real control (the tests click them)
    local onError = d.onError or function() end
    local budget, perFrame = d.budget or 0.012, d.perFrame or math.huge
    local cards = d.cards ~= false
    local tabs, order = {}, {}                                              -- our records, by the tab's index in the window / in creation order
    local side                                                              -- the sidebar group new tabs go into

    ---------------------------------------------------------------------------------------------- the build queue
    -- queues with explicit ends (a table whose first entries were taken out has no reliable #)
    local function newQueue() return {first = 1, last = 0} end
    local function push(q, fn) q.last = q.last + 1; q[q.last] = fn end
    local function pop(q)
        if q.first > q.last then return nil end
        local fn = q[q.first]
        q[q.first] = nil
        q.first = q.first + 1
        return fn
    end
    local function size(q) return q.last - q.first + 1 end
    local urgentQ = newQueue()                                              -- what a click just asked for (an options drawer): before everything else
    local urgentMode = false
    local function job(rec, fn, urgent)
        push((urgent or urgentMode) and urgentQ or rec.queue, fn)
    end
    function B.pending()
        local n = size(urgentQ)
        for _, rec in ipairs(order) do n = n + size(rec.queue) end
        return n
    end
    local function nextJob()
        local fn = pop(urgentQ)
        if fn then return fn end
        local showing = tabs[win.Window.CurrentTab]                           -- (WindUI keeps the shown tab's index)
        if showing then
            fn = pop(showing.queue)
            if fn then return fn end
        end
        for _, rec in ipairs(order) do
            fn = pop(rec.queue)
            if fn then return fn end
        end
        return nil
    end
    task.spawn(function()
        while B.alive do
            local t0, did, count = os.clock(), false, 0
            while B.alive and count < perFrame and (os.clock() - t0 < budget or count == 0) do
                local fn = nextJob()
                if not fn then break end
                did, count = true, count + 1
                local ok, err = pcall(fn)
                if not ok then onError("menu build", err) end
            end
            task.wait(did and 0 or 0.1)
        end
    end)

    ---------------------------------------------------------------------------------------------- hosts: a tab or a group, as the hub's code addresses them
    -- host:enqueue(fn) runs fn(realHost) once the real WindUI host exists (a group's jobs from before a :clear() are dropped)
    local function tabHost(rec)
        local host = {rec = rec, path = rec.name}
        function host:enqueue(fn, urgent) job(rec, function() fn(rec.real) end, urgent) end
        return host
    end
    local function newGroup(parent, o)
        local G = {rec = parent.rec, gen = 0, path = parent.path .. "/" .. tostring(o.Title)}
        function G:enqueue(fn, urgent)
            local g = G.gen
            job(G.rec, function() if G.real and g == G.gen then fn(G.real) end end, urgent)
        end
        function G:clear()
            G.gen = G.gen + 1
            job(G.rec, function() if G.real then G.real:Clear() end end)
        end
        parent:enqueue(function(h) G.real = h:Group(o); B.elements[G.path] = G.real end)
        return G
    end
    local function hostFor(T, parent)                                       -- `parent` is what the hub passes as its last argument (nil = the tab itself)
        if type(parent) == "table" and parent.enqueue then return parent end
        return T.__host
    end

    ---------------------------------------------------------------------------------------------- controls
    local function snapTo(min, max, step)
        return function(v)
            v = math.floor((v - min) / step + 0.5) * step + min
            return math.clamp(tonumber(string.format("%.4f", v)), min, max)
        end
    end

    local function mkToggle(host, text, default, cb, subtitle)
        local st = {on = default and true or false}
        local api = {}
        function api:Get() return st.on end
        function api:Set(v)
            v = v and true or false
            if v == st.on then return end
            st.on = v
            if st.real then st.real:Set(v, true) end
            if cb then task.spawn(cb, v) end
        end
        host:enqueue(function(h)
            st.real = h:Toggle{Title = text, Desc = subtitle, Default = st.on, NoInitialCallback = true, Callback = function(v)
                if v == st.on then return end
                st.on = v
                if cb then task.spawn(cb, v) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        if cb then task.spawn(cb, st.on) end                                -- like the old menu: the callback hears the starting value once
        return api
    end

    local function mkSlider(host, text, min, max, default, step, cb)
        assert(max > min and step > 0, "Slider: need max > min and step > 0")
        local snap = snapTo(min, max, step)
        local st = {value = snap(math.clamp(default, min, max))}
        local api = {}
        function api:Set(v)
            if type(v) ~= "number" then return end
            st.value = snap(math.clamp(v, min, max))
            if st.real then st.real:Set(st.value, true) end
            if cb then task.spawn(cb, st.value) end
        end
        host:enqueue(function(h)
            st.real = h:Slider{Title = text, Min = min, Max = max, Step = step, Default = st.value, Callback = function(v)
                if v == st.value then return end
                st.value = v
                if cb then task.spawn(cb, v) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        if cb then task.spawn(cb, st.value) end
        return api
    end

    local function mkDropdown(host, text, options, default, cb)
        local st = {value = table.find(options, default) and default or options[1]}
        local api = {}
        function api:Set(v)
            if not table.find(options, v) then return end
            st.value = v
            if st.real then st.real:Set(v, true) end
            if cb then task.spawn(cb, v) end
        end
        host:enqueue(function(h)
            st.real = h:Dropdown{Title = text, Values = options, Default = st.value, Search = #options > 8, Callback = function(v)
                if v == st.value then return end
                st.value = v
                if cb then task.spawn(cb, v) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        if cb then task.spawn(cb, st.value) end
        return api
    end

    -- the button's row: the hub only ever shows / hides it (a "Forget" button that has nothing to forget)
    local function mkButton(host, text, cb, desc)
        local st = {visible = true}
        local row = setmetatable({}, {
            __index = function(_, k) if k == "Visible" then return st.visible end end,
            __newindex = function(_, k, v)
                if k == "Visible" then
                    st.visible = v ~= false
                    if st.real then st.real:SetVisible(st.visible) end
                end
            end,
        })
        host:enqueue(function(h)
            st.real = h:Button{Title = text, Desc = desc, Outline = false, Callback = function() if cb then task.spawn(cb) end end}
            B.elements[host.path .. "/" .. text] = st.real
            if not st.visible then st.real:SetVisible(false) end
        end)
        return row
    end

    local function mkInput(host, text, placeholder, default, cb)
        local st = {text = tostring(default or "")}
        local api = {}
        function api:Get() return st.text end
        function api:Set(v)
            st.text = tostring(v)
            if st.real then st.real:Set(st.text, true) end
        end
        host:enqueue(function(h)
            st.real = h:Input{Title = text, Default = st.text, Placeholder = placeholder or "", Callback = function(v)
                st.text = v
                if cb then task.spawn(cb, v, true) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        return api
    end

    -- body text: the hub reads / writes `.Text`; other fields (TextSize, TextColor3) do not apply to a WindUI label
    local function mkLabel(host, text)
        local st = {text = tostring(text or "")}
        local label = setmetatable({}, {
            __index = function(_, k) if k == "Text" then return st.text end end,
            __newindex = function(_, k, v)
                if k == "Text" then
                    v = tostring(v)
                    if v ~= st.text then
                        st.text = v
                        if st.real then st.real:Set(v) end
                    end
                end
            end,
        })
        host:enqueue(function(h) st.real = h:Label(st.text); B.elements[host.path .. "/" .. text] = st.real end)
        return label
    end

    -- a switch on a card: spec = {default, onChange}; :set(v) changes it without calling onChange
    local function mkSwitch(host, text, spec)
        local st = {on = spec.default and true or false}
        local sw = {}
        function sw:set(v)
            v = v and true or false
            if v == st.on then return end
            st.on = v
            if st.real then st.real:Set(v, true) end
        end
        host:enqueue(function(h)
            st.real = h:Toggle{Title = text, Default = st.on, NoInitialCallback = true, Callback = function(v)
                if v == st.on then return end
                st.on = v
                if spec.onChange then task.spawn(spec.onChange, v) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        if st.on and spec.onChange then task.spawn(spec.onChange, true) end
        return sw
    end

    -- the combo card: a folding group with Run, the On screen / Assist switches and the options drawer (built when it is first opened)
    -- extra = {conf, options = function(drawer), pin = {default, onChange}, assist = {default, onChange}}; the result has :SetPinned / :SetArmed (they never call onChange)
    local function mkCard(host, name, desc, cb, extra)
        local handle = {}
        function handle:SetPinned() end
        function handle:SetArmed() end
        if extra == nil then                                                -- a plain row (the player list)
            mkButton(host, name, cb, desc)
            return handle
        end
        local card = newGroup(host, {Title = name, Desc = (extra.conf and ("[" .. extra.conf .. "]  ") or "") .. (desc or ""), Box = true, Opened = false})
        mkButton(card, "Run", cb)
        if extra.pin then
            local sw = mkSwitch(card, "On screen", extra.pin)
            function handle:SetPinned(v) sw:set(v) end
        end
        if extra.assist then
            local sw = mkSwitch(card, "Assist", extra.assist)
            function handle:SetArmed(v) sw:set(v) end
        end
        if extra.options then
            local drawer
            local built = false
            mkSwitch(card, "Show options", {default = false, onChange = function(on)
                if on and not built then
                    built = true
                    urgentMode = true                                      -- what the drawer builds comes before the rest of the queue: the click is waiting for it
                    local ok, err = pcall(extra.options, drawer)
                    urgentMode = false
                    if not ok then onError("options drawer", err) end
                end
                drawer:enqueue(function(h) if on then h:Open() else h:Close() end end, true)
            end})
            drawer = newGroup(card, {Title = "Options", Opened = false})               -- (below its switch)
        end
        return handle
    end

    ---------------------------------------------------------------------------------------------- tabs
    function B.sideHeader(text) side = win:SideSection(text, true) end

    function B.createTab(name, glyph)
        local real = win:Tab(name, TAB_ICONS[name] or "user", side)
        local rec = {name = name, real = real, queue = newQueue(), index = #win.Tabs}
        tabs[rec.index] = rec
        order[#order + 1] = rec
        local T = {__host = tabHost(rec), __rec = rec}
        if cards then
            local blurb = TAB_BLURBS[name] or string.format(CHARACTER_BLURB, name)
            T.__host:enqueue(function(h) B.elements[rec.name .. "/" .. name] = h:Paragraph{Title = name, Desc = blurb, Image = TAB_ICONS[name] or "user"} end)
        end
        function T:Select() win:SelectTab(rec.index) end
        function T:Hide() end
        function T:Label(text, parent) return mkLabel(hostFor(T, parent), text) end
        function T:Toggle(text, default, cb, parent, subtitle) return mkToggle(hostFor(T, parent), text, default, cb, subtitle) end
        function T:Slider(text, min, max, default, step, cb, parent) return mkSlider(hostFor(T, parent), text, min, max, default, step, cb) end
        function T:Dropdown(text, options, default, cb, parent) return mkDropdown(hostFor(T, parent), text, options, default, cb) end
        function T:Button(text, cb, parent) return mkButton(hostFor(T, parent), text, cb) end
        function T:Input(text, placeholder, default, cb, parent) return mkInput(hostFor(T, parent), text, placeholder, default, cb) end
        function T:Banner(title, subtitle, tag)
            T.__host:enqueue(function(h) B.elements[T.__host.path .. "/" .. title] = h:Paragraph{Title = tag and (title .. "   [" .. tag .. "]") or title, Desc = subtitle, Image = "sparkles"} end)
        end
        function T:Section(title, collapsed)
            local G = newGroup(T.__host, {Title = title, Opened = not collapsed})
            local sec = {Body = G}
            function sec:Button(bname, bdesc, bcb, extra) return mkCard(G, bname, bdesc, bcb, extra) end
            function sec:Info(iname, idesc) G:enqueue(function(h) B.elements[G.path .. "/" .. iname] = h:Paragraph{Title = iname, Desc = idesc} end) end
            function sec:Toggle(tname, default, tcb, subtitle) return mkToggle(G, tname, default, tcb, subtitle) end
            function sec:Slider(sname, min, max, default, step, scb) return mkSlider(G, sname, min, max, default, step, scb) end
            function sec:Dropdown(dname, options, default, dcb) return mkDropdown(G, dname, options, default, dcb) end
            function sec:Label(ltext) return mkLabel(G, ltext) end
            function sec:Clear() G:clear() end
            return sec
        end
        return T
    end

    ---------------------------------------------------------------------------------------------- window level
    -- the live ping next to the title: pill.Text / pill.TextColor3 are written like the old menu's ping pill
    function B.pingPill(title, color)
        local tag = win:Tag{Title = title, Color = color}
        local lastText, lastColor
        return setmetatable({}, {
            __newindex = function(_, k, v)
                if k == "Text" and v ~= lastText then lastText = v; tag:Set(v)
                elseif k == "TextColor3" then
                    local hex = hexOf(v)
                    if hex ~= lastColor then lastColor = hex; tag:Set(nil, hex) end
                end
            end,
        })
    end
    function B.toast(text, title) win:Notify{Title = title or "Wraith Hub v1.5", Content = tostring(text), Duration = 3, Type = "info"} end
    function B.setMenu(v) win:SetVisible(v and true or false) end
    function B.isOpen() return win.Main.Visible == true end
    function B.destroy()
        B.alive = false
        win:Destroy()
    end

    return B
end

return M

end)()
-- WindUI by Footagesus (https://github.com/Footagesus/WindUI), MIT License. Copyright (c) 2026 Footages. Unchanged apart from three small patches (mm2/vendor/patch_windui.py).
local WindUILoader = function()
--[[
     _      ___         ____  ______
    | | /| / (_)__  ___/ / / / /  _/
    | |/ |/ / / _ \/ _  / /_/ // /  
    |__/|__/_/_//_/\_,_/\____/___/
    
    v1.6.65  |  2026-07-01  |  Roblox UI Library for scripts
    
    To view the source code, see the `src/` folder on the official GitHub repository.
    
    Author: Footagesus (Footages, .ftgs, oftgs)
    Github: https://github.com/Footagesus/WindUI
    Discord: https://discord.gg/ftgs-development-hub-1300692552005189632
    License: MIT
]]

type ConfigType__DARKLUA_TYPE_a={
Object:Instance,
Camera:Instance?,
Interactive:boolean?,
Height:number?,
Focused:boolean,

Window:any,
WindUI:any,
Tab:any,
Parent:Instance,
}local a a={cache={}, load=function(b)if not a.cache[b]then a.cache[b]={c=a[b]()}end return a.cache[b].c end}do function a.a()

local b

local d={
New=nil,
Init=nil,
Shapes={
Circle={
Image="rbxassetid://111665032676235",
Rect=Rect.new(512,512,512,512),
Radius=512,
},
CircleOutline={
Image="rbxassetid://108556680453287",
Rect=Rect.new(512,512,512,512),
Radius=512,
},
CircleGlass={
Image="rbxassetid://95600044758841",
Rect=Rect.new(512,512,512,512),
Radius=512,
},



SquircleH={
Image="rbxassetid://125083578015333",
Rect=Rect.new(512,325,512,325),
Radius=325,
},
SquircleHOutline={
Image="rbxassetid://107043713170567",
Rect=Rect.new(512,325,512,325),
Radius=325,
},
SquircleHGlass={
Image="rbxassetid://84819521201001",
Rect=Rect.new(512,325,512,325),
Radius=325,
},
["SquircleH-TL-TR"]={
Image="rbxassetid://90680657206619",
Rect=Rect.new(807,512,807,512),
Radius=325,
AutoChange=false,
},
["SquircleH-BL-BR"]={
Image="rbxassetid://99216342056719",
Rect=Rect.new(0,512,0,512),
Radius=325,
AutoChange=false,
},

SquircleV={
Image="rbxassetid://124965260437653",
Rect=Rect.new(325,512,325,512),
Radius=325,
},
SquircleVOutline={
Image="rbxassetid://88808835404198",
Rect=Rect.new(325,512,325,512),
Radius=325,
},
SquircleVGlass={
Image="rbxassetid://124982801466667",
Rect=Rect.new(325,512,325,512),
Radius=325,
},

Squircle={
Image="rbxassetid://89641024074289",
Rect=Rect.new(460,460,460,460),
Radius=310,
},
SquircleOutline={
Image="rbxassetid://74029063732681",
Rect=Rect.new(512,512,512,512),
Radius=310,
},
SquircleGlass={
Image="rbxassetid://131126436897551",
Rect=Rect.new(512,512,512,512),
Radius=310,
},

["Squircle-TL-TR"]={
Image="rbxassetid://75712142040725",
Rect=Rect.new(512,512,512,512),
Radius=310,
AutoChange=false,
},
["Squircle-BL-BR"]={
Image="rbxassetid://83676684425544",
Rect=Rect.new(512,0,512,0),
Radius=310,
AutoChange=false,
},Square=
{
Image="rbxassetid://82909646051652",
Rect=Rect.new(512,512,512,512),
Radius=512,
AutoChange=false,
},
},
}

function d.Init(e,f)
b=f
return e.New
end

function d.New(e,f,g,h,i,j,l)
local m={
Radius=f or 0,
Type=g or"Circle",
GetRadius=nil,
GetType=nil,
SetRadius=nil,
SetType=nil,
}

local p={
["Glass-0.7"]="SquircleGlass",
["Glass-1"]="SquircleGlass",
["Glass-1.4"]="SquircleGlass",
["Squircle-Outline"]="SquircleOutline",
}

local function GetShape(r)
return d.Shapes[p[r]or r]or d.Shapes.Circle
end

local r=b.New(j and"ImageButton"or"ImageLabel",{
Image="",
ScaleType=l~=false and"Slice"or nil,
SliceCenter=m.Type~="Squircle"and Rect.new(512,512,512,512)or nil,
SliceScale=1,
ThemeTag=h and h.ThemeTag or nil,
BackgroundTransparency=1,
},i)

for u,v in next,h do
if not table.find({"ThemeTag"},u)then
r[u]=v
end
end

function m.SetRadius(u,v)
m.Radius=v
r.SliceScale=math.max(v/GetShape(m.Type).Radius,0.0001)
return m
end

function m.SetType(u,v)
m.Type=v
local x=GetShape(v)
r.Image=x.Image
r.SliceCenter=x.Rect
m:SetRadius(m.Radius)
return m
end

function m.GetRadius(u)
return m.Radius
end

function m.GetType(u)
return m.Type
end

m:SetRadius(f)
m:SetType(g)

b.AddSignal(r:GetPropertyChangedSignal"AbsoluteSize",function()
local u=GetShape(m.Type)
if u.AutoChange==false then
return
end

if string.find(m.Type,"Squircle")then
local v=string.find(m.Type,"Glass")and"Glass"or nil
local x=string.find(m.Type,"Outline")and"Outline"or nil

local z=math.round(r.AbsoluteSize.X/b.UIScale)
local A=math.round(r.AbsoluteSize.Y/b.UIScale)

local B=m.Radius~=0 and m.Radius or math.min(z,A)/2
local C=d.Shapes.Squircle.Radius/1024
local F=B/math.min(z,A)

local G

if z>A then
if F>=C then
G="SquircleH"..(x or v or"")
else
G="Squircle"..(x or v or"")
end
elseif z<A then
if F>=C then
G="SquircleV"..(x or v or"")
else
G="Squircle"..(x or v or"")
end
else
if F>=C then
G="Circle"..(x or v or"")
else
G="Squircle"..(x or v or"")
end
end

if G~=m:GetType()then
m:SetType(G)
end
end
end)

return r,m
end

return d end function a.b()

local b=(cloneref or clonereference or function(b)return b end)

local d={Icons={lucide={["bell"]="rbxassetid://97392696311902",["bug"]="rbxassetid://83626408925438",["check"]="rbxassetid://93898873302694",["chevron-down"]="rbxassetid://134243273101015",["chevron-left"]="rbxassetid://73780377692148",["chevron-right"]="rbxassetid://92473583511724",["chevron-up"]="rbxassetid://122444883127455",["chevrons-up-down"]="rbxassetid://131833120209646",["circle"]="rbxassetid://130359823580534",["circle-alert"]="rbxassetid://83898160590116",["circle-check"]="rbxassetid://85262178816537",["circle-x"]="rbxassetid://76821953846248",["clock"]="rbxassetid://121808839832144",["copy"]="rbxassetid://78979572434545",["crosshair"]="rbxassetid://134242818164054",["download"]="rbxassetid://134814648082393",["ellipsis"]="rbxassetid://140019550645825",["expand"]="rbxassetid://137492887754537",["eye"]="rbxassetid://100033680381365",["eye-off"]="rbxassetid://135928786788378",["flag"]="rbxassetid://78183383236196",["folder"]="rbxassetid://80846616596607",["frown"]="rbxassetid://124407301067982",["gamepad-2"]="rbxassetid://92483947987410",["gauge"]="rbxassetid://110273524101447",["gift"]="rbxassetid://109855212076373",["github"]="rbxassetid://120349554354380",["heart"]="rbxassetid://116559368303288",["house"]="rbxassetid://98755624629571",["info"]="rbxassetid://124560466474914",["key"]="rbxassetid://96510194465420",["layout-dashboard"]="rbxassetid://139929981863901",["layout-grid"]="rbxassetid://81344910161871",["link"]="rbxassetid://131607023382430",["list"]="rbxassetid://113179976918783",["lock"]="rbxassetid://134724289526879",["lock-open"]="rbxassetid://93597915325122",["map-pin"]="rbxassetid://84279202219901",["maximize"]="rbxassetid://76045941763188",["menu"]="rbxassetid://77021539815611",["minimize"]="rbxassetid://121304296213645",["minus"]="rbxassetid://118026365011536",["mouse-pointer-click"]="rbxassetid://107150227368485",["move"]="rbxassetid://116138709011735",["music"]="rbxassetid://113343203848535",["octagon-alert"]="rbxassetid://140438367956051",["package"]="rbxassetid://97261141732706",["palette"]="rbxassetid://86350350950064",["pause"]="rbxassetid://74873705394436",["play"]="rbxassetid://135609604299893",["plus"]="rbxassetid://111774323017047",["power"]="rbxassetid://96479131758775",["refresh-cw"]="rbxassetid://138133190015277",["save"]="rbxassetid://126116963775616",["search"]="rbxassetid://121018724060431",["settings"]="rbxassetid://80758916183665",["shield"]="rbxassetid://110987169760162",["skull"]="rbxassetid://137726256442333",["sliders-horizontal"]="rbxassetid://85538382643347",["sparkles"]="rbxassetid://138635884129147",["square"]="rbxassetid://86304921356806",["star"]="rbxassetid://136141469398409",["sword"]="rbxassetid://124448418211665",["swords"]="rbxassetid://81872698913435",["target"]="rbxassetid://87563802520297",["terminal"]="rbxassetid://106783148545356",["timer"]="rbxassetid://85473888890506",["trash"]="rbxassetid://106723740584310",["triangle"]="rbxassetid://126330486745540",["triangle-alert"]="rbxassetid://125920361880643",["upload"]="rbxassetid://138212042425501",["user"]="rbxassetid://81589895647169",["users"]="rbxassetid://115398113982385",["wrench"]="rbxassetid://112148279212860",["x"]="rbxassetid://110786993356448",["zap"]="rbxassetid://130551565616516"}}}

local function parseIconString(e)
if type(e)=="string"then
local f=e:find":"
if f then
local g=e:sub(1,f-1)
local h=e:sub(f+1)
return g,h
end
end
return nil,e
end

function d.AddIcons(e,f)
if type(e)~="string"or type(f)~="table"then
error"AddIcons: packName must be string, iconsData must be table"
return
end

if not d.Icons[e]then
d.Icons[e]={
Icons={},
Spritesheets={}
}
end

for g,h in pairs(f)do
if type(h)=="number"or(type(h)=="string"and h:match"^rbxassetid://")then
local i=h
if type(h)=="number"then
i="rbxassetid://"..tostring(h)
end

d.Icons[e].Icons[g]={
Image=i,
ImageRectSize=Vector2.new(0,0),
ImageRectPosition=Vector2.new(0,0),
Parts=nil
}
d.Icons[e].Spritesheets[i]=i

elseif type(h)=="table"then
if h.Image and h.ImageRectSize and h.ImageRectPosition then
local i=h.Image
if type(i)=="number"then
i="rbxassetid://"..tostring(i)
end

d.Icons[e].Icons[g]={
Image=i,
ImageRectSize=h.ImageRectSize,
ImageRectPosition=h.ImageRectPosition,
Parts=h.Parts
}

if not d.Icons[e].Spritesheets[i]then
d.Icons[e].Spritesheets[i]=i
end
else
warn("AddIcons: Invalid spritesheet data format for icon '"..g.."'")
end
else
warn("AddIcons: Unsupported data type for icon '"..g.."': "..type(h))
end
end
end

function d.SetIconsType(e)
d.IconsType=e
end

local e
function d.Init(f,g)
d.New=f
d.IconThemeTag=g

e=f
return d
end

function d.Icon(f,g,h)
h=h~=false
local i,j=parseIconString(f)

local l=i or g or d.IconsType
local m=j

local p=d.Icons[l]

if p and p.Icons and p.Icons[m]then
return{
p.Spritesheets[tostring(p.Icons[m].Image)],
p.Icons[m],
}
elseif p and p[m]and string.find(p[m],"rbxassetid://")then
return h and{
p[m],
{ImageRectSize=Vector2.new(0,0),ImageRectPosition=Vector2.new(0,0)}
}or p[m]
end
if type(f)=="string"and not f:find"^rbx"and not f:find"^http"and tostring(m):match"^[%a][%w%-_]*$"then
return{"",{ImageRectSize=Vector2.new(0,0),ImageRectPosition=Vector2.new(0,0)}}
end
return nil
end

function d.GetIcon(f,g)
return d.Icon(f,g,false)
end


function d.Icon2(f,g,h)
return d.Icon(f,g,true)
end

function d.Image(f)
local g={
Icon=f.Icon or nil,
Type=f.Type,
Colors=f.Colors or{(d.IconThemeTag or Color3.new(1,1,1)),Color3.new(1,1,1)},
Transparency=f.Transparency or{0,0},
Size=f.Size or UDim2.new(0,24,0,24),

IconFrame=nil,
}

local h={}
local i={}

for j,l in next,g.Colors do
h[j]={
ThemeTag=typeof(l)=="string"and l,
Color=typeof(l)=="Color3"and l,
}
end

for j,l in next,g.Transparency do
i[j]={
ThemeTag=typeof(l)=="string"and l,
Value=typeof(l)=="number"and l,
}
end


local j=d.Icon2(g.Icon,g.Type)
local l=typeof(j)=="string"and string.find(j,'rbxassetid://')

if d.New then
local m=e or d.New



local p=m("ImageLabel",{
Size=g.Size,
BackgroundTransparency=1,
ImageColor3=h[1].Color or nil,
ImageTransparency=i[1].Value or nil,
ThemeTag=h[1].ThemeTag and{
ImageColor3=h[1].ThemeTag,
ImageTransparency=i[1].ThemeTag,
},
Image=l and j or j[1],
ImageRectSize=l and nil or j[2].ImageRectSize,
ImageRectOffset=l and nil or j[2].ImageRectPosition,
})


if not l and j[2].Parts then
for r,u in next,j[2].Parts do
local v=d.Icon(u,g.Type)

m("ImageLabel",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
ImageColor3=h[1+r].Color or nil,
ImageTransparency=i[1+r].Value or nil,
ThemeTag=h[1+r].ThemeTag and{
ImageColor3=h[1+r].ThemeTag,
ImageTransparency=i[1+r].ThemeTag,
},
Image=v[1],
ImageRectSize=v[2].ImageRectSize,
ImageRectOffset=v[2].ImageRectPosition,
Parent=p,
})
end
end

g.IconFrame=p
else
local m=Instance.new"ImageLabel"
m.Size=g.Size
m.BackgroundTransparency=1
m.ImageColor3=h[1].Color
m.ImageTransparency=i[1].Value or nil
m.Image=l and j or j[1]
m.ImageRectSize=l and nil or j[2].ImageRectSize
m.ImageRectOffset=l and nil or j[2].ImageRectPosition


if not l and j[2].Parts then
for p,r in next,j[2].Parts do
local u=d.Icon(r,g.Type)

local v=Instance.New"ImageLabel"
v.Size=UDim2.new(1,0,1,0)
v.BackgroundTransparency=1
v.ImageColor3=h[1+p].Color
v.ImageTransparency=i[1+p].Value or nil
v.Image=u[1]
v.ImageRectSize=u[2].ImageRectSize
v.ImageRectOffset=u[2].ImageRectPosition
v.Parent=m
end
end

g.IconFrame=m
end


return g
end

return d end function a.c()
return function(b)
return{


Primary="Icon",

White=Color3.new(1,1,1),
Black=Color3.new(0,0,0),

Dialog="Accent",

Background="Accent",
BackgroundTransparency=0,
Hover="Text",

PanelBackground="White",
PanelBackgroundTransparency=0.95,

WindowBackground="Background",

WindowShadow="Black",


WindowTopbarTitle="Text",
WindowTopbarAuthor="Text",
WindowTopbarIcon="Icon",
WindowTopbarButtonIcon="Icon",


WindowSearchBarBackground="Dialog",

TabBackground="Hover",
TabBackgroundHover="Hover",
TabBackgroundHoverTransparency=0.97,
TabBackgroundActive="Hover",
TabBackgroundActiveTransparency=0.93,
TabText="Text",
TabTextTransparency=0.3,
TabTextTransparencyActive=0,
TabTitle="Text",
TabIcon="Icon",
TabIconTransparency=0.4,
TabIconTransparencyActive=0.1,
TabBorderTransparency=1,
TabBorderTransparencyActive=0.75,
TabBorder="White",

ElementBackground="Text",
ElementBackgroundTransparency=0.93,
ElementBackgroundHover=b:AddColor("ElementBackground","#ffffff",0.1),
ElementTitle="Text",
ElementDesc="Text",
ElementIcon="Icon",

PopupBackground="Background",
PopupBackgroundTransparency="BackgroundTransparency",
PopupTitle="Text",
PopupContent="Text",
PopupIcon="Icon",

DialogBackground="Dialog",
DialogBackgroundTransparency="BackgroundTransparency",
DialogTitle="Text",
DialogContent="Text",
DialogIcon="Icon",

Toggle="Button",
ToggleBar="White",

Checkbox="Primary",
CheckboxIcon="White",
CheckboxBorder="White",
CheckboxBorderTransparency=0.75,

SliderIcon="Icon",

Slider="Primary",
SliderThumb="White",
SliderIconFrom="SliderIcon",
SliderIconTo="SliderIcon",

ProgressBar="Primary",
ProgressBarTrack="Text",
ProgressBarTrackTransparency=0.9,
ProgressBarText="Text",

Tooltip=Color3.fromHex"4C4C4C",
TooltipText="White",
TooltipSecondary="Primary",
TooltipSecondaryText="White",

TabSectionIcon="Icon",

SectionIcon="Icon",

SectionExpandIcon="Icon",
SectionExpandIconTransparency=0.4,
SectionBox="Text",
SectionBoxTransparency=0.95,
SectionBoxBorder="White",
SectionBoxBorderTransparency=0.75,
SectionBoxBackground="Text",
SectionBoxBackgroundTransparency=0.97,

SearchBarBorder="White",
SearchBarBorderTransparency=0.75,

Notification="Background",
Notification2="White",
Notification2Transparency=0.92,
NotificationTitle="Text",
NotificationTitleTransparency=0,
NotificationContent="Text",
NotificationContentTransparency=0.4,
NotificationDuration="White",
NotificationDurationTransparency=0.95,
NotificationBorder="White",
NotificationBorderTransparency=0.75,

DropdownTabBorder="White",
DropdownTabBackground="ElementBackground",
DropdownBackground="Background",

LabelBackground="White",
LabelBackgroundTransparency=0.95,

ViewportBackground="ElementBackground",
ViewportBackgroundTransparency="ElementBackgroundTransparency",
}
end end function a.d()

local b=(cloneref or clonereference or function(b)
return b
end)

local d=b(game:GetService"RunService")
local e=b(game:GetService"UserInputService")
local f=b(game:GetService"TweenService")
local g=b(game:GetService"LocalizationService")
local h=b(game:GetService"HttpService")

local i=a.load'a'local j=

d.Heartbeat

local l="https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"

local m
if d:IsStudio()or not writefile then
m=a.load'b'
else
m=a.load'b'
end

m.SetIconsType"lucide"

local p

local r
r={
Font="rbxassetid://12187365364",
Localization=nil,
CanDraggable=true,
Theme=nil,
Themes=nil,
Icons=m,
Signals={},
Objects={},
LocalizationObjects={},
UIScale=1,
FontObjects={},
Language=string.match(g.SystemLocaleId,"^[a-z]+"),
Request=http_request or(syn and syn.request)or request,
DefaultProperties={
ScreenGui={
ResetOnSpawn=false,
ZIndexBehavior="Sibling",
},
CanvasGroup={
BorderSizePixel=0,
BackgroundColor3=Color3.new(1,1,1),
},
Frame={
BorderSizePixel=0,
BackgroundColor3=Color3.new(1,1,1),
},
TextLabel={
BackgroundColor3=Color3.new(1,1,1),
BorderSizePixel=0,
Text="",
RichText=true,
TextColor3=Color3.new(1,1,1),
TextSize=14,
},
TextButton={
BackgroundColor3=Color3.new(1,1,1),
BorderSizePixel=0,
Text="",
AutoButtonColor=false,
TextColor3=Color3.new(1,1,1),
TextSize=14,
},
TextBox={
BackgroundColor3=Color3.new(1,1,1),
BorderColor3=Color3.new(0,0,0),
ClearTextOnFocus=false,
Text="",
TextColor3=Color3.new(0,0,0),
TextSize=14,
},
ImageLabel={
BackgroundTransparency=1,
BackgroundColor3=Color3.new(1,1,1),
BorderSizePixel=0,
},
ImageButton={
BackgroundColor3=Color3.new(1,1,1),
BorderSizePixel=0,
AutoButtonColor=false,
},
UIListLayout={
SortOrder="LayoutOrder",
},
ScrollingFrame={
ScrollBarImageTransparency=1,
BorderSizePixel=0,
},
VideoFrame={
BorderSizePixel=0,
},
},
Colors={
Red="#e53935",
Orange="#f57c00",
Green="#43a047",
Blue="#039be5",
White="#ffffff",
Grey="#484848",
},
ThemeFallbacks=nil,





















ThemeChangeCallbacks={},
}

function r.Init(u)
p=u

r.ThemeFallbacks=a.load'c'(r)

r.UIScale=u.UIScale

i:Init(r)
end

function r.AddSignal(u,v)
local x=u:Connect(v)
table.insert(r.Signals,x)
return x
end

function r.DisconnectAll()
for u,v in next,r.Signals do
local x=table.remove(r.Signals,u)
x:Disconnect()
end
end

function r.SafeCallback(u,...)
if not u then
return
end

local v,x=pcall(u,...)
if not v then
if p and p.Window and p.Window.Debug then local
z, A=x:find":%d+: "

warn("[ WindUI: DEBUG Mode ] "..x)

return p:Notify{
Title="DEBUG Mode: Error",
Content=not A and x or x:sub(A+1),
Duration=8,
}
end
end
end

function r.Gradient(u,v)
if p and p.Gradient then
return p:Gradient(u,v)
end

local x={}
local z={}

for A,B in next,u do
local C=tonumber(A)
if C then
C=math.clamp(C/100,0,1)
table.insert(x,ColorSequenceKeypoint.new(C,B.Color))
table.insert(z,NumberSequenceKeypoint.new(C,B.Transparency or 0))
end
end

table.sort(x,function(A,B)
return A.Time<B.Time
end)
table.sort(z,function(A,B)
return A.Time<B.Time
end)

if#x<2 then
error"ColorSequence requires at least 2 keypoints"
end

local A={
Color=ColorSequence.new(x),
Transparency=NumberSequence.new(z),
}

if v then
for B,C in pairs(v)do
A[B]=C
end
end

return A
end

function r.SetTheme(u)
local v=r.Theme
r.Theme=u
r.UpdateTheme(nil,false)

for x,z in next,r.ThemeChangeCallbacks do
r.SafeCallback(z,u,v)
end
end

function r.AddFontObject(u)
table.insert(r.FontObjects,u)
r.UpdateFont(r.Font)
end

function r.UpdateFont(u)
r.Font=u
for v,x in next,r.FontObjects do
x.FontFace=Font.new(u,x.FontFace.Weight,x.FontFace.Style)
end
end

function r.GetThemeProperty(u,v)
local function getValue(x,z)
local A=z[x]

if A==nil then
return nil
end

if typeof(A)=="string"and string.sub(A,1,1)=="#"then
return Color3.fromHex(A)
end

if typeof(A)=="Color3"then
return A
end

if typeof(A)=="number"then
return A
end

if typeof(A)=="table"and A.Color and A.Transparency then
return A
end

if typeof(A)=="function"then
return A(z)
end

return A
end

local x=getValue(u,v)
if x~=nil then
if typeof(x)=="string"and string.sub(x,1,1)~="#"then
local z=r.GetThemeProperty(x,v)
if z~=nil then
return z
end
else
return x
end
end

local z=r.ThemeFallbacks[u]
if z~=nil then
if typeof(z)=="string"and string.sub(z,1,1)~="#"then
return r.GetThemeProperty(z,v)
else
return getValue(u,{[u]=z})
end
end

x=getValue(u,r.Themes.Dark)
if x~=nil then
if typeof(x)=="string"and string.sub(x,1,1)~="#"then
local A=r.GetThemeProperty(x,r.Themes.Dark)
if A~=nil then
return A
end
else
return x
end
end

if z~=nil then
if typeof(z)=="string"and string.sub(z,1,1)~="#"then
return r.GetThemeProperty(z,r.Themes.Dark)
else
return getValue(u,{[u]=z})
end
end

return nil
end

function r.AddThemeObject(u,v,x)
if r.Objects[u]then
for z,A in pairs(v)do
r.Objects[u].Properties[z]=A
end
else
r.Objects[u]={Object=u,Properties=v}
end

if not x then
r.UpdateTheme(u,false)
end
return u
end

function r.AddLangObject(u)
local v=r.LocalizationObjects[u]
if not v then
return
end

local x=v.Object

r.SetLangForObject(u)

return x
end

function r.UpdateTheme(u,v,x,z,A,B)
local function ApplyTheme(C)
for F,G in pairs(C.Properties or{})do
local H=r.GetThemeProperty(G,r.Theme)
if H~=nil then
if typeof(H)=="Color3"then
local J=C.Object:FindFirstChild"LibraryGradient"
if J then
J:Destroy()
end

if x then
r.Tween(
C.Object,
z or 0.2,
{[F]=H},
A or Enum.EasingStyle.Quint,
B or Enum.EasingDirection.Out
):Play()
elseif v then
r.Tween(C.Object,0.08,{[F]=H}):Play()
else
C.Object[F]=H
end
elseif typeof(H)=="table"and H.Color and H.Transparency then
C.Object[F]=Color3.new(1,1,1)

local J=C.Object:FindFirstChild"LibraryGradient"
if not J then
J=Instance.new"UIGradient"
J.Name="LibraryGradient"
J.Parent=C.Object
end

J.Color=H.Color
J.Transparency=H.Transparency

for L,M in pairs(H)do
if L~="Color"and L~="Transparency"and J[L]~=nil then
J[L]=M
end
end
elseif typeof(H)=="number"then
if x then
r.Tween(
C.Object,
z or 0.2,
{[F]=H},
A or Enum.EasingStyle.Quint,
B or Enum.EasingDirection.Out
):Play()
elseif v then
r.Tween(C.Object,0.08,{[F]=H}):Play()
else
C.Object[F]=H
end
end
else
local J=C.Object:FindFirstChild"LibraryGradient"
if J then
J:Destroy()
end
end
end
end

if u then
local C=r.Objects[u]
if C then
ApplyTheme(C)
end
else
for C,F in pairs(r.Objects)do
ApplyTheme(F)
end
end
end

function r.SetThemeTag(u,v,x,z,A)
r.AddThemeObject(u,v)
r.UpdateTheme(u,false,true,x,z,A)
end

function r.SetLangForObject(u)
if r.Localization and r.Localization.Enabled then
local v=r.LocalizationObjects[u]
if not v then
return
end

local x=v.Object
local z=v.TranslationId

local A=r.Localization.Translations[r.Language]
if A and A[z]then
x.Text=A[z]
else
local B=r.Localization
and r.Localization.Translations
and r.Localization.Translations.en
or nil
if B and B[z]then
x.Text=B[z]
else
x.Text="["..z.."]"
end
end
end
end

function r.ChangeTranslationKey(u,v,x)
if r.Localization and r.Localization.Enabled then
local z=string.match(x,"^"..r.Localization.Prefix.."(.+)")
if z then
for A,B in ipairs(r.LocalizationObjects)do
if B.Object==v then
B.TranslationId=z
r.SetLangForObject(A)
return
end
end

table.insert(r.LocalizationObjects,{
TranslationId=z,
Object=v,
})
r.SetLangForObject(#r.LocalizationObjects)
end
end
end

function r.UpdateLang(u)
if u then
r.Language=u
end

for v=1,#r.LocalizationObjects do
local x=r.LocalizationObjects[v]
if x.Object and x.Object.Parent~=nil then
r.SetLangForObject(v)
else
r.LocalizationObjects[v]=nil
end
end
end

function r.SetLanguage(u)
r.Language=u
r.UpdateLang()
end

function r.Icon(u,v)
return m.Icon2(u,nil,v~=false)
end

function r.AddIcons(u,v)
return m.AddIcons(u,v)
end

function r.New(u,v,x)
local z=Instance.new(u)

for A,B in next,r.DefaultProperties[u]or{}do
z[A]=B
end

for A,B in next,v or{}do
if A~="ThemeTag"then
z[A]=B
end
if r.Localization and r.Localization.Enabled and A=="Text"then
local C=string.match(B,"^"..r.Localization.Prefix.."(.+)")
if C then
local F=#r.LocalizationObjects+1
r.LocalizationObjects[F]={TranslationId=C,Object=z}

r.SetLangForObject(F)
end
end
end

for A,B in next,x or{}do
B.Parent=z
end

if v and v.ThemeTag then
r.AddThemeObject(z,v.ThemeTag)
end
if v and v.FontFace then
r.AddFontObject(z)
end
return z
end

function r.Tween(u,v,x,...)
return f:Create(u,TweenInfo.new(v,...),x)
end








































































function r.NewRoundFrame(u,v,x,z,A,B)
return i:New(u,v,x,z,A,nil)
end

local u=r.New local v=
r.Tween

function r.SetDraggable(x)
r.CanDraggable=x
end

function r.Drag(x,z,A)
local B=p.GenerateGUID()

local C
local F=false
local G,H
local J

local L={
CanDraggable=true,
}

if not z or typeof(z)~="table"then
z={x}
end

local function update(M)
if not F or not L.CanDraggable then
return
end

local N=M.Position-G
r.Tween(x,0.02,{
Position=UDim2.new(
H.X.Scale,
H.X.Offset+N.X,
H.Y.Scale,
H.Y.Offset+N.Y
),
}):Play()
end

for M,N in pairs(z)do
N.InputBegan:Connect(function(O)
if not L.CanDraggable or F then
return
end

if
O.UserInputType==Enum.UserInputType.MouseButton1
or O.UserInputType==Enum.UserInputType.Touch
then
if p and p.CurrentInput and p.CurrentInput~=B then
return
end

p.CurrentInput=B

F=true
J=O
C=N
G=O.Position
H=x.Position

if A and typeof(A)=="function"then
A(true,C)
end
end
end)
end

e.InputChanged:Connect(function(M)
if not F then
return
end
if p.CurrentInput and p.CurrentInput~=B then
return
end

if J.UserInputType==Enum.UserInputType.MouseButton1 then
if M.UserInputType==Enum.UserInputType.MouseMovement then
update(M)
end
elseif J.UserInputType==Enum.UserInputType.Touch then
if M==J then
update(M)
end
end
end)

e.InputEnded:Connect(function(M)
if not F or p.CurrentInput~=B then
return
end

if
M==J
or(
J.UserInputType==Enum.UserInputType.MouseButton1
and M.UserInputType==Enum.UserInputType.MouseButton1
)
then
p.CurrentInput=nil
F=false
J=nil
C=nil

if A and typeof(A)=="function"then
A(false,nil)
end
end
end)

function L.Set(M,N)
L.CanDraggable=N
end

return L
end

m.Init(u,"Icon")

function r.SanitizeFilename(x)
local z=x:match"([^/]+)$"or x

z=z:gsub("%.[^%.]+$","")

z=z:gsub("[^%w%-_]","_")

if#z>50 then
z=z:sub(1,50)
end

return z
end

function r.Image(x,z,A,B,C,F,G,H)
B=B or"Temp"
z=r.SanitizeFilename(z)

local J=u("Frame",{
Size=UDim2.new(0,0,0,0),
BackgroundTransparency=1,
},{
u("ImageLabel",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
ScaleType="Crop",
ThemeTag=(r.Icon(x)or G)and{
ImageColor3=F and(H or"Icon")or nil,
}or nil,
},{
u("UICorner",{
CornerRadius=UDim.new(0,A),
}),
}),
})
if r.Icon(x)then
J.ImageLabel:Destroy()

local L=m.Image{
Icon=x,
Size=UDim2.new(1,0,1,0),
Colors={
(F and(H or"Icon")or false),
"Button",
},
}.IconFrame
L.Parent=J
elseif string.find(x,"http")and not string.find(x,"roblox.com")then
local L="WindUI/"..B.."/assets/."..C.."-"..z..".png"
local M,N=pcall(function()
task.spawn(function()
local M=r.Request
and r.Request{
Url=x,
Method="GET",
}.Body
or{}

if not d:IsStudio()and writefile then
writefile(L,M)
end


local N,O=pcall(getcustomasset,L)
if N then
J.ImageLabel.Image=O
else
warn(
string.format(
"[ WindUI.Creator ] Failed to load custom asset '%s': %s",
L,
tostring(O)
)
)
J:Destroy()

return
end
end)
end)
if not M then
warn(
"[ WindUI.Creator ]  '"..identifyexecutor()
or"Studio".."' doesnt support the URL Images. Error: "..N
)

J:Destroy()
end
elseif x==""then
J.Visible=false
else
J.ImageLabel.Image=x
end

return J
end

function r.Color3ToHSB(x)
local z,A,B=x.R,x.G,x.B
local C=math.max(z,A,B)
local F=math.min(z,A,B)
local G=C-F

local H=0
if G~=0 then
if C==z then
H=(A-B)/G%6
elseif C==A then
H=(B-z)/G+2
else
H=(z-A)/G+4
end
H=H*60
else
H=0
end

local J=(C==0)and 0 or(G/C)
local L=C

return{
h=math.floor(H+0.5),
s=J,
b=L,
}
end

function r.GetPerceivedBrightness(x)
local z=x.R
local A=x.G
local B=x.B
return 0.299*z+0.587*A+0.114*B
end

function r.GetTextColorForHSB(x,z)
local A=r.Color3ToHSB(x)local
B, C, F=A.h, A.s, A.b
if r.GetPerceivedBrightness(x)>(z or 0.5)then
return Color3.fromHSV(B/360,0,0.05)
else
return Color3.fromHSV(B/360,0,0.98)
end
end

function r.GetAverageColor(x)
local z,A,B=0,0,0
local C=x.Color.Keypoints
for F,G in ipairs(C)do

z=z+G.Value.R
A=A+G.Value.G
B=B+G.Value.B
end
local F=#C
return Color3.new(z/F,A/F,B/F)
end

function r.GenerateUniqueID(x)
return h:GenerateGUID(false)
end

function r.OnThemeChange(x,z)
if typeof(z)~="function"then
return
end

local A=h:GenerateGUID(false)
r.ThemeChangeCallbacks[A]=z

return{
Disconnect=function()
r.ThemeChangeCallbacks[A]=nil
end,
}
end

function r.AddColor(x,z,A,B)
B=math.clamp(B or 1,0,1)
if typeof(A)=="string"then
A=Color3.fromHex(A)
end

return function(C)
local F
if typeof(z)=="string"and string.sub(z,1,1)~="#"then
F=r.GetThemeProperty(z,C)
elseif typeof(z)=="string"then
F=Color3.fromHex(z)
else
F=z
end

if not F or typeof(F)~="Color3"then
return nil
end

return Color3.new(
math.clamp(F.R+A.R*B,0,1),
math.clamp(F.G+A.G*B,0,1),
math.clamp(F.B+A.B*B,0,1)
)
end
end

function r.GetElementPosition(x,z,A,B)
if type(A)~="number"or A~=math.floor(A)then
return nil,1
end






local C=#z


if C==0 or A<1 or A>C then
return nil,2
end

local function isDelimiter(F)
if F==nil then
return true
end
local G=F.__type
return G=="Divider"or G=="Space"or G=="Section"
end

if isDelimiter(z[A])then
return nil,3
end

local function calculate(F,G)
if G==1 then
return"Squircle"
end
if F==1 then
return B and"SquircleH-TL-TR"or"Squircle-TL-TR"
end
if F==G then
return B and"SquircleH-BL-BR"or"Squircle-BL-BR"
end
return"Square"
end

local F=1
local G=0

for H=1,C do
local J=z[H]
if isDelimiter(J)then
if A>=F and A<=H-1 then
local L=A-F+1
return calculate(L,G)
end
F=H+1
G=0
else
G=G+1
end
end

if A>=F and A<=C then
local H=A-F+1
return calculate(H,G)
end

return nil,4
end

return r end function a.e()

local b={}







function b.New(d,e,f)
local g={
Enabled=e.Enabled or false,
Translations=e.Translations or{},
Prefix=e.Prefix or"loc:",
DefaultLanguage=e.DefaultLanguage or"en"
}

f.Localization=g

return g
end



return b end function a.f()
local b=a.load'd'
local d=b.New
local e=b.Tween

local f={
Size=UDim2.new(0,300,1,-156),
SizeLower=UDim2.new(0,300,1,-56),
UICorner=18,
UIPadding=14,

Holder=nil,
NotificationIndex=0,
Notifications={},
}

function f.Init(g)
local h={
Lower=false,
}

function h.SetLower(i)
h.Lower=i
h.Frame.Size=i and f.SizeLower or f.Size
end

h.Frame=d("Frame",{
Position=UDim2.new(1,-29,0,56),
AnchorPoint=Vector2.new(1,0),
Size=f.Size,
Parent=g,
BackgroundTransparency=1,




},{
d("UIListLayout",{
HorizontalAlignment="Center",
SortOrder="LayoutOrder",
VerticalAlignment="Bottom",
Padding=UDim.new(0,8),
}),
d("UIPadding",{
PaddingBottom=UDim.new(0,29),
}),
})
return h
end

function f.New(g)
local h={
Title=g.Title or"Notification",
Content=g.Content or nil,
Icon=g.Icon or nil,
IconThemed=g.IconThemed,
Background=g.Background,
BackgroundImageTransparency=g.BackgroundImageTransparency,
Duration=g.Duration or 5,
Buttons=g.Buttons or{},
CanClose=g.CanClose~=false,
UIElements={},
Closed=false,
}



f.NotificationIndex=f.NotificationIndex+1
f.Notifications[f.NotificationIndex]=h









local i

if h.Icon then





















i=b.Image(
h.Icon,
h.Title..":"..h.Icon,
0,
g.Window,
"Notification",
h.IconThemed
)
i.Size=UDim2.new(0,26,0,26)
i.Position=UDim2.new(0,f.UIPadding,0,f.UIPadding)

end

local l
if h.CanClose then
l=d("ImageButton",{
Image=b.Icon"x"[1],
ImageRectSize=b.Icon"x"[2].ImageRectSize,
ImageRectOffset=b.Icon"x"[2].ImageRectPosition,
BackgroundTransparency=1,
Size=UDim2.new(0,16,0,16),
Position=UDim2.new(1,-f.UIPadding,0,f.UIPadding),
AnchorPoint=Vector2.new(1,0),
ThemeTag={
ImageColor3="Text",
},
ImageTransparency=0.4,
},{
d("TextButton",{
Size=UDim2.new(1,8,1,8),
BackgroundTransparency=1,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Text="",
}),
})
end

local m=b.NewRoundFrame(f.UICorner,"Squircle",{
Size=UDim2.new(0,0,1,0),
ThemeTag={
ImageTransparency="NotificationDurationTransparency",
ImageColor3="NotificationDuration",
},

})

local p=d("Frame",{
Size=UDim2.new(1,h.Icon and-28-f.UIPadding or 0,1,0),
Position=UDim2.new(1,0,0,0),
AnchorPoint=Vector2.new(1,0),
BackgroundTransparency=1,
AutomaticSize="Y",
},{
d("UIPadding",{
PaddingTop=UDim.new(0,f.UIPadding),
PaddingLeft=UDim.new(0,f.UIPadding),
PaddingRight=UDim.new(0,f.UIPadding),
PaddingBottom=UDim.new(0,f.UIPadding),
}),
d("TextLabel",{
AutomaticSize="Y",
Size=UDim2.new(1,-30-f.UIPadding,0,0),
TextWrapped=true,
TextXAlignment="Left",
RichText=true,
BackgroundTransparency=1,
TextSize=18,
ThemeTag={
TextColor3="NotificationTitle",
TextTransparency="NotificationTitleTransparency",
},
Text=h.Title,
FontFace=Font.new(b.Font,Enum.FontWeight.SemiBold),
}),
d("UIListLayout",{
Padding=UDim.new(0,f.UIPadding/3),
}),
})

if h.Content then
d("TextLabel",{
AutomaticSize="Y",
Size=UDim2.new(1,0,0,0),
TextWrapped=true,
TextXAlignment="Left",
RichText=true,
BackgroundTransparency=1,

TextSize=15,
ThemeTag={
TextColor3="NotificationContent",
TextTransparency="NotificationContentTransparency",
},
Text=h.Content,
FontFace=Font.new(b.Font,Enum.FontWeight.Medium),
Parent=p,
})
end

local r=b.NewRoundFrame(f.UICorner,"Squircle",{
Size=UDim2.new(1,0,0,0),
Position=UDim2.new(2,0,1,0),
AnchorPoint=Vector2.new(0,1),
AutomaticSize="Y",
ImageTransparency=0.05,
ThemeTag={
ImageColor3="Notification",
},

},{
b.NewRoundFrame(f.UICorner,"Squircle",{
Size=UDim2.new(1,0,1,0),
ThemeTag={
ImageColor3="Notification2",
ImageTransparency="Notification2Transparency",
},
}),
d("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
Name="DurationFrame",
},{






d("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
ClipsDescendants=true,
},{
m,
}),




}),
d("ImageLabel",{
Name="Background",
Image=h.Background,
BackgroundTransparency=1,
Size=UDim2.new(1,0,1,0),
ScaleType="Crop",
ImageTransparency=h.BackgroundImageTransparency,

},{
d("UICorner",{
CornerRadius=UDim.new(0,f.UICorner),
}),
}),

p,
i,
l,
})

local u=d("Frame",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,0,0),
Parent=g.Holder,
},{
r,
})

function h.Close(v)
if not h.Closed then
h.Closed=true
e(
u,
0.45,
{Size=UDim2.new(1,0,0,-8)},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
e(r,0.55,{Position=UDim2.new(2,0,1,0)},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
task.wait(0.45)
u:Destroy()
end
end

task.spawn(function()
task.wait()
e(
u,
0.45,
{Size=UDim2.new(1,0,0,r.AbsoluteSize.Y)},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
e(r,0.45,{Position=UDim2.new(0,0,1,0)},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
if h.Duration then
m.Size=UDim2.new(0,r.DurationFrame.AbsoluteSize.X,1,0)
e(
r.DurationFrame.Frame,
h.Duration,
{Size=UDim2.new(0,0,1,0)},
Enum.EasingStyle.Linear,
Enum.EasingDirection.InOut
):Play()
task.wait(h.Duration)
h:Close()
end
end)

if l then
b.AddSignal(l.TextButton.MouseButton1Click,function()
h:Close()
end)
end


return h
end

return f end function a.g()












local b=4294967296;local d=b-1;local function c(e,f)local g,h=0,1;while e~=0 or f~=0 do local i,l=e%2,f%2;local m=(i+l)%2;g=g+m*h;e=math.floor(e/2)f=math.floor(f/2)h=h*2 end;return g%b end;local function k(e,f,g,...)local h;if f then e=e%b;f=f%b;h=c(e,f)if g then h=k(h,g,...)end;return h elseif e then return e%b else return 0 end end;local function n(e,f,g,...)local h;if f then e=e%b;f=f%b;h=(e+f-c(e,f))/2;if g then h=n(h,g,...)end;return h elseif e then return e%b else return d end end;local function o(e)return d-e end;local function q(e,f)if f<0 then return lshift(e,-f)end;return math.floor(e%4294967296/2^f)end;local function s(e,f)if f>31 or f<-31 then return 0 end;return q(e%b,f)end;local function lshift(e,f)if f<0 then return s(e,-f)end;return e*2^f%4294967296 end;local function t(e,f)e=e%b;f=f%32;local g=n(e,2^f-1)return s(e,f)+lshift(g,32-f)end;local e={0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}local function w(f)return string.gsub(f,".",function(g)return string.format("%02x",string.byte(g))end)end;local function y(f,g)local h=""for i=1,g do local l=f%256;h=string.char(l)..h;f=(f-l)/256 end;return h end;local function D(f,g)local h=0;for i=g,g+3 do h=h*256+string.byte(f,i)end;return h end;local function E(f,g)local h=64-(g+9)%64;g=y(8*g,8)f=f.."\128"..string.rep("\0",h)..g;assert(#f%64==0)return f end;local function I(f)f[1]=0x6a09e667;f[2]=0xbb67ae85;f[3]=0x3c6ef372;f[4]=0xa54ff53a;f[5]=0x510e527f;f[6]=0x9b05688c;f[7]=0x1f83d9ab;f[8]=0x5be0cd19;return f end;local function K(f,g,h)local i={}for l=1,16 do i[l]=D(f,g+(l-1)*4)end;for l=17,64 do local m=i[l-15]local p=k(t(m,7),t(m,18),s(m,3))m=i[l-2]i[l]=(i[l-16]+p+i[l-7]+k(t(m,17),t(m,19),s(m,10)))%b end;local l,m,p,r,u,v,x,z=h[1],h[2],h[3],h[4],h[5],h[6],h[7],h[8]for A=1,64 do local B=k(t(l,2),t(l,13),t(l,22))local C=k(n(l,m),n(l,p),n(m,p))local F=(B+C)%b;local G=k(t(u,6),t(u,11),t(u,25))local H=k(n(u,v),n(o(u),x))local J=(z+G+H+e[A]+i[A])%b;z=x;x=v;v=u;u=(r+J)%b;r=p;p=m;m=l;l=(J+F)%b end;h[1]=(h[1]+l)%b;h[2]=(h[2]+m)%b;h[3]=(h[3]+p)%b;h[4]=(h[4]+r)%b;h[5]=(h[5]+u)%b;h[6]=(h[6]+v)%b;h[7]=(h[7]+x)%b;h[8]=(h[8]+z)%b end;local function Z(f)f=E(f,#f)local g=I{}for h=1,#f,64 do K(f,h,g)end;return w(y(g[1],4)..y(g[2],4)..y(g[3],4)..y(g[4],4)..y(g[5],4)..y(g[6],4)..y(g[7],4)..y(g[8],4))end;local f;local g={["\\"]="\\",["\""]="\"",["\b"]="b",["\f"]="f",["\n"]="n",["\r"]="r",["\t"]="t"}local h={["/"]="/"}for i,l in pairs(g)do h[l]=i end;local i=function(i)return"\\"..(g[i]or string.format("u%04x",i:byte()))end;local l=function(l)return"null"end;local m=function(m,p)local r={}p=p or{}if p[m]then error"circular reference"end;p[m]=true;if rawget(m,1)~=nil or next(m)==nil then local u=0;for v in pairs(m)do if type(v)~="number"then error"invalid table: mixed or invalid key types"end;u=u+1 end;if u~=#m then error"invalid table: sparse array"end;for v,x in ipairs(m)do table.insert(r,f(x,p))end;p[m]=nil;return"["..table.concat(r,",").."]"else for u,v in pairs(m)do if type(u)~="string"then error"invalid table: mixed or invalid key types"end;table.insert(r,f(u,p)..":"..f(v,p))end;p[m]=nil;return"{"..table.concat(r,",").."}"end end;local p=function(p)return'"'..p:gsub('[%z\1-\31\\"]',i)..'"'end;local r=function(r)if r~=r or r<=-math.huge or r>=math.huge then error("unexpected number value '"..tostring(r).."'")end;return string.format("%.14g",r)end;local u={["nil"]=l,table=m,string=p,number=r,boolean=tostring}f=function(v,x)local z=type(v)local A=u[z]if A then return A(v,x)end;error("unexpected type '"..z.."'")end;local v=function(v)return f(v)end;local x;local z=function(...)local z={}for A=1,select("#",...)do z[select(A,...)]=true end;return z end;local A=z(" ","\t","\r","\n")local B=z(" ","\t","\r","\n","]","}",",")local C=z("\\","/",'"',"b","f","n","r","t","u")local F=z("true","false","null")local G={["true"]=true,["false"]=false,null=nil}local H=function(H,J,L,M)for N=J,#H do if L[H:sub(N,N)]~=M then return N end end;return#H+1 end;local J=function(J,L,M)local N=1;local O=1;for P=1,L-1 do O=O+1;if J:sub(P,P)=="\n"then N=N+1;O=1 end end;error(string.format("%s at line %d col %d",M,N,O))end;local L=function(L)local M=math.floor;if L<=0x7f then return string.char(L)elseif L<=0x7ff then return string.char(M(L/64)+192,L%64+128)elseif L<=0xffff then return string.char(M(L/4096)+224,M(L%4096/64)+128,L%64+128)elseif L<=0x10ffff then return string.char(M(L/262144)+240,M(L%262144/4096)+128,M(L%4096/64)+128,L%64+128)end;error(string.format("invalid unicode codepoint '%x'",L))end;local M=function(M)local N=tonumber(M:sub(1,4),16)local O=tonumber(M:sub(7,10),16)if O then return L((N-0xd800)*0x400+O-0xdc00+0x10000)else return L(N)end end;local N=function(N,O)local P=""local Q=O+1;local R=Q;while Q<=#N do local S=N:byte(Q)if S<32 then J(N,Q,"control character in string")elseif S==92 then P=P..N:sub(R,Q-1)Q=Q+1;local T=N:sub(Q,Q)if T=="u"then local U=N:match("^[dD][89aAbB]%x%x\\u%x%x%x%x",Q+1)or N:match("^%x%x%x%x",Q+1)or J(N,Q-1,"invalid unicode escape in string")P=P..M(U)Q=Q+#U else if not C[T]then J(N,Q-1,"invalid escape char '"..T.."' in string")end;P=P..h[T]end;R=Q+1 elseif S==34 then P=P..N:sub(R,Q-1)return P,Q+1 end;Q=Q+1 end;J(N,O,"expected closing quote for string")end;local O=function(O,P)local Q=H(O,P,B)local R=O:sub(P,Q-1)local S=tonumber(R)if not S then J(O,P,"invalid number '"..R.."'")end;return S,Q end;local P=function(P,Q)local R=H(P,Q,B)local S=P:sub(Q,R-1)if not F[S]then J(P,Q,"invalid literal '"..S.."'")end;return G[S],R end;local Q=function(Q,R)local S={}local T=1;R=R+1;while 1 do local U;R=H(Q,R,A,true)if Q:sub(R,R)=="]"then R=R+1;break end;U,R=x(Q,R)S[T]=U;T=T+1;R=H(Q,R,A,true)local V=Q:sub(R,R)R=R+1;if V=="]"then break end;if V~=","then J(Q,R,"expected ']' or ','")end end;return S,R end;local R=function(R,S)local T={}S=S+1;while 1 do local U,V;S=H(R,S,A,true)if R:sub(S,S)=="}"then S=S+1;break end;if R:sub(S,S)~='"'then J(R,S,"expected string for key")end;U,S=x(R,S)S=H(R,S,A,true)if R:sub(S,S)~=":"then J(R,S,"expected ':' after key")end;S=H(R,S+1,A,true)V,S=x(R,S)T[U]=V;S=H(R,S,A,true)local W=R:sub(S,S)S=S+1;if W=="}"then break end;if W~=","then J(R,S,"expected '}' or ','")end end;return T,S end;local S={['"']=N,["0"]=O,["1"]=O,["2"]=O,["3"]=O,["4"]=O,["5"]=O,["6"]=O,["7"]=O,["8"]=O,["9"]=O,["-"]=O,t=P,f=P,n=P,["["]=Q,["{"]=R}x=function(T,U)local V=T:sub(U,U)local W=S[V]if W then return W(T,U)end;J(T,U,"unexpected character '"..V.."'")end;local T=function(T)if type(T)~="string"then error("expected argument of type string, got "..type(T))end;local U,V=x(T,H(T,1,A,true))V=H(T,V,A,true)if V<=#T then J(T,V,"trailing garbage")end;return U end;
local U,V,W=v,T,Z;





local X={}

local Y=(cloneref or clonereference or function(Y)return Y end)


function X.New(_,aa)

local ab=_;
local ac=aa;
local ad=true;


local ae=function(ae)end;


repeat task.wait(1)until game:IsLoaded();


local af=false;
local ag,ah,ai,aj,ak,al,am,an,ao=setclipboard or toclipboard,request or http_request or syn_request,string.char,tostring,string.sub,os.time,math.random,math.floor,gethwid or function()return Y(game:GetService"Players").LocalPlayer.UserId end
local ap,aq="",0;


local ar="https://api.platoboost.app";
local as=ah{
Url=ar.."/public/connectivity",
Method="GET"
};
if as.StatusCode~=200 and as.StatusCode~=429 then
ar="https://api.platoboost.net";
end


function cacheLink()
if aq+(600)<al()then
local at=ah{
Url=ar.."/public/start",
Method="POST",
Body=U{
service=ab,
identifier=W(ao())
},
Headers={
["Content-Type"]="application/json",
["User-Agent"]="Roblox/Exploit"
}
};

if at.StatusCode==200 then
local au=V(at.Body);

if au.success==true then
ap=au.data.url;
aq=al();
return true,ap
else
ae(au.message);
return false,au.message
end
elseif at.StatusCode==429 then
local au="you are being rate limited, please wait 20 seconds and try again.";
ae(au);
return false,au
end

local au="Failed to cache link.";
ae(au);
return false,au
else
return true,ap
end
end

cacheLink();


local at=function()
local at=""
for au=1,16 do
at=at..ai(an(am()*(26))+97)
end
return at
end


for au=1,5 do
local av=at();
task.wait(0.2)
if at()==av then
local aw="platoboost nonce error.";
ae(aw);
error(aw);
end
end


local au=function()
local au,av=cacheLink();

if au then
ag(av);
end
end


local av=function(av)
local aw=at();
local ax=ar.."/public/redeem/"..aj(ab);

local ay={
identifier=W(ao()),
key=av
}

if ad then
ay.nonce=aw;
end

local az=ah{
Url=ax,
Method="POST",
Body=U(ay),
Headers={
["Content-Type"]="application/json"
}
};

if az.StatusCode==200 then
local aA=V(az.Body);

if aA.success==true then
if aA.data.valid==true then
if ad then
if aA.data.hash==W("true".."-"..aw.."-"..ac)then
return true
else
ae"failed to verify integrity.";
return false
end
else
return true
end
else
ae"key is invalid.";
return false
end
else
if ak(aA.message,1,27)=="unique constraint violation"then
ae"you already have an active key, please wait for it to expire before redeeming it.";
return false
else
ae(aA.message);
return false
end
end
elseif az.StatusCode==429 then
ae"you are being rate limited, please wait 20 seconds and try again.";
return false
else
ae"server returned an invalid status code, please try again later.";
return false
end
end


local aw=function(aw)
if af==true then
return false,("A request is already being sent, please slow down.")
else
af=true;
end

local ax=at();
local ay=ar.."/public/whitelist/"..aj(ab).."?identifier="..W(ao()).."&key="..aw;

if ad then
ay=ay.."&nonce="..ax;
end

local az=ah{
Url=ay,
Method="GET",
};

af=false;

if az.StatusCode==200 then
local aA=V(az.Body);

if aA.success==true then
if aA.data.valid==true then
if ad then
if aA.data.hash==W("true".."-"..ax.."-"..ac)then
return true,""
else
return false,("failed to verify integrity.")
end
else
return true
end
else
if ak(aw,1,4)=="KEY_"then
return true,av(aw)
else
return false,("Key is invalid.")
end
end
else
return false,(aA.message)
end
elseif az.StatusCode==429 then
return false,("You are being rate limited, please wait 20 seconds and try again.")
else
return false,("Server returned an invalid status code, please try again later.")
end
end


local ax=function(ax)
local ay=at();
local az=ar.."/public/flag/"..aj(ab).."?name="..ax;

if ad then
az=az.."&nonce="..ay;
end

local aA=ah{
Url=az,
Method="GET",
};

if aA.StatusCode==200 then
local aB=V(aA.Body);

if aB.success==true then
if ad then
if aB.data.hash==W(aj(aB.data.value).."-"..ay.."-"..ac)then
return aB.data.value
else
ae"failed to verify integrity.";
return nil
end
else
return aB.data.value
end
else
ae(aB.message);
return nil
end
else
return nil
end
end


return{
Verify=aw,
GetFlag=ax,
Copy=au,
}
end


return X end function a.h()






local aa=(cloneref or clonereference or function(aa)
return aa
end)

local ab=aa(game:GetService"HttpService")
local ac={}

function ac.New(ad)
local ae=gethwid or function()
return aa(game:GetService"Players").LocalPlayer.UserId
end
local af,ag=request or http_request or syn_request,setclipboard or toclipboard

function ValidateKey(ah)
local ai="https://api.pandauth.com/api/v1/keys/validate"

local aj={
ServiceID=ad,
HWID=tostring(ae()),
Key=tostring(ah),
}

local ak=ab:JSONEncode(aj)
local al,am=pcall(function()
return af{
Url=ai,
Method="POST",
Headers={
["User-Agent"]="Roblox/Exploit",
["Content-Type"]="application/json",
},
Body=ak,
}
end)

if al and am then
if am.Success then
local an,ao=pcall(function()
return ab:JSONDecode(am.Body)
end)

if an and ao then
if ao.Authenticated_Status and ao.Authenticated_Status=="Success"then
return true,"Authenticated"
else
local ap=ao.Note or"Unknown reason"
return false,"Authentication failed: "..ap
end
else
return false,"JSON decode error"
end
else
warn(
" HTTP request was not successful. Code: "
..tostring(am.StatusCode)
.." Message: "
..am.StatusMessage
)
return false,"HTTP request failed: "..am.StatusMessage
end
else
return false,"Request pcall error"
end
end

function GetKeyLink()
return"https://new.pandadevelopment.net/getkey/"..tostring(ad).."?hwid="..tostring(ae())
end

function CopyLink()
return ag(GetKeyLink())
end

return{
Verify=ValidateKey,
Copy=CopyLink,
}
end

return ac end function a.i()







local aa={}

function aa.New(ab,ac)
local ad="https://sdkapi-public.luarmor.net/library.lua"

local ae=loadstring(game.HttpGet and game:HttpGet(ad)or HttpService:GetAsync(ad))()
local af=setclipboard or toclipboard

ae.script_id=ab

function ValidateKey(ag)
local ah=ae.check_key(ag)


if ah.code=="KEY_VALID"then
return true,"Whitelisted!"
elseif ah.code=="KEY_HWID_LOCKED"then
return false,"Key linked to a different HWID. Please reset it using our bot"
elseif ah.code=="KEY_INCORRECT"then
return false,"Key is wrong or deleted!"
else
return false,"Key check failed:"..ah.message.." Code: "..ah.code
end
end

function CopyLink()
af(tostring(ac))
end

return{
Verify=ValidateKey,
Copy=CopyLink,
}
end

return aa end function a.j()









local aa={}

function aa.New(ab,ac,ad)
JunkieProtected.API_KEY=ac
JunkieProtected.PROVIDER=ad
JunkieProtected.SERVICE_ID=ab

local function ValidateKey(ae)
if not ae or ae==""then
print"No key provided!"

return false,"No key provided. Please get a key."
end

local af=JunkieProtected.IsKeylessMode()
if af and af.keyless_mode then
print"Keyless mode enabled. Starting script..."
return true,"Keyless mode enabled. Starting script..."
end

local ag=JunkieProtected.ValidateKey{Key=ae}
if ag=="valid"then
print"Key is valid! Starting script..."
load()
if _G.JD_IsPremium then
print"Premium user detected!"
else
print"Standard user"
end

return true,"Key is valid!"
else
local ah=JunkieProtected.GetKeyLink()
print"Invalid key!"

return false,"Invalid key. Get one from:"..ah
end
end

local function copyLink()
local ae=JunkieProtected.GetKeyLink()

if setclipboard then
setclipboard(ae)
end
end
return{
Verify=ValidateKey,
Copy=copyLink
}
end

return aa end function a.k()



return{
platoboost={
Name="Platoboost",
Icon="rbxassetid://75920162824531",
Args={"ServiceId","Secret"},

New=a.load'g'.New
},
pandadevelopment={
Name="Panda Development",
Icon="panda",
Args={"ServiceId"},

New=a.load'h'.New
},
luarmor={
Name="Luarmor",
Icon="rbxassetid://130918283130165",
Args={"ScriptId","Discord"},

New=a.load'i'.New
},
junkiedevelopment={
Name="Junkie Development",
Icon="rbxassetid://106310347705078",
Args={"ServiceId","ApiKey","Provider"},

New=a.load'j'.New
},


}end function a.l()



return[[
{
    "name": "windui",
    "version": "1.6.65",
    "main": "./dist/main.lua",
    "repository": "https://github.com/Footagesus/WindUI",
    "discord": "https://discord.gg/ftgs-development-hub-1300692552005189632",
    "author": "Footagesus",
    "description": "Roblox UI Library for scripts",
    "license": "MIT",
    "scripts": {
        "dev": "bash build/build.sh dev $INPUT_FILE",
        "build": "bash build/build.sh build $INPUT_FILE",
        "live": "python3 -m http.server 8642",
        "watch": "chokidar . -i 'node_modules' -i 'dist' -i 'build' -c 'npm run dev --'",
        "live-build": "concurrently \"npm run live\" \"npm run watch --\"",
        "example-live-build": "INPUT_FILE=main_example.lua npm run live-build",
        "updater": "python3 updater/main.py"
    },
    "keywords": [
        "ui-library",
        "ui-design",
        "script",
        "script-hub",
        "exploiting"
    ],
    "devDependencies": {
        "chokidar-cli": "^3.0.0",
        "concurrently": "^9.2.0"
    }
}
]]end function a.m()

local aa={}

local ab=a.load'd'
local ac=ab.New
local ad=ab.Tween

function aa.New(ae,af,ag,ah,ai,aj,ak,al)
ah=ah or"Primary"
local am=al or(not ak and 10 or 999)
local an
if af and af~=""then
an=ac("ImageLabel",{
Image=ab.Icon(af)[1],
ImageRectSize=ab.Icon(af)[2].ImageRectSize,
ImageRectOffset=ab.Icon(af)[2].ImageRectPosition,
Size=UDim2.new(0,21,0,21),
BackgroundTransparency=1,
ImageColor3=ah=="White"and Color3.new(0,0,0)or nil,
ImageTransparency=ah=="White"and 0.4 or 0,
ThemeTag={
ImageColor3=ah~="White"and"Icon"or nil,
},
})
end

local ao=ac("TextButton",{
Size=UDim2.new(0,0,1,0),
AutomaticSize="X",
Parent=ai,
BackgroundTransparency=1,
},{
ab.NewRoundFrame(am,"Squircle",{
ThemeTag={
ImageColor3=ah~="White"and"Button"or nil,
},
ImageColor3=ah=="White"and Color3.new(1,1,1)or nil,
Size=UDim2.new(1,0,1,0),
Name="Squircle",
ImageTransparency=ah=="Primary"and 0 or ah=="White"and 0 or 0.9,
}),

ab.NewRoundFrame(am,"Squircle",{



ImageColor3=Color3.new(1,1,1),
Size=UDim2.new(1,0,1,0),
Name="Special",
ImageTransparency=ah=="Secondary"and 0.95 or 1,
}),

ab.NewRoundFrame(am,"Shadow-sm",{



ImageColor3=Color3.new(0,0,0),
Size=UDim2.new(1,3,1,3),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Name="Shadow",

ImageTransparency=1,
Visible=not ak,
}),

ab.NewRoundFrame(am,"SquircleGlass",{
ThemeTag={
ImageColor3="White",
},
Size=UDim2.new(1,1,1,1),

ImageTransparency=0.9,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Name="Outline",
},{













}),

ab.NewRoundFrame(am,"Squircle",{
Size=UDim2.new(1,0,1,0),
Name="Frame",
ThemeTag={
ImageColor3=ah~="White"and"Text"or nil,
},
ImageColor3=ah=="White"and Color3.new(0,0,0)or nil,
ImageTransparency=1,
},{
ac("UIPadding",{
PaddingLeft=UDim.new(0,16),
PaddingRight=UDim.new(0,16),
}),
ac("UIListLayout",{
FillDirection="Horizontal",
Padding=UDim.new(0,8),
VerticalAlignment="Center",
HorizontalAlignment="Center",
}),
an,
ac("TextLabel",{
BackgroundTransparency=1,
FontFace=Font.new(ab.Font,Enum.FontWeight.SemiBold),
Text=ae or"Button",
ThemeTag={
TextColor3=(ah~="Primary"and ah~="White")and"Text",
},
TextColor3=ah=="Primary"and Color3.new(1,1,1)
or ah=="White"and Color3.new(0,0,0)
or nil,
AutomaticSize="XY",
TextSize=18,
}),
}),
})

ab.AddSignal(ao.MouseEnter,function()
ad(ao.Frame,0.047,{ImageTransparency=0.95}):Play()
end)
ab.AddSignal(ao.MouseLeave,function()
ad(ao.Frame,0.047,{ImageTransparency=1}):Play()
end)
ab.AddSignal(ao.MouseButton1Click,function()
if aj then
aj:Close()()
end
if ag then
ab.SafeCallback(ag)
end
end)

return ao
end

return aa end function a.n()

local aa={}

local ab=a.load'd'
local ac=ab.New local ad=
ab.Tween

function aa.New(ae,af,ag,ah,ai,aj,ak,al,am)
ah=ah or"Input"
local an=ak or 10
local ao
if af and af~=""then
ao=ac("ImageLabel",{
Image=ab.Icon(af)[1],
ImageRectSize=ab.Icon(af)[2].ImageRectSize,
ImageRectOffset=ab.Icon(af)[2].ImageRectPosition,
Size=UDim2.new(0,21,0,21),
BackgroundTransparency=1,
ThemeTag={
ImageColor3="Icon",
},
})
end

local ap=ah=="Textarea"

local aq=ac("TextBox",{
BackgroundTransparency=1,
TextSize=17,
FontFace=Font.new(ab.Font,Enum.FontWeight.Regular),
Size=UDim2.new(1,ao and-29 or 0,1,0),
PlaceholderText=ae,
ClearTextOnFocus=al or false,
ClipsDescendants=true,
TextWrapped=ap,
MultiLine=ap,
TextXAlignment="Left",
TextYAlignment=ah~="Textarea"and"Center"or"Top",

ThemeTag={
PlaceholderColor3="PlaceholderText",
TextColor3="Text",
},
})

local ar=ac("Frame",{
Size=UDim2.new(1,0,0,42),
Parent=ag,
BackgroundTransparency=1,
},{
ac("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
},{
ab.NewRoundFrame(an,"Squircle",{
ThemeTag={
ImageColor3="Placeholder",
},
Size=UDim2.new(1,0,1,0),
ImageTransparency=0.85,
}),
not am and ab.NewRoundFrame(an-1,"SquircleGlass",{
ThemeTag={
ImageColor3="Outline",
},
Size=UDim2.new(1,1,1,1),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
ImageTransparency=0.8,
})or nil,
ab.NewRoundFrame(an,"Squircle",{
Size=UDim2.new(1,0,1,0),
Name="Frame",
ThemeTag={
ImageColor3="LabelBackground",
ImageTransparency="LabelBackgroundTransparency",
},


},{
ac("UIPadding",{
PaddingTop=UDim.new(0,ah~="Textarea"and 0 or 12),
PaddingLeft=UDim.new(0,12),
PaddingRight=UDim.new(0,12),
PaddingBottom=UDim.new(0,ah~="Textarea"and 0 or 12),
}),
ac("UIListLayout",{
FillDirection="Horizontal",
Padding=UDim.new(0,8),
VerticalAlignment=ah~="Textarea"and"Center"or"Top",
HorizontalAlignment="Left",
}),
ao,
aq,
}),
}),
})










if aj then
ab.AddSignal(aq:GetPropertyChangedSignal"Text",function()
if ai then
ab.SafeCallback(ai,aq.Text)
end
end)
else
ab.AddSignal(aq.FocusLost,function()
if ai then
ab.SafeCallback(ai,aq.Text)
end
end)
end

return ar
end

return aa end function a.o()

local aa=a.load'd'
local ab=aa.New
local ac=aa.Tween




local ad={
Holder=nil,

Parent=nil,
}

function ad.Create(ae,af,ag,ah,ai)
local aj={
UICorner=28,
UIPadding=12,

Window=ag,
WindUI=ah,

UIElements={},
}

if ae then
aj.UIPadding=0
end
if ae then
aj.UICorner=26
end

af=af or"Dialog"

if not ae then
aj.UIElements.FullScreen=ab("Frame",{
ZIndex=999,
BackgroundTransparency=1,
BackgroundColor3=Color3.fromHex"#000000",
Size=UDim2.new(1,0,1,0),
Active=false,
Visible=false,
Parent=ad.Parent
or(ag and ag.UIElements and ag.UIElements.Main and ag.UIElements.Main.Main),
},{
ab("UICorner",{
CornerRadius=UDim.new(0,ag.UICorner),
}),
})
end

ab("ImageLabel",{
Image="rbxassetid://8992230677",
ThemeTag={
ImageColor3="WindowShadow",

},
ImageTransparency=1,
Size=UDim2.new(1,100,1,100),
Position=UDim2.new(0,-50,0,-50),
ScaleType="Slice",
SliceCenter=Rect.new(99,99,99,99),
BackgroundTransparency=1,
ZIndex=-999999999999999,
Name="Blur",
})

aj.UIElements.Main=ab("Frame",{
Size=UDim2.new(0,280,0,0),
ThemeTag={
BackgroundColor3=af.."Background",
},
AutomaticSize="Y",
BackgroundTransparency=1,
Visible=false,
ZIndex=99999,
},{
ab("UIPadding",{
PaddingTop=UDim.new(0,aj.UIPadding),
PaddingLeft=UDim.new(0,aj.UIPadding),
PaddingRight=UDim.new(0,aj.UIPadding),
PaddingBottom=UDim.new(0,aj.UIPadding),
}),
})

aj.UIElements.MainContainer=aa.NewRoundFrame(aj.UICorner,"Squircle",{
Visible=false,

ImageTransparency=ae and 0.15 or 0,
Parent=ai or aj.UIElements.FullScreen,
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
AutomaticSize="XY",
ThemeTag={
ImageColor3=af.."Background",
ImageTransparency=af.."BackgroundTransparency",
},
ZIndex=9999,
},{






aj.UIElements.Main,




















})

function aj.Open(ak)
if not ae then
aj.UIElements.FullScreen.Visible=true
aj.UIElements.FullScreen.Active=true
end

task.spawn(function()
aj.UIElements.MainContainer.Visible=true

if not ae then
ac(aj.UIElements.FullScreen,0.1,{BackgroundTransparency=0.65}):Play()
end
ac(aj.UIElements.MainContainer,0.1,{ImageTransparency=0}):Play()


task.spawn(function()
task.wait(0.05)
aj.UIElements.Main.Visible=true
end)
end)
end
function aj.Close(ak)
if not ae then
ac(aj.UIElements.FullScreen,0.1,{BackgroundTransparency=1}):Play()
aj.UIElements.FullScreen.Active=false
task.spawn(function()
task.wait(0.1)
aj.UIElements.FullScreen.Visible=false
end)
end
aj.UIElements.Main.Visible=false

ac(aj.UIElements.MainContainer,0.1,{ImageTransparency=1}):Play()



task.spawn(function()
task.wait(0.1)
if not ae then
aj.UIElements.FullScreen:Destroy()
else
aj.UIElements.MainContainer:Destroy()
end
end)

return function()end
end


return aj
end

return ad end function a.p()

local aa={}

local ab=a.load'd'
local ac=ab.New
local ad=ab.Tween

local ae=a.load'm'.New
local af=a.load'n'.New

function aa.new(ag,ah,ai,aj)
local ak=a.load'o'
local al=ak.Create(true,"Popup",ag.Window,ag.WindUI,ag.WindUI.ScreenGui.KeySystem)

local am={}

local an

local ao=(ag.KeySystem.Thumbnail and ag.KeySystem.Thumbnail.Width)or 200

local ap=430
if ag.KeySystem.Thumbnail and ag.KeySystem.Thumbnail.Image then
ap=430+(ao/2)
end

al.UIElements.Main.AutomaticSize="Y"
al.UIElements.Main.Size=UDim2.new(0,ap,0,0)

local aq

if ag.Icon then
aq=
ab.Image(ag.Icon,ag.Title..":"..ag.Icon,0,"Temp","KeySystem",ag.IconThemed)
aq.Size=UDim2.new(0,24,0,24)
aq.LayoutOrder=-1
end

local ar=ac("TextLabel",{
AutomaticSize="XY",
BackgroundTransparency=1,
Text=ag.KeySystem.Title or ag.Title,
FontFace=Font.new(ab.Font,Enum.FontWeight.SemiBold),
ThemeTag={
TextColor3="Text",
},
TextSize=20,
})

local as=ac("TextLabel",{
AutomaticSize="XY",
BackgroundTransparency=1,
Text="Key System",
AnchorPoint=Vector2.new(1,0.5),
Position=UDim2.new(1,0,0.5,0),
TextTransparency=1,
FontFace=Font.new(ab.Font,Enum.FontWeight.Medium),
ThemeTag={
TextColor3="Text",
},
TextSize=16,
})

local at=ac("Frame",{
BackgroundTransparency=1,
AutomaticSize="XY",
},{
ac("UIListLayout",{
Padding=UDim.new(0,14),
FillDirection="Horizontal",
VerticalAlignment="Center",
}),
aq,
ar,
})

local au=ac("Frame",{
AutomaticSize="Y",
Size=UDim2.new(1,0,0,0),
BackgroundTransparency=1,
},{





at,
as,
})

local av=af("Enter Key","key",nil,"Input",function(av)
an=av
end)

local aw
if ag.KeySystem.Note and ag.KeySystem.Note~=""then
aw=ac("TextLabel",{
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
FontFace=Font.new(ab.Font,Enum.FontWeight.Medium),
TextXAlignment="Left",
Text=ag.KeySystem.Note,
TextSize=18,
TextTransparency=0.4,
ThemeTag={
TextColor3="Text",
},
BackgroundTransparency=1,
RichText=true,
TextWrapped=true,
})
end

local ax=ac("Frame",{
Size=UDim2.new(1,0,0,42),
BackgroundTransparency=1,
},{
ac("Frame",{
BackgroundTransparency=1,
AutomaticSize="X",
Size=UDim2.new(0,0,1,0),
},{
ac("UIListLayout",{
Padding=UDim.new(0,9),
FillDirection="Horizontal",
}),
}),
})

local ay
if ag.KeySystem.Thumbnail and ag.KeySystem.Thumbnail.Image then
local az
if ag.KeySystem.Thumbnail.Title then
az=ac("TextLabel",{
Text=ag.KeySystem.Thumbnail.Title,
ThemeTag={
TextColor3="Text",
},
TextSize=18,
FontFace=Font.new(ab.Font,Enum.FontWeight.Medium),
BackgroundTransparency=1,
AutomaticSize="XY",
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
})
end
ay=ac("ImageLabel",{
Image=ag.KeySystem.Thumbnail.Image,
BackgroundTransparency=1,
Size=UDim2.new(0,ao,1,-12),
Position=UDim2.new(0,6,0,6),
Parent=al.UIElements.Main,
ScaleType="Crop",
},{
az,
ac("UICorner",{
CornerRadius=UDim.new(0,20),
}),
})
end

ac("Frame",{

Size=UDim2.new(1,ay and-ao or 0,1,0),
Position=UDim2.new(0,ay and ao or 0,0,0),
BackgroundTransparency=1,
Parent=al.UIElements.Main,
},{
ac("Frame",{

Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
},{
ac("UIListLayout",{
Padding=UDim.new(0,18),
FillDirection="Vertical",
}),
au,
aw,
av,
ax,
ac("UIPadding",{
PaddingTop=UDim.new(0,16),
PaddingLeft=UDim.new(0,16),
PaddingRight=UDim.new(0,16),
PaddingBottom=UDim.new(0,16),
}),
}),
})





local az=ae("Exit","log-out",function()
al:Close()()
end,"Tertiary",ax.Frame)

if ay then
az.Parent=ay
az.Size=UDim2.new(0,0,0,42)
az.Position=UDim2.new(0,10,1,-10)
az.AnchorPoint=Vector2.new(0,1)
end

if ag.KeySystem.URL then
ae("Get key","key",function()
setclipboard(ag.KeySystem.URL)
end,"Secondary",ax.Frame)
end

if ag.KeySystem.API then








local aA=240
local aB=false
local b=ae("Get key","key",nil,"Secondary",ax.Frame)

local d=ab.NewRoundFrame(99,"Squircle",{
Size=UDim2.new(0,1,1,0),
ThemeTag={
ImageColor3="Text",
},
ImageTransparency=0.9,
})

ac("Frame",{
BackgroundTransparency=1,
Size=UDim2.new(0,0,1,0),
AutomaticSize="X",
Parent=b.Frame,
},{
d,
ac("UIPadding",{
PaddingLeft=UDim.new(0,5),
PaddingRight=UDim.new(0,5),
}),
})

local f=ab.Image("chevron-down","chevron-down",0,"Temp","KeySystem",true)

f.Size=UDim2.new(1,0,1,0)

ac("Frame",{
Size=UDim2.new(0,21,0,21),
Parent=b.Frame,
BackgroundTransparency=1,
},{
f,
})

local g=ab.NewRoundFrame(15,"Squircle",{
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
ThemeTag={
ImageColor3="Background",
},
},{
ac("UIPadding",{
PaddingTop=UDim.new(0,5),
PaddingLeft=UDim.new(0,5),
PaddingRight=UDim.new(0,5),
PaddingBottom=UDim.new(0,5),
}),
ac("UIListLayout",{
FillDirection="Vertical",
Padding=UDim.new(0,5),
}),
})

local h=ac("Frame",{
BackgroundTransparency=1,
Size=UDim2.new(0,aA,0,0),
ClipsDescendants=true,
AnchorPoint=Vector2.new(1,0),
Parent=b,
Position=UDim2.new(1,0,1,15),
},{
g,
})

ac("TextLabel",{
Text="Select Service",
BackgroundTransparency=1,
FontFace=Font.new(ab.Font,Enum.FontWeight.Medium),
ThemeTag={TextColor3="Text"},
TextTransparency=0.2,
TextSize=16,
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
TextWrapped=true,
TextXAlignment="Left",
Parent=g,
},{
ac("UIPadding",{
PaddingTop=UDim.new(0,10),
PaddingLeft=UDim.new(0,10),
PaddingRight=UDim.new(0,10),
PaddingBottom=UDim.new(0,10),
}),
})

for i,l in next,ag.KeySystem.API do
local m=ag.WindUI.Services[l.Type]
if m then
local p={}
for r,u in next,m.Args do
table.insert(p,l[u])
end

local r=m.New(table.unpack(p))
r.Type=l.Type
table.insert(am,r)

local u=ab.Image(
l.Icon or m.Icon or Icons[l.Type]or"user",
l.Icon or m.Icon or Icons[l.Type]or"user",
0,
"Temp",
"KeySystem",
true
)
u.Size=UDim2.new(0,24,0,24)

local v=ab.NewRoundFrame(10,"Squircle",{
Size=UDim2.new(1,0,0,0),
ThemeTag={ImageColor3="Text"},
ImageTransparency=1,
Parent=g,
AutomaticSize="Y",
},{
ac("UIListLayout",{
FillDirection="Horizontal",
Padding=UDim.new(0,10),
VerticalAlignment="Center",
}),
u,
ac("UIPadding",{
PaddingTop=UDim.new(0,10),
PaddingLeft=UDim.new(0,10),
PaddingRight=UDim.new(0,10),
PaddingBottom=UDim.new(0,10),
}),
ac("Frame",{
BackgroundTransparency=1,
Size=UDim2.new(1,-34,0,0),
AutomaticSize="Y",
},{
ac("UIListLayout",{
FillDirection="Vertical",
Padding=UDim.new(0,5),
HorizontalAlignment="Center",
}),
ac("TextLabel",{
Text=l.Title or m.Name,
BackgroundTransparency=1,
FontFace=Font.new(ab.Font,Enum.FontWeight.Medium),
ThemeTag={TextColor3="Text"},
TextTransparency=0.05,
TextSize=18,
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
TextWrapped=true,
TextXAlignment="Left",
}),
ac("TextLabel",{
Text=l.Desc or"",
BackgroundTransparency=1,
FontFace=Font.new(ab.Font,Enum.FontWeight.Regular),
ThemeTag={TextColor3="Text"},
TextTransparency=0.2,
TextSize=16,
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
TextWrapped=true,
Visible=l.Desc and true or false,
TextXAlignment="Left",
}),
}),
},true)

ab.AddSignal(v.MouseEnter,function()
ad(v,0.08,{ImageTransparency=0.95}):Play()
end)
ab.AddSignal(v.InputEnded,function()
ad(v,0.08,{ImageTransparency=1}):Play()
end)
ab.AddSignal(v.MouseButton1Click,function()
r.Copy()
ag.WindUI:Notify{
Title="Key System",
Content="Key link copied to clipboard.",
Image="key",
}
end)
end
end

ab.AddSignal(b.MouseButton1Click,function()
if not aB then
ad(
h,
0.3,
{Size=UDim2.new(0,aA,0,g.AbsoluteSize.Y+1)},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
ad(f,0.3,{Rotation=180},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
else
ad(
h,
0.25,
{Size=UDim2.new(0,aA,0,0)},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
ad(f,0.25,{Rotation=0},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end
aB=not aB
end)
end

local function handleSuccess(aA)
al:Close()()
writefile((ag.Folder or"Temp").."/"..ah..".key",tostring(aA))
task.wait(0.4)
ai(true)
end

local aA=ae("Submit","arrow-right",function()
local aA=tostring(an or"empty")local aB=
ag.Folder or ag.Title

if ag.KeySystem.KeyValidator then
local b=ag.KeySystem.KeyValidator(aA)

if b then
if ag.KeySystem.SaveKey then
handleSuccess(aA)
else
al:Close()()
task.wait(0.4)
ai(true)
end
else
ag.WindUI:Notify{
Title="Key System. Error",
Content="Invalid key.",
Icon="triangle-alert",
}
end
elseif not ag.KeySystem.API then
local b=type(ag.KeySystem.Key)=="table"and table.find(ag.KeySystem.Key,aA)
or ag.KeySystem.Key==aA

if b then
if ag.KeySystem.SaveKey then
handleSuccess(aA)
else
al:Close()()
task.wait(0.4)
ai(true)
end
end
else
local b,d
for f,g in next,am do
local h,i=g.Verify(aA)
if h then
b,d=true,i
break
end
d=i
end

if b then
handleSuccess(aA)
else
ag.WindUI:Notify{
Title="Key System. Error",
Content=d,
Icon="triangle-alert",
}
end
end
end,"Primary",ax)

aA.AnchorPoint=Vector2.new(1,0.5)
aA.Position=UDim2.new(1,0,0.5,0)










al:Open()
end

return aa end function a.q()




local aa=(cloneref or clonereference or function(aa)return aa end)


local function map(ab,ac,ad,ae,af)
return(ab-ac)*(af-ae)/(ad-ac)+ae
end

local function viewportPointToWorld(ab,ac)
local ad=aa(game:GetService"Workspace").CurrentCamera:ScreenPointToRay(ab.X,ab.Y)
return ad.Origin+ad.Direction*ac
end

local function getOffset()
local ab=aa(game:GetService"Workspace").CurrentCamera.ViewportSize.Y
return map(ab,0,2560,8,56)
end

return{viewportPointToWorld,getOffset}end function a.r()



local aa=(cloneref or clonereference or function(aa)return aa end)


local ab=a.load'd'
local ac=ab.New


local ad,ae=unpack(a.load'q')
local af=Instance.new("Folder",aa(game:GetService"Workspace").CurrentCamera)


local function createAcrylic()
local ag=ac("Part",{
Name="Body",
Color=Color3.new(0,0,0),
Material=Enum.Material.Glass,
Size=Vector3.new(1,1,0),
Anchored=true,
CanCollide=false,
Locked=true,
CastShadow=false,
Transparency=0.98,
},{
ac("SpecialMesh",{
MeshType=Enum.MeshType.Brick,
Offset=Vector3.new(0,0,-1E-6),
}),
})

return ag
end


local function createAcrylicBlur(ag)
local ah={}

ag=ag or 0.001
local ai={
topLeft=Vector2.new(),
topRight=Vector2.new(),
bottomRight=Vector2.new(),
}
local aj=createAcrylic()
aj.Parent=af

local function updatePositions(ak,al)
ai.topLeft=al
ai.topRight=al+Vector2.new(ak.X,0)
ai.bottomRight=al+ak
end

local function render()
local ak=aa(game:GetService"Workspace").CurrentCamera
if ak then
ak=ak.CFrame
end
local al=ak
if not al then
al=CFrame.new()
end

local am=al
local an=ai.topLeft
local ao=ai.topRight
local ap=ai.bottomRight

local aq=ad(an,ag)
local ar=ad(ao,ag)
local as=ad(ap,ag)

local at=(ar-aq).Magnitude
local au=(ar-as).Magnitude

aj.CFrame=
CFrame.fromMatrix((aq+as)/2,am.XVector,am.YVector,am.ZVector)
aj.Mesh.Scale=Vector3.new(at,au,0)
end

local function onChange(ak)
local al=ae()
local am=ak.AbsoluteSize-Vector2.new(al,al)
local an=ak.AbsolutePosition+Vector2.new(al/2,al/2)

updatePositions(am,an)
task.spawn(render)
end

local function renderOnChange()
local ak=aa(game:GetService"Workspace").CurrentCamera
if not ak then
return
end

table.insert(ah,ak:GetPropertyChangedSignal"CFrame":Connect(render))
table.insert(ah,ak:GetPropertyChangedSignal"ViewportSize":Connect(render))
table.insert(ah,ak:GetPropertyChangedSignal"FieldOfView":Connect(render))
task.spawn(render)
end

aj.Destroying:Connect(function()
for ak,al in ah do
pcall(function()
al:Disconnect()
end)
end
end)

renderOnChange()

return onChange,aj
end

return function(ag)
local ah={}
local ai,aj=createAcrylicBlur(ag)

local ak=ac("Frame",{
BackgroundTransparency=1,
Size=UDim2.fromScale(1,1),
})

ab.AddSignal(ak:GetPropertyChangedSignal"AbsolutePosition",function()
ai(ak)
end)

ab.AddSignal(ak:GetPropertyChangedSignal"AbsoluteSize",function()
ai(ak)
end)

ah.AddParent=function(al)
ab.AddSignal(al:GetPropertyChangedSignal"Visible",function()

end)
end

ah.SetVisibility=function(al)
aj.Transparency=al and 0.98 or 1
end

ah.Frame=ak
ah.Model=aj

return ah
end end function a.s()


local aa=a.load'd'
local ab=a.load'r'

local ac=aa.New

return function(ad)
local ae={}

ae.Frame=ac("Frame",{
Size=UDim2.fromScale(1,1),
BackgroundTransparency=1,
BackgroundColor3=Color3.fromRGB(255,255,255),
BorderSizePixel=0,
},{












ac("UICorner",{
CornerRadius=UDim.new(0,8),
}),

ac("Frame",{
BackgroundTransparency=1,
Size=UDim2.fromScale(1,1),
Name="Background",
ThemeTag={
BackgroundColor3="AcrylicMain",
},
},{
ac("UICorner",{
CornerRadius=UDim.new(0,8),
}),
}),

ac("Frame",{
BackgroundColor3=Color3.fromRGB(255,255,255),
BackgroundTransparency=1,
Size=UDim2.fromScale(1,1),
},{










}),

ac("ImageLabel",{
Image="rbxassetid://9968344105",
ImageTransparency=0.98,
ScaleType=Enum.ScaleType.Tile,
TileSize=UDim2.new(0,128,0,128),
Size=UDim2.fromScale(1,1),
BackgroundTransparency=1,
},{
ac("UICorner",{
CornerRadius=UDim.new(0,8),
}),
}),

ac("ImageLabel",{
Image="rbxassetid://9968344227",
ImageTransparency=0.9,
ScaleType=Enum.ScaleType.Tile,
TileSize=UDim2.new(0,128,0,128),
Size=UDim2.fromScale(1,1),
BackgroundTransparency=1,
ThemeTag={
ImageTransparency="AcrylicNoise",
},
},{
ac("UICorner",{
CornerRadius=UDim.new(0,8),
}),
}),

ac("Frame",{
BackgroundTransparency=1,
Size=UDim2.fromScale(1,1),
ZIndex=2,
},{










}),
})


local af

task.wait()
if ad.UseAcrylic then
af=ab()

af.Frame.Parent=ae.Frame
ae.Model=af.Model
ae.AddParent=af.AddParent
ae.SetVisibility=af.SetVisibility
end

return ae,af
end end function a.t()



local aa=(cloneref or clonereference or function(aa)return aa end)


local ab={
AcrylicBlur=a.load'r',

AcrylicPaint=a.load's',
}

function ab.init()
local ac=Instance.new"DepthOfFieldEffect"
ac.FarIntensity=0
ac.InFocusRadius=0.1
ac.NearIntensity=1

local ad={}

function ab.Enable()
for ae,af in pairs(ad)do
af.Enabled=false
end
ac.Parent=aa(game:GetService"Lighting")
end

function ab.Disable()
for ae,af in pairs(ad)do
af.Enabled=af.enabled
end
ac.Parent=nil
end

local function registerDefaults()
local function register(ae)
if ae:IsA"DepthOfFieldEffect"then
ad[ae]={enabled=ae.Enabled}
end
end

for ae,af in pairs(aa(game:GetService"Lighting"):GetChildren())do
register(af)
end

if aa(game:GetService"Workspace").CurrentCamera then
for ae,af in pairs(aa(game:GetService"Workspace").CurrentCamera:GetChildren())do
register(af)
end
end
end

registerDefaults()
ab.Enable()
end

return ab end function a.u()

local aa={}

local ab=a.load'd'
local ac=ab.New local ad=
ab.Tween


function aa.new(ae,af)
local ag={
Title=ae.Title or"Dialog",
Content=ae.Content,
Icon=ae.Icon,
IconThemed=ae.IconThemed,
Thumbnail=ae.Thumbnail,
Buttons=ae.Buttons,

IconSize=22,
}

local ah=a.load'o'
local ai=ah.Create(true,"Popup",ae.WindUI.Window,ae.WindUI,af)

local aj=200

local ak=430
if ag.Thumbnail and ag.Thumbnail.Image then
ak=430+(aj/2)
end

ai.UIElements.Main.AutomaticSize="Y"
ai.UIElements.Main.Size=UDim2.new(0,ak,0,0)



local al

if ag.Icon then
al=ab.Image(
ag.Icon,
ag.Title..":"..ag.Icon,
0,
ae.WindUI.Window,
"Popup",
true,
ae.IconThemed,
"PopupIcon"
)
al.Size=UDim2.new(0,ag.IconSize,0,ag.IconSize)
al.LayoutOrder=-1
end


local am=ac("TextLabel",{
AutomaticSize="Y",
BackgroundTransparency=1,
Text=ag.Title,
TextXAlignment="Left",
FontFace=Font.new(ab.Font,Enum.FontWeight.SemiBold),
ThemeTag={
TextColor3="PopupTitle",
},
TextSize=20,
TextWrapped=true,
Size=UDim2.new(1,al and-ag.IconSize-14 or 0,0,0)
})

local an=ac("Frame",{
BackgroundTransparency=1,
AutomaticSize="XY",
},{
ac("UIListLayout",{
Padding=UDim.new(0,14),
FillDirection="Horizontal",
VerticalAlignment="Center"
}),
al,am
})

local ao=ac("Frame",{
AutomaticSize="Y",
Size=UDim2.new(1,0,0,0),
BackgroundTransparency=1,
},{





an,
})

local ap
if ag.Content and ag.Content~=""then
ap=ac("TextLabel",{
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
FontFace=Font.new(ab.Font,Enum.FontWeight.Medium),
TextXAlignment="Left",
Text=ag.Content,
TextSize=18,
TextTransparency=.2,
ThemeTag={
TextColor3="PopupContent",
},
BackgroundTransparency=1,
RichText=true,
TextWrapped=true,
})
end

local aq=ac("Frame",{
Size=UDim2.new(1,0,0,42),
BackgroundTransparency=1,
},{
ac("UIListLayout",{
Padding=UDim.new(0,9),
FillDirection="Horizontal",
HorizontalAlignment="Right"
})
})

local ar
if ag.Thumbnail and ag.Thumbnail.Image then
local as
if ag.Thumbnail.Title then
as=ac("TextLabel",{
Text=ag.Thumbnail.Title,
ThemeTag={
TextColor3="Text",
},
TextSize=18,
FontFace=Font.new(ab.Font,Enum.FontWeight.Medium),
BackgroundTransparency=1,
AutomaticSize="XY",
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
})
end
ar=ac("ImageLabel",{
Image=ag.Thumbnail.Image,
BackgroundTransparency=1,
Size=UDim2.new(0,aj,1,0),
Parent=ai.UIElements.Main,
ScaleType="Crop"
},{
as,
ac("UICorner",{
CornerRadius=UDim.new(0,0),
})
})
end

ac("Frame",{

Size=UDim2.new(1,ar and-aj or 0,1,0),
Position=UDim2.new(0,ar and aj or 0,0,0),
BackgroundTransparency=1,
Parent=ai.UIElements.Main
},{
ac("Frame",{

Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
},{
ac("UIListLayout",{
Padding=UDim.new(0,18),
FillDirection="Vertical",
}),
ao,
ap,
aq,
ac("UIPadding",{
PaddingTop=UDim.new(0,16),
PaddingLeft=UDim.new(0,16),
PaddingRight=UDim.new(0,16),
PaddingBottom=UDim.new(0,16),
})
}),
})

local as=a.load'm'.New

for at,au in next,ag.Buttons do
as(au.Title,au.Icon,au.Callback,au.Variant,aq,ai)
end

ai:Open()


return ag
end

return aa end function a.v()
return function(aa,ab)
return{
Dark={
Name="Dark",

Accent=Color3.fromHex"#18181b",
Dialog=Color3.fromHex"#1a1a1a",
Outline=Color3.fromHex"#FFFFFF",
Text=Color3.fromHex"#FFFFFF",
Placeholder=Color3.fromHex"#a1a1a1",
Background=Color3.fromHex"#101010",
Button=Color3.fromHex"#52525b",
Icon=Color3.fromHex"#a1a1aa",
Toggle=Color3.fromHex"#33C759",
Slider=Color3.fromHex"#0091FF",
Checkbox=Color3.fromHex"#0091FF",

PanelBackground=Color3.fromHex"#FFFFFF",
PanelBackgroundTransparency=0.95,

SliderIcon=Color3.fromHex"#908F95",
Primary=Color3.fromHex"#0091FF",


LabelBackground=Color3.fromHex"#000000",
LabelBackgroundTransparency=0.83,

ElementBackground=Color3.fromHex"#2A2A2C",
ElementBackgroundTransparency=0,
},

Light={
Name="Light",

Accent=Color3.fromHex"#efefef",
Dialog=Color3.fromHex"#f4f4f5",
Outline=Color3.fromHex"#ffffff",
Text=Color3.fromHex"#000000",
Placeholder=Color3.fromHex"#555555",
Background=Color3.fromHex"#FFFFFF",
Button=Color3.fromHex"#18181b",
Icon=Color3.fromHex"#52525b",
Toggle=Color3.fromHex"#33C759",
Slider=Color3.fromHex"#0091FF",
Checkbox=Color3.fromHex"#0091FF",

DropdownTabBackground=Color3.fromHex"#bebebe",
DropdownBackground=Color3.fromHex"#ffffff",

TabBackground=Color3.fromHex"#ffffff",
TabBackgroundHover=Color3.fromHex"#f3f3f3",
TabBackgroundHoverTransparency=0,
TabBackgroundActive=Color3.fromHex"#efefef",
TabBackgroundActiveTransparency=0,

PanelBackground=Color3.fromHex"#efefef",
PanelBackgroundTransparency=0,

LabelBackground=Color3.fromHex"#efefef",
LabelBackgroundTransparency=0,

ElementBackground=Color3.fromHex"#ffffff",
ElementBackgroundTransparency=0,
},

Rose={
Name="Rose",

Accent=Color3.fromHex"#be185d",
Dialog=Color3.fromHex"#4c0519",

Text=Color3.fromHex"#fdf2f8",
Placeholder=Color3.fromHex"#d67aa6",
Background=Color3.fromHex"#1f0308",
Button=Color3.fromHex"#e95f74",
Icon=Color3.fromHex"#fb7185",

ElementBackground=Color3.fromHex"#381E23",
ElementBackgroundTransparency=0,
},

Plant={
Name="Plant",

Accent=Color3.fromHex"#166534",
Dialog=Color3.fromHex"#052e16",

Text=Color3.fromHex"#f0fdf4",
Placeholder=Color3.fromHex"#4fbf7a",
Background=Color3.fromHex"#0a1b0f",
Button=Color3.fromHex"#16a34a",
Icon=Color3.fromHex"#4ade80",

ElementBackground=Color3.fromHex"#28342A",
ElementBackgroundTransparency=0,
},

Red={
Name="Red",

Accent=Color3.fromHex"#991b1b",
Dialog=Color3.fromHex"#450a0a",

Text=Color3.fromHex"#fef2f2",
Placeholder=Color3.fromHex"#d95353",
Background=Color3.fromHex"#1c0606",
Button=Color3.fromHex"#dc2626",
Icon=Color3.fromHex"#ef4444",

ElementBackground=Color3.fromHex"#322221",
ElementBackgroundTransparency=0,
},

Indigo={
Name="Indigo",

Accent=Color3.fromHex"#3730a3",
Dialog=Color3.fromHex"#1e1b4b",

Text=Color3.fromHex"#f1f5f9",
Placeholder=Color3.fromHex"#7078d9",
Background=Color3.fromHex"#0f0a2e",
Button=Color3.fromHex"#4f46e5",
Icon=Color3.fromHex"#6366f1",

ElementBackground=Color3.fromHex"#282543",
ElementBackgroundTransparency=0,
},

Sky={
Name="Sky",

Accent=Color3.fromHex"#00d4ff",
Dialog=Color3.fromHex"#0a4d66",

Text=Color3.fromHex"#e6f7ff",
Placeholder=Color3.fromHex"#66b3cc",
Background=Color3.fromHex"#051a26",
Button=Color3.fromHex"#00a8cc",
Icon=Color3.fromHex"#2db8d9",

Toggle=Color3.fromHex"#00d9d9",
Slider=Color3.fromHex"#00d4ff",
Checkbox=Color3.fromHex"#00d4ff",

PanelBackground=Color3.fromHex"#0d3a47",
PanelBackgroundTransparency=0.8,

ElementBackground=Color3.fromHex"#172E3B",
ElementBackgroundTransparency=0,
},

Violet={
Name="Violet",

Accent=Color3.fromHex"#6d28d9",
Dialog=Color3.fromHex"#3c1361",

Text=Color3.fromHex"#faf5ff",
Placeholder=Color3.fromHex"#8f7ee0",
Background=Color3.fromHex"#1e0a3e",
Button=Color3.fromHex"#7c3aed",
Icon=Color3.fromHex"#8b5cf6",

ElementBackground=Color3.fromHex"#342650",
ElementBackgroundTransparency=0,
},

Amber={
Name="Amber",

Accent=aa:Gradient({
["0"]={Color=Color3.fromHex"#b45309",Transparency=0},
["100"]={Color=Color3.fromHex"#d97706",Transparency=0},
},{Rotation=45}),

Dialog=aa:Gradient({
["0"]={Color=Color3.fromHex"#451a03",Transparency=0},
["100"]={Color=Color3.fromHex"#6b2e05",Transparency=0},
},{Rotation=90}),






Text=aa:Gradient({
["0"]={Color=Color3.fromHex"#fffbeb",Transparency=0},
["100"]={Color=Color3.fromHex"#fff7ed",Transparency=0},
},{Rotation=45}),

Placeholder=aa:Gradient({
["0"]={Color=Color3.fromHex"#d1a326",Transparency=0},
["100"]={Color=Color3.fromHex"#fbbf24",Transparency=0},
},{Rotation=45}),

Background=aa:Gradient({
["0"]={Color=Color3.fromHex"#1c1003",Transparency=0},
["100"]={Color=Color3.fromHex"#3f210d",Transparency=0},
},{Rotation=90}),

Button=aa:Gradient({
["0"]={Color=Color3.fromHex"#d97706",Transparency=0},
["100"]={Color=Color3.fromHex"#f59e0b",Transparency=0},
},{Rotation=45}),

Icon=Color3.fromHex"#f59e0b",

Toggle=aa:Gradient({
["0"]={Color=Color3.fromHex"#d97706",Transparency=0},
["100"]={Color=Color3.fromHex"#f59e0b",Transparency=0},
},{Rotation=45}),

Slider=Color3.fromHex"#d97706",

Checkbox=aa:Gradient({
["0"]={Color=Color3.fromHex"#d97706",Transparency=0},
["100"]={Color=Color3.fromHex"#fbbf24",Transparency=0},
},{Rotation=45}),

PanelBackground=Color3.fromHex"#FFFFFF",
PanelBackgroundTransparency=0.95,

ElementBackground=Color3.fromHex"#3A2E22",
ElementBackgroundTransparency=0,
},

Emerald={
Name="Emerald",

Accent=Color3.fromHex"#047857",
Dialog=Color3.fromHex"#022c22",

Text=Color3.fromHex"#ecfdf5",
Placeholder=Color3.fromHex"#3fbf8f",
Background=Color3.fromHex"#011411",
Button=Color3.fromHex"#059669",
Icon=Color3.fromHex"#10b981",

ElementBackground=Color3.fromHex"#202E2A",
ElementBackgroundTransparency=0,
},

Midnight={
Name="Midnight",

Accent=Color3.fromHex"#1e3a8a",
Dialog=Color3.fromHex"#0c1e42",

Text=Color3.fromHex"#dbeafe",
Placeholder=Color3.fromHex"#2f74d1",
Background=Color3.fromHex"#0a0f1e",
Button=Color3.fromHex"#2563eb",
Primary=Color3.fromHex"#2563eb",
Icon=Color3.fromHex"#5591f4",

ElementBackground=Color3.fromHex"#242836",
ElementBackgroundTransparency=0,
},

Crimson={
Name="Crimson",

Accent=Color3.fromHex"#b91c1c",
Dialog=Color3.fromHex"#450a0a",

Text=Color3.fromHex"#fef2f2",
Placeholder=Color3.fromHex"#6f757b",
Background=Color3.fromHex"#0c0404",
Button=Color3.fromHex"#991b1b",
Icon=Color3.fromHex"#dc2626",

ElementBackground=Color3.fromHex"#251F1F",
ElementBackgroundTransparency=0,
},

MonokaiPro={
Name="Monokai Pro",

Accent=Color3.fromHex"#fc9867",
Dialog=Color3.fromHex"#1e1e1e",

Text=Color3.fromHex"#fcfcfa",
Placeholder=Color3.fromHex"#afafaf",
Background=Color3.fromHex"#191622",
Button=Color3.fromHex"#ab9df2",
Icon=Color3.fromHex"#a9dc76",

ElementBackground=Color3.fromHex"#323039",
ElementBackgroundTransparency=0,

Metadata={
PullRequest=23,
},
},

CottonCandy={
Name="Cotton Candy",

Accent=Color3.fromHex"#ec4899",
Dialog=Color3.fromHex"#2d1b3d",

Text=Color3.fromHex"#fdf2f8",
Placeholder=Color3.fromHex"#8a5fd3",
Background=Color3.fromHex"#1a0b2e",
Button=Color3.fromHex"#d946ef",
Slider=Color3.fromHex"#d946ef",
Icon=Color3.fromHex"#06b6d4",

ElementBackground=Color3.fromHex"#312643",
ElementBackgroundTransparency=0,
},

Mellowsi={
Name="Mellowsi",

Accent=Color3.fromHex"#342A1E",
Dialog=Color3.fromHex"#291C13",

Text=Color3.fromHex"#F5EBDD",
Placeholder=Color3.fromHex"#9C8A73",
Background=Color3.fromHex"#1C1002",
Button=Color3.fromHex"#342A1E",
Icon=Color3.fromHex"#C9B79C",

Toggle=Color3.fromHex"#a9873f",
Slider=Color3.fromHex"#C9A24D",
Checkbox=Color3.fromHex"#C9A24D",

ElementBackground=Color3.fromHex"#33291E",
ElementBackgroundTransparency=0,

Metadata={
PullRequest=52,
},
},

Rainbow={
Name="Rainbow",

Accent=aa:Gradient({
["0"]={Color=Color3.fromHex"#00ff41",Transparency=0},
["33"]={Color=Color3.fromHex"#00ffff",Transparency=0},
["66"]={Color=Color3.fromHex"#0080ff",Transparency=0},
["100"]={Color=Color3.fromHex"#8000ff",Transparency=0},
},{Rotation=45}),

Dialog=aa:Gradient({
["0"]={Color=Color3.fromHex"#ff0080",Transparency=0},
["25"]={Color=Color3.fromHex"#8000ff",Transparency=0},
["50"]={Color=Color3.fromHex"#0080ff",Transparency=0},
["75"]={Color=Color3.fromHex"#00ff80",Transparency=0},
["100"]={Color=Color3.fromHex"#ff8000",Transparency=0},
},{Rotation=135}),


Text=Color3.fromHex"#ffffff",
Placeholder=Color3.fromHex"#00ff80",

Background=aa:Gradient({
["0"]={Color=Color3.fromHex"#ff0040",Transparency=0},
["20"]={Color=Color3.fromHex"#ff4000",Transparency=0},
["40"]={Color=Color3.fromHex"#ffff00",Transparency=0},
["60"]={Color=Color3.fromHex"#00ff40",Transparency=0},
["80"]={Color=Color3.fromHex"#0040ff",Transparency=0},
["100"]={Color=Color3.fromHex"#4000ff",Transparency=0},
},{Rotation=90}),

Button=aa:Gradient({
["0"]={Color=Color3.fromHex"#ff0080",Transparency=0},
["25"]={Color=Color3.fromHex"#ff8000",Transparency=0},
["50"]={Color=Color3.fromHex"#ffff00",Transparency=0},
["75"]={Color=Color3.fromHex"#80ff00",Transparency=0},
["100"]={Color=Color3.fromHex"#00ffff",Transparency=0},
},{Rotation=60}),

Icon=Color3.fromHex"#ffffff",
},
}
end end function a.w()

local aa={}

local ab=a.load'd'
local ac=ab.New local ad=
ab.Tween

function aa.New(ae,af,ag,ah,ai,aj)
local ak=ai or 10
local al
if af and af~=""then
al=ac("ImageLabel",{
Image=ab.Icon(af)[1],
ImageRectSize=ab.Icon(af)[2].ImageRectSize,
ImageRectOffset=ab.Icon(af)[2].ImageRectPosition,
Size=UDim2.new(0,21,0,21),
BackgroundTransparency=1,
ThemeTag={
ImageColor3="Icon",
},
})
end

local am=ac("TextLabel",{
BackgroundTransparency=1,
TextSize=17,
FontFace=Font.new(ab.Font,Enum.FontWeight.Regular),
Size=UDim2.new(1,al and-29 or 0,1,0),
TextXAlignment="Left",
ThemeTag={
TextColor3=ah and"Placeholder"or"Text",
},
Text=ae,
})

local an=ac("TextButton",{
Size=UDim2.new(1,0,0,42),
Parent=ag,
BackgroundTransparency=1,
Text="",
},{
ac("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
},{
ab.NewRoundFrame(ak,"Squircle",{
ThemeTag={
ImageColor3="Placeholder",
},
Size=UDim2.new(1,0,1,0),
ImageTransparency=0.85,
}),
not aj and ab.NewRoundFrame(ak,"SquircleGlass",{
ThemeTag={
ImageColor3="Outline",
},
Size=UDim2.new(1,1,1,1),
ImageTransparency=0.9,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
})or nil,
ab.NewRoundFrame(ak,"Squircle",{
Size=UDim2.new(1,0,1,0),
Name="Frame",
ThemeTag={
ImageColor3="LabelBackground",
ImageTransparency="LabelBackgroundTransparency",
},


},{
ac("UIPadding",{
PaddingLeft=UDim.new(0,12),
PaddingRight=UDim.new(0,12),
}),
ac("UIListLayout",{
FillDirection="Horizontal",
Padding=UDim.new(0,8),
VerticalAlignment="Center",
HorizontalAlignment="Left",
}),
al,
am,
}),
}),
})

return an
end

return aa end function a.x()

local aa={}

local ab=cloneref or clonereference or function(ab)
return ab
end
local ac=ab(game:GetService"UserInputService")

local ad=a.load'd'
local ae=ad.New

function aa.New(af,ag,ah,ai,aj)
local ak=ae("Frame",{
Size=UDim2.new(0,ai,1,0),
BackgroundTransparency=1,
Position=UDim2.new(1,0,0,0),
AnchorPoint=Vector2.new(1,0),
Parent=ag,
ZIndex=999,
Active=true,
})

local al=ad.NewRoundFrame(ai/2,"Squircle",{
Size=UDim2.new(1,0,0,0),
ImageTransparency=0.85,
ThemeTag={ImageColor3="Text"},
Parent=ak,
})

local am=ae("Frame",{
Size=UDim2.new(1,12,1,12),
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundTransparency=1,
Active=true,
ZIndex=999,
Parent=al,
})

local an=ad:GenerateUniqueID()
local ao=false
local ap,aq

local function UpdateVisuals()
local ar=af.AbsoluteCanvasSize.Y
local as=af.AbsoluteWindowSize.Y

if ar<=as then
al.Visible=false
return
end

al.Visible=true

local at=math.clamp(as/ar,0.05,1)
al.Size=UDim2.new(1,0,at,0)

local au=ar-as
local av=1-at

if au>0 then
local aw=af.CanvasPosition.Y/au
al.Position=UDim2.new(0,0,math.clamp(aw*av,0,av),0)
else
al.Position=UDim2.new(0,0,0,0)
end
end

local function StopDrag()
if aj.CurrentInput==an then
aj.CurrentInput=nil
end
ao=false
af.ScrollingEnabled=true
if ap then
ap:Disconnect()
end
if aq then
aq:Disconnect()
end
end

ad.AddSignal(am.InputBegan,function(ar)
if
ar.UserInputType~=Enum.UserInputType.MouseButton1
and ar.UserInputType~=Enum.UserInputType.Touch
then
return
end
if ao then
return
end
if aj.CurrentInput and aj.CurrentInput~=an then
return
end

aj.CurrentInput=an

ao=true
af.ScrollingEnabled=false

local as=ar.Position.Y
local at=af.CanvasPosition.Y

ap=ac.InputChanged:Connect(function(au)
if
au.UserInputType==Enum.UserInputType.MouseMovement
or au.UserInputType==Enum.UserInputType.Touch
then
local av=au.Position.Y-as

local aw=af.AbsoluteCanvasSize.Y
local ax=af.AbsoluteWindowSize.Y
local ay=math.max(aw-ax,0)

local az=ak.AbsoluteSize.Y
local aA=al.AbsoluteSize.Y
local aB=math.max(az-aA,1)

local b=av*(ay/aB)

af.CanvasPosition=
Vector2.new(af.CanvasPosition.X,math.clamp(at+b,0,ay))
end
end)

aq=ac.InputEnded:Connect(function(au)
if au.UserInputType==ar.UserInputType then
if aj.CurrentInput and aj.CurrentInput~=an then
return
end

aj.CurrentInput=nil

StopDrag()
end
end)
end)

ad.AddSignal(af:GetPropertyChangedSignal"AbsoluteWindowSize",UpdateVisuals)
ad.AddSignal(af:GetPropertyChangedSignal"AbsoluteCanvasSize",UpdateVisuals)
ad.AddSignal(af:GetPropertyChangedSignal"CanvasPosition",UpdateVisuals)

UpdateVisuals()

return ak
end

return aa end function a.y()

local aa={}

local ab=a.load'd'
local ac=ab.New
local ad=ab.Tween

function aa.New(ae,af,ag)
local ah={
Title=af.Title or"Tag",
Icon=af.Icon,
Color=af.Color or Color3.fromHex"#315dff",
Radius=af.Radius or 999,
Border=af.Border or false,

TagFrame=nil,
Height=26,
Padding=10,
TextSize=14,
IconSize=16,
}

local ai
if ah.Icon then
ai=ab.Image(ah.Icon,ah.Icon,0,af.Window,"Tag",false)

ai.Size=UDim2.new(0,ah.IconSize,0,ah.IconSize)
ai.ImageLabel.ImageColor3=typeof(ah.Color)=="Color3"
and ab.GetTextColorForHSB(ah.Color)
or typeof(ah.Color)=="string"
and(ab.GetTextColorForHSB(ab.GetThemeProperty(ah.Color,ab.Theme)))
end

local aj=ac("TextLabel",{
BackgroundTransparency=1,
AutomaticSize="XY",
TextSize=ah.TextSize,
FontFace=Font.new(ab.Font,Enum.FontWeight.SemiBold),
Text=ah.Title,
TextColor3=typeof(ah.Color)=="Color3"and ab.GetTextColorForHSB(ah.Color)or typeof(
ah.Color
)=="string"and(ab.GetTextColorForHSB(ab.GetThemeProperty(ah.Color,ab.Theme))),
})

local ak

if typeof(ah.Color)=="table"then
ak=ac"UIGradient"
for al,am in next,ah.Color do
ak[al]=am
end

aj.TextColor3=ab.GetTextColorForHSB(ab.GetAverageColor(ak))
if ai then
ai.ImageLabel.ImageColor3=ab.GetTextColorForHSB(ab.GetAverageColor(ak))
end
end

local al=ab.NewRoundFrame(ah.Radius,"Squircle",{
AutomaticSize="X",
Size=UDim2.new(0,0,0,ah.Height),
Parent=ag,
ImageColor3=typeof(ah.Color)=="Color3"and ah.Color
or typeof(ah.Color)=="table"and Color3.new(1,1,1)
or nil,
ThemeTag=typeof(ah.Color)=="string"and{
ImageColor3=ah.Color,
},
},{
ak,
ab.NewRoundFrame(ah.Radius+1,"SquircleGlass",{
Size=UDim2.new(1,1,1,1),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
ThemeTag={
ImageColor3="White",
},
ImageTransparency=0.75,
}),
ac("Frame",{
Size=UDim2.new(0,0,1,0),
AutomaticSize="X",
Name="Content",
BackgroundTransparency=1,
},{
ai,
aj,
ac("UIPadding",{
PaddingLeft=UDim.new(0,ah.Padding),
PaddingRight=UDim.new(0,ah.Padding),
}),
ac("UIListLayout",{
FillDirection="Horizontal",
VerticalAlignment="Center",
Padding=UDim.new(0,ah.Padding/1.5),
}),
}),
})

function ah.SetTitle(am,an)
ah.Title=an
aj.Text=an

return ah
end

function ah.SetColor(am,an)
ah.Color=an
if typeof(an)=="table"then
local ao=ab.GetAverageColor(an)
ad(aj,0.06,{TextColor3=ab.GetTextColorForHSB(ao)}):Play()
local ap=al:FindFirstChildOfClass"UIGradient"or ac("UIGradient",{Parent=al})
for aq,ar in next,an do
ap[aq]=ar
end
ad(al,0.06,{ImageColor3=Color3.new(1,1,1)}):Play()
else
if ak then
ak:Destroy()
end
ad(aj,0.06,{TextColor3=ab.GetTextColorForHSB(an)}):Play()
if ai then
ad(ai.ImageLabel,0.06,{ImageColor3=ab.GetTextColorForHSB(an)}):Play()
end
ad(al,0.06,{ImageColor3=an}):Play()
end

return ah
end

function ah.SetIcon(am,an)
ah.Icon=an

if an then
ai=ab.Image(an,an,0,af.Window,"Tag",false)

ai.Size=UDim2.new(0,ah.IconSize,0,ah.IconSize)
ai.Parent=al

if typeof(ah.Color)=="Color3"then
ai.ImageLabel.ImageColor3=ab.GetTextColorForHSB(ah.Color)
elseif typeof(ah.Color)=="table"then
ai.ImageLabel.ImageColor3=ab.GetTextColorForHSB(ab.GetAverageColor(ak))
end
else
if ai then
ai:Destroy()
ai=nil
end
end
return ah
end

function ah.Destroy(am)
al:Destroy()
return ah
end

ab:OnThemeChange(function(am,an)
aj.TextColor3=ab.GetTextColorForHSB(ab.GetThemeProperty(ah.Color,ab.Theme))
ai.ImageLabel.ImageColor3=
ab.GetTextColorForHSB(ab.GetThemeProperty(ah.Color,ab.Theme))
end)

return ah
end

return aa end function a.z()

local aa=(cloneref or clonereference or function(aa)return aa end)


local ab=aa(game:GetService"RunService")
local ac=aa(game:GetService"HttpService")

local ad

local ae
ae={
Folder=nil,
Path=nil,
Configs={},
Parser={
Colorpicker={
Save=function(af)
return{
__type=af.__type,
value=af.Default:ToHex(),
transparency=af.Transparency or nil,
}
end,
Load=function(af,ag)
if af and af.Update then
af:Update(Color3.fromHex(ag.value),ag.transparency or nil)
end
end
},
Dropdown={
Save=function(af)
return{
__type=af.__type,
value=af.Value,
}
end,
Load=function(af,ag)
if af and af.Select then
af:Select(ag.value)
end
end
},
Input={
Save=function(af)
return{
__type=af.__type,
value=af.Value,
}
end,
Load=function(af,ag)
if af and af.Set then
af:Set(ag.value)
end
end
},
Keybind={
Save=function(af)
return{
__type=af.__type,
value=af.Value,
}
end,
Load=function(af,ag)
if af and af.Set then
af:Set(ag.value)
end
end
},
Slider={
Save=function(af)
return{
__type=af.__type,
value=af.Value.Default,
}
end,
Load=function(af,ag)
if af and af.Set then
af:Set(tonumber(ag.value))
end
end
},
Toggle={
Save=function(af)
return{
__type=af.__type,
value=af.Value,
}
end,
Load=function(af,ag)
if af and af.Set then
af:Set(ag.value)
end
end
},
}
}

function ae.Init(af,ag)
if not ag.Folder then
warn"[ WindUI.ConfigManager ] Window.Folder is not specified."
return false
end
if ab:IsStudio()or not writefile then
warn"[ WindUI.ConfigManager ] The config system doesn't work in the studio."
return false
end

ad=ag
ae.Folder=ad.Folder
ae.Path="WindUI/"..tostring(ae.Folder).."/config/"

if not isfolder(ae.Path)then
makefolder(ae.Path)
end

local ah=ae:AllConfigs()

for ai,aj in next,ah do
if isfile and readfile and isfile(aj..".json")then
ae.Configs[aj]=readfile(aj..".json")
end
end

return ae
end

function ae.SetPath(af,ag)
if not ag then
warn"[ WindUI.ConfigManager ] Custom path is not specified."
return false
end

ae.Path=ag
if not ag:match"/$"then
ae.Path=ag.."/"
end

if not isfolder(ae.Path)then
makefolder(ae.Path)
end

return true
end

function ae.CreateConfig(af,ag,ah)
local ai={
Path=ae.Path..ag..".json",
Elements={},
CustomData={},
AutoLoad=ah or false,
Version=1.2,
}

if not ag then
return false,"No config file is selected"
end

function ai.SetAsCurrent(aj)
ad:SetCurrentConfig(ai)
end

function ai.Register(aj,ak,al)
ai.Elements[ak]=al
end

function ai.Set(aj,ak,al)
ai.CustomData[ak]=al
end

function ai.Get(aj,ak)
return ai.CustomData[ak]
end

function ai.SetAutoLoad(aj,ak)
ai.AutoLoad=ak
end

function ai.Save(aj)
if ad.PendingFlags then
for ak,al in next,ad.PendingFlags do
ai:Register(ak,al)
end
end

local ak={
__version=ai.Version,
__elements={},
__autoload=ai.AutoLoad,
__custom=ai.CustomData
}

for al,am in next,ai.Elements do
if ae.Parser[am.__type]then
ak.__elements[tostring(al)]=ae.Parser[am.__type].Save(am)
end
end

local al=ac:JSONEncode(ak)
if writefile then
writefile(ai.Path,al)
end

return ak
end

function ai.Load(aj)
if isfile and not isfile(ai.Path)then
return false,"Config file does not exist"
end

local ak,al=pcall(function()
local ak=readfile or function()
warn"[ WindUI.ConfigManager ] The config system doesn't work in the studio."
return nil
end
return ac:JSONDecode(ak(ai.Path))
end)

if not ak then
return false,"Failed to parse config file"
end

if not al.__version then
local am={
__version=ai.Version,
__elements=al,
__custom={}
}
al=am
end

if ad.PendingFlags then
for am,an in next,ad.PendingFlags do
ai:Register(am,an)
end
end

for am,an in next,(al.__elements or{})do
if ai.Elements[am]and ae.Parser[an.__type]then
task.spawn(function()
ae.Parser[an.__type].Load(ai.Elements[am],an)
end)
end
end

ai.CustomData=al.__custom or{}

return ai.CustomData
end

function ai.Delete(aj)
if not delfile then
return false,"delfile function is not available"
end

if not isfile(ai.Path)then
return false,"Config file does not exist"
end

local ak,al=pcall(function()
delfile(ai.Path)
end)

if not ak then
return false,"Failed to delete config file: "..tostring(al)
end

ae.Configs[ag]=nil

if ad.CurrentConfig==ai then
ad.CurrentConfig=nil
end

return true,"Config deleted successfully"
end

function ai.GetData(aj)
return{
elements=ai.Elements,
custom=ai.CustomData,
autoload=ai.AutoLoad
}
end


if isfile(ai.Path)then
local aj,ak=pcall(function()
return ac:JSONDecode(readfile(ai.Path))
end)

if aj and ak and ak.__autoload then
ai.AutoLoad=true

task.spawn(function()
task.wait(0.5)
local al,am=pcall(function()
return ai:Load()
end)
if al then
if ad.Debug then print("[ WindUI.ConfigManager ] AutoLoaded config: "..ag)end
else
warn("[ WindUI.ConfigManager ] Failed to AutoLoad config: "..ag.." - "..tostring(am))
end
end)
end
end


ai:SetAsCurrent()
ae.Configs[ag]=ai
return ai
end

function ae.Config(af,ag,ah)
return ae:CreateConfig(ag,ah)
end

function ae.GetAutoLoadConfigs(af)
local ag={}

for ah,ai in pairs(ae.Configs)do
if ai.AutoLoad then
table.insert(ag,ah)
end
end

return ag
end

function ae.DeleteConfig(af,ag)
if not delfile then
return false,"delfile function is not available"
end

local ah=ae.Path..ag..".json"

if not isfile(ah)then
return false,"Config file does not exist"
end

local ai,aj=pcall(function()
delfile(ah)
end)

if not ai then
return false,"Failed to delete config file: "..tostring(aj)
end

ae.Configs[ag]=nil

if ad.CurrentConfig and ad.CurrentConfig.Path==ah then
ad.CurrentConfig=nil
end

return true,"Config deleted successfully"
end

function ae.AllConfigs(af)
if not listfiles then return{}end

local ag={}
if not isfolder(ae.Path)then
makefolder(ae.Path)
return ag
end

for ah,ai in next,listfiles(ae.Path)do
local aj=ai:match"([^\\/]+)%.json$"
if aj then
table.insert(ag,aj)
end
end

return ag
end

function ae.GetConfig(af,ag)
return ae.Configs[ag]
end

return ae end function a.A()
local aa={}

local ab=a.load'd'
local ac=ab.New
local ad=ab.Tween


local ae=(cloneref or clonereference or function(ae)return ae end)


ae(game:GetService"UserInputService")


function aa.New(af)
local ag={
Button=nil
}

local ah













local ai=ac("TextLabel",{
Text=af.Title,
TextSize=17,
FontFace=Font.new(ab.Font,Enum.FontWeight.Medium),
BackgroundTransparency=1,
AutomaticSize="XY",
})

local aj=ac("Frame",{
Size=UDim2.new(0,36,0,36),
BackgroundTransparency=1,
Name="Drag",
},{
ac("ImageLabel",{
Image=ab.Icon"move"[1],
ImageRectOffset=ab.Icon"move"[2].ImageRectPosition,
ImageRectSize=ab.Icon"move"[2].ImageRectSize,
Size=UDim2.new(0,18,0,18),
BackgroundTransparency=1,
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
ThemeTag={
ImageColor3="Icon",
},
ImageTransparency=.3,
})
})
local ak=ac("Frame",{
Size=UDim2.new(0,1,1,0),
Position=UDim2.new(0,36,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
BackgroundColor3=Color3.new(1,1,1),
BackgroundTransparency=.9,
})

local al=ac("Frame",{
Size=UDim2.new(0,0,0,0),
Position=UDim2.new(0.5,0,0,28),
AnchorPoint=Vector2.new(0.5,0.5),
Parent=af.Parent,
BackgroundTransparency=1,
Active=true,
Visible=false,
})


local am=ac("UIScale",{
Scale=1,
})

local an=ac("Frame",{
Size=UDim2.new(0,0,0,44),
AutomaticSize="X",
Parent=al,
Active=false,
BackgroundTransparency=.25,
ZIndex=99,
BackgroundColor3=Color3.new(0,0,0),
},{
am,
ac("UICorner",{
CornerRadius=UDim.new(1,0)
}),
ac("UIStroke",{
Thickness=1,
ApplyStrokeMode="Border",
Color=Color3.new(1,1,1),
Transparency=0,
},{
ac("UIGradient",{
Color=ColorSequence.new(Color3.fromHex"40c9ff",Color3.fromHex"e81cff")
})
}),
aj,
ak,

ac("UIListLayout",{
Padding=UDim.new(0,4),
FillDirection="Horizontal",
VerticalAlignment="Center",
}),

ac("TextButton",{
AutomaticSize="XY",
Active=true,
BackgroundTransparency=1,
Size=UDim2.new(0,0,0,36),

BackgroundColor3=Color3.new(1,1,1),
},{
ac("UICorner",{
CornerRadius=UDim.new(1,-4)
}),
ah,
ac("UIListLayout",{
Padding=UDim.new(0,af.UIPadding),
FillDirection="Horizontal",
VerticalAlignment="Center",
}),
ai,
ac("UIPadding",{
PaddingLeft=UDim.new(0,11),
PaddingRight=UDim.new(0,11),
}),
}),
ac("UIPadding",{
PaddingLeft=UDim.new(0,4),
PaddingRight=UDim.new(0,4),
})
})

ag.Button=an



function ag.SetIcon(ao,ap)
if ah then
ah:Destroy()
end
if ap then
ah=ab.Image(
ap,
af.Title,
0,
af.Folder,
"OpenButton",
true,
af.IconThemed
)
ah.Size=UDim2.new(0,22,0,22)
ah.LayoutOrder=-1
ah.Parent=ag.Button.TextButton
end
end

if af.Icon then
ag:SetIcon(af.Icon)
end



ab.AddSignal(an:GetPropertyChangedSignal"AbsoluteSize",function()
al.Size=UDim2.new(
0,an.AbsoluteSize.X,
0,an.AbsoluteSize.Y
)
end)

ab.AddSignal(an.TextButton.MouseEnter,function()
ad(an.TextButton,.1,{BackgroundTransparency=.93}):Play()
end)
ab.AddSignal(an.TextButton.MouseLeave,function()
ad(an.TextButton,.1,{BackgroundTransparency=1}):Play()
end)

local ao=ab.Drag(al)


function ag.Visible(ap,aq)
al.Visible=aq
end

function ag.SetScale(ap,aq)
am.Scale=aq
end

function ag.Edit(ap,aq)
local ar={
Title=aq.Title,
Icon=aq.Icon,
Enabled=aq.Enabled,
Position=aq.Position,
OnlyIcon=aq.OnlyIcon or false,
Draggable=aq.Draggable or nil,
OnlyMobile=aq.OnlyMobile,
CornerRadius=aq.CornerRadius or UDim.new(1,0),
StrokeThickness=aq.StrokeThickness or 2,
Scale=aq.Scale or 1,
Color=aq.Color
or ColorSequence.new(Color3.fromHex"40c9ff",Color3.fromHex"e81cff"),
}



if ar.Enabled==false then
af.IsOpenButtonEnabled=false
end

if ar.OnlyMobile~=false then
ar.OnlyMobile=true
else
af.IsPC=false
end


if ar.Draggable==false and aj and ak then
aj.Visible=ar.Draggable
ak.Visible=ar.Draggable

if ao then
ao:Set(ar.Draggable)
end
end

if ar.Position and al then
al.Position=ar.Position
end

if ar.OnlyIcon==true and ai then
ai.Visible=false
an.TextButton.UIPadding.PaddingLeft=UDim.new(0,7)
an.TextButton.UIPadding.PaddingRight=UDim.new(0,7)
elseif ar.OnlyIcon==false then
ai.Visible=true
an.TextButton.UIPadding.PaddingLeft=UDim.new(0,11)
an.TextButton.UIPadding.PaddingRight=UDim.new(0,11)
end





if ai then
if ar.Title then
ai.Text=ar.Title
ab:ChangeTranslationKey(ai,ar.Title)
elseif ar.Title==nil then

end
end

if ar.Icon then
ag:SetIcon(ar.Icon)
end

an.UIStroke.UIGradient.Color=ar.Color
if Glow then
Glow.UIGradient.Color=ar.Color
end

an.UICorner.CornerRadius=ar.CornerRadius
an.TextButton.UICorner.CornerRadius=UDim.new(ar.CornerRadius.Scale,ar.CornerRadius.Offset-4)
an.UIStroke.Thickness=ar.StrokeThickness

ag:SetScale(ar.Scale)
end

return ag
end



return aa end function a.B()
local aa={}

local ab=a.load'd'
local ac=ab.New
local ad=ab.Tween


function aa.New(ae,af,ag,ah,ai,aj)
local ak={
Container=nil,
TooltipSize=16,

TooltipArrowSizeX=ai=="Small"and 16 or 24,
TooltipArrowSizeY=ai=="Small"and 6 or 9,

PaddingX=ai=="Small"and 12 or 14,
PaddingY=ai=="Small"and 7 or 9,

Radius=999,

TitleFrame=nil,
}

ah=ah or""
aj=aj~=false

local al=ac("TextLabel",{
AutomaticSize="XY",
TextWrapped=aj,
BackgroundTransparency=1,
FontFace=Font.new(ab.Font,Enum.FontWeight.Medium),
Text=ae,
TextSize=ai=="Small"and 15 or 17,
TextTransparency=1,
ThemeTag={
TextColor3="Tooltip"..ah.."Text",
}
})

ak.TitleFrame=al

local am=ac("UIScale",{
Scale=.9
})

local an=ac("Frame",{
AnchorPoint=Vector2.new(0.5,0),
AutomaticSize="XY",
BackgroundTransparency=1,
Parent=af,

Visible=false
},{
ac("UISizeConstraint",{
MaxSize=Vector2.new(400,math.huge)
}),
ac("Frame",{
AutomaticSize="XY",
BackgroundTransparency=1,
LayoutOrder=99,
Visible=ag,
Name="Arrow",
},{
ac("ImageLabel",{
Size=UDim2.new(0,ak.TooltipArrowSizeX,0,ak.TooltipArrowSizeY),
BackgroundTransparency=1,

Image="rbxassetid://105854070513330",
ThemeTag={
ImageColor3="Tooltip"..ah,
},
},{










}),
}),
ab.NewRoundFrame(ak.Radius,"Squircle",{
AutomaticSize="XY",
ThemeTag={
ImageColor3="Tooltip"..ah,
},
ImageTransparency=1,
Name="Background",
},{



ac("Frame",{



AutomaticSize="XY",
BackgroundTransparency=1,
},{
ac("UICorner",{
CornerRadius=UDim.new(0,16),
}),
ac("UIListLayout",{
Padding=UDim.new(0,12),
FillDirection="Horizontal",
VerticalAlignment="Center"
}),

al,
ac("UIPadding",{
PaddingTop=UDim.new(0,ak.PaddingY),
PaddingLeft=UDim.new(0,ak.PaddingX),
PaddingRight=UDim.new(0,ak.PaddingX),
PaddingBottom=UDim.new(0,ak.PaddingY),
}),
})
}),
am,
ac("UIListLayout",{
Padding=UDim.new(0,0),
FillDirection="Vertical",
VerticalAlignment="Center",
HorizontalAlignment="Center",
}),
})
ak.Container=an

function ak.Open(ao)
an.Visible=true


ad(an.Background,.2,{ImageTransparency=0},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
ad(an.Arrow.ImageLabel,.2,{ImageTransparency=0},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
ad(al,.2,{TextTransparency=0},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
ad(am,.22,{Scale=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end

function ak.Close(ao,ap)

ad(an.Background,.3,{ImageTransparency=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
ad(an.Arrow.ImageLabel,.2,{ImageTransparency=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
ad(al,.3,{TextTransparency=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
ad(am,.35,{Scale=.9},Enum.EasingStyle.Quint,Enum.EasingDirection.In):Play()

ap=ap~=false
if ap then
task.wait(.35)

an.Visible=false
an:Destroy()
end
end

return ak
end



return aa end function a.C()
game:GetService"ReplicatedStorage"
local aa=a.load'd'
local ab=aa.New
local ac=aa.NewRoundFrame
local ad=aa.Tween

local ae=(cloneref or clonereference or function(ae)
return ae
end)

ae(game:GetService"UserInputService")

local af=a.load'y'

local function Color3ToHSB(ag)
local ah,ai,aj=ag.R,ag.G,ag.B
local ak=math.max(ah,ai,aj)
local al=math.min(ah,ai,aj)
local am=ak-al

local an=0
if am~=0 then
if ak==ah then
an=(ai-aj)/am%6
elseif ak==ai then
an=(aj-ah)/am+2
else
an=(ah-ai)/am+4
end
an=an*60
else
an=0
end

local ao=(ak==0)and 0 or(am/ak)
local ap=ak

return{
h=math.floor(an+0.5),
s=ao,
b=ap,
}
end

local function GetPerceivedBrightness(ag)
local ah=ag.R
local ai=ag.G
local aj=ag.B
return 0.299*ah+0.587*ai+0.114*aj
end

local function GetTextColorForHSB(ag)
local ah=Color3ToHSB(ag)local
ai, aj, ak=ah.h, ah.s, ah.b
if GetPerceivedBrightness(ag)>0.5 then
return Color3.fromHSV(ai/360,0,0.05)
else
return Color3.fromHSV(ai/360,0,0.98)
end
end

return function(ag)
local ah={
Title=ag.Title,
Desc=ag.Desc or nil,
Hover=ag.Hover,
Thumbnail=ag.Thumbnail,
ThumbnailSize=ag.ThumbnailSize or 80,
Image=ag.Image,
IconThemed=ag.IconThemed or false,
ImageSize=ag.ImageSize or 30,
Color=ag.Color,
Scalable=ag.Scalable,
Parent=ag.Parent,
Justify=ag.Justify or"Between",
UIPadding=ag.Window.ElementConfig.UIPadding,
UICorner=ag.Window.ElementConfig.UICorner,
Size=ag.Size or"Default",
Tags=ag.Tags or{},
UIElements={},

Index=ag.Index,
}

local ai=ah.Size=="Small"and-4 or ah.Size=="Large"and 4 or 0
local aj=ah.Size=="Small"and-4 or ah.Size=="Large"and 4 or 0

local ak=ah.ImageSize
local al=ah.ThumbnailSize
local am=true


local an=0

local ao
local ap
if ah.Thumbnail then
ao=aa.Image(
ah.Thumbnail,
ah.Title,
ag.Window.NewElements and ah.UICorner-11 or(ah.UICorner-4),
ag.Window.Folder,
"Thumbnail",
false,
ah.IconThemed
)
ao.Size=UDim2.new(1,0,0,al)
end
if ah.Image then
ap=aa.Image(
ah.Image,
ah.Title,
ag.Window.NewElements and ah.UICorner-11 or(ah.UICorner-4),
ag.Window.Folder,
"Image",
ah.IconThemed,
not ah.Color and true or false,
"ElementIcon"
)

if typeof(ah.Color)=="string"and not string.find(ah.Image,"rbxthumb")then
ap.ImageLabel.ImageColor3=GetTextColorForHSB(Color3.fromHex(aa.Colors[ah.Color]))
elseif typeof(ah.Color)=="Color3"and not string.find(ah.Image,"rbxthumb")then
ap.ImageLabel.ImageColor3=GetTextColorForHSB(ah.Color)
end

ap.Size=UDim2.new(0,ak,0,ak)

an=ak
end

local function CreateText(aq,ar)
local as=typeof(ah.Color)=="string"
and GetTextColorForHSB(Color3.fromHex(aa.Colors[ah.Color]))
or typeof(ah.Color)=="Color3"and GetTextColorForHSB(ah.Color)

return ab("TextLabel",{
BackgroundTransparency=1,
Text=aq or"",
TextSize=ar=="Desc"and 15 or 17,
TextXAlignment="Left",
ThemeTag={
TextColor3=not ah.Color and("Element"..ar)or nil,
},
TextColor3=ah.Color and as or nil,
TextTransparency=ar=="Desc"and 0.3 or 0,
TextWrapped=true,
Size=UDim2.new(ah.Justify=="Between"and 1 or 0,0,0,0),
AutomaticSize=ah.Justify=="Between"and"Y"or"XY",
FontFace=Font.new(aa.Font,ar=="Desc"and Enum.FontWeight.Medium or Enum.FontWeight.SemiBold),
})
end

local aq=CreateText(ah.Title,"Title")
local ar=CreateText(ah.Desc,"Desc")
if not ah.Title or ah.Title==""then
ar.Visible=false
end
if not ah.Desc or ah.Desc==""then
ar.Visible=false
end

ah.UIElements.Title=aq
ah.UIElements.Desc=ar

ah.UIElements.Container=ab("Frame",{
Size=UDim2.new(1,0,1,0),
AutomaticSize="Y",
BackgroundTransparency=1,
},{
ab("UIListLayout",{
Padding=UDim.new(0,ah.UIPadding),
FillDirection="Vertical",
VerticalAlignment="Center",
HorizontalAlignment=ah.Justify=="Between"and"Left"or"Center",
}),
ao,
ab("Frame",{
Size=UDim2.new(
ah.Justify=="Between"and 1 or 0,
ah.Justify=="Between"and-ag.TextOffset or 0,
0,
0
),
AutomaticSize=ah.Justify=="Between"and"Y"or"XY",
BackgroundTransparency=1,
Name="TitleFrame",
},{
ab("UIListLayout",{
Padding=UDim.new(0,ah.UIPadding),
FillDirection="Horizontal",
VerticalAlignment=ag.Window.NewElements and(ah.Justify=="Between"and"Top"or"Center")
or"Center",
HorizontalAlignment=ah.Justify~="Between"and ah.Justify or"Center",
}),
ap,
ab("Frame",{
BackgroundTransparency=1,
AutomaticSize=ah.Justify=="Between"and"Y"or"XY",
Size=UDim2.new(
ah.Justify=="Between"and 1 or 0,
ah.Justify=="Between"and(ap and-an-ah.UIPadding or-an)
or 0,
1,
0
),
Name="TitleFrame",
},{
ab("UIPadding",{
PaddingTop=UDim.new(0,(ag.Window.NewElements and ah.UIPadding/2 or 0)+aj),
PaddingLeft=UDim.new(0,(ag.Window.NewElements and ah.UIPadding/2 or 0)+ai),
PaddingRight=UDim.new(
0,
(ag.Window.NewElements and ah.UIPadding/2 or 0)+ai
),
PaddingBottom=UDim.new(
0,
(ag.Window.NewElements and ah.UIPadding/2 or 0)+aj
),
}),
ab("UIListLayout",{
Padding=UDim.new(0,6),
FillDirection="Vertical",
VerticalAlignment="Center",
HorizontalAlignment="Left",
}),
ab("ScrollingFrame",{
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
LayoutOrder=-99,
BackgroundTransparency=1,
ScrollingDirection="X",
CanvasSize=UDim2.new(0,0,0,0),
ScrollBarThickness=0,
Visible=false,
},{
ab("UIListLayout",{
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment="Left",
Padding=UDim.new(0,ag.Window.UIPadding/2),
}),
}),
ab("Frame",{
Name="Space",
Size=UDim2.new(1,0,0,0),
BackgroundTransparency=1,
Visible=false,
}),
aq,
ar,
}),
}),
})

for as,at in next,ag.Tags or{}do
if not ah.UIElements.Container.TitleFrame.TitleFrame.ScrollingFrame.Visible then
ah.UIElements.Container.TitleFrame.TitleFrame.ScrollingFrame.Visible=true
ah.UIElements.Container.TitleFrame.TitleFrame.Space.Visible=true
end
af:New(at,ah.UIElements.Container.TitleFrame.TitleFrame.ScrollingFrame)
end

aa.AddSignal(
ah.UIElements.Container.TitleFrame.TitleFrame.ScrollingFrame.UIListLayout:GetPropertyChangedSignal
"AbsoluteContentSize"
,
function()
ah.UIElements.Container.TitleFrame.TitleFrame.ScrollingFrame.Size=UDim2.new(
1,
0,
0,
ah.UIElements.Container.TitleFrame.TitleFrame.ScrollingFrame.UIListLayout.AbsoluteContentSize.Y
/ag.ParentConfig.UIScale
)
end
)





local as=aa.Image("lock","lock",0,ag.Window.Folder,"Lock",false)
as.Size=UDim2.new(0,20,0,20)
as.ImageLabel.ImageColor3=Color3.new(1,1,1)
as.ImageLabel.ImageTransparency=0.4

local at=ab("TextLabel",{
Text="Locked",
TextSize=18,
FontFace=Font.new(aa.Font,Enum.FontWeight.Medium),
AutomaticSize="XY",
BackgroundTransparency=1,
TextColor3=Color3.new(1,1,1),
TextTransparency=0.05,
})

local au=ab("Frame",{
Size=UDim2.new(1,ah.UIPadding*2,1,ah.UIPadding*2),
BackgroundTransparency=1,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
ZIndex=9999999,
})

local av,aw=ac(ah.UICorner,"Squircle",{
Size=UDim2.new(1,0,1,0),
ImageTransparency=0.25,
ImageColor3=Color3.new(0,0,0),
Visible=false,
Active=false,
Parent=au,
},{
ab("UIListLayout",{
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment="Center",
Padding=UDim.new(0,8),
}),
as,
at,
},nil,true)local

ax=ac(ah.UICorner,"Squircle-Outline",{
Size=UDim2.new(1,0,1,0),
ImageTransparency=1,
Active=false,
ThemeTag={
ImageColor3="Text",
},
Parent=au,
},{
ab("UIListLayout",{
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment="Center",
Padding=UDim.new(0,8),
}),
},nil,true)

local ay,az=ac(ah.UICorner,"Squircle",{
Size=UDim2.new(1,0,1,0),
ImageTransparency=1,
Active=false,
ThemeTag={
ImageColor3="Text",
},
Parent=au,
},{
ab("UIListLayout",{
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment="Center",
Padding=UDim.new(0,8),
}),
},nil,true)local

aA=ac(ah.UICorner,"Squircle-Outline",{
Size=UDim2.new(1,0,1,0),
ImageTransparency=1,
Visible=false,
Active=false,
ThemeTag={
ImageColor3="Text",
},
Parent=au,
},{
ab("UIListLayout",{
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment="Center",
Padding=UDim.new(0,8),
}),
ab("UIGradient",{
Name="HoverGradient",
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),
ColorSequenceKeypoint.new(0.5,Color3.new(1,1,1)),
ColorSequenceKeypoint.new(1,Color3.new(1,1,1)),
},
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0,1),
NumberSequenceKeypoint.new(0.25,0.9),
NumberSequenceKeypoint.new(0.5,0.3),
NumberSequenceKeypoint.new(0.75,0.9),
NumberSequenceKeypoint.new(1,1),
},
}),
},nil,true)

local aB,b=ac(ah.UICorner,"Squircle",{
Size=UDim2.new(1,0,1,0),
ImageTransparency=1,
Active=false,
ThemeTag={
ImageColor3="Text",
},
Parent=au,
},{
ab("UIGradient",{
Name="HoverGradient",
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),
ColorSequenceKeypoint.new(0.5,Color3.new(1,1,1)),
ColorSequenceKeypoint.new(1,Color3.new(1,1,1)),
},
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0,1),
NumberSequenceKeypoint.new(0.25,0.9),
NumberSequenceKeypoint.new(0.5,0.3),
NumberSequenceKeypoint.new(0.75,0.9),
NumberSequenceKeypoint.new(1,1),
},
}),
ab("UIListLayout",{
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment="Center",
Padding=UDim.new(0,8),
}),
},nil,true)

local d,f=ac(ah.UICorner,"Squircle",{
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
ImageTransparency=ah.Color and 0.05 or(not ag.Window.NewElements and 0.93 or nil),



Parent=ag.Parent,
ThemeTag={
ImageColor3=not ah.Color and(ag.Window.NewElements and"ElementBackground"or"Text")or nil,
ImageTransparency=not ah.Color
and(ag.Window.NewElements and"ElementBackgroundTransparency"or nil)
or nil,
},
ImageColor3=ah.Color and(typeof(ah.Color)=="string"and Color3.fromHex(
aa.Colors[ah.Color]
)or typeof(ah.Color)=="Color3"and ah.Color)or nil,
},{
ah.UIElements.Container,
au,
ab("UIPadding",{
PaddingTop=UDim.new(0,ah.UIPadding),
PaddingLeft=UDim.new(0,ah.UIPadding),
PaddingRight=UDim.new(0,ah.UIPadding),
PaddingBottom=UDim.new(0,ah.UIPadding),
}),
},true,true)

ah.UIElements.Main=d
ah.UIElements.Locked=av

if ah.Hover then
aa.AddSignal(d.MouseEnter,function()
if am then

ad(aB,0.12,{ImageTransparency=0.9}):Play()
ad(aA,0.12,{ImageTransparency=0.8}):Play()
aa.AddSignal(d.MouseMoved,function(g,h)
aB.HoverGradient.Offset=
Vector2.new(((g-d.AbsolutePosition.X)/d.AbsoluteSize.X)-0.5,0)
aA.HoverGradient.Offset=
Vector2.new(((g-d.AbsolutePosition.X)/d.AbsoluteSize.X)-0.5,0)
end)
end
end)
aa.AddSignal(d.InputEnded,function()
if am then

ad(aB,0.12,{ImageTransparency=1}):Play()
ad(aA,0.12,{ImageTransparency=1}):Play()
end
end)
end

function ah.SetTitle(g,h)
ah.Title=h
aq.Text=h
end

function ah.SetDesc(g,h)
ah.Desc=h
ar.Text=h or""
if not h then
ar.Visible=false
elseif not ar.Visible then
ar.Visible=true
end
end

function ah.Colorize(g,h,i)
if ah.Color then
h[i]=typeof(ah.Color)=="string"
and GetTextColorForHSB(Color3.fromHex(aa.Colors[ah.Color]))
or typeof(ah.Color)=="Color3"and GetTextColorForHSB(ah.Color)
or nil
end
end

if ag.ElementTable then
aa.AddSignal(aq:GetPropertyChangedSignal"Text",function()
if ah.Title~=aq.Text then
ah:SetTitle(aq.Text)
ag.ElementTable.Title=aq.Text
end
end)
aa.AddSignal(ar:GetPropertyChangedSignal"Text",function()
if ah.Desc~=ar.Text then
ah:SetDesc(ar.Text)
ag.ElementTable.Desc=ar.Text
end
end)
end





function ah.SetThumbnail(g,h,i)
ah.Thumbnail=h
if i then
ah.ThumbnailSize=i
al=i
end

if ao then
if h then
ao:Destroy()
ao=aa.Image(
h,
ah.Title,
ah.UICorner-3,
ag.Window.Folder,
"Thumbnail",
false,
ah.IconThemed
)
if ao then
ao.Size=UDim2.new(1,0,0,al)
ao.Parent=ah.UIElements.Container
local l=ah.UIElements.Container:FindFirstChild"UIListLayout"
if l then
ao.LayoutOrder=-1
end
end
else
ao.Visible=false
end
else
if h then
ao=aa.Image(
h,
ah.Title,
ah.UICorner-3,
ag.Window.Folder,
"Thumbnail",
false,
ah.IconThemed
)
if ao then
ao.Size=UDim2.new(1,0,0,al)
ao.Parent=ah.UIElements.Container
local l=ah.UIElements.Container:FindFirstChild"UIListLayout"
if l then
ao.LayoutOrder=-1
end
end
end
end
end

function ah.SetImage(g,h,i)
ah.Image=h
if i then
ah.ImageSize=i
ak=i
end

if h then
local l=ap and ap.Parent or ah.UIElements.Container.TitleFrame
if ap then
ap:Destroy()
end

ap=aa.Image(
h,
h,
ah.UICorner-3,
ag.Window.Folder,
"Image",
not ah.Color and true or false
)
if ap then
if typeof(ah.Color)=="string"and not string.find(ah.Image,"rbxthumb")then
ap.ImageLabel.ImageColor3=
GetTextColorForHSB(Color3.fromHex(aa.Colors[ah.Color]))
elseif typeof(ah.Color)=="Color3"and not string.find(ah.Image,"rbxthumb")then
ap.ImageLabel.ImageColor3=GetTextColorForHSB(ah.Color)
end

ap.Visible=true
ap.Parent=l
ap.LayoutOrder=-99

ap.Size=UDim2.new(0,ak,0,ak)
an=ah.ImageSize+ah.UIPadding
end
else
if ap then
ap.Visible=true
end
an=0
end

ah.UIElements.Container.TitleFrame.TitleFrame.Size=UDim2.new(1,-an,1,0)
end

function ah.Destroy(g)
d:Destroy()
end

function ah.Lock(g,h)
am=false
av.Active=true
av.Visible=true
at.Text=h or"Locked"
end

function ah.Unlock(g)
am=true
av.Active=false
av.Visible=false
end

function ah.Highlight(g)
local h=ab("UIGradient",{
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),
ColorSequenceKeypoint.new(0.5,Color3.new(1,1,1)),
ColorSequenceKeypoint.new(1,Color3.new(1,1,1)),
},
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0,1),
NumberSequenceKeypoint.new(0.1,0.9),
NumberSequenceKeypoint.new(0.5,0.3),
NumberSequenceKeypoint.new(0.9,0.9),
NumberSequenceKeypoint.new(1,1),
},
Rotation=0,
Offset=Vector2.new(-1,0),
Parent=ax,
})

local i=ab("UIGradient",{
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),
ColorSequenceKeypoint.new(0.5,Color3.new(1,1,1)),
ColorSequenceKeypoint.new(1,Color3.new(1,1,1)),
},
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0,1),
NumberSequenceKeypoint.new(0.15,0.8),
NumberSequenceKeypoint.new(0.5,0.1),
NumberSequenceKeypoint.new(0.85,0.8),
NumberSequenceKeypoint.new(1,1),
},
Rotation=0,
Offset=Vector2.new(-1,0),
Parent=ay,
})

ax.ImageTransparency=0.65
ay.ImageTransparency=0.88

ad(h,0.75,{
Offset=Vector2.new(1,0),
}):Play()

ad(i,0.75,{
Offset=Vector2.new(1,0),
}):Play()

task.spawn(function()
task.wait(0.75)
ax.ImageTransparency=1
ay.ImageTransparency=1
h:Destroy()
i:Destroy()
end)
end

function ah.UpdateShape(g)
if ag.Window.NewElements then
local h=aa:GetElementPosition(
g.Elements,
ah.Index,
ag.ParentConfig.ParentTable.__type=="HStack"or ag.ParentConfig.ParentTable.__type=="Group"
)

if h and d then
f:SetType(h)
aw:SetType(h)
az:SetType(h)

b:SetType(h)

end
end
end





return ah
end end function a.D()

local aa=a.load'd'
local ab=aa.New

local ac={}

local ad=a.load'm'.New

function ac.New(ae,af)
af.Hover=false
af.TextOffset=0
af.ParentConfig=af
af.IsButtons=af.Buttons and#af.Buttons>0 and true or false

local ag={
__type="Paragraph",
Title=af.Title or"Paragraph",
Desc=af.Desc or nil,

Locked=af.Locked or false,
}
local ah=a.load'C'(af)

ag.ParagraphFrame=ah
if af.Buttons and#af.Buttons>0 then
local ai=ab("Frame",{
Size=UDim2.new(1,0,0,38),
BackgroundTransparency=1,
AutomaticSize="Y",
Parent=ah.UIElements.Container,
},{
ab("UIListLayout",{
Padding=UDim.new(0,10),
FillDirection="Vertical",
}),
})

for aj,ak in next,af.Buttons do
local al=ad(
ak.Title,
ak.Icon,
ak.Callback,
ak.Variant or"White",
ai,
nil,
nil,
af.Window.NewElements and 999 or 10
)
al.Size=UDim2.new(1,0,0,38)

end
end

return ag.__type,ag
end

return ac end function a.E()

local aa=a.load'd'local ab=
aa.New

local ac={}

function ac.New(ad,ae)
local af={
__type="Button",
Title=ae.Title or"Button",
Desc=ae.Desc or nil,
Icon=ae.Icon or"mouse-pointer-click",
IconThemed=ae.IconThemed or false,
IconColor=ae.IconColor or nil,
Color=ae.Color,
Justify=ae.Justify or"Between",
IconAlign=ae.IconAlign or"Right",
Locked=ae.Locked or false,
LockedTitle=ae.LockedTitle,
Callback=ae.Callback or function()end,
UIElements={},
}

local ag=true

af.ButtonFrame=a.load'C'{
Title=af.Title,
Desc=af.Desc,
Parent=ae.Parent,




Window=ae.Window,
Color=af.Color,
Justify=af.Justify,
TextOffset=20,
Hover=true,
Scalable=true,
Tab=ae.Tab,
Index=ae.Index,
ElementTable=af,
ParentConfig=ae,
Size=ae.Size,
Tags=ae.Tags,
}














af.UIElements.ButtonIcon=aa.Image(
af.Icon,
af.Icon,
0,
ae.Window.Folder,
"Button",
not(af.Color or af.IconColor)and true or nil,
af.IconThemed
)

if af.IconColor then
af.UIElements.ButtonIcon.ImageLabel.ImageColor3=af.IconColor
end

af.UIElements.ButtonIcon.Size=UDim2.new(0,20,0,20)
af.UIElements.ButtonIcon.Parent=af.Justify=="Between"and af.ButtonFrame.UIElements.Main
or af.ButtonFrame.UIElements.Container.TitleFrame
af.UIElements.ButtonIcon.LayoutOrder=af.IconAlign=="Left"and-99999 or 99999
af.UIElements.ButtonIcon.AnchorPoint=Vector2.new(1,0.5)
af.UIElements.ButtonIcon.Position=UDim2.new(1,0,0.5,0)

af.ButtonFrame:Colorize(af.UIElements.ButtonIcon.ImageLabel,"ImageColor3")

function af.Lock(ah)
af.Locked=true
ag=false
return af.ButtonFrame:Lock(af.LockedTitle)
end
function af.Unlock(ah)
af.Locked=false
ag=true
return af.ButtonFrame:Unlock()
end

if af.Locked then
af:Lock()
end

aa.AddSignal(af.ButtonFrame.UIElements.Main.MouseButton1Click,function()
if ag then
task.spawn(function()
aa.SafeCallback(af.Callback)
end)
end
end)
return af.__type,af
end

return ac end function a.F()

local aa={}

local ab=a.load'd'
local ac=ab.New
local ad=ab.Tween

local ae=game:GetService"UserInputService"

function aa.New(af,ag,ah,ai,aj,ak,al)
local am={
GlassSpritesheet={
Id="rbxassetid://77297718671545",
MirroredId="rbxassetid://92258969882244",
Size=Vector2.new(102,128),
Total=80,
Cols=10,
},
}

function am.GetGlassFrame(an,ao:number):(string,Vector2,Vector2)
local ap=am.GlassSpritesheet
local aq:number

if ao<=0.4 then
aq=math.floor((ao/0.4)*(ap.Total-1))
elseif ao<0.6 then
aq=ap.Total-1
else
aq=math.floor(((ao-0.6)/0.4)*(ap.Total-1))
end

aq=math.clamp(aq,0,ap.Total-1)

local ar=ao>=0.6
if ar then
aq=(ap.Total-1)-aq
end

local as=ar and ap.MirroredId or ap.Id

return as,ap.Size,Vector2.new((aq%ap.Cols)*ap.Size.X,math.floor(aq/ap.Cols)*ap.Size.Y)
end

local an=12
local ao
if ag and ag~=""then
ao=ac("ImageLabel",{
Size=UDim2.new(0,13,0,13),
BackgroundTransparency=1,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Image=ab.Icon(ag)[1],
ImageRectOffset=ab.Icon(ag)[2].ImageRectPosition,
ImageRectSize=ab.Icon(ag)[2].ImageRectSize,
ImageTransparency=1,
ImageColor3=Color3.new(0,0,0),
})
end

local ap=ac("Frame",{
Size=UDim2.new(0,2,0,26),
BackgroundTransparency=1,
Parent=ai,
})

local aq=ab.NewRoundFrame(an,"Squircle",{
ImageTransparency=0.85,
ThemeTag={
ImageColor3="Text",
},
Parent=ap,
Size=UDim2.new(0,ak and(52)or(40.8),0,24),
AnchorPoint=Vector2.new(1,0.5),
Position=UDim2.new(0,0,0.5,0),
Name="ToggleFrame",
},{
ab.NewRoundFrame(an,"Squircle",{
Size=UDim2.new(1,0,1,0),
Name="Layer",
ThemeTag={
ImageColor3="Toggle",
},
ImageTransparency=1,
}),
ab.NewRoundFrame(an,"SquircleOutline",{
Size=UDim2.new(1,0,1,0),
Name="Stroke",
ImageColor3=Color3.new(1,1,1),
ImageTransparency=1,
},{
ac("UIGradient",{
Rotation=90,
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0,0),
NumberSequenceKeypoint.new(1,1),
},
}),
}),


ab.NewRoundFrame(an,"Squircle",{
Size=UDim2.new(0,ak and 30 or 20,0,20),
Position=UDim2.new(0,2,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
ImageTransparency=1,
Name="Frame",
},{
ab.NewRoundFrame(an,"Squircle",{
Size=UDim2.new(1,0,1,0),
ImageTransparency=0,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Name="Bar",
},{
ab.New("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundColor3=Color3.new(1,1,1),
Name="Highlight",
BackgroundTransparency=1,
},{
ab.NewRoundFrame(9999,"SquircleGlass",{
Size=UDim2.new(1,1,1,1),
ImageColor3=Color3.new(1,1,1),
Name="SquircleGlass",
ImageTransparency=0.5,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
}),
ab.NewRoundFrame(an,"Squircle",{
Size=UDim2.new(1,0,1,0),
Name="GlassBackground",
ImageTransparency=0,
ThemeTag={
ImageColor3="ElementBackground",
},
ZIndex=-1,
}),
ac("ImageLabel",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
Name="Glass",
ImageTransparency=0,
},{
ac("UICorner",{
CornerRadius=UDim.new(1,0),
}),
}),






ab.NewRoundFrame(an,"Squircle",{
Size=UDim2.new(1,0,1,0),
Name="BarOverlay",
ThemeTag={
ImageColor3="ToggleBar",
},
ZIndex=999,
}),
}),
ao,
ac("UIScale",{
Scale=1,
}),
}),
}),
ac("TextButton",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
Name="Hitbox",
Text="",
}),
})

local ar
local as

local at=ak and 30 or 20
local au=aq.Size.X.Offset

function am.Set(av,aw,ax,ay)
if not ay then
if aw then
ad(aq.Frame,0.35,{
Position=UDim2.new(0,au-at-2,0.5,0),
},Enum.EasingStyle.Back,Enum.EasingDirection.Out):Play()
ab.SetThemeTag(aq.Frame.Bar.Highlight.Glass,{ImageColor3="Toggle"},0.15)

ad(
aq.Frame.Bar.Highlight.Glass,
0.15,
{ImageTransparency=0},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
else
ad(aq.Frame,0.35,{
Position=UDim2.new(0,2,0.5,0),
},Enum.EasingStyle.Back,Enum.EasingDirection.Out):Play()
ab.SetThemeTag(aq.Frame.Bar.Highlight.Glass,{ImageColor3="Text"},0.15)
ad(
aq.Frame.Bar.Highlight.Glass,
0.15,
{ImageTransparency=0.85},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
end
else
if aw then
aq.Frame.Position=UDim2.new(0,au-at-2,0.5,0)
else
aq.Frame.Position=UDim2.new(0,2,0.5,0)
end
end

if aw then
ad(aq.Layer,0.1,{
ImageTransparency=0,
}):Play()
ab.SetThemeTag(aq.Frame.Bar.Highlight.Glass,{ImageColor3="Toggle"},0.1)
ad(
aq.Frame.Bar.Highlight.Glass,
0.1,
{ImageTransparency=0},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()

if ao then
ad(ao,0.1,{
ImageTransparency=0,
}):Play()
end

local az,aA,aB=am:GetGlassFrame(1)

aq.Frame.Bar.Highlight.Glass.Image=az
aq.Frame.Bar.Highlight.Glass.ImageRectSize=aA
aq.Frame.Bar.Highlight.Glass.ImageRectOffset=aB
else
ad(aq.Layer,0.1,{
ImageTransparency=1,
}):Play()
ab.SetThemeTag(aq.Frame.Bar.Highlight.Glass,{ImageColor3="Text"},0.1)
ad(
aq.Frame.Bar.Highlight.Glass,
0.1,
{ImageTransparency=0.85},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()

if ao then
ad(ao,0.1,{
ImageTransparency=1,
}):Play()
end

local az,aA,aB=am:GetGlassFrame(0)

aq.Frame.Bar.Highlight.Glass.Image=az
aq.Frame.Bar.Highlight.Glass.ImageRectSize=aA
aq.Frame.Bar.Highlight.Glass.ImageRectOffset=aB
end

ax=ax~=false

task.spawn(function()
if aj and ax then
ab.SafeCallback(aj,aw)
end
end)
end

function am.Animate(av,aw,ax)
if not al.Window.IsToggleDragging then
al.Window.IsToggleDragging=true

local ay=aw.Position.X
local az=aw.Position.Y
local aA=aq.Frame.Position.X.Offset
local aB=false
local b=false

ad(
aq.Frame.Bar.UIScale,
0.28,
{Scale=1.5},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
ad(
aq.Frame.Bar.Highlight.BarOverlay,
0.28,
{ImageTransparency=0.86},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()

if ar then
ar:Disconnect()
end

ar=ae.InputChanged:Connect(function(d)
if not al.Window.IsToggleDragging then
return
end
if
d.UserInputType~=Enum.UserInputType.MouseMovement
and d.UserInputType~=Enum.UserInputType.Touch
then
return
end
if aB then
return
end

local f=math.abs(d.Position.X-ay)
math.abs(d.Position.Y-az)

if not b and f>8 then
b=true
end

local g=d.Position.X-ay
local h=math.max(2,math.min(aA+g,au-at-2))

local i=math.clamp((h-2)/(au-at-4),0,1)

local l,m,p=am:GetGlassFrame(i)
aq.Frame.Bar.Highlight.Glass.Image=l
aq.Frame.Bar.Highlight.Glass.ImageRectSize=m
aq.Frame.Bar.Highlight.Glass.ImageRectOffset=p

ad(aq.Frame,0.12,{
Position=UDim2.new(0,h,0.5,0),
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end)

if as then
as:Disconnect()
end

as=ae.InputEnded:Connect(function(d)
if not al.Window.IsToggleDragging then
return
end
if
d.UserInputType~=Enum.UserInputType.MouseButton1
and d.UserInputType~=Enum.UserInputType.Touch
then
return
end

al.Window.IsToggleDragging=false

if ar then
ar:Disconnect()
ar=nil
end
if as then
as:Disconnect()
as=nil
end

al.WindUI.CurrentInput=nil

if aB then
return
end

if not b then
ax:Set(not ax.Value,true,false)
else
local f=aq.Frame.Position.X.Offset
local g=f+at/2
local h=g>au/2
ax:Set(h,true,false)
end

ad(
aq.Frame.Bar.UIScale,
0.23,
{Scale=1},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
ad(
aq.Frame.Bar.Highlight.BarOverlay,
0.23,
{ImageTransparency=0},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
end)
end
end

return ap,am
end

return aa end function a.G()

local aa={}

local ab=a.load'd'local ac=
ab.New
local ad=ab.Tween


function aa.New(ae,af,ag,ah,ai,aj)
local ak={}

af=af or"sfsymbols:checkmark"

local al=9

local am=ab.Image(
af,
af,
0,
(aj and aj.Window.Folder or"Temp"),
"Checkbox",
true,
false,
"CheckboxIcon"
)
am.Size=UDim2.new(1,-26+ag,1,-26+ag)
am.AnchorPoint=Vector2.new(0.5,0.5)
am.Position=UDim2.new(0.5,0,0.5,0)


local an=ab.NewRoundFrame(al,"Squircle",{
ImageTransparency=.85,
ThemeTag={
ImageColor3="Text"
},
Parent=ah,
Size=UDim2.new(0,26,0,26),
},{
ab.NewRoundFrame(al,"Squircle",{
Size=UDim2.new(1,0,1,0),
Name="Layer",
ThemeTag={
ImageColor3="Checkbox",
},
ImageTransparency=1,
}),
ab.NewRoundFrame(al,"Glass-1.4",{
Size=UDim2.new(1,0,1,0),
Name="Stroke",
ThemeTag={
ImageColor3="CheckboxBorder",
ImageTransparency="CheckboxBorderTransparency",
},
},{







}),

am,
},true)

function ak.Set(ao,ap)
if ap then
ad(an.Layer,0.06,{
ImageTransparency=0,
}):Play()



ad(am.ImageLabel,0.06,{
ImageTransparency=0,
}):Play()
else
ad(an.Layer,0.05,{
ImageTransparency=1,
}):Play()



ad(am.ImageLabel,0.06,{
ImageTransparency=1,
}):Play()
end

task.spawn(function()
if ai then
ab.SafeCallback(ai,ap)
end
end)
end

return an,ak
end


return aa end function a.H()
local aa=a.load'd'local ab=
aa.New local ac=
aa.Tween

local ad=a.load'F'.New
local ae=a.load'G'.New

local af={}

function af.New(ag,ah)
local ai={
__type="Toggle",
Title=ah.Title or"Toggle",
Desc=ah.Desc or nil,
Locked=ah.Locked or false,
LockedTitle=ah.LockedTitle,
Value=ah.Value,
Icon=ah.Icon or nil,
IconSize=ah.IconSize or 23,
Type=ah.Type or"Toggle",
Callback=ah.Callback or function()end,
UIElements={},
}
ai.ToggleFrame=a.load'C'{
Title=ai.Title,
Desc=ai.Desc,




Window=ah.Window,
Parent=ah.Parent,
TextOffset=(52),
Hover=false,
Tab=ah.Tab,
Index=ah.Index,
ElementTable=ai,
ParentConfig=ah,
Tags=ah.Tags,
}

local aj=true

if ai.Value==nil then
ai.Value=false
end

function ai.Lock(ak)
ai.Locked=true
aj=false
return ai.ToggleFrame:Lock(ai.LockedTitle)
end
function ai.Unlock(ak)
ai.Locked=false
aj=true
return ai.ToggleFrame:Unlock()
end

if ai.Locked then
ai:Lock()
end

local ak=ai.Value

local al,am
if ai.Type=="Toggle"then
al,am=ad(
ak,
ai.Icon,
ai.IconSize,
ai.ToggleFrame.UIElements.Main,
ai.Callback,
ah.Window.NewElements,
ah
)
elseif ai.Type=="Checkbox"then
al,am=ae(
ak,
ai.Icon,
ai.IconSize,
ai.ToggleFrame.UIElements.Main,
ai.Callback,
ah
)
else
error("Unknown Toggle Type: "..tostring(ai.Type))
end

al.AnchorPoint=Vector2.new(1,ah.Window.NewElements and 0 or 0.5)
al.Position=UDim2.new(1,0,ah.Window.NewElements and 0 or 0.5,0)

function ai.Set(an,ao,ap,aq)
if aj then
am:Set(ao,ap,aq or false)
ak=ao
ai.Value=ao
end
end

ai:Set(ak,false,ah.Window.NewElements)

local an=ah.WindUI.GenerateGUID()

if ah.Window.NewElements and am.Animate then
if ai.Type=="Toggle"then
aa.AddSignal(al.ToggleFrame.Hitbox.InputBegan,function(ao)
if
not ah.Window.IsToggleDragging
and(
ao.UserInputType==Enum.UserInputType.MouseButton1
or ao.UserInputType==Enum.UserInputType.Touch
)
then
if ah.WindUI.CurrentInput and ah.WindUI.CurrentInput~=an then
return
end

ah.WindUI.CurrentInput=an
am:Animate(ao,ai)
end
end)
end





else
if ai.Type=="Toggle"then
aa.AddSignal(al.ToggleFrame.Hitbox.MouseButton1Click,function()
ai:Set(not ai.Value,nil,ah.Window.NewElements)
end)
elseif ai.Type=="Checkbox"then
aa.AddSignal(al.MouseButton1Click,function()
ai:Set(not ai.Value,nil,ah.Window.NewElements)
end)
end
end

return ai.__type,ai
end

return af end function a.I()

local aa=(cloneref or clonereference or function(aa)
return aa
end)

local ac=aa(game:GetService"UserInputService")
local ad=aa(game:GetService"RunService")

local ae=a.load'd'
local af=ae.New
local ag=ae.Tween

local ah={}

local ai=false

function ah.New(aj,ak)
local al={
__type="Slider",
Title=ak.Title or nil,
Desc=ak.Desc or nil,
Locked=ak.Locked or nil,
LockedTitle=ak.LockedTitle,
Value=ak.Value or{},
Icons=ak.Icons or nil,
IsTooltip=ak.IsTooltip or false,
IsTextbox=ak.IsTextbox,
Step=ak.Step or 1,
Callback=ak.Callback or function()end,
UIElements={},
IsFocusing=false,

Width=ak.Width or 130,
TextBoxWidth=ak.Window.NewElements and 40 or 30,
ThumbSize=13,
IconSize=26,
}
if al.Icons=={}then
al.Icons={
From="sfsymbols:sunMinFill",
To="sfsymbols:sunMaxFill",
}
end
if al.IsTextbox==nil and al.Title==nil then
al.IsTextbox=false
else
al.IsTextbox=al.IsTextbox~=false
end

local am
local an
local ao
local ap=al.Value.Default or al.Value.Min or 0

local aq=ap
local ar=(ap-(al.Value.Min or 0))/((al.Value.Max or 100)-(al.Value.Min or 0))

local as=true
local at=al.Step%1~=0

local function FormatValue(au)
if at then
return tonumber(string.format("%.2f",au))
end
return math.floor(au+0.5)
end

local function CalculateValue(au)
if at then
return math.floor(au/al.Step+0.5)*al.Step
else
return math.floor(au/al.Step+0.5)*al.Step
end
end

local au,av
local aw=32
if al.Icons then
if al.Icons.From then
au=ae.Image(
al.Icons.From,
al.Icons.From,
0,
ak.Window.Folder,
"SliderIconFrom",
true,
true,
"SliderIconFrom"
)
au.Size=UDim2.new(0,al.IconSize,0,al.IconSize)
aw=aw+al.IconSize-2
end
if al.Icons.To then
av=ae.Image(
al.Icons.To,
al.Icons.To,
0,
ak.Window.Folder,
"SliderIconTo",
true,
true,
"SliderIconTo"
)
av.Size=UDim2.new(0,al.IconSize,0,al.IconSize)
aw=aw+al.IconSize-2
end
end
al.SliderFrame=a.load'C'{
Title=al.Title,
Desc=al.Desc,
Parent=ak.Parent,
TextOffset=al.Width,
Hover=false,
Tab=ak.Tab,
Index=ak.Index,
Window=ak.Window,
ElementTable=al,
ParentConfig=ak,
Tags=ak.Tags,
}

al.UIElements.SliderIcon=ae.NewRoundFrame(99,"Squircle",{
ImageTransparency=0.95,
Size=UDim2.new(1,not al.IsTextbox and-aw or(-al.TextBoxWidth-8),0,4),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Name="Frame",
ThemeTag={
ImageColor3="Text",
},
},{
ae.NewRoundFrame(99,"Squircle",{
Name="Frame",
Size=UDim2.new(ar,0,1,0),
ImageTransparency=0.1,
ThemeTag={
ImageColor3="Slider",
},
},{
ae.NewRoundFrame(99,"Squircle",{
Size=UDim2.new(
0,
ak.Window.NewElements and(al.ThumbSize*2)or(al.ThumbSize+2),
0,
ak.Window.NewElements and(al.ThumbSize+4)or(al.ThumbSize+2)
),
Position=UDim2.new(1,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
ThemeTag={
ImageColor3="SliderThumb",
},
Name="Thumb",
},{
ae.NewRoundFrame(999,"SquircleGlass",{
Size=UDim2.new(1,0,1,0),
ImageColor3=Color3.new(1,1,1),
Name="Highlight",
ImageTransparency=0.5,
}),
}),
}),
})

al.UIElements.SliderContainer=af("Frame",{
Size=UDim2.new(al.Title==nil and 1 or 0,al.Title==nil and 0 or al.Width,0,0),
AutomaticSize="Y",
Position=UDim2.new(1,al.IsTextbox and(ak.Window.NewElements and-16 or 0)or 0,0.5,0),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
Parent=al.SliderFrame.UIElements.Main,
},{
af("UIListLayout",{
Padding=UDim.new(0,al.Title~=nil and 8 or 12),
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment=al.Icons
and(al.Icons.From and(al.Icons.To and"Center"or"Left")or al.Icons.To and"Right")
or"Center",
}),
au,
al.UIElements.SliderIcon,
av,
af("TextBox",{
Size=UDim2.new(0,al.TextBoxWidth,0,0),
TextXAlignment="Left",
Text=FormatValue(ap),
ThemeTag={
TextColor3="Text",
},
TextTransparency=0.4,
AutomaticSize="Y",
TextSize=15,
FontFace=Font.new(ae.Font,Enum.FontWeight.Medium),
BackgroundTransparency=1,
LayoutOrder=-1,
Visible=al.IsTextbox,
}),
})

local ax
if al.IsTooltip then
ax=a.load'B'.New(
ap,
al.UIElements.SliderIcon.Frame.Thumb,
true,
"Secondary",
"Small",
false
)
ax.Container.AnchorPoint=Vector2.new(0.5,1)
ax.Container.Position=UDim2.new(0.5,0,0,-8)
end

function al.Lock(ay)
al.Locked=true
as=false
return al.SliderFrame:Lock(al.LockedTitle)
end
function al.Unlock(ay)
al.Locked=false
as=true
return al.SliderFrame:Unlock()
end

if al.Locked then
al:Lock()
end


local ay=ak.Tab.UIElements.ContainerFrame

function al.Set(az,aA,aB)
if as then
if
not al.IsFocusing
and not ai
and(
not aB
or(
aB.UserInputType==Enum.UserInputType.MouseButton1
or aB.UserInputType==Enum.UserInputType.Touch
)
)
then
if aB then
am=(aB.UserInputType==Enum.UserInputType.Touch)
ay.ScrollingEnabled=false
ai=true

local b=am and aB.Position.X or ac:GetMouseLocation().X
local d=math.clamp(
(b-al.UIElements.SliderIcon.AbsolutePosition.X)
/al.UIElements.SliderIcon.AbsoluteSize.X,
0,
1
)
aA=CalculateValue(al.Value.Min+d*(al.Value.Max-al.Value.Min))
aA=math.clamp(aA,al.Value.Min or 0,al.Value.Max or 100)

if aA~=aq then
ag(al.UIElements.SliderIcon.Frame,0.05,{Size=UDim2.new(d,0,1,0)}):Play()
al.UIElements.SliderContainer.TextBox.Text=FormatValue(aA)
if ax then
ax.TitleFrame.Text=FormatValue(aA)
end
al.Value.Default=FormatValue(aA)
aq=aA
ae.SafeCallback(al.Callback,FormatValue(aA))
end

an=ad.RenderStepped:Connect(function()
local f=am and aB.Position.X or ac:GetMouseLocation().X
local g=math.clamp(
(f-al.UIElements.SliderIcon.AbsolutePosition.X)
/al.UIElements.SliderIcon.AbsoluteSize.X,
0,
1
)
aA=CalculateValue(al.Value.Min+g*(al.Value.Max-al.Value.Min))

if aA~=aq then
ag(al.UIElements.SliderIcon.Frame,0.05,{Size=UDim2.new(g,0,1,0)}):Play()
al.UIElements.SliderContainer.TextBox.Text=FormatValue(aA)
if ax then
ax.TitleFrame.Text=FormatValue(aA)
end
al.Value.Default=FormatValue(aA)
aq=aA
ae.SafeCallback(al.Callback,FormatValue(aA))
end
end)


ao=ac.InputEnded:Connect(function(f)
if
(
f.UserInputType==Enum.UserInputType.MouseButton1
or f.UserInputType==Enum.UserInputType.Touch
)and aB==f
then
an:Disconnect()
ao:Disconnect()
ai=false
ay.ScrollingEnabled=true

ak.WindUI.CurrentInput=nil

if ak.Window.NewElements then
ag(al.UIElements.SliderIcon.Frame.Thumb,0.2,{
ImageTransparency=0,
Size=UDim2.new(
0,
ak.Window.NewElements and(al.ThumbSize*2)or(al.ThumbSize+2),
0,
ak.Window.NewElements and(al.ThumbSize+4)or(al.ThumbSize+2)
),
},Enum.EasingStyle.Quint,Enum.EasingDirection.InOut):Play()
end
if ax then
ax:Close(false)
end
end
end)
else
aA=math.clamp(aA,al.Value.Min or 0,al.Value.Max or 100)

local b=math.clamp(
(aA-(al.Value.Min or 0))/((al.Value.Max or 100)-(al.Value.Min or 0)),
0,
1
)
aA=CalculateValue(al.Value.Min+b*(al.Value.Max-al.Value.Min))

if aA~=aq then
ag(al.UIElements.SliderIcon.Frame,0.05,{Size=UDim2.new(b,0,1,0)}):Play()
al.UIElements.SliderContainer.TextBox.Text=FormatValue(aA)
if ax then
ax.TitleFrame.Text=FormatValue(aA)
end
al.Value.Default=FormatValue(aA)
aq=aA
ae.SafeCallback(al.Callback,FormatValue(aA))
end
end
end
end
end

function al.SetMax(az,aA)
al.Value.Max=aA

local aB=tonumber(al.Value.Default)or aq
if aB>aA then
al:Set(aA)
else
local b=
math.clamp((aB-(al.Value.Min or 0))/(aA-(al.Value.Min or 0)),0,1)
ag(al.UIElements.SliderIcon.Frame,0.1,{Size=UDim2.new(b,0,1,0)}):Play()
end
end

function al.SetMin(az,aA)
al.Value.Min=aA

local aB=tonumber(al.Value.Default)or aq
if aB<aA then
al:Set(aA)
else
local b=math.clamp((aB-aA)/((al.Value.Max or 100)-aA),0,1)
ag(al.UIElements.SliderIcon.Frame,0.1,{Size=UDim2.new(b,0,1,0)}):Play()
end
end

ae.AddSignal(al.UIElements.SliderContainer.TextBox.FocusLost,function(az)
local aA=tonumber(al.UIElements.SliderContainer.TextBox.Text)
if aA then
al:Set(aA)
else
al.UIElements.SliderContainer.TextBox.Text=FormatValue(aq)
if ax then
ax.TitleFrame.Text=FormatValue(aq)
end
end
end)

local az=ak.WindUI.GenerateGUID()

ae.AddSignal(al.UIElements.SliderContainer.InputBegan,function(aA)
if al.Locked or ai then
return
end
if
aA.UserInputType==Enum.UserInputType.MouseButton1
or aA.UserInputType==Enum.UserInputType.Touch
then
if ak.WindUI.CurrentInput and ak.WindUI.CurrentInput~=az then
return
end
ak.WindUI.CurrentInput=az

al:Set(ap,aA)


if ak.Window.NewElements then
ag(al.UIElements.SliderIcon.Frame.Thumb,0.24,{
ImageTransparency=0.85,
Size=UDim2.new(
0,
(ak.Window.NewElements and(al.ThumbSize*2)or al.ThumbSize)+8,
0,
al.ThumbSize+8
),
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end
if ax then
ax:Open()
end

end
end)

return al.__type,al
end

return ah end function a.J()

local aa=a.load'd'
local ac=aa.New
local ad=aa.Tween

local ae={}

local function ToFiniteNumber(af)
local ag=tonumber(af)
if ag==nil or ag~=ag or math.abs(ag)==math.huge then
return nil
end

return ag
end

local function FormatNumber(af)
if af%1==0 then
return tostring(af)
end

return tostring(tonumber(string.format("%.2f",af)))
end

function ae.New(af,ag)
local ah=typeof(ag.Value)=="table"and ag.Value or{}
local ai=ToFiniteNumber(ah.Min)or ToFiniteNumber(ag.Min)or 0
local aj=ToFiniteNumber(ah.Max)or ToFiniteNumber(ag.Max)or 100

if ai>aj then
ai,aj=aj,ai
end

local ak=typeof(ag.Value)=="number"and ag.Value
or ToFiniteNumber(ah.Default)
or ToFiniteNumber(ag.Default)
or ai
ak=ToFiniteNumber(ak)or ai

local al=ag.Indeterminate==true

local am=ag.ShowValue
if am==nil then
am=not al
end

local an=math.max(ToFiniteNumber(ag.ValueWidth)or 44,0)

local ao={
__type="ProgressBar",
Title=ag.Title or"Progress",
Desc=ag.Desc or nil,
Value={
Min=ai,
Max=aj,
Default=math.clamp(ak,ai,aj),
},
ShowValue=am,
DisplayMode=ag.DisplayMode or"Percent",
Format=ag.Format,
Animate=ag.Animate~=false,
AnimationDuration=math.max(ToFiniteNumber(ag.AnimationDuration)or 0.15,0),
Indeterminate=al,
IndeterminateText=ag.IndeterminateText or"",
Speed=math.max(ToFiniteNumber(ag.Speed)or 1,0.01),
ControlGap=math.max(ToFiniteNumber(ag.ControlGap)or 16,0),
UIElements={},

Width=math.max(ToFiniteNumber(ag.Width)or 160,0),
ValueWidth=an,
}

local function GetRatio(ap)
if ao.Value.Max==ao.Value.Min then
return ap>=ao.Value.Max and 1 or 0
end

return math.clamp((ap-ao.Value.Min)/(ao.Value.Max-ao.Value.Min),0,1)
end

local function GetValueText(ap,aq)
if ao.Indeterminate then
return tostring(ao.IndeterminateText)
end

local ar=aq*100

if typeof(ao.Format)=="function"then
local as,at=
pcall(ao.Format,ap,ar,ao.Value.Min,ao.Value.Max)

if as and at~=nil then
return tostring(at)
end
end

if ao.DisplayMode=="Value"then
return FormatNumber(ap)
elseif ao.DisplayMode=="Fraction"then
return FormatNumber(ap).."/"..FormatNumber(ao.Value.Max)
end

return tostring(math.floor(ar+0.5)).."%"
end

ao.ProgressBarFrame=a.load'C'{
Title=ao.Title,
Desc=ao.Desc,
Parent=ag.Parent,
TextOffset=ao.Width+ao.ControlGap,
Hover=false,
Tab=ag.Tab,
Index=ag.Index,
Window=ag.Window,
ElementTable=ao,
ParentConfig=ag,
Tags=ag.Tags,
}

ao.UIElements.Fill=aa.NewRoundFrame(99,"Squircle",{
Name="Fill",
Size=ao.Indeterminate and UDim2.new(0.3,0,1,0)
or UDim2.new(GetRatio(ao.Value.Default),0,1,0),
Position=ao.Indeterminate and UDim2.new(-0.3,0,0,0)or UDim2.new(0,0,0,0),
ThemeTag={
ImageColor3="ProgressBar",
},
})

ao.UIElements.Bar=aa.NewRoundFrame(99,"Squircle",{
Name="Bar",
Size=UDim2.new(1,ao.ShowValue and-(ao.ValueWidth+8)or 0,0,6),
ClipsDescendants=true,
ImageTransparency=0.9,
ThemeTag={
ImageColor3="ProgressBarTrack",
ImageTransparency="ProgressBarTrackTransparency",
},
},{
ao.UIElements.Fill,
})

ao.UIElements.Value=ac("TextLabel",{
Name="Value",
Size=UDim2.new(0,ao.ValueWidth,0,20),
BackgroundTransparency=1,
FontFace=Font.new(aa.Font,Enum.FontWeight.Medium),
Text=GetValueText(ao.Value.Default,GetRatio(ao.Value.Default)),
TextSize=14,
TextTransparency=0.25,
TextTruncate="AtEnd",
TextXAlignment="Right",
Visible=ao.ShowValue,
ThemeTag={
TextColor3="ProgressBarText",
},
})

ao.UIElements.Container=ac("Frame",{
Name="ProgressBarContainer",
Size=UDim2.new(0,ao.Width,0,36),
Position=UDim2.new(1,0,ag.Window.NewElements and 0 or 0.5,0),
AnchorPoint=Vector2.new(1,ag.Window.NewElements and 0 or 0.5),
BackgroundTransparency=1,
Parent=ao.ProgressBarFrame.UIElements.Main,
},{
ac("UIListLayout",{
Padding=UDim.new(0,8),
FillDirection="Horizontal",
HorizontalAlignment="Right",
VerticalAlignment="Center",
}),
ao.UIElements.Bar,
ao.UIElements.Value,
})

if ao.Indeterminate then
local ap=ad(
ao.UIElements.Fill,
1/ao.Speed,
{Position=UDim2.new(1,0,0,0)},
Enum.EasingStyle.Linear,
Enum.EasingDirection.InOut,-1

)
aa.AddSignal(ao.UIElements.Bar.Destroying,function()
ap:Cancel()
end)
ap:Play()
end

local function Update(ap,aq)
local ar=ToFiniteNumber(ap)
if ar==nil then
return ao.Value.Default
end

ar=math.clamp(ar,ao.Value.Min,ao.Value.Max)
ao.Value.Default=ar

local as=GetRatio(ar)
local at=UDim2.new(as,0,1,0)

if ao.UIElements.Fill and not ao.Indeterminate then
if aq or not ao.Animate or ao.AnimationDuration<=0 then
ao.UIElements.Fill.Size=at
else
ad(
ao.UIElements.Fill,
ao.AnimationDuration,
{Size=at},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
end
end

ao.UIElements.Value.Text=GetValueText(ar,as)

return ar
end

function ao.Set(ap,aq)
return Update(aq,false)
end

function ao.Get(ap)
return ao.Value.Default
end

function ao.GetPercentage(ap)
return GetRatio(ao.Value.Default)*100
end

function ao.SetRange(ap,aq,ar)
aq=ToFiniteNumber(aq)
ar=ToFiniteNumber(ar)

if aq==nil or ar==nil then
return ao.Value.Min,ao.Value.Max
end

if aq>ar then
aq,ar=ar,aq
end

ao.Value.Min=aq
ao.Value.Max=ar
Update(ao.Value.Default,false)

return aq,ar
end

function ao.SetMin(ap,aq)
aq=ToFiniteNumber(aq)
if aq==nil then
return ao.Value.Min
end

ao:SetRange(aq,math.max(aq,ao.Value.Max))
return ao.Value.Min
end

function ao.SetMax(ap,aq)
aq=ToFiniteNumber(aq)
if aq==nil then
return ao.Value.Max
end

ao:SetRange(math.min(ao.Value.Min,aq),aq)
return ao.Value.Max
end

Update(ao.Value.Default,true)

return ao.__type,ao
end

return ae end function a.K()

local aa=(cloneref or clonereference or function(aa)
return aa
end)

local ac=aa(game:GetService"UserInputService")

local ad=a.load'd'
local ae=ad.New local af=
ad.Tween

local ag={
UICorner=6,
UIPadding=8,
}

local ah=a.load'w'.New

function ag.New(ai,aj)
local function NormalizeKeyCode(ak)
if typeof(ak)=="EnumItem"then
return ak.Name
elseif type(ak)=="string"then
return ak
else
return"F"
end
end

local ak={
__type="Keybind",
Title=aj.Title or"Keybind",
Desc=aj.Desc or nil,
Locked=aj.Locked or false,
LockedTitle=aj.LockedTitle,
Value=NormalizeKeyCode(aj.Value)or"F",
Callback=aj.Callback or function()end,
CanChange=aj.CanChange~=false,
Blacklist=aj.Blacklist or{},
Picking=false,
UIElements={},
}

local al={}

for am,an in next,ak.Blacklist do
table.insert(al,Enum.KeyCode[NormalizeKeyCode(an)])
end
table.insert(al,Enum.KeyCode[NormalizeKeyCode"Escape"])

local am=true

ak.KeybindFrame=a.load'C'{
Title=ak.Title,
Desc=ak.Desc,
Parent=aj.Parent,
TextOffset=85,
Hover=ak.CanChange,
Tab=aj.Tab,
Index=aj.Index,
Window=aj.Window,
ElementTable=ak,
ParentConfig=aj,
Tags=aj.Tags,
}

ak.UIElements.Keybind=ah(
ak.Value,
nil,
ak.KeybindFrame.UIElements.Main,
nil,
aj.Window.NewElements and 12 or 10
)

ak.UIElements.Keybind.Size=
UDim2.new(0,24+ak.UIElements.Keybind.Frame.Frame.TextLabel.TextBounds.X,0,42)
ak.UIElements.Keybind.AnchorPoint=Vector2.new(1,0.5)
ak.UIElements.Keybind.Position=UDim2.new(1,0,0.5,0)
ak.UIElements.Keybind.Interactable=false

ae("UIScale",{
Parent=ak.UIElements.Keybind,
Scale=0.85,
})

ad.AddSignal(
ak.UIElements.Keybind.Frame.Frame.TextLabel:GetPropertyChangedSignal"TextBounds",
function()
ak.UIElements.Keybind.Size=
UDim2.new(0,24+ak.UIElements.Keybind.Frame.Frame.TextLabel.TextBounds.X,0,42)
end
)

function ak.Lock(an)
ak.Locked=true
am=false
return ak.KeybindFrame:Lock(ak.LockedTitle)
end
function ak.Unlock(an)
ak.Locked=false
am=true
return ak.KeybindFrame:Unlock()
end

function ak.Set(an,ao)
local ap=NormalizeKeyCode(ao)
ak.Value=ap
ak.UIElements.Keybind.Frame.Frame.TextLabel.Text=ap
end

if ak.Locked then
ak:Lock()
end

local an

ad.AddSignal(ak.KeybindFrame.UIElements.Main.MouseButton1Click,function()
if am then
if ak.CanChange then
ak.Picking=true
ak.UIElements.Keybind.Frame.Frame.TextLabel.Text="..."



local ao
ao=ac.InputBegan:Connect(function(ap)
local aq

if ap.UserInputType==Enum.UserInputType.Keyboard then
if table.find(al,ap.KeyCode)then
aq=nil
return
else
aq=ap.KeyCode.Name
end
elseif
ap.UserInputType==Enum.UserInputType.MouseButton1
and not table.find(al,"MouseLeftButton")
then
aq="MouseLeftButton"
elseif
ap.UserInputType==Enum.UserInputType.MouseButton2
and not table.find(al,"MouseRightButton")
then
aq="MouseRightButton"
end

if an then
an:Disconnect()
end

an=ac.InputEnded:Connect(function(ar)
if
aq
and(
ar.KeyCode.Name==aq
or aq=="MouseLeft"and ar.UserInputType==Enum.UserInputType.MouseButton1
or aq=="MouseRight"and ar.UserInputType==Enum.UserInputType.MouseButton2
)
then
ak.Picking=false

ak.UIElements.Keybind.Frame.Frame.TextLabel.Text=aq
ak.Value=aq

ao:Disconnect()
an:Disconnect()
end
end)
end)
end
end
end)

ad.AddSignal(ac.InputBegan,function(ao,ap)
if ac:GetFocusedTextBox()then
return
end
if not am then
return
end
if ak.Picking then
return
end

if ao.UserInputType==Enum.UserInputType.Keyboard then
if ao.KeyCode.Name==ak.Value then
ad.SafeCallback(ak.Callback,ao.KeyCode.Name)
end
elseif ao.UserInputType==Enum.UserInputType.MouseButton1 and ak.Value=="MouseLeft"then
ad.SafeCallback(ak.Callback,"MouseLeft")
elseif ao.UserInputType==Enum.UserInputType.MouseButton2 and ak.Value=="MouseRight"then
ad.SafeCallback(ak.Callback,"MouseRight")
end
end)

return ak.__type,ak
end

return ag end function a.L()

local aa=a.load'd'local ac=
aa.New local ad=
aa.Tween

local ae={
UICorner=8,
UIPadding=8,
}local af=a.load'm'

.New
local ag=a.load'n'.New

function ae.New(ah,ai)
local aj={
__type="Input",
Title=ai.Title or"Input",
Desc=ai.Desc or nil,
Type=ai.Type or"Input",
Locked=ai.Locked or false,
LockedTitle=ai.LockedTitle,
InputIcon=ai.InputIcon or false,
Placeholder=ai.Placeholder or"Enter Text...",
Value=ai.Value or"",
Callback=ai.Callback or function()end,
ClearTextOnFocus=ai.ClearTextOnFocus or false,
UIElements={},

Width=150,
}

local ak=true

aj.InputFrame=a.load'C'{
Title=aj.Title,
Desc=aj.Desc,
Parent=ai.Parent,
TextOffset=aj.Width,
Hover=false,
Tab=ai.Tab,
Index=ai.Index,
Window=ai.Window,
ElementTable=aj,
ParentConfig=ai,
Tags=ai.Tags,
}

local al=ag(
aj.Placeholder,
aj.InputIcon,
aj.Type=="Textarea"and aj.InputFrame.UIElements.Container or aj.InputFrame.UIElements.Main,
aj.Type,
function(al)
aj:Set(al,true)
end,
nil,
ai.Window.NewElements and 12 or 10,
aj.ClearTextOnFocus
)

if aj.Type~="Textarea"then
al.Size=UDim2.new(0,aj.Width,0,36)
al.Position=UDim2.new(1,0,ai.Window.NewElements and 0 or 0.5,0)
al.AnchorPoint=Vector2.new(1,ai.Window.NewElements and 0 or 0.5)
else
al.Size=UDim2.new(1,0,0,148)
end






function aj.Lock(am)
aj.Locked=true
ak=false
return aj.InputFrame:Lock(aj.LockedTitle)
end
function aj.Unlock(am)
aj.Locked=false
ak=true
return aj.InputFrame:Unlock()
end

function aj.Set(am,an,ao)
if ak then
aj.Value=an
aa.SafeCallback(aj.Callback,an)

if not ao then
al.Frame.Frame.TextBox.Text=an
end
end
end

function aj.SetPlaceholder(am,an)
al.Frame.Frame.TextBox.PlaceholderText=an
aj.Placeholder=an
end

aj:Set(aj.Value)

if aj.Locked then
aj:Lock()
end

return aj.__type,aj
end

return ae end function a.M()

local aa=a.load'd'
local ae=aa.New

local af={}

function af.New(ag,ah)
local ai=ae("Frame",{
Size=ah.ParentType~="Group"and UDim2.new(1,0,0,1)or UDim2.new(0,1,1,0),
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundTransparency=.9,
ThemeTag={
BackgroundColor3="Text"
}
})
local aj=ae("Frame",{
Parent=ah.Parent,
Size=ah.ParentType~="Group"and UDim2.new(1,-7,0,7)or UDim2.new(0,7,1,-7),
BackgroundTransparency=1,
},{
ai
})

return"Divider",{__type="Divider",ElementFrame=aj}
end

return af end function a.N()
local aa={}

local ae=(cloneref or clonereference or function(ae)
return ae
end)

local af=ae(game:GetService"UserInputService")
local ag=ae(game:GetService"Players").LocalPlayer:GetMouse()
local ah=ae(game:GetService"Workspace").CurrentCamera local ai=

workspace.CurrentCamera

local aj=a.load'n'.New

local ak=a.load'd'
local al=ak.New
local am=ak.Tween

local an=0.67

function aa.New(ao,ap,aq,ar)
local as={}

if not ap.Callback then
ar="Menu"
end

ap.UIElements.UIListLayout=al("UIListLayout",{
Padding=UDim.new(0,aq.MenuPadding/1.5),
FillDirection="Vertical",
HorizontalAlignment="Center",
})

ap.UIElements.Menu=ak.NewRoundFrame(aq.MenuCorner,"Squircle",{
ThemeTag={
ImageColor3="DropdownBackground",
},
ImageTransparency=1,
Size=UDim2.new(1,0,1,0),
AnchorPoint=Vector2.new(1,0),
Position=UDim2.new(1,0,0,0),
},{
al("UIPadding",{
PaddingTop=UDim.new(0,aq.MenuPadding),
PaddingLeft=UDim.new(0,aq.MenuPadding),
PaddingRight=UDim.new(0,aq.MenuPadding),
PaddingBottom=UDim.new(0,aq.MenuPadding),
}),
al("UIListLayout",{
FillDirection="Vertical",
Padding=UDim.new(0,aq.MenuPadding),
}),
al("Frame",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,1,ap.SearchBarEnabled and-aq.MenuPadding-aq.SearchBarHeight),

ClipsDescendants=true,
LayoutOrder=999,
Name="Frame",
},{
al("UICorner",{
CornerRadius=UDim.new(0,aq.MenuCorner-aq.MenuPadding),
}),
al("ScrollingFrame",{
Size=UDim2.new(1,0,1,0),
ScrollBarThickness=0,
ScrollingDirection="Y",
AutomaticCanvasSize="Y",
CanvasSize=UDim2.new(0,0,0,0),
BackgroundTransparency=1,
ScrollBarImageTransparency=1,
},{
ap.UIElements.UIListLayout,
}),
}),
})

ap.UIElements.MenuCanvas=al("Frame",{
Size=UDim2.new(0,ap.MenuWidth,0,300),
BackgroundTransparency=1,
Position=UDim2.new(-10,0,-10,0),
Visible=false,
Active=false,

Parent=ao.WindUI.DropdownGui,
AnchorPoint=Vector2.new(1,0),
},{
ap.UIElements.Menu,
al("UISizeConstraint",{
MinSize=Vector2.new(170,0),
MaxSize=Vector2.new(300,400),
}),
})

local function RecalculateCanvasSize()
ap.UIElements.Menu.Frame.ScrollingFrame.CanvasSize=
UDim2.fromOffset(0,ap.UIElements.UIListLayout.AbsoluteContentSize.Y)
end

local function RecalculateListSize()
local at=ao.WindUI.DropdownGui.AbsoluteSize.Y

local au=ap.UIElements.UIListLayout.AbsoluteContentSize.Y/ao.UIScale
local av=ap.SearchBarEnabled and(aq.SearchBarHeight+(aq.MenuPadding*3))
or(aq.MenuPadding*2)
local aw=au+av

if aw>at then
ap.UIElements.MenuCanvas.Size=
UDim2.fromOffset(ap.UIElements.MenuCanvas.AbsoluteSize.X,at)
else
ap.UIElements.MenuCanvas.Size=
UDim2.fromOffset(ap.UIElements.MenuCanvas.AbsoluteSize.X,aw)
end
end

function UpdatePosition()
local at=ap.UIElements.Dropdown or ap.DropdownFrame.UIElements.Main
local au=ap.UIElements.MenuCanvas

local av=ah.ViewportSize.Y
-(at.AbsolutePosition.Y+at.AbsoluteSize.Y)
-aq.MenuPadding
-54
local aw=au.AbsoluteSize.Y+aq.MenuPadding

local ax=-54
if av<aw then
ax=aw-av-54
end

au.Position=UDim2.new(
0,
at.AbsolutePosition.X+at.AbsoluteSize.X,
0,
at.AbsolutePosition.Y+at.AbsoluteSize.Y-ax+(aq.MenuPadding*2)
)
end

local at

function as.Display(au)
local av=ap.Values
local aw=""

if ap.Multi then
local ax={}
if typeof(ap.Value)=="table"then
for ay,az in ipairs(ap.Value)do
local aA=typeof(az)=="table"and az.Title or az
ax[aA]=true
end
end

for ay,az in ipairs(av)do
local aA=typeof(az)=="table"and az.Title or az
if ax[aA]then
aw=aw..aA..", "
end
end

if#aw>0 then
aw=aw:sub(1,#aw-2)
end
else
aw=typeof(ap.Value)=="table"and(ap.Value.Title or ap.Value[1])
or ap.Value
or""
end

if ap.UIElements.Dropdown then
ap.UIElements.Dropdown.Frame.Frame.TextLabel.Text=(aw==""and"--"or aw)
end
end

local function Callback(au)
as:Display()
if ap.Locked then
return
end

if ap.Callback then
task.spawn(function()
if ap.Locked then
return
end
ak.SafeCallback(ap.Callback,ap.Value)
end)
else
task.spawn(function()
if ap.Locked then
return
end
ak.SafeCallback(au)
end)
end
end

function as.LockValues(au,av)
if not av then
return
end

for aw,ax in next,ap.Tabs do
if ax and ax.UIElements and ax.UIElements.TabItem then
local ay=ax.Name
local az=false

for aA,aB in next,av do
if ay==aB then
az=true
break
end
end

if az then
am(ax.UIElements.TabItem,0.1,{ImageTransparency=1}):Play()

am(ax.UIElements.TabItem.Frame.Title.TextLabel,0.1,{TextTransparency=0.6}):Play()
if ax.UIElements.TabIcon then
am(ax.UIElements.TabIcon.ImageLabel,0.1,{ImageTransparency=0.6}):Play()
end

ax.UIElements.TabItem.Active=false
ax.Locked=true
else
if ax.Selected then
am(ax.UIElements.TabItem,0.1,{ImageTransparency=an}):Play()

am(ax.UIElements.TabItem.Frame.Title.TextLabel,0.1,{TextTransparency=0}):Play()
if ax.UIElements.TabIcon then
am(ax.UIElements.TabIcon.ImageLabel,0.1,{ImageTransparency=0}):Play()
end
else
am(ax.UIElements.TabItem,0.1,{ImageTransparency=1}):Play()

am(
ax.UIElements.TabItem.Frame.Title.TextLabel,
0.1,
{TextTransparency=ar=="Dropdown"and 0.4 or 0.05}
):Play()
if ax.UIElements.TabIcon then
am(
ax.UIElements.TabIcon.ImageLabel,
0.1,
{ImageTransparency=ar=="Dropdown"and 0.2 or 0}
):Play()
end
end

ax.UIElements.TabItem.Active=true
ax.Locked=false
end
end
end
end

function as.Refresh(au,av)
if ao.Window.Destroyed then
return
end

for aw,ax in next,ap.UIElements.Menu.Frame.ScrollingFrame:GetChildren()do
if not ax:IsA"UIListLayout"then
ax:Destroy()
end
end

ap.Tabs={}

if ap.SearchBarEnabled then
if not at then
at=aj("Search...","search",ap.UIElements.Menu,nil,function(aw)
for ax,ay in next,ap.Tabs do
if string.find(string.lower(ay.Name),string.lower(aw),1,true)then
ay.UIElements.TabItem.Visible=true
else
ay.UIElements.TabItem.Visible=false
end
RecalculateListSize()
RecalculateCanvasSize()
end
end,true)
at.Size=UDim2.new(1,0,0,aq.SearchBarHeight)
at.Position=UDim2.new(0,0,0,0)
at.Name="SearchBar"
end
end

for aw,ax in next,av do
if ax.Type~="Divider"then
local ay={
Name=typeof(ax)=="table"and ax.Title or ax,
Desc=typeof(ax)=="table"and ax.Desc or nil,
Icon=typeof(ax)=="table"and ax.Icon or nil,
IconSize=typeof(ax)=="table"and ax.IconSize or nil,
Original=ax,
Selected=false,
Locked=typeof(ax)=="table"and ax.Locked or false,
UIElements={},
}
local az
if ay.Icon then
az=ak.Image(ay.Icon,ay.Icon,0,ao.Window.Folder,"Dropdown",true)
az.Size=
UDim2.new(0,ay.IconSize or aq.TabIcon,0,ay.IconSize or aq.TabIcon)
az.ImageLabel.ImageTransparency=ar=="Dropdown"and 0.2 or 0
ay.UIElements.TabIcon=az
end
ay.UIElements.TabItem=ak.NewRoundFrame(
aq.MenuCorner-aq.MenuPadding,
"Squircle",
{
Size=UDim2.new(1,0,0,36),
AutomaticSize=ay.Desc and"Y",
ImageTransparency=1,
Parent=ap.UIElements.Menu.Frame.ScrollingFrame,

ThemeTag={
ImageColor3="DropdownTabBackground",
},
Active=not ay.Locked,
},
{
ak.NewRoundFrame(aq.MenuCorner-aq.MenuPadding,"Glass-1.4",{
Size=UDim2.new(1,0,1,0),
ThemeTag={
ImageColor3="DropdownTabBorder",
},
ImageTransparency=1,
Name="Highlight",
},{













}),
al("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
},{
al("UIListLayout",{
Padding=UDim.new(0,aq.TabPadding),
FillDirection="Horizontal",
VerticalAlignment="Center",
}),
al("UIPadding",{
PaddingTop=UDim.new(0,aq.TabPadding),
PaddingLeft=UDim.new(0,aq.TabPadding),
PaddingRight=UDim.new(0,aq.TabPadding),
PaddingBottom=UDim.new(0,aq.TabPadding),
}),
al("UICorner",{
CornerRadius=UDim.new(0,aq.MenuCorner-aq.MenuPadding),
}),
az,
al("Frame",{
Size=UDim2.new(1,az and-aq.TabPadding-aq.TabIcon or 0,0,0),
BackgroundTransparency=1,
AutomaticSize="Y",
Name="Title",
},{
al("TextLabel",{
Text=ay.Name,
TextXAlignment="Left",
FontFace=Font.new(ak.Font,Enum.FontWeight.Medium),
ThemeTag={
TextColor3="Text",
BackgroundColor3="Text",
},
TextSize=15,
BackgroundTransparency=1,
TextTransparency=ar=="Dropdown"and 0.4 or 0.05,
LayoutOrder=999,
AutomaticSize="Y",
Size=UDim2.new(1,0,0,0),
}),
al("TextLabel",{
Text=ay.Desc or"",
TextXAlignment="Left",
FontFace=Font.new(ak.Font,Enum.FontWeight.Regular),
ThemeTag={
TextColor3="Text",
BackgroundColor3="Text",
},
TextSize=15,
BackgroundTransparency=1,
TextTransparency=ar=="Dropdown"and 0.6 or 0.35,
LayoutOrder=999,
AutomaticSize="Y",
TextWrapped=true,
Size=UDim2.new(1,0,0,0),
Visible=ay.Desc and true or false,
Name="Desc",
}),
al("UIListLayout",{
Padding=UDim.new(0,aq.TabPadding/3),
FillDirection="Vertical",
}),
}),
}),
},
true
)

if ay.Locked then
ay.UIElements.TabItem.Frame.Title.TextLabel.TextTransparency=0.6
if ay.UIElements.TabIcon then
ay.UIElements.TabIcon.ImageLabel.ImageTransparency=0.6
end
end

if ap.Multi and typeof(ap.Value)=="string"then
for aA,aB in next,ap.Values do
if typeof(aB)=="table"then
if aB.Title==ap.Value then
ap.Value={aB}
end
else
if aB==ap.Value then
ap.Value={ap.Value}
end
end
end
end

if ap.Multi then
local aA=false
if typeof(ap.Value)=="table"then
for aB,b in ipairs(ap.Value)do
local d=typeof(b)=="table"and b.Title or b
if d==ay.Name then
aA=true
break
end
end
end
ay.Selected=aA
else
local aA=typeof(ap.Value)=="table"and ap.Value.Title or ap.Value
ay.Selected=aA==ay.Name
end

if ay.Selected and not ay.Locked then
ay.UIElements.TabItem.ImageTransparency=an

ay.UIElements.TabItem.Frame.Title.TextLabel.TextTransparency=0
if ay.UIElements.TabIcon then
ay.UIElements.TabIcon.ImageLabel.ImageTransparency=0
end
end

ap.Tabs[aw]=ay

as:Display()

if ar=="Dropdown"then
ak.AddSignal(ay.UIElements.TabItem.MouseButton1Click,function()
if ap.Locked or ay.Locked then
return
end

if ap.Multi then
if not ay.Selected then
ay.Selected=true
am(
ay.UIElements.TabItem,
0.1,
{ImageTransparency=an}
):Play()

am(ay.UIElements.TabItem.Frame.Title.TextLabel,0.1,{TextTransparency=0}):Play()
if ay.UIElements.TabIcon then
am(ay.UIElements.TabIcon.ImageLabel,0.1,{ImageTransparency=0}):Play()
end
table.insert(ap.Value,ay.Original)
else
if not ap.AllowNone and#ap.Value==1 then
return
end
ay.Selected=false
am(ay.UIElements.TabItem,0.1,{ImageTransparency=1}):Play()

am(ay.UIElements.TabItem.Frame.Title.TextLabel,0.1,{TextTransparency=0.4}):Play()
if ay.UIElements.TabIcon then
am(ay.UIElements.TabIcon.ImageLabel,0.1,{ImageTransparency=0.2}):Play()
end

for aA,aB in next,ap.Value do
if typeof(aB)=="table"and(aB.Title==ay.Name)or(aB==ay.Name)then
table.remove(ap.Value,aA)
break
end
end
end
else
for aA,aB in next,ap.Tabs do
am(aB.UIElements.TabItem,0.1,{ImageTransparency=1}):Play()

am(
aB.UIElements.TabItem.Frame.Title.TextLabel,
0.1,
{TextTransparency=0.4}
):Play()
if aB.UIElements.TabIcon then
am(aB.UIElements.TabIcon.ImageLabel,0.1,{ImageTransparency=0.2}):Play()
end
aB.Selected=false
end
ay.Selected=true
am(ay.UIElements.TabItem,0.1,{ImageTransparency=an}):Play()

am(ay.UIElements.TabItem.Frame.Title.TextLabel,0.1,{TextTransparency=0}):Play()
if ay.UIElements.TabIcon then
am(ay.UIElements.TabIcon.ImageLabel,0.1,{ImageTransparency=0}):Play()
end
ap.Value=ay.Original
end
Callback()
end)
elseif ar=="Menu"then
if not ay.Locked then
ak.AddSignal(ay.UIElements.TabItem.MouseEnter,function()
am(ay.UIElements.TabItem,0.08,{ImageTransparency=an}):Play()
end)
ak.AddSignal(ay.UIElements.TabItem.InputEnded,function()
am(ay.UIElements.TabItem,0.08,{ImageTransparency=1}):Play()
end)
end
ak.AddSignal(ay.UIElements.TabItem.MouseButton1Click,function()
if ap.Locked or ay.Locked then
return
end
Callback(ax.Callback or function()end)
end)
end

RecalculateCanvasSize()
RecalculateListSize()
else a.load'M'
:New{Parent=ap.UIElements.Menu.Frame.ScrollingFrame}
end
end










ap.UIElements.MenuCanvas.Size=UDim2.new(
0,
ap.MenuWidth+6+6+5+5+18+6+6,
ap.UIElements.MenuCanvas.Size.Y.Scale,
ap.UIElements.MenuCanvas.Size.Y.Offset
)
Callback()

ap.Values=av
end

as:Refresh(ap.Values)

function as.Select(au,av)
if av then
ap.Value=av
else
if ap.Multi then
ap.Value={}
else
ap.Value=nil
end
end
as:Refresh(ap.Values)
end

RecalculateListSize()
RecalculateCanvasSize()

function as.Open(au)
if not ap.Locked then
ap.UIElements.Menu.Visible=true
ap.UIElements.MenuCanvas.Visible=true
ap.UIElements.MenuCanvas.Active=true
ap.UIElements.Menu.Size=UDim2.new(1,0,0,0)
am(ap.UIElements.Menu,0.1,{
Size=UDim2.new(1,0,1,0),
ImageTransparency=0,
},Enum.EasingStyle.Quart,Enum.EasingDirection.Out):Play()

task.spawn(function()
task.wait(0.1)
if ap.Locked then
return
end
ap.Opened=true
end)

UpdatePosition()
end
end

function as.Close(au)
ap.Opened=false

am(ap.UIElements.Menu,0.25,{
Size=UDim2.new(1,0,0,0),
ImageTransparency=1,
},Enum.EasingStyle.Quart,Enum.EasingDirection.Out):Play()

task.spawn(function()
task.wait(0.1)
ap.UIElements.Menu.Visible=false
end)

task.spawn(function()
task.wait(0.25)
ap.UIElements.MenuCanvas.Visible=false
ap.UIElements.MenuCanvas.Active=false
end)
end

ak.AddSignal(
(
ap.UIElements.Dropdown and ap.UIElements.Dropdown.MouseButton1Click
or ap.DropdownFrame.UIElements.Main.MouseButton1Click
),
function()
as:Open()
end
)

ak.AddSignal(af.InputBegan,function(au)
if
au.UserInputType==Enum.UserInputType.MouseButton1
or au.UserInputType==Enum.UserInputType.Touch
then
local av=ap.UIElements.MenuCanvas
local aw,ax=av.AbsolutePosition,av.AbsoluteSize

local ay=ap.UIElements.Dropdown or ap.DropdownFrame.UIElements.Main
local az=ay.AbsolutePosition
local aA=ay.AbsoluteSize

local aB=ag.X>=az.X
and ag.X<=az.X+aA.X
and ag.Y>=az.Y
and ag.Y<=az.Y+aA.Y

local b=ag.X>=aw.X
and ag.X<=aw.X+ax.X
and ag.Y>=aw.Y
and ag.Y<=aw.Y+ax.Y

if ao.Window.CanDropdown and ap.Opened and not aB and not b then
as:Close()
end
end
end)

ak.AddSignal(
ap.UIElements.Dropdown and ap.UIElements.Dropdown:GetPropertyChangedSignal"AbsolutePosition"
or ap.DropdownFrame.UIElements.Main:GetPropertyChangedSignal"AbsolutePosition",
UpdatePosition
)

return as
end

return aa end function a.O()

local aa=(cloneref or clonereference or function(aa)
return aa
end)

aa(game:GetService"UserInputService")
aa(game:GetService"Players").LocalPlayer:GetMouse()local ae=
aa(game:GetService"Workspace").CurrentCamera

local af=a.load'd'
local ag=af.New local ah=
af.Tween

local ai=a.load'w'.New local aj=a.load'n'
.New
local ak=a.load'N'.New local al=

workspace.CurrentCamera

local am={
UICorner=10,
UIPadding=12,
MenuCorner=15,
MenuPadding=5,
TabPadding=10,
SearchBarHeight=39,
TabIcon=18,
}

function am.New(an,ao)
local ap={
__type="Dropdown",
Title=ao.Title or"Dropdown",
Desc=ao.Desc or nil,
Locked=ao.Locked or false,
LockedTitle=ao.LockedTitle,
Values=ao.Values or{},
MenuWidth=ao.MenuWidth or 180,
Value=ao.Value,
AllowNone=ao.AllowNone,
SearchBarEnabled=ao.SearchBarEnabled or false,
Multi=ao.Multi,
Callback=ao.Callback or nil,

UIElements={},

Opened=false,
Tabs={},

Width=150,
}

if ap.Multi and not ap.Value then
ap.Value={}
end
if ap.Values and typeof(ap.Value)=="number"then
ap.Value=ap.Values[ap.Value]
end

ap.DropdownFrame=a.load'C'{
Title=ap.Title,
Desc=ap.Desc,
Parent=ao.Parent,
TextOffset=ap.Callback and ap.Width or 20,
Hover=not ap.Callback and true or false,
Tab=ao.Tab,
Index=ao.Index,
Window=ao.Window,
ElementTable=ap,
ParentConfig=ao,
Tags=ao.Tags,
}

if ap.Callback then
ap.UIElements.Dropdown=
ai("",nil,ap.DropdownFrame.UIElements.Main,nil,ao.Window.NewElements and 12 or 10)

ap.UIElements.Dropdown.Frame.Frame.TextLabel.TextTruncate="AtEnd"
ap.UIElements.Dropdown.Frame.Frame.TextLabel.Size=
UDim2.new(1,ap.UIElements.Dropdown.Frame.Frame.TextLabel.Size.X.Offset-18-12-12,0,0)

ap.UIElements.Dropdown.Size=UDim2.new(0,ap.Width,0,36)
ap.UIElements.Dropdown.Position=UDim2.new(1,0,ao.Window.NewElements and 0 or 0.5,0)
ap.UIElements.Dropdown.AnchorPoint=Vector2.new(1,ao.Window.NewElements and 0 or 0.5)





end

ap.DropdownMenu=ak(ao,ap,am,"Dropdown")

ap.Display=ap.DropdownMenu.Display
ap.Refresh=ap.DropdownMenu.Refresh
ap.Select=ap.DropdownMenu.Select
ap.Open=ap.DropdownMenu.Open
ap.Close=ap.DropdownMenu.Close

ag("ImageLabel",{
Image=af.Icon"chevrons-up-down"[1],
ImageRectOffset=af.Icon"chevrons-up-down"[2].ImageRectPosition,
ImageRectSize=af.Icon"chevrons-up-down"[2].ImageRectSize,
Size=UDim2.new(0,18,0,18),
Position=UDim2.new(1,ap.UIElements.Dropdown and-12 or 0,0.5,0),
ThemeTag={
ImageColor3="Icon",
},
AnchorPoint=Vector2.new(1,0.5),
Parent=ap.UIElements.Dropdown and ap.UIElements.Dropdown.Frame
or ap.DropdownFrame.UIElements.Main,
})

function ap.Lock(aq)
ap.Locked=true
if ap.Opened or ap.UIElements.MenuCanvas.Visible then
ap:Close()
end
return ap.DropdownFrame:Lock(ap.LockedTitle)
end
function ap.Unlock(aq)
ap.Locked=false
return ap.DropdownFrame:Unlock()
end

if ap.Locked then
ap:Lock()
end

return ap.__type,ap
end

return am end function a.P()




local aa={}
local af={
lua={
"and",
"break",
"or",
"else",
"elseif",
"if",
"then",
"until",
"repeat",
"while",
"do",
"for",
"in",
"end",
"local",
"return",
"function",
"export",
},
rbx={
"game",
"workspace",
"script",
"math",
"string",
"table",
"task",
"wait",
"select",
"next",
"Enum",
"tick",
"assert",
"shared",
"loadstring",
"tonumber",
"tostring",
"type",
"typeof",
"unpack",
"Instance",
"CFrame",
"Vector3",
"Vector2",
"Color3",
"UDim",
"UDim2",
"Ray",
"BrickColor",
"OverlapParams",
"RaycastParams",
"Axes",
"Random",
"Region3",
"Rect",
"TweenInfo",
"collectgarbage",
"not",
"utf8",
"pcall",
"xpcall",
"_G",
"setmetatable",
"getmetatable",
"os",
"pairs",
"ipairs",
},
operators={
"#",
"+",
"-",
"*",
"%",
"/",
"^",
"=",
"~",
"=",
"<",
">",
},
}

local ag={
numbers=Color3.fromHex"#FAB387",
boolean=Color3.fromHex"#FAB387",
operator=Color3.fromHex"#94E2D5",
lua=Color3.fromHex"#CBA6F7",
rbx=Color3.fromHex"#F38BA8",
str=Color3.fromHex"#A6E3A1",
comment=Color3.fromHex"#9399B2",
null=Color3.fromHex"#F38BA8",
call=Color3.fromHex"#89B4FA",
self_call=Color3.fromHex"#89B4FA",
local_property=Color3.fromHex"#CBA6F7",
}

local function createKeywordSet(ai)
local ak={}
for al,am in ipairs(ai)do
ak[am]=true
end
return ak
end

local ai=createKeywordSet(af.lua)
local ak=createKeywordSet(af.rbx)
local al=createKeywordSet(af.operators)

local function getHighlight(am,an)
local ao=am[an]

if ag[ao.."_color"]then
return ag[ao.."_color"]
end

if tonumber(ao)then
return ag.numbers
elseif ao=="nil"then
return ag.null
elseif ao:sub(1,2)=="--"then
return ag.comment
elseif al[ao]then
return ag.operator
elseif ai[ao]then
return ag.lua
elseif ak[ao]then
return ag.rbx
elseif ao:sub(1,1)=='"'or ao:sub(1,1)=="'"then
return ag.str
elseif ao=="true"or ao=="false"then
return ag.boolean
end

if am[an+1]=="("then
if am[an-1]==":"then
return ag.self_call
end

return ag.call
end

if am[an-1]=="."then
if am[an-2]=="Enum"then
return ag.rbx
end

return ag.local_property
end
end

function aa.run(am,an)
if an~=nil then
for ao,ap in next,an do
ag[ao]=ap
end
end

local ao={}
local ap=""

local aq=false
local ar=false
local as=false

for at=1,#am do
local au=am:sub(at,at)

if ar then
if au=="\n"and not as then
table.insert(ao,ap)
table.insert(ao,au)
ap=""

ar=false
elseif am:sub(at-1,at)=="]]"and as then
ap=ap.."]"

table.insert(ao,ap)
ap=""

ar=false
as=false
else
ap=ap..au
end
elseif aq then
if au==aq and am:sub(at-1,at-1)~="\\"or au=="\n"then
ap=ap..au
aq=false
else
ap=ap..au
end
else
if am:sub(at,at+1)=="--"then
table.insert(ao,ap)
ap="-"
ar=true
as=am:sub(at+2,at+3)=="[["
elseif au=='"'or au=="'"then
table.insert(ao,ap)
ap=au
aq=au
elseif al[au]then
table.insert(ao,ap)
table.insert(ao,au)
ap=""
elseif au:match"[%w_]"then
ap=ap..au
else
table.insert(ao,ap)
table.insert(ao,au)
ap=""
end
end
end

table.insert(ao,ap)

local at={}

for au,av in ipairs(ao)do
local aw=getHighlight(ao,au)

if aw then
local ax=string.format(
'<font color = "#%s">%s</font>',
aw:ToHex(),
av:gsub("<","&lt;"):gsub(">","&gt;")
)

table.insert(at,ax)
else
table.insert(at,av)
end
end

return table.concat(at)
end

return aa end function a.Q()

local aa={}

local af=a.load'd'
local ag=af.New
local ai=af.Tween

local ak=a.load'P'

function aa.New(al,am,an,ao,ap)
local aq={
Radius=am.ElementConfig.UICorner,
Padding=am.NewElements and am.ElementConfig.UIPadding+4 or am.ElementConfig.UIPadding,

CodeFrame=nil,
}

local ar=ag("TextLabel",{
Text="",
TextColor3=Color3.fromHex"#CDD6F4",
TextTransparency=0,
TextSize=al.CodeSize,
TextWrapped=false,
LineHeight=1.15,
RichText=true,
TextXAlignment="Left",
Size=UDim2.new(0,0,0,0),
BackgroundTransparency=1,
AutomaticSize="XY",
},{
ag("UIPadding",{
PaddingTop=UDim.new(0,aq.Padding+3),
PaddingLeft=UDim.new(0,aq.Padding+3),
PaddingRight=UDim.new(0,aq.Padding+3),
PaddingBottom=UDim.new(0,aq.Padding+3),
}),
})
ar.Font="Code"

local as=ag("ScrollingFrame",{
Size=UDim2.new(1,0,0,0),
BackgroundTransparency=1,
AutomaticCanvasSize=al.Height~=nil and"XY"or"X",
ScrollingDirection=al.Height~=nil and"XY"or"X",
ElasticBehavior="Never",
CanvasSize=UDim2.new(0,0,0,0),
ScrollBarThickness=0,
},{
ar,
})

local at=al.CanCopied
and ag("TextButton",{
BackgroundTransparency=1,
Size=UDim2.new(0,35,0,35),
Position=UDim2.new(1,-aq.Padding/2,0,aq.Padding/2),
AnchorPoint=Vector2.new(1,0),
Visible=ao and true or false,
},{
af.NewRoundFrame(aq.Radius-4,"Squircle",{



ImageColor3=Color3.fromHex"#ffffff",
ImageTransparency=1,
Size=UDim2.new(1,0,1,0),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Name="Button",
},{
ag("UIScale",{
Scale=1,
}),
ag("ImageLabel",{
Image=af.Icon"copy"[1],
ImageRectSize=af.Icon"copy"[2].ImageRectSize,
ImageRectOffset=af.Icon"copy"[2].ImageRectPosition,
BackgroundTransparency=1,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Size=UDim2.new(0,12,0,12),



ImageColor3=Color3.fromHex"#ffffff",
ImageTransparency=0.1,
}),
}),
})
or nil

local au,av=af.NewRoundFrame(aq.Radius,"SquircleOutline",{
Size=UDim2.new(1,0,1,0),



ImageColor3=Color3.fromHex"#ffffff",
ImageTransparency=0.955,
Visible=false,
})

local aw,ax=af.NewRoundFrame(aq.Radius,"Squircle-TL-TR",{



ImageColor3=Color3.fromHex"#ffffff",
ImageTransparency=0.96,
Size=UDim2.new(1,0,0,20+(aq.Padding*2)),
Visible=al.Title and true or false,
},{










ag("TextLabel",{
Text=al.Title,



TextColor3=Color3.fromHex"#ffffff",
TextTransparency=0.2,
TextSize=18,
AutomaticSize="Y",
FontFace=Font.new(af.Font,Enum.FontWeight.Medium),
TextXAlignment="Left",
BackgroundTransparency=1,
TextTruncate="AtEnd",
Size=UDim2.new(1,at and-20-(aq.Padding*2),0,0),
}),
ag("UIPadding",{

PaddingLeft=UDim.new(0,aq.Padding+3),
PaddingRight=UDim.new(0,aq.Padding+3),

}),
ag("UIListLayout",{
Padding=UDim.new(0,aq.Padding),
FillDirection="Horizontal",
VerticalAlignment="Center",
}),
})

local ay,az=af.NewRoundFrame(aq.Radius,"Squircle",{



ImageColor3=Color3.fromHex"#212121",
ImageTransparency=0.035,
Size=al.Height~=nil
and UDim2.new(1,0,al.Height.Scale,al.Height.Offset==0 and-40 or al.Height.Offset)
or UDim2.new(1,0,0,20+(aq.Padding*2)),
AutomaticSize=al.Height~=nil and"None"or"Y",
Parent=an,
},{
au,
ag("Frame",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,al.Height~=nil and 1 or 0,0),
AutomaticSize=al.Height~=nil and"None"or"Y",
},{
aw,
as,
ag("UIListLayout",{
Padding=UDim.new(0,0),
FillDirection="Vertical",
}),
}),
at,
},nil,true)

aq.CodeFrame=ay
aq.CodeFrameModule=az
aq.OutlineFrame=au
aq.OutlineFrameModule=av
aq.TopbarFrame=aw
aq.TopbarFrameModule=ax

af.AddSignal(ar:GetPropertyChangedSignal"TextBounds",function()
if al.Height~=nil then
as.Size=UDim2.new(1,0,1,al.Title~=nil and-(20+(aq.Padding*2))or nil)
else
as.Size=
UDim2.new(1,0,0,(ar.TextBounds.Y/(ap or 1))+((aq.Padding+3)*2))
end
end)

function aq.Set(aA)
ar.Text=ak.run(aA,al.CodeTheme)
end

function aq.Destroy()
ay:Destroy()
aq=nil
end

aq.Set(al.Code)

if at then
af.AddSignal(at.InputBegan,function(aA:InputObject)
if
aA.UserInputType==Enum.UserInputType.MouseButton1
or aA.UserInputType==Enum.UserInputType.Touch
then
ai(at.Button,0.05,{ImageTransparency=0.95}):Play()
ai(at.Button.UIScale,0.05,{Scale=0.9}):Play()
end
end)
af.AddSignal(at.InputEnded,function()
ai(at.Button,0.08,{ImageTransparency=1}):Play()
ai(at.Button.UIScale,0.08,{Scale=1}):Play()
end)
af.AddSignal(at.MouseButton1Click,function()
if ao then
ao()
local aA=af.Icon"check"
at.Button.ImageLabel.Image=aA[1]
at.Button.ImageLabel.ImageRectSize=aA[2].ImageRectSize
at.Button.ImageLabel.ImageRectOffset=aA[2].ImageRectPosition

task.delay(1,function()
local aB=af.Icon"copy"
at.Button.ImageLabel.Image=aB[1]
at.Button.ImageLabel.ImageRectSize=aB[2].ImageRectSize
at.Button.ImageLabel.ImageRectOffset=aB[2].ImageRectPosition
end)
end
end)
end

return aq
end

return aa end function a.R()

local aa=a.load'd'local af=
aa.New


local ag=a.load'Q'

local ai={}

function ai.New(ak,al)
local am={
__type="Code",
Title=al.Title,
Code=al.Code,
CodeSize=al.CodeSize or 18,
Height=al.Height,
CodeTheme=al.CodeTheme,
Locked=false,
CanCopied=al.CanCopied~=false,
OnCopy=al.OnCopy,

Index=al.Index,
}

local an=not am.Locked











local ao=ag.New(am,al.Window,al.Parent,function()
if an then
local ao=am.Title or"code"
local ap,aq=pcall(function()
if toclipboard then
toclipboard(am.Code)
end
if setclipboard then
setclipboard(am.Code)
end

if am.OnCopy then
am.OnCopy()
end
end)
if not ap then
al.WindUI:Notify{
Title="Error",
Content="The "..ao.." is not copied. Error: "..aq,
Icon="x",
Duration=5,
}
end
end
end,al.WindUI.UIScale)

function am.SetCode(ap,aq)
ao.Set(aq)
am.Code=aq
end

function am.Set(ap,aq)
return am.SetCode(aq)
end

function am.Destroy(ap)
ao.Destroy()
am=nil
end

function am.UpdateShape(ap)
if al.Window.NewElements then
local aq=aa:GetElementPosition(
ap.Elements,
am.Index,
al.ParentType=="HStack"or al.ParentType=="Group"
)

if aq and ao.CodeFrameModule then
ao.CodeFrameModule:SetType(aq)

print(aq)
ao.TopbarFrameModule:SetType(
table.find({"Squircle-BL-BR","SquircleH-BL-BR"},aq)~=nil and"Square"or aq
)
end
end
end

am.UIElements={Main=ao.CodeFrame}
am.ElementFrame=ao.CodeFrame

return am.__type,am
end

return ai end function a.S()

local aa=a.load'd'
local af=aa.New local ag=
aa.Tween

local ai=(cloneref or clonereference or function(ai)
return ai
end)

local ak=ai(game:GetService"UserInputService")
ai(game:GetService"TouchInputService")
local al=ai(game:GetService"RunService")
local am=ai(game:GetService"Players")local an=

al.RenderStepped
local ao=am.LocalPlayer
local ap=ao:GetMouse()

local aq=a.load'm'.New
local ar=a.load'n'.New

local as={
UICorner=9,

}

local at

function as.Colorpicker(au,av,aw,ax,ay)
local az={
__type="Colorpicker",
Title=av.Title,
Desc=av.Desc,
Default=av.Value or av.Default,
Callback=av.Callback,
Transparency=av.Transparency,
UIElements=av.UIElements,

TextPadding=10,
}

local aA={}
local aB=az.Transparency~=nil

function az.SetHSVFromRGB(b,d)
local f,g,h=Color3.toHSV(d)
az.Hue=f
az.Sat=g
az.Vib=h
end

az:SetHSVFromRGB(az.Default)

local b=a.load'o'
local d=b.Create(nil,"Dialog",aw,ax,aw.UIElements.Main.Main)

az.ColorpickerFrame=d

d.UIElements.Main.Size=UDim2.new(1,0,0,0)



local f,g,h=az.Hue,az.Sat,az.Vib

az.UIElements.Title=af("TextLabel",{
Text=az.Title,
TextSize=20,
FontFace=Font.new(aa.Font,Enum.FontWeight.SemiBold),
TextXAlignment="Left",
Size=UDim2.new(0,0,0,0),
AutomaticSize="Y",
ThemeTag={
TextColor3="Text",
},
BackgroundTransparency=1,
Parent=d.UIElements.Main,
},{
af("UIPadding",{
PaddingTop=UDim.new(0,az.TextPadding/2),
PaddingLeft=UDim.new(0,az.TextPadding/2),
PaddingRight=UDim.new(0,az.TextPadding/2),
PaddingBottom=UDim.new(0,az.TextPadding/2),
}),
})





local i=af("Frame",{
Size=UDim2.new(1,0,1,0),
Position=UDim2.new(0,0,0,0),
BackgroundTransparency=1,
})

local l=af("Frame",{
Size=UDim2.new(0,14,0,14),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0,0),
Parent=i,
BackgroundColor3=az.Default,
},{
af("UIStroke",{
Thickness=2,
Transparency=0.1,
ThemeTag={
Color="Text",
},
}),
af("UICorner",{
CornerRadius=UDim.new(1,0),
}),
})

az.UIElements.SatVibMap=af("ImageLabel",{
Size=UDim2.fromOffset(160,158),
Position=UDim2.fromOffset(0,40+az.TextPadding),
Image="rbxassetid://4155801252",
BackgroundColor3=Color3.fromHSV(f,1,1),
BackgroundTransparency=0,
Parent=d.UIElements.Main,
},{
af("UICorner",{
CornerRadius=UDim.new(0,8),
}),
aa.NewRoundFrame(8,"SquircleOutline",{
ThemeTag={
ImageColor3="Outline",
},
Size=UDim2.new(1,0,1,0),
ImageTransparency=0.85,
ZIndex=99999,
},{
af("UIGradient",{
Rotation=45,
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0.0,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(1.0,Color3.fromRGB(255,255,255)),
},
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.0,0.1),
NumberSequenceKeypoint.new(0.5,1),
NumberSequenceKeypoint.new(1.0,0.1),
},
}),
}),

l,
})

az.UIElements.Inputs=af("Frame",{
AutomaticSize="XY",
Size=UDim2.new(0,0,0,0),
Position=UDim2.fromOffset(
aB and 240 or 210,
40+az.TextPadding
),
BackgroundTransparency=1,
Parent=d.UIElements.Main,
},{
af("UIListLayout",{
Padding=UDim.new(0,4),
FillDirection="Vertical",
}),
})





local m=af("Frame",{
BackgroundColor3=az.Default,
Size=UDim2.fromScale(1,1),
BackgroundTransparency=az.Transparency,
},{
af("UICorner",{
CornerRadius=UDim.new(0,8),
}),
})

af("ImageLabel",{
Image="http://www.roblox.com/asset/?id=14204231522",
ImageTransparency=0.45,
ScaleType=Enum.ScaleType.Tile,
TileSize=UDim2.fromOffset(40,40),
BackgroundTransparency=1,
Position=UDim2.fromOffset(85,208+az.TextPadding),
Size=UDim2.fromOffset(75,24),
Parent=d.UIElements.Main,
},{
af("UICorner",{
CornerRadius=UDim.new(0,8),
}),
aa.NewRoundFrame(8,"SquircleOutline",{
ThemeTag={
ImageColor3="Outline",
},
Size=UDim2.new(1,0,1,0),
ImageTransparency=0.85,
ZIndex=99999,
},{
af("UIGradient",{
Rotation=60,
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0.0,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(1.0,Color3.fromRGB(255,255,255)),
},
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.0,0.1),
NumberSequenceKeypoint.new(0.5,1),
NumberSequenceKeypoint.new(1.0,0.1),
},
}),
}),







m,
})

local p=af("Frame",{
BackgroundColor3=az.Default,
Size=UDim2.fromScale(1,1),
BackgroundTransparency=0,
ZIndex=9,
},{
af("UICorner",{
CornerRadius=UDim.new(0,8),
}),
})

af("ImageLabel",{
Image="http://www.roblox.com/asset/?id=14204231522",
ImageTransparency=0.45,
ScaleType=Enum.ScaleType.Tile,
TileSize=UDim2.fromOffset(40,40),
BackgroundTransparency=1,
Position=UDim2.fromOffset(0,208+az.TextPadding),
Size=UDim2.fromOffset(75,24),
Parent=d.UIElements.Main,
},{
af("UICorner",{
CornerRadius=UDim.new(0,8),
}),







aa.NewRoundFrame(8,"SquircleOutline",{
ThemeTag={
ImageColor3="Outline",
},
Size=UDim2.new(1,0,1,0),
ImageTransparency=0.85,
ZIndex=99999,
},{
af("UIGradient",{
Rotation=60,
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0.0,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(1.0,Color3.fromRGB(255,255,255)),
},
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.0,0.1),
NumberSequenceKeypoint.new(0.5,1),
NumberSequenceKeypoint.new(1.0,0.1),
},
}),
}),
p,
})

local r={}

for u=0,1,0.1 do
table.insert(r,ColorSequenceKeypoint.new(u,Color3.fromHSV(u,1,1)))
end

local u=af("UIGradient",{
Color=ColorSequence.new(r),
Rotation=90,
})

local v=af("Frame",{
Size=UDim2.new(0,14,0,14),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0,0),
Parent=i,


BackgroundColor3=az.Default,
},{
af("UIStroke",{
Thickness=2,
Transparency=0.1,
ThemeTag={
Color="Text",
},
}),
af("UICorner",{
CornerRadius=UDim.new(1,0),
}),
})

local x=af("Frame",{
Size=UDim2.fromOffset(6,192),
Position=UDim2.fromOffset(180,40+az.TextPadding),
Parent=d.UIElements.Main,
},{
af("UICorner",{
CornerRadius=UDim.new(1,0),
}),
u,
i,
})

local function CreateNewInput(z,A)
local B=ar(z,nil,az.UIElements.Inputs,nil,nil,nil,nil,nil,true)

af("TextLabel",{
BackgroundTransparency=1,
TextTransparency=0.4,
TextSize=17,
FontFace=Font.new(aa.Font,Enum.FontWeight.Regular),
AutomaticSize="XY",
ThemeTag={
TextColor3="Placeholder",
},
AnchorPoint=Vector2.new(1,0.5),
Position=UDim2.new(1,-12,0.5,0),
Parent=B.Frame,
Text=z,
})

af("UIScale",{
Parent=B,
Scale=0.85,
})

B.Frame.Frame.TextBox.Text=A
B.Size=UDim2.new(0,150,0,42)

return B
end

local function ToRGB(z)
return{
R=math.floor(z.R*255),
G=math.floor(z.G*255),
B=math.floor(z.B*255),
}
end

local z=CreateNewInput("Hex","#"..az.Default:ToHex())

local A=CreateNewInput("Red",ToRGB(az.Default).R)
local B=CreateNewInput("Green",ToRGB(az.Default).G)
local C=CreateNewInput("Blue",ToRGB(az.Default).B)
local F
if aB then
F=CreateNewInput("Alpha",((1-az.Transparency)*100).."%")
end

local G=af("Frame",{
Size=UDim2.new(0,0,0,40),
AutomaticSize="Y",
Position=UDim2.new(0,0,0,254+az.TextPadding),
BackgroundTransparency=1,
Parent=d.UIElements.Main,
LayoutOrder=4,
},{
af("UIListLayout",{
Padding=UDim.new(0,6),
FillDirection="Horizontal",
HorizontalAlignment="Right",
}),






})

aa.AddSignal(d.UIElements.Main:GetPropertyChangedSignal"AbsoluteSize",function()
az.UIElements.Title.Size=UDim2.new(
0,
d.UIElements.Main.AbsoluteSize.X/av.UIScale-(d.UIPadding*2),
0,
0
)
G.Size=UDim2.new(
0,
d.UIElements.Main.AbsoluteSize.X/av.UIScale-d.UIPadding*2,
0,
40
)
end)

local H={
{
Title="Cancel",
Variant="Secondary",
Callback=function()
av.IsShowed=false
for H,J in next,aA do
J:Disconnect()
end
aA={}
end,
},
{
Title="Apply",

Variant="Primary",
Callback=function()
av.IsShowed=false
for H,J in next,aA do
J:Disconnect()
end
aA={}

ay(Color3.fromHSV(az.Hue,az.Sat,az.Vib),az.Transparency)
end,
},
}

for J,L in next,H do
local M=aq(
L.Title,
L.Icon,
L.Callback,
L.Variant,
G,
d,
true
)
M.Size=UDim2.new(0.5,-3,0,40)
M.AutomaticSize="None"
end

local J,L,M
if aB then
local N=af("Frame",{
Size=UDim2.new(1,0,1,0),
Position=UDim2.fromOffset(0,0),
BackgroundTransparency=1,
})

L=af("ImageLabel",{
Size=UDim2.new(0,14,0,14),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0,0),
ThemeTag={
BackgroundColor3="Text",
},
Parent=N,
},{
af("UIStroke",{
Thickness=2,
Transparency=0.1,
ThemeTag={
Color="Text",
},
}),
af("UICorner",{
CornerRadius=UDim.new(1,0),
}),
})

M=af("Frame",{
Size=UDim2.fromScale(1,1),
},{
af("UIGradient",{
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0,0),
NumberSequenceKeypoint.new(1,1),
},
Rotation=270,
}),
af("UICorner",{
CornerRadius=UDim.new(0,6),
}),
})

J=af("Frame",{
Size=UDim2.fromOffset(6,192),
Position=UDim2.fromOffset(210,40+az.TextPadding),
Parent=d.UIElements.Main,
BackgroundTransparency=1,
},{
af("UICorner",{
CornerRadius=UDim.new(1,0),
}),
af("ImageLabel",{
Image="rbxassetid://14204231522",
ImageTransparency=0.45,
ScaleType=Enum.ScaleType.Tile,
TileSize=UDim2.fromOffset(40,40),
BackgroundTransparency=1,
Size=UDim2.fromScale(1,1),
},{
af("UICorner",{
CornerRadius=UDim.new(1,0),
}),
}),
M,
N,
})
end

function az.Round(N,O,P)
if P==0 then
return math.floor(O)
end
O=tostring(O)
return O:find"%."and tonumber(O:sub(1,O:find"%."+P))or O
end

function az.Update(N,O,P)
if O then
f,g,h=Color3.toHSV(O)
else
f,g,h=az.Hue,az.Sat,az.Vib
end

az.UIElements.SatVibMap.BackgroundColor3=Color3.fromHSV(f,1,1)
l.Position=UDim2.new(g,0,1-h,0)
l.BackgroundColor3=Color3.fromHSV(f,g,h)
p.BackgroundColor3=Color3.fromHSV(f,g,h)
v.BackgroundColor3=Color3.fromHSV(f,1,1)
v.Position=UDim2.new(0.5,0,f,0)

z.Frame.Frame.TextBox.Text="#"..Color3.fromHSV(f,g,h):ToHex()
A.Frame.Frame.TextBox.Text=ToRGB(Color3.fromHSV(f,g,h)).R
B.Frame.Frame.TextBox.Text=ToRGB(Color3.fromHSV(f,g,h)).G
C.Frame.Frame.TextBox.Text=ToRGB(Color3.fromHSV(f,g,h)).B

if P or aB then
p.BackgroundTransparency=az.Transparency or P
M.BackgroundColor3=Color3.fromHSV(f,g,h)
L.BackgroundColor3=Color3.fromHSV(f,g,h)
L.BackgroundTransparency=az.Transparency or P
L.Position=UDim2.new(0.5,0,1-az.Transparency or P,0)
F.Frame.Frame.TextBox.Text=az:Round(
(1-az.Transparency or P)*100,
0
).."%"
end
end

az:Update(az.Default,az.Transparency)

local function GetRGB()
local N=Color3.fromHSV(az.Hue,az.Sat,az.Vib)
return{R=math.floor(N.r*255),G=math.floor(N.g*255),B=math.floor(N.b*255)}
end



local function clamp(N,O,P)
return math.clamp(tonumber(N)or 0,O,P)
end

table.insert(
aA,
aa.AddSignal(z.Frame.Frame.TextBox.FocusLost,function(N)
if N then
local O=z.Frame.Frame.TextBox.Text:gsub("#","")
local P,Q=pcall(Color3.fromHex,O)
if P and typeof(Q)=="Color3"then
az.Hue,az.Sat,az.Vib=Color3.toHSV(Q)
az:Update()
az.Default=Q
end
end
end)
)

local function updateColorFromInput(N,O)
aa.AddSignal(N.Frame.Frame.TextBox.FocusLost,function(P)
if P then
local Q=N.Frame.Frame.TextBox
local R=GetRGB()
local S=clamp(Q.Text,0,255)
Q.Text=tostring(S)

R[O]=S
local T=Color3.fromRGB(R.R,R.G,R.B)
az.Hue,az.Sat,az.Vib=Color3.toHSV(T)
az:Update()
end
end)
end

updateColorFromInput(A,"R")
updateColorFromInput(B,"G")
updateColorFromInput(C,"B")

if aB then
aa.AddSignal(F.Frame.Frame.TextBox.FocusLost,function(N)
if N then
local O=F.Frame.Frame.TextBox
local P=clamp(O.Text,0,100)
O.Text=tostring(P)

az.Transparency=1-P*0.01
az:Update(nil,az.Transparency)
end
end)
end



local function UpdateSatVib(N,O)
local P=N.AbsolutePosition.X
local Q=P+N.AbsoluteSize.X
local R=N.AbsolutePosition.Y
local S=R+N.AbsoluteSize.Y

local T=math.clamp(ap.X,P,Q)
local U=math.clamp(ap.Y,R,S)

O.Sat=(T-P)/(Q-P)
O.Vib=1-((U-R)/(S-R))

O:Update()
end

local function UpdateHue(N,O)
local P=N.AbsolutePosition.Y
local Q=P+N.AbsoluteSize.Y

local R=math.clamp(ap.Y,P,Q)

O.Hue=(R-P)/(Q-P)

O:Update()
end

local function UpdateTransparency(N,O)
local P=N.AbsolutePosition.Y
local Q=P+N.AbsoluteSize.Y

local R=math.clamp(ap.Y,P,Q)

O.Transparency=1-((R-P)/(Q-P))

O:Update()
end

local N=ax.GenerateGUID()

table.insert(
aA,
ak.InputChanged:Connect(function(O)
if
O.UserInputType~=Enum.UserInputType.MouseMovement
and O.UserInputType~=Enum.UserInputType.Touch
then
return
end

if at=="SatVib"then
UpdateSatVib(az.UIElements.SatVibMap,az)
elseif at=="Hue"then
UpdateHue(x,az)
elseif at=="Transparency"then
UpdateTransparency(J,az)
end
end)
)

table.insert(
aA,
az.UIElements.SatVibMap.InputBegan:Connect(function(O)
if
O.UserInputType~=Enum.UserInputType.MouseButton1
and O.UserInputType~=Enum.UserInputType.Touch
then
return
end

if ax.CurrentInput and ax.CurrentInput~=N then
return
end
ax.CurrentInput=N

if at and at~="SatVib"then
return
end

at="SatVib"

UpdateSatVib(az.UIElements.SatVibMap,az)
end)
)

table.insert(
aA,
x.InputBegan:Connect(function(O)
if
O.UserInputType~=Enum.UserInputType.MouseButton1
and O.UserInputType~=Enum.UserInputType.Touch
then
return
end

if ax.CurrentInput and ax.CurrentInput~=N then
return
end
ax.CurrentInput=N

if at and at~="Hue"then
return
end

at="Hue"

UpdateHue(x,az)
end)
)

if J then
table.insert(
aA,
J.InputBegan:Connect(function(O)
if
O.UserInputType~=Enum.UserInputType.MouseButton1
and O.UserInputType~=Enum.UserInputType.Touch
then
return
end

if ax.CurrentInput and ax.CurrentInput~=N then
return
end
ax.CurrentInput=N

if at and at~="Transparency"then
return
end

at="Transparency"

UpdateTransparency(J,az)
end)
)
end

table.insert(
aA,
ak.InputEnded:Connect(function(O)
at=nil

if ax.CurrentInput and ax.CurrentInput~=N then
return
end
ax.CurrentInput=nil
end)
)

return az
end

function as.New(au,av)
local aw={
__type="Colorpicker",
Title=av.Title or"Colorpicker",
Desc=av.Desc or nil,
Locked=av.Locked or false,
LockedTitle=av.LockedTitle,
Default=av.Default or Color3.new(1,1,1),
Callback=av.Callback or function()end,

UIScale=av.UIScale,
Transparency=av.Transparency,
UIElements={},

IsShowed=false,
}

local ax=true



aw.ColorpickerFrame=a.load'C'{
Title=aw.Title,
Desc=aw.Desc,
Parent=av.Parent,
TextOffset=40,
Hover=false,
Tab=av.Tab,
Index=av.Index,
Window=av.Window,
ElementTable=aw,
ParentConfig=av,
Tags=av.Tags,
}

aw.UIElements.Colorpicker=aa.NewRoundFrame(as.UICorner,"Squircle",{
ImageTransparency=0,
Active=true,
ImageColor3=aw.Default,
Parent=aw.ColorpickerFrame.UIElements.Main,
Size=UDim2.new(0,26,0,26),
AnchorPoint=Vector2.new(1,0),
Position=UDim2.new(1,0,0,0),
ZIndex=2,
},{
aa.NewRoundFrame(as.UICorner,"SquircleGlass",{
Size=UDim2.new(1,0,1,0),
ThemeTag={
ImageColor3="Outline",
},
ImageTransparency=0.55,
}),
},true)

function aw.Lock(ay)
aw.Locked=true
ax=false
return aw.ColorpickerFrame:Lock(aw.LockedTitle)
end
function aw.Unlock(ay)
aw.Locked=false
ax=true
return aw.ColorpickerFrame:Unlock()
end

if aw.Locked then
aw:Lock()
end

function aw.Update(ay,az,aA)
aw.UIElements.Colorpicker.ImageTransparency=aA or 0
aw.UIElements.Colorpicker.ImageColor3=az
aw.Default=az
if aA then
aw.Transparency=aA
end
end

function aw.Set(ay,az,aA)
return aw:Update(az,aA)
end

aa.AddSignal(aw.UIElements.Colorpicker.MouseButton1Click,function()
if ax and not aw.IsShowed then
aw.IsShowed=true

as:Colorpicker(aw,av.Window,av.WindUI,function(ay,az)
aw:Update(ay,az)
aw.Default=ay
aw.Transparency=az
aa.SafeCallback(aw.Callback,ay,az)
end).ColorpickerFrame
:Open()
end
end)

return aw.__type,aw
end

return as end function a.T()

local aa=a.load'd'
local af=aa.New
local ai=aa.Tween

local ak={}

function ak.New(al,am)
local an={
__type="Section",
Title=am.Title or"Section",
Desc=am.Desc,
Icon=am.Icon,
IconThemed=am.IconThemed,
TextXAlignment=am.TextXAlignment or"Left",
TextSize=am.TextSize or 19,
DescTextSize=am.DescTextSize or 16,
Box=am.Box or false,
BoxBorder=am.BoxBorder or false,
FontWeight=am.FontWeight or Enum.FontWeight.SemiBold,
DescFontWeight=am.DescFontWeight or Enum.FontWeight.Medium,
TextTransparency=am.TextTransparency or 0.05,
DescTextTransparency=am.DescTextTransparency or 0.4,
Opened=am.Opened or false,
UIElements={},

HeaderSize=48,
IconSize=20,
Padding=10,

Elements={},

Expandable=false,
}

local ao

function an.SetIcon(ap,aq)
an.Icon=aq or nil
if ao then
ao:Destroy()
end
if aq then
ao=aa.Image(
aq,
aq..":"..an.Title,
0,
am.Window.Folder,
an.__type,
true,
an.IconThemed,
"SectionIcon"
)
ao.Size=UDim2.new(0,an.IconSize,0,an.IconSize)
end
end

local ap=af("Frame",{
Size=UDim2.new(0,an.IconSize,0,an.IconSize),
BackgroundTransparency=1,
Visible=false,
},{
af("ImageLabel",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
Image=aa.Icon"chevron-down"[1],
ImageRectSize=aa.Icon"chevron-down"[2].ImageRectSize,
ImageRectOffset=aa.Icon"chevron-down"[2].ImageRectPosition,
ThemeTag={
ImageTransparency="SectionExpandIconTransparency",
ImageColor3="SectionExpandIcon",
},
}),
})

if an.Icon then
an:SetIcon(an.Icon)
end

local aq=af("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
},{
af("UIListLayout",{
FillDirection="Vertical",
HorizontalAlignment=an.TextXAlignment,
VerticalAlignment="Center",
Padding=UDim.new(0,4),
}),
})

local ar,as

local function createTitle(at,au)
return af("TextLabel",{
BackgroundTransparency=1,
TextXAlignment=an.TextXAlignment,
AutomaticSize="Y",
TextSize=au=="Title"and an.TextSize or an.DescTextSize,
TextTransparency=au=="Title"and an.TextTransparency or an.DescTextTransparency,
ThemeTag={
TextColor3="Text",
},
FontFace=Font.new(aa.Font,au=="Title"and an.FontWeight or an.DescFontWeight),


Text=at,
Size=UDim2.new(1,0,0,0),
TextWrapped=true,
Parent=aq,
})
end

ar=createTitle(an.Title,"Title")
if an.Desc then
as=createTitle(an.Desc,"Desc")
end

local function UpdateTitleSize()
local at=0
if ao then
at=at-(an.IconSize+8)
end
if ap.Visible then
at=at-(an.IconSize+8)
end
aq.Size=UDim2.new(1,at,0,0)
end

local at=aa.NewRoundFrame(am.Window.ElementConfig.UICorner,"Squircle",{
Size=UDim2.new(1,0,0,0),
BackgroundTransparency=1,
Parent=am.Parent,

AutomaticSize="Y",
ThemeTag={
ImageTransparency=an.Box and"SectionBoxBackgroundTransparency"or nil,
ImageColor3="SectionBoxBackground",
},
ImageTransparency=not an.Box and 1 or nil,
},{
aa.NewRoundFrame(am.Window.ElementConfig.UICorner-1,"SquircleOutline",{
Size=UDim2.new(1,0,1,0),



ThemeTag={

ImageColor3="SectionBoxBorder",
},
ImageTransparency=an.Box and an.BoxBorder and 0.92 or 1,
Name="Outline",
ClipsDescendants=true,
},{
af("TextButton",{
Size=UDim2.new(1,0,0,an.Expandable and 0 or(not as and an.HeaderSize or 0)),
BackgroundTransparency=1,
AutomaticSize=(not an.Expandable or as)and"Y"or nil,
Text="",
Name="Top",
},{
an.Box and af("UIPadding",{
PaddingTop=UDim.new(
0,
am.Window.ElementConfig.UIPadding+(am.Window.NewElements and 4 or 0)
),
PaddingLeft=UDim.new(
0,
am.Window.ElementConfig.UIPadding+(am.Window.NewElements and 4 or 0)
),
PaddingRight=UDim.new(
0,
am.Window.ElementConfig.UIPadding+(am.Window.NewElements and 4 or 0)
),
PaddingBottom=UDim.new(
0,
am.Window.ElementConfig.UIPadding+(am.Window.NewElements and 4 or 0)
),
})or nil,
ao,
aq,
af("UIListLayout",{
Padding=UDim.new(0,8),
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment="Left",
}),
ap,
}),
af("Frame",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
Name="Content",
Visible=false,
Position=UDim2.new(0,0,0,an.HeaderSize+10),
},{
an.Box and af("UIPadding",{
PaddingLeft=UDim.new(0,am.Window.ElementConfig.UIPadding/1.5),
PaddingRight=UDim.new(0,am.Window.ElementConfig.UIPadding/1.5),
PaddingBottom=UDim.new(0,am.Window.ElementConfig.UIPadding/1.5),
})or nil,
af("UIListLayout",{
FillDirection="Vertical",
Padding=UDim.new(0,am.Tab.Gap),
VerticalAlignment="Top",
}),
}),
}),
})





an.ElementFrame=at

at.Outline.Top:GetPropertyChangedSignal"AbsoluteSize":Connect(function()
at.Outline.Content.Position=UDim2.new(0,0,0,(at.Outline.Top.AbsoluteSize.Y/am.UIScale)+10)

if an.Opened then
an:Open(true)
else
an.Close(true)
end
end)

local au=am.ElementsModule

au.Load(an,at.Outline.Content,au.Elements,am.Window,am.WindUI,function()
if not an.Expandable then
an.Expandable=true
ap.Visible=true
UpdateTitleSize()
end
end,au,am.UIScale,am.Tab)

UpdateTitleSize()

function an.SetTitle(av,aw)
an.Title=aw
ar.Text=aw
end

function an.SetDesc(av,aw)
an.Desc=aw
if not as then
as=createTitle(aw,"Desc")
end
as.Text=aw
end

function an.Destroy(av)
for aw,ax in next,an.Elements do
ax:Destroy()
end








at:Destroy()
end

function an.Open(av,aw)
if an.Expandable then
an.Opened=true
if aw then
at.Size=UDim2.new(
at.Size.X.Scale,
at.Size.X.Offset,
0,
at.Outline.Top.AbsoluteSize.Y/am.UIScale
+(at.Outline.Content.AbsoluteSize.Y/am.UIScale)
+10
)
ap.ImageLabel.Rotation=180
else
ai(at,0.33,{
Size=UDim2.new(
at.Size.X.Scale,
at.Size.X.Offset,
0,
at.Outline.Top.AbsoluteSize.Y/am.UIScale
+(at.Outline.Content.AbsoluteSize.Y/am.UIScale)
+10
),
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()

ai(
ap.ImageLabel,
0.2,
{Rotation=180},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
end
end
end
function an.Close(av,aw)
if an.Expandable then
an.Opened=false
if aw then
at.Size=UDim2.new(
at.Size.X.Scale,
at.Size.X.Offset,
0,
(at.Outline.Top.AbsoluteSize.Y/am.UIScale)
)
ap.ImageLabel.Rotation=0
else
ai(at,0.26,{
Size=UDim2.new(
at.Size.X.Scale,
at.Size.X.Offset,
0,
(at.Outline.Top.AbsoluteSize.Y/am.UIScale)
),
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
ai(
ap.ImageLabel,
0.2,
{Rotation=0},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
end
end
end

aa.AddSignal(at.Outline.Top.MouseButton1Click,function()
if an.Expandable then
if an.Opened then
an:Close()
else
an:Open()
end
end
end)

aa.AddSignal(at.Outline.Content.UIListLayout:GetPropertyChangedSignal"AbsoluteContentSize",function()
if an.Opened then
an:Open(true)
else
an:Close(true)
end
end)

task.defer(function()
if an.Expandable then








at.Size=
UDim2.new(at.Size.X.Scale,at.Size.X.Offset,0,at.Outline.Top.AbsoluteSize.Y/am.UIScale)
at.AutomaticSize="None"
at.Outline.Top.Size=UDim2.new(1,0,0,(not as and an.HeaderSize or 0))
at.Outline.Top.AutomaticSize=(not an.Expandable or as)and"Y"or"None"
at.Outline.Content.Visible=true
end
if an.Opened then
an:Open()
else
an:Close(true)
end
end)

return an.__type,an
end

return ak end function a.U()

local aa=a.load'd'
local af=aa.New

local ai={}

function ai.New(ak,al)
local am=af("Frame",{
Parent=al.Parent,
Size=not table.find({"Group","HStack"},al.ParentType)and UDim2.new(1,-7,0,7*(al.Columns or 1))or UDim2.new(0,7*(al.Columns or 1),0,0),
BackgroundTransparency=1,
})

return"Space",{__type="Space",ElementFrame=am}
end

return ai end function a.V()
local aa=a.load'd'
local af=aa.New

local ai={}

local function ParseAspectRatio(ak)
if type(ak)=="string"then
local al,am=ak:match"(%d+):(%d+)"
if al and am then
return tonumber(al)/tonumber(am)
end
elseif type(ak)=="number"then
return ak
end
return nil
end

function ai.New(ak,al)
local am={
__type="Image",
Image=al.Image or"",
AspectRatio=al.AspectRatio or"16:9",
Radius=al.Radius or al.Window.ElementConfig.UICorner,
}
local an=aa.Image(
am.Image,
am.Image,
am.Radius,
al.Window.Folder,
"Image",
false
)
if an and an.Parent then
an.Parent=al.Parent
an.Size=UDim2.new(1,0,0,0)
an.BackgroundTransparency=1












local ao=ParseAspectRatio(am.AspectRatio)
local ap

if ao then
ap=af("UIAspectRatioConstraint",{
Parent=an,
AspectRatio=ao,
AspectType="ScaleWithParentSize",
DominantAxis="Width"
})
end

function am.Destroy(aq)
an:Destroy()
end
end

return am.__type,am
end

return ai end function a.W()
local aa=a.load'd'
local af=aa.New

local ai={}

function ai.New(ak,al)
local am={
__type="Group",
Elements={},
ElementFrame=nil,
}

local an=af("Frame",{
Size=UDim2.new(1,0,0,0),
BackgroundTransparency=1,
AutomaticSize="Y",
Parent=al.Parent,
},{
af("UIListLayout",{
FillDirection="Horizontal",
HorizontalAlignment="Center",

Padding=UDim.new(0,al.Tab and al.Tab.Gap or(al.Window.NewElements and 1 or 6))
}),
})

am.ElementFrame=an

local ao=al.ElementsModule
ao.Load(
am,
an,
ao.Elements,
al.Window,
al.WindUI,
function(ap,aq)
local ar=al.Tab and al.Tab.Gap or(al.Window.NewElements and 1 or 6)

local as={}
local at=0

for au,av in next,aq do
if av.__type=="Space"then
at=at+(av.ElementFrame.Size.X.Offset or 6)
elseif av.__type=="Divider"then
at=at+(av.ElementFrame.Size.X.Offset or 1)
else
table.insert(as,av)
end
end

local au=#as
if au==0 then return end

local av=1/au

local aw=ar*(au-1)

local ax=-(aw+at)

local ay=math.floor(ax/au)
local az=ax-(ay*au)

for aA,aB in next,as do
local b=ay
if aA<=math.abs(az)then
b=b-1
end

if aB.ElementFrame then
aB.ElementFrame.Size=UDim2.new(av,b,1,0)
end
end
end,
ao,
al.UIScale,
al.Tab
)



return am.__type,am
end

return ai end function a.X()
local aa=a.load'd'
local af=aa.New

local ai={}

function ai.New(ak,al)
local am={
__type="HStack",
AutoSpace=al.AutoSpace or false,
Elements={},
ElementFrame=nil,
}

local an=af("Frame",{
Size=UDim2.new(1,0,0,0),
BackgroundTransparency=1,
AutomaticSize="Y",
Parent=al.Parent,
},{
af("UIListLayout",{
FillDirection="Horizontal",
HorizontalAlignment="Center",

Padding=UDim.new(0,al.Tab and al.Tab.Gap or(al.Window.NewElements and 1 or 6)),
}),
})

am.ElementFrame=an

local ao=al.ElementsModule
ao.Load(
am,
an,
ao.Elements,
al.Window,
al.WindUI,
function(ap,aq)
local ar=al.Tab and al.Tab.Gap or(al.Window.NewElements and 1 or 6)

local as={}
local at=0

for au,av in next,aq do
if av.__type=="Space"then
at=at+(av.ElementFrame.Size.X.Offset or 6)
elseif av.__type=="Divider"then
at=at+(av.ElementFrame.Size.X.Offset or 1)
else
table.insert(as,av)
end
end

local au=#as
if au==0 then
return
end

local av=1/au

local aw=ar*(au-1)

local ax=-(aw+at)

local ay=math.floor(ax/au)
local az=ax-(ay*au)

for aA,aB in next,as do
local b=ay
if aA<=math.abs(az)then
b=b-1
end

if aB.ElementFrame then
aB.ElementFrame.Size=UDim2.new(av,b,1,0)
end
end
end,
ao,
al.UIScale,
al.Tab
)

if am.AutoSpace then
for ap in next,ao.Elements do
if ap~="Space"and ap~="Divider"then
local aq=am[ap]
am[ap]=function(ar,as)
if#am.Elements>0 then
am:Space()
end
return aq(ar,as)
end
end
end
end

return am.__type,am
end

return ai end function a.Y()

local aa=a.load'd'
local af=aa.New

local ai={}

function ai.New(ak,al)
local am={
__type="VStack",
Elements={},
ElementFrame=nil,
}

local an=af("Frame",{
Size=UDim2.new(1,0,0,0),
BackgroundTransparency=1,
AutomaticSize="Y",
Parent=al.Parent,
},{
af("UIListLayout",{
FillDirection="Vertical",
HorizontalAlignment="Center",

Padding=UDim.new(0,al.Tab and al.Tab.Gap or(al.Window.NewElements and 1 or 6))
}),
})

am.ElementFrame=an

local ao=al.ElementsModule
ao.Load(
am,
an,
ao.Elements,
al.Window,
al.WindUI,







































nil,
ao,
al.UIScale,
al.Tab
)



return am.__type,am
end

return ai end function a.Z()
local aa=(cloneref or clonereference or function(aa)
return aa
end)

local af=aa(game:GetService"UserInputService")

local ai=a.load'd'
local ak=ai.New

local al={}














function al.New(am,an:ConfigType__DARKLUA_TYPE_a)
local ao={
__type="Viewport",
Object=an.Object,
Camera=an.Camera or Instance.new"Camera",
Interactive=an.Interactive or false,
Height=an.Height or 200,
Focused=an.Focused~=false,
}

local ap=false
local aq=false
local ar,as=0

local at=ai.NewRoundFrame(an.Window.ElementConfig.UICorner,"Squircle",{
Size=UDim2.new(1,0,0,ao.Height),
Parent=an.Parent,
ThemeTag={
ImageColor3="ViewportBackground",
ImageTransparency="ViewportBackgroundTransparency",
},
},{
ak("CanvasGroup",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
},{
ak("UICorner",{
CornerRadius=UDim.new(0,an.Window.ElementConfig.UICorner),
}),
ak("ViewportFrame",{
Name="Viewport",
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
CurrentCamera=ao.Camera,
Active=ao.Interactive,
},{
ao.Object,
}),
}),
})

local function IsTouchInsideViewport(au)
local av=at.CanvasGroup.Viewport.AbsolutePosition
local aw=at.CanvasGroup.Viewport.AbsoluteSize

return au.X>=av.X
and au.X<=av.X+aw.X
and au.Y>=av.Y
and au.Y<=av.Y+aw.Y
end

local au=an.WindUI.GenerateGUID()

ai.AddSignal(at.CanvasGroup.Viewport.MouseEnter,function()
if ao.Interactive then
an.Tab.UIElements.ContainerFrame.ScrollingEnabled=false
end
end)

ai.AddSignal(at.CanvasGroup.Viewport.InputEnded,function(av)
if
av.UserInputType==Enum.UserInputType.MouseMovement
or av.UserInputType==Enum.UserInputType.Touch
then
an.Tab.UIElements.ContainerFrame.ScrollingEnabled=true
end
end)

ai.AddSignal(at.CanvasGroup.Viewport.InputBegan,function(av)
if ao.Interactive then
if
(av.UserInputType==Enum.UserInputType.MouseButton1)
or(av.UserInputType==Enum.UserInputType.Touch and not aq)
then
if an.WindUI.CurrentInput and an.WindUI.CurrentInput~=au then
return
end

an.WindUI.CurrentInput=au

ap=true
as=av.Position
end
end
end)

ai.AddSignal(af.InputEnded,function(av)
if ao.Interactive then
if
av.UserInputType==Enum.UserInputType.MouseButton1
or av.UserInputType==Enum.UserInputType.Touch
then
if an.WindUI.CurrentInput and an.WindUI.CurrentInput~=au then
return
end

an.WindUI.CurrentInput=nil

ap=false
end
end
end)

ai.AddSignal(af.InputChanged,function(av)
if ao.Interactive and ap and not aq then
if
av.UserInputType==Enum.UserInputType.MouseMovement
or av.UserInputType==Enum.UserInputType.Touch
then
local aw=av.Position-as
as=av.Position

local ax=ao.Object:GetPivot().Position
local ay=ao.Camera

local az=CFrame.fromAxisAngle(Vector3.new(0,1,0),-aw.X*0.02)
ay.CFrame=CFrame.new(ax)*az*CFrame.new(-ax)*ay.CFrame

local aA=CFrame.fromAxisAngle(ay.CFrame.RightVector,-aw.Y*0.02)
local aB=CFrame.new(ax)*aA*CFrame.new(-ax)*ay.CFrame

if aB.UpVector.Y>0.1 then
ay.CFrame=aB
end
end
end
end)

ai.AddSignal(at.CanvasGroup.Viewport.InputChanged,function(av)
if ao.Interactive then
if av.UserInputType==Enum.UserInputType.MouseWheel then
local aw=av.Position.Z*2
ao.Camera.CFrame+=ao.Camera.CFrame.LookVector*aw
end
end
end)

ai.AddSignal(af.TouchPinch,function(av,aw,ax,ay)
if not IsTouchInsideViewport(av[1])or not IsTouchInsideViewport(av[2])then
return
end
if ao.Interactive then
if ay==Enum.UserInputState.Begin then
aq=true
ap=false
ar=(av[1]-av[2]).Magnitude
elseif ay==Enum.UserInputState.Change then
if aq then
local az=(av[1]-av[2]).Magnitude
local aA=(az-ar)*0.03
ar=az
ao.Camera.CFrame+=ao.Camera.CFrame.LookVector*aA
end
elseif ay==Enum.UserInputState.End or ay==Enum.UserInputState.Cancel then
aq=false
end
end
end)

local function FocusCamera()
local av=ao.Object:IsA"BasePart"and ao.Object.Size
or select(2,ao.Object:GetBoundingBox(0))
local aw=math.max(av.X,av.Y,av.Z)
local ax=aw*2
local ay=ao.Object:GetPivot().Position

ao.Camera.CFrame=
CFrame.new(ay+Vector3.new(0,aw/2,ax),ay)
end

if ao.Focused then
FocusCamera()
end

function ao.SetObject(av,aw,ax)
if ax then
aw=aw:Clone()
end
if ao.Object then
ao.Object:Destroy()
end

ao.Object=aw
ao.Object.Parent=at.CanvasGroup.Viewport
end

function ao.SetHeight(av,aw)
at.Size=UDim2.new(1,0,0,aw)
end

function ao.Focus(av)
if ao.Object then
FocusCamera()
end
end

function ao.SetCamera(av,aw)
ao.Camera=aw
at.CanvasGroup.Viewport.CurrentCamera=aw
end

function ao.SetInteractive(av,aw)
ao.Interactive=aw
at.CanvasGroup.Viewport.Active=aw
end

ao.Main=at

return ao.__type,ao
end

return al end function a._()

return{
Elements={
Paragraph=a.load'D',
Button=a.load'E',
Toggle=a.load'H',
Slider=a.load'I',
ProgressBar=a.load'J',
Keybind=a.load'K',
Input=a.load'L',
Dropdown=a.load'O',
Code=a.load'R',
Colorpicker=a.load'S',
Section=a.load'T',
Divider=a.load'M',
Space=a.load'U',
Image=a.load'V',
Group=a.load'W',
HStack=a.load'X',
VStack=a.load'Y',
Viewport=a.load'Z',

},
Load=function(aa,af,ai,ak,al,am,an,ao,ap)
for aq,ar in next,ai do
aa[aq]=function(as,at)
at=at or{}
at.Tab=ap or aa
at.ParentType=aa.__type
at.ParentTable=aa
at.Index=#aa.Elements+1
at.GlobalIndex=#ak.AllElements+1
at.Parent=af
at.Window=ak
at.WindUI=al
at.UIScale=ao
at.ElementsModule=an local

au, av=ar:New(at)

if at.Flag and typeof(at.Flag)=="string"then
if ak.CurrentConfig then
ak.CurrentConfig:Register(at.Flag,av)

if ak.PendingConfigData and ak.PendingConfigData[at.Flag]then
local aw=ak.PendingConfigData[at.Flag]

local ax=ak.ConfigManager
if ax.Parser[aw.__type]then
task.defer(function()
local ay,az=pcall(function()
ax.Parser[aw.__type].Load(av,aw)
end)

if ay then
ak.PendingConfigData[at.Flag]=nil
else
warn(
"[ WindUI ] Failed to apply pending config for '"
..at.Flag
.."': "
..tostring(az)
)
end
end)
end
end
else
ak.PendingFlags=ak.PendingFlags or{}
ak.PendingFlags[at.Flag]=av
end
end

local aw
for ax,ay in next,av do
if typeof(ay)=="table"and ax~="ElementFrame"and ax:match"Frame$"then
aw=ay
break
end
end

if aw then
av.ElementFrame=aw.UIElements.Main
function av.SetTitle(ax,ay)
return aw.SetTitle and aw:SetTitle(ay)
end
function av.SetDesc(ax,ay)
return aw.SetDesc and aw:SetDesc(ay)
end
function av.SetImage(ax,ay,az)
return aw.SetImage and aw:SetImage(ay,az)
end
function av.SetThumbnail(ax,ay,az)
return aw.SetThumbnail and aw:SetThumbnail(ay,az)
end
function av.Highlight(ax)
aw:Highlight()
end
function av.Destroy(ax)
aw:Destroy()

table.remove(ak.AllElements,at.GlobalIndex)
table.remove(aa.Elements,at.Index)
table.remove(ap.Elements,at.Index)
aa:UpdateAllElementShapes(aa)
end
end

ak.AllElements[at.Index]=av
aa.Elements[at.Index]=av
if ap then
ap.Elements[at.Index]=av
end

if ak.NewElements then
aa:UpdateAllElementShapes(aa)
end

if am then
am(av,aa.Elements)
end
return av
end
end
function aa.UpdateAllElementShapes(aq,ar)
for as,at in next,ar.Elements do
local au
for av,aw in pairs(at)do
if typeof(aw)=="table"and av:match"Frame$"then
au=aw
break
end
end

if not au and at.UpdateShape then
au=at
end

if au then

au.Index=as
if au.UpdateShape then

au.UpdateShape(ar)
end
end
end
end
end,
}end function a.aa()

local aa=(cloneref or clonereference or function(aa)
return aa
end)

local af=game:GetService"Players"

aa(game:GetService"UserInputService")
local ai=af.LocalPlayer:GetMouse()

local ak=a.load'd'
local al=ak.New

local am=a.load'B'.New
local an=a.load'x'.New



local ao={


Tabs={},
Containers={},
SelectedTab=nil,
TabCount=0,
ToolTipParent=nil,
TabHighlight=nil,

OnChangeFunc=function(ao)end,
}

function ao.Init(ap,aq,ar,as)
Window=ap
WindUI=aq
ao.ToolTipParent=ar
ao.TabHighlight=as
return ao
end

function ao.New(ap,aq)
local ar={
__type="Tab",
Title=ap.Title or"Tab",
Desc=ap.Desc,
Icon=ap.Icon,
IconColor=ap.IconColor,
IconShape=ap.IconShape,
IconThemed=ap.IconThemed,
Locked=ap.Locked,
ShowTabTitle=ap.ShowTabTitle,
TabTitleAlign=ap.TabTitleAlign or"Left",
CustomEmptyPage=(ap.CustomEmptyPage and next(ap.CustomEmptyPage)~=nil)and ap.CustomEmptyPage
or{Icon="lucide:frown",IconSize=48,Title="This tab is Empty",Desc=nil},
Border=ap.Border,
Selected=false,
Index=nil,
Parent=ap.Parent,
UIElements={},
Elements={},
ContainerFrame=nil,
UICorner=Window.UICorner-(Window.UIPadding/2),

Gap=Window.NewElements and 1 or 6,

TabPaddingX=4+(Window.UIPadding/2),
TabPaddingY=3+(Window.UIPadding/2),
TitlePaddingY=0,
}









if ar.IconShape then
ar.TabPaddingX=2+(Window.UIPadding/4)
ar.TabPaddingY=2+(Window.UIPadding/4)
ar.TitlePaddingY=2+(Window.UIPadding/4)
end

ao.TabCount=ao.TabCount+1

local as=ao.TabCount
ar.Index=as

ar.UIElements.Main=ak.NewRoundFrame(ar.UICorner,"Squircle",{
BackgroundTransparency=1,
Size=UDim2.new(1,-7,0,0),
AutomaticSize="Y",
Parent=ap.Parent,
ThemeTag={
ImageColor3="TabBackground",
},
ImageTransparency=1,
},{
ak.NewRoundFrame(ar.UICorner-1,"Glass-1.4",{
Size=UDim2.new(1,1,1,1),
ThemeTag={
ImageColor3="TabBorder",
},
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
ImageTransparency=1,
Name="Outline",
},{













}),
ak.NewRoundFrame(ar.UICorner,"Squircle",{
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
ThemeTag={
ImageColor3="Text",
},
ImageTransparency=1,
Name="Frame",
},{
al("UIListLayout",{
SortOrder="LayoutOrder",
Padding=UDim.new(0,2+(Window.UIPadding/2)),
FillDirection="Horizontal",
VerticalAlignment="Center",
}),
al("TextLabel",{
Text=ar.Title,
ThemeTag={
TextColor3="TabTitle",
},
TextTransparency=not ar.Locked and 0.4 or 0.7,
TextSize=15,
Size=UDim2.new(1,0,0,0),
FontFace=Font.new(ak.Font,Enum.FontWeight.Medium),
TextWrapped=true,
RichText=true,
AutomaticSize="Y",
LayoutOrder=2,
TextXAlignment="Left",
BackgroundTransparency=1,
},{
al("UIPadding",{
PaddingTop=UDim.new(0,ar.TitlePaddingY),


PaddingBottom=UDim.new(0,ar.TitlePaddingY),
}),
}),
al("UIPadding",{
PaddingTop=UDim.new(0,ar.TabPaddingY),
PaddingLeft=UDim.new(0,ar.TabPaddingX),
PaddingRight=UDim.new(0,ar.TabPaddingX),
PaddingBottom=UDim.new(0,ar.TabPaddingY),
}),
}),
},true)

local at=0
local au
local av

if ar.Icon then
au=ak.Image(
ar.Icon,
ar.Icon..":"..ar.Title,
0,
Window.Folder,
ar.__type,
ar.IconColor and false or true,
ar.IconThemed,
"TabIcon"
)
au.Size=UDim2.new(0,16,0,16)
if ar.IconColor then
au.ImageLabel.ImageColor3=ar.IconColor
end
if not ar.IconShape then
au.Parent=ar.UIElements.Main.Frame
ar.UIElements.Icon=au
au.ImageLabel.ImageTransparency=not ar.Locked and 0 or 0.7
at=-18-(Window.UIPadding/2)
ar.UIElements.Main.Frame.TextLabel.Size=UDim2.new(1,at,0,0)
elseif ar.IconColor then
ak.NewRoundFrame(
ar.IconShape~="Circle"and(ar.UICorner+5-(2+(Window.UIPadding/4)))or 9999,
"Squircle",
{
Size=UDim2.new(0,26,0,26),
ImageColor3=ar.IconColor,
Parent=ar.UIElements.Main.Frame,
},
{
au,
ak.NewRoundFrame(
ar.IconShape~="Circle"and(ar.UICorner+5-(2+(Window.UIPadding/4)))or 9999,
"Glass-1.4",
{
Size=UDim2.new(1,0,1,0),
ThemeTag={
ImageColor3="White",
},
ImageTransparency=0,
Name="Outline",
},
{













}
),
}
)
au.AnchorPoint=Vector2.new(0.5,0.5)
au.Position=UDim2.new(0.5,0,0.5,0)
au.ImageLabel.ImageTransparency=0
au.ImageLabel.ImageColor3=ak.GetTextColorForHSB(ar.IconColor,0.68)
at=-28-(Window.UIPadding/2)
ar.UIElements.Main.Frame.TextLabel.Size=UDim2.new(1,at,0,0)
end

av=
ak.Image(ar.Icon,ar.Icon..":"..ar.Title,0,Window.Folder,ar.__type,true,ar.IconThemed)
av.Size=UDim2.new(0,16,0,16)
av.ImageLabel.ImageTransparency=not ar.Locked and 0 or 0.7
at=-30




end

ar.UIElements.ContainerFrame=al("ScrollingFrame",{
Size=UDim2.new(1,0,1,ar.ShowTabTitle and-((Window.UIPadding*2.4)+12)or 0),
BackgroundTransparency=1,
ScrollBarThickness=0,
ElasticBehavior="Never",
CanvasSize=UDim2.new(0,0,0,0),
AnchorPoint=Vector2.new(0,1),
Position=UDim2.new(0,0,1,0),
AutomaticCanvasSize="Y",

ScrollingDirection="Y",
},{
al("UIPadding",{
PaddingTop=UDim.new(0,not Window.HidePanelBackground and 20 or 10),
PaddingLeft=UDim.new(0,not Window.HidePanelBackground and 20 or 10),
PaddingRight=UDim.new(0,not Window.HidePanelBackground and 20 or 10),
PaddingBottom=UDim.new(0,not Window.HidePanelBackground and 20 or 10),
}),
al("UIListLayout",{
SortOrder="LayoutOrder",
Padding=UDim.new(0,ar.Gap),
HorizontalAlignment="Center",
}),
})





ar.UIElements.ContainerFrameCanvas=al("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
Visible=false,
Parent=Window.UIElements.MainBar,
ZIndex=5,
},{
ar.UIElements.ContainerFrame,
al("Frame",{
Size=UDim2.new(1,-14,1,-14),
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundTransparency=1,
Name="ScrollSliderHolder",
}),
al("Frame",{
Size=UDim2.new(1,0,0,((Window.UIPadding*2.4)+12)),
BackgroundTransparency=1,
Visible=ar.ShowTabTitle or false,
Name="TabTitle",
},{
av,
al("TextLabel",{
Text=ar.Title,
ThemeTag={
TextColor3="Text",
},
TextSize=20,
TextTransparency=0.1,
Size=UDim2.new(0,0,1,0),
FontFace=Font.new(ak.Font,Enum.FontWeight.SemiBold),

RichText=true,
LayoutOrder=2,
TextXAlignment="Left",
BackgroundTransparency=1,
AutomaticSize="X",
}),
al("UIPadding",{
PaddingTop=UDim.new(0,20),
PaddingLeft=UDim.new(0,20),
PaddingRight=UDim.new(0,20),
PaddingBottom=UDim.new(0,20),
}),
al("UIListLayout",{
SortOrder="LayoutOrder",
Padding=UDim.new(0,10),
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment=ar.TabTitleAlign,
}),
}),
al("Frame",{
Size=UDim2.new(1,0,0,1),
BackgroundTransparency=0.9,
ThemeTag={
BackgroundColor3="Text",
},
Position=UDim2.new(0,0,0,((Window.UIPadding*2.4)+12)),
Visible=ar.ShowTabTitle or false,
}),
})

ao.Containers[as]=ar.UIElements.ContainerFrameCanvas
ao.Tabs[as]=ar

ar.ContainerFrame=ar.UIElements.ContainerFrameCanvas

ak.AddSignal(ar.UIElements.Main.MouseButton1Click,function()
if not ar.Locked then
ao:SelectTab(as)
end
end)

if Window.ScrollBarEnabled then
an(
ar.UIElements.ContainerFrame,
ar.UIElements.ContainerFrameCanvas.ScrollSliderHolder,
Window,
4,
WindUI
)
end

local aw
local ax
local ay
local az=false


if ar.Desc then
ak.AddSignal(ar.UIElements.Main.InputBegan,function()
az=true
ax=task.spawn(function()
task.wait(0.35)
if az and not aw then
aw=am(ar.Desc,ao.ToolTipParent,true)
aw.Container.AnchorPoint=Vector2.new(0.5,0.5)

local function updatePosition()
if aw then
aw.Container.Position=UDim2.new(0,ai.X,0,ai.Y-4)
end
end

updatePosition()
ay=ai.Move:Connect(updatePosition)
aw:Open()
end
end)
end)
end

ak.AddSignal(ar.UIElements.Main.MouseEnter,function()
if not ar.Locked then
ak.SetThemeTag(ar.UIElements.Main.Frame,{
ImageTransparency="TabBackgroundHoverTransparency",
ImageColor3="TabBackgroundHover",
},0.1)
end
end)
ak.AddSignal(ar.UIElements.Main.InputEnded,function()
if ar.Desc then
az=false
if ax then
task.cancel(ax)
ax=nil
end
if ay then
ay:Disconnect()
ay=nil
end
if aw then
aw:Close()
aw=nil
end
end

if not ar.Locked then
ak.SetThemeTag(ar.UIElements.Main.Frame,{
ImageTransparency="TabBorderTransparency",
},0.1)
end
end)

function ar.ScrollToTheElement(aA,aB)
ar.UIElements.ContainerFrame.ScrollingEnabled=false

ak.Tween(ar.UIElements.ContainerFrame,0.45,{
CanvasPosition=Vector2.new(
0,
ar.Elements[aB].ElementFrame.AbsolutePosition.Y
-ar.UIElements.ContainerFrame.AbsolutePosition.Y
-ar.UIElements.ContainerFrame.UIPadding.PaddingTop.Offset
),
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()

task.spawn(function()
task.wait(0.48)

if ar.Elements[aB].Highlight then
ar.Elements[aB]:Highlight()
end
ar.UIElements.ContainerFrame.ScrollingEnabled=true
end)

return ar
end



local aA=a.load'_'

aA.Load(
ar,
ar.UIElements.ContainerFrame,
aA.Elements,
Window,
WindUI,
nil,
aA,
aq,
ar
)

function ar.LockAll(aB)

for b,d in next,Window.AllElements do
if d.Tab and d.Tab.Index and d.Tab.Index==ar.Index and d.Lock then
d:Lock()
end
end
end
function ar.UnlockAll(aB)
for b,d in next,Window.AllElements do
if d.Tab and d.Tab.Index and d.Tab.Index==ar.Index and d.Unlock then
d:Unlock()
end
end
end
function ar.GetLocked(aB)
local b={}

for d,f in next,Window.AllElements do
if f.Tab and f.Tab.Index and f.Tab.Index==ar.Index and f.Locked==true then
table.insert(b,f)
end
end

return b
end
function ar.GetUnlocked(aB)
local b={}

for d,f in next,Window.AllElements do
if f.Tab and f.Tab.Index and f.Tab.Index==ar.Index and f.Locked==false then
table.insert(b,f)
end
end

return b
end

function ar.Select(aB)
return ao:SelectTab(ar.Index)
end

task.spawn(function()
local aB
if ar.CustomEmptyPage.Icon then
aB=
ak.Image(ar.CustomEmptyPage.Icon,ar.CustomEmptyPage.Icon,0,"Temp","EmptyPage",true)
aB.Size=
UDim2.fromOffset(ar.CustomEmptyPage.IconSize or 48,ar.CustomEmptyPage.IconSize or 48)
end

local b=al("Frame",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,1,-Window.UIElements.Main.Main.Topbar.AbsoluteSize.Y),
Parent=ar.UIElements.ContainerFrame,
},{
al("UIListLayout",{
Padding=UDim.new(0,8),
SortOrder="LayoutOrder",
VerticalAlignment="Center",
HorizontalAlignment="Center",
FillDirection="Vertical",
}),











aB,
ar.CustomEmptyPage.Title and al("TextLabel",{
AutomaticSize="XY",
Text=ar.CustomEmptyPage.Title,
ThemeTag={
TextColor3="Text",
},
TextSize=18,
TextTransparency=0.5,
BackgroundTransparency=1,
FontFace=Font.new(ak.Font,Enum.FontWeight.Medium),
})or nil,
ar.CustomEmptyPage.Desc and al("TextLabel",{
AutomaticSize="XY",
Text=ar.CustomEmptyPage.Desc,
ThemeTag={
TextColor3="Text",
},
TextSize=15,
TextTransparency=0.65,
BackgroundTransparency=1,
FontFace=Font.new(ak.Font,Enum.FontWeight.Regular),
})or nil,
})





local d
d=ak.AddSignal(ar.UIElements.ContainerFrame.ChildAdded,function()
b.Visible=false
d:Disconnect()
end)
end)

return ar
end

function ao.OnChange(ap,aq)
ao.OnChangeFunc=aq
end

function ao.SelectTab(ap,aq)
if not ao.Tabs[aq].Locked then
ao.SelectedTab=aq

for ar,as in next,ao.Tabs do
if not as.Locked then
ak.SetThemeTag(as.UIElements.Main,{
ImageTransparency="TabBorderTransparency",
},0.15)
if as.Border then
ak.SetThemeTag(as.UIElements.Main.Outline,{
ImageTransparency="TabBorderTransparency",
},0.15)
end
ak.SetThemeTag(as.UIElements.Main.Frame.TextLabel,{
TextTransparency="TabTextTransparency",
},0.15)
if as.UIElements.Icon and not as.IconColor then
ak.SetThemeTag(as.UIElements.Icon.ImageLabel,{
ImageTransparency="TabIconTransparency",
},0.15)
end
as.Selected=false
end
end
ak.SetThemeTag(ao.Tabs[aq].UIElements.Main,{
ImageColor3="TabBackgroundActive",
ImageTransparency="TabBackgroundActiveTransparency",
},0.15)
if ao.Tabs[aq].Border then
ak.SetThemeTag(ao.Tabs[aq].UIElements.Main.Outline,{
ImageTransparency="TabBorderTransparencyActive",
},0.15)
end
ak.SetThemeTag(ao.Tabs[aq].UIElements.Main.Frame.TextLabel,{
TextTransparency="TabTextTransparencyActive",
},0.15)
if ao.Tabs[aq].UIElements.Icon and not ao.Tabs[aq].IconColor then
ak.SetThemeTag(ao.Tabs[aq].UIElements.Icon.ImageLabel,{
ImageTransparency="TabIconTransparencyActive",
},0.15)
end
ao.Tabs[aq].Selected=true

task.spawn(function()
for ar,as in next,ao.Containers do
as.AnchorPoint=Vector2.new(0,0.05)
as.Visible=false
end
ao.Containers[aq].Visible=true
local ar=game:GetService"TweenService"

local as=TweenInfo.new(0.15,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
local at=ar:Create(ao.Containers[aq],as,{
AnchorPoint=Vector2.new(0,0),
})
at:Play()
end)

ao.OnChangeFunc(aq)
end
end

return ao end function a.ab()

local aa={}


local af=a.load'd'
local ai=af.New
local ak=af.Tween

local al=a.load'aa'

function aa.New(am,an,ao,ap,aq)
local ar={
Title=am.Title or"Section",
Icon=am.Icon,
IconThemed=am.IconThemed,
Opened=am.Opened or false,

HeaderSize=42,
IconSize=18,

Expandable=false,
}

local as
if ar.Icon then
as=af.Image(
ar.Icon,
ar.Icon,
0,
ao,
"Section",
true,
ar.IconThemed,
"TabSectionIcon"
)

as.Size=UDim2.new(0,ar.IconSize,0,ar.IconSize)
as.ImageLabel.ImageTransparency=.25
end

local at=ai("Frame",{
Size=UDim2.new(0,ar.IconSize,0,ar.IconSize),
BackgroundTransparency=1,
Visible=false
},{
ai("ImageLabel",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
Image=af.Icon"chevron-down"[1],
ImageRectSize=af.Icon"chevron-down"[2].ImageRectSize,
ImageRectOffset=af.Icon"chevron-down"[2].ImageRectPosition,
ThemeTag={
ImageColor3="Icon",
},
ImageTransparency=.7,
})
})

local au=ai("Frame",{
Size=UDim2.new(1,0,0,ar.HeaderSize),
BackgroundTransparency=1,
Parent=an,
ClipsDescendants=true,
},{
ai("TextButton",{
Size=UDim2.new(1,0,0,ar.HeaderSize),
BackgroundTransparency=1,
Text="",
},{
as,
ai("TextLabel",{
Text=ar.Title,
TextXAlignment="Left",
Size=UDim2.new(
1,
as and(-ar.IconSize-10)*2
or(-ar.IconSize-10),

1,
0
),
ThemeTag={
TextColor3="Text",
},
FontFace=Font.new(af.Font,Enum.FontWeight.SemiBold),
TextSize=14,
BackgroundTransparency=1,
TextTransparency=.7,

TextWrapped=true
}),
ai("UIListLayout",{
FillDirection="Horizontal",
VerticalAlignment="Center",
Padding=UDim.new(0,10)
}),
at,
ai("UIPadding",{
PaddingLeft=UDim.new(0,11),
PaddingRight=UDim.new(0,11),
})
}),
ai("Frame",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
Name="Content",
Visible=true,
Position=UDim2.new(0,0,0,ar.HeaderSize)
},{
ai("UIListLayout",{
FillDirection="Vertical",
Padding=UDim.new(0,aq.Gap),
VerticalAlignment="Bottom",
}),
})
})


function ar.Tab(av,aw)
if not ar.Expandable then
ar.Expandable=true
at.Visible=true
end
aw.Parent=au.Content
return al.New(aw,ap)
end

function ar.Open(av)
if ar.Expandable then
ar.Opened=true
ak(au,0.33,{
Size=UDim2.new(1,0,0,ar.HeaderSize+(au.Content.AbsoluteSize.Y/ap))
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()

ak(at.ImageLabel,0.1,{Rotation=180},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end
end
function ar.Close(av)
if ar.Expandable then
ar.Opened=false
ak(au,0.26,{
Size=UDim2.new(1,0,0,ar.HeaderSize)
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
ak(at.ImageLabel,0.1,{Rotation=0},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end
end

af.AddSignal(au.TextButton.MouseButton1Click,function()
if ar.Expandable then
if ar.Opened then
ar:Close()
else
ar:Open()
end
end
end)

af.AddSignal(au.Content.UIListLayout:GetPropertyChangedSignal"AbsoluteContentSize",function()
if ar.Opened then
ar:Open()
end
end)

if ar.Opened then
task.spawn(function()
task.wait()
ar:Open()
end)
end



return ar
end


return aa end function a.ac()
return{
Tab="table-of-contents",
Paragraph="type",
Button="square-mouse-pointer",
Toggle="toggle-right",
Slider="sliders-horizontal",
Keybind="command",
Input="text-cursor-input",
Dropdown="chevrons-up-down",
Code="terminal",
Colorpicker="palette",
}end function a.ad()
local aa=(cloneref or clonereference or function(aa)
return aa
end)

aa(game:GetService"UserInputService")

local af={
Margin=8,
Padding=9,
}

local ai=a.load'd'
local ak=ai.New
local al=ai.Tween

function af.new(am,an,ao)
local ap={
IconSize=18,
Padding=14,
Radius=22,
Width=400,
MaxHeight=380,

Icons=a.load'ac',
}

local aq=ak("TextBox",{
Text="",
PlaceholderText="Search...",
ThemeTag={
PlaceholderColor3="Placeholder",
TextColor3="Text",
},
Size=UDim2.new(1,-((ap.IconSize*2)+(ap.Padding*2)),0,0),
AutomaticSize="Y",
ClipsDescendants=true,
ClearTextOnFocus=false,
BackgroundTransparency=1,
TextXAlignment="Left",
FontFace=Font.new(ai.Font,Enum.FontWeight.Regular),
TextSize=18,
})

local ar=ak("ImageLabel",{
Image=ai.Icon"x"[1],
ImageRectSize=ai.Icon"x"[2].ImageRectSize,
ImageRectOffset=ai.Icon"x"[2].ImageRectPosition,
BackgroundTransparency=1,
ThemeTag={
ImageColor3="Icon",
},
ImageTransparency=0.1,
Size=UDim2.new(0,ap.IconSize,0,ap.IconSize),
},{
ak("TextButton",{
Size=UDim2.new(1,8,1,8),
BackgroundTransparency=1,
Active=true,
ZIndex=999999999,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Text="",
}),
})

local as=ak("ScrollingFrame",{
Size=UDim2.new(1,0,0,0),
AutomaticCanvasSize="Y",
ScrollingDirection="Y",
ElasticBehavior="Never",
ScrollBarThickness=0,
CanvasSize=UDim2.new(0,0,0,0),
BackgroundTransparency=1,
Visible=false,
},{
ak("UIListLayout",{
Padding=UDim.new(0,0),
FillDirection="Vertical",
}),
ak("UIPadding",{
PaddingTop=UDim.new(0,ap.Padding),
PaddingLeft=UDim.new(0,ap.Padding),
PaddingRight=UDim.new(0,ap.Padding),
PaddingBottom=UDim.new(0,ap.Padding),
}),
})

local at=ai.NewRoundFrame(ap.Radius,"Squircle",{
Size=UDim2.new(1,0,1,0),
ThemeTag={
ImageColor3="WindowSearchBarBackground",
},
ImageTransparency=0,
},{
ai.NewRoundFrame(ap.Radius,"Squircle",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,

Visible=false,
ThemeTag={
ImageColor3="White",
},
ImageTransparency=1,
Name="Frame",
},{
ak("Frame",{
Size=UDim2.new(1,0,0,46),
BackgroundTransparency=1,
},{








ak("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
},{
ak("ImageLabel",{
Image=ai.Icon"search"[1],
ImageRectSize=ai.Icon"search"[2].ImageRectSize,
ImageRectOffset=ai.Icon"search"[2].ImageRectPosition,
BackgroundTransparency=1,
ThemeTag={
ImageColor3="Icon",
},
ImageTransparency=0.1,
Size=UDim2.new(0,ap.IconSize,0,ap.IconSize),
}),
aq,
ar,
ak("UIListLayout",{
Padding=UDim.new(0,ap.Padding),
FillDirection="Horizontal",
VerticalAlignment="Center",
}),
ak("UIPadding",{
PaddingLeft=UDim.new(0,ap.Padding),
PaddingRight=UDim.new(0,ap.Padding),
}),
}),
}),
ak("Frame",{
BackgroundTransparency=1,
AutomaticSize="Y",
Size=UDim2.new(1,0,0,0),
Name="Results",
},{
ak("Frame",{
Size=UDim2.new(1,0,0,1),
ThemeTag={
BackgroundColor3="Outline",
},
BackgroundTransparency=0.9,
Visible=false,
}),
as,
ak("UISizeConstraint",{
MaxSize=Vector2.new(ap.Width,ap.MaxHeight),
}),
}),
ak("UIListLayout",{
Padding=UDim.new(0,0),
FillDirection="Vertical",
}),
}),
})

local au=ak("Frame",{
Size=UDim2.new(0,ap.Width,0,0),
AutomaticSize="Y",
Parent=an,
BackgroundTransparency=1,
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
Visible=false,

ZIndex=99999999,
},{
ak("UIScale",{
Scale=0.9,
}),
at,















})

local function CreateSearchTab(av,aw,ax,ay,az,aA)
local aB=ak("TextButton",{
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
BackgroundTransparency=1,
Parent=ay or nil,
},{
ai.NewRoundFrame(ap.Radius-11,"Squircle",{
Size=UDim2.new(1,0,0,0),
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),

ThemeTag={
ImageColor3="Text",
},
ImageTransparency=1,
Name="Main",
},{
ai.NewRoundFrame(ap.Radius-11,"Glass-1",{
Size=UDim2.new(1,0,1,0),
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
ThemeTag={
ImageColor3="White",
},
ImageTransparency=1,
Name="Outline",
},{








ak("UIPadding",{
PaddingTop=UDim.new(0,ap.Padding-2),
PaddingLeft=UDim.new(0,ap.Padding),
PaddingRight=UDim.new(0,ap.Padding),
PaddingBottom=UDim.new(0,ap.Padding-2),
}),
ak("ImageLabel",{
Image=ai.Icon(ax)[1],
ImageRectSize=ai.Icon(ax)[2].ImageRectSize,
ImageRectOffset=ai.Icon(ax)[2].ImageRectPosition,
BackgroundTransparency=1,
ThemeTag={
ImageColor3="Icon",
},
ImageTransparency=0.1,
Size=UDim2.new(0,ap.IconSize,0,ap.IconSize),
}),
ak("Frame",{
Size=UDim2.new(1,-ap.IconSize-ap.Padding,0,0),
BackgroundTransparency=1,
},{
ak("TextLabel",{
Text=av,
ThemeTag={
TextColor3="Text",
},
TextSize=17,
BackgroundTransparency=1,
TextXAlignment="Left",
FontFace=Font.new(ai.Font,Enum.FontWeight.Medium),
Size=UDim2.new(1,0,0,0),
TextTruncate="AtEnd",
AutomaticSize="Y",
Name="Title",
}),
ak("TextLabel",{
Text=aw or"",
Visible=aw and true or false,
ThemeTag={
TextColor3="Text",
},
TextSize=15,
TextTransparency=0.3,
BackgroundTransparency=1,
TextXAlignment="Left",
FontFace=Font.new(ai.Font,Enum.FontWeight.Medium),
Size=UDim2.new(1,0,0,0),
TextTruncate="AtEnd",
AutomaticSize="Y",
Name="Desc",
})or nil,
ak("UIListLayout",{
Padding=UDim.new(0,6),
FillDirection="Vertical",
}),
}),
ak("UIListLayout",{
Padding=UDim.new(0,ap.Padding),
FillDirection="Horizontal",
}),
}),
},true),
ak("Frame",{
Name="ParentContainer",
Size=UDim2.new(1,-ap.Padding,0,0),
AutomaticSize="Y",
BackgroundTransparency=1,
Visible=az,

},{
ai.NewRoundFrame(99,"Squircle",{
Size=UDim2.new(0,2,1,0),
BackgroundTransparency=1,
ThemeTag={
ImageColor3="Text",
},
ImageTransparency=0.9,
}),
ak("Frame",{
Size=UDim2.new(1,-ap.Padding-2,0,0),
Position=UDim2.new(0,ap.Padding+2,0,0),
BackgroundTransparency=1,
},{
ak("UIListLayout",{
Padding=UDim.new(0,0),
FillDirection="Vertical",
}),
}),
}),
ak("UIListLayout",{
Padding=UDim.new(0,0),
FillDirection="Vertical",
HorizontalAlignment="Right",
}),
})



aB.Main.Size=UDim2.new(
1,
0,
0,
aB.Main.Outline.Frame.Desc.Visible
and(((ap.Padding-2)*2)+aB.Main.Outline.Frame.Title.TextBounds.Y+6+aB.Main.Outline.Frame.Desc.TextBounds.Y)
or(((ap.Padding-2)*2)+aB.Main.Outline.Frame.Title.TextBounds.Y)
)

ai.AddSignal(aB.Main.MouseEnter,function()
al(aB.Main,0.04,{ImageTransparency=0.95}):Play()

end)
ai.AddSignal(aB.Main.InputEnded,function()
al(aB.Main,0.08,{ImageTransparency=1}):Play()

end)
ai.AddSignal(aB.Main.MouseButton1Click,function()
if aA then
aA()
end
end)

return aB
end

local function ContainsText(av,aw)
if not aw or aw==""then
return false
end

if not av or av==""then
return false
end

local ax=string.lower(av)
local ay=string.lower(aw)

return string.find(ax,ay,1,true)~=nil
end

local function Search(av)
if not av or av==""then
return{}
end

local aw={}
for ax,ay in next,am.Tabs do
local az=ContainsText(ay.Title or"",av)
local aA={}

for aB,b in next,ay.Elements do
if b.__type~="Section"then
local d=ContainsText(b.Title or"",av)
local f=ContainsText(b.Desc or"",av)

if d or f then
aA[aB]={
Title=b.Title,
Desc=b.Desc,
Original=b,
__type=b.__type,
Index=aB,
}
end
end
end

if az or next(aA)~=nil then
aw[ax]={
Tab=ay,
Title=ay.Title,
Icon=ay.Icon,
Elements=aA,
}
end
end
return aw
end

ai.AddSignal(as.UIListLayout:GetPropertyChangedSignal"AbsoluteContentSize",function()

al(as,0.06,{
Size=UDim2.new(
1,
0,
0,
math.clamp(
as.UIListLayout.AbsoluteContentSize.Y+(ap.Padding*2),
0,
ap.MaxHeight
)
),
},Enum.EasingStyle.Quint,Enum.EasingDirection.InOut):Play()






end)

function ap.Open(av)
task.spawn(function()
at.Frame.Visible=true
au.Visible=true
al(au.UIScale,0.12,{Scale=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end)
end

function ap.Close(av,aw)
task.spawn(function()
ao()
at.Frame.Visible=false
al(au.UIScale,0.12,{Scale=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()

task.wait(0.12)
au.Visible=false
if aw then
au:Destroy()
end
end)
end

ai.AddSignal(ar.TextButton.MouseButton1Click,function()
ap:Close(true)
end)

ap:Open()

function ap.Search(av,aw)
aw=aw or""

local ax=Search(aw)

as.Visible=true
at.Frame.Results.Frame.Visible=true
for ay,az in next,as:GetChildren()do
if az.ClassName~="UIListLayout"and az.ClassName~="UIPadding"then
az:Destroy()
end
end

if ax and next(ax)~=nil then
for ay,az in next,ax do
local aA=ap.Icons.Tab
local aB=CreateSearchTab(az.Title,nil,aA,as,true,function()
ap:Close()
am:SelectTab(ay)
end)
if az.Elements and next(az.Elements)~=nil then
for b,d in next,az.Elements do
local f=ap.Icons[d.__type]
CreateSearchTab(
d.Title,
d.Desc,
f,
aB:FindFirstChild"ParentContainer"and aB.ParentContainer.Frame
or nil,
false,
function()
ap:Close()
am:SelectTab(ay)
if az.Tab.ScrollToTheElement then

az.Tab:ScrollToTheElement(d.Index)
end

end
)

end
end
end
elseif aw~=""then
ak("TextLabel",{
Size=UDim2.new(1,0,0,70),
Text="No results found",
TextSize=16,
ThemeTag={
TextColor3="Text",
},
TextTransparency=0.2,
BackgroundTransparency=1,
FontFace=Font.new(ai.Font,Enum.FontWeight.Medium),
Parent=as,
Name="NotFound",
})
else
as.Visible=false
at.Frame.Results.Frame.Visible=false
end
end

ai.AddSignal(aq:GetPropertyChangedSignal"Text",function()
ap:Search(aq.Text)
end)

return ap
end

return af end function a.ae()



local aa=(cloneref or clonereference or function(aa)
return aa
end)

local af=aa(game:GetService"UserInputService")
local ai=aa(game:GetService"RunService")
local ak=aa(game:GetService"Players")

local al=workspace.CurrentCamera

local am=a.load't'

local an=a.load'd'
local ao=an.New
local ap=an.Tween


local aq=a.load'w'.New
local ar=a.load'm'.New
local as=a.load'x'.New
local at=a.load'y'

local au=a.load'z'



return function(av)
local aw={
Title=av.Title or"UI Library",
Author=av.Author,
Icon=av.Icon,
IconSize=av.IconSize or 22,
IconThemed=av.IconThemed,
IconRadius=av.IconRadius or 0,
Folder=av.Folder,
Resizable=av.Resizable~=false,
Background=av.Background,
BackgroundImageTransparency=av.BackgroundImageTransparency or 0,
ShadowTransparency=av.ShadowTransparency or 0.6,
User=av.User or{},
Footer=av.Footer or{},
Topbar=av.Topbar or{Height=52,ButtonsType="Default"},

Size=av.Size,

MinSize=av.MinSize or Vector2.new(560,350),
MaxSize=av.MaxSize or Vector2.new(850,560),

TopBarButtonIconSize=av.TopBarButtonIconSize,

ToggleKey=av.ToggleKey,
ElementsRadius=av.ElementsRadius,
Radius=av.Radius or 16,
Transparent=av.Transparent or false,
HideSearchBar=av.HideSearchBar~=false,
ScrollBarEnabled=av.ScrollBarEnabled or false,
SideBarWidth=av.SideBarWidth or 200,
Acrylic=av.Acrylic or false,
NewElements=av.NewElements or false,
IgnoreAlerts=av.IgnoreAlerts or false,
HidePanelBackground=av.HidePanelBackground or false,
AutoScale=av.AutoScale~=false,
OpenButton=av.OpenButton,
DragFrameSize=160,

Position=UDim2.new(0.5,0,0.5,0),
UICorner=16,
UIPadding=14,
UIElements={},
CanDropdown=true,
Closed=false,
Parent=av.Parent,
Destroyed=false,
IsFullscreen=false,
CanResize=av.Resizable~=false,
IsOpenButtonEnabled=true,

CurrentConfig=nil,
ConfigManager=nil,
AcrylicPaint=nil,
CurrentTab=nil,
TabModule=nil,

OnOpenCallback=nil,
OnCloseCallback=nil,
OnDestroyCallback=nil,

IsPC=false,

Gap=5,

TopBarButtons={},
AllElements={},

ElementConfig={},

PendingFlags={},

IsToggleDragging=false,
}

aw.UICorner=aw.Radius

aw.TopBarButtonIconSize=aw.TopBarButtonIconSize or(aw.Topbar.ButtonsType=="Mac"and 11 or 16)

aw.ElementConfig={
UIPadding=(aw.NewElements and 10 or 13),
UICorner=aw.ElementsRadius or(aw.NewElements and 23 or 16),
}

local ax=aw.Size or UDim2.new(0,580,0,460)
aw.Size=UDim2.new(
ax.X.Scale,
math.clamp(ax.X.Offset,aw.MinSize.X,aw.MaxSize.X),
ax.Y.Scale,
math.clamp(ax.Y.Offset,aw.MinSize.Y,aw.MaxSize.Y)
)

if aw.Topbar=={}then
aw.Topbar={Height=52,ButtonsType="Default"}
end

if not ai:IsStudio()and aw.Folder and writefile then
if not isfolder("WindUI/"..aw.Folder)then
makefolder("WindUI/"..aw.Folder)
end
if not isfolder("WindUI/"..aw.Folder.."/assets")then
makefolder("WindUI/"..aw.Folder.."/assets")
end
if not isfolder(aw.Folder)then
makefolder(aw.Folder)
end
if not isfolder(aw.Folder.."/assets")then
makefolder(aw.Folder.."/assets")
end
end

local ay=ao("UICorner",{
CornerRadius=UDim.new(0,aw.UICorner),
})

if aw.Folder then
aw.ConfigManager=au:Init(aw)
end

if aw.Acrylic then local
az=am.AcrylicPaint{UseAcrylic=aw.Acrylic}

aw.AcrylicPaint=az
end

local az=ao("Frame",{
Size=UDim2.new(0,32,0,32),
Position=UDim2.new(1,0,1,0),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundTransparency=1,
ZIndex=99,
Active=true,
},{
ao("ImageLabel",{
Size=UDim2.new(0,96,0,96),
BackgroundTransparency=1,
Image="rbxassetid://120997033468887",
Position=UDim2.new(0.5,-16,0.5,-16),
AnchorPoint=Vector2.new(0.5,0.5),
ImageTransparency=1,
}),
})
local aA=an.NewRoundFrame(aw.UICorner,"Squircle",{
Size=UDim2.new(1,0,1,0),
ImageTransparency=1,
ImageColor3=Color3.new(0,0,0),
ZIndex=98,
Active=false,
},{
ao("ImageLabel",{
Size=UDim2.new(0,70,0,70),
Image=an.Icon"expand"[1],
ImageRectOffset=an.Icon"expand"[2].ImageRectPosition,
ImageRectSize=an.Icon"expand"[2].ImageRectSize,
BackgroundTransparency=1,
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
ImageTransparency=1,
}),
})

local aB=an.NewRoundFrame(aw.UICorner,"Squircle",{
Size=UDim2.new(1,0,1,0),
ImageTransparency=1,
ImageColor3=Color3.new(0,0,0),
ZIndex=999,
Active=false,
})









aw.UIElements.SideBar=ao("ScrollingFrame",{
Size=UDim2.new(
1,
aw.ScrollBarEnabled and-3-(aw.UIPadding/2)or 0,
1,
not aw.HideSearchBar and-45 or 0
),
Position=UDim2.new(0,0,1,0),
AnchorPoint=Vector2.new(0,1),
BackgroundTransparency=1,
ScrollBarThickness=0,
ElasticBehavior="Never",
CanvasSize=UDim2.new(0,0,0,0),
AutomaticCanvasSize="Y",
ScrollingDirection="Y",
ClipsDescendants=true,
VerticalScrollBarPosition="Left",
},{
ao("Frame",{
BackgroundTransparency=1,
AutomaticSize="Y",
Size=UDim2.new(1,0,0,0),
Name="Frame",
},{
ao("UIPadding",{



PaddingBottom=UDim.new(0,aw.UIPadding/2),
}),
ao("UIListLayout",{
SortOrder="LayoutOrder",
Padding=UDim.new(0,aw.Gap),
}),
}),
ao("UIPadding",{

PaddingLeft=UDim.new(0,aw.UIPadding/2),
PaddingRight=UDim.new(0,aw.UIPadding/2),
PaddingBottom=UDim.new(0,aw.UIPadding/2),
}),

})

aw.UIElements.SideBarContainer=ao("Frame",{
Size=UDim2.new(
0,
aw.SideBarWidth,
1,
aw.User.Enabled and-aw.Topbar.Height-42-(aw.UIPadding*2)or-aw.Topbar.Height
),
Position=UDim2.new(0,0,0,aw.Topbar.Height),
BackgroundTransparency=1,
Visible=true,
},{
ao("Frame",{
Name="Content",
BackgroundTransparency=1,
Size=UDim2.new(1,0,1,not aw.HideSearchBar and-45-aw.UIPadding or-aw.UIPadding/2),
Position=UDim2.new(0,0,1,-aw.UIPadding/2),
AnchorPoint=Vector2.new(0,1),
}),
aw.UIElements.SideBar,
})

if aw.ScrollBarEnabled then
as(
aw.UIElements.SideBar,
aw.UIElements.SideBarContainer.Content,
aw,
3,
av.WindUI
)
end

aw.UIElements.MainBar=ao("Frame",{
Size=UDim2.new(1,-aw.UIElements.SideBarContainer.AbsoluteSize.X,1,-aw.Topbar.Height),
Position=UDim2.new(1,0,1,0),
AnchorPoint=Vector2.new(1,1),
BackgroundTransparency=1,
},{
an.NewRoundFrame(aw.UICorner-(aw.UIPadding/2),"Squircle",{
Size=UDim2.new(1,0,1,0),
ThemeTag={
ImageColor3="PanelBackground",
ImageTransparency="PanelBackgroundTransparency",
},


ZIndex=3,
Name="Background",
Visible=not aw.HidePanelBackground,
}),
ao("UIPadding",{

PaddingLeft=UDim.new(0,aw.UIPadding/2),
PaddingRight=UDim.new(0,aw.UIPadding/2),
PaddingBottom=UDim.new(0,aw.UIPadding/2),
}),
})

local b=ao("ImageLabel",{
Image="rbxassetid://8992230677",
ThemeTag={
ImageColor3="WindowShadow",

},
ImageTransparency=1,
Size=UDim2.new(1,100,1,100),
Position=UDim2.new(0,-50,0,-50),
ScaleType="Slice",
SliceCenter=Rect.new(99,99,99,99),
BackgroundTransparency=1,
ZIndex=-999999999999999,
Name="Blur",
})

if af.TouchEnabled and not af.KeyboardEnabled then
aw.IsPC=false
elseif af.KeyboardEnabled then
aw.IsPC=true
else
aw.IsPC=nil
end







local d
if aw.User then
local function GetUserThumb()local
f=ak:GetUserThumbnailAsync(
aw.User.Anonymous and 1 or ak.LocalPlayer.UserId,
Enum.ThumbnailType.HeadShot,
Enum.ThumbnailSize.Size420x420
)
return f
end

d=ao("TextButton",{
Size=UDim2.new(
0,
aw.UIElements.SideBarContainer.AbsoluteSize.X-(aw.UIPadding/2),
0,
42+aw.UIPadding
),
Position=UDim2.new(0,aw.UIPadding/2,1,-(aw.UIPadding/2)),
AnchorPoint=Vector2.new(0,1),
BackgroundTransparency=1,
Visible=aw.User.Enabled or false,
},{
an.NewRoundFrame(aw.UICorner-(aw.UIPadding/2),"SquircleOutline",{
Size=UDim2.new(1,0,1,0),
ThemeTag={
ImageColor3="Text",
},
ImageTransparency=1,
Name="Outline",
},{
ao("UIGradient",{
Rotation=78,
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0.0,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(1.0,Color3.fromRGB(255,255,255)),
},
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.0,0.1),
NumberSequenceKeypoint.new(0.5,1),
NumberSequenceKeypoint.new(1.0,0.1),
},
}),
}),
an.NewRoundFrame(aw.UICorner-(aw.UIPadding/2),"Squircle",{
Size=UDim2.new(1,0,1,0),
ThemeTag={
ImageColor3="Text",
},
ImageTransparency=1,
Name="UserIcon",
},{
ao("ImageLabel",{
Image=GetUserThumb(),
BackgroundTransparency=1,
Size=UDim2.new(0,42,0,42),
ThemeTag={
BackgroundColor3="Text",
},
BackgroundTransparency=0.93,
},{
ao("UICorner",{
CornerRadius=UDim.new(1,0),
}),
}),
ao("Frame",{
AutomaticSize="XY",
BackgroundTransparency=1,
},{
ao("TextLabel",{
Text=aw.User.Anonymous and"Anonymous"or ak.LocalPlayer.DisplayName,
TextSize=17,
ThemeTag={
TextColor3="Text",
},
FontFace=Font.new(an.Font,Enum.FontWeight.SemiBold),
AutomaticSize="Y",
BackgroundTransparency=1,
Size=UDim2.new(1,-27,0,0),
TextTruncate="AtEnd",
TextXAlignment="Left",
Name="DisplayName",
}),
ao("TextLabel",{
Text=aw.User.Anonymous and"anonymous"or ak.LocalPlayer.Name,
TextSize=15,
TextTransparency=0.6,
ThemeTag={
TextColor3="Text",
},
FontFace=Font.new(an.Font,Enum.FontWeight.Medium),
AutomaticSize="Y",
BackgroundTransparency=1,
Size=UDim2.new(1,-27,0,0),
TextTruncate="AtEnd",
TextXAlignment="Left",
Name="UserName",
}),
ao("UIListLayout",{
Padding=UDim.new(0,4),
HorizontalAlignment="Left",
}),
}),
ao("UIListLayout",{
Padding=UDim.new(0,aw.UIPadding),
FillDirection="Horizontal",
VerticalAlignment="Center",
}),
ao("UIPadding",{
PaddingLeft=UDim.new(0,aw.UIPadding/2),
PaddingRight=UDim.new(0,aw.UIPadding/2),
}),
}),
})

function aw.User.Enable(f)
aw.User.Enabled=true
ap(
aw.UIElements.SideBarContainer,
0.25,
{Size=UDim2.new(0,aw.SideBarWidth,1,-aw.Topbar.Height-42-(aw.UIPadding*2))},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
d.Visible=true
end
function aw.User.Disable(f)
aw.User.Enabled=false
ap(
aw.UIElements.SideBarContainer,
0.25,
{Size=UDim2.new(0,aw.SideBarWidth,1,-aw.Topbar.Height)},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
d.Visible=false
end
function aw.User.SetAnonymous(f,g)
if g~=false then
g=true
end
aw.User.Anonymous=g
d.UserIcon.ImageLabel.Image=GetUserThumb()
d.UserIcon.Frame.DisplayName.Text=g and"Anonymous"or ak.LocalPlayer.DisplayName
d.UserIcon.Frame.UserName.Text=g and"anonymous"or ak.LocalPlayer.Name
end

if aw.User.Enabled then
aw.User:Enable()
else
aw.User:Disable()
end

if aw.User.Callback then
an.AddSignal(d.MouseButton1Click,function()
aw.User.Callback()
end)
an.AddSignal(d.MouseEnter,function()
ap(d.UserIcon,0.04,{ImageTransparency=0.95}):Play()
ap(d.Outline,0.04,{ImageTransparency=0.85}):Play()
end)
an.AddSignal(d.InputEnded,function()
ap(d.UserIcon,0.04,{ImageTransparency=1}):Play()
ap(d.Outline,0.04,{ImageTransparency=1}):Play()
end)
end
end

local f
local g

local h=false
local i

local l=typeof(aw.Background)=="string"and string.match(aw.Background,"^video:(.+)")or nil

local m=typeof(aw.Background)=="string"
and not l
and string.match(aw.Background,"^https?://.+")
or nil

local p=typeof(aw.Background)=="string"
and not l
and string.match(aw.Background,"^rbxassetid://%d+")
or nil

local function GetImageExtension(r)
if not r or typeof(r)~="string"then
return".png"
end
local u=r:match"^([^?#]+)"or r
local v=u:match"%.(%w+)$"
if v then
v=v:lower()
if v=="jpg"or v=="jpeg"or v=="png"or v=="webp"then
return"."..v
end
end
return".png"
end



if typeof(aw.Background)=="string"and l then
h=true

if string.find(l,"http")then
local r=(aw.Folder or"Temp").."/assets/."..an.SanitizeFilename(l)..".webm"
if not isfile(r)then
local u,v=pcall(function()





local u=game.HttpGet and game:HttpGet(l)
or an.Request{
Url=l,
Method="GET",
Headers={["User-Agent"]="Roblox/Exploit"},
}.Body

writefile(r,u)
end)
if not u then
warn("[ WindUI.Window.Background ] Failed to download video: "..tostring(v))
end
end

local u,v=pcall(function()
return getcustomasset(r)
end)
if not u then
warn("[ WindUI.Window.Background ] Failed to load custom asset: "..tostring(v))
end
warn"[ WindUI.Window.Background ] VideoFrame may not work with custom video"
l=v
end

i=ao("VideoFrame",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,1,0),
Video=l,
Looped=true,
Volume=0,
},{
ao("UICorner",{
CornerRadius=UDim.new(0,aw.UICorner),
}),
})
i:Play()
elseif m then
local r=(aw.Folder or"Temp")
.."/assets/."
..an.SanitizeFilename(m)
..GetImageExtension(m)

if isfile and not isfile(r)then
local u,v=pcall(function()
local u=game.HttpGet and game:HttpGet(m)
or an.Request{
Url=m,
Method="GET",
Headers={["User-Agent"]="Roblox/Exploit"},
}.Body

writefile(r,u)
end)

if not u then
warn("[ Window.Background ] Failed to download image: "..tostring(v))
end
end

local u,v=pcall(function()
return getcustomasset(r)
end)

if not u then
warn("[ Window.Background ] Failed to load custom asset: "..tostring(v))
end

i=ao("ImageLabel",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,1,0),
Image=v,
ImageTransparency=0,
ScaleType="Crop",
},{
ao("UICorner",{
CornerRadius=UDim.new(0,aw.UICorner),
}),
})
elseif p then
i=ao("ImageLabel",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,1,0),
Image=p,
ImageTransparency=0,
ScaleType="Crop",
},{
ao("UICorner",{
CornerRadius=UDim.new(0,aw.UICorner),
}),
})
elseif aw.Background then
i=ao("ImageLabel",{
BackgroundTransparency=1,
Size=UDim2.new(1,0,1,0),
Image=typeof(aw.Background)=="string"and aw.Background or"",
ImageTransparency=1,
ScaleType="Crop",
},{
ao("UICorner",{
CornerRadius=UDim.new(0,aw.UICorner),
}),
})
end

local r=an.NewRoundFrame(99,"Squircle",{
ImageTransparency=0.8,
ImageColor3=Color3.new(1,1,1),
Size=UDim2.new(0,0,0,4),
Position=UDim2.new(0.5,0,1,4),
AnchorPoint=Vector2.new(0.5,0),
},{
ao("TextButton",{
Size=UDim2.new(1,12,1,12),
BackgroundTransparency=1,
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5),
Active=true,
ZIndex=99,
Name="Frame",
}),
})

function createAuthor(u)
return ao("TextLabel",{
Text=u,
FontFace=Font.new(an.Font,Enum.FontWeight.Medium),
BackgroundTransparency=1,
TextTransparency=0.35,
AutomaticSize="XY",
Parent=aw.UIElements.Main and aw.UIElements.Main.Main.Topbar.Left.Title,
TextXAlignment="Left",
TextSize=13,
LayoutOrder=2,
ThemeTag={
TextColor3="WindowTopbarAuthor",
},
Name="Author",
})
end

local u
local v

if aw.Author then
u=createAuthor(aw.Author)
end

local x=ao("TextLabel",{
Text=aw.Title,
FontFace=Font.new(an.Font,Enum.FontWeight.SemiBold),
BackgroundTransparency=1,
AutomaticSize="XY",
Name="Title",
TextXAlignment="Left",
TextSize=16,
ThemeTag={
TextColor3="WindowTopbarTitle",
},
})

aw.UIElements.Main=ao("Frame",{
Size=UDim2.new(aw.Size.X.Scale,aw.Size.X.Offset,0,0),
Position=aw.Position,
BackgroundTransparency=1,
Parent=av.Parent,
AnchorPoint=Vector2.new(0.5,0.5),
Active=true,

},{
av.WindUI.UIScaleObj,
aw.AcrylicPaint and aw.AcrylicPaint.Frame or nil,
b,
an.NewRoundFrame(aw.UICorner,"Squircle",{
ImageTransparency=1,
Size=UDim2.new(1,0,1,0),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
Name="Background",
ThemeTag={
ImageColor3="WindowBackground",
},

},{
i,
r,
az,
}),




ay,
aA,
aB,
ao("Frame",{
Size=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
Name="Main",

Visible=false,
ZIndex=97,
},{
ao("UICorner",{
CornerRadius=UDim.new(0,aw.UICorner),
}),
aw.UIElements.SideBarContainer,
aw.UIElements.MainBar,

d,

g,
ao("Frame",{
Size=UDim2.new(1,0,0,aw.Topbar.Height),
BackgroundTransparency=1,
BackgroundColor3=Color3.fromRGB(50,50,50),
Name="Topbar",
},{
f,






ao("Frame",{
AutomaticSize="X",
Size=UDim2.new(0,0,1,0),
BackgroundTransparency=1,
Name="Left",
},{
ao("UIListLayout",{
Padding=UDim.new(0,aw.UIPadding+4),
SortOrder="LayoutOrder",
FillDirection="Horizontal",
VerticalAlignment="Center",
}),
ao("Frame",{
AutomaticSize="XY",
BackgroundTransparency=1,
Name="Title",
Size=UDim2.new(0,0,1,0),
LayoutOrder=2,
},{
ao("UIListLayout",{
Padding=UDim.new(0,0),
SortOrder="LayoutOrder",
FillDirection="Vertical",
VerticalAlignment="Center",
}),
x,
u,
}),
ao("UIPadding",{
PaddingLeft=UDim.new(0,4),
}),
}),
ao("CanvasGroup",{
Size=UDim2.new(0,0,1,0),
BackgroundTransparency=1,
Name="Center",
AnchorPoint=Vector2.new(0,0.5),
Position=UDim2.new(0,0,0.5,0),
AutomaticSize="Y",
Visible=false,
},{



ao("ScrollingFrame",{
Name="Holder",
BackgroundTransparency=1,
AutomaticSize="Y",
ScrollBarThickness=0,
ScrollingDirection="X",
AutomaticCanvasSize="X",
CanvasSize=UDim2.new(0,0,0,0),
Size=UDim2.new(1,0,1,0),


},{

ao("UIListLayout",{
FillDirection="Horizontal",
VerticalAlignment="Center",
HorizontalAlignment="Left",
Padding=UDim.new(0,aw.UIPadding/2),
}),
}),
}),
ao("Frame",{
AutomaticSize="XY",
BackgroundTransparency=1,
Position=UDim2.new(aw.Topbar.ButtonsType=="Default"and 1 or 0,0,0.5,0),
AnchorPoint=Vector2.new(aw.Topbar.ButtonsType=="Default"and 1 or 0,0.5),
Name="Right",
},{
ao("UIListLayout",{
Padding=UDim.new(0,aw.Topbar.ButtonsType=="Default"and 9 or 0),
FillDirection="Horizontal",
SortOrder="LayoutOrder",
}),
}),
ao("UIPadding",{
PaddingTop=UDim.new(0,aw.UIPadding),
PaddingLeft=UDim.new(
0,
aw.Topbar.ButtonsType=="Default"and aw.UIPadding or aw.UIPadding-2
),
PaddingRight=UDim.new(0,8),
PaddingBottom=UDim.new(0,aw.UIPadding),
}),
}),
}),
})

an.AddSignal(aw.UIElements.Main.Main.Topbar.Left:GetPropertyChangedSignal"AbsoluteSize",function()
local z=0
local A=aw.UIElements.Main.Main.Topbar.Right.UIListLayout.AbsoluteContentSize.X
/av.WindUI.UIScale

z=aw.UIElements.Main.Main.Topbar.Left.AbsoluteSize.X/av.WindUI.UIScale
if aw.Topbar.ButtonsType~="Default"then
z=z+A+aw.UIPadding-4
end

aw.UIElements.Main.Main.Topbar.Center.Position=
UDim2.new(0,z+(aw.UIPadding/av.WindUI.UIScale),0.5,0)
aw.UIElements.Main.Main.Topbar.Center.Size=UDim2.new(
1,
-z
-(aw.UIPadding/av.WindUI.UIScale)
-(aw.Topbar.ButtonsType=="Default"and A+aw.UIPadding or 0),
1,
0
)
end)

if aw.Topbar.ButtonsType~="Default"then
an.AddSignal(aw.UIElements.Main.Main.Topbar.Right:GetPropertyChangedSignal"AbsoluteSize",function()
aw.UIElements.Main.Main.Topbar.Left.Position=UDim2.new(
0,
(aw.UIElements.Main.Main.Topbar.Right.AbsoluteSize.X/av.WindUI.UIScale)+aw.UIPadding-4,
0,
0
)
end)
end

function aw.CreateTopbarButton(z,A,B,C,F,G,H,J)
local L=an.Image(
B,
B,
0,
aw.Folder,
"WindowTopbarIcon",
aw.Topbar.ButtonsType=="Default"and true or false,
G,
"WindowTopbarButtonIcon"
)
L.Size=aw.Topbar.ButtonsType=="Default"
and UDim2.new(0,J or aw.TopBarButtonIconSize,0,J or aw.TopBarButtonIconSize)
or UDim2.new(0,0,0,0)
L.AnchorPoint=Vector2.new(0.5,0.5)
L.Position=UDim2.new(0.5,0,0.5,0)
L.ImageLabel.ImageTransparency=aw.Topbar.ButtonsType=="Default"and 0 or 1

if aw.Topbar.ButtonsType~="Default"then
L.ImageLabel.ImageColor3=an.GetTextColorForHSB(H)
end

local M=an.NewRoundFrame(
aw.Topbar.ButtonsType=="Default"and aw.UICorner-(aw.UIPadding/2)or 999,
"Squircle",
{
Size=aw.Topbar.ButtonsType=="Default"
and UDim2.new(0,aw.Topbar.Height-16,0,aw.Topbar.Height-16)
or UDim2.new(0,14,0,14),
LayoutOrder=F or 999,


ZIndex=9999,
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
ImageColor3=aw.Topbar.ButtonsType~="Default"and(H or Color3.fromHex"#ff3030")or nil,
ThemeTag=aw.Topbar.ButtonsType=="Default"and{
ImageColor3="Text",
}or nil,
ImageTransparency=aw.Topbar.ButtonsType=="Default"and 1 or 0,
},
{












L,
ao("UIScale",{
Scale=1,
}),
},
true
)

local N=ao("Frame",{
Size=aw.Topbar.ButtonsType~="Default"and UDim2.new(0,24,0,24)
or UDim2.new(0,aw.Topbar.Height-16,0,aw.Topbar.Height-16),
BackgroundTransparency=1,
Parent=aw.UIElements.Main.Main.Topbar.Right,
LayoutOrder=F or 999,
},{
M,
})



aw.TopBarButtons[100-F]={
Name=A,
Object=N,
}

an.AddSignal(M.MouseButton1Click,function()
if C then
C()
end
end)
an.AddSignal(M.MouseEnter,function()
if aw.Topbar.ButtonsType=="Default"then
ap(M,0.15,{ImageTransparency=0.93}):Play()


else

ap(
L.ImageLabel,
0.1,
{ImageTransparency=0},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
ap(L,0.1,{
Size=UDim2.new(
0,
J or aw.TopBarButtonIconSize,
0,
J or aw.TopBarButtonIconSize
),
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end
end)

an.AddSignal(M.MouseButton1Down,function()
ap(M.UIScale,0.2,{Scale=0.9},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end)

an.AddSignal(M.MouseLeave,function()
if aw.Topbar.ButtonsType=="Default"then
ap(M,0.1,{ImageTransparency=1}):Play()


else

ap(
L.ImageLabel,
0.1,
{ImageTransparency=1},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
ap(
L,
0.1,
{Size=UDim2.new(0,0,0,0)},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
end
end)

an.AddSignal(M.InputEnded,function()
ap(M.UIScale,0.2,{Scale=1},Enum.EasingStyle.Quint,Enum.EasingDirection.InOut):Play()
end)

return M
end

function aw.Topbar.Button(z,A:{
Name:string,
Icon:string,
Callback:any,
LayoutOrder:number,
IconThemed:boolean,
Color:Color3,
IconSize:number,
})
return aw:CreateTopbarButton(
A.Name,
A.Icon,
A.Callback,
A.LayoutOrder or 0,
A.IconThemed,
A.Color,
A.IconSize
)
end



local z=an.Drag(
aw.UIElements.Main,
{aw.UIElements.Main.Main.Topbar,r.Frame},
function(z,A)
if not aw.Closed then
if z and A==r.Frame then
ap(r,0.1,{ImageTransparency=0.35}):Play()
else
ap(r,0.2,{ImageTransparency=0.8}):Play()
end
aw.Position=aw.UIElements.Main.Position
aw.Dragging=z
end
end
)

if not h and aw.Background and typeof(aw.Background)=="table"then
local A=ao"UIGradient"
for B,C in next,aw.Background do
A[B]=C
end

aw.UIElements.BackgroundGradient=an.NewRoundFrame(aw.UICorner,"Squircle",{
Size=UDim2.new(1,0,1,0),
Parent=aw.UIElements.Main.Background,
ImageTransparency=aw.Transparent and av.WindUI.TransparencyValue or 0,
},{
A,
})
end














aw.OpenButtonMain=a.load'A'.New(aw)

task.spawn(function()
if aw.Icon then
local A=ao("Frame",{
Size=UDim2.new(0,22,0,22),
BackgroundTransparency=1,
Parent=aw.UIElements.Main.Main.Topbar.Left,
})

v=an.Image(
aw.Icon,
aw.Title,
aw.IconRadius,
aw.Folder,
"Window",
true,
aw.IconThemed,
"WindowTopbarIcon"
)
v.Parent=A
v.Size=UDim2.new(0,aw.IconSize,0,aw.IconSize)
v.Position=UDim2.new(0.5,0,0.5,0)
v.AnchorPoint=Vector2.new(0.5,0.5)

aw.OpenButtonMain:SetIcon(aw.Icon)











else
aw.OpenButtonMain:SetIcon(aw.Icon)

end
end)

function aw.SetToggleKey(A,B)
aw.ToggleKey=B
end

function aw.SetTitle(A,B)
aw.Title=B
x.Text=B
end

function aw.SetAuthor(A,B)
aw.Author=B
if not u then
u=createAuthor(aw.Author)
end

u.Text=B
end

function aw.SetSize(A,B)
if typeof(B)=="UDim2"then
aw.Size=B

ap(aw.UIElements.Main,0.08,{Size=B},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end
end

function aw.SetBackgroundImage(A,B)
aw.UIElements.Main.Background.ImageLabel.Image=B
end
function aw.SetBackgroundImageTransparency(A,B)
if i and i:IsA"ImageLabel"then
i.ImageTransparency=math.floor(B*10+0.5)/10
end
aw.BackgroundImageTransparency=math.floor(B*10+0.5)/10
end

function aw.SetBackgroundTransparency(A,B)
local C=math.floor(tonumber(B)*10+0.5)/10
av.WindUI.TransparencyValue=C
aw:ToggleTransparency(C>0)
end

local A
local B
an.Icon"minimize"
an.Icon"maximize"

aw:CreateTopbarButton(
"Fullscreen",
aw.Topbar.ButtonsType=="Mac"and"rbxassetid://127426072704909"or"maximize",
function()
aw:ToggleFullscreen()
end,
(aw.Topbar.ButtonsType=="Default"and 998 or 999),
true,
Color3.fromHex"#60C762",
aw.Topbar.ButtonsType=="Mac"and 9 or nil
)

local function SetSize(C)
ap(aw.UIElements.Main,0.45,{
Size=not aw.IsFullscreen and B or UDim2.new(
0,
(av.WindUI.ScreenGui.AbsoluteSize.X-20)/av.WindUI.UIScale,
0,
(av.WindUI.ScreenGui.AbsoluteSize.Y-20-52)/av.WindUI.UIScale
),
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()

ap(
aw.UIElements.Main,
0.45,
{Position=not aw.IsFullscreen and A or UDim2.new(0.5,0,0.5,26)},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
end

function aw.ToggleFullscreen(C)
local F=aw.IsFullscreen

z:Set(F)

if not F then
A=aw.UIElements.Main.Position
B=aw.UIElements.Main.Size

aw.CanResize=false
else
if aw.Resizable then
aw.CanResize=true
end
end

aw.IsFullscreen=not F

SetSize(true)
end

an.AddSignal(av.WindUI.ScreenGui:GetPropertyChangedSignal"AbsoluteSize",function()
if aw.IsFullscreen then
SetSize()
end
end)

aw:CreateTopbarButton("Minimize","minus",function()
if aw.Close then
aw:Close()
end






















end,(aw.Topbar.ButtonsType=="Default"and 997 or 998),nil,Color3.fromHex"#F4C948")

function aw.OnOpen(C,F)
aw.OnOpenCallback=F
end
function aw.OnClose(C,F)
aw.OnCloseCallback=F
end
function aw.OnDestroy(C,F)
aw.OnDestroyCallback=F
end

if av.WindUI.UseAcrylic then
aw.AcrylicPaint.AddParent(aw.UIElements.Main)
end

function aw.SetIconSize(C,F)
local G
if typeof(F)=="number"then
G=UDim2.new(0,F,0,F)
aw.IconSize=F
elseif typeof(F)=="UDim2"then
G=F
aw.IconSize=F.X.Offset
end

if v then
v.Size=G
end
end

function aw.Open(C)
if aw.Destroyed then
return
end
task.spawn(function()
if aw.OnOpenCallback then
task.spawn(function()
an.SafeCallback(aw.OnOpenCallback)
end)
end

task.wait(0.06)
aw.Closed=false

aw.UIElements.Main.Size=UDim2.new(aw.Size.X.Scale,aw.Size.X.Offset,0,100)

ap(aw.UIElements.Main,0.8,{

Size=aw.Size,
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()

if aw.UIElements.BackgroundGradient then
ap(aw.UIElements.BackgroundGradient,0.2,{
ImageTransparency=0,
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end

aw.UIElements.Main.Background.ImageTransparency=1
ap(aw.UIElements.Main.Background,0.4,{

ImageTransparency=aw.Transparent and av.WindUI.TransparencyValue or 0,
},Enum.EasingStyle.Exponential,Enum.EasingDirection.Out):Play()

if i then
if i:IsA"VideoFrame"then
i.Visible=true
else
ap(i,0.2,{
ImageTransparency=aw.BackgroundImageTransparency,
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end
end

if aw.OpenButtonMain and aw.IsOpenButtonEnabled then
aw.OpenButtonMain:Visible(false)
end









ap(
b,
0.25,
{ImageTransparency=aw.ShadowTransparency},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()




ap(
r,
0.45,
{Size=UDim2.new(0,aw.DragFrameSize,0,4),ImageTransparency=0.8},
Enum.EasingStyle.Exponential,
Enum.EasingDirection.Out
):Play()
z:Set(true)

if aw.Resizable then
ap(
az.ImageLabel,
0.45,
{ImageTransparency=0.8},
Enum.EasingStyle.Exponential,
Enum.EasingDirection.Out
):Play()
aw.CanResize=true
end

aw.CanDropdown=true
aw.UIElements.Main.Visible=true



aw.UIElements.Main:WaitForChild"Main".Visible=true

av.WindUI:ToggleAcrylic(true)

end)
end
function aw.Close(C)
if aw.Destroyed then
return
end

local F={}

if aw.OnCloseCallback then
task.spawn(function()
an.SafeCallback(aw.OnCloseCallback)
end)
end

av.WindUI:ToggleAcrylic(false)

if aw.UIElements.Main and aw.UIElements.Main:WaitForChild"Main"then
aw.UIElements.Main.Main.Visible=false
end

aw.CanDropdown=false
aw.Closed=true

ap(aw.UIElements.Main,0.9,{

Size=UDim2.new(aw.Size.X.Scale,aw.Size.X.Offset,0,0),
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
if aw.UIElements.BackgroundGradient then
ap(aw.UIElements.BackgroundGradient,0.2,{
ImageTransparency=1,
},Enum.EasingStyle.Quint,Enum.EasingDirection.InOut):Play()
end

ap(aw.UIElements.Main.Background,0.3,{

ImageTransparency=1,
},Enum.EasingStyle.Exponential,Enum.EasingDirection.InOut):Play()








if i then
if i:IsA"VideoFrame"then
i.Visible=false
else
ap(i,0.3,{
ImageTransparency=1,
},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
end
end
ap(b,0.25,{ImageTransparency=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()




ap(
r,
0.3,
{Size=UDim2.new(0,0,0,4),ImageTransparency=1},
Enum.EasingStyle.Exponential,
Enum.EasingDirection.InOut
):Play()
ap(
az.ImageLabel,
0.3,
{ImageTransparency=1},
Enum.EasingStyle.Exponential,
Enum.EasingDirection.Out
):Play()
z:Set(false)
aw.CanResize=false

task.spawn(function()
task.wait(0.4)

if not aw.Closed then
return
end

aw.UIElements.Main.Visible=false

if aw.OpenButtonMain and not aw.Destroyed and not aw.IsPC and aw.IsOpenButtonEnabled then
aw.OpenButtonMain:Visible(true)
end
end)

function F.Destroy(G)
task.spawn(function()
if aw.OnDestroyCallback then
task.spawn(function()
an.SafeCallback(aw.OnDestroyCallback)
end)
end

if aw.AcrylicPaint and aw.AcrylicPaint.Model then
aw.AcrylicPaint.Model:Destroy()
end

aw.Destroyed=true

task.wait(0.4)

av.WindUI.ScreenGui:Destroy()
av.WindUI.NotificationGui:Destroy()
av.WindUI.DropdownGui:Destroy()
av.WindUI.TooltipGui:Destroy()

an.DisconnectAll()

return
end)
end

return F
end
function aw.Destroy(C)
return aw:Close():Destroy()
end
function aw.Toggle(C)
if aw.Closed then
aw:Open()
else
aw:Close()
end
end

function aw.ToggleTransparency(C,F)

aw.Transparent=F
av.WindUI.Transparent=F

aw.UIElements.Main.Background.ImageTransparency=F and av.WindUI.TransparencyValue or 0


end

function aw.LockAll(C)
for F,G in next,aw.AllElements do
if G.Lock then
G:Lock()
end
end
end
function aw.UnlockAll(C)
for F,G in next,aw.AllElements do
if G.Unlock then
G:Unlock()
end
end
end
function aw.GetLocked(C)
local F={}

for G,H in next,aw.AllElements do
if H.Locked then
table.insert(F,H)
end
end

return F
end
function aw.GetUnlocked(C)
local F={}

for G,H in next,aw.AllElements do
if H.Locked==false then
table.insert(F,H)
end
end

return F
end

function aw.GetUIScale(C,F)
return av.WindUI.UIScale
end

function aw.SetUIScale(C,F)
av.WindUI.UIScale=F
ap(av.WindUI.UIScaleObj,0.2,{Scale=F},Enum.EasingStyle.Quint,Enum.EasingDirection.Out):Play()
return aw
end

function aw.SetToTheCenter(C)
ap(
aw.UIElements.Main,
0.45,
{Position=UDim2.new(0.5,0,0.5,0)},
Enum.EasingStyle.Quint,
Enum.EasingDirection.Out
):Play()
return aw
end

function aw.SetCurrentConfig(C,F)
aw.CurrentConfig=F
end

do
local C=40
local F=al.ViewportSize
local G=Vector2.new(aw.Size.X.Offset,aw.Size.Y.Offset)

if not aw.IsFullscreen and aw.AutoScale then
local H=F.X-(C*2)
local J=F.Y-(C*2)

local L=H/G.X
local M=J/G.Y

local N=math.min(L,M)

local O=0.3
local P=1.0

local Q=math.clamp(N,O,P)

local R=aw:GetUIScale()or 1
local S=0.05

if math.abs(Q-R)>S then
aw:SetUIScale(Q)
end
end
end

if aw.OpenButtonMain and aw.OpenButtonMain.Button then
an.AddSignal(aw.OpenButtonMain.Button.TextButton.MouseButton1Click,function()


aw:Open()
end)
end

an.AddSignal(af.InputBegan,function(C,F)
if F then
return
end

if aw.ToggleKey then
if C.KeyCode==aw.ToggleKey then
aw:Toggle()
end
end
end)

task.spawn(function()

aw:Open()
end)

function aw.EditOpenButton(C,F)
return aw.OpenButtonMain:Edit(F)
end

if aw.OpenButton and typeof(aw.OpenButton)=="table"then
aw:EditOpenButton(aw.OpenButton)
end

local C=a.load'aa'
local F=a.load'ab'
local G=C.Init(aw,av.WindUI,av.WindUI.TooltipGui)
G:OnChange(function(H)
aw.CurrentTab=H
end)

aw.TabModule=G

function aw.Tab(H,J)
J.Parent=aw.UIElements.SideBar.Frame
return G.New(J,av.WindUI.UIScale)
end

function aw.SelectTab(H,J)
G:SelectTab(J)
end

function aw.Section(H,J)
return F.New(
J,
aw.UIElements.SideBar.Frame,
aw.Folder,
av.WindUI.UIScale,
aw
)
end

function aw.IsResizable(H,J)
aw.Resizable=J
aw.CanResize=J
end

function aw.SetPanelBackground(H,J)
if typeof(J)=="boolean"then
aw.HidePanelBackground=J

aw.UIElements.MainBar.Background.Visible=J

if G then
for L,M in next,G.Containers do
M.ScrollingFrame.UIPadding.PaddingTop=UDim.new(0,aw.HidePanelBackground and 20 or 10)
M.ScrollingFrame.UIPadding.PaddingLeft=
UDim.new(0,aw.HidePanelBackground and 20 or 10)
M.ScrollingFrame.UIPadding.PaddingRight=
UDim.new(0,aw.HidePanelBackground and 20 or 10)
M.ScrollingFrame.UIPadding.PaddingBottom=
UDim.new(0,aw.HidePanelBackground and 20 or 10)
end
end
end
end

function aw.Divider(H)
local J=ao("Frame",{
Size=UDim2.new(1,0,0,1),
Position=UDim2.new(0.5,0,0,0),
AnchorPoint=Vector2.new(0.5,0),
BackgroundTransparency=0.9,
ThemeTag={
BackgroundColor3="Text",
},
})
local L=ao("Frame",{
Parent=aw.UIElements.SideBar.Frame,

Size=UDim2.new(1,-7,0,5),
BackgroundTransparency=1,
},{
J,
})

return L
end

local H=a.load'o'
function aw.Dialog(J,L)
local M={
Title=L.Title or"Dialog",
Width=L.Width or 320,
Content=L.Content,
Buttons=L.Buttons or{},

TextPadding=14,
}
local N=H.Create(false,"Dialog",aw,av.WindUI,aw.UIElements.Main.Main)

N.UIElements.Main.Size=UDim2.new(0,M.Width,0,0)

local O=ao("Frame",{
Size=UDim2.new(1,0,1,0),
AutomaticSize="Y",
BackgroundTransparency=1,
Parent=N.UIElements.Main,
},{
ao("UIListLayout",{
FillDirection="Vertical",

Padding=UDim.new(0,N.UIPadding),
}),
})

local P=ao("Frame",{
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
BackgroundTransparency=1,
Parent=O,
},{
ao("UIListLayout",{
FillDirection="Horizontal",
Padding=UDim.new(0,N.UIPadding),
VerticalAlignment="Center",
}),
ao("UIPadding",{
PaddingTop=UDim.new(0,M.TextPadding/2),
PaddingLeft=UDim.new(0,M.TextPadding/2),
PaddingRight=UDim.new(0,M.TextPadding/2),
}),
})

local Q
if L.Icon then
Q=an.Image(
L.Icon,
M.Title..":"..L.Icon,
0,
aw,
"Dialog",
true,
L.IconThemed
)
Q.Size=UDim2.new(0,22,0,22)
Q.Parent=P
end

N.UIElements.UIListLayout=ao("UIListLayout",{
Padding=UDim.new(0,12),
FillDirection="Vertical",
HorizontalAlignment="Left",
VerticalFlex="SpaceBetween",
Parent=N.UIElements.Main,
})

ao("UISizeConstraint",{
MinSize=Vector2.new(180,20),
MaxSize=Vector2.new(400,math.huge),
Parent=N.UIElements.Main,
})

N.UIElements.Title=ao("TextLabel",{
Text=M.Title,
TextSize=20,
FontFace=Font.new(an.Font,Enum.FontWeight.SemiBold),
TextXAlignment="Left",
TextWrapped=true,
RichText=true,
Size=UDim2.new(1,Q and-26-N.UIPadding or 0,0,0),
AutomaticSize="Y",
ThemeTag={
TextColor3="Text",
},
BackgroundTransparency=1,
Parent=P,
})
if M.Content then
ao("TextLabel",{
Text=M.Content,
TextSize=18,
TextTransparency=0.4,
TextWrapped=true,
RichText=true,
FontFace=Font.new(an.Font,Enum.FontWeight.Medium),
TextXAlignment="Left",
Size=UDim2.new(1,0,0,0),
AutomaticSize="Y",
LayoutOrder=2,
ThemeTag={
TextColor3="Text",
},
BackgroundTransparency=1,
Parent=O,
},{
ao("UIPadding",{
PaddingLeft=UDim.new(0,M.TextPadding/2),
PaddingRight=UDim.new(0,M.TextPadding/2),
PaddingBottom=UDim.new(0,M.TextPadding/2),
}),
})
end

local R=ao("UIListLayout",{
Padding=UDim.new(0,6),
FillDirection="Horizontal",
HorizontalAlignment="Center",
HorizontalFlex="Fill",
})

local S=ao("Frame",{
Size=UDim2.new(1,0,0,36),
AutomaticSize="None",
BackgroundTransparency=1,
Parent=N.UIElements.Main,
LayoutOrder=4,
},{
R,






})

local T={}

for U,V in next,M.Buttons do
local W=
ar(V.Title,V.Icon,V.Callback,V.Variant,S,N,true)
table.insert(T,W)
W.Size=UDim2.new(1,0,1,0)
end





















































N:Open()

return N
end

local J=false

aw:CreateTopbarButton("Close","x",function()
if not J then
if not aw.IgnoreAlerts then
J=true

aw:Dialog{

Title="Close Window",
Content="Do you want to close this window? You will not be able to open it again.",
Buttons={
{
Title="Cancel",

Callback=function()
J=false
end,
Variant="Secondary",
},
{
Title="Close Window",

Callback=function()
J=false
aw:Destroy()
end,
Variant="Primary",
},
},
}
else
aw:Destroy()
end
end
end,(aw.Topbar.ButtonsType=="Default"and 999 or 997),nil,Color3.fromHex"#F4695F")

function aw.Tag(L,M)
if aw.UIElements.Main.Main.Topbar.Center.Visible==false then
aw.UIElements.Main.Main.Topbar.Center.Visible=true
end
M.Window=aw
return at:New(M,aw.UIElements.Main.Main.Topbar.Center.Holder)
end

local L=av.WindUI.GenerateGUID()

local function startResizing(M)
if aw.CanResize then
isResizing=true
aA.Active=true
initialSize=aw.UIElements.Main.Size
initialInputPosition=M.Position


ap(az.ImageLabel,0.1,{ImageTransparency=0.35}):Play()

an.AddSignal(M.Changed,function()
if M.UserInputState==Enum.UserInputState.End then
if av.WindUI.CurrentInput and av.WindUI.CurrentInput~=L then
return
end

av.WindUI.CurrentInput=nil

isResizing=false
aA.Active=false


ap(az.ImageLabel,0.17,{ImageTransparency=0.8}):Play()
end
end)
end
end

an.AddSignal(az.InputBegan,function(M)
if
M.UserInputType==Enum.UserInputType.MouseButton1
or M.UserInputType==Enum.UserInputType.Touch
then
if av.WindUI.CurrentInput and av.WindUI.CurrentInput~=L then
return
end
av.WindUI.CurrentInput=L

if aw.CanResize then
startResizing(M)
end
end
end)

an.AddSignal(af.InputChanged,function(M)
if
M.UserInputType==Enum.UserInputType.MouseMovement
or M.UserInputType==Enum.UserInputType.Touch
then
if isResizing and aw.CanResize then
local N=M.Position-initialInputPosition
local O=UDim2.new(0,initialSize.X.Offset+N.X*2,0,initialSize.Y.Offset+N.Y*2)

O=UDim2.new(
O.X.Scale,
math.clamp(O.X.Offset,aw.MinSize.X,aw.MaxSize.X),
O.Y.Scale,
math.clamp(O.Y.Offset,aw.MinSize.Y,aw.MaxSize.Y)
)

ap(aw.UIElements.Main,0.08,{
Size=O,
},Enum.EasingStyle.Quad,Enum.EasingDirection.Out):Play()

aw.Size=O
end
end
end)

an.AddSignal(az.MouseEnter,function()
if av.WindUI.CurrentInput and av.WindUI.CurrentInput~=L then
return
end
if not isResizing then
ap(az.ImageLabel,0.1,{ImageTransparency=0.35}):Play()
end
end)
an.AddSignal(az.MouseLeave,function()
if av.WindUI.CurrentInput and av.WindUI.CurrentInput~=L then
return
end
if not isResizing then
ap(az.ImageLabel,0.17,{ImageTransparency=0.8}):Play()
end
end)



local M=0
local N=0.4
local O
local P=0

function onDoubleClick()
aw:SetToTheCenter()
end

an.AddSignal(r.Frame.MouseButton1Up,function()
local Q=tick()
local R=aw.Position

P=P+1

if P==1 then
M=Q
O=R

task.spawn(function()
task.wait(N)
if P==1 then
P=0
O=nil
end
end)
elseif P==2 then
if Q-M<=N and R==O then
onDoubleClick()
end

P=0
O=nil
M=0
else
P=1
M=Q
O=R
end
end)



if not aw.HideSearchBar then
local Q=a.load'ad'
local R=false





















local S=aq("Search","search",aw.UIElements.SideBarContainer,true)
S.Size=UDim2.new(1,-aw.UIPadding/2,0,39)
S.Position=UDim2.new(0,aw.UIPadding/2,0,0)

an.AddSignal(S.MouseButton1Click,function()
if R then
return
end

Q.new(aw.TabModule,aw.UIElements.Main,function()

R=false
if aw.Resizable then
aw.CanResize=true
end

ap(aB,0.1,{ImageTransparency=1}):Play()
aB.Active=false
end)
ap(aB,0.1,{ImageTransparency=0.65}):Play()
aB.Active=true

R=true
aw.CanResize=false
end)
end



function aw.DisableTopbarButtons(Q,R)
for S,T in next,R do
for U,V in next,aw.TopBarButtons do
if V.Name==T then
V.Object.Visible=false
end
end
end
end



























return aw
end end end

local aa={
Window=nil,
Theme=nil,
Creator=a.load'd',
LocalizationModule=a.load'e',
NotificationModule=a.load'f',
Themes=nil,
Transparent=false,

TransparencyValue=0.15,

UIScale=1,

ConfigManager=nil,
Version="0.0.0",

Services=a.load'k',

OnThemeChangeFunction=nil,

cloneref=nil,
UIScaleObj=nil,

CreateWindow=nil,

CurrentInput=nil,
}

local af=(cloneref or clonereference or function(af)
return af
end)

aa.cloneref=af

local ai=af(game:GetService"HttpService")
local ak=af(game:GetService"Players")
local al=af(game:GetService"CoreGui")
local am=af(game:GetService"RunService")
local an=af(game:GetService"UserInputService")

function aa.GenerateGUID()
return ai:GenerateGUID(false)
end

local ao=aa.GenerateGUID()

an.InputBegan:Connect(function(ap,aq)




task.defer(function()
if
ap.UserInputType==Enum.UserInputType.MouseButton1
or ap.UserInputType==Enum.UserInputType.Touch
then
if aa.CurrentInput and aa.CurrentInput~=ao then
return
end

aa.CurrentInput=ao


end
end)
end)
an.InputEnded:Connect(function(ap,aq)
if ap.UserInputType==Enum.UserInputType.MouseButton1 or ap.UserInputType==Enum.UserInputType.Touch then
if aa.CurrentInput and aa.CurrentInput~=ao then
return
end

aa.CurrentInput=nil
end
end)

local ap=ak.LocalPlayer or nil

local aq=ai:JSONDecode(a.load'l')
if aq then
aa.Version=aq.version
end

local ar=a.load'p'

local as=aa.Creator

local at=as.New




local au=a.load't'

local av=protectgui or(syn and syn.protect_gui)or function()end

local aw=gethui and gethui()or(al or ap:WaitForChild"PlayerGui")

local ax=at("UIScale",{
Scale=aa.UIScale,
})

aa.UIScaleObj=ax

aa.ScreenGui=at("ScreenGui",{
Name="WindUI",
Parent=aw,
IgnoreGuiInset=true,
ScreenInsets="None",
DisplayOrder=-99999,
},{

at("Folder",{
Name="Window",
}),






at("Folder",{
Name="KeySystem",
}),
at("Folder",{
Name="Popups",
}),
at("Folder",{
Name="ToolTips",
}),
})

aa.NotificationGui=at("ScreenGui",{
Name="WindUI/Notifications",
Parent=aw,
IgnoreGuiInset=true,
})
aa.DropdownGui=at("ScreenGui",{
Name="WindUI/Dropdowns",
Parent=aw,
IgnoreGuiInset=true,
})
aa.TooltipGui=at("ScreenGui",{
Name="WindUI/Tooltips",
Parent=aw,
IgnoreGuiInset=true,
})
av(aa.ScreenGui)
av(aa.NotificationGui)
av(aa.DropdownGui)
av(aa.TooltipGui)

as.Init(aa)

function aa.SetParent(ay,az)
if aa.ScreenGui then
aa.ScreenGui.Parent=az
end
if aa.NotificationGui then
aa.NotificationGui.Parent=az
end
if aa.DropdownGui then
aa.DropdownGui.Parent=az
end
if aa.TooltipGui then
aa.TooltipGui.Parent=az
end
end
math.clamp(aa.TransparencyValue,0,1)

local ay=aa.NotificationModule.Init(aa.NotificationGui)

function aa.Notify(az,aA)
aA.Holder=ay.Frame
aA.Window=aa.Window

return aa.NotificationModule.New(aA)
end

function aa.SetNotificationLower(az,aA)
ay.SetLower(aA)
end

function aa.SetFont(az,aA)
as.UpdateFont(aA)
end

function aa.OnThemeChange(az,aA)
aa.OnThemeChangeFunction=aA
end

function aa.AddTheme(az,aA)
aa.Themes[aA.Name]=aA
return aA
end

function aa.SetTheme(az,aA)
if aa.Themes[aA]then
aa.Theme=aa.Themes[aA]
as.SetTheme(aa.Themes[aA])

if aa.OnThemeChangeFunction then
aa.OnThemeChangeFunction(aA)
end

return aa.Themes[aA]
end
return nil
end

function aa.GetThemes(az)
return aa.Themes
end
function aa.GetCurrentTheme(az)
return aa.Theme.Name
end
function aa.GetTransparency(az)
return aa.Transparent or false
end
function aa.GetWindowSize(az)
return aa.Window.UIElements.Main.Size
end
function aa.Localization(az,aA)
return aa.LocalizationModule:New(aA,as)
end

function aa.SetLanguage(az,aA)
if as.Localization then
return as.SetLanguage(aA)
end
return false
end

function aa.ToggleAcrylic(az,aA)
if aa.Window and aa.Window.AcrylicPaint and aa.Window.AcrylicPaint.Model then
aa.Window.Acrylic=aA
aa.Window.AcrylicPaint.Model.Transparency=aA and 0.98 or 1
if aA then
au.Enable()
else
au.Disable()
end
end
end

function aa.Gradient(az,aA,aB)
local b={}
local d={}

for f,g in next,aA do
local h=tonumber(f)
if h then
h=math.clamp(h/100,0,1)

local i=g.Color
if typeof(i)=="string"and string.sub(i,1,1)=="#"then
i=Color3.fromHex(i)
end

local l=g.Transparency or 0

table.insert(b,ColorSequenceKeypoint.new(h,i))
table.insert(d,NumberSequenceKeypoint.new(h,l))
end
end

table.sort(b,function(f,g)
return f.Time<g.Time
end)
table.sort(d,function(f,g)
return f.Time<g.Time
end)

if#b<2 then
table.insert(b,ColorSequenceKeypoint.new(1,b[1].Value))
table.insert(d,NumberSequenceKeypoint.new(1,d[1].Value))
end

local f={
Color=ColorSequence.new(b),
Transparency=NumberSequence.new(d),
}

if aB then
for g,h in pairs(aB)do
f[g]=h
end
end

return f
end

function aa.Popup(az,aA)
aA.WindUI=aa
return a.load'u'.new(aA,aa.ScreenGui.Popups)
end

aa.Themes=a.load'v'(aa,as)

as.Themes=aa.Themes

aa:SetTheme"Dark"
aa:SetLanguage(as.Language)

function aa.CreateWindow(az,aA)
local aB=a.load'ae'

if not am:IsStudio()and writefile then
if not isfolder"WindUI"then
makefolder"WindUI"
end
if aA.Folder then
makefolder(aA.Folder)
else
makefolder(aA.Title)
end
end

aA.WindUI=aa
aA.Window=aa.Window
aA.Parent=aa.ScreenGui.Window

if aa.Window then
warn"You cannot create more than one window"
return
end

local b=true

local d=aa.Themes[aA.Theme or"Dark"]


as.SetTheme(d)

local f=gethwid or function()
return ak.LocalPlayer.UserId
end

local g=f()

if aA.KeySystem then
b=false

local function loadKeysystem()
ar.new(aA,g,function(h)
b=h
end)
end

local h=(aA.Folder or"Temp").."/"..g..".key"

if aA.KeySystem.KeyValidator then
if aA.KeySystem.SaveKey and isfile(h)then
local i=readfile(h)
local l=aA.KeySystem.KeyValidator(i)

if l then
b=true
else
loadKeysystem()
end
else
loadKeysystem()
end
elseif not aA.KeySystem.API then
if aA.KeySystem.SaveKey and isfile(h)then
local i=readfile(h)
local l=(type(aA.KeySystem.Key)=="table")and table.find(aA.KeySystem.Key,i)
or tostring(aA.KeySystem.Key)==tostring(i)

if l then
b=true
else
loadKeysystem()
end
else
loadKeysystem()
end
else
if isfile(h)then
local i=readfile(h)
local l=false

for m,p in next,aA.KeySystem.API do
local r=aa.Services[p.Type]
if r then
local u={}
for v,x in next,r.Args do
table.insert(u,p[x])
end

local v=r.New(table.unpack(u))
local x=v.Verify(i)
if x then
l=true
break
end
end
end

b=l
if not l then
loadKeysystem()
end
else
loadKeysystem()
end
end

repeat
task.wait()
until b
end

local h=aB(aA)

aa.Transparent=aA.Transparent
aa.Window=h

if aA.Acrylic then
au.init()
end













return h
end

return aa
end

if not game:IsLoaded() then game.Loaded:Wait() end

local function __run()
    ---------------------------------------------------------------- services
    local Players           = game:GetService("Players")
    local RunService        = game:GetService("RunService")
    local UserInputService  = game:GetService("UserInputService")
    local VirtualInput      = game:GetService("VirtualInputManager")

    local LocalPlayer = Players.LocalPlayer

    ---------------------------------------------------------------- helpers
    local function safe(fn, ...)
        local ok, res = pcall(fn, ...)
        if ok then return res end
    end

    local function guiParent()
        if GUI_PARENT == "playergui" then return LocalPlayer:WaitForChild("PlayerGui") end
        if GUI_PARENT == "coregui" then return game:GetService("CoreGui") end
        local p = safe(function() return gethui() end)
        if p then return p end
        p = safe(function() return game:GetService("CoreGui") end)
        if p and safe(function() return #p:GetChildren() end) then return p end
        return LocalPlayer:WaitForChild("PlayerGui")   -- always allowed, works on any executor
    end

    local function tween(obj, props, t, style, dir)
        local tw = game:GetService("TweenService"):Create(obj, TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
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

    local loadBackground, loadCustom
    do
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

    local function pictureOf(j) return j.url end                                         -- waifu.pics answers {"url": ...}
    local function firstResult(j) return j.results and j.results[1] and j.results[1].url end   -- nekos.best answers {"results": [{"url": ...}]}
    local BgSources = {                                                                        -- SFW endpoints only
        ["waifu.pics"] = {api = "https://api.waifu.pics/sfw/waifu", parse = pictureOf},
        ["waifu.pics / neko"] = {api = "https://api.waifu.pics/sfw/neko", parse = pictureOf},
        ["waifu.pics / shinobu"] = {api = "https://api.waifu.pics/sfw/shinobu", parse = pictureOf},
        ["waifu.pics / megumin"] = {api = "https://api.waifu.pics/sfw/megumin", parse = pictureOf},
        ["nekos.best"] = {api = "https://nekos.best/api/v2/waifu", parse = firstResult},
        ["nekos.best / neko"] = {api = "https://nekos.best/api/v2/neko", parse = firstResult},
        ["nekos.best / kitsune"] = {api = "https://nekos.best/api/v2/kitsune", parse = firstResult},
        ["nekos.best / husbando"] = {api = "https://nekos.best/api/v2/husbando", parse = firstResult},
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

    -- YOUR picture: a direct link to a PNG / JPG, the name of a PNG / JPG in the executor's workspace folder, or a Roblox image id.
    -- returns the asset, or nil and a sentence that says what is wrong
    function loadCustom(text)
        if type(text) ~= "string" then return nil, "type a link or a file name first" end
        text = (text:gsub("^%s+", ""):gsub("%s+$", ""))
        if text == "" or #text > 300 or text:find("%c") then return nil, "that is not a usable link or file name" end
        local id = text:match("^rbxassetid://(%d+)$") or text:match("^(%d+)$")
        if id then return "rbxassetid://" .. id end                              -- an image already on Roblox: used as it is
        if text:sub(1, 4):lower() == "http" then
            if not (getcustomasset and writefile) then return nil, "your executor cannot show downloaded pictures (getcustomasset / writefile are missing)" end
            local asset = imageToAsset(text)
            if not asset then return nil, "that link did not give a PNG or JPG picture (gif, webp and web pages do not work)" end
            return asset
        end
        if not (isfile and readfile and getcustomasset) then return nil, "your executor cannot read files" end
        if not safe(isfile, text) then return nil, "there is no file called '" .. text .. "' in your executor's workspace folder" end
        if not imageKind(safe(readfile, text)) then return nil, "that file is not a PNG or JPG picture" end
        local asset = safe(getcustomasset, text)
        if not asset then return nil, "the executor could not turn that file into a picture" end
        return asset
    end

    function loadBackground(sourceName)
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

    end

    ---------------------------------------------------------------- saved settings (loaded first: the theme needs them)
    local genv = safe(function() return getgenv() end) or _G
    -- NOTHING is saved automatically. The only file is the config YOU make with "Save config" (Config tab); it is loaded
    -- when the hub starts. (The old auto-saved animation_hub_settings.json is ignored.)
    local CONFIG_FILE = "animation_hub_config.json"
    local SESSION_KEY = "__AnimationHubSession"   -- in-memory hand-over for "Apply theme" / "Reload config": used once, then gone
    local function readConfigFile()
        if not (isfile and readfile) then return {} end
        local raw = safe(function() if isfile(CONFIG_FILE) then return readfile(CONFIG_FILE) end end)
        if type(raw) ~= "string" or raw == "" then return {} end
        local data = safe(function() return game:GetService("HttpService"):JSONDecode(raw) end)
        return type(data) == "table" and data or {}
    end
    local function num(v, lo, hi, default)
        if type(v) ~= "number" or v ~= v then return default end
        return math.min(math.max(v, lo), hi)
    end
    local Saved, SavedFrom
    do
        local function loadSaved()
            local carried, fromFile = genv[SESSION_KEY], genv[SESSION_KEY .. "FromFile"]
            genv[SESSION_KEY], genv[SESSION_KEY .. "FromFile"] = nil, nil
            if type(carried) == "table" then return carried, fromFile and "file" or "carried over" end
            local data = readConfigFile()
            return data, next(data) ~= nil and "file" or "none"
        end
    Saved, SavedFrom = loadSaved()
    end
    -- your own menu picture (link / workspace file / image id); "" = random anime pictures. Part of the config.
    local Picture = {source = type(Saved.picture) == "string" and #Saved.picture <= 300 and not Saved.picture:find("%c") and Saved.picture or ""}

    ---------------------------------------------------------------- theme
    -- menu look: from your config (or carried over for a rebuild)
    local UiSaved = type(Saved.ui) == "table" and Saved.ui or {}
    local Themes = {
        ["Rose Gold"] = {Back = {121, 51, 107}, Panel = {148, 63, 131}, Item = {176, 74, 155}, Hover = {207, 87, 183},
            Accent = {255, 120, 184}, Accent2 = {186, 132, 255}, Gold = {255, 224, 168}, WinA = {231, 98, 204}, WinB = {142, 60, 126}},
        ["Ocean"] = {Back = {32, 80, 127}, Panel = {40, 98, 155}, Item = {47, 116, 184}, Hover = {56, 136, 217},
            Accent = {120, 214, 255}, Accent2 = {150, 164, 255}, Gold = {206, 246, 255}, WinA = {62, 152, 242}, WinB = {38, 94, 149}},
        ["Violet"] = {Back = {88, 56, 162}, Panel = {108, 69, 199}, Item = {127, 81, 236}, Hover = {157, 100, 255},
            Accent = {206, 148, 255}, Accent2 = {255, 140, 226}, Gold = {255, 228, 255}, WinA = {183, 117, 255}, WinB = {103, 66, 191}},
        ["Emerald"] = {Back = {28, 87, 76}, Panel = {34, 106, 93}, Item = {40, 126, 110}, Hover = {48, 148, 130},
            Accent = {110, 240, 184}, Accent2 = {110, 204, 255}, Gold = {228, 255, 210}, WinA = {53, 166, 145}, WinB = {33, 102, 89}},
        ["Sunset"] = {Back = {126, 57, 33}, Panel = {154, 70, 40}, Item = {183, 83, 48}, Hover = {215, 98, 56},
            Accent = {255, 168, 104}, Accent2 = {255, 120, 168}, Gold = {255, 232, 172}, WinA = {240, 110, 63}, WinB = {148, 67, 39}},
    }
    local ThemeNames = {"Rose Gold", "Ocean", "Violet", "Emerald", "Sunset"}
    local themeName = Themes[UiSaved.theme] and UiSaved.theme or "Rose Gold"
    local pendingTheme = themeName                    -- picked in Effects Preset; applied by "Apply theme"
    local uiScale = num(UiSaved.scale, 0.7, 1.25, 1)  -- menu size
    local glass = num(UiSaved.glass, 0.4, 0.95, 0.82) -- how see-through the tinted veil over the picture is
    local bright = num(UiSaved.bright, 0.8, 1.2, 1)   -- Brightness slider: scales the window / panel colours (not the accents)
    local TH = {}
    for key, c in pairs(Themes[themeName]) do
        if key == "Accent" or key == "Accent2" or key == "Gold" then TH[key] = c
        else TH[key] = {math.min(255, math.floor(c[1] * bright + 0.5)), math.min(255, math.floor(c[2] * bright + 0.5)), math.min(255, math.floor(c[3] * bright + 0.5))} end
    end
    local function rgb(c) return Color3.fromRGB(c[1], c[2], c[3]) end
    local Theme = {
        Back = rgb(TH.Back), Panel = rgb(TH.Panel), Item = rgb(TH.Item), Hover = rgb(TH.Hover),
        Accent = rgb(TH.Accent), Accent2 = rgb(TH.Accent2), Gold = rgb(TH.Gold),
        Ink      = Color3.fromRGB(36, 14, 48),            -- dark text for use ON the bright accent / white buttons
        Text     = Color3.fromRGB(255, 255, 255),
        SubText  = Color3.fromRGB(236, 226, 248),
        Good     = Color3.fromRGB(120, 235, 175),
        White    = Color3.fromRGB(255, 255, 255),
    }
    local function accentGradient(parent, rotation)
        return new("UIGradient", {Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Rotation = rotation or 0, Parent = parent})
    end
    local function hairline(parent, transparency)     -- subtle glass border
        return new("UIStroke", {Color = Theme.White, Thickness = 1, Transparency = transparency or 0.9, Parent = parent})
    end
    -- shiny sweep: a soft diagonal highlight that glides across a surface; call the returned function to play it
    local function sheen(parent, radius)
        local grad = new("UIGradient", {
            Rotation = 25, Offset = Vector2.new(-1, 0),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.78),
                NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1),
            }),
        })
        new("Frame", {
            Name = "Sheen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = 0, Parent = parent,
        }, {new("UICorner", {CornerRadius = UDim.new(0, radius or 12)}), grad})
        return function()
            grad.Offset = Vector2.new(-1, 0)
            tween(grad, {Offset = Vector2.new(1, 0)}, 0.7, Enum.EasingStyle.Quad)
        end
    end
    -- glossy sheen: a white film that is strongest at the top edge and fades out (the "glass" look)
    local function gloss(parent, radius, strength)
        local top = 0.72 + (1 - (strength or 1)) * 0.2          -- strength 1 = brightest sheen
        return new("Frame", {
            Name = "Gloss", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.White, BorderSizePixel = 0,
            ZIndex = 0, Parent = parent,
        }, {
            new("UICorner", {CornerRadius = UDim.new(0, radius or 12)}),
            new("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, top), NumberSequenceKeypoint.new(0.5, 0.96), NumberSequenceKeypoint.new(1, 1),
                }),
                Parent = nil,
            }),
        })
    end

    ---------------------------------------------------------------- cleanup old
    -- re-running the script must not leave the old copy's listeners (Auto Tech, predictor...) alive
    if type(genv.__AnimationHubCleanup) == "function" then pcall(genv.__AnimationHubCleanup) end
    do
        local old = guiParent():FindFirstChild("AnimationHubTSB")
        if old then old:Destroy() end
    end

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
    ---------------------------------------------------------------- the menu: WindUI in the white-water look, or the built-in menu further down
    -- getgenv().AH_LEGACY_UI = true keeps the built-in menu. It is also what you get when WindUI cannot start (an executor that blocks its file / web calls).
    -- ClassicWind / WindAdapter / UILib / WindUILoader are bundled in by game_dev/build_executor.py; the unbundled file only has the built-in menu.
    local Backend
    local windActions = {}                              -- filled in where the tabs are built (the top bar buttons call them)
    local WindPrefs = {theme = "Wraith White", font = "Default", scale = 0.9, alpha = 0.45, water = true, waterStrength = 0.7, waterSpeed = 1, bgDim = 0.35, popup = true}
    windActions.lines = {
        "New look: the Wraith Hub v1.5 window (WindUI) with the white water background, the Wraith White / Pearl themes, search, your player card and a card at the top of every tab.",
        "Same hub inside: Auto block, combo cards (On screen / Assist / Opt), pins, Auto Tech, timing, Tech Lab, teleports and Config are unchanged.",
        "Tech Lab: who the techs go for, safe moves, the knocked-down guard, chains, the input buffer and a hit check.",
        "The floating bar, the pinned buttons and the BLOCK button are still on screen, in the new colours.",
        "Look tab: theme (searchable), font, size, transparency, the white water (also the top bar button), your own picture or video.",
    }
    if ClassicWind and WindAdapter and UILib and WindUILoader and genv.AH_LEGACY_UI ~= true then
        local backendProblem
        WindAdapter.addThemes(WindAdapter.WraithThemes)
        local w = type(Saved.wind) == "table" and Saved.wind or {}
        for _, name in ipairs(WindAdapter.ThemeNames) do if name == w.theme then WindPrefs.theme = name end end
        if WindAdapter.Fonts[w.font] then WindPrefs.font = w.font end
        WindPrefs.scale = num(w.scale, 0.55, 1.2, WindPrefs.scale)
        WindPrefs.alpha = num(w.alpha, 0, 0.9, WindPrefs.alpha)
        WindPrefs.waterStrength = num(w.waterStrength, 0, 1, WindPrefs.waterStrength)
        WindPrefs.waterSpeed = num(w.waterSpeed, 0, 3, WindPrefs.waterSpeed)
        WindPrefs.bgDim = num(w.bgDim, 0, 0.9, WindPrefs.bgDim)
        if type(w.water) == "boolean" then WindPrefs.water = w.water end
        if type(w.popup) == "boolean" then WindPrefs.popup = w.popup end
        local okLib, WindUI = xpcall(WindUILoader, debug.traceback)
        if okLib and type(WindUI) == "table" and WindUI.CreateWindow then
            local vw0 = viewport()
            local ok, res = xpcall(function()
                return ClassicWind.new{
                    Adapter = WindAdapter, WindUI = WindUI, UILib = UILib,
                    onError = function(where, err) warn("[Wraith Hub v1.5] " .. tostring(where) .. ": " .. tostring(err)) end,
                    perFrame = tonumber(genv.AH_MENU_PER_FRAME),        -- (the tests set this: most controls built per frame; normally a time budget decides)
                    cfg = {Title = "Wraith Hub v1.5", Subtitle = "The Strongest Battlegrounds", Folder = "AnimationHub", Parent = guiParent(), GuiName = "AnimationHubTSB_Wind",
                        Theme = WindPrefs.theme, WaveMode = "High", ToggleKey = Enum.KeyCode.RightShift, WindowAlpha = WindPrefs.alpha, Scale = WindPrefs.scale, Mono = false,
                        WindowIcon = "sparkles", OpenColors = {"#ffffff", "#9aa7b8"}, SearchBar = true, UserCard = true, SideBarWidth = (vw0 and vw0 >= 900) and 200 or 130,
                        Size = {660, 520}, TopbarStyle = "Default", Tag = {Title = "v1.5", Color = "#e8eef7"},
                        TopbarButtons = {
                            {Name = "Panic", Icon = "zap", Callback = function() if windActions.panic then windActions.panic() end end},
                            {Name = "Water", Icon = "sparkles", Callback = function() if windActions.toggleWater then windActions.toggleWater() end end},
                            {Name = "Changelog", Icon = "info", Callback = function() if windActions.changelog then windActions.changelog() end end},
                        },
                        Water = {Enabled = WindPrefs.water, Strength = WindPrefs.waterStrength, Speed = WindPrefs.waterSpeed, Tint = WindAdapter.waterTint(WindPrefs.theme)},
                        Background = Picture.source ~= "" and Picture.source or nil, BackgroundDim = WindPrefs.bgDim,
                        OnBackground = function(okBg, msg) if not okBg and windActions.say then windActions.say("Background not loaded: " .. tostring(msg)) end end,
                        OnError = function(where, err) warn("[Wraith Hub v1.5] " .. tostring(where) .. ": " .. tostring(err)) end},
                }
            end, debug.traceback)
            if ok then Backend = res else backendProblem = res end
        else
            backendProblem = WindUI
        end
        if backendProblem then warn("[Wraith Hub v1.5] WindUI did not start, using the built-in menu: " .. tostring(backendProblem):sub(1, 300)) end
    end
    if Backend then
        genv.__AnimationHubUI = Backend                  -- (the tests look at the menu through this)
        onCleanup[#onCleanup + 1] = function() Backend.destroy(); if genv.__AnimationHubUI == Backend then genv.__AnimationHubUI = nil end end
    end

    local WIN_W, WIN_H = 600, 390
    do
        local vw, vh = viewport()
        if vw then
            WIN_W = math.max(360, math.min(WIN_W, vw - 24))
            WIN_H = math.max(240, math.min(WIN_H, vh - 24))
        end
    end
    local COMPACT = WIN_W < 500                 -- narrow screens: icon-only sidebar
    local SIDE_W = COMPACT and 58 or 168

    -- the whole window is a CanvasGroup so it can fade and scale as one piece
    local Main = new("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0),     -- top edge stays put when minimising / opening
        Size = UDim2.fromOffset(WIN_W, WIN_H), Position = UDim2.new(0.5, 0, 0.5, -WIN_H / 2),
        BackgroundColor3 = Theme.Back, BorderSizePixel = 0, GroupTransparency = 1,
        Parent = Gui,
    }, {corner(18)})
    local function fitScale()           -- the menu size the user asked for, never bigger than the screen
        local vw, vh = viewport()
        if not vw then return uiScale end
        return math.max(0.5, math.min(uiScale, (vw - 8) / WIN_W, (vh - 8) / WIN_H))
    end
    local MainScale = new("UIScale", {Scale = 0.92 * fitScale(), Parent = Main})
    local BorderGrad
    do
        local MainStroke = stroke(Theme.White, 1.6, 0.15)
        MainStroke.Parent = Main
        BorderGrad = new("UIGradient", {      -- gold -> accent -> accent2 rim that slowly rotates
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Theme.Gold), ColorSequenceKeypoint.new(0.5, Theme.Accent), ColorSequenceKeypoint.new(1, Theme.Accent2),
            }),
            Rotation = 45, Parent = MainStroke,
        })
    end

    -- background: tinted gradient, optional image, and a dark veil so text stays readable
    new("UIGradient", {
        Color = ColorSequence.new(rgb(TH.WinA), rgb(TH.WinB)),
        Rotation = 60, Parent = Main,
    })
    local Background = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "",
        ScaleType = Enum.ScaleType.Crop, ImageTransparency = BACKGROUND_TRANSPARENCY,
        ZIndex = 0, Parent = Main,
    })
    local Veil = new("Frame", {                      -- dark veil over the picture (the "Glass" slider)
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Back, BackgroundTransparency = glass,
        BorderSizePixel = 0, ZIndex = 0, Parent = Main,
    })
    gloss(Main, 18, 1)
    local bgGen = 0
    local Banners = {}                                -- the hero banners (Main tab...) show the same picture
    local pictureNote, pictureStatus                  -- Effects tab label + the text it should show (the load may finish before the label exists)
    local function noteAboutPicture(text)
        pictureStatus = text
        if pictureNote then pictureNote.Text = text end
    end
    local function setPicture(asset)
        Background.Image = asset
        Background.ImageTransparency = 1                 -- fade the new picture in
        tween(Background, {ImageTransparency = BACKGROUND_TRANSPARENCY}, 0.8)
        for _, b in ipairs(Banners) do b.Image = asset end
    end
    -- sourceName nil = your own picture if you set one, else a random one from the current source; a name = a random one from that source
    local function refreshBackground(sourceName)
        bgGen = bgGen + 1
        local mine = bgGen                       -- only the newest request may set the image
        task.spawn(function()
            local asset, why
            if Picture.source ~= "" and not sourceName then asset, why = loadCustom(Picture.source) end
            if not asset then asset = loadBackground(sourceName) end
            if Picture.source ~= "" and not sourceName then
                noteAboutPicture(why and ("Your picture did not load: " .. why .. " (a random one is shown instead).") or "Your picture is on.")
            end
            if asset and mine == bgGen and alive then setPicture(asset) end
        end)
    end
    if not Backend then refreshBackground() end

    local toast
    do
    -- toast: a small message that slides up from the bottom (pins, errors, confirmations)
    local Toast = new("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40),
        Size = UDim2.fromOffset(280, 38), BackgroundColor3 = Theme.Panel, GroupTransparency = 1, ZIndex = 50, Parent = Gui,
    }, {corner(12), hairline(nil, 0.6), gloss(nil, 12, 1)})
    local ToastText = new("TextLabel", {
        Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), TextTruncate = Enum.TextTruncate.AtEnd, Parent = Toast,
    })
    local toastId = 0
    function toast(text)
        toastId = toastId + 1
        local mine = toastId
        ToastText.Text = tostring(text)
        Toast.Position = UDim2.new(0.5, 0, 1, -22)
        tween(Toast, {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 1, -40)}, 0.3)
        task.spawn(function()
            task.wait(1.9)
            if mine == toastId and alive then
                tween(Toast, {GroupTransparency = 1, Position = UDim2.new(0.5, 0, 1, -28)}, 0.3)
            end
        end)
    end

    end

    -- title bar
    local pingPill                                   -- small live ping readout, filled in by the ping block
    local TopBar = new("Frame", {Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = Main})
    local Title = new("TextLabel", {
        Text = "Wraith Hub v1.5", Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = Theme.White,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 9), Size = UDim2.new(1, -230, 0, 22), Parent = TopBar,
    })
    local TitleGrad = new("UIGradient", {
        Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Gold), ColorSequenceKeypoint.new(1, Theme.Accent)}),
        Parent = Title,
    })
    new("TextLabel", {
        Text = "The Strongest Battlegrounds", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 31), Size = UDim2.new(1, -230, 0, 16), Parent = TopBar,
    })
    pingPill = new("TextLabel", {
        Text = "-- ms", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Good,
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.3,
        Size = UDim2.fromOffset(64, 24), Position = UDim2.new(1, -176, 0, 16), Parent = TopBar,
    }, {corner(12), hairline(nil, 0.85)})
    new("Frame", {                                   -- divider under the title bar
        Size = UDim2.new(1, -32, 0, 1), Position = UDim2.new(0, 16, 1, 0), BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = TopBar,
    })

    -- show / hide the menu with a fade + scale (RightShift on PC, the floating bar on touch devices)
    local menuOpen, menuTok = true, 0
    local renderFab   -- assigned by the floating bar further down
    local function setMenu(v)
        menuOpen = v and true or false
        menuTok = menuTok + 1
        local mine = menuTok
        if menuOpen then
            Main.Visible = true
            tween(Main, {GroupTransparency = 0}, 0.25)
            tween(MainScale, {Scale = fitScale()}, 0.4, Enum.EasingStyle.Back)
        else
            tween(Main, {GroupTransparency = 1}, 0.18)
            tween(MainScale, {Scale = 0.94 * fitScale()}, 0.18)
            task.spawn(function()
                task.wait(0.2)
                if mine == menuTok and alive then Main.Visible = false end
            end)
        end
        if renderFab then renderFab() end
    end
    local function toggleMenu() setMenu(not menuOpen) end

    do
    local function topButton(text, xOff, hoverColor, cb)
        local b = new("TextButton", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text,
            BackgroundColor3 = Theme.Item, BackgroundTransparency = 0.4, AutoButtonColor = false,
            Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, xOff, 0, 12), Parent = TopBar,
        }, {corner(16)})
        b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = hoverColor, BackgroundTransparency = 0.1}, 0.15) end)
        b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = Theme.Item, BackgroundTransparency = 0.4}, 0.2) end)
        b.MouseButton1Click:Connect(cb)
        return b
    end
    local minimized = false
    local fullSize = UDim2.fromOffset(WIN_W, WIN_H)
    topButton("-", -84, Theme.Hover, function()
        minimized = not minimized
        tween(Main, {Size = minimized and UDim2.fromOffset(WIN_W, 57) or fullSize}, 0.35, Enum.EasingStyle.Quint)
    end)
    topButton("X", -44, Color3.fromRGB(200, 70, 100), function()
        tween(Main, {GroupTransparency = 1}, 0.2)
        tween(MainScale, {Scale = 0.9}, 0.2)
        task.spawn(function() task.wait(0.24); cleanup() end)
    end)

    end

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

    connect(UserInputService.InputBegan, function(i, gp)
        if not gp and not Backend and i.KeyCode == Enum.KeyCode.RightShift then toggleMenu() end
    end)

    ---------------------------------------------------------------- sidebar / pages
    new("Frame", {                                   -- frosted glass panel behind the sidebar
        Position = UDim2.fromOffset(6, 60), Size = UDim2.new(0, SIDE_W + 2, 1, -124),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.45, BorderSizePixel = 0,
    }, {corner(16), hairline(nil, 0.84), gloss(nil, 16, 0.9)}).Parent = Main
    local Sidebar = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 62), Size = UDim2.new(0, SIDE_W, 1, -126),
        BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Main,
    }, {
        new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
        new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6)}),
    })

    local Content = new("Frame", {
        Position = UDim2.fromOffset(SIDE_W + 6, 62), Size = UDim2.new(1, -(SIDE_W + 20), 1, -76),
        BackgroundTransparency = 1, Parent = Main,
    })

    -- footer: player card
    do
    local Card = new("Frame", {
        Position = UDim2.new(0, 8, 1, -58), Size = UDim2.fromOffset(SIDE_W - 16, 46),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.2, Parent = Main,
    }, {corner(12), hairline(nil, 0.8), gloss(nil, 12, 1)})
    local avatar = new("ImageLabel", {
        Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(7, 7),
        BackgroundColor3 = Theme.Item, Parent = Card,
    }, {corner(16)})
    if not COMPACT then
        new("TextLabel", {
            Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Text,
            BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -52, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left, Parent = Card,
        })
        new("TextLabel", {
            Text = "@" .. LocalPlayer.Name, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Theme.SubText,
            BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(46, 23), Size = UDim2.new(1, -52, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left, Parent = Card,
        })
    end
    task.spawn(function()
        local img = safe(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if img then avatar.Image = img end
    end)

    end

    local Tabs, currentTab, sideOrder = {}, nil, 0

    -- small caps divider in the sidebar ("CHARACTERS", "TOOLS" ...)
    local function sideHeader(text)
        sideOrder = sideOrder + 1
        if COMPACT then
            new("Frame", {Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, LayoutOrder = sideOrder, Parent = Sidebar})
            return
        end
        new("TextLabel", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Theme.SubText, TextTransparency = 0.25,
            TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24), LayoutOrder = sideOrder, Parent = Sidebar,
        }, {new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 8)})})
    end

    local function createTab(name, icon)
        sideOrder = sideOrder + 1
        local btn = new("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Item, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 38), LayoutOrder = sideOrder, Parent = Sidebar,
        }, {corner(12)})
        local tile = new("Frame", {
            Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(COMPACT and 11 or 8, 6),
            BackgroundColor3 = Theme.Panel, Parent = btn,
        }, {corner(9)})
        local tileText = new("TextLabel", {
            Text = icon, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.SubText,
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = tile,
        })
        local text = new("TextLabel", {
            Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -46, 1, 0), Visible = not COMPACT, Parent = btn,
        })
        local bar = new("Frame", {
            Size = UDim2.fromOffset(3, 0), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = btn,
        }, {corner(2)})

        -- each page is a CanvasGroup (fades / slides in) holding a scrolling list
        local group = new("CanvasGroup", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, GroupTransparency = 1, Parent = Content,
        })
        local page = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent, ScrollBarImageTransparency = 0.3,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
            Parent = group,
        }, {
            new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
            new("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10)}),
        })

        local tab = {Btn = btn, Bar = bar, Page = group, tok = 0}
        local function paint(active)
            tween(btn, {BackgroundTransparency = active and 0.35 or 1}, 0.25)
            tween(text, {TextColor3 = active and Theme.Text or Theme.SubText}, 0.25)
            tween(tileText, {TextColor3 = active and Theme.Ink or Theme.SubText}, 0.25)
            tween(tile, {BackgroundColor3 = active and Theme.Accent or Theme.Panel}, 0.25)
            tween(bar, {Size = UDim2.fromOffset(3, active and 22 or 0)}, 0.3, Enum.EasingStyle.Back)
        end
        function tab:Select()
            if currentTab == tab then return end
            local prev = currentTab
            currentTab = tab
            if prev then prev:Hide() end
            tab.tok = tab.tok + 1
            group.Visible = true
            group.Position = UDim2.fromOffset(0, 16)
            group.GroupTransparency = 1
            tween(group, {Position = UDim2.fromOffset(0, 0), GroupTransparency = 0}, 0.3)
            paint(true)
        end
        function tab:Hide()
            paint(false)
            tab.tok = tab.tok + 1
            local mine = tab.tok
            tween(group, {GroupTransparency = 1}, 0.12)
            task.spawn(function()
                task.wait(0.14)
                if tab.tok == mine and currentTab ~= tab then group.Visible = false end   -- not re-selected meanwhile
            end)
        end
        btn.MouseButton1Click:Connect(function() tab:Select() end)
        local sweepTab = sheen(btn, 12)
        btn.MouseEnter:Connect(function()
            sweepTab()
            if currentTab ~= tab then tween(btn, {BackgroundTransparency = 0.7}, 0.15) end
        end)
        btn.MouseLeave:Connect(function() if currentTab ~= tab then tween(btn, {BackgroundTransparency = 1}, 0.2) end end)

        -- elements ------------------------------------------------------
        local function row(height, parent)
            return new("Frame", {
                Size = UDim2.new(1, 0, 0, height or 44), BackgroundColor3 = Theme.Item,
                BackgroundTransparency = 0.28, Parent = parent or page,
            }, {corner(12), hairline(nil, 0.82), gloss(nil, 12, 0.8)})
        end
        local function label(parent, text, size, color, pos, font)
            return new("TextLabel", {
                Text = text, Font = font or Enum.Font.GothamMedium, TextSize = size or 13,
                TextColor3 = color or Theme.Text, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                Position = pos or UDim2.fromOffset(14, 0), Size = UDim2.new(1, -90, 1, 0), Parent = parent,
            })
        end
        local function isPointer(i)
            return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
        end

        -- wrapped text that grows with its content
        function tab:Label(text, parent)
            return new("TextLabel", {
                Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = (typeof(parent) == "Instance") and parent or page,
            }, {new("UIPadding", {
                PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2),
            })})
        end

        -- an on/off switch, used by Toggle rows and by the "On screen" switch on combo cards
        local function makeSwitch(parent, position, width, height)
            local track = new("Frame", {
                Size = UDim2.fromOffset(width, height), Position = position, BackgroundColor3 = Theme.Panel, Parent = parent,
            }, {corner(height / 2), hairline(nil, 0.85)})
            local pad = 3
            local knobSize = height - pad * 2
            local knob = new("Frame", {
                Size = UDim2.fromOffset(knobSize, knobSize), Position = UDim2.fromOffset(pad, pad),
                BackgroundColor3 = Theme.Text, Parent = track,
            }, {corner(knobSize / 2)})
            local sw = {}
            function sw.render(on, animate)
                local t = animate and 0.28 or 0
                tween(track, {BackgroundColor3 = on and Theme.Accent or Theme.Panel}, t)
                tween(knob, {Position = on and UDim2.fromOffset(width - knobSize - pad, pad) or UDim2.fromOffset(pad, pad)},
                    t, Enum.EasingStyle.Back)
            end
            return sw
        end

        function tab:Toggle(text, default, cb, parent, subtitle)
            local r = row(subtitle and 58 or 44, parent)
            local main = label(r, text)
            if subtitle then
                main.Position = UDim2.fromOffset(14, 7)
                main.Size = UDim2.new(1, -90, 0, 22)
                new("TextLabel", {
                    Text = subtitle, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText,
                    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
                    TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(14, 29), Size = UDim2.new(1, -90, 0, 24), Parent = r,
                })
            end
            local state = default and true or false
            local sw = makeSwitch(r, UDim2.new(1, -60, 0.5, -12), 46, 24)
            sw.render(state, false)
            -- the whole row is the hit area (the switch alone is too small for a finger)
            local hit = new("TextButton", {Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromScale(1, 1), Parent = r})
            local api = {}
            function api:Get() return state end
            function api:Set(v)
                v = v and true or false
                if v == state then return end
                state = v
                sw.render(state, true)
                task.spawn(cb, state)
            end
            hit.MouseButton1Click:Connect(function() api:Set(not state) end)
            hit.MouseEnter:Connect(function() tween(r, {BackgroundTransparency = 0.2}, 0.15) end)
            hit.MouseLeave:Connect(function() tween(r, {BackgroundTransparency = 0.35}, 0.2) end)
            task.spawn(cb, state)
            return api
        end

        -- a text box: the label on top, the box under it. cb(text, enterPressed) runs when the box loses focus
        function tab:Input(text, placeholder, default, cb, parent)
            local r = row(72, parent)
            label(r, text, 13, nil, UDim2.fromOffset(14, 5)).Size = UDim2.new(1, -28, 0, 24)
            local box = new("TextBox", {
                Text = default or "", PlaceholderText = placeholder or "", PlaceholderColor3 = Theme.SubText, ClearTextOnFocus = false,
                Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundColor3 = Theme.Panel, Size = UDim2.new(1, -28, 0, 30), Position = UDim2.fromOffset(14, 33), Parent = r,
            }, {corner(10), hairline(nil, 0.85), new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})})
            box.FocusLost:Connect(function(enter) task.spawn(cb, box.Text, enter) end)
            local api = {}
            function api:Get() return box.Text end
            function api:Set(v) box.Text = tostring(v) end
            return api
        end

        -- hero banner: your picture across the top of a page, with the title over a soft shadow
        function tab:Banner(title, subtitle, tag)
            local f = new("Frame", {
                Size = UDim2.new(1, 0, 0, 118), BackgroundColor3 = Theme.Panel, ClipsDescendants = true, Parent = page,
            }, {corner(16), hairline(nil, 0.7)})
            local img = new("ImageLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Background.Image, ScaleType = Enum.ScaleType.Crop, Parent = f,
            })
            Banners[#Banners + 1] = img
            new("Frame", {                               -- shadow from the left so the title stays readable on any picture
                Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Back, BorderSizePixel = 0, ZIndex = 2, Parent = f,
            }, {new("UIGradient", {
                Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.55, 0.5), NumberSequenceKeypoint.new(1, 0.92)}),
            })})
            local head = new("TextLabel", {
                Text = title, Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = Theme.White, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(18, 22), Size = UDim2.new(1, -120, 0, 30), ZIndex = 3, Parent = f,
            })
            new("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.White), ColorSequenceKeypoint.new(1, Theme.Gold)}), Parent = head})
            new("TextLabel", {
                Text = subtitle or "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
                Position = UDim2.fromOffset(18, 56), Size = UDim2.new(1, -120, 0, 40), ZIndex = 3, Parent = f,
            })
            if tag then
                new("TextLabel", {
                    Text = tag, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Ink, BackgroundColor3 = Theme.Gold,
                    Size = UDim2.fromOffset(54, 22), Position = UDim2.new(1, -70, 0, 14), ZIndex = 4, Parent = f,
                }, {corner(11)})
            end
            new("Frame", {                               -- thin accent line under the picture
                Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), BorderSizePixel = 0, BackgroundColor3 = Theme.White, ZIndex = 4, Parent = f,
            }, {accentGradient(nil, 0)})
            gloss(f, 16, 1)
            return f
        end

        function tab:Button(text, cb, parent)
            local r = row(42, parent)
            local b = new("TextButton", {
                Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AutoButtonColor = false, Parent = r,
            })
            b.MouseEnter:Connect(function() tween(r, {BackgroundTransparency = 0.15}, 0.15) end)
            b.MouseLeave:Connect(function() tween(r, {BackgroundTransparency = 0.35}, 0.2) end)
            b.MouseButton1Click:Connect(function()
                tween(r, {BackgroundColor3 = Theme.Accent}, 0.1).Completed:Connect(function()
                    tween(r, {BackgroundColor3 = Theme.Item}, 0.3)
                end)
                task.spawn(cb)
            end)
            return r
        end

        function tab:Slider(text, min, max, default, step, cb, parent)
            assert(max > min and step > 0, "Slider: need max > min and step > 0")
            local r = row(60, parent)
            label(r, text, 13, Theme.Text, UDim2.fromOffset(14, 6)).Size = UDim2.new(1, -90, 0, 22)
            local val = new("TextLabel", {
                Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Text, BackgroundColor3 = Theme.Panel,
                Position = UDim2.new(1, -72, 0, 6), Size = UDim2.fromOffset(58, 22), Parent = r,
            }, {corner(8)})
            local rail = new("Frame", {
                Position = UDim2.new(0, 16, 1, -22), Size = UDim2.new(1, -32, 0, 8), BackgroundColor3 = Theme.Panel, Parent = r,
            }, {corner(4)})
            local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.White, BorderSizePixel = 0, Parent = rail}, {corner(4)})
            accentGradient(fill, 0)
            local knob = new("Frame", {
                Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = Theme.White, ZIndex = 3, Parent = rail,
            }, {corner(9), stroke(Theme.Accent, 2, 0)})
            local touch = new("TextButton", {            -- generous invisible hit area for fingers
                Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
                Position = UDim2.new(0, -8, 0.5, -16), Size = UDim2.new(1, 16, 0, 32), Parent = rail,
            })
            local function set(v, fire)
                v = math.floor((v - min) / step + 0.5) * step + min       -- snap relative to min
                v = math.clamp(tonumber(string.format("%.4f", v)), min, max)   -- no float noise in callbacks
                val.Text = tostring(v)
                local frac = (v - min) / (max - min)
                tween(fill, {Size = UDim2.fromScale(frac, 1)}, 0.1, Enum.EasingStyle.Linear)
                tween(knob, {Position = UDim2.new(frac, 0, 0.5, 0)}, 0.1, Enum.EasingStyle.Linear)
                if fire then task.spawn(cb, v) end
            end
            set(default, true)
            local dragging = false
            local function fromInput(i)
                local w = rail.AbsoluteSize.X
                if w <= 0 then return end
                set(min + (max - min) * math.clamp((i.Position.X - rail.AbsolutePosition.X) / w, 0, 1), true)
            end
            touch.InputBegan:Connect(function(i)
                if isPointer(i) then
                    dragging = true
                    tween(knob, {Size = UDim2.fromOffset(22, 22)}, 0.12)
                    fromInput(i)
                end
            end)
            connect(UserInputService.InputEnded, function(i)
                if isPointer(i) and dragging then
                    dragging = false
                    tween(knob, {Size = UDim2.fromOffset(18, 18)}, 0.2, Enum.EasingStyle.Back)
                end
            end)
            connect(UserInputService.InputChanged, function(i)
                if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
            end)
            local api = {}
            function api:Set(v) set(v, true) end
            return api
        end

        function tab:Dropdown(text, options, default, cb, parent)
            local r = row(44, parent)
            label(r, text)
            local i = table.find(options, default) or 1        -- unknown default -> first option (and show it)
            local b = new("TextButton", {
                Text = options[i], Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent,
                BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
                Size = UDim2.fromOffset(112, 30), Position = UDim2.new(1, -126, 0.5, -15), Parent = r,
            }, {corner(10), hairline(nil, 0.85)})
            b.MouseButton1Click:Connect(function()
                i = i % #options + 1
                b.Text = options[i]
                tween(b, {BackgroundColor3 = Theme.Hover}, 0.08).Completed:Connect(function() tween(b, {BackgroundColor3 = Theme.Panel}, 0.25) end)
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

        -- collapsible section with cards (like the reference UI)
        function tab:Section(title, collapsed)
            local holder = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Parent = page,
            }, {new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
            local head = new("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0, Parent = holder,
            })
            new("Frame", {                               -- accent tick before the title
                Size = UDim2.fromOffset(4, 16), Position = UDim2.fromOffset(2, 7), BackgroundColor3 = Theme.White,
                BorderSizePixel = 0, Parent = head,
            }, {corner(2), accentGradient(nil, 90)})
            new("TextLabel", {
                Text = title, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -50, 1, 0), Parent = head,
            })
            local arrow = new("TextLabel", {
                Text = "v", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent,
                BackgroundTransparency = 1, Position = UDim2.new(1, -30, 0, 0), Size = UDim2.fromOffset(24, 30),
                Rotation = collapsed and 0 or 180, Parent = head,
            })
            local body = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, LayoutOrder = 1, Parent = holder,
            }, {new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
            local open = not collapsed
            body.Visible = open
            head.MouseButton1Click:Connect(function()
                open = not open
                body.Visible = open
                tween(arrow, {Rotation = open and 180 or 0}, 0.25, Enum.EasingStyle.Back)
            end)

            local sec = {Body = body}
            -- cb = what "Run" does. extra (optional) = {
            --   conf = "high|medium|low|custom",
            --   options = function(drawer) ... end                  fills an options drawer that opens with "Opt"
            --   pin = {default = bool, onChange = function(on)}     the "On screen" switch
            --   assist = {default = bool, onChange = function(on)}  the "Assist" (armed) switch
            -- }
            -- returns a handle with :SetPinned(bool) and :SetArmed(bool) (they never fire onChange)
            function sec:Button(name, desc, cb, extra)
                extra = extra or {}
                local confColor = extra.conf == "high" and Theme.Good or (extra.conf == "medium" and Theme.Accent2 or Theme.SubText)
                local holder2 = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1, Parent = body,
                }, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
                local card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 114), BackgroundColor3 = Theme.Item,
                    BackgroundTransparency = 0.25, LayoutOrder = 0, Parent = holder2,
                }, {corner(14), gloss(nil, 14, 1)})
                local cardStroke = hairline(card, 0.82)
                local sweepCard = sheen(card, 14)
                new("Frame", {                           -- confidence colour strip
                    Size = UDim2.fromOffset(4, 70), Position = UDim2.fromOffset(0, 18), BackgroundColor3 = confColor,
                    BorderSizePixel = 0, Parent = card,
                }, {corner(2)})
                new("TextLabel", {
                    Text = name, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -146, 0, 20), Parent = card,
                })
                new("TextLabel", {
                    Text = desc or "", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText,
                    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                    TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -146, 0, 78), Parent = card,
                })
                -- right column: confidence chip, two switches, Run / Opt
                new("TextLabel", {
                    Text = extra.conf or "?", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = confColor,
                    BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.2,
                    Position = UDim2.new(1, -124, 0, 8), Size = UDim2.fromOffset(112, 18), Parent = card,
                }, {corner(9)})
                local handle = {}
                function handle:SetPinned() end
                function handle:SetArmed() end
                local function switchRow(labelText, y, spec)
                    local state = false
                    new("TextLabel", {
                        Text = labelText, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText,
                        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
                        Position = UDim2.new(1, -124, 0, y), Size = UDim2.fromOffset(62, 20), Parent = card,
                    })
                    local sw = makeSwitch(card, UDim2.new(1, -52, 0, y), 40, 20)
                    local hit = new("TextButton", {
                        Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
                        Position = UDim2.new(1, -126, 0, y - 4), Size = UDim2.fromOffset(116, 28), Parent = card,
                    })
                    local function apply(v, silent)
                        v = v and true or false
                        if v == state then return end
                        state = v
                        sw.render(v, true)
                        if not silent then task.spawn(spec.onChange, v) end
                    end
                    hit.MouseButton1Click:Connect(function() apply(not state) end)
                    if spec.default then state = true; sw.render(true, false); task.spawn(spec.onChange, true) end
                    return apply
                end
                if extra.pin then
                    local apply = switchRow("On screen", 32, extra.pin)
                    function handle:SetPinned(v) apply(v, true) end
                end
                if extra.assist then
                    local apply = switchRow("Assist", 56, extra.assist)
                    function handle:SetArmed(v) apply(v, true) end
                end
                local run = new("TextButton", {
                    Text = "Run", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Ink,
                    BackgroundColor3 = Theme.White, AutoButtonColor = false,
                    Position = UDim2.new(1, -124, 1, -34), Size = UDim2.fromOffset(60, 26), Parent = card,
                }, {corner(10), accentGradient(nil, 0)})
                run.MouseButton1Click:Connect(function()
                    tween(run, {Size = UDim2.fromOffset(56, 24), Position = UDim2.new(1, -122, 1, -33)}, 0.07).Completed:Connect(function()
                        tween(run, {Size = UDim2.fromOffset(60, 26), Position = UDim2.new(1, -124, 1, -34)}, 0.25, Enum.EasingStyle.Back)
                    end)
                    task.spawn(cb)
                end)
                card.MouseEnter:Connect(function()
                    tween(card, {BackgroundTransparency = 0.12}, 0.18); tween(cardStroke, {Transparency = 0.5}, 0.18)
                    sweepCard()
                end)
                card.MouseLeave:Connect(function()
                    tween(card, {BackgroundTransparency = 0.25}, 0.25); tween(cardStroke, {Transparency = 0.82}, 0.25)
                end)

                if extra.options then
                    local drawer = new("Frame", {
                        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundTransparency = 1, Visible = false, LayoutOrder = 1, Parent = holder2,
                    }, {
                        new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
                        new("UIPadding", {PaddingLeft = UDim.new(0, 10)}),
                    })
                    local built, open2 = false, false
                    local optBtn = new("TextButton", {
                        Text = "Opt", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent,
                        BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
                        Position = UDim2.new(1, -60, 1, -34), Size = UDim2.fromOffset(48, 26), Parent = card,
                    }, {corner(10), hairline(nil, 0.85)})
                    optBtn.MouseButton1Click:Connect(function()
                        open2 = not open2
                        if open2 and not built then       -- build lazily: hundreds of sliders up front would be slow on phones
                            built = true
                            extra.options(drawer)
                        end
                        drawer.Visible = open2
                        optBtn.Text = open2 and "Close" or "Opt"
                        tween(optBtn, {BackgroundColor3 = open2 and Theme.Accent or Theme.Panel,
                            TextColor3 = open2 and Theme.Ink or Theme.Accent}, 0.2)
                    end)
                end
                return handle
            end

            -- read-only card with wrapped text (used for the tech library)
            function sec:Info(name, desc)
                local card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Item, BackgroundTransparency = 0.35, Parent = body,
                }, {
                    corner(14), hairline(nil, 0.9),
                    new("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}),
                    new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
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
            function sec:Toggle(name, default, cb, subtitle) return tab:Toggle(name, default, cb, body, subtitle) end
            function sec:Slider(text, min, max, default, step, cb) return tab:Slider(text, min, max, default, step, cb, body) end
            function sec:Dropdown(text, options, default, cb) return tab:Dropdown(text, options, default, cb, body) end
            function sec:Label(text) return tab:Label(text, body) end
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

    if Backend then
        -- the menu is WindUI's: the built-in window above stays hidden (the floating bar, pins and BLOCK button live in its ScreenGui) and the hub's menu calls go to WindUI
        Main.Visible = false
        menuOpen = Backend.isOpen()
        createTab, sideHeader, toast = Backend.createTab, Backend.sideHeader, Backend.toast
        pingPill = Backend.pingPill("-- ms", "#9be8c4")
        setMenu = function(v)
            v = v and true or false
            if Backend.isOpen() ~= v then Backend.setMenu(v) end
            menuOpen = v
            if renderFab then renderFab() end
        end
        toggleMenu = function() setMenu(not Backend.isOpen()) end
        -- the on-screen buttons take the white-water palette
        for key, c in pairs({Back = {20, 26, 36}, Panel = {32, 40, 54}, Item = {46, 56, 74}, Hover = {70, 84, 108}, Accent = {238, 244, 252}, Accent2 = {168, 183, 205}, Gold = {255, 255, 255}}) do
            Theme[key] = rgb(c)
        end
        Theme.Ink, Theme.Text, Theme.SubText, Theme.Good = Color3.fromRGB(16, 22, 32), Color3.fromRGB(245, 248, 252), Color3.fromRGB(178, 190, 206), Color3.fromRGB(130, 232, 190)
    end

    -- ambient shine: the border rotates slowly, and every ~6 s a shimmer runs over the title
    do
        local shimmerAcc = 0
        connect(RunService.Heartbeat, function(dt)
            if not menuOpen or Backend then return end
            BorderGrad.Rotation = (BorderGrad.Rotation + dt * 24) % 360
            shimmerAcc = shimmerAcc + dt
            if shimmerAcc >= 6 then
                shimmerAcc = 0
                TitleGrad.Offset = Vector2.new(-0.7, 0)
                tween(TitleGrad, {Offset = Vector2.new(0.7, 0)}, 1.1, Enum.EasingStyle.Sine)
            end
        end)
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

    do   -- (own scope: a function may only hold 200 locals)
    local lastTech = 0
    local DirectionKeys = {
        Forward = Enum.KeyCode.W, Back = Enum.KeyCode.S,
        Left    = Enum.KeyCode.A, Right = Enum.KeyCode.D,
    }
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
    end

    ---------------------------------------------------------------- timing + ping
    -- Gaps (seconds) after each kind of step. Adjustable in the Timing tab. With "Auto timing" on, the gaps
    -- that wait for a visible cue (after a move or dash) are additionally shortened by about your ping
    -- (see ping_model.lua). Heuristic: it cannot read other players' ping and cannot guarantee a hit.
    local TimingDefaults = {m1 = 0.2, dash = 0.3, move = 0.5, jump = 0.25}
    local Timing = {m1 = 0.2, dash = 0.3, move = 0.5, jump = 0.25}
    local Auto = {on = true, strength = 1, offsetMs = 0, manualPing = 0}
    local macroSpeed = 1
    local PingState = {model = PingModel and PingModel.new(0.2)}

    local ComboOpts = {}                                   -- combo name -> options table (see combo_options.lua)
    local Pins = {}                                        -- pinned on-screen buttons (see the manager further down)
    local SavedPins = type(Saved.pins) == "table" and Saved.pins or {}
    local Armed, armedOrder = {}, {}                       -- Assist: armed combos (never saved: you start disarmed)
    -- auto block: grace = how long after their attack ends I keep F down, maxHold = never hold longer than this
    local Block = {on = false, range = 16, aim = 90, delay = 0, grace = 0.15, maxHold = 1.0, minHold = 0.12, punchPause = 0.22, usePing = true,
        lead = 0.12, learn = true, useLearned = true, chain = false, floater = true, style = "Safe", pierceMode = "block",
        chainGrace = 0.35, rush = true, verify = true,
        stats = {seen = 0, blocked = 0, why = {}, rush = 0, retries = 0, senseOk = 0, senseMiss = 0}, lastDecision = "nothing seen yet"}
    -- how early F goes down before a learned hit: Safe = comfortably early, Perfect = at the last moment (the "perfect block" crit)
    local BlockOpts = {
        styles = {Safe = 0.12, Balanced = 0.05, Perfect = 0.02}, styleNames = {"Safe", "Balanced", "Perfect"},
        pierceModes = {["Do nothing"] = "skip", ["Side dash"] = "dash", ["Block anyway"] = "block"}, pierceNames = {"Do nothing", "Side dash", "Block anyway"},
    }
    if type(Saved.block) == "table" then
        local sb = Saved.block
        Block.range = num(sb.range, 6, 30, Block.range)
        Block.aim = num(sb.aim, 20, 120, Block.aim)
        Block.delay = num(sb.delay, 0, 0.4, Block.delay)
        Block.grace = num(sb.grace, 0.05, 0.5, Block.grace)
        Block.maxHold = num(sb.maxHold, 0.3, 2, Block.maxHold)
        Block.usePing = sb.usePing ~= false
        if BlockOpts.styles[sb.style] then Block.style = sb.style; Block.lead = BlockOpts.styles[sb.style] end
        if sb.pierceMode == "skip" or sb.pierceMode == "dash" or sb.pierceMode == "block" then Block.pierceMode = sb.pierceMode end
        Block.learn = sb.learn ~= false
        Block.useLearned = sb.useLearned ~= false
        Block.chain = sb.chain == true
        Block.floater = sb.floater ~= false
        Block.chainGrace = num(sb.chainGrace, 0, 0.8, Block.chainGrace)
        Block.rush = sb.rush ~= false
        Block.verify = sb.verify ~= false
    end
    -- the learner: how long after an enemy animation starts do I actually get hurt? (kept only if you press Save config)
    -- what blocking looks like on this game (a new animation, a changed attribute, a slower walk): learned from your own presses
    local Sense = BlockSense and BlockSense.new()
    if Sense and type(Saved.block) == "table" then Sense:import(Saved.block.sense) end
    local Learner = BlockPredict and BlockPredict.new()
    if Learner then Learner:import(Saved.learned) end
    if type(Saved.floater) == "table" and type(Saved.floater.x) == "number" and type(Saved.floater.y) == "number" then
        Block.floaterPos = {x = Saved.floater.x, y = Saved.floater.y}
    end
    local SideAuto = {on = false, dir = "Behind", delay = 0.25, cooldown = 0.8, anims = {}}   -- auto side dash after your moves
    -- "dash behind the closest player": most dashes, wait between them (a side dash has a ~2 s cooldown), time for a dash to finish
    -- before checking / hitting, M1 once behind
    local Behind = {count = 1, gap = 2.1, settle = 0.3, m1 = false}
    -- Garou "Flowing Water -> Kyoto" assist options (see kyoto_plan.lua): M1s, wait after Flowing Water, whirlwind dash, twisted, side dash way
    -- how techs START: with YOUR M1 (1-3 of them; the script then plays the rest of the tech, casting its first move itself)
    -- or, with m1 = false, by casting the tech's first move yourself. anims = your M1 animations (touch players teach them once).
    local Start = {m1 = true, settle = 0.35, most = 3, anims = {}}
    if type(Saved.start) == "table" then
        Start.m1 = Saved.start.m1 ~= false
        Start.settle = num(Saved.start.settle, 0.15, 0.8, Start.settle)
        Start.most = math.floor(num(Saved.start.most, 1, 4, Start.most))
        if type(Saved.start.anims) == "table" then
            local n = 0
            for id, v in pairs(Saved.start.anims) do
                if v == true and type(id) == "string" and #id <= 120 and not id:find("%c") and n < 12 then Start.anims[id] = true; n = n + 1 end
            end
        end
    end
    local Kyoto = KyotoPlan and KyotoPlan.clean(type(Saved.kyoto) == "table" and Saved.kyoto or nil)
        or {m1 = 3, wait = 0.3, whirl = true, twisted = true, side = "Toward"}
    if type(Saved.behind) == "table" then
        Behind.count = math.floor(num(Saved.behind.count, 1, 3, Behind.count))
        Behind.gap = num(Saved.behind.gap, 0.5, 4, Behind.gap)
        Behind.settle = num(Saved.behind.settle, 0.1, 1, Behind.settle)
        Behind.m1 = Saved.behind.m1 == true
    end
    if type(Saved.sideAuto) == "table" then
        local sa = Saved.sideAuto
        if sa.dir == "Left" or sa.dir == "Right" or sa.dir == "Alternate" or sa.dir == "Behind" or sa.dir == "Toward" then SideAuto.dir = sa.dir
        elseif sa.dir == "Closest" then SideAuto.dir = "Toward" end                   -- the old name
        SideAuto.delay = num(sa.delay, 0, 1, SideAuto.delay)
        SideAuto.cooldown = num(sa.cooldown, 0.2, 3, SideAuto.cooldown)
        if type(sa.anims) == "table" then
            local n = 0
            for id, v in pairs(sa.anims) do
                if v == true and type(id) == "string" and #id <= 120 and not id:find("%c") and n < 24 then
                    SideAuto.anims[id] = true
                    n = n + 1
                end
            end
        end
    end
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

    -- "dirty" only drives the status line in the Config tab ("unsaved changes"); it never writes anything
    local dirty, ready = false, false
    local configStatus, fabRef
    local function refreshConfigStatus()
        if not configStatus then return end
        local where = SavedFrom == "file" and "A config file was found and loaded when the hub started."
            or (SavedFrom == "carried over" and "Your settings were carried over from the menu rebuild (they are not on disk)." or "No config file loaded - everything is at its defaults.")
        configStatus.Text = where .. (dirty and "  You have changes that are NOT saved." or "")
    end
    local function markDirty()
        if not ready or dirty then return end
        dirty = true
        refreshConfigStatus()
    end
    local techLab                                     -- the Tech Lab engine (tech_lab.lua), when it was bundled in
    -- everything the hub remembers, as plain data (used by Save config and by the menu rebuild)
    local function buildSnapshot()
        local combos = {}
        if ComboOptions then
            for name, o in pairs(ComboOpts) do
                if not ComboOptions.isDefault(o) then combos[name] = o end    -- only what differs from the defaults
            end
        end
        local pinData = {}
        if Pins then
            for name, p in pairs(Pins) do pinData[name] = {x = p.x, y = p.y} end
        end
        for name, pos in pairs(SavedPins or {}) do      -- pins in the file whose card is not built (yet): keep only valid ones
            if type(name) == "string" and pinData[name] == nil and type(pos) == "table"
                and type(pos.x) == "number" and type(pos.y) == "number" then
                pinData[name] = {x = pos.x, y = pos.y}
            end
        end
        return {version = 2, timing = Timing, speed = macroSpeed, auto = Auto, combos = combos, pins = pinData,
            ui = {theme = pendingTheme, scale = uiScale, glass = glass, bright = bright},
            wind = WindPrefs,
            block = {range = Block.range, aim = Block.aim, delay = Block.delay, grace = Block.grace, maxHold = Block.maxHold, usePing = Block.usePing,
                style = Block.style, pierceMode = Block.pierceMode, learn = Block.learn, useLearned = Block.useLearned, chain = Block.chain, floater = Block.floater,
                chainGrace = Block.chainGrace, rush = Block.rush, verify = Block.verify, sense = Sense and Sense:export() or nil},
            learned = Learner and Learner:export() or nil,
            floater = Block.floaterPos,
            fab = fabRef and {x = fabRef.x, y = fabRef.y, locked = fabRef.locked, minimized = fabRef.minimized} or nil,
            behind = {count = Behind.count, gap = Behind.gap, settle = Behind.settle, m1 = Behind.m1},
            kyoto = {m1 = Kyoto.m1, wait = Kyoto.wait, whirl = Kyoto.whirl, twisted = Kyoto.twisted, side = Kyoto.side},
            picture = Picture.source,
            techlab = techLab and techLab:export() or nil,
            start = {m1 = Start.m1, settle = Start.settle, most = Start.most, anims = Start.anims},
            sideAuto = {dir = SideAuto.dir, delay = SideAuto.delay, cooldown = SideAuto.cooldown, anims = SideAuto.anims}}
    end
    -- returns true when the file was written
    local function saveConfig()
        if not writefile then return false, "Your executor cannot write files, so nothing can be saved." end
        local json = safe(function() return game:GetService("HttpService"):JSONEncode(buildSnapshot()) end)
        if type(json) ~= "string" then return false, "Could not turn the settings into a file." end
        if not pcall(writefile, CONFIG_FILE, json) then return false, "Your executor refused to write the file." end
        dirty = false
        SavedFrom = "file"
        refreshConfigStatus()
        return true
    end
    local function deleteConfig()
        local existed = isfile and safe(function() return isfile(CONFIG_FILE) end)
        if delfile and existed then
            pcall(delfile, CONFIG_FILE)
        elseif writefile then
            pcall(writefile, CONFIG_FILE, "")                  -- no delfile: an empty file counts as "no config"
        end
        SavedFrom = "none"
        refreshConfigStatus()
    end
    local pingLabel, gapsLabel

    local function currentPing()                       -- ms, or nil when unknown
        if Auto.manualPing > 0 then return Auto.manualPing end
        return PingState.model and PingState.model:value()
    end
    -- final wait for one step. o = that combo's options (nil = defaults): own gap or global gap, x speeds, then
    -- (auto timing on for this combo) the ping adjustment for gaps that wait for a visible cue
    local DefaultOpts = ComboOptions and ComboOptions.new()
    -- the ping adjustment alone, for one gap in seconds (o = combo options; nil = defaults)
    local function adjustGap(gap, dependent, o)
        o = o or DefaultOpts
        local autoOn = (o and ComboOptions) and ComboOptions.autoOn(Auto.on, o) or Auto.on
        if not (autoOn and PingModel) then return gap end
        return PingModel.adjustDelay(gap, currentPing(), Auto.strength, {dependent = dependent, offsetMs = Auto.offsetMs + (o and o.offsetMs or 0)})
    end
    local function stepDelay(kind, dependent, o)
        o = o or DefaultOpts
        local gap
        if o and ComboOptions then gap = ComboOptions.gap(kind, Timing, o, macroSpeed)
        else gap = Timing[kind] * macroSpeed end
        return adjustGap(gap, dependent, o)
    end

    do
        local function readPing()
            local item = safe(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"] end)
            local v = item and safe(function() return item:GetValue() end)
            if type(v) == "number" then return v end
        end
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
            if Backend then
                local open = Backend.isOpen()
                if open ~= menuOpen then menuOpen = open; if renderFab then renderFab() end end
            end
            if pingPill then
                local shown = currentPing()
                pingPill.Text = shown and (math.floor(shown + 0.5) .. " ms") or "-- ms"
                pingPill.TextColor3 = (shown and shown > 150) and Color3.fromRGB(255, 120, 120) or Theme.Good
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
    local assistBlockedUntil = 0 -- our own inputs must not re-trigger Assist: ignore triggers until this time
    local runningName            -- name of the combo currently playing (pinned buttons light up)
    local renderPins             -- assigned by the pinned-buttons manager below

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
    local KIND = {M1 = "m1", JUMP_M1 = "m1", JUMP = "jump", Q = "dash", FRONTDASH = "dash", BACKDASH = "dash", SIDEDASH = "dash", BEHINDDASH = "dash"}
    local function moveKey(tok, charName)
        local char = Data and Data.Characters[charName]
        local list = char and (char.moveList or char.moves)          -- moveList = hotbar order for characters whose moves carry stats
        if type(list) == "table" then
            for i, mv in ipairs(list) do
                if mv == tok then return MoveSlots[i] end
            end
        end
    end
    local function canPlay(tok, charName) return KIND[tok] ~= nil or moveKey(tok, charName) ~= nil end

    local function vec3(v)
        if v == nil then return nil end
        local x, y, z = v.X, v.Y, v.Z
        if type(x) == "number" and type(y) == "number" and type(z) == "number" then return {x = x, y = y, z = z} end
    end
    -- Which way a SIDEDASH goes. "Left" / "Right" are fixed; "Closest" looks at where the nearest player is
    -- compared with your camera and picks the side that moves you toward them. It only chooses between the A
    -- and D key - it never moves or teleports your character.
    local function resolveSide(mode)
        if mode == "Left" or mode == "Right" then return mode end
        local cam = workspace.CurrentCamera
        local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local right = cam and safe(function() return vec3(cam.CFrame.RightVector) end)
        local myPos = mine and safe(function() return vec3(mine.Position) end)
        if not (CombatMath and right and myPos) then return "Left" end
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local c = p.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                local pos = hrp and safe(function() return vec3(hrp.Position) end)
                local hp = hum and hum.Health
                if pos and (type(hp) ~= "number" or hp > 0) then list[#list + 1] = pos end
            end
        end
        local target = CombatMath.closest(myPos, list, 250)
        return (target and CombatMath.sideToward(myPos, right, target)) or "Left"
    end

    -- Dashes that go ROUND a player to reach his back (hits from behind cannot be blocked). They never move or teleport you:
    -- they only choose which direction key goes with Q. Movement keys are camera relative, so the camera is part of the maths.
    local behindDashKey
    do
    local function closestTarget()
        local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local myPos = mine and safe(function() return vec3(mine.Position) end)
        if not (CombatMath and myPos) then return nil end
        local best, bestD
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local c = p.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                local pos = hrp and safe(function() return vec3(hrp.Position) end)
                local hp = hum and hum.Health
                if pos and (type(hp) ~= "number" or hp > 0) then
                    local d = CombatMath.distance(myPos, pos)
                    if d and d > 0.001 and d <= 250 and (not bestD or d < bestD) then
                        best, bestD = {pos = pos, look = safe(function() return vec3(hrp.CFrame.LookVector) end)}, d
                    end
                end
            end
        end
        return best, myPos
    end
    -- the SIDE dash key (A or D - never W / S, those are the front and back dashes) for ONE dash round the closest player toward his
    -- back, and whether I am already behind him
    function behindDashKey()
        local target, myPos = closestTarget()
        local cam = workspace.CurrentCamera
        local camRight = cam and safe(function() return vec3(cam.CFrame.RightVector) end)
        if not (target and target.look and camRight) then return nil end
        local st = CombatMath.orbitStep(myPos, target.pos, target.look, camRight)
        if not st then return nil end
        local name = CombatMath.sideKey(st.dx, st.dz, camRight)
        return name and Enum.KeyCode[name], st.behind
    end
    end
    -- the key for a SIDEDASH step: Behind (round the closest player), Toward (at him), Left, Right
    local function sideDashKey(mode)
        if mode == "Left" then return Enum.KeyCode.A end
        if mode == "Right" then return Enum.KeyCode.D end
        if mode == "Toward" or mode == "Closest" then return resolveSide("Closest") == "Right" and Enum.KeyCode.D or Enum.KeyCode.A end
        return behindDashKey() or Enum.KeyCode.A                    -- nobody around: just dash left
    end

    -- plays one step; returns (kind of gap that follows it, whether that gap waits for a visible cue),
    -- or nil if the token cannot be played. o = this combo's options.
    local function playToken(tok, charName, o)
        local kind = KIND[tok]
        if tok == "M1" then click()
        elseif tok == "Q" then dash(nil)
        elseif tok == "FRONTDASH" then dash(Enum.KeyCode.W)
        elseif tok == "BACKDASH" then dash(Enum.KeyCode.S)
        elseif tok == "SIDEDASH" then dash(sideDashKey(o and o.side or "Behind"))
        elseif tok == "BEHINDDASH" then                                                  -- the round button: go round him, then (optionally) hit
            for i = 1, Behind.count do
                local key, already = behindDashKey()
                if not key or already then break end                                      -- nobody there / I am behind him already
                dash(key)
                if i < Behind.count then task.wait(Behind.gap) end
            end
            if Behind.m1 then
                task.wait(Behind.settle)                                                  -- let the last dash finish first
                local _, already = behindDashKey()
                if already then click() end                                               -- only if it worked: never hit from the front by accident
            end
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
        runningName = nil
        if renderPins then renderPins() end
    end
    onCleanup[#onCleanup + 1] = stopMacro

    -- lead (optional) = {kind, dependent}: wait out the gap that follows the step YOU just did, then play steps
    -- gaps (optional) = {[i] = seconds to wait after step i}: fixed waits for steps whose timing is not the generic "move" gap
    -- (e.g. the whirlwind dash must come "as early as possible"). They still follow the speed settings and the ping adjustment.
    local function runMacro(steps, charName, comboName, lead, gaps)
        if macroRunning then stopMacro() return end        -- tapping again stops it
        local function fixedGap(seconds, dependent, o)
            return adjustGap(seconds * macroSpeed * ((o and o.speed) or 1), dependent, o)
        end
        macroId = macroId + 1
        local myId = macroId
        macroRunning = true
        if Block.punch then Block.punch() end                -- our own inputs must not run into a held block
        runningName = comboName
        if renderPins then renderPins() end
        local opts = comboName and getOpts(comboName) or nil
        task.spawn(function()
            local ok, err = pcall(function()
                if lead then task.wait(lead.fixed and fixedGap(lead.fixed, lead.dependent, opts) or stepDelay(lead.kind, lead.dependent, opts)) end
                for i, tok in ipairs(steps) do
                    if myId ~= macroId then return end       -- stopped, or replaced by a newer macro
                    local kind, dependent = playToken(tok, charName, opts)
                    if kind then
                        local fixed = gaps and gaps[i]
                        task.wait(type(fixed) == "number" and fixedGap(fixed, dependent, opts) or stepDelay(kind, dependent, opts))
                    end
                end
            end)
            assistBlockedUntil = os.clock() + 0.6
            if myId == macroId then                            -- never clobber a newer macro's flag
                macroRunning = false
                runningName = nil
                if renderPins then renderPins() end
            end
            if not ok then warn("[Wraith Hub v1.5] macro failed: " .. tostring(err)) end
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

    ---------------------------------------------------------------- assist: arm a combo, YOU do the first move
    -- Arming a combo does NOT run it. It waits until you cast the trigger move yourself (by default the first
    -- move of the combo, e.g. Flowing Water for Kyoto, Hunter's Grasp for the Garou catch) and then plays
    -- everything that comes after it. Your cast is recognised from the keyboard (hotbar keys 1-4) or, for
    -- on-screen touch buttons, from the animation that move plays (taught once with "Learn trigger").
    local function shortLabel(name) return (name:gsub("_", " ")) end
    local ComboInfo = {}             -- name -> {steps, charName}, filled in when the cards are built
    local ArmHandles = {}            -- name -> card handle (keeps the Assist switch in step with the pinned button)
    local triggerOf, setArmed, startLearning     -- the only pieces the cards need; the rest lives in the block below
    do
    local learning, learnGen = nil, 0

    local function moveTester(charName) return function(tok) return moveKey(tok, charName) ~= nil end end
    function triggerOf(name)   -- index, token, options of the step YOU perform
        local info = ComboInfo[name]
        if not (info and Assist) then return nil end
        local o = getOpts(name)
        local idx = Assist.triggerIndex(info.steps, moveTester(info.charName), o and o.trigger)
        if not idx then return nil end
        return idx, info.steps[idx], o
    end
    local function gapKindOf(tok, charName)          -- (kind, dependent) of the gap that follows a step
        if KIND[tok] then return KIND[tok], KIND[tok] == "dash" end
        if moveKey(tok, charName) then return "move", true end
        return "m1", false
    end
    local function matchesToken(input, tok, charName)
        local kc = input.KeyCode
        if tok == "M1" then return input.UserInputType == Enum.UserInputType.MouseButton1 end
        if tok == "JUMP" or tok == "JUMP_M1" then return kc == Enum.KeyCode.Space end
        if KIND[tok] == "dash" then
            if kc ~= Enum.KeyCode.Q then return false end
            local function down(k) return UserInputService:IsKeyDown(k) end
            if tok == "FRONTDASH" then return down(Enum.KeyCode.W) end
            if tok == "BACKDASH" then return down(Enum.KeyCode.S) end
            if tok == "SIDEDASH" then return down(Enum.KeyCode.A) or down(Enum.KeyCode.D) end
            return not (down(Enum.KeyCode.W) or down(Enum.KeyCode.A) or down(Enum.KeyCode.S) or down(Enum.KeyCode.D))
        end
        local key = moveKey(tok, charName)
        return key ~= nil and kc == key
    end

    local function startAssist(name)
        if macroRunning or os.clock() < assistBlockedUntil then return end
        local idx, trigTok = triggerOf(name)
        if not idx then return end
        local info = ComboInfo[name]
        local rest = Assist.remaining(info.steps, idx)
        if not rest then return end
        local kind, dependent = gapKindOf(trigTok, info.charName)
        local restGaps, leadGap
        if info.gaps then                                 -- fixed waits, indexed by the FULL step list: shift them to the steps after the trigger
            restGaps = {}
            for i = idx + 1, #info.steps do restGaps[i - idx] = info.gaps[i] end
            leadGap = info.gaps[idx]
        end
        runMacro(rest, info.charName, name, {kind = kind, dependent = dependent, fixed = leadGap}, restGaps)
    end

    -- START WITH M1: every M1 you throw is counted; when you stop (or reach the tech's own M1 count) the newest armed tech plays the rest
    local m1Pending, lastM1Input = nil, -10
    local function userM1(now)
        if #armedOrder == 0 then m1Pending = nil return end
        local prev = m1Pending
        m1Pending = {count = Assist.m1Count(prev and prev.count, prev and prev.last, now, 0.8), last = now}
    end
    local function newestM1Tech()                     -- the newest armed tech that has something left to play after your M1s
        return Assist.pick(armedOrder, function(n)
            local info = ComboInfo[n]
            return info ~= nil and Assist.afterM1(info.steps) ~= nil
        end)
    end
    local function startAssistM1(name)
        if macroRunning then return end
        local info = ComboInfo[name]
        local rest, k = Assist.afterM1(info and info.steps)
        if not rest then return end
        local restGaps, leadGap
        if info.gaps then                              -- fixed waits are indexed by the FULL step list
            restGaps = {}
            for i = k + 1, #info.steps do restGaps[i - k] = info.gaps[i] end
            leadGap = k > 0 and info.gaps[k] or nil
        end
        runMacro(rest, info.charName, name, {kind = "m1", dependent = false, fixed = leadGap}, restGaps)
    end
    connect(RunService.Heartbeat, function()
        local p = m1Pending
        if not p then return end
        if macroRunning or #armedOrder == 0 or not Start.m1 then m1Pending = nil return end
        local name = newestM1Tech()
        if not name then m1Pending = nil return end
        if Assist.m1Ready(p.count, p.last, os.clock(), Assist.m1Cap(ComboInfo[name].steps, Start.most), Start.settle) then
            m1Pending = nil
            startAssistM1(name)
        end
    end)

    function setArmed(name, on)
        on = on and true or false
        if (Armed[name] == true) == on then return end
        Armed[name] = on or nil
        for i, n in ipairs(armedOrder) do if n == name then table.remove(armedOrder, i) break end end
        if on then armedOrder[#armedOrder + 1] = name end
        if ArmHandles[name] then ArmHandles[name]:SetArmed(on) end
        if renderPins then renderPins() end
        if ready then
            local idx, trigTok = triggerOf(name)
            local info = ComboInfo[name]
            if not on then toast(shortLabel(name) .. " disarmed")
            elseif Start.m1 and info and Assist.afterM1(info.steps) then
                toast(shortLabel(name) .. " armed - throw 1-" .. Assist.m1Cap(info.steps, Start.most) .. " M1s, I do the rest")
            elseif idx and info and Assist.remaining(info.steps, idx) then
                toast(shortLabel(name) .. " armed - cast " .. shortLabel(trigTok) .. " yourself, I do the rest")
            else toast(shortLabel(name) .. " has nothing after its trigger step") end
        end
    end
    onCleanup[#onCleanup + 1] = function() armedOrder = {}; Armed = {} end

    -- auto side dash: after one of YOUR moves (hotbar key, or an animation you taught it) it dashes sideways
    local lastSideAuto, lastSide = 0, nil
    local function performSideAuto()
        local now = os.clock()
        if now - lastSideAuto < SideAuto.cooldown then return end
        lastSideAuto = now
        local alt
        if SideAuto.dir == "Alternate" then alt = Assist.nextSide("Alternate", lastSide); lastSide = alt end
        task.spawn(function()
            task.wait(adjustGap(SideAuto.delay, true, nil))
            if not (alive and SideAuto.on) or macroRunning then return end
            dash(alt and (alt == "Right" and Enum.KeyCode.D or Enum.KeyCode.A) or sideDashKey(SideAuto.dir))   -- chosen when it happens: positions change
            assistBlockedUntil = os.clock() + 0.5
        end)
    end

    local function isSlotKey(kc)
        for _, k in ipairs(MoveSlots) do if k == kc then return true end end
        return false
    end
    connect(UserInputService.InputBegan, function(input, gp)
        if gp or macroRunning or os.clock() < assistBlockedUntil then return end
        if Start.m1 then
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                lastM1Input = os.clock()
                userM1(lastM1Input)
            elseif isSlotKey(input.KeyCode) or input.KeyCode == Enum.KeyCode.Q then
                m1Pending = nil                         -- you are doing something else: do not take over
            end
        elseif #armedOrder > 0 then
            local name = Assist.pick(armedOrder, function(n)
                local idx, tok = triggerOf(n)
                return idx ~= nil and matchesToken(input, tok, ComboInfo[n].charName)
            end)
            if name then startAssist(name) return end
        end
        if SideAuto.on and isSlotKey(input.KeyCode) then performSideAuto() end
    end)

    -- touch players: the game's own skill buttons are not keyboard keys, so watch the animation your move plays
    local function shortId(id) return (id:gsub("^rbxassetid://", "")) end
    local function onAnimationPlayed(track)
        local id = safe(function() return track.Animation.AnimationId end)
        if type(id) ~= "string" or id == "" or #id > 120 then return end
        if safe(function() return track.Looped end) == true then return end        -- walking / idle loops are not moves
        if learning and learning.kind == "m1" then       -- teaching your M1 animations: collect everything you play for a few seconds
            local n = 0
            for _ in pairs(Start.anims) do n = n + 1 end
            if n < 12 and not Start.anims[id] then Start.anims[id] = true; markDirty() end
            learning.n = (learning.n or 0) + 1
            return
        end
        if learning then
            local what = learning
            learning = nil
            learnGen = learnGen + 1
            if what.kind == "combo" then
                local o = getOpts(what.name)
                if o then o.trigAnim = id; markDirty() end
                toast("Learned the trigger for " .. shortLabel(what.name))
            else
                local n = 0
                for _ in pairs(SideAuto.anims) do n = n + 1 end
                if n < 24 then SideAuto.anims[id] = true; markDirty() end
                toast("Learned a move for auto side dash (" .. shortId(id) .. ")")
            end
            return
        end
        if macroRunning or os.clock() < assistBlockedUntil then return end
        if Start.m1 then
            local now = os.clock()
            if Start.anims[id] and now - lastM1Input > 0.25 then userM1(now) end    -- a touch player's M1 (a keyboard M1 was counted already)
        else
            local name = Assist.pick(armedOrder, function(n)
                local o = getOpts(n)
                return o ~= nil and o.trigAnim ~= "" and o.trigAnim == id
            end)
            if name then startAssist(name) return end
        end
        if SideAuto.on and SideAuto.anims[id] then performSideAuto() end
    end
    function startLearning(kind, name, hint)
        learning = {kind = kind, name = name, n = 0}
        learnGen = learnGen + 1
        local mine = learnGen
        toast(hint)
        task.spawn(function()
            task.wait(kind == "m1" and 4 or 10)
            if learning and mine == learnGen and alive then
                local l = learning
                learning = nil
                if kind == "m1" then
                    toast(l.n > 0 and ("Learned your M1 animation(s): " .. l.n .. " played") or "I saw no animation - tap again and throw four M1s")
                else
                    toast("Learning timed out - tap Learn again")
                end
            end
        end)
    end
    local function hookCharacter(char)
        task.spawn(function()
            local hum = char:WaitForChild("Humanoid", 10)
            local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 10))
            if animator and alive then connect(animator.AnimationPlayed, onAnimationPlayed) end
        end)
    end
    if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
    connect(LocalPlayer.CharacterAdded, hookCharacter)
    end

    ---------------------------------------------------------------- auto block
    -- Blocks EVERY hit and lets go again quickly so you can punch:
    --   * another player in front of you starts an attack aimed at you -> F goes down, is held through the hit,
    --     and is released a moment after their attack ends
    --   * the next hit of a combo extends the hold, so there is no gap - but never longer than "Longest hold"
    --   * the moment YOU press M1 or a move key, the block drops and does not come back for a split second
    -- WHEN F goes down: the first time an attack animation is seen it uses your "Delay". Every time one of those
    -- animations actually hurts you, the script times "animation start -> damage" and remembers it (kept only with Save config; between
    -- sessions). From then on F goes down just before that hit ("Perfect lead"), minus your ping - that is the
    -- prediction. "Predict chain hits" also remembers which animation follows which (M1 1 -> 2 -> 3) and blocks the
    -- NEXT punch of a chain before its animation even shows up.
    -- Only attacks that CAN be blocked are answered: in range, aimed at you, in front of you (hits from behind always
    -- connect, charged hits and grabs ignore block).
    do
        local state = BlockState and BlockState.new(Block)           -- reads Block.grace / maxHold / minHold / punchPause live
        local lastSwing = setmetatable({}, {__mode = "k"})
        local pollTargets = {}                                      -- player -> that player's Animator (checked 10x a second as a backup)
        -- Is the block really up? The hub learns what changes on you while you block (see block_sense.lua). Once it knows, a press
        -- that did not take (your own M1 lockout, a stun, a dropped input) is repeated instead of letting the hit through.
        local verify                                                -- {due, tries, rest, hurt, repressAt} for the press being checked
        local function snapshotMe()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return nil end
            local snap = {ws = safe(function() return hum.WalkSpeed end), attrs = {}, tracks = {}}
            local attrs = safe(function() return char:GetAttributes() end)
            if type(attrs) == "table" then for k, v in pairs(attrs) do snap.attrs[k] = v end end
            local animator = safe(function() return hum:FindFirstChildOfClass("Animator") end)
            local list = animator and safe(function() return animator:GetPlayingAnimationTracks() end)
            if type(list) == "table" then
                for _, tr in ipairs(list) do
                    local id = safe(function() return tr.Animation.AnimationId end)
                    if type(id) == "string" then snap.tracks[id] = true end
                end
            end
            return snap
        end
        local function apply(action)
            if action == "press" then
                if Sense and Block.verify and not Block.senseOff then
                    verify = {due = os.clock() + 0.12, tries = 0, rest = snapshotMe(), hurt = false}
                end
                keyEvent(true, Enum.KeyCode.F)
            elseif action == "release" then
                verify = nil
                keyEvent(false, Enum.KeyCode.F)
            end
        end
        local function verifyTick(now)
            local v = verify
            if not v then return end
            if not (state and state.holding) then verify = nil return end
            if v.repressAt then
                if now >= v.repressAt then
                    v.repressAt = nil; v.tries = v.tries + 1; v.due = now + 0.12
                    keyEvent(true, Enum.KeyCode.F)
                end
                return
            end
            if now < v.due then return end
            local snap = snapshotMe()
            if not snap then verify = nil return end
            if Sense:ready() then
                if Sense:isUp(snap) then
                    Block.stats.senseOk = Block.stats.senseOk + 1
                    verify = nil
                elseif v.tries < 2 then
                    Block.stats.retries = Block.stats.retries + 1
                    keyEvent(false, Enum.KeyCode.F)                 -- let go and press again
                    v.repressAt = now + 0.03
                else
                    Block.stats.senseMiss = Block.stats.senseMiss + 1
                    verify = nil
                    if Block.stats.senseOk == 0 and Block.stats.senseMiss >= 3 then Block.senseOff = true end   -- it never sees the block: stop second-guessing it
                end
            else
                if not v.hurt and v.rest then Sense:observe(v.rest, snap) end   -- still learning what blocking looks like
                verify = nil
            end
        end
        -- seconds from now until F should go down to be up at `hitIn` seconds from now (minus lead and ping)
        local function pressIn(hitIn)
            local base = math.max(hitIn - Block.lead, 0)
            if not (Block.usePing and PingModel) then return base end
            return PingModel.adjustDelay(base, currentPing(), Auto.strength, {dependent = true, offsetMs = Auto.offsetMs, minDelay = 0, maxFraction = 0.8})
        end
        -- an attack that ignores block: a side dash away from the closest player, timed like the block would have been
        local dodgeUntil = 0
        local function dodge(hitIn)
            local now = os.clock()
            if now < dodgeUntil or macroRunning then return end
            dodgeUntil = now + 1.0                                    -- the dash has its own cooldown; never spam it
            local wait = pressIn(hitIn)
            task.spawn(function()
                task.wait(wait)
                if not (alive and Block.on) or macroRunning or isKnocked(LocalPlayer.Character) then return end
                dash(resolveSide("Closest") == "Right" and Enum.KeyCode.A or Enum.KeyCode.D)
            end)
        end
        -- every attack the hub sees ends in one verdict, kept as text for the Tech tab: a miss can be understood, not guessed at
        local WHY = {far = "too far away", unaimed = "not aimed at you", behind = "he is behind you (F cannot cover that)", unknown = "could not read positions"}
        local function decide(verdict, why, who, label)
            local st = Block.stats
            st.seen = st.seen + 1
            if verdict == "block" then st.blocked = st.blocked + 1 elseif why then st.why[why] = (st.why[why] or 0) + 1 end
            Block.lastDecision = string.format("%s '%s' -> %s%s", who, label, verdict, why and (" (" .. why .. ")") or "")
        end
        local function summary()
            local st = Block.stats
            local parts = {}
            for why, n in pairs(st.why) do parts[#parts + 1] = n .. "x " .. why end
            table.sort(parts)
            return string.format("Last: %s. Seen %d attacks: %d answered%s%s%s.", Block.lastDecision, st.seen, st.blocked,
                #parts > 0 and (", " .. table.concat(parts, ", ")) or "",
                st.rush > 0 and (", " .. st.rush .. " pre-block(s) on rushers") or "",
                st.retries > 0 and (", " .. st.retries .. " press(es) repeated because the block was not up") or "")
        end
        Block.summary = summary
        -- Predict the punch: somebody running / dashing straight at you is about to throw one. A reactive block only starts when his
        -- animation reaches you, a whole round trip (your ping) later - for a first hit that is often too late, so F goes down as he arrives.
        local lastRush = setmetatable({}, {__mode = "k"})
        local function rushCheck(now)
            local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local mp = mine and safe(function() return vec3(mine.Position) end)
            if not mp or isKnocked(LocalPlayer.Character) then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and not (lastRush[p] and now - lastRush[p] < 0.8) then
                    local theirs = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    local snap = theirs and safe(function()
                        return {mp = mp, ml = vec3(mine.CFrame.LookVector), mv = vec3(mine.AssemblyLinearVelocity),
                                tp = vec3(theirs.Position), tl = vec3(theirs.CFrame.LookVector), tv = vec3(theirs.AssemblyLinearVelocity)}
                    end)
                    local eta = snap and snap.tv and CombatMath.rushing(mp, snap.tp, snap.tv, {range = Block.range})
                    if eta and eta <= 0.45 then
                        snap.range, snap.aim, snap.hitIn = Block.range, Block.aim, eta + 0.2
                        if CombatMath.assess(snap) == "block" then
                            lastRush[p] = now
                            state:threat(now, math.max(eta - 0.05, 0), 0.5)
                            Block.stats.rush = Block.stats.rush + 1
                            decide("block", nil, tostring(safe(function() return p.DisplayName end) or "?"), "rushing at you (pre-block)")
                        end
                    end
                end
            end
        end
        local seenTracks = setmetatable({}, {__mode = "k"})       -- the event AND the polling below see the same track: act once
        local function onEnemyAnimation(player, track, fromPoll)
            if not (CombatMath and state) then return end
            if seenTracks[track] then return end
            seenTracks[track] = true
            if not (Block.on or Block.learn) or macroRunning then return end
            local now = os.clock()
            local elapsed = safe(function() return track.TimePosition end)
            if type(elapsed) ~= "number" or elapsed < 0 then elapsed = 0 end
            if fromPoll and elapsed > 0.35 then return end                                     -- already well under way: not a new attack
            if safe(function() return track.Looped end) == true then return end                -- walk / idle loops
            local animName = safe(function() return track.Animation.Name end)
            if type(animName) ~= "string" or animName == "" then animName = safe(function() return track.Name end) end
            if type(animName) ~= "string" then animName = "" end
            local id = safe(function() return track.Animation.AnimationId end)
            if type(id) ~= "string" then id = nil end
            local kind = BlockInfo and BlockInfo.classify(animName)
            local learnedHit = Learner and id and Learner:offset(id)
            -- idle / movement layers are not attacks - unless the name or what hurt me before says this one is
            local prio = safe(function() return track.Priority.Value end)
            local minPrio = safe(function() return Enum.AnimationPriority.Action.Value end)
            if type(prio) == "number" and type(minPrio) == "number" and prio < minPrio and not (learnedHit or kind) then return end
            local key = tostring(id or animName)
            local last = lastSwing[player]
            if last and last.key == key and now - last.t < 0.12 then return end                -- the same swing seen twice
            local otherRecent = last and now - last.t < 0.12                                    -- another track of the same swing
            local chained = last ~= nil and now - last.t >= 0.12 and now - last.t <= 1.0         -- his next hit in a combo: stay up between hits
            lastSwing[player] = {key = key, t = now}
            local who = tostring(safe(function() return player.DisplayName end) or "?")
            local label = animName ~= "" and animName or (id and id:match("%d+")) or "?"

            local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local theirs = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not (mine and theirs) then return end
            local snap = safe(function()
                return {mp = vec3(mine.Position), ml = vec3(mine.CFrame.LookVector), mv = vec3(mine.AssemblyLinearVelocity),
                        tp = vec3(theirs.Position), tl = vec3(theirs.CFrame.LookVector), tv = vec3(theirs.AssemblyLinearVelocity)}
            end)
            if not snap then return end
            local hitIn = math.max((learnedHit or 0.2) - elapsed, 0)
            snap.range, snap.aim, snap.hitIn = Block.range, Block.aim, hitIn
            local verdict = CombatMath.assess(snap)
            if verdict ~= "block" then decide("ignored", WHY[verdict] or verdict, who, label) return end

            local length = safe(function() return track.Length end)                             -- how long their swing lasts
            if type(length) ~= "number" or length <= 0 then length = nil end
            if Learner and Block.learn and id and not otherRecent then Learner:swing(player, id, now - elapsed, length) end
            if not Block.on then decide("learning only", nil, who, label) return end
            if isKnocked(LocalPlayer.Character) then decide("ignored", "you are ragdolled / stunned", who, label) return end

            local pierces = (Learner and id and Learner:isPierce(id)) or (BlockInfo and BlockInfo.ignoresBlock(kind))
            if pierces and Block.pierceMode ~= "block" then                                     -- F is wasted on it
                if Block.pierceMode == "dash" then
                    dodge(hitIn)
                    decide("side dash", "known to ignore block", who, label)
                else
                    decide("skipped", "known to ignore block", who, label)
                end
                return
            end
            local learned = Learner and Block.useLearned and learnedHit
            if learned then
                local hit = learned - elapsed
                if hit < -0.05 then decide("ignored", "its hit already landed", who, label) return end
                state:threat(now, pressIn(math.max(hit, 0)), Block.lead + 0.10, chained and Block.chainGrace or nil)   -- down just before the hit, up just after
            else
                local delay = math.max(Block.delay - elapsed, 0)
                if Block.usePing and PingModel then
                    delay = PingModel.adjustDelay(delay, currentPing(), Auto.strength, {dependent = true, offsetMs = Auto.offsetMs, minDelay = 0})
                end
                state:threat(now, delay, math.max(math.min((length or 0.35) - elapsed, 1.2), 0.1), chained and Block.chainGrace or nil)
            end
            if Block.chain and Learner and id then                                               -- predict the NEXT punch of the chain
                local nextId, gap, seen = Learner:next(id)
                local nextHit = nextId and seen >= 3 and Learner:offset(nextId)
                if nextHit then state:threat(now, pressIn(gap + nextHit), Block.lead + 0.10, Block.chainGrace) end
            end
            decide("block", nil, who, label)
        end
        -- every time you lose health, learn how long after which enemy animation it happened
        local function hookMyHealth(char)
            task.spawn(function()
                local hum = char:WaitForChild("Humanoid", 10)
                if not (hum and alive) then return end
                local last = hum.Health
                connect(hum.HealthChanged, function(h)
                    if verify and type(h) == "number" and type(last) == "number" and h < last - 0.01 then verify.hurt = true end   -- a hit would muddy what we learn
                    if type(h) == "number" and type(last) == "number" and h < last - 0.01 and Learner and Block.learn then
                        local now = os.clock()
                        local heldFor = (state and state.holding and state.holdStart) and (now - state.holdStart) or 0
                        local id, offset = Learner:damage(now)
                        if id then
                            markDirty(); Block.lastLearned = {id = id, offset = offset}
                            -- F was already down for ping + 60 ms (so the server had it up before the hit) and it still hurt:
                            -- this attack ignores block (grab, downslam, charged hit, unblockable move)
                            if heldFor >= (currentPing() or 0) / 1000 + 0.06 then Learner:pierced(id) end
                        end
                    end
                    last = h
                end)
            end)
        end
        if LocalPlayer.Character then hookMyHealth(LocalPlayer.Character) end
        connect(LocalPlayer.CharacterAdded, hookMyHealth)

        -- how much time is left to react: a normal M1 lands ~0.18 s after it starts, and its animation reaches you a whole round trip later
        local function budgetText()
            local ping = currentPing()
            local m1 = (((Data and Data.Mechanics and Data.Mechanics.m1StartupFramesSaitama) or 11) / 60) * 1000
            if not ping then return "Reaction time: your ping is not known yet." end
            local left = m1 - ping - Block.delay * 1000
            return string.format("Reaction time: a basic M1 lands ~%d ms after it starts; your ping is %d ms, so ~%d ms are left to press F.%s", math.floor(m1 + 0.5),
                math.floor(ping + 0.5), math.floor(math.max(left, 0) + 0.5),
                left < 60 and "  That is too little for the FIRST hit of a combo, so rely on 'Pre-block rushers' and 'Stay blocked between hits' (the later hits are covered)." or "")
        end
        local function senseText()
            if not Sense then return "Block check: not available." end
            local st = Block.stats
            if not Block.verify then return "Block check: off." end
            if Block.senseOff then return "Block check: switched off - the block never seemed to come up, so I stopped second-guessing it (Forget to retry)." end
            if Sense:ready() then
                return string.format("Block check: I know what blocking looks like (%s). Confirmed %d, pressed again %d time(s).", Sense:describe(), st.senseOk, st.retries)
            end
            return "Block check: still learning what blocking looks like - it watches your next presses (or press the Teach button)."
        end
        Block.budgetText, Block.senseText = budgetText, senseText
        local teaching = false
        -- stand still and press the Teach button: three short blocks, compared with the moments before - that is how it learns
        Block.teach = function()
            if teaching or not Sense or macroRunning then return end
            if Block.on and state and state.holding then toast("Wait until the block lets go, then try again") return end
            teaching = true
            task.spawn(function()
                for _ = 1, 3 do
                    local rest = snapshotMe()
                    keyEvent(true, Enum.KeyCode.F)
                    task.wait(0.35)
                    local snap = snapshotMe()
                    keyEvent(false, Enum.KeyCode.F)
                    task.wait(0.45)
                    if rest and snap then Sense:observe(rest, snap) end
                    if not alive then break end
                end
                teaching = false
                Block.senseOff = false
                toast(Sense:ready() and "Learned what blocking looks like" or "I could not see anything change when you block - stand still, out of a fight, and try again")
            end)
        end
        Block.forgetSense = function()
            if Sense then Sense:forget() end
            Block.senseOff = false
            Block.stats.senseOk, Block.stats.senseMiss, Block.stats.retries = 0, 0, 0
            markDirty()
        end

        -- the floater: a small round indicator you can drag anywhere. Ring colour = state (grey off, green armed,
        -- pink while F is held). Tap it to switch Auto block on / off. The Lock button freezes it with the other buttons.
        local floater, floaterRing, shown
        local fTracker = DragTracker and DragTracker.new(8)
        do
            local vw, vh = viewport()
            local fx = Block.floaterPos and Block.floaterPos.x or 14
            local fy = Block.floaterPos and Block.floaterPos.y or math.floor((vh or 450) / 2 - 32)
            floater = new("TextButton", {
                Text = "BLOCK\nOFF", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Text, TextWrapped = true,
                BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.1, AutoButtonColor = false,
                Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(fx, fy), ZIndex = 9, Visible = Block.floater, Parent = Gui,
            }, {corner(32), gloss(nil, 32, 1)})
            floaterRing = stroke(Theme.SubText, 2.2, 0.15)
            floaterRing.Parent = floater
            local fScale = new("UIScale", {Scale = 0, Parent = floater})
            tween(fScale, {Scale = 1}, 0.5, Enum.EasingStyle.Back)
            local function place()
                if DragTracker and vw then
                    fx, fy = DragTracker.clamp(fx, fy, 64, 64, vw, vh, 4)
                end
                floater.Position = UDim2.fromOffset(fx, fy)
                Block.floaterPos = {x = fx, y = fy}
            end
            place()
            floater.InputBegan:Connect(function(i)
                if fTracker and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
                    fTracker:begin(i.Position.X, i.Position.Y, fx, fy)
                end
            end)
            floater.MouseButton1Down:Connect(function() tween(fScale, {Scale = 0.92}, 0.08) end)
            floater.MouseButton1Up:Connect(function() tween(fScale, {Scale = 1}, 0.2, Enum.EasingStyle.Back) end)
            floater.MouseButton1Click:Connect(function()
                if fTracker and fTracker:suppressClick(os.clock()) then return end              -- that "click" ended a drag
                if Block.flip then Block.flip() end
            end)
            connect(UserInputService.InputChanged, function(i)
                if not fTracker then return end
                if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
                local nx, ny = fTracker:move(i.Position.X, i.Position.Y)
                if nx then fx, fy = nx, ny; place() end
            end)
            connect(UserInputService.InputEnded, function(i)
                if fTracker and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
                    local moved = fTracker.moved
                    fTracker:finish(os.clock())
                    if moved then markDirty() end
                end
            end)
            local cam = workspace.CurrentCamera
            local vsig = cam and safe(function() return cam:GetPropertyChangedSignal("ViewportSize") end)
            if vsig then connect(vsig, place) end
        end
        local function paintFloater()
            local mode = (not Block.on) and "off" or (state and state.holding and "hold" or "ready")
            if mode == shown then return end
            shown = mode
            floater.Text = mode == "off" and "BLOCK\nOFF" or (mode == "hold" and "BLOCK\nHOLD" or "BLOCK\nREADY")
            tween(floaterRing, {Color = mode == "off" and Theme.SubText or (mode == "hold" and Theme.Accent or Theme.Good)}, 0.15)
            tween(floater, {BackgroundColor3 = mode == "hold" and Theme.Accent or Theme.Panel}, 0.12)
            floater.TextColor3 = mode == "hold" and Theme.Ink or Theme.Text
        end
        local learnTimer, pollTimer = 0, 0
        connect(RunService.Heartbeat, function(dt)
            if state then apply(state:tick(os.clock())) end
            paintFloater()
            if Sense then verifyTick(os.clock()) end
            pollTimer = pollTimer + dt
            if pollTimer >= 0.1 then                          -- backup for animations that never fire AnimationPlayed
                pollTimer = 0
                if Block.on and Block.rush and CombatMath and not macroRunning then rushCheck(os.clock()) end
                if Block.on or Block.learn then
                    for player, animator in pairs(pollTargets) do
                        local list = safe(function() return animator:GetPlayingAnimationTracks() end)
                        if type(list) == "table" then
                            for _, tr in ipairs(list) do onEnemyAnimation(player, tr, true) end
                        end
                    end
                end
            end
            learnTimer = learnTimer + dt
            if learnTimer >= 0.5 then
                learnTimer = 0
                if Block.decisionLabel and Block.summary then Block.decisionLabel.Text = Block.summary() end
                if Block.budgetLabel then Block.budgetLabel.Text = budgetText() end
                if Block.senseLabel then Block.senseLabel.Text = senseText() end
                local lbl = Block.learnLabel
                if lbl and Learner then
                    local animCount, hitCount, ignoring = Learner:stats()
                    local last = Block.lastLearned
                    lbl.Text = string.format("Learned: %d attack animation(s) from %d hit(s) you took.%s%s", animCount, hitCount,
                        last and string.format("  Last: hit %d ms after the swing started.", math.floor(last.offset * 1000 + 0.5)) or "",
                        ignoring > 0 and string.format("  %d of them ignore block.", ignoring) or "")
                end
            end
        end)
        -- you want to hit: your M1 or a move key drops the block right now
        connect(UserInputService.InputBegan, function(input, gp)
            if gp or not (Block.on and state) then return end
            local punching = input.UserInputType == Enum.UserInputType.MouseButton1
            if not punching then
                for _, k in ipairs(MoveSlots) do if k == input.KeyCode then punching = true end end
            end
            if punching then apply(state:punch(os.clock())) end
        end)
        Block.reset = function() if state then apply(state:reset()) end end      -- switched off: let go of F
        Block.punch = function() if state then apply(state:punch(os.clock())) end end   -- a combo / assist starts: let go of F
        Block.setLocked = function(v) if fTracker then fTracker:setLocked(v) end end
        Block.setFloaterVisible = function(v) floater.Visible = v and true or false end
        local function hookEnemy(player)
            if player == LocalPlayer then return end
            local function hookChar(char)
                task.spawn(function()
                    local hum = char:WaitForChild("Humanoid", 10)
                    local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 10))
                    if animator and alive then
                        pollTargets[player] = animator
                        connect(animator.AnimationPlayed, function(track) onEnemyAnimation(player, track) end)
                    end
                end)
            end
            if player.Character then hookChar(player.Character) end
            connect(player.CharacterAdded, hookChar)
        end
        for _, p in ipairs(Players:GetPlayers()) do hookEnemy(p) end
        connect(Players.PlayerAdded, hookEnemy)
        connect(Players.PlayerRemoving, function(p) pollTargets[p] = nil end)
        onCleanup[#onCleanup + 1] = function() Block.on = false; Block.reset() end
    end

    ---------------------------------------------------------------- pinned on-screen buttons
    -- Turn a combo's "On screen" switch on and a button for it appears on your screen. Tap it to run the combo
    -- (tap again to stop), drag it anywhere, the Lock button on the floating bar pins them in place, and the
    -- Pins button on the bar hides / shows all of them. Pinned combos and their positions are only kept if you press Save config.
    local PinLayer = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8, Parent = Gui})
    local pinOrder = {}                            -- Pins: name -> {btn, scale, stroke, tracker, x, y}
    local pinsVisible, pinsLocked = true, false
    local PIN_W, PIN_H = 74, 58

    local function pinDefaultPos(index)
        local vw, vh = viewport()
        vw, vh = vw or 800, vh or 450
        local perColumn = math.max(1, math.floor((vh - 90) / (PIN_H + 8)))
        local col, row = math.floor((index - 1) / perColumn), (index - 1) % perColumn
        return vw - PIN_W - 12 - col * (PIN_W + 8), 70 + row * (PIN_H + 8)
    end
    local function placePin(p)
        local vw, vh = viewport()
        if DragTracker and vw then p.x, p.y = DragTracker.clamp(p.x, p.y, p.w or PIN_W, p.h or PIN_H, vw, vh, 4) end
        p.btn.Position = UDim2.fromOffset(p.x, p.y)
    end
    renderPins = function()
        for name, p in pairs(Pins) do
            local o = getOpts(name)
            local assistMode = o == nil or o.pinMode ~= "run"
            local running = runningName == name
            local armed = Armed[name] == true
            local lit = running or (assistMode and armed)
            tween(p.btn, {BackgroundColor3 = running and Theme.Accent or (lit and Theme.Hover or Theme.Panel)}, 0.18)
            tween(p.stroke, {Transparency = lit and 0 or 0.4}, 0.18)
            p.btn.TextColor3 = running and Theme.Ink or Theme.Text
            p.dot.Visible = assistMode
            tween(p.dot, {BackgroundColor3 = armed and Theme.Good or Theme.SubText}, 0.18)
            p.btn.Visible = pinsVisible
        end
    end
    local function setPinsLocked(v)
        pinsLocked = v and true or false
        if Block.setLocked then Block.setLocked(pinsLocked) end
        for _, p in pairs(Pins) do if p.tracker then p.tracker:setLocked(pinsLocked) end end
    end
    local function setPinsVisible(v)
        pinsVisible = v and true or false
        renderPins()
        if renderFab then renderFab() end
    end

    local function setPinned(name, on, steps, charName, shape, caption)
        local p = Pins[name]
        if not on then
            if p then
                tween(p.scale, {Scale = 0}, 0.18)
                local btn = p.btn
                task.spawn(function() task.wait(0.2); btn:Destroy() end)
                Pins[name] = nil
                SavedPins[name] = nil                     -- forget it, or the saved file would bring it back
                for i, n in ipairs(pinOrder) do if n == name then table.remove(pinOrder, i) break end end
                if ready then toast(shortLabel(name) .. " removed from screen") end
                markDirty()
                if renderFab then renderFab() end               -- (the bar counts the pins)
            end
            return
        end
        if p then return end
        pinOrder[#pinOrder + 1] = name
        local pos = SavedPins[name]
        local x, y
        if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
            x, y = pos.x, pos.y
        else
            x, y = pinDefaultPos(#pinOrder)
        end
        local circle = shape == "circle"
        local pw, ph = PIN_W, PIN_H
        if circle then pw, ph = 70, 70 end
        local radius = circle and 35 or 16
        local btn = new("TextButton", {
            Text = caption or shortLabel(name), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Text,
            TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
            BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.12, AutoButtonColor = false,
            Size = UDim2.fromOffset(pw, ph), Visible = pinsVisible, Parent = PinLayer,
        }, {corner(radius), new("UIPadding", {PaddingLeft = UDim.new(0, circle and 12 or 6), PaddingRight = UDim.new(0, circle and 12 or 6)}), gloss(nil, radius, 1)})
        local pinStroke = stroke(Theme.Accent, 1.6, 0.35)
        pinStroke.Parent = btn
        local pinDot = new("Frame", {                   -- green = armed (Assist mode only)
            Size = UDim2.fromOffset(9, 9), Position = circle and UDim2.new(0.5, -4, 0, 5) or UDim2.new(1, -16, 0, 7), BackgroundColor3 = Theme.SubText,
            BorderSizePixel = 0, ZIndex = 3, Parent = btn,
        }, {corner(5)})
        local scale = new("UIScale", {Scale = 0, Parent = btn})
        p = {btn = btn, scale = scale, stroke = pinStroke, dot = pinDot, x = x, y = y, w = pw, h = ph}
        p.tracker = DragTracker and DragTracker.new(8)
        if p.tracker then p.tracker:setLocked(pinsLocked) end
        Pins[name] = p
        placePin(p)
        tween(scale, {Scale = 1}, 0.35, Enum.EasingStyle.Back)

        btn.InputBegan:Connect(function(i)
            if p.tracker and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
                p.tracker:begin(i.Position.X, i.Position.Y, p.x, p.y)
            end
        end)
        btn.MouseButton1Down:Connect(function() tween(scale, {Scale = 0.92}, 0.08) end)
        btn.MouseButton1Up:Connect(function() tween(scale, {Scale = 1}, 0.2, Enum.EasingStyle.Back) end)
        btn.MouseButton1Click:Connect(function()
            if p.tracker and p.tracker:suppressClick(os.clock()) then return end     -- that "click" ended a drag
            local o = getOpts(name)
            if o and o.pinMode == "run" then runMacro(steps, charName, name)      -- run mode: play the whole combo
            else setArmed(name, not Armed[name]) end                              -- assist mode: arm / disarm
        end)
        renderPins()
        if ready then
            local o = getOpts(name)
            toast(shortLabel(name) .. ((o and o.pinMode == "run") and " pinned - tap it to run" or " pinned - tap it to arm Assist"))
        end
        markDirty()
        if renderFab then renderFab() end                       -- (the bar counts the pins)
    end

    do   -- one pair of global listeners moves / releases whichever pinned button is being dragged
        connect(UserInputService.InputChanged, function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            for _, p in pairs(Pins) do
                if p.tracker then
                    local nx, ny = p.tracker:move(i.Position.X, i.Position.Y)
                    if nx then p.x, p.y = nx, ny; placePin(p) end
                end
            end
        end)
        connect(UserInputService.InputEnded, function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
            for _, p in pairs(Pins) do
                if p.tracker then
                    local moved = p.tracker.moved
                    p.tracker:finish(os.clock())
                    if moved then markDirty() end          -- a drag just ended: remember the new position
                end
            end
        end)
    end

    ---------------------------------------------------------------- tabs
    sideHeader("MENU")
    local Main_  = createTab("Main", "#")
    local Credit = createTab("Credit", "+")
    local CharTabs = {}
    if Data then
        sideHeader("CHARACTERS")
        for _, ch in ipairs({
            {"The Strongest Hero", "Saitama"}, {"Hero Hunter", "Garou"}, {"Hero Hunter (Monster form)", "Garou Monster"}, {"Destructive Cyborg", "Genos"},
            {"Deadly Ninja", "Sonic"}, {"Brutal Demon", "Metal Bat"}, {"Wild Psychic", "Tatsumaki"},
            {"Blade Master", "Atomic Samurai"}, {"Tech Prodigy", "Tech Prodigy"},
        }) do
            CharTabs[#CharTabs + 1] = {tab = createTab(ch[2], ch[2]:sub(1, 1)), full = ch[1], short = ch[2]}
        end
    end
    sideHeader("TOOLS")
    local Timing_ = createTab("Timing", "T")
    local TechLib = Data and createTab("Techs", "?")
    local LabTab = (TechLab and TechMath and TechData and TechOptions) and createTab("Tech Lab", "L")
    local Tech   = createTab("Auto Tech", "*")
    local Tele   = createTab("Teleports", "@")
    local Effects = createTab(Backend and "Look" or "Effects Preset", "~")
    local ConfigTab = createTab("Config", "=")

    -- Main
    Main_:Banner("Wraith Hub v1.5", "Auto block  |  Tech Lab (Supa, Hook, Loop, Kiba ...)  |  Garou Kyoto assist  |  Dash behind the closest player  |  " .. (Backend and "your own picture or video (Look tab)" or "your own picture (Effects tab)"), "TSB")
    -- how techs start (applies to every tech, combo card and tech switch)
    Main_:Toggle("Start techs with my M1 (off = start them by casting their first move)", Start.m1, function(v)
        if Start.m1 ~= v then Start.m1 = v; markDirty() end
    end, nil, "Arm a tech, then throw 1-3 M1s: when you stop (or reach the tech's own M1 count) I play the rest, casting its first move myself.")
    Main_:Slider("Wait after my last M1 before I take over (s)", 0.15, 0.8, Start.settle, 0.05, function(v)
        if Start.settle ~= v then Start.settle = v; markDirty() end
    end)
    Main_:Slider("Most M1s I wait for (techs that do not begin with M1s)", 1, 4, Start.most, 1, function(v)
        if Start.most ~= v then Start.most = v; markDirty() end
    end)
    Main_:Button("Teach my M1 (touch players): tap this, then throw four M1s", function()
        if startLearning then startLearning("m1", nil, "Throw four M1s now") end
    end)
    Main_:Label("Keyboard / mouse players need nothing - your click is the start. On a phone the M1 is an on-screen button, so teach its animations once with the button above (only your M1s - no moves or dashes while it listens).")
    Main_:Label("General utilities")
    do
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
    end
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
            elseif name:find("Catch") then key, title = "tech", label .. " Tech" end
            local o = getOpts(name)
            ComboInfo[name] = {steps = c.steps, charName = fullName}
            local function drawer(parent)                       -- this combo's own options
                local function set(key) return function(v) if o[key] ~= v then o[key] = v; markDirty() end end end
                -- only the adjustments that change something for THIS combo are shown
                local need = ComboOptions.needs(c.steps, function(tok)
                    local k = KIND[tok]
                    if k == "m1" or k == "jump" or k == "dash" then return k end
                    if moveKey(tok, fullName) then return "move" end
                end)
                local pickers, sliders = {}, {}
                if need.dependent then
                    pickers.auto = tab:Dropdown("Auto timing", {"global", "on", "off"}, o.auto, set("auto"), parent)
                end
                if need.played >= 2 then
                    sliders.speed = tab:Slider("Speed (higher = slower)", 0.5, 2, o.speed, 0.05, set("speed"), parent)
                end
                if need.m1 then sliders.m1 = tab:Slider("M1 gap (0 = global)", 0, 0.6, o.m1, 0.01, set("m1"), parent) end
                if need.dash then sliders.dash = tab:Slider("Dash gap (0 = global)", 0, 0.8, o.dash, 0.01, set("dash"), parent) end
                if need.move then sliders.move = tab:Slider("Move gap (0 = global)", 0, 1.2, o.move, 0.01, set("move"), parent) end
                if need.jump then sliders.jump = tab:Slider("Jump gap (0 = global)", 0, 0.6, o.jump, 0.01, set("jump"), parent) end
                if need.dependent then
                    sliders.offsetMs = tab:Slider("Fine-tune (ms, + = later)", -100, 100, o.offsetMs, 5, set("offsetMs"), parent)
                end
                if need.side then pickers.side = tab:Dropdown("Side dash goes", {"Behind", "Toward", "Left", "Right"}, o.side, set("side"), parent) end
                pickers.pinMode = tab:Dropdown("Pinned button does", {"assist", "run"}, o.pinMode, function(v)
                    if o.pinMode ~= v then o.pinMode = v; markDirty(); if renderPins then renderPins() end end
                end, parent)
                -- Assist: which step is YOURS (everything after it is played for you)
                local trigText = tab:Label("", parent)
                local forgetRow
                local function refreshTrig()
                    local idx, tok = triggerOf(name)
                    trigText.Text = idx and ("Trigger: step " .. idx .. " (" .. shortLabel(tok) .. ") - you cast it, I play the rest."
                        .. (o.trigAnim ~= "" and " Touch animation learned." or "")) or "No trigger"
                    if forgetRow then forgetRow.Visible = o.trigAnim ~= "" end
                end
                if need.choosable then
                    sliders.trigger = tab:Slider("Trigger step # (0 = your first move)", 0, #c.steps, o.trigger, 1, function(v)
                        if o.trigger ~= v then o.trigger = v; markDirty() end
                        refreshTrig()
                    end, parent)
                end
                tab:Button("Learn trigger (for on-screen touch buttons)", function()
                    local _, tok = triggerOf(name)
                    startLearning("combo", name, "Now cast " .. (tok and shortLabel(tok) or "the trigger move") .. " yourself, once")
                end, parent)
                forgetRow = tab:Button("Forget learned trigger", function()
                    if o.trigAnim ~= "" then o.trigAnim = ""; markDirty(); refreshTrig(); toast("Trigger forgotten") end
                end, parent)
                refreshTrig()
                tab:Button("Reset this combo", function()
                    for key, sl in pairs(sliders) do sl:Set(ComboOptions.DEFAULTS[key]) end
                    for key, dd in pairs(pickers) do dd:Set(ComboOptions.DEFAULTS[key]) end
                    if o.trigAnim ~= "" then o.trigAnim = ""; markDirty() end
                    refreshTrig()
                end, parent)
            end
            ArmHandles[name] = get(key, title):Button((name:gsub("_", " ")), describe(c.steps, fullName), function()
                runMacro(c.steps, fullName, name)
            end, {
                conf = c.confidence,
                options = o and drawer or nil,
                pin = {
                    default = SavedPins[name] ~= nil,                       -- pinned last time -> pinned again
                    onChange = function(on) setPinned(name, on, c.steps, fullName) end,
                },
                assist = {onChange = function(on) setArmed(name, on) end},
            })
        end
        -- the Tech section: one on/off switch per tech. Switch it on, cast the first move yourself, the rest is played.
        local techs = {}
        for _, t in ipairs(Data.TechAssists or {}) do
            if t.character == fullName then techs[#techs + 1] = t end
        end
        if #techs > 0 then
            local techSec = get("tech", label .. " Tech")
            for _, t in ipairs(techs) do
                local key = "Tech_" .. (t.name:gsub("[^%w]+", "_"))
                ComboInfo[key] = {steps = t.steps, charName = fullName}
                local techOpts = getOpts(key)
                if techOpts then techOpts.side = "Toward" end            -- a side dash inside a tech is a catch-up: it must end up facing him
                techSec:Toggle(t.name, false, function(on) setArmed(key, on) end, t.desc .. "  [" .. tostring(t.confidence) .. "]")
                if t.kyoto and KyotoPlan then
                    -- the steps and waits follow these options; changing one rebuilds the plan at once
                    local function plan()
                        local steps, gaps, o = KyotoPlan.build(Kyoto)
                        ComboInfo[key].steps, ComboInfo[key].gaps = steps, gaps
                        local opts = getOpts(key)
                        if opts then opts.side = o.side end
                    end
                    local function set(field) return function(v) if Kyoto[field] ~= v then Kyoto[field] = v; markDirty() end plan() end end
                    plan()
                    techSec:Dropdown("Kyoto: M1s before the twisted dash", {"1", "2", "3"}, tostring(Kyoto.m1), function(v) set("m1")(tonumber(v)) end)
                    techSec:Slider("Kyoto: wait after Flowing Water (s)", 0.05, 1, Kyoto.wait, 0.05, set("wait"))
                    techSec:Toggle("Lethal Whirlwind Dash (forward dash right after the Stream)", Kyoto.whirl, set("whirl"))
                    techSec:Toggle("Instant Twisted in the air (step back, dash at him)", Kyoto.twisted, set("twisted"))
                    techSec:Dropdown("Kyoto side dash goes", {"Toward", "Behind", "Left", "Right"}, Kyoto.side, set("side"))
                    techSec:Label("Switch the first toggle on, then start it: throw 1-3 M1s (I cast Flowing Water for you after the last one) - or, if you turned 'Start techs with my M1' off, cast Flowing Water yourself. Then I do the side dash (Kyoto), Lethal Whirlwind Stream, the whirlwind dash, your number of M1s, and the instant twisted. Waits follow Auto timing and the Speed setting; change 'wait after Flowing Water' if the side dash comes too early or late.")
                end
            end
        end
        -- what the guides say block can / cannot stop for this character (names only - see block_info.lua)
        if BlockInfo then
            local ignore, other = {}, {}
            for _, e in ipairs(BlockInfo.entries) do
                if e[3] == fullName then
                    local text = e[1] .. " (" .. e[2] .. ", " .. e[4] .. ")"
                    if e[2] == "unblockable" or e[2] == "guardbreak" then ignore[#ignore + 1] = text else other[#other + 1] = text end
                end
            end
            if #ignore + #other > 0 then
                local lines = {}
                if #ignore > 0 then lines[#lines + 1] = "Ignore or break block: " .. table.concat(ignore, ", ") .. "." end
                if #other > 0 then lines[#lines + 1] = "Other notes: " .. table.concat(other, ", ") .. "." end
                lines[#lines + 1] = "Everything not listed is treated as blockable. Fan guides, unverified, patched often - Auto block also learns this from the hits you take."
                get("blockinfo", label .. " vs block"):Info("Which moves F cannot stop", table.concat(lines, "\n"))
            end
        end
        tab:Label("ASSIST: switch it on, then cast the first move yourself - I play everything after it (Kyoto: you cast Flowing Water, I do Lethal Whirlwind and the rest). Run plays the whole combo for you. On screen adds a button for it. Moves use hotbar slots 1-4 (unverified order); on a phone use Opt > Learn trigger once. Steps marked * have no key mapped and are skipped.")
    end
    if Data then
        for _, c in ipairs(CUSTOM_COMBOS) do
            if type(c) == "table" and type(c.name) == "string" and type(c.steps) == "table" and #c.steps > 0 then
                Data.Combos[c.name] = {character = c.character or "Hero Hunter", confidence = c.confidence or "custom", steps = c.steps}
            end
        end
    end
    -- Side dash: round one-tap buttons you can put on screen, plus an automatic side dash after your own moves.
    -- None of this teleports you: it presses Q + A or Q + D. "Closest" chooses A or D by where the nearest player is.
    do
        local sideSec = Main_:Section("Side dash")
        local function sideCard(name, title, desc, side, caption)
            local o = getOpts(name)
            if o then o.side = side; o.pinMode = "run" end            -- fixed: always this way, the button runs it
            ComboInfo[name] = {steps = {"SIDEDASH"}, charName = "Universal"}
            sideSec:Button(title, desc, function() runMacro({"SIDEDASH"}, "Universal", name) end, {
                conf = "custom",
                pin = {
                    default = SavedPins[name] ~= nil,
                    onChange = function(on) setPinned(name, on, {"SIDEDASH"}, "Universal", "circle", caption) end,
                },
            })
        end
        -- the "behind" card runs BEHINDDASH (round the closest player toward his back); the others are one fixed dash
        local bo = getOpts("SideDash_Behind")
        if bo then bo.pinMode = "run" end
        ComboInfo.SideDash_Behind = {steps = {"BEHINDDASH"}, charName = "Universal"}
        sideSec:Button("Dash behind the closest player", "A real side dash (Q + A or Q + D) round the nearest player toward his back, so you can hit him from behind (hits from behind cannot be blocked). No teleport: only the key is chosen, from where he stands and which way he faces. On screen = round button.",
            function() runMacro({"BEHINDDASH"}, "Universal", "SideDash_Behind") end, {
            conf = "custom",
            pin = {
                default = SavedPins.SideDash_Behind ~= nil,
                onChange = function(on) setPinned("SideDash_Behind", on, {"BEHINDDASH"}, "Universal", "circle", "Behind") end,
            },
        })
        sideCard("SideDash_Toward", "Side dash toward the closest player", "Q + A or Q + D, whichever side the nearest player is on. No teleport - it only dashes. On screen = round button.", "Toward", "Toward")
        sideCard("SideDash_Left", "Side dash left", "Q + A in one tap. On screen = round button.", "Left", "Dash Left")
        sideCard("SideDash_Right", "Side dash right", "Q + D in one tap. On screen = round button.", "Right", "Dash Right")
    end
    Main_:Slider("Behind dash: most dashes", 1, 3, Behind.count, 1, function(v)
        if Behind.count ~= v then Behind.count = v; markDirty() end
    end)
    Main_:Slider("Behind dash: wait between dashes (s)", 0.5, 4, Behind.gap, 0.1, function(v)
        if Behind.gap ~= v then Behind.gap = v; markDirty() end
    end)
    Main_:Slider("Behind dash: time for the dash to finish before the M1 (s)", 0.1, 1, Behind.settle, 0.05, function(v)
        if Behind.settle ~= v then Behind.settle = v; markDirty() end
    end)
    Main_:Toggle("Behind dash: M1 once I am behind him", Behind.m1, function(v)
        if Behind.m1 ~= v then Behind.m1 = v; markDirty() end
    end)
    Main_:Label("BEHIND DASH = a real side dash (Q + A or Q + D), never a teleport. It picks the side that takes you round the nearest player toward his back (hits from behind cannot be blocked) and stops as soon as you are behind him. Guides: a side dash has a 2 s cooldown, so a second dash waits that long. Works best when your camera looks at him. Tip from the guides: hit once or twice, then dash to the back of someone who keeps blocking.")
    Main_:Toggle("Auto side dash after my moves", false, function(on)
        SideAuto.on = on
        if ready then toast(on and "Auto side dash ON - cast a move and I dash" or "Auto side dash OFF") end
    end)
    Main_:Dropdown("Side", {"Behind", "Toward", "Alternate", "Left", "Right"}, SideAuto.dir, function(v)
        if SideAuto.dir ~= v then SideAuto.dir = v; markDirty() end
    end)
    Main_:Slider("Delay after my move (s)", 0, 1, SideAuto.delay, 0.05, function(v)
        if SideAuto.delay ~= v then SideAuto.delay = v; markDirty() end
    end)
    Main_:Slider("Cooldown (s)", 0.2, 3, SideAuto.cooldown, 0.1, function(v)
        if SideAuto.cooldown ~= v then SideAuto.cooldown = v; markDirty() end
    end)
    Main_:Button("Learn a move for auto side dash (cast it once)", function()
        startLearning("side", nil, "Now cast one of your moves, once")
    end)
    Main_:Button("Forget learned moves", function()
        SideAuto.anims = {}
        markDirty()
        toast("Forgot the learned moves")
    end)
    Main_:Label("Auto side dash: on a PC your hotbar keys 1-4 trigger it. On a phone tap Learn, then cast each move once so it recognises the animation. Delay is adjusted by Auto timing like the combo gaps.")
    buildCharacter(Main_, "Universal", "Universal")
    for _, ct in ipairs(CharTabs) do buildCharacter(ct.tab, ct.full, ct.short) end

    -- Timing tab
    pingLabel = Timing_:Label("Ping: measuring...")
    gapsLabel = Timing_:Label("Gaps now ...")
    do
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

    end

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

    -- Tech Lab (game_dev/tech_lab.lua): dash techs, combos, defence and helpers, each a small sequence on one engine. The tab is generated from the tech
    -- definitions, so a new tech needs no UI code. Everything starts OFF; options and switches are only remembered by Save config.
    if LabTab then
    do
        local statusLabels, techLogs = {}, {}
        local function statusText(tech) return "Starts: " .. tech.when .. "   |   " .. tech.status end
        local lab = TechLab.new({
            Players = Players, RunService = RunService, UserInputService = UserInputService, Workspace = workspace, LocalPlayer = LocalPlayer, VirtualInput = VirtualInput,
            TechMath = TechMath, TechData = TechData, TechOptions = TechOptions,
            connect = connect, safe = safe, clock = os.clock,
            pingMs = function() return currentPing() end,
            jitterMs = function() return PingState.model and PingState.model:jitter() or 0 end,
            busy = function() return macroRunning end,
            log = function(msg)                                   -- errors inside a tech: kept for "Copy the log", never thrown at the game
                techLogs[#techLogs + 1] = string.format("%.1f  %s", os.clock(), tostring(msg))
                if #techLogs > 40 then table.remove(techLogs, 1) end
            end,
            toast = function(msg) toast(msg) end,
            onStatus = function(tech) local l = statusLabels[tech.id]; if l then l.Text = statusText(tech) end end,
        })
        techLab = lab
        if type(Saved.techlab) == "table" then lab:import(Saved.techlab) end
        onCleanup[#onCleanup + 1] = function() lab:destroy() end

        LabTab:Label("The techs from your own script, rebuilt as small sequences on one engine (cancellable, with cleanup, dash-cooldown aware). Everything is OFF until you switch it on, and nothing is remembered unless you press Save config. They were written from your script and tested only in a simulated arena, never in the real game: if a tech does not react, its trigger animation id has probably changed - use Learn trigger inside the tech.")
        LabTab:Toggle("Tech Lab master switch", lab.master, function(on)
            if lab.master ~= on then lab:setMaster(on); markDirty() end
        end, nil, "Off = every tech stops and ignores its trigger")
        LabTab:Dropdown("Inputs", {"Auto", "Remote", "Keys"}, lab.input, function(v)
            if lab.input ~= v then lab:setInput(v); markDirty() end
        end)
        LabTab:Toggle("Wait for the dash cooldown", lab.dashGuard, function(on)
            if lab.dashGuard ~= on then lab.dashGuard = on; markDirty() end
        end, nil, "A tech that starts with a dash does not start while that dash is on cooldown")
        LabTab:Toggle("Let go of block before an M1", lab.releaseBlock, function(on)
            if lab.releaseBlock ~= on then lab.releaseBlock = on; markDirty() end
        end)
        LabTab:Dropdown("Who the techs go for", TechMath.TARGET_MODES, lab.targetMode, function(v)
            if lab.targetMode ~= v then lab:setTargetMode(v); markDirty() end
        end)
        LabTab:Toggle("Skip players who are blocking", lab.skipBlocking, function(on)
            if lab.skipBlocking ~= on then lab.skipBlocking = on; markDirty() end
        end)
        LabTab:Toggle("Safe moves", lab.safeMoves, function(on)
            if lab.safeMoves ~= on then lab.safeMoves = on; markDirty() end
        end, nil, "A tech that moves you stops in front of a wall and never goes under the floor")
        LabTab:Toggle("Not while I am knocked down", lab.guardKnocked, function(on)
            if lab.guardKnocked ~= on then lab.guardKnocked = on; markDirty() end
        end, nil, "No tech starts while you are ragdolled or stunned")
        LabTab:Slider("Input buffer (ms, 0 = off)", 0, 1000, lab.bufferMs, 10, function(v)
            if lab.bufferMs ~= v then lab.bufferMs = v; markDirty() end
        end)
        local cooldownLabel = LabTab:Label("")
        LabTab:Slider("Ping compensation (0 = off, 1 = full)", 0, 2, lab.net.strength, 0.05, function(v)
            if lab.net.strength ~= v then lab:setNet("strength", v); markDirty() end
        end)
        LabTab:Slider("Typed ping in ms (0 = measure it)", 0, 600, lab.net.manual, 5, function(v)
            if lab.net.manual ~= v then lab:setNet("manual", v); markDirty() end
        end)
        LabTab:Slider("Roblox's drawing delay for other players (ms)", 0, 250, lab.net.interp, 5, function(v)
            if lab.net.interp ~= v then lab:setNet("interp", v); markDirty() end
        end)
        LabTab:Toggle("Measure how late my own animations arrive", lab.net.learn, function(on)
            if lab.net.learn ~= on then lab:setNet("learn", on); markDirty() end
        end, nil, "Every dash I send and the animation that answers it: the gap is used to start waits earlier and to date the dash cooldown")
        LabTab:Button("Panic - cancel every running tech", function()
            lab:cancelAll("cancelled: panic")
            toast("Tech Lab: everything cancelled")
        end)
        LabTab:Button("Copy the Tech Lab log (for a bug report)", function()
            local text = #techLogs > 0 and table.concat(techLogs, "\n") or "no errors logged"
            if setclipboard and pcall(setclipboard, text) then toast("Log copied") else toast(#techLogs > 0 and ("Last error: " .. techLogs[#techLogs]:sub(1, 120)) or "No errors logged") end
        end)
        do   -- the two dash cooldowns, a few times a second
            local last, acc = "", 0
            connect(RunService.Heartbeat, function(dt)
                acc = acc + dt
                if acc < 0.25 then return end
                acc = 0
                local f, sd = lab:dashLeft("forward"), lab:dashLeft("side")
                local text = string.format("Forward dash: %s   |   Side dash: %s", f > 0 and string.format("%.1f s", f) or "ready", sd > 0 and string.format("%.1f s", sd) or "ready")
                local n = lab:netInfo()
                text = text .. "\n" .. string.format("Ping %s ms (jitter %.0f)   |   my animations arrive %s after my input   |   other players are led by %.0f ms",
                    n.ping and string.format("%.0f", n.ping) or "?", n.jitter, n.lag and string.format("%.0f ms", n.lag * 1000) or string.format("? (%d of 3 samples)", n.samples), n.lead * 1000)
                if text ~= last then last = text; cooldownLabel.Text = text end
            end)
        end

        for _, group in ipairs(TechLab.GROUPS) do
            LabTab:Label(group:upper())
            for _, tech in ipairs(lab.order) do
                if tech.group == group then
                    local id = tech.id
                    local sec = LabTab:Section(tech.title, true)
                    sec:Toggle("On", tech.enabled, function(on)
                        if lab.techs[id].enabled ~= on then lab:setEnabled(id, on); markDirty() end
                    end)
                    sec:Label(tech.desc)
                    statusLabels[id] = sec:Label(statusText(tech))
                    local controls = {}
                    if tech.manual then
                        LabTab:Button("Run now", function() lab:fire(id, {manual = true}) end, sec.Body)
                    end
                    for _, d in ipairs(tech.defs) do
                        local key, api = d.key, nil
                        local function put(v)
                            if lab.techs[id].opt[key] ~= v then lab:setOption(id, key, v); markDirty() end
                        end
                        if d.kind == "number" then api = sec:Slider(d.label, d.min, d.max, tech.opt[key], d.step, put)
                        elseif d.kind == "bool" then api = sec:Toggle(d.label, tech.opt[key], put, d.tip)
                        elseif d.kind == "choice" then api = sec:Dropdown(d.label, d.choices, tech.opt[key], put)
                        elseif d.kind == "key" then
                            local keys = {table.unpack(d.choices)}
                            if not table.find(keys, tech.opt[key]) then keys[#keys + 1] = tech.opt[key] end           -- a key bound in the WindUI hub
                            api = sec:Dropdown(d.label, keys, tech.opt[key], put)
                        else api = LabTab:Input(d.label, "", tech.opt[key], function(text) put((text:gsub("^%s+", ""):gsub("%s+$", ""))) end, sec.Body) end
                        controls[#controls + 1] = {def = d, api = api}
                    end
                    if not (tech.observer or tech.poll or tech.manual or tech.mouse or tech.key) then
                        LabTab:Button("Learn trigger: play the move that should start it, once", function()
                            lab:learnTrigger(id, function() markDirty() end)
                            toast("Now play the move that should start " .. tech.title)
                        end, sec.Body)
                        LabTab:Button("Forget the triggers I taught it", function()
                            lab:forgetTriggers(id)
                            markDirty()
                            toast("Learned triggers for " .. tech.title .. " forgotten")
                        end, sec.Body)
                    end
                    LabTab:Button("Reset this tech's options", function()
                        for _, c in ipairs(controls) do
                            lab:setOption(id, c.def.key, c.def.default)
                            c.api:Set(c.def.default)
                        end
                        markDirty()
                        toast(tech.title .. ": options reset")
                    end, sec.Body)
                end
            end
        end
    end
    end

    -- Auto Tech
    local blockToggle
    Tech:Label("Recovers automatically when you get knocked down.")
    local techToggle = Tech:Toggle("Auto Tech", false, function(on)
        Settings.AutoTech = on
        if renderFab then renderFab() end
    end)
    Tech:Dropdown("Direction", {"Back", "Forward", "Left", "Right"}, "Back", function(v) Settings.TechDirection = v end)
    Tech:Slider("Reaction Delay (s)", 0, 0.5, 0.05, 0.01, function(v) Settings.TechDelay = v end)
    Tech:Slider("Cooldown (s)", 0.1, 3, 0.6, 0.05, function(v) Settings.TechCooldown = v end)
    Tech:Label("Dash key defaults to Q - change Settings.TechKey if you rebound it.")

    -- Auto block
    Tech:Label("AUTO BLOCK - blocks every hit aimed at you from in front, then lets go a moment after their attack ends so you can punch. Your own M1 / move key drops the block instantly (PC; on a phone it relies on the quick release). Hits from behind, charged hits and grabs cannot be blocked, so those are skipped.")
    blockToggle = Tech:Toggle("Auto block", false, function(on)
        Block.on = on
        if not on and Block.reset then Block.reset() end
        if renderFab then renderFab() end
        if ready then toast(on and "Auto block ON" or "Auto block OFF") end
    end)
    local function blockSet(key) return function(v) if Block[key] ~= v then Block[key] = v; markDirty() end end end
    Tech:Slider("Range (studs)", 6, 30, Block.range, 1, blockSet("range"))
    Tech:Slider("Aim cone (+- degrees)", 20, 120, Block.aim, 5, blockSet("aim"))
    Tech:Slider("Delay after their swing starts (s) - 0 = press at once", 0, 0.4, Block.delay, 0.01, blockSet("delay"))
    Tech:Slider("Let go after their attack ends (s)", 0.05, 0.5, Block.grace, 0.01, blockSet("grace"))
    Tech:Slider("Longest hold (s)", 0.3, 2, Block.maxHold, 0.05, blockSet("maxHold"))
    Tech:Toggle("Shorten the delay by my ping", Block.usePing, blockSet("usePing"))
    Tech:Slider("Stay blocked between hits of a combo (s)", 0, 0.8, Block.chainGrace, 0.05, blockSet("chainGrace"))
    Tech:Toggle("Pre-block players rushing at me (predict the punch)", Block.rush, blockSet("rush"))
    Block.budgetLabel = Tech:Label("Reaction time: your ping is not known yet.")
    Tech:Toggle("Check the block came up and press again if not", Block.verify, blockSet("verify"))
    Block.senseLabel = Tech:Label("Block check: still learning what blocking looks like.")
    Tech:Button("Teach it what blocking looks like (stand still)", function() if Block.teach then Block.teach() end end)
    Tech:Button("Forget what blocking looks like", function() if Block.forgetSense then Block.forgetSense() end; toast("Forgot - it will learn again") end)
    Tech:Label("LEARNING - every time a player's attack hurts you, I time how long after their animation started. Next time F goes down just before that hit instead of using the Delay above. It only sees hits that reach you (a blocked hit teaches nothing), so to teach it quickly spar for a bit with Auto block OFF. Learned timings are forgotten when you re-run unless you press Save config.")
    Tech:Toggle("Learn from hits I take", Block.learn, blockSet("learn"))
    Tech:Toggle("Use learned timing (predict the punch)", Block.useLearned, blockSet("useLearned"))
    Tech:Dropdown("Block style", BlockOpts.styleNames, Block.style, function(v)
        if BlockOpts.styles[v] and Block.style ~= v then Block.style = v; Block.lead = BlockOpts.styles[v]; markDirty() end
    end)
    Tech:Label("Safe = F down early (hard to miss). Balanced = just before the hit. Perfect = at the last moment, for the perfect-block critical.")
    Tech:Dropdown("When an attack ignores block", BlockOpts.pierceNames, (function()
        for label, mode in pairs(BlockOpts.pierceModes) do if mode == Block.pierceMode then return label end end
        return "Block anyway"
    end)(), function(v)
        local mode = BlockOpts.pierceModes[v]
        if mode and Block.pierceMode ~= mode then Block.pierceMode = mode; markDirty() end
    end)
    Tech:Label("An attack that still hurts although F was already down (grab, downslam, charged hit, unblockable move) is learned after 2 times. Block anyway = never skip (safest), Do nothing = keep your hands free, Side dash = dodge it.")
    Tech:Toggle("Predict chain hits (experimental)", Block.chain, blockSet("chain"))
    Block.learnLabel = Tech:Label("Learned: 0 attack animation(s) from 0 hit(s) you took.")
    Block.decisionLabel = Tech:Label("Last: nothing seen yet.")
    Tech:Button("Reset the attack counters", function()
        Block.stats.seen, Block.stats.blocked, Block.stats.why, Block.stats.rush = 0, 0, {}, 0
        Block.lastDecision = "nothing seen yet"
        if Block.summary then Block.decisionLabel.Text = Block.summary() end
    end)
    Tech:Button("Forget learned timings", function()
        if Learner then Learner:forget(); Block.lastLearned = nil; markDirty(); toast("Forgot all learned timings") end
    end)
    Tech:Toggle("Show the block floater", Block.floater, function(v)
        if Block.floater ~= v then Block.floater = v; markDirty() end
        if Block.setFloaterVisible then Block.setFloaterVisible(v) end
    end)
    Block.flip = function() blockToggle:Set(not blockToggle:Get()) end
    Tech:Label("Perfect block timing depends on each move's hit frame, which I cannot read. Delay is shortened by your ping (Auto timing strength / fine-tune apply). Start at 0.10 s and nudge it: lower = blocks sooner. Longest hold caps one block, so you are never stuck blocking.")

    -- Teleports (list follows players joining / leaving)
    do
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

    end

    -- Credit
    Credit:Label("Wraith Hub v1.5 UI")
    Credit:Label("Tech Lab: the tech ideas (Supa, Hook Dash, Loop Dash, Kyoto, Lethal Dash, M1 Reset, Twisted, Kiba / Kitty Tech - Kitty Tech idea by ItzSoph, ...) come from your own Dovi's Hub script; the code is a rewrite, not a copy.")
    Credit:Label("Settings are NOT saved automatically - use the Config tab (Save config) when you want to keep them.")
    Credit:Label("Toggle menu: RightShift, or the floating bar: Menu = show/hide, Tech = Auto Tech on/off, Pins = show/hide pinned buttons, Lock = freeze bar and pinned buttons, - = shrink to a dot.")
    if Backend then
        Credit:Label("The menu is WindUI by Footagesus (MIT licence), with the white water background made in this script. Icons: Lucide (MIT).")
    else
        Credit:Label("Background: random SFW image from waifu.pics / nekos.best (fan art, not copyright-free).")
    end

    -- Effects Preset / Look: the look of the menu
    -- throw the menu away and build it again from `data` (a snapshot / config table); `data` is used once
    local function restartWith(data, fromFile)
        if genv.AH_DISABLE_REBUILD then toast("Rebuild is disabled") return end
        genv[SESSION_KEY], genv[SESSION_KEY .. "FromFile"] = data, fromFile and true or nil
        cleanup()
        task.spawn(function()
            task.wait(0.4)
            local ok, err = pcall(__run)
            if not ok then
                warn("[Wraith Hub v1.5] rebuild failed: " .. tostring(err))
                notify("Wraith Hub v1.5 error", tostring(err):sub(1, 180), 15)
            end
        end)
    end
    if Backend then
        local win = Backend.win
        Effects:Label("The look of this menu. Nothing here is saved until you press Save config (Config tab).")
        Effects:Dropdown("Theme", WindAdapter.ThemeNames, WindPrefs.theme, function(v)
            if WindPrefs.theme ~= v then WindPrefs.theme = v; win:SetTheme(v); win:SetWater{Tint = WindAdapter.waterTint(v)}; markDirty() end
        end)
        Effects:Dropdown("Font", WindAdapter.FontNames, WindPrefs.font, function(v)
            if WindPrefs.font ~= v then
                WindPrefs.font = v
                local family = WindAdapter.fontFamily(v)
                if family then win:SetFont(family) end
                markDirty()
            end
        end)
        Effects:Slider("Menu size", 0.55, 1.2, WindPrefs.scale, 0.05, function(v)
            if WindPrefs.scale ~= v then WindPrefs.scale = v; win:SetScale(v); markDirty() end
        end)
        Effects:Slider("Window transparency", 0, 0.9, WindPrefs.alpha, 0.05, function(v)
            if WindPrefs.alpha ~= v then WindPrefs.alpha = v; win:SetBackgroundTransparency(v); markDirty() end
        end)
        Effects:Toggle("Welcome card at start", WindPrefs.popup, function(on)
            if WindPrefs.popup ~= on then WindPrefs.popup = on; markDirty() end
        end)
        local waterSec = Effects:Section("White water")
        local waterToggle = waterSec:Toggle("White water", WindPrefs.water, function(on)
            if WindPrefs.water ~= on then WindPrefs.water = on; win:SetWater{Enabled = on}; markDirty() end
        end, "Animated white water behind the menu (also the water button in the top bar)")
        windActions.toggleWater = function()
            waterToggle:Set(not waterToggle:Get())
            toast(WindPrefs.water and "White water on" or "White water off")
        end
        waterSec:Slider("Water brightness", 0, 1, WindPrefs.waterStrength, 0.05, function(v)
            if WindPrefs.waterStrength ~= v then WindPrefs.waterStrength = v; win:SetWater{Strength = v}; markDirty() end
        end)
        waterSec:Slider("Wave speed", 0, 3, WindPrefs.waterSpeed, 0.05, function(v)
            if WindPrefs.waterSpeed ~= v then WindPrefs.waterSpeed = v; win:SetWater{Speed = v}; markDirty() end
        end)
        local pictureSec = Effects:Section("Your own picture or video", true)
        pictureSec:Label("Optional, under the water: a direct link to a .png / .jpg / .webm (or rbxassetid://). A video needs an executor that can save files, and WindUI itself says video backgrounds may not work everywhere. It is kept if you Save config.")
        Effects:Input("Picture or video link", "empty = none", Picture.source, function(text)
            text = (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
            if #text > 300 or text:find("%c") then toast("That link is not usable") return end
            if Picture.source == text then return end
            Picture.source = text
            markDirty()
            win:SetBackground(text, function(ok, msg)
                if text ~= "" then toast(ok and ("A " .. tostring(msg) .. " is behind the menu") or ("Background not loaded: " .. tostring(msg))) end
            end)
        end, pictureSec.Body)
        pictureSec:Slider("Darken the picture / video", 0, 0.9, WindPrefs.bgDim, 0.05, function(v)
            if WindPrefs.bgDim ~= v then WindPrefs.bgDim = v; win:SetBackgroundDim(v); markDirty() end
        end)
    else
        Effects:Label("Menu look")
        Effects:Dropdown("Theme", ThemeNames, themeName, function(v) pendingTheme = v end)
        Effects:Button("Apply theme (rebuilds the menu)", function() restartWith(buildSnapshot()) end)    -- keeps everything you have set in this session
        Effects:Slider("Menu size", 0.7, 1.25, uiScale, 0.05, function(v)
            if uiScale ~= v then
                uiScale = v
                if menuOpen then MainScale.Scale = fitScale() end
                markDirty()
            end
        end)
        Effects:Slider("Glass (higher = clearer picture)", 0.4, 0.95, glass, 0.01, function(v)
            if glass ~= v then glass = v; Veil.BackgroundTransparency = v; markDirty() end
        end)
        Effects:Slider("Brightness (press Apply theme)", 0.8, 1.2, bright, 0.05, function(v)
            if bright ~= v then bright = v; markDirty() end
        end)
        Effects:Label("Background image")
        Effects:Slider("Image opacity", 0.1, 1, 1 - BACKGROUND_TRANSPARENCY, 0.05, function(v)
            Background.ImageTransparency = 1 - v
        end)
        Effects:Dropdown("Random picture from", {"waifu.pics", "waifu.pics / neko", "waifu.pics / shinobu", "waifu.pics / megumin", "nekos.best",
            "nekos.best / neko", "nekos.best / kitsune", "nekos.best / husbando"}, BACKGROUND_SOURCE, function(v) BACKGROUND_SOURCE = v end)
        Effects:Button("New random picture", function() Picture.source = ""; refreshBackground(BACKGROUND_SOURCE) end)
        Effects:Label("YOUR OWN PICTURE: type a direct link to a PNG / JPG (the link must end in the picture itself), or the name of a PNG / JPG you put in your executor's workspace folder, or a Roblox image id. It becomes the window background and the banner, and is kept if you Save config.")
        pictureNote = Effects:Label(pictureStatus or (Picture.source ~= "" and ("Your picture: " .. Picture.source) or "Random anime pictures are on."))
        local pictureBox = Effects:Input("Picture link, file name or image id", "https://... .png   |   my_picture.png   |   123456789", Picture.source, function() end)
        Effects:Button("Use this picture", function()
            local text = (pictureBox:Get():gsub("^%s+", ""):gsub("%s+$", ""))
            local asset, why = loadCustom(text)
            if not asset then
                noteAboutPicture("Not changed: " .. tostring(why))
                toast("That picture did not load")
                return
            end
            Picture.source = text
            markDirty()
            setPicture(asset)
            noteAboutPicture("Your picture is on.")
            toast("Picture changed")
        end)
        Effects:Button("Back to random anime pictures", function()
            Picture.source = ""
            pictureBox:Set("")
            markDirty()
            noteAboutPicture("Random anime pictures are on.")
            refreshBackground(BACKGROUND_SOURCE)
        end)
        Effects:Label("Images come from public waifu APIs (SFW endpoints). They are community fan art, so the artists keep the copyright - use your own CC0 image via BACKGROUND_URL if you need that.")

    end

    -- Config: the ONLY way anything is remembered between runs
    ConfigTab:Label("NOTHING is saved automatically. Pinned buttons, armed combos, timings, Auto block settings, learned punch timings, the floater and bar positions and the theme all start fresh every time you run the script - unless you press Save config. A saved config is loaded the next time the hub starts.")
    configStatus = ConfigTab:Label("")
    ConfigTab:Button("Save config", function()
        local ok, why = saveConfig()
        toast(ok and "Config saved - it will be loaded next time" or ("Not saved: " .. tostring(why)))
    end)
    ConfigTab:Button("Reload saved config (rebuilds the menu)", function()
        local data = readConfigFile()
        if next(data) == nil then toast("There is no saved config to load") return end
        restartWith(data, true)
    end)
    ConfigTab:Button("Delete saved config", function()
        deleteConfig()
        toast("Saved config deleted - the next start is clean")
    end)
    ConfigTab:Label("Reload throws away what you changed since the last Save and rebuilds the menu from the file. Delete only removes the file; what is on screen now stays until you re-run.")
    refreshConfigStatus()

    -- Predictor tab: only when combo_engine/tsb_data were bundled in (see game_dev/build_executor.py)
    if Engine and Data then
        Engine.loadData(Data)
        local Pred = createTab("Predictor", "?")
        Pred:Label("Guesses which combo you are doing from your M1 / dash / jump inputs and what usually comes next.")
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
    -- [Menu] [Tech] [Pins] [Lock] [-]
    --   Menu  show / hide this window          Tech  Auto Tech on / off
    --   Pins  show / hide the pinned buttons   Lock  freeze the bar AND the pinned buttons in place
    --   -     shrink the bar to a dot (tap the dot to bring it back). Drag the bar anywhere.
    -- Position / lock / minimised state are part of your config (Config tab) - they are not remembered on their own.
    do
        local BAR_W, BAR_H, DOT = 304, 46, 38
        local saved = type(Saved.fab) == "table" and Saved.fab or {}
        local fabState = {x = type(saved.x) == "number" and saved.x or nil, y = type(saved.y) == "number" and saved.y or nil,
            locked = saved.locked == true, minimized = saved.minimized == true}
        fabRef = fabState
        local vw0 = viewport()
        fabState.x = fabState.x or math.floor(((vw0 or 800) - BAR_W) / 2)     -- top centre: clear of the thumbsticks
        fabState.y = fabState.y or 10

        local tracker = DragTracker and DragTracker.new(8)    -- no tracker (unbundled file): bar is simply fixed
        if tracker then tracker:setLocked(fabState.locked) end
        setPinsLocked(fabState.locked)

        local fab = new("Frame", {
            Size = UDim2.fromOffset(BAR_W, BAR_H), Position = UDim2.fromOffset(fabState.x, fabState.y),
            BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.08, ZIndex = 10, Parent = Gui,
        }, {corner(23), gloss(nil, 23, 1)})
        local fabScale = new("UIScale", {Scale = 0, Parent = fab})
        local fabStroke = stroke(Theme.White, 1.5, 0.2)
        fabStroke.Parent = fab
        accentGradient(fabStroke, 0)

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
            tween(btn, {BackgroundColor3 = on and Theme.Accent or Theme.Item, TextColor3 = on and Theme.Ink or Theme.Text}, 0.2)
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
                Size = UDim2.fromOffset(w, BAR_H - 10), Position = UDim2.fromOffset(x, 5), ZIndex = 11, Parent = fab,
            }, {corner(15)})
            b.MouseButton1Click:Connect(tappable(onTap))
            b.MouseButton1Down:Connect(function() tween(b, {Size = UDim2.fromOffset(w - 4, BAR_H - 14), Position = UDim2.fromOffset(x + 2, 7)}, 0.07) end)
            local function release() tween(b, {Size = UDim2.fromOffset(w, BAR_H - 10), Position = UDim2.fromOffset(x, 5)}, 0.2, Enum.EasingStyle.Back) end
            b.MouseButton1Up:Connect(release)
            b.MouseLeave:Connect(release)
            attachDrag(b)
            return b
        end

        local menuBtn, techBtn, blockBtn, pinsBtn, lockBtn, minBtn, dot
        local function place()
            local w, h = BAR_W, BAR_H
            if fabState.minimized then w, h = DOT, DOT end
            local vw, vh = viewport()
            if DragTracker and vw then
                fabState.x, fabState.y = DragTracker.clamp(fabState.x, fabState.y, w, h, vw, vh, 4)
            end
            fab.Size = UDim2.fromOffset(w, h)
            fab.Position = UDim2.fromOffset(fabState.x, fabState.y)
        end
        renderFab = function()
            paint(menuBtn, menuOpen)
            paint(techBtn, Settings.AutoTech)
            techBtn.Text = Settings.AutoTech and "Tech ON" or "Tech OFF"
            paint(blockBtn, Block.on)
            blockBtn.Text = Block.on and "Block ON" or "Block"
            paint(pinsBtn, pinsVisible and #pinOrder > 0)
            pinsBtn.Text = #pinOrder > 0 and ("Pins " .. #pinOrder) or "Pins"
            paint(lockBtn, fabState.locked)
            lockBtn.Text = fabState.locked and "Locked" or "Lock"
            for _, b in ipairs({menuBtn, techBtn, blockBtn, pinsBtn, lockBtn, minBtn}) do b.Visible = not fabState.minimized end
            dot.Visible = fabState.minimized
            place()
        end

        menuBtn = barButton("Menu", 4, 46, toggleMenu)
        techBtn = barButton("Tech OFF", 54, 56, function() techToggle:Set(not techToggle:Get()) end)
        blockBtn = barButton("Block", 114, 54, function() blockToggle:Set(not blockToggle:Get()) end)
        pinsBtn = barButton("Pins", 172, 46, function()
            if #pinOrder == 0 then toast("Nothing pinned yet - turn On screen on for a combo") return end
            setPinsVisible(not pinsVisible)
            toast(pinsVisible and "Pinned buttons shown" or "Pinned buttons hidden")
        end)
        lockBtn = barButton("Lock", 222, 50, function()
            fabState.locked = not fabState.locked
            if tracker then tracker:setLocked(fabState.locked) end
            setPinsLocked(fabState.locked)
            toast(fabState.locked and "Locked: the bar and pinned buttons stay where they are" or "Unlocked: drag them anywhere")
            markDirty()
            renderFab()
        end)
        minBtn = barButton("-", 276, 24, function() fabState.minimized = true; markDirty(); renderFab() end)
        dot = new("TextButton", {
            Text = "WH", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Ink,
            BackgroundColor3 = Theme.White, AutoButtonColor = false, Visible = false,
            Size = UDim2.fromOffset(DOT - 8, DOT - 8), Position = UDim2.fromOffset(4, 4), ZIndex = 11, Parent = fab,
        }, {corner(15), accentGradient(nil, 0)})
        dot.MouseButton1Click:Connect(tappable(function() fabState.minimized = false; markDirty(); renderFab() end))
        attachDrag(dot)
        attachDrag(fab)

        if tracker then
            connect(UserInputService.InputChanged, function(i)
                if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
                local nx, ny = tracker:move(i.Position.X, i.Position.Y)
                if nx then fabState.x, fabState.y = nx, ny; place() end
            end)
            connect(UserInputService.InputEnded, function(i)
                if isPointer(i) then
                    if tracker.moved then markDirty() end
                    tracker:finish(os.clock())
                end
            end)
        end

        -- keep everything on screen when the screen rotates / resizes
        local cam = workspace.CurrentCamera
        local sig = cam and safe(function() return cam:GetPropertyChangedSignal("ViewportSize") end)
        if sig then
            connect(sig, function()
                place()
                for _, p in pairs(Pins) do placePin(p) end
            end)
        end

        renderFab()
        tween(fabScale, {Scale = 1}, 0.55, Enum.EasingStyle.Back)       -- pops in so you notice it
    end

    if Backend then
        windActions.say = toast
        windActions.panic = function()                  -- the top bar's Panic: stop the combo that is playing and every Tech Lab tech
            if stopMacro then stopMacro() end
            if techLab then techLab:cancelAll("cancelled: panic") end
            toast("Panic: everything stopped")
        end
        windActions.changelog = function()
            local lines = {}
            for i, line in ipairs(windActions.lines) do lines[i] = "- " .. line end
            Backend.win:Dialog{Title = "What is new in v1.5", Content = table.concat(lines, "\n"), Buttons = {{Title = "Close", Variant = "Primary"}}}
        end
    end

    ready = true                       -- from here on, changing something marks the config as "not saved" (nothing is written)
    dirty = SavedFrom == "carried over"   -- carried-over settings live in memory only
    refreshConfigStatus()
    Main_:Select()
    setMenu(true)                      -- fade + scale the window in
    notify("Wraith Hub v1.5", "Ready - the floating bar is at the top of your screen (Menu / Tech / Pins / Lock). RightShift also toggles the menu.", 7)
    if Backend and WindPrefs.popup then
        Backend.win:Popup{Title = '<font color="#ffffff">Wraith</font> <font color="#dfe7f1">Hub</font> <font color="#aab6c6">v1.5</font>', Icon = "sparkles",
            Content = "White water edition for The Strongest Battlegrounds. Everything you had is still here: Auto block, combo cards, pins, Auto Tech, the Tech Lab. Nothing is saved until you press Save config. Nothing was tested in the real game.",
            Buttons = {{Title = "What is new", Variant = "Secondary", Callback = windActions.changelog}, {Title = "Start", Variant = "Primary"}}}
    end
    print("[Wraith Hub v1.5] ready, UI parent: " .. tostring(Gui.Parent and Gui.Parent.Name))

    -- soft game check: warn (never block) if this is not The Strongest Battlegrounds
    task.spawn(function()
        local ok, info = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        end)
        if ok and info and not info:lower():find("strongest battlegrounds") then
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Wraith Hub v1.5", Text = "This place is '" .. info .. "', not TSB. Auto Tech is tuned for TSB.", Duration = 6,
                })
            end)
        end
    end)

end

-- run guarded so a failure shows a message instead of silently doing nothing (common on mobile executors)
local ok, err = pcall(__run)
if not ok then
    warn("[Wraith Hub v1.5] failed to start: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Wraith Hub v1.5 error", Text = tostring(err):sub(1, 180), Duration = 15,
        })
    end)
end
