--!strict
-- Picks the next theme. Holiday rounds rotate room, gingerbread, then tree.
-- A season with no themes of a type (Winter has no gingerbread) skips that slot.
-- The last 10 theme ids are avoided while any other choice of the needed type exists.
--
-- hostThemeId is the private-server hook. It is not wired to a remote yet.
-- A valid in-season id is used for one round and does not consume the rotation.

local Config = if script ~= nil and script.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")
local Themes = if script ~= nil and script.Parent ~= nil then require(script.Parent.Parent.Themes) else require("../Themes")

export type Theme = {
	id: string,
	name: string,
	roundType: string,
	season: string,
}

export type Pick = {
	theme: Theme,
	recent: { string },
	typeIndex: number,
	usedHost: boolean,
}

export type PickArgs = {
	season: string,
	themes: { Theme }?,
	recent: { string }?,
	typeIndex: number?,
	rng: (() -> number)?,
	window: number?,
	hostThemeId: string?,
}

local ThemePicker = {}

local function remember(recent: { string }, id: string, window: number): { string }
	local nextList = {}
	for _, item in ipairs(recent) do
		if item ~= id then
			table.insert(nextList, item)
		end
	end
	table.insert(nextList, id)
	while #nextList > window do
		table.remove(nextList, 1)
	end
	return nextList
end

local function listed(recent: { string }, id: string): boolean
	for _, item in ipairs(recent) do
		if item == id then
			return true
		end
	end
	return false
end

local function choose(list: { Theme }, rng: () -> number): Theme
	local roll = rng()
	if roll < 0 then
		roll = 0
	end
	if roll >= 1 then
		roll = 1 - 1e-9
	end
	local index = math.floor(roll * #list) + 1
	local theme = list[index] or list[1]
	if not theme then
		error("ThemePicker chose from an empty list")
	end
	return theme
end

local function pool(season: string, roundType: string, source: { Theme }, recent: { string }, allowRecent: boolean): { Theme }
	local list = {}
	for _, theme in ipairs(source) do
		if theme.season == season and theme.roundType == roundType then
			if allowRecent or not listed(recent, theme.id) then
				table.insert(list, theme)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

function ThemePicker.pick(args: PickArgs): Pick?
	local season = args.season
	local source = args.themes or Themes.all()
	local recent = args.recent or {}
	local typeIndex = args.typeIndex or 1
	local window = args.window or Config.RecentThemes
	local rng = args.rng or math.random
	local order = Config.RoundTypeOrder

	if args.hostThemeId and args.hostThemeId ~= "" then
		for _, theme in ipairs(source) do
			if theme.id == args.hostThemeId and theme.season == season then
				return {
					theme = theme,
					recent = remember(recent, theme.id, window),
					typeIndex = typeIndex,
					usedHost = true,
				}
			end
		end
	end

	if #order == 0 then
		return nil
	end

	for step = 0, #order - 1 do
		local slot = ((typeIndex - 1 + step) % #order) + 1
		local kind = order[slot]
		local fresh = pool(season, kind, source, recent, false)
		local list = fresh
		if #list == 0 then
			list = pool(season, kind, source, recent, true)
		end
		if #list > 0 then
			local theme = choose(list, rng)
			return {
				theme = theme,
				recent = remember(recent, theme.id, window),
				typeIndex = (slot % #order) + 1,
				usedHost = false,
			}
		end
	end

	return nil
end

return ThemePicker
