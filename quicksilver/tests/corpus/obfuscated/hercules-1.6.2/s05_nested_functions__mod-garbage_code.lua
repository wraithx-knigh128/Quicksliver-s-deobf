--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local naekjd = 52
local uzgzuj = 56
local function oraigu(qtihgr) local _ = 49 end
local ykbkic = 99
while false do local _ = 67 break end
local function krnxzk(lybtag) local _ = 65 end
local function gwhdva(eftubf) local _ = 23 end
local vqhvdl = 13
local function vhhyuo(ewioug) local _ = 64 end
local feiljw = 60
local function eahvrd(csspbq) local _ = 17 end
local function kqkpbe(svriif) local _ = 74 end
if false then local _ = 3 end
if false then local _ = 18 end
local function xqmwdl(luyinr) local _ = 60 end
while false do local _ = 21 break end
if false then local _ = 50 end
if true then local _ = 31 end
local function eyuycb(hbrvas) local _ = 65 end
local pkkgvc = 41
local yucrpk = 5
while false do local _ = 54 break end
local function kweuql(juhfvx) local _ = 98 end
if false then local _ = 21 end
if true then local _ = 43 end
local nekspf = 86
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

local rfojpt = 24
if false then local _ = 75 end
if true then local _ = 5 end
if true then local _ = 46 end
if true then local _ = 70 end
local function tvyram(ghjgnb) local _ = 42 end
local function pqnzkr(xogbhx) local _ = 87 end
local cipkvg = 21
local vgcrmi = 18
if false then local _ = 72 end
while false do local _ = 53 break end
if true then local _ = 41 end
local function lmqhxh(sqkonj) local _ = 21 end
local xxmfvz = 33
local function zuxtqg(bxmjmj) local _ = 11 end
if false then local _ = 48 end
local function qocskq(fvhdmv) local _ = 69 end
if false then local _ = 15 end
if true then local _ = 93 end
if true then local _ = 45 end
local huckpz = 94
local function wnxbbl(ukxxma) local _ = 60 end
local function crhaim(cpypgy) local _ = 89 end