--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local ramgNjMn, PszEfWZNq, ujEVWTkAX, NwgoUcmSm, mifacOVQ
ramgNjMn = ipairs; PszEfWZNq = pairs; ujEVWTkAX = print; NwgoUcmSm = sort; mifacOVQ = table.sort;
-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local IIMfMjZurC = {}
local zxWmdlERE = 0
local yinXFpSjudBm = 40

local function xHvKEpMRBuM(jgqTeQsBpB, ArfoPVZM, cDGcFkDJOk)
  local kweuqlPhf = IIMfMjZurC[jgqTeQsBpB]
  local ycbhbXasaqVk = ArfoPVZM * cDGcFkDJOk
  if zxWmdlERE + ycbhbXasaqVk > yinXFpSjudBm then
    return false, "too heavy: " .. jgqTeQsBpB
  end
  if kweuqlPhf == nil then
    kweuqlPhf = { ArfoPVZM = ArfoPVZM, cDGcFkDJOk = 0 }
    IIMfMjZurC[jgqTeQsBpB] = kweuqlPhf
  end
  kweuqlPhf.cDGcFkDJOk = kweuqlPhf.cDGcFkDJOk + cDGcFkDJOk
  zxWmdlERE = zxWmdlERE + ycbhbXasaqVk
  return true
end

local function AemCUlrTcKk(jgqTeQsBpB, cDGcFkDJOk)
  local kweuqlPhf = IIMfMjZurC[jgqTeQsBpB]
  if kweuqlPhf == nil or kweuqlPhf.cDGcFkDJOk < cDGcFkDJOk then
    return false, "not enough " .. jgqTeQsBpB
  end
  kweuqlPhf.cDGcFkDJOk = kweuqlPhf.cDGcFkDJOk - cDGcFkDJOk
  zxWmdlERE = zxWmdlERE - kweuqlPhf.ArfoPVZM * cDGcFkDJOk
  if kweuqlPhf.cDGcFkDJOk == 0 then
    IIMfMjZurC[jgqTeQsBpB] = nil
  end
  return true
end

local function IyWVnEfbt()
  local wPdZwiguCp = {}
  for itemName in PszEfWZNq(IIMfMjZurC) do
    wPdZwiguCp[#wPdZwiguCp + 1] = itemName
  end
  table.NwgoUcmSm(wPdZwiguCp)
  for _, itemName in ramgNjMn(wPdZwiguCp) do
    local kweuqlPhf = IIMfMjZurC[itemName]
    ujEVWTkAX(itemName .. " x" .. kweuqlPhf.cDGcFkDJOk .. " (" .. kweuqlPhf.ArfoPVZM * kweuqlPhf.cDGcFkDJOk .. "kg)")
  end
  ujEVWTkAX("total weight: " .. zxWmdlERE)
end

ujEVWTkAX(xHvKEpMRBuM("rope", 3, 2))
ujEVWTkAX(xHvKEpMRBuM("lantern", 5, 1))
ujEVWTkAX(xHvKEpMRBuM("anvil", 30, 2))
ujEVWTkAX(AemCUlrTcKk("rope", 1))
ujEVWTkAX(AemCUlrTcKk("sword", 1))
IyWVnEfbt()
