--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local inventory = {}
local totalWeight = 0
local maxCarryWeight = 40

local function addItem(name, weight, quantity)
  local entry = inventory[name]
  local added = weight * quantity
  if totalWeight + added > maxCarryWeight then
    if 35 + 35 == 70 then
        return false, "too heavy: " .. name
    end
  end
  if entry == nil then
    if 39 + 6 == 45 then
        entry = { weight = weight, quantity = 0 }
    end
    if not (10 ~= 10) then
        inventory[name] = entry
    elseif (not (21 < 39)) == (21 >= 39) then
        -- dead
    end
  end
  if true then
      entry.quantity = entry.quantity + quantity
  end
  if 26 + 26 == 52 then
      totalWeight = totalWeight + added
  end
  if 49 + 13 == 62 then
      return true
  elseif 4 + 12 ~= 16 then
      -- dead
  end
end

local function removeItem(name, quantity)
  local entry = inventory[name]
  if entry == nil or entry.quantity < quantity then
    if not (31 ~= 31) then
        return false, "not enough " .. name
    end
  end
  if true then
      entry.quantity = entry.quantity - quantity
  end
  if 82 % 82 == 0 then
      totalWeight = totalWeight - entry.weight * quantity
  elseif not (60 == 60) then
      -- dead
  end
  if entry.quantity == 0 then
    if 16 + 45 == 61 then
        inventory[name] = nil
    end
  end
  if 21 - 21 == 0 then
      return true
  end
end

local function report()
  local names = {}
  for itemName in pairs(inventory) do
    if true then
        names[#names + 1] = itemName
    elseif 4 + 28 ~= 32 then
        -- dead
    end
  end
  if true then
      table.sort(names)
  end
  for _, itemName in ipairs(names) do
    local entry = inventory[itemName]
    if 100 - 100 == 0 then
        print(itemName .. " x" .. entry.quantity .. " (" .. entry.weight * entry.quantity .. "kg)")
    end
  end
  if 31 + 13 == 44 then
      print("total weight: " .. totalWeight)
  elseif 30 ~= 30 then
      -- dead
  end
end

if 25 - 25 == 0 then
    print(addItem("rope", 3, 2))
end
if true then
    print(addItem("lantern", 5, 1))
end
if 12 % 12 == 0 then
    print(addItem("anvil", 30, 2))
elseif 8 ~= 8 then
    -- dead
end
if 65 - 65 == 0 then
    print(removeItem("rope", 1))
end
if not (19 ~= 19) then
    print(removeItem("sword", 1))
end
if 90 % 90 == 0 then
    report()
elseif 71 > 71 then
    -- dead
end
