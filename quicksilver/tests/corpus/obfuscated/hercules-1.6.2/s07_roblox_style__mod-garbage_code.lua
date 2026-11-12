--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
while false do local _ = 7 break end
local vaeftu = 34
while false do local _ = 72 break end
local lmzvhh = 53
if false then local _ = 73 end
if false then local _ = 85 end
if true then local _ = 74 end
local reahvr = 100
local function sspbqq(kjeesf) local _ = 48 end
local lcofgc = 40
local mqhxhs = 17
local function onjupy(xxmfvz) local _ = 33 end
local function ccgxfg(xjturx) local _ = 90 end
while false do local _ = 60 break end
if false then local _ = 21 end
if true then local _ = 68 end
local mrdxmb = 30
while false do local _ = 25 break end
local function ucrpke(ywjdtw) local _ = 73 end
if true then local _ = 85 end
if false then local _ = 16 end
local xbvepg = 56
local ugkujg = 17
if false then local _ = 59 end
local function pfvirf(ojptgx) local _ = 3 end
local function uvydik(demolr) local _ = 46 end
local function yekjcy(qpnfbt) local _ = 22 end
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

if false then local _ = 71 end
local hyqruj = 95
local function vmmmho(ymifac) local _ = 41 end
local function vguexs(cemxmo) local _ = 97 end
local function rmixqr(miwdih) local _ = 40 end
local function nswtbd(sxsduv) local _ = 41 end
if false then local _ = 35 end
local kfzlkf = 18
while false do local _ = 85 break end
local function cgyrmg(xprgpm) local _ = 73 end
local function vcvxxx(wbrbwj) local _ = 43 end
if true then local _ = 45 end
local function chzvef(stwzqo) local _ = 3 end
local function kqfvhd(mvenml) local _ = 46 end
local function jmhnhz(gpwtjm) local _ = 41 end
if true then local _ = 59 end
if true then local _ = 60 end
if true then local _ = 78 end
while false do local _ = 14 break end
if true then local _ = 36 end
local mvzmny = 27
if false then local _ = 77 end
local hxayts = 6
local function zgmsvk(eszxip) local _ = 20 end
while false do local _ = 92 break end