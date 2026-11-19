--!nocheck
-- Small seeded generator with the Random.new method names the bots use.
local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number)
	return setmetatable({ s = (math.floor(seed) % 2147483646) + 1 }, Rng)
end

function Rng:NextNumber(lo: number?, hi: number?): number
	self.s = (self.s * 16807) % 2147483647
	local u = (self.s - 1) / 2147483646
	if lo == nil then
		return u
	end
	return lo + (hi - lo) * u
end

function Rng:NextInteger(lo: number, hi: number): number
	return math.min(hi, lo + math.floor(self:NextNumber() * (hi - lo + 1)))
end

return Rng
