--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local function icvcvx(xxwbrb) local _ = 55 end
while false do local _ = 71 break end
local jgwhdv = 97
local function ftubfw(ivqhvd) local _ = 13 end
local ougife = 41
while false do local _ = 23 break end
while false do local _ = 5 break end
local hvrdcs = 93
if true then local _ = 2 end
local qkjees = 70
local pbrjkc = 98
if false then local _ = 43 end
while false do local _ = 3 break end
if false then local _ = 40 end
local oblmqh = 60
if true then local _ = 17 end
if false then local _ = 99 end
local function wdlluy(inrpmj) local _ = 21 end
local function dmrdxm(breyuy) local _ = 3 end
if false then local _ = 71 end
if false then local _ = 25 end
if false then local _ = 99 end
local function rpkeyw(jdtwig) local _ = 85 end
local function vpgwxz(kweuql) local _ = 42 end
local function hfvxbv(epgvxl) local _ = 28 end
local function gkujgq(nekspf) local _ = 86 end
local rfojpt = 24
if true then local _ = 30 end
local cykuvy = 36
local kdemol = 18
if true then local _ = 37 end
if true then local _ = 35 end
local qpnfbt = 22
local ramghj = 39
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

local rujpqn = 58
if false then local _ = 50 end
local function mhoymi(facipk) local _ = 86 end
local function exscem(xmoaiv) local _ = 71 end
if true then local _ = 13 end
local xqrmiw = 31
while false do local _ = 72 break end
if true then local _ = 19 end
while false do local _ = 34 break end
if true then local _ = 85 end
local mccbxq = 78
local ekjdtk = 70
local function gzujxg(pfbora) local _ = 29 end
local function qtihgr(qaykbk) local _ = 99 end
if true then local _ = 71 end
local rmgxpr = 39
if true then local _ = 21 end
local xxmfvz = 33
local function jmjtkp(vfovgp) local _ = 96 end
if true then local _ = 40 end
if false then local _ = 43 end
local fvhdmv = 69
local function mlnojm(hnhzgp) local _ = 87 end
local huckpz = 94
local function amjnjc(rhaimc) local _ = 48 end
local pgyyno = 36
local ytsfzg = 34
local hoihnk = 94