--[[
    block_state.lua - the "hold F" state machine behind Auto block. Pure logic (no Roblox APIs), unit-tested.

    Goal: block EVERY incoming hit, let go again as soon as their attack is over, never hold for long, and let go
    the instant YOU want to punch.

      local b = BlockState.new(cfg)       cfg (read live, so sliders can change it): {grace, maxHold, minHold, punchPause}
      b:threat(now, delay, duration, g)   an attack will land ~`delay` s from now and its animation lasts `duration` s; g (optional) = how long to
                                          stay blocked after it instead of cfg.grace (a combo's next hit is coming: stay up)
      b:punch(now)                        you want to attack: drop the block now; no block can come up for `punchPause` s (the game's
                                          lockout after your own M1), but an attack that lands after that is still blocked
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

    function self:threat(now, delay, duration, graceOverride)
        if type(now) ~= "number" then return end
        delay = math.max(tonumber(delay) or 0, 0)
        duration = math.max(tonumber(duration) or 0, 0)
        if now < self.pausedUntil then
            -- you just punched, so the game will not let you block before the lockout ends. A hit that is over by then is
            -- lost anyway; one that lands after it is still blocked - the press just waits for the lockout.
            local attackEnds = now + delay + duration
            if attackEnds <= self.pausedUntil then return end
            delay = math.max(delay, self.pausedUntil - now)
            duration = math.max(attackEnds - (now + delay), 0.1)           -- the attack still ends when it ends
        end
        local hitEnd = now + delay + duration + (type(graceOverride) == "number" and math.max(graceOverride, 0) or grace())
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
