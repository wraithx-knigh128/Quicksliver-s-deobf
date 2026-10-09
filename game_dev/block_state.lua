--[[
    block_state.lua - the "hold F" state machine behind Auto block. Pure logic (no Roblox APIs), unit-tested.

    Goal: block EVERY incoming hit, let go again as soon as their attack is over, never hold for long, and let go
    the instant YOU want to punch.

      local b = BlockState.new(cfg)       cfg (read live, so sliders can change it): {grace, maxHold, minHold, punchPause}
      b:threat(now, delay, duration)      an attack will land ~`delay` s from now and its animation lasts `duration` s
      b:punch(now)                        you want to attack: drop the block now, no new block for `punchPause` s
      b:tick(now)  -> "press" | "release" | nil     call every frame; the caller presses / releases F
      b:reset()    -> "release" | nil     turn everything off (e.g. Auto block switched off)

    Timeline for one hit: threat -> (delay) press F -> hold through the attack animation + `grace` -> release.
    A second attack while holding extends the hold (no gap between hits of a combo) but never past `maxHold`
    from when this block started.
]]

local M = {}

function M.new(cfg)
    cfg = cfg or {}
    local self = {holding = false, pressAt = nil, pendingRelease = nil, releaseAt = nil, holdStart = nil, pausedUntil = -math.huge}

    local function grace() return cfg.grace or 0.15 end
    local function maxHold() return math.max(cfg.maxHold or 1.0, cfg.minHold or 0.12) end
    local function minHold() return cfg.minHold or 0.12 end

    function self:threat(now, delay, duration)
        if type(now) ~= "number" or now < self.pausedUntil then return end          -- you just punched: let it through
        delay = math.max(tonumber(delay) or 0, 0)
        duration = math.max(tonumber(duration) or 0, 0)
        local hitEnd = now + delay + duration + grace()
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
