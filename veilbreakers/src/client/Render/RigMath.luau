--!nonstrict
-- Skeleton definition + forward kinematics + leg IK for OOF COMBAT fighters.
-- Pure CFrame math (no Instances) so poses can be evaluated headless for previews.
--
-- Rig space: origin on the floor between the feet, +Y up, facing -Z (Roblox
-- convention), +X is the fighter's right-hand side. Proportions follow R15.

local RigMath = {}

-- name, parent, size, joint position in parent space, joint position in child space
-- (unscaled; scale `s` and torso width `w` are applied in RigMath.skeleton)
local function boneDefs(w: number)
	local armX = w + 0.47
	local legX = 0.5 * w
	return {
		{ "LowerTorso", nil, Vector3.new(2 * w, 0.55, 1.0 * w), Vector3.new(0, 2.35, 0), Vector3.new(0, 0, 0) },
		{ "UpperTorso", "LowerTorso", Vector3.new(2 * w, 1.55, 1.0 * w), Vector3.new(0, 0.275, 0), Vector3.new(0, -0.775, 0) },
		{ "Head", "UpperTorso", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 0.775, 0), Vector3.new(0, -0.62, 0) },
		{ "RightUpperArm", "UpperTorso", Vector3.new(0.95, 0.95, 0.95), Vector3.new(armX, 0.52, 0), Vector3.new(0, 0.3, 0) },
		{ "RightLowerArm", "RightUpperArm", Vector3.new(0.9, 0.86, 0.9), Vector3.new(0, -0.47, 0), Vector3.new(0, 0.4, 0) },
		{ "RightHand", "RightLowerArm", Vector3.new(0.84, 0.42, 0.84), Vector3.new(0, -0.43, 0), Vector3.new(0, 0.19, 0) },
		{ "LeftUpperArm", "UpperTorso", Vector3.new(0.95, 0.95, 0.95), Vector3.new(-armX, 0.52, 0), Vector3.new(0, 0.3, 0) },
		{ "LeftLowerArm", "LeftUpperArm", Vector3.new(0.9, 0.86, 0.9), Vector3.new(0, -0.47, 0), Vector3.new(0, 0.4, 0) },
		{ "LeftHand", "LeftLowerArm", Vector3.new(0.84, 0.42, 0.84), Vector3.new(0, -0.43, 0), Vector3.new(0, 0.19, 0) },
		{ "RightUpperLeg", "LowerTorso", Vector3.new(0.98, 0.98, 0.98), Vector3.new(legX, -0.25, 0), Vector3.new(0, 0.46, 0) },
		{ "RightLowerLeg", "RightUpperLeg", Vector3.new(0.9, 0.94, 0.9), Vector3.new(0, -0.465, 0), Vector3.new(0, 0.45, 0) },
		{ "RightFoot", "RightLowerLeg", Vector3.new(0.9, 0.28, 1.15), Vector3.new(0, -0.45, 0), Vector3.new(0, 0.135, 0.1) },
		{ "LeftUpperLeg", "LowerTorso", Vector3.new(0.98, 0.98, 0.98), Vector3.new(-legX, -0.25, 0), Vector3.new(0, 0.46, 0) },
		{ "LeftLowerLeg", "LeftUpperLeg", Vector3.new(0.9, 0.94, 0.9), Vector3.new(0, -0.465, 0), Vector3.new(0, 0.45, 0) },
		{ "LeftFoot", "LeftLowerLeg", Vector3.new(0.9, 0.28, 1.15), Vector3.new(0, -0.45, 0), Vector3.new(0, 0.135, 0.1) },
	}
end

-- Short pose keys -> bone names
RigMath.Keys = {
	LT = "LowerTorso",
	UT = "UpperTorso",
	H = "Head",
	RUA = "RightUpperArm",
	RLA = "RightLowerArm",
	RH = "RightHand",
	LUA = "LeftUpperArm",
	LLA = "LeftLowerArm",
	LH = "LeftHand",
	RUL = "RightUpperLeg",
	RLL = "RightLowerLeg",
	RF = "RightFoot",
	LUL = "LeftUpperLeg",
	LLL = "LeftLowerLeg",
	LF = "LeftFoot",
}

function RigMath.skeleton(scale: number, width: number)
	local s = scale
	local defs = boneDefs(width)
	local sk = { scale = s, width = width, bones = {}, order = {} }
	for _, d in defs do
		local name, parent, size, jp, jc = d[1], d[2], d[3], d[4], d[5]
		local b = {
			name = name,
			parent = parent,
			size = size * s,
			c0 = CFrame.new(jp * s),
			c1inv = CFrame.new(-jc * s),
		}
		sk.bones[name] = b
		table.insert(sk.order, name)
	end
	-- leg lengths for IK
	sk.thigh = 0.925 * s
	sk.shin = 0.9 * s
	sk.ankle = 0.275 * s
	sk.hipHeight = 2.35 * s
	return sk
end

local rad = math.rad

local function rot(v): CFrame
	if v == nil then
		return CFrame.identity
	end
	return CFrame.Angles(rad(v[1] or 0), rad(v[2] or 0), rad(v[3] or 0))
end
RigMath.rot = rot

-- Two-bone leg IK in the LowerTorso's local frame.
-- Returns hip {rx, 0, rz}, knee {rx}, foot {rx, 0, rz} in degrees.
local function solveLeg(sk, ltCF: CFrame, hipLocal: Vector3, targetWorld: Vector3, footPitch: number)
	local hipWorld = ltCF:PointToWorldSpace(hipLocal)
	local v = ltCF:VectorToObjectSpace(targetWorld - hipWorld)
	local a, b = sk.thigh, sk.shin
	local L = v.Magnitude
	L = math.clamp(L, math.abs(a - b) + 0.05, a + b - 0.002)
	local cosK = math.clamp((a * a + b * b - L * L) / (2 * a * b), -1, 1)
	local k = math.pi - math.acos(cosK)
	local cosA = math.clamp((a * a + L * L - b * b) / (2 * a * L), -1, 1)
	local alpha = math.acos(cosA)
	local phi = math.atan2(-v.Z, -v.Y)
	local hipRx = phi + alpha
	local kneeRx = -k
	local rz = math.asin(math.clamp(v.X / math.max(L, 0.001), -0.9, 0.9))
	-- keep the sole parallel to the floor: undo LowerTorso pitch too
	local _, _, _ = ltCF:ToOrientation()
	local ltLook = ltCF.LookVector
	local ltPitch = math.asin(math.clamp(ltLook.Y, -1, 1)) -- forward lean (look down -> negative)
	local footRx = -(hipRx + kneeRx) - ltPitch + rad(footPitch or 0)
	return { math.deg(hipRx), 0, math.deg(rz) }, { math.deg(kneeRx), 0, 0 }, { math.deg(footRx), 0, -math.deg(rz) }
end

-- Evaluate a pose into world CFrames for every bone.
-- pose: { root = {x,y,z, rx,ry,rz}, LT = {rx,ry,rz}, ..., ikL = {x,y,z,p}, ikR = {...} }
-- ik targets are in rig space (relative to rootCF, on the floor), p = toe pitch in degrees.
function RigMath.solve(sk, rootCF: CFrame, pose, out)
	out = out or {}
	local r = pose.root
	local hip = sk.hipHeight
	local base = rootCF
	if r then
		base = rootCF
			* CFrame.new(0, hip, 0)
			* CFrame.new((r[1] or 0) * sk.scale, (r[2] or 0) * sk.scale, (r[3] or 0) * sk.scale)
			* CFrame.Angles(rad(r[4] or 0), rad(r[5] or 0), rad(r[6] or 0))
			* CFrame.new(0, -hip, 0)
	end
	local bones = sk.bones
	-- lower torso
	local lt = bones.LowerTorso
	local ltCF = base * lt.c0 * rot(pose.LT) * lt.c1inv
	out.LowerTorso = ltCF
	local legAngles = {}
	if pose.ikL or pose.ikR then
		for side, key in { L = "ikL", R = "ikR" } do
			local t = pose[key]
			if t then
				local prefix = side == "L" and "Left" or "Right"
				local ul = bones[prefix .. "UpperLeg"]
				local hipLocal = ul.c0.Position
				local target = rootCF:PointToWorldSpace(Vector3.new((t[1] or 0) * sk.scale, (t[2] or 0) * sk.scale + sk.ankle, (t[3] or 0) * sk.scale))
				local h, k, f = solveLeg(sk, ltCF, hipLocal, target, t[4] or 0)
				legAngles[prefix .. "UpperLeg"] = h
				legAngles[prefix .. "LowerLeg"] = k
				legAngles[prefix .. "Foot"] = f
			end
		end
	end
	local keyOf = RigMath.BoneKey
	for _, name in sk.order do
		if name ~= "LowerTorso" then
			local b = bones[name]
			local parentCF = out[b.parent]
			local angles = legAngles[name] or pose[keyOf[name]]
			out[name] = parentCF * b.c0 * rot(angles) * b.c1inv
		end
	end
	return out
end

RigMath.BoneKey = {}
for k, v in RigMath.Keys do
	RigMath.BoneKey[v] = k
end

return RigMath
