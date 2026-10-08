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
    Data lives in tsb_data.lua: Engine.loadData(require("tsb_data")).
]]

local Engine = {}

Engine.Combos = {}
Engine.Mechanics = {}
Engine.Techs = {}
Engine.Characters = {}

local function validSteps(steps)
    if type(steps) ~= "table" or #steps == 0 then return false end
    for i = 1, #steps do
        if type(steps[i]) ~= "string" or steps[i] == "" then return false end
    end
    return true
end

-- Load tsb_data.lua (or your own table with the same shape).
-- Malformed combos are skipped; the names of skipped ones are returned as a list.
function Engine.loadData(data, defaultGap)
    local skipped = {}
    for name, c in pairs(data.Combos or {}) do
        if type(name) == "string" and type(c) == "table" and validSteps(c.steps) then
            Engine.Combos[name] = {
                steps = c.steps, maxGap = c.maxGap or defaultGap or 1.2,
                character = c.character, confidence = c.confidence,
            }
        else
            skipped[#skipped + 1] = tostring(name)
        end
    end
    for k, v in pairs(data.Mechanics or {}) do Engine.Mechanics[k] = v end
    Engine.Techs, Engine.Characters = data.Techs or {}, data.Characters or {}
    table.sort(skipped)
    return Engine, skipped
end

-- Register / replace a combo (this is where "Oreo" and your own combos go).
function Engine.define(name, steps, maxGap)
    assert(type(name) == "string" and name ~= "", "define: name must be a non-empty string")
    assert(validSteps(steps), "define: steps must be a non-empty list of non-empty strings")
    assert(maxGap == nil or (type(maxGap) == "number" and maxGap > 0), "define: maxGap must be a positive number")
    Engine.Combos[name] = {steps = steps, maxGap = maxGap or 1.2}
end

----------------------------------------------------------------- predictor
-- For every combo we keep ALL alignments that are still alive (not just one counter), so a combo
-- is found even when it starts in the middle of a longer run of the same input
-- (e.g. M1 M1 M1 SIDEDASH still matches a combo that is "M1 M1 SIDEDASH").
local Predictor = {}
Predictor.__index = Predictor

function Engine.newPredictor(combos)
    return setmetatable({
        combos = combos or Engine.Combos,
        state = {},          -- name -> {t = time of last matched input, at = {[stepIndex] = true}}
        onComplete = nil,
    }, Predictor)
end

function Predictor:reset()
    self.state = {}
end

function Predictor:feed(token, now)
    if type(token) ~= "string" or type(now) ~= "number" then return end
    for name, combo in pairs(self.combos) do
        local steps = combo.steps
        local st = self.state[name]
        local live = (st and now - st.t <= combo.maxGap) and st.at or nil   -- window expired -> nothing alive

        local nextAt, any, completed = {}, false, false
        if live then
            for idx in pairs(live) do
                if steps[idx + 1] == token then
                    if idx + 1 == #steps then completed = true else nextAt[idx + 1] = true; any = true end
                end
            end
        end
        if steps[1] == token then                      -- a fresh start is always possible
            if #steps == 1 then completed = true else nextAt[1] = true; any = true end
        end

        self.state[name] = any and {t = now, at = nextAt} or nil
        if completed and self.onComplete then self.onComplete(name) end
    end
end

-- Likely combos right now, best first. One entry per combo (its furthest alignment).
function Predictor:predict(now)
    local out = {}
    for name, st in pairs(self.state) do
        local combo = self.combos[name]
        if combo and now - st.t <= combo.maxGap then
            local best = 0
            for idx in pairs(st.at) do if idx > best then best = idx end end
            if best > 0 then
                out[#out + 1] = {
                    name       = name,
                    progress   = best,
                    total      = #combo.steps,
                    confidence = best / #combo.steps,
                    next       = combo.steps[best + 1],
                    expiresIn  = combo.maxGap - (now - st.t),
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.confidence ~= b.confidence then return a.confidence > b.confidence end
        return a.name < b.name
    end)
    return out
end

-- Aggregate "what input comes next?" over every live candidate: {token -> weight}, plus best token.
function Predictor:nextInputs(now)
    local weights, best, bestW = {}, nil, 0
    for _, r in ipairs(self:predict(now)) do
        if r.next then
            local w = (weights[r.next] or 0) + r.confidence
            weights[r.next] = w
            if w > bestW or (w == bestW and best and r.next < best) then best, bestW = r.next, w end
        end
    end
    return weights, best
end

----------------------------------------------------------------- tech recovery
-- state = {knockback = {x, z}, facing = {x, z}, wallAhead = bool}
-- returns "Back" | "Forward" | "Left" | "Right"
function Engine.chooseTechDirection(state)
    local kb, f = state and state.knockback, state and state.facing
    if type(kb) ~= "table" or type(f) ~= "table" then return "Back" end
    local kx, kz, fx, fz = kb.x or 0, kb.z or 0, f.x or 0, f.z or 0
    local kmag = math.sqrt(kx * kx + kz * kz)
    local fmag = math.sqrt(fx * fx + fz * fz)
    if kmag < 1e-6 then return "Back" end
    if state.wallAhead then return "Left" end   -- slide off the wall instead of into it
    if fmag < 1e-6 then return "Back" end

    local dot   = (kx * fx + kz * fz) / (kmag * fmag)       -- both vectors normalised
    local cross = (fx * kz - fz * kx) / (kmag * fmag)
    if math.abs(dot) >= math.abs(cross) then
        -- thrown backwards relative to facing -> dash forward to close, else back away
        return dot < 0 and "Forward" or "Back"
    end
    return cross > 0 and "Left" or "Right"   -- dash against the knockback, like Forward/Back
end

return Engine
