--!nonstrict
-- Secondary-motion layer for fighter animation.
--
-- The authored pose (Poses + crossfades) is the *target*; this module chases it with
-- per-joint damped springs. That gives weight and follow-through (strikes overshoot
-- slightly and settle), removes visible snapping between states, and lets combat
-- events "kick" joints with impulses (a head snapping back on a heavy hit, a chest
-- compressing on block, a squash on landing).
--
-- Legs are deliberately excluded: they stay on exact leg IK so feet stay planted.

local AnimSpring = {}
AnimSpring.__index = AnimSpring

-- key -> { omega (rad/s stiffness), zeta (damping ratio) }
local TUNING = {
	root = { 20, 0.85 },
	LT = { 22, 0.9 },
	UT = { 18, 0.78 },
	H = { 14, 0.72 },
	RUA = { 26, 0.68 },
	RLA = { 30, 0.66 },
	RH = { 30, 0.7 },
	LUA = { 26, 0.68 },
	LLA = { 30, 0.66 },
	LH = { 30, 0.7 },
}
AnimSpring.KEYS = { "root", "LT", "UT", "H", "RUA", "RLA", "RH", "LUA", "LLA", "LH" }

local function wrap(d: number): number
	-- shortest signed angle difference in degrees
	d = (d + 180) % 360 - 180
	return d
end

function AnimSpring.new()
	local self = setmetatable({}, AnimSpring)
	self.x = {}
	self.v = {}
	self.primed = false
	return self
end

-- Snap the springs onto a pose (used on spawn / teleport).
function AnimSpring:reset(pose)
	for _, k in AnimSpring.KEYS do
		local t = pose[k]
		local n = k == "root" and 6 or 3
		local x, v = table.create(n, 0), table.create(n, 0)
		for i = 1, n do
			x[i] = t and t[i] or 0
		end
		self.x[k] = x
		self.v[k] = v
	end
	self.primed = true
end

-- Add angular (deg/s) or positional (studs/s) velocity to a joint component.
function AnimSpring:kick(key: string, index: number, amount: number)
	local v = self.v[key]
	if v then
		v[index] = (v[index] or 0) + amount
	end
end

-- How far a joint may trail its target. Keeps fast authored motion (spins, flips,
-- getups) readable and bounds the overshoot of big impulses.
local MAX_LAG_DEG = 48
local MAX_LAG_STUDS = 0.6

-- Advance toward `target` and return a pose table (target's legs/IK untouched).
-- `snap` (0..1) temporarily stiffens the arms, for crisp strikes.
-- The returned joint arrays are reused between calls: consume before the next step.
function AnimSpring:step(target, dt: number, snap: number?)
	if not self.primed then
		self:reset(target)
	end
	local out = table.clone(target)
	local buf = self.buf
	if not buf then
		buf = {}
		self.buf = buf
	end
	local boost = 1 + (snap or 0) * 0.8
	-- substep for stability on slow frames
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _, k in AnimSpring.KEYS do
		local tune = TUNING[k]
		local omega = tune[1]
		if k ~= "root" and k ~= "LT" and k ~= "UT" and k ~= "H" then
			omega *= boost
		end
		local zeta = tune[2]
		local x, v = self.x[k], self.v[k]
		local tgt = target[k]
		local n = #x
		for i = 1, n do
			local goal = tgt and tgt[i] or 0
			local isAngle = not (k == "root" and i <= 3)
			local xi, vi = x[i], v[i]
			for _ = 1, steps do
				local diff = isAngle and wrap(goal - xi) or (goal - xi)
				vi += (omega * omega * diff - 2 * zeta * omega * vi) * h
				xi += vi * h
			end
			-- bounded lag
			local cap = isAngle and MAX_LAG_DEG or MAX_LAG_STUDS
			local diff = isAngle and wrap(goal - xi) or (goal - xi)
			if diff > cap then
				xi = goal - cap
			elseif diff < -cap then
				xi = goal + cap
			end
			if isAngle and math.abs(xi) > 720 then
				-- keep accumulated spin angles small (equivalent orientation)
				xi = wrap(xi)
			end
			x[i], v[i] = xi, vi
		end
		local o = buf[k]
		if not o or #o ~= n then
			o = table.create(n, 0)
			buf[k] = o
		end
		for i = 1, n do
			o[i] = x[i]
		end
		out[k] = o
	end
	return out
end

return AnimSpring
