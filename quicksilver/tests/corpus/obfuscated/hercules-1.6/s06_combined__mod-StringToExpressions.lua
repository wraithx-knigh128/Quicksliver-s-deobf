--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local Shape = {}
Shape.__index = Shape

function Shape.new(name)
  return setmetatable({ name = name }, Shape)
end

function Shape:describe()
  return self.name .. string.char(-315 + 347)..string.char(-399 + 518)..string.char(-58 + 163)..string.char(859 - (743))..string.char(714 - (610))..string.char(749 - (717))..string.char(376 - (279))..string.char(256 - (142))..string.char(573 - (472))..string.char(-730 + 827)..string.char(-528 + 560) .. string.format(string.char(999 - (962))..string.char(130 - (84))..string.char(-774 + 824)..string.char(940 - (838)), self:area())
end

function Shape:area()
  return 0
end

local Circle = setmetatable({}, { __index = Shape })
Circle.__index = Circle

function Circle.new(radius)
  local self = Shape.new(string.char(853 - (754))..string.char(451 - (346))..string.char(720 - (606))..string.char(482 - (383))..string.char(-403 + 511)..string.char(917 - (816)))
  self.radius = radius
  return setmetatable(self, Circle)
end

function Circle:area()
  return math.pi * self.radius ^ 2
end

local Rect = setmetatable({}, { __index = Shape })
Rect.__index = Rect

function Rect.new(width, height)
  local self = Shape.new(string.char(443 - (329))..string.char(-413 + 514)..string.char(421 - (322))..string.char(-417 + 533))
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
queue:push(Shape.new(string.char(-154 + 252)..string.char(-656 + 764)..string.char(997 - (886))..string.char(229 - (131))))

while queue:size() > 0 do
  print(queue:pop():describe())
end

local function wordFrequency(text)
  local freq = {}
  for word in text:lower():gmatch(string.char(-820 + 857)..string.char(-385 + 482)..string.char(-761 + 804)) do
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
    lines[#lines + 1] = keys[i] .. string.char(-537 + 595) .. freq[keys[i]]
  end
  return table.concat(lines, string.char(-418 + 462)..string.char(-313 + 345))
end

print(wordFrequency(string.char(-824 + 908)..string.char(-781 + 892)..string.char(326 - (294))..string.char(245 - (147))..string.char(-873 + 974)..string.char(-850 + 894)..string.char(205 - (173))..string.char(-371 + 482)..string.char(-314 + 428)..string.char(-714 + 746)..string.char(896 - (786))..string.char(-772 + 883)..string.char(378 - (262))..string.char(-893 + 925)..string.char(-623 + 739)..string.char(7 + 104)..string.char(372 - (340))..string.char(-427 + 525)..string.char(675 - (574))..string.char(489 - (445))..string.char(643 - (611))..string.char(251 - (135))..string.char(-657 + 761)..string.char(962 - (865))..string.char(650 - (534))..string.char(411 - (379))..string.char(-22 + 127)..string.char(-812 + 927)..string.char(-170 + 202)..string.char(472 - (356))..string.char(-514 + 618)..string.char(-172 + 273)..string.char(-686 + 718)..string.char(246 - (133))..string.char(-714 + 831)..string.char(809 - (708))..string.char(-601 + 716)..string.char(693 - (577))..string.char(-826 + 931)..string.char(397 - (286))..string.char(-809 + 919)..string.char(353 - (295))..string.char(-174 + 206)..string.char(-397 + 513)..string.char(9 + 102)..string.char(-291 + 323)..string.char(990 - (892))..string.char(536 - (435))..string.char(924 - (892))..string.char(-277 + 396)..string.char(-190 + 295)..string.char(11 + 104)..string.char(-283 + 384)..string.char(431 - (399))..string.char(-637 + 742)..string.char(-789 + 904)..string.char(-877 + 909)..string.char(-328 + 444)..string.char(-100 + 211)..string.char(497 - (465))..string.char(-583 + 681)..string.char(229 - (128))))
