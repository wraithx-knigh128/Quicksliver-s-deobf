--!nonstrict
-- Music, ambience, SFX and voice playback with volume groups and crossfades.
-- Sound ids come from Assets.Sounds (uploaded pack) with built-in fallbacks.
-- Missing ids are skipped silently so the game never errors on absent audio.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Assets = require(Veil.Assets)

local Audio = {}

local groups = {}
local function group(name: string, volume: number): SoundGroup
	if groups[name] then
		return groups[name]
	end
	local g = Instance.new("SoundGroup")
	g.Name = "Veil" .. name
	g.Volume = volume
	g.Parent = SoundService
	groups[name] = g
	return g
end

local music = group("Music", 0.55)
local sfx = group("SFX", 0.8)
local ambience = group("Ambience", 0.45)
local voice = group("Voice", 0.85)
local ui = group("UI", 0.7)

local currentMusic: Sound? = nil
local currentMusicKey: string? = nil
local currentAmb: Sound? = nil
local currentAmbKey: string? = nil

local pools = {}

local function makeSound(id: string, g: SoundGroup, looped: boolean?, region): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.SoundGroup = g
	s.Looped = looped == true
	if region then
		-- play a slice of an audio atlas
		s.PlaybackRegionsEnabled = true
		local range = NumberRange.new(region.start, region.start + region.length)
		s.PlaybackRegion = range
		if looped then
			s.LoopRegion = range
		end
	end
	s.Parent = g
	return s
end

function Audio.setVolumes(settings)
	music.Volume = settings.music or music.Volume
	sfx.Volume = settings.sfx or sfx.Volume
	ambience.Volume = (settings.sfx or 0.8) * 0.55
	voice.Volume = settings.voice or voice.Volume
	ui.Volume = (settings.sfx or 0.8) * 0.85
end

-- One-shot sound effect. opts: { volume, pitch, pitchVar, group }
function Audio.play(key: string, opts)
	local id, region = Assets.sound(key)
	if id == "" then
		return nil
	end
	opts = opts or {}
	local g = opts.group == "ui" and ui or (opts.group == "voice" and voice or sfx)
	local pool = pools[key]
	if not pool then
		pool = { list = {}, idx = 0 }
		pools[key] = pool
	end
	pool.idx = pool.idx % 4 + 1
	local s = pool.list[pool.idx]
	if not s then
		s = makeSound(id, g, false, region)
		pool.list[pool.idx] = s
	end
	s.Volume = opts.volume or 0.8
	local pitch = opts.pitch or 1
	if opts.pitchVar then
		pitch += (math.random() - 0.5) * 2 * opts.pitchVar
	end
	s.PlaybackSpeed = pitch
	s.TimePosition = region and region.start or 0
	s:Play()
	return s
end

function Audio.ui(key: string)
	return Audio.play(key, { group = "ui", volume = 0.6 })
end

local VOICE_PREFIX = { male = "voice_m_", female = "voice_f_", deep = "voice_d_", hollow = "voice_h_" }
function Audio.voice(kind: string, what: string)
	local key = (VOICE_PREFIX[kind] or "voice_m_") .. what
	return Audio.play(key, { group = "voice", volume = 0.7, pitchVar = 0.06 })
end

local function fadeOut(s: Sound?, time: number)
	if not s then
		return
	end
	local tw = TweenService:Create(s, TweenInfo.new(time), { Volume = 0 })
	tw:Play()
	task.delay(time + 0.05, function()
		s:Stop()
		s:Destroy()
	end)
end

function Audio.music(key: string?, fade: number?)
	if key == currentMusicKey then
		return
	end
	fadeOut(currentMusic, fade or 1.2)
	currentMusic = nil
	currentMusicKey = key
	if not key then
		return
	end
	local id, region = Assets.sound(key)
	if id == "" then
		return
	end
	local s = makeSound(id, music, key ~= "music_victory", region)
	s.Volume = 0
	s:Play()
	TweenService:Create(s, TweenInfo.new(fade or 1.2), { Volume = 0.7 }):Play()
	currentMusic = s
end

function Audio.ambience(key: string?)
	if key == currentAmbKey then
		return
	end
	fadeOut(currentAmb, 1.5)
	currentAmb = nil
	currentAmbKey = key
	if not key or key == "" then
		return
	end
	local id, region = Assets.sound(key)
	if id == "" then
		return
	end
	local s = makeSound(id, ambience, true, region)
	s.Volume = 0
	s:Play()
	TweenService:Create(s, TweenInfo.new(2), { Volume = 0.6 }):Play()
	currentAmb = s
end

-- Duck music briefly (supers, finishers, KO)
function Audio.duck(amount: number, time: number)
	if not currentMusic then
		return
	end
	local s = currentMusic
	TweenService:Create(s, TweenInfo.new(0.15), { Volume = 0.7 * amount }):Play()
	task.delay(time, function()
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(0.6), { Volume = 0.7 }):Play()
		end
	end)
end

return Audio
