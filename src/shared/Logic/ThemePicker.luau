--!strict
-- Picks the theme for a round.
-- Holiday Season rotates room, gingerbread, then tree.
-- The last 10 theme ids are skipped when another choice exists.
-- A private-server host can pass a theme id; the remote for that is wired later.

local ThemePicker = {}

export type Theme = {
	id: string,
	name: string,
	roundType: string,
	season: string,
}

export type Options = {
	season: string,
	history: { string },
	roundIndex: number,
	roundTypeOrder: { string },
	recentLimit: number,
	hostThemeId: string?,
	rng: () -> number,
}

function ThemePicker.find(themes: { Theme }, id: string): Theme?
	for _, theme in ipairs(themes) do
		if theme.id == id then
			return theme
		end
	end
	return nil
end

local function pool(themes: { Theme }, season: string, roundType: string?): { Theme }
	local list: { Theme } = {}
	for _, theme in ipairs(themes) do
		if theme.season == season and (roundType == nil or theme.roundType == roundType) then
			table.insert(list, theme)
		end
	end
	return list
end

local function blocked(history: { string }, limit: number): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local startAt = math.max(1, #history - limit + 1)
	for i = startAt, #history do
		set[history[i]] = true
	end
	return set
end

local function choose(list: { Theme }, skip: { [string]: boolean }, rng: () -> number): Theme?
	if #list == 0 then
		return nil
	end
	local open: { Theme } = {}
	for _, theme in ipairs(list) do
		if not skip[theme.id] then
			table.insert(open, theme)
		end
	end
	local use = if #open > 0 then open else list
	local sample = rng()
	if type(sample) ~= "number" then
		sample = 0
	end
	local idx = math.floor(sample * #use) + 1
	if idx > #use then
		idx = #use
	end
	if idx < 1 then
		idx = 1
	end
	return use[idx]
end

function ThemePicker.pick(themes: { Theme }, options: Options): Theme?
	local hostId = options.hostThemeId
	if type(hostId) == "string" and hostId ~= "" then
		local host = ThemePicker.find(themes, hostId)
		if host and host.season == options.season then
			return host
		end
	end

	local desired: string? = nil
	if options.season == "holiday" then
		local order = options.roundTypeOrder
		if #order > 0 then
			desired = order[(options.roundIndex % #order) + 1]
		end
	end

	local list = pool(themes, options.season, desired)
	if #list == 0 then
		list = pool(themes, options.season, nil)
	end
	return choose(list, blocked(options.history, options.recentLimit), options.rng)
end

return ThemePicker
