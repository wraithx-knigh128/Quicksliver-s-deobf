local a = {}
local b = 0
local c = 40
local function d(e, f, g)
  local h = a[e]
  local i = (f * g)
  if ((b + i) > c) then
    return false, ("too heavy: " .. e)
  end
  if (h == nil) then
    h = {weight = f, quantity = 0}
    a[e] = h
  end
  h.quantity = (h.quantity + g)
  b = (b + i)
  return true
end
local function j(k, l)
  local m = a[k]
  if ((m == nil) or (m.quantity < l)) then
    return false, ("not enough " .. k)
  end
  m.quantity = (m.quantity - l)
  b = (b - (m.weight * l))
  if (m.quantity == 0) then
    a[k] = nil
  end
  return true
end
local function n()
  local o = {}
  for p in pairs(a) do
    o[(#o + 1)] = p
  end
  table.sort(o)
  for q, r in ipairs(o) do
    local s = a[r]
    print((r .. (" x" .. (s.quantity .. (" (" .. ((s.weight * s.quantity) .. "kg)"))))))
  end
  print(("total weight: " .. b))
end
print(d("rope", 3, 2))
print(d("lantern", 5, 1))
print(d("anvil", 30, 2))
print(j("rope", 1))
print(j("sword", 1))
n()