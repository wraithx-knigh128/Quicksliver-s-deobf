--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local function zxWm3dlEREu(Qg2IO5y71ID9)
    return (Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57) or 
           (Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90) or 
           (Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122)
end

local function IIM4fM4j0urC(BmXJxEmbDXKy1, cbhbX2asaq)
    local inX8FpSju1 = {}
    for i = 1, #BmXJxEmbDXKy1 do
        local Qg2IO5y71ID9 = BmXJxEmbDXKy1:byte(i)
        if zxWm3dlEREu(Qg2IO5y71ID9) then
            local VQeA5wPd0wi            if Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 48 - cbhbX2asaq + 10) % 10) + 48
            elseif Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 65 - cbhbX2asaq + 26) % 26) + 65
            elseif Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 97 - cbhbX2asaq + 26) % 26) + 97
            end
            table.insert(inX8FpSju1, string.char(VQeA5wPd0wi))
        else
            table.insert(inX8FpSju1, string.char(Qg2IO5y71ID9))
        end
    end
    return table.concat(inX8FpSju1)
end

-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local Players = game:GetService(IIM4fM4j0urC("Vrgekxy", -319449722))
local RunService = game:GetService(IIM4fM4j0urC("HkdIuhlysu", -255556012))
local ReplicatedStorage = game:GetService(IIM4fM4j0urC("UhsolfdwhgVwrudjh", 541087797))

local player = Players.LocalPlayer
local settings = { speed = 24, jump = 50, label = IIM4fM4j0urC("JnbvdLbeoxk", -40125937) }

local function configure(character)
  local humanoid = character:WaitForChild(IIM4fM4j0urC("Boguhicx", -550623482))
  humanoid.WalkSpeed = settings.speed
  humanoid.JumpPower = settings.jump
  return humanoid
end

local part = Instance.new(IIM4fM4j0urC("Vgxz", -1157038058))
part.Name = settings.label .. IIM4fM4j0urC("Hvmfzm", 1536593495)
part.Anchored = true
part.Parent = workspace

local humanoid = configure(player.Character)
print(IIM4fM4j0urC("htsknlzwji", 1457098297), humanoid.WalkSpeed, humanoid.JumpPower, part.Name)

local ticks = 0
local connection
connection = RunService.Heartbeat:Connect(function(dt)
  ticks = ticks + 1
  if ticks >= 3 then
    connection:Disconnect()
    print(IIM4fM4j0urC("pmizbjmib lwvm", -952757174), ticks)
  end
end)

local remote = ReplicatedStorage:WaitForChild(IIM4fM4j0urC("Cpxzep", -232073857))
remote:FireServer(IIM4fM4j0urC("jgnnq", -1590649578), 42)
