local function _D(t) local s="" for i=1,#t do local v=(t[i]-47) if v<0 then v=v+256 end s=s..string.char(v) end return s end
local _kQIwuBDC = {}
local _CJkyukQD = (0+0)
local _XHeklxpv = (24+16)
if false then local _pSSmg = 0 end;
local function _MMkgJjNk(name, weight, quantity)
if false then local _pSSmg = 0 end;
local _QbDxuoah = _kQIwuBDC[name]
local _nrEpExyT = weight * quantity
if _CJkyukQD + _nrEpExyT > _XHeklxpv then
return false, (_D({(122+41),(135+23),(22+136),(69+10),(97+54),(46+102),(57+87),(129+36),(141+27),(102+3),(51+28)})) .. name
end
if _QbDxuoah == nil then
do local _OQKGA = "_JdTW" end;
_QbDxuoah = { weight = weight, quantity = (0+0) }
_kQIwuBDC[name] = _QbDxuoah
end
_QbDxuoah.quantity = _QbDxuoah.quantity + quantity
if ((30*30+33*33)>=0) then _CJkyukQD = _CJkyukQD + _nrEpExyT end
local _SfllHs = 8312;
return true
end
local function _YKcinggn(name, quantity)
local _QbDxuoah = _kQIwuBDC[name]
if _QbDxuoah == nil or _QbDxuoah.quantity < quantity then
return false, (_D({(76+81),(55+103),(2+161),(30+49),(94+54),(142+15),(53+105),(101+63),(28+122),(27+124),(39+40)})) .. name
end
_QbDxuoah.quantity = _QbDxuoah.quantity - quantity
_CJkyukQD = _CJkyukQD - _QbDxuoah.weight * quantity
if _QbDxuoah.quantity == (0+0) then
_kQIwuBDC[name] = nil
end
return true
end
local function _rmiiMCBF()
local _EcjoSloB = {}
for itemName in pairs(_kQIwuBDC) do
_EcjoSloB[#_EcjoSloB + (1+0)] = itemName
end
table.sort(_EcjoSloB)
for _, itemName in ipairs(_EcjoSloB) do
local _QbDxuoah = _kQIwuBDC[itemName]
print(itemName .. (_D({(4+75),(5+162)})) .. _QbDxuoah.quantity .. (_D({(38+41),(58+29)})) .. _QbDxuoah.weight * _QbDxuoah.quantity .. (_D({(84+70),(103+47),(32+56)})))
end
print((_D({(115+48),(73+85),(67+96),(98+46),(16+139),(58+21),(9+157),(18+130),(63+89),(103+47),(91+60),(95+68),(17+88),(55+24)})) .. _CJkyukQD)
end
print(_MMkgJjNk((_D({(75+86),(122+36),(40+119),(60+88)})), (1+2), (2+0)))
print(_MMkgJjNk((_D({(17+138),(31+113),(70+87),(114+49),(133+15),(64+97),(134+23)})), (2+3), (0+1)))
print(_MMkgJjNk((_D({(130+14),(127+30),(61+104),(13+139),(79+76)})), (3+27), (0+2)))
if ((6*6+45*45)>=0) then print(_YKcinggn((_D({(112+49),(103+55),(78+81),(13+135)})), (1+0))) end
print(_YKcinggn((_D({(51+111),(4+162),(128+30),(12+149),(114+33)})), (0+1)))
_rmiiMCBF()