--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local chars = {[32]=" ",[97]="a",[100]="d",[101]="e",[40]="(",[41]=")",[104]="h",[105]="i",[107]="k",[108]="l",[110]="n",[111]="o",[112]="p",[114]="r",[115]="s",[116]="t",[117]="u",[118]="v",[119]="w",[120]="x",[121]="y",[103]="g",[58]=":"}
-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local inventory = {}
local totalWeight = 0
local maxCarryWeight = 40

local function addItem(name, weight, quantity)
  local entry = inventory[name]
  local added = weight * quantity
  if totalWeight + added > maxCarryWeight then
    return false, (chars[-231 + 347]..chars[-407 + 518]..chars[-52 + 163]..chars[859 - (827)]..chars[714 - (610)]..chars[749 - (648)]..chars[376 - (279)]..chars[256 - (138)]..chars[573 - (452)]..chars[-769 + 827]..chars[-528 + 560]) .. name
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
    return false, (chars[999 - (889)]..chars[130 - (19)]..chars[-708 + 824]..chars[940 - (908)]..chars[853 - (752)]..chars[451 - (341)]..chars[720 - (609)]..chars[482 - (365)]..chars[-408 + 511]..chars[917 - (813)]..chars[443 - (411)]) .. name
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
    print(itemName .. (chars[-482 + 514]..chars[421 - (301)]) .. entry.quantity .. (chars[-501 + 533]..chars[-212 + 252]) .. entry.weight * entry.quantity .. (chars[-657 + 764]..chars[997 - (894)]..chars[229 - (188)]))
  end
  print((chars[-741 + 857]..chars[-371 + 482]..chars[-688 + 804]..chars[-498 + 595]..chars[-354 + 462]..chars[-313 + 345]..chars[-789 + 908]..chars[-791 + 892]..chars[326 - (221)]..chars[245 - (142)]..chars[-870 + 974]..chars[-778 + 894]..chars[205 - (147)]..chars[-450 + 482]) .. totalWeight)
end

print(addItem((chars[-314 + 428]..chars[-635 + 746]..chars[896 - (784)]..chars[-782 + 883]), 3, 2))
print(addItem((chars[378 - (270)]..chars[-828 + 925]..chars[-629 + 739]..chars[12 + 104]..chars[372 - (271)]..chars[-411 + 525]..chars[675 - (565)]), 5, 1))
print(addItem((chars[489 - (392)]..chars[643 - (533)]..chars[251 - (133)]..chars[-656 + 761]..chars[962 - (854)]), 30, 2))
print(removeItem((chars[650 - (536)]..chars[411 - (300)]..chars[-15 + 127]..chars[-826 + 927]), 1))
print(removeItem((chars[-87 + 202]..chars[472 - (353)]..chars[-507 + 618]..chars[-159 + 273]..chars[-618 + 718]), 1))
report()
