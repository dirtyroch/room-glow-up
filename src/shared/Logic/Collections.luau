--!strict
-- A stamp for each theme scored at 4 stars or better, and a bonus for the set.

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

local Save = sibling("Save")

local Collections = {}

local NAMES = {
	holiday_room = "Holiday rooms",
	holiday_gingerbread = "Holiday houses",
	holiday_tree = "Holiday trees",
	winter_room = "Winter rooms",
	winter_gingerbread = "Winter houses",
	winter_tree = "Winter trees",
}

function Collections.groups(themes: { any }): { any }
	local order: { any } = {}
	local map: { [string]: any } = {}
	for _, theme in ipairs(themes) do
		local id = tostring(theme.season) .. "_" .. tostring(theme.roundType)
		local group = map[id]
		if not group then
			group = {
				id = id,
				name = NAMES[id] or id,
				themes = {},
			}
			map[id] = group
			table.insert(order, group)
		end
		table.insert(group.themes, theme.id)
	end
	return order
end

local function groupOf(themes: { any }, themeId: string): any
	for _, group in ipairs(Collections.groups(themes)) do
		for _, id in ipairs(group.themes) do
			if id == themeId then
				return group
			end
		end
	end
	return nil
end

function Collections.consider(profile: { [string]: any }, themeId: string, average: number, themes: { any }, config: any): { [string]: any }
	local empty = {
		stamped = false,
		already = false,
		setComplete = false,
		coins = 0,
		xp = 0,
		name = "",
		setName = "",
	}
	if type(themeId) ~= "string" or themeId == "" then
		return empty
	end
	if type(average) ~= "number" or average < config.Progress.StampStars then
		return empty
	end
	local group = groupOf(themes, themeId)
	if not group then
		return empty
	end
	if type(profile.stamps) ~= "table" then
		profile.stamps = {}
	end
	if Save.hasId(profile.stamps, themeId) then
		empty.already = true
		empty.name = themeId
		return empty
	end
	table.insert(profile.stamps, themeId)
	local complete = true
	for _, id in ipairs(group.themes) do
		if not Save.hasId(profile.stamps, id) then
			complete = false
		end
	end
	local coins = 0
	local xp = 0
	if complete and not Save.hasId(profile.bonuses, group.id) then
		if type(profile.bonuses) ~= "table" then
			profile.bonuses = {}
		end
		table.insert(profile.bonuses, group.id)
		coins = config.Progress.SetBonusCoins
		xp = config.Progress.SetBonusXp
		profile.coins += coins
		profile.xp += xp
	end
	return {
		stamped = true,
		already = false,
		setComplete = coins > 0,
		coins = coins,
		xp = xp,
		name = themeId,
		setName = group.name,
	}
end

return Collections
