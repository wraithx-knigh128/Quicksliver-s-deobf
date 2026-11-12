--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local function zxWmdlERE(gIOyIDrVQe)
    return (gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57) or (gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90) or (gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122)
end
	
local function IIMfMjZurC(JxEmbDXKy, ycbhbXasaqVk)
    local yinXFpSjudBm = {}
    for i = 1, #JxEmbDXKy do
        local gIOyIDrVQe = JxEmbDXKy:byte(i)
        if zxWmdlERE(gIOyIDrVQe) then
            local wPdZwiguCp            if gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57 then
                wPdZwiguCp = ((gIOyIDrVQe - 48 - ycbhbXasaqVk + 10) % 10) + 48
            elseif gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90 then
                wPdZwiguCp = ((gIOyIDrVQe - 65 - ycbhbXasaqVk + 26) % 26) + 65
            elseif gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122 then
                wPdZwiguCp = ((gIOyIDrVQe - 97 - ycbhbXasaqVk + 26) % 26) + 97
            end
            table.insert(yinXFpSjudBm, string.char(wPdZwiguCp))
        else
            table.insert(yinXFpSjudBm, string.char(gIOyIDrVQe))
        end
    end
    return table.concat(yinXFpSjudBm)
end

local function zxWmdlERE(gIOyIDrVQe)
    return (gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57) or (gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90) or (gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122)
end

-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local Players = game:GetService(IIMfMjZurC("Mixvbop", 23))
local RunService = game:GetService(IIMfMjZurC("CfyDpcgtnp", 11))
local ReplicatedStorage = game:GetService(IIMfMjZurC("WjuqnhfyjiXytwflj", 5))

local player = Players.LocalPlayer
local settings = { speed = 24, jump = 50, label = IIMfMjZurC("HlztbJzcmvi", 17) }

local function configure(character)
  local humanoid = character:WaitForChild(IIMfMjZurC("Pcuivwql", 8))
  humanoid.WalkSpeed = settings.speed
  humanoid.JumpPower = settings.jump
  return humanoid
end

local part = Instance.new(IIMfMjZurC("Lwnp", 22))
part.Name = settings.label .. IIMfMjZurC("Octmgt", 2)
part.Anchored = true
part.Parent = workspace

local humanoid = configure(player.Character)
print(IIMfMjZurC("htsknlzwji", 5), humanoid.WalkSpeed, humanoid.JumpPower, part.Name)

local ticks = 0
local connection
connection = RunService.Heartbeat:Connect(function(dt)
  ticks = ticks + 1
  if ticks >= 3 then
    connection:Disconnect()
    print(IIMfMjZurC("dawnpxawp zkja", 22), ticks)
  end
end)

local remote = ReplicatedStorage:WaitForChild(IIMfMjZurC("Dqyafq", 12))
remote:FireServer(IIMfMjZurC("olssv", 7), 42)
