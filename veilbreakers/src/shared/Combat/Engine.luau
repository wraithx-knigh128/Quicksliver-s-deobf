--!nonstrict
-- VEILBREAKERS combat engine.
--
-- A deterministic, fixed-step (60 Hz) 2D fighting simulation. It knows nothing about
-- Roblox instances: the client renders whatever state this module exposes and reacts
-- to the events it emits. The same code runs headless in the Lune test-suite.
--
-- Coordinates: x along the arena (studs, 0 = centre), y up from the floor.

local Config = require(script.Parent.Parent.Config)
local Fighters = require(script.Parent.Parent.Data.Fighters)
local Echoes = require(script.Parent.Parent.Data.Echoes)
local Rng = require(script.Parent.Rng)

local Engine = {}

local BUTTONS = { "L", "H", "K", "S", "B", "E", "X" }
local NEUTRAL_INPUT = {
	left = false,
	right = false,
	up = false,
	down = false,
	L = false,
	H = false,
	K = false,
	S = false,
	B = false,
	E = false,
	X = false,
}
Engine.NeutralInput = NEUTRAL_INPUT

local function sign(n: number): number
	if n > 0 then
		return 1
	elseif n < 0 then
		return -1
	end
	return 0
end

local function overlap(a, b): boolean
	return math.abs(a.cx - b.cx) * 2 < (a.w + b.w) and math.abs(a.cy - b.cy) * 2 < (a.h + b.h)
end

-------------------------------------------------------------------------------
-- Fighter construction
-------------------------------------------------------------------------------

local function newFighter(_match, index: number, spec)
	local def = Fighters.get(spec.fighter)
	local echoDef = Echoes.get(spec.echo or "okoro")
	local maxHp = def.health
	if spec.boss then
		maxHp += Config.BossHealthBonus
	end
	local f = {
		index = index,
		def = def,
		echoDef = echoDef,
		scale = def.look.scale,
		x = index == 1 and -4 or 4,
		y = 0,
		vx = 0,
		vy = 0,
		facing = index == 1 and 1 or -1,
		hp = maxHp,
		maxHp = maxHp,
		meter = 0,
		echoCD = 0,
		state = "intro",
		t = 0,
		move = nil,
		moveT = 0,
		moveHit = false,
		moveBlocked = false,
		moveHits = 0,
		moveHitCooldown = 0,
		hitTargets = {},
		pendingChain = nil,
		stun = 0,
		crouch = false,
		walk = 0,
		jumpDir = 0,
		juggle = 0,
		juggleLocked = false,
		comboHits = 0,
		comboDamage = 0,
		invuln = 0,
		armorUsed = false,
		pushV = 0,
		knockdownKind = nil,
		throwPartner = nil,
		throwT = 0,
		throwBack = false,
		throwTechable = false,
		throwDamage = 0,
		lastHitBy = nil,
		hitReact = "mid",
		input = table.clone(NEUTRAL_INPUT),
		prevInput = table.clone(NEUTRAL_INPUT),
		pressedAt = {},
		consumed = {},
		lastDirTap = { f = -100, b = -100 },
		prevFwd = false,
		prevBack = false,
		roundWins = 0,
		isCPU = spec.cpu == true,
		pose = "stance",
		introLine = 1,
		winQuote = 1,
		stats = {
			damage = 0,
			hits = 0,
			maxCombo = 0,
			maxComboDamage = 0,
			blocks = 0,
			throws = 0,
			specials = 0,
			supers = 0,
			echoes = 0,
			breakers = 0,
		},
	}
	for _, b in BUTTONS do
		f.pressedAt[b] = -1000
		f.consumed[b] = true
	end
	return f
end

-------------------------------------------------------------------------------
-- Match
-------------------------------------------------------------------------------

function Engine.newMatch(opts)
	local match = {
		opts = opts,
		frame = 0,
		round = 1,
		phase = "intro",
		phaseT = 0,
		timer = Config.RoundTimeSeconds * Config.TickRate,
		hitstop = 0,
		slowmo = 0,
		cinematic = nil,
		projectiles = {},
		echoes = {},
		events = {},
		winner = nil,
		roundWinner = nil,
		over = false,
		training = opts.training == true,
		stage = opts.stage or "hollowroot",
		rng = Rng.new(opts.seed or 1337),
		finisher = nil,
		nextId = 1,
		roundsToWin = opts.roundsToWin or Config.RoundsToWin,
		perfect = false,
	}
	match.fighters = {
		newFighter(match, 1, opts.p1),
		newFighter(match, 2, opts.p2),
	}
	match.fighters[1].opponent = match.fighters[2]
	match.fighters[2].opponent = match.fighters[1]
	match.fighters[1].introLine = match.rng:int(1, #match.fighters[1].def.intro)
	match.fighters[2].introLine = match.rng:int(1, #match.fighters[2].def.intro)
	if match.training then
		match.phase = "fight"
		match.fighters[1].state = "stand"
		match.fighters[2].state = "stand"
		match.trainingDummy = opts.dummy or "stand"
		match.fighters[1].meter = Config.MeterMax
		match.fighters[2].meter = Config.MeterMax
	end
	if opts.skipIntro then
		match.phase = "roundcall"
		match.fighters[1].state = "stand"
		match.fighters[2].state = "stand"
	end
	return match
end

local function emit(match, ev)
	ev.frame = match.frame
	table.insert(match.events, ev)
end
Engine.emit = emit

function Engine.drainEvents(match)
	local evs = match.events
	match.events = {}
	return evs
end

local function setPhase(match, phase: string)
	match.phase = phase
	match.phaseT = 0
	emit(match, { type = "phase", phase = phase, round = match.round })
end

local function resetRound(match)
	local p1, p2 = match.fighters[1], match.fighters[2]
	for _, f in match.fighters do
		f.x = f.index == 1 and -4 or 4
		f.y = 0
		f.vx = 0
		f.vy = 0
		f.facing = f.index == 1 and 1 or -1
		f.hp = f.maxHp
		f.state = "stand"
		f.t = 0
		f.move = nil
		f.stun = 0
		f.juggle = 0
		f.juggleLocked = false
		f.comboHits = 0
		f.comboDamage = 0
		f.invuln = 0
		f.pushV = 0
		f.crouch = false
		f.throwPartner = nil
		f.echoCD = 0
		f.pendingChain = nil
		f.pose = "stance"
		f.dying = false
		f.pullTarget = nil
		f.throwTechable = false
		f.landLag = nil
		f.walk = 0
		f.armorUsed = false
		f.pushSource = nil
	end
	p1.opponent = p2
	p2.opponent = p1
	match.projectiles = {}
	match.echoes = {}
	match.timer = Config.RoundTimeSeconds * Config.TickRate
	match.cinematic = nil
	match.hitstop = 0
	match.slowmo = 0
	match.roundWinner = nil
end

-------------------------------------------------------------------------------
-- Input helpers
-------------------------------------------------------------------------------

local function relDir(f, inp)
	local fwd, back
	if f.facing == 1 then
		fwd, back = inp.right, inp.left
	else
		fwd, back = inp.left, inp.right
	end
	if fwd and back then
		fwd, back = false, false
	end
	return fwd, back
end

local function pressed(match, f, b: string): boolean
	return (not f.consumed[b]) and (match.frame - f.pressedAt[b] <= Config.InputBuffer)
end

local function consume(f, b: string)
	f.consumed[b] = true
end

local function readInput(match, f, inp)
	f.prevInput = f.input
	f.input = inp
	for _, b in BUTTONS do
		if inp[b] and not f.prevInput[b] then
			f.pressedAt[b] = match.frame
			f.consumed[b] = false
		end
	end
	-- double-tap detection for dashes
	local fwd, back = relDir(f, inp)
	f.dashRequest = nil
	if fwd and not f.prevFwd then
		if match.frame - f.lastDirTap.f <= Config.DoubleTapWindow then
			f.dashRequest = "dash"
			f.lastDirTap.f = -100
		else
			f.lastDirTap.f = match.frame
		end
	end
	if back and not f.prevBack then
		if match.frame - f.lastDirTap.b <= Config.DoubleTapWindow then
			f.dashRequest = "backdash"
			f.lastDirTap.b = -100
		else
			f.lastDirTap.b = match.frame
		end
	end
	f.prevFwd = fwd
	f.prevBack = back
end

-------------------------------------------------------------------------------
-- Geometry
-------------------------------------------------------------------------------

local function isAirborne(f): boolean
	return f.y > 0.001
end

local function hurtbox(f)
	local s = f.scale
	local st = f.state
	if st == "knockdown" or st == "dead_down" or st == "banished" then
		return nil
	end
	if st == "attack" and f.move and (f.move.crouching or f.move.lowProfile) then
		local h = f.move.lowProfile and 1.8 or 3.5 * s
		return { cx = f.x, cy = f.y + h / 2, w = 2.0 * s, h = h }
	end
	if f.crouch and not isAirborne(f) then
		return { cx = f.x, cy = 1.75 * s, w = 2.0 * s, h = 3.5 * s }
	end
	if isAirborne(f) or st == "juggle" then
		return { cx = f.x, cy = f.y + 2.4 * s, w = 1.8 * s, h = 4.2 * s }
	end
	return { cx = f.x, cy = 2.65 * s, w = 1.9 * s, h = 5.3 * s }
end
Engine.hurtbox = hurtbox

local function moveHitbox(f, box)
	return {
		cx = f.x + f.facing * box.x,
		cy = f.y + box.y,
		w = box.w,
		h = box.h,
	}
end
Engine.moveHitbox = moveHitbox

-------------------------------------------------------------------------------
-- State helpers
-------------------------------------------------------------------------------

local function setState(f, st: string)
	f.state = st
	f.t = 0
end

local function isActionable(f): boolean
	local st = f.state
	return st == "stand" or st == "crouch" or st == "block" or st == "walk"
end

local function inHitstun(f): boolean
	local st = f.state
	return st == "hitstun" or st == "juggle" or st == "blockstun" or st == "thrown" or st == "knockdown"
end
Engine.inHitstun = inHitstun

local function startMove(match, f, id: string)
	local move = f.def.moves[id]
	if not move then
		return false
	end
	if move.cost and f.meter < move.cost then
		return false
	end
	if move.cost then
		f.meter -= move.cost
	end
	f.move = move
	f.moveT = 0
	f.moveHit = false
	f.moveBlocked = false
	f.moveHits = 0
	f.moveHitCooldown = 0
	f.hitTargets = {}
	f.pendingChain = nil
	f.armorUsed = false
	f.parried = false
	setState(f, "attack")
	if not move.air then
		f.vx = 0
	end
	f.crouch = move.crouching == true
	if move.kind == "special" then
		f.stats.specials += 1
	end
	emit(match, { type = "move", fighter = f.index, move = id, anim = move.anim, kind = move.kind })
	if move.kind == "super" then
		f.stats.supers += 1
		match.superFlash = 30
		emit(match, { type = "super_start", fighter = f.index, move = id })
	end
	return true
end
Engine.startMove = startMove

local function endMove(f)
	f.move = nil
	f.pendingChain = nil
	if isAirborne(f) then
		setState(f, "air")
	else
		setState(f, "stand")
		f.crouch = false
	end
end

local function faceOpponent(f)
	local d = f.opponent.x - f.x
	if math.abs(d) > 0.05 then
		f.facing = sign(d)
	end
end

local function comboScale(hits: number): number
	if hits <= 1 then
		return 1
	end
	return math.max(Config.ComboScalingMin, 1 - Config.ComboScalingStep * (hits - 1))
end

local function addMeter(f, amount: number)
	f.meter = math.clamp(f.meter + amount, 0, Config.MeterMax)
end

-------------------------------------------------------------------------------
-- Choosing actions from input
-------------------------------------------------------------------------------

local function normalFor(f, button: string, fwd: boolean, back: boolean, down: boolean): string
	if isAirborne(f) then
		return "J" .. button
	end
	if down then
		return "D" .. button
	end
	if fwd and button == "H" then
		return "FH"
	end
	if back and button == "K" then
		return "BK"
	end
	return button
end

local function specialFor(f, fwd: boolean, back: boolean, down: boolean): string
	if isAirborne(f) then
		return "SA"
	end
	if down then
		return "SD"
	elseif fwd then
		return "SF"
	elseif back then
		return "SB"
	end
	return "SN"
end

local function trySummonEcho(match, f)
	if f.echoCD > 0 or not pressed(match, f, "E") then
		return
	end
	local st = f.state
	if inHitstun(f) or st == "throwing" or st == "super" or st == "dead" or st == "breaker" then
		return
	end
	consume(f, "E")
	local variant = f.input.down and "down" or "neutral"
	local em = f.echoDef[variant]
	local e = {
		id = match.nextId,
		owner = f.index,
		def = f.echoDef,
		move = em,
		variant = variant,
		t = 0,
		facing = f.facing,
		x = 0,
		y = 0,
		hitTargets = {},
		hits = 0,
		cooldown = 0,
		alive = true,
		spawned = false,
	}
	match.nextId += 1
	if em.spawn == "front" then
		e.x = f.x + f.facing * 1.5
	else
		e.x = f.x - f.facing * 1.7
	end
	e.x = math.clamp(e.x, -Config.StageHalfWidth, Config.StageHalfWidth)
	table.insert(match.echoes, e)
	f.echoCD = Config.EchoCooldown
	f.stats.echoes += 1
	emit(match, { type = "echo_summon", fighter = f.index, echo = f.echoDef.id, variant = variant, id = e.id })
end

-- Try the highest-priority buffered action for an actionable / cancelable fighter.
-- Returns true if a move started.
local function tryActions(match, f, cancelMode: string?)
	local inp = f.input
	local fwd, back = relDir(f, inp)
	local down = inp.down

	-- Super
	if pressed(match, f, "X") and f.meter >= Config.SuperCost and not isAirborne(f) and f.def.moves.SUPER then
		if cancelMode == nil or cancelMode == "special" or cancelMode == "normal" then
			consume(f, "X")
			return startMove(match, f, "SUPER")
		end
	end
	-- Throw: block + light
	if cancelMode == nil and not isAirborne(f) and pressed(match, f, "L") and inp.B then
		consume(f, "L")
		return startMove(match, f, "THROW")
	end
	-- Specials
	if pressed(match, f, "S") and (cancelMode == nil or cancelMode == "normal") then
		local id = specialFor(f, fwd, back, down)
		if f.def.moves[id] then
			consume(f, "S")
			return startMove(match, f, id)
		end
	end
	if cancelMode ~= nil then
		return false
	end
	-- Normals
	for _, b in { "H", "K", "L" } do
		if pressed(match, f, b) then
			local id = normalFor(f, b, fwd, back, down)
			if f.def.moves[id] then
				consume(f, b)
				return startMove(match, f, id)
			end
		end
	end
	return false
end

-------------------------------------------------------------------------------
-- Per-fighter think: state transitions driven by input
-------------------------------------------------------------------------------

local function think(match, f)
	local inp = f.input
	local fwd, back = relDir(f, inp)
	local st = f.state

	if match.phase ~= "fight" then
		-- Only the finisher prompt allows the winner to act.
		if match.phase == "finish_prompt" and match.finisher and match.finisher.winner == f.index then
			if isActionable(f) or st == "walk" then
				if inp.down and pressed(match, f, "S") then
					consume(f, "S")
					match.finisher.triggered = true
					return
				end
				f.walk = 0
				if fwd then
					f.walk = 1
				elseif back then
					f.walk = -1
				end
				f.crouch = inp.down
			end
		end
		return
	end

	trySummonEcho(match, f)

	if st == "attack" then
		local m = f.move
		-- target-combo chains
		if m.chain and f.moveT >= m.startup then
			for b, nextId in m.chain do
				if pressed(match, f, b) then
					consume(f, b)
					f.pendingChain = nextId
				end
			end
		end
		if f.pendingChain and f.moveT >= m.startup + m.active then
			local id = f.pendingChain
			f.pendingChain = nil
			startMove(match, f, id)
			return
		end
		-- special / super cancels on contact
		if (f.moveHit or f.moveBlocked) and f.moveT > m.startup then
			if m.specialCancel and m.kind == "normal" then
				if tryActions(match, f, "normal") then
					return
				end
			elseif m.kind == "special" and not m.cost then
				if tryActions(match, f, "special") then
					return
				end
			end
		end
		return
	end

	if st == "hitstun" or st == "juggle" then
		-- Breaker
		if pressed(match, f, "X") and f.meter >= Config.BreakerCost and f.comboHits >= Config.BreakerMinHits then
			consume(f, "X")
			f.meter -= Config.BreakerCost
			f.echoCD = math.max(f.echoCD, Config.EchoCooldownAfterBreaker)
			f.stats.breakers += 1
			local o = f.opponent
			setState(f, "breaker")
			f.invuln = 30
			f.vx = 0
			f.vy = isAirborne(f) and 0.2 or 0
			f.comboHits = 0
			o.move = nil
			setState(o, "hitstun")
			o.stun = 28
			o.hitReact = "mid"
			o.pushV = -o.facing * 0.7
			o.vy = 0
			match.hitstop = 8
			emit(match, { type = "breaker", fighter = f.index, x = f.x, y = f.y + 2.5 })
		end
		return
	end

	if st == "thrown" then
		if f.throwTechable and pressed(match, f, "L") and inp.B then
			consume(f, "L")
			local o = f.opponent
			if o.state == "throwing" and o.throwT <= Config.ThrowTechWindow then
				f.throwTechable = false
				setState(f, "blockstun")
				f.stun = 18
				f.pushV = -f.facing * 0.5
				setState(o, "blockstun")
				o.stun = 18
				o.pushV = -o.facing * 0.5
				o.move = nil
				f.throwPartner = nil
				o.throwPartner = nil
				emit(match, { type = "tech", fighter = f.index, x = (f.x + o.x) / 2, y = 3 })
			end
		end
		return
	end

	if st == "air" then
		if tryActions(match, f) then
			return
		end
		return
	end

	if st == "dash" or st == "backdash" or st == "jumpsquat" or st == "land" or st == "knockdown" or st == "getup" then
		return
	end
	if st == "blockstun" or st == "breaker" or st == "super" or st == "throwing" then
		return
	end

	if not isActionable(f) then
		return
	end

	-- dashes
	if f.dashRequest == "dash" and not inp.down and not inp.B then
		setState(f, "dash")
		emit(match, { type = "dash", fighter = f.index, dir = 1 })
		return
	elseif f.dashRequest == "backdash" and not inp.down and not inp.B then
		setState(f, "backdash")
		f.invuln = 6
		emit(match, { type = "dash", fighter = f.index, dir = -1 })
		return
	end

	if tryActions(match, f) then
		return
	end

	if inp.up then
		setState(f, "jumpsquat")
		f.jumpDir = fwd and 1 or (back and -1 or 0)
		f.crouch = false
		return
	end

	if inp.B then
		f.crouch = inp.down
		if st ~= "block" then
			setState(f, "block")
		end
		f.walk = 0
		return
	end

	if inp.down then
		f.crouch = true
		if st ~= "crouch" then
			setState(f, "crouch")
		end
		f.walk = 0
		return
	end

	f.crouch = false
	if fwd then
		f.walk = 1
	elseif back then
		f.walk = -1
	else
		f.walk = 0
	end
	if st ~= "stand" then
		setState(f, "stand")
	end
end

-------------------------------------------------------------------------------
-- Projectiles
-------------------------------------------------------------------------------

local function spawnProjectile(match, owner, pdef, fromX: number, fromY: number, facing: number, sourceId: string)
	local x = fromX + facing * (pdef.offset and pdef.offset.x or 1)
	local y = (pdef.offset and pdef.offset.y or 3)
	if pdef.spawnAt == "ahead" then
		x = fromX + facing * (pdef.ahead or 5)
	elseif pdef.spawnAt == "opponent" then
		x = owner.opponent.x
		y = (pdef.offset and pdef.offset.y or 8)
	else
		y = fromY + y
	end
	x = math.clamp(x, -Config.StageHalfWidth - 2, Config.StageHalfWidth + 2)
	local p = {
		id = match.nextId,
		owner = owner.index,
		def = pdef,
		source = sourceId,
		x = x,
		y = y,
		vx = facing * pdef.vx,
		vy = pdef.vy or 0,
		facing = facing,
		t = 0,
		life = pdef.life,
		hitsLeft = pdef.hits or 1,
		cooldown = 0,
		delay = pdef.delay or 0,
		alive = true,
		returned = false,
	}
	match.nextId += 1
	table.insert(match.projectiles, p)
	emit(match, { type = "projectile_spawn", id = p.id, kind = pdef.kind, owner = owner.index, x = x, y = y })
	return p
end

-------------------------------------------------------------------------------
-- Hit resolution
-------------------------------------------------------------------------------

local function knockdown(match, f, kind: string?)
	setState(f, "knockdown")
	f.knockdownKind = kind or "back"
	f.vx = 0
	f.vy = 0
	f.y = 0
	f.crouch = false
	f.move = nil
	emit(match, { type = "knockdown", fighter = f.index, x = f.x })
end

local function ko(match, victim, attacker)
	if match.phase ~= "fight" then
		return
	end
	victim.hp = 0
	match.roundWinner = attacker.index
	attacker.roundWins += 1
	match.perfect = attacker.hp >= attacker.maxHp
	setPhase(match, "ko")
	match.slowmo = 75
	emit(match, { type = "ko", victim = victim.index, winner = attacker.index, x = victim.x, y = victim.y + 3, perfect = match.perfect })
	if victim.state ~= "juggle" then
		setState(victim, "juggle")
		victim.vy = 0.42
		victim.vx = -victim.facing * 0.12
	end
	victim.juggleLocked = true
	victim.dying = true
end

-- hit: a table with damage/guard/onHit/onBlock/launch/knockdown/push/strength fields.
-- source: "move" | "projectile" | "echo"
local function applyHit(match, attacker, victim, hit, source: string, activeIdx: number?, hitX: number, hitY: number, meta)
	if match.phase ~= "fight" then
		return "none"
	end
	-- parry stances
	if victim.state == "attack" and victim.move and victim.move.parry and source == "move" then
		local pr = victim.move.parry
		if victim.moveT >= pr.from and victim.moveT <= pr.to and hit.guard ~= "low" then
			local counter = pr.counter
			emit(match, { type = "parry", fighter = victim.index, x = hitX, y = hitY })
			startMove(match, victim, counter)
			attacker.move = nil
			setState(attacker, "hitstun")
			attacker.stun = 22
			attacker.hitReact = "high"
			match.hitstop = 12
			return "parried"
		end
	end
	-- armor
	if victim.state == "attack" and victim.move and victim.move.armor and not victim.armorUsed then
		local ar = victim.move.armor
		if victim.moveT >= ar[1] and victim.moveT <= ar[2] and hit.guard ~= "unblockable" then
			victim.armorUsed = true
			local dmg = math.floor(hit.damage * 0.75 + 0.5)
			victim.hp -= dmg
			attacker.stats.damage += dmg
			match.hitstop = 7
			emit(match, { type = "armor", fighter = victim.index, x = hitX, y = hitY, damage = dmg })
			if victim.hp <= 0 then
				ko(match, victim, attacker)
			end
			return "armored"
		end
	end

	local blocking = false
	if (victim.state == "block" or victim.state == "blockstun") and victim.input.B and not isAirborne(victim) then
		blocking = true
	end
	if victim.isDummyBlocking then
		blocking = true
		victim.crouch = hit.guard == "low"
	end
	local guard = hit.guard or "mid"
	if guard == "unblockable" then
		blocking = false
	elseif blocking then
		local wrongHeight = (guard == "low" and not victim.crouch) or (guard == "overhead" and victim.crouch)
		if wrongHeight then
			blocking = false
		end
	end

	local away = sign(victim.x - attacker.x)
	if away == 0 then
		away = attacker.facing
	end
	if source ~= "move" and meta and meta.dir then
		away = meta.dir
	end

	if blocking then
		local chip = 0
		if hit.kind ~= "normal" and hit.kind ~= "air" then
			chip = math.floor(hit.damage * Config.ChipFraction)
			if victim.hp - chip < 1 then
				chip = math.max(0, victim.hp - 1)
			end
		end
		victim.hp -= chip
		local bs
		if source == "move" then
			local remaining = (hit.active - (activeIdx or 1)) + hit.recovery
			bs = math.max(6, remaining + (hit.onBlock or -2))
		else
			bs = math.max(8, 14 + (hit.onBlock or 0))
		end
		setState(victim, "blockstun")
		victim.stun = bs
		victim.move = nil
		victim.pushV = away * (hit.blockPush or hit.push or 0.2) * 1.1
		victim.pushSource = attacker
		victim.stats.blocks += 1
		addMeter(attacker, 4)
		addMeter(victim, 3)
		match.hitstop = math.max(match.hitstop, 5)
		emit(match, {
			type = "block",
			attacker = attacker.index,
			victim = victim.index,
			x = hitX,
			y = hitY,
			chip = chip,
			strength = hit.strength,
			source = source,
		})
		return "blocked"
	end

	-- Hit!
	if victim.state == "thrown" or victim.state == "throwing" then
		return "none"
	end
	local airborneBefore = isAirborne(victim) or victim.state == "juggle"
	victim.comboHits += 1
	local scale = comboScale(victim.comboHits)
	local dmg = math.max(1, math.floor(hit.damage * scale * Config.DamageScale + 0.5))
	if match.training then
		-- training dummy never dies
		dmg = math.min(dmg, victim.hp - 1)
	end
	victim.hp -= dmg
	victim.comboDamage += dmg
	victim.lastHitBy = attacker.index
	attacker.stats.damage += dmg
	attacker.stats.hits += 1
	if victim.comboHits > attacker.stats.maxCombo then
		attacker.stats.maxCombo = victim.comboHits
	end
	if victim.comboDamage > attacker.stats.maxComboDamage then
		attacker.stats.maxComboDamage = victim.comboDamage
	end
	addMeter(attacker, math.max(3, dmg * 0.14))
	addMeter(victim, dmg * 0.09)
	victim.move = nil
	victim.pendingChain = nil
	victim.crouch = false

	local react = "mid"
	if hit.guard == "low" then
		react = "low"
	elseif (hitY - victim.y) > 3.6 * victim.scale then
		react = "high"
	end
	victim.hitReact = react

	local result = "hit"
	if hit.launch or (airborneBefore and not victim.juggleLocked) then
		victim.juggle += 1
		setState(victim, "juggle")
		if victim.juggle > Config.MaxJuggleHits then
			victim.juggleLocked = true
		end
		local lvy = hit.launch and hit.launch.vy or 0.36
		if airborneBefore and not hit.launch then
			lvy = math.max(0.28, 0.42 - victim.juggle * 0.03)
		elseif airborneBefore then
			lvy = lvy * math.max(0.5, 1 - victim.juggle * 0.08)
		end
		victim.vy = lvy
		victim.vx = away * (hit.launch and hit.launch.vx or 0.06)
		victim.y = math.max(victim.y, 0.05)
		result = "launch"
	elseif hit.knockdown then
		if hit.guard == "low" then
			knockdown(match, victim, "sweep")
			victim.pushV = away * 0.12
		else
			setState(victim, "juggle")
			victim.juggleLocked = true
			victim.vy = 0.3
			victim.vx = away * 0.16
			victim.y = 0.05
		end
		result = "knockdown"
	elseif airborneBefore then
		setState(victim, "juggle")
		victim.vy = 0.25
		victim.vx = away * 0.08
	else
		local hs
		if source == "move" then
			local remaining = (hit.active - (activeIdx or 1)) + hit.recovery
			hs = math.max(8, remaining + (hit.onHit or 2))
		elseif source == "echo" then
			hs = 20 + (hit.onHit or 0)
		else
			hs = math.max(10, hit.onHit or 14)
		end
		setState(victim, "hitstun")
		victim.stun = hs
		victim.pushV = away * (hit.push or 0.2)
		victim.pushSource = attacker
	end

	if meta and meta.pull then
		-- hook: drag the victim toward the owner
		victim.pullTarget = attacker.x + attacker.facing * 1.9
		victim.pullSpeed = meta.pull
	end

	local strength = hit.strength or "medium"
	match.hitstop = math.max(match.hitstop, Config.Hitstop[strength] or 6)
	emit(match, {
		type = "hit",
		attacker = attacker.index,
		victim = victim.index,
		x = hitX,
		y = hitY,
		damage = dmg,
		strength = strength,
		source = source,
		result = result,
		react = react,
		combo = victim.comboHits,
		comboDamage = victim.comboDamage,
		element = hit.element,
		sfx = hit.hitSfx,
		move = hit.id,
	})
	if victim.hp <= 0 then
		victim.hp = 0
		ko(match, victim, attacker)
	end
	return result
end

local function startThrow(match, attacker, victim, move)
	local techable = move.id == "THROW"
	local back = false
	if techable then
		local _, heldBack = relDir(attacker, attacker.input)
		back = heldBack
	end
	setState(attacker, "throwing")
	attacker.throwPartner = victim
	attacker.throwT = 0
	attacker.throwBack = back
	attacker.throwDamage = move.damage
	attacker.throwMove = move.id
	victim.move = nil
	setState(victim, "thrown")
	victim.throwTechable = techable
	victim.throwPartner = attacker
	victim.crouch = false
	victim.vx = 0
	victim.vy = 0
	attacker.stats.throws += 1
	emit(match, { type = "throw", attacker = attacker.index, victim = victim.index, move = move.id, x = victim.x, y = 3 })
end

local function canBeThrown(v): boolean
	local st = v.state
	if isAirborne(v) or v.invuln > 0 then
		return false
	end
	return st == "stand"
		or st == "crouch"
		or st == "block"
		or st == "walk"
		or st == "land"
		or st == "dash"
		or st == "backdash"
		or (st == "attack" and v.move and v.moveT <= v.move.startup and v.move.id ~= "THROW")
end

local function isInvulnerable(f): boolean
	if f.invuln > 0 then
		return true
	end
	if f.state == "attack" and f.move and f.move.invuln then
		local iv = f.move.invuln
		if f.moveT >= iv[1] and f.moveT <= iv[2] then
			return true
		end
	end
	if f.state == "breaker" or f.state == "super" or f.state == "throwing" or f.state == "getup" then
		return true
	end
	if f.juggleLocked and f.state == "juggle" and not f.dying then
		return true
	end
	return false
end
Engine.isInvulnerable = isInvulnerable

-------------------------------------------------------------------------------
-- Fighter physics & move progression
-------------------------------------------------------------------------------

local function stepMove(match, f)
	local m = f.move
	f.moveT += 1
	local t = f.moveT

	-- jump arc
	if m.jumpArc and t == m.jumpArc.frame then
		f.vy = m.jumpArc.vy
		f.vx = f.facing * m.jumpArc.vx
		f.y = math.max(f.y, 0.01)
	end
	-- scripted motion
	local moved = false
	if m.motion then
		for _, seg in m.motion do
			if t >= seg.from and t <= seg.to then
				f.x += f.facing * seg.vx
				if seg.vy then
					f.y = math.max(0, f.y + seg.vy)
					f.vy = 0
				end
				moved = true
			end
		end
	end
	-- teleport
	if m.teleport and t == m.teleport.frame then
		local o = f.opponent
		local dir = sign(o.x - f.x)
		if dir == 0 then
			dir = f.facing
		end
		local tp = m.teleport
		local nx
		if tp.mode == "behind" then
			nx = o.x + dir * (tp.dist or 1.6)
		elseif tp.mode == "front" then
			nx = o.x - dir * (tp.dist or 1.6)
		elseif tp.mode == "above" then
			nx = o.x - dir * (tp.dist or 0.8)
			f.y = 4.6
			f.vy = 0.02
		else
			nx = f.x + f.facing * (tp.dist or 4)
		end
		local lim = Config.StageHalfWidth - 0.6
		if nx > lim or nx < -lim then
			-- no room behind: appear in front instead
			nx = math.clamp(o.x - dir * 1.6, -lim, lim)
		end
		emit(match, { type = "teleport", fighter = f.index, fromX = f.x, fromY = f.y, toX = nx })
		f.x = nx
		faceOpponent(f)
	end
	-- projectile spawn
	if m.projectile then
		local spawnAt = m.projectile.spawnFrame or m.startup
		if t == spawnAt then
			spawnProjectile(match, f, m.projectile, f.x, f.y, f.facing, m.id)
		end
	end
	-- air physics during moves
	if isAirborne(f) and not moved then
		f.vy -= Config.Gravity
		f.y += f.vy
		f.x += f.vx
		if f.y <= 0 then
			f.y = 0
			f.vy = 0
			if m.air then
				local lag = m.landRecovery or 3
				f.move = nil
				setState(f, "land")
				f.landLag = lag
				emit(match, { type = "land", fighter = f.index, x = f.x })
				return
			else
				f.vx = 0
				emit(match, { type = "land", fighter = f.index, x = f.x, heavy = m.jumpArc ~= nil })
			end
		end
	elseif moved and m.air and t > 1 then
		if f.y <= 0.001 then
			f.y = 0
			local lag = m.landRecovery or 3
			f.move = nil
			setState(f, "land")
			f.landLag = lag
			emit(match, { type = "land", fighter = f.index, x = f.x })
			return
		end
	end

	local total = m.startup + m.active + m.recovery
	if m.air then
		-- air moves persist until landing; after their frames finish the fighter just falls
		if t >= total then
			f.move = nil
			setState(f, "air")
		end
		return
	end
	if t >= total then
		endMove(f)
	end
end

local function stepFighter(match, f)
	f.t += 1
	if f.invuln > 0 then
		f.invuln -= 1
	end
	if f.echoCD > 0 and match.phase == "fight" then
		f.echoCD -= 1
	end

	-- pushback slide
	if f.pushV ~= 0 then
		f.x += f.pushV
		f.pushV *= 0.8
		if math.abs(f.pushV) < 0.01 then
			f.pushV = 0
		end
		local lim = Config.StageHalfWidth
		if math.abs(f.x) > lim then
			local over = math.abs(f.x) - lim
			f.x = sign(f.x) * lim
			-- transfer leftover push to the attacker (corner pushback)
			local src = f.pushSource
			if src and src ~= f and not isAirborne(src) then
				src.x -= sign(f.x) * over
			end
			f.pushV = 0
		end
	end
	if f.pullTarget then
		local d = f.pullTarget - f.x
		if math.abs(d) < 0.2 or f.state ~= "hitstun" then
			f.pullTarget = nil
		else
			f.x += math.clamp(d, -f.pullSpeed, f.pullSpeed)
		end
	end

	local st = f.state
	if st == "stand" or st == "walk" then
		if match.phase == "fight" or match.phase == "finish_prompt" then
			local spd = f.walk > 0 and Config.WalkForward or Config.WalkBack
			f.x += f.facing * f.walk * spd * f.def.walkMult
		end
	elseif st == "dash" then
		local k = 1 - f.t / Config.DashFrames
		f.x += f.facing * Config.DashSpeed * math.max(0.2, k) * f.def.walkMult
		if f.t >= Config.DashFrames then
			setState(f, "stand")
		end
	elseif st == "backdash" then
		local k = 1 - f.t / Config.BackdashFrames
		f.x -= f.facing * Config.BackdashSpeed * math.max(0.2, k)
		if f.t >= Config.BackdashFrames then
			setState(f, "stand")
		end
	elseif st == "jumpsquat" then
		if f.t >= Config.JumpSquat then
			setState(f, "air")
			f.vy = Config.JumpVelocity
			f.vx = f.facing * f.jumpDir * Config.JumpForward
			f.y = 0.01
			emit(match, { type = "jump", fighter = f.index, x = f.x })
		end
	elseif st == "air" then
		f.vy -= Config.Gravity
		f.y += f.vy
		f.x += f.vx
		if f.y <= 0 then
			f.y = 0
			f.vy = 0
			f.vx = 0
			setState(f, "land")
			f.landLag = Config.LandingLag
			emit(match, { type = "land", fighter = f.index, x = f.x })
		end
	elseif st == "land" then
		if f.t >= (f.landLag or Config.LandingLag) then
			setState(f, "stand")
		end
	elseif st == "attack" then
		stepMove(match, f)
	elseif st == "hitstun" or st == "blockstun" then
		f.stun -= 1
		if f.stun <= 0 then
			if st == "blockstun" and f.input.B then
				setState(f, "block")
			else
				setState(f, "stand")
			end
		end
	elseif st == "juggle" then
		f.vy -= Config.JuggleGravity
		f.y += f.vy
		f.x += f.vx
		if f.y <= 0 and f.vy < 0 then
			f.y = 0
			if f.dying then
				setState(f, "dead_down")
				emit(match, { type = "knockdown", fighter = f.index, x = f.x, dead = true })
			else
				knockdown(match, f, "back")
			end
		end
	elseif st == "knockdown" then
		if f.t >= Config.KnockdownFrames and match.phase == "fight" then
			setState(f, "getup")
			f.invuln = Config.GetupInvuln
			emit(match, { type = "getup", fighter = f.index })
		end
	elseif st == "getup" then
		if f.t >= Config.GetupFrames then
			setState(f, "stand")
		end
	elseif st == "breaker" then
		if isAirborne(f) then
			f.vy -= Config.Gravity
			f.y = math.max(0, f.y + f.vy)
		end
		if f.t >= 24 and not isAirborne(f) then
			setState(f, "stand")
		end
	elseif st == "throwing" then
		f.throwT += 1
		local v = f.throwPartner
		if v and v.state == "thrown" then
			-- hold the victim in front of us
			v.x = f.x + f.facing * 1.25
			v.y = math.min(2.2, f.throwT * 0.12)
			if f.throwT == 30 then
				v.throwTechable = false
				local dmg = math.floor(f.throwDamage * Config.DamageScale)
				v.hp -= dmg
				f.stats.damage += dmg
				v.comboHits += 1
				v.comboDamage += dmg
				addMeter(f, 14)
				if f.throwBack then
					-- swap sides
					local old = f.x
					f.x = v.x
					v.x = old
					f.facing = -f.facing
				end
				local away = sign(v.x - f.x)
				if away == 0 then
					away = f.facing
				end
				emit(match, {
					type = "hit",
					attacker = f.index,
					victim = v.index,
					x = v.x,
					y = 2,
					damage = dmg,
					strength = "heavy",
					source = "throw",
					result = "knockdown",
					react = "mid",
					combo = v.comboHits,
					comboDamage = v.comboDamage,
					sfx = "throw_slam",
				})
				match.hitstop = 10
				setState(v, "juggle")
				v.juggleLocked = true
				v.vy = 0.22
				v.vx = away * 0.2
				v.y = 0.4
				v.throwPartner = nil
				f.throwPartner = nil
				if v.hp <= 0 then
					v.hp = 0
					ko(match, v, f)
				end
			end
		end
		if f.throwT >= 44 then
			f.throwPartner = nil
			setState(f, "stand")
			faceOpponent(f)
		end
	elseif st == "thrown" then
		if not f.throwPartner then
			setState(f, "stand")
		end
	elseif st == "dead_down" or st == "win" or st == "dazed" or st == "banished" then
		-- idle until the next round
		if isAirborne(f) then
			f.vy -= Config.Gravity
			f.y = math.max(0, f.y + f.vy)
		end
	end

	-- clamp to the arena
	local lim = Config.StageHalfWidth
	f.x = math.clamp(f.x, -lim, lim)
	if f.y < 0 then
		f.y = 0
	end
end

-- Keep fighters from overlapping and from walking past the camera limits.
local function resolvePush(match)
	local a, b = match.fighters[1], match.fighters[2]
	if a.state == "thrown" or b.state == "thrown" then
		return
	end
	if a.state == "knockdown" or b.state == "knockdown" or a.state == "dead_down" or b.state == "dead_down" then
		-- lying fighters can be walked over
		return
	end
	local ha = Config.PushHalfWidth * math.sqrt(a.scale)
	local hb = Config.PushHalfWidth * math.sqrt(b.scale)
	local minD = ha + hb
	local dx = b.x - a.x
	local vOverlap = math.abs((a.y + 2.5) - (b.y + 2.5)) < 4.2
	if math.abs(dx) < minD and vOverlap then
		local dir = sign(dx)
		if dir == 0 then
			dir = a.facing
		end
		local push = (minD - math.abs(dx)) / 2
		a.x -= dir * push
		b.x += dir * push
		local lim = Config.StageHalfWidth
		if math.abs(a.x) > lim then
			local over = math.abs(a.x) - lim
			a.x = sign(a.x) * lim
			b.x += dir * over
		end
		if math.abs(b.x) > lim then
			local over = math.abs(b.x) - lim
			b.x = sign(b.x) * lim
			a.x -= dir * over
		end
	end
	-- maximum separation (camera)
	local sep = math.abs(b.x - a.x)
	if sep > Config.MaxSeparation then
		local over = sep - Config.MaxSeparation
		local dir = sign(b.x - a.x)
		-- pull back whichever moved outward the most this frame (approximate: both share)
		a.x += dir * over / 2
		b.x -= dir * over / 2
	end
end

-------------------------------------------------------------------------------
-- Hit detection
-------------------------------------------------------------------------------

local function checkMoveHits(match)
	local pending = {}
	for _, f in match.fighters do
		local m = f.move
		if f.state == "attack" and m and m.box then
			local t = f.moveT
			if f.moveHitCooldown > 0 then
				f.moveHitCooldown -= 1
			end
			local activeIdx = t - m.startup
			if activeIdx >= 1 and activeIdx <= m.active and f.moveHitCooldown <= 0 then
				local maxHits = m.hits or 1
				local o = f.opponent
				if f.moveHits < maxHits and not f.hitTargets[o.index] then
					local hb = moveHitbox(f, m.box)
					local hurt = hurtbox(o)
					if hurt and overlap(hb, hurt) and not isInvulnerable(o) then
						if m.grab then
							if canBeThrown(o) then
								table.insert(pending, { f = f, o = o, grab = true })
							end
						else
							table.insert(pending, { f = f, o = o, hb = hb, hurt = hurt, idx = activeIdx })
						end
					end
				end
			end
		end
	end
	-- throw vs throw: tech
	if #pending == 2 and pending[1].grab and pending[2].grab then
		for _, p in pending do
			setState(p.f, "blockstun")
			p.f.stun = 16
			p.f.pushV = -p.f.facing * 0.5
			p.f.move = nil
		end
		emit(match, { type = "tech", fighter = 1, x = (match.fighters[1].x + match.fighters[2].x) / 2, y = 3 })
		return
	end
	-- strikes beat throws that start on the same frame
	local striking = {}
	for _, p in pending do
		if not p.grab then
			striking[p.f.index] = true
		end
	end
	-- capture each attacker's move before resolving so simultaneous hits trade
	-- symmetrically (neither player gets priority from processing order)
	for _, p in pending do
		p.move = p.f.move
	end
	for _, p in pending do
		local f, o = p.f, p.o
		local m = p.move
		if p.grab and striking[o.index] then
			continue
		end
		if p.grab and f.state ~= "attack" then
			continue
		end
		if p.grab then
			if o.state == "attack" and o.move and o.move.id == "THROW" and o.moveT <= o.move.startup + o.move.active then
				-- both throwing
				setState(f, "blockstun")
				f.stun = 16
				f.pushV = -f.facing * 0.5
				setState(o, "blockstun")
				o.stun = 16
				o.pushV = -o.facing * 0.5
				emit(match, { type = "tech", fighter = f.index, x = (f.x + o.x) / 2, y = 3 })
			else
				startThrow(match, f, o, m)
			end
		else
			local hx = (math.max(p.hb.cx - p.hb.w / 2, p.hurt.cx - p.hurt.w / 2) + math.min(p.hb.cx + p.hb.w / 2, p.hurt.cx + p.hurt.w / 2)) / 2
			local hy = (math.max(p.hb.cy - p.hb.h / 2, p.hurt.cy - p.hurt.h / 2) + math.min(p.hb.cy + p.hb.h / 2, p.hurt.cy + p.hurt.h / 2)) / 2
			local result = applyHit(match, f, o, m, "move", p.idx, hx, hy)
			if result == "blocked" then
				f.moveBlocked = true
			elseif result == "hit" or result == "launch" or result == "knockdown" then
				f.moveHit = true
				if m.cinematic and match.phase == "fight" and f.state == "attack" and f.move == m then
					-- start the super cinematic
					match.cinematic = {
						attacker = f.index,
						victim = o.index,
						t = 0,
						duration = 150,
						damage = m.damage,
						style = m.cinematic,
					}
					-- the initial contact does no extra damage beyond the first hit's
					setState(f, "super")
					setState(o, "super")
					o.vx, o.vy = 0, 0
					f.y = 0
					o.y = 0
					emit(match, { type = "super_hit", attacker = f.index, victim = o.index, style = m.cinematic })
				end
			end
			if result ~= "parried" then
				f.moveHits += 1
				if m.hits and m.hits > 1 and f.moveHits < m.hits then
					f.moveHitCooldown = m.hitEvery or 3
				else
					f.hitTargets[o.index] = true
				end
			end
		end
	end
end

local function stepProjectiles(match)
	local list = match.projectiles
	for _, p in list do
		if not p.alive then
			continue
		end
		p.t += 1
		if p.delay > 0 then
			p.delay -= 1
			continue
		end
		local d = p.def
		if not d.stationary then
			if d.gravity then
				p.vy -= d.gravity
			end
			p.x += p.vx
			p.y += p.vy
			if d.returns and not p.returned and p.t >= d.life / 2 then
				p.returned = true
				p.vx = -p.vx
				p.hitTargets = nil
				p.hitsLeft = math.max(p.hitsLeft, 1)
			end
		end
		if p.cooldown > 0 then
			p.cooldown -= 1
		end
		if p.t >= p.life + (d.delay or 0) or math.abs(p.x) > Config.StageHalfWidth + 6 or p.y < -2 then
			p.alive = false
			emit(match, { type = "projectile_end", id = p.id, x = p.x, y = p.y, kind = d.kind })
		end
	end
	-- projectile vs projectile clashes
	for i = 1, #list do
		local a = list[i]
		if a.alive and a.delay <= 0 then
			for j = i + 1, #list do
				local b = list[j]
				if b.alive and b.delay <= 0 and a.owner ~= b.owner then
					local ba = { cx = a.x, cy = a.y, w = a.def.box.w, h = a.def.box.h }
					local bb = { cx = b.x, cy = b.y, w = b.def.box.w, h = b.def.box.h }
					if overlap(ba, bb) then
						if not a.def.absorbs then
							a.alive = false
						end
						if not b.def.absorbs then
							b.alive = false
						end
						if a.def.absorbs and b.def.absorbs then
							a.alive, b.alive = false, false
						end
						emit(match, { type = "clash", x = (a.x + b.x) / 2, y = (a.y + b.y) / 2, a = a.id, b = b.id })
					end
				end
			end
		end
	end
	-- projectile vs fighters
	for _, p in list do
		if not p.alive or p.delay > 0 or p.cooldown > 0 then
			continue
		end
		local owner = match.fighters[p.owner]
		local victim = owner.opponent
		if p.hitTargets and p.hitTargets[victim.index] then
			continue
		end
		local hurt = hurtbox(victim)
		if not hurt or isInvulnerable(victim) then
			continue
		end
		local d = p.def
		local box = { cx = p.x, cy = p.y, w = d.box.w, h = d.box.h }
		if overlap(box, hurt) then
			local hit = {
				id = p.source,
				damage = d.damage,
				guard = d.guard or "mid",
				onHit = d.onHit,
				onBlock = d.onBlock,
				launch = d.launch,
				knockdown = d.knockdown,
				push = 0.25,
				strength = d.strength or "special",
				kind = "special",
				element = d.element,
				hitSfx = "projectile_hit",
			}
			local dir = sign(p.vx)
			if dir == 0 then
				dir = sign(victim.x - owner.x)
			end
			local result = applyHit(match, owner, victim, hit, "projectile", nil, p.x, p.y, { dir = dir, pull = d.pull })
			p.hitsLeft -= 1
			if p.hitsLeft <= 0 then
				if not d.stationary or not d.absorbs then
					p.alive = false
				else
					p.hitTargets = p.hitTargets or {}
					p.hitTargets[victim.index] = true
				end
				if d.returns and not p.returned then
					p.alive = false
				end
				emit(match, { type = "projectile_end", id = p.id, x = p.x, y = p.y, kind = d.kind, hit = result })
			else
				p.cooldown = d.hitEvery or 8
			end
		end
	end
	-- prune
	local keep = {}
	for _, p in list do
		if p.alive then
			table.insert(keep, p)
		end
	end
	match.projectiles = keep
end

local function stepEchoes(match)
	local keep = {}
	for _, e in match.echoes do
		local owner = match.fighters[e.owner]
		local m = e.move
		e.t += 1
		-- dispelled if the caller is hit before the echo strikes
		if e.t <= m.startup and (owner.state == "hitstun" or owner.state == "juggle" or owner.state == "thrown") then
			e.alive = false
			emit(match, { type = "echo_vanish", id = e.id, x = e.x, y = 0, dispelled = true })
		end
		if e.alive then
			if m.motion then
				for _, seg in m.motion do
					if e.t >= seg.from and e.t <= seg.to then
						e.x += e.facing * seg.vx
					end
				end
			end
			if m.projectile and e.t == m.startup then
				spawnProjectile(match, owner, m.projectile, e.x, 0, e.facing, m.id)
			end
			if m.box then
				if e.cooldown > 0 then
					e.cooldown -= 1
				end
				local ai = e.t - m.startup
				local maxHits = m.hits or 1
				if ai >= 1 and ai <= m.active and e.hits < maxHits and e.cooldown <= 0 then
					local victim = owner.opponent
					local hb = { cx = e.x + e.facing * m.box.x, cy = m.box.y, w = m.box.w, h = m.box.h }
					local hurt = hurtbox(victim)
					if hurt and overlap(hb, hurt) and not isInvulnerable(victim) then
						local hit = {
							id = m.id,
							damage = m.damage,
							guard = m.guard,
							onHit = m.onHit,
							onBlock = m.onBlock,
							launch = m.launch,
							knockdown = m.knockdown,
							push = m.push,
							strength = m.strength,
							kind = "special",
							element = m.element,
							hitSfx = m.hitSfx,
						}
						applyHit(match, owner, victim, hit, "echo", nil, hb.cx, hb.cy, { dir = e.facing })
						e.hits += 1
						e.cooldown = m.hitEvery or 4
					end
				end
			end
			if e.t >= m.startup + m.active + m.recovery then
				e.alive = false
				emit(match, { type = "echo_vanish", id = e.id, x = e.x, y = 0 })
			end
		end
		if e.alive then
			table.insert(keep, e)
		end
	end
	match.echoes = keep
end

-------------------------------------------------------------------------------
-- Facing & combo bookkeeping
-------------------------------------------------------------------------------

local function updateFacing(match)
	for _, f in match.fighters do
		local st = f.state
		if (st == "stand" or st == "crouch" or st == "block" or st == "land" or st == "walk" or st == "getup") and not isAirborne(f) then
			faceOpponent(f)
		end
	end
end

local function updateCombos(match)
	for _, f in match.fighters do
		local st = f.state
		if not (st == "hitstun" or st == "juggle" or st == "knockdown" or st == "thrown" or st == "super") then
			if f.comboHits > 0 then
				emit(match, { type = "combo_end", victim = f.index, hits = f.comboHits, damage = f.comboDamage })
			end
			f.comboHits = 0
			f.comboDamage = 0
			f.juggle = 0
			f.juggleLocked = false
			f.counterHit = false
		end
	end
end

-------------------------------------------------------------------------------
-- Cinematics
-------------------------------------------------------------------------------

local function stepCinematic(match)
	local c = match.cinematic
	c.t += 1
	local a = match.fighters[c.attacker]
	local v = match.fighters[c.victim]
	if c.t == 118 then
		local dmg = math.floor(c.damage * Config.DamageScale * (v.comboHits > 1 and 0.75 or 1))
		v.hp -= dmg
		v.comboHits += 1
		v.comboDamage += dmg
		a.stats.damage += dmg
		emit(match, {
			type = "hit",
			attacker = a.index,
			victim = v.index,
			x = v.x,
			y = 3,
			damage = dmg,
			strength = "heavy",
			source = "super",
			result = "knockdown",
			react = "mid",
			combo = v.comboHits,
			comboDamage = v.comboDamage,
			sfx = "super_impact",
			element = c.style,
		})
	end
	if c.t >= c.duration then
		match.cinematic = nil
		setState(a, "stand")
		local away = sign(v.x - a.x)
		if away == 0 then
			away = a.facing
		end
		setState(v, "juggle")
		v.juggleLocked = true
		v.vy = 0.36
		v.vx = away * 0.18
		v.y = 0.1
		a.move = nil
		emit(match, { type = "super_end", attacker = a.index, victim = v.index })
		if v.hp <= 0 then
			v.hp = 0
			ko(match, v, a)
		end
	end
end

-------------------------------------------------------------------------------
-- Round / match flow
-------------------------------------------------------------------------------

local INTRO_FRAMES_FIRST = 300
local INTRO_FRAMES = 40
local ROUNDCALL_FRAMES = 110
local KO_FRAMES = 150
local ROUNDWIN_FRAMES = 170
local FINISHER_FRAMES = 360

local function decideTimeOver(match)
	local a, b = match.fighters[1], match.fighters[2]
	local ra, rb = a.hp / a.maxHp, b.hp / b.maxHp
	emit(match, { type = "time_over" })
	if math.abs(ra - rb) < 0.0005 then
		match.roundWinner = 0
		a.roundWins += 1
		b.roundWins += 1
	elseif ra > rb then
		match.roundWinner = 1
		a.roundWins += 1
	else
		match.roundWinner = 2
		b.roundWins += 1
	end
	match.perfect = false
	setPhase(match, "ko")
	match.timeOver = true
end

local function stepFlow(match)
	match.phaseT += 1
	local ph = match.phase
	local a, b = match.fighters[1], match.fighters[2]
	if ph == "intro" then
		local len = match.round == 1 and INTRO_FRAMES_FIRST or INTRO_FRAMES
		if match.opts.shortIntro then
			len = INTRO_FRAMES
		end
		if match.phaseT == 1 and match.round == 1 then
			emit(match, { type = "intro", fighter = 1, line = a.introLine })
		end
		if match.phaseT == math.floor(INTRO_FRAMES_FIRST / 2) and match.round == 1 and not match.opts.shortIntro then
			emit(match, { type = "intro", fighter = 2, line = b.introLine })
		end
		if match.phaseT >= len then
			a.state = "stand"
			b.state = "stand"
			setPhase(match, "roundcall")
		end
	elseif ph == "roundcall" then
		if match.phaseT == 1 then
			emit(match, { type = "round_call", round = match.round })
		end
		if match.phaseT >= ROUNDCALL_FRAMES then
			setPhase(match, "fight")
			emit(match, { type = "fight" })
		end
	elseif ph == "fight" then
		if not match.training then
			if match.timer > 0 then
				match.timer -= 1
				if match.timer <= 0 then
					decideTimeOver(match)
				end
			end
		end
	elseif ph == "ko" then
		local bothSettled = true
		for _, f in match.fighters do
			if f.state == "juggle" or f.state == "attack" or isAirborne(f) or f.state == "super" then
				bothSettled = false
			end
		end
		if match.phaseT >= KO_FRAMES and (bothSettled or match.phaseT > KO_FRAMES + 120) then
			local w = match.roundWinner
			-- stop everything
			for _, f in match.fighters do
				f.move = nil
				if f.state ~= "dead_down" then
					f.state = "stand"
				end
			end
			if w and w > 0 then
				local wf = match.fighters[w]
				setState(wf, "win")
				wf.winQuote = match.rng:int(1, #wf.def.victory)
			end
			setPhase(match, "roundwin")
			emit(match, { type = "round_win", winner = w, round = match.round, perfect = match.perfect, timeOver = match.timeOver })
		end
	elseif ph == "roundwin" then
		if match.phaseT >= ROUNDWIN_FRAMES then
			local winnerIdx = nil
			for _, f in match.fighters do
				if f.roundWins >= match.roundsToWin then
					if winnerIdx and winnerIdx ~= f.index then
						-- double KO / draw at match point: sudden death round
						winnerIdx = nil
						a.roundWins = match.roundsToWin - 1
						b.roundWins = match.roundsToWin - 1
						break
					end
					winnerIdx = f.index
				end
			end
			if winnerIdx then
				match.winner = winnerIdx
				local loser = match.fighters[3 - winnerIdx]
				local wf = match.fighters[winnerIdx]
				if match.opts.noFinisher then
					setPhase(match, "matchend")
					match.over = true
					emit(match, { type = "match_end", winner = winnerIdx })
				else
					-- loser staggers up, dazed
					local keepHp = wf.hp
					resetRound(match)
					wf.hp = math.max(1, keepHp)
					loser.state = "dazed"
					loser.hp = 0
					wf.state = "stand"
					wf.x = loser.index == 1 and 2.6 or -2.6
					loser.x = loser.index == 1 and -2.6 or 2.6
					faceOpponent(wf)
					faceOpponent(loser)
					match.finisher = {
						winner = winnerIdx,
						loser = loser.index,
						triggered = false,
						t = 0,
						style = wf.def.finisher.style,
					}
					setPhase(match, "finish_prompt")
					emit(match, { type = "finish_prompt", winner = winnerIdx })
				end
			else
				match.round += 1
				match.timeOver = false
				resetRound(match)
				setPhase(match, "intro")
			end
		end
	elseif ph == "finish_prompt" then
		local fin = match.finisher
		local w = match.fighters[fin.winner]
		w.x = math.clamp(w.x, -Config.StageHalfWidth, Config.StageHalfWidth)
		if fin.triggered then
			setPhase(match, "finisher")
			local l = match.fighters[fin.loser]
			-- bring the fighters into position
			local dir = sign(l.x - w.x)
			if dir == 0 then
				dir = 1
			end
			w.x = l.x - dir * 2.4
			w.facing = dir
			l.facing = -dir
			setState(w, "finisher")
			setState(l, "dazed")
			w.walk = 0
			emit(match, { type = "finisher_start", winner = fin.winner, loser = fin.loser, style = fin.style })
		elseif match.phaseT >= Config.FinisherWindowSeconds * Config.TickRate then
			local l = match.fighters[fin.loser]
			setState(l, "juggle")
			l.dying = true
			l.juggleLocked = true
			l.vy = 0.2
			l.vx = 0
			l.y = 0.05
			w.walk = 0
			setState(w, "win")
			setPhase(match, "matchend")
			match.over = true
			emit(match, { type = "match_end", winner = fin.winner, finisher = false })
		end
	elseif ph == "finisher" then
		local fin = match.finisher
		fin.t += 1
		if fin.t == 200 then
			local l = match.fighters[fin.loser]
			setState(l, "banished")
			emit(match, { type = "finisher_hit", winner = fin.winner, loser = fin.loser, style = fin.style })
		end
		if fin.t >= FINISHER_FRAMES then
			local w = match.fighters[fin.winner]
			setState(w, "win")
			setPhase(match, "matchend")
			match.over = true
			emit(match, { type = "match_end", winner = fin.winner, finisher = true })
		end
	end
end

-------------------------------------------------------------------------------
-- Training mode helpers
-------------------------------------------------------------------------------

local function stepTraining(match)
	local dummy = match.fighters[2]
	local player = match.fighters[1]
	match.trainingInfinite = true
	for _, f in match.fighters do
		if f.comboHits == 0 and isActionable(f) then
			f.refill = (f.refill or 0) + 1
			if f.refill > Config.TrainingRefillDelay then
				f.hp = math.min(f.maxHp, f.hp + 25)
			end
		else
			f.refill = 0
		end
		if match.trainingMeter ~= false then
			f.meter = Config.MeterMax
		end
	end
	if not dummy.isCPU then
		local mode = match.trainingDummy
		dummy.isDummyBlocking = (mode == "block") and (isActionable(dummy) or dummy.state == "blockstun")
	end
	player.isDummyBlocking = false
end

-------------------------------------------------------------------------------
-- Main step
-------------------------------------------------------------------------------

function Engine.step(match, input1, input2)
	match.frame += 1
	local a, b = match.fighters[1], match.fighters[2]
	readInput(match, a, input1 or NEUTRAL_INPUT)
	readInput(match, b, input2 or NEUTRAL_INPUT)

	if match.superFlash and match.superFlash > 0 then
		match.superFlash -= 1
	end
	if match.slowmo > 0 then
		match.slowmo -= 1
	end

	if match.hitstop > 0 then
		match.hitstop -= 1
		return
	end

	if match.cinematic then
		stepCinematic(match)
		return
	end

	if match.training then
		stepTraining(match)
	end

	think(match, a)
	think(match, b)
	stepFighter(match, a)
	stepFighter(match, b)
	resolvePush(match)
	updateFacing(match)
	if match.phase == "fight" or match.phase == "ko" then
		checkMoveHits(match)
		stepProjectiles(match)
		stepEchoes(match)
	end
	updateCombos(match)
	stepFlow(match)
end

-------------------------------------------------------------------------------
-- Queries used by the renderer / UI / AI
-------------------------------------------------------------------------------

-- Animation descriptor: name and normalised progress within the current action.
function Engine.animState(f)
	local st = f.state
	if st == "attack" and f.move then
		local m = f.move
		return m.anim, f.moveT, m
	end
	return st, f.t, nil
end

function Engine.timerSeconds(match): number
	return math.ceil(match.timer / Config.TickRate)
end

function Engine.isActionable(f): boolean
	return isActionable(f)
end

function Engine.isAirborne(f): boolean
	return isAirborne(f)
end

function Engine.relDir(f, inp)
	return relDir(f, inp)
end

function Engine.resetRound(match)
	resetRound(match)
end

-- Jump straight to the round call (players can skip intros).
function Engine.skipIntro(match)
	if match.phase == "intro" then
		match.phaseT = 100000
	end
end

return Engine
