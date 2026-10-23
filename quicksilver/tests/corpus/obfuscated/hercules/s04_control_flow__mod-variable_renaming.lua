--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local cDGcFkDJOk,AemCUlrTcKk,IyWVnEfbt,ramgNjMn,PszEfWZNq
cDGcFkDJOk=ipairs;AemCUlrTcKk=pairs;IyWVnEfbt=print;ramgNjMn=math.floor;PszEfWZNq=table.concat;
-- s04: branching and looping. Used to test control-flow recovery.
local function ArfoPVZM(n)
  local yinXFpSjudBm = 0
  while n ~= 1 do
    if n % 2 == 0 then
      n = n / 2
    else
      n = 3 * n + 1
    end
    yinXFpSjudBm = yinXFpSjudBm + 1
  end
  return yinXFpSjudBm
end

local function zxWmdlERE(n)
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

local function kweuqlPhf(n)
  local wPdZwiguCp
  for d = 2, n do
    if n % d == 0 then
      wPdZwiguCp = d
      break
    end
  end
  return wPdZwiguCp
end

local function JxEmbDXKy(n)
  local gIOyIDrVQe = 0
  repeat
    gIOyIDrVQe = gIOyIDrVQe + n % 10
    n = math.floor(n / 10)
  until n == 0
  return gIOyIDrVQe
end

local function IIMfMjZurC(input)
  local xHvKEpMRBuM = "start"
  local jgqTeQsBpB = {}
  for i = 1, #input do
    local ycbhbXasaqVk = input:sub(i, i)
    if xHvKEpMRBuM == "start" then
      if ycbhbXasaqVk == "a" then xHvKEpMRBuM = "seenA" end
    elseif xHvKEpMRBuM == "seenA" then
      if ycbhbXasaqVk == "b" then
        xHvKEpMRBuM = "seenAB"
      elseif ycbhbXasaqVk ~= "a" then
        xHvKEpMRBuM = "start"
      end
    elseif xHvKEpMRBuM == "seenAB" then
      xHvKEpMRBuM = (ycbhbXasaqVk == "c") and "accept" or "start"
    end
    jgqTeQsBpB[#jgqTeQsBpB + 1] = xHvKEpMRBuM
  end
  return xHvKEpMRBuM, table.concat(jgqTeQsBpB, ">")
end

for _, n in cDGcFkDJOk({ 6, 7, 27 }) do
  IyWVnEfbt("collatz(" .. n .. ") = " .. ArfoPVZM(n))
end
for _, n in cDGcFkDJOk({ -5, 0, 7, 42, 1000 }) do
  IyWVnEfbt(n .. " is " .. zxWmdlERE(n))
end
IyWVnEfbt(kweuqlPhf(91), kweuqlPhf(97), JxEmbDXKy(98765))
IyWVnEfbt(IIMfMjZurC("xxabcab"))
IyWVnEfbt(IIMfMjZurC("aabx"))
