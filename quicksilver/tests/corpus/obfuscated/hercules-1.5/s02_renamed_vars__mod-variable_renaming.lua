--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local AemCUlrTcKk, IyWVnEfbt, ramgNjMn, PszEfWZNq, ujEVWTkAX
AemCUlrTcKk = pairs; IyWVnEfbt = ipairs; ramgNjMn = print; PszEfWZNq = sort; ujEVWTkAX = table.sort;
-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local IIMfMjZurC = {}
local zxWmdlERE = 0
local yinXFpSjudBm = 40

local function wPdZwiguCp(kweuqlPhf, xHvKEpMRBuM, jgqTeQsBpB)
  local JxEmbDXKy = IIMfMjZurC[kweuqlPhf]
  local ycbhbXasaqVk = xHvKEpMRBuM * jgqTeQsBpB
  if zxWmdlERE + ycbhbXasaqVk > yinXFpSjudBm then
    return false, "too heavy: " .. kweuqlPhf
  end
  if JxEmbDXKy == nil then
    JxEmbDXKy = { xHvKEpMRBuM = xHvKEpMRBuM, jgqTeQsBpB = 0 }
    IIMfMjZurC[kweuqlPhf] = JxEmbDXKy
  end
  JxEmbDXKy.jgqTeQsBpB = JxEmbDXKy.jgqTeQsBpB + jgqTeQsBpB
  zxWmdlERE = zxWmdlERE + ycbhbXasaqVk
  return true
end

local function ArfoPVZM(kweuqlPhf, jgqTeQsBpB)
  local JxEmbDXKy = IIMfMjZurC[kweuqlPhf]
  if JxEmbDXKy == nil or JxEmbDXKy.jgqTeQsBpB < jgqTeQsBpB then
    return false, "not enough " .. kweuqlPhf
  end
  JxEmbDXKy.jgqTeQsBpB = JxEmbDXKy.jgqTeQsBpB - jgqTeQsBpB
  zxWmdlERE = zxWmdlERE - JxEmbDXKy.xHvKEpMRBuM * jgqTeQsBpB
  if JxEmbDXKy.jgqTeQsBpB == 0 then
    IIMfMjZurC[kweuqlPhf] = nil
  end
  return true
end

local function cDGcFkDJOk()
  local gIOyIDrVQe = {}
  for itemName in AemCUlrTcKk(IIMfMjZurC) do
    gIOyIDrVQe[#gIOyIDrVQe + 1] = itemName
  end
  table.PszEfWZNq(gIOyIDrVQe)
  for _, itemName in iAemCUlrTcKk(gIOyIDrVQe) do
    local JxEmbDXKy = IIMfMjZurC[itemName]
    ramgNjMn(itemName .. " x" .. JxEmbDXKy.jgqTeQsBpB .. " (" .. JxEmbDXKy.xHvKEpMRBuM * JxEmbDXKy.jgqTeQsBpB .. "kg)")
  end
  ramgNjMn("total xHvKEpMRBuM: " .. zxWmdlERE)
end

ramgNjMn(wPdZwiguCp("rope", 3, 2))
ramgNjMn(wPdZwiguCp("lantern", 5, 1))
ramgNjMn(wPdZwiguCp("anvil", 30, 2))
ramgNjMn(ArfoPVZM("rope", 1))
ramgNjMn(ArfoPVZM("sword", 1))
cDGcFkDJOk()
