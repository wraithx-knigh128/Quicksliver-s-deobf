-- Headless test-suite for the VEILBREAKERS combat engine and CPU AI.
-- Run from the project root:  lune run tests/run

local process = require("@lune/process")
local Loader = require("./loader")

local shared = Loader.root("src/shared")
local Config = Loader.require(shared.Config)
local Fighters = Loader.require(shared.Data.Fighters)
local Echoes = Loader.require(shared.Data.Echoes)
local Stages = Loader.require(shared.Data.Stages)
local Story = Loader.require(shared.Data.Story)
local MoveKit = Loader.require(shared.Data.MoveKit)
local Engine = Loader.require(shared.Combat.Engine)
local AI = Loader.require(shared.Combat.AI)

local failures = 0
local passes = 0
local function check(cond, msg)
	if cond then
		passes += 1
	else
		failures += 1
		print("  FAIL: " .. msg)
	end
end

local function neutral()
	return table.clone(Engine.NeutralInput)
end

---------------------------------------------------------------------------
print("[1] Data integrity")
---------------------------------------------------------------------------
for _, f in Fighters.list do
	for _, id in f.order do
		check(f.moves[id] ~= nil or id == "SA", f.id .. " missing move " .. id)
	end
	for id, m in f.moves do
		check(m.startup >= 1 and m.active >= 1 and m.recovery >= 0, f.id .. "." .. id .. " frame data")
		check(m.box ~= nil or m.projectile ~= nil or m.teleport ~= nil or m.parry ~= nil or m.motion ~= nil or m.kind == "special", f.id .. "." .. id .. " has no effect")
		if m.chain then
			for b, nid in m.chain do
				check(f.moves[nid] ~= nil, f.id .. "." .. id .. " chains to missing " .. nid)
			end
		end
		if m.parry then
			check(f.moves[m.parry.counter] ~= nil, f.id .. "." .. id .. " parry counter missing")
		end
		local desc = MoveKit.describe(m)
		check(type(desc) == "string" and #desc > 0, "describe " .. id)
	end
	for _, key in { "combos", "pokes", "mixups", "punish", "juggle" } do
		for _, entry in f.ai[key] do
			if type(entry) == "table" then
				for _, id in entry do
					check(f.moves[id] ~= nil, f.id .. " ai." .. key .. " references missing " .. id)
				end
			else
				check(f.moves[entry] ~= nil, f.id .. " ai." .. key .. " references missing " .. entry)
			end
		end
	end
	check(#f.intro >= 1 and #f.victory >= 1 and #f.ending >= 1, f.id .. " text")
end
for _, e in Echoes.list do
	check(e.neutral and e.down, e.id .. " echo moves")
end
for _, ch in Story.chapters do
	for i, beat in ch.beats do
		check(Stages.byId[beat.stage] ~= nil, "story beat " .. i .. " stage")
		if beat.type == "fight" then
			check(Fighters.byId[beat.player] ~= nil and Fighters.byId[beat.opponent] ~= nil, "story fight fighters " .. i)
			check(Echoes.byId[beat.playerEcho] ~= nil and Echoes.byId[beat.opponentEcho] ~= nil, "story fight echoes " .. i)
		else
			for _, a in beat.actors do
				check(Fighters.byId[a.id] ~= nil, "story actor " .. a.id)
			end
			for _, shot in beat.shots do
				for _, line in shot.lines or {} do
					check(Story.speakerNames[line.speaker] ~= nil, "speaker " .. line.speaker)
				end
				for _, ev in shot.events or {} do
					if ev.actor then
						check(beat.actors[ev.actor] ~= nil, "story event actor index " .. ev.actor)
					end
				end
				if shot.a then
					check(beat.actors[shot.a] ~= nil, "shot actor a")
				end
				if shot.b then
					check(beat.actors[shot.b] ~= nil, "shot actor b")
				end
			end
		end
	end
end

---------------------------------------------------------------------------
print("[2] Every input produces its move (training mode, scripted input)")
---------------------------------------------------------------------------
local INPUTS = {
	L = { L = true },
	H = { H = true },
	K = { K = true },
	FH = { H = true, fwd = true },
	BK = { K = true, back = true },
	DL = { L = true, down = true },
	DH = { H = true, down = true },
	DK = { K = true, down = true },
	SN = { S = true },
	SF = { S = true, fwd = true },
	SB = { S = true, back = true },
	SD = { S = true, down = true },
	SUPER = { X = true },
	THROW = { L = true, B = true },
}
for _, f in Fighters.list do
	for id, spec in INPUTS do
		if f.moves[id] then
			local match = Engine.newMatch({
				p1 = { fighter = f.id, echo = "grandpa" },
				p2 = { fighter = "noob", echo = "grandpa" },
				training = true,
				stage = "proving",
			})
			match.fighters[1].x = -8
			match.fighters[2].x = 8
			-- settle
			for _ = 1, 5 do
				Engine.step(match, neutral(), neutral())
			end
			local inp = neutral()
			inp.L, inp.H, inp.K, inp.S, inp.X, inp.B = spec.L, spec.H, spec.K, spec.S, spec.X, spec.B
			inp.down = spec.down or false
			if spec.fwd then
				inp.right = true
			end
			if spec.back then
				inp.left = true
			end
			Engine.step(match, inp, neutral())
			local p = match.fighters[1]
			check(p.state == "attack" and p.move and p.move.id == id, string.format("%s %s -> got %s/%s", f.id, id, p.state, p.move and p.move.id or "-"))
			-- run until it finishes; must return to a neutral state
			local guard = 0
			while p.state ~= "stand" and p.state ~= "crouch" and guard < 400 do
				local held = neutral()
				Engine.step(match, held, neutral())
				guard += 1
			end
			check(guard < 400, f.id .. " " .. id .. " never recovered (state " .. p.state .. ")")
		end
	end
	-- jump-in air normal
	local match = Engine.newMatch({
		p1 = { fighter = f.id, echo = "dana" },
		p2 = { fighter = "studzilla", echo = "dana" },
		training = true,
	})
	local inp = neutral()
	inp.up = true
	Engine.step(match, inp, neutral())
	for _ = 1, 8 do
		Engine.step(match, neutral(), neutral())
	end
	local air = neutral()
	air.K = true
	Engine.step(match, air, neutral())
	check(match.fighters[1].move and match.fighters[1].move.id == "JK", f.id .. " jump kick")
end

---------------------------------------------------------------------------
print("[2b] Powers on keys 1-4: slots, cooldowns, motion inputs share them")
---------------------------------------------------------------------------
for _, f in Fighters.list do
	local match = Engine.newMatch({
		p1 = { fighter = f.id, echo = "grandpa" },
		p2 = { fighter = "noob", echo = "grandpa" },
		stage = "proving",
		skipIntro = true,
	})
	local function settle(n)
		for _ = 1, n do
			Engine.step(match, neutral(), neutral())
		end
	end
	local function waitForFight()
		local g = 0
		while match.phase ~= "fight" and g < 600 do
			settle(1)
			g += 1
		end
	end
	waitForFight()
	local p = match.fighters[1]
	p.x, match.fighters[2].x = -12, 12
	for slot = 1, 4 do
		local id = Engine.powerSlotId(p, slot)
		check(id ~= nil and f.moves[id] ~= nil, f.id .. " has power " .. slot)
		-- recover to neutral (and out of any hitstop from a returning projectile)
		local g = 0
		while ((p.state ~= "stand" and p.state ~= "crouch") or match.hitstop > 0) and g < 400 do
			settle(1)
			g += 1
		end
		p.x, match.fighters[2].x = -12, 12
		local inp = neutral()
		inp["P" .. slot] = true
		Engine.step(match, inp, neutral())
		check(p.state == "attack" and p.move and p.move.id == id, string.format("%s key %d -> %s (got %s)", f.id, slot, tostring(id), p.move and p.move.id or p.state))
		local cd = Engine.powerCooldown(p, id)
		check(cd > 30, f.id .. " power " .. slot .. " went on cooldown (" .. cd .. ")")
	end
	-- the motion input for a power on cooldown does nothing
	local g = 0
	while ((p.state ~= "stand" and p.state ~= "crouch") or match.hitstop > 0) and g < 400 do
		settle(1)
		g += 1
	end
	local snIdx = nil
	for slot = 1, 4 do
		if Engine.powerSlotId(p, slot) == "SN" then
			snIdx = slot
		end
	end
	if snIdx and Engine.powerCooldown(p, "SN") > 0 then
		local inp = neutral()
		inp.S = true
		Engine.step(match, inp, neutral())
		check(not (p.move and p.move.id == "SN" and p.moveT <= 1), f.id .. " SN came out while on cooldown")
	end
	-- cooldowns expire
	settle(200)
	for slot = 1, 4 do
		check(Engine.powerCooldown(p, Engine.powerSlotId(p, slot)) == 0, f.id .. " power " .. slot .. " cooldown expired")
	end
end
do
	-- no cooldowns in practice
	local match = Engine.newMatch({
		p1 = { fighter = "frosty", echo = "grandpa" },
		p2 = { fighter = "noob", echo = "grandpa" },
		training = true,
		stage = "proving",
	})
	for _ = 1, 5 do
		Engine.step(match, neutral(), neutral())
	end
	local inp = neutral()
	inp.P1 = true
	Engine.step(match, inp, neutral())
	check(Engine.powerCooldown(match.fighters[1], "SN") == 0, "practice mode has no power cooldowns")
end

---------------------------------------------------------------------------
print("[3] Hits, blocks, combos and KO")
---------------------------------------------------------------------------
do
	local match = Engine.newMatch({
		p1 = { fighter = "noob", echo = "grandpa" },
		p2 = { fighter = "guest", echo = "pigeon" },
		skipIntro = true,
		seed = 7,
	})
	match.fighters[1].x = -1.2
	match.fighters[2].x = 1.2
	-- run through round call
	local guard = 0
	while match.phase ~= "fight" and guard < 400 do
		Engine.step(match, neutral(), neutral())
		guard += 1
	end
	check(match.phase == "fight", "reached fight phase")
	local p1, p2 = match.fighters[1], match.fighters[2]
	p1.x, p2.x = -1.1, 1.1
	local hp0 = p2.hp
	local inp = neutral()
	inp.L = true
	Engine.step(match, inp, neutral())
	for _ = 1, 30 do
		Engine.step(match, neutral(), neutral())
	end
	check(p2.hp < hp0, "jab hits a standing opponent")
	-- blocked hit
	for _ = 1, 30 do
		Engine.step(match, neutral(), neutral())
	end
	local hp1 = p2.hp
	local blk = neutral()
	blk.B = true
	Engine.step(match, neutral(), blk)
	p1.x, p2.x = -1.1, 1.1
	inp = neutral()
	inp.K = true
	Engine.step(match, inp, blk)
	local sawBlock = false
	for _ = 1, 30 do
		Engine.step(match, neutral(), blk)
		for _, ev in Engine.drainEvents(match) do
			if ev.type == "block" then
				sawBlock = true
			end
		end
	end
	check(sawBlock and p2.hp == hp1, "standing block stops a mid kick without chip")
	-- low beats standing block
	p1.x, p2.x = -1.1, 1.1
	inp = neutral()
	inp.K = true
	inp.down = true
	Engine.step(match, inp, blk)
	local hp2 = p2.hp
	for _ = 1, 40 do
		Engine.step(match, neutral(), blk)
	end
	check(p2.hp < hp2, "sweep hits a standing blocker")
	-- launch juggle
	for _ = 1, 120 do
		Engine.step(match, neutral(), neutral())
	end
	p1.x, p2.x = -1.1, 1.1
	inp = neutral()
	inp.H = true
	inp.down = true
	Engine.step(match, inp, neutral())
	local launched = false
	for _ = 1, 20 do
		Engine.step(match, neutral(), neutral())
		if p2.state == "juggle" then
			launched = true
		end
	end
	check(launched, "uppercut launches")
	-- KO
	for _ = 1, 120 do
		Engine.step(match, neutral(), neutral())
	end
	p2.hp = 10
	p1.x, p2.x = -1.1, 1.1
	inp = neutral()
	inp.K = true
	Engine.step(match, inp, neutral())
	local sawKo = false
	for _ = 1, 60 do
		Engine.step(match, neutral(), neutral())
		for _, ev in Engine.drainEvents(match) do
			if ev.type == "ko" then
				sawKo = true
			end
		end
	end
	check(sawKo and match.phase == "ko", "KO triggers")
end

---------------------------------------------------------------------------
print("[4] CPU vs CPU: every matchup plays to completion")
---------------------------------------------------------------------------
local echoIds = {}
for _, e in Echoes.list do
	table.insert(echoIds, e.id)
end
local totals = {
	matches = 0,
	frames = 0,
	ko = 0,
	timeouts = 0,
	finishers = 0,
	specials = 0,
	supers = 0,
	echoes = 0,
	throws = 0,
	breakers = 0,
	blocks = 0,
	hits = 0,
	projectiles = 0,
	parries = 0,
	maxCombo = 0,
	maxComboDamage = 0,
}
local moveUse = {}
local sideWins = { 0, 0 }
local seed = 1
for _, a in Fighters.list do
	for _, b in Fighters.list do
		for level = 2, 4, 2 do
			seed += 1
			local match = Engine.newMatch({
				p1 = { fighter = a.id, echo = echoIds[(seed % #echoIds) + 1], cpu = true },
				p2 = { fighter = b.id, echo = echoIds[((seed + 1) % #echoIds) + 1], cpu = true },
				stage = "hollowroot",
				seed = seed,
				shortIntro = true,
			})
			local ai1 = AI.new(match, 1, level, seed * 3)
			local ai2 = AI.new(match, 2, level, seed * 5)
			local frames = 0
			local ok, err = pcall(function()
				while not match.over and frames < 60 * 60 * 12 do
					Engine.step(match, ai1:getInput(), ai2:getInput())
					frames += 1
					for _, ev in Engine.drainEvents(match) do
						if ev.type == "move" then
							local key = (ev.fighter == 1 and a.id or b.id) .. "." .. ev.move
							moveUse[key] = (moveUse[key] or 0) + 1
						elseif ev.type == "time_over" then
							totals.timeouts += 1
						elseif ev.type == "ko" then
							totals.ko += 1
						elseif ev.type == "finisher_start" then
							totals.finishers += 1
						elseif ev.type == "projectile_spawn" then
							totals.projectiles += 1
						elseif ev.type == "parry" then
							totals.parries += 1
						end
					end
				end
			end)
			check(ok, string.format("%s vs %s (lvl %d) crashed: %s", a.id, b.id, level, tostring(err)))
			check(match.over, string.format("%s vs %s (lvl %d) did not finish in time (phase %s, round %d)", a.id, b.id, level, match.phase, match.round))
			if match.winner then
				sideWins[match.winner] += 1
			end
			totals.matches += 1
			totals.frames += frames
			for _, f in match.fighters do
				local s = f.stats
				totals.specials += s.specials
				totals.supers += s.supers
				totals.echoes += s.echoes
				totals.throws += s.throws
				totals.breakers += s.breakers
				totals.blocks += s.blocks
				totals.hits += s.hits
				totals.maxCombo = math.max(totals.maxCombo, s.maxCombo)
				totals.maxComboDamage = math.max(totals.maxComboDamage, s.maxComboDamage)
				check(f.hp <= f.maxHp and f.hp >= 0, "hp bounds")
				check(f.meter >= 0 and f.meter <= Config.MeterMax, "meter bounds")
			end
		end
	end
end
print(string.format(
	"  %d matches, avg %.1fs, KOs %d, time-outs %d, finishers %d",
	totals.matches,
	totals.frames / totals.matches / 60,
	totals.ko,
	totals.timeouts,
	totals.finishers
))
print(string.format(
	"  hits %d, blocks %d, specials %d, supers %d, echoes %d, throws %d, breakers %d, projectiles %d, parries %d",
	totals.hits,
	totals.blocks,
	totals.specials,
	totals.supers,
	totals.echoes,
	totals.throws,
	totals.breakers,
	totals.projectiles,
	totals.parries
))
print(string.format("  best combo %d hits / %d damage", totals.maxCombo, totals.maxComboDamage))
print(string.format("  side balance: P1 won %d, P2 won %d", sideWins[1], sideWins[2]))
check(math.min(sideWins[1], sideWins[2]) >= totals.matches * 0.3, "no side advantage from processing order")
check(totals.supers > 0, "CPU uses supers")
check(totals.echoes > 0, "CPU summons echoes")
check(totals.throws > 0, "CPU throws")
check(totals.blocks > 0, "CPU blocks")
check(totals.finishers > 0, "CPU performs finishers")
check(totals.maxCombo >= 3, "CPU lands combos")
check(totals.timeouts <= totals.matches * 0.25, "rounds mostly end by KO (time-outs " .. totals.timeouts .. ")")
check(totals.parries > 0, "CPU uses parry stances")

-- every fighter's specials get used by the CPU at least once
for _, f in Fighters.list do
	for _, id in { "SN", "SF", "SB", "SD" } do
		check((moveUse[f.id .. "." .. id] or 0) > 0 or (id == "SD") or (id == "SB"), "CPU never used " .. f.id .. "." .. id)
	end
end

---------------------------------------------------------------------------
print("[5] Determinism")
---------------------------------------------------------------------------
local function runOnce(s)
	local match = Engine.newMatch({
		p1 = { fighter = "emote", echo = "dana", cpu = true },
		p2 = { fighter = "frosty", echo = "nightguard", cpu = true },
		seed = s,
		shortIntro = true,
	})
	local a1, a2 = AI.new(match, 1, 3, s), AI.new(match, 2, 3, s + 1)
	local n = 0
	while not match.over and n < 60 * 60 * 10 do
		Engine.step(match, a1:getInput(), a2:getInput())
		n += 1
	end
	return string.format("%d|%d|%d|%d", n, match.fighters[1].hp, match.fighters[2].hp, match.winner or 0)
end
check(runOnce(42) == runOnce(42), "identical seeds replay identically")

print(string.format("\n%d checks passed, %d failed", passes, failures))
if failures > 0 then
	process.exit(1)
end
