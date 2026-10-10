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
    local function loadSaved()
        local carried, fromFile = genv[SESSION_KEY], genv[SESSION_KEY .. "FromFile"]
        genv[SESSION_KEY], genv[SESSION_KEY .. "FromFile"] = nil, nil
        if type(carried) == "table" then return carried, fromFile and "file" or "carried over" end
        local data = readConfigFile()
        return data, next(data) ~= nil and "file" or "none"
    end
    local function num(v, lo, hi, default)
        if type(v) ~= "number" or v ~= v then return default end
        return math.min(math.max(v, lo), hi)
    end
    local Saved, SavedFrom = loadSaved()
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
    local MainStroke = stroke(Theme.White, 1.6, 0.15)
    MainStroke.Parent = Main
    local BorderGrad = new("UIGradient", {      -- gold -> accent -> accent2 rim that slowly rotates
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Gold), ColorSequenceKeypoint.new(0.5, Theme.Accent), ColorSequenceKeypoint.new(1, Theme.Accent2),
        }),
        Rotation = 45, Parent = MainStroke,
    })

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
    refreshBackground()

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
        Text = "Animation Hub", Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = Theme.White,
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
        if not gp and i.KeyCode == Enum.KeyCode.RightShift then toggleMenu() end
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
        function tab:Section(title)
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
                Rotation = 180, Parent = head,
            })
            local body = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, LayoutOrder = 1, Parent = holder,
            }, {new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
            local open = true
            head.MouseButton1Click:Connect(function()
                open = not open
                body.Visible = open
                tween(arrow, {Rotation = open and 180 or 0}, 0.25, Enum.EasingStyle.Back)
            end)

            local sec = {}
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

    -- ambient shine: the border rotates slowly, and every ~6 s a shimmer runs over the title
    do
        local shimmerAcc = 0
        connect(RunService.Heartbeat, function(dt)
            if not menuOpen then return end
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
            block = {range = Block.range, aim = Block.aim, delay = Block.delay, grace = Block.grace, maxHold = Block.maxHold, usePing = Block.usePing,
                style = Block.style, pierceMode = Block.pierceMode, learn = Block.learn, useLearned = Block.useLearned, chain = Block.chain, floater = Block.floater,
                chainGrace = Block.chainGrace, rush = Block.rush, verify = Block.verify, sense = Sense and Sense:export() or nil},
            learned = Learner and Learner:export() or nil,
            floater = Block.floaterPos,
            fab = fabRef and {x = fabRef.x, y = fabRef.y, locked = fabRef.locked, minimized = fabRef.minimized} or nil,
            behind = {count = Behind.count, gap = Behind.gap, settle = Behind.settle, m1 = Behind.m1},
            kyoto = {m1 = Kyoto.m1, wait = Kyoto.wait, whirl = Kyoto.whirl, twisted = Kyoto.twisted, side = Kyoto.side},
            picture = Picture.source,
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
    local CharList = {
        {"The Strongest Hero", "Saitama"}, {"Hero Hunter", "Garou"}, {"Hero Hunter (Monster form)", "Garou Monster"}, {"Destructive Cyborg", "Genos"},
        {"Deadly Ninja", "Sonic"}, {"Brutal Demon", "Metal Bat"}, {"Wild Psychic", "Tatsumaki"},
        {"Blade Master", "Atomic Samurai"}, {"Tech Prodigy", "Tech Prodigy"},
    }
    local CharTabs = {}
    if Data then
        sideHeader("CHARACTERS")
        for _, ch in ipairs(CharList) do
            CharTabs[#CharTabs + 1] = {tab = createTab(ch[2], ch[2]:sub(1, 1)), full = ch[1], short = ch[2]}
        end
    end
    sideHeader("TOOLS")
    local Timing_ = createTab("Timing", "T")
    local TechLib = Data and createTab("Techs", "?")
    local Tech   = createTab("Auto Tech", "*")
    local Tele   = createTab("Teleports", "@")
    local Effects = createTab("Effects Preset", "~")
    local ConfigTab = createTab("Config", "=")

    -- Main
    Main_:Banner("Animation Hub", "Auto block  |  Garou Kyoto assist  |  Dash behind the closest player  |  your own picture (Effects tab)", "TSB")
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
                local reset = new("TextButton", {
                    Text = "Reset this combo", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
                    BackgroundColor3 = Theme.Panel, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), Parent = parent,
                }, {corner(8)})
                reset.MouseButton1Click:Connect(function()
                    for key, sl in pairs(sliders) do sl:Set(ComboOptions.DEFAULTS[key]) end
                    for key, dd in pairs(pickers) do dd:Set(ComboOptions.DEFAULTS[key]) end
                    if o.trigAnim ~= "" then o.trigAnim = ""; markDirty() end
                    refreshTrig()
                end)
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
    Credit:Label("Animation Hub UI")
    Credit:Label("Settings are NOT saved automatically - use the Config tab (Save config) when you want to keep them.")
    Credit:Label("Toggle menu: RightShift, or the floating bar: Menu = show/hide, Tech = Auto Tech on/off, Pins = show/hide pinned buttons, Lock = freeze bar and pinned buttons, - = shrink to a dot.")
    Credit:Label("Background: random SFW image from waifu.pics / nekos.best (fan art, not copyright-free).")

    -- Effects Preset: look + menu adjustments
    Effects:Label("Menu look")
    Effects:Dropdown("Theme", ThemeNames, themeName, function(v) pendingTheme = v end)
    -- throw the menu away and build it again from `data` (a snapshot / config table); `data` is used once
    local function restartWith(data, fromFile)
        if genv.AH_DISABLE_REBUILD then toast("Rebuild is disabled") return end
        genv[SESSION_KEY], genv[SESSION_KEY .. "FromFile"] = data, fromFile and true or nil
        cleanup()
        task.spawn(function()
            task.wait(0.4)
            local ok, err = pcall(__run)
            if not ok then
                warn("[Animation Hub] rebuild failed: " .. tostring(err))
                notify("Animation Hub error", tostring(err):sub(1, 180), 15)
            end
        end)
    end
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
            Text = "AH", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Ink,
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

    ready = true                       -- from here on, changing something marks the config as "not saved" (nothing is written)
    dirty = SavedFrom == "carried over"   -- carried-over settings live in memory only
    refreshConfigStatus()
    Main_:Select()
    setMenu(true)                      -- fade + scale the window in
    notify("Animation Hub", "Ready - the floating bar is at the top of your screen (Menu / Tech / Pins / Lock). RightShift also toggles the menu.", 7)
    print("[Animation Hub] ready, UI parent: " .. tostring(Gui.Parent and Gui.Parent.Name))

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
