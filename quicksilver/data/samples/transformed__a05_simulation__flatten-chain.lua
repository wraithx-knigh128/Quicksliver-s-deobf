-- Small simulations: a cellular automaton, a bank, a vending state machine.
local function life__1(grid__2, generations__3)
  local rows__4, cols__5, ___6, lim__49, stp__50, ctr__51, nextGrid__7, r__8, lim__52, stp__53, ctr__54, c__9, lim__55, stp__56, ctr__57, alive__10, dr__11, lim__58, stp__59, ctr__60, dc__12, lim__61, stp__62, ctr__63, rr__13, cc__14
  local st__64 = 116

  while st__64 ~= 1 do
    if st__64 == 125 then
      rr__13, cc__14 = r__8 + dr__11, c__9 + dc__12

      if rr__13 >= 1 and rr__13 <= rows__4 and cc__14 >= 1 and cc__14 <= cols__5 and grid__2[rr__13][cc__14] == 1 then
        st__64 = 63
      else
        st__64 = 81
      end
    elseif st__64 == 107 then
      ctr__54 = ctr__54 + stp__53
      st__64 = 30
    elseif st__64 == 39 then
      nextGrid__7[r__8][c__9] = alive__10 == 3 and 1 or 0
      st__64 = 55
    elseif st__64 == 28 then
      nextGrid__7[r__8][c__9] = (alive__10 == 2 or alive__10 == 3) and 1 or 0
      st__64 = 55
    elseif st__64 == 128 then
      dc__12 = ctr__63

      if not (dr__11 == 0 and dc__12 == 0) then
        st__64 = 125
      else
        st__64 = 86
      end
    elseif st__64 == 136 then
      if stp__62 > 0 and ctr__63 <= lim__61 or stp__62 <= 0 and ctr__63 >= lim__61 then
        st__64 = 128
      else
        st__64 = 53
      end
    elseif st__64 == 27 then
      ctr__63 = ctr__63 + stp__62
      st__64 = 136
    elseif st__64 == 137 then
      if stp__59 > 0 and ctr__60 <= lim__58 or stp__59 <= 0 and ctr__60 >= lim__58 then
        st__64 = 75
      else
        st__64 = 61
      end
    elseif st__64 == 30 then
      if stp__53 > 0 and ctr__54 <= lim__52 or stp__53 <= 0 and ctr__54 >= lim__52 then
        st__64 = 23
      else
        st__64 = 46
      end
    elseif st__64 == 81 then
      st__64 = 146
    elseif st__64 == 46 then
      grid__2 = nextGrid__7
      ctr__51 = ctr__51 + stp__50
      st__64 = 32
    elseif st__64 == 99 then
      if stp__56 > 0 and ctr__57 <= lim__55 or stp__56 <= 0 and ctr__57 >= lim__55 then
        st__64 = 147
      else
        st__64 = 107
      end
    elseif st__64 == 67 then
      ___6 = ctr__51
      nextGrid__7 = {}
      ctr__54, lim__52, stp__53 = 1, rows__4, 1
      st__64 = 30
    elseif st__64 == 146 then
      st__64 = 27
    elseif st__64 == 55 then
      ctr__57 = ctr__57 + stp__56
      st__64 = 99
    elseif st__64 == 23 then
      r__8 = ctr__54
      nextGrid__7[r__8] = {}
      ctr__57, lim__55, stp__56 = 1, cols__5, 1
      st__64 = 99
    elseif st__64 == 63 then
      alive__10 = alive__10 + 1
      st__64 = 146
    elseif st__64 == 116 then
      rows__4, cols__5 = #grid__2, #grid__2[1]
      ctr__51, lim__49, stp__50 = 1, generations__3, 1
      st__64 = 32
    elseif st__64 == 61 then
      if grid__2[r__8][c__9] == 1 then
        st__64 = 28
      else
        st__64 = 39
      end
    elseif st__64 == 32 then
      if stp__50 > 0 and ctr__51 <= lim__49 or stp__50 <= 0 and ctr__51 >= lim__49 then
        st__64 = 67
      else
        st__64 = 93
      end
    elseif st__64 == 86 then
      st__64 = 27
    elseif st__64 == 93 then
      return grid__2
    elseif st__64 == 147 then
      c__9 = ctr__57
      alive__10 = 0
      ctr__60, lim__58, stp__59 = -1, 1, 1
      st__64 = 137
    elseif st__64 == 75 then
      dr__11 = ctr__60
      ctr__63, lim__61, stp__62 = -1, 1, 1
      st__64 = 136
    elseif st__64 == 53 then
      ctr__60 = ctr__60 + stp__59
      st__64 = 137
    end
  end
end

local function render__15(grid__16)
  local lines__17, r__18, lim__42, stp__43, ctr__44, row__19, c__20, lim__45, stp__46, ctr__47
  local st__48 = 62

  while st__48 ~= 1 do
    if st__48 == 38 then
      lines__17[r__18] = table.concat(row__19)
      ctr__44 = ctr__44 + stp__43
      st__48 = 39
    elseif st__48 == 62 then
      lines__17 = {}
      ctr__44, lim__42, stp__43 = 1, #grid__16, 1
      st__48 = 39
    elseif st__48 == 46 then
      c__20 = ctr__47
      row__19[c__20] = grid__16[r__18][c__20] == 1 and "#" or "."
      ctr__47 = ctr__47 + stp__46
      st__48 = 45
    elseif st__48 == 45 then
      if stp__46 > 0 and ctr__47 <= lim__45 or stp__46 <= 0 and ctr__47 >= lim__45 then
        st__48 = 46
      else
        st__48 = 38
      end
    elseif st__48 == 54 then
      r__18 = ctr__44
      row__19 = {}
      ctr__47, lim__45, stp__46 = 1, #grid__16[r__18], 1
      st__48 = 45
    elseif st__48 == 39 then
      if stp__43 > 0 and ctr__44 <= lim__42 or stp__43 <= 0 and ctr__44 >= lim__42 then
        st__48 = 54
      else
        st__48 = 35
      end
    elseif st__48 == 35 then
      return table.concat(lines__17, "/")
    end
  end
end

local function makeAccount__21(balance__22)
  local history__23, self__24
  local st__41 = 15

  while st__41 ~= 1 do
    if st__41 == 15 then
      history__23 = {}
      self__24 = {}

      function self__24.deposit(n__25)
        balance__22 = balance__22 + n__25
        history__23[#history__23 + 1] = "+" .. n__25
      end

      function self__24.withdraw(n__26)
        local st__40 = 32

        while st__40 ~= 1 do
          if st__40 == 32 then
            if n__26 > balance__22 then
              st__40 = 27
            else
              st__40 = 23
            end
          elseif st__40 == 28 then
            balance__22 = balance__22 - n__26
            history__23[#history__23 + 1] = "-" .. n__26
            return true
          elseif st__40 == 23 then
            st__40 = 28
          elseif st__40 == 27 then
            history__23[#history__23 + 1] = "!" .. n__26
            return false
          end
        end
      end

      function self__24.report()
        return balance__22 .. " [" .. table.concat(history__23, ",") .. "]"
      end

      return self__24
    end
  end
end

local function vend__27(events__28)
  local state__29, credit__30, log__31, it__36, st__37, ct__38, ___32, e__33
  local st__39 = 30

  while st__39 ~= 1 do
    if st__39 == 38 then
      credit__30 = credit__30 + 1

      if credit__30 >= 3 then
        st__39 = 114
      else
        st__39 = 153
      end
    elseif st__39 == 43 then
      st__39 = 90
    elseif st__39 == 96 then
      st__39 = 57
    elseif st__39 == 105 then
      st__39 = 90
    elseif st__39 == 118 then
      credit__30 = credit__30 + 1
      state__29 = "paying"
      st__39 = 128
    elseif st__39 == 67 then
      st__39 = 128
    elseif st__39 == 143 then
      if e__33 == "coin" then
        st__39 = 118
      else
        st__39 = 67
      end
    elseif st__39 == 62 then
      if e__33 == "select" then
        st__39 = 49
      else
        st__39 = 146
      end
    elseif st__39 == 90 then
      log__31[#log__31 + 1] = state__29 .. ":" .. credit__30
      st__39 = 74
    elseif st__39 == 134 then
      st__39 = 57
    elseif st__39 == 30 then
      state__29, credit__30, log__31 = "idle", 0, {}
      it__36, st__37, ct__38 = ipairs(events__28)
      st__39 = 74
    elseif st__39 == 42 then
      if state__29 == "paying" then
        st__39 = 69
      else
        st__39 = 23
      end
    elseif st__39 == 83 then
      return table.concat(log__31, " ")
    elseif st__39 == 69 then
      if e__33 == "coin" then
        st__39 = 38
      else
        st__39 = 24
      end
    elseif st__39 == 119 then
      credit__30 = 0
      state__29 = "idle"
      st__39 = 57
    elseif st__39 == 128 then
      st__39 = 90
    elseif st__39 == 74 then
      ___32, e__33 = it__36(st__37, ct__38)

      if ___32 ~= nil then
        st__39 = 155
      else
        st__39 = 83
      end
    elseif st__39 == 24 then
      if e__33 == "refund" then
        st__39 = 119
      else
        st__39 = 134
      end
    elseif st__39 == 114 then
      state__29 = "ready"
      st__39 = 96
    elseif st__39 == 49 then
      log__31[#log__31 + 1] = "vended"
      credit__30 = credit__30 - 3
      state__29 = credit__30 > 0 and "paying" or "idle"
      st__39 = 105
    elseif st__39 == 155 then
      ct__38 = ___32

      if state__29 == "idle" then
        st__39 = 143
      else
        st__39 = 42
      end
    elseif st__39 == 146 then
      st__39 = 105
    elseif st__39 == 153 then
      st__39 = 96
    elseif st__39 == 57 then
      st__39 = 90
    elseif st__39 == 23 then
      if state__29 == "ready" then
        st__39 = 62
      else
        st__39 = 43
      end
    end
  end
end

local glider__34 = { { 0, 1, 0, 0, 0 }, { 0, 0, 1, 0, 0 }, { 1, 1, 1, 0, 0 }, { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } }
print(render__15(life__1(glider__34, 4)))
local acct__35 = makeAccount__21(100)
acct__35.deposit(50)
print(acct__35.withdraw(500), acct__35.withdraw(30))
print(acct__35.report())

print(vend__27({
  "coin", "coin", "coin", "select", "coin", "refund", "coin", "coin", "coin", "coin", "select", "select",
}))
