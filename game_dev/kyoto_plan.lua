--[[
    kyoto_plan.lua - the step list (and exact waits) for the Garou "Flowing Water -> Kyoto" assist. Pure Lua, unit-tested.

    What the guides / wiki say (fan sources, unverified):
      * Kyoto            = side dash right after Flowing Water, so Lethal Whirlwind Stream catches them.
      * Whirlwind Dash   = forward dash in a circle right after Lethal Whirlwind Stream, as EARLY as possible: they take less
                           knockback and stay within side dash reach, so the combo can go on.
      * Twisted (dash)   = the M1 string's last hit launches them; a small step back, then a dash at them ("Instant Twisted"
                           is the faster camera-flick version, which a script cannot do - the macro does back dash + front dash).

    You cast Flowing Water yourself (the trigger); everything after it is played:

      FLOWING_WATER (you) -> SIDEDASH -> LETHAL_WHIRLWIND_STREAM -> [FRONTDASH = whirlwind dash] -> M1 x m1 -> [BACKDASH -> FRONTDASH = twisted]

      local o = KyotoPlan.clean(savedTable)      options, always valid
      local steps, gaps = KyotoPlan.build(o)     steps = tokens incl. the trigger; gaps[i] = seconds to wait AFTER step i (nil = engine default)
]]

local M = {}

M.DEFAULTS = {m1 = 3, wait = 0.30, whirl = true, twisted = true, side = "Toward"}
local SIDES = {Behind = true, Toward = true, Left = true, Right = true}

-- timings of the fixed parts (seconds)
M.CATCH = 0.12       -- after the side dash: Lethal Whirlwind Stream right away (it is what catches them)
M.WHIRL = 0.12       -- after the Stream: the whirlwind dash "as early as possible"
M.LAND = 0.30        -- after the whirlwind dash: let it land before the first M1
M.STEP_BACK = 0.14   -- the small step back before the twisted dash

function M.clean(src)
    src = type(src) == "table" and src or {}
    local o = {}
    local m1 = tonumber(src.m1)
    o.m1 = (m1 and m1 == m1) and math.min(math.max(math.floor(m1), 1), 3) or M.DEFAULTS.m1
    local wait = tonumber(src.wait)
    o.wait = (wait and wait == wait) and math.min(math.max(wait, 0.05), 1.0) or M.DEFAULTS.wait
    o.whirl = src.whirl == nil and M.DEFAULTS.whirl or src.whirl == true
    o.twisted = src.twisted == nil and M.DEFAULTS.twisted or src.twisted == true
    o.side = SIDES[src.side] and src.side or (src.side == "Closest" and "Toward" or M.DEFAULTS.side)
    return o
end

function M.build(opts)
    local o = M.clean(opts)
    local steps, gaps = {"FLOWING_WATER", "SIDEDASH", "LETHAL_WHIRLWIND_STREAM"}, {}
    gaps[1] = o.wait
    gaps[2] = M.CATCH
    if o.whirl then
        gaps[3] = M.WHIRL
        steps[#steps + 1] = "FRONTDASH"
        gaps[#steps] = M.LAND
    end
    for _ = 1, o.m1 do steps[#steps + 1] = "M1" end                  -- gaps after M1: the normal M1 gap of the Timing tab
    if o.twisted then
        steps[#steps + 1] = "BACKDASH"
        gaps[#steps] = M.STEP_BACK
        steps[#steps + 1] = "FRONTDASH"
    end
    return steps, gaps, o
end

return M
