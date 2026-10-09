--[[
    block_predict.lua - learns WHEN each enemy attack animation actually hurts you, so Auto block can press F just
    before the hit instead of guessing. Pure logic (no Roblox APIs), unit-tested.

    What it learns, per animation id:
      * the hit offset  = seconds from the moment you SEE the animation start until you take damage
        (this already contains network delay, which is exactly what matters for pressing F in time)
    and per enemy:
      * the chain: which animation tends to follow which, and how long after (so the next punch can be predicted)

      local p = BlockPredict.new()
      p:swing(enemyKey, animId, now, length)   an enemy attack animation started (and lasts `length` s)
      p:damage(now) -> animId, offset | nil     you lost health: attribute it to the most plausible recent swing
      p:offset(animId) -> seconds | nil         learned hit offset (needs `minSamples` observations)
      p:next(animId) -> nextId, dt, n | nil     the animation that usually follows, and after how long
      p:pierced(animId) -> count                 a hit landed although F had been down long enough: it ignores block
      p:isPierce(animId) -> bool                 seen ignoring block `pierceNeeded` (2) times -> do not waste F on it
      p:export() / p:import(table)              save / restore (import sanitises everything)
]]

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
