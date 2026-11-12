--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local cDGcFkDJOk,AemCUlrTcKk,IyWVnEfbt,ramgNjMn,PszEfWZNq,ujEVWTkAX,NwgoUcmSm
cDGcFkDJOk=pairs;AemCUlrTcKk=print;IyWVnEfbt=math.min;ramgNjMn=math.pi;PszEfWZNq=string.format;ujEVWTkAX=table.concat;NwgoUcmSm=table.sort;
-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local jgqTeQsBpB = {}
jgqTeQsBpB.__index = jgqTeQsBpB

function jgqTeQsBpB.new(name)
  return setmetatable({name= name }, jgqTeQsBpB)
end

function jgqTeQsBpB:describe()
  return xHvKEpMRBuM.name .. " with area " .. string.format("%.2f", xHvKEpMRBuM:area())
end

function jgqTeQsBpB:area()
  return 0
end

local IIMfMjZurC = setmetatable({}, {__index= jgqTeQsBpB })
IIMfMjZurC.__index = IIMfMjZurC

function IIMfMjZurC.new(radius)
  local xHvKEpMRBuM = jgqTeQsBpB.new("circle")
  xHvKEpMRBuM.radius = radius
  return setmetatable(xHvKEpMRBuM, IIMfMjZurC)
end

function IIMfMjZurC:area()
  return math.pi * xHvKEpMRBuM.radius ^ 2
end

local kweuqlPhf = setmetatable({}, {__index= jgqTeQsBpB })
kweuqlPhf.__index = kweuqlPhf

function kweuqlPhf.new(width, height)
  local xHvKEpMRBuM = jgqTeQsBpB.new("rect")
  xHvKEpMRBuM.width, xHvKEpMRBuM.height = width, height
  return setmetatable(xHvKEpMRBuM, kweuqlPhf)
end

function kweuqlPhf:area()
  return xHvKEpMRBuM.width * xHvKEpMRBuM.height
end

local ycbhbXasaqVk = {}
ycbhbXasaqVk.__index = ycbhbXasaqVk
ycbhbXasaqVk.__len = nil

function ycbhbXasaqVk.new()
  return setmetatable({first= 1, last = 0, items = {} }, ycbhbXasaqVk)
end

function ycbhbXasaqVk:push(JxEmbDXKy)
  xHvKEpMRBuM.last = xHvKEpMRBuM.last + 1
  xHvKEpMRBuM.items[xHvKEpMRBuM.last] = JxEmbDXKy
end

function ycbhbXasaqVk:pop()
  if xHvKEpMRBuM.first > xHvKEpMRBuM.last then
    return nil
  end
  local JxEmbDXKy = xHvKEpMRBuM.items[xHvKEpMRBuM.first]
  xHvKEpMRBuM.items[xHvKEpMRBuM.first] = nil
  xHvKEpMRBuM.first = xHvKEpMRBuM.first + 1
  return JxEmbDXKy
end

function ycbhbXasaqVk:size()
  return xHvKEpMRBuM.last - xHvKEpMRBuM.first + 1
end

local ArfoPVZM = ycbhbXasaqVk.new()
ArfoPVZM:push(IIMfMjZurC.new(2))
ArfoPVZM:push(kweuqlPhf.new(3, 4))
ArfoPVZM:push(jgqTeQsBpB.new("blob"))

while ArfoPVZM:size() > 0 do
  AemCUlrTcKk(ArfoPVZM:pop():describe())
end

local function yinXFpSjudBm(text)
  local zxWmdlERE = {}
  for word in text:lower():gmatch("%a+") do
    zxWmdlERE[word] = (zxWmdlERE[word] or 0) + 1
  end
  local gIOyIDrVQe = {}
  for word in cDGcFkDJOk(zxWmdlERE) do
    gIOyIDrVQe[#gIOyIDrVQe + 1] = word
  end
  table.sort(gIOyIDrVQe, function(a, b)
    if zxWmdlERE[a] ~= zxWmdlERE[b] then
      return zxWmdlERE[a] > zxWmdlERE[b]
    end
    return a < b
  end)
  local wPdZwiguCp = {}
  for i = 1, math.min(3, #gIOyIDrVQe) do
    wPdZwiguCp[#wPdZwiguCp + 1] = gIOyIDrVQe[i] .. ":" .. zxWmdlERE[gIOyIDrVQe[i]]
  end
  return table.concat(wPdZwiguCp, ", ")
end

AemCUlrTcKk(yinXFpSjudBm("To be, or not to be, that is the question: to be wise is to be"))
