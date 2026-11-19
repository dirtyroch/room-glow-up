--!strict
-- Round twists. About one round in three, chosen here, announced at Theme Reveal.
-- Mystery Item is a free piece from a fixed list. It is not a crate roll.

local function parent(name: string): any
	local ok, loaded = pcall(function()
		local child = script.Parent.Parent:WaitForChild(name)
		return (require :: any)(child)
	end)
	if ok then
		return loaded
	end
	return (require :: any)("../" .. name)
end

local Config = parent("Config")

local Modifiers = {}

function Modifiers.pick(roundIndex: number): string?
	if type(roundIndex) ~= "number" or roundIndex ~= roundIndex then
		return nil
	end
	local n = math.floor(roundIndex)
	if n < 0 then
		return nil
	end
	local every = Config.Modifiers.Every
	if type(every) ~= "number" or every < 1 then
		every = 3
	end
	if n % every ~= (every - 1) then
		return nil
	end
	local order = Config.Modifiers.Order
	local turn = math.floor(n / every)
	local index = (turn % #order) + 1
	return order[index]
end

function Modifiers.label(id: string?): string
	if type(id) ~= "string" then
		return ""
	end
	local text = Config.Modifiers.Labels[id]
	if type(text) ~= "string" then
		return ""
	end
	return text
end

-- Lobby stays quiet. Theme Reveal and the rest of the round announce it.
function Modifiers.announce(id: string?, phase: string): string
	if phase == "Lobby" or id == nil or id == "" then
		return ""
	end
	return Modifiers.label(id)
end

function Modifiers.buildSeconds(base: number, id: string?): number
	if id == "speed" then
		local speed = Config.Modifiers.SpeedBuild
		if type(speed) == "number" and speed == speed and speed > 0 then
			return speed
		end
	end
	return base
end

-- Tiny Budget never drops below the cheapest piece a new player can place.
function Modifiers.budget(base: number, id: string?, floorCost: number?): number
	if id ~= "tiny" then
		return base
	end
	local tiny = Config.Modifiers.TinyBudget
	if type(tiny) ~= "number" or tiny ~= tiny or tiny < 0 then
		tiny = 0
	end
	tiny = math.floor(tiny)
	local floor = floorCost or 0
	if type(floor) ~= "number" or floor ~= floor or floor < 0 then
		floor = 0
	end
	floor = math.floor(floor)
	if tiny < floor then
		return floor
	end
	return tiny
end

function Modifiers.allowsTime(id: string?): boolean
	return id ~= "speed"
end

function Modifiers.mystery(roundType: string, roundIndex: number): string
	local pools = Config.Modifiers.Mystery
	local pool = pools[roundType]
	if type(pool) ~= "table" or #pool < 1 then
		pool = pools.room
	end
	local n = roundIndex
	if type(n) ~= "number" or n ~= n then
		n = 0
	end
	local index = (math.floor(math.abs(n)) % #pool) + 1
	return pool[index]
end

-- Tour copy. Names passed in are ignored on purpose.
function Modifiers.tourLine(index: number, total: number, _names: { string }?): string
	local shown = index
	local count = total
	if type(shown) ~= "number" or shown < 1 then
		shown = 1
	end
	if type(count) ~= "number" or count < 1 then
		count = 1
	end
	return string.format("Room %d of %d", math.floor(shown), math.floor(count))
end

function Modifiers.leaks(text: string, names: { string }): boolean
	if type(text) ~= "string" then
		return false
	end
	local hay = string.lower(text)
	for _, name in ipairs(names) do
		if type(name) == "string" and name ~= "" then
			if string.find(hay, string.lower(name), 1, true) ~= nil then
				return true
			end
		end
	end
	return false
end

return Modifiers
