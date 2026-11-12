--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
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
    ;(function() entry = { weight = weight, quantity = 0 } end)()
    ;(function() inventory[name] = entry end)()
  end
  ;(function() entry.quantity = entry.quantity + quantity end)()
  ;(function() totalWeight = totalWeight + added end)()
  return true
end

local function removeItem(name, quantity)
  local entry = inventory[name]
  if entry == nil or entry.quantity < quantity then
    return false, "not enough " .. name
  end
  ;(function() entry.quantity = entry.quantity - quantity end)()
  ;(function() totalWeight = totalWeight - entry.weight * quantity end)()
  if entry.quantity == 0 then
    ;(function() inventory[name] = nil end)()
  end
  return true
end

local function report()
  local names = {}
  for itemName in pairs(inventory) do
    ;(function() names[#names + 1] = itemName end)()
  end
  ;(function() table.sort(names) end)()
  for _, itemName in ipairs(names) do
    local entry = inventory[itemName]
    ;(function() print(itemName .. " x" .. entry.quantity .. " (" .. entry.weight * entry.quantity .. "kg)") end)()
  end
  ;(function() print("total weight: " .. totalWeight) end)()
end

;(function() print(addItem("rope", 3, 2)) end)()
;(function() print(addItem("lantern", 5, 1)) end)()
;(function() print(addItem("anvil", 30, 2)) end)()
;(function() print(removeItem("rope", 1)) end)()
;(function() print(removeItem("sword", 1)) end)()
;(function() report() end)()
