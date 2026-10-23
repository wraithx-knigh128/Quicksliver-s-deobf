--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local cDGcFkDJOk,AemCUlrTcKk,IyWVnEfbt,ramgNjMn,PszEfWZNq,ujEVWTkAX,NwgoUcmSm
cDGcFkDJOk=pairs;AemCUlrTcKk=print;IyWVnEfbt=math.min;ramgNjMn=math.pi;PszEfWZNq=string.format;ujEVWTkAX=table.concat;NwgoUcmSm=table.sort;
-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local wPdZwiguCp = {}
wPdZwiguCp.__index = wPdZwiguCp

function wPdZwiguCp.new(name)
  return setmetatable({name= name }, wPdZwiguCp)
end

function wPdZwiguCp:describe()
  return gIOyIDrVQe.name .. " with area " .. string.format("%.2f", gIOyIDrVQe:area())
end

function wPdZwiguCp:area()
  return 0
end

local kweuqlPhf = setmetatable({}, {__index= wPdZwiguCp })
kweuqlPhf.__index = kweuqlPhf

function kweuqlPhf.new(radius)
  local gIOyIDrVQe = wPdZwiguCp.new("circle")
  gIOyIDrVQe.radius = radius
  return setmetatable(gIOyIDrVQe, kweuqlPhf)
end

function kweuqlPhf:area()
  return math.pi * gIOyIDrVQe.radius ^ 2
end

local ycbhbXasaqVk = setmetatable({}, {__index= wPdZwiguCp })
ycbhbXasaqVk.__index = ycbhbXasaqVk

function ycbhbXasaqVk.new(width, height)
  local gIOyIDrVQe = wPdZwiguCp.new("rect")
  gIOyIDrVQe.width, gIOyIDrVQe.height = width, height
  return setmetatable(gIOyIDrVQe, ycbhbXasaqVk)
end

function ycbhbXasaqVk:area()
  return gIOyIDrVQe.width * gIOyIDrVQe.height
end

local IIMfMjZurC = {}
IIMfMjZurC.__index = IIMfMjZurC
IIMfMjZurC.__len = nil

function IIMfMjZurC.new()
  return setmetatable({first= 1, last = 0, items = {} }, IIMfMjZurC)
end

function IIMfMjZurC:push(zxWmdlERE)
  gIOyIDrVQe.last = gIOyIDrVQe.last + 1
  gIOyIDrVQe.items[gIOyIDrVQe.last] = zxWmdlERE
end

function IIMfMjZurC:pop()
  if gIOyIDrVQe.first > gIOyIDrVQe.last then
    return nil
  end
  local zxWmdlERE = gIOyIDrVQe.items[gIOyIDrVQe.first]
  gIOyIDrVQe.items[gIOyIDrVQe.first] = nil
  gIOyIDrVQe.first = gIOyIDrVQe.first + 1
  return zxWmdlERE
end

function IIMfMjZurC:size()
  return gIOyIDrVQe.last - gIOyIDrVQe.first + 1
end

local JxEmbDXKy = IIMfMjZurC.new()
JxEmbDXKy:push(kweuqlPhf.new(2))
JxEmbDXKy:push(ycbhbXasaqVk.new(3, 4))
JxEmbDXKy:push(wPdZwiguCp.new("blob"))

while JxEmbDXKy:size() > 0 do
  AemCUlrTcKk(JxEmbDXKy:pop():describe())
end

local function xHvKEpMRBuM(text)
  local jgqTeQsBpB = {}
  for word in text:lower():gmatch("%a+") do
    jgqTeQsBpB[word] = (jgqTeQsBpB[word] or 0) + 1
  end
  local yinXFpSjudBm = {}
  for word in cDGcFkDJOk(jgqTeQsBpB) do
    yinXFpSjudBm[#yinXFpSjudBm + 1] = word
  end
  table.sort(yinXFpSjudBm, function(a, b)
    if jgqTeQsBpB[a] ~= jgqTeQsBpB[b] then
      return jgqTeQsBpB[a] > jgqTeQsBpB[b]
    end
    return a < b
  end)
  local ArfoPVZM = {}
  for i = 1, math.min(3, #yinXFpSjudBm) do
    ArfoPVZM[#ArfoPVZM + 1] = yinXFpSjudBm[i] .. ":" .. jgqTeQsBpB[yinXFpSjudBm[i]]
  end
  return table.concat(ArfoPVZM, ", ")
end

AemCUlrTcKk(xHvKEpMRBuM("To be, or not to be, that is the question: to be wise is to be"))
