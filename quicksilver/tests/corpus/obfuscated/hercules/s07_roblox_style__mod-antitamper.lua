--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["tostring"]=tostring,["string.match"]=string.match,["xpcall"]=xpcall,["math.rad"]=math.rad,["debug.traceback"]=debug.traceback,["string.gmatch"]=string.gmatch,["next"]=next,["debug.getupvalue"]=debug.getupvalue,["table.sort"]=table.sort,["debug.getlocal"]=debug.getlocal,["string.format"]=string.format,["debug.getinfo"]=debug.getinfo,["string.find"]=string.find,["math.cos"]=math.cos,["math.sin"]=math.sin,["tonumber"]=tonumber,["os.time"]=os.time,["dofile"]=dofile,["os.clock"]=os.clock,["os.date"]=os.date,["assert"]=assert,["os.difftime"]=os.difftime,["math.fmod"]=math.fmod,["math.acos"]=math.acos,["loadfile"]=loadfile,["math.min"]=math.min,["math.modf"]=math.modf,["math.max"]=math.max,["type"]=type,["string.reverse"]=string.reverse,["string.len"]=string.len,["string.lower"]=string.lower,["string.upper"]=string.upper,["math.tan"]=math.tan,["os.exit"]=os.exit,["table.concat"]=table.concat,["string.sub"]=string.sub,["math.deg"]=math.deg,["math.floor"]=math.floor,["load"]=load,["rawset"]=rawset,["math.ceil"]=math.ceil,["math.atan"]=math.atan,["debug.setupvalue"]=debug.setupvalue,["pcall"]=pcall,["error"]=error,["math.sqrt"]=math.sqrt,["string.rep"]=string.rep,["math.abs"]=math.abs,["table.remove"]=table.remove,["math.exp"]=math.exp,["table.insert"]=table.insert,["setmetatable"]=setmetatable,["rawget"]=rawget,["string.byte"]=string.byte,["string.char"]=string.char,["getmetatable"]=getmetatable,["debug.sethook"]=debug.sethook,["math.asin"]=math.asin,["string.dump"]=string.dump,["rawequal"]=rawequal,["collectgarbage"]=collectgarbage,["select"]=select,["string.gsub"]=string.gsub},{},type,error,pairs,getmetatable,rawget
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

-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local settings = { speed = 24, jump = 50, label = "QuickSilver" }

local function configure(character)
  local humanoid = character:WaitForChild("Humanoid")
  humanoid.WalkSpeed = settings.speed
  humanoid.JumpPower = settings.jump
  return humanoid
end

local part = Instance.new("Part")
part.Name = settings.label .. "Marker"
part.Anchored = true
part.Parent = workspace

local humanoid = configure(player.Character)
print("configured", humanoid.WalkSpeed, humanoid.JumpPower, part.Name)

local ticks = 0
local connection
connection = RunService.Heartbeat:Connect(function(dt)
  ticks = ticks + 1
  if ticks >= 3 then
    connection:Disconnect()
    print("heartbeat done", ticks)
  end
end)

local remote = ReplicatedStorage:WaitForChild("Remote")
remote:FireServer("hello", 42)
