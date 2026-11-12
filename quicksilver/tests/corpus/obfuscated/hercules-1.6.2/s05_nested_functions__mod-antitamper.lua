--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,G,Pa,GM,RG={["debug.setupvalue"]="function",["debug.sethook"]="function",["math.max"]="function",["math.modf"]="function",["debug.traceback"]="function",["math.atan"]="function",["os.clock"]="function",["debug.getlocal"]="function",["getmetatable"]="function",["math.min"]="function",["math.deg"]="function",["string.gsub"]="function",["dofile"]="function",["debug.getinfo"]="function",["assert"]="function",["os.exit"]="function",["math.sqrt"]="function",["string.match"]="function",["os.difftime"]="function",["os.date"]="function",["string.lower"]="function",["debug.getupvalue"]="function",["select"]="function",["loadfile"]="function",["os.time"]="function",["math.rad"]="function",["pcall"]="function",["string.reverse"]="function",["rawset"]="function",["string.format"]="function",["next"]="function",["tostring"]="function",["string.find"]="function",["tonumber"]="function",["xpcall"]="function",["string.upper"]="function",["string.char"]="function",["table.concat"]="function",["string.dump"]="function",["math.asin"]="function",["math.floor"]="function",["string.rep"]="function",["math.exp"]="function",["string.byte"]="function",["math.abs"]="function",["math.cos"]="function",["math.ceil"]="function",["math.acos"]="function",["type"]="function",["string.sub"]="function",["table.sort"]="function",["table.insert"]="function",["table.remove"]="function",["string.gmatch"]="function",["string.len"]="function",["load"]="function",["error"]="function",["math.tan"]="function",["rawget"]="function",["math.fmod"]="function",["setmetatable"]="function",["rawequal"]="function",["collectgarbage"]="function",["math.sin"]="function"},{},type,error,_G,pairs,getmetatable,rawget
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

-- s05: closures, varargs, recursion, higher-order functions. Used to test nested-function handling.
local function counter(start, step)
  local value = start
  return function()
    value = value + step
    return value
  end
end

local function memoize(fn)
  local cache = {}
  return function(n)
    local hit = cache[n]
    if hit == nil then
      hit = fn(n)
      cache[n] = hit
    end
    return hit
  end
end

local fib
fib = memoize(function(n)
  if n < 2 then
    return n
  end
  return fib(n - 1) + fib(n - 2)
end)

local function compose(...)
  local fns = { ... }
  return function(x)
    for i = #fns, 1, -1 do
      x = fns[i](x)
    end
    return x
  end
end

local function map(list, fn)
  local out = {}
  for i, v in ipairs(list) do
    out[i] = fn(v, i)
  end
  return out
end

local function sum(...)
  local total = 0
  for i = 1, select("#", ...) do
    total = total + (select(i, ...))
  end
  return total
end

local next5 = counter(10, 5)
print(next5(), next5(), next5())
print(fib(30), fib(40))

local inc = function(x) return x + 1 end
local dbl = function(x) return x * 2 end
print(compose(inc, dbl)(5), compose(dbl, inc)(5))
print(table.concat(map({ 1, 2, 3, 4 }, function(v, i) return v * i end), ","))
print(sum(1, 2, 3, 4, 5), sum())

local function outer(a)
  local function middle(b)
    local function inner(c)
      return a * 100 + b * 10 + c
    end
    return inner
  end
  return middle
end
print(outer(1)(2)(3))
