local q__266, q__267 = 4, 29

local function P__195(a, b)
  local q__210, q__211 = 30, 5

  if q__210 * (q__210 + 1) % 2 ~= 0 then
    g__212 = 7
  end

  return a == b
end

if q__267 * q__267 < 0 then
  g__268 = 4
end

local function Q__196(a, b)
  local q__213, q__214 = 5, 24
  return P__195(a, b)
end

local function P__197(a, b)
  local q__215, q__216 = 31, 5
  return a + b
end

local function Q__198(a, b)
  local q__217, q__218 = 36, 6
  return P__197(a, b)
end

local function P__199(a, b)
  local q__219, q__220 = 15, 29

  if q__220 * q__220 < 0 then
    g__221 = 6
  end

  return a <= b
end

local function Q__200(a, b)
  local q__222, q__223 = 39, 3

  if q__223 * (q__223 + 1) % 2 ~= 0 then
    g__224 = 3
  end

  return P__199(a, b)
end

local function P__201(a, b)
  local q__225, q__226 = 10, 19
  return a .. b
end

local function Q__202(a, b)
  local q__227, q__228 = 29, 30
  return P__201(a, b)
end

local function P__203(a, b)
  local q__229, q__230 = 26, 10

  if q__230 * q__230 < 0 then
    g__231 = 7
  end

  return a - b
end

local function Q__204(a, b)
  local q__232, q__233 = 26, 4
  return P__203(a, b)
end

local function K__205()
  local q__234, q__235 = 28, 29
  return 1
end

local function K__206()
  local q__236, q__237 = 22, 29
  return 3
end

local function K__207()
  local q__238, q__239 = 18, 35
  return 0
end

local function K__208()
  local q__240, q__241 = 38, 18

  if q__241 ~= q__241 then
    g__242 = 2
  end

  return 4
end

local function K__209()
  local q__243, q__244 = 21, 28
  return 50
end

-- Small simulations: a cellular automaton, a bank, a vending state machine.
local function life(grid, generations)
  local q__245, q__246 = 15, 37
  local rows, cols = #grid, #grid[1]

  if q__245 * q__245 % 4 == 2 then
    g__247 = 1
  end

  for _ = 1, generations do
    local nextGrid = {}

    for r = 1, rows do
      nextGrid[r] = {}

      for c = 1, cols do
        local alive = 0

        for dr = -1, 1 do
          for dc = -1, K__205() do
            if not (Q__196(dr, 0) and Q__196(dc, 0)) then
              local rr, cc = Q__198(r, dr), Q__198(c, dc)

              if rr >= 1 and Q__200(rr, rows) and cc >= 1 and Q__200(cc, cols) and Q__196(grid[rr][cc], 1) then
                alive = alive + 1
              end
            end
          end
        end

        if Q__196(grid[r][c], K__205()) then
          nextGrid[r][c] = (Q__196(alive, 2) or Q__196(alive, 3)) and K__205() or 0
        else
          nextGrid[r][c] = Q__196(alive, K__206()) and 1 or K__207()
        end
      end
    end

    grid = nextGrid
  end

  return grid
end

local function render(grid)
  local q__248, q__249 = 33, 28
  local lines = {}

  for r = 1, #grid do
    local row = {}

    for c = 1, #grid[r] do
      row[c] = grid[r][c] == 1 and "#" or "."
    end

    lines[r] = table.concat(row)
  end

  return table.concat(lines, "/")
end

local function makeAccount(balance)
  local q__250, q__251 = 38, 19
  local history = {}
  local self = {}

  if q__250 ~= q__250 then
    g__252 = 8
  end

  function self.deposit(n)
    local q__253, q__254 = 33, 22

    if q__254 * q__254 % 4 == 2 then
      g__255 = 1
    end

    balance = Q__198(balance, n)

    if q__253 * (q__253 + 1) % 2 == 0 then
      history[Q__198(#history, 1)] = Q__202("+", n)
    else
      g__256 = 9
    end
  end

  function self.withdraw(n)
    local q__257, q__258 = 21, 4

    if q__257 * q__257 < 0 then
      g__259 = 5
    end

    if n > balance then
      history[Q__198(#history, 1)] = Q__202("!", n)
      return false
    end

    if (7 * q__257 + 1) % 7 == 1 then
      balance = Q__204(balance, n)
    else
      g__260 = 8
    end

    if q__257 * q__257 >= 0 then
      history[#history + K__205()] = Q__202("-", n)
    else
      g__261 = 5
    end

    return true
  end

  function self.report()
    local q__262, q__263 = 16, 31
    return Q__202(balance, Q__202(" [", table.concat(history, ",") .. "]"))
  end

  return self
end

local function vend(events)
  local q__264, q__265 = 9, 17
  local state, credit, log = "idle", K__207(), {}

  for _, e in ipairs(events) do
    if Q__196(state, "idle") then
      if Q__196(e, "coin") then
        credit = Q__198(credit, 1)
        state = "paying"
      end
    elseif Q__196(state, "paying") then
      if Q__196(e, "coin") then
        credit = Q__198(credit, 1)

        if credit >= 3 then
          state = "ready"
        end
      elseif Q__196(e, "refund") then
        credit = K__207()
        state = "idle"
      end
    elseif state == "ready" then
      if Q__196(e, "select") then
        log[Q__198(#log, 1)] = "vended"
        credit = Q__204(credit, K__206())
        state = credit > 0 and "paying" or "idle"
      end
    end

    log[Q__198(#log, K__205())] = Q__202(state, Q__202(":", credit))
  end

  return table.concat(log, " ")
end

local glider = {
  { 0, 1, K__207(), 0, 0 },
  { 0, 0, K__205(), 0, 0 },
  { 1, 1, K__205(), 0, K__207() },
  { 0, K__207(), K__207(), 0, K__207() },
  { 0, 0, 0, 0, 0 },
}

print(render(life(glider, K__208())))
local acct = makeAccount(100)

if q__267 * (q__267 + 1) % 2 == 0 then
  acct.deposit(K__209())
else
  local j__269 = 27
end

if (7 * q__267 + 1) % 7 == 1 then
  print(acct.withdraw(500), acct.withdraw(30))
else
  local j__270 = 80
end

print(acct.report())

if q__267 * (q__267 + 1) % 2 == 0 then
  print(
    vend({ "coin", "coin", "coin", "select", "coin", "refund", "coin", "coin", "coin", "coin", "select", "select" })
  )
else
  local j__271 = 43
end
