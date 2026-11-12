--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local AemCUlrTcKk,IyWVnEfbt,ramgNjMn,PszEfWZNq,ujEVWTkAX,NwgoUcmSm,mifacOVQ
AemCUlrTcKk=pairs;IyWVnEfbt=print;ramgNjMn=math.min;PszEfWZNq=math.pi;ujEVWTkAX=string.format;NwgoUcmSm=table.concat;mifacOVQ=table.sort
-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local yinXFpSjudBm = {}
yinXFpSjudBm.__index = yinXFpSjudBm

function yinXFpSjudBm.new(name)
  return setmetatable({ name = name }, yinXFpSjudBm)
end

function yinXFpSjudBm:describe()
  return IIMfMjZurC.name .. " with area " .. ujEVWTkAX("%.2f", IIMfMjZurC:area())
end

function yinXFpSjudBm:area()
  return 0
end

local JxEmbDXKy = setmetatable({}, { __index = yinXFpSjudBm })
JxEmbDXKy.__index = JxEmbDXKy

function JxEmbDXKy.new(radius)
  local IIMfMjZurC = yinXFpSjudBm.new("circle")
  IIMfMjZurC.radius = radius
  return setmetatable(IIMfMjZurC, JxEmbDXKy)
end

function JxEmbDXKy:area()
  return PszEfWZNq * IIMfMjZurC.radius ^ 2
end

local zxWmdlERE = setmetatable({}, { __index = yinXFpSjudBm })
zxWmdlERE.__index = zxWmdlERE

function zxWmdlERE.new(width, height)
  local IIMfMjZurC = yinXFpSjudBm.new("rect")
  IIMfMjZurC.width, IIMfMjZurC.height = width, height
  return setmetatable(IIMfMjZurC, zxWmdlERE)
end

function zxWmdlERE:area()
  return IIMfMjZurC.width * IIMfMjZurC.height
end

local ArfoPVZM = {}
ArfoPVZM.__index = ArfoPVZM
ArfoPVZM.__len = nil

function ArfoPVZM.new()
  return setmetatable({ first = 1, last = 0, items = {} }, ArfoPVZM)
end

function ArfoPVZM:push(ycbhbXasaqVk)
  IIMfMjZurC.last = IIMfMjZurC.last + 1
  IIMfMjZurC.items[IIMfMjZurC.last] = ycbhbXasaqVk
end

function ArfoPVZM:pop()
  if IIMfMjZurC.first > IIMfMjZurC.last then
    return nil
  end
  local ycbhbXasaqVk = IIMfMjZurC.items[IIMfMjZurC.first]
  IIMfMjZurC.items[IIMfMjZurC.first] = nil
  IIMfMjZurC.first = IIMfMjZurC.first + 1
  return ycbhbXasaqVk
end

function ArfoPVZM:size()
  return IIMfMjZurC.last - IIMfMjZurC.first + 1
end

local cDGcFkDJOk = ArfoPVZM.new()
cDGcFkDJOk:push(JxEmbDXKy.new(2))
cDGcFkDJOk:push(zxWmdlERE.new(3, 4))
cDGcFkDJOk:push(yinXFpSjudBm.new("blob"))

while cDGcFkDJOk:size() > 0 do
  IyWVnEfbt(cDGcFkDJOk:pop():describe())
end

local function wPdZwiguCp(kweuqlPhf)
  local jgqTeQsBpB = {}
  for word in kweuqlPhf:lower():gmatch("%a+") do
    jgqTeQsBpB[word] = (jgqTeQsBpB[word] or 0) + 1
  end
  local xHvKEpMRBuM = {}
  for word in AemCUlrTcKk(jgqTeQsBpB) do
    xHvKEpMRBuM[#xHvKEpMRBuM + 1] = word
  end
  mifacOVQ(xHvKEpMRBuM, function(a, b)
    if jgqTeQsBpB[a] ~= jgqTeQsBpB[b] then
      return jgqTeQsBpB[a] > jgqTeQsBpB[b]
    end
    return a < b
  end)
  local gIOyIDrVQe = {}
  for i = 1, ramgNjMn(3, #xHvKEpMRBuM) do
    gIOyIDrVQe[#gIOyIDrVQe + 1] = xHvKEpMRBuM[i] .. ":" .. jgqTeQsBpB[xHvKEpMRBuM[i]]
  end
  return NwgoUcmSm(gIOyIDrVQe, ", ")
end

IyWVnEfbt(wPdZwiguCp("To be, or not to be, that is the question: to be wise is to be"))
