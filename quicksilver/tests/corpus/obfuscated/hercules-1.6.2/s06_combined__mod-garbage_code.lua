--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
while false do local _ = 29 break end
local function qtihgr(qaykbk) local _ = 99 end
if false then local _ = 30 end
local function icvcvx(xxwbrb) local _ = 55 end
if false then local _ = 88 end
if true then local _ = 44 end
local ybtaga = 10
local vaeftu = 34
while false do local _ = 72 break end
local lmzvhh = 53
local function wiougi(feiljw) local _ = 60 end
if false then local _ = 33 end
if false then local _ = 35 end
local function sfqpbr(jkcbkq) local _ = 43 end
if false then local _ = 19 end
if true then local _ = 31 end
while false do local _ = 74 break end
local urxzzx = 49
local function wdlluy(inrpmj) local _ = 21 end
local function dmrdxm(breyuy) local _ = 3 end
if true then local _ = 2 end
if true then local _ = 65 end
while false do local _ = 25 break end
if false then local _ = 23 end
local function vpgwxz(kweuql) local _ = 42 end
local function hfvxbv(epgvxl) local _ = 28 end
local function gkujgq(nekspf) local _ = 86 end
if false then local _ = 52 end
local ikdemo = 76
if true then local _ = 3 end
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

if true then local _ = 89 end
local fbtvyr = 1
local function ghjgnb(jszfqt) local _ = 40 end
while false do local _ = 21 break end
if true then local _ = 49 end
local function ifacip(kvguex) local _ = 35 end
local function mxmoai(vgcrmi) local _ = 18 end
local function iwdihh(cnswtb) local _ = 36 end
if true then local _ = 49 end
while false do local _ = 37 break end
while false do local _ = 85 break end
if true then local _ = 93 end
if true then local _ = 85 end
if true then local _ = 16 end
if true then local _ = 1 end
local lcofgc = 40
if true then local _ = 45 end
local function ahuulh(ioblmq) local _ = 8 end
local xhsqko = 21
local function fvzagj(zuxtqg) local _ = 66 end
local function jmjtkp(vfovgp) local _ = 96 end
if false then local _ = 47 end
local function nmlnoj(mhnhzg) local _ = 30 end
local jmihuc = 59
if false then local _ = 58 end
if false then local _ = 76 end
local function kxxmam(jnjcrh) local _ = 1 end
while false do local _ = 45 break end
if false then local _ = 31 end
if false then local _ = 32 end
local jibtmv = 26