--!strict
-- Three daily quests, chosen from the date in Central time.
-- The same date always picks the same three. A few rounds can finish them.

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

local Quests = {}

local POOL = {
	{ id = "rooms", label = "Finish 3 rooms", goal = 3, stat = "rooms" },
	{ id = "stars", label = "Score 3 stars in 3 rounds", goal = 3, stat = "starRounds" },
	{ id = "props", label = "Place 16 props", goal = 16, stat = "props" },
	{ id = "meter", label = "Hit theme match twice", goal = 2, stat = "meterRounds" },
	{ id = "colors", label = "Recolor 6 pieces", goal = 6, stat = "recolors" },
	{ id = "full", label = "Fill 8 spots in 2 rounds", goal = 2, stat = "fullRounds" },
}

local function hash(text: string): number
	local n = 0
	for index = 1, #text do
		n = (n * 33 + string.byte(text, index)) % 1000003
	end
	return n
end

function Quests.dayKey(unix: number, offsetHours: number): string
	local parts = Season.parts(unix, offsetHours)
	return string.format("%04d-%02d-%02d", parts.year, parts.month, parts.day)
end

function Quests.template(id: string): any
	for _, row in ipairs(POOL) do
		if row.id == id then
			return row
		end
	end
	return nil
end

function Quests.pick(dayKey: string): { any }
	local order: { number } = {}
	for index = 1, #POOL do
		order[index] = index
	end
	table.sort(order, function(a: number, b: number): boolean
		local left = POOL[a]
		local right = POOL[b]
		local ha = hash(dayKey .. ":" .. left.id)
		local hb = hash(dayKey .. ":" .. right.id)
		if ha == hb then
			return left.id < right.id
		end
		return ha < hb
	end)
	local picked: { any } = {}
	for index = 1, 3 do
		local src = POOL[order[index]]
		table.insert(picked, {
			id = src.id,
			label = src.label,
			goal = src.goal,
			stat = src.stat,
			progress = 0,
		})
	end
	return picked
end

function Quests.ensure(profile: { [string]: any }, dayKey: string)
	if profile.questDay == dayKey and type(profile.quests) == "table" and #profile.quests == 3 then
		local rebound: { any } = {}
		for _, quest in ipairs(profile.quests) do
			local src = if type(quest) == "table" then Quests.template(quest.id) else nil
			if not src then
				profile.questDay = ""
				break
			end
			table.insert(rebound, {
				id = src.id,
				label = src.label,
				goal = src.goal,
				stat = src.stat,
				progress = math.max(0, math.floor(quest.progress or 0)),
			})
		end
		if #rebound == 3 and profile.questDay == dayKey then
			profile.quests = rebound
			return
		end
	end
	profile.questDay = dayKey
	profile.quests = Quests.pick(dayKey)
end

-- Returns how many quests are complete, and coins for ones that just finished.
function Quests.apply(profile: { [string]: any }, stats: { [string]: number }, coinEach: number): (number, number)
	local done = 0
	local coins = 0
	local quests = profile.quests
	if type(quests) ~= "table" then
		return 0, 0
	end
	for _, quest in ipairs(quests) do
		local before = quest.progress
		local gain = stats[quest.stat] or 0
		if type(gain) ~= "number" or gain < 0 then
			gain = 0
		end
		if gain > 0 and before < quest.goal then
			quest.progress = math.min(quest.goal, before + math.floor(gain))
		end
		if quest.progress >= quest.goal then
			done += 1
			if before < quest.goal then
				coins += coinEach
			end
		end
	end
	return done, coins
end

return Quests
