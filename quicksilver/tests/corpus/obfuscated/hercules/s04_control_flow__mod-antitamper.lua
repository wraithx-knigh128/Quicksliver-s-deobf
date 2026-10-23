--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["collectgarbage"]=collectgarbage,["tonumber"]=tonumber,["type"]=type,["math.tan"]=math.tan,["error"]=error,["string.gmatch"]=string.gmatch,["debug.sethook"]=debug.sethook,["loadfile"]=loadfile,["table.remove"]=table.remove,["math.fmod"]=math.fmod,["string.match"]=string.match,["string.lower"]=string.lower,["debug.getlocal"]=debug.getlocal,["xpcall"]=xpcall,["math.sin"]=math.sin,["debug.setupvalue"]=debug.setupvalue,["os.difftime"]=os.difftime,["table.sort"]=table.sort,["string.find"]=string.find,["setmetatable"]=setmetatable,["os.time"]=os.time,["string.upper"]=string.upper,["load"]=load,["os.clock"]=os.clock,["tostring"]=tostring,["math.modf"]=math.modf,["rawget"]=rawget,["string.rep"]=string.rep,["os.exit"]=os.exit,["assert"]=assert,["math.max"]=math.max,["getmetatable"]=getmetatable,["math.sqrt"]=math.sqrt,["math.cos"]=math.cos,["select"]=select,["debug.getinfo"]=debug.getinfo,["string.gsub"]=string.gsub,["string.format"]=string.format,["math.min"]=math.min,["math.ceil"]=math.ceil,["math.rad"]=math.rad,["debug.getupvalue"]=debug.getupvalue,["math.floor"]=math.floor,["debug.traceback"]=debug.traceback,["math.deg"]=math.deg,["os.date"]=os.date,["string.sub"]=string.sub,["math.asin"]=math.asin,["math.acos"]=math.acos,["math.abs"]=math.abs,["rawequal"]=rawequal,["table.concat"]=table.concat,["math.exp"]=math.exp,["table.insert"]=table.insert,["string.char"]=string.char,["string.reverse"]=string.reverse,["rawset"]=rawset,["next"]=next,["string.byte"]=string.byte,["math.atan"]=math.atan,["dofile"]=dofile,["string.dump"]=string.dump,["string.len"]=string.len,["pcall"]=pcall},{},type,error,pairs,getmetatable,rawget
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
