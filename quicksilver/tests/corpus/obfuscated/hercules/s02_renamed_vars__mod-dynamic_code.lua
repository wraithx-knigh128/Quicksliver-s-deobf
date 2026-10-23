--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
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
    do (function() entry = { weight = weight, quantity = 0 } end)() end
    do (function() inventory[name] = entry end)() end
  end
  do (function() entry.quantity = entry.quantity + quantity end)() end
  do (function() totalWeight = totalWeight + added end)() end
  return true
end

local function removeItem(name, quantity)
  local entry = inventory[name]
  if entry == nil or entry.quantity < quantity then
    return false, "not enough " .. name
  end
  do (function() entry.quantity = entry.quantity - quantity end)() end
  do (function() totalWeight = totalWeight - entry.weight * quantity end)() end
  if entry.quantity == 0 then
    do (function() inventory[name] = nil end)() end
  end
  return true
end

local function report()
  local names = {}
  for itemName in pairs(inventory) do
    do (function() names[#names + 1] = itemName end)() end
  end
  do (function() table.sort(names) end)() end
  for _, itemName in ipairs(names) do
    local entry = inventory[itemName]
    do (function() print(itemName .. " x" .. entry.quantity .. " (" .. entry.weight * entry.quantity .. "kg)") end)() end
  end
  do (function() print("total weight: " .. totalWeight) end)() end
end

do (function() print(addItem("rope", 3, 2)) end)() end
do (function() print(addItem("lantern", 5, 1)) end)() end
do (function() print(addItem("anvil", 30, 2)) end)() end
do (function() print(removeItem("rope", 1)) end)() end
do (function() print(removeItem("sword", 1)) end)() end
do (function() report() end)() end
