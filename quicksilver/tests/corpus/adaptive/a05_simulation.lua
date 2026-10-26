-- Small simulations: a cellular automaton, a bank, a vending state machine.
local function life(grid, generations)
  local rows, cols = #grid, #grid[1]
  for _ = 1, generations do
    local nextGrid = {}
    for r = 1, rows do
      nextGrid[r] = {}
      for c = 1, cols do
        local alive = 0
        for dr = -1, 1 do
          for dc = -1, 1 do
            if not (dr == 0 and dc == 0) then
              local rr, cc = r + dr, c + dc
              if rr >= 1 and rr <= rows and cc >= 1 and cc <= cols and grid[rr][cc] == 1 then alive = alive + 1 end
            end
          end
        end
        if grid[r][c] == 1 then
          nextGrid[r][c] = (alive == 2 or alive == 3) and 1 or 0
        else
          nextGrid[r][c] = alive == 3 and 1 or 0
        end
      end
    end
    grid = nextGrid
  end
  return grid
end

local function render(grid)
  local lines = {}
  for r = 1, #grid do
    local row = {}
    for c = 1, #grid[r] do row[c] = grid[r][c] == 1 and "#" or "." end
    lines[r] = table.concat(row)
  end
  return table.concat(lines, "/")
end

local function makeAccount(balance)
  local history = {}
  local self = {}
  function self.deposit(n)
    balance = balance + n
    history[#history + 1] = "+" .. n
  end
  function self.withdraw(n)
    if n > balance then
      history[#history + 1] = "!" .. n
      return false
    end
    balance = balance - n
    history[#history + 1] = "-" .. n
    return true
  end
  function self.report() return balance .. " [" .. table.concat(history, ",") .. "]" end
  return self
end

local function vend(events)
  local state, credit, log = "idle", 0, {}
  for _, e in ipairs(events) do
    if state == "idle" then
      if e == "coin" then credit = credit + 1; state = "paying" end
    elseif state == "paying" then
      if e == "coin" then
        credit = credit + 1
        if credit >= 3 then state = "ready" end
      elseif e == "refund" then
        credit = 0
        state = "idle"
      end
    elseif state == "ready" then
      if e == "select" then
        log[#log + 1] = "vended"
        credit = credit - 3
        state = credit > 0 and "paying" or "idle"
      end
    end
    log[#log + 1] = state .. ":" .. credit
  end
  return table.concat(log, " ")
end

local glider = { { 0, 1, 0, 0, 0 }, { 0, 0, 1, 0, 0 }, { 1, 1, 1, 0, 0 }, { 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 } }
print(render(life(glider, 4)))
local acct = makeAccount(100)
acct.deposit(50)
print(acct.withdraw(500), acct.withdraw(30))
print(acct.report())
print(vend({ "coin", "coin", "coin", "select", "coin", "refund", "coin", "coin", "coin", "coin", "select", "select" }))
