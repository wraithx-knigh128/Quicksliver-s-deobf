local function _D(t) local s="" for i=1,#t do local v=(t[i]-47) if v<0 then v=v+256 end s=s..string.char(v) end return s end
local function _kQIwuBDC(start, step)
local _CJkyukQD = start
return function()
_CJkyukQD = _CJkyukQD + step
return _CJkyukQD
end
end
local function _XHeklxpv(fn)
local _MMkgJjNk = {}
return function(n)
local _QbDxuoah = _MMkgJjNk[n]
if _QbDxuoah == nil then
_QbDxuoah = fn(n)
_MMkgJjNk[n] = _QbDxuoah
end
return _QbDxuoah
end
end
local _nrEpExyT
_nrEpExyT = _XHeklxpv(function(n)
if n < (1+1) then
return n
end
return _nrEpExyT(n - (0+1)) + _nrEpExyT(n - (1+1))
end)
local function _YKcinggn(...)
local _rmiiMCBF = { ... }
return function(x)
for i = #_rmiiMCBF, (0+1), -(0+1) do
x = _rmiiMCBF[i](x)
end
return x
end
end
local function _EcjoSloB(list, fn)
local _GFNThUIq = {}
for i, v in ipairs(list) do
if false then local _tDbUk = 0 end;
_GFNThUIq[i] = fn(v, i)
end
return _GFNThUIq
end
local function _uPSZIEzs(...)
local _atHVrGjj = (0+0)
for i = (0+1), select((_D({(63+19)})), ...) do
if ((6*6+1*1)>=0) then _atHVrGjj = _atHVrGjj + (select(i, ...)) end
end
return _atHVrGjj
end
local _ARWdbzJC = _kQIwuBDC((3+7), (5+0))
print(_ARWdbzJC(), _ARWdbzJC(), _ARWdbzJC())
print(_nrEpExyT((3+27)), _nrEpExyT((9+31)))
local _qazdIx = 9879;
local _KtLyvJfM = function(x) return x + (0+1) end
local _dgwKFEiK = function(x) return x * (1+1) end
print(_YKcinggn(_KtLyvJfM, _dgwKFEiK)((2+3)), _YKcinggn(_dgwKFEiK, _KtLyvJfM)((4+1)))
print(table.concat(_EcjoSloB({ (0+1), (2+0), (3+0), (1+3) }, function(v, i) return v * i end), (_D({(11+80)}))))
print(_uPSZIEzs((1+0), (2+0), (2+1), (3+1), (3+2)), _uPSZIEzs())
local function _yOnvwUfl(a)
local function _xKVuTtuV(b)
local function _QteBfpKI(c)
return a * (66+34) + b * (0+10) + c
end
if false then local _tDbUk = 0 end;
return _QteBfpKI
end
return _xKVuTtuV
end
print(_yOnvwUfl((1+0))((2+0))((0+3)))