--!nonstrict
-- VEILBREAKERS server bootstrap.
-- The fights themselves run on each player's client (single-player vs CPU), so the
-- server only owns profile persistence: settings + lifetime stats in a DataStore.
-- All remote input is validated and rate-limited; DataStore failures degrade to
-- in-memory profiles without erroring.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

Players.CharacterAutoLoads = false

local STORE_NAME = "VeilbreakersProfile_v1"
local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	end
end

local remotes = Instance.new("Folder")
remotes.Name = "VeilRemotes"
remotes.Parent = ReplicatedStorage

local getProfile = Instance.new("RemoteFunction")
getProfile.Name = "GetProfile"
getProfile.Parent = remotes

local saveProfile = Instance.new("RemoteEvent")
saveProfile.Name = "SaveProfile"
saveProfile.Parent = remotes

local DEFAULT = {
	version = 1,
	settings = {
		music = 0.6,
		sfx = 0.8,
		voice = 0.85,
		subtitles = true,
		shake = true,
		difficulty = 2,
		touch = "auto",
	},
	stats = {
		wins = 0,
		losses = 0,
		ascents = 0,
		finishers = 0,
		storyDone = false,
	},
}

local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local lastSave: { [Player]: number } = {}
local loaded: { [Player]: boolean } = {}

local function deepCopy(t)
	local out = {}
	for k, v in t do
		out[k] = type(v) == "table" and deepCopy(v) or v
	end
	return out
end

-- Merge stored data over defaults, keeping only known keys with the right types.
local function sanitize(data)
	local p = deepCopy(DEFAULT)
	if type(data) ~= "table" then
		return p
	end
	for _, section in { "settings", "stats" } do
		local src = data[section]
		if type(src) == "table" then
			for k, def in DEFAULT[section] do
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
	return p
end

local function load(player: Player)
	local data = nil
	if store then
		-- Studio without API access fails fast: try once, never stall the session.
		local attempts = RunService:IsStudio() and 1 or 3
		for attempt = 1, attempts do
			local ok, result = pcall(function()
				return store:GetAsync("p_" .. player.UserId)
			end)
			if ok then
				data = result
				break
			end
			if attempt < attempts then
				task.wait(attempt)
			end
		end
	end
	profiles[player] = sanitize(data)
	loaded[player] = true
end

local function save(player: Player)
	local p = profiles[player]
	if not p or not store or not dirty[player] then
		return
	end
	dirty[player] = false
	local snapshot = deepCopy(p)
	local attempts = RunService:IsStudio() and 1 or 3
	for attempt = 1, attempts do
		local ok = pcall(function()
			store:UpdateAsync("p_" .. player.UserId, function()
				return snapshot
			end)
		end)
		if ok then
			return
		end
		if attempt < attempts then
			task.wait(attempt)
		end
	end
	dirty[player] = true
end

Players.PlayerAdded:Connect(function(player)
	load(player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(load, player)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	profiles[player] = nil
	dirty[player] = nil
	lastSave[player] = nil
	loaded[player] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		task.spawn(save, player)
	end
	task.wait(2)
end)

getProfile.OnServerInvoke = function(player: Player)
	local waited = 0
	while not loaded[player] and waited < 10 do
		task.wait(0.2)
		waited += 0.2
	end
	return deepCopy(profiles[player] or DEFAULT)
end

-- Client reports settings + stat deltas. Stats are only allowed to grow by small
-- amounts per request so a tampered client can't inflate them arbitrarily.
saveProfile.OnServerEvent:Connect(function(player: Player, payload)
	if type(payload) ~= "table" then
		return
	end
	local now = os.clock()
	if lastSave[player] and now - lastSave[player] < 1 then
		return
	end
	lastSave[player] = now
	local p = profiles[player]
	if not p then
		return
	end
	if type(payload.settings) == "table" then
		local merged = sanitize({ settings = payload.settings, stats = p.stats })
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
	dirty[player] = true
end)

-- periodic autosave
task.spawn(function()
	while true do
		task.wait(90)
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
	end
end)
