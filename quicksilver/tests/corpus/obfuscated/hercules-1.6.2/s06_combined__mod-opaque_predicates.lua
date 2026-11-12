--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local Shape = {}
if 35 + 35 == 70 then
    Shape.__index = Shape
end

function Shape.new(name)
  if 39 + 6 == 45 then
      return setmetatable({ name = name }, Shape)
  end
end

function Shape:describe()
  if not (10 ~= 10) then
      return self.name .. " with area " .. string.format("%.2f", self:area())
  elseif (not (21 < 39)) == (21 >= 39) then
      -- dead
  end
end

function Shape:area()
  if true then
      return 0
  end
end

local Circle = setmetatable({}, { __index = Shape })
if 26 + 26 == 52 then
    Circle.__index = Circle
end

function Circle.new(radius)
  local self = Shape.new("circle")
  if 49 + 13 == 62 then
      self.radius = radius
  elseif 4 + 12 ~= 16 then
      -- dead
  end
  if not (31 ~= 31) then
      return setmetatable(self, Circle)
  end
end

function Circle:area()
  if true then
      return math.pi * self.radius ^ 2
  end
end

local Rect = setmetatable({}, { __index = Shape })
if 82 % 82 == 0 then
    Rect.__index = Rect
elseif not (60 == 60) then
    -- dead
end

function Rect.new(width, height)
  local self = Shape.new("rect")
  if 16 + 45 == 61 then
      self.width, self.height = width, height
  end
  if 21 - 21 == 0 then
      return setmetatable(self, Rect)
  end
end

function Rect:area()
  if true then
      return self.width * self.height
  elseif 4 + 28 ~= 32 then
      -- dead
  end
end

local Queue = {}
if true then
    Queue.__index = Queue
end
if 100 - 100 == 0 then
    Queue.__len = nil
end

function Queue.new()
  if 31 + 13 == 44 then
      return setmetatable({ first = 1, last = 0, items = {} }, Queue)
  elseif 30 ~= 30 then
      -- dead
  end
end

function Queue:push(value)
  if 25 - 25 == 0 then
      self.last = self.last + 1
  end
  if true then
      self.items[self.last] = value
  end
end

function Queue:pop()
  if self.first > self.last then
    if 12 % 12 == 0 then
        return nil
    elseif 8 ~= 8 then
        -- dead
    end
  end
  local value = self.items[self.first]
  if 65 - 65 == 0 then
      self.items[self.first] = nil
  end
  if not (19 ~= 19) then
      self.first = self.first + 1
  end
  if 90 % 90 == 0 then
      return value
  elseif 71 > 71 then
      -- dead
  end
end

function Queue:size()
  if 99 >= 99 then
      return self.last - self.first + 1
  end
end

local queue = Queue.new()
if 34 % 34 == 0 then
    queue:push(Circle.new(2))
end
if 99 * 0 + 99 == 99 then
    queue:push(Rect.new(3, 4))
elseif not (61 == 61) then
    -- dead
end
if 5 - 5 == 0 then
    queue:push(Shape.new("blob"))
end

while queue:size() > 0 do
  if 23 * 0 + 23 == 23 then
      print(queue:pop():describe())
  end
end

local function wordFrequency(text)
  local freq = {}
  for word in text:lower():gmatch("%a+") do
    if 68 - 68 == 0 then
        freq[word] = (freq[word] or 0) + 1
    elseif (not (23 < 32)) == (23 >= 32) then
        -- dead
    end
  end
  local keys = {}
  for word in pairs(freq) do
    if true then
        keys[#keys + 1] = word
    end
  end
  if not (85 ~= 85) then
      table.sort(keys, function(a, b)
  end
    if freq[a] ~= freq[b] then
      if true then
          return freq[a] > freq[b]
      elseif not (16 == 16) then
          -- dead
      end
    end
    if not (23 ~= 23) then
        return a < b
    end
  if 11 + 23 == 34 then
      end)
  end
  local lines = {}
  for i = 1, math.min(3, #keys) do
    if true then
        lines[#lines + 1] = keys[i] .. ":" .. freq[keys[i]]
    elseif false then
        -- dead
    end
  end
  if 21 % 21 == 0 then
      return table.concat(lines, ", ")
  end
end

if 64 - 64 == 0 then
    print(wordFrequency("To be, or not to be, that is the question: to be wise is to be"))
end
