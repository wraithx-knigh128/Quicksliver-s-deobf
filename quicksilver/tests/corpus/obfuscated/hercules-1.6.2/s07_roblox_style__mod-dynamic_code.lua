--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local settings = { speed = 24, jump = 50, label = "QuickSilver" }

local function configure(character)
  local humanoid = character:WaitForChild("Humanoid")
  ;(function() humanoid.WalkSpeed = settings.speed end)()
  ;(function() humanoid.JumpPower = settings.jump end)()
  return humanoid
end

local part = Instance.new("Part")
;(function() part.Name = settings.label .. "Marker" end)()
;(function() part.Anchored = true end)()
;(function() part.Parent = workspace end)()

local humanoid = configure(player.Character)
;(function() print("configured", humanoid.WalkSpeed, humanoid.JumpPower, part.Name) end)()

local ticks = 0
local connection
;(function() connection = RunService.Heartbeat:Connect(function(dt) end)()
  ;(function() ticks = ticks + 1 end)()
  if ticks >= 3 then
    ;(function() connection:Disconnect() end)()
    ;(function() print("heartbeat done", ticks) end)()
  end
end)

local remote = ReplicatedStorage:WaitForChild("Remote")
;(function() remote:FireServer("hello", 42) end)()
