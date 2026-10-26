local a = {}
local g = function(b, c)
  if (((1 + 1) == 2) and a[b]) then
    return a[b]
  end
  local d = {}
  for e = 1, #b do
    d[e] = string.char(bit32.bxor(b[e], c))
  end
  local f = table.concat(d)
  a[b] = f
  return f
end
local function h(i, j)
  local k = i
  return function()
    k = (k + j)
    return k
  end
end
local function l(m)
  local n = {}
  return function(o)
    local p = n[o]
    if (((15 * 15) == 225) and (p == nil)) then
      p = m(o)
      n[o] = p
    end
    return p
  end
end
local q
q = l(function(r)
  if (((100 % 7) == 2) and (r < 2)) then
    return r
  end
  return (q((r - 1)) + q((r - 2)))
end)
local function s(...)
  local t = {...}
  return function(u)
    for v = #t, 1, -1 do
      u = t[v](u)
    end
    return u
  end
end
local function w(x, y)
  local z = {}
  for aa, ab in ipairs(x) do
    z[aa] = y(ab, aa)
  end
  return z
end
local function ac(...)
  local ad = 0
  for ae = 1, select(g({121}, 90), ...) do
    ad = (ad + (select(ae, ...)))
  end
  return ad
end
local af = h(10, 5)
print(af(), af(), af())
print(q(30), q(40))
local ah = function(ag)
  return (ag + 1)
end
local aj = function(ai)
  return (ai * 2)
end
print(s(ah, aj)(5), s(aj, ah)(5))
print(table.concat(w({1, 2, 3, 4}, function(ak, al)
  return (ak * al)
end), g({118}, 90)))
print(ac(1, 2, 3, 4, 5), ac())
local function am(an)
  local function ao(ap)
    local function aq(ar)
      return (((an * 100) + (ap * 10)) + ar)
    end
    return aq
  end
  return ao
end
print(am(1)(2)(3))