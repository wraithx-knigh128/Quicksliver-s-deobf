--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
local function counter(start, step)
  local value = start
  return function()
    ;(function() value = value + step end)()
    return value
  end
end

local function memoize(fn)
  local cache = {}
  return function(n)
    local hit = cache[n]
    if hit == nil then
      ;(function() hit = fn(n) end)()
      ;(function() cache[n] = hit end)()
    end
    return hit
  end
end

local fib
;(function() fib = memoize(function(n) end)()
  if n < 2 then
    return n
  end
  return fib(n - 1) + fib(n - 2)
end)

local function compose(...)
  local fns = { ... }
  return function(x)
    for i = #fns, 1, -1 do
      ;(function() x = fns[i](x) end)()
    end
    return x
  end
end

local function map(list, fn)
  local out = {}
  for i, v in ipairs(list) do
    ;(function() out[i] = fn(v, i) end)()
  end
  return out
end

local function sum(...)
  local total = 0
  for i = 1, select("#", ...) do
    ;(function() total = total + (select(i, ...)) end)()
  end
  return total
end

local next5 = counter(10, 5)
;(function() print(next5(), next5(), next5()) end)()
;(function() print(fib(30), fib(40)) end)()

local inc = function(x) return x + 1 end
local dbl = function(x) return x * 2 end
;(function() print(compose(inc, dbl)(5), compose(dbl, inc)(5)) end)()
;(function() print(table.concat(map({ 1, 2, 3, 4 }, function(v, i) return v * i end), ",")) end)()
;(function() print(sum(1, 2, 3, 4, 5), sum()) end)()

local function outer(a)
  local function middle(b)
    local function inner(c)
      return a * 100 + b * 10 + c
    end
    return inner
  end
  return middle
end
;(function() print(outer(1)(2)(3)) end)()
