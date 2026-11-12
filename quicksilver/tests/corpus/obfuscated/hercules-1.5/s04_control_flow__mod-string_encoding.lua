--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local function zxWm3dlEREu(Qg2IO5y71ID9)
    return (Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57) or 
           (Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90) or 
           (Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122)
end

local function IIM4fM4j0urC(BmXJxEmbDXKy1, cbhbX2asaq)
    local inX8FpSju1 = {}
    for i = 1, #BmXJxEmbDXKy1 do
        local Qg2IO5y71ID9 = BmXJxEmbDXKy1:byte(i)
        if zxWm3dlEREu(Qg2IO5y71ID9) then
            local VQeA5wPd0wi            if Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 48 - cbhbX2asaq + 10) % 10) + 48
            elseif Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 65 - cbhbX2asaq + 26) % 26) + 65
            elseif Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 97 - cbhbX2asaq + 26) % 26) + 97
            end
            table.insert(inX8FpSju1, string.char(VQeA5wPd0wi))
        else
            table.insert(inX8FpSju1, string.char(Qg2IO5y71ID9))
        end
    end
    return table.concat(inX8FpSju1)
end

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
    return IIM4fM4j0urC("tkmgzobk", -319449722)
  elseif n == 0 then
    return IIM4fM4j0urC("puhe", -255556012)
  elseif n < 10 then
    return IIM4fM4j0urC("vpdoo", 541087797)
  elseif n < 100 then
    return IIM4fM4j0urC("fxwbnf", -40125937)
  else
    return IIM4fM4j0urC("fulay", -550623482)
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
  local state = IIM4fM4j0urC("yzgxz", -1157038058)
  local trace = {}
  for i = 1, #input do
    local ch = input:sub(i, i)
    if state == IIM4fM4j0urC("novmo", 1536593495) then
      if ch == IIM4fM4j0urC("f", 1457098297) then state = IIM4fM4j0urC("ammvI", -952757174) end
    elseif state == IIM4fM4j0urC("dppyL", -232073857) then
      if ch == IIM4fM4j0urC("d", -1590649578) then
        state = IIM4fM4j0urC("myyhUV", -36359420)
      elseif ch ~= IIM4fM4j0urC("s", 1353030996) then
        state = IIM4fM4j0urC("yzgxz", 1417633808)
      end
    elseif state == IIM4fM4j0urC("pbbkXY", 30393867) then
      state = (ch == IIM4fM4j0urC("p", -114656087)) and IIM4fM4j0urC("ikkmxb", -1116102668) or IIM4fM4j0urC("novmo", 1036303679)
    end
    trace[#trace + 1] = state
  end
  return state, table.concat(trace, IIM4fM4j0urC(">", -1146540025))
end

for _, n in ipairs({ 6, 7, 27 }) do
  print(IIM4fM4j0urC("rdaapio(", -540453483) .. n .. IIM4fM4j0urC(") = ", -976130785) .. collatzSteps(n))
end
for _, n in ipairs({ -5, 0, 7, 42, 1000 }) do
  print(n .. IIM4fM4j0urC(" fp ", -298124869) .. classify(n))
end
print(firstDivisor(91), firstDivisor(97), digitSum(98765))
print(stateMachine(IIM4fM4j0urC("ggjkljk", -1347759209)))
print(stateMachine(IIM4fM4j0urC("hhie", -1003211423)))
