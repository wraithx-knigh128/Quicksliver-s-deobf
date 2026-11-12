--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local function zxWm3dlEREu(Qg2IO5y71ID9)
    return (Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57) or 
           (Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90) or 
           (Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122)
end

local function IIM4fM4j0urC(BmXJxEmbDXKy1, cbhbX2asaq)
    local inX8FpSju1 = {}
    for i = 1, #BmXJxEmbDXKy1 do
        local Qg2IO5y71ID9 = BmXJxEmbDXKy1:byte(i)
        if zxWm3dlEREu(Qg2IO5y71ID9) then
            local VQeA5wPd0wi            if Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 48 - cbhbX2asaq + 10) % 10) + 48
            elseif Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 65 - cbhbX2asaq + 26) % 26) + 65
            elseif Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 97 - cbhbX2asaq + 26) % 26) + 97
            end
            table.insert(inX8FpSju1, string.char(VQeA5wPd0wi))
        else
            table.insert(inX8FpSju1, string.char(Qg2IO5y71ID9))
        end
    end
    return table.concat(inX8FpSju1)
end

-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local Shape = {}
Shape.__index = Shape

function Shape.new(name)
  return setmetatable({ name = name }, Shape)
end

function Shape:describe()
  return self.name .. IIM4fM4j0urC(" cozn gxkg ", -319449722) .. string.format(IIM4fM4j0urC("%.0v", -255556012), self:area())
end

function Shape:area()
  return 0
end

local Circle = setmetatable({}, { __index = Shape })
Circle.__index = Circle

function Circle.new(radius)
  local self = Shape.new(IIM4fM4j0urC("flufoh", 541087797))
  self.radius = radius
  return setmetatable(self, Circle)
end

function Circle:area()
  return math.pi * self.radius ^ 2
end

local Rect = setmetatable({}, { __index = Shape })
Rect.__index = Rect

function Rect.new(width, height)
  local self = Shape.new(IIM4fM4j0urC("kxvm", -40125937))
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
queue:push(Shape.new(IIM4fM4j0urC("vfiv", -550623482)))

while queue:size() > 0 do
  print(queue:pop():describe())
end

local function wordFrequency(text)
  local freq = {}
  for word in text:lower():gmatch(IIM4fM4j0urC("%g+", -1157038058)) do
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
    lines[#lines + 1] = keys[i] .. IIM4fM4j0urC(":", 1536593495) .. freq[keys[i]]
  end
  return table.concat(lines, IIM4fM4j0urC(", ", 1457098297))
end

print(wordFrequency(IIM4fM4j0urC("Bw jm, wz vwb bw jm, bpib qa bpm ycmabqwv: bw jm eqam qa bw jm", -952757174)))
