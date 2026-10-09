--[[
    combat_math.lua - pure geometry for "side dash toward the closest player" and "auto block".
    No Roblox APIs: positions / directions are plain {x=, y=, z=} tables, so it is unit-tested outside the engine.

      CombatMath.closest(myPos, list, maxDist)                 nearest entry of list (each has x,y,z), and its distance
      CombatMath.sideToward(myPos, rightVec, targetPos)        "Left" | "Right": the side a sideways dash must go to approach
      CombatMath.facing(fromPos, lookVec, toPos, halfAngleDeg) is `from` looking toward `to` (within +-halfAngle)?
      CombatMath.shouldBlock(...)                              attacker close enough, aimed at me, and in front of me
      CombatMath.assess(o)                                     the same, but looks ahead: "block" or "far" | "unaimed" | "behind"
      CombatMath.orbitStep(myPos, theirPos, theirLook, prefer) how far round the player I already am, and which way to dash next
      CombatMath.dominantKey(dx, dz, camLook, camRight)        "W" | "A" | "S" | "D": the key that moves me closest to that direction
]]

local M = {}

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
    if not M.facing(o.mp, o.ml, o.tp, 90) and not M.facing(o.mp, o.ml, predTheirs, 90) then return "behind" end
    return "block"
end

-- Going round a player to reach his back. How far round am I already, and which way along the circle is next?
--   returns {angle = 0..180 (0 = right in front of him, 180 = exactly behind), behind = angle >= 120, dx, dz = unit direction of the
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
    return {angle = angle, behind = angle >= 120, dx = px / pl, dz = pz / pl, radius = r}
end

-- The key that moves me closest to the world direction (dx, dz), given the camera (movement keys are camera relative).
-- Returns the key and the two components (forward, right). A dash goes the way of ONE key, so the strongest axis wins.
function M.dominantKey(dx, dz, camLook, camRight)
    if not (num(dx) and num(dz) and valid(camLook) and valid(camRight)) then return nil end
    local rl = math.sqrt(camRight.x * camRight.x + camRight.z * camRight.z)
    if rl < 1e-6 then return nil end
    local rx, rz = camRight.x / rl, camRight.z / rl
    local fx, fz = camLook.x, camLook.z
    local fl = math.sqrt(fx * fx + fz * fz)
    if fl < 1e-6 then fx, fz = rz, -rx else fx, fz = fx / fl, fz / fl end   -- looking straight up / down: forward from the right vector
    local f, r = dx * fx + dz * fz, dx * rx + dz * rz
    if math.abs(r) >= math.abs(f) then return r >= 0 and "D" or "A", f, r end
    return f >= 0 and "W" or "S", f, r
end

return M
