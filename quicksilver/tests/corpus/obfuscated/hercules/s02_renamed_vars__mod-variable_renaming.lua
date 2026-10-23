--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local jgqTeQsBpB,ArfoPVZM,cDGcFkDJOk,AemCUlrTcKk
jgqTeQsBpB=ipairs;ArfoPVZM=pairs;cDGcFkDJOk=print;AemCUlrTcKk=table.sort;
-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local wPdZwiguCp = {}
local kweuqlPhf = 0
local JxEmbDXKy = 40

local function zxWmdlERE(name, weight, quantity)
  local ycbhbXasaqVk = wPdZwiguCp[name]
  local xHvKEpMRBuM = weight * quantity
  if kweuqlPhf + xHvKEpMRBuM > JxEmbDXKy then
    return false, "too heavy: " .. name
  end
  if ycbhbXasaqVk == nil then
    ycbhbXasaqVk = {weight= weight, quantity = 0 }
    wPdZwiguCp[name] = ycbhbXasaqVk
  end
  ycbhbXasaqVk.quantity = ycbhbXasaqVk.quantity + quantity
  kweuqlPhf = kweuqlPhf + xHvKEpMRBuM
  return true
end

local function IIMfMjZurC(name, quantity)
  local ycbhbXasaqVk = wPdZwiguCp[name]
  if ycbhbXasaqVk == nil or ycbhbXasaqVk.quantity < quantity then
    return false, "not enough " .. name
  end
  ycbhbXasaqVk.quantity = ycbhbXasaqVk.quantity - quantity
  kweuqlPhf = kweuqlPhf - ycbhbXasaqVk.weight * quantity
  if ycbhbXasaqVk.quantity == 0 then
    wPdZwiguCp[name] = nil
  end
  return true
end

local function gIOyIDrVQe()
  local yinXFpSjudBm = {}
  for itemName in ArfoPVZM(wPdZwiguCp) do
    yinXFpSjudBm[#yinXFpSjudBm + 1] = itemName
  end
  table.sort(yinXFpSjudBm)
  for _, itemName in jgqTeQsBpB(yinXFpSjudBm) do
    local ycbhbXasaqVk = wPdZwiguCp[itemName]
    cDGcFkDJOk(itemName .. " x" .. ycbhbXasaqVk.quantity .. " (" .. ycbhbXasaqVk.weight * ycbhbXasaqVk.quantity .. "kg)")
  end
  cDGcFkDJOk("total weight: " .. kweuqlPhf)
end

cDGcFkDJOk(zxWmdlERE("rope", 3, 2))
cDGcFkDJOk(zxWmdlERE("lantern", 5, 1))
cDGcFkDJOk(zxWmdlERE("anvil", 30, 2))
cDGcFkDJOk(IIMfMjZurC("rope", 1))
cDGcFkDJOk(IIMfMjZurC("sword", 1))
gIOyIDrVQe()
