--!nonstrict
-- Live 3D portraits rendered in ViewportFrames (HUD medallions, select grid, versus).

local Render = script.Parent.Parent.Render
local Rig = require(Render.Rig)
local Poses = require(Render.Poses)

local Portrait = {}

-- framing: "head" | "bust" | "full"
function Portrait.create(parent: Instance, look, props)
	props = props or {}
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = props.Size or UDim2.fromScale(1, 1)
	vp.Position = props.Position or UDim2.new()
	vp.AnchorPoint = props.AnchorPoint or Vector2.zero
	vp.Ambient = props.Ambient or Color3.fromRGB(120, 115, 110)
	vp.LightColor = props.LightColor or Color3.fromRGB(255, 240, 220)
	vp.LightDirection = props.LightDirection or Vector3.new(-0.6, -0.5, -1)
	vp.ZIndex = props.ZIndex or 1
	vp.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = props.fov or 30
	cam.Parent = vp
	vp.CurrentCamera = cam

	local rig = Rig.build(look, { world = world, spectral = props.spectral })
	rig.model.Parent = world
	local style = props.style or "unarmed"
	local pose = props.pose or Poses.stance(style)
	local facing = props.facing or 1
	local yaw = math.rad(props.yaw or 30) * facing
	local rootCF = CFrame.new(0, 0, 0) * CFrame.Angles(0, -math.pi / 2 * facing + yaw, 0)
	Rig.apply(rig, rootCF, pose, { time = 0 })

	local framing = props.framing or "head"
	local s = rig.scale
	local headPos = Rig.bonePosition(rig, "Head")
	local target, dist
	if framing == "head" then
		target = headPos + Vector3.new(0, 0.1 * s, 0)
		dist = 4.6 * s
	elseif framing == "bust" then
		target = headPos - Vector3.new(0, 1.0 * s, 0)
		dist = 8.5 * s
	else
		target = Vector3.new(0, 2.8 * s, 0)
		dist = 15 * s
	end
	-- camera in front of the face (rig faces along its LookVector)
	local fwd = (rootCF.LookVector * Vector3.new(1, 0, 1)).Unit
	local side = props.camSide or 0.35
	local right = fwd:Cross(Vector3.yAxis)
	local camPos = target + (fwd + right * side * facing).Unit * dist + Vector3.new(0, 0.25 * s, 0)
	cam.CFrame = CFrame.lookAt(camPos, target)

	local obj = { frame = vp, rig = rig, camera = cam, world = world, rootCF = rootCF, style = style }
	function obj:setPose(p, t)
		Rig.apply(self.rig, self.rootCF, p, { time = t or 0 })
	end
	function obj:destroy()
		vp:Destroy()
	end
	return obj
end

return Portrait
