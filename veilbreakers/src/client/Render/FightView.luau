--!nonstrict
-- Runs a match: fixed-step engine simulation, CPU brains, rendering of fighters,
-- Echoes and projectiles, combat events -> VFX / audio / camera / HUD, super and
-- finisher cinematics, intros and the end-of-match handoff.

local RunService = game:GetService("RunService")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Config = require(Veil.Config)
local Fighters = require(Veil.Data.Fighters)
local Echoes = require(Veil.Data.Echoes)
local Stages = require(Veil.Data.Stages)
local MoveKit = require(Veil.Data.MoveKit)
local Engine = require(Veil.Combat.Engine)
local AI = require(Veil.Combat.AI)

local Client = script.Parent.Parent
local Rig = require(script.Parent.Rig)
local Poses = require(script.Parent.Poses)
local AnimSpring = require(script.Parent.AnimSpring)
local StageBuilder = require(script.Parent.StageBuilder)
local FightCamera = require(script.Parent.FightCamera)
local VFX = require(script.Parent.VFX)
local Audio = require(Client.Core.Audio)
local Input = require(Client.Core.Input)
local HUD = require(Client.UI.HUD)
local Subtitles = require(Client.UI.Subtitles)
local MobileControls = require(Client.UI.MobileControls)
local Theme = require(Client.UI.Theme)

local FightView = {}
FightView.__index = FightView

local DT = 1 / 60
local YAW = math.rad(25)

local ECHO_STYLE = { staff = "pole", bow = "ranged", lantern = "unarmed", none = "unarmed" }

local STRENGTH_SFX = { light = "hit_light", medium = "hit_medium", heavy = "hit_heavy", special = "hit_heavy", super = "super_impact" }
local STRENGTH_SHAKE = { light = 0.25, medium = 0.45, heavy = 0.8, special = 0.7, super = 1.4 }
-- how hard a hit "kicks" the victim's spine and head (secondary-motion impulses)
local STRENGTH_KICK = { light = 0.55, medium = 1.0, heavy = 1.6, special = 1.4, super = 2.0 }

local function v3(x: number, y: number, z: number?): Vector3
	return Vector3.new(x, y, z or 0)
end

local function rootCFrame(x: number, y: number, facing: number, extraYaw: number?): CFrame
	local pos = v3(x, y, 0)
	local yaw = YAW + (extraYaw or 0)
	local fwd = Vector3.new(facing * math.cos(yaw), 0, math.sin(yaw))
	return CFrame.lookAt(pos, pos + fwd)
end

function FightView.new(opts)
	local self = setmetatable({}, FightView)
	self.opts = opts
	self.settings = opts.settings or {}
	self.time = 0
	self.acc = 0
	self.paused = false
	self.ended = false
	self.connections = {}

	local p1Def = Fighters.get(opts.p1.fighter)
	local p2Def = Fighters.get(opts.p2.fighter)
	local p1Echo = Echoes.get(opts.p1.echo)
	local p2Echo = Echoes.get(opts.p2.echo)
	self.defs = { p1Def, p2Def }
	self.echoDefs = { p1Echo, p2Echo }
	self.styles = { Poses.STYLE_OF[p1Def.stance] or "unarmed", Poses.STYLE_OF[p2Def.stance] or "unarmed" }

	-- world
	self.stage = StageBuilder.build(opts.stage)
	local stageDef = Stages.get(opts.stage)
	self.folder = Instance.new("Folder")
	self.folder.Name = "VeilFight"
	self.folder.Parent = workspace

	-- engine
	self.match = Engine.newMatch({
		p1 = { fighter = opts.p1.fighter, echo = opts.p1.echo, cpu = opts.p1.cpu },
		p2 = { fighter = opts.p2.fighter, echo = opts.p2.echo, cpu = opts.p2.cpu, boss = opts.boss },
		stage = opts.stage,
		training = opts.training,
		dummy = opts.dummy,
		seed = opts.seed or math.floor(os.clock() * 1000) % 1000000,
		roundsToWin = opts.roundsToWin,
		shortIntro = opts.shortIntro,
		noFinisher = opts.noFinisher,
	})
	self.ai = {}
	for i, spec in { opts.p1, opts.p2 } do
		if spec.cpu then
			self.ai[i] = AI.new(self.match, i, spec.difficulty or 2, (opts.seed or 7) + i * 101)
		end
	end
	if opts.training and not opts.p2.cpu then
		self.match.trainingDummy = opts.dummy or "stand"
	end

	-- who is who: P1 / P2 / CPU / DUMMY (HUD chips and floating markers)
	local function tagFor(spec, side: number)
		if opts.training and side == 2 then
			return "DUMMY"
		end
		return spec.cpu and "CPU" or ("P" .. side)
	end
	self.tags = { tagFor(opts.p1, 1), tagFor(opts.p2, 2) }

	-- rigs
	self.rigs = {}
	self.anim = {}
	self.springs = {}
	self.highlights = {}
	for i, def in self.defs do
		local rig = Rig.build(def.look, { name = def.name, world = workspace })
		rig.model.Parent = self.folder
		self.rigs[i] = rig
		self.anim[i] = { key = nil, start = 0, from = nil, last = Poses.stance(self.styles[i]), walkPhase = 0, idleOffset = i * 1.37 }
		self.springs[i] = AnimSpring.new()
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.new(1, 1, 1)
		hl.FillTransparency = 1
		hl.OutlineTransparency = 1
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = rig.model
		self.highlights[i] = hl
	end
	self.worldTags = {}
	for i, rig in self.rigs do
		local head = rig.parts.Head
		local g = Instance.new("BillboardGui")
		g.Name = "PlayerTag"
		g.Size = UDim2.fromOffset(90, 44)
		g.StudsOffset = Vector3.new(0, 2.6 * rig.scale, 0)
		g.AlwaysOnTop = true
		g.LightInfluence = 0
		g.Enabled = false
		g.Parent = head
		local isCpu = self.tags[i] ~= "P1" and self.tags[i] ~= "P2"
		local accent = isCpu and Theme.Colors.text or Color3.fromHex(self.defs[i].accent)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 26)
		l.Text = self.tags[i]
		l.FontFace = Theme.Fonts.labelBold
		l.TextSize = 22
		l.TextColor3 = accent
		l.TextStrokeTransparency = 0.2
		l.Parent = g
		local arrow = Instance.new("TextLabel")
		arrow.BackgroundTransparency = 1
		arrow.Position = UDim2.fromOffset(0, 22)
		arrow.Size = UDim2.new(1, 0, 0, 20)
		arrow.Text = "\u{25BC}"
		arrow.FontFace = Theme.Fonts.labelBold
		arrow.TextSize = 16
		arrow.TextColor3 = accent
		arrow.TextStrokeTransparency = 0.3
		arrow.Parent = g
		self.worldTags[i] = { gui = g, label = l, arrow = arrow, token = 0 }
	end
	self.echoRigs = {}
	self.projVisuals = {}
	self.prevPos = {}
	for i, f in self.match.fighters do
		self.prevPos[i] = { x = f.x, y = f.y }
	end

	-- UI
	self.hud = HUD.new(opts.root, p1Def, p1Echo, p2Def, p2Echo, { training = opts.training, tags = self.tags })
	if (Input.mode == "touch" or opts.forceTouch) and not opts.noTouch then
		self.touch = MobileControls.new(self.hud.root, {
			onPause = function()
				if opts.onPause then
					opts.onPause()
				end
			end,
		})
	end
	if self.touch and opts.training then
		-- touch players cycle the practice dummy with an on-screen button
		local b = Instance.new("TextButton")
		b.Name = "DummyButton"
		b.Text = "DUMMY"
		b.FontFace = Theme.Fonts.labelBold
		b.TextSize = 18
		b.TextColor3 = Theme.Colors.ivory
		b.AutoButtonColor = false
		b.BackgroundColor3 = Color3.fromHex("#0C0D10")
		b.BackgroundTransparency = 0.3
		b.Size = UDim2.fromOffset(120, 50)
		b.Position = UDim2.new(1, -36, 0, 350)
		b.AnchorPoint = Vector2.new(1, 0)
		b.ZIndex = 30
		b.Parent = self.hud.root
		Theme.corner(b, 8)
		Theme.stroke(b, Theme.Colors.goldDim, 1.5)
		table.insert(self.connections, b.Activated:Connect(function()
			self:cycleDummy()
		end))
	end
	self.hud:setVisible(true)

	-- camera & audio
	FightCamera.enable()
	FightCamera.setShakeScale(self.settings.shake == false and 0 or 1)
	FightCamera.snap(self.match.fighters[1].x, self.match.fighters[2].x)
	Audio.music(stageDef.music)
	Audio.ambience(stageDef.ambience)

	Input.fightEnabled = true
	table.insert(self.connections, RunService.RenderStepped:Connect(function(dt)
		self:frame(math.min(dt, 0.1))
	end))
	table.insert(self.connections, Input.nav.Event:Connect(function(action)
		if action == "start" and not self.ended and opts.onPause then
			opts.onPause()
		elseif action == "alt" and self.match.training then
			self:cycleDummy()
		elseif action == "confirm" or action == "back" then
			if self.match.phase == "intro" then
				Engine.skipIntro(self.match)
			end
		end
	end))
	if self.match.phase == "intro" then
		self:introCamera(1)
		self.hud:cinema(true, 0.01)
	end
	return self
end

-------------------------------------------------------------------------------
-- Simulation
-------------------------------------------------------------------------------

function FightView:setPaused(p: boolean)
	self.paused = p
	if self.touch then
		self.touch:setVisible(not p)
	end
end

function FightView:cycleDummy()
	local order = { "stand", "block", "cpu" }
	local cur = self.match.trainingDummy or "stand"
	local idx = table.find(order, cur) or 1
	local nextMode = order[idx % #order + 1]
	self.match.trainingDummy = nextMode
	local f2 = self.match.fighters[2]
	if nextMode == "cpu" then
		f2.isCPU = true
		self.ai[2] = AI.new(self.match, 2, 2, 77)
	else
		f2.isCPU = false
		self.ai[2] = nil
	end
	self.hud:announce("DUMMY: " .. string.upper(nextMode), nil, { size = 54, hold = 0.8, band = false })
end

function FightView:inputFor(i: number)
	local brain = self.ai[i]
	if brain then
		return brain:getInput()
	end
	if i == 1 then
		return Input.fightState()
	end
	return Engine.NeutralInput
end

function FightView:frame(dt: number)
	self.time += dt
	local m = self.match
	if not self.paused then
		local scale = (m.slowmo and m.slowmo > 0) and 0.35 or 1
		self.acc += dt * scale
		local steps = 0
		while self.acc >= DT and steps < 4 do
			self.acc -= DT
			steps += 1
			for i, f in m.fighters do
				self.prevPos[i].x = f.x
				self.prevPos[i].y = f.y
			end
			local i1 = self:inputFor(1)
			local i2 = self:inputFor(2)
			Engine.step(m, i1, i2)
			for _, ev in Engine.drainEvents(m) do
				self:onEvent(ev)
			end
		end
		if steps >= 4 then
			self.acc = 0
		end
	end
	self:render(dt)
end

-------------------------------------------------------------------------------
-- Rendering
-------------------------------------------------------------------------------

local function hitPose(react: string)
	if react == "high" then
		return Poses.States.hit_high()
	elseif react == "low" then
		return Poses.States.hit_low()
	end
	return Poses.States.hit_mid()
end

function FightView:poseFor(i: number, f, t: number)
	local style = self.styles[i]
	local st = f.state
	local m = self.match
	local key, pose
	local extraYaw = 0
	if st == "attack" and f.move then
		local mv = f.move
		key = "atk:" .. mv.id .. ":" .. tostring(m.frame - f.moveT)
		pose = Poses.attack(mv.anim, style, f.moveT, mv.startup, mv.active, mv.recovery)
	elseif st == "stand" or st == "walk" then
		local walking = f.walk ~= 0 and (m.phase == "fight" or m.phase == "finish_prompt")
		local a = self.anim[i]
		if walking then
			key = "walk"
			local before = a.walkPhase
			-- phase advances with real time so the stride is frame-rate independent
			a.walkPhase += (f.walk > 0 and 1 or -1) * 13.2 * f.def.walkMult * (self.renderDt or DT)
			local stepA, stepB = math.floor(before / math.pi), math.floor(a.walkPhase / math.pi)
			if stepA ~= stepB then
				self:footstep(i, f)
			end
			pose = Poses.walk(style, a.walkPhase, f.walk)
		else
			key = "idle"
			pose = Poses.idleFor(style, f.def.personality, t + a.idleOffset)
		end
	elseif st == "crouch" then
		key = "crouch"
		pose = Poses.States.crouch(style)
	elseif st == "block" or st == "blockstun" then
		key = f.crouch and "cblock" or "block"
		pose = f.crouch and Poses.States.crouch_block(style) or Poses.States.block(style)
		if st == "blockstun" then
			pose = table.clone(pose)
			local r = pose.root or { 0, 0, 0 }
			pose.root = { r[1], r[2], (r[3] or 0) + 0.25 }
		end
	elseif st == "jumpsquat" or st == "land" then
		key = "land"
		pose = Poses.States.land(style)
	elseif st == "air" then
		key = f.vy > 0 and "jump" or "fall"
		pose = f.vy > 0 and Poses.States.jump(style) or Poses.States.fall(style)
		if f.jumpDir ~= 0 and f.vy > -0.2 then
			pose = table.clone(pose)
			pose.root = { 0, 0.1, 0, -f.jumpDir * math.clamp(f.t * 12, 0, 360) * (f.t < 30 and 1 or 0), 0, 0 }
		end
	elseif st == "dash" then
		key = "dash"
		pose = Poses.States.dash(style)
	elseif st == "backdash" then
		key = "backdash"
		pose = Poses.States.backdash(style)
	elseif st == "hitstun" then
		key = "hit:" .. tostring(f.hitReact) .. tostring(f.lastHitFrame or 0)
		local base = hitPose(f.hitReact)
		local k = math.clamp(f.stun / 12, 0, 1)
		pose = Poses.lerp(Poses.stance(style), base, k)
	elseif st == "juggle" then
		key = "juggle"
		pose = table.clone(Poses.States.juggle())
		local spin = math.clamp(-f.vy * 90, -40, 60)
		pose.root = { 0, 0, 0, 52 + spin, 0, 0 }
	elseif st == "knockdown" or st == "dead_down" then
		key = "lie"
		pose = Poses.States.lie()
	elseif st == "getup" then
		key = "getup"
		local k = math.clamp(f.t / Config.GetupFrames, 0, 1)
		if k < 0.5 then
			pose = Poses.lerp(Poses.States.lie(), Poses.States.getup(style), k * 2)
		else
			pose = Poses.lerp(Poses.States.getup(style), Poses.stance(style), (k - 0.5) * 2)
		end
	elseif st == "thrown" then
		key = "thrown"
		pose = Poses.States.thrown()
	elseif st == "throwing" then
		key = f.throwT < 26 and "throwing" or "slam"
		pose = f.throwT < 26 and Poses.States.throwing() or Poses.States.throwing_slam()
	elseif st == "breaker" then
		key = "breaker"
		pose = Poses.States.breaker()
	elseif st == "super" then
		pose, key = self:superPose(i, f, style)
	elseif st == "finisher" then
		pose, key = self:finisherPose(i, f, style)
	elseif st == "win" then
		key = "win"
		pose = Poses.victoryFor(f.def.id, style, t)
	elseif st == "dazed" then
		key = "dazed"
		pose = table.clone(Poses.States.dazed())
		local r = pose.root
		pose.root = { r[1], r[2], r[3], math.sin(t * 1.7) * 6, math.sin(t * 1.1) * 8, math.sin(t * 2.3) * 7 }
	elseif st == "intro" then
		key = "intro"
		local introT = m.phaseT / 60
		local mine = (i == 1 and introT < 2.5) or (i == 2 and introT >= 2.5)
		if mine and m.round == 1 then
			-- signature pose on your name card, then settle into your fighting stance
			local hump = math.clamp(math.sin(math.min(introT % 2.5, 2.2) / 2.2 * math.pi) * 1.4, 0, 1)
			pose = Poses.lerp(Poses.idleFor(style, f.def.personality, t), Poses.victoryFor(f.def.id, style, t), Poses.ease(hump))
		else
			pose = Poses.idleFor(style, f.def.personality, t + self.anim[i].idleOffset)
		end
	elseif st == "banished" then
		key = "banished"
		pose = Poses.States.dazed()
	else
		key = st
		pose = Poses.stance(style)
	end
	return pose, key, extraYaw
end

-- Super cinematic choreography (150 frames)
function FightView:superPose(i: number, _f, style: string)
	local c = self.match.cinematic
	if not c then
		return Poses.stance(style), "super"
	end
	local t = c.t
	if c.attacker == i then
		local seq = Poses.SuperSequence[style] or Poses.SuperSequence.unarmed
		if t < 18 then
			return Poses.lerp(Poses.stance(style), Poses.States.breaker(), t / 18), "super:charge"
		end
		local idx = math.min(#seq, math.floor((t - 18) / 20) + 1)
		local local_t = (t - 18) - (idx - 1) * 20
		local name = seq[idx]
		if t >= 118 then
			local def = Poses.Attacks[seq[#seq]]
			return def and def.hit or Poses.stance(style), "super:final"
		end
		return Poses.attack(name, style, local_t, 8, 4, 8), "super:" .. idx
	else
		if t < 118 then
			local cyc = math.floor(t / 10) % 2
			return cyc == 0 and Poses.States.hit_high() or Poses.States.hit_mid(), "superhit:" .. cyc
		end
		return Poses.States.juggle(), "superhit:final"
	end
end

function FightView:finisherPose(_i: number, f, style: string)
	local fin = self.match.finisher
	local t = fin and fin.t or 0
	if t < 50 then
		return Poses.lerp(Poses.stance(style), Poses.Attacks.cast_up.hit, t / 50), "fin:charge"
	elseif t < 190 then
		local seq = Poses.SuperSequence[style] or Poses.SuperSequence.unarmed
		local idx = math.min(#seq, math.floor((t - 50) / 28) + 1)
		local lt = (t - 50) - (idx - 1) * 28
		return Poses.attack(seq[idx], style, lt, 10, 6, 12), "fin:" .. idx
	elseif t < 230 then
		local def = Poses.Attacks[(Poses.SuperSequence[style] or Poses.SuperSequence.unarmed)[5]]
		return def.hit, "fin:final"
	end
	return Poses.victoryFor(f.def.id, style, self.time), "fin:win"
end

function FightView:render(dt: number)
	local m = self.match
	local alpha = math.clamp(self.acc / DT, 0, 1)
	local t = self.time
	self.renderDt = self.paused and 0 or dt * ((m.slowmo and m.slowmo > 0) and 0.35 or 1)
	for i, f in m.fighters do
		local rig = self.rigs[i]
		if rig.shattered then
			continue
		end
		local a = self.anim[i]
		local pose, key, extraYaw = self:poseFor(i, f, t)
		if key ~= a.key then
			a.from = a.last
			a.start = t
			a.key = key
			a.blend = (string.sub(key, 1, 4) == "atk:") and 0.05 or 0.1
		end
		local final = pose
		if a.from then
			local k = (t - a.start) / a.blend
			if k < 1 then
				final = Poses.lerp(a.from, pose, Poses.ease(math.clamp(k, 0, 1)))
			else
				a.from = nil
			end
		end
		a.last = final
		-- secondary motion: springs chase the authored pose for weight, overshoot and
		-- hit impulses; arms stiffen around active frames so strikes stay crisp.
		local snap = 0
		if f.state == "attack" and f.move then
			local mv = f.move
			if f.moveT >= mv.startup - 3 and f.moveT <= mv.startup + mv.active + 2 then
				snap = 1
			end
		elseif f.state == "super" or f.state == "finisher" or f.state == "throwing" then
			snap = 1
		end
		final = self.springs[i]:step(final, self.renderDt, snap)
		local pp = self.prevPos[i]
		local x = pp.x + (f.x - pp.x) * alpha
		local y = pp.y + (f.y - pp.y) * alpha
		if m.hitstop > 0 and (f.state == "hitstun" or f.state == "juggle" or f.state == "blockstun") then
			x += math.sin(t * 90) * 0.07
		end
		local cf = rootCFrame(x, y, f.facing, extraYaw)
		Rig.apply(rig, cf, final, { time = t, vx = (f.x - pp.x) * f.facing * 3, vy = f.vy or 0 })
		-- weapon trails during active frames
		local trailOn = false
		if f.state == "attack" and f.move then
			local mv = f.move
			trailOn = (mv.trail or mv.kind == "special" or mv.kind == "super") and f.moveT >= mv.startup - 3 and f.moveT <= mv.startup + mv.active + 3
		elseif f.state == "super" or f.state == "finisher" then
			trailOn = true
		end
		if rig.trailOn ~= trailOn then
			rig.trailOn = trailOn
			Rig.setTrails(rig, trailOn)
		end
		-- invulnerability shimmer during teleports
		local fade = 0
		if f.state == "attack" and f.move and f.move.teleport then
			local tp = f.move.teleport.frame
			local d = math.abs(f.moveT - tp)
			if d < 6 then
				fade = 1 - d / 6
			end
		end
		Rig.setTransparency(rig, math.floor(fade * 10) / 10)
	end

	self:renderEchoes(t)
	self:renderProjectiles(t)

	local f1, f2 = m.fighters[1], m.fighters[2]
	FightCamera.update(dt, f1.x, f1.y, f2.x, f2.y)
	StageBuilder.update(t, FightCamera.position().X, self.renderDt, m.fighters)
	self.hud:update(m, dt)
	if self.touch then
		self.touch:update(f1, Config.SuperCost, Config.BreakerCost)
	end
	if m.training then
		self:trainingReadout()
	end
	if m.over and not self.ended then
		self.ended = true
		task.delay(3.4, function()
			if not self.destroyed and self.opts.onEnd then
				self.opts.onEnd(self:result())
			end
		end)
	end
end

function FightView:renderEchoes(t: number)
	local m = self.match
	local alive = {}
	for _, e in m.echoes do
		alive[e.id] = true
		local er = self.echoRigs[e.id]
		if not er then
			local def = e.def
			local rig = Rig.build(def.look, { name = "Echo_" .. def.id, spectral = Color3.fromHex(def.accent), world = workspace })
			rig.model.Parent = self.folder
			er = { rig = rig, style = ECHO_STYLE[def.look.weapon] or "unarmed" }
			self.echoRigs[e.id] = er
		end
		local mv = e.move
		local pose = Poses.attack(mv.anim, er.style, e.t, mv.startup, mv.active, mv.recovery)
		Rig.apply(er.rig, rootCFrame(e.x, 0, e.facing), pose, { time = t })
		local total = mv.startup + mv.active + mv.recovery
		local fade = 0
		if e.t < 8 then
			fade = 1 - e.t / 8
		elseif e.t > total - 8 then
			fade = (e.t - (total - 8)) / 8
		end
		Rig.setTransparency(er.rig, math.clamp(math.floor(fade * 10) / 10, 0, 1))
	end
	for id, er in self.echoRigs do
		if not alive[id] then
			Rig.destroy(er.rig)
			self.echoRigs[id] = nil
		end
	end
end

function FightView:renderProjectiles(_t: number)
	local m = self.match
	local alive = {}
	for _, p in m.projectiles do
		alive[p.id] = true
		local vis = self.projVisuals[p.id]
		if not vis then
			vis = VFX.projectile(p.def.kind, p.def.element)
			self.projVisuals[p.id] = vis
		end
		local facing = p.vx < 0 and -1 or (p.vx > 0 and 1 or p.facing)
		local origin = nil
		if p.def.kind == "hook" then
			local o = m.fighters[p.owner]
			origin = v3(o.x + o.facing * 1.2, 3.2)
		end
		if p.delay > 0 then
			vis.model.Parent = nil
		else
			if not vis.model.Parent then
				vis.model.Parent = workspace:FindFirstChild("VeilVFX") or workspace
			end
			vis:set(v3(p.x, p.y), facing, p.t / 60, origin)
		end
	end
	for id, vis in self.projVisuals do
		if not alive[id] then
			vis:destroy(vis.lastPos)
			self.projVisuals[id] = nil
		end
	end
end

function FightView:trainingReadout()
	local m = self.match
	local p1 = m.fighters[1]
	local lines = {}
	lines[1] = "PRACTICE  \u{2014}  DUMMY: " .. string.upper(m.trainingDummy or "stand")
	lines[2] = "Switch dummy:  [" .. (Input.mode == "touch" and "DUMMY" or Input.glyph("alt")) .. "]"
	if self.lastMove then
		lines[3] = self.lastMove.name
		lines[4] = MoveKit.describe(self.lastMove)
	else
		lines[3] = "Perform a move to see its frame data"
		lines[4] = ""
	end
	lines[5] = string.format("Last combo: %d hits  /  %d dmg", self.lastCombo or 0, self.lastComboDmg or 0)
	self.hud:trainingInfo(lines)
	local _ = p1
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

-- Floating P1 / CPU markers over the fighters for the start of each round.
function FightView:showWorldTags(seconds: number)
	for _, wt in self.worldTags do
		wt.token += 1
		local token = wt.token
		wt.gui.Enabled = true
		wt.label.TextTransparency = 0
		wt.arrow.TextTransparency = 0
		task.delay(seconds, function()
			if self.destroyed or wt.token ~= token then
				return
			end
			Theme.tween(wt.label, 0.4, { TextTransparency = 1 })
			Theme.tween(wt.arrow, 0.4, { TextTransparency = 1 })
			task.delay(0.42, function()
				if not self.destroyed and wt.token == token then
					wt.gui.Enabled = false
				end
			end)
		end)
	end
end

-- Foot plant during walks: soft step sound, and a puff of dust for the heavyweights.
function FightView:footstep(i: number, f)
	local heavy = (f.def.weight or 1) >= 1.15
	Audio.play("footstep", { volume = heavy and 0.32 or 0.16, pitch = heavy and 0.8 or 1, pitchVar = 0.08 })
	if heavy then
		VFX.footDust(v3(f.x, 0), f.facing)
		FightCamera.shake(0.08)
	end
	local _ = i
end

-- Physical reaction impulses on the victim's spine / head, by hit height.
function FightView:hitImpulse(victimIndex: number, strength: string?, react: string?, blocked: boolean?)
	local sp = self.springs[victimIndex]
	if not sp then
		return
	end
	local k = STRENGTH_KICK[strength or "medium"] or 1
	if blocked then
		-- guard absorbs it: chest compresses back, a small skid on the root
		sp:kick("UT", 1, 160 * k)
		sp:kick("H", 1, 120 * k)
		sp:kick("root", 3, 3.5 * k)
		sp:kick("RUA", 1, -120 * k)
		sp:kick("LUA", 1, -120 * k)
		return
	end
	local side = (math.random() < 0.5) and -1 or 1
	if react == "high" then
		-- head snaps back and twists away from the blow
		sp:kick("H", 1, 520 * k)
		sp:kick("H", 3, 260 * k * side)
		sp:kick("UT", 1, 240 * k)
	elseif react == "low" then
		-- legs taken out: hips drop, torso pitches forward
		sp:kick("root", 2, -5 * k)
		sp:kick("UT", 1, -200 * k)
		sp:kick("H", 1, -160 * k)
	else
		-- gut shot: doubles over, head whips forward
		sp:kick("UT", 1, -320 * k)
		sp:kick("H", 1, -260 * k)
		sp:kick("root", 3, 3 * k)
	end
	sp:kick("UT", 2, 140 * k * side)
	sp:kick("RUA", 3, 200 * k)
	sp:kick("LUA", 3, -200 * k)
end

function FightView:rigFlash(i: number, color: Color3?)
	local hl = self.highlights[i]
	if not hl then
		return
	end
	hl.FillColor = color or Color3.new(1, 1, 1)
	hl.FillTransparency = 0.35
	Theme.tween(hl, 0.14, { FillTransparency = 1 })
end

function FightView:fighterWorldPos(i: number, yOff: number?)
	local f = self.match.fighters[i]
	return v3(f.x, f.y + (yOff or 3))
end

function FightView:introCamera(i: number)
	local f = self.match.fighters[i]
	local rig = self.rigs[i]
	local s = rig.scale
	FightCamera.cinematic(function(t)
		local head = v3(f.x, 4.4 * s, 0)
		local side = f.facing
		local orbit = math.rad(-20 + t * 8) * side
		local dist = 7.5 * s - t * 0.25
		local pos = head + Vector3.new(math.sin(orbit) * dist * side + side * 2.5, -0.4 + t * 0.12, math.cos(orbit) * dist)
		return CFrame.lookAt(pos, head - Vector3.new(0, 0.6 * s, 0)), 32
	end, 2.5)
end

function FightView:onEvent(ev)
	local m = self.match
	local typ = ev.type
	if typ == "intro" then
		local f = m.fighters[ev.fighter]
		local def = f.def
		Subtitles.show(def.name, def.intro[ev.line] or def.intro[1], 2.3, Color3.fromHex(def.accent))
		self.hud:cinema(true)
		self.hud:nameCard(ev.fighter, def, 2.1)
		Audio.voice(def.voice, "attack")
		if ev.fighter == 2 then
			self:introCamera(2)
		end
	elseif typ == "round_call" then
		FightCamera.clearCinematic()
		self.hud:cinema(false)
		local final = m.fighters[1].roundWins == m.roundsToWin - 1 and m.fighters[2].roundWins == m.roundsToWin - 1
		self.hud:announce(final and "FINAL ROUND (NO PRESSURE)" or ("ROUND " .. tostring(ev.round)), nil, { hold = 1.1 })
		StageBuilder.react("round")
		Audio.play("round_gong", { volume = 0.9 })
		Audio.play("countdown", { volume = 0.6 })
	elseif typ == "fight" then
		self.hud:announce("FIGHT", nil, { punch = true, color = Theme.Colors.goldBright, hold = 0.7 })
		self:showWorldTags(2.2)
		Audio.play("fight", { volume = 1 })
		FightCamera.shake(0.5)
	elseif typ == "move" then
		local f = m.fighters[ev.fighter]
		local mv = f.def.moves[ev.move]
		if mv then
			if mv.sfx then
				Audio.play(mv.sfx, { volume = 0.7, pitchVar = 0.08 })
			end
			if (mv.kind == "special" or mv.strength == "heavy") and math.random() < 0.55 then
				Audio.voice(f.def.voice, "attack")
			end
			if ev.fighter == 1 then
				self.lastMove = mv
			end
			if mv.kind == "special" and mv.element then
				local cols = VFX.colors(mv.element)
				VFX.flashBall(self:fighterWorldPos(ev.fighter, 3.4) + v3(f.facing * 1.0, 0), cols[2], 2.2, 0.18)
			end
		end
	elseif typ == "super_start" then
		local f = m.fighters[ev.fighter]
		self.hud:flash(Color3.fromHex(f.def.accent), 0.45)
		Audio.play("super_start", { volume = 1 })
		StageBuilder.react("super")
		FightCamera.shake(0.6)
		VFX.burstShockwave(self:fighterWorldPos(ev.fighter, 3), Color3.fromHex(f.def.accent))
	elseif typ == "hit" then
		local attacker = m.fighters[ev.attacker]
		local dir = attacker.facing
		local pos = v3(ev.x, ev.y, 0.2)
		local essence = ev.source ~= "throw"
		VFX.hit(pos, ev.strength or "medium", ev.element, dir, essence)
		-- layered impact: the move's own sound, a body layer by strength, and a low
		-- thump under the big ones
		local strength = ev.strength or "medium"
		Audio.play(ev.sfx or STRENGTH_SFX[strength] or "hit_medium", { volume = 0.85, pitchVar = 0.07 })
		if ev.sfx and STRENGTH_SFX[strength] and ev.sfx ~= STRENGTH_SFX[strength] then
			Audio.play(STRENGTH_SFX[strength], { volume = 0.45, pitchVar = 0.06 })
		end
		local big = strength == "heavy" or strength == "special" or strength == "super"
		if big then
			StageBuilder.react("heavy")
			Audio.play("impact_sub", { volume = strength == "super" and 1 or 0.75, pitchVar = 0.05 })
			FightCamera.punch(strength == "super" and 5 or 2.5)
		end
		-- the camera jolts the way the blow travelled (launchers kick upward)
		local upward = ev.result == "launch" and 0.8 or -0.25
		FightCamera.shake(STRENGTH_SHAKE[strength] or 0.4, big and dir or dir * 0.4, big and upward or 0)
		self:rigFlash(ev.victim)
		self:hitImpulse(ev.victim, ev.strength, ev.react, false)
		local victim = m.fighters[ev.victim]
		victim.lastHitFrame = m.frame
		if ev.combo and ev.combo >= 2 then
			self.hud:combo(ev.attacker, ev.combo, (ev.comboDamage or 0) / victim.maxHp * 100)
		end
		if math.random() < 0.4 or ev.strength == "heavy" then
			Audio.voice(victim.def.voice, "hurt")
		end
		if ev.result == "knockdown" or ev.result == "launch" then
			FightCamera.shake(0.6)
			VFX.impactLight(self.rigs[ev.victim].parts.UpperTorso, Color3.fromHex(attacker.def.accent), 5, 14, 0.3)
		end
		if ev.attacker == 1 then
			self.lastCombo = ev.combo
			self.lastComboDmg = ev.comboDamage
		end
	elseif typ == "block" then
		local attacker = m.fighters[ev.attacker]
		VFX.block(v3(ev.x, ev.y, 0.2), attacker.facing, ev.strength)
		Audio.play("block", { volume = 0.7, pitchVar = 0.06 })
		self:hitImpulse(ev.victim, ev.strength, nil, true)
		FightCamera.shake(0.15)
	elseif typ == "throw" then
		Audio.play("whoosh_heavy", { volume = 0.7 })
		Audio.voice(m.fighters[ev.attacker].def.voice, "attack")
	elseif typ == "tech" then
		VFX.parry(v3(ev.x, ev.y, 0.3))
		Audio.play("tech", { volume = 0.8 })
		self.hud:announce("NICE TRY", nil, { size = 56, hold = 0.6, band = false })
	elseif typ == "projectile_spawn" then
		local p = nil
		for _, pp in m.projectiles do
			if pp.id == ev.id then
				p = pp
			end
		end
		if p then
			local vis = VFX.projectile(p.def.kind, p.def.element)
			self.projVisuals[p.id] = vis
		end
	elseif typ == "projectile_end" then
		local vis = self.projVisuals[ev.id]
		if vis then
			vis:destroy(v3(ev.x, ev.y, 0.3))
			self.projVisuals[ev.id] = nil
			if ev.hit then
				Audio.play("projectile_hit", { volume = 0.7, pitchVar = 0.08 })
			end
		end
	elseif typ == "clash" then
		VFX.flashBall(v3(ev.x, ev.y, 0.3), Color3.new(1, 1, 1), 4, 0.2)
		VFX.ring(v3(ev.x, ev.y, 0.3), Color3.fromHex("#FFE6A0"), 6, 0.25)
		Audio.play("projectile_hit", { volume = 0.9 })
	elseif typ == "echo_summon" then
		local f = m.fighters[ev.fighter]
		local echo = f.echoDef
		VFX.teleport(v3(f.x - f.facing * 1.6, 0), Color3.fromHex(echo.accent))
		Audio.play("echo_summon", { volume = 0.8 })
		Subtitles.show(echo.name, echo.callLine, 1.4, Color3.fromHex(echo.accent))
	elseif typ == "echo_vanish" then
		VFX.teleport(v3(ev.x, 0), Color3.fromHex("#9FEFFF"))
	elseif typ == "teleport" then
		local f = m.fighters[ev.fighter]
		local col = Color3.fromHex(f.def.accent)
		VFX.teleport(v3(ev.fromX, ev.fromY or 0), col)
		VFX.teleport(v3(ev.toX, 0), col)
		Audio.play("teleport", { volume = 0.8 })
	elseif typ == "dash" then
		local f = m.fighters[ev.fighter]
		VFX.footDust(v3(f.x, 0), -f.facing * (ev.dir or 1))
		Audio.play("dash", { volume = 0.5 })
		-- lean into a dash, rock back on a backdash
		self.springs[ev.fighter]:kick("UT", 1, (ev.dir or 1) > 0 and -240 or 200)
	elseif typ == "jump" then
		Audio.play("jump", { volume = 0.45, pitchVar = 0.05 })
	elseif typ == "land" then
		VFX.dust(v3(ev.x, 0), ev.heavy)
		Audio.play("land", { volume = ev.heavy and 0.9 or 0.4 })
		-- weight on landing: hips squash down, chest folds, arms follow through
		local sp = self.springs[ev.fighter]
		if sp then
			sp:kick("root", 2, ev.heavy and -14 or -8)
			sp:kick("UT", 1, ev.heavy and -260 or -150)
			sp:kick("RUA", 1, -160)
			sp:kick("LUA", 1, -160)
		end
		if ev.heavy then
			FightCamera.shake(0.6)
			VFX.groundEruption(v3(ev.x, 0), m.fighters[ev.fighter].def.moves.SB and m.fighters[ev.fighter].def.moves.SB.element or "ice", 2.5)
		end
	elseif typ == "knockdown" then
		VFX.dust(v3(ev.x, 0), true)
		Audio.play("knockdown", { volume = 0.9 })
		Audio.play("body_fall", { volume = 0.8, pitchVar = 0.06 })
		FightCamera.shake(0.5, 0, -1)
		local sp = self.springs[ev.fighter]
		if sp then
			sp:kick("root", 2, -6)
			sp:kick("H", 1, 300)
		end
	elseif typ == "getup" then
		Audio.play("getup", { volume = 0.4 })
	elseif typ == "parry" then
		VFX.parry(v3(ev.x, ev.y, 0.3))
		Audio.play("parry", { volume = 1 })
		self.hud:flash(Color3.new(1, 1, 1), 0.3)
		self.hud:announce("NOT TODAY", nil, { size = 60, hold = 0.6, band = false, color = Theme.Colors.goldBright })
	elseif typ == "armor" then
		VFX.ring(v3(ev.x, ev.y, 0.3), Color3.fromHex("#FFD27A"), 5, 0.25)
		Audio.play("block", { volume = 0.9, pitch = 0.8 })
	elseif typ == "breaker" then
		local f = m.fighters[ev.fighter]
		VFX.burstShockwave(v3(ev.x, ev.y), Color3.fromHex(f.def.accent))
		Audio.play("breaker", { volume = 1 })
		self.hud:flash(Color3.fromHex(f.def.accent), 0.5)
		self.hud:announce("RAGE QUIT!", nil, { size = 70, hold = 0.7, band = false, color = Color3.fromHex(f.def.accent) })
		FightCamera.shake(1)
	elseif typ == "super_hit" then
		self:startSuperCinematic(ev)
	elseif typ == "super_end" then
		self:endSuperCinematic()
	elseif typ == "ko" then
		self.hud:flash(Color3.new(1, 1, 1), 0.8)
		self.hud:announce("OOF!", ev.perfect and "NO DAMAGE TAKEN. EMBARRASSING." or nil, { punch = true, color = Theme.Colors.crimsonBright, size = 150, hold = 2.0 })
		Audio.play("ko", { volume = 1 })
		StageBuilder.react("ko")
		Audio.play("oof", { group = "voice", volume = 1 })
		Audio.duck(0.35, 2.5)
		FightCamera.shake(1.4)
		VFX.burstShockwave(v3(ev.x, ev.y), Theme.Colors.crimsonBright)
	elseif typ == "time_over" then
		self.hud:announce("TIME", nil, { hold = 1.4 })
		Audio.play("round_gong", { volume = 1 })
	elseif typ == "round_win" then
		if ev.winner and ev.winner > 0 then
			local wf = m.fighters[ev.winner]
			self.hud:announce(wf.def.name .. " WINS", ev.perfect and "NOT EVEN CLOSE" or (ev.timeOver and "TIME (SERVER LAG)" or nil), {
				size = 84,
				hold = 1.8,
				color = Theme.Colors.ivory,
			})
			self:winCamera(ev.winner)
			self.hud:cinema(true)
		else
			self.hud:announce("DRAW", "BOTH OF YOU ARE NOOBS", { hold = 1.6 })
		end
	elseif typ == "finish_prompt" then
		FightCamera.clearCinematic()
		self.hud:cinema(false)
		self.hud:showFinisherPrompt(true)
		Audio.play("finisher_ready", { volume = 1 })
		Audio.duck(0.4, 6)
	elseif typ == "finisher_start" then
		self.hud:showFinisherPrompt(false)
		self.hud:cinema(true)
		self:startFinisherCinematic(ev)
	elseif typ == "finisher_hit" then
		local loser = self.rigs[ev.loser]
		local wf = m.fighters[ev.winner]
		local col = Color3.fromHex(wf.def.accent)
		VFX.elementBurst(v3(m.fighters[ev.loser].x, 3), ev.style, true)
		VFX.oofBreak(loser, col)
		loser.shattered = true
		Audio.play("shatter", { volume = 1 })
		Audio.play("oof", { group = "voice", volume = 1 })
		self.hud:flash(col, 0.8)
		FightCamera.shake(1.5)
		task.delay(0.6, function()
			if self.destroyed then
				return
			end
			self.hud:announce("ACCOUNT DELETED", nil, { size = 100, hold = 2.0, color = Theme.Colors.crimsonBright })
		end)
	elseif typ == "match_end" then
		self.hud:showFinisherPrompt(false)
		self.hud:cinema(true)
		local wf = m.fighters[ev.winner]
		local quote = wf.def.victory[wf.winQuote or 1] or wf.def.victory[1]
		task.delay(ev.finisher and 1.2 or 0.4, function()
			if self.destroyed then
				return
			end
			self.hud:announce(wf.def.name .. " WINS", nil, { size = 92, hold = 2.4 })
			Subtitles.show(wf.def.name, quote, 2.8, Color3.fromHex(wf.def.accent))
			Audio.voice(wf.def.voice, "attack")
			Audio.music("music_victory", 1.0)
		end)
		self:winCamera(ev.winner)
	end
end

function FightView:winCamera(i: number)
	local f = self.match.fighters[i]
	local s = self.rigs[i].scale
	FightCamera.cinematic(function(t)
		local center = v3(f.x, 3.6 * s, 0)
		local a = math.rad(15 + t * 6) * f.facing
		local pos = center + Vector3.new(math.sin(a) * 9 * f.facing + f.facing * 3, 0.6 + t * 0.15, math.cos(a) * 9)
		return CFrame.lookAt(pos, center), 34
	end, 4.5)
end

function FightView:startSuperCinematic(ev)
	local m = self.match
	local a = m.fighters[ev.attacker]
	local v = m.fighters[ev.victim]
	local col = Color3.fromHex(a.def.accent)
	self.hud:superBanner(a.def.superName, ev.attacker, col)
	self.hud:cinema(true, 0.25)
	Audio.duck(0.3, 2.6)
	local grade = self.stage and self.stage.fx and self.stage.fx.grade
	if grade then
		self.savedGrade = { grade.Brightness, grade.Saturation, grade.TintColor }
		Theme.tween(grade, 0.3, { Brightness = -0.18, Saturation = -0.4, TintColor = col:Lerp(Color3.new(1, 1, 1), 0.6) })
	end
	local strikeFrames = { 26, 46, 66, 86, 106 }
	for k, fr in strikeFrames do
		task.delay(fr / 60, function()
			if self.destroyed or not self.match.cinematic then
				return
			end
			local pos = v3(v.x, 3.2 + (k % 2) * 0.6, 0.4)
			VFX.hit(pos, "heavy", ev.style, a.facing, true)
			Audio.play("hit_heavy", { volume = 0.8, pitchVar = 0.1 })
			FightCamera.shake(0.7)
		end)
	end
	task.delay(118 / 60, function()
		if self.destroyed then
			return
		end
		self.hud:flash(Color3.new(1, 1, 1), 0.85)
		VFX.burstShockwave(v3(v.x, 3), col)
		VFX.elementBurst(v3(v.x, 3), ev.style, true)
		FightCamera.shake(1.6)
	end)
	FightCamera.cinematic(function(t)
		local mid = v3((a.x + v.x) / 2, 3.2, 0)
		local ang = math.rad(-35 + t * 40) * a.facing
		local dist = 10 - math.min(t, 1.2) * 2.5
		local pos = mid + Vector3.new(math.sin(ang) * dist, 1.2 + math.sin(t * 2) * 0.5, math.cos(ang) * dist)
		if t > 1.95 then
			pos = mid + Vector3.new(-a.facing * 4, 0.5, 7)
		end
		return CFrame.lookAt(pos, mid), 40 - math.min(t, 1) * 6
	end, 150 / 60)
end

function FightView:endSuperCinematic()
	FightCamera.clearCinematic()
	if not self.match.over and self.match.phase == "fight" then
		self.hud:cinema(false, 0.3)
	end
	local grade = self.stage and self.stage.fx and self.stage.fx.grade
	if grade and self.savedGrade then
		Theme.tween(grade, 0.4, { Brightness = self.savedGrade[1], Saturation = self.savedGrade[2], TintColor = self.savedGrade[3] })
	end
end

function FightView:startFinisherCinematic(ev)
	local m = self.match
	local w = m.fighters[ev.winner]
	local l = m.fighters[ev.loser]
	local col = Color3.fromHex(w.def.accent)
	self.hud:superBanner(w.def.finisher.name, ev.winner, col)
	Audio.play("super_start", { volume = 1 })
	local grade = self.stage and self.stage.fx and self.stage.fx.grade
	if grade then
		Theme.tween(grade, 0.6, { Brightness = -0.2, Saturation = -0.5, TintColor = col:Lerp(Color3.new(1, 1, 1), 0.5) })
	end
	for k = 0, 4 do
		task.delay((50 + k * 28 + 12) / 60, function()
			if self.destroyed then
				return
			end
			VFX.hit(v3(l.x, 3.2, 0.4), "heavy", ev.style, w.facing, false)
			Audio.play("hit_heavy", { volume = 0.8, pitchVar = 0.1 })
			FightCamera.shake(0.6)
		end)
	end
	-- elemental build-up around the loser
	task.delay(0.4, function()
		if not self.destroyed then
			VFX.elementBurst(v3(l.x, 2.5), ev.style, true)
		end
	end)
	FightCamera.cinematic(function(t)
		local mid = v3((w.x + l.x) / 2, 3.4, 0)
		local ang = math.rad(25 - t * 14) * w.facing
		local dist = 13 - math.min(t, 3) * 1.6
		local pos = mid + Vector3.new(math.sin(ang) * dist, 1.5 + t * 0.2, math.cos(ang) * dist)
		return CFrame.lookAt(pos, mid), 38
	end, 6.0)
end

function FightView:result()
	local m = self.match
	return {
		winner = m.winner,
		rounds = { m.fighters[1].roundWins, m.fighters[2].roundWins },
		stats = { m.fighters[1].stats, m.fighters[2].stats },
		p1 = self.opts.p1,
		p2 = self.opts.p2,
		stage = self.opts.stage,
		finisher = m.finisher and m.finisher.triggered or false,
	}
end

function FightView:destroy()
	self.destroyed = true
	for _, c in self.connections do
		c:Disconnect()
	end
	self.connections = {}
	Input.fightEnabled = false
	for _, vis in self.projVisuals do
		vis:destroy()
	end
	self.projVisuals = {}
	for _, er in self.echoRigs do
		Rig.destroy(er.rig)
	end
	self.echoRigs = {}
	if self.touch then
		self.touch:destroy()
	end
	self.hud:destroy()
	self.folder:Destroy()
	VFX.clear()
	Subtitles.hide()
	FightCamera.disable()
end

return FightView
