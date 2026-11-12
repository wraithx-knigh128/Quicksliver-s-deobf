--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local nGDKQPJZ, QfARQfrOuz, CMzujMpEfHoX, OMCqZiFh
nGDKQPJZ = pairs; QfARQfrOuz = ipairs; CMzujMpEfHoX = print; OMCqZiFh = table.concat;
-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
local function ArfoPVZM(cDGcFkDJOk, AemCUlrTcKk)
  local IIMfMjZurC = cDGcFkDJOk
  return function()
    IIMfMjZurC = IIMfMjZurC + AemCUlrTcKk
    return IIMfMjZurC
  end
end

local function IyWVnEfbt(ramgNjMn)
  local zxWmdlERE = {}
  return function(n)
    local yinXFpSjudBm = zxWmdlERE[n]
    if yinXFpSjudBm == nil then
      yinXFpSjudBm = ramgNjMn(n)
      zxWmdlERE[n] = yinXFpSjudBm
    end
    return yinXFpSjudBm
  end
end

local JxEmbDXKy
JxEmbDXKy = IyWVnEfbt(function(n)
  if n < 2 then
    return n
  end
  return JxEmbDXKy(n - 1) + JxEmbDXKy(n - 2)
end)

local function compose(...)
  local ycbhbXasaqVk = { ... }
  return function(x)
    for i = #ycbhbXasaqVk, 1, -1 do
      x = ycbhbXasaqVk[i](x)
    end
    return x
  end
end

local function PszEfWZNq(ujEVWTkAX, ramgNjMn)
  local gIOyIDrVQe = {}
  for i, v in inGDKQPJZ(ujEVWTkAX) do
    gIOyIDrVQe[i] = ramgNjMn(v, i)
  end
  return gIOyIDrVQe
end

local function sum(...)
  local wPdZwiguCp = 0
  for i = 1, select("#", ...) do
    wPdZwiguCp = wPdZwiguCp + (select(i, ...))
  end
  return wPdZwiguCp
end

local kweuqlPhf = ArfoPVZM(10, 5)
CMzujMpEfHoX(kweuqlPhf(), kweuqlPhf(), kweuqlPhf())
CMzujMpEfHoX(JxEmbDXKy(30), JxEmbDXKy(40))

local xHvKEpMRBuM = function(x) return x + 1 end
local jgqTeQsBpB = function(x) return x * 2 end
CMzujMpEfHoX(compose(xHvKEpMRBuM, jgqTeQsBpB)(5), compose(jgqTeQsBpB, xHvKEpMRBuM)(5))
CMzujMpEfHoX(OMCqZiFh(PszEfWZNq({ 1, 2, 3, 4 }, function(v, i) return v * i end), ","))
CMzujMpEfHoX(sum(1, 2, 3, 4, 5), sum())

local function NwgoUcmSm(mifacOVQ)
  local function eYIeSxSoGOvg(XmDOWrmiEd)
    local function hNInstHJ(AxYduOmIIH)
      return mifacOVQ * 100 + XmDOWrmiEd * 10 + AxYduOmIIH
    end
    return hNInstHJ
  end
  return eYIeSxSoGOvg
end
CMzujMpEfHoX(NwgoUcmSm(1)(2)(3))
