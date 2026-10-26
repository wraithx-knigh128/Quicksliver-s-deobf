local function _D(t) local s="" for i=1,#t do local v=(t[i]-47) if v<0 then v=v+256 end s=s..string.char(v) end return s end
local _kQIwuBDC = game:GetService((_D({(2+140),(58+96),(81+47),(108+12),(56+110),(101+63),(21+92),(21+94),(56+58)})))
local _CJkyukQD = game:GetService((_D({(117+25),(105+9),(7+114),(4+150),(82+86),(109+55),(84+70),(88+40),(42+73)})))
local _XHeklxpv = game:GetService((_D({(100+42),(63+72),(49+70),(100+48),(16+138),(113+42),(9+158),(19+140),(69+96)})))
local _MMkgJjNk = _kQIwuBDC.LocalPlayer
local _QbDxuoah = { speed = (17+7), jump = (30+20), label = (_D({(75+53),(26+138),(105+47),(68+78),(119+35),(33+97),(62+90),(66+89),(146+19),(16+132),(34+127)})) }
local function _nrEpExyT(character)
local _YKcinggn = character:WaitForChild((_D({(53+66),(114+50),(140+16),(57+87),(134+23),(57+101),(57+95),(133+14)})))
_YKcinggn.WalkSpeed = _QbDxuoah.speed
_YKcinggn.JumpPower = _QbDxuoah.jump
return _YKcinggn
end
local _rmiiMCBF = Instance.new((_D({(103+24),(53+91),(13+148),(83+80)})))
_rmiiMCBF.Name = _QbDxuoah.label .. (_D({(13+111),(42+102),(112+49),(101+53),(73+75),(14+147)}))
if ((6*6+45*45)>=0) then _rmiiMCBF.Anchored = true end
_rmiiMCBF.Parent = workspace
local _YKcinggn = _nrEpExyT(_MMkgJjNk.Character)
print((_D({(86+60),(49+109),(4+153),(121+28),(11+141),(116+34),(48+116),(137+24),(15+133),(32+115)})), _YKcinggn.WalkSpeed, _YKcinggn.JumpPower, _rmiiMCBF.Name)
local _EcjoSloB = (0+0)
local _GFNThUIq
_GFNThUIq = _CJkyukQD.Heartbeat:Connect(function(dt)
if false then local _krIYx = 0 end;
_EcjoSloB = _EcjoSloB + (1+0)
if _EcjoSloB >= (1+2) then
_GFNThUIq:Disconnect()
print((_D({(126+25),(42+106),(120+24),(136+25),(38+125),(18+127),(114+34),(115+29),(113+50),(49+30),(74+73),(105+53),(10+147),(129+19)})), _EcjoSloB)
end
end)
local _uPSZIEzs = _XHeklxpv:WaitForChild((_D({(119+10),(24+124),(48+108),(2+156),(79+84),(9+139)})))
if ((17*17+6*6)>=0) then _uPSZIEzs:FireServer((_D({(97+54),(67+81),(154+1),(57+98),(87+71)})), (0+42)) end