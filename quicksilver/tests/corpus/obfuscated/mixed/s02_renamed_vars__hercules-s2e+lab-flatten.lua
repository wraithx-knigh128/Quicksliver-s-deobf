local oAGwwvtKifUz__1, ZrsMuoExE__2, pWPHtMkbefw__3, arxeLGbw__4, aFaUPSvCbjP__5, RiIMpmwuXKdq__6, RvxIrZJAmQ__7, kBqgHeoxN__8, nOMKYiuPDR__9, TKCssUWEUD__15, tWLbHMHaLl__19
local st__34 = 23

while true do
  if st__34 == 23 then
    oAGwwvtKifUz__1, ZrsMuoExE__2, pWPHtMkbefw__3, arxeLGbw__4 = nil, nil, nil, nil
    oAGwwvtKifUz__1 = ipairs
    ZrsMuoExE__2 = pairs
    pWPHtMkbefw__3 = print
    arxeLGbw__4 = table.sort

    aFaUPSvCbjP__5 = {
      [32] = " ",
      [97] = "a",
      [100] = "d",
      [101] = "e",
      [40] = "(",
      [41] = ")",
      [104] = "h",
      [105] = "i",
      [107] = "k",
      [108] = "l",
      [110] = "n",
      [111] = "o",
      [112] = "p",
      [114] = "r",
      [115] = "s",
      [116] = "t",
      [117] = "u",
      [118] = "v",
      [119] = "w",
      [120] = "x",
      [121] = "y",
      [103] = "g",
      [58] = ":",
    }

    RiIMpmwuXKdq__6 = {}
    RvxIrZJAmQ__7 = 0
    kBqgHeoxN__8 = 40

    nOMKYiuPDR__9 = function(name__10, weight__11, quantity__12)
      local dVOVKxEh__13, sceZGBGluIkn__14
      local st__33 = 50

      while true do
        if st__33 == 50 then
          dVOVKxEh__13 = RiIMpmwuXKdq__6[name__10]
          sceZGBGluIkn__14 = weight__11 * quantity__12

          if RvxIrZJAmQ__7 + sceZGBGluIkn__14 > kBqgHeoxN__8 then
            st__33 = 30
          else
            st__33 = 18
          end
        elseif st__33 == 48 then
          dVOVKxEh__13 = { weight = weight__11, quantity = 0 }
          RiIMpmwuXKdq__6[name__10] = dVOVKxEh__13
          st__33 = 25
        elseif st__33 == 18 then
          st__33 = 39
        elseif st__33 == 39 then
          if dVOVKxEh__13 == nil then
            st__33 = 48
          else
            st__33 = 17
          end
        elseif st__33 == 30 then
          return false, (aFaUPSvCbjP__5[-644 + 760]
            .. aFaUPSvCbjP__5[-815 + 926]
            .. aFaUPSvCbjP__5[744 - (633)]
            .. aFaUPSvCbjP__5[383 - (351)]
            .. aFaUPSvCbjP__5[185 - (81)]
            .. aFaUPSvCbjP__5[815 - (714)]
            .. aFaUPSvCbjP__5[949 - (852)]
            .. aFaUPSvCbjP__5[-797 + 915]
            .. aFaUPSvCbjP__5[-73 + 194]
            .. aFaUPSvCbjP__5[-774 + 832]
            .. aFaUPSvCbjP__5[-826 + 858]) .. name__10
        elseif st__33 == 25 then
          dVOVKxEh__13.quantity = dVOVKxEh__13.quantity + quantity__12
          RvxIrZJAmQ__7 = RvxIrZJAmQ__7 + sceZGBGluIkn__14
          return true
        elseif st__33 == 17 then
          st__33 = 25
        end
      end
    end

    TKCssUWEUD__15 = function(name__16, quantity__17)
      local dVOVKxEh__18
      local st__32 = 45

      while true do
        if st__32 == 45 then
          dVOVKxEh__18 = RiIMpmwuXKdq__6[name__16]

          if dVOVKxEh__18 == nil or dVOVKxEh__18.quantity < quantity__17 then
            st__32 = 24
          else
            st__32 = 53
          end
        elseif st__32 == 36 then
          dVOVKxEh__18.quantity = dVOVKxEh__18.quantity - quantity__17
          RvxIrZJAmQ__7 = RvxIrZJAmQ__7 - dVOVKxEh__18.weight * quantity__17

          if dVOVKxEh__18.quantity == 0 then
            st__32 = 37
          else
            st__32 = 29
          end
        elseif st__32 == 53 then
          st__32 = 36
        elseif st__32 == 29 then
          st__32 = 59
        elseif st__32 == 59 then
          return true
        elseif st__32 == 37 then
          RiIMpmwuXKdq__6[name__16] = nil
          st__32 = 59
        elseif st__32 == 24 then
          return false, (aFaUPSvCbjP__5[273 - (163)]
            .. aFaUPSvCbjP__5[844 - (733)]
            .. aFaUPSvCbjP__5[-93 + 209]
            .. aFaUPSvCbjP__5[312 - (280)]
            .. aFaUPSvCbjP__5[-876 + 977]
            .. aFaUPSvCbjP__5[-441 + 551]
            .. aFaUPSvCbjP__5[242 - (131)]
            .. aFaUPSvCbjP__5[292 - (175)]
            .. aFaUPSvCbjP__5[108 - (5)]
            .. aFaUPSvCbjP__5[-767 + 871]
            .. aFaUPSvCbjP__5[923 - (891)]) .. name__16
        end
      end
    end

    tWLbHMHaLl__19 = function()
      local tUAlsFZCWmeM__20, it__25, st__26, ct__27, itemName__21, it__28, st__29, ct__30, ___22, itemName__23, dVOVKxEh__24
      local st__31 = 37

      while true do
        if st__31 == 28 then
          ___22, itemName__23 = it__28(st__29, ct__30)

          if ___22 ~= nil then
            st__31 = 33
          else
            st__31 = 21
          end
        elseif st__31 == 25 then
          table.sort(tUAlsFZCWmeM__20)
          it__28, st__29, ct__30 = oAGwwvtKifUz__1(tUAlsFZCWmeM__20)
          st__31 = 28
        elseif st__31 == 16 then
          ct__27 = itemName__21
          tUAlsFZCWmeM__20[#tUAlsFZCWmeM__20 + 1] = itemName__21
          st__31 = 40
        elseif st__31 == 21 then
          pWPHtMkbefw__3((aFaUPSvCbjP__5[733 - (617)]
            .. aFaUPSvCbjP__5[-703 + 814]
            .. aFaUPSvCbjP__5[-265 + 381]
            .. aFaUPSvCbjP__5[791 - (694)]
            .. aFaUPSvCbjP__5[319 - (211)]
            .. aFaUPSvCbjP__5[-696 + 728]
            .. aFaUPSvCbjP__5[-341 + 460]
            .. aFaUPSvCbjP__5[-408 + 509]
            .. aFaUPSvCbjP__5[-261 + 366]
            .. aFaUPSvCbjP__5[-687 + 790]
            .. aFaUPSvCbjP__5[-373 + 477]
            .. aFaUPSvCbjP__5[-804 + 920]
            .. aFaUPSvCbjP__5[313 - (255)]
            .. aFaUPSvCbjP__5[839 - (807)]) .. RvxIrZJAmQ__7)

          break
        elseif st__31 == 40 then
          itemName__21 = it__25(st__26, ct__27)

          if itemName__21 ~= nil then
            st__31 = 16
          else
            st__31 = 25
          end
        elseif st__31 == 33 then
          ct__30 = ___22
          dVOVKxEh__24 = RiIMpmwuXKdq__6[itemName__23]

          pWPHtMkbefw__3(itemName__23
            .. (aFaUPSvCbjP__5[-708 + 740] .. aFaUPSvCbjP__5[-484 + 604])
            .. dVOVKxEh__24.quantity
            .. (aFaUPSvCbjP__5[-360 + 392] .. aFaUPSvCbjP__5[-436 + 476])
            .. dVOVKxEh__24.weight * dVOVKxEh__24.quantity
            .. (aFaUPSvCbjP__5[257 - (150)] .. aFaUPSvCbjP__5[-206 + 309] .. aFaUPSvCbjP__5[764 - (723)]))

          st__31 = 28
        elseif st__31 == 37 then
          tUAlsFZCWmeM__20 = {}
          it__25, st__26, ct__27 = ZrsMuoExE__2(RiIMpmwuXKdq__6)
          st__31 = 40
        end
      end
    end

    pWPHtMkbefw__3(nOMKYiuPDR__9((aFaUPSvCbjP__5[223 - (109)]
      .. aFaUPSvCbjP__5[929 - (818)]
      .. aFaUPSvCbjP__5[248 - (136)]
      .. aFaUPSvCbjP__5[120 - (19)]), 3, 2))

    pWPHtMkbefw__3(nOMKYiuPDR__9((aFaUPSvCbjP__5[624 - (516)]
      .. aFaUPSvCbjP__5[928 - (831)]
      .. aFaUPSvCbjP__5[-73 + 183]
      .. aFaUPSvCbjP__5[-587 + 703]
      .. aFaUPSvCbjP__5[-316 + 417]
      .. aFaUPSvCbjP__5[-416 + 530]
      .. aFaUPSvCbjP__5[717 - (607)]), 5, 1))

    pWPHtMkbefw__3(nOMKYiuPDR__9((aFaUPSvCbjP__5[906 - (809)]
      .. aFaUPSvCbjP__5[-739 + 849]
      .. aFaUPSvCbjP__5[701 - (583)]
      .. aFaUPSvCbjP__5[683 - (578)]
      .. aFaUPSvCbjP__5[459 - (351)]), 30, 2))

    pWPHtMkbefw__3(TKCssUWEUD__15((aFaUPSvCbjP__5[-829 + 943]
      .. aFaUPSvCbjP__5[-814 + 925]
      .. aFaUPSvCbjP__5[573 - (461)]
      .. aFaUPSvCbjP__5[-798 + 899]), 1))

    pWPHtMkbefw__3(TKCssUWEUD__15((aFaUPSvCbjP__5[692 - (577)]
      .. aFaUPSvCbjP__5[-351 + 470]
      .. aFaUPSvCbjP__5[457 - (346)]
      .. aFaUPSvCbjP__5[-856 + 970]
      .. aFaUPSvCbjP__5[295 - (195)]), 1))

    tWLbHMHaLl__19()
    break
  end
end
