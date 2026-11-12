--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local AemCUlrTcKk
AemCUlrTcKk=print
-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local kweuqlPhf = game:GetService("Players")
local gIOyIDrVQe = game:GetService("RunService")
local ycbhbXasaqVk = game:GetService("ReplicatedStorage")

local zxWmdlERE = kweuqlPhf.LocalPlayer
local JxEmbDXKy = { speed = 24, jump = 50, label = "QuickSilver" }

local function ArfoPVZM(IIMfMjZurC)
  local cDGcFkDJOk = IIMfMjZurC:WaitForChild("Humanoid")
  cDGcFkDJOk.WalkSpeed = JxEmbDXKy.speed
  cDGcFkDJOk.JumpPower = JxEmbDXKy.jump
  return cDGcFkDJOk
end

local xHvKEpMRBuM = Instance.new("Part")
xHvKEpMRBuM.Name = JxEmbDXKy.label .. "Marker"
xHvKEpMRBuM.Anchored = true
xHvKEpMRBuM.Parent = workspace

local cDGcFkDJOk = ArfoPVZM(zxWmdlERE.Character)
AemCUlrTcKk("configured", cDGcFkDJOk.WalkSpeed, cDGcFkDJOk.JumpPower, xHvKEpMRBuM.Name)

local yinXFpSjudBm = 0
local jgqTeQsBpB
jgqTeQsBpB = gIOyIDrVQe.Heartbeat:Connect(function(dt)
  yinXFpSjudBm = yinXFpSjudBm + 1
  if yinXFpSjudBm >= 3 then
    jgqTeQsBpB:Disconnect()
    AemCUlrTcKk("heartbeat done", yinXFpSjudBm)
  end
end)

local wPdZwiguCp = ycbhbXasaqVk:WaitForChild("Remote")
wPdZwiguCp:FireServer("hello", 42)
