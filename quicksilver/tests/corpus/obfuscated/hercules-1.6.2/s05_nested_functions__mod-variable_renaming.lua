--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local CMzujMpEfHoX,OMCqZiFh,WaDQbQOII,grmgxVXMVD,icvcvxwbrbjQ,TxzkRBbZa
CMzujMpEfHoX=ipairs;OMCqZiFh=next;WaDQbQOII=pairs;grmgxVXMVD=print;icvcvxwbrbjQ=select;TxzkRBbZa=table.concat
-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
local function gIOyIDrVQe(JxEmbDXKy, kweuqlPhf)
  local IyWVnEfbt = JxEmbDXKy
  return function()
    IyWVnEfbt = IyWVnEfbt + kweuqlPhf
    return IyWVnEfbt
  end
end

local function nGDKQPJZ(PszEfWZNq)
  local QfARQfrOuz = {}
  return function(n)
    local cDGcFkDJOk = QfARQfrOuz[n]
    if cDGcFkDJOk == nil then
      cDGcFkDJOk = PszEfWZNq(n)
      QfARQfrOuz[n] = cDGcFkDJOk
    end
    return cDGcFkDJOk
  end
end

local ArfoPVZM
ArfoPVZM = nGDKQPJZ(function(n)
  if n < 2 then
    return n
  end
  return ArfoPVZM(n - 1) + ArfoPVZM(n - 2)
end)

local function wPdZwiguCp(...)
  local AxYduOmIIH = { ... }
  return function(x)
    for i = #AxYduOmIIH, 1, -1 do
      x = AxYduOmIIH[i](x)
    end
    return x
  end
end

local function zxWmdlERE(NwgoUcmSm, PszEfWZNq)
  local yinXFpSjudBm = {}
  for i, v in CMzujMpEfHoX(NwgoUcmSm) do
    yinXFpSjudBm[i] = PszEfWZNq(v, i)
  end
  return yinXFpSjudBm
end

local function XmDOWrmiEd(...)
  local jgqTeQsBpB = 0
  for i = 1, icvcvxwbrbjQ("#", ...) do
    jgqTeQsBpB = jgqTeQsBpB + (icvcvxwbrbjQ(i, ...))
  end
  return jgqTeQsBpB
end

local hNInstHJ = gIOyIDrVQe(10, 5)
grmgxVXMVD(hNInstHJ(), hNInstHJ(), hNInstHJ())
grmgxVXMVD(ArfoPVZM(30), ArfoPVZM(40))

local eYIeSxSoGOvg = function(x) return x + 1 end
local xHvKEpMRBuM = function(x) return x * 2 end
grmgxVXMVD(wPdZwiguCp(eYIeSxSoGOvg, xHvKEpMRBuM)(5), wPdZwiguCp(xHvKEpMRBuM, eYIeSxSoGOvg)(5))
grmgxVXMVD(TxzkRBbZa(zxWmdlERE({ 1, 2, 3, 4 }, function(v, i) return v * i end), ","))
grmgxVXMVD(XmDOWrmiEd(1, 2, 3, 4, 5), XmDOWrmiEd())

local function mifacOVQ(ujEVWTkAX)
  local function ramgNjMn(IIMfMjZurC)
    local function ycbhbXasaqVk(AemCUlrTcKk)
      return ujEVWTkAX * 100 + IIMfMjZurC * 10 + AemCUlrTcKk
    end
    return ycbhbXasaqVk
  end
  return ramgNjMn
end
grmgxVXMVD(mifacOVQ(1)(2)(3))
