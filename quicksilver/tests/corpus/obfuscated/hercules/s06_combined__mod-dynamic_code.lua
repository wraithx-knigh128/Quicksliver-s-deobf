--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local Shape = {}
do (function() Shape.__index = Shape end)() end

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
do (function() Circle.__index = Circle end)() end

function Circle.new(radius)
  local self = Shape.new("circle")
  do (function() self.radius = radius end)() end
  return setmetatable(self, Circle)
end

function Circle:area()
  return math.pi * self.radius ^ 2
end

local Rect = setmetatable({}, { __index = Shape })
do (function() Rect.__index = Rect end)() end

function Rect.new(width, height)
  local self = Shape.new("rect")
  do (function() self.width, self.height = width, height end)() end
  return setmetatable(self, Rect)
end

function Rect:area()
  return self.width * self.height
end

local Queue = {}
do (function() Queue.__index = Queue end)() end
do (function() Queue.__len = nil end)() end

function Queue.new()
  return setmetatable({ first = 1, last = 0, items = {} }, Queue)
end

function Queue:push(value)
  do (function() self.last = self.last + 1 end)() end
  do (function() self.items[self.last] = value end)() end
end

function Queue:pop()
  if self.first > self.last then
    return nil
  end
  local value = self.items[self.first]
  do (function() self.items[self.first] = nil end)() end
  do (function() self.first = self.first + 1 end)() end
  return value
end

function Queue:size()
  return self.last - self.first + 1
end

local queue = Queue.new()
do (function() queue:push(Circle.new(2)) end)() end
do (function() queue:push(Rect.new(3, 4)) end)() end
do (function() queue:push(Shape.new("blob")) end)() end

while queue:size() > 0 do
  do (function() print(queue:pop():describe()) end)() end
end

local function wordFrequency(text)
  local freq = {}
  for word in text:lower():gmatch("%a+") do
    do (function() freq[word] = (freq[word] or 0) + 1 end)() end
  end
  local keys = {}
  for word in pairs(freq) do
    do (function() keys[#keys + 1] = word end)() end
  end
  table.sort(keys, function(a, b)
    if freq[a] ~= freq[b] then
      return freq[a] > freq[b]
    end
    return a < b
  end)
  local lines = {}
  for i = 1, math.min(3, #keys) do
    do (function() lines[#lines + 1] = keys[i] .. ":" .. freq[keys[i]] end)() end
  end
  return table.concat(lines, ", ")
end

do (function() print(wordFrequency("To be, or not to be, that is the question: to be wise is to be")) end)() end
