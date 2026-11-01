--!nonstrict
-- Client side of the multiplayer remotes. Caches the latest inventory snapshot and
-- re-broadcasts server messages as local signals so screens can listen safely.
-- When the remotes aren't there (offline tests) everything reports unavailable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.onOnline = Instance.new("BindableEvent")
Net.onTrade = Instance.new("BindableEvent")
Net.onInventory = Instance.new("BindableEvent")
Net.inv = { res = {}, weapons = {}, equipped = {} }
Net.available = false

local remotes = nil

function Net.start(folder)
	remotes = folder
	if not remotes then
		return
	end
	local online = remotes:FindFirstChild("Online")
	local trade = remotes:FindFirstChild("Trade")
	if not online or not trade or not remotes:FindFirstChild("Inventory") then
		return
	end
	Net.available = true
	online.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		if msg.inv then
			Net.setInventory(msg.inv)
		end
		Net.onOnline:Fire(msg)
	end)
	trade.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		if msg.inv then
			Net.setInventory(msg.inv)
		end
		Net.onTrade:Fire(msg)
	end)
	task.spawn(function()
		Net.request("get")
	end)
end

function Net.setInventory(inv)
	if type(inv) == "table" and type(inv.weapons) == "table" then
		Net.inv = inv
		Net.onInventory:Fire(inv)
	end
end

-- Inventory remote function: returns the server reply table (never errors).
function Net.request(op: string, arg)
	if not remotes then
		return { ok = false, err = "offline" }
	end
	local fn = remotes:FindFirstChild("Inventory")
	if not fn then
		return { ok = false, err = "offline" }
	end
	local ok, res = pcall(function()
		return fn:InvokeServer(op, arg)
	end)
	if not ok or type(res) ~= "table" then
		return { ok = false, err = "the server didn't answer" }
	end
	if res.inv then
		Net.setInventory(res.inv)
	end
	return res
end

function Net.online(msg)
	local ev = remotes and remotes:FindFirstChild("Online")
	if ev then
		ev:FireServer(msg)
	end
end

function Net.trade(msg)
	local ev = remotes and remotes:FindFirstChild("Trade")
	if ev then
		ev:FireServer(msg)
	end
end

function Net.sendInput(held: number, pressed: number)
	local ev = remotes and remotes:FindFirstChild("OnlineInput")
	if ev then
		ev:FireServer(held, pressed)
	end
end

-- The cosmetic the local player has equipped on a fighter: { item, ench } or nil.
function Net.cosmeticFor(fighterId: string)
	local uid = Net.inv.equipped and Net.inv.equipped[fighterId]
	if not uid then
		return nil
	end
	for _, w in Net.inv.weapons do
		if w.uid == uid then
			return { item = w.item, ench = w.ench, lvl = w.lvl or 1 }
		end
	end
	return nil
end

-- Other players in this server (for challenges and trades).
function Net.others()
	local out = {}
	local me = Players.LocalPlayer
	for _, p in Players:GetPlayers() do
		if p ~= me then
			table.insert(out, p)
		end
	end
	return out
end

local _ = ReplicatedStorage
return Net
