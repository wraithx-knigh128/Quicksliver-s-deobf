--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local QfARQfrOuz, CMzujMpEfHoX, OMCqZiFh, WaDQbQOII
QfARQfrOuz = ipairs; CMzujMpEfHoX = pairs; OMCqZiFh = print; WaDQbQOII = table.concat;
-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
local function cDGcFkDJOk(AemCUlrTcKk, IyWVnEfbt)
  local IIMfMjZurC = AemCUlrTcKk
  return function()
    IIMfMjZurC = IIMfMjZurC + IyWVnEfbt
    return IIMfMjZurC
  end
end

local function ramgNjMn(PszEfWZNq)
  local zxWmdlERE = {}
  return function(n)
    local yinXFpSjudBm = zxWmdlERE[n]
    if yinXFpSjudBm == nil then
      yinXFpSjudBm = PszEfWZNq(n)
      zxWmdlERE[n] = yinXFpSjudBm
    end
    return yinXFpSjudBm
  end
end

local ycbhbXasaqVk
ycbhbXasaqVk = ramgNjMn(function(n)
  if n < 2 then
    return n
  end
  return ycbhbXasaqVk(n - 1) + ycbhbXasaqVk(n - 2)
end)

local function compose(...)
  local gIOyIDrVQe = { ... }
  return function(x)
    for i = #gIOyIDrVQe, 1, -1 do
      x = gIOyIDrVQe[i](x)
    end
    return x
  end
end

local function ujEVWTkAX(NwgoUcmSm, PszEfWZNq)
  local wPdZwiguCp = {}
  for i, v in QfARQfrOuz(NwgoUcmSm) do
    wPdZwiguCp[i] = PszEfWZNq(v, i)
  end
  return wPdZwiguCp
end

local function sum(...)
  local kweuqlPhf = 0
  for i = 1, select("#", ...) do
    kweuqlPhf = kweuqlPhf + (select(i, ...))
  end
  return kweuqlPhf
end

local xHvKEpMRBuM = cDGcFkDJOk(10, 5)
OMCqZiFh(xHvKEpMRBuM(), xHvKEpMRBuM(), xHvKEpMRBuM())
OMCqZiFh(ycbhbXasaqVk(30), ycbhbXasaqVk(40))

local jgqTeQsBpB = function(x) return x + 1 end
local ArfoPVZM = function(x) return x * 2 end
OMCqZiFh(compose(jgqTeQsBpB, ArfoPVZM)(5), compose(ArfoPVZM, jgqTeQsBpB)(5))
OMCqZiFh(WaDQbQOII(ujEVWTkAX({ 1, 2, 3, 4 }, function(v, i) return v * i end), ","))
OMCqZiFh(sum(1, 2, 3, 4, 5), sum())

local function mifacOVQ(eYIeSxSoGOvg)
  local function XmDOWrmiEd(hNInstHJ)
    local function AxYduOmIIH(nGDKQPJZ)
      return eYIeSxSoGOvg * 100 + hNInstHJ * 10 + nGDKQPJZ
    end
    return inner
  end
  return middle
end
OMCqZiFh(mifacOVQ(1)(2)(3))
