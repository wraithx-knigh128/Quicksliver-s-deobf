--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local function zxWmdlERE(gIOyIDrVQe)
    return (gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57) or (gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90) or (gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122)
end

local function IIMfMjZurC(JxEmbDXKy, ycbhbXasaqVk)
    local yinXFpSjudBm = {}
    for i = 1, #JxEmbDXKy do
        local gIOyIDrVQe = JxEmbDXKy:byte(i)
        if zxWmdlERE(gIOyIDrVQe) then
            local wPdZwiguCp            if gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57 then
                wPdZwiguCp = ((gIOyIDrVQe - 48 - ycbhbXasaqVk + 10) % 10) + 48
            elseif gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90 then
                wPdZwiguCp = ((gIOyIDrVQe - 65 - ycbhbXasaqVk + 26) % 26) + 65
            elseif gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122 then
                wPdZwiguCp = ((gIOyIDrVQe - 97 - ycbhbXasaqVk + 26) % 26) + 97
            end
            table.insert(yinXFpSjudBm, string.char(wPdZwiguCp))
        else
            table.insert(yinXFpSjudBm, string.char(gIOyIDrVQe))
        end
    end
    return table.concat(yinXFpSjudBm)
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
    return IIMfMjZurC("lceyrgtc", 24)
  elseif n == 0 then
    return IIMfMjZurC("uzmj", 21)
  elseif n < 10 then
    return IIMfMjZurC("qkyjj", 24)
  elseif n < 100 then
    return IIMfMjZurC("kcbgsk", 24)
  else
    return IIMfMjZurC("gvmbz", 21)
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
  local state = IIMfMjZurC("jkrik", 17)
  local trace = {}
  for i = 1, #input do
    local ch = input:sub(i, i)
    if state == IIMfMjZurC("opwnp", 22) then
      if ch == IIMfMjZurC("s", 18) then state = IIMfMjZurC("myyhU", 20) end
    elseif state == IIMfMjZurC("qcclY", 24) then
      if ch == IIMfMjZurC("e", 3) then
        state = IIMfMjZurC("rddmZA", 25)
      elseif ch ~= IIMfMjZurC("j", 9) then
        state = IIMfMjZurC("hipgi", 15)
      end
    elseif state == IIMfMjZurC("rddmZA", 25) then
      state = (ch == IIMfMjZurC("n", 11)) and IIMfMjZurC("zbbdos", 25) or IIMfMjZurC("rszqs", 25)
    end
    trace[#trace + 1] = state
  end
  return state, table.concat(trace, IIMfMjZurC(">", 1))
end

for _, n in ipairs({ 6, 7, 27 }) do
  print(IIMfMjZurC("ugddslr(", 18) .. n .. IIMfMjZurC(") = ", 1) .. collatzSteps(n))
end
for _, n in ipairs({ -5, 0, 7, 42, 1000 }) do
  print(n .. IIMfMjZurC(" wg ", 14) .. classify(n))
end
print(firstDivisor(91), firstDivisor(97), digitSum(98765))
print(stateMachine(IIMfMjZurC("wwzabza", 25)))
print(stateMachine(IIMfMjZurC("vvws", 21)))
