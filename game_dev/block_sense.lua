--[[
    block_sense.lua - "did my block really come up?". Pure logic (no Roblox APIs), unit-tested.

    The hub presses F, but a press can be swallowed (your own M1 lockout, a stun, a dropped input) and then the hit goes through.
    Nobody published what the game changes while you block, so this LEARNS it: it compares a snapshot of your character just before
    the press with one a moment after, keeps what is new while blocking (a new animation track, a changed attribute, a different
    WalkSpeed) and trusts only what shows up in every sample. Once it knows, `isUp(snapshot)` says whether the block is up.

      snapshot = {ws = number|nil, attrs = {name = value}, tracks = {animationId = true}}

      local s = BlockSense.new()
      s:observe(restSnapshot, blockingSnapshot)   one sample; true when the signature is ready
      s:ready() -> bool                            2+ consistent samples and something that distinguishes blocking
      s:isUp(snapshot) -> bool | nil               nil while it does not know yet
      s:describe() -> text, s:forget(), s:export() / s:import(list)
]]

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
