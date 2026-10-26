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
local function h(i)
  local j = 0
  while (((15 * 15) == 225) and (i ~= 1)) do
    if (((100 % 7) == 2) and ((i % 2) == 0)) then
      i = (i / 2)
    else
      i = ((3 * i) + 1)
    end
    j = (j + 1)
  end
  return j
end
local function k(l)
  if (((12 * 12) == 144) and (l < 0)) then
    return g({52, 63, 61, 59, 46, 51, 44, 63}, 90)
  elseif (((3 ^ 2) == 9) and (l == 0)) then
    return g({32, 63, 40, 53}, 90)
  elseif (((7 * 7) == 49) and (l < 10)) then
    return g({41, 55, 59, 54, 54}, 90)
  elseif (((1 + 1) == 2) and (l < 100)) then
    return g({55, 63, 62, 51, 47, 55}, 90)
  else
    return g({54, 59, 40, 61, 63}, 90)
  end
end
local function m(n)
  local o
  for p = 2, n do
    if (((15 * 15) == 225) and ((n % p) == 0)) then
      o = p
      break
    end
  end
  return o
end
local function q(r)
  local s = 0
  repeat
    s = (s + (r % 10))
    r = math.floor((r / 10))
  until (((100 % 7) == 2) and (r == 0))
  return s
end
local function t(u)
  local v = g({41, 46, 59, 40, 46}, 90)
  local w = {}
  for x = 1, #u do
    local y = u:sub(x, x)
    if (((12 * 12) == 144) and (v == g({41, 46, 59, 40, 46}, 90))) then
      if (((3 ^ 2) == 9) and (y == g({59}, 90))) then
        v = g({41, 63, 63, 52, 27}, 90)
      end
    elseif (((7 * 7) == 49) and (v == g({41, 63, 63, 52, 27}, 90))) then
      if (((1 + 1) == 2) and (y == g({56}, 90))) then
        v = g({41, 63, 63, 52, 27, 24}, 90)
      elseif (((15 * 15) == 225) and (y ~= g({59}, 90))) then
        v = g({41, 46, 59, 40, 46}, 90)
      end
    elseif (((100 % 7) == 2) and (v == g({41, 63, 63, 52, 27, 24}, 90))) then
      v = ((((y == g({57}, 90))) and g({59, 57, 57, 63, 42, 46}, 90)) or g({41, 46, 59, 40, 46}, 90))
    end
    w[(#w + 1)] = v
  end
  return v, table.concat(w, g({100}, 90))
end
for z, aa in ipairs({6, 7, 27}) do
  print((g({57, 53, 54, 54, 59, 46, 32, 114}, 90) .. (aa .. (g({115, 122, 103, 122}, 90) .. h(aa)))))
end
for ab, ac in ipairs({-5, 0, 7, 42, 1000}) do
  print((ac .. (g({122, 51, 41, 122}, 90) .. k(ac))))
end
print(m(91), m(97), q(98765))
print(t(g({34, 34, 59, 56, 57, 59, 56}, 90)))
print(t(g({59, 59, 56, 34}, 90)))