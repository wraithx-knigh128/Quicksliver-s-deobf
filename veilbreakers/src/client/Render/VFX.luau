--!nonstrict
-- Combat visual effects: hit sparks, essence bursts, block sparks, shockwaves,
-- slash arcs, projectiles, teleports, ground dust, finisher shatters.
-- Everything is client-side and cleaned up with Debris.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Assets = require(Veil.Assets)

local VFX = {}

local V = Vector3.new
local C = CFrame.new
local A = CFrame.Angles
local rad = math.rad

local ELEMENT_COLORS = {
	lightning = { Color3.fromHex("#E8F6FF"), Color3.fromHex("#58B4FF") },
	radiant = { Color3.fromHex("#FFFFFF"), Color3.fromHex("#3FE0C8") },
	nature = { Color3.fromHex("#E6FFD8"), Color3.fromHex("#5BFF6A") },
	shadow = { Color3.fromHex("#F2E6FF"), Color3.fromHex("#A86BFF") },
	ice = { Color3.fromHex("#FFFFFF"), Color3.fromHex("#8FE6FF") },
	fire = { Color3.fromHex("#FFF2C8"), Color3.fromHex("#FF7A1A") },
	ash = { Color3.fromHex("#FFE6E6"), Color3.fromHex("#FF3B4E") },
	soulfire = { Color3.fromHex("#E6FFE8"), Color3.fromHex("#63FF8A") },
	spirit = { Color3.fromHex("#FFFFFF"), Color3.fromHex("#9FEFFF") },
	storm = { Color3.fromHex("#E8F6FF"), Color3.fromHex("#58B4FF") },
	default = { Color3.fromHex("#FFF6E0"), Color3.fromHex("#FFB04A") },
}
VFX.ElementColors = ELEMENT_COLORS

local root: Folder? = nil
local function container(): Instance
	if root and root.Parent then
		return root
	end
	local f = Instance.new("Folder")
	f.Name = "VeilVFX"
	f.Parent = workspace
	root = f
	return f
end

function VFX.clear()
	if root then
		root:Destroy()
		root = nil
	end
end

local function colors(element: string?)
	return ELEMENT_COLORS[element or "default"] or ELEMENT_COLORS.default
end
VFX.colors = colors

local function anchorAt(pos: Vector3, life: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = V(0.2, 0.2, 0.2)
	p.CFrame = C(pos)
	p.Parent = container()
	Debris:AddItem(p, life)
	return p
end

local function burst(parent: Instance, count: number, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.texture or Assets.Particles.Spark
	e.Rate = 0
	e.Lifetime = props.lifetime or NumberRange.new(0.2, 0.45)
	e.Speed = props.speed or NumberRange.new(10, 22)
	e.SpreadAngle = props.spread or Vector2.new(180, 180)
	e.Size = props.size or NumberSequence.new(0.5, 0)
	e.Transparency = props.transparency or NumberSequence.new(0, 1)
	e.Color = props.color or ColorSequence.new(Color3.new(1, 1, 1))
	e.LightEmission = props.lightEmission or 1
	e.LightInfluence = 0
	e.Acceleration = props.accel or V(0, 0, 0)
	e.Drag = props.drag or 4
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = props.rotSpeed or NumberRange.new(-200, 200)
	e.EmissionDirection = props.dir or Enum.NormalId.Top
	e.Orientation = props.orientation or Enum.ParticleOrientation.FacingCamera
	e.ZOffset = props.zoffset or 1
	e.Parent = parent
	e:Emit(count)
	return e
end
VFX.burst = burst

local function flashBall(pos: Vector3, color: Color3, size: number, life: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = V(size * 0.3, size * 0.3, size * 0.3)
	p.CFrame = C(pos)
	p.Transparency = 0.05
	p.Parent = container()
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = V(size, size, size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, life + 0.05)
	return p
end
VFX.flashBall = flashBall

local function ring(pos: Vector3, color: Color3, size: number, life: number, flat: boolean?)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = V(0.1, 1, 1)
	-- cylinder axis is X: face the camera (+Z) or lie flat on the ground
	local rot = flat and A(0, 0, rad(90)) or A(0, rad(90), 0)
	p.CFrame = C(pos) * rot
	p.Transparency = 0.2
	p.Parent = container()
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = V(0.05, size, size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, life + 0.05)
	return p
end
VFX.ring = ring

-------------------------------------------------------------------------------
-- Impacts
-------------------------------------------------------------------------------

-- Short-lived point light that flashes the surroundings (fighters, floor, walls).
local function impactLight(parent: BasePart, color: Color3, brightness: number, range: number, life: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	TweenService:Create(l, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0, Range = range * 0.6 }):Play()
	Debris:AddItem(l, life + 0.05)
	return l
end
VFX.impactLight = impactLight

-- Bright streak along the line of the blow (heavies only).
local function streak(pos: Vector3, dir: number, color: Color3, len: number, life: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = V(len, 0.14, 0.14)
	p.CFrame = C(pos + V(dir * len * 0.1, 0, 0.6)) * A(0, 0, rad((math.random() - 0.5) * 30))
	p.Parent = container()
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = V(len * 1.6, 0.02, 0.02),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, life + 0.05)
end

-- Per-strength tuning: light hits stay small and quick so they never clutter the
-- screen; heavies, specials and supers escalate with light, streaks and rings.
local HIT_TUNING = {
	light = { sparks = 7, speed = { 8, 16 }, spark = 0.26, core = { 1.8, 2.4 }, essence = 4, flash = 1.3, light = { 2.5, 8, 0.1 } },
	medium = { sparks = 12, speed = { 10, 22 }, spark = 0.34, core = { 2.6, 3.6 }, essence = 8, flash = 1.9, light = { 4, 11, 0.14 } },
	heavy = { sparks = 20, speed = { 16, 34 }, spark = 0.5, core = { 4.2, 6.6 }, essence = 14, flash = 3.0, light = { 7, 16, 0.22 }, streak = 4.5, ring = 7 },
	special = { sparks = 18, speed = { 14, 30 }, spark = 0.46, core = { 4, 6 }, essence = 12, flash = 2.8, light = { 6, 15, 0.22 }, streak = 4, ring = 6 },
	super = { sparks = 30, speed = { 18, 40 }, spark = 0.6, core = { 5.5, 8.5 }, essence = 20, flash = 4.2, light = { 10, 22, 0.32 }, streak = 6, ring = 14 },
}

-- strength: light | medium | heavy | special | super
function VFX.hit(pos: Vector3, strength: string, element: string?, dir: number, essence: boolean?)
	local cols = colors(element)
	local tune = HIT_TUNING[strength] or HIT_TUNING.medium
	local a = anchorAt(pos + V(0, 0, 0.8), 1.4)
	-- sparks fly the way the blow travelled, with a smaller radial spray
	burst(a, math.ceil(tune.sparks * 0.65), {
		color = ColorSequence.new(cols[1], cols[2]),
		speed = NumberRange.new(tune.speed[1], tune.speed[2]),
		spread = Vector2.new(55, 55),
		dir = dir > 0 and Enum.NormalId.Right or Enum.NormalId.Left,
		size = NumberSequence.new(tune.spark, 0),
		lifetime = NumberRange.new(0.12, 0.32),
		orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	burst(a, math.floor(tune.sparks * 0.35), {
		color = ColorSequence.new(cols[1], cols[2]),
		speed = NumberRange.new(tune.speed[1] * 0.6, tune.speed[2] * 0.6),
		size = NumberSequence.new(tune.spark * 0.7, 0),
		lifetime = NumberRange.new(0.08, 0.2),
		orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	burst(a, 1, {
		texture = Assets.Particles.ExplosionCore,
		color = ColorSequence.new(cols[1], cols[2]),
		speed = NumberRange.new(0, 0),
		size = NumberSequence.new(tune.core[1], tune.core[2]),
		lifetime = NumberRange.new(0.1, 0.15),
		transparency = NumberSequence.new(0, 1),
	})
	if essence ~= false then
		-- stylised crimson "essence" spray
		burst(a, tune.essence, {
			color = ColorSequence.new(Color3.fromHex("#B0101C"), Color3.fromHex("#4A0408")),
			speed = NumberRange.new(6, tune.speed[2] * 0.55),
			spread = Vector2.new(40, 40),
			dir = dir > 0 and Enum.NormalId.Right or Enum.NormalId.Left,
			size = NumberSequence.new(tune.spark * 0.75, 0.05),
			lifetime = NumberRange.new(0.35, 0.7),
			accel = V(0, -60, 0),
			drag = 1,
			lightEmission = 0.1,
		})
	end
	flashBall(pos, cols[1], tune.flash, tune.streak and 0.16 or 0.09)
	impactLight(a, cols[2], tune.light[1], tune.light[2], tune.light[3])
	if tune.streak then
		streak(pos, dir, cols[1], tune.streak, 0.12)
	end
	if tune.ring then
		ring(pos, cols[2], tune.ring, 0.3)
	end
	if element and element ~= "default" then
		VFX.elementBurst(pos, element, tune.streak ~= nil)
	end
end

function VFX.block(pos: Vector3, dir: number, strength: string?)
	local heavy = strength == "heavy" or strength == "special" or strength == "super"
	local a = anchorAt(pos + V(0, 0, 0.8), 1)
	-- sparks deflect back toward the attacker off the guard
	burst(a, heavy and 18 or 10, {
		color = ColorSequence.new(Color3.fromHex("#FFFFFF"), Color3.fromHex("#7FC8FF")),
		speed = NumberRange.new(8, heavy and 24 or 16),
		spread = Vector2.new(60, 60),
		dir = dir > 0 and Enum.NormalId.Left or Enum.NormalId.Right,
		size = NumberSequence.new(heavy and 0.38 or 0.28, 0),
		lifetime = NumberRange.new(0.12, 0.3),
		orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	ring(pos, Color3.fromHex("#9AD8FF"), heavy and 4.6 or 3.2, 0.18)
	impactLight(a, Color3.fromHex("#9AD8FF"), heavy and 4 or 2.5, heavy and 10 or 7, 0.14)
end

-- Small kick-up of dust at the feet (foot plants, dashes). dir = direction it sprays.
function VFX.footDust(pos: Vector3, dir: number)
	local a = anchorAt(pos + V(0, 0.15, 0), 1.4)
	burst(a, 3, {
		texture = Assets.Particles.Smoke,
		color = ColorSequence.new(Color3.fromHex("#B8AE9E")),
		speed = NumberRange.new(1.5, 3.5),
		spread = Vector2.new(25, 10),
		dir = dir > 0 and Enum.NormalId.Right or Enum.NormalId.Left,
		size = NumberSequence.new(0.5, 1.4),
		lifetime = NumberRange.new(0.35, 0.7),
		transparency = NumberSequence.new(0.55, 1),
		lightEmission = 0,
		drag = 4,
	})
end

function VFX.parry(pos: Vector3)
	ring(pos, Color3.fromHex("#FFFFFF"), 8, 0.35)
	flashBall(pos, Color3.fromHex("#FFF6C8"), 4, 0.2)
	local a = anchorAt(pos, 1)
	burst(a, 26, {
		color = ColorSequence.new(Color3.fromHex("#FFFFFF"), Color3.fromHex("#FFD27A")),
		speed = NumberRange.new(14, 30),
		size = NumberSequence.new(0.4, 0),
		orientation = Enum.ParticleOrientation.VelocityParallel,
	})
end

function VFX.elementBurst(pos: Vector3, element: string, big: boolean?)
	local cols = colors(element)
	local a = anchorAt(pos, 2)
	if element == "fire" or element == "soulfire" then
		burst(a, big and 16 or 8, {
			texture = Assets.Particles.Fire,
			color = ColorSequence.new(cols[1], cols[2]),
			speed = NumberRange.new(3, 8),
			size = NumberSequence.new(big and 2.4 or 1.5, 0),
			lifetime = NumberRange.new(0.3, 0.6),
			accel = V(0, 10, 0),
			lightEmission = 1,
		})
	elseif element == "ice" then
		for i = 1, big and 6 or 3 do
			local s = Instance.new("Part")
			s.Anchored = true
			s.CanCollide = false
			s.CanQuery = false
			s.CanTouch = false
			s.CastShadow = false
			s.Material = Enum.Material.Glass
			s.Transparency = 0.25
			s.Color = cols[2]
			s.Size = V(0.3, 1.2, 0.3)
			s.CFrame = C(pos) * A(math.random() * 6, math.random() * 6, math.random() * 6) * C(0, 0.6, 0)
			s.Parent = container()
			TweenService:Create(s, TweenInfo.new(0.45), { Transparency = 1, Size = V(0.05, 0.4, 0.05) }):Play()
			Debris:AddItem(s, 0.5)
			local _ = i
		end
	elseif element == "lightning" or element == "storm" then
		VFX.lightning(pos + V(-1.6, 1.4, 0), pos + V(1.6, -1.0, 0), cols[2], 0.14)
		VFX.lightning(pos + V(1.2, 1.8, 0), pos + V(-1.0, -1.2, 0), cols[1], 0.12)
	elseif element == "shadow" then
		burst(a, big and 14 or 8, {
			texture = Assets.Particles.Smoke,
			color = ColorSequence.new(Color3.fromHex("#3A1A5A"), Color3.fromHex("#0A0612")),
			speed = NumberRange.new(2, 6),
			size = NumberSequence.new(1.4, 3),
			lifetime = NumberRange.new(0.4, 0.8),
			transparency = NumberSequence.new(0.3, 1),
			lightEmission = 0,
		})
	elseif element == "nature" then
		burst(a, big and 18 or 10, {
			color = ColorSequence.new(Color3.fromHex("#B6FF9A"), Color3.fromHex("#2A6A1A")),
			speed = NumberRange.new(6, 14),
			size = NumberSequence.new(0.35, 0),
			lifetime = NumberRange.new(0.4, 0.8),
			accel = V(0, -20, 0),
		})
	else
		burst(a, big and 14 or 8, {
			color = ColorSequence.new(cols[1], cols[2]),
			speed = NumberRange.new(4, 12),
			size = NumberSequence.new(0.4, 0),
			lifetime = NumberRange.new(0.3, 0.6),
		})
	end
end

-- Jagged lightning bolt between two points.
function VFX.lightning(a: Vector3, b: Vector3, color: Color3, life: number)
	local segs = 6
	local prev = a
	for i = 1, segs do
		local t = i / segs
		local p = a:Lerp(b, t)
		if i < segs then
			p += V((math.random() - 0.5) * 0.9, (math.random() - 0.5) * 0.9, 0)
		end
		local mid = (prev + p) / 2
		local len = (p - prev).Magnitude
		local s = Instance.new("Part")
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Material = Enum.Material.Neon
		s.Color = color
		s.Size = V(0.12, 0.12, len)
		s.CFrame = CFrame.lookAt(mid, p)
		s.Parent = container()
		TweenService:Create(s, TweenInfo.new(life), { Transparency = 1 }):Play()
		Debris:AddItem(s, life + 0.05)
		prev = p
	end
end

function VFX.dust(pos: Vector3, big: boolean?)
	local a = anchorAt(pos + V(0, 0.3, 0), 2)
	burst(a, big and 14 or 6, {
		texture = Assets.Particles.Smoke,
		color = ColorSequence.new(Color3.fromHex("#B8AE9E")),
		speed = NumberRange.new(2, big and 7 or 4),
		spread = Vector2.new(80, 10),
		size = NumberSequence.new(big and 1.6 or 1, big and 4 or 2.4),
		lifetime = NumberRange.new(0.5, 1.0),
		transparency = NumberSequence.new(0.45, 1),
		lightEmission = 0,
		drag = 3,
	})
	if big then
		ring(pos + V(0, 0.1, 0), Color3.fromHex("#D8D0C0"), 6, 0.3, true)
	end
end

function VFX.teleport(pos: Vector3, color: Color3)
	local a = anchorAt(pos + V(0, 2.6, 0), 2)
	burst(a, 1, {
		texture = Assets.Particles.Implosion,
		color = ColorSequence.new(color),
		speed = NumberRange.new(0, 0),
		size = NumberSequence.new(7, 1),
		lifetime = NumberRange.new(0.25, 0.25),
	})
	burst(a, 16, {
		texture = Assets.Particles.Smoke,
		color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.6)),
		speed = NumberRange.new(1, 4),
		size = NumberSequence.new(1.6, 3.2),
		lifetime = NumberRange.new(0.5, 0.9),
		transparency = NumberSequence.new(0.3, 1),
		lightEmission = 0.2,
	})
	flashBall(pos + V(0, 2.6, 0), color, 4, 0.22)
end

function VFX.burstShockwave(pos: Vector3, color: Color3)
	ring(pos, color, 16, 0.45)
	ring(pos, Color3.new(1, 1, 1), 9, 0.3)
	flashBall(pos, color, 6, 0.3)
	local a = anchorAt(pos, 2)
	burst(a, 40, {
		color = ColorSequence.new(Color3.new(1, 1, 1), color),
		speed = NumberRange.new(20, 40),
		size = NumberSequence.new(0.5, 0),
		orientation = Enum.ParticleOrientation.VelocityParallel,
	})
end

function VFX.groundEruption(pos: Vector3, element: string, height: number)
	local cols = colors(element)
	for i = 1, 5 do
		local s = Instance.new("Part")
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.Material = element == "nature" and Enum.Material.Wood or Enum.Material.Neon
		s.Color = element == "nature" and Color3.fromHex("#4A3624") or cols[2]
		s.Size = V(0.4, 0.2, 0.4)
		local base = pos + V((i - 3) * 0.5, 0, (math.random() - 0.5) * 1.2)
		s.CFrame = C(base) * A(0, 0, rad((i - 3) * 9))
		s.Parent = container()
		TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
			Size = V(0.45, height * (0.6 + math.random() * 0.4), 0.45),
			CFrame = C(base + V(0, height * 0.4, 0)) * A(0, 0, rad((i - 3) * 9)),
		}):Play()
		task.delay(0.35, function()
			TweenService:Create(s, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(s, 0.75)
	end
	VFX.dust(pos, true)
end

-------------------------------------------------------------------------------
-- Projectiles: build a visual and return an object with :update(pos, t) / :destroy()
-------------------------------------------------------------------------------

local function neon(size: Vector3, color: Color3, shape)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	return p
end

local function attachTrail(p: BasePart, color: Color3, width: number, life: number)
	local a0 = Instance.new("Attachment")
	a0.Position = V(0, width / 2, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = V(0, -width / 2, 0)
	a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.Lifetime = life
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Parent = p
	return tr
end

local PROJ = {}

PROJ.lightning_bolt = function(m, cols)
	local core = neon(V(1.6, 0.35, 0.35), cols[1])
	core.Parent = m
	local glow = neon(V(2.0, 0.7, 0.7), cols[2])
	glow.Transparency = 0.5
	glow.Parent = m
	attachTrail(core, cols[2], 0.8, 0.18)
	local l = Instance.new("PointLight")
	l.Color = cols[2]
	l.Brightness = 3
	l.Range = 12
	l.Parent = core
	return function(cf, t)
		core.CFrame = cf * A(t * 7, 0, 0)
		glow.CFrame = cf * A(-t * 5, 0, 0)
	end
end
PROJ.halo_disc = function(m, cols)
	local d = neon(V(0.15, 1.6, 1.6), cols[2], Enum.PartType.Cylinder)
	d.Parent = m
	local inner = neon(V(0.18, 1.0, 1.0), cols[1], Enum.PartType.Cylinder)
	inner.Parent = m
	attachTrail(d, cols[2], 1.2, 0.2)
	return function(cf, t)
		local r = cf * A(0, rad(90), 0) * A(t * 14, 0, 0)
		d.CFrame = r
		inner.CFrame = r
	end
end
PROJ.thorns = function(m, cols)
	local parts = {}
	for i = 1, 4 do
		local s = Instance.new("Part")
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.Material = Enum.Material.Wood
		s.Color = Color3.fromHex("#4A3624")
		s.Size = V(0.35, 1.6, 0.35)
		s.Parent = m
		parts[i] = s
	end
	local g = neon(V(1.6, 0.1, 1.0), cols[2])
	g.Transparency = 0.4
	g.Parent = m
	return function(cf, t)
		for i, s in parts do
			local ph = (t * 10 + i * 1.7) % 3
			local h = math.clamp(ph, 0, 1.5)
			s.CFrame = cf * C((i - 2.5) * 0.4, -0.6 + h * 0.6, (i % 2 - 0.5) * 0.4) * A(0, 0, rad((i - 2.5) * 12))
		end
		g.CFrame = cf * C(0, -0.55, 0)
	end
end
PROJ.shadow_orb = function(m, cols)
	local o = Instance.new("Part")
	o.Shape = Enum.PartType.Ball
	o.Anchored = true
	o.CanCollide = false
	o.CanQuery = false
	o.CanTouch = false
	o.CastShadow = false
	o.Material = Enum.Material.ForceField
	o.Color = cols[2]
	o.Size = V(1.6, 1.6, 1.6)
	o.Parent = m
	local core = neon(V(0.7, 0.7, 0.7), Color3.fromHex("#0A0612"), Enum.PartType.Ball)
	core.Material = Enum.Material.SmoothPlastic
	core.Parent = m
	local e = Instance.new("ParticleEmitter")
	e.Texture = Assets.Particles.Smoke
	e.Rate = 30
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(0.5, 1)
	e.Size = NumberSequence.new(1, 2)
	e.Transparency = NumberSequence.new(0.4, 1)
	e.Color = ColorSequence.new(Color3.fromHex("#3A1A5A"))
	e.LightEmission = 0.4
	e.Parent = o
	return function(cf, t)
		local s = 1.5 + math.sin(t * 12) * 0.15
		o.Size = V(s, s, s)
		o.CFrame = cf
		core.CFrame = cf
	end
end
PROJ.ice_shard = function(m, cols)
	local s = Instance.new("WedgePart")
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.Material = Enum.Material.Glass
	s.Transparency = 0.15
	s.Color = cols[2]
	s.Size = V(0.6, 0.8, 1.8)
	s.Parent = m
	local core = neon(V(0.25, 0.3, 1.4), cols[1])
	core.Parent = m
	attachTrail(core, cols[2], 0.6, 0.2)
	return function(cf, t)
		s.CFrame = cf * A(0, rad(-90), 0) * A(0, 0, t * 6)
		core.CFrame = cf * A(0, rad(90), 0)
	end
end
PROJ.ice_wall = function(m, cols)
	local w = Instance.new("Part")
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Material = Enum.Material.Glass
	w.Transparency = 0.2
	w.Color = cols[2]
	w.Size = V(1.2, 0.2, 2.4)
	w.Parent = m
	local spikes = {}
	for i = 1, 3 do
		local sp = Instance.new("WedgePart")
		sp.Anchored = true
		sp.CanCollide = false
		sp.CanQuery = false
		sp.CanTouch = false
		sp.Material = Enum.Material.Glass
		sp.Transparency = 0.25
		sp.Color = cols[1]
		sp.Size = V(0.5, 1.4, 0.8)
		sp.Parent = m
		spikes[i] = sp
	end
	return function(cf, t)
		local h = math.min(4.4, t * 40)
		w.Size = V(1.2, h, 2.4)
		w.CFrame = cf * C(0, -2.2 + h / 2, 0)
		for i, sp in spikes do
			sp.CFrame = cf * C((i - 2) * 0.35, -2.2 + h + 0.4, (i - 2) * 0.5) * A(0, rad(i * 60), 0)
		end
	end
end
PROJ.chakram = function(m, cols)
	local r = neon(V(0.15, 1.3, 1.3), cols[2], Enum.PartType.Cylinder)
	r.Parent = m
	local g = Instance.new("Part")
	g.Shape = Enum.PartType.Cylinder
	g.Anchored = true
	g.CanCollide = false
	g.CanQuery = false
	g.CanTouch = false
	g.Material = Enum.Material.Metal
	g.Color = Color3.fromHex("#E9C46A")
	g.Size = V(0.17, 1.0, 1.0)
	g.Parent = m
	attachTrail(r, cols[2], 1.0, 0.2)
	return function(cf, t)
		local c = cf * A(0, 0, rad(90)) * A(t * 30, 0, 0)
		r.CFrame = c
		g.CFrame = c
	end
end
PROJ.bolt = function(m, cols)
	local b = Instance.new("Part")
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.Material = Enum.Material.Metal
	b.Color = Color3.fromHex("#D8D8E0")
	b.Size = V(1.4, 0.1, 0.1)
	b.Parent = m
	local tip = neon(V(0.3, 0.2, 0.2), cols[2])
	tip.Parent = m
	attachTrail(b, cols[2], 0.25, 0.12)
	return function(cf)
		b.CFrame = cf
		tip.CFrame = cf * C(0.75, 0, 0)
	end
end
PROJ.hook = function(m, cols)
	local h = Instance.new("Part")
	h.Anchored = true
	h.CanCollide = false
	h.CanQuery = false
	h.CanTouch = false
	h.Material = Enum.Material.Metal
	h.Color = Color3.fromHex("#5A5A5A")
	h.Size = V(0.5, 0.7, 0.2)
	h.Parent = m
	local chain = neon(V(1, 0.08, 0.08), cols[2])
	chain.Material = Enum.Material.Metal
	chain.Color = Color3.fromHex("#3A3A3A")
	chain.Parent = m
	return function(cf, _t, origin)
		h.CFrame = cf
		if origin then
			local mid = (origin + cf.Position) / 2
			local len = (cf.Position - origin).Magnitude
			chain.Size = V(math.max(0.1, len), 0.08, 0.08)
			chain.CFrame = CFrame.lookAt(mid, cf.Position) * A(0, rad(90), 0)
		end
	end
end
PROJ.trap = function(m, cols)
	local base = Instance.new("Part")
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Material = Enum.Material.Metal
	base.Color = Color3.fromHex("#3A3A3A")
	base.Size = V(1.4, 0.15, 1.0)
	base.Parent = m
	local teeth = neon(V(1.2, 0.2, 0.08), cols[2])
	teeth.Parent = m
	return function(cf, t)
		base.CFrame = cf * C(0, -0.25, 0)
		teeth.CFrame = cf * C(0, -0.1, 0)
		teeth.Transparency = 0.3 + 0.3 * math.sin(t * 8)
	end
end
PROJ.light_pillar = function(m, cols)
	local p = neon(V(1.8, 0.2, 1.8), cols[1])
	p.Transparency = 0.2
	p.Parent = m
	local outer = neon(V(2.6, 0.2, 2.6), cols[2])
	outer.Transparency = 0.6
	outer.Parent = m
	return function(cf, t)
		local h = math.min(8, t * 50)
		p.Size = V(1.6, h, 1.6)
		p.CFrame = cf * C(0, -3 + h / 2, 0)
		outer.Size = V(2.6, h, 2.6)
		outer.CFrame = cf * C(0, -3 + h / 2, 0)
	end
end
PROJ.fang_spikes = function(m, cols)
	local parts = {}
	for i = 1, 5 do
		local s = neon(V(0.3, 0.2, 0.3), cols[1])
		s.Material = Enum.Material.Glass
		s.Transparency = 0.2
		s.Parent = m
		parts[i] = s
	end
	return function(cf, t)
		local h = math.min(3.2, t * 30)
		for i, s in parts do
			s.Size = V(0.35, h * (0.6 + (i % 3) * 0.2), 0.35)
			s.CFrame = cf * C((i - 3) * 0.4, -1.6 + s.Size.Y / 2, (i % 2 - 0.5) * 0.5) * A(0, 0, rad((i - 3) * 10))
		end
	end
end
PROJ.soulfire = function(m, cols)
	local base = neon(V(1.8, 0.2, 1.2), cols[2])
	base.Transparency = 0.4
	base.Parent = m
	local e = Instance.new("ParticleEmitter")
	e.Texture = Assets.Particles.Fire
	e.Rate = 60
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(3, 6)
	e.Size = NumberSequence.new(1.8, 0.4)
	e.Color = ColorSequence.new(cols[1], cols[2])
	e.LightEmission = 1
	e.Parent = base
	local l = Instance.new("PointLight")
	l.Color = cols[2]
	l.Brightness = 3
	l.Range = 12
	l.Parent = base
	return function(cf)
		base.CFrame = cf * C(0, -1.1, 0)
	end
end
PROJ.seal = function(m, cols)
	local d = neon(V(0.12, 1.8, 1.8), cols[2], Enum.PartType.Cylinder)
	d.Transparency = 0.3
	d.Parent = m
	local inner = neon(V(0.14, 1.1, 1.1), cols[1], Enum.PartType.Cylinder)
	inner.Parent = m
	return function(cf, t)
		local r = cf * A(0, rad(90), 0) * A(t * 4, 0, 0)
		d.CFrame = r
		inner.CFrame = r * A(-t * 8, 0, 0)
	end
end
PROJ.wolf = function(m, cols)
	local body = Instance.new("Part")
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Material = Enum.Material.ForceField
	body.Color = cols[2]
	body.Size = V(2.2, 1.1, 0.9)
	body.Parent = m
	local head = body:Clone()
	head.Size = V(0.9, 0.8, 0.7)
	head.Parent = m
	local legs = {}
	for i = 1, 4 do
		local l = body:Clone()
		l.Size = V(0.25, 0.9, 0.25)
		l.Parent = m
		legs[i] = l
	end
	return function(cf, t)
		local bob = math.abs(math.sin(t * 18)) * 0.25
		body.CFrame = cf * C(0, bob, 0)
		head.CFrame = cf * C(1.35, bob + 0.35, 0)
		for i, l in legs do
			local sx = i <= 2 and 0.8 or -0.8
			local sz = (i % 2 == 0) and 0.3 or -0.3
			l.CFrame = cf * C(sx, -0.75, sz) * A(0, 0, math.sin(t * 18 + i) * 0.6)
		end
	end
end
PROJ.lantern_bomb = function(m, cols)
	local cage = Instance.new("Part")
	cage.Anchored = true
	cage.CanCollide = false
	cage.CanQuery = false
	cage.CanTouch = false
	cage.Material = Enum.Material.Metal
	cage.Color = Color3.fromHex("#1A1C1E")
	cage.Size = V(0.7, 0.9, 0.7)
	cage.Transparency = 0.3
	cage.Parent = m
	local core = neon(V(0.45, 0.6, 0.45), cols[2])
	core.Parent = m
	local l = Instance.new("PointLight")
	l.Color = cols[2]
	l.Brightness = 4
	l.Range = 14
	l.Parent = core
	return function(cf, t)
		cage.CFrame = cf * A(0, t * 3, math.sin(t * 6) * 0.3)
		core.CFrame = cage.CFrame
	end
end
PROJ.ravens = function(m, cols)
	local birds = {}
	for i = 1, 6 do
		local b = Instance.new("Part")
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.Material = Enum.Material.SmoothPlastic
		b.Color = Color3.fromHex("#0E0B10")
		b.Size = V(0.6, 0.15, 0.9)
		b.Parent = m
		local eye = neon(V(0.08, 0.08, 0.08), cols[2])
		eye.Parent = m
		birds[i] = { b, eye }
	end
	return function(cf, t)
		for i, pair in birds do
			local o = C(math.sin(t * 9 + i) * 0.7, math.cos(t * 7 + i * 2) * 0.7, math.sin(t * 5 + i) * 0.5)
			local c = cf * o * A(0, 0, math.sin(t * 30 + i) * 0.6)
			pair[1].CFrame = c
			pair[2].CFrame = c * C(0.3, 0.05, 0)
		end
	end
end
PROJ.raven_dive = function(m, cols)
	local b = Instance.new("Part")
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.Material = Enum.Material.SmoothPlastic
	b.Color = Color3.fromHex("#0E0B10")
	b.Size = V(1.6, 0.25, 2.2)
	b.Parent = m
	attachTrail(b, cols[2], 0.6, 0.25)
	return function(cf, t)
		b.CFrame = cf * A(rad(70), 0, math.sin(t * 25) * 0.3)
	end
end

function VFX.projectile(kind: string, element: string?)
	local m = Instance.new("Model")
	m.Name = "Proj_" .. kind
	local cols = colors(element)
	local builder = PROJ[kind] or PROJ.lightning_bolt
	local update = builder(m, cols)
	m.Parent = container()
	local obj = { model = m, update = update, kind = kind, element = element }
	function obj:set(pos: Vector3, facing: number, t: number, origin: Vector3?)
		local cf = CFrame.new(pos) * (facing < 0 and A(0, math.pi, 0) or CFrame.identity)
		self.update(cf, t, origin)
	end
	function obj:destroy(pos: Vector3?)
		if pos then
			flashBall(pos, cols[2], 2.6, 0.15)
			local a = anchorAt(pos, 1)
			burst(a, 10, {
				color = ColorSequence.new(cols[1], cols[2]),
				speed = NumberRange.new(6, 14),
				size = NumberSequence.new(0.4, 0),
			})
		end
		self.model:Destroy()
	end
	return obj
end

-------------------------------------------------------------------------------
-- Finisher: shatter a rig into glowing shards
-------------------------------------------------------------------------------

function VFX.shatter(rig, color: Color3, style: string?)
	for _, p in rig.allParts do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.Neon
			p.Color = p.Color:Lerp(color, 0.65)
			p.CanCollide = false
			p.Anchored = true
			local here = p.CFrame.Position
			local dir = (here - rig.model:GetPivot().Position)
			if dir.Magnitude < 0.01 then
				dir = V(0, 1, 0)
			end
			dir = dir.Unit
			local target = here + dir * (4 + math.random() * 6) + V(0, 2 + math.random() * 4, (math.random() - 0.5) * 4)
			if style == "nature" then
				target = here - V(0, 4, 0)
			elseif style == "ice" then
				p.Material = Enum.Material.Glass
			end
			TweenService:Create(p, TweenInfo.new(1.4 + math.random() * 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(target) * A(math.random() * 6, math.random() * 6, math.random() * 6),
				Transparency = 1,
				Size = p.Size * 0.4,
			}):Play()
		end
	end
	local pos = rig.model:GetPivot().Position
	VFX.burstShockwave(pos + V(0, 1, 0), color)
	local a = anchorAt(pos + V(0, 1, 0), 4)
	burst(a, 80, {
		color = ColorSequence.new(Color3.new(1, 1, 1), color),
		speed = NumberRange.new(4, 18),
		size = NumberSequence.new(0.5, 0),
		lifetime = NumberRange.new(1, 2.5),
		accel = V(0, 3, 0),
		drag = 1.5,
	})
end

-------------------------------------------------------------------------------
-- Parody finisher: the classic Roblox death. Every part pops loose, flies apart
-- with real physics and clatters onto the floor, with a big "OOF".
-------------------------------------------------------------------------------

function VFX.oofBreak(rig, color: Color3)
	local pivot = rig.model:GetPivot().Position
	for _, p in rig.allParts do
		if p:IsA("BasePart") then
			local here = p.CFrame.Position
			local dir = here - pivot
			if dir.Magnitude < 0.05 then
				dir = V(math.random() - 0.5, 1, math.random() - 0.5)
			end
			dir = dir.Unit
			p.Anchored = false
			p.CanCollide = true
			p.CanQuery = false
			p.Massless = false
			p.AssemblyLinearVelocity = dir * (10 + math.random() * 14) + V(0, 14 + math.random() * 12, (math.random() - 0.5) * 10)
			p.AssemblyAngularVelocity = V((math.random() - 0.5) * 20, (math.random() - 0.5) * 20, (math.random() - 0.5) * 20)
		end
	end
	VFX.burstShockwave(pivot + V(0, 1.5, 0), color)
	-- the OOF
	local a = anchorAt(pivot + V(0, 5, 0), 3)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(420, 160)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = true
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "OOF"
	t.TextColor3 = Color3.fromHex("#FFF2C8")
	t.TextStrokeColor3 = Color3.fromHex("#B0141E")
	t.TextStrokeTransparency = 0
	t.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	t.TextScaled = true
	t.Parent = bb
	TweenService:Create(bb, TweenInfo.new(2.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { StudsOffset = V(0, 4, 0) }):Play()
	task.delay(1.4, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
	-- a little confetti of studs
	burst(a, 40, {
		color = ColorSequence.new(Color3.fromHex("#F5CD30"), Color3.fromHex("#0D69AC")),
		speed = NumberRange.new(8, 20),
		size = NumberSequence.new(0.4, 0.1),
		lifetime = NumberRange.new(1, 2),
		accel = V(0, -30, 0),
		drag = 0.5,
		lightEmission = 0.3,
	})
end

return VFX
