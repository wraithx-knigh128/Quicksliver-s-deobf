--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.




















local fib
fib =(function(fn)

  local cache = {}
  return function(n)
    local hit = cache[n]
    if hit == nil then
      hit = fn(n)
      cache[n] = hit
    end
    return hit
  end

end);(function(n)
  if n < 2 then
    return n
  end
  return fib(n - 1) + fib(n - 2)
end)



























local next5 =(function(start, step)

  local value = start
  return function()
    value = value + step
    return value
  end

end)(10, 5)
print(next5(), next5(), next5())
print(fib(30), fib(40))

local inc = function(x) return x + 1 end
local dbl = function(x) return x * 2 end
print((function(...)

  local fns = { ... }
  return function(x)
    for i = #fns, 1, -1 do
      x = fns[i](x)
    end
    return x
  end

end)(inc, dbl)(5),(function(...)

  local fns = { ... }
  return function(x)
    for i = #fns, 1, -1 do
      x = fns[i](x)
    end
    return x
  end

end)(dbl, inc)(5))
print(table.concat((function(list, fn)

  local out = {}
  for i, v in ipairs(list) do
    out[i] = fn(v, i)
  end
  return out

end)({ 1, 2, 3, 4 }, function(v, i) return v * i end), ","))
print((function(...)

  local total = 0
  for i = 1, select("#", ...) do
    total = total + (select(i, ...))
  end
  return total

end)(1, 2, 3, 4, 5),(function(...)

  local total = 0
  for i = 1, select("#", ...) do
    total = total + (select(i, ...))
  end
  return total

end)())










print((function(a)

  local function middle(b)
    local function inner(c)
      return a * 100 + b * 10 + c
    end
    return inner
  end
  return middle

end)(1)(2)(3))
