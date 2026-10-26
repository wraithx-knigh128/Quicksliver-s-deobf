return (function(...)
  local lOl1Il = {
    "R\142", "\164\152\149\153\175", "\165\152\160\154\153\171", "\155\151\160\154", "\168\152\162\153\155\155",
    "\162\148\173\158\164\158", "\155\151\160\154", "\149\162\157\163", "\155\151\160\154", "\162\148\173\158\164\158",
    "\149\162\157\163", "\162\148\173\158\164\158", "\164\152\149\153\175", "\155\151\160\154",
    "\164\152\154\170\164\155", "\149\162\157\163", "\149\162\157\163", "\149\162\157\163", "\165\152\160\154\153\171",
    "\149\162\157\163", "\164\152\154\170\164\155", "\149\162\157\163", "\149\162\157\163", "\149\162\157\163",
    "\149\162\157\163", "\165\152\160\154\153\171", "\165\152\160\154\153\171",
  }

  local function ll1OI0(lIO1IO)
    local ll0O01 = lOl1Il[lIO1IO - 2903]
    local l001OO = {}

    for llI010 = 1, #ll0O01 do
      l001OO[llI010] = string.char((ll0O01:byte(llI010) - 49 - llI010) % 256)
    end

    return table.concat(l001OO)
  end

  local l0OO1O, l0OI0O = 6, 30

  local function lOlllO(lI1lOI, l1OI1l)
    local l1l00I, ll0III = 31, 26
    return lI1lOI == l1OI1l
  end

  local function l0IlII(l0O00O, l100IO)
    local llO1O0, lOI011 = 34, 30
    return l0O00O + l100IO
  end

  local function l001lO(l010lI, lO11OI)
    local lllll0, lI010O = 11, 11
    return l010lI <= lO11OI
  end

  local function l1O101(lIOl0I, lOOll0)
    local lO1l01, l00IIl = 11, 21
    return lIOl0I .. lOOll0
  end

  local function ll0ll1(lIlll1, lIIOl1)
    local llOlOl, llIII1 = 22, 6
    return lIlll1 - lIIOl1
  end

  local function l11l0O()
    local l0I0OO, lOO11O = 38, 34
    return 1
  end

  local function llIOO0()
    local l1lIII, l00l1I = 37, 15
    return 0
  end

  local function lIl01O()
    local l110ll, llll1l = 30, 6
    return 2
  end

  local function lII0lI()
    local lll11I, lI0O0l
    local lOOI10 = 28

    while true do
      if lOOI10 <= 32 then
        if lOOI10 <= 28 then
          lll11I, lI0O0l = 9, 10

          if lll11I * lll11I < 0 then
            lOOI10 = lOOI10 + 22
          else
            lOOI10 = lOOI10 + 4
          end
        else
          lOOI10 = lOOI10 + 9
        end
      else
        if lOOI10 <= 41 then
          return 3
        else
          g__301 = 5
          lOOI10 = lOOI10 + -9
        end
      end
    end
  end

  local function l1I00O()
    local lIOll1, l01IIl = 7, 22
    return 4
  end

  local function l0I0O0()
    local lll0I1, ll00I1 = 15, 19
    return 100
  end

  -- Small simulations: a cellular automaton, a bank, a vending state machine.
  local function lI1O11(lIOOII, lO1Il0)
    local l1000I, l1ll00, llII10, l00I11, lO1II0, lI1l00, ll0111, lllIOI, lIlOlI, l11001, l1Ol00, lOIllO, llO0I0, l1lIOl, lO01OO, lII100, lIlIll, lll0O0, llO00O, lO0lI1, ll1O1O, lO1O0l, lIO1Ol, lIOOll, llOIO0, lOI01l, l0IOI0, lI10ll
    local l1Ol0O = 92

    while true do
      if l1Ol0O <= 82 then
        if l1Ol0O <= 56 then
          if l1Ol0O <= 42 then
            if l1Ol0O <= 33 then
              if l1Ol0O <= 32 then
                if lII100 > 0 and lIlIll <= lO01OO or lII100 <= 0 and lIlIll >= lO01OO then
                  l1Ol0O = l1Ol0O + 26
                else
                  l1Ol0O = l1Ol0O + 106
                end
              else
                lIlOlI[l11001][l1lIOl] = lOlllO(lll0O0, lII0lI()) and l11l0O() or 0
                l1Ol0O = l1Ol0O + 12
              end
            else
              if l1Ol0O <= 39 then
                if lIOOII[l11001][l1lIOl] == 1 then
                  l1Ol0O = l1Ol0O + 80
                else
                  l1Ol0O = l1Ol0O + -6
                end
              else
                if llOIO0 > 0 and lOI01l <= lIOOll or llOIO0 <= 0 and lOI01l >= lIOOll then
                  l1Ol0O = l1Ol0O + 37
                else
                  l1Ol0O = l1Ol0O + 60
                end
              end
            end
          else
            if l1Ol0O <= 49 then
              if l1Ol0O <= 45 then
                lIlIll = lIlIll + lII100
                l1Ol0O = l1Ol0O + -13
              else
                l1Ol0O = l1Ol0O + 29
              end
            else
              l1Ol0O = l1Ol0O + 22
            end
          end
        else
          if l1Ol0O <= 71 then
            if l1Ol0O <= 62 then
              if l1Ol0O <= 58 then
                l1lIOl = lIlIll
                lll0O0 = llIOO0()
                lO1O0l, lO0lI1, ll1O1O = -l11l0O(), 1, 1
                l1Ol0O = l1Ol0O + 84
              else
                l11001 = llO0I0
                lIlOlI[l11001] = {}
                lIlIll, lO01OO, lII100 = l11l0O(), l00I11, 1
                l1Ol0O = l1Ol0O + -30
              end
            else
              lll0O0 = lll0O0 + 1
              l1Ol0O = l1Ol0O + -15
            end
          else
            if l1Ol0O <= 79 then
              if l1Ol0O <= 78 then
                lOI01l = lOI01l + llOIO0
                l1Ol0O = l1Ol0O + -36
              else
                lIO1Ol = lOI01l

                if not (lOlllO(llO00O, 0) and lOlllO(lIO1Ol, 0)) then
                  l1Ol0O = l1Ol0O + 31
                else
                  l1Ol0O = l1Ol0O + -30
                end
              end
            else
              if ll0111 > 0 and lllIOI <= lI1l00 or ll0111 <= 0 and lllIOI >= lI1l00 then
                l1Ol0O = l1Ol0O + 45
              else
                l1Ol0O = l1Ol0O + 61
              end
            end
          end
        end
      else
        if l1Ol0O <= 110 then
          if l1Ol0O <= 93 then
            if l1Ol0O <= 92 then
              if l1Ol0O <= 85 then
                if lOIllO > 0 and llO0I0 <= l1Ol00 or lOIllO <= 0 and llO0I0 >= l1Ol00 then
                  l1Ol0O = l1Ol0O + -23
                else
                  l1Ol0O = l1Ol0O + 8
                end
              else
                l1000I, l1ll00 = 13, 6
                llII10, l00I11 = #lIOOII, #lIOOII[1]
                lllIOI, lI1l00, ll0111 = l11l0O(), lO1Il0, 1
                l1Ol0O = l1Ol0O + -10
              end
            else
              lIOOII = lIlOlI
              lllIOI = lllIOI + ll0111
              l1Ol0O = l1Ol0O + -11
            end
          else
            if l1Ol0O <= 107 then
              if l1Ol0O <= 102 then
                lO1O0l = lO1O0l + ll1O1O
                l1Ol0O = l1Ol0O + 40
              else
                l1Ol0O = l1Ol0O + -51
              end
            else
              l0IOI0, lI10ll = l0IlII(l11001, llO00O), l0IlII(l1lIOl, lIO1Ol)

              if l0IOI0 >= 1
                and l0IOI0 <= llII10
                and lI10ll >= 1
                and l001lO(lI10ll, l00I11)
                and lOlllO(lIOOII[l0IOI0][lI10ll], 1) then
                l1Ol0O = l1Ol0O + -39
              else
                l1Ol0O = l1Ol0O + -3
              end
            end
          end
        else
          if l1Ol0O <= 132 then
            if l1Ol0O <= 127 then
              if l1Ol0O <= 119 then
                lIlOlI[l11001][l1lIOl] = (lOlllO(lll0O0, lIl01O()) or lOlllO(lll0O0, 3)) and l11l0O() or llIOO0()
                l1Ol0O = l1Ol0O + -74
              else
                lO1II0 = lllIOI
                lIlOlI = {}
                llO0I0, l1Ol00, lOIllO = l11l0O(), llII10, 1
                l1Ol0O = l1Ol0O + -42
              end
            else
              llO00O = lO1O0l
              lOI01l, lIOOll, llOIO0 = -1, 1, 1
              l1Ol0O = l1Ol0O + -90
            end
          else
            if l1Ol0O <= 142 then
              if l1Ol0O <= 138 then
                llO0I0 = llO0I0 + lOIllO
                l1Ol0O = l1Ol0O + -53
              else
                if ll1O1O > 0 and lO1O0l <= lO0lI1 or ll1O1O <= 0 and lO1O0l >= lO0lI1 then
                  l1Ol0O = l1Ol0O + -10
                else
                  l1Ol0O = l1Ol0O + -103
                end
              end
            else
              return lIOOII
            end
          end
        end
      end
    end
  end

  local function l0II00(l1IlO0)
    local l0O1O1, lO0OlI, ll11I0, l1Olll, llIl1l, l01OOI, l1OlOO, lll1Ol, l01I00, l0OII1, l1111l, l0l1Ol
    local lIlOIl = 57

    while true do
      if lIlOIl <= 39 then
        if lIlOIl <= 26 then
          if lIlOIl <= 24 then
            return table.concat(ll11I0, "/")
          else
            l1Olll = l1OlOO
            lll1Ol = {}
            l0l1Ol, l0OII1, l1111l = 1, #l1IlO0[l1Olll], 1
            lIlOIl = lIlOIl + 5
          end
        else
          if lIlOIl <= 31 then
            if l1111l > 0 and l0l1Ol <= l0OII1 or l1111l <= 0 and l0l1Ol >= l0OII1 then
              lIlOIl = lIlOIl + 17
            else
              lIlOIl = lIlOIl + 15
            end
          else
            if l01OOI > 0 and l1OlOO <= llIl1l or l01OOI <= 0 and l1OlOO >= llIl1l then
              lIlOIl = lIlOIl + -13
            else
              lIlOIl = lIlOIl + -15
            end
          end
        end
      else
        if lIlOIl <= 48 then
          if lIlOIl <= 46 then
            ll11I0[l1Olll] = table.concat(lll1Ol)
            l1OlOO = l1OlOO + l01OOI
            lIlOIl = lIlOIl + -7
          else
            l01I00 = l0l1Ol
            lll1Ol[l01I00] = lOlllO(l1IlO0[l1Olll][l01I00], 1) and "#" or "."
            l0l1Ol = l0l1Ol + l1111l
            lIlOIl = lIlOIl + -17
          end
        else
          l0O1O1, lO0OlI = 4, 7
          ll11I0 = {}
          l1OlOO, llIl1l, l01OOI = 1, #l1IlO0, 1
          lIlOIl = lIlOIl + -18
        end
      end
    end
  end

  local function llll11(lI0l0O)
    local l0l1ll, lI1I11, l1I0l0, lOI0O0
    local l1OOOI = 55

    while true do
      if l1OOOI <= 55 then
        if l1OOOI <= 41 then
          if l1OOOI <= 35 then
            g__313 = 5
            l1OOOI = l1OOOI + 6
          else
            return lOI0O0
          end
        else
          if l1OOOI <= 46 then
            lOI0O0 = {}

            function lOI0O0.deposit(l01Il1)
              local l0Olll, lI0110
              local lO0lO0 = 32

              while true do
                if lO0lO0 <= 25 then
                  if lO0lO0 <= 16 then
                    lI0l0O = l0IlII(lI0l0O, l01Il1)
                    lO0lO0 = lO0lO0 + 24
                  else
                    g__316 = 4
                    lO0lO0 = lO0lO0 + 15
                  end
                else
                  if lO0lO0 <= 32 then
                    l0Olll, lI0110 = 11, 9

                    if lI0110 == lI0110 then
                      lO0lO0 = lO0lO0 + -16
                    else
                      lO0lO0 = lO0lO0 + -7
                    end
                  else
                    l1I0l0[l0IlII(#l1I0l0, 1)] = "+" .. l01Il1
                    break
                  end
                end
              end
            end

            function lOI0O0.withdraw(l1IOO0)
              local lO00I1, llIlOO
              local lOI0IO = 18

              while true do
                if lOI0IO <= 23 then
                  if lOI0IO <= 18 then
                    if lOI0IO <= 15 then
                      g__319 = 8
                      lOI0IO = lOI0IO + 26
                    else
                      lO00I1, llIlOO = 36, 3

                      if lO00I1 * (lO00I1 + 1) % 2 ~= 0 then
                        lOI0IO = lOI0IO + -3
                      else
                        lOI0IO = lOI0IO + 12
                      end
                    end
                  else
                    if lOI0IO <= 19 then
                      l1I0l0[l0IlII(#l1I0l0, l11l0O())] = l1O101("!", l1IOO0)
                      return false
                    else
                      lOI0IO = lOI0IO + 15
                    end
                  end
                else
                  if lOI0IO <= 38 then
                    if lOI0IO <= 30 then
                      lOI0IO = lOI0IO + 11
                    else
                      lI0l0O = ll0ll1(lI0l0O, l1IOO0)
                      l1I0l0[l0IlII(#l1I0l0, l11l0O())] = "-" .. l1IOO0
                      return true
                    end
                  else
                    if l1IOO0 > lI0l0O then
                      lOI0IO = lOI0IO + -22
                    else
                      lOI0IO = lOI0IO + -18
                    end
                  end
                end
              end
            end

            function lOI0O0.report()
              local lO1lOl, lIIOIl = 32, 39
              return l1O101(lI0l0O, ll1OI0(2904) .. l1O101(table.concat(l1I0l0, ","), "]"))
            end

            if l0l1ll * (l0l1ll + 1) % 2 ~= 0 then
              l1OOOI = l1OOOI + -11
            else
              l1OOOI = l1OOOI + 21
            end
          else
            l0l1ll, lI1I11 = 19, 7
            l1I0l0 = {}

            if l0l1ll * l0l1ll % 4 == 2 then
              l1OOOI = l1OOOI + 6
            else
              l1OOOI = l1OOOI + 16
            end
          end
        end
      else
        if l1OOOI <= 67 then
          if l1OOOI <= 61 then
            g__312 = 4
            l1OOOI = l1OOOI + -15
          else
            l1OOOI = l1OOOI + -26
          end
        else
          l1OOOI = l1OOOI + -25
        end
      end
    end
  end

  local function ll01I1(lOIl0O)
    local llOl10, lOI1O0, ll11Il, l1lI01, lOOOl1, lOO11l, lOOIOO, ll0IIl, l0l000, l11lO0
    local lOOIII = 79

    while true do
      if lOOIII <= 86 then
        if lOOIII <= 68 then
          if lOOIII <= 56 then
            if lOOIII <= 40 then
              if lOOIII <= 37 then
                if lOlllO(ll11Il, ll1OI0(2905)) then
                  lOOIII = lOOIII + 3
                else
                  lOOIII = lOOIII + 69
                end
              else
                if lOlllO(l11lO0, ll1OI0(2906)) then
                  lOOIII = lOOIII + 27
                else
                  lOOIII = lOOIII + 22
                end
              end
            else
              if lOOIII <= 47 then
                return table.concat(lOOOl1, " ")
              else
                l1lI01 = 0
                ll11Il = ll1OI0(2907)
                lOOIII = lOOIII + 58
              end
            end
          else
            if lOOIII <= 67 then
              if lOOIII <= 62 then
                lOOIII = lOOIII + 24
              else
                lOOOl1[l0IlII(#lOOOl1, 1)] = ll1OI0(2908)
                l1lI01 = ll0ll1(l1lI01, 3)
                ll11Il = l1lI01 > 0 and ll1OI0(2909) or ll1OI0(2910)
                lOOIII = lOOIII + 19
              end
            else
              lOOIII = lOOIII + 23
            end
          end
        else
          if lOOIII <= 79 then
            if lOOIII <= 76 then
              if lOOIII <= 74 then
                if lOlllO(l11lO0, ll1OI0(2911)) then
                  lOOIII = lOOIII + 24
                else
                  lOOIII = lOOIII + 33
                end
              else
                l1lI01 = l0IlII(l1lI01, 1)

                if l1lI01 >= 3 then
                  lOOIII = lOOIII + 45
                else
                  lOOIII = lOOIII + 17
                end
              end
            else
              llOl10, lOI1O0 = 33, 27
              ll11Il, l1lI01, lOOOl1 = ll1OI0(2912), 0, {}
              lOO11l, lOOIOO, ll0IIl = ipairs(lOIl0O)
              lOOIII = lOOIII + 15
            end
          else
            if lOOIII <= 82 then
              if lOOIII <= 81 then
                if lOlllO(ll11Il, ll1OI0(2913)) then
                  lOOIII = lOOIII + 8
                else
                  lOOIII = lOOIII + -44
                end
              else
                lOOIII = lOOIII + 32
              end
            else
              lOOIII = lOOIII + 5
            end
          end
        end
      else
        if lOOIII <= 102 then
          if lOOIII <= 93 then
            if lOOIII <= 91 then
              if lOOIII <= 89 then
                if lOlllO(l11lO0, ll1OI0(2914)) then
                  lOOIII = lOOIII + -13
                else
                  lOOIII = lOOIII + 45
                end
              else
                lOOOl1[l0IlII(#lOOOl1, 1)] = l1O101(ll11Il, l1O101(":", l1lI01))
                lOOIII = lOOIII + 3
              end
            else
              lOOIII = lOOIII + 9
            end
          else
            if lOOIII <= 98 then
              if lOOIII <= 94 then
                l0l000, l11lO0 = lOO11l(lOOIOO, ll0IIl)

                if l0l000 ~= nil then
                  lOOIII = lOOIII + 34
                else
                  lOOIII = lOOIII + -47
                end
              else
                l1lI01 = l0IlII(l1lI01, l11l0O())
                ll11Il = ll1OI0(2915)
                lOOIII = lOOIII + -30
              end
            else
              lOOIII = lOOIII + 12
            end
          end
        else
          if lOOIII <= 114 then
            if lOOIII <= 107 then
              if lOOIII <= 106 then
                lOOIII = lOOIII + -15
              else
                lOOIII = lOOIII + -39
              end
            else
              lOOIII = lOOIII + -23
            end
          else
            if lOOIII <= 128 then
              if lOOIII <= 121 then
                ll11Il = ll1OI0(2916)
                lOOIII = lOOIII + -19
              else
                ll0IIl = l0l000

                if lOlllO(ll11Il, ll1OI0(2917)) then
                  lOOIII = lOOIII + -54
                else
                  lOOIII = lOOIII + -47
                end
              end
            else
              if lOlllO(l11lO0, ll1OI0(2918)) then
                lOOIII = lOOIII + -78
              else
                lOOIII = lOOIII + -52
              end
            end
          end
        end
      end
    end
  end

  local l1Ill0 = {
    { 0, l11l0O(), llIOO0(), 0, 0 },
    { 0, 0, l11l0O(), llIOO0(), 0 },
    { 1, 1, 1, 0, 0 },
    { llIOO0(), 0, 0, 0, 0 },
    { 0, llIOO0(), llIOO0(), 0, 0 },
  }

  print(l0II00(lI1O11(l1Ill0, l1I00O())))
  local lOOl0l = llll11(l0I0O0())
  lOOl0l.deposit(50)

  if (l0OI0O * l0OI0O + l0OI0O) % 2 == 0 then
    print(lOOl0l.withdraw(500), lOOl0l.withdraw(30))
  else
    local lOOOl0 = 17
  end

  if l0OO1O * (l0OO1O + 1) % 2 == 0 then
    print(lOOl0l.report())
  else
    local lIOOOI = 8
  end

  if (l0OO1O * l0OO1O + l0OO1O) % 2 == 0 then
    print(ll01I1({
      ll1OI0(2919),
      ll1OI0(2920),
      ll1OI0(2921),
      ll1OI0(2922),
      ll1OI0(2923),
      ll1OI0(2924),
      ll1OI0(2925),
      ll1OI0(2926),
      ll1OI0(2927),
      ll1OI0(2928),
      ll1OI0(2929),
      ll1OI0(2930),
    }))
  else
    local l10110 = 50
  end
end)(
  ...
)
