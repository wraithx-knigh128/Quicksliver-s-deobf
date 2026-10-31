--!nonstrict
-- On-screen touch controls: floating thumbstick on the left, a diamond of attack
-- buttons on the right with Block, Echo, Super/Breaker and Throw, plus Pause.
-- Multi-touch safe: each finger is tracked by its InputObject.

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Input = require(script.Parent.Parent.Core.Input)

local C = Theme.Colors
local F = Theme.Fonts

local MobileControls = {}
MobileControls.__index = MobileControls

local function circleButton(parent: Instance, label: string, size: number, pos: UDim2, color: Color3, sub: string?)
	local b = Instance.new("TextButton")
	b.Name = label
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.fromOffset(size, size)
	b.Position = pos
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = Color3.fromHex("#0C0D10")
	b.BackgroundTransparency = 0.3
	b.ZIndex = 30
	b.Parent = parent
	Theme.corner(b, size // 2)
	local st = Theme.stroke(b, color, 2.5, 0.1)
	local t = Theme.label(b, label, {
		Size = UDim2.fromScale(1, sub and 0.62 or 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = math.floor(math.min(size * 0.34, size * 1.25 / math.max(1, #label))),
		TextColor3 = C.ivory,
		ZIndex = 31,
	})
	Theme.textStroke(t, 1.5, 0.2)
	if sub then
		Theme.label(b, sub, {
			Size = UDim2.new(1, 0, 0.3, 0),
			Position = UDim2.fromScale(0, 0.58),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = F.labelBold,
			TextSize = math.max(11, math.floor(size * 0.13)),
			TextColor3 = color,
			ZIndex = 31,
		})
	end
	return b, st
end

function MobileControls.new(root: Instance, opts)
	local self = setmetatable({}, MobileControls)
	opts = opts or {}
	local scale = opts.scale or 1
	local gui = Theme.frame(root, { Name = "Touch", Size = UDim2.fromScale(1, 1), ZIndex = 29 })
	self.gui = gui
	self.touches = {}
	self.connections = {}
	self.onPause = opts.onPause

	-- thumbstick
	local base = Theme.frame(gui, {
		Size = UDim2.fromOffset(230 * scale, 230 * scale),
		Position = UDim2.new(0, 210 * scale, 1, -245 * scale),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromHex("#0C0D10"),
		BackgroundTransparency = 0.55,
		ZIndex = 30,
	})
	Theme.corner(base, 115 * scale)
	Theme.stroke(base, C.goldDim, 2, 0.2)
	for i = 0, 3 do
		Theme.diamond(base, 10 * scale, C.gold, {
			Position = UDim2.fromScale(0.5 + math.cos(i * math.pi / 2) * 0.42, 0.5 + math.sin(i * math.pi / 2) * 0.42),
			BackgroundTransparency = 0.4,
			ZIndex = 31,
		})
	end
	local knob = Theme.frame(base, {
		Size = UDim2.fromOffset(96 * scale, 96 * scale),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromHex("#2A2B32"),
		BackgroundTransparency = 0.1,
		ZIndex = 32,
	})
	Theme.corner(knob, 48 * scale)
	Theme.stroke(knob, C.gold, 2)
	self.base = base
	self.knob = knob
	self.homePos = base.Position

	-- action cluster (bottom-right)
	local cx, cy = -230 * scale, -250 * scale
	local s = 112 * scale
	local gap = 92 * scale
	local buttons = {
		{ id = "L", label = "L", sub = "LIGHT", pos = UDim2.new(1, cx - gap, 1, cy), color = Color3.fromHex("#E8E2D4") },
		{ id = "H", label = "H", sub = "HEAVY", pos = UDim2.new(1, cx, 1, cy - gap), color = Color3.fromHex("#E8B24A") },
		{ id = "K", label = "K", sub = "KICK", pos = UDim2.new(1, cx, 1, cy + gap), color = Color3.fromHex("#C9A24A") },
		{ id = "S", label = "SP", sub = "SPECIAL", pos = UDim2.new(1, cx + gap, 1, cy), color = Color3.fromHex("#7FE3FF") },
	}
	self.buttons = {}
	for _, def in buttons do
		local b, st = circleButton(gui, def.label, s, def.pos, def.color, def.sub)
		self:bind(b, def.id, st, def.color)
	end
	local blk, blkSt = circleButton(gui, "BLOCK", 128 * scale, UDim2.new(1, cx - gap * 2.5, 1, cy + gap * 0.65), Color3.fromHex("#9AD8FF"))
	self:bind(blk, "B", blkSt, Color3.fromHex("#9AD8FF"))
	local echo, echoSt = circleButton(gui, "FRIEND", 92 * scale, UDim2.new(1, cx - gap * 1.9, 1, cy - gap * 1.25), Color3.fromHex("#7FE3FF"))
	self:bind(echo, "E", echoSt, Color3.fromHex("#7FE3FF"))
	local sup, supSt = circleButton(gui, "SUPER", 92 * scale, UDim2.new(1, cx + gap * 1.05, 1, cy - gap * 1.45), Color3.fromHex("#FF6A4A"))
	self:bind(sup, "X", supSt, Color3.fromHex("#FF6A4A"))
	self.superButton = sup
	local thr, thrSt = circleButton(gui, "THROW", 84 * scale, UDim2.new(1, cx - gap * 0.95, 1, cy - gap * 1.95), Color3.fromHex("#C9A24A"))
	self:bind(thr, "THROW", thrSt, Color3.fromHex("#C9A24A"))

	-- pause
	local pause = Instance.new("TextButton")
	pause.AutoButtonColor = false
	pause.Text = "II"
	pause.FontFace = F.labelBold
	pause.TextSize = 26
	pause.TextColor3 = C.ivory
	pause.Size = UDim2.fromOffset(64, 64)
	pause.Position = UDim2.new(0.5, 0, 0, 150)
	pause.AnchorPoint = Vector2.new(0.5, 0)
	pause.BackgroundColor3 = Color3.fromHex("#0C0D10")
	pause.BackgroundTransparency = 0.3
	pause.ZIndex = 30
	pause.Parent = gui
	Theme.corner(pause, 32)
	Theme.stroke(pause, C.goldDim, 2)
	table.insert(self.connections, pause.Activated:Connect(function()
		if self.onPause then
			self.onPause()
		end
	end))

	-- stick handling: any touch that starts on the left 45% of the screen drives the stick
	table.insert(self.connections, UserInputService.TouchStarted:Connect(function(io, processed)
		if self.stickTouch or not gui.Visible then
			return
		end
		local vp = workspace.CurrentCamera.ViewportSize
		if io.Position.X < vp.X * 0.45 and io.Position.Y > vp.Y * 0.3 then
			self.stickTouch = io
			self.stickOrigin = Vector2.new(io.Position.X, io.Position.Y)
			local _ = processed
		end
	end))
	table.insert(self.connections, UserInputService.TouchMoved:Connect(function(io)
		if io ~= self.stickTouch then
			return
		end
		local d = Vector2.new(io.Position.X, io.Position.Y) - self.stickOrigin
		local radius = base.AbsoluteSize.X * 0.42
		local v = d / math.max(1, radius)
		if v.Magnitude > 1 then
			v = v.Unit
		end
		Input.setStick(v)
		knob.Position = UDim2.fromScale(0.5 + v.X * 0.42, 0.5 + v.Y * 0.42)
	end))
	table.insert(self.connections, UserInputService.TouchEnded:Connect(function(io)
		if io == self.stickTouch then
			self.stickTouch = nil
			Input.setStick(Vector2.zero)
			knob.Position = UDim2.fromScale(0.5, 0.5)
		end
		local id = self.touches[io]
		if id then
			self.touches[io] = nil
			-- release only if no other finger still holds the same button
			local still = false
			for _, other in self.touches do
				if other == id then
					still = true
				end
			end
			if not still then
				Input.setTouch(id, false)
				local entry = self.buttons[id]
				if entry then
					entry.button.BackgroundTransparency = 0.3
					entry.stroke.Thickness = 2.5
				end
			end
		end
	end))
	return self
end

function MobileControls:bind(button: GuiButton, id: string, stroke: UIStroke, color: Color3)
	self.buttons[id] = { button = button, stroke = stroke, color = color }
	table.insert(self.connections, button.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			self.touches[io] = id
			Input.setTouch(id, true)
			button.BackgroundTransparency = 0.05
			stroke.Thickness = 4
			if io.UserInputType == Enum.UserInputType.MouseButton1 then
				task.delay(0.08, function()
					self.touches[io] = nil
					Input.setTouch(id, false)
					button.BackgroundTransparency = 0.3
					stroke.Thickness = 2.5
				end)
			end
		end
	end))
end

-- Light up the super button when 2 bars are available; relabel to BREAK in a combo.
function MobileControls:update(fighter, superCost: number, breakerCost: number)
	local entry = self.buttons.X
	if not entry then
		return
	end
	local inCombo = (fighter.state == "hitstun" or fighter.state == "juggle") and fighter.comboHits >= 2
	local label = entry.button:FindFirstChildOfClass("TextLabel")
	if inCombo then
		if label then
			label.Text = "RAGE"
		end
		entry.stroke.Transparency = fighter.meter >= breakerCost and 0 or 0.7
	else
		if label then
			label.Text = "SUPER"
		end
		entry.stroke.Transparency = fighter.meter >= superCost and 0 or 0.7
	end
	local echo = self.buttons.E
	if echo then
		echo.stroke.Transparency = fighter.echoCD <= 0 and 0 or 0.7
	end
end

function MobileControls:setVisible(v: boolean)
	self.gui.Visible = v
	if not v then
		Input.clearTouch()
	end
end

function MobileControls:destroy()
	for _, c in self.connections do
		c:Disconnect()
	end
	Input.clearTouch()
	self.gui:Destroy()
end

return MobileControls
