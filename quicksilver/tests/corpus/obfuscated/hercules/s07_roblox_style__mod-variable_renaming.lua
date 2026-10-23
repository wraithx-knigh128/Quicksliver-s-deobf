--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local cDGcFkDJOk
cDGcFkDJOk=print;
-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local zxWmdlERE = game:GetService("Players")
local jgqTeQsBpB = game:GetService("RunService")
local IIMfMjZurC = game:GetService("ReplicatedStorage")

local xHvKEpMRBuM = zxWmdlERE.LocalPlayer
local yinXFpSjudBm = {speed= 24, jump = 50, label = "QuickSilver" }

local function kweuqlPhf(character)
  local ArfoPVZM = character:WaitForChild("Humanoid")
  ArfoPVZM.WalkSpeed = yinXFpSjudBm.speed
  ArfoPVZM.JumpPower = yinXFpSjudBm.jump
  return ArfoPVZM
end

local gIOyIDrVQe = Instance.new("Part")
gIOyIDrVQe.Name = yinXFpSjudBm.label .. "Marker"
gIOyIDrVQe.Anchored = true
gIOyIDrVQe.Parent = workspace

local ArfoPVZM = kweuqlPhf(xHvKEpMRBuM.Character)
cDGcFkDJOk("configured", ArfoPVZM.WalkSpeed, ArfoPVZM.JumpPower, gIOyIDrVQe.Name)

local wPdZwiguCp = 0
local JxEmbDXKy
JxEmbDXKy = jgqTeQsBpB.Heartbeat:Connect(function(dt)
  wPdZwiguCp = wPdZwiguCp + 1
  if wPdZwiguCp >= 3 then
    JxEmbDXKy:Disconnect()
    cDGcFkDJOk("heartbeat done", wPdZwiguCp)
  end
end)

local ycbhbXasaqVk = IIMfMjZurC:WaitForChild("Remote")
ycbhbXasaqVk:FireServer("hello", 42)
