--!strict
-- Shop pieces sit beside the level unlock order. Owning one does not unlock the next set.

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

local Save = sibling("Save")
local Levels = sibling("Levels")
local Config = parent("Config")

local Owned = {}

function Owned.has(profile: { [string]: any }, itemId: string, level: number?): boolean
	if Save.hasId(profile.owned, itemId) then
		return true
	end
	if type(level) == "number" and Levels.owns(itemId, level) then
		return true
	end
	return false
end

-- A duplicate becomes coins. The item list does not grow a second copy.
function Owned.give(profile: { [string]: any }, itemId: string, level: number?): boolean
	if type(profile.owned) ~= "table" then
		profile.owned = {}
	end
	if Owned.has(profile, itemId, level) then
		local coins = Config.Shop.DuplicateCoins
		if type(coins) == "number" and coins > 0 then
			profile.coins += math.floor(coins)
		end
		return true
	end
	table.insert(profile.owned, itemId)
	return false
end

return Owned
