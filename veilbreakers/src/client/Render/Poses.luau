--!nonstrict
-- Procedural animation library.
--
-- A pose is a table of joint rotations in degrees, keyed by short bone names
-- (see RigMath.Keys), plus optional `root` = {x, y, z, rx, ry, rz} and leg IK targets
-- `ikL` / `ikR` = {x, y, z, toePitch} measured on the floor in rig space.
--
-- Conventions (rig faces -Z):
--   limbs   rx > 0 swings forward / up, right rz > 0 and left rz < 0 swing outward
--   elbows  rx > 0 bends the forearm up;  knees rx < 0 bends
--   torso / head rx < 0 leans forward;  ry > 0 turns to the fighter's left
--
-- Attack animations are authored as wind-up / strike / (strike2) poses and are
-- time-mapped onto each move's real startup / active / recovery frame counts, so the
-- visuals always line up with the frame data.

local Poses = {}

local function merge(...)
	local out = {}
	for i = 1, select("#", ...) do
		local t = select(i, ...)
		if t then
			for k, v in t do
				out[k] = v
			end
		end
	end
	return out
end
Poses.merge = merge

-------------------------------------------------------------------------------
-- Building blocks
-------------------------------------------------------------------------------

local LEGS = {
	stance = { root = { 0, -0.3, 0 }, ikL = { -0.55, 0, -0.85, 0 }, ikR = { 0.62, 0, 0.8, 0 } },
	wide = { root = { 0, -0.45, 0 }, ikL = { -0.8, 0, -0.9, 0 }, ikR = { 0.85, 0, 0.9, 0 } },
	low = { root = { 0, -0.75, 0 }, ikL = { -0.75, 0, -1.0, 0 }, ikR = { 0.8, 0, 1.0, 0 } },
	square = { root = { 0, -0.15, 0 }, ikL = { -0.6, 0, -0.1, 0 }, ikR = { 0.6, 0, 0.1, 0 } },
	crouch = { root = { 0, -1.3, 0 }, ikL = { -0.8, 0, -0.55, 0 }, ikR = { 0.85, 0, 0.6, 0 } },
	lunge = { root = { 0, -0.7, -0.4 }, ikL = { -0.55, 0, -1.6, 0 }, ikR = { 0.6, 0, 1.2, 0 } },
	deep = { root = { 0, -1.0, -0.6 }, ikL = { -0.6, 0, -1.9, 0 }, ikR = { 0.6, 0, 1.3, 0 } },
	tall = { root = { 0, 0.05, 0 }, ikL = { -0.5, 0, -0.4, 0 }, ikR = { 0.5, 0, 0.4, 0 } },
}
Poses.LEGS = LEGS

local TORSO_TURN = { LT = { 0, -22, 0 }, UT = { -6, -8, 0 }, H = { 4, 28, 0 } }

-- Guard arm sets per stance style
local ARMS = {
	unarmed = {
		RUA = { 42, 0, -8 },
		RLA = { 112, 0, 0 },
		RH = { 0, 0, 0 },
		LUA = { 62, 0, 6 },
		LLA = { 98, 0, 0 },
	},
	blade = {
		RUA = { 28, 0, 14 },
		RLA = { 62, 0, 0 },
		RH = { -18, 0, 0 },
		LUA = { 58, 0, 12 },
		LLA = { 70, 0, 0 },
	},
	pole = {
		RUA = { 18, 0, 12 },
		RLA = { 58, 0, 0 },
		RH = { -60, 0, 0 },
		LUA = { 50, 0, -28 },
		LLA = { 46, 0, 0 },
	},
	heavy = {
		RUA = { 72, 0, 38 },
		RLA = { 118, 0, 0 },
		RH = { 32, 0, 0 },
		LUA = { 34, 0, 4 },
		LLA = { 78, 0, 0 },
	},
	dual = {
		RUA = { 30, 0, 22 },
		RLA = { 84, 0, 0 },
		RH = { 50, 0, 0 },
		LUA = { 52, 0, -6 },
		LLA = { 92, 0, 0 },
	},
	ranged = {
		RUA = { 22, 0, 10 },
		RLA = { 70, 0, 0 },
		RH = { -70, 0, 0 },
		LUA = { 44, 0, -30 },
		LLA = { 70, 0, 0 },
	},
}
Poses.ARMS = ARMS

local STANCE_LEGS = {
	unarmed = "stance",
	blade = "stance",
	pole = "stance",
	heavy = "wide",
	dual = "low",
	ranged = "stance",
}

local STYLE_OF = {
	stance_unarmed = "unarmed",
	stance_blade = "blade",
	stance_pole = "pole",
	stance_heavy = "heavy",
	stance_dual = "dual",
	stance_ranged = "ranged",
}
Poses.STYLE_OF = STYLE_OF

function Poses.stance(style: string)
	return merge(LEGS[STANCE_LEGS[style] or "stance"], TORSO_TURN, ARMS[style] or ARMS.unarmed)
end

-------------------------------------------------------------------------------
-- Attack animations: { wind, hit, hit2?, legsWind?, legsHit?, spin? }
-------------------------------------------------------------------------------

local A = {}
Poses.Attacks = A

local function atk(name, def)
	A[name] = def
end

-- Punches / basic strikes
atk("jab", {
	wind = merge(LEGS.stance, TORSO_TURN, ARMS.unarmed, { LUA = { 70, 0, 4 }, LLA = { 120, 0, 0 } }),
	hit = merge(LEGS.lunge, { LT = { 0, -40, 0 }, UT = { -8, -18, 0 }, H = { 2, 50, 0 } }, ARMS.unarmed, {
		LUA = { 92, 0, -4 },
		LLA = { 4, 0, 0 },
		LH = { 0, 0, 0 },
	}),
})
atk("cross", {
	wind = merge(LEGS.stance, TORSO_TURN, ARMS.unarmed, { RUA = { 30, 0, 10 }, RLA = { 120, 0, 0 } }),
	hit = merge(LEGS.lunge, { LT = { 0, 18, 0 }, UT = { -10, 26, 0 }, H = { 0, -14, 0 } }, ARMS.unarmed, {
		RUA = { 92, 0, -6 },
		RLA = { 4, 0, 0 },
		LUA = { 46, 0, 8 },
		LLA = { 120, 0, 0 },
	}),
})
atk("hook", {
	wind = merge(LEGS.stance, { LT = { 0, -40, 0 }, UT = { -6, -30, 0 }, H = { 0, 50, 0 } }, ARMS.unarmed, {
		RUA = { 50, 0, 60 },
		RLA = { 90, 0, 0 },
	}),
	hit = merge(LEGS.lunge, { LT = { 0, 30, 0 }, UT = { -12, 40, 0 }, H = { 0, -30, 0 } }, ARMS.unarmed, {
		RUA = { 88, -50, 30 },
		RLA = { 70, 0, 0 },
	}),
})
atk("hammer_fist", {
	wind = merge(LEGS.stance, TORSO_TURN, ARMS.unarmed, { UT = { 14, 0, 0 }, RUA = { 172, 0, 10 }, RLA = { 40, 0, 0 } }),
	hit = merge(LEGS.lunge, { UT = { -32, 0, 0 }, H = { -10, 0, 0 } }, ARMS.unarmed, {
		RUA = { 46, 0, -6 },
		RLA = { 6, 0, 0 },
		LUA = { 120, 0, 10 },
		LLA = { 30, 0, 0 },
	}),
})
atk("uppercut", {
	wind = merge(LEGS.crouch, { UT = { -18, 10, 0 } }, ARMS.unarmed, { RUA = { -12, 0, 12 }, RLA = { 100, 0, 0 } }),
	hit = merge(LEGS.tall, { root = { 0, 0.4, -0.2 }, UT = { 12, 30, 0 }, H = { 18, -20, 0 } }, ARMS.unarmed, {
		RUA = { 168, 0, -4 },
		RLA = { 26, 0, 0 },
	}),
})
atk("crouch_jab", {
	wind = merge(LEGS.crouch, TORSO_TURN, ARMS.unarmed, { LUA = { 60, 0, 0 }, LLA = { 120, 0, 0 } }),
	hit = merge(LEGS.crouch, { UT = { -14, -20, 0 }, H = { 0, 30, 0 } }, ARMS.unarmed, { LUA = { 78, 0, 0 }, LLA = { 4, 0, 0 } }),
})
atk("palm_strike", {
	wind = merge(LEGS.stance, TORSO_TURN, { RUA = { 10, 0, 20 }, RLA = { 110, 0, 0 }, LUA = { 50, 0, 0 }, LLA = { 90, 0, 0 } }),
	hit = merge(LEGS.deep, { UT = { -10, 20, 0 } }, { RUA = { 90, 0, 0 }, RLA = { 0, 0, 0 }, RH = { -70, 0, 0 }, LUA = { 20, 0, -10 }, LLA = { 80, 0, 0 } }),
})

-- Kicks
atk("kick_front", {
	wind = merge(LEGS.stance, TORSO_TURN, ARMS.unarmed, {
		ikR = false,
		RUL = { 80, 0, 0 },
		RLL = { -100, 0, 0 },
		RF = { 20, 0, 0 },
		UT = { 10, -6, 0 },
	}),
	hit = merge(
		{ root = { 0, -0.1, 0.1 }, ikL = { -0.5, 0, -0.2, 0 } },
		{ LT = { -6, -10, 0 }, UT = { 16, 0, 0 }, H = { -6, 14, 0 } },
		ARMS.unarmed,
		{ RUL = { 98, 0, 0 }, RLL = { -4, 0, 0 }, RF = { -30, 0, 0 } }
	),
})
atk("side_kick", {
	wind = merge(LEGS.stance, { LT = { 0, 50, 0 }, UT = { 6, 10, 0 }, H = { 0, -50, 0 } }, ARMS.unarmed, {
		ikR = false,
		RUL = { 96, 0, 6 },
		RLL = { -120, 0, 0 },
	}),
	hit = merge(
		{ root = { 0, -0.15, 0.25 }, ikL = { -0.4, 0, -0.2, 0 } },
		{ LT = { 0, 30, 0 }, UT = { 24, 10, 0 }, H = { -12, -24, 0 } },
		ARMS.unarmed,
		{ RUL = { 104, 0, 8 }, RLL = { -2, 0, 0 }, RF = { -40, 0, 0 } }
	),
})
atk("roundhouse", {
	wind = merge(LEGS.stance, { LT = { 0, -60, 0 }, UT = { 0, -20, 0 }, H = { 0, 60, 0 } }, ARMS.unarmed, {
		ikR = false,
		RUL = { 40, 0, 40 },
		RLL = { -90, 0, 0 },
	}),
	hit = merge(
		{ root = { 0, -0.1, 0 }, ikL = { -0.45, 0, -0.1, 0 } },
		{ LT = { 0, 40, 18 }, UT = { 14, 30, 14 }, H = { 0, -30, 0 } },
		ARMS.unarmed,
		{ RUL = { 100, -10, 34 }, RLL = { -8, 0, 0 }, LUA = { 30, 0, -50 } }
	),
})
atk("spin_kick", {
	spin = 360,
	wind = merge(LEGS.stance, { LT = { 0, -80, 0 }, UT = { 0, -30, 0 } }, ARMS.unarmed, {
		ikR = false,
		RUL = { 30, 0, 30 },
		RLL = { -60, 0, 0 },
	}),
	hit = merge(
		{ root = { 0, 0.1, 0 }, ikL = { -0.3, 0, 0, 0 } },
		{ LT = { 0, 0, 24 }, UT = { 18, 0, 18 }, H = { 0, 0, -10 } },
		{ RUA = { 30, 0, 70 }, LUA = { 30, 0, -70 }, RLA = { 20, 0, 0 }, LLA = { 20, 0, 0 } },
		{ RUL = { 104, 0, 40 }, RLL = { -4, 0, 0 } }
	),
})
atk("sweep", {
	wind = merge(LEGS.crouch, { root = { 0, -1.5, 0 }, UT = { -20, -20, 0 } }, ARMS.unarmed, {
		ikR = false,
		RUL = { 30, 0, 50 },
		RLL = { -40, 0, 0 },
		LUA = { 30, 0, -20 },
	}),
	hit = merge(
		{ root = { 0, -1.65, 0, 0, 40, 0 }, ikL = { -0.7, 0, -0.4, 0 } },
		{ UT = { -24, 20, 0 }, H = { 0, -30, 0 } },
		{ RUA = { 20, 0, 40 }, LUA = { 40, 0, -40 }, RLA = { 40, 0, 0 }, LLA = { 30, 0, 0 } },
		{ RUL = { 84, -20, 62 }, RLL = { -2, 0, 0 }, RF = { 10, 0, 0 } }
	),
})
atk("flip_kick", {
	flip = -340,
	wind = merge(LEGS.crouch, { UT = { -20, 0, 0 } }, ARMS.unarmed, { RUA = { -30, 0, 20 }, LUA = { -30, 0, -20 } }),
	hit = merge(
		{ root = { 0, 0.4, 0, 30, 0, 0 } },
		{ UT = { 14, 0, 0 }, H = { 20, 0, 0 } },
		{ RUA = { -40, 0, 50 }, LUA = { -40, 0, -50 }, RLA = { 30, 0, 0 }, LLA = { 30, 0, 0 } },
		{ RUL = { 165, 0, 4 }, RLL = { -6, 0, 0 }, LUL = { 20, 0, 0 }, LLL = { -100, 0, 0 } }
	),
})
atk("slide", {
	wind = merge(LEGS.crouch, { UT = { -10, 0, 0 } }, ARMS.unarmed),
	hit = merge(
		{ root = { 0, -1.9, 0, 52, 0, 0 } },
		{ UT = { -20, 0, 0 }, H = { -30, 0, 0 } },
		{ RUA = { -40, 0, 30 }, LUA = { 20, 0, -40 }, RLA = { 20, 0, 0 } },
		{ RUL = { 60, 0, 0 }, RLL = { 0, 0, 0 }, LUL = { 40, 0, 0 }, LLL = { -80, 0, 0 } }
	),
})
atk("dive_kick", {
	wind = merge({ root = { 0, 0, 0, 20, 0, 0 } }, ARMS.unarmed, {
		RUL = { 90, 0, 0 },
		RLL = { -110, 0, 0 },
		LUL = { 60, 0, 0 },
		LLL = { -100, 0, 0 },
	}),
	hit = merge({ root = { 0, 0, 0, -36, 0, 0 } }, { UT = { 10, 0, 0 } }, ARMS.unarmed, {
		RUL = { 52, 0, 0 },
		RLL = { -2, 0, 0 },
		RF = { -40, 0, 0 },
		LUL = { 10, 0, 0 },
		LLL = { -120, 0, 0 },
	}),
})

-- Blade work
atk("slash_diag", {
	wind = merge(LEGS.stance, { LT = { 0, -24, 0 }, UT = { 8, -30, 0 }, H = { 0, 50, 0 } }, ARMS.blade, {
		RUA = { 150, 0, 54 },
		RLA = { 70, 0, 0 },
		RH = { -20, 0, 0 },
	}),
	hit = merge(LEGS.lunge, { LT = { 0, 30, 0 }, UT = { -18, 34, 0 }, H = { 0, -40, 0 } }, ARMS.blade, {
		RUA = { 62, 0, -42 },
		RLA = { 8, 0, 0 },
		RH = { -30, 0, 0 },
		LUA = { 30, 0, -40 },
		LLA = { 30, 0, 0 },
	}),
})
atk("slash_rising", {
	wind = merge(LEGS.low, { UT = { -18, -20, 0 } }, ARMS.blade, { RUA = { -24, 0, 24 }, RLA = { 20, 0, 0 }, RH = { -50, 0, 0 } }),
	hit = merge(LEGS.tall, { root = { 0, 0.25, -0.2 }, UT = { 14, 20, 0 }, H = { 10, -10, 0 } }, ARMS.blade, {
		RUA = { 170, 0, 6 },
		RLA = { 0, 0, 0 },
		RH = { -60, 0, 0 },
		LUA = { -10, 0, -30 },
		LLA = { 20, 0, 0 },
	}),
})
atk("overhead_chop", {
	wind = merge(LEGS.stance, { UT = { 16, 0, 0 }, H = { 10, 20, 0 } }, ARMS.blade, {
		RUA = { 176, 0, 8 },
		RLA = { 50, 0, 0 },
		RH = { 20, 0, 0 },
		LUA = { 170, 0, -8 },
		LLA = { 50, 0, 0 },
	}),
	hit = merge(LEGS.deep, { UT = { -34, 0, 0 }, H = { -8, 20, 0 } }, ARMS.blade, {
		RUA = { 46, 0, 0 },
		RLA = { 4, 0, 0 },
		RH = { -40, 0, 0 },
		LUA = { 50, 0, -10 },
		LLA = { 10, 0, 0 },
	}),
})
atk("lunge_slash", {
	wind = merge(LEGS.deep, { LT = { 0, -20, 0 }, UT = { -28, -30, 0 }, H = { 10, 50, 0 } }, ARMS.blade, {
		RUA = { -36, 0, 40 },
		RLA = { 20, 0, 0 },
		RH = { -40, 0, 0 },
		LUA = { 70, 0, -10 },
		LLA = { 10, 0, 0 },
	}),
	hit = merge(LEGS.deep, { root = { 0, -1.0, -0.8 }, LT = { 0, 34, 0 }, UT = { -20, 40, 0 }, H = { 0, -50, 0 } }, ARMS.blade, {
		RUA = { 92, 0, -60 },
		RLA = { 6, 0, 0 },
		RH = { -10, 0, 0 },
		LUA = { 20, 0, -60 },
		LLA = { 10, 0, 0 },
	}),
})
atk("rising_slash", {
	wind = merge(LEGS.crouch, { UT = { -24, -10, 0 } }, ARMS.blade, { RUA = { -20, 0, 20 }, RLA = { 10, 0, 0 }, RH = { -60, 0, 0 } }),
	hit = merge(
		{ root = { 0, 0.2, 0, 8, 0, 0 } },
		{ UT = { 10, 30, 0 }, H = { 20, -20, 0 } },
		ARMS.blade,
		{ RUA = { 178, 0, 4 }, RLA = { 0, 0, 0 }, RH = { -70, 0, 0 }, LUA = { -20, 0, -40 }, LLA = { 20, 0, 0 } },
		{ RUL = { 20, 0, 0 }, RLL = { -20, 0, 0 }, LUL = { 90, 0, 0 }, LLL = { -100, 0, 0 } }
	),
})
atk("parry_stance", {
	wind = merge(LEGS.low, { UT = { -10, -10, 0 } }, ARMS.blade, {
		RUA = { 80, 0, -24 },
		RLA = { 40, 0, 0 },
		RH = { -90, 0, 0 },
		LUA = { 76, 0, 30 },
		LLA = { 70, 0, 0 },
	}),
	hit = merge(LEGS.low, { UT = { -12, -14, 0 }, H = { -4, 20, 0 } }, ARMS.blade, {
		RUA = { 86, 0, -30 },
		RLA = { 34, 0, 0 },
		RH = { -92, 0, 0 },
		LUA = { 80, 0, 34 },
		LLA = { 76, 0, 0 },
	}),
	hold = true,
})

-- Polearm
atk("thrust", {
	wind = merge(LEGS.stance, { root = { 0, -0.35, 0.35 }, UT = { 4, 10, 0 } }, ARMS.pole, {
		RUA = { 30, 0, 20 },
		RLA = { 80, 0, 0 },
		RH = { -80, 0, 0 },
		LUA = { 46, 0, -20 },
		LLA = { 60, 0, 0 },
	}),
	hit = merge(LEGS.lunge, { root = { 0, -0.7, -0.7 }, LT = { 0, 20, 0 }, UT = { -12, 26, 0 }, H = { 0, -20, 0 } }, {
		RUA = { 88, 0, -6 },
		RLA = { 4, 0, 0 },
		RH = { -90, 0, 0 },
		LUA = { 84, 0, 26 },
		LLA = { 16, 0, 0 },
	}),
})
atk("thrust_lunge", {
	wind = A.thrust.wind,
	hit = merge(LEGS.deep, { root = { 0, -1.1, -1.0 }, LT = { 0, 24, 0 }, UT = { -18, 30, 0 }, H = { -4, -24, 0 } }, {
		RUA = { 90, 0, -6 },
		RLA = { 2, 0, 0 },
		RH = { -90, 0, 0 },
		LUA = { 88, 0, 28 },
		LLA = { 10, 0, 0 },
	}),
})
atk("dive_lance", {
	wind = merge({ root = { 0, 0, 0, 10, 0, 0 } }, { RUA = { 150, 0, 10 }, RLA = { 40, 0, 0 }, RH = { 0, 0, 0 }, LUA = { 150, 0, -10 } }, {
		RUL = { 60, 0, 0 },
		RLL = { -90, 0, 0 },
		LUL = { 30, 0, 0 },
		LLL = { -60, 0, 0 },
	}),
	hit = merge({ root = { 0, 0, 0, -30, 0, 0 } }, { RUA = { 20, 0, 0 }, RLA = { 0, 0, 0 }, RH = { -100, 0, 0 }, LUA = { 30, 0, 20 } }, {
		RUL = { 10, 0, 0 },
		RLL = { -20, 0, 0 },
		LUL = { 0, 0, 0 },
		LLL = { -40, 0, 0 },
	}),
})

-- Heavy weapons
atk("hammer_swing", {
	wind = merge(LEGS.wide, { LT = { 0, -30, 0 }, UT = { 6, -36, 0 }, H = { 0, 60, 0 } }, {
		RUA = { 150, 0, 50 },
		RLA = { 70, 0, 0 },
		RH = { 20, 0, 0 },
		LUA = { 140, 0, 20 },
		LLA = { 80, 0, 0 },
	}),
	hit = merge(LEGS.lunge, { LT = { 0, 34, 0 }, UT = { -20, 40, 0 }, H = { 0, -50, 0 } }, {
		RUA = { 74, 0, -26 },
		RLA = { 6, 0, 0 },
		RH = { -20, 0, 0 },
		LUA = { 70, 0, 34 },
		LLA = { 20, 0, 0 },
	}),
})
atk("hammer_slam", {
	wind = merge(LEGS.wide, { UT = { 22, 0, 0 }, H = { 10, 20, 0 } }, {
		RUA = { 178, 0, 10 },
		RLA = { 40, 0, 0 },
		RH = { 30, 0, 0 },
		LUA = { 176, 0, -6 },
		LLA = { 40, 0, 0 },
	}),
	hit = merge(LEGS.deep, { UT = { -44, 0, 0 }, H = { -10, 0, 0 } }, {
		RUA = { 40, 0, 0 },
		RLA = { 2, 0, 0 },
		RH = { -40, 0, 0 },
		LUA = { 44, 0, 14 },
		LLA = { 10, 0, 0 },
	}),
})
atk("ground_pound", {
	wind = merge(LEGS.wide, { root = { 0, 0.1, 0 }, UT = { 18, 0, 0 } }, {
		RUA = { 172, 0, 20 },
		RLA = { 30, 0, 0 },
		LUA = { 172, 0, -20 },
		LLA = { 30, 0, 0 },
	}),
	hit = merge(LEGS.crouch, { root = { 0, -1.5, -0.2 }, UT = { -50, 0, 0 }, H = { -10, 0, 0 } }, {
		RUA = { 30, 0, -8 },
		RLA = { 0, 0, 0 },
		LUA = { 30, 0, 8 },
		LLA = { 0, 0, 0 },
	}),
})
atk("shoulder_charge", {
	wind = merge(LEGS.wide, { UT = { -10, -30, 0 }, H = { 0, 40, 0 } }, ARMS.heavy),
	hit = merge(LEGS.deep, { LT = { 0, -50, 0 }, UT = { -30, -40, 0 }, H = { -10, 60, 0 } }, {
		RUA = { 40, 0, -40 },
		RLA = { 90, 0, 0 },
		LUA = { 20, 0, -10 },
		LLA = { 100, 0, 0 },
	}),
})
atk("leap_slam", {
	wind = merge(LEGS.crouch, { UT = { -20, 0, 0 } }, { RUA = { -30, 0, 20 }, LUA = { -30, 0, -20 }, RLA = { 30, 0, 0 } }),
	air = merge({ root = { 0, 0, 0, 14, 0, 0 } }, { UT = { 16, 0, 0 } }, {
		RUA = { 178, 0, 10 },
		RLA = { 40, 0, 0 },
		RH = { 30, 0, 0 },
		LUA = { 176, 0, -6 },
		LLA = { 40, 0, 0 },
		RUL = { 70, 0, 0 },
		RLL = { -100, 0, 0 },
		LUL = { 40, 0, 0 },
		LLL = { -80, 0, 0 },
	}),
	hit = A.hammer_slam and A.hammer_slam.hit or nil,
})
A.leap_slam.hit = A.hammer_slam.hit

-- Dual daggers
atk("dual_stab", {
	wind = merge(LEGS.low, { UT = { -10, 0, 0 } }, ARMS.dual, { RUA = { 20, 0, 30 }, LUA = { 20, 0, -30 }, RLA = { 110, 0, 0 }, LLA = { 110, 0, 0 } }),
	hit = merge(LEGS.deep, { UT = { -22, 0, 0 }, H = { -6, 20, 0 } }, {
		RUA = { 92, 0, 6 },
		RLA = { 4, 0, 0 },
		RH = { -20, 0, 0 },
		LUA = { 88, 0, -6 },
		LLA = { 4, 0, 0 },
		LH = { -20, 0, 0 },
	}),
})
atk("dual_flurry", {
	wind = A.dual_stab.wind,
	hit = merge(LEGS.deep, { UT = { -20, 30, 0 }, H = { 0, -10, 0 } }, {
		RUA = { 96, 0, -20 },
		RLA = { 4, 0, 0 },
		RH = { -20, 0, 0 },
		LUA = { 40, 0, -10 },
		LLA = { 110, 0, 0 },
	}),
	hit2 = merge(LEGS.deep, { UT = { -20, -30, 0 }, H = { 0, 40, 0 } }, {
		RUA = { 40, 0, 10 },
		RLA = { 110, 0, 0 },
		LUA = { 96, 0, 20 },
		LLA = { 4, 0, 0 },
		LH = { -20, 0, 0 },
	}),
})
atk("veil_drop", {
	wind = merge(LEGS.crouch, { UT = { -30, 0, 0 } }, { RUA = { -20, 0, 30 }, LUA = { -20, 0, -30 }, RLA = { 60, 0, 0 }, LLA = { 60, 0, 0 } }),
	hit = merge({ root = { 0, 0, 0, -20, 0, 0 } }, { UT = { -20, 0, 0 } }, {
		RUA = { 150, 0, 20 },
		RLA = { 10, 0, 0 },
		RH = { -100, 0, 0 },
		LUA = { 150, 0, -20 },
		LLA = { 10, 0, 0 },
		LH = { -100, 0, 0 },
		RUL = { 60, 0, 0 },
		RLL = { -90, 0, 0 },
		LUL = { 30, 0, 0 },
		LLL = { -60, 0, 0 },
	}),
})
atk("teleport", {
	wind = merge(LEGS.crouch, { UT = { -30, 0, 0 }, H = { -20, 0, 0 } }, {
		RUA = { 60, 0, -50 },
		RLA = { 90, 0, 0 },
		LUA = { 60, 0, 50 },
		LLA = { 90, 0, 0 },
	}),
	hit = merge(LEGS.low, { UT = { -10, 0, 0 } }, ARMS.dual),
})

-- Ranged
atk("shoot", {
	wind = merge(LEGS.stance, TORSO_TURN, ARMS.ranged, { RUA = { 70, 0, 10 }, RLA = { 30, 0, 0 }, RH = { -20, 0, 0 } }),
	hit = merge(LEGS.stance, { root = { 0, -0.3, 0.2 }, LT = { 0, -10, 0 }, UT = { 6, -10, 0 }, H = { 0, 20, 0 } }, {
		RUA = { 88, 0, -4 },
		RLA = { 6, 0, 0 },
		RH = { -4, 0, 0 },
		LUA = { 84, 0, 30 },
		LLA = { 40, 0, 0 },
	}),
})
atk("butt_strike", {
	wind = merge(LEGS.stance, { LT = { 0, -20, 0 }, UT = { 6, -30, 0 }, H = { 0, 40, 0 } }, ARMS.ranged, { RUA = { 40, 0, 40 }, RLA = { 90, 0, 0 } }),
	hit = merge(LEGS.lunge, { LT = { 0, 20, 0 }, UT = { -16, 30, 0 }, H = { 0, -30, 0 } }, {
		RUA = { 80, 0, -30 },
		RLA = { 20, 0, 0 },
		RH = { -90, 0, 0 },
		LUA = { 80, 0, 30 },
		LLA = { 30, 0, 0 },
	}),
})
atk("hook_throw", {
	wind = merge(LEGS.stance, { UT = { 4, 30, 0 } }, ARMS.ranged, { LUA = { 130, 0, -40 }, LLA = { 60, 0, 0 } }),
	hit = merge(LEGS.lunge, { UT = { -14, -26, 0 }, H = { 0, 30, 0 } }, ARMS.ranged, { LUA = { 92, 0, 0 }, LLA = { 0, 0, 0 } }),
})
atk("roll_back", {
	flip = 360,
	wind = merge(LEGS.crouch, { UT = { -20, 0, 0 } }, ARMS.ranged),
	hit = merge({ root = { 0, -1.6, 0.4, 0, 0, 0 } }, { UT = { -40, 0, 0 }, H = { -40, 0, 0 } }, {
		RUA = { 60, 0, -30 },
		RLA = { 120, 0, 0 },
		LUA = { 60, 0, 30 },
		LLA = { 120, 0, 0 },
		RUL = { 120, 0, 0 },
		RLL = { -140, 0, 0 },
		LUL = { 120, 0, 0 },
		LLL = { -140, 0, 0 },
	}),
})
atk("place_trap", {
	wind = merge(LEGS.crouch, { UT = { -30, 0, 0 } }, ARMS.ranged, { LUA = { 40, 0, 0 } }),
	hit = merge(LEGS.crouch, { UT = { -40, 0, 0 }, H = { -20, 0, 0 } }, ARMS.ranged, { LUA = { 30, 0, 0 }, LLA = { 0, 0, 0 } }),
})

-- Casting
atk("cast_forward", {
	wind = merge(LEGS.stance, { LT = { 0, -24, 0 }, UT = { 4, -34, 0 }, H = { 0, 50, 0 } }, {
		RUA = { 26, 0, 40 },
		RLA = { 110, 0, 0 },
		RH = { 0, 0, 0 },
		LUA = { 70, 0, -10 },
		LLA = { 60, 0, 0 },
	}),
	hit = merge(LEGS.lunge, { LT = { 0, 22, 0 }, UT = { -10, 30, 0 }, H = { 0, -30, 0 } }, {
		RUA = { 90, 0, -4 },
		RLA = { 2, 0, 0 },
		RH = { -80, 0, 0 },
		LUA = { 40, 0, -30 },
		LLA = { 60, 0, 0 },
	}),
})
atk("cast_ground", {
	wind = merge(LEGS.wide, { UT = { 16, 0, 0 } }, { RUA = { 160, 0, 20 }, RLA = { 30, 0, 0 }, LUA = { 160, 0, -20 }, LLA = { 30, 0, 0 } }),
	hit = merge(LEGS.crouch, { root = { 0, -1.4, -0.1 }, UT = { -46, 0, 0 }, H = { -10, 0, 0 } }, {
		RUA = { 40, 0, 10 },
		RLA = { 10, 0, 0 },
		RH = { -60, 0, 0 },
		LUA = { 40, 0, -10 },
		LLA = { 10, 0, 0 },
		LH = { -60, 0, 0 },
	}),
})
atk("cast_up", {
	wind = merge(LEGS.stance, TORSO_TURN, { RUA = { 40, 0, 30 }, LUA = { 40, 0, -30 }, RLA = { 90, 0, 0 }, LLA = { 90, 0, 0 } }),
	hit = merge(LEGS.tall, { UT = { 16, 0, 0 }, H = { 26, 0, 0 } }, { RUA = { 170, 0, 20 }, LUA = { 170, 0, -20 }, RLA = { 6, 0, 0 }, LLA = { 6, 0, 0 } }),
})
atk("point", {
	wind = merge(LEGS.stance, TORSO_TURN, { LUA = { 50, 0, -10 }, LLA = { 60, 0, 0 } }),
	hit = merge(LEGS.stance, { LT = { 0, -40, 0 }, UT = { -6, -20, 0 }, H = { 0, 50, 0 } }, { LUA = { 92, 0, 0 }, LLA = { 0, 0, 0 }, RUA = { 20, 0, 30 }, RLA = { 60, 0, 0 } }),
})
atk("lantern_raise", {
	wind = merge(LEGS.stance, { UT = { -6, 0, 0 } }, { RUA = { 40, 0, 10 }, RLA = { 60, 0, 0 } }),
	hit = merge(LEGS.stance, { UT = { 10, 0, 0 }, H = { 10, 0, 0 } }, { RUA = { 150, 0, 6 }, RLA = { 10, 0, 0 }, LUA = { 60, 0, -40 }, LLA = { 30, 0, 0 } }),
})
atk("spin_burst", {
	spin = 540,
	wind = merge(LEGS.crouch, { UT = { -24, 0, 0 } }, { RUA = { 40, 0, -40 }, LUA = { 40, 0, 40 }, RLA = { 100, 0, 0 }, LLA = { 100, 0, 0 } }),
	hit = merge(LEGS.square, { root = { 0, 0.1, 0 }, UT = { 10, 0, 0 }, H = { 14, 0, 0 } }, {
		RUA = { 90, 0, 80 },
		RLA = { 4, 0, 0 },
		LUA = { 90, 0, -80 },
		LLA = { 4, 0, 0 },
	}),
})
atk("armor_stance", {
	wind = merge(LEGS.wide, { UT = { -10, 0, 0 } }, { RUA = { 80, 0, -50 }, RLA = { 70, 0, 0 }, LUA = { 80, 0, 50 }, LLA = { 70, 0, 0 } }),
	hit = merge(LEGS.wide, { root = { 0, -0.6, 0 }, UT = { -16, 0, 0 }, H = { -10, 0, 0 } }, {
		RUA = { 86, 0, -56 },
		RLA = { 76, 0, 0 },
		LUA = { 86, 0, 56 },
		LLA = { 76, 0, 0 },
	}),
	hold = true,
})
atk("grab_cmd", {
	wind = merge(LEGS.wide, { UT = { 6, 0, 0 } }, { RUA = { 70, 0, 60 }, LUA = { 70, 0, -60 }, RLA = { 30, 0, 0 }, LLA = { 30, 0, 0 } }),
	hit = merge(LEGS.lunge, { UT = { -20, 0, 0 } }, { RUA = { 92, 0, 14 }, LUA = { 92, 0, -14 }, RLA = { 30, 0, 0 }, LLA = { 30, 0, 0 } }),
})
atk("throw_grab", {
	wind = merge(LEGS.stance, TORSO_TURN, { RUA = { 60, 0, 30 }, LUA = { 60, 0, -30 }, RLA = { 40, 0, 0 }, LLA = { 40, 0, 0 } }),
	hit = merge(LEGS.lunge, { UT = { -16, 0, 0 } }, { RUA = { 90, 0, 10 }, LUA = { 90, 0, -10 }, RLA = { 20, 0, 0 }, LLA = { 20, 0, 0 } }),
})

-- Air normals (legs FK, tucked)
local AIR_LEGS = { RUL = { 70, 0, 0 }, RLL = { -110, 0, 0 }, LUL = { 90, 0, 0 }, LLL = { -120, 0, 0 } }
Poses.AIR_LEGS = AIR_LEGS
atk("air_punch", {
	wind = merge(AIR_LEGS, ARMS.unarmed, { RUA = { 40, 0, 20 }, RLA = { 110, 0, 0 } }),
	hit = merge(AIR_LEGS, { UT = { -14, 20, 0 } }, ARMS.unarmed, { RUA = { 64, 0, -6 }, RLA = { 4, 0, 0 } }),
})
atk("air_slash", {
	wind = merge(AIR_LEGS, { UT = { 14, 0, 0 } }, ARMS.blade, { RUA = { 170, 0, 20 }, RLA = { 40, 0, 0 }, RH = { 10, 0, 0 } }),
	hit = merge(AIR_LEGS, { UT = { -26, 0, 0 } }, ARMS.blade, { RUA = { 40, 0, -10 }, RLA = { 4, 0, 0 }, RH = { -50, 0, 0 } }),
})
atk("air_kick", {
	wind = merge(AIR_LEGS, ARMS.unarmed),
	hit = merge({ UT = { 16, 0, 0 } }, ARMS.unarmed, {
		RUL = { 64, 0, 0 },
		RLL = { -2, 0, 0 },
		RF = { -30, 0, 0 },
		LUL = { 30, 0, 0 },
		LLL = { -110, 0, 0 },
	}),
})
atk("air_slam", {
	wind = merge(AIR_LEGS, { UT = { 16, 0, 0 } }, { RUA = { 176, 0, 10 }, RLA = { 40, 0, 0 }, LUA = { 176, 0, -10 }, LLA = { 40, 0, 0 } }),
	hit = merge(AIR_LEGS, { UT = { -34, 0, 0 } }, { RUA = { 50, 0, 0 }, RLA = { 4, 0, 0 }, RH = { -40, 0, 0 }, LUA = { 50, 0, 0 }, LLA = { 4, 0, 0 } }),
})

-------------------------------------------------------------------------------
-- State poses
-------------------------------------------------------------------------------

local S = {}
Poses.States = S

S.block = function(style)
	return merge(LEGS.stance, { root = { 0, -0.4, 0.1 }, UT = { -10, -10, 0 }, H = { -6, 20, 0 } }, {
		RUA = { 72, 0, -34 },
		RLA = { 118, 0, 0 },
		RH = style == "blade" and { -90, 0, 0 } or { 0, 0, 0 },
		LUA = { 72, 0, 34 },
		LLA = { 118, 0, 0 },
	})
end
S.crouch = function(style)
	return merge(LEGS.crouch, { LT = { 0, -18, 0 }, UT = { -16, -8, 0 }, H = { 6, 26, 0 } }, ARMS[style] or ARMS.unarmed)
end
S.crouch_block = function(style)
	return merge(S.crouch(style), {
		RUA = { 70, 0, -34 },
		RLA = { 120, 0, 0 },
		LUA = { 70, 0, 34 },
		LLA = { 120, 0, 0 },
		UT = { -24, 0, 0 },
	})
end
S.jump = function(style)
	return merge({ root = { 0, 0.1, 0 } }, AIR_LEGS, { UT = { -6, 0, 0 } }, ARMS[style] or ARMS.unarmed)
end
S.fall = function(style)
	return merge({ root = { 0, 0, 0 } }, { RUL = { 30, 0, 4 }, RLL = { -50, 0, 0 }, LUL = { 40, 0, -4 }, LLL = { -60, 0, 0 } }, ARMS[style] or ARMS.unarmed)
end
S.land = function(style)
	return merge(LEGS.crouch, { root = { 0, -0.9, 0 }, UT = { -12, 0, 0 } }, ARMS[style] or ARMS.unarmed)
end
S.dash = function(style)
	return merge(LEGS.lunge, { UT = { -24, -10, 0 }, H = { 10, 20, 0 } }, ARMS[style] or ARMS.unarmed)
end
S.backdash = function(style)
	return merge(LEGS.stance, { root = { 0, -0.2, 0.3 }, UT = { 14, -10, 0 }, H = { -6, 20, 0 } }, ARMS[style] or ARMS.unarmed)
end
S.hit_high = function()
	return merge(LEGS.stance, { root = { 0, -0.3, 0.35 }, UT = { 26, 10, 0 }, H = { 30, 0, 10 } }, {
		RUA = { -10, 0, 34 },
		RLA = { 40, 0, 0 },
		LUA = { -10, 0, -34 },
		LLA = { 40, 0, 0 },
	})
end
S.hit_mid = function()
	return merge(LEGS.stance, { root = { 0, -0.55, 0.3 }, UT = { -34, 0, 0 }, H = { -16, 0, 0 } }, {
		RUA = { 30, 0, -10 },
		RLA = { 90, 0, 0 },
		LUA = { 30, 0, 10 },
		LLA = { 90, 0, 0 },
	})
end
S.hit_low = function()
	return merge(LEGS.crouch, { root = { 0, -0.9, 0.2 }, UT = { -18, 0, 12 }, H = { 10, 0, 0 } }, {
		RUA = { 10, 0, 40 },
		RLA = { 30, 0, 0 },
		LUA = { 10, 0, -40 },
		LLA = { 30, 0, 0 },
	})
end
S.juggle = function()
	return merge({ root = { 0, 0, 0, 52, 0, 0 } }, { UT = { 20, 0, 0 }, H = { 30, 0, 0 } }, {
		RUA = { 150, 0, 40 },
		RLA = { 30, 0, 0 },
		LUA = { 140, 0, -40 },
		LLA = { 40, 0, 0 },
		RUL = { 50, 0, 6 },
		RLL = { -50, 0, 0 },
		LUL = { 30, 0, -6 },
		LLL = { -20, 0, 0 },
	})
end
S.lie = function()
	return merge({ root = { 0, -1.82, 0, 88, 0, 0 } }, { UT = { 4, 0, 0 }, H = { 10, 20, 0 } }, {
		RUA = { 30, 0, 60 },
		RLA = { 20, 0, 0 },
		LUA = { 50, 0, -50 },
		LLA = { 40, 0, 0 },
		RUL = { 10, 0, 10 },
		RLL = { -30, 0, 0 },
		LUL = { 30, 0, -8 },
		LLL = { -50, 0, 0 },
	})
end
S.lie_face = function()
	return merge({ root = { 0, -1.82, 0, -88, 0, 0 } }, { H = { 30, 30, 0 } }, {
		RUA = { 160, 0, 20 },
		RLA = { 30, 0, 0 },
		LUA = { 100, 0, -40 },
		LLA = { 60, 0, 0 },
		RUL = { -6, 0, 6 },
		RLL = { -20, 0, 0 },
		LUL = { 6, 0, -6 },
		LLL = { -40, 0, 0 },
	})
end
S.getup = function(style)
	return merge(LEGS.crouch, { UT = { -30, 0, 0 } }, ARMS[style] or ARMS.unarmed)
end
S.dazed = function()
	return merge(LEGS.square, { root = { 0, -0.35, 0.1 }, UT = { -18, 0, 6 }, H = { -28, 0, 10 } }, {
		RUA = { 4, 0, 10 },
		RLA = { 14, 0, 0 },
		LUA = { 10, 0, -14 },
		LLA = { 20, 0, 0 },
	})
end
S.kneel = function()
	return merge({ root = { 0, -1.15, 0 }, ikL = { -0.6, 0, -0.95, 0 }, ikR = { 0.6, 0, 0.75, -60 } }, { UT = { -20, 0, 0 }, H = { -30, 0, 0 } }, {
		RUA = { 20, 0, 6 },
		RLA = { 40, 0, 0 },
		LUA = { 40, 0, -10 },
		LLA = { 70, 0, 0 },
	})
end
S.thrown = function()
	return merge({ root = { 0, 0.4, 0, 20, 0, 0 } }, { UT = { 20, 0, 0 }, H = { 30, 0, 0 } }, {
		RUA = { 120, 0, 50 },
		RLA = { 30, 0, 0 },
		LUA = { 110, 0, -50 },
		LLA = { 30, 0, 0 },
		RUL = { 20, 0, 6 },
		RLL = { -40, 0, 0 },
		LUL = { 40, 0, -6 },
		LLL = { -70, 0, 0 },
	})
end
S.throwing = function()
	return merge(LEGS.wide, { UT = { 10, 0, 0 } }, {
		RUA = { 150, 0, 16 },
		RLA = { 30, 0, 0 },
		LUA = { 150, 0, -16 },
		LLA = { 30, 0, 0 },
	})
end
S.throwing_slam = function()
	return merge(LEGS.deep, { UT = { -40, 0, 0 } }, {
		RUA = { 50, 0, 10 },
		RLA = { 10, 0, 0 },
		LUA = { 50, 0, -10 },
		LLA = { 10, 0, 0 },
	})
end
S.breaker = function()
	return merge(LEGS.wide, { root = { 0, 0, 0 }, UT = { 18, 0, 0 }, H = { 20, 0, 0 } }, {
		RUA = { 110, 0, 80 },
		RLA = { 6, 0, 0 },
		LUA = { 110, 0, -80 },
		LLA = { 6, 0, 0 },
	})
end

-- Victory poses per style
local WIN = {
	blade = merge(LEGS.tall, { UT = { 8, 10, 0 }, H = { 12, -10, 0 } }, {
		RUA = { 176, 0, 14 },
		RLA = { 4, 0, 0 },
		RH = { 0, 0, 0 },
		LUA = { 10, 0, -14 },
		LLA = { 20, 0, 0 },
	}),
	pole = merge(LEGS.tall, { UT = { 4, 0, 0 }, H = { 10, 0, 0 } }, {
		RUA = { 30, 0, 26 },
		RLA = { 40, 0, 0 },
		RH = { -88, 0, 0 },
		LUA = { 60, 0, -60 },
		LLA = { 120, 0, 0 },
	}),
	heavy = merge(LEGS.wide, { UT = { 6, 20, 0 }, H = { 14, -10, 0 } }, {
		RUA = { 140, 0, 40 },
		RLA = { 120, 0, 0 },
		RH = { 50, 0, 0 },
		LUA = { 100, 0, -60 },
		LLA = { 60, 0, 0 },
	}),
	dual = merge(LEGS.stance, { UT = { 4, -20, 0 }, H = { -6, 30, 0 } }, {
		RUA = { 60, 0, -50 },
		RLA = { 100, 0, 0 },
		LUA = { 60, 0, 50 },
		LLA = { 100, 0, 0 },
	}),
	unarmed = merge(LEGS.tall, { UT = { 10, 0, 0 }, H = { 16, 0, 0 } }, {
		RUA = { 172, 0, 10 },
		RLA = { 10, 0, 0 },
		LUA = { 30, 0, -20 },
		LLA = { 110, 0, 0 },
	}),
	ranged = merge(LEGS.tall, { UT = { 4, 20, 0 }, H = { 6, -20, 0 } }, {
		RUA = { 150, 0, 30 },
		RLA = { 130, 0, 0 },
		RH = { 40, 0, 0 },
		LUA = { 20, 0, -14 },
		LLA = { 60, 0, 0 },
	}),
}
Poses.WIN = WIN

-------------------------------------------------------------------------------
-- Super cinematic sequences (anim names played back-to-back)
-------------------------------------------------------------------------------

Poses.SuperSequence = {
	blade = { "lunge_slash", "slash_diag", "slash_rising", "lunge_slash", "overhead_chop" },
	pole = { "thrust", "slash_diag", "thrust_lunge", "slash_rising", "overhead_chop" },
	heavy = { "hammer_swing", "uppercut", "hammer_swing", "ground_pound", "hammer_slam" },
	dual = { "dual_stab", "dual_flurry", "spin_kick", "dual_flurry", "veil_drop" },
	unarmed = { "jab", "cross", "hook", "uppercut", "hammer_fist" },
	ranged = { "butt_strike", "shoot", "kick_front", "shoot", "shoot" },
}

-------------------------------------------------------------------------------
-- Sampling
-------------------------------------------------------------------------------

local function lerpVec(a, b, t)
	if a == nil and b == nil then
		return nil
	end
	a = a or { 0, 0, 0, 0, 0, 0 }
	b = b or { 0, 0, 0, 0, 0, 0 }
	local n = math.max(#a, #b)
	local out = table.create(n)
	for i = 1, n do
		local x = a[i] or 0
		local y = b[i] or 0
		out[i] = x + (y - x) * t
	end
	return out
end

local POSE_KEYS = { "root", "LT", "UT", "H", "RUA", "RLA", "RH", "LUA", "LLA", "LH", "RUL", "RLL", "RF", "LUL", "LLL", "LF" }
Poses.POSE_KEYS = POSE_KEYS

function Poses.lerp(a, b, t: number)
	if t <= 0 then
		return a
	elseif t >= 1 then
		return b
	end
	local out = {}
	for _, k in POSE_KEYS do
		out[k] = lerpVec(a[k], b[k], t)
	end
	-- leg IK: blend targets when both have them; otherwise snap at halfway
	for _, k in { "ikL", "ikR" } do
		if a[k] and b[k] then
			out[k] = lerpVec(a[k], b[k], t)
		elseif t < 0.5 then
			out[k] = a[k]
		else
			out[k] = b[k]
		end
		if out[k] == nil then
			-- FK legs: blend the leg angles
			local side = k == "ikL" and "L" or "R"
			for _, part in { "UL", "LL", "F" } do
				local key = side .. part
				out[key] = lerpVec(a[key], b[key], t)
			end
		end
	end
	return out
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end
local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end
local function easeIn(t: number): number
	return t * t
end
Poses.ease = ease

-- Attack animation at frame `t` of a move with the given frame data.
function Poses.attack(name: string, style: string, t: number, startup: number, active: number, recovery: number)
	local def = A[name] or A.jab
	local stance = Poses.stance(style)
	local wind = def.wind
	local hit = def.hit
	local windEnd = math.max(1, math.floor(startup * 0.65))
	local pose
	local extra = nil
	if t <= windEnd then
		pose = Poses.lerp(stance, wind, easeOut(t / windEnd))
	elseif t <= startup then
		local k = (t - windEnd) / math.max(1, startup - windEnd)
		if def.air and k < 0.85 then
			pose = Poses.lerp(wind, def.air, easeOut(k / 0.85))
		else
			pose = Poses.lerp(def.air or wind, hit, easeIn(k))
		end
	elseif t <= startup + active then
		if def.hit2 then
			local k = (t - startup) / math.max(1, active)
			local cyc = math.floor(k * 5) % 2
			pose = cyc == 0 and hit or def.hit2
		elseif def.hold then
			local k = (t - startup) / math.max(1, active)
			pose = Poses.lerp(wind, hit, 0.5 + 0.5 * math.sin(k * math.pi * 4))
		else
			pose = hit
		end
	else
		local k = (t - startup - active) / math.max(1, recovery)
		pose = Poses.lerp(hit, stance, ease(math.clamp(k, 0, 1)))
	end
	if def.spin and t > windEnd then
		local k = math.clamp((t - windEnd) / math.max(1, startup + active - windEnd), 0, 1)
		extra = { spin = def.spin * easeOut(k) }
	end
	if def.flip and t > windEnd then
		local k = math.clamp((t - windEnd) / math.max(1, startup + active + recovery * 0.5 - windEnd), 0, 1)
		extra = { flip = def.flip * ease(k) }
	end
	if extra then
		pose = table.clone(pose)
		local r = pose.root and table.clone(pose.root) or { 0, 0, 0, 0, 0, 0 }
		for i = #r + 1, 6 do
			r[i] = 0
		end
		if extra.spin then
			r[5] = (r[5] or 0) + extra.spin
		end
		if extra.flip then
			r[4] = (r[4] or 0) + extra.flip
		end
		pose.root = r
	end
	return pose
end

-- Walk cycle: stepping IK targets around the stance.
function Poses.walk(style: string, phase: number, dir: number)
	local base = Poses.stance(style)
	local p = table.clone(base)
	local s = math.sin(phase)
	local c = math.cos(phase)
	local stride = 0.38 * dir
	local lift = 0.28
	local L = base.ikL
	local R = base.ikR
	p.ikL = { L[1], math.max(0, s) * lift, L[3] - s * stride, 0 }
	p.ikR = { R[1], math.max(0, -s) * lift, R[3] + s * stride, 0 }
	local r = base.root
	p.root = { r[1], r[2] + math.abs(c) * 0.06, r[3] }
	return p
end

-- Idle breathing on top of the stance.
function Poses.idle(style: string, time: number)
	local p = table.clone(Poses.stance(style))
	local b = math.sin(time * 2.4)
	local r = p.root
	p.root = { r[1], r[2] + b * 0.04, r[3] }
	p.UT = { (p.UT[1] or 0) + b * 1.6, p.UT[2], p.UT[3] }
	if p.RUA then
		p.RUA = { p.RUA[1] + b * 2, p.RUA[2], p.RUA[3] }
	end
	if p.LUA then
		p.LUA = { p.LUA[1] - b * 2, p.LUA[2], p.LUA[3] }
	end
	return p
end

return Poses
