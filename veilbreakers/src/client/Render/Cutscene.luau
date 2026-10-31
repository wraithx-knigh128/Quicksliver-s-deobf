--!nonstrict
-- In-engine story cinematics: letterboxed camera shots over the real stages with
-- posed actors, subtitles, location captions and scripted effects.

local RunService = game:GetService("RunService")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Fighters = require(Veil.Data.Fighters)
local Stages = require(Veil.Data.Stages)
local Story = require(Veil.Data.Story)

local Client = script.Parent.Parent
local Rig = require(script.Parent.Rig)
local Poses = require(script.Parent.Poses)
local StageBuilder = require(script.Parent.StageBuilder)
local FightCamera = require(script.Parent.FightCamera)
local VFX = require(script.Parent.VFX)
local Audio = require(Client.Core.Audio)
local Input = require(Client.Core.Input)
local Theme = require(Client.UI.Theme)
local Subtitles = require(Client.UI.Subtitles)

local C = Theme.Colors
local F = Theme.Fonts

local Cutscene = {}

local YAW = math.rad(25)

local function rootCF(x: number, facing: number)
	local pos = Vector3.new(x, 0, 0)
	return CFrame.lookAt(pos, pos + Vector3.new(facing * math.cos(YAW), 0, math.sin(YAW)))
end

local function poseFor(anim: string?, style: string, t: number)
	if anim == "dazed" then
		local p = table.clone(Poses.States.dazed())
		local r = p.root
		p.root = { r[1], r[2], r[3], math.sin(t * 1.7) * 5, math.sin(t * 1.1) * 6, math.sin(t * 2.3) * 5 }
		return p
	elseif anim == "kneel" then
		return Poses.States.kneel()
	elseif anim == "win" then
		return Poses.WIN[style] or Poses.WIN.unarmed
	end
	return Poses.idle(style, t)
end

-- Camera presets -> function(t) returning CFrame, fov
local function shotCamera(shot, actors)
	local function head(i)
		local a = actors[i]
		if not a then
			return Vector3.new(0, 4, 0)
		end
		return Vector3.new(a.x, 4.4 * a.rig.scale, 0)
	end
	local function visibleMid()
		local sum, n = Vector3.zero, 0
		for _, a in actors do
			if not a.hidden then
				sum += Vector3.new(a.x, 3.2, 0)
				n += 1
			end
		end
		return n > 0 and sum / n or Vector3.new(0, 3.2, 0)
	end
	local cam = shot.cam
	if cam == "sky" then
		return function(t)
			local pos = Vector3.new(-8 + t * 1.6, 7 + t * 0.4, 30)
			local look = Vector3.new(-2 + t * 1.2, 18, -60)
			return CFrame.lookAt(pos, look), 50
		end
	elseif cam == "wide" then
		return function(t)
			local mid = visibleMid()
			local pos = mid + Vector3.new(-3 + t * 0.6, 2.2, 21 - t * 0.5)
			return CFrame.lookAt(pos, mid), 40
		end
	elseif cam == "two" then
		return function(t)
			local a, b = head(shot.a or 1), head(shot.b or 2)
			local mid = (a + b) / 2 - Vector3.new(0, 0.6, 0)
			local sep = (a - b).Magnitude
			local pos = mid + Vector3.new(t * 0.3, 0.6, 7 + sep * 0.9 - t * 0.2)
			return CFrame.lookAt(pos, mid), 38
		end
	elseif cam == "close" then
		return function(t)
			local a = actors[shot.a or 1]
			local h = head(shot.a or 1) - Vector3.new(0, 0.2, 0)
			local facing = a and a.facing or 1
			local pos = h + Vector3.new(facing * 3.2, 0.2, 5.4 - t * 0.18)
			return CFrame.lookAt(pos, h), 30
		end
	elseif cam == "over" then
		return function(t)
			local a, b = head(shot.a or 1), head(shot.b or 2)
			local dir = (b - a).Unit
			local pos = a - dir * 3.2 + Vector3.new(0, 0.8, 2.8 + t * 0.1)
			return CFrame.lookAt(pos, b - Vector3.new(0, 0.4, 0)), 36
		end
	elseif cam == "low" then
		return function(t)
			local a = actors[shot.a or 1]
			local h = head(shot.a or 1)
			local facing = a and a.facing or 1
			local pos = Vector3.new(h.X + facing * 4.5, 0.8 + t * 0.1, 6.5)
			return CFrame.lookAt(pos, h + Vector3.new(0, 0.6, 0)), 42
		end
	end
	return function(_t)
		local mid = visibleMid()
		return CFrame.lookAt(mid + Vector3.new(0, 3, 18), mid), 40
	end
end

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
	for i, a in scene.actors or {} do
		local def = Fighters.get(a.id)
		local rig = Rig.build(def.look, { name = def.name, world = workspace })
		rig.model.Parent = a.hidden and nil or folder
		actors[i] = {
			id = a.id,
			def = def,
			rig = rig,
			x = a.x,
			facing = a.facing,
			anim = a.anim or "stance",
			hidden = a.hidden == true,
			style = Poses.STYLE_OF[def.stance] or "unarmed",
		}
	end

	-- letterbox + caption + skip hint
	local ui = Theme.frame(uiRoot, { Name = "Cutscene", Size = UDim2.fromScale(1, 1), ZIndex = 35 })
	local barT = Theme.frame(ui, { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 36 })
	local barB = Theme.frame(ui, {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 36,
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
		ZIndex = 37,
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
		ZIndex = 37,
	})
	skip.Text = "[" .. Input.glyph("confirm") .. "] NEXT    [" .. Input.glyph("back") .. "] SKIP SCENE"
	local fade = Theme.frame(ui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 45 })
	Theme.tween(fade, 0.8, { BackgroundTransparency = 1 })

	FightCamera.enable()
	local t0 = os.clock()
	local renderConn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		for _, a in actors do
			if not a.hidden then
				Rig.apply(a.rig, rootCF(a.x, a.facing), poseFor(a.anim, a.style, t + a.x), { time = t })
			end
		end
		FightCamera.update(dt, -2, 0, 2, 0)
		StageBuilder.update(t, 0)
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

	local function wait(sec: number)
		local start = os.clock()
		while os.clock() - start < sec do
			if skipShot or skipScene then
				return false
			end
			RunService.Heartbeat:Wait()
		end
		return true
	end

	local function runEvent(ev)
		local a = ev.actor and actors[ev.actor]
		if ev.type == "show" and a then
			a.hidden = false
			a.rig.model.Parent = folder
		elseif ev.type == "hide" and a then
			a.hidden = true
			a.rig.model.Parent = nil
		elseif ev.type == "anim" and a then
			a.anim = ev.anim
		elseif ev.type == "sfx" then
			Audio.play(ev.key, { volume = 0.9 })
		elseif ev.type == "shake" then
			FightCamera.shake(ev.amount or 0.6)
		elseif ev.type == "vfx" then
			local pos = a and Vector3.new(a.x, 0, 0) or Vector3.new(0, 0, 0)
			if ev.kind == "rift" then
				for k = 0, 8 do
					local p = Instance.new("Part")
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.Material = Enum.Material.Neon
					p.Color = k % 3 == 0 and Color3.fromHex("#FF3B4E") or Color3.fromHex("#63FF8A")
					p.Size = Vector3.new(1.2, 8 - math.abs(k - 4), 0.5)
					p.CFrame = CFrame.new(-6 + k * 1.6, 30 + math.sin(k * 1.9) * 2.5, -50) * CFrame.Angles(0, 0, math.rad(k % 2 == 0 and 24 or -24))
					p.Parent = folder
				end
				VFX.burstShockwave(Vector3.new(0, 30, -48), Color3.fromHex("#63FF8A"))
			elseif ev.kind == "teleport" then
				VFX.teleport(pos, a and Color3.fromHex(a.def.accent) or Color3.new(1, 1, 1))
			elseif ev.kind == "roots" then
				VFX.groundEruption(pos, "nature", 4)
			elseif ev.kind == "bolt_impact" then
				VFX.hit(pos + Vector3.new(0.8, 3.5, 0.4), "heavy", "ash", 1, false)
			elseif ev.kind == "smoke" then
				VFX.teleport(pos, Color3.fromHex("#8A8478"))
			elseif ev.kind == "souls" then
				VFX.elementBurst(pos + Vector3.new(0, 3, 0), "soulfire", true)
				VFX.burstShockwave(pos + Vector3.new(0, 3, 0), Color3.fromHex("#63FF8A"))
			elseif ev.kind == "flash" then
				local fl = Theme.frame(ui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 44 })
				Theme.tween(fl, 1.2, { BackgroundTransparency = 1 })
			end
		end
	end

	for _, shot in scene.shots or {} do
		if skipScene then
			break
		end
		skipShot = false
		FightCamera.cinematic(shotCamera(shot, actors))
		local lineTotal = 0
		for _, line in shot.lines or {} do
			lineTotal += Story.lineDuration(line.text)
		end
		local duration = shot.duration or (lineTotal + 0.6)
		-- schedule events
		local evs = table.clone(shot.events or {})
		table.sort(evs, function(x, y)
			return (x.t or 0) < (y.t or 0)
		end)
		local shotStart = os.clock()
		local evIdx = 1
		local evConn = RunService.Heartbeat:Connect(function()
			local el = os.clock() - shotStart
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
			for _, line in shot.lines do
				if skipShot or skipScene then
					break
				end
				local d = Story.lineDuration(line.text)
				local spk = Fighters.byId[line.speaker]
				local col = spk and Color3.fromHex(spk.accent) or C.goldBright
				Subtitles.show(Story.speakerNames[line.speaker] or line.speaker, line.text, d - 0.15, col)
				if spk then
					Audio.voice(spk.voice, "attack")
				end
				if not wait(d) then
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
			runEvent(evs[evIdx])
			evIdx += 1
		end
		evConn:Disconnect()
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
