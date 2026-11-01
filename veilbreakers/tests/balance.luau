-- Combat-balance fingerprint: every number that affects a fight (health, weight,
-- walk speed, and each move's frame data, damage, guard, advantage, hitboxes,
-- projectiles...). Cosmetic data (names, looks, lines, personality) is excluded.
local Balance = {}

local SKIP = { name = true, input = true, anim = true, sfx = true, hitSfx = true, element = true, trail = true, desc = true }

local function walk(v, out, path)
	local t = type(v)
	if t == "table" then
		local keys = {}
		for k in v do
			if not SKIP[k] then
				table.insert(keys, tostring(k))
			end
		end
		table.sort(keys)
		for _, k in keys do
			local val = v[k]
			if val == nil then
				val = v[tonumber(k)]
			end
			walk(val, out, path .. "." .. k)
		end
	elseif t == "number" or t == "boolean" or t == "string" then
		table.insert(out, path .. "=" .. tostring(v))
	end
end

function Balance.fingerprint(Fighters)
	local out = {}
	local ids = {}
	for _, f in Fighters.list do
		table.insert(ids, f.id)
	end
	table.sort(ids)
	for _, id in ids do
		local f = Fighters.byId[id]
		walk({ health = f.health, walkMult = f.walkMult, weight = f.weight, moves = f.moves }, out, id)
	end
	local s = table.concat(out, ";")
	local h = 0
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return h, #out
end

return Balance
