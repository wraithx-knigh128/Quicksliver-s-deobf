--!nonstrict
-- Global tuning values for OOF COMBAT. Everything in the combat engine runs on a
-- fixed 60 Hz tick, so all durations here are in frames unless the name says otherwise.

local Config = {}

Config.GameTitle = "OOF COMBAT"
Config.GameSubtitle = "THE GREAT SERVER RESET"
Config.Version = "1.3.0"

Config.TickRate = 60
Config.TickDt = 1 / 60

-- Match rules
Config.RoundTimeSeconds = 99
Config.RoundsToWin = 2
Config.MaxHealth = 1000
Config.BossHealthBonus = 50

-- Meter (3 bars of 100)
Config.MeterBar = 100
Config.MeterMax = 300
Config.SuperCost = 200
Config.BreakerCost = 100
Config.BreakerMinHits = 2

-- Powers (keys 1-4): each fighter's four ground specials. Using one, by its key
-- or by its motion input, puts it on cooldown (frames). No cooldowns in Practice.
Config.PowerSlots = { "SN", "SF", "SB", "SD" }
Config.PowerCooldowns = true
Config.PowerCooldown = {
	default = 96,
	projectile = 78,
	teleport = 120,
	parry = 140,
	reversal = 150, -- invulnerable starts
}

-- Echo (assist) cooldown, frames
Config.EchoCooldown = 60 * 11
Config.EchoCooldownAfterBreaker = 60 * 6

-- Stage geometry (studs)
Config.StageHalfWidth = 36
Config.MaxSeparation = 21 -- camera limit: fighters can't walk further apart
Config.PushHalfWidth = 1.05
Config.GroundY = 0

-- Movement (studs / frame)
Config.WalkForward = 0.155
Config.WalkBack = 0.115
Config.JumpVelocity = 0.60
Config.JumpForward = 0.165
Config.Gravity = 0.033
Config.JuggleGravity = 0.030
Config.DashFrames = 16
Config.DashSpeed = 0.42
Config.BackdashFrames = 18
Config.BackdashSpeed = 0.36
Config.DoubleTapWindow = 12
Config.JumpSquat = 3
Config.LandingLag = 4
Config.InputBuffer = 7

-- Hit reactions
Config.KnockdownFrames = 34
Config.GetupFrames = 18
Config.GetupInvuln = 22
Config.DamageScale = 1.22
Config.MaxJuggleHits = 7
Config.ComboScalingStep = 0.09
Config.ComboScalingMin = 0.35
Config.ChipFraction = 0.12
Config.ThrowRange = 1.15 -- beyond pushbox contact
Config.ThrowTechWindow = 9

-- Hitstop (freeze) frames by strength
Config.Hitstop = {
	light = 5,
	medium = 7,
	heavy = 10,
	special = 9,
	super = 0,
}

-- Finisher
Config.FinisherWindowSeconds = 6

-- Training
Config.TrainingRefillDelay = 50

-- Camera
Config.CameraFov = 36
Config.CameraBaseDistance = 19.5
Config.CameraDistancePerStud = 0.42
Config.CameraHeight = 4.2
Config.CameraLookHeight = 3.6

Config.Difficulty = {
	{
		id = "novice",
		name = "NOOB",
		reaction = 26,
		blockChance = 0.18,
		punishChance = 0.15,
		antiAirChance = 0.12,
		comboSkill = 0.25,
		aggression = 0.5,
		breakerChance = 0.05,
		superChance = 0.25,
		techChance = 0.05,
	},
	{
		id = "adept",
		name = "PRO",
		reaction = 16,
		blockChance = 0.42,
		punishChance = 0.45,
		antiAirChance = 0.4,
		comboSkill = 0.6,
		aggression = 0.62,
		breakerChance = 0.25,
		superChance = 0.55,
		techChance = 0.25,
	},
	{
		id = "veteran",
		name = "TRYHARD",
		reaction = 11,
		blockChance = 0.66,
		punishChance = 0.75,
		antiAirChance = 0.65,
		comboSkill = 0.85,
		aggression = 0.72,
		breakerChance = 0.5,
		superChance = 0.8,
		techChance = 0.45,
	},
	{
		id = "veilbreaker",
		name = "SWEAT",
		reaction = 7,
		blockChance = 0.86,
		punishChance = 0.95,
		antiAirChance = 0.88,
		comboSkill = 1.0,
		aggression = 0.8,
		breakerChance = 0.75,
		superChance = 0.95,
		techChance = 0.7,
	},
}

return Config
