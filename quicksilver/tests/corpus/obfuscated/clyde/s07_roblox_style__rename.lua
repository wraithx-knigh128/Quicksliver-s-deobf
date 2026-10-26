local Players = game:GetService("Players")
local a = game:GetService("RunService")
local b = game:GetService("ReplicatedStorage")
local c = Players.LocalPlayer
local d = {speed = 24, jump = 50, label = "QuickSilver"}
local function e(f)
  local g = f:WaitForChild("Humanoid")
  g.WalkSpeed = d.speed
  g.JumpPower = d.jump
  return g
end
local h = Instance.new("Part")
h.Name = (d.label .. "Marker")
h.Anchored = true
h.Parent = workspace
local i = e(c.Character)
print("configured", i.WalkSpeed, i.JumpPower, h.Name)
local j = 0
local k
k = a.Heartbeat:Connect(function(l)
  j = (j + 1)
  if (j >= 3) then
    k:Disconnect()
    print("heartbeat done", j)
  end
end)
local m = b:WaitForChild("Remote")
m:FireServer("hello", 42)