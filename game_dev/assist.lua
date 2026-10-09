--[[
    assist.lua - pure logic for "Assist" mode: you perform the first move yourself and the script
    continues the rest of the combo. No Roblox APIs; unit-tested in tests/run_tests.lua.

      Assist.triggerIndex(steps, isMove, override)  which step is YOUR move (the trigger)
      Assist.remaining(steps, index)                the steps the script plays after it
      Assist.pick(armedOrder, matches)              several armed combos share a trigger: newest armed wins
      Assist.nextSide(direction, last)              "Left" | "Right" | "Alternate" -> the side to use now
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

return M
