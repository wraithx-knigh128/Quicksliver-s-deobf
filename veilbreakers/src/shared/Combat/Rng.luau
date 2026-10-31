--!nonstrict
-- Tiny deterministic PRNG (xorshift32) so matches and CPU behaviour replay identically
-- in Roblox and in headless tests.

local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number?)
	local self = setmetatable({}, Rng)
	local s = math.floor(seed or 123456789) % 4294967296
	if s == 0 then
		s = 2463534242
	end
	self.state = s
	return self
end

function Rng:nextInt(): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

-- [0, 1)
function Rng:next(): number
	return self:nextInt() / 4294967296
end

function Rng:range(a: number, b: number): number
	return a + (b - a) * self:next()
end

function Rng:int(a: number, b: number): number
	return a + (self:nextInt() % (b - a + 1))
end

function Rng:chance(p: number): boolean
	return self:next() < p
end

function Rng:pick(list: { any }): any
	if #list == 0 then
		return nil
	end
	return list[self:int(1, #list)]
end

return Rng
