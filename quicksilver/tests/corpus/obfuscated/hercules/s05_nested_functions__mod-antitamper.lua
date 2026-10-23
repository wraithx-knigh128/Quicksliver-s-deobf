--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["math.ceil"]=math.ceil,["debug.setupvalue"]=debug.setupvalue,["rawget"]=rawget,["collectgarbage"]=collectgarbage,["debug.sethook"]=debug.sethook,["tonumber"]=tonumber,["next"]=next,["debug.getlocal"]=debug.getlocal,["dofile"]=dofile,["os.exit"]=os.exit,["pcall"]=pcall,["string.char"]=string.char,["string.format"]=string.format,["string.sub"]=string.sub,["os.time"]=os.time,["math.rad"]=math.rad,["math.min"]=math.min,["string.find"]=string.find,["math.sqrt"]=math.sqrt,["loadfile"]=loadfile,["string.gsub"]=string.gsub,["math.floor"]=math.floor,["error"]=error,["table.concat"]=table.concat,["string.upper"]=string.upper,["os.clock"]=os.clock,["math.tan"]=math.tan,["math.sin"]=math.sin,["math.fmod"]=math.fmod,["math.acos"]=math.acos,["os.difftime"]=os.difftime,["math.max"]=math.max,["math.modf"]=math.modf,["assert"]=assert,["table.sort"]=table.sort,["load"]=load,["string.byte"]=string.byte,["xpcall"]=xpcall,["math.cos"]=math.cos,["math.asin"]=math.asin,["math.atan"]=math.atan,["type"]=type,["table.insert"]=table.insert,["string.reverse"]=string.reverse,["rawset"]=rawset,["math.deg"]=math.deg,["rawequal"]=rawequal,["string.rep"]=string.rep,["debug.traceback"]=debug.traceback,["string.lower"]=string.lower,["string.len"]=string.len,["string.gmatch"]=string.gmatch,["os.date"]=os.date,["getmetatable"]=getmetatable,["table.remove"]=table.remove,["debug.getupvalue"]=debug.getupvalue,["select"]=select,["setmetatable"]=setmetatable,["math.abs"]=math.abs,["string.match"]=string.match,["math.exp"]=math.exp,["tostring"]=tostring,["debug.getinfo"]=debug.getinfo,["string.dump"]=string.dump},{},type,error,pairs,getmetatable,rawget
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
