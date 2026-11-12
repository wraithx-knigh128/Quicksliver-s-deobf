--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local cDGcFkDJOk
cDGcFkDJOk=print;
-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local ycbhbXasaqVk = game:GetService("Players")
local gIOyIDrVQe = game:GetService("RunService")
local IIMfMjZurC = game:GetService("ReplicatedStorage")

local ArfoPVZM = ycbhbXasaqVk.LocalPlayer
local jgqTeQsBpB = {speed= 24, jump = 50, label = "QuickSilver" }

local function JxEmbDXKy(character)
  local wPdZwiguCp = character:WaitForChild("Humanoid")
  wPdZwiguCp.WalkSpeed = jgqTeQsBpB.speed
  wPdZwiguCp.JumpPower = jgqTeQsBpB.jump
  return wPdZwiguCp
end

local zxWmdlERE = Instance.new("Part")
zxWmdlERE.Name = jgqTeQsBpB.label .. "Marker"
zxWmdlERE.Anchored = true
zxWmdlERE.Parent = workspace

local wPdZwiguCp = JxEmbDXKy(ArfoPVZM.Character)
cDGcFkDJOk("configured", wPdZwiguCp.WalkSpeed, wPdZwiguCp.JumpPower, zxWmdlERE.Name)

local kweuqlPhf = 0
local yinXFpSjudBm
yinXFpSjudBm = gIOyIDrVQe.Heartbeat:Connect(function(dt)
  kweuqlPhf = kweuqlPhf + 1
  if kweuqlPhf >= 3 then
    yinXFpSjudBm:Disconnect()
    cDGcFkDJOk("heartbeat done", kweuqlPhf)
  end
end)

local xHvKEpMRBuM = IIMfMjZurC:WaitForChild("Remote")
xHvKEpMRBuM:FireServer("hello", 42)
