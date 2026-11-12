--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local mifacOVQ,eYIeSxSoGOvg,XmDOWrmiEd,hNInstHJ,AxYduOmIIH,nGDKQPJZ
mifacOVQ=ipairs;eYIeSxSoGOvg=next;XmDOWrmiEd=pairs;hNInstHJ=print;AxYduOmIIH=select;nGDKQPJZ=table.concat;
-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
local function IIMfMjZurC(start, step)
  local PszEfWZNq = start
  return function()
    PszEfWZNq = PszEfWZNq + step
    return PszEfWZNq
  end
end

local function gIOyIDrVQe(fn)
  local zxWmdlERE = {}
  return function(n)
    local yinXFpSjudBm = zxWmdlERE[n]
    if yinXFpSjudBm == nil then
      yinXFpSjudBm = fn(n)
      zxWmdlERE[n] = yinXFpSjudBm
    end
    return yinXFpSjudBm
  end
end

local ujEVWTkAX
ujEVWTkAX = gIOyIDrVQe(function(n)
  if n < 2 then
    return n
  end
  return ujEVWTkAX(n - 1) + ujEVWTkAX(n - 2)
end)

local function NwgoUcmSm(...)
  local jgqTeQsBpB = { ... }
  return function(x)
    for i = #jgqTeQsBpB, 1, -1 do
      x = jgqTeQsBpB[i](x)
    end
    return x
  end
end

local function xHvKEpMRBuM(list, fn)
  local IyWVnEfbt = {}
  for i, v in mifacOVQ(list) do
    IyWVnEfbt[i] = fn(v, i)
  end
  return IyWVnEfbt
end

local function ramgNjMn(...)
  local cDGcFkDJOk = 0
  for i = 1, AxYduOmIIH("#", ...) do
    cDGcFkDJOk = cDGcFkDJOk + (AxYduOmIIH(i, ...))
  end
  return cDGcFkDJOk
end

local JxEmbDXKy = IIMfMjZurC(10, 5)
hNInstHJ(JxEmbDXKy(), JxEmbDXKy(), JxEmbDXKy())
hNInstHJ(ujEVWTkAX(30), ujEVWTkAX(40))

local wPdZwiguCp = function(x) return x + 1 end
local kweuqlPhf = function(x) return x * 2 end
hNInstHJ(NwgoUcmSm(wPdZwiguCp, kweuqlPhf)(5), NwgoUcmSm(kweuqlPhf, wPdZwiguCp)(5))
hNInstHJ(table.concat(xHvKEpMRBuM({ 1, 2, 3, 4 }, function(v, i) return v * i end), ","))
hNInstHJ(ramgNjMn(1, 2, 3, 4, 5), ramgNjMn())

local function ycbhbXasaqVk(a)
  local function ArfoPVZM(b)
    local function AemCUlrTcKk(c)
      return a * 100 + b * 10 + c
    end
    return AemCUlrTcKk
  end
  return ArfoPVZM
end
hNInstHJ(ycbhbXasaqVk(1)(2)(3))
