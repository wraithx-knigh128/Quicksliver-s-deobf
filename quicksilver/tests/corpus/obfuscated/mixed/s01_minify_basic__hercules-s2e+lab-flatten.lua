local aFaUPSvCbjP__1, kBqgHeoxN__2, dVOVKxEh__3, RvxIrZJAmQ__4, tUAlsFZCWmeM__5, tWLbHMHaLl__6, RiIMpmwuXKdq__7, sceZGBGluIkn__8, EsnOMKYiuPD__12, BeQUwPMJTUz__15, kTKCssUWEUD__18, hJNplAqzvFk__23, candidate__24, lim__33, stp__34, ctr__35
local st__36 = 50

while true do
  if st__36 == 50 then
    aFaUPSvCbjP__1, kBqgHeoxN__2, dVOVKxEh__3, RvxIrZJAmQ__4, tUAlsFZCWmeM__5, tWLbHMHaLl__6 = nil, nil, nil, nil, nil, nil
    aFaUPSvCbjP__1 = print
    kBqgHeoxN__2 = tostring
    dVOVKxEh__3 = math.floor
    RvxIrZJAmQ__4 = math.sqrt
    tUAlsFZCWmeM__5 = string.format
    tWLbHMHaLl__6 = table.concat

    RiIMpmwuXKdq__7 = {
      [124] = "|",
      [32] = " ",
      [97] = "a",
      [98] = "b",
      [99] = "c",
      [100] = "d",
      [101] = "e",
      [40] = "(",
      [103] = "g",
      [102] = "f",
      [105] = "i",
      [44] = ",",
      [45] = "-",
      [108] = "l",
      [109] = "m",
      [48] = "0",
      [50] = "2",
      [112] = "p",
      [51] = "3",
      [52] = "4",
      [115] = "s",
      [54] = "6",
      [46] = ".",
      [56] = "8",
      [53] = "5",
      [58] = ":",
      [37] = "%",
      [41] = ")",
      [61] = "=",
      [114] = "r",
    }

    sceZGBGluIkn__8 = function(value__9, low__10, high__11)
      if value__9 < low__10 then
        return low__10
      elseif value__9 > high__11 then
        return high__11
      end

      return value__9
    end

    EsnOMKYiuPD__12 = function(a__13, b__14)
      while b__14 ~= 0 do
        a__13, b__14 = b__14, a__13 % b__14
      end

      return a__13
    end

    BeQUwPMJTUz__15 = function(n__16)
      local i__17, lim__29, stp__30, ctr__31
      local st__32 = 39

      while true do
        if st__32 == 39 then
          if n__16 < 2 then
            st__32 = 34
          else
            st__32 = 64
          end
        elseif st__32 == 31 then
          return false
        elseif st__32 == 64 then
          st__32 = 56
        elseif st__32 == 54 then
          return true
        elseif st__32 == 50 then
          if stp__30 > 0 and ctr__31 <= lim__29 or stp__30 <= 0 and ctr__31 >= lim__29 then
            st__32 = 41
          else
            st__32 = 54
          end
        elseif st__32 == 41 then
          i__17 = ctr__31

          if n__16 % i__17 == 0 then
            st__32 = 31
          else
            st__32 = 63
          end
        elseif st__32 == 69 then
          ctr__31 = ctr__31 + stp__30
          st__32 = 50
        elseif st__32 == 34 then
          return false
        elseif st__32 == 56 then
          ctr__31, lim__29, stp__30 = 2, math.floor(math.sqrt(n__16)), 1
          st__32 = 50
        elseif st__32 == 63 then
          st__32 = 69
        end
      end
    end

    kTKCssUWEUD__18 = function(list__19, separator__20)
      local NYWCLrMd__21, index__22, lim__25, stp__26, ctr__27
      local st__28 = 28

      while true do
        if st__28 == 21 then
          return table.concat(NYWCLrMd__21, separator__20)
        elseif st__28 == 25 then
          if stp__26 > 0 and ctr__27 <= lim__25 or stp__26 <= 0 and ctr__27 >= lim__25 then
            st__28 = 16
          else
            st__28 = 21
          end
        elseif st__28 == 16 then
          index__22 = ctr__27
          NYWCLrMd__21[#NYWCLrMd__21 + 1] = kBqgHeoxN__2(list__19[index__22])
          ctr__27 = ctr__27 + stp__26
          st__28 = 25
        elseif st__28 == 28 then
          NYWCLrMd__21 = {}
          ctr__27, lim__25, stp__26 = 1, #list__19, 1
          st__28 = 25
        end
      end
    end

    hJNplAqzvFk__23 = {}
    ctr__35, lim__33, stp__34 = 1, 50, 1
    st__36 = 39
  elseif st__36 == 48 then
    hJNplAqzvFk__23[#hJNplAqzvFk__23 + 1] = candidate__24
    st__36 = 25
  elseif st__36 == 18 then
    aFaUPSvCbjP__1((RiIMpmwuXKdq__7[-648 + 760]
      .. RiIMpmwuXKdq__7[-812 + 926]
      .. RiIMpmwuXKdq__7[744 - (639)]
      .. RiIMpmwuXKdq__7[383 - (274)]
      .. RiIMpmwuXKdq__7[185 - (84)]
      .. RiIMpmwuXKdq__7[815 - (700)]
      .. RiIMpmwuXKdq__7[949 - (891)]
      .. RiIMpmwuXKdq__7[-883 + 915]) .. kTKCssUWEUD__18(hJNplAqzvFk__23, (RiIMpmwuXKdq__7[-150 + 194])))

    aFaUPSvCbjP__1((RiIMpmwuXKdq__7[-729 + 832]
      .. RiIMpmwuXKdq__7[-759 + 858]
      .. RiIMpmwuXKdq__7[273 - (173)]
      .. RiIMpmwuXKdq__7[844 - (804)]
      .. RiIMpmwuXKdq__7[-153 + 209]
      .. RiIMpmwuXKdq__7[312 - (260)]
      .. RiIMpmwuXKdq__7[-933 + 977]
      .. RiIMpmwuXKdq__7[-519 + 551]
      .. RiIMpmwuXKdq__7[242 - (191)]
      .. RiIMpmwuXKdq__7[292 - (238)]
      .. RiIMpmwuXKdq__7[108 - (67)]
      .. RiIMpmwuXKdq__7[-839 + 871]
      .. RiIMpmwuXKdq__7[923 - (862)]
      .. RiIMpmwuXKdq__7[-708 + 740]) .. EsnOMKYiuPD__12(84, 36))

    aFaUPSvCbjP__1((RiIMpmwuXKdq__7[-505 + 604]
      .. RiIMpmwuXKdq__7[-284 + 392]
      .. RiIMpmwuXKdq__7[-379 + 476]
      .. RiIMpmwuXKdq__7[257 - (148)]
      .. RiIMpmwuXKdq__7[-197 + 309]
      .. RiIMpmwuXKdq__7[764 - (706)]
      .. RiIMpmwuXKdq__7[733 - (701)]) .. sceZGBGluIkn__8(15, 0, 10) .. (RiIMpmwuXKdq__7[-782 + 814]) .. sceZGBGluIkn__8(-3, 0, 10) .. (RiIMpmwuXKdq__7[-349 + 381]) .. sceZGBGluIkn__8(7, 0, 10))

    aFaUPSvCbjP__1(string.format((RiIMpmwuXKdq__7[791 - (754)]
      .. RiIMpmwuXKdq__7[319 - (266)]
      .. RiIMpmwuXKdq__7[-682 + 728]
      .. RiIMpmwuXKdq__7[-410 + 460]
      .. RiIMpmwuXKdq__7[-407 + 509]
      .. RiIMpmwuXKdq__7[-242 + 366]
      .. RiIMpmwuXKdq__7[-753 + 790]
      .. RiIMpmwuXKdq__7[-432 + 477]
      .. RiIMpmwuXKdq__7[-866 + 920]
      .. RiIMpmwuXKdq__7[313 - (198)]
      .. RiIMpmwuXKdq__7[839 - (715)]
      .. RiIMpmwuXKdq__7[223 - (186)]
      .. RiIMpmwuXKdq__7[929 - (881)]
      .. RiIMpmwuXKdq__7[248 - (197)]
      .. RiIMpmwuXKdq__7[120 - (20)]), 3.14159, (RiIMpmwuXKdq__7[624 - (527)] .. RiIMpmwuXKdq__7[928 - (830)]), 7))

    break
  elseif st__36 == 39 then
    if stp__34 > 0 and ctr__35 <= lim__33 or stp__34 <= 0 and ctr__35 >= lim__33 then
      st__36 = 30
    else
      st__36 = 18
    end
  elseif st__36 == 30 then
    candidate__24 = ctr__35

    if BeQUwPMJTUz__15(candidate__24) then
      st__36 = 48
    else
      st__36 = 17
    end
  elseif st__36 == 25 then
    ctr__35 = ctr__35 + stp__34
    st__36 = 39
  elseif st__36 == 17 then
    st__36 = 25
  end
end
