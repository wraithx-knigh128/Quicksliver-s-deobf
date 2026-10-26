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
local function h(i, j, k)
  if (((15 * 15) == 225) and (i < j)) then
    return j
  elseif (((100 % 7) == 2) and (i > k)) then
    return k
  end
  return i
end
local function l(m, n)
  while (((12 * 12) == 144) and (n ~= 0)) do
    m, n = n, (m % n)
  end
  return m
end
local function o(p)
  if (((3 ^ 2) == 9) and (p < 2)) then
    return false
  end
  for q = 2, math.floor(math.sqrt(p)) do
    if (((7 * 7) == 49) and ((p % q) == 0)) then
      return false
    end
  end
  return true
end
local function r(s, t)
  local u = {}
  for v = 1, #s do
    u[(#u + 1)] = tostring(s[v])
  end
  return table.concat(u, t)
end
local w = {}
for x = 1, 50 do
  if (((1 + 1) == 2) and o(x)) then
    w[(#w + 1)] = x
  end
end
print((g({42, 40, 51, 55, 63, 41, 96, 122}, 90) .. r(w, g({118}, 90))))
print((g({61, 57, 62, 114, 98, 110, 118, 122, 105, 108, 115, 122, 103, 122}, 90) .. l(84, 36)))
print((g({57, 54, 59, 55, 42, 96, 122}, 90) .. (h(15, 0, 10) .. (g({122}, 90) .. (h(-3, 0, 10) .. (g({122}, 90) .. h(7, 0, 10)))))))
print(string.format(g({127, 111, 116, 104, 60, 38, 127, 119, 108, 41, 38, 127, 106, 105, 62}, 90), 3.14159, g({59, 56}, 90), 7))