--!strict
-- Decor Crate odds. The display and the roll read the same rows.
-- Decor Rain swaps the row list. A restricted player never reaches the roll.

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

local Crates = {}

export type Row = { itemId: string, percent: number }

function Crates.rows(raining: boolean): { Row }
	local source = if raining then Config.Shop.Crates.rain else Config.Shop.Crates.base
	local copy: { Row } = {}
	for _, row in ipairs(source) do
		table.insert(copy, { itemId = row.itemId, percent = row.percent })
	end
	return copy
end

function Crates.total(rows: { Row }): number
	local sum = 0
	for _, row in ipairs(rows) do
		sum += row.percent
	end
	return sum
end

function Crates.display(rows: { Row }, nameOf: (string) -> string): string
	local lines: { string } = {}
	for _, row in ipairs(rows) do
		table.insert(lines, string.format("%s %d%%", nameOf(row.itemId), row.percent))
	end
	return table.concat(lines, "\n")
end

function Crates.roll(rows: { Row }, rng: () -> number): string
	local sample = rng()
	if type(sample) ~= "number" or sample ~= sample then
		sample = 0
	end
	if sample < 0 then
		sample = 0
	end
	if sample > 0.999 then
		sample = 0.999
	end
	local pick = math.floor(sample * 100)
	local acc = 0
	for _, row in ipairs(rows) do
		acc += row.percent
		if pick < acc then
			return row.itemId
		end
	end
	return rows[#rows].itemId
end

function Crates.fallback(): { string }
	local copy: { string } = {}
	for _, id in ipairs(Config.Shop.Crates.fallback) do
		table.insert(copy, id)
	end
	return copy
end

return Crates
