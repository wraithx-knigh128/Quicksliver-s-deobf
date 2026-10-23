--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local function ccgxfg(xjturx) local _ = 90 end
while false do local _ = 60 break end
local juudmr = 100
local breyuy = 3
local function kgvciy(yucrpk) local _ = 5 end
local function ywjdtw(iguvpg) local _ = 23 end
if false then local _ = 98 end
local pgvxlu = 60
local function ujgqne(kspfvi) local _ = 27 end
local function uvydik(demolr) local _ = 46 end
local function yekjcy(qpnfbt) local _ = 22 end
local ghjgnb = 42
local function zfqthy(qrujpq) local _ = 59 end
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

local function vmmmho(ymifac) local _ = 41 end
local function vguexs(cemxmo) local _ = 97 end
local function rmixqr(miwdih) local _ = 40 end
local function nswtbd(sxsduv) local _ = 41 end
local ccbxqn = 33
local kjdtkf = 58
local function lkfriy(uzgzuj) local _ = 56 end
local function cgyrmg(xprgpm) local _ = 73 end
local function vcvxxx(wbrbwj) local _ = 43 end
while false do local _ = 7 break end
if false then local _ = 97 end
local ftubfw = 9
while false do local _ = 72 break end
if false then local _ = 13 end
while false do local _ = 61 break end