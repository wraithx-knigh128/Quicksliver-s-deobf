--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local ccgxfg = 10 local function juudmr(dxmbre) local _ = 25 end local function ycbhbr(vasaqp) local _ = 75 end local gvciyy = 99 local function rpkeyw(jdtwig) local _ = 85 end local function vpgwxz(kweuql) local _ = 42 end local function hfvxbv(epgvxl) local _ = 28 end local function gkujgq(nekspf) local _ = 86 end if false then local _ = 52 end local cacyku = 54 while false do local _ = 41 break end local demolr = 46 local yekjcy = 14 if true then local _ = 14 end if false then local _ = 19 end if true then local _ = 70 end -- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
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
 while false do local _ = 21 break end if true then local _ = 49 end local nzkrxo = 71 if true then local _ = 56 end local vmmmho = 25 local function mifaci(pkvgue) local _ = 35 end local function mxmoai(vgcrmi) local _ = 18 end local function iwdihh(cnswtb) local _ = 36 end local xsduvi = 13 local cbxqna = 94 local function kjdtkf(zlkfri) local _ = 85 end if true then local _ = 93 end if true then local _ = 85 end if true then local _ = 16 end if true then local _ = 1 end while false do local _ = 29 break end local function qtihgr(qaykbk) local _ = 99 end local cgyrmg = 24 local function prgpmi(cvcvxx) local _ = 56 end