--!nonstrict
-- 2.5D fight camera with smoothing, zoom-by-distance, jump tracking, shake and
-- cinematic overrides (intros, supers, finishers, cutscenes).

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Config = require(Veil.Config)

local FightCamera = {}

local cam: Camera = workspace.CurrentCamera
local state = {
	pos = Vector3.new(0, Config.CameraHeight + 3, Config.CameraBaseDistance),
	look = Vector3.new(0, Config.CameraLookHeight, 0),
	fov = Config.CameraFov,
	shake = 0,
	shakeDecay = 6,
	cinematic = nil,
	enabled = false,
	shakeScale = 1,
	-- directional kick: a damped spring offset in camera space (x right, y up)
	kick = Vector2.zero,
	kickV = Vector2.zero,
	-- FOV punch (degrees, negative = zoom in) and its velocity
	fovPunch = 0,
	fovPunchV = 0,
}

function FightCamera.enable()
	cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	state.enabled = true
end

function FightCamera.disable()
	state.enabled = false
	state.cinematic = nil
end

function FightCamera.setShakeScale(k: number)
	state.shakeScale = k
end

-- Noise shake, optionally with a directional jolt (dirX: +1 = push right on screen,
-- dirY: -1 = slam down). Directional jolts read as weight: a heavy hit knocks the
-- frame the way the blow travelled instead of rattling randomly.
function FightCamera.shake(amount: number, dirX: number?, dirY: number?)
	local s = amount * state.shakeScale
	state.shake = math.max(state.shake, s)
	if dirX or dirY then
		-- initial velocity sized so the peak offset is roughly 0.25 studs per unit of shake
		state.kickV += Vector2.new((dirX or 0) * s * 17, (dirY or 0) * s * 17)
	end
end

-- Brief zoom-in on big impacts (amount in degrees of FOV).
function FightCamera.punch(amount: number)
	if state.shakeScale <= 0 then
		return
	end
	state.fovPunchV -= amount * 60
end

-- fn(t) -> (CFrame, fov?) ; duration in seconds (nil = until cleared)
function FightCamera.cinematic(fn, duration: number?)
	state.cinematic = { fn = fn, t = 0, duration = duration }
end

function FightCamera.clearCinematic()
	state.cinematic = nil
end

function FightCamera.isCinematic(): boolean
	return state.cinematic ~= nil
end

-- Snap instantly to the fight framing for the given fighters.
function FightCamera.snap(x1: number, x2: number)
	local tp, tl = FightCamera.target(x1, 0, x2, 0)
	state.pos = tp
	state.look = tl
end

function FightCamera.target(x1: number, y1: number, x2: number, y2: number)
	local mid = (x1 + x2) / 2
	local sep = math.abs(x1 - x2)
	local dist = Config.CameraBaseDistance + math.max(0, sep - 4) * Config.CameraDistancePerStud
	local halfView = dist * math.tan(math.rad(Config.CameraFov / 2)) * 1.6
	local lim = Config.StageHalfWidth + 2 - halfView
	if lim > 0 then
		mid = math.clamp(mid, -lim, lim)
	end
	local maxY = math.max(y1, y2)
	local h = Config.CameraHeight + maxY * 0.55
	local lookY = Config.CameraLookHeight + maxY * 0.45
	return Vector3.new(mid, h, dist), Vector3.new(mid, lookY, 0)
end

local function noise(t: number, seed: number): number
	return math.sin(t * 37.1 + seed) * 0.5 + math.sin(t * 61.7 + seed * 2.3) * 0.35 + math.sin(t * 13.3 + seed * 0.7) * 0.15
end

local clock = 0
function FightCamera.update(dt: number, x1: number, y1: number, x2: number, y2: number)
	if not state.enabled then
		return
	end
	clock += dt
	cam.CameraType = Enum.CameraType.Scriptable
	local cf, fov
	if state.cinematic then
		local c = state.cinematic
		c.t += dt
		cf, fov = c.fn(c.t)
		if c.duration and c.t >= c.duration then
			state.cinematic = nil
		end
		state.pos = cf.Position
		state.look = cf.Position + cf.LookVector * 20
		state.fov = fov or state.fov
	else
		local tp, tl = FightCamera.target(x1, y1, x2, y2)
		local k = 1 - math.exp(-dt * 6)
		state.pos = state.pos:Lerp(tp, k)
		state.look = state.look:Lerp(tl, k)
		state.fov = state.fov + (Config.CameraFov - state.fov) * k
		cf = CFrame.lookAt(state.pos, state.look)
	end
	if state.shake > 0.001 then
		local s = state.shake
		cf = cf * CFrame.new(noise(clock, 1) * s * 0.35, noise(clock, 7) * s * 0.35, 0) * CFrame.Angles(0, 0, noise(clock, 3) * s * 0.02)
		state.shake = math.max(0, s - dt * state.shakeDecay * math.max(0.4, s))
	end
	-- directional kick + FOV punch springs (stiff, slightly underdamped), substepped
	do
		local w, z = 38, 0.55
		local steps = math.max(1, math.ceil(math.min(dt, 0.1) / (1 / 240)))
		local h = math.min(dt, 0.1) / steps
		for _ = 1, steps do
			local acc = state.kick * -(w * w) - state.kickV * (2 * z * w)
			state.kickV += acc * h
			state.kick += state.kickV * h
			local fa = -state.fovPunch * (w * w) - state.fovPunchV * (2 * z * w)
			state.fovPunchV += fa * h
			state.fovPunch += state.fovPunchV * h
		end
		state.fovPunch = math.clamp(state.fovPunch, -12, 6)
	end
	if state.kick.Magnitude > 0.0005 then
		cf = cf * CFrame.new(state.kick.X, state.kick.Y, 0) * CFrame.Angles(0, 0, -state.kick.X * 0.03)
	end
	cam.CFrame = cf
	cam.FieldOfView = math.clamp(state.fov + state.fovPunch, 10, 100)
end

function FightCamera.position(): Vector3
	return state.pos
end

return FightCamera
