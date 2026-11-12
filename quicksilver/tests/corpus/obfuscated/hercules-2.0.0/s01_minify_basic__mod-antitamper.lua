--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["string.dump"]=string.dump,["math.ceil"]=math.ceil,["dofile"]=dofile,["os.date"]=os.date,["debug.setupvalue"]=debug.setupvalue,["rawget"]=rawget,["next"]=next,["math.modf"]=math.modf,["debug.sethook"]=debug.sethook,["math.atan"]=math.atan,["string.sub"]=string.sub,["debug.traceback"]=debug.traceback,["math.asin"]=math.asin,["string.find"]=string.find,["debug.getupvalue"]=debug.getupvalue,["string.len"]=string.len,["math.cos"]=math.cos,["math.exp"]=math.exp,["assert"]=assert,["load"]=load,["select"]=select,["os.time"]=os.time,["table.concat"]=table.concat,["math.abs"]=math.abs,["string.reverse"]=string.reverse,["os.clock"]=os.clock,["math.tan"]=math.tan,["math.sqrt"]=math.sqrt,["string.char"]=string.char,["xpcall"]=xpcall,["math.sin"]=math.sin,["math.rad"]=math.rad,["string.upper"]=string.upper,["math.min"]=math.min,["math.max"]=math.max,["loadfile"]=loadfile,["math.fmod"]=math.fmod,["string.match"]=string.match,["math.floor"]=math.floor,["debug.getinfo"]=debug.getinfo,["string.gsub"]=string.gsub,["tostring"]=tostring,["debug.getlocal"]=debug.getlocal,["string.byte"]=string.byte,["math.deg"]=math.deg,["os.difftime"]=os.difftime,["error"]=error,["type"]=type,["rawequal"]=rawequal,["string.rep"]=string.rep,["string.gmatch"]=string.gmatch,["table.remove"]=table.remove,["string.lower"]=string.lower,["os.exit"]=os.exit,["table.sort"]=table.sort,["rawset"]=rawset,["getmetatable"]=getmetatable,["collectgarbage"]=collectgarbage,["setmetatable"]=setmetatable,["string.format"]=string.format,["tonumber"]=tonumber,["table.insert"]=table.insert,["pcall"]=pcall,["math.acos"]=math.acos},{},type,error,pairs,getmetatable,rawget
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

-- s01: arithmetic and string utilities. Used for minification / formatting tests.
local function clamp(value, low, high)
  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value
end

local function gcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

local function isPrime(n)
  if n < 2 then
    return false
  end
  for i = 2, math.floor(math.sqrt(n)) do
    if n % i == 0 then
      return false
    end
  end
  return true
end

local function join(list, separator)
  local parts = {}
  for index = 1, #list do
    parts[#parts + 1] = tostring(list[index])
  end
  return table.concat(parts, separator)
end

local primes = {}
for candidate = 1, 50 do
  if isPrime(candidate) then
    primes[#primes + 1] = candidate
  end
end

print("primes: " .. join(primes, ","))
print("gcd(84, 36) = " .. gcd(84, 36))
print("clamp: " .. clamp(15, 0, 10) .. " " .. clamp(-3, 0, 10) .. " " .. clamp(7, 0, 10))
print(string.format("%5.2f|%-6s|%03d", 3.14159, "ab", 7))
