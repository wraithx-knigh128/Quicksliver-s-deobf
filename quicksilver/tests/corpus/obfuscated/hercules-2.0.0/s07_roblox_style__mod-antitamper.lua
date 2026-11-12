--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["string.sub"]=string.sub,["debug.setupvalue"]=debug.setupvalue,["rawset"]=rawset,["debug.traceback"]=debug.traceback,["math.min"]=math.min,["tostring"]=tostring,["math.sin"]=math.sin,["string.match"]=string.match,["table.remove"]=table.remove,["debug.getlocal"]=debug.getlocal,["math.max"]=math.max,["dofile"]=dofile,["error"]=error,["debug.getinfo"]=debug.getinfo,["math.deg"]=math.deg,["string.char"]=string.char,["os.exit"]=os.exit,["string.len"]=string.len,["debug.getupvalue"]=debug.getupvalue,["math.atan"]=math.atan,["assert"]=assert,["os.difftime"]=os.difftime,["os.date"]=os.date,["os.clock"]=os.clock,["math.tan"]=math.tan,["math.cos"]=math.cos,["string.upper"]=string.upper,["math.floor"]=math.floor,["string.reverse"]=string.reverse,["os.time"]=os.time,["math.acos"]=math.acos,["collectgarbage"]=collectgarbage,["getmetatable"]=getmetatable,["math.abs"]=math.abs,["math.fmod"]=math.fmod,["string.dump"]=string.dump,["type"]=type,["xpcall"]=xpcall,["pcall"]=pcall,["next"]=next,["math.ceil"]=math.ceil,["string.format"]=string.format,["math.modf"]=math.modf,["string.find"]=string.find,["setmetatable"]=setmetatable,["string.gsub"]=string.gsub,["loadfile"]=loadfile,["tonumber"]=tonumber,["rawget"]=rawget,["math.exp"]=math.exp,["math.sqrt"]=math.sqrt,["table.insert"]=table.insert,["math.asin"]=math.asin,["math.rad"]=math.rad,["table.concat"]=table.concat,["string.gmatch"]=string.gmatch,["debug.sethook"]=debug.sethook,["string.lower"]=string.lower,["string.byte"]=string.byte,["rawequal"]=rawequal,["table.sort"]=table.sort,["string.rep"]=string.rep,["select"]=select,["load"]=load},{},type,error,pairs,getmetatable,rawget
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
