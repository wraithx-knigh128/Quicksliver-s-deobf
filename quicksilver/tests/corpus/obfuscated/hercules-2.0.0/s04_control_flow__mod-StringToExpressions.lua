--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local chars = {[62]=">",[32]=" ",[65]="A",[97]="a",[98]="b",[99]="c",[100]="d",[101]="e",[40]="(",[103]="g",[105]="i",[108]="l",[109]="m",[110]="n",[111]="o",[112]="p",[114]="r",[115]="s",[116]="t",[117]="u",[118]="v",[120]="x",[41]=")",[122]="z",[61]="=",[66]="B"}
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
    return (chars[-237 + 347]..chars[-417 + 518]..chars[-60 + 163]..chars[859 - (762)]..chars[714 - (598)]..chars[749 - (644)]..chars[376 - (258)]..chars[256 - (155)])
  elseif n == 0 then
    return (chars[573 - (451)]..chars[-726 + 827]..chars[-446 + 560]..chars[999 - (888)])
  elseif n < 10 then
    return (chars[130 - (15)]..chars[-715 + 824]..chars[940 - (843)]..chars[853 - (745)]..chars[451 - (343)])
  elseif n < 100 then
    return (chars[720 - (611)]..chars[482 - (381)]..chars[-411 + 511]..chars[917 - (812)]..chars[443 - (326)]..chars[-405 + 514])
  else
    return (chars[421 - (313)]..chars[-436 + 533]..chars[-138 + 252]..chars[-661 + 764]..chars[997 - (896)])
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
  local state = (chars[229 - (114)]..chars[-741 + 857]..chars[-385 + 482]..chars[-690 + 804]..chars[-479 + 595])
  local trace = {}
  for i = 1, #input do
    local ch = input:sub(i, i)
    if state == (chars[-347 + 462]..chars[-229 + 345]..chars[-811 + 908]..chars[-778 + 892]..chars[326 - (210)]) then
      if ch == (chars[245 - (148)]) then state = (chars[-859 + 974]..chars[-793 + 894]..chars[205 - (104)]..chars[-372 + 482]..chars[-363 + 428]) end
    elseif state == (chars[-631 + 746]..chars[896 - (795)]..chars[-782 + 883]..chars[378 - (268)]..chars[-860 + 925]) then
      if ch == (chars[-641 + 739]) then
        state = (chars[11 + 104]..chars[372 - (271)]..chars[-424 + 525]..chars[675 - (565)]..chars[489 - (424)]..chars[643 - (577)])
      elseif ch ~= (chars[251 - (154)]) then
        state = (chars[-646 + 761]..chars[962 - (846)]..chars[650 - (553)]..chars[411 - (297)]..chars[-11 + 127])
      end
    elseif state == (chars[-812 + 927]..chars[-101 + 202]..chars[472 - (371)]..chars[-508 + 618]..chars[-208 + 273]..chars[-652 + 718]) then
      state = (ch == (chars[246 - (147)])) and (chars[-734 + 831]..chars[809 - (710)]..chars[-617 + 716]..chars[693 - (592)]..chars[-819 + 931]..chars[397 - (281)]) or (chars[-804 + 919]..chars[353 - (237)]..chars[-109 + 206]..chars[-399 + 513]..chars[14 + 102])
    end
    trace[#trace + 1] = state
  end
  return state, table.concat(trace, (chars[-261 + 323]))
end

for _, n in ipairs({ 6, 7, 27 }) do
  print((chars[990 - (891)]..chars[536 - (425)]..chars[924 - (816)]..chars[-288 + 396]..chars[-198 + 295]..chars[12 + 104]..chars[-262 + 384]..chars[431 - (391)]) .. n .. (chars[-701 + 742]..chars[-872 + 904]..chars[-848 + 909]..chars[-412 + 444]) .. collatzSteps(n))
end
for _, n in ipairs({ -5, 0, 7, 42, 1000 }) do
  print(n .. (chars[-179 + 211]..chars[497 - (392)]..chars[-566 + 681]..chars[229 - (197)]) .. classify(n))
end
print(firstDivisor(91), firstDivisor(97), digitSum(98765))
print(stateMachine((chars[505 - (385)]..chars[764 - (644)]..chars[-3 + 100]..chars[-512 + 610]..chars[907 - (808)]..chars[650 - (553)]..chars[901 - (803)])))
print(stateMachine((chars[758 - (661)]..chars[-584 + 681]..chars[663 - (565)]..chars[-164 + 284])))
