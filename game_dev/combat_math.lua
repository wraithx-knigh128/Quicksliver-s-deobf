--[[
    combat_math.lua - pure geometry for "side dash toward the closest player" and "auto block".
    No Roblox APIs: positions / directions are plain {x=, y=, z=} tables, so it is unit-tested outside the engine.

      CombatMath.closest(myPos, list, maxDist)                 nearest entry of list (each has x,y,z), and its distance
      CombatMath.sideToward(myPos, rightVec, targetPos)        "Left" | "Right": the side a sideways dash must go to approach
      CombatMath.facing(fromPos, lookVec, toPos, halfAngleDeg) is `from` looking toward `to` (within +-halfAngle)?
      CombatMath.shouldBlock(...)                              attacker close enough, aimed at me, and in front of me
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

return M
