-- Small simulations: a cellular automaton, a bank, a vending state machine.
local function life__129(grid__130, generations__131)
  local rows__132, cols__133, ___134, lim__177, stp__178, ctr__179, nextGrid__135, r__136, lim__180, stp__181, ctr__182, c__137, lim__183, stp__184, ctr__185, alive__138, dr__139, lim__186, stp__187, ctr__188, dc__140, lim__189, stp__190, ctr__191, rr__141, cc__142
  local st__192 = 81

  while st__192 ~= 1 do
    if st__192 == 137 then
      st__192 = (stp__184 > 0 and ctr__185 <= lim__183 or stp__184 <= 0 and ctr__185 >= lim__183) and 127 or 151
    end

    if st__192 == 76 then
      return grid__130
    end

    if st__192 == 128 then
      grid__130 = nextGrid__135
      ctr__179 = ctr__179 + stp__178
      st__192 = 94
    end

    if st__192 == 47 then
      dc__140 = ctr__191
      st__192 = not (dr__139 == 0 and dc__140 == 0) and 36 or 111
    end

    if st__192 == 111 then
      st__192 = 118
    end

    if st__192 == 149 then
      alive__138 = alive__138 + 1
      st__192 = 142
    end

    if st__192 == 105 then
      dr__139 = ctr__188
      ctr__191, lim__189, stp__190 = -1, 1, 1
      st__192 = 75
    end

    if st__192 == 75 then
      st__192 = (stp__190 > 0 and ctr__191 <= lim__189 or stp__190 <= 0 and ctr__191 >= lim__189) and 47 or 72
    end

    if st__192 == 86 then
      st__192 = (stp__181 > 0 and ctr__182 <= lim__180 or stp__181 <= 0 and ctr__182 >= lim__180) and 109 or 128
    end

    if st__192 == 72 then
      ctr__188 = ctr__188 + stp__187
      st__192 = 132
    end

    if st__192 == 118 then
      ctr__191 = ctr__191 + stp__190
      st__192 = 75
    end

    if st__192 == 63 then
      nextGrid__135[r__136][c__137] = (alive__138 == 2 or alive__138 == 3) and 1 or 0
      st__192 = 40
    end

    if st__192 == 40 then
      ctr__185 = ctr__185 + stp__184
      st__192 = 137
    end

    if st__192 == 151 then
      ctr__182 = ctr__182 + stp__181
      st__192 = 86
    end

    if st__192 == 142 then
      st__192 = 118
    end

    if st__192 == 94 then
      st__192 = (stp__178 > 0 and ctr__179 <= lim__177 or stp__178 <= 0 and ctr__179 >= lim__177) and 148 or 76
    end

    if st__192 == 153 then
      st__192 = grid__130[r__136][c__137] == 1 and 63 or 55
    end

    if st__192 == 55 then
      nextGrid__135[r__136][c__137] = alive__138 == 3 and 1 or 0
      st__192 = 40
    end

    if st__192 == 81 then
      rows__132, cols__133 = #grid__130, #grid__130[1]
      ctr__179, lim__177, stp__178 = 1, generations__131, 1
      st__192 = 94
    end

    if st__192 == 101 then
      st__192 = 142
    end

    if st__192 == 109 then
      r__136 = ctr__182
      nextGrid__135[r__136] = {}
      ctr__185, lim__183, stp__184 = 1, cols__133, 1
      st__192 = 137
    end

    if st__192 == 132 then
      st__192 = (stp__187 > 0 and ctr__188 <= lim__186 or stp__187 <= 0 and ctr__188 >= lim__186) and 105 or 153
    end

    if st__192 == 148 then
      ___134 = ctr__179
      nextGrid__135 = {}
      ctr__182, lim__180, stp__181 = 1, rows__132, 1
      st__192 = 86
    end

    if st__192 == 127 then
      c__137 = ctr__185
      alive__138 = 0
      ctr__188, lim__186, stp__187 = -1, 1, 1
      st__192 = 132
    end

    if st__192 == 36 then
      rr__141, cc__142 = r__136 + dr__139, c__137 + dc__140

      st__192 = rr__141 >= 1
        and rr__141 <= rows__132
        and cc__142 >= 1
        and cc__142 <= cols__133
        and grid__130[rr__141][cc__142] == 1
        and 149 or 101
    end
  end
end

local function render__143(grid__144)
  local lines__145, r__146, lim__170, stp__171, ctr__172, row__147, c__148, lim__173, stp__174, ctr__175
  local st__176 = 61

  while st__176 ~= 1 do
    if st__176 == 37 then
      return table.concat(lines__145, "/")
    end

    if st__176 == 61 then
      lines__145 = {}
      ctr__172, lim__170, stp__171 = 1, #grid__144, 1
      st__176 = 56
    end

    if st__176 == 56 then
      st__176 = (stp__171 > 0 and ctr__172 <= lim__170 or stp__171 <= 0 and ctr__172 >= lim__170) and 38 or 37
    end

    if st__176 == 38 then
      r__146 = ctr__172
      row__147 = {}
      ctr__175, lim__173, stp__174 = 1, #grid__144[r__146], 1
      st__176 = 44
    end

    if st__176 == 53 then
      lines__145[r__146] = table.concat(row__147)
      ctr__172 = ctr__172 + stp__171
      st__176 = 56
    end

    if st__176 == 31 then
      c__148 = ctr__175
      row__147[c__148] = grid__144[r__146][c__148] == 1 and "#" or "."
      ctr__175 = ctr__175 + stp__174
      st__176 = 44
    end

    if st__176 == 44 then
      st__176 = (stp__174 > 0 and ctr__175 <= lim__173 or stp__174 <= 0 and ctr__175 >= lim__173) and 31 or 53
    end
  end
end

local function makeAccount__149(balance__150)
  local history__151, self__152
  local st__169 = 22

  while st__169 ~= 1 do
    if st__169 == 22 then
      history__151 = {}
      self__152 = {}

      function self__152.deposit(n__153)
        balance__150 = balance__150 + n__153
        history__151[#history__151 + 1] = "+" .. n__153
      end

      function self__152.withdraw(n__154)
        local st__168 = 33

        while st__168 ~= 1 do
          if st__168 == 39 then
            st__168 = 51
          end

          if st__168 == 43 then
            history__151[#history__151 + 1] = "!" .. n__154
            return false
          end

          if st__168 == 51 then
            balance__150 = balance__150 - n__154
            history__151[#history__151 + 1] = "-" .. n__154
            return true
          end

          if st__168 == 33 then
            st__168 = n__154 > balance__150 and 43 or 39
          end
        end
      end

      function self__152.report()
        return balance__150 .. " [" .. table.concat(history__151, ",") .. "]"
      end

      return self__152
    end
  end
end

local function vend__155(events__156)
  local state__157, credit__158, log__159, it__164, st__165, ct__166, ___160, e__161
  local st__167 = 70

  while st__167 ~= 1 do
    if st__167 == 43 then
      log__159[#log__159 + 1] = state__157 .. ":" .. credit__158
      st__167 = 90
    end

    if st__167 == 127 then
      st__167 = e__161 == "select" and 77 or 84
    end

    if st__167 == 99 then
      st__167 = 43
    end

    if st__167 == 26 then
      st__167 = state__157 == "ready" and 127 or 136
    end

    if st__167 == 70 then
      state__157, credit__158, log__159 = "idle", 0, {}
      it__164, st__165, ct__166 = ipairs(events__156)
      st__167 = 90
    end

    if st__167 == 126 then
      st__167 = e__161 == "coin" and 134 or 118
    end

    if st__167 == 53 then
      st__167 = state__157 == "paying" and 103 or 26
    end

    if st__167 == 132 then
      st__167 = 138
    end

    if st__167 == 50 then
      credit__158 = credit__158 + 1
      st__167 = credit__158 >= 3 and 29 or 110
    end

    if st__167 == 64 then
      st__167 = 43
    end

    if st__167 == 90 then
      ___160, e__161 = it__164(st__165, ct__166)
      st__167 = ___160 ~= nil and 129 or 56
    end

    if st__167 == 136 then
      st__167 = 43
    end

    if st__167 == 118 then
      st__167 = 64
    end

    if st__167 == 120 then
      st__167 = e__161 == "refund" and 38 or 60
    end

    if st__167 == 38 then
      credit__158 = 0
      state__157 = "idle"
      st__167 = 138
    end

    if st__167 == 60 then
      st__167 = 138
    end

    if st__167 == 103 then
      st__167 = e__161 == "coin" and 50 or 120
    end

    if st__167 == 138 then
      st__167 = 43
    end

    if st__167 == 110 then
      st__167 = 132
    end

    if st__167 == 56 then
      return table.concat(log__159, " ")
    end

    if st__167 == 29 then
      state__157 = "ready"
      st__167 = 132
    end

    if st__167 == 134 then
      credit__158 = credit__158 + 1
      state__157 = "paying"
      st__167 = 64
    end

    if st__167 == 129 then
      ct__166 = ___160
      st__167 = state__157 == "idle" and 126 or 53
    end

    if st__167 == 84 then
      st__167 = 99
    end

    if st__167 == 77 then
      log__159[#log__159 + 1] = "vended"
      credit__158 = credit__158 - 3
      state__157 = credit__158 > 0 and "paying" or "idle"
      st__167 = 99
    end
  end
end

local glider__162 = { { 0, 1, 0, 0, 0 }, { 0, 0, 1, 0, 0 }, { 1, 1, 1, 0, 0 }, { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } }
print(render__143(life__129(glider__162, 4)))
local acct__163 = makeAccount__149(100)
acct__163.deposit(50)
print(acct__163.withdraw(500), acct__163.withdraw(30))
print(acct__163.report())

print(vend__155({
  "coin", "coin", "coin", "select", "coin", "refund", "coin", "coin", "coin", "coin", "select", "select",
}))
