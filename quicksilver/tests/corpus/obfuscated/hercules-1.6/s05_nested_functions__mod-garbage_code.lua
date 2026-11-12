--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
if false then local _ = 99 end local function turxzz(xqmwdl) local _ = 31 end local dmrdxm = 66 local function eyuycb(hbrvas) local _ = 65 end while false do local _ = 75 break end if true then local _ = 99 end while false do local _ = 25 break end if false then local _ = 99 end local rpkeyw = 68 local function kweuql(juhfvx) local _ = 98 end local pgvxlu = 60 if false then local _ = 10 end if true then local _ = 19 end if true then local _ = 94 end local vydikd = 91 -- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
local function counter(start, step)
  local value = start
  return function()
    value = value + step
    return value
  end
end

local function memoize(fn)
  local cache = {}
  return function(n)
    local hit = cache[n]
    if hit == nil then
      hit = fn(n)
      cache[n] = hit
    end
    return hit
  end
end

local fib
fib = memoize(function(n)
  if n < 2 then
    return n
  end
  return fib(n - 1) + fib(n - 2)
end)

local function compose(...)
  local fns = { ... }
  return function(x)
    for i = #fns, 1, -1 do
      x = fns[i](x)
    end
    return x
  end
end

local function map(list, fn)
  local out = {}
  for i, v in ipairs(list) do
    out[i] = fn(v, i)
  end
  return out
end

local function sum(...)
  local total = 0
  for i = 1, select("#", ...) do
    total = total + (select(i, ...))
  end
  return total
end

local next5 = counter(10, 5)
print(next5(), next5(), next5())
print(fib(30), fib(40))

local inc = function(x) return x + 1 end
local dbl = function(x) return x * 2 end
print(compose(inc, dbl)(5), compose(dbl, inc)(5))
print(table.concat(map({ 1, 2, 3, 4 }, function(v, i) return v * i end), ","))
print(sum(1, 2, 3, 4, 5), sum())

local function outer(a)
  local function middle(b)
    local function inner(c)
      return a * 100 + b * 10 + c
    end
    return inner
  end
  return middle
end
print(outer(1)(2)(3))
 local molrnc = 37 if true then local _ = 35 end local function gnbjsz(fqthyq) local _ = 21 end local function pqnzkr(xogbhx) local _ = 87 end if false then local _ = 77 end local mhoymi = 6 while false do local _ = 41 break end if false then local _ = 71 end local exscem = 24 local oaivgc = 13 while false do local _ = 18 break end local iwdihh = 99 if false then local _ = 20 end local function dsxsdu(vimccb) local _ = 88 end local kjdtkf = 58 if false then local _ = 6 end if true then local _ = 41 end