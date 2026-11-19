--!strict
-- Hooks for a later shop. This milestone does not sell anything.
-- The server owns every source. Client actions cannot set them.

local Monetization = {}

local coinSource = function(_userId: string?): number
	return 1
end

local slotSource = function(_userId: string?): number
	return 0
end

local luckSource = function(_userId: string?): boolean
	return false
end

function Monetization.setCoinSource(fn: (string?) -> number)
	coinSource = fn
end

function Monetization.coinMultiplier(userId: string?): number
	local n = coinSource(userId)
	if type(n) ~= "number" or n ~= n or n < 0 then
		return 1
	end
	return n
end

function Monetization.setSlotSource(fn: (string?) -> number)
	slotSource = fn
end

function Monetization.extraDreamSlots(userId: string?): number
	local n = slotSource(userId)
	if type(n) ~= "number" or n ~= n then
		return 0
	end
	return math.max(0, math.floor(n))
end

function Monetization.setLuckSource(fn: (string?) -> boolean)
	luckSource = fn
end

function Monetization.luck(userId: string?): boolean
	return luckSource(userId) == true
end

function Monetization.reset()
	coinSource = function(_userId: string?): number
		return 1
	end
	slotSource = function(_userId: string?): number
		return 0
	end
	luckSource = function(_userId: string?): boolean
		return false
	end
end

return Monetization
