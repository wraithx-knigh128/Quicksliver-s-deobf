local function _D(t) local s="" for i=1,#t do local v=(t[i]-47) if v<0 then v=v+256 end s=s..string.char(v) end return s end
local _kQIwuBDC = {}
if ((27*27+41*41)>=0) then _kQIwuBDC.__index = _kQIwuBDC end
function _kQIwuBDC.new(name)
return setmetatable({ name = name }, _kQIwuBDC)
end
function _kQIwuBDC:describe()
return self.name .. (_D({(31+48),(129+37),(127+25),(158+5),(97+54),(46+33),(70+74),(56+105),(2+146),(54+90),(50+29)})) .. string.format((_D({(76+8),(31+62),(60+37),(27+122)})), self:area())
end
function _kQIwuBDC:area()
return (0+0)
end
local _CJkyukQD = setmetatable({}, { __index = _kQIwuBDC })
_CJkyukQD.__index = _CJkyukQD
if false then local _TlvLo = 0 end;
function _CJkyukQD.new(radius)
local self = _kQIwuBDC.new((_D({(72+74),(125+27),(148+13),(8+138),(4+151),(72+76)})))
self.radius = radius
return setmetatable(self, _CJkyukQD)
end
function _CJkyukQD:area()
return math.pi * self.radius ^ (1+1)
end
local _XHeklxpv = setmetatable({}, { __index = _kQIwuBDC })
_XHeklxpv.__index = _XHeklxpv
function _XHeklxpv.new(width, height)
local self = _kQIwuBDC.new((_D({(88+73),(102+46),(54+92),(115+48)})))
if ((33*33+40*40)>=0) then self.width, self.height = width, height end
return setmetatable(self, _XHeklxpv)
end
local _IYxmrR = 4840;
function _XHeklxpv:area()
return self.width * self.height
end
local _MMkgJjNk = {}
_MMkgJjNk.__index = _MMkgJjNk
if ((3*3+24*24)>=0) then _MMkgJjNk.__len = nil end
function _MMkgJjNk.new()
return setmetatable({ first = (0+1), last = (0+0), items = {} }, _MMkgJjNk)
end
function _MMkgJjNk:push(_QbDxuoah)
self.last = self.last + (1+0)
if false then local _TlvLo = 0 end;
self.items[self.last] = _QbDxuoah
end
function _MMkgJjNk:pop()
if self.first > self.last then
return nil
end
local _QbDxuoah = self.items[self.first]
if ((22*22+3*3)>=0) then self.items[self.first] = nil end
self.first = self.first + (0+1)
return _QbDxuoah
end
local _IYxmrR = 4840;
function _MMkgJjNk:size()
if false then local _TlvLo = 0 end;
return self.last - self.first + (1+0)
end
local _nrEpExyT = _MMkgJjNk.new()
_nrEpExyT:push(_CJkyukQD.new((0+2)))
_nrEpExyT:push(_XHeklxpv.new((0+3), (2+2)))
_nrEpExyT:push(_kQIwuBDC.new((_D({(100+45),(93+62),(92+66),(23+122)}))))
while _nrEpExyT:size() > (0+0) do
print(_nrEpExyT:pop():describe())
end
local function _YKcinggn(text)
local _rmiiMCBF = {}
for word in text:lower():gmatch((_D({(39+45),(112+32),(23+67)}))) do
if false then local _TlvLo = 0 end;
_rmiiMCBF[word] = (_rmiiMCBF[word] or (0+0)) + (0+1)
end
local _EcjoSloB = {}
for word in pairs(_rmiiMCBF) do
_EcjoSloB[#_EcjoSloB + (1+0)] = word
end
table.sort(_EcjoSloB, function(a, b)
if false then local _TlvLo = 0 end;
if _rmiiMCBF[a] ~= _rmiiMCBF[b] then
return _rmiiMCBF[a] > _rmiiMCBF[b]
end
return a < b
end)
local _GFNThUIq = {}
for i = (0+1), math.min((0+3), #_EcjoSloB) do
_GFNThUIq[#_GFNThUIq + (0+1)] = _EcjoSloB[i] .. (_D({(73+32)})) .. _rmiiMCBF[_EcjoSloB[i]]
end
return table.concat(_GFNThUIq, (_D({(82+9),(31+48)})))
end
print(_YKcinggn((_D({(112+19),(57+101),(30+49),(131+14),(120+28),(34+57),(6+73),(81+77),(18+143),(23+56),(110+47),(103+55),(80+83),(7+72),(96+67),(49+109),(2+77),(117+28),(11+137),(70+21),(23+56),(138+25),(15+136),(31+113),(36+127),(51+28),(53+99),(135+27),(22+57),(136+27),(128+23),(35+113),(10+69),(123+37),(131+33),(103+45),(101+61),(82+81),(101+51),(10+148),(137+20),(97+8),(13+66),(50+113),(2+156),(38+41),(9+136),(95+53),(36+43),(165+1),(56+96),(89+73),(3+145),(70+9),(30+122),(72+90),(28+51),(110+53),(9+149),(22+57),(28+117),(48+100)}))))