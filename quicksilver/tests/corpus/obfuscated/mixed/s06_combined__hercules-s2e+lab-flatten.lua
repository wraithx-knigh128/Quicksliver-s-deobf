--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local nhJSDyuAtUk__1, NcSIlALoCb__2, xpmDhenWxq__3, YdQtXAvlqDz__4, tNdJNILRqFO__5, MSvRryPV__6, xkkxMuFEpfz__7
nhJSDyuAtUk__1 = pairs
NcSIlALoCb__2 = print
xpmDhenWxq__3 = math.min
YdQtXAvlqDz__4 = math.pi
tNdJNILRqFO__5 = string.format
MSvRryPV__6 = table.concat
xkkxMuFEpfz__7 = table.sort

local tUAlsFZCWmeM__8 = {
  [32] = " ",
  [97] = "a",
  [98] = "b",
  [99] = "c",
  [101] = "e",
  [102] = "f",
  [104] = "h",
  [105] = "i",
  [44] = ",",
  [46] = ".",
  [110] = "n",
  [111] = "o",
  [50] = "2",
  [113] = "q",
  [114] = "r",
  [84] = "T",
  [116] = "t",
  [117] = "u",
  [119] = "w",
  [58] = ":",
  [115] = "s",
  [43] = "+",
  [37] = "%",
  [108] = "l",
}

-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local UPSvCbjP__9 = {}
UPSvCbjP__9.__index = UPSvCbjP__9

function UPSvCbjP__9.new(name__10)
  return setmetatable({ name = name__10 }, UPSvCbjP__9)
end

function UPSvCbjP__9:describe()
  return VuTqcSIsT.name .. (tUAlsFZCWmeM__8[-728 + 760]
    .. tUAlsFZCWmeM__8[-807 + 926]
    .. tUAlsFZCWmeM__8[744 - (639)]
    .. tUAlsFZCWmeM__8[383 - (267)]
    .. tUAlsFZCWmeM__8[185 - (81)]
    .. tUAlsFZCWmeM__8[815 - (783)]
    .. tUAlsFZCWmeM__8[949 - (852)]
    .. tUAlsFZCWmeM__8[-801 + 915]
    .. tUAlsFZCWmeM__8[-93 + 194]
    .. tUAlsFZCWmeM__8[-735 + 832]
    .. tUAlsFZCWmeM__8[-826 + 858]) .. string.format((tUAlsFZCWmeM__8[273 - (236)]
    .. tUAlsFZCWmeM__8[844 - (798)]
    .. tUAlsFZCWmeM__8[-159 + 209]
    .. tUAlsFZCWmeM__8[312 - (210)]), VuTqcSIsT:area())
end

function UPSvCbjP__9:area()
  return 0
end

local kBqgHeoxN__11 = setmetatable({}, { __index = UPSvCbjP__9 })
kBqgHeoxN__11.__index = kBqgHeoxN__11

function kBqgHeoxN__11.new(radius__12)
  local VuTqcSIsT__13
  local st__44 = 30

  while true do
    if st__44 == 30 then
      VuTqcSIsT__13 = UPSvCbjP__9.new((tUAlsFZCWmeM__8[-878 + 977]
        .. tUAlsFZCWmeM__8[-446 + 551]
        .. tUAlsFZCWmeM__8[242 - (128)]
        .. tUAlsFZCWmeM__8[292 - (193)]
        .. tUAlsFZCWmeM__8[108 - (0)]
        .. tUAlsFZCWmeM__8[-770 + 871]))

      VuTqcSIsT__13.radius = radius__12
      return setmetatable(VuTqcSIsT__13, kBqgHeoxN__11)
    end
  end
end

function kBqgHeoxN__11:area()
  return math.pi * VuTqcSIsT.radius ^ 2
end

local pWPHtMkbefw__14 = setmetatable({}, { __index = UPSvCbjP__9 })
pWPHtMkbefw__14.__index = pWPHtMkbefw__14

function pWPHtMkbefw__14.new(width__15, height__16)
  local VuTqcSIsT__17
  local st__43 = 17

  while true do
    if st__43 == 17 then
      VuTqcSIsT__17 = UPSvCbjP__9.new((tUAlsFZCWmeM__8[923 - (809)]
        .. tUAlsFZCWmeM__8[-639 + 740]
        .. tUAlsFZCWmeM__8[-505 + 604]
        .. tUAlsFZCWmeM__8[-276 + 392]))

      VuTqcSIsT__17.width, VuTqcSIsT__17.height = width__15, height__16
      return setmetatable(VuTqcSIsT__17, pWPHtMkbefw__14)
    end
  end
end

function pWPHtMkbefw__14:area()
  return VuTqcSIsT.width * VuTqcSIsT.height
end

local ktgEHnNou__18 = {}
ktgEHnNou__18.__index = ktgEHnNou__18
ktgEHnNou__18.__len = nil

function ktgEHnNou__18.new()
  return setmetatable({ first = 1, last = 0, items = {} }, ktgEHnNou__18)
end

function ktgEHnNou__18:push(dVOVKxEh__19)
  VuTqcSIsT.last = VuTqcSIsT.last + 1
  VuTqcSIsT.items[VuTqcSIsT.last] = dVOVKxEh__19
end

function ktgEHnNou__18:pop()
  local dVOVKxEh__20
  local st__42 = 27

  while true do
    if st__42 == 27 then
      if VuTqcSIsT.first > VuTqcSIsT.last then
        st__42 = 39
      else
        st__42 = 30
      end
    elseif st__42 == 41 then
      dVOVKxEh__20 = VuTqcSIsT.items[VuTqcSIsT.first]
      VuTqcSIsT.items[VuTqcSIsT.first] = nil
      VuTqcSIsT.first = VuTqcSIsT.first + 1
      return dVOVKxEh__20
    elseif st__42 == 30 then
      st__42 = 41
    elseif st__42 == 39 then
      return nil
    end
  end
end

function ktgEHnNou__18:size()
  return VuTqcSIsT.last - VuTqcSIsT.first + 1
end

local ZrsMuoExE__21 = ktgEHnNou__18.new()
ZrsMuoExE__21:push(kBqgHeoxN__11.new(2))
ZrsMuoExE__21:push(pWPHtMkbefw__14.new(3, 4))

ZrsMuoExE__21:push(UPSvCbjP__9.new((tUAlsFZCWmeM__8[-378 + 476]
  .. tUAlsFZCWmeM__8[257 - (149)]
  .. tUAlsFZCWmeM__8[-198 + 309]
  .. tUAlsFZCWmeM__8[764 - (666)])))

while ZrsMuoExE__21:size() > 0 do
  NcSIlALoCb__2(ZrsMuoExE__21:pop():describe())
end

local function arxeLGbw__22(text__23)
  local RvxIrZJAmQ__24, it__32, st__33, ct__34, word__25, oAGwwvtKifUz__26, it__35, st__36, ct__37, word__27, tWLbHMHaLl__30, i__31, lim__38, stp__39, ctr__40
  local st__41 = 41

  while true do
    if st__41 == 28 then
      word__25 = it__32(st__33, ct__34)

      if word__25 ~= nil then
        st__41 = 43
      else
        st__41 = 50
      end
    elseif st__41 == 16 then
      table.sort(oAGwwvtKifUz__26, function(a__28, b__29)
        if RvxIrZJAmQ__24[a__28] ~= RvxIrZJAmQ__24[b__29] then
          return RvxIrZJAmQ__24[a__28] > RvxIrZJAmQ__24[b__29]
        end

        return a__28 < b__29
      end)

      tWLbHMHaLl__30 = {}
      ctr__40, lim__38, stp__39 = 1, math.min(3, #oAGwwvtKifUz__26), 1
      st__41 = 33
    elseif st__41 == 50 then
      oAGwwvtKifUz__26 = {}
      it__35, st__36, ct__37 = nhJSDyuAtUk__1(RvxIrZJAmQ__24)
      st__41 = 21
    elseif st__41 == 43 then
      ct__34 = word__25
      RvxIrZJAmQ__24[word__25] = (RvxIrZJAmQ__24[word__25] or 0) + 1
      st__41 = 28
    elseif st__41 == 25 then
      i__31 = ctr__40

      tWLbHMHaLl__30[#tWLbHMHaLl__30 + 1] = oAGwwvtKifUz__26[i__31]
        .. (tUAlsFZCWmeM__8[791 - (733)])
        .. RvxIrZJAmQ__24[oAGwwvtKifUz__26[i__31]]

      ctr__40 = ctr__40 + stp__39
      st__41 = 33
    elseif st__41 == 33 then
      if stp__39 > 0 and ctr__40 <= lim__38 or stp__39 <= 0 and ctr__40 >= lim__38 then
        st__41 = 25
      else
        st__41 = 40
      end
    elseif st__41 == 41 then
      RvxIrZJAmQ__24 = {}

      it__32, st__33, ct__34 = text__23:lower():gmatch((tUAlsFZCWmeM__8[733 - (696)]
        .. tUAlsFZCWmeM__8[-717 + 814]
        .. tUAlsFZCWmeM__8[-338 + 381]))

      st__41 = 28
    elseif st__41 == 37 then
      ct__37 = word__27
      oAGwwvtKifUz__26[#oAGwwvtKifUz__26 + 1] = word__27
      st__41 = 21
    elseif st__41 == 40 then
      return table.concat(tWLbHMHaLl__30, (tUAlsFZCWmeM__8[319 - (275)] .. tUAlsFZCWmeM__8[-696 + 728]))
    elseif st__41 == 21 then
      word__27 = it__35(st__36, ct__37)

      if word__27 ~= nil then
        st__41 = 37
      else
        st__41 = 16
      end
    end
  end
end

NcSIlALoCb__2(arxeLGbw__22((tUAlsFZCWmeM__8[-376 + 460]
  .. tUAlsFZCWmeM__8[-398 + 509]
  .. tUAlsFZCWmeM__8[-334 + 366]
  .. tUAlsFZCWmeM__8[-692 + 790]
  .. tUAlsFZCWmeM__8[-376 + 477]
  .. tUAlsFZCWmeM__8[-876 + 920]
  .. tUAlsFZCWmeM__8[313 - (281)]
  .. tUAlsFZCWmeM__8[839 - (728)]
  .. tUAlsFZCWmeM__8[223 - (109)]
  .. tUAlsFZCWmeM__8[929 - (897)]
  .. tUAlsFZCWmeM__8[248 - (138)]
  .. tUAlsFZCWmeM__8[120 - (9)]
  .. tUAlsFZCWmeM__8[624 - (508)]
  .. tUAlsFZCWmeM__8[928 - (896)]
  .. tUAlsFZCWmeM__8[-67 + 183]
  .. tUAlsFZCWmeM__8[-592 + 703]
  .. tUAlsFZCWmeM__8[-385 + 417]
  .. tUAlsFZCWmeM__8[-432 + 530]
  .. tUAlsFZCWmeM__8[717 - (616)]
  .. tUAlsFZCWmeM__8[906 - (862)]
  .. tUAlsFZCWmeM__8[-817 + 849]
  .. tUAlsFZCWmeM__8[701 - (585)]
  .. tUAlsFZCWmeM__8[683 - (579)]
  .. tUAlsFZCWmeM__8[459 - (362)]
  .. tUAlsFZCWmeM__8[-827 + 943]
  .. tUAlsFZCWmeM__8[-893 + 925]
  .. tUAlsFZCWmeM__8[573 - (468)]
  .. tUAlsFZCWmeM__8[-784 + 899]
  .. tUAlsFZCWmeM__8[692 - (660)]
  .. tUAlsFZCWmeM__8[-354 + 470]
  .. tUAlsFZCWmeM__8[457 - (353)]
  .. tUAlsFZCWmeM__8[-869 + 970]
  .. tUAlsFZCWmeM__8[295 - (263)]
  .. tUAlsFZCWmeM__8[-657 + 770]
  .. tUAlsFZCWmeM__8[-444 + 561]
  .. tUAlsFZCWmeM__8[-421 + 522]
  .. tUAlsFZCWmeM__8[-749 + 864]
  .. tUAlsFZCWmeM__8[-632 + 748]
  .. tUAlsFZCWmeM__8[347 - (242)]
  .. tUAlsFZCWmeM__8[193 - (82)]
  .. tUAlsFZCWmeM__8[-163 + 273]
  .. tUAlsFZCWmeM__8[-444 + 502]
  .. tUAlsFZCWmeM__8[-754 + 786]
  .. tUAlsFZCWmeM__8[-361 + 477]
  .. tUAlsFZCWmeM__8[786 - (675)]
  .. tUAlsFZCWmeM__8[-576 + 608]
  .. tUAlsFZCWmeM__8[-772 + 870]
  .. tUAlsFZCWmeM__8[345 - (244)]
  .. tUAlsFZCWmeM__8[644 - (612)]
  .. tUAlsFZCWmeM__8[196 - (77)]
  .. tUAlsFZCWmeM__8[-271 + 376]
  .. tUAlsFZCWmeM__8[-748 + 863]
  .. tUAlsFZCWmeM__8[-204 + 305]
  .. tUAlsFZCWmeM__8[-495 + 527]
  .. tUAlsFZCWmeM__8[-541 + 646]
  .. tUAlsFZCWmeM__8[-192 + 307]
  .. tUAlsFZCWmeM__8[-922 + 954]
  .. tUAlsFZCWmeM__8[184 - (68)]
  .. tUAlsFZCWmeM__8[776 - (665)]
  .. tUAlsFZCWmeM__8[-124 + 156]
  .. tUAlsFZCWmeM__8[-309 + 407]
  .. tUAlsFZCWmeM__8[-158 + 259])))
