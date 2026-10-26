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
local h = g({18, 63, 54, 54, 53, 118, 122, 11, 47, 51, 57, 49, 9, 51, 54, 44, 63, 40, 123}, 90)
local i = g({119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119, 119}, 90)
local j = {g({59, 54, 42, 50, 59}, 90), g({56, 40, 59, 44, 53}, 90), g({57, 50, 59, 40, 54, 51, 63}, 90), g({62, 63, 54, 46, 59}, 90), g({63, 57, 50, 53}, 90), g({60, 53, 34, 46, 40, 53, 46}, 90)}
local k = g({1, 127, 106, 104, 62, 7, 122, 127, 41, 122, 114, 127, 62, 122, 57, 50, 59, 40, 41, 115}, 90)
print(h)
print(i)
for l, m in ipairs(j) do
  print(string.format(k, l, m:upper(), #m))
end
print(i)
local n = g({46, 50, 63, 122, 43, 47, 51, 57, 49, 122, 56, 40, 53, 45, 52, 122, 60, 53, 34, 122, 48, 47, 55, 42, 41, 122, 53, 44, 63, 40, 122, 46, 50, 63, 122, 54, 59, 32, 35, 122, 62, 53, 61}, 90)
local o = {}
for p in n:gmatch(g({127, 59}, 90)) do
  o[p] = (((o[p] or 0)) + 1)
end
local q = {}
for r in pairs(o) do
  q[(#q + 1)] = r
end
table.sort(q)
local s = {}
for t, u in ipairs(q) do
  s[(#s + 1)] = (u .. (g({103}, 90) .. o[u]))
end
print(table.concat(s, g({122}, 90)))
print(n:reverse())
print((n:gsub(g({53}, 90), g({106}, 90))))
print((g({59, 56}, 90)):rep(3))
print((n:sub(5, 9) .. (g({38}, 90) .. n:find(g({60, 53, 34}, 90), 1, true))))