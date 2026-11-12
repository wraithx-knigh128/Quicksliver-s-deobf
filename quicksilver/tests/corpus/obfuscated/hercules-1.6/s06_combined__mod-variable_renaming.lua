--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local IyWVnEfbt, ramgNjMn, PszEfWZNq, ujEVWTkAX, NwgoUcmSm, mifacOVQ, eYIeSxSoGOvg, XmDOWrmiEd
IyWVnEfbt = pairs; ramgNjMn = print; PszEfWZNq = sort; ujEVWTkAX = math.min; NwgoUcmSm = math.pi; mifacOVQ = string.format; eYIeSxSoGOvg = table.concat; XmDOWrmiEd = table.sort;
-- s06: metatables, inheritance, queues and AemCUlrTcKk processing in one program.
-- Used to test combined transformations end to end.
local IIMfMjZurC = {}
IIMfMjZurC.__index = IIMfMjZurC

function IIMfMjZurC.new(name)
  return setmetatable({ name = name }, IIMfMjZurC)
end

function IIMfMjZurC:describe()
  return ycbhbXasaqVk.name .. " with area " .. mifacOVQ("%.2f", ycbhbXasaqVk:area())
end

function IIMfMjZurC:area()
  return 0
end

local zxWmdlERE = setmetatable({}, { __index = IIMfMjZurC })
zxWmdlERE.__index = zxWmdlERE

function zxWmdlERE.new(radius)
  local ycbhbXasaqVk = IIMfMjZurC.new("circle")
  ycbhbXasaqVk.radius = radius
  return setmetatable(ycbhbXasaqVk, zxWmdlERE)
end

function zxWmdlERE:area()
  return math.pi * ycbhbXasaqVk.radius ^ 2
end

local JxEmbDXKy = setmetatable({}, { __index = IIMfMjZurC })
JxEmbDXKy.__index = JxEmbDXKy

function JxEmbDXKy.new(width, height)
  local ycbhbXasaqVk = IIMfMjZurC.new("rect")
  ycbhbXasaqVk.width, ycbhbXasaqVk.height = width, height
  return setmetatable(ycbhbXasaqVk, JxEmbDXKy)
end

function JxEmbDXKy:area()
  return ycbhbXasaqVk.width * ycbhbXasaqVk.height
end

local gIOyIDrVQe = {}
gIOyIDrVQe.__index = gIOyIDrVQe
gIOyIDrVQe.__len = nil

function gIOyIDrVQe.new()
  return setmetatable({ first = 1, last = 0, items = {} }, gIOyIDrVQe)
end

function gIOyIDrVQe:push(wPdZwiguCp)
  ycbhbXasaqVk.last = ycbhbXasaqVk.last + 1
  ycbhbXasaqVk.items[ycbhbXasaqVk.last] = wPdZwiguCp
end

function gIOyIDrVQe:pop()
  if ycbhbXasaqVk.first > ycbhbXasaqVk.last then
    return nil
  end
  local wPdZwiguCp = ycbhbXasaqVk.items[ycbhbXasaqVk.first]
  ycbhbXasaqVk.items[ycbhbXasaqVk.first] = nil
  ycbhbXasaqVk.first = ycbhbXasaqVk.first + 1
  return wPdZwiguCp
end

function gIOyIDrVQe:size()
  return ycbhbXasaqVk.last - ycbhbXasaqVk.first + 1
end

local kweuqlPhf = gIOyIDrVQe.new()
kweuqlPhf:push(zxWmdlERE.new(2))
kweuqlPhf:push(JxEmbDXKy.new(3, 4))
kweuqlPhf:push(IIMfMjZurC.new("blob"))

while kweuqlPhf:size() > 0 do
  ramgNjMn(kweuqlPhf:pop():describe())
end

local function cDGcFkDJOk(AemCUlrTcKk)
  local xHvKEpMRBuM = {}
  for word in AemCUlrTcKk:lower():gmatch("%a+") do
    xHvKEpMRBuM[word] = (xHvKEpMRBuM[word] or 0) + 1
  end
  local jgqTeQsBpB = {}
  for word in IyWVnEfbt(xHvKEpMRBuM) do
    jgqTeQsBpB[#jgqTeQsBpB + 1] = word
  end
  table.PszEfWZNq(jgqTeQsBpB, function(a, b)
    if xHvKEpMRBuM[a] ~= xHvKEpMRBuM[b] then
      return xHvKEpMRBuM[a] > xHvKEpMRBuM[b]
    end
    return a < b
  end)
  local ArfoPVZM = {}
  for i = 1, ujEVWTkAX(3, #jgqTeQsBpB) do
    ArfoPVZM[#ArfoPVZM + 1] = jgqTeQsBpB[i] .. ":" .. xHvKEpMRBuM[jgqTeQsBpB[i]]
  end
  return eYIeSxSoGOvg(ArfoPVZM, ", ")
end

ramgNjMn(cDGcFkDJOk("To be, or not to be, that is the question: to be wise is to be"))
