--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
while false do local _ = 99 break end
local function turxzz(xqmwdl) local _ = 31 end
if true then local _ = 85 end
local inrpmj = 21
local function eyuycb(hbrvas) local _ = 65 end
local pkkgvc = 41
local yucrpk = 5
while false do local _ = 23 break end
local function dtwigu(vpgwxz) local _ = 75 end
if false then local _ = 98 end
if false then local _ = 80 end
if false then local _ = 86 end
local rfojpt = 24
local cykuvy = 36
local kdemol = 18
-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
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

local qpnfbt = 22
local ramghj = 39
local function jszfqt(hyqruj) local _ = 95 end
local nzkrxo = 71
local function hxwxgo(ocvmmm) local _ = 8 end
local mifaci = 43
local ivgcrm = 94
local xqrmiw = 31
if false then local _ = 72 end
if false then local _ = 34 end
if true then local _ = 27 end
local mccbxq = 78
local ekjdtk = 70
local function lkfriy(uzgzuj) local _ = 56 end
local function oraigu(qtihgr) local _ = 49 end