--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
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

local function zxWmdlERE(gIOyIDrVQe)
    return (gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57) or (gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90) or (gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122)
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
    return IIMfMjZurC("kbdxqfsb", 23)
  elseif n == 0 then
    return IIMfMjZurC("kpcz", 11)
  elseif n < 10 then
    return IIMfMjZurC("xrfqq", 5)
  elseif n < 100 then
    return IIMfMjZurC("dvuzld", 17)
  else
    return IIMfMjZurC("tizom", 8)
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
  local state = IIMfMjZurC("opwnp", 22)
  local trace = {}
  for i = 1, #input do
    local ch = input:sub(i, i)
    if state == IIMfMjZurC("uvctv", 2) then
      if ch == IIMfMjZurC("f", 5) then state = IIMfMjZurC("oaajW", 22) end
    elseif state == IIMfMjZurC("eqqzM", 12) then
      if ch == IIMfMjZurC("i", 7) then
        state = IIMfMjZurC("cooxKL", 10)
      elseif ch ~= IIMfMjZurC("r", 17) then
        state = IIMfMjZurC("delce", 11)
      end
    elseif state == IIMfMjZurC("iuudQR", 16) then
      state = (ch == IIMfMjZurC("y", 22)) and IIMfMjZurC("suuwhl", 18) or IIMfMjZurC("hipgi", 15)
    end
    trace[#trace + 1] = state
  end
  return state, table.concat(trace, IIMfMjZurC(">", 4))
end

for _, n in ipairs({ 6, 7, 27 }) do
  print(IIMfMjZurC("amjjyrx(", 24) .. n .. IIMfMjZurC(") = ", 3) .. collatzSteps(n))
end
for _, n in ipairs({ -5, 0, 7, 42, 1000 }) do
  print(n .. IIMfMjZurC(" lv ", 3) .. classify(n))
end
print(firstDivisor(91), firstDivisor(97), digitSum(98765))
print(stateMachine(IIMfMjZurC("iilmnlm", 11)))
print(stateMachine(IIMfMjZurC("wwxt", 22)))
