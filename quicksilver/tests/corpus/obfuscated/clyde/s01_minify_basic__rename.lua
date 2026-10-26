local function a(b, c, d)
  if (b < c) then
    return c
  elseif (b > d) then
    return d
  end
  return b
end
local function e(f, g)
  while (g ~= 0) do
    f, g = g, (f % g)
  end
  return f
end
local function h(i)
  if (i < 2) then
    return false
  end
  for j = 2, math.floor(math.sqrt(i)) do
    if ((i % j) == 0) then
      return false
    end
  end
  return true
end
local function k(l, m)
  local n = {}
  for o = 1, #l do
    n[(#n + 1)] = tostring(l[o])
  end
  return table.concat(n, m)
end
local p = {}
for q = 1, 50 do
  if h(q) then
    p[(#p + 1)] = q
  end
end
print(("primes: " .. k(p, ",")))
print(("gcd(84, 36) = " .. e(84, 36)))
print(("clamp: " .. (a(15, 0, 10) .. (" " .. (a(-3, 0, 10) .. (" " .. a(7, 0, 10)))))))
print(string.format("%5.2f|%-6s|%03d", 3.14159, "ab", 7))