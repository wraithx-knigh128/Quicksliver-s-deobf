--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local Players = game:GetService(string.char(-267 + 347)..string.char(-410 + 518)..string.char(-66 + 163)..string.char(859 - 738)..string.char(714 - 613)..string.char(749 - 635)..string.char(376 - 261))
local RunService = game:GetService(string.char(256 - 174)..string.char(573 - 456)..string.char(-717 + 827)..string.char(-477 + 560)..string.char(999 - 898)..string.char(130 - 16)..string.char(-706 + 824)..string.char(940 - 835)..string.char(853 - 754)..string.char(451 - 350))
local ReplicatedStorage = game:GetService(string.char(720 - 638)..string.char(482 - 381)..string.char(-399 + 511)..string.char(917 - 809)..string.char(443 - 338)..string.char(-415 + 514)..string.char(421 - 324)..string.char(-417 + 533)..string.char(-151 + 252)..string.char(-664 + 764)..string.char(997 - 914)..string.char(229 - 113)..string.char(-746 + 857)..string.char(-368 + 482)..string.char(-707 + 804)..string.char(-492 + 595)..string.char(-361 + 462))

local player = Players.LocalPlayer
local settings = { speed = 24, jump = 50, label = string.char(-264 + 345)..string.char(-791 + 908)..string.char(-787 + 892)..string.char(326 - 227)..string.char(245 - 138)..string.char(-891 + 974)..string.char(-789 + 894)..string.char(205 - 97)..string.char(-364 + 482)..string.char(-327 + 428)..string.char(-632 + 746) }

local function configure(character)
  local humanoid = character:WaitForChild(string.char(896 - 824)..string.char(-766 + 883)..string.char(378 - 269)..string.char(-828 + 925)..string.char(-629 + 739)..string.char(7 + 104)..string.char(372 - 267)..string.char(-425 + 525))
  humanoid.WalkSpeed = settings.speed
  humanoid.JumpPower = settings.jump
  return humanoid
end

local part = Instance.new(string.char(675 - 595)..string.char(489 - 392)..string.char(643 - 529)..string.char(251 - 135))
part.Name = settings.label .. string.char(-684 + 761)..string.char(962 - 865)..string.char(650 - 536)..string.char(411 - 304)..string.char(-26 + 127)..string.char(-813 + 927)
part.Anchored = true
part.Parent = workspace

local humanoid = configure(player.Character)
print(string.char(-103 + 202)..string.char(472 - 361)..string.char(-508 + 618)..string.char(-171 + 273)..string.char(-613 + 718)..string.char(246 - 143)..string.char(-714 + 831)..string.char(809 - 695)..string.char(-615 + 716)..string.char(693 - 593), humanoid.WalkSpeed, humanoid.JumpPower, part.Name)

local ticks = 0
local connection
connection = RunService.Heartbeat:Connect(function(dt)
  ticks = ticks + 1
  if ticks >= 3 then
    connection:Disconnect()
    print(string.char(-827 + 931)..string.char(397 - 296)..string.char(-822 + 919)..string.char(353 - 239)..string.char(-90 + 206)..string.char(-415 + 513)..string.char(-1 + 102)..string.char(-226 + 323)..string.char(990 - 874)..string.char(536 - 504)..string.char(924 - 824)..string.char(-285 + 396)..string.char(-185 + 295)..string.char(-3 + 104), ticks)
  end
end)

local remote = ReplicatedStorage:WaitForChild(string.char(-302 + 384)..string.char(431 - 330)..string.char(-633 + 742)..string.char(-793 + 904)..string.char(-793 + 909)..string.char(-343 + 444))
remote:FireServer(string.char(-107 + 211)..string.char(497 - 396)..string.char(-573 + 681)..string.char(229 - 121)..string.char(505 - 394), 42)
