--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local chars = {[32]=" ",[97]="a",[98]="b",[99]="c",[100]="d",[101]="e",[102]="f",[103]="g",[104]="h",[105]="i",[107]="k",[108]="l",[109]="m",[110]="n",[80]="P",[112]="p",[82]="R",[83]="S",[115]="s",[116]="t",[117]="u",[118]="v",[77]="M",[72]="H",[121]="y",[81]="Q",[111]="o",[114]="r"}
-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local Players = game:GetService((chars[-267 + 347]..chars[-410 + 518]..chars[-66 + 163]..chars[859 - (738)]..chars[714 - (613)]..chars[749 - (635)]..chars[376 - (261)]))
local RunService = game:GetService((chars[256 - (174)]..chars[573 - (456)]..chars[-717 + 827]..chars[-477 + 560]..chars[999 - (898)]..chars[130 - (16)]..chars[-706 + 824]..chars[940 - (835)]..chars[853 - (754)]..chars[451 - (350)]))
local ReplicatedStorage = game:GetService((chars[720 - (638)]..chars[482 - (381)]..chars[-399 + 511]..chars[917 - (809)]..chars[443 - (338)]..chars[-415 + 514]..chars[421 - (324)]..chars[-417 + 533]..chars[-151 + 252]..chars[-664 + 764]..chars[997 - (914)]..chars[229 - (113)]..chars[-746 + 857]..chars[-368 + 482]..chars[-707 + 804]..chars[-492 + 595]..chars[-361 + 462]))

local player = Players.LocalPlayer
local settings = { speed = 24, jump = 50, label = (chars[-264 + 345]..chars[-791 + 908]..chars[-787 + 892]..chars[326 - (227)]..chars[245 - (138)]..chars[-891 + 974]..chars[-789 + 894]..chars[205 - (97)]..chars[-364 + 482]..chars[-327 + 428]..chars[-632 + 746]) }

local function configure(character)
  local humanoid = character:WaitForChild((chars[896 - (824)]..chars[-766 + 883]..chars[378 - (269)]..chars[-828 + 925]..chars[-629 + 739]..chars[7 + 104]..chars[372 - (267)]..chars[-425 + 525]))
  humanoid.WalkSpeed = settings.speed
  humanoid.JumpPower = settings.jump
  return humanoid
end

local part = Instance.new((chars[675 - (595)]..chars[489 - (392)]..chars[643 - (529)]..chars[251 - (135)]))
part.Name = settings.label .. (chars[-684 + 761]..chars[962 - (865)]..chars[650 - (536)]..chars[411 - (304)]..chars[-26 + 127]..chars[-813 + 927])
part.Anchored = true
part.Parent = workspace

local humanoid = configure(player.Character)
print((chars[-103 + 202]..chars[472 - (361)]..chars[-508 + 618]..chars[-171 + 273]..chars[-613 + 718]..chars[246 - (143)]..chars[-714 + 831]..chars[809 - (695)]..chars[-615 + 716]..chars[693 - (593)]), humanoid.WalkSpeed, humanoid.JumpPower, part.Name)

local ticks = 0
local connection
connection = RunService.Heartbeat:Connect(function(dt)
  ticks = ticks + 1
  if ticks >= 3 then
    connection:Disconnect()
    print((chars[-827 + 931]..chars[397 - (296)]..chars[-822 + 919]..chars[353 - (239)]..chars[-90 + 206]..chars[-415 + 513]..chars[-1 + 102]..chars[-226 + 323]..chars[990 - (874)]..chars[536 - (504)]..chars[924 - (824)]..chars[-285 + 396]..chars[-185 + 295]..chars[-3 + 104]), ticks)
  end
end)

local remote = ReplicatedStorage:WaitForChild((chars[-302 + 384]..chars[431 - (330)]..chars[-633 + 742]..chars[-793 + 904]..chars[-793 + 909]..chars[-343 + 444]))
remote:FireServer((chars[-107 + 211]..chars[497 - (396)]..chars[-573 + 681]..chars[229 - (121)]..chars[505 - (394)]), 42)
