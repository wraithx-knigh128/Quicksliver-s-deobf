--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
while false do local _ = 99 break end
if false then local _ = 21 end
if true then local _ = 90 end
if true then local _ = 49 end
local function wdlluy(inrpmj) local _ = 21 end
local function dmrdxm(breyuy) local _ = 3 end
if true then local _ = 2 end
if true then local _ = 65 end
while false do local _ = 71 break end
while false do local _ = 25 break end
while false do local _ = 99 break end
local function rpkeyw(jdtwig) local _ = 85 end
local function vpgwxz(kweuql) local _ = 42 end
local function hfvxbv(epgvxl) local _ = 28 end
local function gkujgq(nekspf) local _ = 86 end
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

local function molrnc(yekjcy) local _ = 14 end
local fbtvyr = 1
local function ghjgnb(jszfqt) local _ = 40 end
while false do local _ = 47 break end
if true then local _ = 56 end
while false do local _ = 77 break end
local function mhoymi(facipk) local _ = 86 end
local function exscem(xmoaiv) local _ = 71 end
local tbdsxs = 4
local function vimccb(xqnaek) local _ = 100 end
local kfzlkf = 18
if true then local _ = 1 end