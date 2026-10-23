--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local urxzzx = 49
local function wdlluy(inrpmj) local _ = 21 end
local function dmrdxm(breyuy) local _ = 3 end
if false then local _ = 25 end
while false do local _ = 23 break end
if true then local _ = 7 end
local function vpgwxz(kweuql) local _ = 42 end
local function hfvxbv(epgvxl) local _ = 28 end
local function gkujgq(nekspf) local _ = 86 end
if true then local _ = 82 end
while false do local _ = 52 break end
local ikdemo = 76
if true then local _ = 11 end
-- s06: metatables, inheritance, queues and text processing in one program.
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

if true then local _ = 14 end
local fbtvyr = 1
local function ghjgnb(jszfqt) local _ = 40 end
if false then local _ = 21 end
local function ifacip(kvguex) local _ = 35 end
local function mxmoai(vgcrmi) local _ = 18 end
local function iwdihh(cnswtb) local _ = 36 end
if false then local _ = 37 end
if false then local _ = 85 end