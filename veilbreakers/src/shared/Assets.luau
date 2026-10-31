--!strict
-- Content ids. Images were generated with ForgeGUI and published to Roblox under the
-- project owner's account (approved by moderation).
--
-- Sounds: the game ships with a synthesized SFX/music pack in /audio. Upload that
-- folder (see README "Audio") and paste the resulting ids into Sounds below. Any
-- entry left empty falls back to a built-in Roblox sound or is skipped silently.

local Assets = {}

Assets.Images = {
	KeyArt = "rbxassetid://96901475166081",
	Emblem = "rbxassetid://118607179718886",
	Backdrop_hollowroot = "rbxassetid://75547949120352",
	Backdrop_skyreach = "rbxassetid://103130573906456",
	Backdrop_cathedral = "rbxassetid://101210805452512",
	Backdrop_emberthrone = "",
	Backdrop_proving = "",
}

-- Built-in particle textures that ship with every Roblox client.
Assets.Particles = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	FireSparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	ExplosionCore = "rbxasset://textures/particles/explosion01_core_main.dds",
	Implosion = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	Shockwave = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	ExplosionSmoke = "rbxasset://textures/particles/explosion01_smoke_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

Assets.Face = "rbxasset://textures/face.png"

-- Sound ids from the uploaded /audio pack. Leave "" to use the fallback.
Assets.Sounds = {
	music_menu = "",
	music_select = "",
	music_battle_a = "",
	music_battle_b = "",
	music_boss = "",
	music_story = "",
	music_victory = "",
	amb_forest = "",
	amb_wind = "",
	amb_cathedral = "",
	amb_lava = "",
	hit_light = "",
	hit_medium = "",
	hit_heavy = "",
	hit_blade = "",
	block = "",
	whoosh_light = "",
	whoosh_heavy = "",
	dash_slash = "",
	jump = "",
	land = "",
	dash = "",
	throw_slam = "",
	tech = "",
	knockdown = "",
	cast_lightning = "",
	cast_radiant = "",
	cast_shadow = "",
	cast_ice = "",
	cast_soul = "",
	fire_whoosh = "",
	fire_burst = "",
	lightning_crack = "",
	ground_crack = "",
	ground_slam = "",
	roots = "",
	teleport = "",
	parry_ready = "",
	parry = "",
	dagger_flurry = "",
	chakram_throw = "",
	crossbow = "",
	chain = "",
	smoke = "",
	trap_set = "",
	charge = "",
	slide = "",
	wing_flap = "",
	spin = "",
	projectile_hit = "",
	echo_summon = "",
	wolf_howl = "",
	ravens = "",
	lantern = "",
	flare = "",
	palm = "",
	super_start = "",
	super_impact = "",
	breaker = "",
	ko = "",
	round_gong = "",
	fight = "",
	finisher_ready = "",
	shatter = "",
	ui_move = "",
	ui_confirm = "",
	ui_back = "",
	ui_select = "",
	ui_lock = "",
	ui_versus = "",
	voice_m_attack = "",
	voice_m_hurt = "",
	voice_f_attack = "",
	voice_f_hurt = "",
	voice_d_attack = "",
	voice_d_hurt = "",
	voice_h_attack = "",
	voice_h_hurt = "",
	countdown = "",
}

-- Built-in Roblox sounds used when the matching Sounds entry is empty.
Assets.SoundFallback = {
	whoosh_light = "rbxasset://sounds/swordslash.wav",
	whoosh_heavy = "rbxasset://sounds/swordlunge.wav",
	dash_slash = "rbxasset://sounds/swordlunge.wav",
	dagger_flurry = "rbxasset://sounds/swordslash.wav",
	hit_blade = "rbxasset://sounds/swordslash.wav",
	jump = "rbxasset://sounds/action_jump.mp3",
	land = "rbxasset://sounds/action_jump_land.mp3",
	knockdown = "rbxasset://sounds/action_jump_land.mp3",
	throw_slam = "rbxasset://sounds/action_jump_land.mp3",
	ground_slam = "rbxasset://sounds/collide.wav",
	super_impact = "rbxasset://sounds/collide.wav",
	projectile_hit = "rbxasset://sounds/collide.wav",
	fire_burst = "rbxasset://sounds/collide.wav",
	ko = "rbxasset://sounds/collide.wav",
	crossbow = "rbxasset://sounds/Rocket shot.wav",
	cast_lightning = "rbxasset://sounds/Rocket shot.wav",
	cast_ice = "rbxasset://sounds/Rocket shot.wav",
	cast_soul = "rbxasset://sounds/Rocket whoosh 01.wav",
	cast_shadow = "rbxasset://sounds/Rocket whoosh 01.wav",
	cast_radiant = "rbxasset://sounds/Rocket whoosh 01.wav",
	chakram_throw = "rbxasset://sounds/Rocket whoosh 01.wav",
	fire_whoosh = "rbxasset://sounds/Rocket whoosh 01.wav",
	ui_confirm = "rbxasset://sounds/unsheath.wav",
	ui_lock = "rbxasset://sounds/unsheath.wav",
	parry_ready = "rbxasset://sounds/unsheath.wav",
	getup = "rbxasset://sounds/action_get_up.mp3",
}

function Assets.image(key: string): string
	return (Assets.Images :: any)[key] or ""
end

function Assets.sound(key: string): string
	local id = (Assets.Sounds :: any)[key]
	if id and id ~= "" then
		if string.match(id, "^%d+$") then
			return "rbxassetid://" .. id
		end
		return id
	end
	return (Assets.SoundFallback :: any)[key] or ""
end

return Assets
