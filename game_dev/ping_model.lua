--[[
    ping_model.lua - pure logic for smoothing your own ping and shifting combo timing by it.

    * PingModel.new(alpha)      :sample(ms) :value() :jitter() :stable()
    * PingModel.adjustDelay(base, pingMs, strength, opts)

    Why timing moves at all: what you SEE (a move ending, an opponent landing) reaches you roughly one
    ping late. A step that waits for such a visible cue should therefore go out earlier by about that
    amount; steps with a fixed internal cooldown (M1 spacing) should not move.  This is a tunable
    heuristic (strength 0 = off), not a guarantee that every hit lands - hit registration is decided by
    the server, and Roblox gives a client no way to read another player's ping.
]]

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

-- Seconds. Only "dependent" gaps (>= minDependent, i.e. after a move or dash) are shortened, and never by
-- more than maxFraction of the planned gap, so a bad ping reading can't collapse the timing.
function M.adjustDelay(base, pingMs, strength, opts)
    opts = opts or {}
    if type(base) ~= "number" or base < (opts.minDependent or 0.3) then return base end
    if type(pingMs) ~= "number" or pingMs <= 0 or type(strength) ~= "number" or strength <= 0 then return base end
    local lead = math.min((pingMs / 1000) * strength, base * (opts.maxFraction or 0.4))
    return base - lead
end

return M
