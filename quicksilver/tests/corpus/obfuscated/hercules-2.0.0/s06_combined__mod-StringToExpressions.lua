--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local chars = {[32]=" ",[97]="a",[98]="b",[99]="c",[101]="e",[102]="f",[104]="h",[105]="i",[44]=",",[46]=".",[110]="n",[111]="o",[50]="2",[113]="q",[114]="r",[84]="T",[116]="t",[117]="u",[119]="w",[58]=":",[115]="s",[43]="+",[37]="%",[108]="l"}
-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local Shape = {}
Shape.__index = Shape

function Shape.new(name)
  return setmetatable({ name = name }, Shape)
end

function Shape:describe()
  return self.name .. (chars[-315 + 347]..chars[-399 + 518]..chars[-58 + 163]..chars[859 - (743)]..chars[714 - (610)]..chars[749 - (717)]..chars[376 - (279)]..chars[256 - (142)]..chars[573 - (472)]..chars[-730 + 827]..chars[-528 + 560]) .. string.format((chars[999 - (962)]..chars[130 - (84)]..chars[-774 + 824]..chars[940 - (838)]), self:area())
end

function Shape:area()
  return 0
end

local Circle = setmetatable({}, { __index = Shape })
Circle.__index = Circle

function Circle.new(radius)
  local self = Shape.new((chars[853 - (754)]..chars[451 - (346)]..chars[720 - (606)]..chars[482 - (383)]..chars[-403 + 511]..chars[917 - (816)]))
  self.radius = radius
  return setmetatable(self, Circle)
end

function Circle:area()
  return math.pi * self.radius ^ 2
end

local Rect = setmetatable({}, { __index = Shape })
Rect.__index = Rect

function Rect.new(width, height)
  local self = Shape.new((chars[443 - (329)]..chars[-413 + 514]..chars[421 - (322)]..chars[-417 + 533]))
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
queue:push(Shape.new((chars[-154 + 252]..chars[-656 + 764]..chars[997 - (886)]..chars[229 - (131)])))

while queue:size() > 0 do
  print(queue:pop():describe())
end

local function wordFrequency(text)
  local freq = {}
  for word in text:lower():gmatch((chars[-820 + 857]..chars[-385 + 482]..chars[-761 + 804])) do
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
    lines[#lines + 1] = keys[i] .. (chars[-537 + 595]) .. freq[keys[i]]
  end
  return table.concat(lines, (chars[-418 + 462]..chars[-313 + 345]))
end

print(wordFrequency((chars[-824 + 908]..chars[-781 + 892]..chars[326 - (294)]..chars[245 - (147)]..chars[-873 + 974]..chars[-850 + 894]..chars[205 - (173)]..chars[-371 + 482]..chars[-314 + 428]..chars[-714 + 746]..chars[896 - (786)]..chars[-772 + 883]..chars[378 - (262)]..chars[-893 + 925]..chars[-623 + 739]..chars[7 + 104]..chars[372 - (340)]..chars[-427 + 525]..chars[675 - (574)]..chars[489 - (445)]..chars[643 - (611)]..chars[251 - (135)]..chars[-657 + 761]..chars[962 - (865)]..chars[650 - (534)]..chars[411 - (379)]..chars[-22 + 127]..chars[-812 + 927]..chars[-170 + 202]..chars[472 - (356)]..chars[-514 + 618]..chars[-172 + 273]..chars[-686 + 718]..chars[246 - (133)]..chars[-714 + 831]..chars[809 - (708)]..chars[-601 + 716]..chars[693 - (577)]..chars[-826 + 931]..chars[397 - (286)]..chars[-809 + 919]..chars[353 - (295)]..chars[-174 + 206]..chars[-397 + 513]..chars[9 + 102]..chars[-291 + 323]..chars[990 - (892)]..chars[536 - (435)]..chars[924 - (892)]..chars[-277 + 396]..chars[-190 + 295]..chars[11 + 104]..chars[-283 + 384]..chars[431 - (399)]..chars[-637 + 742]..chars[-789 + 904]..chars[-877 + 909]..chars[-328 + 444]..chars[-100 + 211]..chars[497 - (465)]..chars[-583 + 681]..chars[229 - (128)])))
