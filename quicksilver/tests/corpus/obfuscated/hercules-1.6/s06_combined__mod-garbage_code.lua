--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
if false then local _ = 99 end local function turxzz(xqmwdl) local _ = 31 end local dmrdxm = 66 local function eyuycb(hbrvas) local _ = 65 end while false do local _ = 75 break end if true then local _ = 99 end while false do local _ = 25 break end if false then local _ = 99 end local rpkeyw = 68 local function kweuql(juhfvx) local _ = 98 end local pgvxlu = 60 if false then local _ = 10 end if true then local _ = 19 end if true then local _ = 94 end local vydikd = 91 -- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local Shape = {}
Shape.__index = Shape

function Shape.new(name)
  return setmetatable({ name = name }, Shape)
end

function Shape:describe()
  return self.name .. " with area " .. string.format("%.2f", self:area())
end

function Shape:area()
  return 0
end

local Circle = setmetatable({}, { __index = Shape })
Circle.__index = Circle

function Circle.new(radius)
  local self = Shape.new("circle")
  self.radius = radius
  return setmetatable(self, Circle)
end

function Circle:area()
  return math.pi * self.radius ^ 2
end

local Rect = setmetatable({}, { __index = Shape })
Rect.__index = Rect

function Rect.new(width, height)
  local self = Shape.new("rect")
  self.width, self.height = width, height
  return setmetatable(self, Rect)
end

function Rect:area()
  return self.width * self.height
end

local Queue = {}
Queue.__index = Queue
Queue.__len = nil

function Queue.new()
  return setmetatable({ first = 1, last = 0, items = {} }, Queue)
end

function Queue:push(value)
  self.last = self.last + 1
  self.items[self.last] = value
end

function Queue:pop()
  if self.first > self.last then
    return nil
  end
  local value = self.items[self.first]
  self.items[self.first] = nil
  self.first = self.first + 1
  return value
end

function Queue:size()
  return self.last - self.first + 1
end

local queue = Queue.new()
queue:push(Circle.new(2))
queue:push(Rect.new(3, 4))
queue:push(Shape.new("blob"))

while queue:size() > 0 do
  print(queue:pop():describe())
end

local function wordFrequency(text)
  local freq = {}
  for word in text:lower():gmatch("%a+") do
    freq[word] = (freq[word] or 0) + 1
  end
  local keys = {}
  for word in pairs(freq) do
    keys[#keys + 1] = word
  end
  table.sort(keys, function(a, b)
    if freq[a] ~= freq[b] then
      return freq[a] > freq[b]
    end
    return a < b
  end)
  local lines = {}
  for i = 1, math.min(3, #keys) do
    lines[#lines + 1] = keys[i] .. ":" .. freq[keys[i]]
  end
  return table.concat(lines, ", ")
end

print(wordFrequency("To be, or not to be, that is the question: to be wise is to be"))
 local molrnc = 37 if true then local _ = 35 end local function gnbjsz(fqthyq) local _ = 21 end local function pqnzkr(xogbhx) local _ = 87 end if false then local _ = 77 end local mhoymi = 6 while false do local _ = 41 break end if false then local _ = 71 end local exscem = 24 local oaivgc = 13 while false do local _ = 18 break end local iwdihh = 99 if false then local _ = 20 end local function dsxsdu(vimccb) local _ = 88 end local kjdtkf = 58 if false then local _ = 6 end if true then local _ = 41 end