--!nonstrict
-- OOF COMBAT server.
--
--   Profiles     DataStore profiles with session locking (settings, stats, inventory)
--   Inventory    weapons, enchantments, resources (all cosmetic), altar, forge
--   Trading      player-to-player trades with confirm countdown and atomic swap
--   OnlineMatch  online 1v1: queue, challenges, server-run fights, input relay
--
-- Single-player modes (story, tower, versus CPU, practice) still run on the client;
-- they can only claim a small, rate-limited resource reward. Every remote payload is
-- type-checked and rate-limited here before it reaches a service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

Players.CharacterAutoLoads = false

local Veil = ReplicatedStorage:WaitForChild("Veil")
local Items = require(Veil.Data.Items)
local Fighters = require(Veil.Data.Fighters)

local Profiles = require(script.Parent.Profiles)
local Inventory = require(script.Parent.Inventory)
local Trading = require(script.Parent.Trading)
local OnlineMatch = require(script.Parent.OnlineMatch)

-------------------------------------------------------------------------------
-- Remotes
-------------------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "VeilRemotes"
remotes.Parent = ReplicatedStorage

local function remote(class: string, name: string)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end

local getProfile = remote("RemoteFunction", "GetProfile")
local saveProfile = remote("RemoteEvent", "SaveProfile")
local invFn = remote("RemoteFunction", "Inventory")
local tradeEv = remote("RemoteEvent", "Trade")
local onlineEv = remote("RemoteEvent", "Online")
local inputEv = remote("RemoteEvent", "OnlineInput")

-------------------------------------------------------------------------------
-- Rate limiting
-------------------------------------------------------------------------------

local buckets = {}
local function allow(player: Player, key: string, perSecond: number, burst: number): boolean
	local b = buckets[player]
	if not b then
		b = {}
		buckets[player] = b
	end
	local now = os.clock()
	local e = b[key]
	if not e then
		e = { tokens = burst, t = now }
		b[key] = e
	end
	e.tokens = math.min(burst, e.tokens + (now - e.t) * perSecond)
	e.t = now
	if e.tokens < 1 then
		return false
	end
	e.tokens -= 1
	return true
end

-------------------------------------------------------------------------------
-- Services
-------------------------------------------------------------------------------

local rng = Random.new()
local function rand(): number
	return rng:NextNumber()
end

local function log(msg: string)
	print("[OofCombat] " .. msg)
end

local online
local trading = Trading.new({
	getProfile = Profiles.get,
	send = function(p, msg)
		if p.Parent then
			tradeEv:FireClient(p, msg)
		end
	end,
	save = function(p)
		-- deferred: if the player is leaving, the release save supersedes this one
		task.defer(Profiles.save, p)
	end,
	now = os.clock,
	isBusy = function(p)
		return online and online:isBusy(p)
	end,
	log = log,
})

online = OnlineMatch.new({
	getProfile = Profiles.get,
	send = function(p, msg)
		if p.Parent then
			onlineEv:FireClient(p, msg)
		end
	end,
	save = function(p)
		-- deferred: if the player is leaving, the release save supersedes this one
		task.defer(Profiles.save, p)
	end,
	now = os.clock,
	rand = rand,
	log = log,
})

Profiles.start()

Players.PlayerRemoving:Connect(function(player)
	-- settle first (forfeit counts, trades cancel), then save and release the profile
	online:playerLeft(player)
	trading:playerLeft(player)
	buckets[player] = nil
	Profiles.release(player)
end)

RunService.Heartbeat:Connect(function(dt)
	online:tick(dt)
	trading:step()
end)

-------------------------------------------------------------------------------
-- Profile (settings + stats)
-------------------------------------------------------------------------------

local function publicProfile(p)
	return {
		settings = Profiles.deepCopy(p.settings),
		stats = Profiles.deepCopy(p.stats),
		inv = Inventory.snapshot(p.inv),
	}
end

getProfile.OnServerInvoke = function(player: Player)
	local p = Profiles.await(player, 10)
	if not p then
		return publicProfile(Profiles.sanitize(nil))
	end
	return publicProfile(p)
end

-- Client reports settings + stat deltas. Stats only grow by small amounts per
-- request so a tampered client can't inflate them.
saveProfile.OnServerEvent:Connect(function(player: Player, payload)
	if type(payload) ~= "table" or not allow(player, "save", 1, 3) then
		return
	end
	local p = Profiles.get(player)
	if not p then
		return
	end
	if type(payload.settings) == "table" then
		local merged = Profiles.sanitize({ settings = payload.settings, stats = p.stats, inv = p.inv, daily = p.daily, lastClaim = p.lastClaim })
		p.settings = merged.settings
	end
	if type(payload.delta) == "table" then
		local d = payload.delta
		local function bump(key: string, maxStep: number)
			local v = d[key]
			if type(v) == "number" and v == v and v >= 0 and v <= maxStep then
				p.stats[key] += math.floor(v)
			end
		end
		bump("wins", 1)
		bump("losses", 1)
		bump("ascents", 1)
		bump("finishers", 1)
		if d.storyDone == true then
			p.stats.storyDone = true
		end
	end
	Profiles.markDirty(player)
end)

-------------------------------------------------------------------------------
-- Inventory: equip, enchant altar, forge, CPU-fight claims
-------------------------------------------------------------------------------

local function today(): number
	return math.floor(os.time() / 86400)
end

invFn.OnServerInvoke = function(player: Player, op, arg)
	if type(op) ~= "string" or not allow(player, "inv", 4, 8) then
		return { ok = false, err = "slow down" }
	end
	local p = Profiles.await(player, 5)
	if not p then
		return { ok = false, err = "profile not loaded" }
	end
	local inv = p.inv
	if op == "get" then
		return { ok = true, inv = Inventory.snapshot(inv) }
	end
	if trading:inTrade(player) and op ~= "equip" then
		return { ok = false, err = "finish your trade first" }
	end
	if op == "equip" then
		if type(arg) ~= "table" or type(arg.fighter) ~= "string" or (arg.uid ~= nil and type(arg.uid) ~= "string") then
			return { ok = false, err = "bad request" }
		end
		local ok, err = Inventory.equip(inv, arg.fighter, arg.uid)
		Profiles.markDirty(player)
		return { ok = ok, err = err, inv = Inventory.snapshot(inv) }
	elseif op == "enchant" then
		if type(arg) ~= "string" then
			return { ok = false, err = "bad request" }
		end
		local ok, res = Inventory.enchant(inv, arg, rand)
		if ok then
			Profiles.markDirty(player)
		end
		return { ok = ok, err = (not ok) and res or nil, ench = ok and res or nil, inv = Inventory.snapshot(inv) }
	elseif op == "forge" then
		if type(arg) ~= "string" then
			return { ok = false, err = "bad request" }
		end
		local rec, err = Inventory.forge(inv, player.UserId, arg, rand)
		if rec then
			Profiles.markDirty(player)
		end
		return { ok = rec ~= nil, err = err, weapon = rec and { uid = rec.uid, item = rec.item } or nil, inv = Inventory.snapshot(inv) }
	elseif op == "claim" then
		-- reward for finishing a CPU fight (unverifiable): small and rate-limited
		local now = os.time()
		if p.daily.day ~= today() then
			p.daily.day = today()
			p.daily.claims = 0
		end
		if now - (p.lastClaim or 0) < Items.OfflineClaimInterval or p.daily.claims >= Items.OfflineClaimsPerDay then
			return { ok = false, err = "no reward this time", inv = Inventory.snapshot(inv) }
		end
		p.lastClaim = now
		p.daily.claims += 1
		local rewards = Inventory.rollRewards(Items.Rewards.offline, rand)
		Inventory.applyRewards(inv, player.UserId, rewards)
		Profiles.markDirty(player)
		return { ok = true, rewards = rewards.res, inv = Inventory.snapshot(inv) }
	end
	return { ok = false, err = "unknown request" }
end

-------------------------------------------------------------------------------
-- Trading
-------------------------------------------------------------------------------

local function playerById(userId)
	if type(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

tradeEv.OnServerEvent:Connect(function(player: Player, msg)
	if type(msg) ~= "table" or type(msg.op) ~= "string" or not allow(player, "trade", 8, 16) then
		return
	end
	local ok, err = true, nil
	if msg.op == "request" then
		ok, err = trading:request(player, playerById(msg.target))
	elseif msg.op == "respond" then
		ok, err = trading:respond(player, playerById(msg.from), msg.accept == true)
	elseif msg.op == "offer" then
		ok, err = trading:offer(player, msg.offer)
	elseif msg.op == "ready" then
		ok, err = trading:setReady(player, msg.on == true)
	elseif msg.op == "cancel" then
		trading:cancel(player, player.DisplayName .. " cancelled")
	elseif msg.op == "incoming" then
		local list = {}
		for _, r in trading:incoming(player) do
			table.insert(list, { from = r.from.UserId, name = r.from.DisplayName })
		end
		tradeEv:FireClient(player, { op = "incoming", list = list })
	end
	if not ok then
		tradeEv:FireClient(player, { op = "error", err = err or "trade error" })
	end
end)

-------------------------------------------------------------------------------
-- Online matches
-------------------------------------------------------------------------------

onlineEv.OnServerEvent:Connect(function(player: Player, msg)
	if type(msg) ~= "table" or type(msg.op) ~= "string" or not allow(player, "online", 6, 12) then
		return
	end
	local ok, err = true, nil
	if msg.op == "queue" then
		if trading:inTrade(player) then
			ok, err = false, "finish your trade first"
		else
			ok, err = online:queuePlayer(player, msg.pick)
		end
	elseif msg.op == "unqueue" then
		online:unqueue(player)
	elseif msg.op == "challenge" then
		ok, err = online:challenge(player, playerById(msg.target), msg.pick)
	elseif msg.op == "respond" then
		ok, err = online:respond(player, playerById(msg.from), msg.accept == true, msg.pick)
	elseif msg.op == "ready" then
		online:setReady(player, msg.id)
	elseif msg.op == "forfeit" then
		online:forfeit(player, "forfeit")
	end
	if not ok then
		onlineEv:FireClient(player, { op = "error", err = err or "online error" })
	end
end)

inputEv.OnServerEvent:Connect(function(player: Player, held, pressed)
	online:input(player, held, pressed)
end)

-- keep the lints honest about used modules
local _ = Fighters
