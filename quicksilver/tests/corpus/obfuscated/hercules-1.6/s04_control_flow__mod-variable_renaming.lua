--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local ramgNjMn, PszEfWZNq, ujEVWTkAX, NwgoUcmSm, mifacOVQ
ramgNjMn = ipairs; PszEfWZNq = pairs; ujEVWTkAX = print; NwgoUcmSm = math.floor; mifacOVQ = table.concat;
-- s04: branching and looping. Used to test control-flow recovery.
local function kweuqlPhf(xHvKEpMRBuM)
  local IIMfMjZurC = 0
  while xHvKEpMRBuM ~= 1 do
    if xHvKEpMRBuM % 2 == 0 then
      xHvKEpMRBuM = xHvKEpMRBuM / 2
    else
      xHvKEpMRBuM = 3 * xHvKEpMRBuM + 1
    end
    IIMfMjZurC = IIMfMjZurC + 1
  end
  return IIMfMjZurC
end

local function jgqTeQsBpB(xHvKEpMRBuM)
  if xHvKEpMRBuM < 0 then
    return "negative"
  elseif xHvKEpMRBuM == 0 then
    return "zero"
  elseif xHvKEpMRBuM < 10 then
    return "small"
  elseif xHvKEpMRBuM < 100 then
    return "medium"
  else
    return "large"
  end
end

local function ArfoPVZM(xHvKEpMRBuM)
  local zxWmdlERE
  yinXFpSjudBm d = 2, xHvKEpMRBuM do
    if xHvKEpMRBuM % d == 0 then
      zxWmdlERE = d
      break
    end
  end
  return zxWmdlERE
end

local function cDGcFkDJOk(xHvKEpMRBuM)
  local JxEmbDXKy = 0
  repeat
    JxEmbDXKy = JxEmbDXKy + xHvKEpMRBuM % 10
    xHvKEpMRBuM = NwgoUcmSm(xHvKEpMRBuM / 10)
  until xHvKEpMRBuM == 0
  return JxEmbDXKy
end

local function AemCUlrTcKk(IyWVnEfbt)
  local ycbhbXasaqVk = "start"
  local gIOyIDrVQe = {}
  yinXFpSjudBm i = 1, #IyWVnEfbt do
    local wPdZwiguCp = IyWVnEfbt:sub(i, i)
    if ycbhbXasaqVk == "start" then
      if wPdZwiguCp == "a" then ycbhbXasaqVk = "seenA" end
    elseif ycbhbXasaqVk == "seenA" then
      if wPdZwiguCp == "b" then
        ycbhbXasaqVk = "seenAB"
      elseif wPdZwiguCp ~= "a" then
        ycbhbXasaqVk = "start"
      end
    elseif ycbhbXasaqVk == "seenAB" then
      ycbhbXasaqVk = (wPdZwiguCp == "c") and "accept" or "start"
    end
    gIOyIDrVQe[#gIOyIDrVQe + 1] = ycbhbXasaqVk
  end
  return ycbhbXasaqVk, mifacOVQ(gIOyIDrVQe, ">")
end

yinXFpSjudBm _, xHvKEpMRBuM in ramgNjMn({ 6, 7, 27 }) do
  ujEVWTkAX("collatz(" .. xHvKEpMRBuM .. ") = " .. kweuqlPhf(xHvKEpMRBuM))
end
yinXFpSjudBm _, xHvKEpMRBuM in ramgNjMn({ -5, 0, 7, 42, 1000 }) do
  ujEVWTkAX(xHvKEpMRBuM .. " is " .. jgqTeQsBpB(xHvKEpMRBuM))
end
ujEVWTkAX(ArfoPVZM(91), ArfoPVZM(97), cDGcFkDJOk(98765))
ujEVWTkAX(AemCUlrTcKk("xxabcab"))
ujEVWTkAX(AemCUlrTcKk("aabx"))
