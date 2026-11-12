--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s04: branching and looping. Used to test control-flow recovery.
local function collatzSteps(n)
  local steps = 0
  while n ~= 1 do
    if n % 2 == 0 then
      ;(function() n = n / 2 end)()
    else
      ;(function() n = 3 * n + 1 end)()
    end
    ;(function() steps = steps + 1 end)()
  end
  return steps
end

local function classify(n)
  if n < 0 then
    return "negative"
  elseif n == 0 then
    return "zero"
  elseif n < 10 then
    return "small"
  elseif n < 100 then
    return "medium"
  else
    return "large"
  end
end

local function firstDivisor(n)
  local found
  for d = 2, n do
    if n % d == 0 then
      ;(function() found = d end)()
      ;(function() break end)()
    end
  end
  return found
end

local function digitSum(n)
  local total = 0
  repeat
    ;(function() total = total + n % 10 end)()
    ;(function() n = math.floor(n / 10) end)()
  until n == 0
  return total
end

local function stateMachine(input)
  local state = "start"
  local trace = {}
  for i = 1, #input do
    local ch = input:sub(i, i)
    if state == "start" then
      if ch == "a" then state = "seenA" end
    elseif state == "seenA" then
      if ch == "b" then
        ;(function() state = "seenAB" end)()
      elseif ch ~= "a" then
        ;(function() state = "start" end)()
      end
    elseif state == "seenAB" then
      ;(function() state = (ch == "c") and "accept" or "start" end)()
    end
    ;(function() trace[#trace + 1] = state end)()
  end
  return state, table.concat(trace, ">")
end

for _, n in ipairs({ 6, 7, 27 }) do
  ;(function() print("collatz(" .. n .. ") = " .. collatzSteps(n)) end)()
end
for _, n in ipairs({ -5, 0, 7, 42, 1000 }) do
  ;(function() print(n .. " is " .. classify(n)) end)()
end
;(function() print(firstDivisor(91), firstDivisor(97), digitSum(98765)) end)()
;(function() print(stateMachine("xxabcab")) end)()
;(function() print(stateMachine("aabx")) end)()
