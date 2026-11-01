--!nonstrict
-- Tradeable items: resources, weapon skins and enchantments.
--
-- Everything here is COSMETIC. A weapon skin changes how a fighter's weapon looks;
-- an enchantment adds visual effects (particles, glow, trail colour). None of it
-- touches frame data, damage, health or meter, so no fighter is buffed or nerfed.
-- (tests/run.luau checks the combat data against a fixed checksum.)
--
-- Weapons are unique records { uid, item, ench }; resources are stack counts.
-- The server owns every roll (enchant altar, forge, drops); clients only ask.

local Items = {}

Items.RARITIES = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }
Items.RARITY = {
	common = { order = 1, name = "COMMON", color = "#C8C8C8" },
	uncommon = { order = 2, name = "UNCOMMON", color = "#5BD15B" },
	rare = { order = 3, name = "RARE", color = "#4AA8FF" },
	epic = { order = 4, name = "EPIC", color = "#B65CFF" },
	legendary = { order = 5, name = "LEGENDARY", color = "#FFB02E" },
	mythic = { order = 6, name = "MYTHIC", color = "#FF4A6A" },
}

-------------------------------------------------------------------------------
-- Resources
-------------------------------------------------------------------------------

Items.Resources = {
	{ id = "studs", name = "Loose Studs", rarity = "common", desc = "Fell off a 2008 build. Everyone has a pocket full." },
	{ id = "scrap", name = "Free Model Scrap", rarity = "common", desc = "Salvaged from the toolbox. Mostly safe. Mostly." },
	{ id = "glitch", name = "Glitch Shard", rarity = "uncommon", desc = "A piece of a texture that failed to load." },
	{ id = "relic", name = "Enchant Relic", rarity = "rare", desc = "Offer one at the Enchant Altar to roll a new enchantment." },
	{ id = "token", name = "Admin Token", rarity = "epic", desc = "Dropped by someone who definitely bought admin." },
	{ id = "essence", name = "Oof Essence", rarity = "legendary", desc = "The distilled sound of a thousand resets." },
}
Items.ResourceById = {}
for _, r in Items.Resources do
	Items.ResourceById[r.id] = r
end

-------------------------------------------------------------------------------
-- Weapon types (one per fighter weapon) and skins
-------------------------------------------------------------------------------

-- weapon type -> display name (types match Looks.WEAPON keys)
Items.WeaponTypes = {
	{ id = "katana", name = "Katana" },
	{ id = "spear", name = "Spear" },
	{ id = "brick_fists", name = "Brick Fists" },
	{ id = "daggers", name = "Daggers" },
	{ id = "hammer", name = "Hammer" },
	{ id = "chakram", name = "Hula Hoops" },
	{ id = "crossbow", name = "Crossbow" },
	{ id = "greatsword", name = "Greatsword" },
}
Items.WeaponTypeById = {}
for _, t in Items.WeaponTypes do
	Items.WeaponTypeById[t.id] = t
end

-- Skin colours: primary = metal / main body, secondary = handle / wood / leather,
-- glow = neon accents and trail. primaryMat replaces metal materials.
Items.Weapons = {
	-- katana
	{ id = "katana_bloxy", type = "katana", name = "Bloxy Blade", rarity = "uncommon", primary = "#F2C94C", primaryMat = "Foil", secondary = "#3A2410", glow = "#FFE27A" },
	{ id = "katana_neon", type = "katana", name = "Neon Katana", rarity = "rare", primary = "#1BE7FF", primaryMat = "Neon", secondary = "#101418", glow = "#7FF6FF" },
	{ id = "katana_404", type = "katana", name = "Error 404 Edge", rarity = "epic", primary = "#111111", primaryMat = "Glass", secondary = "#FF2BD6", glow = "#FF2BD6" },
	{ id = "katana_starter", type = "katana", name = "Starter Katana", rarity = "common", primary = "#A9B3BC", primaryMat = "Metal", secondary = "#2A1C12", glow = "#58B4FF" },
	-- spear
	{ id = "spear_wings", type = "spear", name = "Wingspan Lance", rarity = "rare", primary = "#FFFFFF", primaryMat = "Glass", secondary = "#FFB6E1", glow = "#FF8FCB" },
	{ id = "spear_rust", type = "spear", name = "Rusty Pool Noodle", rarity = "common", primary = "#B4652A", primaryMat = "CorrodedMetal", secondary = "#4A3A2A", glow = "#FF9A4A" },
	{ id = "spear_void", type = "spear", name = "Void Pike", rarity = "epic", primary = "#1A0E2A", primaryMat = "Glass", secondary = "#3A1A5A", glow = "#B65CFF" },
	-- brick fists
	{ id = "fists_gold", type = "brick_fists", name = "Golden Bricks", rarity = "rare", primary = "#E8B53A", primaryMat = "Foil", secondary = "#E8B53A", glow = "#FFE27A" },
	{ id = "fists_lego", type = "brick_fists", name = "Rainbow Bricks", rarity = "uncommon", primary = "#4B974B", primaryMat = "SmoothPlastic", secondary = "#F5CD30", glow = "#7DFF8C" },
	{ id = "fists_obsidian", type = "brick_fists", name = "Obsidian Blocks", rarity = "epic", primary = "#15121C", primaryMat = "Basalt", secondary = "#2A1A3A", glow = "#FF4A2A" },
	-- daggers
	{ id = "daggers_ghost", type = "daggers", name = "Ghost Shivs", rarity = "rare", primary = "#E8F4FF", primaryMat = "ForceField", secondary = "#101018", glow = "#9FEFFF" },
	{ id = "daggers_red", type = "daggers", name = "Redline Knives", rarity = "uncommon", primary = "#C4281C", primaryMat = "Metal", secondary = "#1A1414", glow = "#FF4A4A" },
	{ id = "daggers_666", type = "daggers", name = "Daggers 666", rarity = "legendary", primary = "#0A0A0A", primaryMat = "Glass", secondary = "#5A0A10", glow = "#FF1A1A" },
	-- hammer
	{ id = "hammer_ice", type = "hammer", name = "Glacier Mallet", rarity = "rare", primary = "#BDEBFF", primaryMat = "Ice", secondary = "#3A5A7A", glow = "#7FE3FF" },
	{ id = "hammer_toy", type = "hammer", name = "Squeaky Toy Hammer", rarity = "common", primary = "#FF3A3A", primaryMat = "SmoothPlastic", secondary = "#F5CD30", glow = "#FFE14A" },
	{ id = "hammer_ban", type = "hammer", name = "The Ban Hammer", rarity = "legendary", primary = "#2A2A2E", primaryMat = "DiamondPlate", secondary = "#C4281C", glow = "#FF3A3A" },
	-- chakram (hula hoops)
	{ id = "hoops_disco", type = "chakram", name = "Disco Hoops", rarity = "rare", primary = "#E8E8E8", primaryMat = "Glass", secondary = "#FF4AD8", glow = "#FF8AF0" },
	{ id = "hoops_basic", type = "chakram", name = "Gym Class Hoops", rarity = "common", primary = "#3A8AFF", primaryMat = "SmoothPlastic", secondary = "#FFFFFF", glow = "#8AC8FF" },
	{ id = "hoops_sun", type = "chakram", name = "Solar Rings", rarity = "epic", primary = "#FFB02E", primaryMat = "Foil", secondary = "#7A3A0A", glow = "#FFD86A" },
	-- crossbow
	{ id = "bow_camo", type = "crossbow", name = "Bush Camo Crossbow", rarity = "uncommon", primary = "#3A5A2A", primaryMat = "Grass", secondary = "#2A3A1A", glow = "#9AFF5A" },
	{ id = "bow_sniper", type = "crossbow", name = "No-Scope Repeater", rarity = "rare", primary = "#1A1C20", primaryMat = "Metal", secondary = "#4A4A52", glow = "#FF3A3A" },
	{ id = "bow_vip", type = "crossbow", name = "VIP Crossbow", rarity = "legendary", primary = "#F2C94C", primaryMat = "Foil", secondary = "#FFFFFF", glow = "#FFE27A" },
	-- greatsword
	{ id = "great_admin", type = "greatsword", name = "Command Blade", rarity = "epic", primary = "#0A0A0A", primaryMat = "Glass", secondary = "#FFB02E", glow = "#FFB02E" },
	{ id = "great_noob", type = "greatsword", name = "Big Noob Sword", rarity = "common", primary = "#F5CD30", primaryMat = "SmoothPlastic", secondary = "#0D69AC", glow = "#A4BD47" },
	{ id = "great_cosmic", type = "greatsword", name = "Cosmic Buster", rarity = "mythic", primary = "#140A2A", primaryMat = "Glass", secondary = "#6A3AFF", glow = "#C89AFF" },
}
Items.WeaponById = {}
for _, w in Items.Weapons do
	Items.WeaponById[w.id] = w
end

-------------------------------------------------------------------------------
-- Enchantments (cosmetic visual effects only)
-------------------------------------------------------------------------------

-- fx: particles = particle preset, color = effect colour, light = glow colour,
-- trail = trail colour override, animated = per-frame effect kind
Items.Enchantments = {
	{ id = "blazing", name = "Blazing", rarity = "common", weight = 220, desc = "On fire. Permanently. Somehow fine.", fx = { particles = "fire", color = "#FF7A2A", light = "#FF8A3A", trail = "#FF7A2A" } },
	{ id = "frostbite", name = "Frostbite", rarity = "common", weight = 220, desc = "Leaves a little frost on everything it touches.", fx = { particles = "frost", color = "#BDEBFF", light = "#7FE3FF", trail = "#9FEFFF" } },
	{ id = "bubbly", name = "Bubbly", rarity = "uncommon", weight = 150, desc = "Blows bubbles. Very intimidating.", fx = { particles = "bubbles", color = "#BDF4FF", light = "#8AD8FF", trail = "#BDF4FF" } },
	{ id = "toxic", name = "Toxic", rarity = "uncommon", weight = 140, desc = "Drips something green. Do not lick.", fx = { particles = "drip", color = "#7DFF4A", light = "#5AFF3A", trail = "#7DFF4A" } },
	{ id = "stormcaller", name = "Stormcaller", rarity = "rare", weight = 85, desc = "Crackles with static, like a 2009 voice chat.", fx = { particles = "sparks", color = "#9FD8FF", light = "#7FC8FF", trail = "#C8E8FF" } },
	{ id = "void", name = "Void", rarity = "rare", weight = 80, desc = "Swallows light. And the occasional texture.", fx = { particles = "smoke", color = "#3A1A5A", light = "#8A3AFF", trail = "#6A2ACF" } },
	{ id = "golden", name = "Golden", rarity = "epic", weight = 40, desc = "Turns the weapon to solid gold. Purely for flex.", fx = { particles = "sparkle", color = "#FFE27A", light = "#FFD24A", trail = "#FFE27A", gold = true } },
	{ id = "glitched", name = "Glitched", rarity = "epic", weight = 38, desc = "Flickers between textures that never finished loading.", fx = { particles = "sparks", color = "#FF2BD6", light = "#2BE7FF", trail = "#FF2BD6", animated = "glitch" } },
	{ id = "rainbow", name = "Rainbow", rarity = "legendary", weight = 14, desc = "Cycles every colour. Bought with zero Robux.", fx = { particles = "sparkle", color = "#FFFFFF", light = "#FFFFFF", animated = "rainbow" } },
	{ id = "oof", name = "Certified Oof", rarity = "mythic", weight = 3, desc = "Every swing remembers the old death sound.", fx = { particles = "embers", color = "#FF3A3A", light = "#FF2A2A", trail = "#FF3A3A", animated = "pulse" } },
}
Items.EnchantById = {}
for _, e in Items.Enchantments do
	Items.EnchantById[e.id] = e
end

-------------------------------------------------------------------------------
-- Economy (all rolls happen on the server)
-------------------------------------------------------------------------------

Items.EnchantCost = { relic = 1, studs = 15 }
Items.ForgeCost = { scrap = 25, studs = 40 }
Items.MaxWeapons = 150
Items.MaxResource = 99999

-- Forge rarity weights for a new weapon of a chosen type.
Items.ForgeWeights = { common = 50, uncommon = 28, rare = 14, epic = 6, legendary = 1.8, mythic = 0.2 }

-- Rewards. Online matches are simulated by the server, so they pay out properly.
-- CPU fights run on the player's own device and can't be verified, so they pay a
-- small, rate-limited amount and never drop weapons.
Items.Rewards = {
	onlineWin = { studs = { 20, 35 }, scrap = { 8, 14 }, glitch = { 2, 4 }, relic = 0.35, token = 0.05, essence = 0.01, weapon = 0.15 },
	onlineLoss = { studs = { 10, 18 }, scrap = { 4, 8 }, glitch = { 0, 2 }, relic = 0.12, token = 0.01, essence = 0, weapon = 0.05 },
	offline = { studs = { 5, 9 }, scrap = { 2, 4 }, glitch = { 0, 1 }, relic = 0.03, token = 0, essence = 0, weapon = 0 },
}
Items.OfflineClaimInterval = 45 -- seconds between CPU-fight claims
Items.OfflineClaimsPerDay = 60
Items.PairRewardsPerHour = 4 -- rewarded online matches between the same two players

Items.StarterPack = { studs = 60, scrap = 30, glitch = 3, relic = 2 }

-- Trades
Items.TradeMaxWeapons = 8
Items.TradeConfirmSeconds = 3

-------------------------------------------------------------------------------
-- Rarity pays: the reward bonus (an economy buff, never a combat one)
-------------------------------------------------------------------------------

-- The weapon you fight with boosts every resource you earn from that fight:
-- its skin rarity + its enchantment rarity + its upgrade level.
Items.RarityBonus = { common = 0.05, uncommon = 0.10, rare = 0.18, epic = 0.28, legendary = 0.40, mythic = 0.60 }
Items.EnchantBonus = { common = 0.03, uncommon = 0.05, rare = 0.08, epic = 0.12, legendary = 0.18, mythic = 0.25 }
Items.LevelBonus = 0.04 -- per upgrade level above 1
Items.MaxLevel = 10
Items.MaxBonus = 1.5 -- +150% at most

-- Fraction (0.28 = +28%) a weapon record adds to rewards.
function Items.rewardBonus(rec): number
	if not rec then
		return 0
	end
	local def = Items.WeaponById[rec.item]
	if not def then
		return 0
	end
	local b = Items.RarityBonus[def.rarity] or 0
	local e = rec.ench and Items.EnchantById[rec.ench]
	if e then
		b += Items.EnchantBonus[e.rarity] or 0
	end
	b += Items.LevelBonus * (math.clamp(rec.lvl or 1, 1, Items.MaxLevel) - 1)
	return math.min(b, Items.MaxBonus)
end

-- Cost to raise a weapon from `level` to `level + 1`.
function Items.upgradeCost(level: number)
	local c = { studs = math.floor(30 * level ^ 1.6 + 0.5), scrap = 6 * level }
	if level >= 4 then
		c.glitch = level - 3
	end
	if level >= 8 then
		c.token = 1
	end
	return c
end

-- What salvaging a weapon pays: by skin rarity, plus half the studs and scrap
-- spent upgrading it.
Items.SalvageByRarity = {
	common = { studs = 15, scrap = 5 },
	uncommon = { studs = 30, scrap = 10, glitch = 1 },
	rare = { studs = 60, scrap = 18, glitch = 2 },
	epic = { studs = 120, scrap = 30, glitch = 4, relic = 1 },
	legendary = { studs = 250, scrap = 60, glitch = 8, relic = 2, token = 1 },
	mythic = { studs = 500, scrap = 120, glitch = 15, relic = 4, token = 2, essence = 1 },
}
function Items.salvageValue(rec)
	local def = Items.WeaponById[rec.item]
	local out = table.clone(Items.SalvageByRarity[def and def.rarity or "common"] or Items.SalvageByRarity.common)
	for lv = 1, math.clamp(rec.lvl or 1, 1, Items.MaxLevel) - 1 do
		local c = Items.upgradeCost(lv)
		out.studs = (out.studs or 0) + math.floor(c.studs * 0.5)
		out.scrap = (out.scrap or 0) + math.floor(c.scrap * 0.5)
	end
	if rec.ench then
		local e = Items.EnchantById[rec.ench]
		local order = e and Items.RARITY[e.rarity].order or 1
		out.glitch = (out.glitch or 0) + order
	end
	return out
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

function Items.weaponTypeOf(fighterDef): string?
	return fighterDef and fighterDef.look and fighterDef.look.weapon
end

-- Weighted pick from a list of { id, weight } with a 0..1 random number.
function Items.weightedPick(list, r: number)
	local total = 0
	for _, e in list do
		total += e.weight
	end
	local x = r * total
	for _, e in list do
		x -= e.weight
		if x <= 0 then
			return e
		end
	end
	return list[#list]
end

function Items.weaponsOfType(weaponType: string)
	local out = {}
	for _, w in Items.Weapons do
		if w.type == weaponType then
			table.insert(out, w)
		end
	end
	return out
end

-- Readable name for a weapon record: "Neon Katana +3  ·  Blazing".
function Items.weaponLabel(rec): string
	local def = Items.WeaponById[rec.item]
	local name = def and def.name or rec.item
	if (rec.lvl or 1) > 1 then
		name ..= " +" .. tostring(rec.lvl - 1)
	end
	local e = rec.ench and Items.EnchantById[rec.ench]
	if e then
		return name .. "  \u{00B7}  " .. e.name
	end
	return name
end

return Items
