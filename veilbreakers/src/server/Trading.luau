--!nonstrict
-- Player-to-player trading, server authoritative.
--
--   request -> (other player) accept -> both edit offers -> both READY ->
--   short countdown -> ownership re-checked -> atomic swap -> both profiles saved
--
-- Anti-scam / anti-dupe rules:
--   * any change to either offer clears both READY flags and the countdown
--   * offers are validated against the live inventory on every change AND again
--     at the moment of the swap (items enchanted/forged away mid-trade fail it)
--   * inventory actions (enchant, forge) are refused while a player is trading
--   * the swap moves the exact weapon records (uids are globally unique) and is
--     done in one server step; both profiles are saved immediately afterwards
--   * profiles are session-locked (Profiles.luau), so a player can't hop servers
--
-- Dependencies are injected so the whole flow runs in the headless tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Veil = ReplicatedStorage:WaitForChild("Veil")
local Items = require(Veil.Data.Items)

local Inventory = require(script.Parent.Inventory)

local Trading = {}
Trading.__index = Trading

local REQUEST_TTL = 30

-- deps: getProfile(p), send(p, msg), save(p), now(), isBusy(p)?, log(msg)?
function Trading.new(deps)
	local self = setmetatable({}, Trading)
	self.deps = deps
	self.requests = {} -- [target] = { [from] = expiry }
	self.trades = {} -- [player] = trade
	self.nextId = 1
	return self
end

function Trading:inTrade(p): boolean
	return self.trades[p] ~= nil
end

local function emptyOffer()
	return { weapons = {}, res = {} }
end

local function otherOf(t, p)
	return t.a == p and t.b or t.a
end

-- Validate an offer against an inventory. Returns a clean copy or nil + reason.
function Trading.validateOffer(inv, offer)
	if type(offer) ~= "table" then
		return nil, "bad offer"
	end
	local clean = emptyOffer()
	local seen = {}
	if offer.weapons ~= nil then
		if type(offer.weapons) ~= "table" then
			return nil, "bad offer"
		end
		for _, uid in offer.weapons do
			if type(uid) ~= "string" or seen[uid] then
				return nil, "bad weapon"
			end
			if not Inventory.findWeapon(inv, uid) then
				return nil, "you don't own that weapon"
			end
			seen[uid] = true
			table.insert(clean.weapons, uid)
			if #clean.weapons > Items.TradeMaxWeapons then
				return nil, "too many weapons (max " .. Items.TradeMaxWeapons .. ")"
			end
		end
	end
	if offer.res ~= nil then
		if type(offer.res) ~= "table" then
			return nil, "bad offer"
		end
		for id, n in offer.res do
			if not Items.ResourceById[id] then
				return nil, "unknown resource"
			end
			if type(n) ~= "number" or n ~= n or n < 0 or math.floor(n) ~= n then
				return nil, "bad amount"
			end
			if n > Inventory.count(inv, id) then
				return nil, "not enough " .. Items.ResourceById[id].name
			end
			if n > 0 then
				clean.res[id] = n
			end
		end
	end
	return clean
end

-- What the client is shown for an offer (weapon records resolved).
local function describe(inv, offer)
	local out = { weapons = {}, res = table.clone(offer.res) }
	for _, uid in offer.weapons do
		local w = Inventory.findWeapon(inv, uid)
		if w then
			table.insert(out.weapons, { uid = w.uid, item = w.item, ench = w.ench, lvl = w.lvl })
		end
	end
	return out
end

function Trading:broadcast(t)
	local now = self.deps.now()
	for _, p in { t.a, t.b } do
		local o = otherOf(t, p)
		local mine = self.deps.getProfile(p)
		local theirs = self.deps.getProfile(o)
		if mine and theirs then
			self.deps.send(p, {
				op = "state",
				id = t.id,
				with = o.UserId,
				mine = describe(mine.inv, t.offers[p]),
				theirs = describe(theirs.inv, t.offers[o]),
				readyMe = t.ready[p],
				readyThem = t.ready[o],
				countdown = t.confirmAt and math.max(0, t.confirmAt - now) or nil,
			})
		end
	end
end

function Trading:request(from, to)
	if from == to or not to or not to.Parent then
		return false, "can't trade with that player"
	end
	if self.trades[from] or self.trades[to] then
		return false, "already trading"
	end
	if self.deps.isBusy and (self.deps.isBusy(from) or self.deps.isBusy(to)) then
		return false, "player is in a match"
	end
	self.requests[to] = self.requests[to] or {}
	self.requests[to][from] = self.deps.now() + REQUEST_TTL
	self.deps.send(to, { op = "request", from = from.UserId, name = from.DisplayName })
	return true
end

function Trading:respond(to, from, accept: boolean)
	local list = self.requests[to]
	local exp = list and list[from]
	if not exp or exp < self.deps.now() then
		return false, "request expired"
	end
	list[from] = nil
	if not accept then
		self.deps.send(from, { op = "declined", by = to.UserId })
		return true
	end
	if self.trades[from] or self.trades[to] then
		return false, "already trading"
	end
	if not from.Parent then
		return false, "player left"
	end
	local t = {
		id = self.nextId,
		a = from,
		b = to,
		offers = { [from] = emptyOffer(), [to] = emptyOffer() },
		ready = { [from] = false, [to] = false },
		confirmAt = nil,
	}
	self.nextId += 1
	self.trades[from] = t
	self.trades[to] = t
	self.deps.send(from, { op = "open", id = t.id, with = to.UserId, name = to.DisplayName })
	self.deps.send(to, { op = "open", id = t.id, with = from.UserId, name = from.DisplayName })
	self:broadcast(t)
	return true
end

function Trading:offer(p, offer)
	local t = self.trades[p]
	if not t then
		return false, "not trading"
	end
	local prof = self.deps.getProfile(p)
	if not prof then
		return false, "no profile"
	end
	local clean, why = Trading.validateOffer(prof.inv, offer)
	if not clean then
		return false, why
	end
	t.offers[p] = clean
	-- any change resets both sides
	t.ready[t.a] = false
	t.ready[t.b] = false
	t.confirmAt = nil
	self:broadcast(t)
	return true
end

function Trading:setReady(p, on: boolean)
	local t = self.trades[p]
	if not t then
		return false, "not trading"
	end
	t.ready[p] = on == true
	if t.ready[t.a] and t.ready[t.b] then
		t.confirmAt = self.deps.now() + Items.TradeConfirmSeconds
	else
		t.confirmAt = nil
	end
	self:broadcast(t)
	return true
end

function Trading:close(t, reason: string, okResult)
	self.trades[t.a] = nil
	self.trades[t.b] = nil
	for _, p in { t.a, t.b } do
		if p.Parent then
			local prof = self.deps.getProfile(p)
			self.deps.send(p, {
				op = okResult and "done" or "closed",
				id = t.id,
				reason = reason,
				inv = prof and Inventory.snapshot(prof.inv) or nil,
			})
		end
	end
end

function Trading:cancel(p, reason: string?)
	local t = self.trades[p]
	if not t then
		return false
	end
	self:close(t, reason or "cancelled")
	return true
end

-- The swap. Re-validates both sides against the live inventories first.
function Trading:execute(t)
	local pa, pb = self.deps.getProfile(t.a), self.deps.getProfile(t.b)
	if not pa or not pb then
		self:close(t, "a profile is missing")
		return false
	end
	local oa = Trading.validateOffer(pa.inv, t.offers[t.a])
	local ob = Trading.validateOffer(pb.inv, t.offers[t.b])
	if not oa or not ob then
		self:close(t, "an item changed during the trade")
		return false
	end
	-- capacity
	if #pa.inv.weapons - #oa.weapons + #ob.weapons > Items.MaxWeapons or #pb.inv.weapons - #ob.weapons + #oa.weapons > Items.MaxWeapons then
		self:close(t, "inventory full")
		return false
	end
	-- move weapons (same records, same uids)
	local moveA, moveB = {}, {}
	for _, uid in oa.weapons do
		table.insert(moveA, Inventory.takeWeapon(pa.inv, uid))
	end
	for _, uid in ob.weapons do
		table.insert(moveB, Inventory.takeWeapon(pb.inv, uid))
	end
	for _, rec in moveA do
		table.insert(pb.inv.weapons, rec)
	end
	for _, rec in moveB do
		table.insert(pa.inv.weapons, rec)
	end
	-- move resources
	Inventory.spend(pa.inv, oa.res)
	Inventory.spend(pb.inv, ob.res)
	Inventory.addResources(pb.inv, oa.res)
	Inventory.addResources(pa.inv, ob.res)
	pa.stats.trades = (pa.stats.trades or 0) + 1
	pb.stats.trades = (pb.stats.trades or 0) + 1
	if self.deps.log then
		self.deps.log(string.format("trade %d: %d -> %d [%s] / %d -> %d [%s]", t.id, t.a.UserId, t.b.UserId, table.concat(oa.weapons, ","), t.b.UserId, t.a.UserId, table.concat(ob.weapons, ",")))
	end
	self:close(t, "trade complete", true)
	self.deps.save(t.a)
	self.deps.save(t.b)
	return true
end

-- Call regularly: finishes countdowns and expires stale requests.
function Trading:step()
	local now = self.deps.now()
	local done = {}
	for _, t in self.trades do
		if t.confirmAt and now >= t.confirmAt and not done[t] then
			done[t] = true
		end
	end
	for t in done do
		self:execute(t)
	end
	for to, list in self.requests do
		for from, exp in list do
			if exp < now then
				list[from] = nil
			end
		end
		if next(list) == nil then
			self.requests[to] = nil
		end
	end
end

function Trading:playerLeft(p)
	self:cancel(p, "the other player left")
	self.requests[p] = nil
	for _, list in self.requests do
		list[p] = nil
	end
end

-- Pending incoming requests for a player: { { from = Player, expires } }
function Trading:incoming(p)
	local out = {}
	for from, exp in self.requests[p] or {} do
		table.insert(out, { from = from, expires = exp })
	end
	return out
end

return Trading
