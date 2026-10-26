-- Closures, varargs, error handling, metatables.
local function counter(start, step)
  local n = start
  return function()
    n = n + step
    return n
  end
end

local function sum(...)
  local total = 0
  for i = 1, select("#", ...) do
    total = total + (select(i, ...))
  end
  return total
end

local function map(list, fn)
  local out = {}
  for i, v in ipairs(list) do out[i] = fn(v, i) end
  return out
end

local function safeDivide(a, b)
  local ok, result = pcall(function()
    if b == 0 then error("division by zero") end
    return a / b
  end)
  if ok then return result end
  return "error: " .. tostring(result):gsub("^.-:%d+: ", "")
end

local Vec = {}
Vec.__index = Vec
Vec.__add = function(a, b) return setmetatable({ x = a.x + b.x, y = a.y + b.y }, Vec) end
Vec.__tostring = function(v) return "(" .. v.x .. "," .. v.y .. ")" end
local function vec(x, y) return setmetatable({ x = x, y = y }, Vec) end

local c1, c2 = counter(0, 2), counter(100, -5)
print(c1(), c1(), c1(), c2(), c2())
print(sum(1, 2, 3, 4, 5), sum(), sum(10))
print(table.concat(map({ 3, 1, 4, 1, 5 }, function(v, i) return v * i end), " "))
print(safeDivide(10, 4), safeDivide(1, 0))
print(tostring(vec(1, 2) + vec(10, 20)))
local words = { "pear", "apple", "fig", "banana" }
table.sort(words, function(a, b) return #a < #b or (#a == #b and a < b) end)
print(table.concat(words, ","))
local acc = {}
for i = 1, 5 do
  acc[#acc + 1] = function() return i * i end
end
local squares = {}
for _, f in ipairs(acc) do squares[#squares + 1] = f() end
print(table.concat(squares, " "))
