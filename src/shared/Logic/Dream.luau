--!strict
-- A personal home that is not the contest plot.
-- Studio, then loft, then a two-storey house. No budget. Owned items only.
-- Lookbook keeps up to three contest rooms.

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
local Levels = sibling("Levels")
local Placement = sibling("Placement")

local Dream = {}

function Dream.tier(level: number): string
	if level >= Config.Progress.HouseLevel then
		return "house"
	end
	if level >= Config.Progress.LoftLevel then
		return "loft"
	end
	return "studio"
end

function Dream.cap(level: number): number
	local tier = Dream.tier(level)
	if tier == "house" then
		return Config.Progress.HouseItems
	end
	if tier == "loft" then
		return Config.Progress.LoftItems
	end
	return Config.Progress.StudioItems
end

function Dream.slots(extra: number): number
	local more = extra
	if type(more) ~= "number" or more ~= more then
		more = 0
	end
	return 1 + math.max(0, math.floor(more))
end

function Dream.ensureSlots(doc: { [string]: any }, extra: number): number
	local want = Dream.slots(extra)
	if type(doc.homes) ~= "table" then
		doc.homes = {}
	end
	while #doc.homes < want do
		table.insert(doc.homes, { pieces = {} })
	end
	return want
end

function Dream.roomFrom(pieces: { any }): any
	local room = Placement.empty()
	local nextId = 1
	for _, piece in ipairs(pieces) do
		local copy = {
			id = piece.id,
			itemId = piece.itemId,
			surface = piece.surface,
			x = piece.x,
			z = piece.z,
			rot = piece.rot,
			color = piece.color,
			cost = piece.cost,
			placedAt = piece.placedAt,
		}
		table.insert(room.pieces, copy)
		if type(piece.id) == "number" and piece.id >= nextId then
			nextId = piece.id + 1
		end
	end
	room.nextId = nextId
	room.spent = 0
	return room
end

function Dream.context(level: number, catalog: any, now: number): any
	local tier = Dream.tier(level)
	return {
		catalog = catalog,
		roundType = "room",
		themeId = "",
		budget = 0,
		maxItems = Dream.cap(level),
		role = "active",
		phase = "Dream",
		locked = false,
		matchExact = 0,
		matchFamily = 0,
		matchCap = 100,
		palette = Config.Palette,
		now = now,
		undoCap = Config.UndoCap,
		gridType = tier,
		freeSpend = true,
		allow = function(itemId: string): boolean
			return Levels.owns(itemId, level)
		end,
	}
end

function Dream.piecesOf(room: any): { any }
	local list: { any } = {}
	for _, piece in ipairs(room.pieces) do
		table.insert(list, {
			id = piece.id,
			itemId = piece.itemId,
			surface = piece.surface,
			x = piece.x,
			z = piece.z,
			rot = piece.rot,
			color = piece.color,
			cost = piece.cost,
			placedAt = piece.placedAt,
		})
	end
	return list
end

function Dream.remember(book: { any }, snap: any, cap: number): (boolean, string?)
	if type(snap) ~= "table" or type(snap.roundId) ~= "string" then
		return false, "No score yet."
	end
	if type(snap.average) ~= "number" then
		return false, "No score yet."
	end
	for index, old in ipairs(book) do
		if old.roundId == snap.roundId then
			book[index] = snap
			return true, "Saved."
		end
	end
	if #book < cap then
		table.insert(book, snap)
		return true, "Saved."
	end
	local worst = 1
	for index, old in ipairs(book) do
		if old.average < book[worst].average then
			worst = index
		end
	end
	if snap.average <= book[worst].average then
		return false, "Lookbook is full of stronger rooms."
	end
	book[worst] = snap
	return true, "Saved."
end

return Dream
