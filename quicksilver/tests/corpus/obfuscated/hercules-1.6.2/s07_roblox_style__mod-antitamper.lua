--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,G,Pa,GM,RG={["table.remove"]="function",["debug.traceback"]="function",["math.cos"]="function",["load"]="function",["math.sin"]="function",["debug.setupvalue"]="function",["xpcall"]="function",["pcall"]="function",["string.find"]="function",["debug.sethook"]="function",["dofile"]="function",["math.exp"]="function",["os.exit"]="function",["math.ceil"]="function",["os.time"]="function",["os.difftime"]="function",["debug.getinfo"]="function",["debug.getlocal"]="function",["math.deg"]="function",["type"]="function",["math.sqrt"]="function",["math.abs"]="function",["rawset"]="function",["os.clock"]="function",["math.tan"]="function",["string.dump"]="function",["os.date"]="function",["rawequal"]="function",["math.min"]="function",["math.modf"]="function",["math.rad"]="function",["table.insert"]="function",["math.max"]="function",["rawget"]="function",["string.upper"]="function",["string.len"]="function",["math.fmod"]="function",["error"]="function",["string.match"]="function",["string.rep"]="function",["next"]="function",["string.reverse"]="function",["math.floor"]="function",["collectgarbage"]="function",["debug.getupvalue"]="function",["setmetatable"]="function",["math.atan"]="function",["table.sort"]="function",["math.asin"]="function",["string.format"]="function",["math.acos"]="function",["string.sub"]="function",["getmetatable"]="function",["table.concat"]="function",["string.lower"]="function",["tonumber"]="function",["string.char"]="function",["loadfile"]="function",["string.gmatch"]="function",["string.byte"]="function",["assert"]="function",["string.gsub"]="function",["select"]="function",["tostring"]="function"},{},type,error,_G,pairs,getmetatable,rawget
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
