--!nonstrict
-- Applies a player's equipped weapon skin and enchantment to a fighter rig.
-- Purely visual: colours, materials, trail colours, particles and glow. Combat
-- data never changes, so cosmetics can't buff or nerf anyone.

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Items = require(Veil.Data.Items)
local Assets = require(Veil.Assets)

local Cosmetics = {}

local PRIMARY = {
	[Enum.Material.Metal] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Foil] = true,
}
local SECONDARY = {
	[Enum.Material.Wood] = true,
	[Enum.Material.Leather] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Grass] = true,
}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function mat(name: string?)
	if name and (Enum.Material :: any)[name] then
		return (Enum.Material :: any)[name]
	end
	return nil
end

-- particle presets: texture, rate, speed, lifetime, size, accel, spread
local PRESETS = {
	fire = { tex = "Fire", rate = 18, speed = { 0.5, 1.5 }, life = { 0.3, 0.6 }, size = { 0.7, 0 }, accel = Vector3.new(0, 6, 0), emission = 1 },
	frost = { tex = "Spark", rate = 14, speed = { 0.2, 0.6 }, life = { 0.6, 1.2 }, size = { 0.25, 0 }, accel = Vector3.new(0, -2, 0), emission = 0.8 },
	bubbles = { tex = "Glow", rate = 8, speed = { 0.4, 1 }, life = { 0.8, 1.4 }, size = { 0.3, 0.45 }, accel = Vector3.new(0, 3, 0), emission = 0.4 },
	drip = { tex = "Spark", rate = 10, speed = { 0, 0.3 }, life = { 0.5, 0.9 }, size = { 0.2, 0.05 }, accel = Vector3.new(0, -14, 0), emission = 0.6 },
	sparks = { tex = "Spark", rate = 22, speed = { 3, 6 }, life = { 0.08, 0.2 }, size = { 0.25, 0 }, accel = Vector3.zero, emission = 1 },
	smoke = { tex = "Smoke", rate = 10, speed = { 0.2, 0.6 }, life = { 0.6, 1.1 }, size = { 0.6, 1.4 }, accel = Vector3.new(0, 1, 0), emission = 0 },
	sparkle = { tex = "Spark", rate = 10, speed = { 0, 0.3 }, life = { 0.4, 0.9 }, size = { 0.35, 0 }, accel = Vector3.zero, emission = 1 },
	embers = { tex = "FireSparks", rate = 14, speed = { 0.5, 1.5 }, life = { 0.5, 1 }, size = { 0.35, 0 }, accel = Vector3.new(0, 4, 0), emission = 1 },
}

local function emitter(parent: BasePart, preset, color: Color3)
	local p = PRESETS[preset] or PRESETS.sparkle
	local e = Instance.new("ParticleEmitter")
	e.Name = "EnchantFX"
	e.Texture = Assets.Particles[p.tex] or Assets.Particles.Spark
	e.Rate = p.rate
	e.Speed = NumberRange.new(p.speed[1], p.speed[2])
	e.Lifetime = NumberRange.new(p.life[1], p.life[2])
	e.Size = NumberSequence.new(p.size[1], p.size[2])
	e.Acceleration = p.accel
	e.SpreadAngle = Vector2.new(180, 180)
	e.Color = ColorSequence.new(color)
	e.LightEmission = p.emission
	e.LightInfluence = 0
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parent
	return e
end

-- The biggest weapon part held in each hand: where effects attach.
local function hosts(rig)
	local best = {}
	for _, entry in rig.weapon.parts do
		local bone = entry.bone
		if string.find(bone, "Hand") then
			local p = entry.part
			local size = p.Size.Magnitude
			if not best[bone] or size > best[bone].Size.Magnitude then
				best[bone] = p
			end
		end
	end
	local out = {}
	for _, p in best do
		table.insert(out, p)
	end
	return out
end

-- Rarity aura around the fighter: epic motes, legendary haze + light, mythic embers
-- + a pulsing light; a sparkle crown at max weapon level.
local function aura(rig, def, level: number, color: Color3, state)
	local torso = rig.parts and rig.parts.LowerTorso
	if not torso then
		return
	end
	local order = Items.RARITY[def.rarity].order
	local tier = math.max(order >= 6 and 3 or (order >= 5 and 2 or (order >= 4 and 1 or 0)), level >= 8 and 1 or 0)
	if tier <= 0 and level < 10 then
		return
	end
	local function add(parent, preset, col, rate, size)
		local e = emitter(parent, preset, col)
		e.Name = "RarityAura"
		e.Rate = rate
		if size then
			e.Size = NumberSequence.new(size, 0)
		end
		table.insert(state.emitters, e)
		return e
	end
	if tier >= 1 then
		local motes = add(torso, "sparkle", color, 8, 0.3)
		motes.Acceleration = Vector3.new(0, 5, 0)
		motes.Speed = NumberRange.new(0.5, 1.5)
		motes.Lifetime = NumberRange.new(0.8, 1.4)
	end
	if tier >= 2 then
		local haze = add(torso, "bubbles", color, 3, 1.6)
		haze.Transparency = NumberSequence.new(0.75, 1)
		haze.LightEmission = 1
		local l = Instance.new("PointLight")
		l.Name = "RarityGlow"
		l.Color = color
		l.Brightness = 1.2
		l.Range = 9
		l.Shadows = false
		l.Parent = torso
		table.insert(state.auraLights, l)
	end
	if tier >= 3 then
		local embers = add(torso, "embers", Color3.fromHex("#FF4A6A"), 12, 0.35)
		embers.Color = ColorSequence.new(Color3.fromHex("#FF4A6A"), color)
		state.pulseAura = true
	end
	if level >= 10 and rig.parts.Head then
		local crown = add(rig.parts.Head, "sparkle", Color3.fromHex("#FFE27A"), 7, 0.28)
		crown.Acceleration = Vector3.new(0, 3, 0)
		crown.Speed = NumberRange.new(0.2, 0.6)
	end
end

-- cosmetic = { item = weaponSkinId, ench = enchantId?, lvl = 1..10 }
function Cosmetics.apply(rig, cosmetic)
	if not cosmetic or not rig.weapon then
		return false
	end
	local def = Items.WeaponById[cosmetic.item]
	if not def or def.type ~= rig.weapon.type then
		return false
	end
	local ench = cosmetic.ench and Items.EnchantById[cosmetic.ench]
	local fx = ench and ench.fx or {}
	local primary = fx.gold and hex("#FFD24A") or hex(def.primary)
	local primaryMat = fx.gold and Enum.Material.Foil or mat(def.primaryMat)
	local glow = hex(def.glow)
	local glowParts = {}
	for _, entry in rig.weapon.parts do
		local p = entry.part
		local m = p.Material
		if m == Enum.Material.Neon or m == Enum.Material.Glass then
			p.Color = glow
			table.insert(glowParts, p)
		elseif PRIMARY[m] then
			p.Color = primary
			if primaryMat then
				p.Material = primaryMat
			end
			if primaryMat == Enum.Material.Neon then
				table.insert(glowParts, p)
			end
		elseif SECONDARY[m] then
			p.Color = hex(def.secondary)
		end
	end
	local trailColor = fx.trail and hex(fx.trail) or glow
	for _, tr in rig.weapon.trails do
		tr.Color = ColorSequence.new(Color3.new(1, 1, 1), trailColor)
	end
	local level = math.clamp(cosmetic.lvl or 1, 1, Items.MaxLevel)
	local state = { glowParts = glowParts, trails = rig.weapon.trails, lights = {}, emitters = {}, auraLights = {}, anim = fx.animated, glow = glow, level = level }
	-- weapon level makes the trail longer and brighter
	for _, tr in rig.weapon.trails do
		tr.Lifetime = 0.24 + 0.015 * (level - 1)
	end
	if ench then
		for _, host in hosts(rig) do
			local main = emitter(host, fx.particles, hex(fx.color))
			table.insert(state.emitters, main)
			local l = Instance.new("PointLight")
			l.Name = "EnchantGlow"
			l.Color = hex(fx.light or fx.color)
			l.Brightness = 1.6
			l.Range = 7
			l.Shadows = false
			l.Parent = host
			table.insert(state.lights, l)
			-- level 5+: the enchantment runs hotter and throws a second sparkle layer
			if level >= 5 then
				main.Rate = main.Rate * (1 + 0.12 * (level - 4))
				local extra = emitter(host, "sparkle", hex(fx.light or fx.color))
				extra.Rate = 4 + level
				table.insert(state.emitters, extra)
				l.Brightness = 1.6 + 0.15 * (level - 4)
			end
		end
	end
	aura(rig, def, level, glow, state)
	rig.cosmetic = state
	return true
end

-- Per-frame animated enchantments (rainbow, glitch, pulse).
function Cosmetics.update(rig, t: number)
	local st = rig.cosmetic
	if not st then
		return
	end
	if st.pulseAura then
		local k = 0.5 + 0.5 * math.sin(t * 4)
		for _, l in st.auraLights do
			l.Brightness = 0.8 + k * 1.8
		end
	end
	if not st.anim then
		return
	end
	if st.anim == "rainbow" then
		local c = Color3.fromHSV((t * 0.35) % 1, 0.85, 1)
		for _, p in st.glowParts do
			p.Color = c
		end
		for _, l in st.lights do
			l.Color = c
		end
		local seq = ColorSequence.new(Color3.new(1, 1, 1), c)
		for _, tr in st.trails do
			tr.Color = seq
		end
		for _, e in st.emitters do
			e.Color = ColorSequence.new(c)
		end
	elseif st.anim == "glitch" then
		-- hold a colour for a few frames, then snap to another (stuttery texture)
		local slot = math.floor(t * 9)
		if slot ~= st.slot then
			st.slot = slot
			local pick = (slot * 7919) % 3
			local c = pick == 0 and hex("#FF2BD6") or (pick == 1 and hex("#2BE7FF") or st.glow)
			for _, p in st.glowParts do
				p.Color = c
			end
			for _, l in st.lights do
				l.Color = c
			end
		end
	elseif st.anim == "pulse" then
		local k = 0.5 + 0.5 * math.sin(t * 6)
		for _, l in st.lights do
			l.Brightness = 0.8 + k * 2.4
		end
	end
end

return Cosmetics
