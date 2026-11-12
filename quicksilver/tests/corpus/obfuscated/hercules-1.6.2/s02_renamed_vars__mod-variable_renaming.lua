--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local AemCUlrTcKk,IyWVnEfbt,ramgNjMn,PszEfWZNq
AemCUlrTcKk=ipairs;IyWVnEfbt=pairs;ramgNjMn=print;PszEfWZNq=table.sort
-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local ycbhbXasaqVk = {}
local JxEmbDXKy = 0
local cDGcFkDJOk = 40

local function wPdZwiguCp(kweuqlPhf, jgqTeQsBpB, zxWmdlERE)
  local xHvKEpMRBuM = ycbhbXasaqVk[kweuqlPhf]
  local IIMfMjZurC = jgqTeQsBpB * zxWmdlERE
  if JxEmbDXKy + IIMfMjZurC > cDGcFkDJOk then
    return false, "too heavy: " .. kweuqlPhf
  end
  if xHvKEpMRBuM == nil then
    xHvKEpMRBuM = { jgqTeQsBpB = jgqTeQsBpB, zxWmdlERE = 0 }
    ycbhbXasaqVk[kweuqlPhf] = xHvKEpMRBuM
  end
  xHvKEpMRBuM.zxWmdlERE = xHvKEpMRBuM.zxWmdlERE + zxWmdlERE
  JxEmbDXKy = JxEmbDXKy + IIMfMjZurC
  return true
end

local function yinXFpSjudBm(kweuqlPhf, zxWmdlERE)
  local xHvKEpMRBuM = ycbhbXasaqVk[kweuqlPhf]
  if xHvKEpMRBuM == nil or xHvKEpMRBuM.zxWmdlERE < zxWmdlERE then
    return false, "not enough " .. kweuqlPhf
  end
  xHvKEpMRBuM.zxWmdlERE = xHvKEpMRBuM.zxWmdlERE - zxWmdlERE
  JxEmbDXKy = JxEmbDXKy - xHvKEpMRBuM.jgqTeQsBpB * zxWmdlERE
  if xHvKEpMRBuM.zxWmdlERE == 0 then
    ycbhbXasaqVk[kweuqlPhf] = nil
  end
  return true
end

local function gIOyIDrVQe()
  local ArfoPVZM = {}
  for itemName in IyWVnEfbt(ycbhbXasaqVk) do
    ArfoPVZM[#ArfoPVZM + 1] = itemName
  end
  PszEfWZNq(ArfoPVZM)
  for _, itemName in AemCUlrTcKk(ArfoPVZM) do
    local xHvKEpMRBuM = ycbhbXasaqVk[itemName]
    ramgNjMn(itemName .. " x" .. xHvKEpMRBuM.zxWmdlERE .. " (" .. xHvKEpMRBuM.jgqTeQsBpB * xHvKEpMRBuM.zxWmdlERE .. "kg)")
  end
  ramgNjMn("total weight: " .. JxEmbDXKy)
end

ramgNjMn(wPdZwiguCp("rope", 3, 2))
ramgNjMn(wPdZwiguCp("lantern", 5, 1))
ramgNjMn(wPdZwiguCp("anvil", 30, 2))
ramgNjMn(yinXFpSjudBm("rope", 1))
ramgNjMn(yinXFpSjudBm("sword", 1))
gIOyIDrVQe()
