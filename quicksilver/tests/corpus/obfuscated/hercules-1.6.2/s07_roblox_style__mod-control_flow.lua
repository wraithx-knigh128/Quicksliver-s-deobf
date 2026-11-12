--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local thing = 708;
local thing2 = 708;
local counter = 0;
local threshold = 261;
while thing == thing2 and counter < 3 do
    thing = thing + -447;
    counter = counter + 1;
    if thing < threshold then
        local str = 'dummy'; str = str .. str;
    else
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

        break
    end
end
local dummy = 1; dummy = dummy + 9;
