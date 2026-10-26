local a = {}
a.__index = a
function a.new(b)
  return setmetatable({name = b}, a)
end
function a:describe()
  return (self.name .. (" with area " .. string.format("%.2f", self:area())))
end
function a:area()
  return 0
end
local c = setmetatable({}, {__index = a})
c.__index = c
function c.new(d)
  local e = a.new("circle")
  e.radius = d
  return setmetatable(e, c)
end
function c:area()
  return (math.pi * (self.radius ^ 2))
end
local f = setmetatable({}, {__index = a})
f.__index = f
function f.new(g, h)
  local i = a.new("rect")
  i.width, i.height = g, h
  return setmetatable(i, f)
end
function f:area()
  return (self.width * self.height)
end
local j = {}
j.__index = j
j.__len = nil
function j.new()
  return setmetatable({first = 1, last = 0, items = {}}, j)
end
function j:push(k)
  self.last = (self.last + 1)
  self.items[self.last] = k
end
function j:pop()
  if (self.first > self.last) then
    return nil
  end
  local l = self.items[self.first]
  self.items[self.first] = nil
  self.first = (self.first + 1)
  return l
end
function j:size()
  return ((self.last - self.first) + 1)
end
local m = j.new()
m:push(c.new(2))
m:push(f.new(3, 4))
m:push(a.new("blob"))
while (m:size() > 0) do
  print(m:pop():describe())
end
local function n(o)
  local p = {}
  for q in o:lower():gmatch("%a+") do
    p[q] = (((p[q] or 0)) + 1)
  end
  local r = {}
  for s in pairs(p) do
    r[(#r + 1)] = s
  end
  table.sort(r, function(t, u)
    if (p[t] ~= p[u]) then
      return (p[t] > p[u])
    end
    return (t < u)
  end)
  local v = {}
  for w = 1, math.min(3, #r) do
    v[(#v + 1)] = (r[w] .. (":" .. p[r[w]]))
  end
  return table.concat(v, ", ")
end
print(n("To be, or not to be, that is the question: to be wise is to be"))