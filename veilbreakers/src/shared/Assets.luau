--!nonstrict
-- Content ids. Images were generated with ForgeGUI and published to Roblox under the
-- project owner's account (approved by moderation).
--
-- Audio: the game ships with a synthesized pack packed into four atlas files in
-- /audio/atlas. Upload those four files (README "Audio") and paste their ids into
-- AudioAtlas below; every SFX, voice, ambience and music cue then plays from its
-- region (src/shared/AudioAtlas.luau). Individual ids in Sounds override the atlas.
-- Anything without an id falls back to a built-in Roblox sound or stays silent.

local Atlas = require(script.Parent.AudioAtlas)

local Assets = {}

Assets.Images = {
	KeyArt = "rbxassetid://96901475166081",
	Emblem = "rbxassetid://118607179718886",
	Backdrop_hollowroot = "rbxassetid://75547949120352",
	Backdrop_skyreach = "rbxassetid://103130573906456",
	Backdrop_cathedral = "rbxassetid://101210805452512",
	Backdrop_emberthrone = "",
	Backdrop_proving = "",
	Backdrop_baseplate = "",
	-- Original VFX textures in /art/vfx (tools/make_vfx_textures.py). Upload them in
	-- Studio (Asset Manager > Bulk Import) and paste the image ids here; until then the
	-- game draws speed lines procedurally and uses the built-in particle textures.
	FX_SpeedLines = "",
	FX_Slash = "",
	FX_HitBurst = "",
	FX_Shockwave = "",
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

-- Asset ids of the four uploaded atlas files (numbers only or rbxassetid://...).
Assets.AudioAtlas = {
	sfx = "",
	ambience = "",
	music_a = "",
	music_b = "",
}

-- Optional per-sound overrides. Leave "" to use the atlas / fallback.
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
	oof = "",
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
	-- Only long-standing built-in client sounds (classic sword gear + character
	-- sounds), so a fresh place never logs "Failed to load sound".
	whoosh_light = "rbxasset://sounds/swordslash.wav",
	whoosh_heavy = "rbxasset://sounds/swordlunge.wav",
	dash_slash = "rbxasset://sounds/swordlunge.wav",
	dagger_flurry = "rbxasset://sounds/swordslash.wav",
	hit_blade = "rbxasset://sounds/swordslash.wav",
	ui_confirm = "rbxasset://sounds/unsheath.wav",
	ui_lock = "rbxasset://sounds/unsheath.wav",
	parry_ready = "rbxasset://sounds/unsheath.wav",
	jump = "rbxasset://sounds/action_jump.mp3",
	land = "rbxasset://sounds/action_jump_land.mp3",
	knockdown = "rbxasset://sounds/action_jump_land.mp3",
	throw_slam = "rbxasset://sounds/action_jump_land.mp3",
	getup = "rbxasset://sounds/action_get_up.mp3",
}

function Assets.image(key: string): string
	return (Assets.Images :: any)[key] or ""
end

local function normalise(id: string): string
	if string.match(id, "^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

-- Returns (soundId, region?) where region = { start, length } inside an atlas.
function Assets.sound(key: string): (string, { start: number, length: number }?)
	local id = (Assets.Sounds :: any)[key]
	if id and id ~= "" then
		return normalise(id), nil
	end
	local region = Atlas[key]
	if region then
		local atlasId = (Assets.AudioAtlas :: any)[region.atlas]
		if atlasId and atlasId ~= "" then
			return normalise(atlasId), region
		end
	end
	return (Assets.SoundFallback :: any)[key] or "", nil
end

return Assets
