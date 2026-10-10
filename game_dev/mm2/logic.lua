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
-- opts: mode ("Murderer" | "Sheriff" | "Closest to crosshair" | "Nearest" | "Anyone but me"), fov (pixels), maxDist, needVisible
function Logic.pickTarget(cands, opts)
    local best, bestScore
    local mode = opts.mode or "Nearest"
    for _, c in ipairs(cands) do
        local ok = c.alive ~= false and c.dist <= (opts.maxDist or math.huge)
        if ok and opts.needVisible and not c.visible then ok = false end
        if ok and mode == "Murderer" and c.role ~= "Murderer" and c.role ~= "Infected" then ok = false end
        if ok and mode == "Sheriff" and c.role ~= "Sheriff" and c.role ~= "Hero" then ok = false end
        local score = c.dist
        if ok and mode == "Closest to crosshair" then
            if c.screen == nil or c.screen > (opts.fov or math.huge) then ok = false else score = c.screen end
        end
        if ok and opts.fov and opts.fovAlways and (c.screen == nil or c.screen > opts.fov) then ok = false end
        if ok and (bestScore == nil or score < bestScore) then best, bestScore = c.id, score end
    end
    return best
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
