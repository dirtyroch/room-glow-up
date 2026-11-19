--!strict
-- A monthly designer track. Points never go down inside the month.
-- The month id is the calendar month, not the holiday or winter theme season.

local function sibling(name: string): any
	local ok, loaded = pcall(function()
		local child = script.Parent:WaitForChild(name)
		return (require :: any)(child)
	end)
	if ok then
		return loaded
	end
	return (require :: any)("./" .. name)
end

local Season = sibling("Season")

local Rank = {}

function Rank.month(unix: number, offsetHours: number): string
	local parts = Season.parts(unix, offsetHours)
	return string.format("%04d-%02d", parts.year, parts.month)
end

local function claimed(profile: { [string]: any }, index: number): boolean
	local list = profile.rankClaimed
	if type(list) ~= "table" then
		return false
	end
	for _, entry in ipairs(list) do
		if entry == index then
			return true
		end
	end
	return false
end

-- Adding zero points leaves the score where it is. There is no decay step.
function Rank.award(profile: { [string]: any }, monthId: string, points: number, track: { any }): { [string]: any }
	if profile.rankMonth ~= monthId then
		profile.rankMonth = monthId
		profile.rankPoints = 0
		profile.rankClaimed = {}
	end
	local gain = points
	if type(gain) ~= "number" or gain ~= gain or gain < 0 then
		gain = 0
	end
	gain = math.floor(gain)
	if gain > 0 then
		profile.rankPoints += gain
	end
	local coins = 0
	local tiers: { number } = {}
	for index, tier in ipairs(track) do
		if profile.rankPoints >= tier.points and not claimed(profile, index) then
			if type(profile.rankClaimed) ~= "table" then
				profile.rankClaimed = {}
			end
			table.insert(profile.rankClaimed, index)
			coins += tier.coins
			table.insert(tiers, index)
		end
	end
	if coins > 0 then
		profile.coins += coins
	end
	return { coins = coins, tiers = tiers, points = profile.rankPoints }
end

return Rank
