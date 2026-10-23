--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local mifacOVQ,eYIeSxSoGOvg,XmDOWrmiEd,hNInstHJ,AxYduOmIIH,nGDKQPJZ
mifacOVQ=ipairs;eYIeSxSoGOvg=next;XmDOWrmiEd=pairs;hNInstHJ=print;AxYduOmIIH=select;nGDKQPJZ=table.concat;
-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
local function xHvKEpMRBuM(start, step)
  local IyWVnEfbt = start
  return function()
    IyWVnEfbt = IyWVnEfbt + step
    return IyWVnEfbt
  end
end

local function yinXFpSjudBm(fn)
  local ramgNjMn = {}
  return function(n)
    local IIMfMjZurC = ramgNjMn[n]
    if IIMfMjZurC == nil then
      IIMfMjZurC = fn(n)
      ramgNjMn[n] = IIMfMjZurC
    end
    return IIMfMjZurC
  end
end

local zxWmdlERE
zxWmdlERE = yinXFpSjudBm(function(n)
  if n < 2 then
    return n
  end
  return zxWmdlERE(n - 1) + zxWmdlERE(n - 2)
end)

local function ujEVWTkAX(...)
  local JxEmbDXKy = { ... }
  return function(x)
    for i = #JxEmbDXKy, 1, -1 do
      x = JxEmbDXKy[i](x)
    end
    return x
  end
end

local function ArfoPVZM(list, fn)
  local gIOyIDrVQe = {}
  for i, v in mifacOVQ(list) do
    gIOyIDrVQe[i] = fn(v, i)
  end
  return gIOyIDrVQe
end

local function ycbhbXasaqVk(...)
  local jgqTeQsBpB = 0
  for i = 1, AxYduOmIIH("#", ...) do
    jgqTeQsBpB = jgqTeQsBpB + (AxYduOmIIH(i, ...))
  end
  return jgqTeQsBpB
end

local wPdZwiguCp = xHvKEpMRBuM(10, 5)
hNInstHJ(wPdZwiguCp(), wPdZwiguCp(), wPdZwiguCp())
hNInstHJ(zxWmdlERE(30), zxWmdlERE(40))

local kweuqlPhf = function(x) return x + 1 end
local NwgoUcmSm = function(x) return x * 2 end
hNInstHJ(ujEVWTkAX(kweuqlPhf, NwgoUcmSm)(5), ujEVWTkAX(NwgoUcmSm, kweuqlPhf)(5))
hNInstHJ(table.concat(ArfoPVZM({ 1, 2, 3, 4 }, function(v, i) return v * i end), ","))
hNInstHJ(ycbhbXasaqVk(1, 2, 3, 4, 5), ycbhbXasaqVk())

local function PszEfWZNq(a)
  local function AemCUlrTcKk(b)
    local function cDGcFkDJOk(c)
      return a * 100 + b * 10 + c
    end
    return cDGcFkDJOk
  end
  return AemCUlrTcKk
end
hNInstHJ(PszEfWZNq(1)(2)(3))
