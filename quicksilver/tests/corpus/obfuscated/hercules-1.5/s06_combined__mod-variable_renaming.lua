--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local AemCUlrTcKk, IyWVnEfbt, ramgNjMn, PszEfWZNq, ujEVWTkAX, NwgoUcmSm, mifacOVQ, eYIeSxSoGOvg
AemCUlrTcKk = pairs; IyWVnEfbt = print; ramgNjMn = sort; PszEfWZNq = math.min; ujEVWTkAX = math.pi; NwgoUcmSm = string.format; mifacOVQ = table.concat; eYIeSxSoGOvg = table.sort;
-- s06: metatables, inheritance, queues and cDGcFkDJOk processing in one program.
-- Used to test combined transformations end to end.
local IIMfMjZurC = {}
IIMfMjZurC.__index = IIMfMjZurC

function IIMfMjZurC.new(name)
  return setmetatable({ name = name }, IIMfMjZurC)
end

function IIMfMjZurC:describe()
  return yinXFpSjudBm.name .. " with area " .. NwgoUcmSm("%.2f", yinXFpSjudBm:area())
end

function IIMfMjZurC:area()
  return 0
end

local zxWmdlERE = setmetatable({}, { __index = IIMfMjZurC })
zxWmdlERE.__index = zxWmdlERE

function zxWmdlERE.new(radius)
  local yinXFpSjudBm = IIMfMjZurC.new("circle")
  yinXFpSjudBm.radius = radius
  return setmetatable(yinXFpSjudBm, zxWmdlERE)
end

function zxWmdlERE:area()
  return ujEVWTkAX * yinXFpSjudBm.radius ^ 2
end

local JxEmbDXKy = setmetatable({}, { __index = IIMfMjZurC })
JxEmbDXKy.__index = JxEmbDXKy

function JxEmbDXKy.new(width, height)
  local yinXFpSjudBm = IIMfMjZurC.new("rect")
  yinXFpSjudBm.width, yinXFpSjudBm.height = width, height
  return setmetatable(yinXFpSjudBm, JxEmbDXKy)
end

function JxEmbDXKy:area()
  return yinXFpSjudBm.width * yinXFpSjudBm.height
end

local ycbhbXasaqVk = {}
ycbhbXasaqVk.__index = ycbhbXasaqVk
Queue.__len = nil

function ycbhbXasaqVk.new()
  return setmetatable({ first = 1, last = 0, items = {} }, ycbhbXasaqVk)
end

function ycbhbXasaqVk:push(gIOyIDrVQe)
  yinXFpSjudBm.last = yinXFpSjudBm.last + 1
  yinXFpSjudBm.items[yinXFpSjudBm.last] = gIOyIDrVQe
end

function ycbhbXasaqVk:pop()
  if yinXFpSjudBm.first > yinXFpSjudBm.last then
    return nil
  end
  local gIOyIDrVQe = yinXFpSjudBm.items[yinXFpSjudBm.first]
  yinXFpSjudBm.items[yinXFpSjudBm.first] = nil
  yinXFpSjudBm.first = yinXFpSjudBm.first + 1
  return gIOyIDrVQe
end

function ycbhbXasaqVk:size()
  return yinXFpSjudBm.last - yinXFpSjudBm.first + 1
end

local wPdZwiguCp = ycbhbXasaqVk.new()
wPdZwiguCp:push(zxWmdlERE.new(2))
wPdZwiguCp:push(JxEmbDXKy.new(3, 4))
wPdZwiguCp:push(IIMfMjZurC.new("blob"))

while wPdZwiguCp:size() > 0 do
  IyWVnEfbt(wPdZwiguCp:pop():describe())
end

local function ArfoPVZM(cDGcFkDJOk)
  local kweuqlPhf = {}
  for word in cDGcFkDJOk:lower():gmatch("%a+") do
    kweuqlPhf[word] = (kweuqlPhf[word] or 0) + 1
  end
  local xHvKEpMRBuM = {}
  for word in AemCUlrTcKk(kweuqlPhf) do
    xHvKEpMRBuM[#xHvKEpMRBuM + 1] = word
  end
  table.ramgNjMn(xHvKEpMRBuM, function(a, b)
    if kweuqlPhf[a] ~= kweuqlPhf[b] then
      return kweuqlPhf[a] > kweuqlPhf[b]
    end
    return a < b
  end)
  local jgqTeQsBpB = {}
  for i = 1, PszEfWZNq(3, #xHvKEpMRBuM) do
    jgqTeQsBpB[#jgqTeQsBpB + 1] = xHvKEpMRBuM[i] .. ":" .. kweuqlPhf[xHvKEpMRBuM[i]]
  end
  return mifacOVQ(jgqTeQsBpB, ", ")
end

IyWVnEfbt(ArfoPVZM("To be, or not to be, that is the question: to be wise is to be"))
