--!nonstrict
-- Per-fight looks for each arena: the map you pick decides the place, the variant
-- (rolled every fight) decides the time of day and weather, so no two fights look
-- the same. Online, the server rolls it so both players see the same sky.

local StageVariants = {}

-- id -> { name, clock (ClockTime override), bright (Lighting.Brightness multiplier),
--         tint (grade tint), fog (atmosphere density add), weather = rain|snow|ash|leaves|nil,
--         storm (lightning flashes) }
StageVariants.Defs = {
	default = { name = "" },
	dusk = { name = "DUSK", clock = 17.6, bright = 0.85, tint = "#FFD2B0", fog = 0.05 },
	night = { name = "NIGHT", clock = 0.4, bright = 0.55, tint = "#B8C8FF", fog = 0.04 },
	storm = { name = "STORM", bright = 0.7, tint = "#C8D2E0", fog = 0.08, weather = "rain", storm = true },
	fog = { name = "FOG", bright = 0.9, tint = "#E6ECEC", fog = 0.22 },
	rain = { name = "RAIN", bright = 0.8, tint = "#D2DCE6", fog = 0.06, weather = "rain" },
	snow = { name = "SNOWFALL", bright = 1.0, tint = "#E8F2FF", fog = 0.08, weather = "snow" },
	ashstorm = { name = "ASH STORM", bright = 0.75, tint = "#FFC8A8", fog = 0.12, weather = "ash" },
	sunset = { name = "SUNSET", clock = 18.1, bright = 0.9, tint = "#FFC89A", fog = 0.03 },
}

-- Which variants each stage can roll.
StageVariants.ByStage = {
	hollowroot = { "default", "fog", "storm", "night" },
	skyreach = { "default", "dusk", "night", "rain" },
	cathedral = { "default", "storm", "fog", "snow" },
	emberthrone = { "default", "ashstorm", "night" },
	baseplate = { "default", "sunset", "night", "rain" },
	proving = { "default" },
}

function StageVariants.list(stageId: string)
	return StageVariants.ByStage[stageId] or { "default" }
end

-- r in [0, 1)
function StageVariants.roll(stageId: string, r: number): string
	local list = StageVariants.list(stageId)
	return list[math.floor(r * #list) + 1] or "default"
end

function StageVariants.get(id: string?)
	return StageVariants.Defs[id or "default"] or StageVariants.Defs.default
end

return StageVariants
