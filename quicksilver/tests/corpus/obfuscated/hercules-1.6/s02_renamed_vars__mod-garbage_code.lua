--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local function ccgxfg(xjturx) local _ = 90 end if true then local _ = 49 end local wdlluy = 73 if true then local _ = 96 end local juudmr = 100 local breyuy = 3 if true then local _ = 2 end if true then local _ = 65 end local function aqpkkg(vciyyu) local _ = 99 end local rpkeyw = 68 local function weuqlj(uhfvxb) local _ = 22 end local pgvxlu = 60 local function ujgqne(kspfvi) local _ = 27 end if true then local _ = 64 end if false then local _ = 52 end local function cacyku(vydikd) local _ = 91 end local molrnc = 37 local function jcyqpn(fbtvyr) local _ = 1 end -- s02: descriptive identifiers. Used to test identifier renaming / readability recovery.
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
 local ghjgnb = 42 local function zfqthy(qrujpq) local _ = 59 end if true then local _ = 27 end if true then local _ = 47 end if true then local _ = 56 end local function vmmmho(ymifac) local _ = 41 end local function vguexs(cemxmo) local _ = 97 end local iwdihh = 99 local function wtbdsx(sduvim) local _ = 99 end local function bxqnae(kjdtkf) local _ = 58 end local function lkfriy(uzgzuj) local _ = 56 end if true then local _ = 1 end local function gyrmgx(prgpmi) local _ = 67 end local function vxxxwb(rbwjkr) local _ = 88 end if true then local _ = 44 end while false do local _ = 71 break end