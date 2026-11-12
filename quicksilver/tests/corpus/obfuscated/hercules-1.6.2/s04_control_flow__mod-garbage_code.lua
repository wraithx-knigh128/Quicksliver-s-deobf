--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
while false do local _ = 24 break end
while false do local _ = 63 break end
local lybtag = 65
if true then local _ = 34 end
local function vqhvdl(mzvhhy) local _ = 53 end
while false do local _ = 73 break end
while false do local _ = 85 break end
local function feiljw(reahvr) local _ = 100 end
local sspbqq = 11
local jeesfq = 48
if false then local _ = 3 end
local ihrrmm = 1
while false do local _ = 53 break end
if true then local _ = 41 end
local ccgxfg = 10
if false then local _ = 18 end
local function nrpmju(udmrdx) local _ = 31 end
local function yyucrp(keywjd) local _ = 23 end
local function guvpgw(xzkweu) local _ = 17 end
if true then local _ = 64 end
if false then local _ = 98 end
if false then local _ = 21 end
if true then local _ = 43 end
local function nekspf(virfoj) local _ = 48 end
if false then local _ = 24 end
local cacyku = 54
local function dikdem(olrncy) local _ = 37 end
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

local jcyqpn = 60
if false then local _ = 57 end
local function rujpqn(zkrxog) local _ = 2 end
local vmmmho = 25
local function cipkvg(uexsce) local _ = 45 end
local function vgcrmi(xqrmiw) local _ = 31 end
if false then local _ = 72 end
local nswtbd = 51
local xsduvi = 13
local cbxqna = 94
while false do local _ = 100 break end
if true then local _ = 43 end
local fzlkfr = 41
local function uzgzuj(xgpfbo) local _ = 1 end
local function guqtih(grqayk) local _ = 66 end
local icccgy = 18
local onjupy = 24
while false do local _ = 30 break end
if false then local _ = 48 end
local chzvef = 55
if false then local _ = 22 end
if false then local _ = 30 end
if false then local _ = 15 end
local jmhnhz = 30
if true then local _ = 93 end
if true then local _ = 45 end
local function huckpz(zwnxbb) local _ = 76 end
local function pgyyno(drjjpw) local _ = 95 end