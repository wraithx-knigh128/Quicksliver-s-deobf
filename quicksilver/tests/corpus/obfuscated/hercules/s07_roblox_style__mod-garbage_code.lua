--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
if false then local _ = 18 end
local function xqmwdl(luyinr) local _ = 60 end
while false do local _ = 21 break end
if false then local _ = 50 end
if true then local _ = 31 end
local function eyuycb(hbrvas) local _ = 65 end
local pkkgvc = 41
local yucrpk = 5
while false do local _ = 54 break end
local function kweuql(juhfvx) local _ = 98 end
if false then local _ = 21 end
if true then local _ = 43 end
local nekspf = 86
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

local rfojpt = 24
if false then local _ = 75 end
if true then local _ = 5 end
if true then local _ = 46 end
if true then local _ = 70 end
local function tvyram(ghjgnb) local _ = 42 end
local function pqnzkr(xogbhx) local _ = 87 end
local cipkvg = 21
local vgcrmi = 18
if false then local _ = 72 end