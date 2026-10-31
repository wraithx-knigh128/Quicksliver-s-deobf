--!nonstrict
-- Builds an R15-proportioned fighter model from a look spec (Data/Fighters.luau) and
-- poses it every frame with forward kinematics. All parts are anchored and moved with
-- BulkMoveTo, so there is no physics, no Humanoid and no replication cost.

local RigMath = require(script.Parent.RigMath)
local Looks = require(script.Parent.Looks)

local Rig = {}

local function hex(c: string): Color3
	return Color3.fromHex(c)
end
Rig.hex = hex

local function newPart(className: string?): BasePart
	local p = Instance.new(className or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end
Rig.newPart = newPart

local BONE_COLOR_KEY = {
	Head = "skin",
	UpperTorso = "torso",
	LowerTorso = "torso",
	RightUpperArm = "arms",
	RightLowerArm = "arms",
	LeftUpperArm = "arms",
	LeftLowerArm = "arms",
	RightHand = "hands",
	LeftHand = "hands",
	RightUpperLeg = "legs",
	RightLowerLeg = "legs",
	LeftUpperLeg = "legs",
	LeftLowerLeg = "legs",
	RightFoot = "feet",
	LeftFoot = "feet",
}
local BONE_MAT_KEY = {
	UpperTorso = "torsoMat",
	LowerTorso = "torsoMat",
	RightUpperArm = "armsMat",
	RightLowerArm = "armsMat",
	LeftUpperArm = "armsMat",
	LeftLowerArm = "armsMat",
	RightUpperLeg = "legsMat",
	RightLowerLeg = "legsMat",
	LeftUpperLeg = "legsMat",
	LeftLowerLeg = "legsMat",
}

local function material(name: string?): Enum.Material
	if name and (Enum.Material :: any)[name] then
		return (Enum.Material :: any)[name]
	end
	return Enum.Material.SmoothPlastic
end
Rig.material = material

-- opts: { name: string?, spectral: Color3?, world: WorldRoot? }
function Rig.build(look, opts)
	opts = opts or {}
	local s = look.scale or 1
	local w = look.width or 1
	local sk = RigMath.skeleton(s, w)
	local model = Instance.new("Model")
	model.Name = opts.name or "Fighter"

	local rig = {
		model = model,
		sk = sk,
		look = look,
		scale = s,
		parts = {},
		attached = {},
		allParts = {},
		glow = {},
		trails = {},
		lights = {},
		world = opts.world or workspace,
		poseCache = {},
		transparency = 0,
		baseT = {},
		decals = {},
	}

	for _, name in sk.order do
		local b = sk.bones[name]
		local p = newPart()
		p.Name = name
		p.Size = b.size
		local colorKey = BONE_COLOR_KEY[name]
		p.Color = hex(look[colorKey] or "#888888")
		p.Material = material(look[BONE_MAT_KEY[name] or ""] )
		if name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1, 1, 1)
			mesh.Parent = p
			p.Material = Enum.Material.SmoothPlastic
		elseif name == "RightHand" or name == "LeftHand" or name == "RightFoot" or name == "LeftFoot" then
			p.Material = material(look[BONE_MAT_KEY[name] or ""] or "SmoothPlastic")
		end
		p.Parent = model
		rig.parts[name] = p
		table.insert(rig.allParts, p)
	end
	model.PrimaryPart = rig.parts.LowerTorso

	-- Accessory helper handed to Looks: attach(bone, size, offsetCF, color, materialName, extra)
	local function attach(bone: string, size: Vector3, offset: CFrame, color, matName: string?, extra)
		extra = extra or {}
		local p = newPart(extra.class)
		p.Name = extra.name or (bone .. "_acc")
		if extra.class ~= "WedgePart" and extra.class ~= "CornerWedgePart" and extra.shape then
			p.Shape = extra.shape
		end
		p.Size = size * s
		if typeof(color) == "string" then
			p.Color = hex(color)
		else
			p.Color = color
		end
		p.Material = material(matName)
		if extra.transparency then
			p.Transparency = extra.transparency
		end
		if extra.reflectance then
			p.Reflectance = extra.reflectance
		end
		if extra.mesh then
			local m = Instance.new("SpecialMesh")
			m.MeshType = extra.mesh
			m.Parent = p
		end
		p.CastShadow = extra.shadow ~= false
		p.Parent = model
		local pos = offset.Position * s
		local entry = {
			part = p,
			bone = bone,
			offset = CFrame.new(pos) * offset.Rotation,
			swing = extra.swing,
			baseTransparency = p.Transparency,
		}
		if extra.swing and extra.swing.pivot then
			entry.pivot = extra.swing.pivot * s
		end
		table.insert(rig.attached, entry)
		table.insert(rig.allParts, p)
		rig.baseT[p] = p.Transparency
		if extra.glow then
			table.insert(rig.glow, p)
		end
		return p
	end

	Looks.apply(rig, look, attach)

	if opts.spectral then
		Rig.makeSpectral(rig, opts.spectral)
	end

	-- buffers for BulkMoveTo
	rig.moveParts = {}
	for _, name in sk.order do
		table.insert(rig.moveParts, rig.parts[name])
	end
	for _, a in rig.attached do
		table.insert(rig.moveParts, a.part)
	end
	rig.moveCFrames = table.create(#rig.moveParts, CFrame.identity)

	model:SetAttribute("VeilRig", true)
	return rig
end

function Rig.makeSpectral(rig, color: Color3)
	for _, p in rig.allParts do
		p.Material = Enum.Material.ForceField
		p.Color = color
		p.CastShadow = false
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.82
	hl.FillColor = color
	hl.OutlineColor = color
	hl.OutlineTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = rig.model
	rig.spectral = hl
end

local bulkOk = true

-- Pose the rig. motion = { time, vx, vy } drives cloth / hair sway.
function Rig.apply(rig, rootCF: CFrame, pose, motion)
	local sk = rig.sk
	local bones = RigMath.solve(sk, rootCF, pose, rig.poseCache)
	local cfs = rig.moveCFrames
	local i = 0
	for _, name in sk.order do
		i += 1
		cfs[i] = bones[name]
	end
	local t = motion and motion.time or 0
	local vx = motion and motion.vx or 0
	local vy = motion and motion.vy or 0
	for _, a in rig.attached do
		i += 1
		local boneCF = bones[a.bone]
		local sw = a.swing
		if sw then
			local ang = (sw.base or 0)
				+ math.sin(t * (sw.speed or 3) + (sw.phase or 0)) * (sw.amp or 6)
				+ math.clamp(vx * (sw.vel or 40), -35, 35)
				+ math.clamp(-vy * (sw.velY or 30), -25, 25)
			local piv = a.pivot or Vector3.zero
			local r = sw.axis == "z" and CFrame.Angles(0, 0, math.rad(ang)) or CFrame.Angles(math.rad(ang), 0, 0)
			cfs[i] = boneCF * CFrame.new(piv) * r * CFrame.new(-piv) * a.offset
		else
			cfs[i] = boneCF * a.offset
		end
	end
	if bulkOk then
		local ok = pcall(function()
			rig.world:BulkMoveTo(rig.moveParts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		if not ok then
			bulkOk = false
		end
	end
	if not bulkOk then
		for k, p in rig.moveParts do
			p.CFrame = cfs[k]
		end
	end
	rig.lastBones = bones
end

-- World position of a bone (after the last apply)
function Rig.bonePosition(rig, bone: string): Vector3
	local b = rig.lastBones and rig.lastBones[bone]
	if b then
		return b.Position
	end
	return rig.model:GetPivot().Position
end

function Rig.setTransparency(rig, t: number)
	if rig.transparency == t then
		return
	end
	rig.transparency = t
	for _, p in rig.allParts do
		p.Transparency = math.max(rig.baseT[p] or 0, t)
	end
	for _, d in rig.decals do
		d.Transparency = t
	end
end

function Rig.setTrails(rig, enabled: boolean)
	for _, tr in rig.trails do
		tr.Enabled = enabled
	end
end

function Rig.setVisible(rig, visible: boolean)
	rig.model.Parent = visible and (rig.parentWhenVisible or workspace) or nil
end

function Rig.destroy(rig)
	rig.model:Destroy()
end

return Rig
