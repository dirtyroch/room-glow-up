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

-- XP to leave a level. Level 1 is one round. After that a gentle line, then
-- a curve from XpCurveFrom so level 50 is a long goal (about 11 to 12 hours
-- of 10-player rounds) while the early unlocks stay quick.
function Levels.step(level: number): number
	local p = Config.Progress
	if level < 1 then
		level = 1
	end
	if level == 1 then
		return p.XpFirst
	end
	local past = math.max(0, level - p.XpCurveFrom)
	return math.floor(p.XpBase + p.XpStep * (level - 2) + p.XpCurve * past * past + 1e-6)
end

local totals: { number } = {}
local function fill()
	totals[1] = 0
	for level = 2, Config.Progress.MaxLevel do
		totals[level] = totals[level - 1] + Levels.step(level - 1)
	end
end
fill()

-- XP required to arrive at this level. Level 1 is 0.
function Levels.total(level: number): number
	if level <= 1 then
		return 0
	end
	local cap = Config.Progress.MaxLevel
	if level > cap then
		return totals[cap] + (level - cap) * Levels.step(cap)
	end
	return totals[math.floor(level)]
end

-- The first curve (schema 1 saves): XP to leave level L was 20 + (L - 1) * 6.
-- Frozen here so old saves can be read, whatever the live curve becomes.
function Levels.legacyTotal(level: number): number
	local n = level - 1
	if n <= 0 then
		return 0
	end
	return n * 20 + math.floor(6 * (n - 1) * n / 2)
end

local function legacyLevel(xp: number): number
	local level = 1
	while level < Config.Progress.MaxLevel and xp >= Levels.legacyTotal(level + 1) do
		level += 1
	end
	return level
end

-- Moves XP earned on the old curve onto the live one. The level stays the
-- same and so does the share of the way to the next level. Never lowers XP.
function Levels.migrateXp(xp: number): number
	if type(xp) ~= "number" or xp ~= xp or xp <= 0 then
		return 0
	end
	local cap = Config.Progress.MaxLevel
	local level = legacyLevel(xp)
	local moved: number
	if level >= cap then
		moved = Levels.total(cap) + (xp - Levels.legacyTotal(cap))
	else
		local lo = Levels.legacyTotal(level)
		local hi = Levels.legacyTotal(level + 1)
		local share = (xp - lo) / math.max(1, hi - lo)
		local newLo = Levels.total(level)
		local newHi = Levels.total(level + 1)
		moved = newLo + math.floor(share * (newHi - newLo))
		if moved >= newHi then
			moved = newHi - 1
		end
	end
	return math.max(math.floor(xp), math.floor(moved))
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
