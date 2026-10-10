--[[
    assist.lua - pure logic for "Assist" mode: you perform the first move yourself and the script
    continues the rest of the combo. No Roblox APIs; unit-tested in tests/run_tests.lua.

      Assist.triggerIndex(steps, isMove, override)  which step is YOUR move (the trigger)
      Assist.remaining(steps, index)                the steps the script plays after it
      Assist.pick(armedOrder, matches)              several armed combos share a trigger: newest armed wins
      Assist.nextSide(direction, last)              "Left" | "Right" | "Alternate" -> the side to use now

    "Start with M1" mode (every tech): YOU throw 1-3 M1s, then the script plays the rest of the tech.
      Assist.leadingM1(steps)                       how many of the tech's FIRST steps are plain M1s (the part you do yourself)
      Assist.afterM1(steps)                         the steps the script plays after your M1s (all steps when the tech does not start with M1)
      Assist.m1Cap(steps, most)                     how many of your M1s it waits for at most before taking over
      Assist.m1Count(count, last, now, window)      your M1 count, starting again after a pause longer than `window`
      Assist.m1Ready(count, last, now, cap, settle) take over now? (cap reached, or you stopped M1ing for `settle` seconds)
]]

local M = {}

-- override >= 1 wins (clamped to the combo length); otherwise the first step that is a character move
-- (that is the thing you do yourself); a combo without any move starts after step 1.
function M.triggerIndex(steps, isMove, override)
    if type(steps) ~= "table" or #steps == 0 then return nil end
    if type(override) == "number" and override >= 1 then return math.min(math.floor(override), #steps) end
    for i, tok in ipairs(steps) do
        if isMove and isMove(tok) then return i end
    end
    return 1
end

-- steps after the trigger, or nil when there is nothing left to play
function M.remaining(steps, index)
    if type(steps) ~= "table" or type(index) ~= "number" or index >= #steps then return nil end
    local out = {}
    for i = index + 1, #steps do out[#out + 1] = steps[i] end
    return out
end

-- armedOrder: names, oldest first. Returns the most recently armed name that matches.
function M.pick(armedOrder, matches)
    for i = #armedOrder, 1, -1 do
        if matches(armedOrder[i]) then return armedOrder[i] end
    end
    return nil
end

-- "Left"/"Right" are fixed; "Alternate" flips from the side used last time (starting with Left)
function M.nextSide(direction, last)
    if direction == "Right" then return "Right" end
    if direction == "Alternate" then return last == "Left" and "Right" or "Left" end
    return "Left"
end

-- ---- "Start with M1" ---------------------------------------------------------------------------------------------------------
function M.leadingM1(steps)
    if type(steps) ~= "table" then return 0 end
    local k = 0
    for _, tok in ipairs(steps) do
        if tok ~= "M1" then break end
        k = k + 1
    end
    return k
end

-- returns rest, k : rest = the steps after your k M1s (nil when nothing is left)
function M.afterM1(steps)
    if type(steps) ~= "table" or #steps == 0 then return nil, 0 end
    local k = M.leadingM1(steps)
    if k >= #steps then return nil, k end
    local rest = {}
    for i = k + 1, #steps do rest[#rest + 1] = steps[i] end
    return rest, k
end

function M.m1Cap(steps, most)
    local k = M.leadingM1(steps)
    if k > 0 then return k end
    local m = tonumber(most)
    return (m and m >= 1) and math.floor(m) or 3
end

function M.m1Count(count, last, now, window)
    if type(count) == "number" and count > 0 and type(last) == "number" and type(now) == "number" and now - last <= (window or 0.8) then
        return count + 1
    end
    return 1
end

function M.m1Ready(count, last, now, cap, settle)
    if type(count) ~= "number" or count < 1 or type(last) ~= "number" or type(now) ~= "number" then return false end
    if count >= cap then return true end
    return now - last >= settle - 1e-9                                  -- (floating point: 10.35 - 10 is a hair under 0.35)
end

return M
