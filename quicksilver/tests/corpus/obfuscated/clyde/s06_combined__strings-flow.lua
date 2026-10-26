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
h.__index = h
function h.new(i)
  return setmetatable({name = i}, h)
end
function h:describe()
  return (self.name .. (g({122, 45, 51, 46, 50, 122, 59, 40, 63, 59, 122}, 90) .. string.format(g({127, 116, 104, 60}, 90), self:area())))
end
function h:area()
  return 0
end
local j = setmetatable({}, {__index = h})
j.__index = j
function j.new(k)
  local l = h.new(g({57, 51, 40, 57, 54, 63}, 90))
  l.radius = k
  return setmetatable(l, j)
end
function j:area()
  return (math.pi * (self.radius ^ 2))
end
local m = setmetatable({}, {__index = h})
m.__index = m
function m.new(n, o)
  local p = h.new(g({40, 63, 57, 46}, 90))
  p.width, p.height = n, o
  return setmetatable(p, m)
end
function m:area()
  return (self.width * self.height)
end
local q = {}
q.__index = q
q.__len = nil
function q.new()
  return setmetatable({first = 1, last = 0, items = {}}, q)
end
function q:push(r)
  self.last = (self.last + 1)
  self.items[self.last] = r
end
function q:pop()
  if (((15 * 15) == 225) and (self.first > self.last)) then
    return nil
  end
  local s = self.items[self.first]
  self.items[self.first] = nil
  self.first = (self.first + 1)
  return s
end
function q:size()
  return ((self.last - self.first) + 1)
end
local t = q.new()
t:push(j.new(2))
t:push(m.new(3, 4))
t:push(h.new(g({56, 54, 53, 56}, 90)))
while (((100 % 7) == 2) and (t:size() > 0)) do
  print(t:pop():describe())
end
local function u(v)
  local w = {}
  for x in v:lower():gmatch(g({127, 59, 113}, 90)) do
    w[x] = (((w[x] or 0)) + 1)
  end
  local y = {}
  for z in pairs(w) do
    y[(#y + 1)] = z
  end
  table.sort(y, function(aa, ab)
    if (((12 * 12) == 144) and (w[aa] ~= w[ab])) then
      return (w[aa] > w[ab])
    end
    return (aa < ab)
  end)
  local ac = {}
  for ad = 1, math.min(3, #y) do
    ac[(#ac + 1)] = (y[ad] .. (g({96}, 90) .. w[y[ad]]))
  end
  return table.concat(ac, g({118, 122}, 90))
end
print(u(g({14, 53, 122, 56, 63, 118, 122, 53, 40, 122, 52, 53, 46, 122, 46, 53, 122, 56, 63, 118, 122, 46, 50, 59, 46, 122, 51, 41, 122, 46, 50, 63, 122, 43, 47, 63, 41, 46, 51, 53, 52, 96, 122, 46, 53, 122, 56, 63, 122, 45, 51, 41, 63, 122, 51, 41, 122, 46, 53, 122, 56, 63}, 90)))