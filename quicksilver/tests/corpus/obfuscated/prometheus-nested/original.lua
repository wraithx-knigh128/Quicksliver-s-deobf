-- Nested loops that leave early, a search that returns from inside two loops, closures over loop state, and a key check shaped like a
-- hub's: the code a flattening obfuscator has to keep the structure of.
local function findPair(grid, target)
  for r = 1, #grid do
    local row = grid[r]
    for c = 1, #row do
      if row[c] == target then
        return r, c
      end
    end
  end
  return nil
end

local function tally(words)
  local counts, order = {}, {}
  for _, w in ipairs(words) do
    for i = 1, #w do
      local ch = w:sub(i, i)
      if ch == "x" then break end
      if not counts[ch] then counts[ch] = 0; order[#order + 1] = ch end
      counts[ch] = counts[ch] + 1
    end
  end
  table.sort(order)
  local parts = {}
  for _, ch in ipairs(order) do parts[#parts + 1] = ch .. "=" .. counts[ch] end
  return table.concat(parts, ",")
end

local function makeChecker(valid)
  local attempts = 0
  local function check(key)
    attempts = attempts + 1
    if type(key) ~= "string" or #key == 0 then return false, "Invalid key format!" end
    for i = 1, #valid do
      if valid[i] == key then return true, "Key valid" end
    end
    if attempts >= 3 then return false, "Too many attempts" end
    return false, "Key is incorrect or deleted!"
  end
  return check
end

local grid = { { 3, 1, 4 }, { 1, 5, 9 }, { 2, 6, 5 } }
print(findPair(grid, 9))
local missing = findPair(grid, 7)
print(missing)
print(tally({ "apple", "banana", "xylophone", "cherry" }))
local check = makeChecker({ "alpha", "beta" })
for _, k in ipairs({ "", "zeta", "beta", "gamma", "alpha" }) do
  local ok, msg = check(k)
  print(k == "" and "<empty>" or k, ok, msg)
end
local total, n = 0, 0
while true do
  n = n + 1
  if n % 2 == 0 then
    total = total + n
  elseif n > 9 then
    break
  end
end
print("total", total, n)
