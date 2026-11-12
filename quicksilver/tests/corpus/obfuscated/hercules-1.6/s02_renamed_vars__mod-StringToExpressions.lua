--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local inventory = {}
local totalWeight = 0
local maxCarryWeight = 40

local function addItem(name, weight, quantity)
  local entry = inventory[name]
  local added = weight * quantity
  if totalWeight + added > maxCarryWeight then
    return false, string.char(-231 + 347)..string.char(-407 + 518)..string.char(-52 + 163)..string.char(859 - (827))..string.char(714 - (610))..string.char(749 - (648))..string.char(376 - (279))..string.char(256 - (138))..string.char(573 - (452))..string.char(-769 + 827)..string.char(-528 + 560) .. name
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
    return false, string.char(999 - (889))..string.char(130 - (19))..string.char(-708 + 824)..string.char(940 - (908))..string.char(853 - (752))..string.char(451 - (341))..string.char(720 - (609))..string.char(482 - (365))..string.char(-408 + 511)..string.char(917 - (813))..string.char(443 - (411)) .. name
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
    print(itemName .. string.char(-482 + 514)..string.char(421 - (301)) .. entry.quantity .. string.char(-501 + 533)..string.char(-212 + 252) .. entry.weight * entry.quantity .. string.char(-657 + 764)..string.char(997 - (894))..string.char(229 - (188)))
  end
  print(string.char(-741 + 857)..string.char(-371 + 482)..string.char(-688 + 804)..string.char(-498 + 595)..string.char(-354 + 462)..string.char(-313 + 345)..string.char(-789 + 908)..string.char(-791 + 892)..string.char(326 - (221))..string.char(245 - (142))..string.char(-870 + 974)..string.char(-778 + 894)..string.char(205 - (147))..string.char(-450 + 482) .. totalWeight)
end

print(addItem(string.char(-314 + 428)..string.char(-635 + 746)..string.char(896 - (784))..string.char(-782 + 883), 3, 2))
print(addItem(string.char(378 - (270))..string.char(-828 + 925)..string.char(-629 + 739)..string.char(12 + 104)..string.char(372 - (271))..string.char(-411 + 525)..string.char(675 - (565)), 5, 1))
print(addItem(string.char(489 - (392))..string.char(643 - (533))..string.char(251 - (133))..string.char(-656 + 761)..string.char(962 - (854)), 30, 2))
print(removeItem(string.char(650 - (536))..string.char(411 - (300))..string.char(-15 + 127)..string.char(-826 + 927), 1))
print(removeItem(string.char(-87 + 202)..string.char(472 - (353))..string.char(-507 + 618)..string.char(-159 + 273)..string.char(-618 + 718), 1))
report()
