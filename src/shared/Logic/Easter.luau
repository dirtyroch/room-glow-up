--!strict
-- Two free jokes. A pit-bull rug and a recliner for unc.
-- Level unlocks and place-quests both grant them. Crates do not own the path.

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

local Config = parent("Config")
local Save = sibling("Save")
local Owned = sibling("Owned")

local Easter = {}

local LINES: { [string]: string } = {
	pibble_rug = "That pit-bull rug has the good kind of zoomies. I am keeping my shoes on.",
	unc_chair = "The recliner, the remote, and the reading glasses. Unc has clocked in.",
}

function Easter.lines(): { [string]: string }
	return LINES
end

function Easter.line(itemIds: any): string
	if type(itemIds) ~= "table" then
		return ""
	end
	local parts: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, id in ipairs(itemIds) do
		local joke = LINES[id]
		if type(joke) == "string" and seen[id] ~= true then
			seen[id] = true
			table.insert(parts, joke)
		end
	end
	return table.concat(parts, " ")
end

function Easter.crateOnly(): boolean
	return false
end

local function give(profile: { [string]: any }, itemId: string)
	if Save.hasId(profile.owned, itemId) then
		return
	end
	Owned.give(profile, itemId, nil)
end

function Easter.grant(profile: { [string]: any }, level: number?)
	local lvl = level or 1
	if type(lvl) ~= "number" or lvl ~= lvl then
		lvl = 1
	end
	local rugs = profile.rugPlaces or 0
	local seats = profile.seatPlaces or 0
	if lvl >= Config.Easter.PibbleLevel or rugs >= Config.Easter.PibbleRugs then
		give(profile, "pibble_rug")
	end
	if lvl >= Config.Easter.UncLevel or seats >= Config.Easter.UncSeats then
		give(profile, "unc_chair")
	end
end

function Easter.note(profile: { [string]: any }, item: any, level: number?)
	if type(item) == "table" then
		if item.category == "Rugs" then
			local count = profile.rugPlaces or 0
			profile.rugPlaces = count + 1
		elseif item.category == "Seating" then
			local count = profile.seatPlaces or 0
			profile.seatPlaces = count + 1
		end
	end
	Easter.grant(profile, level)
end

return Easter
