--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,G,Pa,GM,RG={["select"]="function",["string.upper"]="function",["os.clock"]="function",["os.time"]="function",["math.floor"]="function",["getmetatable"]="function",["string.format"]="function",["math.max"]="function",["math.sqrt"]="function",["debug.traceback"]="function",["setmetatable"]="function",["debug.getlocal"]="function",["math.fmod"]="function",["math.modf"]="function",["math.exp"]="function",["os.exit"]="function",["debug.setupvalue"]="function",["os.difftime"]="function",["xpcall"]="function",["os.date"]="function",["math.sin"]="function",["math.rad"]="function",["math.min"]="function",["string.dump"]="function",["tonumber"]="function",["loadfile"]="function",["string.sub"]="function",["rawget"]="function",["debug.getinfo"]="function",["table.insert"]="function",["debug.sethook"]="function",["math.deg"]="function",["string.gmatch"]="function",["next"]="function",["math.cos"]="function",["math.atan"]="function",["string.gsub"]="function",["string.match"]="function",["math.ceil"]="function",["string.byte"]="function",["math.asin"]="function",["collectgarbage"]="function",["math.abs"]="function",["string.len"]="function",["string.reverse"]="function",["table.concat"]="function",["rawequal"]="function",["type"]="function",["string.find"]="function",["table.sort"]="function",["assert"]="function",["string.char"]="function",["math.tan"]="function",["tostring"]="function",["rawset"]="function",["load"]="function",["debug.getupvalue"]="function",["pcall"]="function",["string.rep"]="function",["error"]="function",["dofile"]="function",["math.acos"]="function",["table.remove"]="function",["string.lower"]="function"},{},type,error,_G,pairs,getmetatable,rawget
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
