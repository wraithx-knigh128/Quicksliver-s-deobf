--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
if false then local _ = 99 end local function turxzz(xqmwdl) local _ = 31 end local dmrdxm = 66 local function eyuycb(hbrvas) local _ = 65 end while false do local _ = 75 break end if true then local _ = 99 end while false do local _ = 25 break end if false then local _ = 99 end local rpkeyw = 68 local function kweuql(juhfvx) local _ = 98 end local pgvxlu = 60 if false then local _ = 10 end if true then local _ = 19 end if true then local _ = 94 end local vydikd = 91 -- s04: branching and looping. Used to test control-flow recovery.
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
 local molrnc = 37 if true then local _ = 35 end local function gnbjsz(fqthyq) local _ = 21 end local function pqnzkr(xogbhx) local _ = 87 end if false then local _ = 77 end local mhoymi = 6 while false do local _ = 41 break end if false then local _ = 71 end local exscem = 24 local oaivgc = 13 while false do local _ = 18 break end local iwdihh = 99 if false then local _ = 20 end local function dsxsdu(vimccb) local _ = 88 end local kjdtkf = 58 if false then local _ = 6 end if true then local _ = 41 end