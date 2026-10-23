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
  do (function() humanoid.WalkSpeed = settings.speed end)() end
  do (function() humanoid.JumpPower = settings.jump end)() end
  return humanoid
end

local part = Instance.new("Part")
do (function() part.Name = settings.label .. "Marker" end)() end
do (function() part.Anchored = true end)() end
do (function() part.Parent = workspace end)() end

local humanoid = configure(player.Character)
do (function() print("configured", humanoid.WalkSpeed, humanoid.JumpPower, part.Name) end)() end

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
do (function() remote:FireServer("hello", 42) end)() end
