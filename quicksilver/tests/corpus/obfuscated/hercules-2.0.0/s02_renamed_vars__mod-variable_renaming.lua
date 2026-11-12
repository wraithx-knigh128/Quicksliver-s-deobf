--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local jgqTeQsBpB,ArfoPVZM,cDGcFkDJOk,AemCUlrTcKk
jgqTeQsBpB=ipairs;ArfoPVZM=pairs;cDGcFkDJOk=print;AemCUlrTcKk=table.sort;
-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local JxEmbDXKy = {}
local zxWmdlERE = 0
local xHvKEpMRBuM = 40

local function ycbhbXasaqVk(name, weight, quantity)
  local yinXFpSjudBm = JxEmbDXKy[name]
  local wPdZwiguCp = weight * quantity
  if zxWmdlERE + wPdZwiguCp > xHvKEpMRBuM then
    return false, "too heavy: " .. name
  end
  if yinXFpSjudBm == nil then
    yinXFpSjudBm = {weight= weight, quantity = 0 }
    JxEmbDXKy[name] = yinXFpSjudBm
  end
  yinXFpSjudBm.quantity = yinXFpSjudBm.quantity + quantity
  zxWmdlERE = zxWmdlERE + wPdZwiguCp
  return true
end

local function kweuqlPhf(name, quantity)
  local yinXFpSjudBm = JxEmbDXKy[name]
  if yinXFpSjudBm == nil or yinXFpSjudBm.quantity < quantity then
    return false, "not enough " .. name
  end
  yinXFpSjudBm.quantity = yinXFpSjudBm.quantity - quantity
  zxWmdlERE = zxWmdlERE - yinXFpSjudBm.weight * quantity
  if yinXFpSjudBm.quantity == 0 then
    JxEmbDXKy[name] = nil
  end
  return true
end

local function gIOyIDrVQe()
  local IIMfMjZurC = {}
  for itemName in ArfoPVZM(JxEmbDXKy) do
    IIMfMjZurC[#IIMfMjZurC + 1] = itemName
  end
  table.sort(IIMfMjZurC)
  for _, itemName in jgqTeQsBpB(IIMfMjZurC) do
    local yinXFpSjudBm = JxEmbDXKy[itemName]
    cDGcFkDJOk(itemName .. " x" .. yinXFpSjudBm.quantity .. " (" .. yinXFpSjudBm.weight * yinXFpSjudBm.quantity .. "kg)")
  end
  cDGcFkDJOk("total weight: " .. zxWmdlERE)
end

cDGcFkDJOk(ycbhbXasaqVk("rope", 3, 2))
cDGcFkDJOk(ycbhbXasaqVk("lantern", 5, 1))
cDGcFkDJOk(ycbhbXasaqVk("anvil", 30, 2))
cDGcFkDJOk(kweuqlPhf("rope", 1))
cDGcFkDJOk(kweuqlPhf("sword", 1))
gIOyIDrVQe()
