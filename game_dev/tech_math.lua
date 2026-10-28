--[[
    tech_math.lua - the geometry and timing behind the Tech Lab. Pure Lua (no Roblox APIs): positions and directions are plain {x=, y=, z=} tables,
    so everything here is unit-tested outside the engine (tests/run_tests.lua).

      TechMath.nearest(from, list, radius)                  closest entry of list (each has x,y,z) within radius, and its distance
      TechMath.hookPoint(me, target, vel, look, o)          where a hook dash steers me: the point beside / behind the target, and which side
      TechMath.steer(me, point, seconds, maxSpeed)          flat velocity that covers the way to `point` in `seconds`, never faster than maxSpeed
      TechMath.supaPoints(me, target, o)                    where the Supa dash-in lands me: under them, then behind them
      TechMath.orbitPose(center, startAngle, t01, o)        one frame of a loop dash: position on the circle and the point to look at
      TechMath.heightAbove(floorY, y, maxHeight)            how high the loop dash stays above the ground (never 0)
      TechMath.smoothAlpha(smoothness, dt)                  exponential smoothing factor for a 1..1000 "smoothness" slider (1000+ = instant)
      TechMath.yawTo(from, to) / lerpAngle(a, b, t)         heading (radians, 0 = looking down -Z) and the short way round between two headings
      TechMath.inFrontBox(me, look, them, vel, o)           is `them` (led by vel * lead) inside the box in front of me?
      TechMath.flipAngle(percent, lookUp)                   pitch (radians) for the dash flip
      TechMath.pingWait(ms, mult, lo, hi)                   a wait that scales with ping, clamped
      TechMath.dashClock(cfg)                               which dash is on cooldown ( :seen(kind, now, lag)  :left(kind, now)  :ready(kind, now) )
      TechMath.leadSeconds(pingMs, interpMs, strength)      how far ahead of what I SEE another player really is (seconds)
      TechMath.scaleByPing(base, pingMs, interpMs, strength, refPingMs)   a number tuned at refPing, scaled to the current ping
      TechMath.shiftWait(base, lagSec, strength, o)         a wait anchored on one of MY animations that arrives `lag` late: start the action earlier by that much
      TechMath.predict(pos, vel, seconds)                   pos + vel * seconds
      TechMath.lagLearner(o)                                measures how late my own animations arrive after my input ( :sent(kind, t)  :seen(kind, t)  :value()  :count() )
]]

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

return M
