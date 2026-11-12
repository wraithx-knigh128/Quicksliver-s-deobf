--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s04: branching and looping. Used to test control-flow recovery.
local function collatzSteps(n)
  local steps = 0
  while n ~= 1 do
    if n % 2 == 0 then
      if 35 + 35 == 70 then
          n = n / 2
      end
    else
      if 39 + 6 == 45 then
          n = 3 * n + 1
      end
    end
    if not (10 ~= 10) then
        steps = steps + 1
    elseif (not (21 < 39)) == (21 >= 39) then
        -- dead
    end
  end
  if true then
      return steps
  end
end

local function classify(n)
  if n < 0 then
    if 26 + 26 == 52 then
        return "negative"
    end
  elseif n == 0 then
    if 49 + 13 == 62 then
        return "zero"
    elseif 4 + 12 ~= 16 then
        -- dead
    end
  elseif n < 10 then
    if not (31 ~= 31) then
        return "small"
    end
  elseif n < 100 then
    if true then
        return "medium"
    end
  else
    if 82 % 82 == 0 then
        return "large"
    elseif not (60 == 60) then
        -- dead
    end
  end
end

local function firstDivisor(n)
  local found
  for d = 2, n do
    if n % d == 0 then
      if 16 + 45 == 61 then
          found = d
      end
      if 21 - 21 == 0 then
          break
      end
    end
  end
  if true then
      return found
  elseif 4 + 28 ~= 32 then
      -- dead
  end
end

local function digitSum(n)
  local total = 0
  repeat
    if true then
        total = total + n % 10
    end
    if 100 - 100 == 0 then
        n = math.floor(n / 10)
    end
  until n == 0
  if 31 + 13 == 44 then
      return total
  elseif 30 ~= 30 then
      -- dead
  end
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
        if 25 - 25 == 0 then
            state = "seenAB"
        end
      elseif ch ~= "a" then
        if true then
            state = "start"
        end
      end
    elseif state == "seenAB" then
      if 12 % 12 == 0 then
          state = (ch == "c") and "accept" or "start"
      elseif 8 ~= 8 then
          -- dead
      end
    end
    if 65 - 65 == 0 then
        trace[#trace + 1] = state
    end
  end
  if not (19 ~= 19) then
      return state, table.concat(trace, ">")
  end
end

for _, n in ipairs({ 6, 7, 27 }) do
  if 90 % 90 == 0 then
      print("collatz(" .. n .. ") = " .. collatzSteps(n))
  elseif 71 > 71 then
      -- dead
  end
end
for _, n in ipairs({ -5, 0, 7, 42, 1000 }) do
  if 99 >= 99 then
      print(n .. " is " .. classify(n))
  end
end
if 34 % 34 == 0 then
    print(firstDivisor(91), firstDivisor(97), digitSum(98765))
end
if 99 * 0 + 99 == 99 then
    print(stateMachine("xxabcab"))
elseif not (61 == 61) then
    -- dead
end
if 5 - 5 == 0 then
    print(stateMachine("aabx"))
end
