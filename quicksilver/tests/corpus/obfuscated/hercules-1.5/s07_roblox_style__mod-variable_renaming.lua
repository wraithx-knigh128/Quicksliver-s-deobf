--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local AemCUlrTcKk
AemCUlrTcKk = print;
-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local IIMfMjZurC = game:GetService("IIMfMjZurC")
local zxWmdlERE = game:GetService("zxWmdlERE")
local yinXFpSjudBm = game:GetService("yinXFpSjudBm")

local JxEmbDXKy = IIMfMjZurC.LocalPlayer
local ycbhbXasaqVk = { speed = 24, jump = 50, label = "QuickSilver" }

local function ArfoPVZM(cDGcFkDJOk)
  local gIOyIDrVQe = cDGcFkDJOk:WaitForChild("Humanoid")
  gIOyIDrVQe.WalkSpeed = ycbhbXasaqVk.speed
  gIOyIDrVQe.JumpPower = ycbhbXasaqVk.jump
  return gIOyIDrVQe
end

local wPdZwiguCp = Instance.new("Part")
wPdZwiguCp.Name = ycbhbXasaqVk.label .. "Marker"
wPdZwiguCp.Anchored = true
wPdZwiguCp.Parent = workspace

local gIOyIDrVQe = ArfoPVZM(JxEmbDXKy.Character)
AemCUlrTcKk("configured", gIOyIDrVQe.WalkSpeed, gIOyIDrVQe.JumpPower, wPdZwiguCp.Name)

local kweuqlPhf = 0
local xHvKEpMRBuM
xHvKEpMRBuM = zxWmdlERE.Heartbeat:Connect(function(dt)
  kweuqlPhf = kweuqlPhf + 1
  if kweuqlPhf >= 3 then
    xHvKEpMRBuM:Disconnect()
    AemCUlrTcKk("heartbeat done", kweuqlPhf)
  end
end)

local jgqTeQsBpB = yinXFpSjudBm:WaitForChild("Remote")
jgqTeQsBpB:FireServer("hello", 42)
