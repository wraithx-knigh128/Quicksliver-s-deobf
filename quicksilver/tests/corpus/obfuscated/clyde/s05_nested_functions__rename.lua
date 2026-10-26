local function a(b, c)
  local d = b
  return function()
    d = (d + c)
    return d
  end
end
local function e(f)
  local g = {}
  return function(h)
    local i = g[h]
    if (i == nil) then
      i = f(h)
      g[h] = i
    end
    return i
  end
end
local j
j = e(function(k)
  if (k < 2) then
    return k
  end
  return (j((k - 1)) + j((k - 2)))
end)
local function l(...)
  local m = {...}
  return function(n)
    for o = #m, 1, -1 do
      n = m[o](n)
    end
    return n
  end
end
local function p(q, r)
  local s = {}
  for t, u in ipairs(q) do
    s[t] = r(u, t)
  end
  return s
end
local function v(...)
  local w = 0
  for x = 1, select("#", ...) do
    w = (w + (select(x, ...)))
  end
  return w
end
local y = a(10, 5)
print(y(), y(), y())
print(j(30), j(40))
local aa = function(z)
  return (z + 1)
end
local ac = function(ab)
  return (ab * 2)
end
print(l(aa, ac)(5), l(ac, aa)(5))
print(table.concat(p({1, 2, 3, 4}, function(ad, ae)
  return (ad * ae)
end), ","))
print(v(1, 2, 3, 4, 5), v())
local function af(ag)
  local function ah(ai)
    local function aj(ak)
      return (((ag * 100) + (ai * 10)) + ak)
    end
    return aj
  end
  return ah
end
print(af(1)(2)(3))