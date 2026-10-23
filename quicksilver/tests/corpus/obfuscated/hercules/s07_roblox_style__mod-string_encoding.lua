--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
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

-- s07: Roblox-style script written against the mock environment in tests/corpus/tools/run_lua.py.
-- Exercises global API access patterns that obfuscators hide (GetService, Instance.new, events).
local Players = game:GetService(IIMfMjZurC("Njywcpq", 24))
local RunService = game:GetService(IIMfMjZurC("PslQcptgac", 24))
local ReplicatedStorage = game:GetService(IIMfMjZurC("PcnjgayrcbQrmpyec", 24))

local player = Players.LocalPlayer
local settings = { speed = 24, jump = 50, label = IIMfMjZurC("MqeygOehran", 22) }

local function configure(character)
  local humanoid = character:WaitForChild(IIMfMjZurC("Gtlzmnhc", 25))
  humanoid.WalkSpeed = settings.speed
  humanoid.JumpPower = settings.jump
  return humanoid
end

local part = Instance.new(IIMfMjZurC("Ozqs", 25))
part.Name = settings.label .. IIMfMjZurC("Bpgztg", 15)
part.Anchored = true
part.Parent = workspace

local humanoid = configure(player.Character)
print(IIMfMjZurC("bnmehftqdc", 25), humanoid.WalkSpeed, humanoid.JumpPower, part.Name)

local ticks = 0
local connection
connection = RunService.Heartbeat:Connect(function(dt)
  ticks = ticks + 1
  if ticks >= 3 then
    connection:Disconnect()
    print(IIMfMjZurC("gdzqsadzs cnmd", 25), ticks)
  end
end)

local remote = ReplicatedStorage:WaitForChild(IIMfMjZurC("Kxfhmx", 19))
remote:FireServer(IIMfMjZurC("gdkkn", 25), 42)
