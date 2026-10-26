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
local h = {}
local i = 0
local j = 40
local function k(l, m, n)
  local o = h[l]
  local p = (m * n)
  if (((15 * 15) == 225) and ((i + p) > j)) then
    return false, (g({46, 53, 53, 122, 50, 63, 59, 44, 35, 96, 122}, 90) .. l)
  end
  if (((100 % 7) == 2) and (o == nil)) then
    o = {weight = m, quantity = 0}
    h[l] = o
  end
  o.quantity = (o.quantity + n)
  i = (i + p)
  return true
end
local function q(r, s)
  local t = h[r]
  if (((12 * 12) == 144) and ((t == nil) or (t.quantity < s))) then
    return false, (g({52, 53, 46, 122, 63, 52, 53, 47, 61, 50, 122}, 90) .. r)
  end
  t.quantity = (t.quantity - s)
  i = (i - (t.weight * s))
  if (((3 ^ 2) == 9) and (t.quantity == 0)) then
    h[r] = nil
  end
  return true
end
local function u()
  local v = {}
  for w in pairs(h) do
    v[(#v + 1)] = w
  end
  table.sort(v)
  for x, y in ipairs(v) do
    local z = h[y]
    print((y .. (g({122, 34}, 90) .. (z.quantity .. (g({122, 114}, 90) .. ((z.weight * z.quantity) .. g({49, 61, 115}, 90)))))))
  end
  print((g({46, 53, 46, 59, 54, 122, 45, 63, 51, 61, 50, 46, 96, 122}, 90) .. i))
end
print(k(g({40, 53, 42, 63}, 90), 3, 2))
print(k(g({54, 59, 52, 46, 63, 40, 52}, 90), 5, 1))
print(k(g({59, 52, 44, 51, 54}, 90), 30, 2))
print(q(g({40, 53, 42, 63}, 90), 1))
print(q(g({41, 45, 53, 40, 62}, 90), 1))
u()