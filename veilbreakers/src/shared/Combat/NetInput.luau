--!nonstrict
-- Compact input encoding for online matches: one integer per player per frame.
-- Directions are absolute (left / right on screen), exactly what Engine.step takes.

local NetInput = {}

NetInput.KEYS = { "left", "right", "up", "down", "L", "H", "K", "S", "B", "E", "X", "P1", "P2", "P3", "P4" }
NetInput.MAX = 2 ^ #NetInput.KEYS - 1

function NetInput.encode(inp): number
	local m = 0
	for i, k in NetInput.KEYS do
		if inp[k] then
			m += 2 ^ (i - 1)
		end
	end
	return m
end

function NetInput.decode(m: number)
	local out = {}
	local v = math.floor(m)
	for _, k in NetInput.KEYS do
		out[k] = v % 2 == 1
		v = math.floor(v / 2)
	end
	return out
end

-- Bitwise OR for two masks (no bit32 dependency so it runs anywhere).
function NetInput.union(a: number, b: number): number
	local out, bit = 0, 1
	a, b = math.floor(a), math.floor(b)
	while a > 0 or b > 0 do
		if a % 2 == 1 or b % 2 == 1 then
			out += bit
		end
		a, b = math.floor(a / 2), math.floor(b / 2)
		bit *= 2
	end
	return out
end

function NetInput.valid(m): boolean
	return type(m) == "number" and m == m and m >= 0 and m <= NetInput.MAX and math.floor(m) == m
end

return NetInput
