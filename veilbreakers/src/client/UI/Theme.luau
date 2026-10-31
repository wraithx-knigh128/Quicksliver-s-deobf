--!nonstrict
-- Visual language for the OOF FIGHTERS 1 interface: black glass panels, thin engraved
-- gold lines, high-contrast serif display type. All layout is authored at a 1600x900
-- design resolution and scaled with a UIScale, so it fits PC, console and phones.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.DesignW = 1600
Theme.DesignH = 900

Theme.Colors = {
	bg = Color3.fromHex("#08090C"),
	panel = Color3.fromHex("#101116"),
	panelHi = Color3.fromHex("#1A1B22"),
	gold = Color3.fromHex("#C9A24A"),
	goldBright = Color3.fromHex("#F0D58A"),
	goldDim = Color3.fromHex("#6E5A2C"),
	ivory = Color3.fromHex("#ECE6D8"),
	text = Color3.fromHex("#E8E2D4"),
	textDim = Color3.fromHex("#8F887A"),
	crimson = Color3.fromHex("#B0141E"),
	crimsonBright = Color3.fromHex("#FF3B3B"),
	jade = Color3.fromHex("#5BFF6A"),
	shadow = Color3.fromHex("#000000"),
	health = Color3.fromHex("#E9DFC6"),
	healthLow = Color3.fromHex("#E04A3A"),
	meter = Color3.fromHex("#E8B24A"),
	echo = Color3.fromHex("#7FE3FF"),
}

Theme.Fonts = {
	display = Font.fromEnum(Enum.Font.Bodoni),
	serif = Font.fromEnum(Enum.Font.Merriweather),
	label = Font.fromEnum(Enum.Font.GothamMedium),
	labelBold = Font.fromEnum(Enum.Font.GothamBold),
	numbers = Font.fromEnum(Enum.Font.Bodoni),
}

local C = Theme.Colors

function Theme.tween(inst: Instance, time: number, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function apply(inst: Instance, props)
	if props then
		for k, v in props do
			if k ~= "children" then
				(inst :: any)[k] = v
			end
		end
	end
	return inst
end

function Theme.new(className: string, props, parent: Instance?)
	local inst = Instance.new(className)
	apply(inst, props)
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = Theme.new

function Theme.frame(parent: Instance, props)
	local f = new("Frame", {
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, parent)
	apply(f, props)
	return f
end

function Theme.label(parent: Instance, text: string, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = C.text,
		FontFace = Theme.Fonts.label,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	}, parent)
	apply(l, props)
	return l
end

function Theme.image(parent: Instance, image: string, props)
	local i = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Crop,
	}, parent)
	apply(i, props)
	return i
end

function Theme.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", {
		Color = color or C.gold,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Theme.textStroke(parent: Instance, thickness: number?, transparency: number?)
	return new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, parent)
end

function Theme.corner(parent: Instance, radius: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, parent)
end

function Theme.gradient(parent: Instance, colors, rotation: number?, transparency)
	local g = new("UIGradient", {
		Color = typeof(colors) == "ColorSequence" and colors or ColorSequence.new(colors[1], colors[2]),
		Rotation = rotation or 0,
	}, parent)
	if transparency then
		g.Transparency = transparency
	end
	return g
end

-- Black glass panel with a thin gold border and an inner highlight line.
function Theme.panel(parent: Instance, props)
	local f = Theme.frame(parent, {
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.18,
	})
	apply(f, props)
	Theme.stroke(f, C.goldDim, 1.2, 0.1)
	Theme.gradient(f, { Color3.fromHex("#1C1D24"), Color3.fromHex("#07080B") }, 90)
	return f
end

-- Horizontal engraved gold rule with fading ends.
function Theme.rule(parent: Instance, props)
	local r = Theme.frame(parent, {
		BackgroundColor3 = C.gold,
		BackgroundTransparency = 0,
		Size = UDim2.new(0, 400, 0, 1),
	})
	apply(r, props)
	Theme.gradient(r, { C.gold, C.gold }, 0, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}))
	return r
end

-- Small rotated diamond ornament.
function Theme.diamond(parent: Instance, size: number, color: Color3?, props)
	local d = Theme.frame(parent, {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color or C.gold,
		BackgroundTransparency = 0,
		Rotation = 45,
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	apply(d, props)
	return d
end

-- Full-screen root container scaled from the design resolution.
function Theme.root(screenGui: ScreenGui)
	local root = Theme.frame(screenGui, {
		Name = "Root",
		Size = UDim2.fromOffset(Theme.DesignW, Theme.DesignH),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	local scale = new("UIScale", {}, root)
	local function refit()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(Theme.DesignW, Theme.DesignH)
		local s = math.min(vp.X / Theme.DesignW, vp.Y / Theme.DesignH)
		scale.Scale = math.max(0.3, s)
		-- widen the root to cover ultrawide / tall screens so edge-anchored UI hugs the edges
		root.Size = UDim2.fromOffset(vp.X / scale.Scale, vp.Y / scale.Scale)
	end
	refit()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end
	return root, scale
end

return Theme
