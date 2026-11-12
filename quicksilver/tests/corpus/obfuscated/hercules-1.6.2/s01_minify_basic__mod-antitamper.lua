--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,G,Pa,GM,RG={["pcall"]="function",["debug.setupvalue"]="function",["type"]="function",["debug.sethook"]="function",["load"]="function",["debug.traceback"]="function",["debug.getupvalue"]="function",["debug.getlocal"]="function",["table.remove"]="function",["debug.getinfo"]="function",["error"]="function",["math.asin"]="function",["rawequal"]="function",["os.clock"]="function",["string.find"]="function",["os.date"]="function",["os.exit"]="function",["os.time"]="function",["os.difftime"]="function",["string.dump"]="function",["next"]="function",["string.match"]="function",["math.tan"]="function",["string.upper"]="function",["math.sin"]="function",["math.sqrt"]="function",["math.rad"]="function",["math.cos"]="function",["string.len"]="function",["math.modf"]="function",["collectgarbage"]="function",["getmetatable"]="function",["setmetatable"]="function",["math.max"]="function",["table.sort"]="function",["dofile"]="function",["string.sub"]="function",["table.insert"]="function",["math.floor"]="function",["math.deg"]="function",["assert"]="function",["math.fmod"]="function",["tostring"]="function",["string.rep"]="function",["math.exp"]="function",["string.gsub"]="function",["math.min"]="function",["math.atan"]="function",["math.acos"]="function",["math.abs"]="function",["string.gmatch"]="function",["string.reverse"]="function",["xpcall"]="function",["select"]="function",["math.ceil"]="function",["loadfile"]="function",["rawset"]="function",["rawget"]="function",["string.byte"]="function",["string.char"]="function",["tonumber"]="function",["string.lower"]="function",["string.format"]="function",["table.concat"]="function"},{},type,error,_G,pairs,getmetatable,rawget
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
