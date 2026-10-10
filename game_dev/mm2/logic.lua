--[[ MM2 hub - pure logic (no Roblox types, so it is unit-tested with plain numbers and tables).
  Roles from tools / remote data, aim prediction, direction text for the gun finder, target picking,
  and the "which argument of a recorded shot is the aim point" planner used by shot replay / silent aim. ]]
local Logic = {}

local sqrt, atan2, floor, max, min = math.sqrt, math.atan2 or math.atan, math.floor, math.max, math.min

------------------------------------------------------------------------------------------------ roles
local ROLE_WORDS = {
    murderer = "Murderer", murder = "Murderer", killer = "Murderer", infected = "Infected", zombie = "Infected",
    sheriff = "Sheriff", detective = "Sheriff", gunner = "Sheriff",
    hero = "Hero",
    innocent = "Innocent", civilian = "Innocent", survivor = "Innocent", innocents = "Innocent",
}

-- "murderer " -> "Murderer"; anything unknown -> nil
function Logic.normalizeRole(s)
    if type(s) ~= "string" then return nil end
    return ROLE_WORDS[(s:lower():gsub("[^%a]", ""))]
end

-- what a Tool's name says about its owner: knife -> Murderer, gun -> Sheriff (or Hero), anything else nil
function Logic.toolRole(name)
    if type(name) ~= "string" then return nil end
    local n = name:lower()
    if n:find("knife", 1, true) then return "Murderer" end
    if n == "gun" or n == "revolver" or n:find("^gun[^%a]") then return "Sheriff" end
    return nil
end

-- "Gun" / "Knife" / nil : which weapon slot a tool name belongs to
function Logic.weaponOf(name)
    local r = Logic.toolRole(name)
    if r == "Murderer" then return "Knife" end
    if r == "Sheriff" then return "Gun" end
    return nil
end

local function deadFlag(v)
    if v.Dead == true or v.dead == true or v.Killed == true or v.killed == true then return true end
    if v.Alive == false or v.alive == false then return true end
    return false
end

-- Walks whatever table a "player data" remote returned and lists {key=, role=, dead=}. It accepts the shapes seen in
-- Roblox games: {[name] = {Role = "Murderer"}}, {[name] = "Murderer"}, {Murderer = "name", Sheriff = "name"}, and one level of nesting.
function Logic.parseRoles(data, depth)
    local out = {}
    depth = depth or 0
    if type(data) ~= "table" or depth > 2 then return out end
    for k, v in pairs(data) do
        local keyRole = type(k) == "string" and Logic.normalizeRole(k) or nil
        if type(v) == "table" then
            local r = Logic.normalizeRole(v.Role or v.role or v.Team or v.team)
            if r then
                out[#out + 1] = {key = k, role = r, dead = deadFlag(v)}
            elseif keyRole and (v.Name or v.name or v.Player or v.player) then
                out[#out + 1] = {key = v.Name or v.name or v.Player or v.player, role = keyRole, dead = deadFlag(v)}
            else
                for _, e in ipairs(Logic.parseRoles(v, depth + 1)) do out[#out + 1] = e end
            end
        elseif type(v) == "string" then
            local r = Logic.normalizeRole(v)
            if r and keyRole == nil then out[#out + 1] = {key = k, role = r, dead = false}
            elseif keyRole then out[#out + 1] = {key = v, role = keyRole, dead = false} end
        end
    end
    return out
end

------------------------------------------------------------------------------------------------ aim
-- Where to aim at a moving target. target / velocity / shooter are {x,y,z}; opts:
--   speed    projectile speed in studs/s (0 or nil = instant hit, only latency is led)
--   latency  seconds (one way) added on top
--   strength 0..2 multiplier on the lead (1 = full prediction)
--   maxLead  seconds, never lead further than this
--   vertical 0..1 how much of the vertical velocity to lead (jumping targets are hard to predict)
function Logic.lead(tx, ty, tz, vx, vy, vz, sx, sy, sz, opts)
    opts = opts or {}
    local speed = opts.speed or 0
    local latency = max(0, opts.latency or 0)
    local strength = opts.strength == nil and 1 or opts.strength
    local maxLead = opts.maxLead or 0.6
    local vertical = opts.vertical == nil and 0.5 or opts.vertical
    local t = latency
    local px, py, pz = tx, ty, tz
    for _ = 1, 4 do                                      -- solve "where is it when the shot arrives" (converges in a few steps)
        local dx, dy, dz = px - sx, py - sy, pz - sz
        local flight = speed > 0 and sqrt(dx * dx + dy * dy + dz * dz) / speed or 0
        t = min(maxLead, (latency + flight) * strength)
        px, py, pz = tx + vx * t, ty + vy * t * vertical, tz + vz * t
    end
    return px, py, pz, t
end

-- Direction of (dx,dz) relative to where I look (lx,lz), as one of 8 words; ahead is 0 degrees, right 90.
function Logic.direction(dx, dz, lx, lz)
    local ll = sqrt(lx * lx + lz * lz)
    if ll < 1e-6 then lx, lz, ll = 0, -1, 1 end
    lx, lz = lx / ll, lz / ll
    local fwd = dx * lx + dz * lz
    local rgt = dx * (-lz) + dz * lx                     -- right vector of look (lx, lz): (-lz, lx)
    local ang = atan2(rgt, fwd) * 180 / math.pi          -- 0 ahead, 90 right, -90 left, +-180 behind
    local names = {"ahead", "ahead-right", "right", "behind-right", "behind", "behind-left", "left", "ahead-left"}
    local idx = floor(((ang + 22.5) % 360) / 45) + 1
    return names[idx], ang
end

-- "37 studs ahead-left, 6 higher"
function Logic.describe(dx, dy, dz, lx, lz)
    local flat = sqrt(dx * dx + dz * dz)
    local dist = sqrt(dx * dx + dy * dy + dz * dz)
    local where = flat < 3 and "right here" or Logic.direction(dx, dz, lx, lz)
    local s = string.format("%d studs %s", floor(dist + 0.5), where)
    if dy > 6 then s = s .. ", " .. floor(dy + 0.5) .. " higher" elseif dy < -6 then s = s .. ", " .. floor(-dy + 0.5) .. " lower" end
    return s
end

-- Picks one candidate id. cands: {{id=, dist=, screen=(pixels from the crosshair or nil when off screen), visible=bool, role=, alive=bool}}
-- opts: mode ("Murderer" | "Sheriff" | "Sheriff first" | "Closest to crosshair" | "Nearest"), fov (pixels), maxDist, needVisible
function Logic.pickTarget(cands, opts)
    local best, bestScore
    local mode = opts.mode or "Nearest"
    for _, c in ipairs(cands) do
        local ok = c.alive ~= false and c.dist <= (opts.maxDist or math.huge)
        if ok and opts.needVisible and not c.visible then ok = false end
        if ok and mode == "Murderer" and c.role ~= "Murderer" and c.role ~= "Infected" then ok = false end
        if ok and mode == "Sheriff" and c.role ~= "Sheriff" and c.role ~= "Hero" then ok = false end
        local score = c.dist
        if ok and mode == "Sheriff first" and c.role ~= "Sheriff" and c.role ~= "Hero" then score = c.dist + 1e6 end   -- anyone, but the sheriff / hero wins
        if ok and mode == "Closest to crosshair" then
            if c.screen == nil or c.screen > (opts.fov or math.huge) then ok = false else score = c.screen end
        end
        if ok and opts.fov and opts.fovAlways and (c.screen == nil or c.screen > opts.fov) then ok = false end
        if ok and (bestScore == nil or score < bestScore) then best, bestScore = c.id, score end
    end
    return best
end


------------------------------------------------------------------------------------------------ ping + velocity
-- Smoothed round-trip time. Samples are milliseconds; one spike (a lag blip) must not move the aim, so the value is the EMA of the median of
-- the last few samples.
function Logic.newPing(opts)
    opts = opts or {}
    local keep, alpha = opts.keep or 5, opts.alpha or 0.35
    local self = {samples = {}, ema = nil}
    function self:add(ms)
        if type(ms) ~= "number" or ms ~= ms or ms < 0 or ms > 5000 then return end
        local s = self.samples
        s[#s + 1] = ms
        if #s > keep then table.remove(s, 1) end
        local sorted = {}
        for i, v in ipairs(s) do sorted[i] = v end
        table.sort(sorted)
        local median = sorted[floor((#sorted + 1) / 2)]
        self.ema = self.ema and (self.ema + (median - self.ema) * alpha) or median
    end
    function self:ms() return self.ema or (opts.default or 80) end
    function self:seconds() return self:ms() / 1000 end
    return self
end

-- How far ahead of what I SEE the target really is when my shot arrives: my screen shows other players about one interpolation delay plus half
-- the round trip in the past, and the shot needs another half round trip to reach the server => about ping + interpolation.
--   pingMs      smoothed round trip (ms)       comp  0..1.5 multiplier on the ping part      interpMs  render delay of remote players
--   extraMs     manual trim (can be negative)  max   upper bound in seconds
function Logic.pingLead(pingMs, comp, interpMs, extraMs, maxLead)
    local lead = (pingMs or 0) * (comp == nil and 1 or comp) + (interpMs or 0) + (extraMs or 0)
    return max(0, min(maxLead or 0.8, lead / 1000))
end

-- Velocity from recent position samples {{t=, x=, y=, z=}, ...} (oldest first): the displacement over the last `window` seconds.
-- A jump faster than `maxSpeed` studs/s is a teleport / respawn, not running: it reports 0.
function Logic.estimateVelocity(samples, window, maxSpeed)
    local n = #samples
    if n < 2 then return 0, 0, 0 end
    local cap = maxSpeed or 90
    local last = samples[n]
    local first = last
    for i = n - 1, 1, -1 do
        local a, b = samples[i], samples[i + 1]
        local sdt = b.t - a.t
        if sdt > 0 and sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2) / sdt > cap then break end   -- a teleport: nothing older counts
        first = a
        if last.t - a.t >= (window or 0.18) then break end
    end
    local dt = last.t - first.t
    if dt < 0.04 then return 0, 0, 0 end
    local vx, vy, vz = (last.x - first.x) / dt, (last.y - first.y) / dt, (last.z - first.z) / dt
    if sqrt(vx * vx + vy * vy + vz * vz) > cap then return 0, 0, 0 end
    return vx, vy, vz
end

-- physics velocity when the engine reports one, otherwise what the position history says; never faster than `maxSpeed`
function Logic.pickVelocity(px, py, pz, hx, hy, hz, maxSpeed)
    local ps = sqrt(px * px + py * py + pz * pz)
    local hs = sqrt(hx * hx + hy * hy + hz * hz)
    local vx, vy, vz, speed = px, py, pz, ps
    if not (ps >= 0.5 or hs < 1) then vx, vy, vz, speed = hx, hy, hz, hs end
    local cap = maxSpeed or 90
    if speed > cap then local k = cap / speed; return vx * k, vy * k, vz * k end
    return vx, vy, vz
end

------------------------------------------------------------------------------------------------ shot templates
-- A recorded shot is a list of arguments. descs[i] = {kind = "vec" | "cf" | "inst" | "other", x,y,z}.
-- Returns plan[i] = "origin" | "target" for the position arguments:
--   one position  -> it is the aim point
--   several       -> the one closest to my head (within maxOrigin studs) is the origin, the others are aim points
function Logic.planShot(descs, hx, hy, hz, maxOrigin)
    local plan, positions = {}, {}
    for i, d in ipairs(descs) do
        if d.kind == "vec" or d.kind == "cf" then positions[#positions + 1] = i end
    end
    if #positions == 0 then return plan end
    if #positions == 1 then plan[positions[1]] = "target"; return plan end
    local nearest, nd
    for _, i in ipairs(positions) do
        local d = descs[i]
        local dist = sqrt((d.x - hx) ^ 2 + (d.y - hy) ^ 2 + (d.z - hz) ^ 2)
        if nd == nil or dist < nd then nearest, nd = i, dist end
    end
    for _, i in ipairs(positions) do plan[i] = "target" end
    if nd <= (maxOrigin or 25) then plan[nearest] = "origin" end
    return plan
end

-- remote names worth recording when they are NOT inside the weapon tool
function Logic.looksLikeShotRemote(name)
    if type(name) ~= "string" then return false end
    local n = name:lower()
    for _, w in ipairs({"shoot", "fire", "throw", "knife", "gun", "stab", "slash", "hit", "bullet", "attack"}) do
        if n:find(w, 1, true) then return true end
    end
    return false
end

------------------------------------------------------------------------------------------------ config
-- copy only the keys the script knows, and only with the right type (a hand-edited or old file cannot break anything)
function Logic.mergeFlags(defaults, saved)
    local out = {}
    for k, v in pairs(defaults) do out[k] = v end
    if type(saved) ~= "table" then return out end
    for k, v in pairs(saved) do
        local d = defaults[k]
        if d ~= nil and type(v) == type(d) then out[k] = v end
    end
    return out
end

function Logic.clamp(v, lo, hi) return max(lo, min(hi, v)) end

return Logic
