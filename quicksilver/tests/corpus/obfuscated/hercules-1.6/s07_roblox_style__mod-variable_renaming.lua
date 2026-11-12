--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local ramgNjMn, PszEfWZNq
ramgNjMn = print; PszEfWZNq = game:GetService;
-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local IIMfMjZurC = PszEfWZNq("IIMfMjZurC")
local zxWmdlERE = PszEfWZNq("zxWmdlERE")
local yinXFpSjudBm = PszEfWZNq("yinXFpSjudBm")

local JxEmbDXKy = IIMfMjZurC.LocalPlayer
local ycbhbXasaqVk = { speed = 24, jump = 50, label = "QuickSilver" }

local function AemCUlrTcKk(IyWVnEfbt)
  local kweuqlPhf = IyWVnEfbt:WaitForChild("Humanoid")
  kweuqlPhf.WalkSpeed = ycbhbXasaqVk.speed
  kweuqlPhf.JumpPower = ycbhbXasaqVk.jump
  return kweuqlPhf
end

local wPdZwiguCp = Instance.new("Part")
wPdZwiguCp.Name = ycbhbXasaqVk.label .. "Marker"
wPdZwiguCp.Anchored = true
wPdZwiguCp.Parent = workspace

local kweuqlPhf = AemCUlrTcKk(JxEmbDXKy.Character)
ramgNjMn("configured", kweuqlPhf.WalkSpeed, kweuqlPhf.JumpPower, wPdZwiguCp.Name)

local xHvKEpMRBuM = 0
local ArfoPVZM
ArfoPVZM = zxWmdlERE.Heartbeat:Connect(function(dt)
  xHvKEpMRBuM = xHvKEpMRBuM + 1
  if xHvKEpMRBuM >= 3 then
    ArfoPVZM:Disconnect()
    ramgNjMn("heartbeat done", xHvKEpMRBuM)
  end
end)

local cDGcFkDJOk = yinXFpSjudBm:WaitForChild("Remote")
cDGcFkDJOk:FireServer("hello", 42)
