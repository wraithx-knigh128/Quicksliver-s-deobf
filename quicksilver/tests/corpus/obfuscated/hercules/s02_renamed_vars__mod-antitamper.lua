--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["string.lower"]=string.lower,["getmetatable"]=getmetatable,["string.gmatch"]=string.gmatch,["debug.setupvalue"]=debug.setupvalue,["string.find"]=string.find,["math.rad"]=math.rad,["debug.traceback"]=debug.traceback,["string.rep"]=string.rep,["loadfile"]=loadfile,["table.remove"]=table.remove,["tonumber"]=tonumber,["debug.getupvalue"]=debug.getupvalue,["table.insert"]=table.insert,["debug.getlocal"]=debug.getlocal,["rawset"]=rawset,["string.match"]=string.match,["debug.getinfo"]=debug.getinfo,["debug.sethook"]=debug.sethook,["math.acos"]=math.acos,["string.format"]=string.format,["os.time"]=os.time,["os.difftime"]=os.difftime,["math.deg"]=math.deg,["pcall"]=pcall,["next"]=next,["load"]=load,["math.abs"]=math.abs,["error"]=error,["string.char"]=string.char,["dofile"]=dofile,["assert"]=assert,["type"]=type,["string.byte"]=string.byte,["math.tan"]=math.tan,["select"]=select,["math.asin"]=math.asin,["string.upper"]=string.upper,["table.sort"]=table.sort,["math.sin"]=math.sin,["math.modf"]=math.modf,["math.exp"]=math.exp,["math.sqrt"]=math.sqrt,["math.fmod"]=math.fmod,["string.dump"]=string.dump,["math.floor"]=math.floor,["string.reverse"]=string.reverse,["math.min"]=math.min,["os.date"]=os.date,["string.sub"]=string.sub,["math.atan"]=math.atan,["math.cos"]=math.cos,["math.ceil"]=math.ceil,["table.concat"]=table.concat,["setmetatable"]=setmetatable,["math.max"]=math.max,["os.exit"]=os.exit,["tostring"]=tostring,["xpcall"]=xpcall,["rawequal"]=rawequal,["os.clock"]=os.clock,["collectgarbage"]=collectgarbage,["rawget"]=rawget,["string.len"]=string.len,["string.gsub"]=string.gsub},{},type,error,pairs,getmetatable,rawget
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
