-- Small simulations: a cellular automaton, a bank, a vending state machine.
local function life__65(grid__66, generations__67)
  local rows__68, cols__69, ___70, lim__113, stp__114, ctr__115, nextGrid__71, r__72, lim__116, stp__117, ctr__118, c__73, lim__119, stp__120, ctr__121, alive__74, dr__75, lim__122, stp__123, ctr__124, dc__76, lim__125, stp__126, ctr__127, rr__77, cc__78
  local st__128 = 35

  while true do
    if st__128 <= 93 then
      if st__128 <= 64 then
        if st__128 <= 43 then
          if st__128 <= 35 then
            if st__128 <= 34 then
              if stp__123 > 0 and ctr__124 <= lim__122 or stp__123 <= 0 and ctr__124 >= lim__122 then
                st__128 = st__128 + 59
              else
                st__128 = st__128 + 54
              end
            else
              rows__68, cols__69 = #grid__66, #grid__66[1]
              ctr__115, lim__113, stp__114 = 1, generations__67, 1
              st__128 = st__128 + 108
            end
          else
            if st__128 <= 38 then
              nextGrid__71[r__72][c__73] = alive__74 == 3 and 1 or 0
              st__128 = st__128 + 78
            else
              nextGrid__71[r__72][c__73] = (alive__74 == 2 or alive__74 == 3) and 1 or 0
              st__128 = st__128 + 73
            end
          end
        else
          if st__128 <= 58 then
            if st__128 <= 51 then
              st__128 = st__128 + 69
            else
              grid__66 = nextGrid__71
              ctr__115 = ctr__115 + stp__114
              st__128 = st__128 + 85
            end
          else
            r__72 = ctr__118
            nextGrid__71[r__72] = {}
            ctr__121, lim__119, stp__120 = 1, cols__69, 1
            st__128 = st__128 + 8
          end
        end
      else
        if st__128 <= 76 then
          if st__128 <= 72 then
            if st__128 <= 66 then
              rr__77, cc__78 = r__72 + dr__75, c__73 + dc__76

              if rr__77 >= 1
                and rr__77 <= rows__68
                and cc__78 >= 1
                and cc__78 <= cols__69
                and grid__66[rr__77][cc__78] == 1 then
                st__128 = st__128 + 82
              else
                st__128 = st__128 + 78
              end
            else
              if stp__120 > 0 and ctr__121 <= lim__119 or stp__120 <= 0 and ctr__121 >= lim__119 then
                st__128 = st__128 + 36
              else
                st__128 = st__128 + 58
              end
            end
          else
            return grid__66
          end
        else
          if st__128 <= 88 then
            if st__128 <= 81 then
              ctr__124 = ctr__124 + stp__123
              st__128 = st__128 + -47
            else
              if grid__66[r__72][c__73] == 1 then
                st__128 = st__128 + -45
              else
                st__128 = st__128 + -50
              end
            end
          else
            dr__75 = ctr__124
            ctr__127, lim__125, stp__126 = -1, 1, 1
            st__128 = st__128 + 36
          end
        end
      end
    else
      if st__128 <= 129 then
        if st__128 <= 116 then
          if st__128 <= 108 then
            if st__128 <= 101 then
              if stp__117 > 0 and ctr__118 <= lim__116 or stp__117 <= 0 and ctr__118 >= lim__116 then
                st__128 = st__128 + -37
              else
                st__128 = st__128 + -43
              end
            else
              c__73 = ctr__121
              alive__74 = 0
              ctr__124, lim__122, stp__123 = -1, 1, 1
              st__128 = st__128 + -74
            end
          else
            ctr__121 = ctr__121 + stp__120
            st__128 = st__128 + -44
          end
        else
          if st__128 <= 120 then
            if st__128 <= 117 then
              st__128 = st__128 + 3
            else
              ctr__127 = ctr__127 + stp__126
              st__128 = st__128 + 9
            end
          else
            if stp__126 > 0 and ctr__127 <= lim__125 or stp__126 <= 0 and ctr__127 >= lim__125 then
              st__128 = st__128 + 18
            else
              st__128 = st__128 + -48
            end
          end
        end
      else
        if st__128 <= 143 then
          if st__128 <= 137 then
            if st__128 <= 130 then
              ctr__118 = ctr__118 + stp__117
              st__128 = st__128 + -29
            else
              ___70 = ctr__115
              nextGrid__71 = {}
              ctr__118, lim__116, stp__117 = 1, rows__68, 1
              st__128 = st__128 + -36
            end
          else
            if stp__114 > 0 and ctr__115 <= lim__113 or stp__114 <= 0 and ctr__115 >= lim__113 then
              st__128 = st__128 + -6
            else
              st__128 = st__128 + -67
            end
          end
        else
          if st__128 <= 147 then
            if st__128 <= 144 then
              st__128 = st__128 + -93
            else
              dc__76 = ctr__127

              if not (dr__75 == 0 and dc__76 == 0) then
                st__128 = st__128 + -81
              else
                st__128 = st__128 + -30
              end
            end
          else
            alive__74 = alive__74 + 1
            st__128 = st__128 + -97
          end
        end
      end
    end
  end
end

local function render__79(grid__80)
  local lines__81, r__82, lim__106, stp__107, ctr__108, row__83, c__84, lim__109, stp__110, ctr__111
  local st__112 = 58

  while true do
    if st__112 <= 40 then
      if st__112 <= 32 then
        if st__112 <= 25 then
          c__84 = ctr__111
          row__83[c__84] = grid__80[r__82][c__84] == 1 and "#" or "."
          ctr__111 = ctr__111 + stp__110
          st__112 = st__112 + 24
        else
          if stp__107 > 0 and ctr__108 <= lim__106 or stp__107 <= 0 and ctr__108 >= lim__106 then
            st__112 = st__112 + 2
          else
            st__112 = st__112 + 8
          end
        end
      else
        if st__112 <= 34 then
          r__82 = ctr__108
          row__83 = {}
          ctr__111, lim__109, stp__110 = 1, #grid__80[r__82], 1
          st__112 = st__112 + 15
        else
          return table.concat(lines__81, "/")
        end
      end
    else
      if st__112 <= 56 then
        if st__112 <= 49 then
          if stp__110 > 0 and ctr__111 <= lim__109 or stp__110 <= 0 and ctr__111 >= lim__109 then
            st__112 = st__112 + -24
          else
            st__112 = st__112 + 7
          end
        else
          lines__81[r__82] = table.concat(row__83)
          ctr__108 = ctr__108 + stp__107
          st__112 = st__112 + -24
        end
      else
        lines__81 = {}
        ctr__108, lim__106, stp__107 = 1, #grid__80, 1
        st__112 = st__112 + -26
      end
    end
  end
end

local function makeAccount__85(balance__86)
  local history__87, self__88
  local st__105 = 38

  while true do
    history__87 = {}
    self__88 = {}

    function self__88.deposit(n__89)
      balance__86 = balance__86 + n__89
      history__87[#history__87 + 1] = "+" .. n__89
    end

    function self__88.withdraw(n__90)
      local st__104 = 39

      while true do
        if st__104 <= 38 then
          if st__104 <= 32 then
            balance__86 = balance__86 - n__90
            history__87[#history__87 + 1] = "-" .. n__90
            return true
          else
            st__104 = st__104 + -6
          end
        else
          if st__104 <= 39 then
            if n__90 > balance__86 then
              st__104 = st__104 + 3
            else
              st__104 = st__104 + -1
            end
          else
            history__87[#history__87 + 1] = "!" .. n__90
            return false
          end
        end
      end
    end

    function self__88.report()
      return balance__86 .. " [" .. table.concat(history__87, ",") .. "]"
    end

    return self__88
  end
end

local function vend__91(events__92)
  local state__93, credit__94, log__95, it__100, st__101, ct__102, ___96, e__97
  local st__103 = 56

  while true do
    if st__103 <= 65 then
      if st__103 <= 47 then
        if st__103 <= 29 then
          if st__103 <= 20 then
            if st__103 <= 19 then
              st__103 = st__103 + 16
            else
              if state__93 == "paying" then
                st__103 = st__103 + 31
              else
                st__103 = st__103 + 1
              end
            end
          else
            if st__103 <= 21 then
              if state__93 == "ready" then
                st__103 = st__103 + 64
              else
                st__103 = st__103 + 51
              end
            else
              state__93 = "ready"
              st__103 = st__103 + -10
            end
          end
        else
          if st__103 <= 39 then
            if st__103 <= 35 then
              st__103 = st__103 + 70
            else
              credit__94 = 0
              state__93 = "idle"
              st__103 = st__103 + -4
            end
          else
            st__103 = st__103 + 58
          end
        end
      else
        if st__103 <= 54 then
          if st__103 <= 52 then
            if st__103 <= 51 then
              if e__97 == "coin" then
                st__103 = st__103 + 3
              else
                st__103 = st__103 + 67
              end
            else
              return table.concat(log__95, " ")
            end
          else
            credit__94 = credit__94 + 1

            if credit__94 >= 3 then
              st__103 = st__103 + -25
            else
              st__103 = st__103 + 73
            end
          end
        else
          if st__103 <= 60 then
            if st__103 <= 56 then
              state__93, credit__94, log__95 = "idle", 0, {}
              it__100, st__101, ct__102 = ipairs(events__92)
              st__103 = st__103 + 61
            else
              st__103 = st__103 + 46
            end
          else
            if e__97 == "coin" then
              st__103 = st__103 + 48
            else
              st__103 = st__103 + 33
            end
          end
        end
      end
    else
      if st__103 <= 105 then
        if st__103 <= 85 then
          if st__103 <= 78 then
            if st__103 <= 72 then
              st__103 = st__103 + 33
            else
              st__103 = st__103 + -43
            end
          else
            if e__97 == "select" then
              st__103 = st__103 + 8
            else
              st__103 = st__103 + -25
            end
          end
        else
          if st__103 <= 98 then
            if st__103 <= 93 then
              log__95[#log__95 + 1] = "vended"
              credit__94 = credit__94 - 3
              state__93 = credit__94 > 0 and "paying" or "idle"
              st__103 = st__103 + 13
            else
              st__103 = st__103 + -51
            end
          else
            log__95[#log__95 + 1] = state__93 .. ":" .. credit__94
            st__103 = st__103 + 12
          end
        end
      else
        if st__103 <= 117 then
          if st__103 <= 113 then
            if st__103 <= 106 then
              st__103 = st__103 + -1
            else
              credit__94 = credit__94 + 1
              state__93 = "paying"
              st__103 = st__103 + -66
            end
          else
            ___96, e__97 = it__100(st__101, ct__102)

            if ___96 ~= nil then
              st__103 = st__103 + 16
            else
              st__103 = st__103 + -65
            end
          end
        else
          if st__103 <= 127 then
            if st__103 <= 118 then
              if e__97 == "refund" then
                st__103 = st__103 + -79
              else
                st__103 = st__103 + -40
              end
            else
              st__103 = st__103 + -108
            end
          else
            ct__102 = ___96

            if state__93 == "idle" then
              st__103 = st__103 + -68
            else
              st__103 = st__103 + -113
            end
          end
        end
      end
    end
  end
end

local glider__98 = { { 0, 1, 0, 0, 0 }, { 0, 0, 1, 0, 0 }, { 1, 1, 1, 0, 0 }, { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } }
print(render__79(life__65(glider__98, 4)))
local acct__99 = makeAccount__85(100)
acct__99.deposit(50)
print(acct__99.withdraw(500), acct__99.withdraw(30))
print(acct__99.report())

print(vend__91({
  "coin", "coin", "coin", "select", "coin", "refund", "coin", "coin", "coin", "coin", "select", "select",
}))
