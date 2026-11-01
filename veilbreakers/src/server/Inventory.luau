--!nonstrict
-- Server-side inventory rules. Pure functions over a profile's `inv` table so they
-- can be unit-tested without Roblox. Every mutation validates ownership, counts and
-- item ids; randomness comes from an injected rand() returning [0, 1).
--
-- inv = {
--   res = { [resourceId] = count },
--   weapons = { { uid = "w123-4", item = "katana_neon", ench = "blazing"? } },
--   equipped = { [fighterId] = uid },
--   nextUid = 1,
-- }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Veil = ReplicatedStorage:WaitForChild("Veil")
local Items = require(Veil.Data.Items)
local Fighters = require(Veil.Data.Fighters)

local Inventory = {}

local function isInt(n): boolean
	return type(n) == "number" and n == n and n >= 0 and n <= Items.MaxResource and math.floor(n) == n
end

function Inventory.new()
	local inv = { res = {}, weapons = {}, equipped = {}, nextUid = 1 }
	for id, n in Items.StarterPack do
		inv.res[id] = n
	end
	return inv
end

-- Keep only valid data (used on load; never trust what was stored).
function Inventory.sanitize(raw)
	if type(raw) ~= "table" then
		return Inventory.new()
	end
	local inv = { res = {}, weapons = {}, equipped = {}, nextUid = 1 }
	if type(raw.res) == "table" then
		for _, r in Items.Resources do
			local n = raw.res[r.id]
			if isInt(n) then
				inv.res[r.id] = n
			end
		end
	end
	local seen = {}
	if type(raw.weapons) == "table" then
		for _, w in raw.weapons do
			if #inv.weapons >= Items.MaxWeapons then
				break
			end
			if type(w) == "table" and type(w.uid) == "string" and #w.uid <= 40 and not seen[w.uid] and Items.WeaponById[w.item] then
				local ench = (type(w.ench) == "string" and Items.EnchantById[w.ench]) and w.ench or nil
				seen[w.uid] = true
				table.insert(inv.weapons, { uid = w.uid, item = w.item, ench = ench })
			end
		end
	end
	if type(raw.equipped) == "table" then
		for fid, uid in raw.equipped do
			if type(fid) == "string" and Fighters.byId[fid] and type(uid) == "string" and seen[uid] then
				inv.equipped[fid] = uid
			end
		end
	end
	if isInt(raw.nextUid) and raw.nextUid >= 1 then
		inv.nextUid = raw.nextUid
	end
	return inv
end

function Inventory.findWeapon(inv, uid: string)
	for i, w in inv.weapons do
		if w.uid == uid then
			return w, i
		end
	end
	return nil, nil
end

function Inventory.count(inv, resId: string): number
	return inv.res[resId] or 0
end

function Inventory.canAfford(inv, cost): boolean
	for id, n in cost do
		if Inventory.count(inv, id) < n then
			return false
		end
	end
	return true
end

function Inventory.spend(inv, cost): boolean
	if not Inventory.canAfford(inv, cost) then
		return false
	end
	for id, n in cost do
		inv.res[id] = Inventory.count(inv, id) - n
	end
	return true
end

function Inventory.addResources(inv, add)
	for id, n in add do
		if Items.ResourceById[id] and isInt(n) then
			inv.res[id] = math.min(Items.MaxResource, Inventory.count(inv, id) + n)
		end
	end
end

-- uid prefix keeps ids unique across all players even after trades.
function Inventory.addWeapon(inv, ownerId: number, item: string, ench: string?)
	if not Items.WeaponById[item] or #inv.weapons >= Items.MaxWeapons then
		return nil
	end
	local uid = string.format("w%d-%d", ownerId, inv.nextUid)
	inv.nextUid += 1
	local rec = { uid = uid, item = item, ench = (ench and Items.EnchantById[ench]) and ench or nil }
	table.insert(inv.weapons, rec)
	return rec
end

-- Remove a weapon (unequips it everywhere). Returns the record.
function Inventory.takeWeapon(inv, uid: string)
	local w, i = Inventory.findWeapon(inv, uid)
	if not w then
		return nil
	end
	table.remove(inv.weapons, i)
	for fid, e in inv.equipped do
		if e == uid then
			inv.equipped[fid] = nil
		end
	end
	return w
end

-- Equip a weapon skin on a fighter whose weapon type matches (nil uid = default).
function Inventory.equip(inv, fighterId: string, uid: string?): (boolean, string?)
	local def = Fighters.byId[fighterId]
	if not def then
		return false, "unknown fighter"
	end
	if uid == nil then
		inv.equipped[fighterId] = nil
		return true
	end
	local w = Inventory.findWeapon(inv, uid)
	if not w then
		return false, "you don't own that weapon"
	end
	local wdef = Items.WeaponById[w.item]
	if wdef.type ~= Items.weaponTypeOf(def) then
		return false, def.name .. " can't use a " .. (Items.WeaponTypeById[wdef.type] and Items.WeaponTypeById[wdef.type].name or wdef.type)
	end
	inv.equipped[fighterId] = uid
	return true
end

-- Enchant Altar: spend the cost, roll a weighted enchantment (replaces the old one).
function Inventory.enchant(inv, uid: string, rand: () -> number): (boolean, string?)
	local w = Inventory.findWeapon(inv, uid)
	if not w then
		return false, "you don't own that weapon"
	end
	if not Inventory.spend(inv, Items.EnchantCost) then
		return false, "not enough resources"
	end
	local e = Items.weightedPick(Items.Enchantments, rand())
	w.ench = e.id
	return true, e.id
end

local function rarityPick(weights, rand)
	local list = {}
	for _, r in Items.RARITIES do
		table.insert(list, { id = r, weight = weights[r] or 0 })
	end
	return Items.weightedPick(list, rand()).id
end

-- Pick a weapon skin of a type at a rolled rarity (falls back to the nearest rarity).
local function rollSkin(weaponType: string, rand)
	local pool = Items.weaponsOfType(weaponType)
	if #pool == 0 then
		return nil
	end
	local want = Items.RARITY[rarityPick(Items.ForgeWeights, rand)].order
	local best, bestD = {}, math.huge
	for _, w in pool do
		local d = math.abs(Items.RARITY[w.rarity].order - want)
		if d < bestD then
			best, bestD = { w }, d
		elseif d == bestD then
			table.insert(best, w)
		end
	end
	return best[math.floor(rand() * #best) + 1] or best[1]
end
Inventory.rollSkin = rollSkin

-- Forge: spend scrap + studs for a random skin of the chosen weapon type.
function Inventory.forge(inv, ownerId: number, weaponType: string, rand: () -> number)
	if not Items.WeaponTypeById[weaponType] then
		return nil, "unknown weapon type"
	end
	if #inv.weapons >= Items.MaxWeapons then
		return nil, "inventory full"
	end
	if not Inventory.spend(inv, Items.ForgeCost) then
		return nil, "not enough resources"
	end
	local skin = rollSkin(weaponType, rand)
	return Inventory.addWeapon(inv, ownerId, skin.id, nil)
end

-- Roll a reward table ({ min, max } ranges or a 0..1 chance) into concrete amounts.
function Inventory.rollRewards(spec, rand: () -> number)
	local out = { res = {}, weapon = nil }
	for _, r in Items.Resources do
		local v = spec[r.id]
		if type(v) == "table" then
			local n = v[1] + math.floor(rand() * (v[2] - v[1] + 1))
			if n > 0 then
				out.res[r.id] = n
			end
		elseif type(v) == "number" and v > 0 and rand() < v then
			out.res[r.id] = 1
		end
	end
	if (spec.weapon or 0) > 0 and rand() < spec.weapon then
		local t = Items.WeaponTypes[math.floor(rand() * #Items.WeaponTypes) + 1]
		local skin = rollSkin(t.id, rand)
		out.weapon = skin and skin.id or nil
	end
	return out
end

function Inventory.applyRewards(inv, ownerId: number, rewards)
	Inventory.addResources(inv, rewards.res or {})
	local rec = nil
	if rewards.weapon then
		rec = Inventory.addWeapon(inv, ownerId, rewards.weapon, nil)
	end
	return rec
end

-- The cosmetic a fighter wears in a fight: { item, ench } or nil.
function Inventory.cosmeticFor(inv, fighterId: string)
	local uid = inv.equipped[fighterId]
	if not uid then
		return nil
	end
	local w = Inventory.findWeapon(inv, uid)
	if not w then
		return nil
	end
	return { item = w.item, ench = w.ench }
end

-- Copy for the client.
function Inventory.snapshot(inv)
	local out = { res = table.clone(inv.res), weapons = {}, equipped = table.clone(inv.equipped) }
	for _, w in inv.weapons do
		table.insert(out.weapons, { uid = w.uid, item = w.item, ench = w.ench })
	end
	return out
end

return Inventory
