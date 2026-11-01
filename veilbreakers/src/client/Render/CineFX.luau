--!nonstrict
-- Editing effects for cinematics, in the style of Roblox animation channels:
--
--   impact frames   2-4 stark black/white frames with the actors as silhouettes
--   speed lines     anime radial lines (texture if uploaded, otherwise procedural)
--   freeze frame    the shot freezes and desaturates, a tilted name card slams in
--   pop captions    meme text that bounces in next to the action
--   whip pan blur   motion blur for fast camera whips between shots
--   flash / vignette
--
-- One instance per cinematic; destroy() removes everything it created, including
-- the post effects it parented to Lighting. Flashing effects respect the player's
-- "flashes" setting (CineFX.flashesEnabled), falling back to gentle versions.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Assets = require(Veil.Assets)

local Client = script.Parent.Parent
local Audio = require(Client.Core.Audio)
local Theme = require(Client.UI.Theme)

local CineFX = {}
CineFX.__index = CineFX

-- Set from the player's settings (Main.client applySettings).
CineFX.flashesEnabled = true

local MEME_FONT = Font.fromEnum(Enum.Font.Bangers)
local CARD_FONT = Font.fromEnum(Enum.Font.LuckiestGuy)

local function frame(parent: Instance, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

function CineFX.new(uiRoot: Instance, zBase: number?)
	local self = setmetatable({}, CineFX)
	self.z = zBase or 40
	self.ui = frame(uiRoot, { Name = "CineFX", Size = UDim2.fromScale(1, 1), ZIndex = self.z })
	self.made = {}
	self.conns = {}
	self.highlights = {}
	self.destroyed = false
	-- dedicated grade for impact / freeze frames (sits on top of the stage grade)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CineFXGrade"
	cc.Enabled = false
	cc.Parent = Lighting
	self.grade = cc
	table.insert(self.made, cc)
	local blur = Instance.new("BlurEffect")
	blur.Name = "CineFXBlur"
	blur.Size = 0
	blur.Parent = Lighting
	self.blur = blur
	table.insert(self.made, blur)
	-- soft vignette
	local vig = frame(self.ui, {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = self.z,
	})
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.22, 1),
		NumberSequenceKeypoint.new(0.78, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	g.Parent = vig
	self.vignette = vig
	return self
end

-------------------------------------------------------------------------------
-- Speed lines
-------------------------------------------------------------------------------

-- Radial anime lines over the whole screen for `duration` seconds.
function CineFX:speedLines(duration: number, color: Color3?, density: number?)
	if self.destroyed then
		return
	end
	local col = color or Color3.new(1, 1, 1)
	local holder = frame(self.ui, { Name = "SpeedLines", Size = UDim2.fromScale(1, 1), ZIndex = self.z + 2, ClipsDescendants = true })
	local tex = Assets.image("FX_SpeedLines")
	local lines = {}
	if tex ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = tex
		img.ImageColor3 = col
		img.Size = UDim2.fromScale(1.6, 1.6)
		img.SizeConstraint = Enum.SizeConstraint.RelativeXX
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.ZIndex = self.z + 2
		img.Parent = holder
		lines.image = img
	else
		local n = density or 46
		for i = 1, n do
			local l = frame(holder, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundColor3 = col,
				BackgroundTransparency = 0.15,
				ZIndex = self.z + 2,
			})
			lines[i] = l
		end
	end
	local t0 = os.clock()
	local lastJitter = -1
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= duration or self.destroyed then
			conn:Disconnect()
			holder:Destroy()
			return
		end
		-- re-roll at ~30 fps for the flickery hand-drawn feel
		if t - lastJitter < 1 / 30 then
			return
		end
		lastJitter = t
		local fadeOut = math.clamp((duration - t) / 0.15, 0, 1)
		if lines.image then
			lines.image.Rotation = math.random() * 360
			lines.image.ImageTransparency = 1 - 0.85 * fadeOut
		else
			for _, l in lines do
				local ang = math.random() * 360
				local r0 = 0.32 + math.random() * 0.22
				local len = 0.5 + math.random() * 0.4
				local a = math.rad(ang)
				l.Rotation = ang
				l.Size = UDim2.new(len, 0, 0, 2 + math.random() * 5)
				l.Position = UDim2.fromScale(0.5 + math.cos(a) * r0 * 0.6, 0.5 + math.sin(a) * r0)
				l.BackgroundTransparency = 1 - (0.85 * fadeOut)
			end
		end
	end)
	table.insert(self.conns, conn)
end

-------------------------------------------------------------------------------
-- Impact frames
-------------------------------------------------------------------------------

local function silhouette(self, rigs, fill: Color3, outline: Color3)
	for _, rig in rigs do
		local hl = self.highlights[rig]
		if not hl then
			hl = Instance.new("Highlight")
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent = rig.model
			self.highlights[rig] = hl
		end
		hl.Enabled = true
		hl.FillColor = fill
		hl.FillTransparency = 0
		hl.OutlineColor = outline
		hl.OutlineTransparency = 0
	end
end

local function clearSilhouettes(self)
	for _, hl in self.highlights do
		hl.Enabled = false
	end
end

-- 2-4 alternating stark frames: white world / black silhouettes, then inverted.
-- `rigs` are the actors to silhouette (Rig objects). Yields for its duration.
function CineFX:impactFrames(rigs, count: number?, sound: string?)
	if self.destroyed then
		return
	end
	Audio.play(sound or "impact_frame", { volume = 1 })
	if not CineFX.flashesEnabled then
		-- gentle version: one contrast punch, no strobing
		self.grade.Enabled = true
		self.grade.Contrast = 0.4
		self.grade.Saturation = -0.4
		TweenService:Create(self.grade, TweenInfo.new(0.35), { Contrast = 0, Saturation = 0 }):Play()
		task.wait(0.35)
		self.grade.Enabled = false
		return
	end
	local n = count or 3
	local g = self.grade
	g.Enabled = true
	self:speedLines(0.08 * n + 0.1, Color3.new(0, 0, 0), 60)
	for i = 1, n do
		if self.destroyed then
			return
		end
		local light = i % 2 == 1
		g.Saturation = -1
		g.Contrast = 2.2
		g.Brightness = light and 0.55 or -0.55
		g.TintColor = Color3.new(1, 1, 1)
		if light then
			silhouette(self, rigs, Color3.new(0, 0, 0), Color3.new(0, 0, 0))
		else
			silhouette(self, rigs, Color3.new(1, 1, 1), Color3.fromHex("#FF2A2A"))
		end
		task.wait(0.07)
	end
	g.Enabled = false
	g.Brightness, g.Contrast, g.Saturation = 0, 0, 0
	clearSilhouettes(self)
end

-------------------------------------------------------------------------------
-- Freeze frame name card
-------------------------------------------------------------------------------

-- Desaturate, slam in a tilted name card, hold, then release. Yields for `hold`.
-- The caller freezes its own animation clock while this runs.
function CineFX:freezeFrame(name: string, sub: string?, accent: Color3?, side: number?, hold: number?)
	if self.destroyed then
		return
	end
	local col = accent or Theme.Colors.gold
	local left = (side or 1) == 1
	Audio.play("scratch", { volume = 0.9 })
	local g = self.grade
	g.Enabled = true
	g.Saturation = -0.75
	g.Contrast = 0.25
	g.Brightness = -0.04
	g.TintColor = Color3.fromHex("#FFF2DA")
	local card = frame(self.ui, {
		Name = "FreezeCard",
		Size = UDim2.fromOffset(760, 170),
		Position = UDim2.new(left and 0.06 or 0.94, 0, 0.6, 0),
		AnchorPoint = Vector2.new(left and 0 or 1, 0.5),
		Rotation = left and -6 or 6,
		ZIndex = self.z + 5,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 2.2
	scale.Parent = card
	local plate = frame(card, {
		Size = UDim2.new(1, 0, 0, 104),
		BackgroundColor3 = col,
		BackgroundTransparency = 0,
		ZIndex = self.z + 5,
	})
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -40, 1, 0)
	nameLabel.Position = UDim2.fromOffset(20, 0)
	nameLabel.Text = name
	nameLabel.TextScaled = true
	nameLabel.FontFace = CARD_FONT
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	nameLabel.ZIndex = self.z + 6
	nameLabel.Parent = plate
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.new(0, 0, 0)
	st.Parent = nameLabel
	if sub and sub ~= "" then
		local strip = frame(card, {
			Size = UDim2.new(0.86, 0, 0, 52),
			Position = UDim2.new(left and 0.08 or 0.06, 0, 0, 98),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0,
			ZIndex = self.z + 5,
		})
		local subLabel = Instance.new("TextLabel")
		subLabel.BackgroundTransparency = 1
		subLabel.Size = UDim2.new(1, -24, 1, -10)
		subLabel.Position = UDim2.fromOffset(12, 5)
		subLabel.Text = string.upper(sub)
		subLabel.TextScaled = true
		subLabel.FontFace = MEME_FONT
		subLabel.TextColor3 = Color3.new(1, 1, 1)
		subLabel.TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
		subLabel.ZIndex = self.z + 6
		subLabel.Parent = strip
	end
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.wait(hold or 1.8)
	if self.destroyed then
		return
	end
	TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Position = UDim2.new(left and -0.8 or 1.8, 0, 0.6, 0),
	}):Play()
	TweenService:Create(g, TweenInfo.new(0.2), { Saturation = 0, Contrast = 0, Brightness = 0 }):Play()
	task.delay(0.22, function()
		card:Destroy()
		if not self.destroyed then
			g.Enabled = false
			g.TintColor = Color3.new(1, 1, 1)
		end
	end)
end

-------------------------------------------------------------------------------
-- Pop captions, flashes, whip blur
-------------------------------------------------------------------------------

-- Meme caption that bounces in at a screen position (scale coords), then fades.
function CineFX:pop(text: string, pos: Vector2?, color: Color3?, size: number?, life: number?)
	if self.destroyed then
		return
	end
	local p = pos or Vector2.new(0.5, 0.35)
	Audio.play("pop", { volume = 0.8, pitchVar = 0.08 })
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(p.X, p.Y)
	label.Size = UDim2.fromOffset(700, size or 110)
	label.Text = text
	label.TextScaled = true
	label.FontFace = MEME_FONT
	label.TextColor3 = color or Color3.fromHex("#FFE14A")
	label.Rotation = math.random(-10, 10)
	label.ZIndex = self.z + 4
	label.Parent = self.ui
	local st = Instance.new("UIStroke")
	st.Thickness = 5
	st.Color = Color3.new(0, 0, 0)
	st.Parent = label
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = label
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local l = life or 1.3
	task.delay(l, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			TweenService:Create(st, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			task.delay(0.26, function()
				label:Destroy()
			end)
		end
	end)
	return label
end

function CineFX:flash(color: Color3?, time: number?)
	if self.destroyed then
		return
	end
	local f = frame(self.ui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color or Color3.new(1, 1, 1),
		BackgroundTransparency = CineFX.flashesEnabled and 0 or 0.6,
		ZIndex = self.z + 6,
	})
	TweenService:Create(f, TweenInfo.new(time or 0.5), { BackgroundTransparency = 1 }):Play()
	task.delay((time or 0.5) + 0.05, function()
		f:Destroy()
	end)
end

-- Motion blur pulse for whip pans.
function CineFX:whip()
	if self.destroyed then
		return
	end
	Audio.play("whoosh_light", { volume = 0.7, pitch = 1.3 })
	self.blur.Size = 26
	TweenService:Create(self.blur, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 0 }):Play()
end

function CineFX:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, c in self.conns do
		c:Disconnect()
	end
	for _, hl in self.highlights do
		hl:Destroy()
	end
	for _, inst in self.made do
		inst:Destroy()
	end
	self.ui:Destroy()
end

return CineFX
