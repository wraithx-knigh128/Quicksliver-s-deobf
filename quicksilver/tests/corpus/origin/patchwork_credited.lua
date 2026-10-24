-- made by Cyph3r, credits to the Rayfield team
-- discord.gg/abcd1234
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({Name = "Hub"})

local Tab = Window:CreateTab("Main")
local speed_value = 16
local jump_value = 50
local function set_speed(value_to_set)
	local character = game.Players.LocalPlayer.Character
	character.Humanoid.WalkSpeed = value_to_set
end
local function set_jump(value_to_set)
	local character = game.Players.LocalPlayer.Character
	character.Humanoid.JumpPower = value_to_set
end
Tab:CreateSlider({Name = "Speed", Range = {16, 100}, Increment = 1, CurrentValue = 16, Callback = function(v) set_speed(v) end})
Tab:CreateSlider({Name = "Jump", Range = {50, 200}, Increment = 1, CurrentValue = 50, Callback = function(v) set_jump(v) end})
local function more_stuff_one()
	local a = 1
	local b = 2
	return a + b
end
local function more_stuff_two()
	local a = 3
	local b = 4
	return a * b
end
local function more_stuff_three()
	local a = 5
	local b = 6
	return a - b
end
local function more_stuff_four()
	local a = 7
	local b = 8
	return a / b
end
local function more_stuff_five()
	local a = 9
	local b = 10
	return a % b
end
local function more_stuff_six()
	local a = 11
	local b = 12
	return a ^ b
end
local function more_stuff_seven()
	local a = 13
	local b = 14
	return a + b
end

local playerStatsManager = {}
function playerStatsManager.getHealthPercentage(playerCharacter)
    local humanoid = playerCharacter:FindFirstChildOfClass("Humanoid")
    if not humanoid then return 0 end
    return humanoid.Health / humanoid.MaxHealth
end
function playerStatsManager.isPlayerAlive(playerCharacter)
    local humanoid = playerCharacter:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end
function playerStatsManager.getDistanceBetween(firstCharacter, secondCharacter)
    local firstRoot = firstCharacter:FindFirstChild("HumanoidRootPart")
    local secondRoot = secondCharacter:FindFirstChild("HumanoidRootPart")
    if not firstRoot or not secondRoot then return math.huge end
    return (firstRoot.Position - secondRoot.Position).Magnitude
end
function playerStatsManager.getAllAlivePlayers()
    local alivePlayers = {}
    for _, currentPlayer in ipairs(game.Players:GetPlayers()) do
        if currentPlayer.Character and playerStatsManager.isPlayerAlive(currentPlayer.Character) then
            table.insert(alivePlayers, currentPlayer)
        end
    end
    return alivePlayers
end
