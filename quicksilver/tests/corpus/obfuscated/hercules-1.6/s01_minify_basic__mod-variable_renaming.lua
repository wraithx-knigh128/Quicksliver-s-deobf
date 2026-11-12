--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local ramgNjMn, PszEfWZNq, ujEVWTkAX, NwgoUcmSm, mifacOVQ, eYIeSxSoGOvg
ramgNjMn = tostring; PszEfWZNq = print; ujEVWTkAX = math.floor; NwgoUcmSm = math.sqrt; mifacOVQ = string.format; eYIeSxSoGOvg = table.concat;
-- s01: arithmetic and string utilities. Used for minification / formatting tests.
local function yinXFpSjudBm(JxEmbDXKy, ycbhbXasaqVk, gIOyIDrVQe)
  if JxEmbDXKy < ycbhbXasaqVk then
    return ycbhbXasaqVk
  elseif JxEmbDXKy > gIOyIDrVQe then
    return gIOyIDrVQe
  end
  return JxEmbDXKy
end

local function wPdZwiguCp(kweuqlPhf, xHvKEpMRBuM)
  while xHvKEpMRBuM ~= 0 do
    kweuqlPhf, xHvKEpMRBuM = xHvKEpMRBuM, kweuqlPhf % xHvKEpMRBuM
  end
  return kweuqlPhf
end

local function jgqTeQsBpB(ArfoPVZM)
  if ArfoPVZM < 2 then
    return false
  end
  for i = 2, ujEVWTkAX(NwgoUcmSm(ArfoPVZM)) do
    if ArfoPVZM % i == 0 then
      return false
    end
  end
  return true
end

local function cDGcFkDJOk(AemCUlrTcKk, IyWVnEfbt)
  local IIMfMjZurC = {}
  for index = 1, #AemCUlrTcKk do
    IIMfMjZurC[#IIMfMjZurC + 1] = ramgNjMn(AemCUlrTcKk[index])
  end
  return eYIeSxSoGOvg(IIMfMjZurC, IyWVnEfbt)
end

local zxWmdlERE = {}
for candidate = 1, 50 do
  if jgqTeQsBpB(candidate) then
    zxWmdlERE[#zxWmdlERE + 1] = candidate
  end
end

PszEfWZNq("zxWmdlERE: " .. cDGcFkDJOk(zxWmdlERE, ","))
PszEfWZNq("wPdZwiguCp(84, 36) = " .. wPdZwiguCp(84, 36))
PszEfWZNq("clamp: " .. yinXFpSjudBm(15, 0, 10) .. " " .. yinXFpSjudBm(-3, 0, 10) .. " " .. yinXFpSjudBm(7, 0, 10))
PszEfWZNq(mifacOVQ("%5.2f|%-6s|%03d", 3.14159, "ab", 7))
