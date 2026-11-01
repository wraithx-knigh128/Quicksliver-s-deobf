--!nonstrict
-- Player profiles: settings, lifetime stats and the tradeable inventory.
--
-- Persistence uses one DataStore key per player with a session lock, so a profile
-- can only be live on one server at a time (the lock is taken in UpdateAsync on
-- load, refreshed on every save and released when the player leaves). That is what
-- stops item duplication by hopping servers mid-trade. If the DataStore isn't
-- reachable (Studio without API access) profiles live in memory for the session.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Inventory = require(script.Parent.Inventory)

local Profiles = {}

local STORE_NAME = "OofCombatProfile_v1" -- key name kept so v1 saves migrate in place
local SCHEMA = 2
local LOCK_STALE = 30 * 60 -- seconds before a crashed server's lock is ignored

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	end
end
Profiles.persistent = store ~= nil

Profiles.DEFAULT = {
	settings = {
		music = 0.6,
		sfx = 0.8,
		voice = 0.85,
		subtitles = true,
		shake = true,
		flashes = true,
		tts = true,
		difficulty = 2,
		touch = "auto",
	},
	stats = {
		wins = 0,
		losses = 0,
		ascents = 0,
		finishers = 0,
		storyDone = false,
		onlineWins = 0,
		onlineLosses = 0,
		trades = 0,
	},
}

local live: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local releasing: { [Player]: boolean } = {}
local loadedEvent = Instance.new("BindableEvent")
Profiles.Loaded = loadedEvent.Event

local function deepCopy(t)
	local out = {}
	for k, v in t do
		out[k] = type(v) == "table" and deepCopy(v) or v
	end
	return out
end
Profiles.deepCopy = deepCopy

-- Merge stored data over defaults, keeping only known keys with the right types.
function Profiles.sanitize(data)
	local p = deepCopy(Profiles.DEFAULT)
	p.version = SCHEMA
	if type(data) ~= "table" then
		p.inv = Inventory.new()
		p.daily = { day = 0, claims = 0 }
		p.lastClaim = 0
		return p
	end
	for _, section in { "settings", "stats" } do
		local src = data[section]
		if type(src) == "table" then
			for k, def in Profiles.DEFAULT[section] do
				local v = src[k]
				if type(v) == type(def) then
					if type(v) == "number" then
						if v ~= v or v == math.huge or v == -math.huge then
							continue
						end
						if section == "settings" then
							if k == "difficulty" then
								v = math.clamp(math.floor(v), 1, 4)
							else
								v = math.clamp(v, 0, 1)
							end
						else
							v = math.clamp(math.floor(v), 0, 1e7)
						end
					elseif type(v) == "string" then
						if k == "touch" and v ~= "auto" and v ~= "on" and v ~= "off" then
							continue
						end
					end
					p[section][k] = v
				end
			end
		end
	end
	-- v1 saves had no inventory: they get the starter pack
	p.inv = data.inv and Inventory.sanitize(data.inv) or Inventory.new()
	local d = data.daily
	p.daily = { day = 0, claims = 0 }
	if type(d) == "table" and type(d.day) == "number" and type(d.claims) == "number" then
		p.daily.day = math.floor(d.day)
		p.daily.claims = math.clamp(math.floor(d.claims), 0, 1000)
	end
	p.lastClaim = type(data.lastClaim) == "number" and data.lastClaim or 0
	return p
end

local function key(player: Player): string
	return "p_" .. player.UserId
end

local function lockFree(lock): boolean
	if type(lock) ~= "table" then
		return true
	end
	if lock.job == game.JobId then
		return true
	end
	return type(lock.t) ~= "number" or os.time() - lock.t > LOCK_STALE
end

function Profiles.load(player: Player)
	local data = nil
	if store then
		local attempts = RunService:IsStudio() and 1 or 6
		for attempt = 1, attempts do
			local locked = false
			local ok, result = pcall(function()
				return store:UpdateAsync(key(player), function(old)
					if old ~= nil and not lockFree(old.lock) then
						locked = true
						return nil -- leave it untouched; another server owns it
					end
					old = old or {}
					old.lock = { job = game.JobId, t = os.time() }
					return old
				end)
			end)
			if ok and not locked then
				data = result
				break
			end
			if attempt < attempts then
				task.wait(math.min(8, attempt * 1.5))
			end
		end
	end
	if not player.Parent then
		return -- left while loading
	end
	live[player] = Profiles.sanitize(data)
	loadedEvent:Fire(player)
end

function Profiles.get(player: Player)
	return live[player]
end

-- Wait (briefly) for a profile to load.
function Profiles.await(player: Player, timeout: number?)
	local t = 0
	while not live[player] and t < (timeout or 10) and player.Parent do
		task.wait(0.2)
		t += 0.2
	end
	return live[player]
end

function Profiles.markDirty(player: Player)
	dirty[player] = true
end

-- Write the profile now (keeps the session lock unless `release`).
function Profiles.save(player: Player, release: boolean?)
	local p = live[player]
	if not p or not store then
		return true
	end
	if releasing[player] and not release then
		return true -- the final (lock-releasing) save is already on its way
	end
	dirty[player] = false
	local snapshot = deepCopy(p)
	snapshot.lock = (not release) and { job = game.JobId, t = os.time() } or nil
	local attempts = RunService:IsStudio() and 1 or 3
	for attempt = 1, attempts do
		local ok = pcall(function()
			store:UpdateAsync(key(player), function(old)
				if old and not lockFree(old.lock) then
					return nil -- someone else owns it now: never overwrite their data
				end
				return snapshot
			end)
		end)
		if ok then
			return true
		end
		if attempt < attempts then
			task.wait(attempt)
		end
	end
	dirty[player] = true
	return false
end

function Profiles.release(player: Player)
	if releasing[player] then
		return
	end
	releasing[player] = true
	Profiles.save(player, true)
	live[player] = nil
	dirty[player] = nil
	releasing[player] = nil
end

function Profiles.start()
	Players.PlayerAdded:Connect(function(player)
		Profiles.load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(Profiles.load, player)
	end
	-- PlayerRemoving is handled by Main.server so matches and trades settle first,
	-- then it calls Profiles.release.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(Profiles.release, player)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				-- always save: it also refreshes the session lock
				task.spawn(Profiles.save, player)
			end
		end
	end)
end

-- Test hook: install a profile directly.
function Profiles._set(player, profile)
	live[player] = profile
end

return Profiles
