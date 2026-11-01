--!nonstrict
-- Builds the arenas: a matte-painted backdrop (ForgeGUI art) far behind the lane,
-- 3D mid-ground set dressing, foreground silhouettes, lighting, post-processing and
-- ambient particles. Everything created is tagged and cleaned up by StageBuilder.clear.

local Lighting = game:GetService("Lighting")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Assets = require(Veil.Assets)
local Stages = require(Veil.Data.Stages)

local StageLife = require(script.Parent.StageLife)
local StageVariants = require(Veil.Data.StageVariants)

local StageBuilder = {}

local V = Vector3.new
local C = CFrame.new
local A = CFrame.Angles
local rad = math.rad

local current = nil

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function part(parent: Instance, props)
	local p = Instance.new(props.class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape and p:IsA("Part") then
		p.Shape = props.shape
	end
	p.Size = props.size or V(1, 1, 1)
	p.CFrame = props.cf or C()
	p.Color = typeof(props.color) == "string" and hex(props.color) or (props.color or Color3.new(0.5, 0.5, 0.5))
	p.Material = props.material or Enum.Material.SmoothPlastic
	if props.transparency then
		p.Transparency = props.transparency
	end
	if props.reflectance then
		p.Reflectance = props.reflectance
	end
	p.CastShadow = props.shadow ~= false
	p.Name = props.name or "Prop"
	p.Parent = parent
	return p
end

local function light(parent: Instance, color, brightness: number, range: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = typeof(color) == "string" and hex(color) or color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

local function seq(a: number, b: number, c: number?)
	if c then
		return NumberSequence.new({
			NumberSequenceKeypoint.new(0, a),
			NumberSequenceKeypoint.new(0.5, b),
			NumberSequenceKeypoint.new(1, c),
		})
	end
	return NumberSequence.new(a, b)
end
StageBuilder.seq = seq

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.texture or Assets.Particles.Spark
	e.Rate = props.rate or 10
	e.Lifetime = props.lifetime or NumberRange.new(2, 4)
	e.Speed = props.speed or NumberRange.new(0.5, 1.5)
	e.SpreadAngle = props.spread or Vector2.new(30, 30)
	e.Size = props.sizeSeq or seq(props.size or 0.3, 0)
	e.Transparency = props.transparencySeq or seq(0.2, 1)
	e.Color = props.colorSeq or ColorSequence.new(typeof(props.color) == "string" and hex(props.color) or (props.color or Color3.new(1, 1, 1)))
	e.LightEmission = props.lightEmission or 1
	e.LightInfluence = props.lightInfluence or 0
	e.Acceleration = props.accel or V(0, 0, 0)
	e.Drag = props.drag or 0
	e.RotSpeed = props.rotSpeed or NumberRange.new(-30, 30)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = props.dir or Enum.NormalId.Top
	e.ZOffset = props.zoffset or 0
	e.LockedToPart = props.locked == true
	e.Parent = parent
	return e
end
StageBuilder.emitter = emitter

-------------------------------------------------------------------------------
-- Lighting presets
-------------------------------------------------------------------------------

local function applyLighting(stage, theme: string, made: { Instance })
	Lighting.ClockTime = stage.clockTime
	Lighting.Ambient = hex(stage.ambient)
	Lighting.OutdoorAmbient = hex(stage.ambient)
	Lighting.FogColor = hex(stage.fogColor)
	Lighting.FogStart = 0
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ExposureCompensation = 0

	for _, child in Lighting:GetChildren() do
		if child:GetAttribute("VeilStage") or child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	local function add(inst: Instance)
		inst:SetAttribute("VeilStage", true)
		inst.Parent = Lighting
		table.insert(made, inst)
		return inst
	end

	local atmo = Instance.new("Atmosphere")
	atmo.Color = hex(stage.fogColor)
	atmo.Decay = hex(stage.fogColor)
	atmo.Density = 0.3
	atmo.Offset = 0.15
	atmo.Glare = 0
	atmo.Haze = 1.2

	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = true
	sky.StarCount = 3000
	sky.MoonAngularSize = 14
	sky.SunAngularSize = 12

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 1.1
	bloom.Size = 30
	bloom.Threshold = 1.25

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StageGrade"
	cc.Contrast = 0.12
	cc.Saturation = -0.05
	cc.Brightness = 0
	cc.TintColor = Color3.new(1, 1, 1)

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.28
	dof.FocusDistance = 21
	dof.InFocusRadius = 16
	dof.NearIntensity = 0.6

	local rays = nil

	if theme == "forest" then
		Lighting.Brightness = 1.2
		Lighting.ColorShift_Top = hex("#7FA88A")
		Lighting.ColorShift_Bottom = hex("#1C2A20")
		atmo.Density = 0.38
		atmo.Haze = 2.2
		atmo.Color = hex("#4A6A58")
		atmo.Decay = hex("#1A2A22")
		cc.TintColor = hex("#D6F0DC")
		cc.Saturation = -0.12
		cc.Contrast = 0.16
	elseif theme == "monastery" then
		Lighting.Brightness = 2.4
		Lighting.ColorShift_Top = hex("#FFB070")
		Lighting.ColorShift_Bottom = hex("#3A2A3A")
		atmo.Density = 0.3
		atmo.Haze = 1.6
		atmo.Glare = 0.6
		atmo.Color = hex("#C99A8A")
		atmo.Decay = hex("#6A5A7A")
		cc.TintColor = hex("#FFE8D6")
		cc.Saturation = 0.05
		rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.12
		rays.Spread = 0.6
	elseif theme == "cathedral" then
		Lighting.Brightness = 0.9
		Lighting.ColorShift_Top = hex("#8A9AFF")
		Lighting.ColorShift_Bottom = hex("#1A1A2A")
		atmo.Density = 0.34
		atmo.Haze = 1.8
		atmo.Color = hex("#3A3A6A")
		atmo.Decay = hex("#151A2A")
		cc.TintColor = hex("#DCD8FF")
		cc.Saturation = -0.1
		sky.MoonAngularSize = 22
	elseif theme == "volcano" then
		Lighting.Brightness = 1.0
		Lighting.ColorShift_Top = hex("#FF7A3A")
		Lighting.ColorShift_Bottom = hex("#3A0A04")
		atmo.Density = 0.36
		atmo.Haze = 2.4
		atmo.Glare = 0.4
		atmo.Color = hex("#8A2A12")
		atmo.Decay = hex("#2A0A04")
		cc.TintColor = hex("#FFD8C8")
		cc.Saturation = 0.08
		cc.Contrast = 0.18
		sky.StarCount = 0
	elseif theme == "baseplate" then
		Lighting.Brightness = 2.8
		Lighting.ColorShift_Top = hex("#FFFFFF")
		Lighting.ColorShift_Bottom = hex("#000000")
		Lighting.EnvironmentDiffuseScale = 1
		atmo.Density = 0.22
		atmo.Haze = 0.6
		atmo.Color = hex("#C8E0F5")
		atmo.Decay = hex("#9FC3E6")
		cc.TintColor = hex("#FFFFFF")
		cc.Contrast = 0.04
		cc.Saturation = 0.05
		dof.FarIntensity = 0.12
		sky.StarCount = 0
		rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.06
		rays.Spread = 0.5
	else
		Lighting.Brightness = 1.4
		Lighting.ColorShift_Top = hex("#C9B88A")
		Lighting.ColorShift_Bottom = hex("#101114")
		atmo.Density = 0.25
		atmo.Color = hex("#2A2A30")
		atmo.Decay = hex("#101114")
		cc.TintColor = hex("#F2EEE6")
	end

	add(atmo)
	add(sky)
	add(bloom)
	add(cc)
	add(dof)
	if rays then
		add(rays)
	end
	return { grade = cc, bloom = bloom, dof = dof, atmosphere = atmo }
end

-------------------------------------------------------------------------------
-- Shared set-dressing pieces
-------------------------------------------------------------------------------

local function floor(model, stage, _theme)
	local f = part(model, {
		name = "Floor",
		size = V(220, 2, 70),
		cf = C(0, -1, -12),
		color = stage.floorColor,
		material = (Enum.Material :: any)[stage.floorMaterial] or Enum.Material.Slate,
	})
	-- solid so finisher debris (Roblox-style break apart) lands on it
	f.CanCollide = true
	-- lane strip: slightly different tone under the fighters
	part(model, {
		name = "Lane",
		size = V(90, 0.08, 9),
		cf = C(0, 0.0, 0),
		color = Color3.fromHex(stage.floorColor):Lerp(Color3.new(0, 0, 0), 0.15),
		material = (Enum.Material :: any)[stage.floorMaterial] or Enum.Material.Slate,
		shadow = false,
	})
	return f
end

local function backdrop(model, stage)
	local id = Assets.image(stage.backdrop)
	if id == "" then
		return nil
	end
	local p = part(model, {
		name = "Backdrop",
		size = V(250, 141, 1),
		cf = C(0, 26, -100),
		color = Color3.new(0, 0, 0),
		transparency = 1,
		shadow = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 6
	gui.LightInfluence = 0
	gui.Brightness = 1.05
	gui.AlwaysOnTop = false
	gui.Parent = p
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = id
	img.ScaleType = Enum.ScaleType.Crop
	img.Parent = gui
	return p
end

local function rock(model, cf: CFrame, size: Vector3, color: string)
	return part(model, { size = size, cf = cf, color = color, material = Enum.Material.Rock })
end

local function tree(model, x: number, z: number, height: number, thick: number, bark: string, seed: number)
	local trunk = part(model, {
		name = "Trunk",
		size = V(height, thick, thick),
		cf = C(x, height / 2 - 0.5, z) * A(0, 0, rad(90)) * A(rad(seed * 37 % 20 - 10), 0, 0),
		shape = Enum.PartType.Cylinder,
		color = bark,
		material = Enum.Material.Wood,
	})
	-- flared roots
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + seed
		part(model, {
			size = V(thick * 0.45, thick * 1.2, thick * 0.45),
			cf = C(x + math.cos(a) * thick * 0.55, thick * 0.35, z + math.sin(a) * thick * 0.55) * A(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6),
			color = bark,
			material = Enum.Material.Wood,
		})
	end
	-- twisting branches
	local bx, by = x, height * 0.75
	for i = 1, 4 do
		local dir = (i % 2 == 0) and 1 or -1
		local len = height * (0.35 - i * 0.04)
		part(model, {
			size = V(len, thick * (0.35 - i * 0.05), thick * (0.35 - i * 0.05)),
			cf = C(bx + dir * len * 0.4, by + i * height * 0.05, z + (seed % 3 - 1) * 1.5) * A(0, rad(seed * 13 % 40 - 20), rad(dir * (25 + i * 8))),
			shape = Enum.PartType.Cylinder,
			color = bark,
			material = Enum.Material.Wood,
		})
	end
	return trunk
end

-------------------------------------------------------------------------------
-- Themes
-------------------------------------------------------------------------------

local THEMES = {}

THEMES.forest = function(model, _stage, _ctx)
	local bark = "#2A2018"
	-- distant + mid trees
	local positions = {
		{ -34, -26, 26, 3.4 },
		{ -20, -34, 30, 4.2 },
		{ -8, -42, 34, 5 },
		{ 10, -38, 30, 4.4 },
		{ 24, -28, 28, 3.8 },
		{ 38, -34, 32, 4.6 },
		{ -44, -16, 22, 3 },
		{ 46, -18, 24, 3.2 },
		{ -28, -55, 38, 6 },
		{ 30, -58, 40, 6.5 },
	}
	for i, p in positions do
		tree(model, p[1], p[2], p[3], p[4], bark, i)
	end
	-- the great hollow tree with a face of spirit-fire
	local hx, hz = 2, -24
	part(model, { name = "HollowTree", size = V(12, 30, 10), cf = C(hx, 14, hz) * A(0, rad(8), rad(3)), color = "#3A2C20", material = Enum.Material.Wood })
	part(model, { size = V(14, 6, 12), cf = C(hx, 2.5, hz), color = "#2E2218", material = Enum.Material.Wood })
	for _, sx in { -1, 1 } do
		local eye = part(model, {
			name = "SpiritEye",
			size = V(2.0, 1.4, 0.6),
			cf = C(hx + sx * 2.2, 18, hz + 5.2) * A(0, 0, rad(sx * -12)),
			color = "#7DFF8C",
			material = Enum.Material.Neon,
			shadow = false,
		})
		light(eye, "#63FF8A", 3, 18)
		emitter(eye, {
			texture = Assets.Particles.Fire,
			rate = 18,
			lifetime = NumberRange.new(0.8, 1.6),
			speed = NumberRange.new(0.5, 1.5),
			size = 1.6,
			color = "#63FF8A",
			accel = V(0, 2, 0),
		})
	end
	part(model, { size = V(4.5, 3.5, 0.6), cf = C(hx, 12.5, hz + 5.1), color = "#0A0806", material = Enum.Material.SmoothPlastic })
	-- spirit flames along the roots
	for i = 1, 7 do
		local fx = -30 + i * 9 + (i % 2) * 2
		local fz = -14 - (i % 3) * 3
		local anchor = part(model, { size = V(2, 0.4, 2), cf = C(fx, 0.2, fz), color = "#1A1A12", material = Enum.Material.Mud })
		emitter(anchor, {
			texture = Assets.Particles.Fire,
			rate = 22,
			lifetime = NumberRange.new(0.6, 1.4),
			speed = NumberRange.new(1, 3),
			sizeSeq = seq(1.4, 0.6, 0),
			colorSeq = ColorSequence.new(hex("#B6FF9A"), hex("#2ACC5A")),
			accel = V(0, 3, 0),
		})
		light(anchor, "#5BFF6A", 2.2, 14)
	end
	-- hanging moss curtains
	for i = 1, 14 do
		local mx = -40 + i * 6
		part(model, {
			size = V(0.4, 3 + (i % 4), 0.4),
			cf = C(mx, 13 + (i % 3) * 2, -18 - (i % 4) * 4),
			color = "#3A5230",
			material = Enum.Material.Grass,
			shadow = false,
		})
	end
	-- red wildflowers and pale mushrooms near the lane
	for i = 1, 40 do
		local fx = -42 + (i * 2.17) % 84
		local fz = -5 - ((i * 1.37) % 9)
		part(model, {
			size = V(0.32, 0.32, 0.32),
			cf = C(fx, 0.35, fz),
			shape = Enum.PartType.Ball,
			color = i % 5 == 0 and "#D8D2C0" or "#B0141E",
			material = i % 5 == 0 and Enum.Material.SmoothPlastic or Enum.Material.Neon,
			shadow = false,
		})
	end
	-- still black water pools
	for i = 1, 4 do
		part(model, {
			size = V(12, 0.1, 6),
			cf = C(-30 + i * 15, 0.06, -9 - (i % 2) * 3),
			color = "#0C1210",
			material = Enum.Material.Glass,
			reflectance = 0.35,
			transparency = 0.1,
			shadow = false,
		})
	end
	-- rocks & roots crossing behind the lane
	for i = 1, 8 do
		rock(model, C(-38 + i * 10, 0.4, -7 - (i % 3)) * A(rad(i * 23), rad(i * 41), 0), V(1.6 + i % 3, 1 + i % 2, 1.4), "#2E2A24")
	end
	-- foreground silhouettes (out of focus)
	part(model, { size = V(2.4, 26, 2.4), cf = C(-26, 12, 9) * A(0, 0, rad(-6)), color = "#0A0806", material = Enum.Material.Wood })
	part(model, { size = V(2.8, 28, 2.8), cf = C(29, 13, 10) * A(0, 0, rad(8)), color = "#0A0806", material = Enum.Material.Wood })
	part(model, { size = V(18, 1.4, 1.4), cf = C(-18, 22, 8) * A(0, 0, rad(-20)), color = "#0A0806", material = Enum.Material.Wood })
	-- floating motes & low mist
	local air = part(model, { name = "Motes", size = V(90, 12, 30), cf = C(0, 6, -12), transparency = 1, shadow = false })
	emitter(air, {
		rate = 26,
		lifetime = NumberRange.new(4, 8),
		speed = NumberRange.new(0.2, 0.6),
		size = 0.18,
		color = "#B8FF9A",
		spread = Vector2.new(180, 180),
	})
	local mist = part(model, { name = "Mist", size = V(110, 1, 26), cf = C(0, 0.6, -6), transparency = 1, shadow = false })
	emitter(mist, {
		texture = Assets.Particles.Smoke,
		rate = 8,
		lifetime = NumberRange.new(8, 12),
		speed = NumberRange.new(0.3, 0.8),
		sizeSeq = seq(6, 12),
		transparencySeq = seq(1, 0.85, 1),
		color = "#9AB8A6",
		lightEmission = 0,
		lightInfluence = 1,
		dir = Enum.NormalId.Right,
	})
end

THEMES.monastery = function(model, _stage, ctx)
	local wood = "#3A1E14"
	local roof = "#2A3A3A"
	-- courtyard stones
	for i = -9, 9 do
		part(model, {
			size = V(4.6, 0.12, 2.2),
			cf = C(i * 4.8, 0.05, -4.2),
			color = (i % 2 == 0) and "#BDB6AC" or "#AFA89E",
			material = Enum.Material.Slate,
			shadow = false,
		})
	end
	-- temple halls behind the lane
	for i, hx in { -26, 0, 26 } do
		local z = -26 - (i == 2 and 6 or 0)
		local h = i == 2 and 12 or 9
		part(model, { size = V(18, h, 8), cf = C(hx, h / 2, z), color = "#5A2A1E", material = Enum.Material.WoodPlanks })
		for k = 0, 1 do
			local w = 24 - k * 6
			local y = h + 1 + k * 4
			part(model, { class = "WedgePart", size = V(w, 3, 7), cf = C(hx, y, z - 3.5), color = roof, material = Enum.Material.Slate })
			part(model, { class = "WedgePart", size = V(w, 3, 7), cf = C(hx, y, z + 3.5) * A(0, rad(180), 0), color = roof, material = Enum.Material.Slate })
			part(model, { size = V(w + 1, 0.4, 0.6), cf = C(hx, y - 1.4, z - 6.6), color = "#C9A24A", material = Enum.Material.Metal })
		end
		for c = -2, 2 do
			part(model, { size = V(0.8, h, 0.8), cf = C(hx + c * 4, h / 2, z - 4.2), color = "#7A1E14", material = Enum.Material.Wood })
		end
		-- glowing paper lanterns
		for c = -1, 1 do
			local lan = part(model, {
				size = V(1.1, 1.4, 1.1),
				cf = C(hx + c * 5, h - 2.5, z - 5),
				shape = Enum.PartType.Ball,
				color = "#FFB25A",
				material = Enum.Material.Neon,
				shadow = false,
			})
			light(lan, "#FFB25A", 2.5, 16)
		end
	end
	-- stone railing at the cliff edge behind
	for i = -12, 12 do
		part(model, { size = V(0.8, 2.4, 0.8), cf = C(i * 3.6, 1.2, -12), color = "#8A867E", material = Enum.Material.Slate })
	end
	part(model, { size = V(90, 0.6, 0.9), cf = C(0, 2.5, -12), color = "#8A867E", material = Enum.Material.Slate })
	-- prayer flags on ropes
	ctx.flags = {}
	for row = 0, 1 do
		for i = -10, 10 do
			local colors = { "#C0392B", "#2E86C1", "#F1C40F", "#27AE60", "#ECF0F1" }
			local f = part(model, {
				size = V(1.0, 1.2, 0.05),
				cf = C(i * 2.6, 10 - math.abs(i) * 0.12 + row * 3, -14 - row * 6),
				color = colors[(i % 5) + 1],
				material = Enum.Material.Fabric,
				shadow = false,
			})
			table.insert(ctx.flags, { part = f, base = f.CFrame, phase = i * 0.7 + row })
		end
	end
	-- incense burner
	local burner = part(model, { size = V(2.4, 2, 2.4), cf = C(0, 1, -8), shape = Enum.PartType.Cylinder, color = "#5A4A2A", material = Enum.Material.Metal })
	burner.CFrame = C(0, 1, -8) * A(0, 0, rad(90))
	emitter(burner, {
		texture = Assets.Particles.Smoke,
		rate = 4,
		lifetime = NumberRange.new(4, 6),
		speed = NumberRange.new(1, 2),
		sizeSeq = seq(1, 4),
		transparencySeq = seq(0.6, 1),
		color = "#D8D0C8",
		lightEmission = 0,
		lightInfluence = 1,
		dir = Enum.NormalId.Right,
	})
	light(burner, "#FF9A4A", 1.5, 10)
	-- falling snow
	local snow = part(model, { name = "Snow", size = V(100, 1, 40), cf = C(0, 24, -6), transparency = 1, shadow = false })
	emitter(snow, {
		rate = 60,
		lifetime = NumberRange.new(6, 9),
		speed = NumberRange.new(2, 4),
		size = 0.2,
		color = "#FFFFFF",
		lightEmission = 0.3,
		lightInfluence = 1,
		accel = V(1.2, 0, 0),
		dir = Enum.NormalId.Bottom,
		spread = Vector2.new(15, 15),
	})
	-- foreground pillar silhouettes
	part(model, { size = V(2.2, 30, 2.2), cf = C(-28, 15, 10), color = "#2A0E0A", material = Enum.Material.Wood })
	part(model, { size = V(2.2, 30, 2.2), cf = C(30, 15, 10), color = "#2A0E0A", material = Enum.Material.Wood })
	part(model, { size = V(70, 1.4, 1.6), cf = C(0, 26, 10), color = "#2A0E0A", material = Enum.Material.Wood })
	local _ = wood
end

THEMES.cathedral = function(model, _stage, _ctx)
	local stone = "#3A3C46"
	-- reflective flood water around the stone lane
	part(model, {
		name = "Water",
		size = V(220, 0.2, 60),
		cf = C(0, 0.08, -32),
		color = "#0C1022",
		material = Enum.Material.Glass,
		reflectance = 0.45,
		transparency = 0.05,
		shadow = false,
	})
	-- columns
	for i = -6, 6 do
		for row = 0, 1 do
			local x = i * 9 + row * 4.5
			local z = -14 - row * 14
			local broken = (i + row) % 4 == 0
			local h = broken and (8 + (i % 3) * 3) or 30
			part(model, { size = V(h, 2.4, 2.4), cf = C(x, h / 2, z) * A(0, 0, rad(90)), shape = Enum.PartType.Cylinder, color = stone, material = Enum.Material.Slate })
			part(model, { size = V(3.4, 1.2, 3.4), cf = C(x, 0.6, z), color = "#2A2C34", material = Enum.Material.Slate })
			if not broken then
				part(model, { size = V(3.6, 1.4, 3.6), cf = C(x, h - 0.6, z), color = "#2A2C34", material = Enum.Material.Slate })
			end
		end
	end
	-- vault ribs
	for i = -3, 3 do
		part(model, { size = V(1.2, 1.2, 40), cf = C(i * 18, 34, -20) * A(rad(-8), 0, 0), color = stone, material = Enum.Material.Slate })
	end
	-- rose window (ring of glowing panes)
	local cx, cy, cz = 0, 26, -44
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		part(model, {
			size = V(3.2, 1.6, 0.4),
			cf = C(cx + math.cos(a) * 9, cy + math.sin(a) * 9, cz) * A(0, 0, a + math.pi / 2),
			color = i % 2 == 0 and "#6A5AFF" or "#B07AFF",
			material = Enum.Material.Neon,
			shadow = false,
		})
		part(model, {
			size = V(0.6, 8, 0.3),
			cf = C(cx + math.cos(a) * 4.5, cy + math.sin(a) * 4.5, cz + 0.1) * A(0, 0, a + math.pi / 2),
			color = "#2A2A3A",
			material = Enum.Material.Slate,
		})
	end
	local core = part(model, { size = V(4, 4, 0.4), cf = C(cx, cy, cz), color = "#C9B8FF", material = Enum.Material.Neon, shadow = false })
	light(core, "#9A8AFF", 4, 40)
	-- moonlight shafts
	for i = -1, 1 do
		local shaft = part(model, {
			size = V(5, 40, 5),
			cf = C(i * 14, 18, -16) * A(rad(-12), 0, rad(i * 8)),
			color = "#B8C8FF",
			material = Enum.Material.Neon,
			transparency = 0.93,
			shadow = false,
		})
		local _ = shaft
	end
	-- candles
	for i = 1, 22 do
		local x = -40 + (i * 3.9) % 80
		local z = -7 - (i % 4) * 1.8
		part(model, { size = V(0.3, 0.8 + (i % 3) * 0.3, 0.3), cf = C(x, 0.5, z), color = "#E8E0CC", material = Enum.Material.SmoothPlastic })
		local fl = part(model, { size = V(0.16, 0.3, 0.16), cf = C(x, 1.1 + (i % 3) * 0.15, z), color = "#FFC86A", material = Enum.Material.Neon, shadow = false })
		if i % 3 == 0 then
			light(fl, "#FFB25A", 1.2, 8)
		end
	end
	-- faceless statues
	for _, sx in { -1, 1 } do
		local x = sx * 22
		part(model, { size = V(3, 2, 3), cf = C(x, 1, -10), color = "#2A2C34", material = Enum.Material.Slate })
		part(model, { size = V(2.4, 6, 1.6), cf = C(x, 5, -10), color = "#4A4C56", material = Enum.Material.Marble })
		part(model, { size = V(1.4, 1.6, 1.4), cf = C(x, 8.8, -10), color = "#4A4C56", material = Enum.Material.Marble })
		part(model, { size = V(3.4, 0.4, 2.2), cf = C(x, 7.6, -10), color = "#4A4C56", material = Enum.Material.Marble })
	end
	-- hanging chains
	for i = -4, 4 do
		for k = 0, 6 do
			part(model, { size = V(0.25, 0.6, 0.25), cf = C(i * 10 + 3, 30 - k * 0.6, -12), color = "#2A2A2A", material = Enum.Material.Metal, shadow = false })
		end
	end
	-- violet arcane motes
	local air = part(model, { name = "Motes", size = V(90, 16, 30), cf = C(0, 8, -14), transparency = 1, shadow = false })
	emitter(air, {
		rate = 22,
		lifetime = NumberRange.new(5, 9),
		speed = NumberRange.new(0.2, 0.5),
		size = 0.2,
		color = "#C9A0FF",
		spread = Vector2.new(180, 180),
	})
	local mist = part(model, { name = "Mist", size = V(110, 1, 26), cf = C(0, 0.4, -10), transparency = 1, shadow = false })
	emitter(mist, {
		texture = Assets.Particles.Smoke,
		rate = 7,
		lifetime = NumberRange.new(8, 12),
		speed = NumberRange.new(0.3, 0.6),
		sizeSeq = seq(6, 12),
		transparencySeq = seq(1, 0.88, 1),
		color = "#8A8AC8",
		lightEmission = 0,
		lightInfluence = 1,
		dir = Enum.NormalId.Right,
	})
	-- foreground columns
	part(model, { size = V(34, 3, 3), cf = C(-27, 16, 10) * A(0, 0, rad(90)), shape = Enum.PartType.Cylinder, color = "#101118", material = Enum.Material.Slate })
	part(model, { size = V(34, 3, 3), cf = C(28, 16, 10) * A(0, 0, rad(90)), shape = Enum.PartType.Cylinder, color = "#101118", material = Enum.Material.Slate })
end

THEMES.volcano = function(model, _stage, ctx)
	ctx.lava = {}
	-- cracked floor with glowing seams
	for i = 1, 18 do
		local x = -44 + i * 5 + (i % 3)
		local seam = part(model, {
			size = V(3 + (i % 4), 0.06, 0.18),
			cf = C(x, 0.04, -1.5 - (i % 5) * 1.2) * A(0, rad(i * 37), 0),
			color = "#FF6A1A",
			material = Enum.Material.Neon,
			shadow = false,
		})
		table.insert(ctx.lava, seam)
	end
	-- lava river behind the lane
	local river = part(model, {
		name = "LavaRiver",
		size = V(220, 0.4, 10),
		cf = C(0, -0.1, -16),
		color = "#FF4A0A",
		material = Enum.Material.Neon,
		shadow = false,
	})
	table.insert(ctx.lava, river)
	part(model, { size = V(220, 1.2, 1.6), cf = C(0, 0.3, -10.8), color = "#1A1412", material = Enum.Material.Basalt })
	part(model, { size = V(220, 1.2, 1.6), cf = C(0, 0.3, -21.2), color = "#1A1412", material = Enum.Material.Basalt })
	for i = 1, 6 do
		local anchor = part(model, { size = V(1, 1, 1), cf = C(-40 + i * 14, 1, -16), transparency = 1, shadow = false })
		light(anchor, "#FF5A1A", 3, 22)
		emitter(anchor, {
			texture = Assets.Particles.Fire,
			rate = 6,
			lifetime = NumberRange.new(0.6, 1.2),
			speed = NumberRange.new(2, 4),
			size = 1.2,
			color = "#FF7A2A",
		})
	end
	-- the throne citadel
	part(model, { size = V(40, 26, 10), cf = C(0, 13, -40), color = "#141010", material = Enum.Material.Basalt })
	part(model, { size = V(10, 16, 4), cf = C(0, 8, -34), color = "#1C1614", material = Enum.Material.Basalt })
	part(model, { size = V(12, 2, 6), cf = C(0, 1, -33), color = "#1C1614", material = Enum.Material.Basalt })
	for _, sx in { -1, 1 } do
		part(model, { size = V(4, 36, 4), cf = C(sx * 22, 18, -38), color = "#100C0C", material = Enum.Material.Basalt })
		part(model, { class = "WedgePart", size = V(4, 8, 4), cf = C(sx * 22, 40, -38), color = "#100C0C", material = Enum.Material.Basalt })
		-- lava falls
		local fall = part(model, {
			size = V(4, 26, 0.6),
			cf = C(sx * 13, 13, -34.6),
			color = "#FF6A1A",
			material = Enum.Material.Neon,
			shadow = false,
		})
		table.insert(ctx.lava, fall)
		-- braziers
		local br = part(model, { size = V(2.2, 1.2, 2.2), cf = C(sx * 9, 1.6, -8), color = "#3A2A1A", material = Enum.Material.CorrodedMetal })
		part(model, { size = V(0.6, 1.2, 0.6), cf = C(sx * 9, 0.6, -8), color = "#2A1A0A", material = Enum.Material.CorrodedMetal })
		emitter(br, {
			texture = Assets.Particles.Fire,
			rate = 30,
			lifetime = NumberRange.new(0.5, 1.0),
			speed = NumberRange.new(2, 4),
			sizeSeq = seq(1.8, 0.4),
			colorSeq = ColorSequence.new(hex("#FFD27A"), hex("#FF3A0A")),
		})
		light(br, "#FF7A2A", 3, 18, true)
	end
	-- green rift high in the smoke
	for i = 0, 6 do
		part(model, {
			size = V(0.8, 6 - math.abs(i - 3), 0.4),
			cf = C(-6 + i * 2, 44 + math.sin(i * 1.7) * 2, -60) * A(0, 0, rad((i % 2 == 0) and 20 or -20)),
			color = "#63FF8A",
			material = Enum.Material.Neon,
			shadow = false,
		})
	end
	-- obsidian spires
	for i = 1, 9 do
		local x = -48 + i * 11
		local h = 10 + (i * 7) % 14
		part(model, { class = "WedgePart", size = V(4, h, 5), cf = C(x, h / 2, -28 - (i % 3) * 5) * A(0, rad(i * 40), 0), color = "#0E0A0A", material = Enum.Material.Basalt })
	end
	-- embers rising
	local air = part(model, { name = "Embers", size = V(100, 2, 30), cf = C(0, 0, -10), transparency = 1, shadow = false })
	emitter(air, {
		rate = 40,
		lifetime = NumberRange.new(3, 6),
		speed = NumberRange.new(1.5, 4),
		size = 0.18,
		colorSeq = ColorSequence.new(hex("#FFD27A"), hex("#FF3A0A")),
		spread = Vector2.new(25, 25),
		accel = V(0.6, 0.6, 0),
	})
	-- chains in the foreground
	for _, sx in { -1, 1 } do
		for k = 0, 12 do
			part(model, { size = V(0.5, 1.0, 0.5), cf = C(sx * 27, 30 - k * 1.0, 9), color = "#0A0808", material = Enum.Material.Metal })
		end
	end
end

-- The default Roblox baseplate: flat, gray, infinite and a little bit sad.
THEMES.baseplate = function(model, _stage, _ctx)
	-- faint stud grid
	for i = -25, 25 do
		part(model, { size = V(0.06, 0.02, 70), cf = C(i * 4, 0.01, -12), color = "#9A999C", material = Enum.Material.SmoothPlastic, shadow = false })
	end
	for k = -8, 8 do
		part(model, { size = V(220, 0.02, 0.06), cf = C(0, 0.01, -12 + k * 4), color = "#9A999C", material = Enum.Material.SmoothPlastic, shadow = false })
	end
	-- the spawn pad everybody has seen a million times
	part(model, { name = "SpawnPad", size = V(6, 1, 6), cf = C(0, 0.5, -14), color = "#A3A2A5", material = Enum.Material.SmoothPlastic })
	part(model, { size = V(4, 0.06, 4), cf = C(0, 1.03, -14), color = "#E8E8E8", material = Enum.Material.SmoothPlastic, shadow = false })
	-- leftover test bricks somebody forgot to delete
	local colors = { "#C4281C", "#0D69AC", "#F5CD30", "#4B974B", "#F2F3F3" }
	local stacks = { { -18, -10 }, { 16, -9 }, { -30, -20 }, { 28, -22 }, { 6, -30 } }
	for si, st in stacks do
		for h = 0, (si % 3) + 1 do
			part(model, {
				size = V(4, 1.2, 2),
				cf = C(st[1] + (h % 2) * 0.6, 0.6 + h * 1.2, st[2]) * A(0, rad(si * 17 + h * 9), 0),
				color = colors[(si + h) % #colors + 1],
				material = Enum.Material.SmoothPlastic,
			})
		end
	end
	-- a sign
	part(model, { size = V(0.4, 5, 0.4), cf = C(-9, 2.5, -8), color = "#6B4A2A", material = Enum.Material.Wood })
	local sign = part(model, { size = V(6, 2.6, 0.3), cf = C(-9, 5.6, -8), color = "#F2F3F3", material = Enum.Material.SmoothPlastic })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "my first game\n(work in progress)\n(since 2014)"
	t.TextColor3 = Color3.fromHex("#1B1B1F")
	t.TextScaled = true
	t.FontFace = Font.fromEnum(Enum.Font.Cartoon)
	t.Parent = gui
	-- floating dust motes in the sun
	local air = part(model, { name = "Motes", size = V(90, 14, 30), cf = C(0, 7, -12), transparency = 1, shadow = false })
	emitter(air, { rate = 8, lifetime = NumberRange.new(5, 9), speed = NumberRange.new(0.2, 0.4), size = 0.12, color = "#FFFFFF", spread = Vector2.new(180, 180) })
end

THEMES.proving = function(model, _stage, _ctx)
	for i = -20, 20 do
		part(model, { size = V(0.08, 0.04, 40), cf = C(i * 4, 0.03, -16), color = "#6A5A2A", material = Enum.Material.Neon, transparency = 0.6, shadow = false })
	end
	for k = 0, 8 do
		part(model, { size = V(170, 0.04, 0.08), cf = C(0, 0.03, -k * 4), color = "#6A5A2A", material = Enum.Material.Neon, transparency = 0.6, shadow = false })
	end
	for i = 1, 10 do
		local x = -50 + i * 10
		local h = 6 + (i % 4) * 3
		part(model, { size = V(3, h, 3), cf = C(x, h / 2 + 4 + (i % 3) * 2, -30 - (i % 2) * 8) * A(0, rad(i * 21), 0), color = "#2A2A30", material = Enum.Material.Slate })
	end
	local air = part(model, { name = "Motes", size = V(90, 16, 30), cf = C(0, 8, -14), transparency = 1, shadow = false })
	emitter(air, { rate = 14, lifetime = NumberRange.new(5, 9), speed = NumberRange.new(0.2, 0.5), size = 0.16, color = "#E8C66A", spread = Vector2.new(180, 180) })
end

-------------------------------------------------------------------------------

function StageBuilder.clear()
	if current then
		StageLife.clear(current.life)
		for _, inst in current.made do
			if inst and inst.Parent then
				inst:Destroy()
			end
		end
		if current.model then
			current.model:Destroy()
		end
		current = nil
	end
end

-- Time of day / weather for this fight (StageVariants). Applied after the theme
-- lighting so it layers on top of each arena's own look.
local function applyVariant(cur, variantId: string?)
	local v = StageVariants.get(variantId)
	cur.variant = variantId or "default"
	if v == StageVariants.Defs.default then
		return
	end
	local fx = cur.fx
	local life = cur.life
	if v.clock then
		Lighting.ClockTime = v.clock
	end
	if v.bright then
		Lighting.Brightness *= v.bright
		Lighting.ExposureCompensation = (v.bright < 0.7) and -0.15 or 0
	end
	if fx and fx.grade and v.tint then
		fx.grade.TintColor = fx.grade.TintColor:Lerp(Color3.fromHex(v.tint), 0.6)
	end
	if fx and fx.atmosphere and v.fog then
		fx.atmosphere.Density = math.clamp(fx.atmosphere.Density + v.fog, 0, 0.75)
		fx.atmosphere.Haze = math.clamp(fx.atmosphere.Haze + v.fog * 6, 0, 10)
	end
	if life then
		life.baseBrightness = Lighting.Brightness
		life.baseAmbient = Lighting.Ambient
		if life.gradeBase and fx and fx.grade then
			life.gradeBase.TintColor = fx.grade.TintColor
		end
		if v.storm and not life.lightning then
			life.lightning = { next = 3 + math.random() * 4, t = -1 }
		end
	end
	if v.weather then
		local sky = part(cur.model, { name = "Weather", size = V(120, 1, 40), cf = C(0, 34, -8), transparency = 1, shadow = false })
		local e = Instance.new("ParticleEmitter")
		e.Name = "Weather"
		e.Texture = Assets.Particles.Spark
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(6, 6)
		e.LightInfluence = 1
		e.Rotation = NumberRange.new(0, 360)
		if v.weather == "rain" then
			e.Rate = 260
			e.Speed = NumberRange.new(60, 80)
			e.Lifetime = NumberRange.new(0.5, 0.7)
			e.Size = NumberSequence.new(0.12)
			e.Color = ColorSequence.new(Color3.fromHex("#C8D8E8"))
			e.Transparency = NumberSequence.new(0.35, 0.6)
			e.Orientation = Enum.ParticleOrientation.VelocityParallel
			e.LightEmission = 0.3
			-- wet floor
			local floorPart = cur.model:FindFirstChild("Floor")
			if floorPart then
				floorPart.Reflectance = math.max(floorPart.Reflectance, 0.22)
			end
		elseif v.weather == "snow" then
			e.Rate = 70
			e.Speed = NumberRange.new(2, 4)
			e.Lifetime = NumberRange.new(9, 12)
			e.Size = NumberSequence.new(0.22)
			e.Acceleration = Vector3.new(0.6, -0.4, 0)
			e.Color = ColorSequence.new(Color3.new(1, 1, 1))
			e.Transparency = NumberSequence.new(0.1, 0.4)
			e.LightEmission = 0.4
			e.RotSpeed = NumberRange.new(-60, 60)
		elseif v.weather == "ash" then
			e.Rate = 90
			e.Speed = NumberRange.new(3, 6)
			e.Lifetime = NumberRange.new(6, 9)
			e.Size = NumberSequence.new(0.2, 0.12)
			e.Acceleration = Vector3.new(2.5, -0.6, 0)
			e.Color = ColorSequence.new(Color3.fromHex("#8A807A"), Color3.fromHex("#FF7A3A"))
			e.Transparency = NumberSequence.new(0.1, 0.6)
			e.LightEmission = 0.2
			e.RotSpeed = NumberRange.new(-90, 90)
		end
		e.Parent = sky
	end
end

-- opts: { variant = StageVariants id }
function StageBuilder.build(stageId: string, opts)
	StageBuilder.clear()
	local stage = Stages.get(stageId)
	local model = Instance.new("Model")
	model.Name = "Stage_" .. stage.id
	local made = {}
	local ctx = { stage = stage }
	floor(model, stage, stage.theme)
	local bd = backdrop(model, stage)
	local builder = THEMES[stage.theme] or THEMES.proving
	builder(model, stage, ctx)
	model.Parent = workspace
	local fx = applyLighting(stage, stage.theme, made)
	current = {
		id = stageId,
		stage = stage,
		model = model,
		backdrop = bd,
		backdropBase = bd and bd.CFrame or nil,
		made = made,
		ctx = ctx,
		fx = fx,
	}
	StageLife.build(current)
	applyVariant(current, opts and opts.variant)
	return current
end

-- Per-frame animation of stage elements; camX gives backdrop parallax. `fighters`
-- (optional, the engine's fighter list) drives the key/rim lighting rig.
function StageBuilder.update(t: number, camX: number, dt: number?, fighters: { any }?)
	local cur = current
	if not cur then
		return
	end
	StageLife.update(cur.life, t, dt or 1 / 60, fighters)
	if cur.backdrop and cur.backdropBase then
		cur.backdrop.CFrame = cur.backdropBase * C(camX * 0.55, 0, 0)
	end
	local ctx = cur.ctx
	if ctx.flags then
		for _, f in ctx.flags do
			f.part.CFrame = f.base * A(math.sin(t * 2.2 + f.phase) * 0.25, 0, math.sin(t * 1.7 + f.phase) * 0.12)
		end
	end
	if ctx.lava then
		local k = 0.5 + 0.5 * math.sin(t * 1.6)
		for i, p in ctx.lava do
			local kk = 0.5 + 0.5 * math.sin(t * 1.3 + i)
			p.Color = Color3.fromRGB(255, 70 + math.floor(50 * kk), 10 + math.floor(20 * k))
		end
	end
end

-- Arena reaction to a fight beat: heavy | super | ko | round
function StageBuilder.react(kind: string)
	if current then
		StageLife.react(current.life, kind)
	end
end

function StageBuilder.current()
	return current
end

return StageBuilder
