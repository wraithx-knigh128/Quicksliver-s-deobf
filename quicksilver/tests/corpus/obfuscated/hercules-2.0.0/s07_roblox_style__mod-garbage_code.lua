--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local function ccgxfg(xjturx) local _ = 90 end
local wdlluy = 73
local juudmr = 100
local breyuy = 3
local function aqpkkg(vciyyu) local _ = 99 end
local rpkeyw = 68
local uqljuh = 6
local kspfvi = 27
while false do local _ = 52 break end
local function cacyku(vydikd) local _ = 91 end
local molrnc = 37
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

local function jcyqpn(fbtvyr) local _ = 1 end
local ghjgnb = 42
local function zfqthy(qrujpq) local _ = 59 end
local function vmmmho(ymifac) local _ = 41 end
local function vguexs(cemxmo) local _ = 97 end
if true then local _ = 71 end
local function rmixqr(miwdih) local _ = 40 end
local function nswtbd(sxsduv) local _ = 41 end
local ccbxqn = 33
local kjdtkf = 58
local function lkfriy(uzgzuj) local _ = 56 end
if false then local _ = 29 end
local qtihgr = 49
if true then local _ = 57 end
local function bkiccc(gyrmgx) local _ = 61 end
while false do local _ = 30 break end