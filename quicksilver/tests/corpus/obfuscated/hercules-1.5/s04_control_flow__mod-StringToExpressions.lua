--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
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
    return string.char(-237 + 347)..string.char(-417 + 518)..string.char(-60 + 163)..string.char(859 - 762)..string.char(714 - 598)..string.char(749 - 644)..string.char(376 - 258)..string.char(256 - 155)
  elseif n == 0 then
    return string.char(573 - 451)..string.char(-726 + 827)..string.char(-446 + 560)..string.char(999 - 888)
  elseif n < 10 then
    return string.char(130 - 15)..string.char(-715 + 824)..string.char(940 - 843)..string.char(853 - 745)..string.char(451 - 343)
  elseif n < 100 then
    return string.char(720 - 611)..string.char(482 - 381)..string.char(-411 + 511)..string.char(917 - 812)..string.char(443 - 326)..string.char(-405 + 514)
  else
    return string.char(421 - 313)..string.char(-436 + 533)..string.char(-138 + 252)..string.char(-661 + 764)..string.char(997 - 896)
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
  local state = string.char(229 - 114)..string.char(-741 + 857)..string.char(-385 + 482)..string.char(-690 + 804)..string.char(-479 + 595)
  local trace = {}
  for i = 1, #input do
    local ch = input:sub(i, i)
    if state == string.char(-347 + 462)..string.char(-229 + 345)..string.char(-811 + 908)..string.char(-778 + 892)..string.char(326 - 210) then
      if ch == string.char(245 - 148) then state = string.char(-859 + 974)..string.char(-793 + 894)..string.char(205 - 104)..string.char(-372 + 482)..string.char(-363 + 428) end
    elseif state == string.char(-631 + 746)..string.char(896 - 795)..string.char(-782 + 883)..string.char(378 - 268)..string.char(-860 + 925) then
      if ch == string.char(-641 + 739) then
        state = string.char(11 + 104)..string.char(372 - 271)..string.char(-424 + 525)..string.char(675 - 565)..string.char(489 - 424)..string.char(643 - 577)
      elseif ch ~= string.char(251 - 154) then
        state = string.char(-646 + 761)..string.char(962 - 846)..string.char(650 - 553)..string.char(411 - 297)..string.char(-11 + 127)
      end
    elseif state == string.char(-812 + 927)..string.char(-101 + 202)..string.char(472 - 371)..string.char(-508 + 618)..string.char(-208 + 273)..string.char(-652 + 718) then
      state = (ch == string.char(246 - 147)) and string.char(-734 + 831)..string.char(809 - 710)..string.char(-617 + 716)..string.char(693 - 592)..string.char(-819 + 931)..string.char(397 - 281) or string.char(-804 + 919)..string.char(353 - 237)..string.char(-109 + 206)..string.char(-399 + 513)..string.char(14 + 102)
    end
    trace[#trace + 1] = state
  end
  return state, table.concat(trace, string.char(-261 + 323))
end

for _, n in ipairs({ 6, 7, 27 }) do
  print(string.char(990 - 891)..string.char(536 - 425)..string.char(924 - 816)..string.char(-288 + 396)..string.char(-198 + 295)..string.char(12 + 104)..string.char(-262 + 384)..string.char(431 - 391) .. n .. string.char(-701 + 742)..string.char(-872 + 904)..string.char(-848 + 909)..string.char(-412 + 444) .. collatzSteps(n))
end
for _, n in ipairs({ -5, 0, 7, 42, 1000 }) do
  print(n .. string.char(-179 + 211)..string.char(497 - 392)..string.char(-566 + 681)..string.char(229 - 197) .. classify(n))
end
print(firstDivisor(91), firstDivisor(97), digitSum(98765))
print(stateMachine(string.char(505 - 385)..string.char(764 - 644)..string.char(-3 + 100)..string.char(-512 + 610)..string.char(907 - 808)..string.char(650 - 553)..string.char(901 - 803)))
print(stateMachine(string.char(758 - 661)..string.char(-584 + 681)..string.char(663 - 565)..string.char(-164 + 284)))
