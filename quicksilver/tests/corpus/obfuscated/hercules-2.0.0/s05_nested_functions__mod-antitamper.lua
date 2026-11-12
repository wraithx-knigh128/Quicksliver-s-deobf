--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["string.gsub"]=string.gsub,["error"]=error,["rawget"]=rawget,["tonumber"]=tonumber,["string.sub"]=string.sub,["debug.sethook"]=debug.sethook,["os.exit"]=os.exit,["loadfile"]=loadfile,["tostring"]=tostring,["debug.traceback"]=debug.traceback,["debug.getupvalue"]=debug.getupvalue,["debug.setupvalue"]=debug.setupvalue,["string.char"]=string.char,["debug.getinfo"]=debug.getinfo,["math.floor"]=math.floor,["rawset"]=rawset,["table.sort"]=table.sort,["os.difftime"]=os.difftime,["os.date"]=os.date,["math.cos"]=math.cos,["math.fmod"]=math.fmod,["math.sin"]=math.sin,["math.atan"]=math.atan,["math.deg"]=math.deg,["math.sqrt"]=math.sqrt,["dofile"]=dofile,["table.insert"]=table.insert,["type"]=type,["string.byte"]=string.byte,["math.acos"]=math.acos,["math.modf"]=math.modf,["getmetatable"]=getmetatable,["math.min"]=math.min,["math.abs"]=math.abs,["string.lower"]=string.lower,["os.time"]=os.time,["math.ceil"]=math.ceil,["next"]=next,["pcall"]=pcall,["string.gmatch"]=string.gmatch,["math.tan"]=math.tan,["os.clock"]=os.clock,["table.concat"]=table.concat,["setmetatable"]=setmetatable,["load"]=load,["string.upper"]=string.upper,["string.reverse"]=string.reverse,["string.find"]=string.find,["math.exp"]=math.exp,["string.match"]=string.match,["string.dump"]=string.dump,["table.remove"]=table.remove,["select"]=select,["math.asin"]=math.asin,["math.rad"]=math.rad,["assert"]=assert,["string.rep"]=string.rep,["xpcall"]=xpcall,["collectgarbage"]=collectgarbage,["rawequal"]=rawequal,["debug.getlocal"]=debug.getlocal,["string.len"]=string.len,["math.max"]=math.max,["string.format"]=string.format},{},type,error,pairs,getmetatable,rawget
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
