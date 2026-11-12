--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local Shape = {}
;(function() Shape.__index = Shape end)()

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
;(function() Circle.__index = Circle end)()

function Circle.new(radius)
  local self = Shape.new("circle")
  ;(function() self.radius = radius end)()
  return setmetatable(self, Circle)
end

function Circle:area()
  return math.pi * self.radius ^ 2
end

local Rect = setmetatable({}, { __index = Shape })
;(function() Rect.__index = Rect end)()

function Rect.new(width, height)
  local self = Shape.new("rect")
  ;(function() self.width, self.height = width, height end)()
  return setmetatable(self, Rect)
end

function Rect:area()
  return self.width * self.height
end

local Queue = {}
;(function() Queue.__index = Queue end)()
;(function() Queue.__len = nil end)()

function Queue.new()
  return setmetatable({ first = 1, last = 0, items = {} }, Queue)
end

function Queue:push(value)
  ;(function() self.last = self.last + 1 end)()
  ;(function() self.items[self.last] = value end)()
end

function Queue:pop()
  if self.first > self.last then
    return nil
  end
  local value = self.items[self.first]
  ;(function() self.items[self.first] = nil end)()
  ;(function() self.first = self.first + 1 end)()
  return value
end

function Queue:size()
  return self.last - self.first + 1
end

local queue = Queue.new()
;(function() queue:push(Circle.new(2)) end)()
;(function() queue:push(Rect.new(3, 4)) end)()
;(function() queue:push(Shape.new("blob")) end)()

while queue:size() > 0 do
  ;(function() print(queue:pop():describe()) end)()
end

local function wordFrequency(text)
  local freq = {}
  for word in text:lower():gmatch("%a+") do
    ;(function() freq[word] = (freq[word] or 0) + 1 end)()
  end
  local keys = {}
  for word in pairs(freq) do
    ;(function() keys[#keys + 1] = word end)()
  end
  ;(function() table.sort(keys, function(a, b) end)()
    if freq[a] ~= freq[b] then
      return freq[a] > freq[b]
    end
    return a < b
  end)
  local lines = {}
  for i = 1, math.min(3, #keys) do
    ;(function() lines[#lines + 1] = keys[i] .. ":" .. freq[keys[i]] end)()
  end
  return table.concat(lines, ", ")
end

;(function() print(wordFrequency("To be, or not to be, that is the question: to be wise is to be")) end)()
