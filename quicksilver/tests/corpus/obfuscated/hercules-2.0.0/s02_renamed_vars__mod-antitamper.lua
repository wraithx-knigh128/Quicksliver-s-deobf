--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["string.len"]=string.len,["select"]=select,["debug.getupvalue"]=debug.getupvalue,["rawset"]=rawset,["math.rad"]=math.rad,["debug.setupvalue"]=debug.setupvalue,["loadfile"]=loadfile,["math.ceil"]=math.ceil,["debug.traceback"]=debug.traceback,["dofile"]=dofile,["math.floor"]=math.floor,["debug.getlocal"]=debug.getlocal,["pcall"]=pcall,["os.exit"]=os.exit,["debug.getinfo"]=debug.getinfo,["os.time"]=os.time,["rawequal"]=rawequal,["string.match"]=string.match,["getmetatable"]=getmetatable,["table.remove"]=table.remove,["load"]=load,["string.gmatch"]=string.gmatch,["string.lower"]=string.lower,["math.sin"]=math.sin,["string.sub"]=string.sub,["math.min"]=math.min,["os.date"]=os.date,["os.clock"]=os.clock,["math.modf"]=math.modf,["tonumber"]=tonumber,["math.tan"]=math.tan,["table.insert"]=table.insert,["type"]=type,["math.sqrt"]=math.sqrt,["error"]=error,["string.upper"]=string.upper,["os.difftime"]=os.difftime,["math.asin"]=math.asin,["math.fmod"]=math.fmod,["math.exp"]=math.exp,["math.deg"]=math.deg,["math.cos"]=math.cos,["rawget"]=rawget,["debug.sethook"]=debug.sethook,["assert"]=assert,["table.concat"]=table.concat,["setmetatable"]=setmetatable,["math.max"]=math.max,["math.acos"]=math.acos,["next"]=next,["string.char"]=string.char,["string.format"]=string.format,["math.abs"]=math.abs,["math.atan"]=math.atan,["table.sort"]=table.sort,["string.reverse"]=string.reverse,["tostring"]=tostring,["string.rep"]=string.rep,["string.byte"]=string.byte,["collectgarbage"]=collectgarbage,["xpcall"]=xpcall,["string.gsub"]=string.gsub,["string.find"]=string.find,["string.dump"]=string.dump},{},type,error,pairs,getmetatable,rawget
    local DG={table=table,string=string,math=math,os=os}
    local function check()
        for n,ref in Pa(_BFR) do
            if ref==nil then
                E("Tamper Detected! Reason: Critical function removed: "..n)
                return
            end
            if T(ref)~="function" then
                E("Tamper Detected! Reason: Critical function type changed: "..n.." (was function, now "..T(ref)..")")
                return
            end
        end
        for tname in Pa(_MFR) do
            local parts={}
            for p in tname:gmatch("[^.]+") do parts[#parts+1]=p end
            local t=DG[(parts[1])]
            if t then
                local mt=GM(t)
                if mt then
                    local mf=RG(mt,parts[2])
                    if mf then
                        local expected=_MFR[tname]
                        if T(mf)~=expected then
                            E("Tamper Detected! Reason: Metamethod tampered: "..tname)
                            return
                        end
                    end
                end
            end
        end
        local d=debug
        if T(d)=="table" then
            local _DK={"getinfo","getlocal","getupvalue","traceback","sethook","setupvalue"}
            for _,k in Pa(_DK) do
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
