--!nonstrict
-- In-engine story cinematics, edited the way Roblox animation channels cut theirs:
--
--   * Acting: every actor runs through the spring layer (eased, overshooting motion),
--     talks with head nods and beat gestures picked from the line (shrug on a question,
--     shout on CAPS, point on an exclamation...), and listeners turn to the speaker.
--     Actors can walk into frame, hop, and play attack animations.
--   * Coverage: multi-line dialogue shots cut between a two-shot, over-the-shoulder
--     angles and close-ups on whoever is talking; shouted lines get a crash zoom.
--   * Camera: handheld drift, push-ins, orbits, dutch angles, whip pans with blur.
--   * Editing beats (CineFX): freeze-frame name cards, impact frames, pop captions,
--     speed lines, slow motion, booms.
--
-- Scene data lives in Data/Story.luau; see the event list in runEvent below.

local RunService = game:GetService("RunService")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Fighters = require(Veil.Data.Fighters)
local Stages = require(Veil.Data.Stages)
local Story = require(Veil.Data.Story)

local Client = script.Parent.Parent
local Rig = require(script.Parent.Rig)
local Poses = require(script.Parent.Poses)
local AnimSpring = require(script.Parent.AnimSpring)
local CineFX = require(script.Parent.CineFX)
local StageBuilder = require(script.Parent.StageBuilder)
local FightCamera = require(script.Parent.FightCamera)
local VFX = require(script.Parent.VFX)
local Audio = require(Client.Core.Audio)
local Input = require(Client.Core.Input)
local Voice = require(Client.Core.Voice)
local Theme = require(Client.UI.Theme)
local Subtitles = require(Client.UI.Subtitles)

local C = Theme.Colors
local F = Theme.Fonts

local Cutscene = {}

local YAW = math.rad(25)
local V = Vector3.new

local function rootCF(x: number, facing: number, y: number?)
	local pos = V(x, y or 0, 0)
	return CFrame.lookAt(pos, pos + V(facing * math.cos(YAW), 0, math.sin(YAW)))
end

-------------------------------------------------------------------------------
-- Acting: gestures layered over the base pose
-------------------------------------------------------------------------------

-- Arm keys are absolute targets; UT / H / LT are added to the base pose.
local GESTURES = {
	talk = { RUA = { 48, 0, 16 }, RLA = { 72, 0, 0 }, RH = { -20, 0, 0 } },
	point = { RUA = { 88, 0, 6 }, RLA = { 6, 0, 0 }, RH = { 0, 0, 0 }, UT = { -5, 6, 0 }, H = { 3, 0, 0 } },
	shrug = { RUA = { 12, 0, 44 }, RLA = { 92, 0, 0 }, LUA = { 12, 0, -44 }, LLA = { 92, 0, 0 }, H = { 0, 0, 14 }, UT = { 3, 0, 0 } },
	facepalm = { RUA = { 142, 0, -24 }, RLA = { 128, 0, 0 }, H = { -22, 0, 0 }, UT = { -8, 0, 0 } },
	cross = { RUA = { 70, 0, -46 }, RLA = { 100, 0, 0 }, RH = { 60, 0, 0 }, LUA = { 70, 0, 46 }, LLA = { 100, 0, 0 }, H = { 8, 0, 0 } },
	shout = { RUA = { -18, 0, 34 }, RLA = { 28, 0, 0 }, LUA = { -18, 0, -34 }, LLA = { 28, 0, 0 }, UT = { -14, 0, 0 }, H = { 12, 0, 0 } },
	fist = { RUA = { 104, 0, 10 }, RLA = { 112, 0, 0 }, UT = { -6, 0, 0 } },
	think = { RUA = { 112, 0, -18 }, RLA = { 148, 0, 0 }, LUA = { 38, 0, 28 }, LLA = { 96, 0, 0 }, H = { -6, 0, 12 } },
	nervous = { RUA = { 165, 0, 36 }, RLA = { 122, 0, 0 }, H = { -6, 0, -10 } },
	wave = { RUA = { 165, 0, 24 }, RLA = { 18, 0, 0 } },
	laugh = { RUA = { 18, 0, 28 }, LUA = { 18, 0, -28 }, H = { 20, 0, 0 }, UT = { 8, 0, 0 } },
	sad = { RUA = { 4, 0, 4 }, RLA = { 6, 0, 0 }, LUA = { 4, 0, -4 }, LLA = { 6, 0, 0 }, H = { -26, 0, 0 }, UT = { -12, 0, 0 } },
	flex = { RUA = { 92, 0, 80 }, RLA = { 125, 0, 0 }, LUA = { 92, 0, -80 }, LLA = { 125, 0, 0 }, UT = { 6, 0, 0 }, H = { 14, 0, 0 } },
}
Cutscene.GESTURES = GESTURES

local ADDITIVE = { UT = true, H = true, LT = true }

local function applyGesture(base, g, w: number)
	local out = table.clone(base)
	for k, v in g do
		local b = base[k] or { 0, 0, 0 }
		if ADDITIVE[k] then
			out[k] = { (b[1] or 0) + v[1] * w, (b[2] or 0) + v[2] * w, (b[3] or 0) + v[3] * w }
		else
			out[k] = { (b[1] or 0) + (v[1] - (b[1] or 0)) * w, (b[2] or 0) + (v[2] - (b[2] or 0)) * w, (b[3] or 0) + (v[3] - (b[3] or 0)) * w }
		end
	end
	return out
end

local function addTo(pose, key: string, a: number, b: number, c: number)
	local v = pose[key] or { 0, 0, 0 }
	pose[key] = { (v[1] or 0) + a, (v[2] or 0) + b, (v[3] or 0) + c }
end

-- Face for an actor: from its gesture while talking, else from its base anim.
local GESTURE_FACE = {
	shout = "angry",
	fist = "angry",
	point = "focus",
	sad = "sad",
	nervous = "sad",
	facepalm = "sad",
	shrug = "neutral",
	laugh = "happy",
	wave = "happy",
	flex = "angry",
	cross = "focus",
	think = "focus",
}
function Cutscene.expressionFor(a): string
	if a.act then
		return "angry"
	end
	if a.gesture and GESTURE_FACE[a.gesture] then
		return GESTURE_FACE[a.gesture]
	end
	if a.anim == "dazed" then
		return "ko"
	elseif a.anim == "kneel" then
		return "hurt"
	elseif a.anim == "win" then
		return "happy"
	end
	return GESTURE_FACE[a.anim] or "neutral"
end

-- Pick a gesture from how the line reads.
function Cutscene.autoGesture(text: string, speakerId: string?): string?
	if speakerId == "system" then
		return nil
	end
	local letters, caps = 0, 0
	for ch in string.gmatch(text, "%a") do
		letters += 1
		if string.match(ch, "%u") then
			caps += 1
		end
	end
	if letters >= 6 and caps / letters > 0.7 then
		return "shout"
	end
	local lower = string.lower(text)
	if string.find(lower, "^%.%.%.") then
		return "sad"
	elseif string.find(lower, "^hey") or string.find(lower, "^hi[%s,!.]") then
		return "wave"
	elseif string.find(lower, "haha") or string.find(lower, "lol") then
		return "laugh"
	elseif string.find(text, "%?%s*$") or string.find(text, "%?\"?%s*$") then
		return "shrug"
	elseif string.find(text, "!%s*$") then
		return "point"
	end
	return "talk"
end

-------------------------------------------------------------------------------
-- Camera shots: function(shot, actors, t) -> CFrame, fov
-------------------------------------------------------------------------------

local function headPos(actors, i: number?)
	local a = i and actors[i]
	if not a then
		return V(0, 4, 0)
	end
	return V(a.x, (a.y or 0) + 4.4 * a.rig.scale, 0)
end

local function visibleMid(actors)
	local sum, n = Vector3.zero, 0
	for _, a in actors do
		if not a.hidden then
			sum += V(a.x, 3.2, 0)
			n += 1
		end
	end
	return n > 0 and sum / n or V(0, 3.2, 0)
end

local SHOTS = {}
SHOTS.sky = function(_shot, _actors, t)
	local pos = V(-8 + t * 1.6, 7 + t * 0.4, 30)
	local look = V(-2 + t * 1.2, 18, -60)
	return CFrame.lookAt(pos, look), 50
end
SHOTS.wide = function(_shot, actors, t)
	local mid = visibleMid(actors)
	local pos = mid + V(-3 + t * 0.6, 2.2, 21 - t * 0.5)
	return CFrame.lookAt(pos, mid), 40
end
SHOTS.two = function(shot, actors, t)
	local a, b = headPos(actors, shot.a or 1), headPos(actors, shot.b or 2)
	local mid = (a + b) / 2 - V(0, 0.6, 0)
	local sep = (a - b).Magnitude
	local pos = mid + V(t * 0.3, 0.6, 7 + sep * 0.9 - t * 0.2)
	return CFrame.lookAt(pos, mid), 38
end
SHOTS.close = function(shot, actors, t)
	local a = actors[shot.a or 1]
	local h = headPos(actors, shot.a or 1) - V(0, 0.2, 0)
	local facing = a and a.facing or 1
	local pos = h + V(facing * 3.2, 0.2, 5.4 - t * 0.18)
	return CFrame.lookAt(pos, h), 30
end
-- over the shoulder of `a`, looking at `b`
SHOTS.over = function(shot, actors, t)
	local a, b = headPos(actors, shot.a or 1), headPos(actors, shot.b or 2)
	local d = b - a
	local dir = d.Magnitude > 0.01 and d.Unit or V(1, 0, 0)
	local pos = a - dir * 3.2 + V(0, 0.8, 2.8 + t * 0.1)
	return CFrame.lookAt(pos, b - V(0, 0.4, 0)), 36
end
SHOTS.low = function(shot, actors, t)
	local a = actors[shot.a or 1]
	local h = headPos(actors, shot.a or 1)
	local facing = a and a.facing or 1
	local pos = V(h.X + facing * 4.5, 0.8 + t * 0.1, 6.5)
	return CFrame.lookAt(pos, h + V(0, 0.6, 0)), 42
end
-- crash zoom: snaps from a medium to a tight close-up with a dutch tilt
SHOTS.crash = function(shot, actors, t)
	local a = actors[shot.a or 1]
	local h = headPos(actors, shot.a or 1) - V(0, 0.15, 0)
	local facing = a and a.facing or 1
	local k = math.clamp(t / 0.22, 0, 1)
	k = 1 - (1 - k) ^ 3
	local fov = 44 + (20 - 44) * k
	local pos = h + V(facing * 2.6, 0.1, 5.8)
	return CFrame.lookAt(pos, h) * CFrame.Angles(0, 0, math.rad(8) * facing), fov
end
SHOTS.dutch = function(shot, actors, t)
	local a = actors[shot.a or 1]
	local h = headPos(actors, shot.a or 1)
	local facing = a and a.facing or 1
	local pos = h + V(facing * 3.6, -0.6, 5.2 - t * 0.25)
	return CFrame.lookAt(pos, h) * CFrame.Angles(0, 0, math.rad(-14) * facing), 34
end
SHOTS.orbit = function(shot, actors, t)
	local h = headPos(actors, shot.a or 1) - V(0, 0.5, 0)
	local ang = math.rad(-30 + t * 18)
	local pos = h + V(math.sin(ang) * 7, 0.8, math.cos(ang) * 7)
	return CFrame.lookAt(pos, h), 34
end
SHOTS.dolly = function(shot, actors, t)
	local a = actors[shot.a or 1]
	local h = headPos(actors, shot.a or 1) - V(0, 0.3, 0)
	local facing = a and a.facing or 1
	local dist = math.max(4.2, 11 - t * 1.6)
	local pos = h + V(facing * dist * 0.45, 0.3, dist)
	return CFrame.lookAt(pos, h), 34
end
SHOTS.track = function(shot, actors, t)
	local h = headPos(actors, shot.a or 1) - V(0, 1.2, 0)
	local pos = h + V(-2, 1.4, 13)
	local _ = t
	return CFrame.lookAt(pos, h + V(0, 0.4, 0)), 38
end

local function shotCF(shot, actors, t)
	local fn = SHOTS[shot.cam] or SHOTS.wide
	return fn(shot, actors, t)
end

-------------------------------------------------------------------------------
-- Player
-------------------------------------------------------------------------------

-- Plays a scene beat. Yields until finished (or skipped). Returns "done" | "skipped".
function Cutscene.play(scene, uiRoot: Instance)
	local stageDef = Stages.get(scene.stage)
	local stage = StageBuilder.build(scene.stage)
	Audio.music("music_story")
	Audio.ambience(stageDef.ambience)
	local folder = Instance.new("Folder")
	folder.Name = "VeilCutscene"
	folder.Parent = workspace

	local actors = {}
	local byId = {}
	for i, a in scene.actors or {} do
		local def = Fighters.get(a.id)
		local rig = Rig.build(def.look, { name = def.name, world = workspace })
		rig.model.Parent = a.hidden and nil or folder
		actors[i] = {
			id = a.id,
			def = def,
			rig = rig,
			x = a.x,
			y = 0,
			facing = a.facing,
			anim = a.anim or "stance",
			hidden = a.hidden == true,
			style = Poses.STYLE_OF[def.stance] or "unarmed",
			spring = AnimSpring.new(),
			gesture = nil,
			talking = false,
			lookAt = nil,
			phase = i * 1.37,
		}
		byId[a.id] = byId[a.id] or i
	end

	-- letterbox + caption + skip hint
	local ui = Theme.frame(uiRoot, { Name = "Cutscene", Size = UDim2.fromScale(1, 1), ZIndex = 35 })
	local barT = Theme.frame(ui, { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 50 })
	local barB = Theme.frame(ui, {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 50,
	})
	Theme.tween(barT, 0.6, { Size = UDim2.new(1, 0, 0, 96) })
	Theme.tween(barB, 0.6, { Size = UDim2.new(1, 0, 0, 96) })
	local caption = Theme.label(ui, "", {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0.5, 0, 1, -150),
		AnchorPoint = Vector2.new(0.5, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 40,
		TextColor3 = C.ivory,
		TextTransparency = 1,
		ZIndex = 51,
	})
	Theme.textStroke(caption, 2, 0.2)
	local skip = Theme.label(ui, "", {
		Size = UDim2.fromOffset(400, 30),
		Position = UDim2.new(1, -30, 1, -30),
		AnchorPoint = Vector2.new(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = F.label,
		TextSize = 16,
		TextColor3 = C.textDim,
		ZIndex = 51,
	})
	skip.Text = "[" .. Input.glyph("confirm") .. "] NEXT    [" .. Input.glyph("back") .. "] SKIP SCENE"
	local fade = Theme.frame(ui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 60 })
	Theme.tween(fade, 0.8, { BackgroundTransparency = 1 })
	local fx = CineFX.new(ui, 40)

	-- clocks: `shotClock` drives lines and events (stops during freeze frames),
	-- `animClock` drives acting (stops when frozen, slows in slow motion),
	-- `camClock` drives camera moves.
	local paused = 0
	local timeScale = 1
	local slowUntil = 0
	local shotClock = 0
	local animClock = 0
	local camClock = 0
	local realClock = 0
	local current = { cam = "wide" }
	local camT0 = 0
	local whipT = -1
	local whipDir = 1

	local function cutTo(spec, whip: boolean?)
		current = spec
		camT0 = camClock
		if whip then
			whipT = realClock
			whipDir = -whipDir
			fx:whip()
		end
	end

	FightCamera.enable()
	FightCamera.cinematic(function(_t)
		local cf, fov = shotCF(current, actors, camClock - camT0)
		-- handheld drift
		local n1 = math.sin(realClock * 1.3) * 0.6 + math.sin(realClock * 2.9) * 0.25
		local n2 = math.sin(realClock * 1.7 + 1.2) * 0.5 + math.sin(realClock * 3.7) * 0.2
		cf = cf * CFrame.Angles(math.rad(n1 * 0.35), math.rad(n2 * 0.35), 0)
		-- whip pan: fast yaw that settles into the new shot
		if whipT >= 0 then
			local k = (realClock - whipT) / 0.2
			if k < 1 then
				cf = cf * CFrame.Angles(0, math.rad(35 * whipDir * (1 - k) ^ 2), 0)
			end
		end
		return cf, fov
	end)

	local function lookYaw(a, target)
		local f = V(a.facing * math.cos(YAW), 0, math.sin(YAW))
		local d = V(target.x - a.x, 0, 0.0001)
		if d.Magnitude < 0.01 then
			return 0
		end
		d = d.Unit
		local yaw = math.deg(math.atan2(f.Z * d.X - f.X * d.Z, f.X * d.X + f.Z * d.Z))
		return math.clamp(yaw, -75, 75)
	end

	local function basePose(a, t: number)
		local style = a.style
		if a.act then
			local act = a.act
			local frames = math.max(12, act.dur * 60)
			local ft = (t - act.t0) * 60
			if ft >= frames then
				a.act = nil
			else
				local startup = math.floor(frames * 0.35)
				local active = math.max(2, math.floor(frames * 0.15))
				return Poses.attack(act.anim, style, ft, startup, active, frames - startup - active), 1
			end
		end
		if a.walk then
			local w = a.walk
			local k = math.clamp((t - w.t0) / w.dur, 0, 1)
			a.x = w.from + (w.to - w.from) * k
			if k >= 1 then
				a.walk = nil
			else
				local dir = (w.to > w.from) and 1 or -1
				return Poses.walk(style, (t - w.t0) * 13.2, dir * a.facing), 0
			end
		end
		local anim = a.anim
		if anim == "kneel" then
			return Poses.States.kneel(), 0
		elseif anim == "dazed" then
			local p = table.clone(Poses.States.dazed())
			local r = p.root
			p.root = { r[1], r[2], r[3], math.sin(t * 1.7) * 5, math.sin(t * 1.1) * 6, math.sin(t * 2.3) * 5 }
			return p, 0
		elseif anim == "win" then
			return Poses.victoryFor(a.id, style, t), 0
		end
		local idle = Poses.idleFor(style, a.def.personality, t + a.phase)
		if GESTURES[anim] then
			return applyGesture(idle, GESTURES[anim], 1), 0
		end
		return idle, 0
	end

	local renderConn = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		realClock += dt
		if realClock > slowUntil then
			timeScale = 1
		end
		local frozen = paused > 0
		local adt = frozen and 0 or dt * timeScale
		animClock += adt
		camClock += frozen and dt * 0.04 or dt * timeScale
		local t = animClock
		for i, a in actors do
			if a.hidden then
				continue
			end
			local pose, snap = basePose(a, t)
			if a.gesture and not a.act and not a.walk then
				local g = GESTURES[a.gesture]
				if g then
					pose = applyGesture(pose, g, 1)
					if a.gesture == "wave" then
						addTo(pose, "RUA", 0, 0, math.sin(t * 9) * 22)
					elseif a.gesture == "laugh" then
						addTo(pose, "UT", math.abs(math.sin(t * 11)) * 5, 0, 0)
						addTo(pose, "H", math.abs(math.sin(t * 11)) * 6, 0, 0)
					end
				end
			else
				pose = table.clone(pose)
			end
			-- talking: nods, beats, a little torso sway
			if a.talking then
				addTo(pose, "H", math.sin(t * 8.5) * 2.2 + math.max(0, math.sin(t * 3.1)) * 4, math.sin(t * 1.9) * 3, 0)
				addTo(pose, "UT", 0, math.sin(t * 2.2) * 3, math.sin(t * 1.6) * 1.5)
				if a.gesture == "talk" or a.gesture == "point" then
					addTo(pose, "RLA", math.sin(t * 5.2) * 12, 0, 0)
				end
			end
			-- look at whoever is talking
			local target = a.lookAt and actors[a.lookAt]
			if target and target ~= a and not target.hidden then
				local yaw = lookYaw(a, target)
				addTo(pose, "H", 0, yaw * 0.65, 0)
				addTo(pose, "UT", 0, yaw * 0.25, 0)
			end
			-- hop
			local y = 0
			if a.jumpT then
				local k = (t - a.jumpT) / 0.5
				if k >= 0 and k < 1 then
					y = 4 * k * (1 - k) * 2.2
				else
					a.jumpT = nil
				end
			end
			a.y = y
			local final = a.spring:step(pose, adt, snap)
			Rig.apply(a.rig, rootCF(a.x, a.facing, y), final, { time = t })
			Rig.setExpression(a.rig, Cutscene.expressionFor(a))
			local _ = i
		end
		FightCamera.update(dt, -2, 0, 2, 0)
		StageBuilder.update(realClock, 0, dt)
	end)

	local skipShot, skipScene = false, false
	local navConn = Input.nav.Event:Connect(function(action)
		if action == "confirm" then
			skipShot = true
		elseif action == "back" or action == "start" then
			skipScene = true
		end
	end)
	local tapConn = nil
	if Input.mode == "touch" then
		tapConn = Input.anyPressed.Event:Connect(function()
			skipShot = true
		end)
	end

	-- pause-aware wait on the shot clock
	local function wait(sec: number)
		local target = shotClock + sec
		while shotClock < target do
			if skipShot or skipScene then
				return false
			end
			local dt = RunService.Heartbeat:Wait()
			if paused == 0 then
				shotClock += dt
			end
		end
		return true
	end

	local function visibleRigs()
		local list = {}
		for _, a in actors do
			if not a.hidden then
				table.insert(list, a.rig)
			end
		end
		return list
	end

	local function freeze(a, name: string?, sub: string?, hold: number?)
		paused += 1
		FightCamera.punch(5)
		local nm = name or (a and (Story.speakerNames[a.id] or a.def.name)) or ""
		local sb = sub or (a and a.def.title) or ""
		local side = (a and a.x < 0) and 1 or 2
		fx:freezeFrame(nm, sb, a and Color3.fromHex(a.def.accent) or nil, side, hold or 1.7)
		paused = math.max(0, paused - 1)
	end

	-- Cosmetic events are dropped when a shot is skipped; state events always run.
	local COSMETIC = { freeze = true, impact = true, pop = true, crash = true, boom = true, slowmo = true, speedlines = true, whip = true, sfx = true, shake = true, vfx = true }

	local function runEvent(ev, flushing: boolean?)
		-- (the rift is kept even when skipping: later shots show it)
		if flushing and COSMETIC[ev.type] and not (ev.type == "vfx" and ev.kind == "rift") then
			return
		end
		local a = ev.actor and actors[ev.actor]
		local typ = ev.type
		if typ == "show" and a then
			a.hidden = false
			a.rig.model.Parent = folder
		elseif typ == "hide" and a then
			a.hidden = true
			a.rig.model.Parent = nil
		elseif typ == "anim" and a then
			a.anim = ev.anim
		elseif typ == "gesture" and a then
			a.gesture = ev.gesture
		elseif typ == "face" and a then
			a.facing = ev.facing
		elseif typ == "walk" and a then
			if flushing then
				a.x = ev.to
			else
				a.walk = { from = a.x, to = ev.to, t0 = animClock, dur = ev.time or 1.2 }
			end
		elseif typ == "act" and a then
			a.act = { anim = ev.anim, t0 = animClock, dur = ev.time or 0.8 }
		elseif typ == "jump" and a then
			a.jumpT = animClock
			Audio.play("jump", { volume = 0.5 })
		elseif typ == "sfx" then
			Audio.play(ev.key, { volume = ev.volume or 0.9 })
		elseif typ == "shake" then
			FightCamera.shake(ev.amount or 0.6)
		elseif typ == "freeze" then
			task.spawn(freeze, a, ev.name, ev.sub, ev.hold)
		elseif typ == "impact" then
			local rigs = visibleRigs()
			task.spawn(function()
				paused += 1
				fx:impactFrames(rigs, ev.count or 3)
				paused = math.max(0, paused - 1)
				FightCamera.shake(ev.shake or 0.9)
			end)
		elseif typ == "pop" then
			local pos = nil
			if ev.x then
				pos = Vector2.new(ev.x, ev.y or 0.35)
			end
			fx:pop(ev.text, pos, ev.color and Color3.fromHex(ev.color) or nil, ev.size)
		elseif typ == "crash" then
			FightCamera.punch(ev.amount or 6)
			Audio.play("boom", { volume = 0.9 })
			FightCamera.shake(0.4)
		elseif typ == "boom" then
			Audio.play("boom", { volume = ev.volume or 1 })
			FightCamera.shake(ev.amount or 0.7)
		elseif typ == "slowmo" then
			timeScale = ev.scale or 0.3
			slowUntil = realClock + (ev.time or 1.2)
		elseif typ == "speedlines" then
			fx:speedLines(ev.time or 0.6, ev.color and Color3.fromHex(ev.color) or nil)
		elseif typ == "whip" then
			fx:whip()
		elseif typ == "cam" then
			cutTo({ cam = ev.cam, a = ev.a, b = ev.b }, ev.whip)
		elseif typ == "vfx" then
			local pos = a and V(a.x, 0, 0) or V(0, 0, 0)
			if ev.kind == "rift" then
				for k = 0, 8 do
					local p = Instance.new("Part")
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.Material = Enum.Material.Neon
					p.Color = k % 3 == 0 and Color3.fromHex("#FF3B4E") or Color3.fromHex("#63FF8A")
					p.Size = V(1.2, 8 - math.abs(k - 4), 0.5)
					p.CFrame = CFrame.new(-6 + k * 1.6, 30 + math.sin(k * 1.9) * 2.5, -50) * CFrame.Angles(0, 0, math.rad(k % 2 == 0 and 24 or -24))
					p.Parent = folder
				end
				if not flushing then
					VFX.burstShockwave(V(0, 30, -48), Color3.fromHex("#63FF8A"))
				end
			elseif ev.kind == "teleport" then
				VFX.teleport(pos, a and Color3.fromHex(a.def.accent) or Color3.new(1, 1, 1))
			elseif ev.kind == "roots" then
				VFX.groundEruption(pos, "nature", 4)
			elseif ev.kind == "bolt_impact" then
				VFX.hit(pos + V(0.8, 3.5, 0.4), "heavy", "ash", 1, false)
			elseif ev.kind == "smoke" then
				VFX.teleport(pos, Color3.fromHex("#8A8478"))
			elseif ev.kind == "souls" then
				VFX.elementBurst(pos + V(0, 3, 0), "soulfire", true)
				VFX.burstShockwave(pos + V(0, 3, 0), Color3.fromHex("#63FF8A"))
			elseif ev.kind == "slam" then
				VFX.burstShockwave(pos + V(0, 0.5, 0), a and Color3.fromHex(a.def.accent) or Color3.new(1, 1, 1))
				VFX.dust(pos, true)
			elseif ev.kind == "flash" then
				fx:flash(Color3.new(1, 1, 1), 1.2)
			end
		end
	end

	-- Coverage for one line of dialogue in a multi-line shot.
	local function coverageFor(shot, line, idx: number, prevSpeaker: number?)
		if line.cam then
			return { cam = line.cam, a = line.a or byId[line.speaker], b = line.b }, line.whip
		end
		if shot.auto == false or not shot.lines or #shot.lines < 2 then
			return nil
		end
		if shot.cam ~= "two" and shot.cam ~= "over" then
			return nil
		end
		if idx == 1 then
			return nil
		end
		local sp = byId[line.speaker]
		if not sp then
			return nil
		end
		local listener = prevSpeaker ~= sp and prevSpeaker or nil
		if not listener then
			local a, b = shot.a or 1, shot.b or 2
			listener = (a == sp) and b or a
		end
		if Cutscene.autoGesture(line.text, line.speaker) == "shout" then
			return { cam = "crash", a = sp }, false
		end
		if idx % 2 == 0 then
			return { cam = "over", a = listener, b = sp }, false
		end
		return { cam = "close", a = sp }, false
	end

	for _, shot in scene.shots or {} do
		if skipScene then
			break
		end
		skipShot = false
		cutTo({ cam = shot.cam, a = shot.a, b = shot.b }, shot.whip)
		local lineTotal = 0
		for _, line in shot.lines or {} do
			lineTotal += Story.lineDuration(line.text)
		end
		local duration = shot.duration or (lineTotal + 0.6)
		-- schedule events on the (pause-aware) shot clock
		local evs = table.clone(shot.events or {})
		table.sort(evs, function(x, y)
			return (x.t or 0) < (y.t or 0)
		end)
		local shotStart = shotClock
		local evIdx = 1
		local evConn = RunService.Heartbeat:Connect(function()
			local el = shotClock - shotStart
			while evs[evIdx] and (evs[evIdx].t or 0) <= el do
				runEvent(evs[evIdx])
				evIdx += 1
			end
		end)
		if shot.caption then
			caption.Text = shot.caption
			Theme.tween(caption, 0.6, { TextTransparency = 0 })
		end
		-- lines
		local lineStart = 0.25
		task.wait(0)
		if shot.lines and #shot.lines > 0 then
			wait(lineStart)
			local prevSpeaker = nil
			for idx, line in shot.lines do
				if skipShot or skipScene then
					break
				end
				local d = Story.lineDuration(line.text)
				local spk = Fighters.byId[line.speaker]
				local col = spk and Color3.fromHex(spk.accent) or C.goldBright
				local si = byId[line.speaker]
				-- coverage cut
				local cov, whip = coverageFor(shot, line, idx, prevSpeaker)
				if cov then
					cutTo(cov, whip)
				end
				-- acting: speaker talks + gestures, everyone else looks at them
				for ai, a in actors do
					a.talking = ai == si
					if si and ai ~= si then
						a.lookAt = si
					end
				end
				local sa = si and actors[si]
				if sa then
					sa.lookAt = prevSpeaker ~= si and prevSpeaker or sa.lookAt
					sa.gesture = line.gesture or Cutscene.autoGesture(line.text, line.speaker)
				end
				-- per-line editing beats
				if line.freeze and sa then
					task.spawn(freeze, sa, line.freezeName, line.freezeSub)
				end
				if line.crash then
					runEvent({ type = "crash" })
				end
				if line.impact then
					runEvent({ type = "impact" })
				end
				if line.pop then
					runEvent({ type = "pop", text = line.pop, x = line.popX, y = line.popY })
				end
				Subtitles.show(Story.speakerNames[line.speaker] or line.speaker, line.text, d - 0.15, col)
				local profile = spk and spk.voice or (line.speaker == "system" and "system" or "announcer")
				if not Voice.say(line.text, profile, { channel = "dialogue" }) and spk then
					Audio.voice(spk.voice, "attack")
				end
				local ok = wait(d)
				if sa then
					sa.talking = false
					if not line.holdGesture then
						sa.gesture = nil
					end
				end
				prevSpeaker = si or prevSpeaker
				if not ok then
					break
				end
			end
			if not skipShot and not skipScene then
				wait(math.max(0, duration - lineTotal - lineStart))
			end
		else
			wait(duration)
		end
		-- flush remaining events so visibility stays consistent when skipping
		while evs[evIdx] do
			runEvent(evs[evIdx], true)
			evIdx += 1
		end
		evConn:Disconnect()
		for _, a in actors do
			a.talking = false
		end
		if shot.caption then
			Theme.tween(caption, 0.4, { TextTransparency = 1 })
		end
		Subtitles.hide()
	end

	-- outro
	Theme.tween(fade, 0.5, { BackgroundTransparency = 0 })
	task.wait(0.55)
	navConn:Disconnect()
	if tapConn then
		tapConn:Disconnect()
	end
	renderConn:Disconnect()
	FightCamera.clearCinematic()
	fx:destroy()
	for _, a in actors do
		Rig.destroy(a.rig)
	end
	folder:Destroy()
	ui:Destroy()
	VFX.clear()
	local _ = stage
	return skipScene and "skipped" or "done"
end

return Cutscene
