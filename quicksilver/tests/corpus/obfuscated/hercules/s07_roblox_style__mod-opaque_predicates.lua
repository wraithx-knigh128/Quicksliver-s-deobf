--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
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
if 35 + 35 == 70 then
    part.Name = settings.label .. "Marker"
    part.Anchored = true
end
if 39 + 6 == 45 then
    part.Parent = workspace
end

local humanoid = configure(player.Character)
if not (10 ~= 10) then
    print("configured", humanoid.WalkSpeed, humanoid.JumpPower, part.Name)
elseif (not (21 < 39)) == (21 >= 39) then
    -- dead
end

local ticks = 0
local connection
if true then
    connection = RunService.Heartbeat:Connect(function(dt)
    ticks = ticks + 1
    if ticks >= 3 then
    connection:Disconnect()
    print("heartbeat done", ticks)
    end
    end)
end

local remote = ReplicatedStorage:WaitForChild("Remote")
if 26 + 26 == 52 then
    remote:FireServer("hello", 42)
end
