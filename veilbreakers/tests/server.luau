-- Headless tests for the multiplayer server: inventory rules, trading (including
-- dupe protection), and full online matches with client-side replay checks.
-- Run from the project root:  lune run tests/server

local process = require("@lune/process")
local Loader = require("./loader")
local Mock = require("./mock_roblox")

local shared = Loader.root("src/shared")
local server = Loader.root("src/server")
local env = Mock.build(shared)
Loader.addGlobals(env)

local Items = Loader.require(shared.Data.Items)
local Fighters = Loader.require(shared.Data.Fighters)
local Engine = Loader.require(shared.Combat.Engine)
local AI = Loader.require(shared.Combat.AI)
local NetInput = Loader.require(shared.Combat.NetInput)
local Rng = Loader.require(shared.Combat.Rng)
local Inventory = Loader.require(server.Inventory)
local Profiles = Loader.require(server.Profiles)
local Trading = Loader.require(server.Trading)
local OnlineMatch = Loader.require(server.OnlineMatch)

local passes, failures = 0, 0
local function check(cond, msg)
	if cond then
		passes += 1
	else
		failures += 1
		print("  FAIL: " .. msg)
	end
end

local rng = Rng.new(4242)
local function rand()
	return rng:next()
end

local function fakePlayer(id, name)
	return { UserId = id, DisplayName = name, Name = name, Parent = true }
end

local function totalResources(list)
	local t = {}
	for _, inv in list do
		for id, n in inv.res do
			t[id] = (t[id] or 0) + n
		end
	end
	return t
end

---------------------------------------------------------------------------
print("[1] Items catalog")
---------------------------------------------------------------------------
do
	local types = {}
	for _, f in Fighters.list do
		types[f.look.weapon] = true
	end
	for t in types do
		check(#Items.weaponsOfType(t) >= 3, "weapon type " .. t .. " has at least 3 skins")
		check(Items.WeaponTypeById[t] ~= nil, "weapon type " .. t .. " is listed")
	end
	for _, w in Items.Weapons do
		check(Items.RARITY[w.rarity] ~= nil, w.id .. " rarity")
		check(types[w.type] == true, w.id .. " fits a real fighter weapon")
	end
	for _, e in Items.Enchantments do
		check(e.weight > 0 and e.fx ~= nil, e.id .. " has weight and fx")
		-- cosmetic only: no stat-like keys anywhere
		for _, bad in { "damage", "speed", "health", "hp", "meter", "startup", "recovery" } do
			check(e.fx[bad] == nil and e[bad] == nil, e.id .. " has no " .. bad .. " stat")
		end
	end
end

---------------------------------------------------------------------------
print("[2] Inventory: forge, enchant, equip, sanitize")
---------------------------------------------------------------------------
do
	local inv = Inventory.new()
	check(inv.res.studs == Items.StarterPack.studs and inv.res.relic == Items.StarterPack.relic, "starter pack")
	inv.res.scrap = 100
	inv.res.studs = 200
	local w = Inventory.forge(inv, 7, "katana", rand)
	check(w ~= nil and Items.WeaponById[w.item].type == "katana", "forge makes a katana skin")
	check(inv.res.scrap == 100 - Items.ForgeCost.scrap and inv.res.studs == 200 - Items.ForgeCost.studs, "forge spends the cost")
	local relics = inv.res.relic
	local ok, ench = Inventory.enchant(inv, w.uid, rand)
	check(ok and Items.EnchantById[ench] ~= nil and Inventory.findWeapon(inv, w.uid).ench == ench, "enchant rolls an enchantment")
	check(inv.res.relic == relics - 1, "enchant spends a relic")
	inv.res.relic = 0
	local ok2, why = Inventory.enchant(inv, w.uid, rand)
	check(not ok2 and why == "not enough resources", "enchant refuses without a relic")
	check(Inventory.equip(inv, "noob", w.uid) == true, "noob (katana) can equip a katana skin")
	local ok3 = Inventory.equip(inv, "frosty", w.uid)
	check(ok3 == false, "frosty (hammer) can't equip a katana skin")
	check(Inventory.cosmeticFor(inv, "noob").item == w.item, "cosmeticFor returns the equipped skin")
	-- enchant distribution follows the weights (common far more often than mythic)
	local counts = {}
	local test = Inventory.new()
	local rec = Inventory.addWeapon(test, 1, "katana_neon")
	test.res.relic = 5000
	test.res.studs = 99999
	for _ = 1, 3000 do
		local _, e = Inventory.enchant(test, rec.uid, rand)
		counts[e] = (counts[e] or 0) + 1
	end
	check((counts.blazing or 0) > (counts.rainbow or 0) * 4, "enchant rarity weights respected")
	-- sanitize rejects junk
	local dirty = {
		res = { studs = -5, scrap = 1.5, glitch = 3, fake = 9 },
		weapons = { { uid = "a", item = "katana_neon" }, { uid = "a", item = "katana_neon" }, { uid = "b", item = "not_real" }, "junk" },
		equipped = { noob = "a", frosty = "zzz", nobody = "a" },
	}
	local clean = Inventory.sanitize(dirty)
	check(clean.res.studs == nil and clean.res.scrap == nil and clean.res.glitch == 3 and clean.res.fake == nil, "sanitize resources")
	check(#clean.weapons == 1, "sanitize drops duplicate / unknown weapons")
	check(clean.equipped.noob == "a" and clean.equipped.frosty == nil and clean.equipped.nobody == nil, "sanitize equipped")
	-- old (v1) profiles get an inventory
	local migrated = Profiles.sanitize({ version = 1, settings = { music = 0.3 }, stats = { wins = 4 } })
	check(migrated.inv ~= nil and migrated.inv.res.studs == Items.StarterPack.studs and migrated.stats.wins == 4 and migrated.settings.music == 0.3, "v1 profile migrates with a starter pack")
end

---------------------------------------------------------------------------
print("[3] Trading: offers, ready reset, countdown, atomic swap, no dupes")
---------------------------------------------------------------------------
do
	local A, B = fakePlayer(1001, "Alice"), fakePlayer(1002, "Bob")
	local profiles = { [A] = Profiles.sanitize(nil), [B] = Profiles.sanitize(nil) }
	local wA = Inventory.addWeapon(profiles[A].inv, A.UserId, "hammer_ban", "rainbow")
	local wB = Inventory.addWeapon(profiles[B].inv, B.UserId, "katana_404", nil)
	Inventory.equip(profiles[A].inv, "frosty", wA.uid)
	local sent = { [A] = {}, [B] = {} }
	local saved = {}
	local clock = 0
	local tr = Trading.new({
		getProfile = function(p)
			return profiles[p]
		end,
		send = function(p, msg)
			table.insert(sent[p], msg)
		end,
		save = function(p)
			saved[p] = (saved[p] or 0) + 1
		end,
		now = function()
			return clock
		end,
	})
	local before = totalResources({ profiles[A].inv, profiles[B].inv })
	check(tr:request(A, B) == true, "request")
	check(sent[B][#sent[B]].op == "request", "target is told")
	check(tr:respond(B, A, true) == true, "accept opens the trade")
	check(tr:inTrade(A) and tr:inTrade(B), "both are trading")
	check(tr:offer(A, { weapons = { wA.uid }, res = { studs = 10 } }) == true, "A offers")
	local okBad, whyBad = tr:offer(B, { weapons = { wA.uid } })
	check(okBad == false and whyBad ~= nil, "B can't offer A's weapon")
	local okMany = tr:offer(B, { res = { relic = 999 } })
	check(okMany == false, "can't offer more than you own")
	check(tr:offer(B, { weapons = { wB.uid }, res = { relic = 1 } }) == true, "B offers")
	tr:setReady(A, true)
	tr:setReady(B, true)
	check(sent[A][#sent[A]].countdown ~= nil, "countdown starts when both are ready")
	-- a change resets both sides
	tr:offer(B, { weapons = { wB.uid }, res = { relic = 2 } })
	local st = sent[A][#sent[A]]
	check(st.readyMe == false and st.readyThem == false and st.countdown == nil, "changing an offer clears both READY flags")
	tr:setReady(A, true)
	tr:setReady(B, true)
	clock += Items.TradeConfirmSeconds - 0.5
	tr:step()
	check(tr:inTrade(A), "not executed before the countdown ends")
	clock += 1
	tr:step()
	check(not tr:inTrade(A) and not tr:inTrade(B), "trade executed and closed")
	check(Inventory.findWeapon(profiles[A].inv, wA.uid) == nil and Inventory.findWeapon(profiles[B].inv, wA.uid) ~= nil, "A's hammer moved to B")
	check(Inventory.findWeapon(profiles[B].inv, wA.uid).ench == "rainbow", "the enchantment travels with the weapon")
	check(Inventory.findWeapon(profiles[A].inv, wB.uid) ~= nil and Inventory.findWeapon(profiles[B].inv, wB.uid) == nil, "B's katana moved to A")
	check(profiles[A].inv.equipped.frosty == nil, "traded weapon was unequipped")
	local after = totalResources({ profiles[A].inv, profiles[B].inv })
	for id, n in before do
		check(after[id] == n, "resource " .. id .. " conserved (" .. n .. " -> " .. tostring(after[id]) .. ")")
	end
	check(profiles[A].inv.res.relic == Items.StarterPack.relic + 2 and profiles[B].inv.res.studs == Items.StarterPack.studs + 10, "resources moved")
	check(saved[A] == 1 and saved[B] == 1, "both profiles saved after the swap")
	check(sent[A][#sent[A]].op == "done" and sent[A][#sent[A]].inv ~= nil, "players get their new inventory")

	-- item changing mid-trade fails the swap instead of duplicating
	tr:request(A, B)
	tr:respond(B, A, true)
	tr:offer(A, { weapons = { wB.uid } })
	tr:setReady(A, true)
	tr:setReady(B, true)
	Inventory.takeWeapon(profiles[A].inv, wB.uid) -- vanished (e.g. another path)
	clock += 10
	tr:step()
	check(Inventory.findWeapon(profiles[B].inv, wB.uid) == nil, "a weapon that vanished mid-trade is not created on the other side")
	check(sent[A][#sent[A]].op == "closed", "trade closed with a reason")

	-- leaving cancels
	tr:request(A, B)
	tr:respond(B, A, true)
	tr:playerLeft(B)
	check(not tr:inTrade(A), "leaving cancels the trade")
	-- self-trade and expiry
	check(tr:request(A, A) == false, "no self-trades")
	tr:request(A, B)
	clock += 100
	check(tr:respond(B, A, true) == false, "requests expire")
end

---------------------------------------------------------------------------
print("[4] Online 1v1: queue, map pick, server match, client replay")
---------------------------------------------------------------------------
local function runOnline(opts)
	local P1, P2 = fakePlayer(2001, "Red"), fakePlayer(2002, "Blue")
	local profiles = { [P1] = Profiles.sanitize(nil), [P2] = Profiles.sanitize(nil) }
	local skin = Inventory.addWeapon(profiles[P1].inv, P1.UserId, "katana_neon", "blazing")
	Inventory.equip(profiles[P1].inv, "noob", skin.uid)
	local inbox = { [P1] = {}, [P2] = {} }
	local clock = 0
	local svc = OnlineMatch.new({
		getProfile = function(p)
			return profiles[p]
		end,
		send = function(p, msg)
			table.insert(inbox[p], msg)
		end,
		save = function() end,
		now = function()
			return clock
		end,
		rand = rand,
	})
	check(svc:queuePlayer(P1, { fighter = "noob", echo = "grandpa", stage = "cathedral" }) == true, "queue P1")
	check(svc:queuePlayer(P2, { fighter = opts.p2fighter or "frosty", echo = "dana", stage = "hollowroot" }) == true, "queue P2")
	local start1, start2
	for _, msg in inbox[P1] do
		if msg.op == "start" then
			start1 = msg
		end
	end
	for _, msg in inbox[P2] do
		if msg.op == "start" then
			start2 = msg
		end
	end
	check(start1 and start2 and start1.spec.id == start2.spec.id, "both players get the same match")
	local spec = start1.spec
	check(spec.stage == "cathedral" or spec.stage == "hollowroot", "map is one of the two picks")
	check(start1.side == 1 and start2.side == 2, "sides assigned")
	check(spec.p1.cosmetic and spec.p1.cosmetic.item == "katana_neon" and spec.p1.cosmetic.ench == "blazing", "equipped cosmetic is sent from the server profile")
	check(svc:isBusy(P1) and svc:isBusy(P2), "players are busy")
	svc:setReady(P1, spec.id)
	svc:setReady(P2, spec.id)
	local m = svc.byPlayer[P1]
	check(m and m.state == "running", "match runs once both are ready")

	-- drive both players with the CPU brain looking at the server match
	local ai1 = AI.new(m.engine, 1, 3, 11)
	local ai2 = AI.new(m.engine, 2, 3, 22)
	local frames = 0
	while svc.byPlayer[P1] and frames < (opts.maxFrames or 20000) do
		local i1 = ai1:getInput()
		local i2 = ai2:getInput()
		svc:input(P1, NetInput.encode(i1), NetInput.encode(i1))
		svc:input(P2, NetInput.encode(i2), NetInput.encode(i2))
		clock += 1 / 60
		svc:tick(1 / 60)
		frames += 1
		if opts.leaveAt and frames == opts.leaveAt then
			P2.Parent = nil
			svc:playerLeft(P2)
		end
	end
	return { svc = svc, inbox = inbox, P1 = P1, P2 = P2, spec = spec, engine = m.engine, frames = frames, profiles = profiles }
end

do
	local r = runOnline({})
	local endMsg
	for _, msg in r.inbox[r.P1] do
		if msg.op == "end" then
			endMsg = msg
		end
	end
	check(endMsg ~= nil and (endMsg.winner == 1 or endMsg.winner == 2) and endMsg.reason == "ko", "match ends with a winner")
	check(r.engine.over == true, "server engine finished the match")
	check(not r.svc:isBusy(r.P1) and not r.svc:isBusy(r.P2), "players freed after the match")
	-- replay: a client running the same engine on the streamed frames ends identically
	local replay = Engine.newMatch(OnlineMatch.engineOpts(r.spec))
	local nextFrame = 1
	local syncOk, syncCount = true, 0
	local syncs = {}
	for _, msg in r.inbox[r.P2] do
		if msg.op == "sync" then
			syncs[msg.frame] = msg
		end
	end
	for _, msg in r.inbox[r.P2] do
		if msg.op == "f" then
			check(msg.from == nextFrame, "frame packets arrive in order (" .. msg.from .. " vs " .. nextFrame .. ")")
			for k = 1, #msg.m, 2 do
				Engine.step(replay, NetInput.decode(msg.m[k]), NetInput.decode(msg.m[k + 1]))
				Engine.drainEvents(replay)
				nextFrame += 1
				local s = syncs[replay.frame]
				if s then
					syncCount += 1
					local f1, f2 = replay.fighters[1], replay.fighters[2]
					if f1.hp ~= s.hp[1] or f2.hp ~= s.hp[2] or f1.x ~= s.x[1] or f2.x ~= s.x[2] or replay.timer ~= s.timer then
						syncOk = false
					end
				end
			end
		end
	end
	check(syncCount > 5 and syncOk, "client replay matches every server state check (" .. syncCount .. " checks)")
	check(replay.over and replay.winner == r.engine.winner and replay.frame == r.engine.frame, "client replay ends with the same winner on the same frame")
	check(replay.fighters[1].hp == r.engine.fighters[1].hp and replay.fighters[2].hp == r.engine.fighters[2].hp, "client replay has identical health")
	local winnerP = endMsg.winner == 1 and r.P1 or r.P2
	check(r.profiles[winnerP].stats.onlineWins == 1, "winner's online wins recorded")
	local got = 0
	for _, n in endMsg.rewards or {} do
		got += n
	end
	check(endMsg.rewarded == true and got > 0, "rewards granted from the server's result")
	print(string.format("  online match: %d frames, winner P%d, %d sync checks", r.frames, endMsg.winner, syncCount))
end

do
	-- disconnect early: the other player wins, but a 5-second quit pays no rewards
	local r = runOnline({ leaveAt = 300, maxFrames = 400 })
	local endMsg
	for _, msg in r.inbox[r.P1] do
		if msg.op == "end" then
			endMsg = msg
		end
	end
	check(endMsg and endMsg.winner == 1 and endMsg.reason == "disconnect", "leaving mid-match forfeits")
	check(endMsg and endMsg.rewarded == false, "no rewards for an instant forfeit (anti-farming)")
end

do
	-- validation: bad picks, practice room, bogus inputs
	local P = fakePlayer(3001, "X")
	local svc = OnlineMatch.new({
		getProfile = function()
			return nil
		end,
		send = function() end,
		save = function() end,
		now = function()
			return 0
		end,
		rand = rand,
	})
	check(svc:queuePlayer(P, { fighter = "nobody", echo = "grandpa", stage = "cathedral" }) == false, "unknown fighter rejected")
	check(svc:queuePlayer(P, { fighter = "noob", echo = "grandpa", stage = "proving" }) == false, "practice room is not an online map")
	check(svc:queuePlayer(P, "junk") == false, "junk pick rejected")
	check(svc:input(P, 5, 0) == false, "input outside a match ignored")
	check(NetInput.valid(2 ^ 40) == false and NetInput.valid(-1) == false and NetInput.valid(1.5) == false, "bogus input masks rejected")
	local mask = NetInput.encode({ left = true, L = true, P3 = true })
	local back = NetInput.decode(mask)
	check(back.left and back.L and back.P3 and not back.right and not back.H, "input mask round trip")
	check(NetInput.union(5, 3) == 7 and NetInput.union(0, 0) == 0, "mask union")
end

print(string.format("\n%d checks passed, %d failed", passes, failures))
process.exit(failures == 0 and 0 or 1)
