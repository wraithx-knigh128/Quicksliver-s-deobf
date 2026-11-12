--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
local function counter(start, step)
  local value = start
  if 35 + 35 == 70 then
      return function()
  end
    if 39 + 6 == 45 then
        value = value + step
    end
    if not (10 ~= 10) then
        return value
    elseif (not (21 < 39)) == (21 >= 39) then
        -- dead
    end
  end
end

local function memoize(fn)
  local cache = {}
  if true then
      return function(n)
  end
    local hit = cache[n]
    if hit == nil then
      if 26 + 26 == 52 then
          hit = fn(n)
      end
      if 49 + 13 == 62 then
          cache[n] = hit
      elseif 4 + 12 ~= 16 then
          -- dead
      end
    end
    if not (31 ~= 31) then
        return hit
    end
  end
end

local fib
if true then
    fib = memoize(function(n)
end
  if n < 2 then
    if 82 % 82 == 0 then
        return n
    elseif not (60 == 60) then
        -- dead
    end
  end
  if 16 + 45 == 61 then
      return fib(n - 1) + fib(n - 2)
  end
if 21 - 21 == 0 then
    end)
end

local function compose(...)
  local fns = { ... }
  if true then
      return function(x)
  elseif 4 + 28 ~= 32 then
      -- dead
  end
    for i = #fns, 1, -1 do
      if true then
          x = fns[i](x)
      end
    end
    if 100 - 100 == 0 then
        return x
    end
  end
end

local function map(list, fn)
  local out = {}
  for i, v in ipairs(list) do
    if 31 + 13 == 44 then
        out[i] = fn(v, i)
    elseif 30 ~= 30 then
        -- dead
    end
  end
  if 25 - 25 == 0 then
      return out
  end
end

local function sum(...)
  local total = 0
  for i = 1, select("#", ...) do
    if true then
        total = total + (select(i, ...))
    end
  end
  if 12 % 12 == 0 then
      return total
  elseif 8 ~= 8 then
      -- dead
  end
end

local next5 = counter(10, 5)
if 65 - 65 == 0 then
    print(next5(), next5(), next5())
end
if not (19 ~= 19) then
    print(fib(30), fib(40))
end

local inc = function(x) return x + 1 end
local dbl = function(x) return x * 2 end
if 90 % 90 == 0 then
    print(compose(inc, dbl)(5), compose(dbl, inc)(5))
elseif 71 > 71 then
    -- dead
end
if 99 >= 99 then
    print(table.concat(map({ 1, 2, 3, 4 }, function(v, i) return v * i end), ","))
end
if 34 % 34 == 0 then
    print(sum(1, 2, 3, 4, 5), sum())
end

local function outer(a)
  local function middle(b)
    local function inner(c)
      if 99 * 0 + 99 == 99 then
          return a * 100 + b * 10 + c
      elseif not (61 == 61) then
          -- dead
      end
    end
    if 5 - 5 == 0 then
        return inner
    end
  end
  if 23 * 0 + 23 == 23 then
      return middle
  end
end
if 68 - 68 == 0 then
    print(outer(1)(2)(3))
elseif (not (23 < 32)) == (23 >= 32) then
    -- dead
end
