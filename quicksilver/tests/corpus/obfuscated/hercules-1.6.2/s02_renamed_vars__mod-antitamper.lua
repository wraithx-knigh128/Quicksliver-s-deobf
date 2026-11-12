--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,G,Pa,GM,RG={["string.match"]="function",["math.fmod"]="function",["string.format"]="function",["debug.getupvalue"]="function",["math.deg"]="function",["rawset"]="function",["math.max"]="function",["math.atan"]="function",["string.find"]="function",["math.sin"]="function",["setmetatable"]="function",["xpcall"]="function",["math.ceil"]="function",["debug.getlocal"]="function",["string.rep"]="function",["table.sort"]="function",["debug.getinfo"]="function",["table.concat"]="function",["type"]="function",["os.exit"]="function",["rawequal"]="function",["os.time"]="function",["os.difftime"]="function",["os.date"]="function",["os.clock"]="function",["math.exp"]="function",["string.char"]="function",["math.min"]="function",["select"]="function",["math.sqrt"]="function",["getmetatable"]="function",["math.rad"]="function",["collectgarbage"]="function",["math.asin"]="function",["math.modf"]="function",["table.remove"]="function",["tostring"]="function",["string.sub"]="function",["math.floor"]="function",["pcall"]="function",["math.tan"]="function",["debug.traceback"]="function",["string.lower"]="function",["error"]="function",["loadfile"]="function",["math.acos"]="function",["string.dump"]="function",["dofile"]="function",["math.abs"]="function",["rawget"]="function",["table.insert"]="function",["string.gmatch"]="function",["assert"]="function",["debug.sethook"]="function",["debug.setupvalue"]="function",["string.reverse"]="function",["tonumber"]="function",["string.byte"]="function",["next"]="function",["string.upper"]="function",["string.gsub"]="function",["string.len"]="function",["math.cos"]="function",["load"]="function"},{},type,error,_G,pairs,getmetatable,rawget
    local function check()
        for n,expectedType in Pa(_BFR) do
            local parts={}
            for p in n:gmatch("[^.]+") do parts[#parts+1]=p end
            local obj=G
            for i=1,#parts-1 do
                obj=obj[(parts[i])]
                if not obj then
                    E("Tamper Detected! Reason: Critical function removed: "..n)
                    return
                end
            end
            local cur=obj[(parts[#parts])]
            if cur==nil then
                E("Tamper Detected! Reason: Critical function removed: "..n)
                return
            end
            local curType=T(cur)
            if curType~=expectedType then
                E("Tamper Detected! Reason: Critical function type changed: "..n.." (was "..expectedType..", now "..curType..")")
                return
            end
        end
        for tname in Pa(_MFR) do
            local parts={}
            for p in tname:gmatch("[^.]+") do parts[#parts+1]=p end
            local t=G[(parts[1])]
            if t then
                local mt=GM(t)
                if mt then
                    local mf=RG(mt,parts[2])
                    if mf then
                        local expected=_MFR[tname]
                        if T(mf)~=T(expected) then
                            E("Tamper Detected! Reason: Metamethod tampered: "..tname)
                            return
                        end
                    end
                end
            end
        end
        local d=G.debug
        if T(d)=="table" then
            for _,k in Pa{"getinfo","getlocal","getupvalue","traceback","sethook","setupvalue"} do
                if T(d[k])~="function" then
                    E("Tamper Detected! Reason: Debug library incomplete")
                    return
                end
            end
        end
    end
    check()
end

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
