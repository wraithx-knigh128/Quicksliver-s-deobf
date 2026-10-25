local plrs = game:GetService("Players")
local lp = plrs.LocalPlayer
local rs=game:GetService("RunService")
local t = {}
local on = true  
--local boxes = {}
local function mk(p)
	local b = Drawing.new("Square")
	b.Visible=false
	b.Color = Color3.new(1,0,0)
	t[p] = b
end
for _,v in pairs(plrs:GetPlayers()) do
    if v ~= lp then mk(v) end
end
print("here")
plrs.PlayerAdded:Connect(function(p)
	mk(p)
end)
rs.RenderStepped:Connect(function()
	for p,b in pairs(t) do
		local c = p.Character
		if c and c:FindFirstChild("HumanoidRootPart") then
			local pos, vis = workspace.CurrentCamera:WorldToViewportPoint(c.HumanoidRootPart.Position)
			b.Visible = vis and on
			--b.Position = Vector2.new(pos.X, pos.Y)
			b.Position=Vector2.new(pos.X,pos.Y)
		else b.Visible=false end
	end
end)
--print(t)
game:GetService("UserInputService").InputBegan:Connect(function(i,g)
    if i.KeyCode == Enum.KeyCode.RightShift then on = not on end
end)
