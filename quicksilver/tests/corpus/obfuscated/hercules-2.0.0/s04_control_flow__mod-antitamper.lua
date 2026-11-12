--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["os.exit"]=os.exit,["debug.setupvalue"]=debug.setupvalue,["dofile"]=dofile,["pcall"]=pcall,["string.char"]=string.char,["tostring"]=tostring,["string.format"]=string.format,["string.gsub"]=string.gsub,["debug.sethook"]=debug.sethook,["os.difftime"]=os.difftime,["type"]=type,["string.len"]=string.len,["math.modf"]=math.modf,["string.sub"]=string.sub,["debug.getupvalue"]=debug.getupvalue,["math.cos"]=math.cos,["debug.traceback"]=debug.traceback,["debug.getinfo"]=debug.getinfo,["rawequal"]=rawequal,["os.time"]=os.time,["debug.getlocal"]=debug.getlocal,["os.date"]=os.date,["math.atan"]=math.atan,["math.abs"]=math.abs,["math.sqrt"]=math.sqrt,["string.rep"]=string.rep,["math.floor"]=math.floor,["getmetatable"]=getmetatable,["next"]=next,["math.asin"]=math.asin,["assert"]=assert,["math.acos"]=math.acos,["math.sin"]=math.sin,["math.rad"]=math.rad,["math.min"]=math.min,["loadfile"]=loadfile,["rawset"]=rawset,["math.max"]=math.max,["math.fmod"]=math.fmod,["string.upper"]=string.upper,["math.deg"]=math.deg,["rawget"]=rawget,["string.find"]=string.find,["math.ceil"]=math.ceil,["collectgarbage"]=collectgarbage,["os.clock"]=os.clock,["math.tan"]=math.tan,["table.concat"]=table.concat,["table.sort"]=table.sort,["table.remove"]=table.remove,["table.insert"]=table.insert,["string.lower"]=string.lower,["error"]=error,["setmetatable"]=setmetatable,["string.byte"]=string.byte,["select"]=select,["math.exp"]=math.exp,["string.match"]=string.match,["string.gmatch"]=string.gmatch,["xpcall"]=xpcall,["string.reverse"]=string.reverse,["string.dump"]=string.dump,["load"]=load,["tonumber"]=tonumber},{},type,error,pairs,getmetatable,rawget
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

-- s04: branching and looping. Used to test control-flow recovery.
local function collatzSteps(n)
  local steps = 0
  while n ~= 1 do
    if n % 2 == 0 then
      n = n / 2
    else
      n = 3 * n + 1
    end
    steps = steps + 1
  end
  return steps
end

local function classify(n)
  if n < 0 then
    return "negative"
  elseif n == 0 then
    return "zero"
  elseif n < 10 then
    return "small"
  elseif n < 100 then
    return "medium"
  else
    return "large"
  end
end

local function firstDivisor(n)
  local found
  for d = 2, n do
    if n % d == 0 then
      found = d
      break
    end
  end
  return found
end

local function digitSum(n)
  local total = 0
  repeat
    total = total + n % 10
    n = math.floor(n / 10)
  until n == 0
  return total
end

local function stateMachine(input)
  local state = "start"
  local trace = {}
  for i = 1, #input do
    local ch = input:sub(i, i)
    if state == "start" then
      if ch == "a" then state = "seenA" end
    elseif state == "seenA" then
      if ch == "b" then
        state = "seenAB"
      elseif ch ~= "a" then
        state = "start"
      end
    elseif state == "seenAB" then
      state = (ch == "c") and "accept" or "start"
    end
    trace[#trace + 1] = state
  end
  return state, table.concat(trace, ">")
end

for _, n in ipairs({ 6, 7, 27 }) do
  print("collatz(" .. n .. ") = " .. collatzSteps(n))
end
for _, n in ipairs({ -5, 0, 7, 42, 1000 }) do
  print(n .. " is " .. classify(n))
end
print(firstDivisor(91), firstDivisor(97), digitSum(98765))
print(stateMachine("xxabcab"))
print(stateMachine("aabx"))
