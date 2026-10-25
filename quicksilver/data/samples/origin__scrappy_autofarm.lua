getgenv().farm = true
local lp = game.Players.LocalPlayer
local function tp(cf)
	lp.Character.HumanoidRootPart.CFrame = cf
end
spawn(function()
	while farm do
		for i,v in pairs(workspace.Coins:GetChildren()) do
			if not farm then break end
			tp(v.CFrame)
			wait(.1)
		end
		wait()
	end
end)
print(1)
-- toggle w/ K
game:GetService("UserInputService").InputBegan:Connect(function(k)
	if k.KeyCode == Enum.KeyCode.K then farm = not farm end
end)
