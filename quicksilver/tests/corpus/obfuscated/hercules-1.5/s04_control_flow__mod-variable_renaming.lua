--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local PszEfWZNq, ujEVWTkAX, NwgoUcmSm, mifacOVQ, eYIeSxSoGOvg
PszEfWZNq = pairs; ujEVWTkAX = ipairs; NwgoUcmSm = print; mifacOVQ = math.floor; eYIeSxSoGOvg = table.concat;
-- s04: branching and looping. Used to test control-flow recovery.
local function xHvKEpMRBuM(jgqTeQsBpB)
  local IIMfMjZurC = 0
  while jgqTeQsBpB ~= 1 do
    if jgqTeQsBpB % 2 == 0 then
      jgqTeQsBpB = jgqTeQsBpB / 2
    else
      jgqTeQsBpB = 3 * jgqTeQsBpB + 1
    end
    IIMfMjZurC = IIMfMjZurC + 1
  end
  return IIMfMjZurC
end

local function ArfoPVZM(jgqTeQsBpB)
  if jgqTeQsBpB < 0 then
    return "negative"
  elseif jgqTeQsBpB == 0 then
    return "zero"
  elseif jgqTeQsBpB < 10 then
    return "small"
  elseif jgqTeQsBpB < 100 then
    return "medium"
  else
    return "large"
  end
end

local function cDGcFkDJOk(jgqTeQsBpB)
  local zxWmdlERE
  yinXFpSjudBm JxEmbDXKy = 2, jgqTeQsBpB do
    if jgqTeQsBpB % JxEmbDXKy == 0 then
      zxWmdlERE = JxEmbDXKy
      break
    end
  end
  return zxWmdlERE
end

local function AemCUlrTcKk(jgqTeQsBpB)
  local ycbhbXasaqVk = 0
  repeat
    ycbhbXasaqVk = ycbhbXasaqVk + jgqTeQsBpB % 10
    jgqTeQsBpB = mifacOVQ(jgqTeQsBpB / 10)
  until jgqTeQsBpB == 0
  return ycbhbXasaqVk
end

local function IyWVnEfbt(ramgNjMn)
  local gIOyIDrVQe = "start"
  local wPdZwiguCp = {}
  yinXFpSjudBm i = 1, #ramgNjMn do
    local kweuqlPhf = ramgNjMn:sub(i, i)
    if gIOyIDrVQe == "start" then
      if kweuqlPhf == "a" then gIOyIDrVQe = "seenA" end
    elseif gIOyIDrVQe == "seenA" then
      if kweuqlPhf == "b" then
        gIOyIDrVQe = "seenAB"
      elseif kweuqlPhf ~= "a" then
        gIOyIDrVQe = "start"
      end
    elseif gIOyIDrVQe == "seenAB" then
      gIOyIDrVQe = (kweuqlPhf == "c") and "accept" or "start"
    end
    wPdZwiguCp[#wPdZwiguCp + 1] = gIOyIDrVQe
  end
  return gIOyIDrVQe, eYIeSxSoGOvg(wPdZwiguCp, ">")
end

yinXFpSjudBm _, jgqTeQsBpB in iPszEfWZNq({ 6, 7, 27 }) do
  NwgoUcmSm("collatz(" .. jgqTeQsBpB .. ") = " .. xHvKEpMRBuM(jgqTeQsBpB))
end
yinXFpSjudBm _, jgqTeQsBpB in iPszEfWZNq({ -5, 0, 7, 42, 1000 }) do
  NwgoUcmSm(jgqTeQsBpB .. " is " .. ArfoPVZM(jgqTeQsBpB))
end
NwgoUcmSm(cDGcFkDJOk(91), cDGcFkDJOk(97), AemCUlrTcKk(98765))
NwgoUcmSm(IyWVnEfbt("xxabcab"))
NwgoUcmSm(IyWVnEfbt("aabx"))
