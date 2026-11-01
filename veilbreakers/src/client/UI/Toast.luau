--!nonstrict
-- Small stacked notifications in the top-right corner (challenges, trade requests,
-- rewards, errors). Purely visual: they never take input focus.

local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local F = Theme.Fonts

local Toast = {}

local holder = nil

function Toast.mount(root: Instance)
	holder = Theme.frame(root, {
		Name = "Toasts",
		Size = UDim2.fromOffset(460, 600),
		Position = UDim2.new(1, -24, 0, 150),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 95,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
end

local order = 0
function Toast.show(text: string, sub: string?, color: Color3?, life: number?)
	if not holder then
		return
	end
	order += 1
	local box = Theme.frame(holder, {
		Size = UDim2.fromOffset(440, sub and 78 or 50),
		BackgroundColor3 = Color3.fromHex("#0C0D10"),
		BackgroundTransparency = 0.1,
		LayoutOrder = order,
		ZIndex = 95,
	})
	Theme.corner(box, 8)
	Theme.stroke(box, color or C.gold, 1.5)
	Theme.frame(box, { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = color or C.gold, BackgroundTransparency = 0, ZIndex = 96 })
	Theme.label(box, text, {
		Size = UDim2.new(1, -30, 0, 28),
		Position = UDim2.fromOffset(18, 10),
		FontFace = F.labelBold,
		TextSize = 18,
		TextColor3 = C.ivory,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 96,
	})
	if sub then
		Theme.label(box, sub, {
			Size = UDim2.new(1, -30, 0, 24),
			Position = UDim2.fromOffset(18, 42),
			FontFace = F.label,
			TextSize = 15,
			TextColor3 = C.text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 96,
		})
	end
	task.delay(life or 5, function()
		if box.Parent then
			Theme.tween(box, 0.3, { BackgroundTransparency = 1 })
			task.delay(0.32, function()
				box:Destroy()
			end)
		end
	end)
end

return Toast
