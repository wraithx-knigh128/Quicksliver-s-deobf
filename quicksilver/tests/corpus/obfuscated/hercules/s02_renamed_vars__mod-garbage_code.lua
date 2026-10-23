--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
if false then local _ = 99 end
local function turxzz(xqmwdl) local _ = 31 end
local uyinrp = 74
local function eyuycb(hbrvas) local _ = 65 end
while false do local _ = 75 break end
if true then local _ = 99 end
while false do local _ = 25 break end
if false then local _ = 99 end
local wiguvp = 7
local function kweuql(juhfvx) local _ = 98 end
local pfvirf = 64
local function ptgxkc(acykuv) local _ = 57 end
local ikdemo = 76
local function ncyekj(cyqpnf) local _ = 2 end
local vyramg = 40
local function gnbjsz(fqthyq) local _ = 21 end
-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local inventory = {}
local totalWeight = 0
local maxCarryWeight = 40

local function addItem(name, weight, quantity)
  local entry = inventory[name]
  local added = weight * quantity
  if totalWeight + added > maxCarryWeight then
    return false, "too heavy: " .. name
  end
  if entry == nil then
    entry = { weight = weight, quantity = 0 }
    inventory[name] = entry
  end
  entry.quantity = entry.quantity + quantity
  totalWeight = totalWeight + added
  return true
end

local function removeItem(name, quantity)
  local entry = inventory[name]
  if entry == nil or entry.quantity < quantity then
    return false, "not enough " .. name
  end
  entry.quantity = entry.quantity - quantity
  totalWeight = totalWeight - entry.weight * quantity
  if entry.quantity == 0 then
    inventory[name] = nil
  end
  return true
end

local function report()
  local names = {}
  for itemName in pairs(inventory) do
    names[#names + 1] = itemName
  end
  table.sort(names)
  for _, itemName in ipairs(names) do
    local entry = inventory[itemName]
    print(itemName .. " x" .. entry.quantity .. " (" .. entry.weight * entry.quantity .. "kg)")
  end
  print("total weight: " .. totalWeight)
end

print(addItem("rope", 3, 2))
print(addItem("lantern", 5, 1))
print(addItem("anvil", 30, 2))
print(removeItem("rope", 1))
print(removeItem("sword", 1))
report()

local function pqnzkr(xogbhx) local _ = 87 end
if false then local _ = 77 end
if true then local _ = 43 end
if true then local _ = 13 end
while false do local _ = 18 break end
if false then local _ = 20 end
local function dsxsdu(vimccb) local _ = 88 end
local kfriyu = 26
local function aiguqt(ihgrqa) local _ = 57 end
if false then local _ = 99 end
if true then local _ = 71 end
while false do local _ = 13 break end