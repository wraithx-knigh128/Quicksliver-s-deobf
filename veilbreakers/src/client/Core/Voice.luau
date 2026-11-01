--!nonstrict
-- Spoken lines through Roblox's built-in text-to-speech (AudioTextToSpeech, part of
-- the audio API). It reads the game's own original lines (intros, victory quotes,
-- story dialogue, the announcer) with a voice profile per character.
--
-- It is feature-detected: if the experience/Studio version doesn't offer
-- AudioTextToSpeech, or a line fails to load, Voice.say returns false and callers
-- fall back to the synthesized voice grunts. The first failure disables it for the
-- session so it never spams errors.

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Voice = {}

Voice.enabled = true
Voice.volume = 0.85

-- VoiceId values are Roblox's built-in TTS voices; Pitch / Speed shape each cast
-- member. If your Studio lists different voice ids, change them here.
Voice.PROFILES = {
	male = { id = "1", pitch = 1.0, speed = 1.05 },
	female = { id = "2", pitch = 1.05, speed = 1.05 },
	deep = { id = "1", pitch = 0.72, speed = 0.9 },
	hollow = { id = "2", pitch = 0.82, speed = 0.88 },
	announcer = { id = "1", pitch = 0.8, speed = 0.95 },
	system = { id = "2", pitch = 1.2, speed = 1.15 },
}

local supported = nil
local channels = {}

function Voice.isSupported(): boolean
	if supported ~= nil then
		return supported
	end
	local ok, inst = pcall(Instance.new, "AudioTextToSpeech")
	supported = ok and inst ~= nil
	if ok and inst then
		inst:Destroy()
	end
	return supported
end

local function stopChannel(name: string)
	local cur = channels[name]
	if cur then
		channels[name] = nil
		pcall(function()
			cur:Pause()
			cur:Destroy()
		end)
	end
end

-- Speak `text` with a profile ("male", "deep", "announcer"...). One line per
-- channel: a new line on the same channel cuts the previous one off.
-- Returns true if text-to-speech is handling it.
function Voice.say(text: string, profile: string?, opts): boolean
	if not Voice.enabled or not text or text == "" or not Voice.isSupported() then
		return false
	end
	opts = opts or {}
	local prof = Voice.PROFILES[profile or "male"] or Voice.PROFILES.male
	local channel = opts.channel or "dialogue"
	stopChannel(channel)
	local ok = pcall(function()
		local tts = Instance.new("AudioTextToSpeech")
		tts.Text = text
		tts.VoiceId = prof.id
		tts.Pitch = prof.pitch
		tts.Speed = prof.speed
		tts.Volume = math.clamp(Voice.volume * (opts.volume or 1), 0, 3)
		local out = Instance.new("AudioDeviceOutput")
		out.Parent = tts
		local wire = Instance.new("Wire")
		wire.SourceInstance = tts
		wire.TargetInstance = out
		wire.Parent = tts
		tts.Parent = SoundService
		channels[channel] = tts
		Debris:AddItem(tts, 15)
		task.spawn(function()
			local loaded, status = pcall(function()
				return tts:LoadAsync()
			end)
			if not loaded or status ~= Enum.AssetFetchStatus.Success then
				if not loaded then
					supported = false
				end
				if channels[channel] == tts then
					channels[channel] = nil
				end
				tts:Destroy()
				return
			end
			if channels[channel] == tts then
				tts:Play()
			end
		end)
	end)
	if not ok then
		supported = false
	end
	return ok
end

function Voice.stopAll()
	for name in channels do
		stopChannel(name)
	end
end

return Voice
