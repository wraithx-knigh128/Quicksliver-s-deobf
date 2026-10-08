--[[
    combo_engine.lua  -  pure Lua (no Roblox APIs), usable in your own game.

    * Combos are plain data: an ordered list of input tokens + a max gap between inputs.
    * Predictor:feed(token, time) tracks every combo in parallel and Predictor:predict()
      returns the likely combos with progress, confidence and the next expected input.
    * chooseTechDirection() picks a recovery dash direction from simple state.

    NOTE on the data below: the Kyoto sequence comes from a public combo guide
    (itemlevel.net) found by search; I could not open the page to double-check it and
    TSB gets patched often, so treat it as a starting point. No reliable source for an
    "Oreo" combo was found, so none is invented - add it with Engine.define(...).
]]

local Engine = {}

Engine.Combos = {
    Kyoto = {
        maxGap = 1.2,
        steps = {
            "M1", "M1", "M1",
            "SIDEDASH", "FLOWING_WATER",
            "LETHAL_WHIRLWIND",
            "HOLD_SPACE+HUNTERS_GRASP",
            "M1", "SIDEDASH", "UPPERCUT", "Q",
        },
    },
    -- Garou variant listed by Gamezebo (unverified):
    KyotoGarou = {
        maxGap = 1.2,
        steps = {
            "Q", "M1", "M1", "M1", "FLOWING_WATER", "SIDEDASH", "HUNTERS_GRASP",
            "Q", "M1", "M1", "M1", "LETHAL_WHIRLWIND",
        },
    },
}

-- Game numbers gathered from fan wikis/guides (see RESEARCH.md). Several sources disagree,
-- so these are tunable defaults for YOUR game, not verified TSB data.
Engine.Mechanics = {
    m1Chain          = {3, 3, 4, 5},   -- % damage per hit, 4th launches
    wallComboDamage  = 12,             -- % (4th M1 near wall + forward dash)
    sideDashCooldown = 2,              -- s (one wiki; another says ~1)
    frontDashCooldown = 5,             -- s, shared with back dash
    ragdollCancelCooldown = 30,        -- s (sources say 20-30)
}

-- Register / replace a combo (this is where "Oreo" and your own combos go).
function Engine.define(name, steps, maxGap)
    assert(type(name) == "string" and #steps > 0, "define(name, steps, maxGap)")
    Engine.Combos[name] = {steps = steps, maxGap = maxGap or 1.2}
end

----------------------------------------------------------------- predictor
local Predictor = {}
Predictor.__index = Predictor

function Engine.newPredictor(combos)
    local self = setmetatable({
        combos = combos or Engine.Combos,
        progress = {},   -- name -> {index, lastTime}
        onComplete = nil,
    }, Predictor)
    return self
end

function Predictor:reset()
    self.progress = {}
end

function Predictor:feed(token, now)
    for name, combo in pairs(self.combos) do
        local p = self.progress[name]
        if p and now - p.t > combo.maxGap then p = nil end   -- window expired

        local nextIndex = p and p.i + 1 or 1
        if combo.steps[nextIndex] == token then
            p = {i = nextIndex, t = now}
        elseif combo.steps[1] == token then
            p = {i = 1, t = now}                               -- restart on a fresh opener
        else
            p = nil
        end
        self.progress[name] = p

        if p and p.i == #combo.steps then
            self.progress[name] = nil
            if self.onComplete then self.onComplete(name) end
        end
    end
end

-- Likely combos right now, best first.
function Predictor:predict(now)
    local out = {}
    for name, p in pairs(self.progress) do
        local combo = self.combos[name]
        if now - p.t <= combo.maxGap then
            out[#out + 1] = {
                name       = name,
                progress   = p.i,
                total      = #combo.steps,
                confidence = p.i / #combo.steps,
                next       = combo.steps[p.i + 1],
                expiresIn  = combo.maxGap - (now - p.t),
            }
        end
    end
    table.sort(out, function(a, b)
        if a.confidence ~= b.confidence then return a.confidence > b.confidence end
        return a.name < b.name
    end)
    return out
end

----------------------------------------------------------------- tech recovery
-- state = {knockback = {x, z}, facing = {x, z}, wallAhead = bool}
-- returns "Back" | "Forward" | "Left" | "Right"
function Engine.chooseTechDirection(state)
    local kb, f = state.knockback, state.facing
    local mag = math.sqrt(kb.x * kb.x + kb.z * kb.z)
    if mag < 1e-6 then return "Back" end
    if state.wallAhead then return "Left" end   -- slide off the wall instead of into it

    local dot   = (kb.x * f.x + kb.z * f.z) / mag
    local cross = (f.x * kb.z - f.z * kb.x) / mag
    if math.abs(dot) >= math.abs(cross) then
        -- thrown backwards relative to facing -> dash forward to close, else back away
        return dot < 0 and "Forward" or "Back"
    end
    return cross > 0 and "Left" or "Right"   -- dash against the knockback, like Forward/Back
end

return Engine
