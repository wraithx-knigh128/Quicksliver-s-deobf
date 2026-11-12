--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
while false do local _ = 99 break end
local turxzz = 88
local function mwdllu(yinrpm) local _ = 74 end
if true then local _ = 68 end
if false then local _ = 3 end
local hbrvas = 65
local function pkkgvc(iyyucr) local _ = 5 end
while false do local _ = 23 break end
local dtwigu = 29
local kweuql = 42
if true then local _ = 8 end
if false then local _ = 59 end
if true then local _ = 57 end
-- s04: branching and looping. Used to test control-flow recovery.
local function collatzSteps(n)
  local steps = 0
  while n ~= 1 do
    if n % 2 == 0 then
      n = n / 2
    else
      n = 3 * n + 1
    end
    steps = steps + 1
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
      found = d
      break
    end
  end
  return found
end

local function digitSum(n)
  local total = 0
  repeat
    total = total + n % 10
    n = math.floor(n / 10)
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
        state = "seenAB"
      elseif ch ~= "a" then
        state = "start"
      end
    elseif state == "seenAB" then
      state = (ch == "c") and "accept" or "start"
    end
    trace[#trace + 1] = state
  end
  return state, table.concat(trace, ">")
end

for _, n in ipairs({ 6, 7, 27 }) do
  print("collatz(" .. n .. ") = " .. collatzSteps(n))
end
for _, n in ipairs({ -5, 0, 7, 42, 1000 }) do
  print(n .. " is " .. classify(n))
end
print(firstDivisor(91), firstDivisor(97), digitSum(98765))
print(stateMachine("xxabcab"))
print(stateMachine("aabx"))

local function qpnfbt(vyramg) local _ = 40 end
local gnbjsz = 95
local function thyqru(jpqnzk) local _ = 27 end
local xogbhx = 87
while false do local _ = 77 break end
if true then local _ = 8 end
local function mifaci(pkvgue) local _ = 35 end
if true then local _ = 24 end
if true then local _ = 97 end
local function vgcrmi(xqrmiw) local _ = 31 end
local dsxsdu = 41
if false then local _ = 35 end
local xqnaek = 100
local function uzgzuj(xgpfbo) local _ = 1 end
local function guqtih(grqayk) local _ = 66 end