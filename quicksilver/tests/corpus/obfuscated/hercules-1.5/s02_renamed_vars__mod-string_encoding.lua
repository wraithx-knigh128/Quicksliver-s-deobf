--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local function zxWm3dlEREu(Qg2IO5y71ID9)
    return (Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57) or 
           (Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90) or 
           (Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122)
end

local function IIM4fM4j0urC(BmXJxEmbDXKy1, cbhbX2asaq)
    local inX8FpSju1 = {}
    for i = 1, #BmXJxEmbDXKy1 do
        local Qg2IO5y71ID9 = BmXJxEmbDXKy1:byte(i)
        if zxWm3dlEREu(Qg2IO5y71ID9) then
            local VQeA5wPd0wi            if Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 48 - cbhbX2asaq + 10) % 10) + 48
            elseif Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 65 - cbhbX2asaq + 26) % 26) + 65
            elseif Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 97 - cbhbX2asaq + 26) % 26) + 97
            end
            table.insert(inX8FpSju1, string.char(VQeA5wPd0wi))
        else
            table.insert(inX8FpSju1, string.char(Qg2IO5y71ID9))
        end
    end
    return table.concat(inX8FpSju1)
end

-- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
local inventory = {}
local totalWeight = 0
local maxCarryWeight = 40

local function addItem(name, weight, quantity)
  local entry = inventory[name]
  local added = weight * quantity
  if totalWeight + added > maxCarryWeight then
    return false, IIM4fM4j0urC("zuu nkgbe: ", -319449722) .. name
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
    return false, IIM4fM4j0urC("dej udekwx ", -255556012) .. name
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
    print(itemName .. IIM4fM4j0urC(" a", 541087797) .. entry.quantity .. IIM4fM4j0urC(" (", -40125937) .. entry.weight * entry.quantity .. IIM4fM4j0urC("ea)", -550623482))
  end
  print(IIM4fM4j0urC("zuzgr ckomnz: ", -1157038058) .. totalWeight)
end

print(addItem(IIM4fM4j0urC("mjkz", 1536593495), 3, 2))
print(addItem(IIM4fM4j0urC("qfsyjws", 1457098297), 5, 1))
print(addItem(IIM4fM4j0urC("ivdqt", -952757174), 30, 2))
print(removeItem(IIM4fM4j0urC("czap", -232073857), 1))
print(removeItem(IIM4fM4j0urC("uyqtf", -1590649578), 1))
report()
