--!strict
-- Spot the Theme. A skippable guess during Results, after the podium is up.
-- It pays a few coins. It does not sell time.

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

local Spot = {}

function Spot.sellsTime(): boolean
	return Config.Spot.SellsTime == true
end

function Spot.deal(themeId: string, themes: { any }, salt: number?): { any }
	local correct: { id: string, name: string }? = nil
	local others: { { id: string, name: string } } = {}
	if type(themeId) ~= "string" or themeId == "" or type(themes) ~= "table" then
		return {}
	end
	for _, theme in ipairs(themes) do
		if type(theme) == "table" and type(theme.id) == "string" and type(theme.name) == "string" then
			local row = { id = theme.id, name = theme.name }
			if theme.id == themeId then
				correct = row
			else
				table.insert(others, row)
			end
		end
	end
	if correct == nil then
		return {}
	end
	table.sort(others, function(a, b)
		return a.id < b.id
	end)
	local picked: { { id: string, name: string } } = { correct }
	if #others > 0 then
		local start = 0
		if type(salt) == "number" and salt == salt then
			start = math.floor(math.abs(salt)) % #others
		end
		local need = Config.Spot.Choices - 1
		for offset = 0, need - 1 do
			local row = others[(start + offset) % #others + 1]
			local duplicate = false
			for _, have in ipairs(picked) do
				if have.id == row.id then
					duplicate = true
				end
			end
			if not duplicate then
				table.insert(picked, row)
			end
			if #picked >= Config.Spot.Choices then
				break
			end
		end
	end
	table.sort(picked, function(a, b)
		return a.id < b.id
	end)
	return picked
end

function Spot.encode(options: { any }): string
	local parts: { string } = {}
	for _, row in ipairs(options) do
		if type(row) == "table" and type(row.id) == "string" and type(row.name) == "string" then
			local name = string.gsub(row.name, "[|\n;]", " ")
			table.insert(parts, row.id .. "|" .. name)
		end
	end
	return table.concat(parts, ";")
end

function Spot.decode(text: string): { any }
	local rows: { any } = {}
	if type(text) ~= "string" or text == "" then
		return rows
	end
	for chunk in string.gmatch(text, "[^;]+") do
		local id, name = string.match(chunk, "^([^|]+)|(.*)$")
		if id and name then
			table.insert(rows, { id = id, name = name })
		end
	end
	return rows
end

function Spot.grade(answer: any, themeId: string): boolean
	return type(answer) == "string" and answer ~= "" and answer == themeId
end

-- The podium payload has to be on screen before the minigame can open.
function Spot.visible(phase: string, podium: any): boolean
	return phase == "Results" and type(podium) == "string" and podium ~= ""
end

-- Spot sits with the rewards card, at `at` seconds into Results (10 by default).
function Spot.open(elapsed: number, at: number?): boolean
	if type(elapsed) ~= "number" or elapsed ~= elapsed then
		return false
	end
	local mark = if type(at) == "number" and at >= 0 then at else 10
	return elapsed >= mark
end

function Spot.pay(profile: { [string]: any }, roundKey: string, correct: boolean): number
	if type(roundKey) ~= "string" or roundKey == "" then
		return 0
	end
	if type(profile.spotPaid) ~= "table" then
		profile.spotPaid = {}
	end
	if Save.hasId(profile.spotPaid, roundKey) then
		return 0
	end
	table.insert(profile.spotPaid, roundKey)
	while #profile.spotPaid > 24 do
		table.remove(profile.spotPaid, 1)
	end
	if correct ~= true then
		return 0
	end
	local coins = Config.Spot.Coins
	if type(coins) ~= "number" or coins < 0 then
		coins = 0
	end
	coins = math.floor(coins)
	profile.coins += coins
	return coins
end

return Spot
