--!nonstrict
-- Character dressing: faces, hair, headwear, masks, armour, cloth and weapons.
-- Every piece is attached to a bone with an offset in that bone's local space
-- (unscaled; Rig scales by the fighter's size). Bone space: +Y up the limb,
-- -Z is the front of the body, +X the fighter's right.

local Looks = {}

local V = Vector3.new
local C = CFrame.new
local A = CFrame.Angles
local rad = math.rad

local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder

local function hexDarken(h: string, k: number): Color3
	local c = Color3.fromHex(h)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end
Looks.darken = hexDarken

-------------------------------------------------------------------------------
-- Faces
-------------------------------------------------------------------------------

local FEATURE = "#1A1310"

local function eyes(attach, look, z)
	attach("Head", V(0.17, 0.08, 0.04), C(0.23, 0.07, z), FEATURE, "SmoothPlastic", { shadow = false })
	attach("Head", V(0.17, 0.08, 0.04), C(-0.23, 0.07, z), FEATURE, "SmoothPlastic", { shadow = false })
	attach("Head", V(0.3, 0.06, 0.04), C(0.23, 0.21, z) * A(0, 0, rad(12)), look.hairColor or FEATURE, "SmoothPlastic", { shadow = false })
	attach("Head", V(0.3, 0.06, 0.04), C(-0.23, 0.21, z) * A(0, 0, rad(-12)), look.hairColor or FEATURE, "SmoothPlastic", { shadow = false })
end

local FACES = {}
FACES.plain = function(attach, look)
	eyes(attach, look, -0.62)
	attach("Head", V(0.1, 0.16, 0.06), C(0, -0.06, -0.63), hexDarken(look.skin, 0.88), "SmoothPlastic", { shadow = false })
	attach("Head", V(0.28, 0.04, 0.04), C(0, -0.27, -0.61), "#5A2E26", "SmoothPlastic", { shadow = false })
end
FACES.scarred = function(attach, look)
	FACES.plain(attach, look)
	attach("Head", V(0.04, 0.42, 0.03), C(-0.3, 0.12, -0.635) * A(0, 0, rad(-18)), "#7A2E26", "SmoothPlastic", { shadow = false })
end
FACES.bearded = function(attach, look)
	eyes(attach, look, -0.62)
	attach("Head", V(0.1, 0.16, 0.06), C(0, -0.06, -0.63), hexDarken(look.skin, 0.88), "SmoothPlastic", { shadow = false })
	attach("Head", V(1.0, 0.55, 0.34), C(0, -0.5, -0.42), look.hairColor, "Fabric")
	attach("Head", V(0.55, 0.09, 0.06), C(0, -0.2, -0.63), look.hairColor, "Fabric", { shadow = false })
	attach("Head", V(0.5, 0.35, 0.25), C(0, -0.85, -0.38) * A(rad(-10), 0, 0), look.hairColor, "Fabric")
end
FACES.blindfold = function(attach, look)
	attach("Head", V(1.25, 0.24, 1.25), C(0, 0.1, 0), look.accent, "Fabric")
	attach("Head", V(0.08, 0.6, 0.06), C(0.1, -0.1, 0.66) * A(0, 0, rad(12)), look.accent, "Fabric", {
		swing = { amp = 8, speed = 3, vel = 30, pivot = V(0, 0.2, 0) },
	})
	attach("Head", V(0.28, 0.04, 0.04), C(0, -0.27, -0.61), "#3A1E1E", "SmoothPlastic", { shadow = false })
end
FACES.none = function() end
-- The classic Roblox smile, as a decal on the head.
FACES.classic = function(_attach, _look, rig)
	local head = rig and rig.parts and rig.parts.Head
	if not head then
		return
	end
	local d = Instance.new("Decal")
	d.Name = "face"
	d.Texture = "rbxasset://textures/face.png"
	d.Face = Enum.NormalId.Front
	d.Parent = head
	table.insert(rig.decals, d)
end

-------------------------------------------------------------------------------
-- Hair
-------------------------------------------------------------------------------

local HAIR = {}
HAIR.topknot = function(attach, look)
	attach("Head", V(1.26, 0.34, 1.26), C(0, 0.5, 0.04), look.hairColor, "SmoothPlastic")
	attach("Head", V(1.22, 0.7, 0.2), C(0, 0.22, 0.58), look.hairColor, "SmoothPlastic")
	attach("Head", V(0.46, 0.46, 0.46), C(0, 0.84, 0.2), look.hairColor, "SmoothPlastic", { shape = BALL })
	attach("Head", V(0.2, 0.22, 0.22), C(0, 0.84, 0.2) * A(0, 0, rad(90)), look.trim, "Metal", { shape = CYL })
end
HAIR.braid_long = function(attach, look)
	attach("Head", V(1.27, 0.4, 1.28), C(0, 0.46, 0.04), look.hairColor, "SmoothPlastic")
	attach("Head", V(1.24, 0.95, 0.24), C(0, 0.08, 0.57), look.hairColor, "SmoothPlastic")
	for i = 0, 4 do
		attach("Head", V(0.34, 0.34, 0.34), C(0, -0.45 - i * 0.3, 0.66 + i * 0.02), look.hairColor, "SmoothPlastic", {
			shape = BALL,
			swing = { amp = 3 + i, speed = 2.6, phase = i * 0.4, vel = 25, base = 6, pivot = V(0, 0.4 + i * 0.3, -0.06) },
		})
	end
	attach("Head", V(0.2, 0.22, 0.22), C(0, -0.45, 0.66) * A(0, 0, rad(90)), look.trim, "Metal", { shape = CYL })
end
HAIR.moss = function(attach, look)
	attach("Head", V(0.8, 0.5, 0.8), C(-0.25, 0.55, 0.1), look.hairColor, "Grass", { shape = BALL })
	attach("Head", V(0.7, 0.45, 0.7), C(0.3, 0.55, -0.05), look.hairColor, "Grass", { shape = BALL })
	attach("Head", V(0.9, 0.55, 0.6), C(0, 0.5, 0.45), look.hairColor, "Grass", { shape = BALL })
end
HAIR.bob = function(attach, look)
	attach("Head", V(1.29, 0.44, 1.3), C(0, 0.43, 0.05), look.hairColor, "SmoothPlastic")
	attach("Head", V(0.2, 0.86, 1.05), C(0.63, 0.02, 0.1), look.hairColor, "SmoothPlastic")
	attach("Head", V(0.2, 0.86, 1.05), C(-0.63, 0.02, 0.1), look.hairColor, "SmoothPlastic")
	attach("Head", V(1.26, 0.9, 0.24), C(0, 0.02, 0.6), look.hairColor, "SmoothPlastic")
	attach("Head", V(0.7, 0.3, 0.14), C(0.2, 0.42, -0.58) * A(0, 0, rad(-10)), look.hairColor, "SmoothPlastic")
end
HAIR.long = function(attach, look)
	attach("Head", V(1.28, 0.4, 1.28), C(0, 0.46, 0.04), look.hairColor, "SmoothPlastic")
	attach("Head", V(1.26, 1.9, 0.26), C(0, -0.42, 0.6), look.hairColor, "SmoothPlastic", {
		swing = { amp = 3, speed = 2, vel = 20, base = 4, pivot = V(0, 0.9, -0.05) },
	})
	attach("Head", V(0.2, 1.1, 0.5), C(0.62, -0.05, 0.35), look.hairColor, "SmoothPlastic")
	attach("Head", V(0.2, 1.1, 0.5), C(-0.62, -0.05, 0.35), look.hairColor, "SmoothPlastic")
end
HAIR.ponytail = function(attach, look)
	attach("Head", V(1.27, 0.38, 1.28), C(0, 0.47, 0.04), look.hairColor, "SmoothPlastic")
	attach("Head", V(1.22, 0.6, 0.22), C(0, 0.25, 0.58), look.hairColor, "SmoothPlastic")
	for i = 0, 3 do
		attach("Head", V(0.36 - i * 0.04, 0.5, 0.36 - i * 0.04), C(0, 0.3 - i * 0.42, 0.78 + i * 0.12) * A(rad(-20), 0, 0), look.hairColor, "SmoothPlastic", {
			swing = { amp = 6 + i * 2, speed = 3.2, phase = i * 0.5, vel = 40, base = 10, pivot = V(0, 0.55 + i * 0.42, -0.2 - i * 0.12) },
		})
	end
	attach("Head", V(0.15, 0.3, 0.3), C(0, 0.42, 0.72) * A(0, 0, rad(90)), look.trim, "Metal", { shape = CYL })
end
HAIR.short = function(attach, look)
	attach("Head", V(1.27, 0.36, 1.28), C(0, 0.48, 0.04), look.hairColor, "SmoothPlastic")
	attach("Head", V(1.22, 0.55, 0.22), C(0, 0.2, 0.58), look.hairColor, "SmoothPlastic")
end
HAIR.none = function() end
-- Bacon hair: layered wavy strips of brown and pink.
HAIR.bacon = function(attach, _look)
	local cols = { "#7A3B1E", "#D98C74" }
	for i = 0, 4 do
		attach("Head", V(1.3, 0.15, 1.32), C(0, 0.66 - i * 0.09, 0.04 + i * 0.03) * A(rad(math.sin(i * 1.7) * 6), 0, rad(math.cos(i * 1.3) * 5)), cols[i % 2 + 1], "SmoothPlastic")
	end
	for i = 0, 5 do
		attach("Head", V(1.26, 0.16, 0.22), C(0, 0.42 - i * 0.15, 0.6 + i * 0.01) * A(0, 0, rad(math.sin(i * 2.1) * 7)), cols[i % 2 + 1], "SmoothPlastic", {
			swing = { amp = 2, speed = 2, phase = i * 0.4, vel = 15, pivot = V(0, 0.4 + i * 0.15, 0) },
		})
	end
	for _, sx in { 1, -1 } do
		for i = 0, 2 do
			attach("Head", V(0.18, 0.18, 0.95), C(sx * 0.63, 0.35 - i * 0.18, 0.12), cols[(i + (sx > 0 and 1 or 0)) % 2 + 1], "SmoothPlastic")
		end
	end
end

-------------------------------------------------------------------------------
-- Headwear
-------------------------------------------------------------------------------

local HEAD = {}
HEAD.headband = function(attach, look)
	attach("Head", V(1.27, 0.17, 1.27), C(0, 0.3, 0), look.accent, "Fabric")
	attach("Head", V(0.1, 0.08, 0.95), C(0.12, 0.28, 1.05) * A(rad(-15), rad(8), 0), look.accent, "Fabric", {
		swing = { amp = 10, speed = 4, vel = 60, base = -10, pivot = V(0, 0, -0.45) },
	})
	attach("Head", V(0.1, 0.08, 0.8), C(-0.12, 0.24, 1.0) * A(rad(-25), rad(-8), 0), look.accent, "Fabric", {
		swing = { amp = 12, speed = 3.6, phase = 1, vel = 60, base = -14, pivot = V(0, 0, -0.4) },
	})
end
HEAD.circlet = function(attach, look)
	attach("Head", V(1.28, 0.09, 1.28), C(0, 0.34, 0), look.trim, "Metal", { reflectance = 0.15 })
	attach("Head", V(0.14, 0.2, 0.06), C(0, 0.38, -0.66), look.glow, "Neon", { glow = true })
end
HEAD.hood = function(attach, look)
	local col = hexDarken(look.torso, 1.15)
	attach("Head", V(1.48, 0.26, 1.5), C(0, 0.7, 0.05), col, "Fabric")
	attach("Head", V(0.18, 1.3, 1.45), C(0.73, 0.1, 0.06), col, "Fabric")
	attach("Head", V(0.18, 1.3, 1.45), C(-0.73, 0.1, 0.06), col, "Fabric")
	attach("Head", V(1.48, 1.35, 0.22), C(0, 0.08, 0.76), col, "Fabric")
	attach("Head", V(0.6, 0.5, 0.5), C(0, 0.72, 0.62) * A(rad(-35), 0, 0), col, "Fabric", { class = "WedgePart" })
	attach("Head", V(1.5, 0.14, 0.14), C(0, 0.6, -0.72), look.accent, "Fabric")
end
HEAD.deep_hood = function(attach, look)
	local col = look.torso
	attach("Head", V(1.62, 0.3, 1.7), C(0, 0.78, 0.0), col, "Fabric")
	attach("Head", V(0.22, 1.6, 1.7), C(0.8, 0.02, 0.0), col, "Fabric")
	attach("Head", V(0.22, 1.6, 1.7), C(-0.8, 0.02, 0.0), col, "Fabric")
	attach("Head", V(1.62, 1.6, 0.24), C(0, 0.02, 0.84), col, "Fabric")
	attach("Head", V(1.2, 1.2, 0.06), C(0, 0, -0.5), "#050507", "SmoothPlastic", { shadow = false })
	attach("Head", V(0.7, 0.6, 0.6), C(0, 0.85, 0.7) * A(rad(-30), 0, 0), col, "Fabric", { class = "WedgePart" })
end
HEAD.antlers = function(attach, look)
	local wood = "#5A4630"
	for _, sx in { 1, -1 } do
		attach("Head", V(0.2, 0.75, 0.2), C(0.45 * sx, 0.9, 0.1) * A(0, 0, rad(-28 * sx)), wood, "Wood")
		attach("Head", V(0.16, 0.6, 0.16), C(0.78 * sx, 1.32, 0.12) * A(0, 0, rad(-55 * sx)), wood, "Wood")
		attach("Head", V(0.14, 0.5, 0.14), C(0.6 * sx, 1.5, -0.05) * A(rad(-15), 0, rad(-12 * sx)), wood, "Wood")
		attach("Head", V(0.12, 0.4, 0.12), C(1.05 * sx, 1.55, 0.1) * A(0, 0, rad(-20 * sx)), wood, "Wood")
		attach("Head", V(0.16, 0.16, 0.16), C(1.05 * sx, 1.78, 0.1), look.glow, "Neon", { shape = BALL, glow = true })
	end
end
HEAD.horned_helm = function(attach, look)
	attach("Head", V(1.34, 0.6, 1.34), C(0, 0.4, 0), look.trim, "Metal", { reflectance = 0.1 })
	attach("Head", V(1.38, 0.14, 1.38), C(0, 0.12, 0), hexDarken(look.trim, 0.7), "Metal")
	attach("Head", V(0.13, 0.55, 0.1), C(0, 0.0, -0.68), look.trim, "Metal")
	for _, sx in { 1, -1 } do
		attach("Head", V(0.55, 0.28, 0.28), C(0.85 * sx, 0.5, 0) * A(0, 0, rad(20 * sx)), "#E6DCC6", "SmoothPlastic", { shape = CYL })
		attach("Head", V(0.45, 0.22, 0.22), C(1.18 * sx, 0.78, 0) * A(0, 0, rad(55 * sx)), "#E6DCC6", "SmoothPlastic", { shape = CYL })
		attach("Head", V(0.35, 0.16, 0.16), C(1.3 * sx, 1.12, 0) * A(0, 0, rad(80 * sx)), "#D8CCB0", "SmoothPlastic", { shape = CYL })
	end
end
HEAD.crown = function(attach, look)
	attach("Head", V(1.36, 0.26, 1.36), C(0, 0.72, 0), look.trim, "Metal", { reflectance = 0.2 })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local x, z = math.sin(a) * 0.62, math.cos(a) * 0.62
		attach("Head", V(0.14, 0.62 + (i % 2) * 0.3, 0.14), C(x, 1.05 + (i % 2) * 0.15, z) * A(0, a, 0), look.trim, "Metal")
		if i % 2 == 0 then
			attach("Head", V(0.12, 0.12, 0.12), C(x * 1.03, 0.74, z * 1.03), look.glow, "Neon", { shape = BALL, glow = true })
		end
	end
end
HEAD.tricorn = function(attach, look)
	attach("Head", V(0.12, 2.1, 2.1), C(0, 0.66, 0) * A(0, 0, rad(90)), "#1A1412", "Leather", { shape = CYL })
	attach("Head", V(1.25, 0.55, 1.25), C(0, 0.92, 0), "#1A1412", "Leather")
	attach("Head", V(1.27, 0.12, 1.27), C(0, 0.72, 0), look.trim, "Metal")
	attach("Head", V(0.08, 0.5, 0.3), C(0.66, 1.0, 0.1) * A(0, 0, rad(-25)), look.accent, "Fabric")
end
HEAD.veil_headdress = function(attach, look)
	attach("Head", V(1.32, 0.5, 1.34), C(0, 0.45, 0.06), look.torso, "Fabric")
	attach("Head", V(1.32, 1.7, 0.14), C(0, -0.45, 0.72), look.torso, "Fabric", {
		swing = { amp = 5, speed = 2.5, vel = 35, base = 6, pivot = V(0, 0.85, -0.05) },
	})
	attach("Head", V(1.36, 0.1, 1.36), C(0, 0.24, 0), look.trim, "Metal", { reflectance = 0.25 })
	for i = -2, 2 do
		attach("Head", V(0.04, 0.16, 0.16), C(i * 0.22, 0.12, -0.69) * A(0, rad(90), 0), look.trim, "Metal", { shape = CYL })
	end
	attach("Head", V(0.12, 0.12, 0.06), C(0, 0.4, -0.68), look.glow, "Neon", { glow = true })
end
HEAD.wolf_pelt = function(attach, _look)
	local fur = "#8E949A"
	attach("Head", V(1.38, 0.58, 1.55), C(0, 0.58, 0.1), fur, "Fabric")
	attach("Head", V(0.55, 0.32, 0.65), C(0, 0.52, -0.85), fur, "Fabric")
	attach("Head", V(0.16, 0.12, 0.12), C(0, 0.6, -1.2), "#1A1A1A", "SmoothPlastic")
	for _, sx in { 1, -1 } do
		attach("Head", V(0.16, 0.42, 0.28), C(0.42 * sx, 0.98, 0.05), fur, "Fabric", { class = "WedgePart" })
		attach("Head", V(0.1, 0.06, 0.06), C(0.24 * sx, 0.68, -0.98), "#E0C060", "Neon", { glow = true })
	end
	attach("Head", V(1.42, 1.8, 0.16), C(0, -0.55, 0.78), fur, "Fabric", {
		swing = { amp = 4, speed = 2.2, vel = 30, base = 6, pivot = V(0, 0.9, -0.05) },
	})
end
HEAD.feather_crown = function(attach, look)
	for i = -3, 3 do
		attach("Head", V(0.1, 0.9 - math.abs(i) * 0.08, 0.3), C(i * 0.18, 0.95 - math.abs(i) * 0.04, 0.35 + math.abs(i) * 0.06) * A(rad(-15), 0, rad(-i * 9)), "#0E0B10", "Fabric")
	end
	attach("Head", V(1.3, 0.12, 1.3), C(0, 0.42, 0), look.trim, "Metal")
	attach("Head", V(0.14, 0.14, 0.06), C(0, 0.46, -0.66), look.glow, "Neon", { glow = true })
end
HEAD.none = function() end
-- The legendary guest cap.
HEAD.guest_cap = function(attach, _look)
	attach("Head", V(1.32, 0.44, 1.34), C(0, 0.5, 0.04), "#1B1B1F", "SmoothPlastic")
	attach("Head", V(1.28, 0.08, 0.72), C(0, 0.31, -0.86), "#C4281C", "SmoothPlastic")
	attach("Head", V(0.26, 0.26, 0.04), C(0, 0.52, -0.68), "#F2F3F3", "SmoothPlastic", { shadow = false })
end

-------------------------------------------------------------------------------
-- Masks
-------------------------------------------------------------------------------

local MASK = {}
MASK.skull = function(attach, _look)
	local bone = "#D9D2C0"
	attach("Head", V(1.12, 0.95, 0.22), C(0, 0.06, -0.58), bone, "SmoothPlastic")
	attach("Head", V(0.3, 0.24, 0.06), C(0.25, 0.1, -0.7), "#0C0A08", "SmoothPlastic", { shadow = false })
	attach("Head", V(0.3, 0.24, 0.06), C(-0.25, 0.1, -0.7), "#0C0A08", "SmoothPlastic", { shadow = false })
	attach("Head", V(0.82, 0.32, 0.24), C(0, -0.5, -0.52), bone, "SmoothPlastic")
	for i = -2, 2 do
		attach("Head", V(0.1, 0.12, 0.04), C(i * 0.14, -0.36, -0.66), "#BFB49C", "SmoothPlastic", { shadow = false })
	end
end
MASK.veil = function(attach, look)
	attach("Head", V(1.08, 0.48, 0.1), C(0, -0.28, -0.62), hexDarken(look.torso, 1.3), "Fabric")
	attach("Head", V(0.9, 0.5, 0.06), C(0, -0.72, -0.6) * A(rad(10), 0, 0), hexDarken(look.torso, 1.3), "Fabric", {
		swing = { amp = 4, speed = 3, vel = 30, base = 4, pivot = V(0, 0.25, 0) },
	})
end
MASK.half = function(attach, look)
	attach("Head", V(1.08, 0.5, 0.12), C(0, -0.27, -0.62), "#1A1412", "Leather")
	attach("Head", V(0.5, 0.05, 0.03), C(0, -0.28, -0.69), look.glow, "Neon", { glow = true, shadow = false })
	attach("Head", V(0.1, 0.1, 0.1), C(0.42, -0.15, -0.66), look.trim, "Metal", { shape = BALL })
	attach("Head", V(0.1, 0.1, 0.1), C(-0.42, -0.15, -0.66), look.trim, "Metal", { shape = BALL })
end
MASK.skull_helm = function(attach, look)
	attach("Head", V(1.34, 1.34, 1.34), C(0, 0.03, 0.02), look.torso, "CorrodedMetal")
	attach("Head", V(1.05, 0.95, 0.12), C(0, -0.02, -0.7), "#4A4A42", "CorrodedMetal")
	attach("Head", V(0.3, 0.2, 0.05), C(0.25, 0.08, -0.77), "#050505", "SmoothPlastic", { shadow = false })
	attach("Head", V(0.3, 0.2, 0.05), C(-0.25, 0.08, -0.77), "#050505", "SmoothPlastic", { shadow = false })
	for i = -2, 2 do
		attach("Head", V(0.08, 0.2, 0.04), C(i * 0.15, -0.38, -0.77), "#2A2A24", "SmoothPlastic", { shadow = false })
	end
end
MASK.none = function() end

local function glowEyes(attach, look)
	if not look.eyes then
		return
	end
	local z = -0.64
	if look.mask == "skull" then
		z = -0.74
	elseif look.mask == "skull_helm" then
		z = -0.8
	elseif look.headwear == "deep_hood" then
		z = -0.55
	end
	local l = attach("Head", V(0.2, 0.1, 0.04), C(0.25, 0.08, z), look.eyes, "Neon", { glow = true, shadow = false })
	attach("Head", V(0.2, 0.1, 0.04), C(-0.25, 0.08, z), look.eyes, "Neon", { glow = true, shadow = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex(look.eyes)
	light.Brightness = 1.2
	light.Range = 5
	light.Shadows = false
	light.Parent = l
end

-------------------------------------------------------------------------------
-- Extras (armour / cloth / ornaments)
-------------------------------------------------------------------------------

local EXTRA = {}

EXTRA.sash = function(attach, look, w)
	attach("LowerTorso", V(2 * w + 0.1, 0.32, w + 0.1), C(0, 0.12, 0), look.accent, "Fabric")
	attach("LowerTorso", V(0.28, 1.1, 0.08), C(0.55 * w, -0.5, w / 2 + 0.08) * A(0, 0, rad(6)), look.accent, "Fabric", {
		swing = { amp = 6, speed = 3, vel = 50, base = 8, pivot = V(0, 0.55, 0) },
	})
	attach("LowerTorso", V(0.24, 0.9, 0.08), C(0.25 * w, -0.42, w / 2 + 0.08) * A(0, 0, rad(-4)), look.accent, "Fabric", {
		swing = { amp = 8, speed = 3.4, phase = 1.2, vel = 50, base = 8, pivot = V(0, 0.45, 0) },
	})
end
EXTRA.pauldron_l = function(attach, look)
	attach("LeftUpperArm", V(1.28, 0.42, 1.22), C(-0.05, 0.42, 0) * A(0, 0, rad(12)), look.trim, "Metal", { reflectance = 0.1 })
	attach("LeftUpperArm", V(1.14, 0.3, 1.1), C(-0.08, 0.16, 0) * A(0, 0, rad(16)), hexDarken(look.trim, 0.75), "Metal")
	attach("LeftUpperArm", V(0.08, 0.36, 1.24), C(-0.66, 0.36, 0) * A(0, 0, rad(12)), look.accent, "Neon", { glow = true, shadow = false })
end
EXTRA.pauldron_r = function(attach, look)
	attach("RightUpperArm", V(1.28, 0.42, 1.22), C(0.05, 0.42, 0) * A(0, 0, rad(-12)), look.trim, "Metal", { reflectance = 0.1 })
	attach("RightUpperArm", V(1.14, 0.3, 1.1), C(0.08, 0.16, 0) * A(0, 0, rad(-16)), hexDarken(look.trim, 0.75), "Metal")
end
EXTRA.arm_wraps = function(attach, _look)
	for _, side in { "Right", "Left" } do
		attach(side .. "LowerArm", V(0.95, 0.5, 0.95), C(0, -0.12, 0), "#D9D0BE", "Fabric")
		attach(side .. "LowerArm", V(0.96, 0.08, 0.96), C(0, 0.12, 0), "#BDB29C", "Fabric")
	end
end
EXTRA.hakama = function(attach, look)
	for _, side in { "Right", "Left" } do
		attach(side .. "UpperLeg", V(1.18, 1.02, 1.18), C(0, -0.02, 0), look.legs, "Fabric")
		attach(side .. "LowerLeg", V(1.16, 0.85, 1.16), C(0, 0.04, 0), look.legs, "Fabric")
	end
end
EXTRA.tabard = function(attach, look, w)
	attach("LowerTorso", V(1.3 * w, 1.8, 0.08), C(0, -1.0, -(w / 2) - 0.06), look.accent, "Fabric", {
		swing = { amp = 3, speed = 2.4, vel = -30, base = -4, pivot = V(0, 0.9, 0) },
	})
	attach("LowerTorso", V(1.32 * w, 0.1, 0.09), C(0, -1.82, -(w / 2) - 0.06), look.trim, "Metal", {
		swing = { amp = 3, speed = 2.4, vel = -30, base = -4, pivot = V(0, 1.72, 0) },
	})
	attach("LowerTorso", V(1.5 * w, 1.9, 0.08), C(0, -1.05, w / 2 + 0.06), look.accent, "Fabric", {
		swing = { amp = 4, speed = 2.2, phase = 1, vel = 40, base = 6, pivot = V(0, 0.95, 0) },
	})
	attach("UpperTorso", V(2 * w + 0.05, 1.2, 0.1), C(0, -0.1, -(w / 2) - 0.03), look.trim, "Metal", { reflectance = 0.1 })
	attach("UpperTorso", V(0.3, 0.5, 0.06), C(0, 0.1, -(w / 2) - 0.09), look.glow, "Neon", { glow = true })
end
EXTRA.wings = function(attach, look, w)
	for _, sx in { 1, -1 } do
		for i = 0, 2 do
			local len = 1.9 - i * 0.35
			local p = attach("UpperTorso", V(0.14, len, 0.5), C(sx * (0.5 + i * 0.32), 0.55 + i * 0.25, w / 2 + 0.32 + i * 0.05) * A(rad(-15), 0, rad(-sx * (35 + i * 18))), "#E2E6EC", "Metal", {
				reflectance = 0.2,
				swing = { axis = "z", amp = 3, speed = 2.6, phase = i * 0.3, vel = 10, pivot = V(-sx * 0.0, -len / 2, 0) },
			})
			attach("UpperTorso", V(0.05, len * 0.9, 0.08), C(sx * (0.5 + i * 0.32) + sx * 0.04, 0.55 + i * 0.25, w / 2 + 0.58 + i * 0.05) * A(rad(-15), 0, rad(-sx * (35 + i * 18))), look.glow, "Neon", { glow = true, shadow = false })
			local _ = p
		end
	end
end
EXTRA.greaves = function(attach, look)
	for _, side in { "Right", "Left" } do
		attach(side .. "LowerLeg", V(0.96, 0.85, 0.2), C(0, 0.02, -0.48), look.trim, "Metal", { reflectance = 0.1 })
		attach(side .. "Foot", V(0.94, 0.16, 1.18), C(0, 0.08, 0), hexDarken(look.trim, 0.7), "Metal")
	end
end
EXTRA.bark_plates = function(attach, look, w)
	local bark = "#3A2C1E"
	attach("UpperTorso", V(2 * w + 0.12, 0.95, 0.22), C(0, 0.25, -(w / 2) - 0.08), bark, "Wood")
	attach("UpperTorso", V(2 * w * 0.8, 0.5, 0.22), C(0, -0.45, -(w / 2) - 0.06), bark, "Wood")
	attach("UpperTorso", V(0.06, 0.8, 0.04), C(0.3, 0.2, -(w / 2) - 0.2) * A(0, 0, rad(18)), look.glow, "Neon", { glow = true, shadow = false })
	attach("UpperTorso", V(0.05, 0.6, 0.04), C(-0.5, -0.2, -(w / 2) - 0.2) * A(0, 0, rad(-30)), look.glow, "Neon", { glow = true, shadow = false })
	for _, side in { "Right", "Left" } do
		local sx = side == "Right" and 1 or -1
		attach(side .. "UpperArm", V(1.22, 0.55, 1.22), C(0.05 * sx, 0.38, 0) * A(0, 0, rad(-14 * sx)), bark, "Wood")
		attach(side .. "UpperLeg", V(1.08, 0.6, 1.08), C(0, 0.1, -0.05), bark, "Wood")
	end
end
EXTRA.moss_cloak = function(attach, look, w)
	attach("UpperTorso", V(2 * w + 0.3, 0.55, w + 0.35), C(0, 0.72, 0.05), look.hairColor, "Grass")
	attach("UpperTorso", V(2 * w + 0.2, 2.6, 0.22), C(0, -0.65, w / 2 + 0.16), look.hairColor, "Grass", {
		swing = { amp = 2, speed = 1.8, vel = 20, base = 4, pivot = V(0, 1.25, 0) },
	})
end
EXTRA.root_arms = function(attach, _look)
	local wood = "#4A3624"
	for _, side in { "Right", "Left" } do
		attach(side .. "LowerArm", V(0.14, 1.0, 0.14), C(0.42, 0, -0.3) * A(rad(20), 0, rad(15)), wood, "Wood")
		attach(side .. "LowerArm", V(0.12, 0.9, 0.12), C(-0.42, 0.05, 0.25) * A(rad(-15), 0, rad(-20)), wood, "Wood")
		attach(side .. "UpperArm", V(0.14, 0.9, 0.14), C(0.4, 0, 0.35) * A(rad(-20), 0, rad(20)), wood, "Wood")
	end
end
EXTRA.mushrooms = function(attach, look, w)
	local spots = {
		{ "UpperTorso", V(0.7 * w, 0.85, 0.2) },
		{ "UpperTorso", V(-0.5 * w, 0.9, 0.3) },
		{ "LeftUpperArm", V(-0.3, 0.68, 0.1) },
	}
	for i, sp in spots do
		attach(sp[1], V(0.1, 0.28, 0.1), C(sp[2]), "#D8D2C0", "SmoothPlastic")
		attach(sp[1], V(0.36 - i * 0.04, 0.18, 0.36 - i * 0.04), C(sp[2] + V(0, 0.18, 0)), look.glow, "Neon", { shape = BALL, glow = true })
	end
end
EXTRA.shadow_cape = function(attach, _look, w)
	for i = 0, 4 do
		local x = (i - 2) * 0.38 * w
		attach("UpperTorso", V(0.4 * w, 2.9 - math.abs(i - 2) * 0.25, 0.07), C(x, -0.75, w / 2 + 0.1), "#120E18", "Fabric", {
			swing = { amp = 6, speed = 2.8, phase = i * 0.7, vel = 55, velY = 40, base = 8, pivot = V(0, 1.45, 0) },
		})
	end
	attach("UpperTorso", V(2 * w + 0.2, 0.3, w + 0.25), C(0, 0.68, 0.05), "#120E18", "Fabric")
end
EXTRA.belt_daggers = function(attach, look, w)
	attach("LowerTorso", V(2 * w + 0.08, 0.22, w + 0.08), C(0, 0.12, 0), "#2A1E1A", "Leather")
	for _, sx in { 1, -1 } do
		attach("LowerTorso", V(0.14, 0.62, 0.22), C(sx * (w - 0.15), -0.25, 0.1) * A(0, 0, rad(sx * 15)), "#2A1E1A", "Leather")
		attach("LowerTorso", V(0.1, 0.12, 0.1), C(sx * (w - 0.12), 0.1, 0.1), look.glow, "Neon", { glow = true })
	end
end
EXTRA.skirt_tatters = function(attach, look, w)
	for i = 0, 2 do
		local x = (i - 1) * 0.6 * w
		attach("LowerTorso", V(0.55 * w, 1.0 - (i % 2) * 0.2, 0.06), C(x, -0.65, -(w / 2) - 0.05), look.accent == "#A86BFF" and "#241A30" or look.accent, "Fabric", {
			swing = { amp = 5, speed = 3, phase = i, vel = -40, base = -6, pivot = V(0, 0.5, 0) },
		})
		attach("LowerTorso", V(0.55 * w, 1.1 - (i % 2) * 0.2, 0.06), C(x, -0.7, w / 2 + 0.05), look.accent == "#A86BFF" and "#241A30" or look.accent, "Fabric", {
			swing = { amp = 6, speed = 2.8, phase = i + 1, vel = 45, base = 8, pivot = V(0, 0.55, 0) },
		})
	end
end
EXTRA.fur_collar = function(attach, _look, w)
	local fur = "#8A7A66"
	attach("UpperTorso", V(2 * w + 0.35, 0.5, 0.36), C(0, 0.78, -(w / 2)), fur, "Fabric")
	attach("UpperTorso", V(2 * w + 0.35, 0.6, 0.4), C(0, 0.8, w / 2), fur, "Fabric")
	attach("UpperTorso", V(0.4, 0.55, w + 0.5), C(w + 0.05, 0.78, 0), fur, "Fabric")
	attach("UpperTorso", V(0.4, 0.55, w + 0.5), C(-w - 0.05, 0.78, 0), fur, "Fabric")
end
EXTRA.belt_heavy = function(attach, look, w)
	attach("LowerTorso", V(2 * w + 0.14, 0.42, w + 0.14), C(0, 0.06, 0), "#3A2A1C", "Leather")
	attach("LowerTorso", V(0.55, 0.44, 0.1), C(0, 0.06, -(w / 2) - 0.1), look.trim, "Metal", { reflectance = 0.15 })
	attach("LowerTorso", V(0.16, 0.16, 0.05), C(0, 0.06, -(w / 2) - 0.16), look.glow, "Neon", { glow = true })
end
EXTRA.bracers = function(attach, look)
	for _, side in { "Right", "Left" } do
		attach(side .. "LowerArm", V(0.99, 0.6, 0.99), C(0, -0.08, 0), look.trim, "Metal", { reflectance = 0.1 })
		attach(side .. "LowerArm", V(1.0, 0.06, 1.0), C(0, 0.1, 0), look.glow, "Neon", { glow = true, shadow = false })
	end
end
EXTRA.fur_kilt = function(attach, _look, w)
	local fur = "#6A5A48"
	attach("LowerTorso", V(2 * w + 0.12, 1.0, 0.14), C(0, -0.6, -(w / 2) - 0.04), fur, "Fabric", {
		swing = { amp = 3, speed = 2.5, vel = -25, base = -4, pivot = V(0, 0.5, 0) },
	})
	attach("LowerTorso", V(2 * w + 0.12, 1.05, 0.14), C(0, -0.62, w / 2 + 0.04), fur, "Fabric", {
		swing = { amp = 3, speed = 2.3, phase = 1, vel = 30, base = 5, pivot = V(0, 0.52, 0) },
	})
end
EXTRA.bangles = function(attach, look)
	for _, side in { "Right", "Left" } do
		for i = 0, 1 do
			attach(side .. "LowerArm", V(0.1, 1.0, 1.0), C(0, -0.25 - i * 0.14, 0) * A(0, 0, rad(90)), look.trim, "Metal", { shape = CYL, reflectance = 0.3 })
		end
	end
end
EXTRA.gold_collar = function(attach, look, w)
	attach("UpperTorso", V(2 * w * 0.82, 0.24, w + 0.12), C(0, 0.72, 0), look.trim, "Metal", { reflectance = 0.3 })
	attach("UpperTorso", V(1.0, 0.45, 0.08), C(0, 0.5, -(w / 2) - 0.05), look.trim, "Metal", { reflectance = 0.3 })
	attach("UpperTorso", V(0.18, 0.18, 0.05), C(0, 0.45, -(w / 2) - 0.1), look.glow, "Neon", { glow = true })
end
EXTRA.long_coat = function(attach, look, w)
	attach("LowerTorso", V(2 * w + 0.18, 2.1, 0.12), C(0, -1.1, w / 2 + 0.1), look.torso, "Leather", {
		swing = { amp = 3, speed = 2.2, vel = 45, velY = 30, base = 5, pivot = V(0, 1.05, 0) },
	})
	for _, sx in { 1, -1 } do
		attach("LowerTorso", V(0.12, 2.0, w * 0.8), C(sx * (w + 0.07), -1.05, 0.12), look.torso, "Leather", {
			swing = { amp = 3, speed = 2.4, phase = sx, vel = 35, base = 3, pivot = V(0, 1.0, 0) },
		})
	end
	attach("UpperTorso", V(2 * w * 0.9, 0.55, 0.16), C(0, 0.92, w / 2 - 0.02) * A(rad(-12), 0, 0), look.torso, "Leather")
	attach("UpperTorso", V(0.1, 1.5, 0.06), C(-0.25 * w, -0.05, -(w / 2) - 0.04), look.trim, "Metal")
end
EXTRA.bandolier = function(attach, look, w)
	attach("UpperTorso", V(0.26, 2.2, 0.08), C(0, 0, -(w / 2) - 0.06) * A(0, 0, rad(40)), "#3A2A1C", "Leather")
	for i = -1, 2 do
		attach("UpperTorso", V(0.22, 0.3, 0.14), C(i * 0.3, -i * 0.25, -(w / 2) - 0.12) * A(0, 0, rad(40)), look.trim, "Metal")
	end
end
EXTRA.belt_pouches = function(attach, _look, w)
	attach("LowerTorso", V(2 * w + 0.08, 0.24, w + 0.08), C(0, 0.1, 0), "#3A2A1C", "Leather")
	for i, x in { 0.55, -0.55, 0.1 } do
		attach("LowerTorso", V(0.36, 0.38, 0.26), C(x * w, -0.12, -(w / 2) - 0.12 + (i == 3 and w + 0.24 or 0)), "#4A3424", "Leather")
	end
end
EXTRA.gauntlet = function(attach, look)
	attach("RightLowerArm", V(1.06, 0.72, 1.06), C(0, -0.08, 0), look.trim, "Metal", { reflectance = 0.15 })
	attach("RightHand", V(0.92, 0.48, 0.92), C(0, 0, 0), hexDarken(look.trim, 0.8), "Metal")
end
EXTRA.royal_cape = function(attach, look, w)
	attach("UpperTorso", V(2 * w + 0.45, 3.7, 0.12), C(0, -1.3, w / 2 + 0.14), "#3A0A10", "Fabric", {
		swing = { amp = 2.5, speed = 1.8, vel = 40, velY = 30, base = 5, pivot = V(0, 1.85, 0) },
	})
	attach("UpperTorso", V(2 * w + 0.47, 0.12, 0.13), C(0, -3.1, w / 2 + 0.15), look.trim, "Metal", {
		swing = { amp = 2.5, speed = 1.8, vel = 40, velY = 30, base = 5, pivot = V(0, 3.65, 0) },
	})
	attach("UpperTorso", V(2 * w + 0.4, 0.4, w + 0.4), C(0, 0.7, 0.05), "#2A070C", "Fabric")
	for _, sx in { 1, -1 } do
		attach("UpperTorso", V(0.3, 0.3, 0.3), C(sx * (w - 0.1), 0.6, -(w / 2) - 0.1), look.trim, "Metal", { shape = BALL })
	end
end
EXTRA.soul_chains = function(attach, look, w)
	for _, sx in { 1, -1 } do
		for i = 0, 4 do
			local glowLink = i % 2 == 1
			attach("LowerTorso", V(0.14, 0.26, 0.14), C(sx * (w - 0.1), -0.25 - i * 0.24, 0.2), glowLink and look.glow or "#3A3A38", glowLink and "Neon" or "Metal", {
				glow = glowLink,
				swing = { amp = 6 + i * 2, speed = 3, phase = i * 0.4 + sx, vel = 40, base = 4, pivot = V(0, 0.4 + i * 0.24, 0) },
			})
		end
	end
end
EXTRA.prayer_beads = function(attach, look, w)
	for i = 0, 10 do
		local a = (i / 10 - 0.5) * math.pi * 0.9
		attach("UpperTorso", V(0.17, 0.17, 0.17), C(math.sin(a) * 0.7 * w, 0.55 - math.cos(a) * 0.45, -(w / 2) - 0.07), i == 5 and look.glow or "#5A2E1E", i == 5 and "Neon" or "Wood", {
			shape = BALL,
			glow = i == 5,
		})
	end
end
-- Classic studs on top of the torso and shoulders.
EXTRA.studs = function(attach, look, w)
	for ix = -1.5, 1.5 do
		for iz = -0.5, 0.5 do
			attach("UpperTorso", V(0.16, 0.42, 0.42), C(ix * 0.48 * w, 0.86, iz * 0.5 * w) * A(0, 0, rad(90)), look.torso, "SmoothPlastic", { shape = CYL })
		end
	end
	for _, side in { "Right", "Left" } do
		attach(side .. "UpperArm", V(0.16, 0.4, 0.4), C(0, 0.55, 0) * A(0, 0, rad(90)), look.arms, "SmoothPlastic", { shape = CYL })
	end
end
-- Mismatched free-model bricks stuck all over the body.
EXTRA.brick_plates = function(attach, _look, w)
	local bricks = {
		{ "UpperTorso", V(0.9, 0.5, 0.25), C(0.45 * w, 0.2, -(w / 2) - 0.1), "#F5CD30" },
		{ "UpperTorso", V(0.7, 0.45, 0.25), C(-0.5 * w, -0.3, -(w / 2) - 0.1), "#4B974B" },
		{ "UpperTorso", V(1.2, 0.5, 0.25), C(0, 0.1, w / 2 + 0.1), "#0D69AC" },
		{ "LowerTorso", V(0.8, 0.35, 0.25), C(0.4 * w, 0, -(w / 2) - 0.1), "#F2F3F3" },
		{ "RightUpperLeg", V(0.6, 0.45, 0.2), C(0, 0.1, -0.55), "#C4281C" },
		{ "LeftUpperLeg", V(0.6, 0.45, 0.2), C(0, -0.1, -0.55), "#F5CD30" },
		{ "LeftUpperArm", V(1.1, 0.45, 1.1), C(0, 0.3, 0), "#0D69AC" },
		{ "RightUpperArm", V(1.1, 0.45, 1.1), C(0, 0.3, 0), "#4B974B" },
	}
	for _, b in bricks do
		attach(b[1], b[2], b[3], b[4], "SmoothPlastic")
		attach(b[1], V(0.14, 0.3, 0.3), b[3] * C(0, b[2].Y / 2 + 0.06, 0) * A(0, 0, rad(90)), b[4], "SmoothPlastic", { shape = CYL })
	end
end
-- Floating tag above the head (Roblox-style overhead text).
local function overheadTag(rig, text: string, color: string, size: number?)
	local head = rig and rig.parts and rig.parts.Head
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "OverheadTag"
	bb.Size = UDim2.fromOffset(240, 34)
	bb.StudsOffset = Vector3.new(0, 2.3 * (rig.scale or 1), 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.AlwaysOnTop = false
	bb.Parent = head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextColor3 = Color3.fromHex(color)
	t.TextStrokeTransparency = 0.3
	t.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	t.TextSize = size or 20
	t.Parent = bb
end
EXTRA.admin_tag = function(_attach, _look, _w, rig)
	overheadTag(rig, "[ADMIN]", "#FF3B3B", 22)
end
EXTRA.free_model_tag = function(_attach, _look, _w, rig)
	overheadTag(rig, "Free Model (Untitled) (2)", "#C8C8C8", 16)
end
-- Ghillie "bush" suit.
EXTRA.bush_suit = function(attach, _look, w)
	local spots = {
		{ "Head", V(0.75, 0.6, 0.75), C(0.35, 0.75, 0.15) },
		{ "Head", V(0.65, 0.55, 0.65), C(-0.4, 0.7, 0.25) },
		{ "UpperTorso", V(1.0, 0.8, 0.8), C(0.6 * w, 0.6, 0.35) },
		{ "UpperTorso", V(0.9, 0.75, 0.75), C(-0.6 * w, 0.55, 0.4) },
		{ "UpperTorso", V(1.1, 0.9, 0.7), C(0, -0.1, w / 2 + 0.3) },
		{ "LowerTorso", V(1.0, 0.7, 0.7), C(0.3, -0.3, w / 2 + 0.25) },
	}
	for i, sp in spots do
		attach(sp[1], sp[2], sp[3], i % 2 == 0 and "#5E8C3A" or "#79A64A", "Grass", { shape = BALL })
	end
end
-- DJ headphones.
EXTRA.headphones = function(attach, look)
	attach("Head", V(1.42, 0.12, 0.22), C(0, 0.68, 0.05), "#1A1A1A", "SmoothPlastic")
	for _, sx in { 1, -1 } do
		attach("Head", V(0.2, 0.55, 0.55), C(sx * 0.68, 0.12, 0.05) * A(0, 0, 0), "#1A1A1A", "SmoothPlastic", { shape = CYL })
		attach("Head", V(0.06, 0.58, 0.58), C(sx * 0.79, 0.12, 0.05), look.glow, "Neon", { shape = CYL, glow = true, shadow = false })
	end
end

EXTRA.feather_cloak = function(attach, _look, w)
	for i = 0, 6 do
		local a = (i - 3) * 11
		attach("UpperTorso", V(0.36, 2.4 - math.abs(i - 3) * 0.2, 0.08), C((i - 3) * 0.28 * w, -0.6, w / 2 + 0.12) * A(0, 0, rad(a)), "#0E0B10", "Fabric", {
			swing = { amp = 4, speed = 2.6, phase = i * 0.5, vel = 45, base = 5, pivot = V(0, 1.2, 0) },
		})
	end
	for _, sx in { 1, -1 } do
		attach(sx == 1 and "RightUpperArm" or "LeftUpperArm", V(1.15, 0.4, 1.15), C(0, 0.4, 0), "#0E0B10", "Fabric")
	end
end

-------------------------------------------------------------------------------
-- Weapons (held in the right hand; blade axis is the hand's -Z)
-------------------------------------------------------------------------------

local function trail(rig, part: BasePart, a0: Vector3, a1: Vector3, color: Color3)
	local att0 = Instance.new("Attachment")
	att0.Position = a0
	att0.Parent = part
	local att1 = Instance.new("Attachment")
	att1.Position = a1
	att1.Parent = part
	local tr = Instance.new("Trail")
	tr.Attachment0 = att0
	tr.Attachment1 = att1
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.Lifetime = 0.16
	tr.MinLength = 0.02
	tr.LightEmission = 1
	tr.LightInfluence = 0
	tr.FaceCamera = false
	tr.WidthScale = NumberSequence.new(1, 0.4)
	tr.Enabled = false
	tr.Parent = part
	table.insert(rig.trails, tr)
	rig.weaponTip = att1
	return tr
end

local WEAPON = {}

WEAPON.katana = function(rig, attach, look)
	local s = rig.scale
	attach("RightHand", V(0.17, 0.17, 1.05), C(0, -0.04, 0.18), "#1A1410", "Fabric")
	attach("RightHand", V(0.08, 0.55, 0.55), C(0, -0.04, -0.38) * A(0, rad(90), 0), look.trim, "Metal", { shape = CYL })
	local blade = attach("RightHand", V(0.07, 0.2, 3.3), C(0, -0.04, -2.05), "#C9D2DA", "Metal", { reflectance = 0.35 })
	attach("RightHand", V(0.03, 0.05, 3.25), C(0, -0.14, -2.05), look.glow, "Neon", { glow = true, shadow = false })
	attach("RightHand", V(0.07, 0.2, 0.35), C(0, -0.04, -3.85) * A(0, 0, 0), "#C9D2DA", "Metal", { class = "WedgePart" })
	trail(rig, blade, V(0, 0, 1.4 * s), V(0, 0, -1.65 * s), Color3.fromHex(look.glow))
	-- scabbard on the hip
	attach("LowerTorso", V(0.2, 0.22, 3.0), C(-(look.width or 1) - 0.1, -0.1, 0.4) * A(rad(-30), 0, 0), "#1A1410", "Leather")
end
WEAPON.greatsword = function(rig, attach, look)
	local s = rig.scale
	attach("RightHand", V(0.2, 0.2, 1.4), C(0, -0.04, 0.28), "#1A1410", "Leather")
	attach("RightHand", V(0.3, 0.3, 0.3), C(0, -0.04, 1.05), look.trim, "Metal", { shape = BALL })
	attach("RightHand", V(1.3, 0.2, 0.22), C(0, -0.04, -0.48), look.trim, "Metal")
	local blade = attach("RightHand", V(0.1, 0.5, 4.3), C(0, -0.04, -2.75), "#2A2C28", "CorrodedMetal")
	attach("RightHand", V(0.12, 0.1, 3.9), C(0, -0.04, -2.7), look.glow, "Neon", { glow = true, shadow = false })
	attach("RightHand", V(0.1, 0.5, 0.6), C(0, -0.04, -5.2), "#2A2C28", "CorrodedMetal", { class = "WedgePart" })
	trail(rig, blade, V(0, 0, 2.0 * s), V(0, 0, -2.15 * s), Color3.fromHex(look.glow))
end
WEAPON.spear = function(rig, attach, look)
	local s = rig.scale
	local shaft = attach("RightHand", V(0.16, 0.16, 6.2), C(0, -0.04, -0.7), "#E6E2D6", "Metal", { reflectance = 0.15 })
	attach("RightHand", V(0.2, 0.2, 0.3), C(0, -0.04, 2.35), look.trim, "Metal")
	attach("RightHand", V(0.06, 0.42, 1.1), C(0, -0.04, -4.3), "#D8E6E6", "Metal", { reflectance = 0.4 })
	attach("RightHand", V(0.06, 0.42, 0.45), C(0, -0.04, -5.05), "#D8E6E6", "Metal", { class = "WedgePart" })
	attach("RightHand", V(0.62, 0.14, 0.14), C(0, -0.04, -3.75), look.trim, "Metal")
	attach("RightHand", V(0.04, 0.12, 1.05), C(0, -0.04, -4.3), look.glow, "Neon", { glow = true, shadow = false })
	attach("RightHand", V(0.05, 0.9, 0.18), C(0.05, -0.5, -3.65) * A(rad(20), 0, 0), look.accent, "Fabric", {
		swing = { amp = 14, speed = 4, vel = 50, base = 10, pivot = V(0, 0.45, 0) },
	})
	trail(rig, shaft, V(0, 0, -2.6 * s), V(0, 0, -4.4 * s), Color3.fromHex(look.glow))
end
WEAPON.hammer = function(rig, attach, look)
	local s = rig.scale
	attach("RightHand", V(0.22, 0.22, 3.6), C(0, -0.04, -1.1), "#4A3A2A", "Wood")
	attach("RightHand", V(0.3, 0.3, 0.3), C(0, -0.04, 0.75), look.trim, "Metal")
	local head = attach("RightHand", V(1.5, 0.95, 0.95), C(0, -0.04, -3.1), "#7A8A96", "Metal", { reflectance = 0.15 })
	attach("RightHand", V(1.55, 0.2, 1.0), C(0, -0.04, -3.1), look.trim, "Metal")
	attach("RightHand", V(0.4, 0.62, 0.62), C(0.78, -0.04, -3.1) * A(0, 0, rad(90)), look.glow, "Glass", { transparency = 0.2 })
	attach("RightHand", V(0.4, 0.62, 0.62), C(-0.78, -0.04, -3.1) * A(0, 0, rad(-90)), look.glow, "Glass", { transparency = 0.2 })
	attach("RightHand", V(0.08, 0.5, 0.5), C(0, 0.46, -3.1), look.glow, "Neon", { glow = true, shadow = false })
	trail(rig, head, V(0.75 * s, 0, 0), V(-0.75 * s, 0, 0), Color3.fromHex(look.glow))
end
WEAPON.daggers = function(rig, attach, look)
	local s = rig.scale
	for _, side in { "Right", "Left" } do
		attach(side .. "Hand", V(0.14, 0.14, 0.55), C(0, -0.04, 0.08), "#1A1414", "Leather")
		attach(side .. "Hand", V(0.36, 0.1, 0.1), C(0, -0.04, -0.24), look.trim, "Metal")
		local blade = attach(side .. "Hand", V(0.05, 0.16, 1.15), C(0, -0.04, -0.85) * A(0, 0, 0), "#B8B0D0", "Metal", { reflectance = 0.3 })
		attach(side .. "Hand", V(0.02, 0.04, 1.1), C(0, -0.13, -0.85), look.glow, "Neon", { glow = true, shadow = false })
		trail(rig, blade, V(0, 0, 0.5 * s), V(0, 0, -0.6 * s), Color3.fromHex(look.glow))
	end
end
WEAPON.chakram = function(rig, attach, look)
	local s = rig.scale
	for _, side in { "Right", "Left" } do
		local ring = attach(side .. "Hand", V(0.1, 1.35, 1.35), C(0, -0.05, -0.45) * A(0, rad(90), 0), look.trim, "Metal", { shape = CYL, reflectance = 0.35 })
		attach(side .. "Hand", V(0.11, 1.05, 1.05), C(0, -0.05, -0.45) * A(0, rad(90), 0), "#2A1610", "SmoothPlastic", { shape = CYL })
		attach(side .. "Hand", V(0.12, 1.42, 1.42), C(0, -0.05, -0.45) * A(0, rad(90), 0), look.glow, "Neon", { shape = CYL, glow = true, transparency = 0.55, shadow = false })
		trail(rig, ring, V(0, 0.65 * s, 0), V(0, -0.65 * s, 0), Color3.fromHex(look.glow))
	end
end
WEAPON.crossbow = function(rig, attach, look)
	local s = rig.scale
	local stock = attach("RightHand", V(0.24, 0.3, 1.9), C(0, -0.08, -0.55), "#2A1E16", "Wood")
	attach("RightHand", V(2.0, 0.12, 0.16), C(0, -0.02, -1.35) * A(0, rad(8), 0), "#1A1412", "Metal")
	attach("RightHand", V(0.12, 0.12, 0.16), C(1.0, -0.02, -1.25), look.trim, "Metal")
	attach("RightHand", V(0.12, 0.12, 0.16), C(-1.0, -0.02, -1.25), look.trim, "Metal")
	attach("RightHand", V(1.9, 0.03, 0.03), C(0, 0.05, -1.05), look.glow, "Neon", { glow = true, shadow = false })
	attach("RightHand", V(0.06, 0.06, 1.4), C(0, 0.12, -1.0), "#C9C2B0", "Metal")
	attach("RightHand", V(0.16, 0.2, 0.3), C(0, 0.2, -0.3), look.trim, "Metal")
	trail(rig, stock, V(0, 0, 0.9 * s), V(0, 0, -0.95 * s), Color3.fromHex(look.glow))
	-- hook & chain on the belt
	attach("LowerTorso", V(0.3, 0.5, 0.3), C((look.width or 1) + 0.1, -0.2, 0), "#4A4A4A", "Metal")
end
WEAPON.fists = function(rig, attach, look)
	for _, side in { "Right", "Left" } do
		local g = attach(side .. "Hand", V(1.18, 0.72, 1.18), C(0, -0.1, 0), "#3A2C1E", "Wood")
		attach(side .. "Hand", V(1.2, 0.18, 1.2), C(0, 0.18, 0), look.hairColor or "#2F4A22", "Grass")
		attach(side .. "Hand", V(0.06, 0.5, 0.04), C(0.2, -0.1, -0.6) * A(0, 0, rad(20)), look.glow, "Neon", { glow = true, shadow = false })
		if side == "Right" then
			trail(rig, g, V(0, 0.4, 0), V(0, -0.4, 0), Color3.fromHex(look.glow))
		end
	end
end
WEAPON.staff = function(rig, attach, look)
	local s = rig.scale
	local shaft = attach("RightHand", V(0.17, 0.17, 5.6), C(0, -0.04, -0.6), "#5A3A1E", "Wood")
	attach("RightHand", V(0.26, 0.26, 0.4), C(0, -0.04, 2.2), look.trim, "Metal")
	attach("RightHand", V(0.3, 0.3, 0.3), C(0, -0.04, -3.45), look.glow, "Neon", { shape = BALL, glow = true })
	trail(rig, shaft, V(0, 0, -1.8 * s), V(0, 0, -2.8 * s), Color3.fromHex(look.glow))
end
WEAPON.bow = function(_rig, attach, look)
	attach("LeftHand", V(0.13, 3.3, 0.16), C(0, 0, -0.1), "#4A3424", "Wood")
	attach("LeftHand", V(0.03, 3.2, 0.03), C(0, 0, 0.25), look.glow, "Neon", { glow = true, shadow = false })
	attach("UpperTorso", V(0.4, 1.4, 0.4), C(0.4, 0.1, (look.width or 1) / 2 + 0.25) * A(0, 0, rad(-20)), "#3A2A1C", "Leather")
end
WEAPON.lantern = function(rig, attach, look)
	attach("RightHand", V(0.06, 0.7, 0.06), C(0, -0.5, 0), "#2A2A2A", "Metal", {
		swing = { amp = 8, speed = 3, vel = 40, pivot = V(0, 0.35, 0) },
	})
	local cage = attach("RightHand", V(0.55, 0.75, 0.55), C(0, -1.2, 0), "#1A1C1E", "Metal", {
		transparency = 0.3,
		swing = { amp = 8, speed = 3, vel = 40, pivot = V(0, 1.05, 0) },
	})
	attach("RightHand", V(0.32, 0.45, 0.32), C(0, -1.2, 0), look.glow, "Neon", {
		glow = true,
		shadow = false,
		swing = { amp = 8, speed = 3, vel = 40, pivot = V(0, 1.05, 0) },
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex(look.glow)
	light.Brightness = 2
	light.Range = 10
	light.Parent = cage
	table.insert(rig.lights, light)
end
-- Studzilla's fists: oversized brick blocks with studs.
WEAPON.brick_fists = function(rig, attach, look)
	local cols = { "#C4281C", "#0D69AC" }
	for i, side in { "Right", "Left" } do
		local g = attach(side .. "Hand", V(1.3, 0.85, 1.3), C(0, -0.12, 0), cols[i], "SmoothPlastic")
		for ix = -0.5, 0.5 do
			for iz = -0.5, 0.5 do
				attach(side .. "Hand", V(0.14, 0.34, 0.34), C(ix * 0.6, 0.38, iz * 0.6) * A(0, 0, rad(90)), cols[i], "SmoothPlastic", { shape = CYL })
			end
		end
		if side == "Right" then
			trail(rig, g, V(0, 0.45, 0), V(0, -0.45, 0), Color3.fromHex(look.glow))
		end
	end
end
WEAPON.none = function() end

-------------------------------------------------------------------------------

function Looks.apply(rig, look, attach)
	local w = look.width or 1
	;(FACES[look.face] or FACES.plain)(attach, look, rig)
	;(HAIR[look.hair] or HAIR.none)(attach, look)
	;(HEAD[look.headwear] or HEAD.none)(attach, look)
	;(MASK[look.mask] or MASK.none)(attach, look)
	glowEyes(attach, look)
	for _, ex in look.extras or {} do
		local fn = EXTRA[ex]
		if fn then
			fn(attach, look, w, rig)
		end
	end
	;(WEAPON[look.weapon] or WEAPON.none)(rig, attach, look)
end

Looks.WEAPON = WEAPON
Looks.EXTRA = EXTRA

return Looks
