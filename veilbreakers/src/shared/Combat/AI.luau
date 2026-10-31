--!nonstrict
-- CPU opponent. Produces held-button input tables for the engine, exactly like a
-- human controller would, so the CPU obeys the same frame data and rules.
--
-- The brain perceives the opponent through a reaction-delay buffer, rolls
-- difficulty-scaled chances to block / punish / anti-air, and executes combo routes
-- authored per fighter in Fighters.luau (ai.combos / ai.punish / ai.juggle).

local Config = require(script.Parent.Parent.Config)
local Engine = require(script.Parent.Engine)
local Rng = require(script.Parent.Rng)

local AI = {}
AI.__index = AI

local BTN_FOR = {
	L = { btn = "L" },
	H = { btn = "H" },
	K = { btn = "K" },
	FH = { btn = "H", dir = "f" },
	BK = { btn = "K", dir = "b" },
	DL = { btn = "L", down = true },
	DH = { btn = "H", down = true },
	DK = { btn = "K", down = true },
	JL = { btn = "L" },
	JH = { btn = "H" },
	JK = { btn = "K" },
	SN = { btn = "S" },
	SF = { btn = "S", dir = "f" },
	SB = { btn = "S", dir = "b" },
	SD = { btn = "S", down = true },
	SA = { btn = "S", down = true },
	SUPER = { btn = "X" },
	THROW = { btn = "L", block = true },
}

function AI.new(match, index: number, level: number, seed: number?)
	local self = setmetatable({}, AI)
	self.match = match
	self.index = index
	self.f = match.fighters[index]
	self.o = self.f.opponent
	self.level = math.clamp(level or 2, 1, #Config.Difficulty)
	self.d = Config.Difficulty[self.level]
	self.rng = Rng.new((seed or 99) + index * 7919)
	self.history = {}
	self.btnHold = {}
	self.btnCooldown = {}
	self.moveDir = 0
	self.crouchHold = false
	self.blockHold = false
	self.blockUntil = 0
	self.blockLow = false
	self.decideAt = 0
	self.plan = nil
	self.seenMove = nil
	self.seenProjectiles = {}
	self.breakerRolled = false
	self.techRolled = false
	self.wakeRolled = false
	self.lastPunishRoll = -1
	self.antiAirRolled = false
	self.dummyMode = nil
	return self
end

-------------------------------------------------------------------------------
-- Low level input helpers
-------------------------------------------------------------------------------

function AI:press(btn: string, frames: number?)
	if (self.btnCooldown[btn] or 0) > 0 then
		return false
	end
	self.btnHold[btn] = frames or 2
	return true
end

function AI:distance(): number
	return math.abs(self.o.x - self.f.x)
end

function AI:snapshot()
	local o = self.o
	local m = o.move
	return {
		state = o.state,
		move = m,
		moveT = o.moveT,
		x = o.x,
		y = o.y,
		vy = o.vy,
		airborne = Engine.isAirborne(o),
		frame = self.match.frame,
		moveStart = m and (self.match.frame - o.moveT) or nil,
	}
end

function AI:perceive()
	local delay = self.d.reaction
	local h = self.history
	local idx = #h - delay
	if idx < 1 then
		return h[1]
	end
	return h[idx]
end

-------------------------------------------------------------------------------
-- Plans (combo routes and scripted sequences)
-------------------------------------------------------------------------------

function AI:startCombo(route: { string })
	if not route or #route == 0 then
		return
	end
	local valid = {}
	for _, id in route do
		if self.f.def.moves[id] then
			table.insert(valid, id)
		end
	end
	if #valid == 0 then
		return
	end
	self.plan = { kind = "combo", route = valid, idx = 0, wait = 0, startedAt = self.match.frame }
	self.moveDir = 0
	self.blockHold = false
	self.crouchHold = false
end

function AI:startSequence(steps)
	self.plan = { kind = "seq", steps = steps, idx = 1, t = 0 }
end

function AI:pressMoveInput(id: string): boolean
	local spec = BTN_FOR[id]
	if not spec then
		return false
	end
	if not self:press(spec.btn, 2) then
		return false
	end
	self.heldSpec = {
		dir = spec.dir,
		down = spec.down,
		block = spec.block,
		frames = 4,
	}
	return true
end

-- Returns true while the plan is still driving input.
function AI:runPlan(): boolean
	local plan = self.plan
	if not plan then
		return false
	end
	local f = self.f
	local m = self.match
	if plan.kind == "seq" then
		local step = plan.steps[plan.idx]
		if not step then
			self.plan = nil
			return false
		end
		if plan.t == 0 then
			if step.btn then
				self:press(step.btn, step.frames or 2)
			end
		end
		self.planHold = { dir = step.dir, down = step.down, block = step.block, up = step.up, frames = 1 }
		plan.t += 1
		if plan.t >= (step.frames or 2) then
			plan.idx += 1
			plan.t = 0
		end
		return true
	end

	-- combo route
	if Engine.inHitstun(f) or f.state == "dead_down" or m.phase ~= "fight" then
		self.plan = nil
		return false
	end
	if m.frame - plan.startedAt > 240 then
		self.plan = nil
		return false
	end
	if plan.idx == 0 then
		if Engine.isActionable(f) or f.state == "air" then
			if self:pressMoveInput(plan.route[1]) then
				plan.idx = 1
				plan.pressedAt = m.frame
			end
		end
		return true
	end
	local cur = plan.route[plan.idx]
	local nextId = plan.route[plan.idx + 1]
	if not nextId then
		-- wait for the final move to finish
		if f.state ~= "attack" or (f.move and f.move.id ~= cur) then
			if m.frame - plan.pressedAt > 6 then
				self.plan = nil
				return false
			end
		end
		return true
	end
	if f.state == "attack" and f.move and f.move.id == cur then
		local mv = f.move
		if f.moveT >= mv.startup then
			local contact = f.moveHit or f.moveBlocked
			local isChain = mv.chain ~= nil
			local chainOk = false
			if isChain then
				for _, cid in mv.chain do
					if cid == nextId then
						chainOk = true
					end
				end
			end
			if f.moveBlocked and not f.moveHit then
				-- blocked: smart CPUs stop unsafe follow-ups
				local nextMove = f.def.moves[nextId]
				if nextMove and nextMove.onBlock < -8 and self.rng:chance(self.d.comboSkill * 0.8) then
					self.plan = nil
					return false
				end
			end
			if chainOk or contact then
				if not self.rng:chance(self.d.comboSkill + 0.15) and not plan.rolledDrop then
					plan.rolledDrop = true
					self.plan = nil
					return false
				end
				if self:pressMoveInput(nextId) then
					plan.rolledDrop = false
					plan.idx += 1
					plan.pressedAt = m.frame
					if f.moveHit and mv.launch then
						plan.juggleFrom = plan.idx
					end
				end
			elseif f.moveT > mv.startup + mv.active + 2 then
				self.plan = nil
				return false
			end
		end
		return true
	end
	-- juggle follow-up after a launcher: wait to be actionable and the target in range
	if plan.juggleFrom and Engine.isActionable(f) then
		local o = self.o
		local dist = self:distance()
		if o.state == "juggle" and o.y > 0.6 and o.y < 4.2 and dist < 3.6 then
			if self:pressMoveInput(plan.route[plan.idx]) then
				plan.pressedAt = m.frame
				plan.juggleFrom = nil
			end
			return true
		elseif o.state ~= "juggle" then
			self.plan = nil
			return false
		end
		-- walk in under the falling opponent
		self.moveDir = dist > 2.4 and 1 or 0
		return true
	end
	if m.frame - plan.pressedAt > 14 then
		self.plan = nil
		return false
	end
	return true
end

-------------------------------------------------------------------------------
-- Decision making
-------------------------------------------------------------------------------

local function moveReach(move): number
	if move.projectile then
		return 40
	end
	if not move.box then
		return 0
	end
	local reach = move.box.x + move.box.w / 2
	if move.motion then
		for _, seg in move.motion do
			reach += math.abs(seg.vx) * (seg.to - seg.from + 1)
		end
	end
	if move.teleport then
		reach = 40
	end
	return reach
end

function AI:defend(per)
	-- react to a perceived attack
	local f = self.f
	local frame = self.match.frame
	if not per then
		return
	end
	if per.state == "attack" and per.move and per.moveStart then
		local key = tostring(per.moveStart) .. per.move.id
		if self.seenMove ~= key then
			self.seenMove = key
			local mv = per.move
			if mv.kind == "super" or mv.grab then
				return
			end
			local reach = moveReach(mv) + 1.2
			if self:distance() <= reach + 1.0 then
				local chance = self.d.blockChance
				local sd = f.def.moves.SD
				if sd and sd.parry and mv.guard ~= "low" and Engine.isActionable(f) and self.rng:chance(0.1 + chance * 0.12) then
					-- read the attack and counter it
					self:startCombo({ "SD" })
					return
				end
				if Engine.isActionable(f) or f.state == "attack" and f.moveT < 3 then
					if self.rng:chance(chance) then
						local total = mv.startup + mv.active + mv.recovery
						self.blockUntil = frame + math.max(8, total - (per.moveT or 0)) + 2
						local read = self.rng:chance(0.35 + self.d.blockChance * 0.6)
						if mv.guard == "low" then
							self.blockLow = read
						elseif mv.guard == "overhead" then
							self.blockLow = not read
						else
							self.blockLow = self.rng:chance(0.3)
						end
						self.plan = nil
					end
				end
			end
		end
	end
	-- projectiles
	for _, p in self.match.projectiles do
		if p.owner ~= self.index and not self.seenProjectiles[p.id] then
			local dx = f.x - p.x
			local toward = (p.vx == 0) or (dx * p.vx > 0)
			if toward and math.abs(dx) < 9 then
				self.seenProjectiles[p.id] = true
				if self.rng:chance(self.d.blockChance) then
					local g = p.def.guard
					local roll = self.rng:next()
					if roll < 0.25 and Engine.isActionable(f) and p.def.ground ~= true and math.abs(dx) > 4 then
						-- jump over it
						self:startSequence({ { up = true, dir = "f", frames = 3 } })
					else
						self.blockUntil = frame + math.floor(math.abs(dx) / math.max(0.2, math.abs(p.vx))) + 10
						self.blockLow = g == "low"
					end
				end
			end
		end
	end
end

function AI:offense(per)
	local f = self.f
	local o = self.o
	local d = self.d
	local ai = f.def.ai
	local dist = self:distance()
	local frame = self.match.frame

	-- punish recovery
	if per and per.state == "attack" and per.move and per.move.kind ~= "super" then
		local mv = per.move
		local remaining = (mv.startup + mv.active + mv.recovery) - (per.moveT or 0)
		if per.moveT > mv.startup + mv.active and remaining > 8 and dist < 3.8 then
			if self.lastPunishRoll ~= per.moveStart then
				self.lastPunishRoll = per.moveStart
				if self.rng:chance(d.punishChance) then
					if f.meter >= Config.SuperCost and self.rng:chance(d.superChance * 0.5) then
						self:startCombo({ "SUPER" })
					else
						self:startCombo(ai.punish)
					end
					return
				end
			end
		end
	end
	-- anti-air
	if per and per.airborne and o.state == "air" then
		if not self.antiAirRolled and dist < 4.6 and o.y < 4.5 and o.vy < 0.2 then
			self.antiAirRolled = true
			if self.rng:chance(d.antiAirChance) then
				self:startCombo({ ai.antiAir })
				return
			else
				self.blockUntil = frame + 14
				self.blockLow = false
				return
			end
		end
	else
		self.antiAirRolled = false
	end

	if frame < self.decideAt then
		return
	end
	self.decideAt = frame + math.floor(d.reaction * 0.8) + self.rng:int(2, 10)

	-- super
	if f.meter >= Config.SuperCost and dist < 3.0 and self.rng:chance(d.superChance * 0.12) then
		self:startCombo({ "SUPER" })
		return
	end

	-- echo usage
	if f.echoCD <= 0 and self.rng:chance(0.08 + d.aggression * 0.1) then
		local down = self.rng:chance(0.4)
		self:startSequence({ { btn = "E", down = down, frames = 2 } })
		return
	end

	local range = ai.range
	local roll = self.rng:next()
	local ownProjectile = false
	for _, p in self.match.projectiles do
		if p.owner == self.index then
			ownProjectile = true
		end
	end
	local canZone = ai.projectile ~= nil and not ownProjectile and frame - (self.lastZone or -999) > 70
	if dist > range + 3 then
		-- far away: approach or zone
		if canZone and self.rng:chance(ai.zoning * 0.75) then
			self.lastZone = frame
			self:startCombo({ ai.projectile })
		elseif ai.approach and dist < range + 8 and self.rng:chance(0.18 + d.aggression * 0.2) then
			self:startCombo({ ai.approach })
		elseif roll < 0.2 + d.aggression * 0.15 then
			-- dash in
			self:startSequence({ { dir = "f", frames = 2 }, { frames = 2 }, { dir = "f", frames = 3 } })
		elseif roll < 0.4 then
			self:startSequence({ { up = true, dir = "f", frames = 3 } })
		else
			self.moveDir = 1
		end
		return
	end

	if dist < range - 1.8 and range > 4 then
		-- zoner too close: escape
		if roll < 0.3 then
			self:startSequence({ { dir = "b", frames = 2 }, { frames = 2 }, { dir = "b", frames = 3 } })
		elseif roll < 0.55 then
			self:startCombo(self.rng:pick(ai.combos))
		elseif f.def.moves.SB and f.def.moves.SB.motion and f.def.moves.SB.motion[1].vx < 0 and roll < 0.7 then
			self:startCombo({ "SB" })
		else
			self.moveDir = -1
		end
		return
	end

	-- in range: choose an option weighted by aggression
	if self.rng:chance(d.aggression) then
		local r = self.rng:next()
		if dist < 2.9 then
			if r < 0.45 then
				self:startCombo(self.rng:pick(ai.combos))
			elseif r < 0.72 then
				local mix = self.rng:pick(ai.mixups)
				self:startCombo({ mix })
			elseif r < 0.88 then
				self:startCombo({ self.rng:pick(ai.pokes) })
			else
				self.moveDir = -1
			end
		else
			if r < 0.38 then
				self:startCombo({ self.rng:pick(ai.pokes) })
			elseif r < 0.52 and ai.approach then
				self:startCombo({ ai.approach })
			elseif r < 0.64 and canZone then
				self.lastZone = frame
				self:startCombo({ ai.projectile })
			elseif r < 0.74 then
				self:startSequence({ { up = true, dir = "f", frames = 3 } })
			else
				self.moveDir = 1
			end
		end
	else
		local r = self.rng:next()
		if r < 0.3 then
			self.blockUntil = frame + self.rng:int(10, 26)
			self.blockLow = self.rng:chance(0.5)
		elseif r < 0.45 then
			self.moveDir = -1
		elseif r < 0.85 then
			self.moveDir = 1
		else
			self.moveDir = 0
		end
	end
end

function AI:reactInHitstun()
	local f = self.f
	if f.state == "hitstun" or f.state == "juggle" then
		if not self.breakerRolled and f.comboHits >= 3 and f.meter >= Config.BreakerCost then
			self.breakerRolled = true
			if self.rng:chance(self.d.breakerChance) then
				self:press("X", 2)
			end
		end
	else
		self.breakerRolled = false
	end
	if f.state == "thrown" and f.throwTechable then
		if not self.techRolled then
			self.techRolled = true
			if self.rng:chance(self.d.techChance) then
				self:startSequence({ { frames = 2 }, { btn = "L", block = true, frames = 2 } })
			end
		end
	else
		self.techRolled = false
	end
	if f.state == "knockdown" or f.state == "getup" then
		if not self.wakeRolled then
			self.wakeRolled = true
			local r = self.rng:next()
			if r < 0.35 then
				self.blockUntil = self.match.frame + 40 + Config.KnockdownFrames - f.t
				self.blockLow = self.rng:chance(0.5)
			end
		end
	else
		self.wakeRolled = false
	end
end

-------------------------------------------------------------------------------
-- Frame output
-------------------------------------------------------------------------------

function AI:getInput()
	local m = self.match
	local f = self.f
	table.insert(self.history, self:snapshot())
	if #self.history > 90 then
		table.remove(self.history, 1)
	end

	self.planHold = nil
	local inp = table.clone(Engine.NeutralInput)
	if self.heldSpec then
		self.heldSpec.frames -= 1
		if self.heldSpec.frames <= 0 then
			self.heldSpec = nil
		end
	end

	if m.phase == "finish_prompt" and m.finisher and m.finisher.winner == self.index then
		-- CPU finishes you off more often at higher difficulties
		if m.phaseT > 70 and self.rng:chance(0.04 * self.level) then
			inp.down = true
			self:press("S", 2)
		end
	end

	if m.phase == "fight" then
		if self.dummyMode == "stand" then
			return inp
		end
		local per = self:perceive()
		self:reactInHitstun()
		if not self.plan or self.plan.kind ~= "combo" or self.plan.idx == 0 then
			self:defend(per)
		end
		local planActive = self:runPlan()
		if not planActive and Engine.isActionable(f) and m.frame >= self.blockUntil then
			self:offense(per)
			self:runPlan()
		end
	else
		self.plan = nil
		self.moveDir = 0
		self.blockUntil = 0
	end

	-- compose held input
	local facing = f.facing
	local function holdDir(dir)
		if dir == "f" then
			if facing == 1 then
				inp.right = true
			else
				inp.left = true
			end
		elseif dir == "b" then
			if facing == 1 then
				inp.left = true
			else
				inp.right = true
			end
		end
	end

	local blocking = m.frame < self.blockUntil and not self.plan
	if blocking then
		inp.B = true
		inp.down = self.blockLow
	elseif self.planHold or self.heldSpec then
		local hold = self.planHold or self.heldSpec
		holdDir(hold.dir)
		if hold.down then
			inp.down = true
		end
		if hold.block then
			inp.B = true
		end
		if hold.up then
			inp.up = true
		end
	elseif m.phase == "fight" and not self.plan then
		if self.moveDir == 1 then
			holdDir("f")
		elseif self.moveDir == -1 then
			holdDir("b")
		end
	end

	for btn, n in self.btnHold do
		if n > 0 then
			inp[btn] = true
			self.btnHold[btn] = n - 1
			if n - 1 <= 0 then
				self.btnCooldown[btn] = 2
			end
		end
	end
	for btn, n in self.btnCooldown do
		if n > 0 then
			self.btnCooldown[btn] = n - 1
		end
	end
	-- never press block together with a button unless it is a throw / tech
	return inp
end

return AI
