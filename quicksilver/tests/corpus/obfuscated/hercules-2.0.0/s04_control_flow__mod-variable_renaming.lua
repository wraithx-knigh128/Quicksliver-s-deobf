--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local cDGcFkDJOk,AemCUlrTcKk,IyWVnEfbt,ramgNjMn,PszEfWZNq
cDGcFkDJOk=ipairs;AemCUlrTcKk=pairs;IyWVnEfbt=print;ramgNjMn=math.floor;PszEfWZNq=table.concat;
-- s04: branching and looping. Used to test control-flow recovery.
local function jgqTeQsBpB(n)
  local zxWmdlERE = 0
  while n ~= 1 do
    if n % 2 == 0 then
      n = n / 2
    else
      n = 3 * n + 1
    end
    zxWmdlERE = zxWmdlERE + 1
  end
  return zxWmdlERE
end

local function wPdZwiguCp(n)
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

local function JxEmbDXKy(n)
  local ycbhbXasaqVk
  for d = 2, n do
    if n % d == 0 then
      ycbhbXasaqVk = d
      break
    end
  end
  return ycbhbXasaqVk
end

local function yinXFpSjudBm(n)
  local IIMfMjZurC = 0
  repeat
    IIMfMjZurC = IIMfMjZurC + n % 10
    n = math.floor(n / 10)
  until n == 0
  return IIMfMjZurC
end

local function ArfoPVZM(input)
  local xHvKEpMRBuM = "start"
  local kweuqlPhf = {}
  for i = 1, #input do
    local gIOyIDrVQe = input:sub(i, i)
    if xHvKEpMRBuM == "start" then
      if gIOyIDrVQe == "a" then xHvKEpMRBuM = "seenA" end
    elseif xHvKEpMRBuM == "seenA" then
      if gIOyIDrVQe == "b" then
        xHvKEpMRBuM = "seenAB"
      elseif gIOyIDrVQe ~= "a" then
        xHvKEpMRBuM = "start"
      end
    elseif xHvKEpMRBuM == "seenAB" then
      xHvKEpMRBuM = (gIOyIDrVQe == "c") and "accept" or "start"
    end
    kweuqlPhf[#kweuqlPhf + 1] = xHvKEpMRBuM
  end
  return xHvKEpMRBuM, table.concat(kweuqlPhf, ">")
end

for _, n in cDGcFkDJOk({ 6, 7, 27 }) do
  IyWVnEfbt("collatz(" .. n .. ") = " .. jgqTeQsBpB(n))
end
for _, n in cDGcFkDJOk({ -5, 0, 7, 42, 1000 }) do
  IyWVnEfbt(n .. " is " .. wPdZwiguCp(n))
end
IyWVnEfbt(JxEmbDXKy(91), JxEmbDXKy(97), yinXFpSjudBm(98765))
IyWVnEfbt(ArfoPVZM("xxabcab"))
IyWVnEfbt(ArfoPVZM("aabx"))
