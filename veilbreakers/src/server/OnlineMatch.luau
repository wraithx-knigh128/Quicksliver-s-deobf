--!nonstrict
-- Online 1v1, server authoritative.
--
-- The server runs the real match with the same deterministic engine the clients
-- use. Each client sends its controller state; every tick the server resolves both
-- players' inputs, steps the engine, and streams the resolved inputs (one integer
-- per player per frame) back to both clients. Clients replay exactly those frames
-- through their own copy of the engine, so they render the authoritative fight with
-- full animation and effects from a few bytes per frame. The engine uses only
-- deterministic arithmetic, and the server also sends periodic state checks that
-- clients correct against. Results and rewards come only from the server's match.
--
-- Map choice: each player picks a map; if they differ the server flips a coin
-- between the two picks. The weather / time-of-day variant is rolled every fight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Veil = ReplicatedStorage:WaitForChild("Veil")
local Engine = require(Veil.Combat.Engine)
local NetInput = require(Veil.Combat.NetInput)
local Fighters = require(Veil.Data.Fighters)
local Echoes = require(Veil.Data.Echoes)
local Stages = require(Veil.Data.Stages)
local StageVariants = require(Veil.Data.StageVariants)
local Items = require(Veil.Data.Items)

local Inventory = require(script.Parent.Inventory)

local OnlineMatch = {}
OnlineMatch.__index = OnlineMatch

local DT = 1 / 60
local CHALLENGE_TTL = 25
local READY_TIMEOUT = 15
local SEND_EVERY = 2 -- frames per packet
local SYNC_EVERY = 120 -- frames between state checks
local MIN_FRAMES_FOR_FORFEIT_REWARD = 60 * 20

-- deps: getProfile(p), send(p, msg), save(p), now(), rand() -> [0,1), log?(msg)
function OnlineMatch.new(deps)
	local self = setmetatable({}, OnlineMatch)
	self.deps = deps
	self.queue = {}
	self.challenges = {} -- [target] = { [from] = { pick, expires } }
	self.matches = {}
	self.byPlayer = {}
	self.pairLog = {} -- "a:b" -> { timestamps }
	self.nextId = 1
	return self
end

function OnlineMatch:isBusy(p): boolean
	return self.byPlayer[p] ~= nil
end

function OnlineMatch:isQueued(p): boolean
	for _, q in self.queue do
		if q.player == p then
			return true
		end
	end
	return false
end

-- Validate a player's pick. Practice room is not an online arena.
function OnlineMatch.validatePick(pick)
	if type(pick) ~= "table" then
		return nil
	end
	local f = type(pick.fighter) == "string" and Fighters.byId[pick.fighter]
	local e = type(pick.echo) == "string" and Echoes.get(pick.echo)
	local ok, s = pcall(Stages.get, pick.stage)
	if not f or not e or e.id ~= pick.echo or not ok or not s or s.id ~= pick.stage or s.id == "proving" then
		return nil
	end
	return { fighter = f.id, echo = e.id, stage = s.id }
end

function OnlineMatch:queuePlayer(p, pick)
	local clean = OnlineMatch.validatePick(pick)
	if not clean then
		return false, "bad pick"
	end
	if self:isBusy(p) then
		return false, "already in a match"
	end
	self:unqueue(p)
	table.insert(self.queue, { player = p, pick = clean, t = self.deps.now() })
	self.deps.send(p, { op = "queued", size = #self.queue })
	-- pair the two longest-waiting players
	while #self.queue >= 2 do
		local a = table.remove(self.queue, 1)
		local b = table.remove(self.queue, 1)
		if a.player.Parent and b.player.Parent then
			self:createMatch(a.player, a.pick, b.player, b.pick)
		elseif a.player.Parent then
			table.insert(self.queue, 1, a)
		elseif b.player.Parent then
			table.insert(self.queue, 1, b)
		end
	end
	return true
end

function OnlineMatch:unqueue(p)
	for i = #self.queue, 1, -1 do
		if self.queue[i].player == p then
			table.remove(self.queue, i)
		end
	end
end

function OnlineMatch:challenge(from, target, pick)
	local clean = OnlineMatch.validatePick(pick)
	if not clean then
		return false, "bad pick"
	end
	if from == target or not target or not target.Parent then
		return false, "can't challenge that player"
	end
	if self:isBusy(from) or self:isBusy(target) then
		return false, "player is in a match"
	end
	self.challenges[target] = self.challenges[target] or {}
	self.challenges[target][from] = { pick = clean, expires = self.deps.now() + CHALLENGE_TTL }
	local s = Stages.get(clean.stage)
	self.deps.send(target, { op = "challenge", from = from.UserId, name = from.DisplayName, stage = clean.stage, stageName = s.name, fighter = clean.fighter })
	return true
end

function OnlineMatch:respond(target, from, accept: boolean, pick)
	local list = self.challenges[target]
	local c = list and list[from]
	if not c or c.expires < self.deps.now() then
		return false, "challenge expired"
	end
	list[from] = nil
	if not accept then
		self.deps.send(from, { op = "declined", by = target.UserId, name = target.DisplayName })
		return true
	end
	local clean = OnlineMatch.validatePick(pick)
	if not clean then
		return false, "bad pick"
	end
	if self:isBusy(from) or self:isBusy(target) or not from.Parent then
		return false, "player is busy"
	end
	self:unqueue(from)
	self:unqueue(target)
	self:createMatch(from, c.pick, target, clean)
	return true
end

local function playerSpec(p, pick, profile)
	return {
		userId = p.UserId,
		name = p.DisplayName,
		fighter = pick.fighter,
		echo = pick.echo,
		cosmetic = profile and Inventory.cosmeticFor(profile.inv, pick.fighter) or nil,
	}
end

function OnlineMatch:createMatch(pa, pickA, pb, pickB)
	local rand = self.deps.rand
	local stage = pickA.stage
	local pickedBy = pa
	if pickB.stage ~= pickA.stage and rand() < 0.5 then
		stage = pickB.stage
		pickedBy = pb
	end
	local spec = {
		id = self.nextId,
		seed = math.floor(rand() * 1000000),
		stage = stage,
		stagePickedBy = pickedBy.DisplayName,
		variant = StageVariants.roll(stage, rand()),
		p1 = playerSpec(pa, pickA, self.deps.getProfile(pa)),
		p2 = playerSpec(pb, pickB, self.deps.getProfile(pb)),
	}
	self.nextId += 1
	local m = {
		id = spec.id,
		spec = spec,
		players = { pa, pb },
		state = "loading",
		ready = { false, false },
		createdAt = self.deps.now(),
		engine = Engine.newMatch(OnlineMatch.engineOpts(spec)),
		acc = 0,
		held = { 0, 0 },
		pending = { 0, 0 },
		out = {},
		sentFrame = 0,
		inputCount = { 0, 0 },
		inputWindow = self.deps.now(),
	}
	self.matches[m.id] = m
	self.byPlayer[pa] = m
	self.byPlayer[pb] = m
	for side, p in m.players do
		self.deps.send(p, { op = "start", spec = spec, side = side })
	end
	return m
end

-- The exact options both server and clients pass to Engine.newMatch.
function OnlineMatch.engineOpts(spec)
	return {
		p1 = { fighter = spec.p1.fighter, echo = spec.p1.echo },
		p2 = { fighter = spec.p2.fighter, echo = spec.p2.echo },
		stage = spec.stage,
		seed = spec.seed,
	}
end

function OnlineMatch:setReady(p, matchId)
	local m = self.byPlayer[p]
	if not m or m.id ~= matchId or m.state ~= "loading" then
		return false
	end
	local side = m.players[1] == p and 1 or 2
	m.ready[side] = true
	if m.ready[1] and m.ready[2] then
		m.state = "running"
		for _, pl in m.players do
			self.deps.send(pl, { op = "go", id = m.id })
		end
	end
	return true
end

-- Controller state from a client: held mask + buttons pressed since its last send.
function OnlineMatch:input(p, held, pressed)
	local m = self.byPlayer[p]
	if not m or m.state ~= "running" then
		return false
	end
	if not NetInput.valid(held) or not NetInput.valid(pressed) then
		return false
	end
	local side = m.players[1] == p and 1 or 2
	-- rate limit: 120 messages per second per player
	local now = self.deps.now()
	if now - m.inputWindow >= 1 then
		m.inputWindow = now
		m.inputCount = { 0, 0 }
	end
	m.inputCount[side] += 1
	if m.inputCount[side] > 120 then
		return false
	end
	m.held[side] = held
	m.pending[side] = NetInput.union(m.pending[side], pressed)
	return true
end

function OnlineMatch:flush(m)
	if #m.out == 0 then
		return
	end
	local msg = { op = "f", id = m.id, from = m.sentFrame + 1, m = m.out }
	for _, p in m.players do
		if p.Parent then
			self.deps.send(p, msg)
		end
	end
	m.sentFrame += #m.out // 2
	m.out = {}
end

local function pairKey(a, b)
	local x, y = a.UserId, b.UserId
	if x > y then
		x, y = y, x
	end
	return x .. ":" .. y
end

function OnlineMatch:finish(m, winnerSide: number?, reason: string)
	if m.state == "over" then
		return
	end
	self:flush(m)
	m.state = "over"
	local now = self.deps.now()
	-- anti win-trading: limited rewarded matches per pair per hour
	local key = pairKey(m.players[1], m.players[2])
	local log = self.pairLog[key] or {}
	for i = #log, 1, -1 do
		if now - log[i] > 3600 then
			table.remove(log, i)
		end
	end
	local rewarded = #log < Items.PairRewardsPerHour
	if reason ~= "ko" and m.engine.frame < MIN_FRAMES_FOR_FORFEIT_REWARD then
		rewarded = false
	end
	if rewarded then
		table.insert(log, now)
	end
	self.pairLog[key] = log
	for side, p in m.players do
		local prof = self.deps.getProfile(p)
		local won = winnerSide == side
		local rewards = { res = {} }
		local newWeapon = nil
		if prof then
			if won then
				prof.stats.onlineWins = (prof.stats.onlineWins or 0) + 1
			elseif winnerSide then
				prof.stats.onlineLosses = (prof.stats.onlineLosses or 0) + 1
			end
			if rewarded and winnerSide then
				local fighterId = side == 1 and m.spec.p1.fighter or m.spec.p2.fighter
				rewards = Inventory.rollRewards(won and Items.Rewards.onlineWin or Items.Rewards.onlineLoss, self.deps.rand, Inventory.bonusFor(prof.inv, fighterId))
				newWeapon = Inventory.applyRewards(prof.inv, p.UserId, rewards)
			end
		end
		if p.Parent then
			local f = m.engine.fighters
			self.deps.send(p, {
				op = "end",
				id = m.id,
				winner = winnerSide,
				side = side,
				reason = reason,
				rounds = { f[1].roundWins, f[2].roundWins },
				stats = { f[1].stats, f[2].stats },
				rewards = rewards.res,
				bonus = rewards.bonus,
				weapon = newWeapon and { uid = newWeapon.uid, item = newWeapon.item } or nil,
				rewarded = rewarded,
				inv = prof and Inventory.snapshot(prof.inv) or nil,
			})
			self.deps.save(p)
		end
		self.byPlayer[p] = nil
	end
	self.matches[m.id] = nil
	if self.deps.log then
		self.deps.log(string.format("match %d over: winner side %s (%s)", m.id, tostring(winnerSide), reason))
	end
end

-- Step every running match by real time.
function OnlineMatch:tick(dt: number)
	local now = self.deps.now()
	for _, m in self.matches do
		if m.state == "loading" then
			if now - m.createdAt > READY_TIMEOUT then
				for _, p in m.players do
					self.byPlayer[p] = nil
					if p.Parent then
						self.deps.send(p, { op = "cancelled", id = m.id, reason = "the other player didn't load in" })
					end
				end
				self.matches[m.id] = nil
			end
			continue
		end
		if m.state ~= "running" then
			continue
		end
		-- KO slow motion plays at the same pace the clients show it
		local scale = ((m.engine.slowmo or 0) > 0) and 0.35 or 1
		m.acc += math.min(dt, 0.25) * scale
		local steps = 0
		while m.acc >= DT and steps < 6 do
			m.acc -= DT
			steps += 1
			local in1 = NetInput.union(m.held[1], m.pending[1])
			local in2 = NetInput.union(m.held[2], m.pending[2])
			m.pending[1], m.pending[2] = 0, 0
			Engine.step(m.engine, NetInput.decode(in1), NetInput.decode(in2))
			Engine.drainEvents(m.engine)
			table.insert(m.out, in1)
			table.insert(m.out, in2)
			local frame = m.engine.frame
			if #m.out >= SEND_EVERY * 2 then
				self:flush(m)
			end
			if frame % SYNC_EVERY == 0 then
				self:flush(m)
				local f1, f2 = m.engine.fighters[1], m.engine.fighters[2]
				local sync = { op = "sync", id = m.id, frame = frame, hp = { f1.hp, f2.hp }, x = { f1.x, f2.x }, y = { f1.y, f2.y }, meter = { f1.meter, f2.meter }, timer = m.engine.timer, wins = { f1.roundWins, f2.roundWins } }
				for _, p in m.players do
					if p.Parent then
						self.deps.send(p, sync)
					end
				end
			end
			if m.engine.over then
				self:finish(m, m.engine.winner, "ko")
				break
			end
		end
		if m.acc > DT * 6 then
			m.acc = 0 -- server hitch: don't spiral
		end
	end
	-- expire challenges
	for target, list in self.challenges do
		for from, c in list do
			if c.expires < now then
				list[from] = nil
			end
		end
		if next(list) == nil then
			self.challenges[target] = nil
		end
	end
end

function OnlineMatch:forfeit(p, reason: string?)
	local m = self.byPlayer[p]
	if not m then
		return false
	end
	if m.state == "loading" then
		for _, pl in m.players do
			self.byPlayer[pl] = nil
			if pl.Parent and pl ~= p then
				self.deps.send(pl, { op = "cancelled", id = m.id, reason = "the other player backed out" })
			end
		end
		self.matches[m.id] = nil
		return true
	end
	local side = m.players[1] == p and 1 or 2
	self:finish(m, 3 - side, reason or "forfeit")
	return true
end

function OnlineMatch:playerLeft(p)
	self:unqueue(p)
	self:forfeit(p, "disconnect")
	self.challenges[p] = nil
	for _, list in self.challenges do
		list[p] = nil
	end
end

return OnlineMatch
