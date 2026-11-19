--!strict
-- Level 1 to 50 on a gentle curve, and the furniture each level unlocks.
-- The order is fixed so the tray can show the next set before the player reaches it.

local function sibling(name: string): any
	local ok, loaded = pcall(function()
		local child = script.Parent.Parent:WaitForChild(name)
		return (require :: any)(child)
	end)
	if ok then
		return loaded
	end
	return (require :: any)("../" .. name)
end

local Config = sibling("Config")
local Items = sibling("Items")

local Levels = {}

-- A fresh player can furnish a room, a gingerbread house, or a tree.
local STARTER = {
	"butter_bench",
	"mint_pouf",
	"coral_armchair",
	"cocoa_stool",
	"cocoa_table",
	"round_side",
	"hearth_lamp",
	"window_candle",
	"book_ledge",
	"hearth_rug",
	"dot_rug",
	"stripe_rug",
	"checker_rug",
	"mini_pine",
	"fern_pot",
	"cocoa_wreath",
	"cocoa_mug",
	"gift_stack",
	"icing_drip",
	"icing_shingle",
	"frosting_swirl",
	"sugar_border",
	"gumdrop",
	"candy_cane",
	"peppermint_disc",
	"sprinkle_dash",
	"licorice_stick",
	"mint_disc",
	"jelly_square",
	"butter_bauble",
	"coral_bauble",
	"mint_bauble",
	"cream_bauble",
	"paper_star",
	"tinsel_bow",
	"popcorn_string",
	"cranberry_string",
	"bell_drop",
	"pinecone_charm",
	"snowflake_cut",
}

export type UnlockSet = {
	level: number,
	name: string,
	items: { string },
}

local schedule: { UnlockSet } = {}
local unlockOf: { [string]: number } = {}

local function setName(ids: { string }): string
	local cats: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, id in ipairs(ids) do
		local item = Items.get(id)
		if item and seen[item.category] ~= true then
			seen[item.category] = true
			table.insert(cats, item.category)
		end
	end
	if #cats == 0 then
		return "Furniture"
	end
	if #cats == 1 then
		return cats[1]
	end
	return cats[1] .. " and " .. cats[2]
end

local function build()
	local seen: { [string]: boolean } = {}
	local starter: { string } = {}
	for _, id in ipairs(STARTER) do
		if Items.get(id) and seen[id] ~= true then
			seen[id] = true
			unlockOf[id] = 1
			table.insert(starter, id)
		end
	end
	schedule[1] = { level = 1, name = "First room", items = starter }
	local rest: { any } = {}
	for _, item in ipairs(Items.list) do
		if seen[item.id] ~= true then
			table.insert(rest, item)
		end
	end
	local cap = Config.Progress.MaxLevel
	local slots = cap - 1
	local base = math.floor(#rest / slots)
	local extra = #rest % slots
	local index = 1
	for level = 2, cap do
		local take = base
		if (level - 1) <= extra then
			take += 1
		end
		local ids: { string } = {}
		for _ = 1, take do
			local item = rest[index]
			index += 1
			if item then
				unlockOf[item.id] = level
				table.insert(ids, item.id)
			end
		end
		schedule[level] = { level = level, name = setName(ids), items = ids }
	end
end

build()

function Levels.step(level: number): number
	if level < 1 then
		level = 1
	end
	return Config.Progress.XpBase + (level - 1) * Config.Progress.XpStep
end

-- XP required to arrive at this level. Level 1 is 0.
function Levels.total(level: number): number
	local n = level - 1
	if n <= 0 then
		return 0
	end
	local base = Config.Progress.XpBase
	local step = Config.Progress.XpStep
	return n * base + math.floor(step * (n - 1) * n / 2)
end

function Levels.fromXp(xp: number): number
	if type(xp) ~= "number" or xp ~= xp or xp < 0 then
		xp = 0
	end
	local cap = Config.Progress.MaxLevel
	local level = 1
	while level < cap and xp >= Levels.total(level + 1) do
		level += 1
	end
	return level
end

function Levels.unlockLevel(itemId: string): number
	local need = unlockOf[itemId]
	if type(need) ~= "number" then
		return Config.Progress.MaxLevel
	end
	return need
end

function Levels.owns(itemId: string, level: number): boolean
	if type(level) ~= "number" then
		return false
	end
	return level >= Levels.unlockLevel(itemId) and unlockOf[itemId] ~= nil
end

function Levels.gate(itemId: string, level: number): { owned: boolean, level: number }
	local need = Levels.unlockLevel(itemId)
	return {
		owned = Levels.owns(itemId, level),
		level = need,
	}
end

function Levels.setAt(level: number): UnlockSet?
	return schedule[level]
end

function Levels.ownedCount(level: number): number
	local n = 0
	for _, item in ipairs(Items.list) do
		if Levels.owns(item.id, level) then
			n += 1
		end
	end
	return n
end

-- Always names the next set, until the last level.
function Levels.next(level: number): string
	local row = schedule[level + 1]
	if not row then
		return "All the furniture is yours."
	end
	return "Level " .. tostring(row.level) .. " · " .. row.name
end

function Levels.setsBetween(fromLevel: number, toLevel: number): { UnlockSet }
	local rows: { UnlockSet } = {}
	local lo = fromLevel + 1
	if lo < 2 then
		lo = 2
	end
	for level = lo, toLevel do
		local row = schedule[level]
		if row and #row.items > 0 then
			table.insert(rows, row)
		end
	end
	return rows
end

return Levels
