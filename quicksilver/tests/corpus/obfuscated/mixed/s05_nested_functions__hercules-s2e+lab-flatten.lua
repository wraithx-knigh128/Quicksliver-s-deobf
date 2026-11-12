local sFZCWmeMEMA__1, WLbHMHaLlCo__2, GwwvtKifUz__3, ZrsMuoExE__4, pWPHtMkbefw__5, arxeLGbw__6, qOmzIkWfY__7, qgHeoxNvGdV__8, MJTUzZhJN__12, VKxEhRvx__17, YiuPDRkTKCss__19, aseKUYDLryX__23, rZJAmQStUA__29, kkvbJDTux__32, AqzvFkqNYWC__34, dBJvsljrNOVk__36, EUDsceZG__39
local st__54 = 19

while true do
  if st__54 == 19 then
    sFZCWmeMEMA__1, WLbHMHaLlCo__2, GwwvtKifUz__3, ZrsMuoExE__4, pWPHtMkbefw__5, arxeLGbw__6 = nil, nil, nil, nil, nil, nil
    sFZCWmeMEMA__1 = ipairs
    WLbHMHaLlCo__2 = next
    GwwvtKifUz__3 = pairs
    ZrsMuoExE__4 = print
    pWPHtMkbefw__5 = select
    arxeLGbw__6 = table.concat
    qOmzIkWfY__7 = { [35] = "#", [44] = "," }

    qgHeoxNvGdV__8 = function(start__9, step__10)
      local dBmxztBeQUwP__11 = start__9

      return function()
        dBmxztBeQUwP__11 = dBmxztBeQUwP__11 + step__10
        return dBmxztBeQUwP__11
      end
    end

    MJTUzZhJN__12 = function(fn__13)
      local TdQozaFilxdG__14 = {}

      return function(n__15)
        local wuXKdqnZaFaU__16
        local st__53 = 41

        while true do
          if st__53 == 49 then
            st__53 = 33
          elseif st__53 == 41 then
            wuXKdqnZaFaU__16 = TdQozaFilxdG__14[n__15]

            if wuXKdqnZaFaU__16 == nil then
              st__53 = 32
            else
              st__53 = 49
            end
          elseif st__53 == 32 then
            wuXKdqnZaFaU__16 = fn__13(n__15)
            TdQozaFilxdG__14[n__15] = wuXKdqnZaFaU__16
            st__53 = 33
          elseif st__53 == 33 then
            return wuXKdqnZaFaU__16
          end
        end
      end
    end

    VKxEhRvx__17 = nil

    VKxEhRvx__17 = MJTUzZhJN__12(function(n__18)
      if n__18 < 2 then
        return n__18
      end

      return VKxEhRvx__17(n__18 - 1) + VKxEhRvx__17(n__18 - 2)
    end)

    YiuPDRkTKCss__19 = function(...)
      local SvCbjPoXk__20 = { ... }

      return function(x__21)
        for i__22 = #SvCbjPoXk__20, 1, -1 do
          x__21 = SvCbjPoXk__20[i__22](x__21)
        end

        return x__21
      end
    end

    aseKUYDLryX__23 = function(list__24, fn__25)
      local CsQTDZOTyu__26, it__49, st__50, ct__51, i__27, v__28
      local st__52 = 39

      while true do
        if st__52 == 31 then
          ct__51 = i__27
          CsQTDZOTyu__26[i__27] = fn__25(v__28, i__27)
          st__52 = 41
        elseif st__52 == 34 then
          return CsQTDZOTyu__26
        elseif st__52 == 41 then
          i__27, v__28 = it__49(st__50, ct__51)

          if i__27 ~= nil then
            st__52 = 31
          else
            st__52 = 34
          end
        elseif st__52 == 39 then
          CsQTDZOTyu__26 = {}
          it__49, st__50, ct__51 = sFZCWmeMEMA__1(list__24)
          st__52 = 41
        end
      end
    end

    rZJAmQStUA__29 = function(...)
      local tNkAzoZHB__30, i__31, lim__45, stp__46, ctr__47
      local st__48 = 28

      while true do
        if st__48 == 21 then
          return tNkAzoZHB__30
        elseif st__48 == 25 then
          if stp__46 > 0 and ctr__47 <= lim__45 or stp__46 <= 0 and ctr__47 >= lim__45 then
            st__48 = 16
          else
            st__48 = 21
          end
        elseif st__48 == 16 then
          i__31 = ctr__47
          tNkAzoZHB__30 = tNkAzoZHB__30 + (pWPHtMkbefw__5(i__31, ...))
          ctr__47 = ctr__47 + stp__46
          st__48 = 25
        elseif st__48 == 28 then
          tNkAzoZHB__30 = 0
          ctr__47, lim__45, stp__46 = 1, pWPHtMkbefw__5((qOmzIkWfY__7[-725 + 760]), ...), 1
          st__48 = 25
        end
      end
    end

    kkvbJDTux__32 = qgHeoxNvGdV__8(10, 5)
    ZrsMuoExE__4(kkvbJDTux__32(), kkvbJDTux__32(), kkvbJDTux__32())
    ZrsMuoExE__4(VKxEhRvx__17(30), VKxEhRvx__17(40))

    AqzvFkqNYWC__34 = function(x__33)
      return x__33 + 1
    end

    dBJvsljrNOVk__36 = function(x__35)
      return x__35 * 2
    end

    ZrsMuoExE__4(
      YiuPDRkTKCss__19(AqzvFkqNYWC__34, dBJvsljrNOVk__36)(5),
      YiuPDRkTKCss__19(dBJvsljrNOVk__36, AqzvFkqNYWC__34)(5)
    )

    ZrsMuoExE__4(table.concat(aseKUYDLryX__23({ 1, 2, 3, 4 }, function(v__37, i__38)
      return v__37 * i__38
    end), (qOmzIkWfY__7[-882 + 926])))

    ZrsMuoExE__4(rZJAmQStUA__29(1, 2, 3, 4, 5), rZJAmQStUA__29())

    EUDsceZG__39 = function(a__40)
      local function GluIknwRiIM__41(b__42)
        local function MdREsnOMK__43(c__44)
          return a__40 * 100 + b__42 * 10 + c__44
        end

        return MdREsnOMK__43
      end

      return GluIknwRiIM__41
    end

    ZrsMuoExE__4(EUDsceZG__39(1)(2)(3))
    break
  end
end
