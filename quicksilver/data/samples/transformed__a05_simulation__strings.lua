local E__193 = {
  "Q\141", "\154\150\159\153", "\154\150\159\153", "\148\161\156\162", "\161\147\172\157\163\157",
  "\161\147\172\157\163\157", "\148\161\156\162", "\163\151\148\152\174", "\163\151\153\169\163\154",
  "\154\150\159\153", "\163\151\148\152\174", "\164\151\159\153\152\170", "\167\151\161\152\154\154",
  "\161\147\172\157\163\157", "\154\150\159\153", "\148\161\156\162", "\148\161\156\162", "\148\161\156\162",
  "\164\151\159\153\152\170", "\148\161\156\162", "\163\151\153\169\163\154", "\148\161\156\162", "\148\161\156\162",
  "\148\161\156\162", "\148\161\156\162", "\164\151\159\153\152\170", "\164\151\159\153\152\170",
}

local function D__194(i)
  local s = E__193[i - 3528]
  local r = {}

  for j = 1, #s do
    r[j] = string.char((s:byte(j) - 48 - j) % 256)
  end

  return table.concat(r)
end

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

              if rr >= 1 and rr <= rows and cc >= 1 and cc <= cols and grid[rr][cc] == 1 then
                alive = alive + 1
              end
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

    for c = 1, #grid[r] do
      row[c] = grid[r][c] == 1 and "#" or "."
    end

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

  function self.report()
    return balance .. D__194(3529) .. table.concat(history, ",") .. "]"
  end

  return self
end

local function vend(events)
  local state, credit, log = D__194(3530), 0, {}

  for _, e in ipairs(events) do
    if state == D__194(3531) then
      if e == D__194(3532) then
        credit = credit + 1
        state = D__194(3533)
      end
    elseif state == D__194(3534) then
      if e == D__194(3535) then
        credit = credit + 1

        if credit >= 3 then
          state = D__194(3536)
        end
      elseif e == D__194(3537) then
        credit = 0
        state = D__194(3538)
      end
    elseif state == D__194(3539) then
      if e == D__194(3540) then
        log[#log + 1] = D__194(3541)
        credit = credit - 3
        state = credit > 0 and D__194(3542) or D__194(3543)
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

print(vend({
  D__194(3544),
  D__194(3545),
  D__194(3546),
  D__194(3547),
  D__194(3548),
  D__194(3549),
  D__194(3550),
  D__194(3551),
  D__194(3552),
  D__194(3553),
  D__194(3554),
  D__194(3555),
}))
