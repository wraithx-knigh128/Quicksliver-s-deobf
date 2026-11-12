--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local IyWVnEfbt,ramgNjMn,PszEfWZNq,ujEVWTkAX,NwgoUcmSm
IyWVnEfbt=ipairs;ramgNjMn=pairs;PszEfWZNq=print;ujEVWTkAX=math.floor;NwgoUcmSm=table.concat
-- s04: branching and looping. Used to test control-flow recovery.
local function gIOyIDrVQe(wPdZwiguCp)
  local AemCUlrTcKk = 0
  while wPdZwiguCp ~= 1 do
    if wPdZwiguCp % 2 == 0 then
      wPdZwiguCp = wPdZwiguCp / 2
    else
      wPdZwiguCp = 3 * wPdZwiguCp + 1
    end
    AemCUlrTcKk = AemCUlrTcKk + 1
  end
  return AemCUlrTcKk
end

local function zxWmdlERE(wPdZwiguCp)
  if wPdZwiguCp < 0 then
    return "negative"
  elseif wPdZwiguCp == 0 then
    return "zero"
  elseif wPdZwiguCp < 10 then
    return "small"
  elseif wPdZwiguCp < 100 then
    return "medium"
  else
    return "large"
  end
end

local function xHvKEpMRBuM(wPdZwiguCp)
  local yinXFpSjudBm
  for d = 2, wPdZwiguCp do
    if wPdZwiguCp % d == 0 then
      yinXFpSjudBm = d
      break
    end
  end
  return yinXFpSjudBm
end

local function jgqTeQsBpB(wPdZwiguCp)
  local ycbhbXasaqVk = 0
  repeat
    ycbhbXasaqVk = ycbhbXasaqVk + wPdZwiguCp % 10
    wPdZwiguCp = ujEVWTkAX(wPdZwiguCp / 10)
  until wPdZwiguCp == 0
  return ycbhbXasaqVk
end

local function JxEmbDXKy(cDGcFkDJOk)
  local IIMfMjZurC = "start"
  local kweuqlPhf = {}
  for i = 1, #cDGcFkDJOk do
    local ArfoPVZM = cDGcFkDJOk:sub(i, i)
    if IIMfMjZurC == "start" then
      if ArfoPVZM == "a" then IIMfMjZurC = "seenA" end
    elseif IIMfMjZurC == "seenA" then
      if ArfoPVZM == "b" then
        IIMfMjZurC = "seenAB"
      elseif ArfoPVZM ~= "a" then
        IIMfMjZurC = "start"
      end
    elseif IIMfMjZurC == "seenAB" then
      IIMfMjZurC = (ArfoPVZM == "c") and "accept" or "start"
    end
    kweuqlPhf[#kweuqlPhf + 1] = IIMfMjZurC
  end
  return IIMfMjZurC, NwgoUcmSm(kweuqlPhf, ">")
end

for _, wPdZwiguCp in IyWVnEfbt({ 6, 7, 27 }) do
  PszEfWZNq("collatz(" .. wPdZwiguCp .. ") = " .. gIOyIDrVQe(wPdZwiguCp))
end
for _, wPdZwiguCp in IyWVnEfbt({ -5, 0, 7, 42, 1000 }) do
  PszEfWZNq(wPdZwiguCp .. " is " .. zxWmdlERE(wPdZwiguCp))
end
PszEfWZNq(xHvKEpMRBuM(91), xHvKEpMRBuM(97), jgqTeQsBpB(98765))
PszEfWZNq(JxEmbDXKy("xxabcab"))
PszEfWZNq(JxEmbDXKy("aabx"))
