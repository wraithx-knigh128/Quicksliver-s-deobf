--[[ Wraith's TSB Lab (The Strongest Battlegrounds): the Tech Lab (tech_lab.lua) on the WindUI window library, laid out like the tech hub it was rewritten from:
  one tab per tech family, an Overview with the master switch / Panic / live cooldowns and ping, a Settings tab with the menu options, the ping model and a config manager.
  The tabs are generated from the tech definitions in tech_lab.lua, so a new tech needs no UI code.
  Source file: build it into one script with `python3 game_dev/tsb/build_tsb_lab.py` (it fills in the PingModel / Tech* / UILib / WindUI modules below).
  Nothing in it has been run in the real game - see the README. Nothing is saved unless you press Save config. ]]
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
                 net = {strength = 1, manual = 0, interp = 80, learn = true, ref = 60}, lagger = TM.lagLearner()}
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
        if PING_AWARE[d.id] then
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
        tech.status = text
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
        function c.abort(text) c.result = text; tech.stats.aborts = tech.stats.aborts + 1 end
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

        function c.target(radius) return lab:nearestEnemy(radius) end
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
            local goal = V3(point)
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
        -- like push, but sideways only (gravity and jumps keep working)
        function c.pushFlat(v)
            local bv = c.instance(Instance.new("BodyVelocity"))
            bv.MaxForce = Vector3.new(1e5, 0, 1e5)
            bv.Velocity = Vector3.new(v.x, 0, v.z)
            bv.Parent = root
            return {stop = function() if bv.Parent then bv:Destroy() end end}
        end
        function c.floorY(pos)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {char}
            local hit = Workspace:Raycast(Vector3.new(pos.x, pos.y + 80, pos.z), Vector3.new(0, -300, 0), params)
            return hit and hit.Position.Y or pos.y
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
    function lab:fire(id, info)
        local tech = type(id) == "table" and id or lab.byId[id]
        if not tech then return false, "unknown tech" end
        info = info or {}
        info.manual = info.manual or tech.manual or nil           -- a key / button press (the keys and the UI call lab:fire with manual = true)
        if not lab.alive then return false, "off" end
        if not info.manual and not (lab.master and tech.enabled) then return false, "off" end
        if tech.running then return false, "running" end
        if tech.moves then
            for _, other in ipairs(lab.order) do
                if other ~= tech and other.moves and other.running then
                    if info.manual then setStatus(tech, "not now: " .. other.title .. " is running") end
                    return false, "exclusive"
                end
            end
        end
        if not info.manual and env.busy and env.busy() then return false, "busy" end
        local now = clock()
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
            if ok and ctx.committed then tech.cooldownUntil = clock() + (tech.opt.cooldown or 0) end
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
        lab:fire(tech, {anim = id, enemy = model.Name})
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
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not ctx.alive() then conn:Disconnect(); return end
            local p = plan(fixedSide, first.dir)
            -- the velocity that arrives exactly when the dash time is up (a fixed time constant would only ever cover 63 % of the way)
            local left = math.max(o.duration - (clock() - t0), 1 / 60)
            local v = TM.steer(vec(ctx.root.Position), p.point, left, 300)
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
        ctx.root.CFrame = ctx.root.CFrame * CFrame.new(0, 0, o.stepBack)
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
        ctx.root.CFrame = ctx.root.CFrame + Vector3.new(0, o.height, 0)
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
        ctx.root.CFrame = ctx.root.CFrame * CFrame.new(0, 0, o.stepBack)
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
        ctx.root.CFrame = ctx.root.CFrame + V3(TM.scale(dir, o.hop))
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
                     net = {strength = lab.net.strength, manual = lab.net.manual, interp = lab.net.interp, learn = lab.net.learn, ref = lab.net.ref}}
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
        Size = size, MinSize = Vector2.new(380, 230), SideBarWidth = vp.X < 900 and 124 or 150, HideSearchBar = true,
        Transparent = true, HidePanelBackground = true, ElementsRadius = 14, Radius = 16, ToggleKey = cfg.ToggleKey,
        Topbar = {Height = 38, ButtonsType = "Mac"},
        User = {Enabled = false},
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

    function win:Tab(name, iconKind)
        local ui = Window:Tab{Title = name, Icon = ICONS[iconKind or "dots"] or iconKind or "circle"}        -- (a name that is not one of ours is passed on as a Lucide icon name)
        local tab = {name = name, ui = ui}
        win.Tabs[#win.Tabs + 1] = tab

        function tab:Section(title)
            return ui:Section{Title = title, TextSize = 18}
        end

        function tab:Label(text)                                          -- body text, the way the official WindUI example writes it: a Section with a small, softer title
            local el = {Value = tostring(text or "")}
            local p = ui:Section{Title = el.Value ~= "" and el.Value or " ", TextSize = 14, TextTransparency = 0.25, FontWeight = Enum.FontWeight.Medium}
            function el:Set(v)
                v = tostring(v)
                if v == el.Value then return end
                el.Value = v
                pcall(function() p:SetTitle(v ~= "" and v or " ") end)
            end
            return el
        end

        function tab:Button(o)
            local el = {Value = nil, Title = o.Title, Click = function() fire(o.Callback) end}
            el.Ui = ui:Button{Title = o.Title or "Button", Desc = o.Desc, Icon = "mouse-pointer-click", Callback = function() fire(o.Callback) end}
            decorate(el.Ui, ui)
            function el:Set() end
            -- the grey water flows round the button's OUTLINE (nothing is drawn inside it); it runs while this tab is open
            local okSkin, skinErr = pcall(function()
                local host = el.Ui.ElementFrame
                local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = host
                el.Outline = win:Outline(host, {Thickness = 1.5, Glow = false, Page = ui.ContainerFrame})
            end)
            if not okSkin then onError("button outline", skinErr) end
            return addElement(el)
        end

        function tab:Toggle(o)
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
            addElement(el, o.Flag)
            if el.Value and o.Callback and not o.NoInitialCallback then fire(o.Callback, true) end
            return el
        end

        function tab:Slider(o)
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
            addElement(el, o.Flag)
            return el
        end

        function tab:Dropdown(o)
            local el = {Value = o.Default, Values = o.Values or {}}
            if el.Value == nil then el.Value = el.Values[1] end
            local p
            p = ui:Dropdown{Title = o.Title or "Dropdown", Desc = o.Desc, Values = el.Values, Value = el.Value, AllowNone = false, Callback = function(v)
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
            return addElement(el, o.Flag)
        end

        function tab:Input(o)
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
            return addElement(el, o.Flag)
        end

        function tab:Keybind(o)
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
            return addElement(el, o.Flag)
        end

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


local function __run()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer
    while LocalPlayer == nil do task.wait(0.1); LocalPlayer = Players.LocalPlayer end

    local function service(name) local ok, s = pcall(function() return game:GetService(name) end); return ok and s or nil end
    local VIM, Stats = service("VirtualInputManager"), service("Stats")

    ------------------------------------------------------------------------------------------ session / logging
    local genv = (getgenv and getgenv()) or _G
    if type(genv.__TSBLab) == "table" and genv.__TSBLab.Destroy then pcall(genv.__TSBLab.Destroy) end
    local Hub = {Alive = true, Conns = {}, Cleanups = {}}
    genv.__TSBLab = Hub
    Hub.Destroy = function()
        if not Hub.Alive then return end
        Hub.Alive = false
        for _, c in ipairs(Hub.Conns) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(Hub.Cleanups) do pcall(fn) end
        if Hub.Win then pcall(function() Hub.Win:Destroy() end) end
        if genv.__TSBLab == Hub then genv.__TSBLab = nil end
    end
    local LOG, LOG_MAX = {}, 40
    Hub.Log = LOG
    local function logLine(s)
        LOG[#LOG + 1] = string.format("%s  %s", string.format("%.0f", os.clock() % 100000), s)
        if #LOG > LOG_MAX then table.remove(LOG, 1) end
    end
    local function report(where, err) logLine("[" .. where .. "] " .. tostring(err)) end
    local function guard(where, fn)
        return function(...)
            local ok, err = pcall(fn, ...)
            if not ok then report(where, err) end
        end
    end
    local function track(conn) Hub.Conns[#Hub.Conns + 1] = conn; return conn end
    local function onCleanup(fn) Hub.Cleanups[#Hub.Cleanups + 1] = fn end

    ------------------------------------------------------------------------------------------ what this executor can do
    local Cap = {
        files = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function",
        listfiles = type(listfiles) == "function",
        folders = type(makefolder) == "function" and type(isfolder) == "function",
        delfile = type(delfile) == "function",
        clipboard = type(setclipboard) == "function",
        gethui = type(gethui) == "function",
    }
    local function uiParent()
        if Cap.gethui then local ok, h = pcall(gethui); if ok and h then return h end end
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg then
            local okp = pcall(function() local f = Instance.new("Folder"); f.Parent = cg; f:Destroy() end)
            if okp then return cg end
        end
        return LocalPlayer:WaitForChild("PlayerGui")
    end
    local PARENT = uiParent()

    ------------------------------------------------------------------------------------------ ping (round trip, smoothed: one lag spike must not move every timing)
    local PingM = PingModel.new(0.2)
    local function samplePing()
        local ok, ms = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and type(ms) == "number" then PingM:sample(ms) end
    end
    samplePing()

    ------------------------------------------------------------------------------------------ menu settings + config files
    local function clampNum(v, lo, hi, default) if type(v) == "number" and v == v then return math.max(lo, math.min(hi, v)) end return default end
    -- the Lab's own colours (the standard WindUI themes stay available too)
    WindAdapter.addThemes({
        {Name = "Frost", Accent = "#0f1c24", Dialog = "#101c24", Outline = "#bfefff", Text = "#eaf8ff", Placeholder = "#7fa3b3", Background = "#0b1218", Button = "#2c4a5a", Icon = "#8fd8f0",
         Toggle = "#36d1ff", Slider = "#36d1ff", Checkbox = "#36d1ff", Primary = "#36d1ff", SliderIcon = "#8fd8f0", PanelBackground = "#bfefff", PanelBackgroundTransparency = 0.95,
         LabelBackground = "#000000", LabelBackgroundTransparency = 0.8, ElementBackground = "#17262f", ElementBackgroundTransparency = 0},
        {Name = "Ember", Accent = "#1f1410", Dialog = "#22160f", Outline = "#ffd9b8", Text = "#fff1e6", Placeholder = "#b39a88", Background = "#140d09", Button = "#5a3a28", Icon = "#ffb27a",
         Toggle = "#ff8a3d", Slider = "#ff8a3d", Checkbox = "#ff8a3d", Primary = "#ff8a3d", SliderIcon = "#ffb27a", PanelBackground = "#ffd9b8", PanelBackgroundTransparency = 0.95,
         LabelBackground = "#000000", LabelBackgroundTransparency = 0.8, ElementBackground = "#2b1c14", ElementBackgroundTransparency = 0},
        {Name = "Mint", Accent = "#0f1f19", Dialog = "#10201a", Outline = "#c9ffe6", Text = "#ecfff6", Placeholder = "#84ad9a", Background = "#0a130f", Button = "#2c5a46", Icon = "#8fe8c0",
         Toggle = "#3ddc97", Slider = "#3ddc97", Checkbox = "#3ddc97", Primary = "#3ddc97", SliderIcon = "#8fe8c0", PanelBackground = "#c9ffe6", PanelBackgroundTransparency = 0.95,
         LabelBackground = "#000000", LabelBackgroundTransparency = 0.8, ElementBackground = "#16291f", ElementBackgroundTransparency = 0},
    })
    local THEMES = WindAdapter.ThemeNames
    local FLOAT_DEFS = {   -- the on-screen buttons: id, label, icon, accent, the tech it runs (nil = Panic)
        {id = "panic", title = "PANIC", icon = "close", accent = {236, 64, 72}},
        {id = "hook", title = "HOOK", icon = "crosshair", accent = {120, 200, 255}, tech = "hook"},
        {id = "m1reset", title = "M1 RESET", icon = "bolt", accent = {255, 200, 80}, tech = "m1reset"},
        {id = "emotedash", title = "EMOTE DASH", icon = "move", accent = {170, 120, 255}, tech = "emotedash"},
        {id = "backdash", title = "BACKDASH", icon = "chevron_down", accent = {120, 230, 160}, tech = "backdash"},
        {id = "microdash", title = "MICRO", icon = "spark", accent = {255, 140, 200}, tech = "microdash"},
        {id = "shovedash", title = "SHOVE", icon = "knife", accent = {255, 160, 90}, tech = "shovedash"},
    }
    local DEFAULT_UI = {theme = "Frost", uiKey = "RightShift", uiScale = 0.9, uiAlpha = 0.45, waves = "High", btnSize = 76, btnLock = false, autoLoad = false, configName = "default"}
    local S = {}
    for k, v in pairs(DEFAULT_UI) do S[k] = v end
    S.floats = {}
    for i, d in ipairs(FLOAT_DEFS) do S.floats[d.id] = {x = -1, y = -1, visible = d.id == "panic"} end      -- -1 = placed down the right edge

    local DIR, INDEX = "TSBLab", "TSBLab/index.json"
    local function cleanName(name)
        name = tostring(name or ""):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if #name > 32 then name = name:sub(1, 32) end
        return name ~= "" and name or "default"
    end
    local function pathOf(name) return DIR .. "/" .. cleanName(name) .. ".json" end
    local function ensureDir()
        if Cap.folders then
            local okd, has = pcall(isfolder, DIR)
            if okd and not has then pcall(makefolder, DIR) end
        end
    end
    local function decodeFile(path)
        if not (Cap.files and pcall(isfile, path) and isfile(path)) then return nil end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if ok and type(data) == "table" then return data end
        report("config", data)
    end
    local function listConfigs()
        local out = {}
        if Cap.listfiles then
            local ok, files = pcall(listfiles, DIR)
            if ok and type(files) == "table" then
                for _, f in ipairs(files) do
                    local name = tostring(f):match("([^/\\]+)%.json$")
                    if name and name ~= "index" then out[#out + 1] = name end
                end
            end
        end
        table.sort(out)
        return out
    end
    -- the settings that live outside the Tech Lab; anything invalid in a file falls back to the default
    local function mergeUI(saved)
        if type(saved) ~= "table" then return end
        if type(saved.theme) == "string" then for _, t in ipairs(THEMES) do if t == saved.theme then S.theme = t end end end
        if type(saved.uiKey) == "string" and saved.uiKey:match("^%a[%w]*$") and #saved.uiKey <= 16 then S.uiKey = saved.uiKey end
        S.uiScale = clampNum(saved.uiScale, 0.55, 1.2, S.uiScale)
        S.uiAlpha = clampNum(saved.uiAlpha, 0, 0.9, S.uiAlpha)
        if saved.waves == "High" or saved.waves == "Low" or saved.waves == "Off" then S.waves = saved.waves end
        S.btnSize = clampNum(saved.btnSize, 56, 120, S.btnSize)
        if type(saved.btnLock) == "boolean" then S.btnLock = saved.btnLock end
    end
    local function mergeFloats(saved)
        if type(saved) ~= "table" then return end
        for id, f in pairs(S.floats) do
            local sf = saved[id]
            if type(sf) == "table" then
                f.x, f.y = clampNum(sf.x, -1, 1, f.x), clampNum(sf.y, -1, 1, f.y)
                if type(sf.visible) == "boolean" then f.visible = sf.visible end
            end
        end
    end
    local savedTech
    local loadedFrom = "none"
    local function adopt(data, name)
        if type(data) ~= "table" then return false end
        mergeUI(data.ui)
        mergeFloats(data.floats)
        savedTech = type(data.techlab) == "table" and data.techlab or nil
        S.configName = cleanName(name)
        loadedFrom = "file"
        return true
    end
    do   -- start-up: only a config you saved yourself is loaded, and only when you asked for Auto load when you saved it
        local index = decodeFile(INDEX)
        if index and index.autoload == true and type(index.name) == "string" then
            if adopt(decodeFile(pathOf(index.name)), index.name) then S.autoLoad = true end
        end
    end

    ------------------------------------------------------------------------------------------ the window (declared first: toasts raised before it exists wait in a queue)
    local Win
    local queued = {}
    local function notify(title, content, kind, secs)
        if Win then Win:Notify{Title = title, Content = content, Type = kind or "info", Duration = secs or 4}; return end
        queued[#queued + 1] = {title, content, kind, secs}
    end

    ------------------------------------------------------------------------------------------ the Tech Lab engine
    local Floats = {}
    local statusLabels = {}
    local dirty = false
    local ready = false
    local configStatus
    local function refreshConfigStatus()
        if not configStatus then return end
        local where = loadedFrom == "file" and ("Config '" .. S.configName .. "' is loaded.") or "No config loaded: everything is at its defaults."
        configStatus:Set(where .. (dirty and "  Changes since then are NOT saved." or ""))
    end
    local function markDirty()
        if not ready or dirty then return end
        dirty = true
        refreshConfigStatus()
    end
    local function shortStatus(tech)
        local t = tech.status or ""
        if #t > 26 then t = t:sub(1, 25) .. "~" end
        return t
    end
    local lab
    local function statusText(tech) return "Starts: " .. tech.when .. "\nStatus: " .. tech.status end
    lab = TechLab.new({
        Players = Players, RunService = RunService, UserInputService = UIS, Workspace = workspace, LocalPlayer = LocalPlayer, VirtualInput = VIM,
        TechMath = TechMath, TechData = TechData, TechOptions = TechOptions,
        connect = function(sig, fn) return track(sig:Connect(fn)) end,
        safe = function(fn, ...) local ok, r = pcall(fn, ...); if ok then return r end end,
        clock = os.clock,
        pingMs = function() return PingM:value() end,
        jitterMs = function() return PingM:jitter() end,
        busy = function() return false end,
        log = function(msg) logLine(msg) end,
        toast = function(msg) notify("Tech Lab", msg, "info", 3) end,
        onStatus = function(tech)
            local l = statusLabels[tech.id]
            if l then l:Set(statusText(tech)) end
            local f = Floats[tech.id]
            if f then
                local kind = tech.running and "wait" or (tech.enabled and "ready" or "off")
                f:SetStatus(shortStatus(tech), kind)
            end
        end,
    })
    if savedTech then lab:import(savedTech) end
    onCleanup(function() lab:destroy() end)

    local function snapshot()
        local floats = {}
        for id, f in pairs(S.floats) do
            local live = Floats[id]
            local x, y = f.x, f.y
            if live then x, y = live:GetPos() end
            floats[id] = {x = x, y = y, visible = f.visible}
        end
        return {version = 1, ui = {theme = S.theme, uiKey = S.uiKey, uiScale = S.uiScale, uiAlpha = S.uiAlpha, waves = S.waves, btnSize = S.btnSize, btnLock = S.btnLock},
            floats = floats, techlab = lab:export()}
    end
    local function saveConfig(name)
        if not Cap.files then return false, "Your executor cannot write files, so nothing can be saved." end
        name = cleanName(name)
        ensureDir()
        local okj, json = pcall(function() return HttpService:JSONEncode(snapshot()) end)
        if not okj or type(json) ~= "string" then return false, "Could not turn the settings into a file." end
        if not pcall(writefile, pathOf(name), json) then return false, "Your executor refused to write the file." end
        pcall(writefile, INDEX, HttpService:JSONEncode({autoload = S.autoLoad == true, name = name}))      -- (what Auto load means is decided when you SAVE)
        S.configName, loadedFrom, dirty = name, "file", false
        refreshConfigStatus()
        return true
    end
    local function deleteConfig(name)
        name = cleanName(name)
        local path = pathOf(name)
        local existed = Cap.files and pcall(isfile, path) and isfile(path)
        if not existed then return false, "There is no config called " .. name end
        if Cap.delfile then pcall(delfile, path) elseif Cap.files then pcall(writefile, path, "") end
        local index = decodeFile(INDEX)
        if index and index.name == name then pcall(writefile, INDEX, HttpService:JSONEncode({autoload = false, name = name})) end
        if S.configName == name then loadedFrom = "none" end
        refreshConfigStatus()
        return true
    end

    ------------------------------------------------------------------------------------------ the window
    local function traceback(e) return debug.traceback(tostring(e), 2) end
    local usingWind = false
    local function keyCodeFor(name)
        local ok, code = pcall(function() return Enum.KeyCode[name] end)
        return ok and code or Enum.KeyCode.RightShift
    end
    local function makeWindow(cfg)
        local okLib, WindUI = xpcall(WindUILoader, traceback)
        if okLib and type(WindUI) == "table" and WindUI.CreateWindow then
            cfg.Theme = WindAdapter.themeFor(S.theme)
            local ok, res = xpcall(WindAdapter.new, traceback, WindUI, UILib, cfg)
            if ok then usingWind = true; return res end
            report("WindUI window", res)
        else
            report("WindUI load", WindUI)
        end
        queued[#queued + 1] = {"WindUI could not start", "Using the small built-in menu instead (details: Settings > Log). Your executor may block the library's file / web calls.", "warn", 8}
        local theme = "Ocean"
        cfg.Theme = theme
        return UILib.new(cfg)
    end
    Win = makeWindow{Title = "Wraith's TSB Lab", Subtitle = "The Strongest Battlegrounds", Group = "Wraith's TSB Lab", Parent = PARENT, GuiName = "WraithsTSBLab", Folder = "TSBLab",
        WaveMode = S.waves, ToggleKey = keyCodeFor(S.uiKey), OnError = report, WindowAlpha = S.uiAlpha, Scale = S.uiScale, Mono = false,
        WindowIcon = "sword", OpenColors = {"#7ad7ff", "#9b7bff"}}
    S.theme = Win:GetTheme()
    Hub.Win = Win
    Hub.Lab = lab
    Hub.S = S
    for _, q in ipairs(queued) do notify(q[1], q[2], q[3], q[4]) end
    queued = {}

    ------------------------------------------------------------------------------------------ the on-screen buttons
    local function floatPos(index)                                  -- down the right edge, two columns
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local size = S.btnSize
        local col = (index - 1) % 2 + 1
        local row = math.floor((index - 1) / 2)
        local x = vp.X - 12 - col * size - (col - 1) * 8
        local y = vp.Y * 0.14 + row * (size + 26)
        return math.max(0, math.min(x, vp.X - size)) / vp.X, math.max(0, math.min(y, vp.Y - size)) / vp.Y
    end
    for i, d in ipairs(FLOAT_DEFS) do
        local f = S.floats[d.id]
        local fx, fy = f.x, f.y
        if fx < 0 or fy < 0 then fx, fy = floatPos(i) end
        Floats[d.id] = Win:Floating{Id = d.id, Title = d.title, Icon = d.icon, Accent = d.accent, Size = S.btnSize, Pos = {fx, fy}, Visible = f.visible, Locked = S.btnLock,
            OnPress = function()
                if not d.tech then
                    lab:cancelAll("cancelled: panic")
                    return true
                end
                local ok = lab:fire(d.tech, {manual = true})
                local tech, f = lab.techs[d.tech], Floats[d.id]
                if f then
                    f:Flash(ok == true)
                    if ok and tech.opt.cooldown and tech.opt.cooldown > 0.1 then f:Cooldown(tech.opt.cooldown) end
                end
                return "async"
            end,
            OnMoved = function(x, y) f.x, f.y = x, y; markDirty() end}
    end

    ------------------------------------------------------------------------------------------ building the menu a few controls per frame (a phone builds a WindUI menu slowly)
    local paceCount, paceStart = 0, os.clock()
    local function pace()
        paceCount = paceCount + 1
        if paceCount >= 6 or os.clock() - paceStart > 0.012 then
            paceCount = 0
            task.wait()
            paceStart = os.clock()
            if not Hub.Alive then error("__unloaded__", 0) end
        end
    end
    local function paced(tab)
        for _, name in ipairs({"Section", "Label", "Toggle", "Slider", "Dropdown", "Keybind", "Button", "Input"}) do
            local f = tab[name]
            if f then tab[name] = function(self, ...) local r = f(self, ...); pace(); return r end end
        end
        return tab
    end
    local function tabIcon(wind, classic) return usingWind and wind or classic end

    ------------------------------------------------------------------------------------------ Overview
    local overview = paced(Win:Tab("Overview", tabIcon("layout-dashboard", "grid")))
    overview:Section("Tech Lab")
    overview:Label("The techs from your own Dovi's Hub script, rebuilt as small sequences on one engine: every wait stops when you die, respawn, press Panic or switch the tech off, everything a tech creates is removed again, a tech that starts with a dash waits for that dash's cooldown, and only one moving tech runs at a time. Everything starts OFF. Nothing was run in the real game - if a tech does not react, its trigger animation id has probably changed: use 'Learn trigger' inside the tech.")
    overview:Toggle{Title = "Tech Lab master switch", Desc = "Off = every tech stops and ignores its trigger", Default = lab.master, Flag = "master", NoInitialCallback = true, Callback = guard("master", function(on)
        if lab.master ~= on then lab:setMaster(on); markDirty() end
    end)}
    overview:Button{Title = "Panic - cancel every running tech", Desc = "Also the red PANIC button on screen", Callback = guard("panic", function()
        lab:cancelAll("cancelled: panic")
        notify("Tech Lab", "Everything cancelled", "good", 2)
    end)}
    overview:Dropdown{Title = "Inputs", Desc = "Auto = the game's own remote, keys when it is missing", Values = {"Auto", "Remote", "Keys"}, Default = lab.input, Flag = "input", Callback = guard("input", function(v)
        if lab.input ~= v then lab:setInput(v); markDirty() end
    end)}
    overview:Toggle{Title = "Wait for the dash cooldown", Desc = "A tech that starts with a dash does not start while that dash is on cooldown", Default = lab.dashGuard, Flag = "dashGuard", NoInitialCallback = true,
        Callback = guard("dashGuard", function(on) if lab.dashGuard ~= on then lab.dashGuard = on; markDirty() end end)}
    overview:Toggle{Title = "Let go of block before an M1", Default = lab.releaseBlock, Flag = "releaseBlock", NoInitialCallback = true,
        Callback = guard("releaseBlock", function(on) if lab.releaseBlock ~= on then lab.releaseBlock = on; markDirty() end end)}
    overview:Section("Live")
    local cooldownLabel = overview:Label("")
    local pingLabel = overview:Label("")

    ------------------------------------------------------------------------------------------ one tab per tech family
    local TABS = {
        {"Supa", "sword", "spark", {"supa"}},
        {"Hook Dash", "link", "crosshair", {"hook"}},
        {"Loop Dash", "refresh-cw", "bolt", {"loop", "loop2"}},
        {"Kiba / Kitty", "crosshair", "crosshair", {"kiba"}},
        {"Kyoto Combo", "swords", "knife", {"kyoto", "dunk", "surf"}},
        {"Lethal Dash", "zap", "bolt", {"lethal", "lethalgrasp"}},
        {"Twisted", "move", "move", {"twisted"}},
        {"M1 Reset", "timer", "dots", {"m1reset", "emotedash", "shovedash"}},
        {"Cancels", "gauge", "dots", {"backdash", "microdash", "uppercutcatch", "uppercutgrasp", "flowinggrasp"}},
        {"Auto Counter", "shield", "dots", {"counter"}},
        {"Tech Helper", "wrench", "gear", {"flip", "catch", "mousedash", "sidem1", "noendlag", "slidem1", "downslam", "fastdash", "dashclip"}},
        {"Awareness", "eye", "eye", {"counteresp", "deathcounter", "blockwarn", "blockesp"}},
    }
    Hub.Tabs = TABS
    local FLOAT_OF = {}
    for _, d in ipairs(FLOAT_DEFS) do if d.tech then FLOAT_OF[d.tech] = d end end

    local function buildTech(tab, id)
        local tech = lab.techs[id]
        tab:Section(tech.title)
        tab:Toggle{Title = "Enable " .. tech.title, Desc = tech.desc, Default = tech.enabled, Flag = id .. ".on", NoInitialCallback = true, Callback = guard(id .. " switch", function(on)
            if lab.techs[id].enabled ~= on then lab:setEnabled(id, on); markDirty() end
        end)}
        statusLabels[id] = tab:Label(statusText(tech))
        local controls = {}
        if tech.manual then
            tab:Button{Title = "Run " .. tech.title .. " now", Desc = tech.when, Callback = guard(id .. " run", function() lab:fire(id, {manual = true}) end)}
        end
        for _, d in ipairs(tech.defs) do
            local key = d.key
            local function put(v)
                if lab.techs[id].opt[key] ~= v then lab:setOption(id, key, v); markDirty() end
            end
            local flag = id .. "." .. key
            local el
            if d.kind == "number" then
                el = tab:Slider{Title = d.label, Min = d.min, Max = d.max, Step = d.step, Default = tech.opt[key], Flag = flag, Callback = guard(flag, put)}
            elseif d.kind == "bool" then
                el = tab:Toggle{Title = d.label, Desc = d.tip, Default = tech.opt[key], Flag = flag, NoInitialCallback = true, Callback = guard(flag, put)}
            elseif d.kind == "choice" then
                el = tab:Dropdown{Title = d.label, Values = d.choices, Default = tech.opt[key], Flag = flag, Callback = guard(flag, put)}
            elseif d.kind == "key" then
                el = tab:Keybind{Title = d.label, Desc = "Press the key you want (any key)", Default = tech.opt[key], Flag = flag, Changed = guard(flag, put), IgnoreProcessed = false}
            else
                el = tab:Input{Title = d.label, Default = tech.opt[key], Placeholder = "empty = the default", Flag = flag, Callback = guard(flag, function(text) put((text:gsub("^%s+", ""):gsub("%s+$", ""))) end)}
            end
            controls[#controls + 1] = {def = d, el = el}
        end
        if not (tech.observer or tech.poll or tech.manual or tech.mouse or tech.key) then
            tab:Button{Title = "Learn trigger: play the move that should start " .. tech.title, Desc = "Listens for the next animation you play (15 s)", Callback = guard(id .. " learn", function()
                lab:learnTrigger(id, function() markDirty() end)
                notify("Tech Lab", "Now play the move that should start " .. tech.title, "info", 4)
            end)}
            tab:Button{Title = "Forget the triggers I taught " .. tech.title, Callback = guard(id .. " forget", function()
                lab:forgetTriggers(id)
                markDirty()
                notify("Tech Lab", "Learned triggers forgotten", "info", 3)
            end)}
        end
        local fd = FLOAT_OF[id]
        if fd then
            tab:Toggle{Title = "Show the on-screen " .. fd.title .. " button", Default = S.floats[fd.id].visible, Flag = "float." .. fd.id, NoInitialCallback = true, Callback = guard(fd.id .. " button", function(on)
                if S.floats[fd.id].visible ~= on then S.floats[fd.id].visible = on; markDirty() end
                if Floats[fd.id] then Floats[fd.id]:SetVisible(on) end
            end)}
        end
        tab:Button{Title = "Reset " .. tech.title .. " to its defaults", Callback = guard(id .. " reset", function()
            for _, c in ipairs(controls) do
                lab:setOption(id, c.def.key, c.def.default)
                c.el:Set(c.def.default, true)
            end
            markDirty()
            notify("Tech Lab", tech.title .. ": options reset", "info", 2)
        end)}
    end
    for _, t in ipairs(TABS) do
        local tab = paced(Win:Tab(t[1], tabIcon(t[2], t[3])))
        for _, id in ipairs(t[4]) do buildTech(tab, id) end
    end

    ------------------------------------------------------------------------------------------ Settings
    local settings = paced(Win:Tab("Settings", tabIcon("settings", "gear")))
    settings:Section("Menu")
    settings:Keybind{Title = "Menu key", Desc = "Shows / hides this window", Default = S.uiKey, Flag = "uiKey", Changed = guard("menu key", function(v)
        if S.uiKey ~= v then S.uiKey = v; Win.ToggleKey = keyCodeFor(v); markDirty() end
    end)}
    settings:Dropdown{Title = "Theme", Values = THEMES, Default = S.theme, Flag = "theme", Callback = guard("theme", function(v)
        if S.theme ~= v then S.theme = v; Win:SetTheme(v); markDirty() end
    end)}
    settings:Slider{Title = "Menu size", Min = 0.55, Max = 1.2, Step = 0.05, Default = S.uiScale, Flag = "uiScale", Callback = guard("uiScale", function(v)
        if S.uiScale ~= v then S.uiScale = v; if Win.SetScale then Win:SetScale(v) end; markDirty() end
    end)}
    settings:Slider{Title = "Window transparency", Min = 0, Max = 0.9, Step = 0.05, Default = S.uiAlpha, Flag = "uiAlpha", Callback = guard("uiAlpha", function(v)
        if S.uiAlpha ~= v then S.uiAlpha = v; if Win.SetBackgroundTransparency then Win:SetBackgroundTransparency(v) end; markDirty() end
    end)}
    settings:Section("Ping")
    settings:Label("What the Tech Lab does with your ping: waits that start at one of your own animations start earlier by how late those animations arrive after your input (measured from your own dashes), another player is led by half your ping plus Roblox's drawing delay, and a number tuned at 60 ms scales with your ping.")
    settings:Slider{Title = "Ping compensation (0 = off, 1 = full)", Min = 0, Max = 2, Step = 0.05, Default = lab.net.strength, Flag = "net.strength", Callback = guard("net.strength", function(v)
        if lab.net.strength ~= v then lab:setNet("strength", v); markDirty() end
    end)}
    settings:Slider{Title = "Typed ping in ms (0 = measure it)", Min = 0, Max = 600, Step = 5, Default = lab.net.manual, Flag = "net.manual", Callback = guard("net.manual", function(v)
        if lab.net.manual ~= v then lab:setNet("manual", v); markDirty() end
    end)}
    settings:Slider{Title = "Roblox's drawing delay for other players (ms)", Min = 0, Max = 250, Step = 5, Default = lab.net.interp, Flag = "net.interp", Callback = guard("net.interp", function(v)
        if lab.net.interp ~= v then lab:setNet("interp", v); markDirty() end
    end)}
    settings:Slider{Title = "The ping my default numbers were tuned at (ms)", Min = 10, Max = 300, Step = 5, Default = lab.net.ref, Flag = "net.ref", Callback = guard("net.ref", function(v)
        if lab.net.ref ~= v then lab:setNet("ref", v); markDirty() end
    end)}
    settings:Toggle{Title = "Measure how late my own animations arrive", Desc = "Every dash I send and the animation that answers it", Default = lab.net.learn, Flag = "net.learn", NoInitialCallback = true,
        Callback = guard("net.learn", function(on) if lab.net.learn ~= on then lab:setNet("learn", on); markDirty() end end)}
    settings:Section("On-screen buttons")
    settings:Slider{Title = "Button size", Min = 56, Max = 120, Step = 2, Default = S.btnSize, Flag = "btnSize", Callback = guard("btnSize", function(v)
        if S.btnSize ~= v then
            S.btnSize = v
            for _, f in pairs(Floats) do f:SetSize(v) end
            markDirty()
        end
    end)}
    settings:Toggle{Title = "Lock the buttons in place", Default = S.btnLock, Flag = "btnLock", NoInitialCallback = true, Callback = guard("btnLock", function(on)
        if S.btnLock ~= on then S.btnLock = on; for _, f in pairs(Floats) do f:SetLocked(on) end; markDirty() end
    end)}
    settings:Toggle{Title = "Show the PANIC button", Default = S.floats.panic.visible, Flag = "float.panic", NoInitialCallback = true, Callback = guard("panic button", function(on)
        if S.floats.panic.visible ~= on then S.floats.panic.visible = on; markDirty() end
        if Floats.panic then Floats.panic:SetVisible(on) end
    end)}
    settings:Label("The buttons for Hook Dash, M1 Reset, Emote Dash, Backdash Cancel, Micro Dash and Shove Dash are switched on inside each tech. Drag one to move it; it keeps its place when you press Save config.")
    settings:Section("Config")
    settings:Label("NOTHING is saved automatically. A config holds the menu options, the on-screen buttons and every tech's switch / option / learned trigger. Auto load is decided when you press Save.")
    configStatus = settings:Label("")
    local nameInput = settings:Input{Title = "Config name", Default = S.configName, Placeholder = "default", Flag = "configName", Callback = guard("config name", function(v) S.configName = cleanName(v) end)}
    local allConfigs = settings:Dropdown{Title = "All configs", Desc = "Pick one, then Load", Values = (function() local l = listConfigs(); return #l > 0 and l or {"(none yet)"} end)(), Default = S.configName, Flag = "allConfigs",
        Callback = guard("all configs", function(v) if v ~= "(none yet)" then S.configName = cleanName(v); nameInput:Set(S.configName, true) end end)}
    local function refreshConfigList()
        local l = listConfigs()
        allConfigs:SetValues(#l > 0 and l or {"(none yet)"})
    end
    settings:Toggle{Title = "Auto load", Desc = "Load this config the next time the script starts (written when you press Save)", Default = S.autoLoad, Flag = "autoLoad", NoInitialCallback = true,
        Callback = guard("autoLoad", function(on) if S.autoLoad ~= on then S.autoLoad = on; markDirty() end end)}
    settings:Button{Title = "Save config", Callback = guard("save", function()
        local ok, why = saveConfig(S.configName)
        notify(ok and "Config saved" or "Not saved", ok and ("'" .. S.configName .. "' will be available next time") or tostring(why), ok and "good" or "bad", 4)
        if ok then refreshConfigList() end
    end)}
    settings:Button{Title = "Load config (rebuilds nothing - applies live)", Callback = guard("load", function()
        local data = decodeFile(pathOf(S.configName))
        if not data then notify("Not loaded", "There is no saved config called " .. S.configName, "warn", 4) return end
        mergeUI(data.ui)
        mergeFloats(data.floats)
        if type(data.techlab) == "table" then lab:import(data.techlab) end
        loadedFrom, dirty = "file", false
        for _, el in ipairs(Win.Elements) do                       -- the controls follow the new values
            local flag = el.Flag
            if flag then
                local id, key = flag:match("^([%w]+)%.([%w]+)$")
                local tech = id and lab.techs[id]
                if tech and key == "on" then el:Set(tech.enabled, true)
                elseif tech and tech.opt[key] ~= nil then el:Set(tech.opt[key], true)
                elseif id == "net" and lab.net[key] ~= nil then el:Set(lab.net[key], true)
                elseif id == "float" and S.floats[key] then el:Set(S.floats[key].visible, true) end
            end
        end
        for id, f in pairs(Floats) do f:SetVisible(S.floats[id].visible) end
        Win:SetTheme(S.theme)
        if Win.SetScale then Win:SetScale(S.uiScale) end
        if Win.SetBackgroundTransparency then Win:SetBackgroundTransparency(S.uiAlpha) end
        refreshConfigStatus()
        notify("Config loaded", "'" .. S.configName .. "' is applied", "good", 3)
    end)}
    settings:Button{Title = "Delete config", Callback = guard("delete", function()
        local ok, why = deleteConfig(S.configName)
        notify(ok and "Config deleted" or "Not deleted", ok and "The next start is clean" or tostring(why), ok and "good" or "warn", 3)
        if ok then refreshConfigList() end
    end)}
    settings:Button{Title = "Refresh the list", Callback = guard("refresh", refreshConfigList)}
    settings:Section("Help")
    settings:Button{Title = "Copy the log (for a bug report)", Callback = guard("copy log", function()
        local text = #LOG > 0 and table.concat(LOG, "\n") or "no errors logged"
        if Cap.clipboard and pcall(setclipboard, text) then notify("Log copied", #LOG .. " lines", "good", 2) else notify("Log", LOG[#LOG] or "empty", "info", 6) end
    end)}
    settings:Button{Title = "Unload the script", Desc = "Removes the window and every tech", Callback = guard("unload", function() Hub.Destroy() end)}

    ------------------------------------------------------------------------------------------ the live panel
    do
        local acc, last = 0, ""
        track(RunService.Heartbeat:Connect(function(dt)
            acc = acc + dt
            if acc < 0.25 then return end
            acc = 0
            samplePing()
            if not Win.Main.Visible then return end
            local f, sd = lab:dashLeft("forward"), lab:dashLeft("side")
            local n = lab:netInfo()
            local text = string.format("Forward dash: %s   |   Side dash: %s\nPing %s ms (jitter %.0f)   |   my animations arrive %s after my input   |   other players are led by %.0f ms",
                f > 0 and string.format("%.1f s", f) or "ready", sd > 0 and string.format("%.1f s", sd) or "ready", n.ping and string.format("%.0f", n.ping) or "?", n.jitter,
                n.lag and string.format("%.0f ms", n.lag * 1000) or string.format("not measured yet (%d of 3 samples)", n.samples), n.lead * 1000)
            if text ~= last then
                last = text
                local a, b = text:match("^(.-)\n(.*)$")
                cooldownLabel:Set(a); pingLabel:Set(b)
            end
        end))
    end

    refreshConfigStatus()
    Win:SelectTab("Overview")
    ready = true
    notify("Wraith's TSB Lab loaded", "33 techs, all off. Nothing was run in the real game: use Learn trigger if one does not react.", "good", 5)
end

local ok, err = xpcall(__run, function(e) return debug.traceback(tostring(e), 2) end)
if not ok and not tostring(err):find("__unloaded__", 1, true) then
    warn("[Wraith's TSB Lab] failed to start: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Wraith's TSB Lab failed to start", Text = tostring(err):sub(1, 180), Duration = 20})
    end)
end
