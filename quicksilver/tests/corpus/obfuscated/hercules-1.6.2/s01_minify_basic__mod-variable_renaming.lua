--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local ramgNjMn,PszEfWZNq,ujEVWTkAX,NwgoUcmSm,mifacOVQ,eYIeSxSoGOvg
ramgNjMn=print;PszEfWZNq=tostring;ujEVWTkAX=math.floor;NwgoUcmSm=math.sqrt;mifacOVQ=string.format;eYIeSxSoGOvg=table.concat
-- s01: arithmetic and string utilities. Used for minification / formatting tests.
local function IyWVnEfbt(zxWmdlERE, xHvKEpMRBuM, jgqTeQsBpB)
  if zxWmdlERE < xHvKEpMRBuM then
    return xHvKEpMRBuM
  elseif zxWmdlERE > jgqTeQsBpB then
    return jgqTeQsBpB
  end
  return zxWmdlERE
end

local function gIOyIDrVQe(ArfoPVZM, wPdZwiguCp)
  while wPdZwiguCp ~= 0 do
    ArfoPVZM, wPdZwiguCp = wPdZwiguCp, ArfoPVZM % wPdZwiguCp
  end
  return ArfoPVZM
end

local function cDGcFkDJOk(IIMfMjZurC)
  if IIMfMjZurC < 2 then
    return false
  end
  for i = 2, ujEVWTkAX(NwgoUcmSm(IIMfMjZurC)) do
    if IIMfMjZurC % i == 0 then
      return false
    end
  end
  return true
end

local function ycbhbXasaqVk(kweuqlPhf, AemCUlrTcKk)
  local JxEmbDXKy = {}
  for index = 1, #kweuqlPhf do
    JxEmbDXKy[#JxEmbDXKy + 1] = PszEfWZNq(kweuqlPhf[index])
  end
  return eYIeSxSoGOvg(JxEmbDXKy, AemCUlrTcKk)
end

local yinXFpSjudBm = {}
for candidate = 1, 50 do
  if cDGcFkDJOk(candidate) then
    yinXFpSjudBm[#yinXFpSjudBm + 1] = candidate
  end
end

ramgNjMn("primes: " .. ycbhbXasaqVk(yinXFpSjudBm, ","))
ramgNjMn("gcd(84, 36) = " .. gIOyIDrVQe(84, 36))
ramgNjMn("clamp: " .. IyWVnEfbt(15, 0, 10) .. " " .. IyWVnEfbt(-3, 0, 10) .. " " .. IyWVnEfbt(7, 0, 10))
ramgNjMn(mifacOVQ("%5.2f|%-6s|%03d", 3.14159, "ab", 7))
