--!strict
-- Server-authoritative round, as plain data so tests can step the clock.
--
-- Lobby holds until at least one player is here, then runs for Config.Phases.Lobby.
-- ThemeReveal shows the pick. Build lasts Config.Phases.Build and ends early
-- once every active player has pressed DONE. When Build ends, every active
-- player who is still here is toured (DONE locks in early; the clock submits
-- the rest). Leaving removes that room. Tour is Config.Phases.TourPerRoom
-- per room. Results, then Lobby.
--
-- A player who joins after Lobby is a spectator until the next Lobby.
-- If nobody active is left mid-round, the server returns to Lobby so a
-- spectator can play the next one instead of watching an empty tour.

local Config = if script ~= nil and script.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")
local Themes = if script ~= nil and script.Parent ~= nil then require(script.Parent.Parent.Themes) else require("../Themes")
local ThemePicker = if script ~= nil and script.Parent ~= nil then require(script.Parent.ThemePicker) else require("./ThemePicker")

local Round = {}

export type Member = {
	active: boolean,
	done: boolean,
}

export type State = {
	phase: string,
	phaseEndsAt: number,
	holding: boolean,
	themeId: string?,
	recent: { string },
	typeIndex: number,
	hostThemeId: string?,
	members: { [string]: Member },
	arrival: { string },
	tourOrder: { string },
	tourIndex: number,
	seasonOverride: string?,
	year: number,
	month: number,
	day: number,
	rng: () -> number,
	roundNumber: number,
}

export type Options = {
	rng: (() -> number)?,
	seasonOverride: string?,
	year: number?,
	month: number?,
	day: number?,
}

export type View = {
	phase: string,
	timeLeft: number,
	endsAt: number,
	holding: boolean,
	themeId: string,
	themeName: string,
	roundType: string,
	typeLabel: string,
	tourIndex: number,
	tourCount: number,
	seasonLabel: string,
	roundNumber: number,
}

local PHASE_LOBBY = "Lobby"
local PHASE_REVEAL = "ThemeReveal"
local PHASE_BUILD = "Build"
local PHASE_TOUR = "Tour"
local PHASE_RESULTS = "Results"

Round.Lobby = PHASE_LOBBY
Round.ThemeReveal = PHASE_REVEAL
Round.Build = PHASE_BUILD
Round.Tour = PHASE_TOUR
Round.Results = PHASE_RESULTS

local function countActive(state: State): number
	local n = 0
	for _, member in pairs(state.members) do
		if member.active then
			n += 1
		end
	end
	return n
end

local function countMembers(state: State): number
	local n = 0
	for _ in pairs(state.members) do
		n += 1
	end
	return n
end

local function removeId(list: { string }, id: string): number?
	for index, value in ipairs(list) do
		if value == id then
			table.remove(list, index)
			return index
		end
	end
	return nil
end

local function allActiveDone(state: State): boolean
	local anyActive = false
	for _, member in pairs(state.members) do
		if member.active then
			anyActive = true
			if not member.done then
				return false
			end
		end
	end
	return anyActive
end

local function seasonOf(state: State): string
	local setting = state.seasonOverride or Config.Season
	return Themes.activeSeason(setting, state.year, state.month, state.day)
end

local function beginResults(state: State, now: number)
	state.phase = PHASE_RESULTS
	state.holding = false
	state.tourOrder = {}
	state.tourIndex = 0
	state.phaseEndsAt = now + Config.Phases.Results
end

local function beginTour(state: State, now: number)
	local order = {}
	for _, id in ipairs(state.arrival) do
		local member = state.members[id]
		if member and member.active then
			table.insert(order, id)
		end
	end
	state.phase = PHASE_TOUR
	state.holding = false
	state.tourOrder = order
	state.tourIndex = if #order > 0 then 1 else 0
	if #order == 0 then
		beginResults(state, now)
		return
	end
	state.phaseEndsAt = now + Config.Phases.TourPerRoom
end

local function beginBuild(state: State, now: number)
	state.phase = PHASE_BUILD
	state.holding = false
	state.tourOrder = {}
	state.tourIndex = 0
	state.phaseEndsAt = now + Config.Phases.Build
	for _, member in pairs(state.members) do
		if member.active then
			member.done = false
		end
	end
end

local function beginReveal(state: State, now: number)
	local picked = ThemePicker.pick({
		season = seasonOf(state),
		recent = state.recent,
		typeIndex = state.typeIndex,
		rng = state.rng,
		window = Config.RecentThemes,
		hostThemeId = state.hostThemeId,
	})
	if not picked then
		state.holding = true
		state.phaseEndsAt = math.huge
		state.hostThemeId = nil
		return
	end
	state.themeId = picked.theme.id
	state.recent = picked.recent
	state.typeIndex = picked.typeIndex
	state.hostThemeId = nil
	state.phase = PHASE_REVEAL
	state.holding = false
	state.phaseEndsAt = now + Config.Phases.ThemeReveal
	state.roundNumber += 1
end

local function beginLobby(state: State, now: number, activate: boolean)
	state.phase = PHASE_LOBBY
	state.themeId = nil
	state.tourOrder = {}
	state.tourIndex = 0
	for _, member in pairs(state.members) do
		member.done = false
		if activate then
			member.active = true
		end
	end
	if countActive(state) >= Config.MinPlayers then
		state.holding = false
		state.phaseEndsAt = now + Config.Phases.Lobby
	else
		state.holding = true
		state.phaseEndsAt = math.huge
	end
end

local function advanceTour(state: State, now: number)
	if state.tourIndex < #state.tourOrder then
		state.tourIndex += 1
		state.phaseEndsAt = state.phaseEndsAt + Config.Phases.TourPerRoom
		if state.phaseEndsAt < now then
			state.phaseEndsAt = now
		end
		return
	end
	beginResults(state, now)
end

local function step(state: State, now: number)
	if state.phase == PHASE_LOBBY then
		beginReveal(state, now)
	elseif state.phase == PHASE_REVEAL then
		beginBuild(state, now)
	elseif state.phase == PHASE_BUILD then
		beginTour(state, now)
	elseif state.phase == PHASE_TOUR then
		advanceTour(state, now)
	elseif state.phase == PHASE_RESULTS then
		beginLobby(state, now, true)
	end
end

local function defaultRng(): number
	return math.random()
end

function Round.new(now: number, options: Options?): State
	local seasonOverride: string? = nil
	local year = 2026
	local month = 11
	local day = 19
	local rng = defaultRng
	if options then
		seasonOverride = options.seasonOverride
		if options.year then
			year = options.year
		end
		if options.month then
			month = options.month
		end
		if options.day then
			day = options.day
		end
		if options.rng then
			rng = options.rng
		end
	end
	local state: State = {
		phase = PHASE_LOBBY,
		phaseEndsAt = math.huge,
		holding = true,
		themeId = nil,
		recent = {},
		typeIndex = 1,
		hostThemeId = nil,
		members = {},
		arrival = {},
		tourOrder = {},
		tourIndex = 0,
		seasonOverride = seasonOverride,
		year = year,
		month = month,
		day = day,
		rng = rng,
		roundNumber = 0,
	}
	beginLobby(state, now, false)
	return state
end

function Round.setDate(state: State, year: number, month: number, day: number)
	state.year = year
	state.month = month
	state.day = day
end

-- Private-server host hook. Validates an id against the season the next
-- reveal will use. Not connected to the action remote.
function Round.setHostTheme(state: State, themeId: string?): (boolean, string?)
	if themeId == nil or themeId == "" then
		state.hostThemeId = nil
		return true, "Cleared."
	end
	if type(themeId) ~= "string" then
		return false, "Bad theme."
	end
	local theme = Themes.byId(themeId)
	if not theme or theme.season ~= seasonOf(state) then
		return false, "That theme is not in this season."
	end
	state.hostThemeId = themeId
	return true, "Theme set for the next round."
end

function Round.join(state: State, playerId: string, now: number): (boolean, string?)
	if type(playerId) ~= "string" or playerId == "" or #playerId > 40 then
		return false, "Bad request."
	end
	if state.members[playerId] then
		return true, "Already here."
	end
	if countMembers(state) >= Config.MaxPlayers then
		return false, "This server is full."
	end
	local active = state.phase == PHASE_LOBBY
	state.members[playerId] = { active = active, done = false }
	table.insert(state.arrival, playerId)
	if active and state.holding and countActive(state) >= Config.MinPlayers then
		state.holding = false
		state.phaseEndsAt = now + Config.Phases.Lobby
	end
	if active then
		return true, "You're in."
	end
	return true, "You'll play next round."
end

function Round.leave(state: State, playerId: string, now: number)
	if not state.members[playerId] then
		return
	end
	local wasShowing = state.tourIndex
	local tourPos = removeId(state.tourOrder, playerId)
	state.members[playerId] = nil
	removeId(state.arrival, playerId)
	if tourPos and tourPos < wasShowing then
		state.tourIndex -= 1
	end
	local wasCurrent = tourPos ~= nil and tourPos == wasShowing

	if countMembers(state) == 0 then
		beginLobby(state, now, false)
		return
	end

	if state.phase == PHASE_LOBBY then
		if countActive(state) < Config.MinPlayers then
			state.holding = true
			state.phaseEndsAt = math.huge
		end
		return
	end

	if countActive(state) == 0 then
		beginLobby(state, now, true)
		return
	end

	if state.phase == PHASE_BUILD and allActiveDone(state) then
		beginTour(state, now)
		return
	end

	if state.phase ~= PHASE_TOUR then
		return
	end

	-- The room on screen left: later rooms slide into this index. If that
	-- was the last room, the tour is over instead of replaying an earlier one.
	if #state.tourOrder == 0 or (wasCurrent and state.tourIndex > #state.tourOrder) then
		beginResults(state, now)
		return
	end
	if wasCurrent then
		state.phaseEndsAt = now + Config.Phases.TourPerRoom
	end
end

function Round.done(state: State, playerId: string, now: number): (boolean, string?)
	if state.phase ~= PHASE_BUILD then
		return false, "Not during build."
	end
	local member = state.members[playerId]
	if not member then
		return false, "Still joining."
	end
	if not member.active then
		return false, "You're watching this round."
	end
	if member.done then
		return false, "Already finished."
	end
	member.done = true
	if allActiveDone(state) then
		beginTour(state, now)
	end
	return true, "Room locked in."
end

function Round.timeLeft(state: State, now: number): number
	if state.holding or state.phaseEndsAt == math.huge then
		return -1
	end
	local left = state.phaseEndsAt - now
	if left <= 0 then
		return 0
	end
	return math.ceil(left - 1e-6)
end

function Round.tick(state: State, now: number): { string }
	local entered = {}
	local guard = 0
	while not state.holding and now >= state.phaseEndsAt and guard < 5000 do
		local prevPhase = state.phase
		local prevEnd = state.phaseEndsAt
		local prevTour = state.tourIndex
		step(state, now)
		guard += 1
		table.insert(entered, state.phase)
		if state.holding then
			break
		end
		if state.phase == prevPhase and state.phaseEndsAt == prevEnd and state.tourIndex == prevTour then
			break
		end
	end
	return entered
end

function Round.role(state: State, playerId: string): string
	local member = state.members[playerId]
	if not member then
		return "joining"
	end
	if not member.active then
		return "spectating"
	end
	if member.done and state.phase == PHASE_BUILD then
		return "done"
	end
	return "playing"
end

function Round.view(state: State, now: number): View
	local theme = if state.themeId then Themes.byId(state.themeId) else nil
	local season = seasonOf(state)
	local touring = state.phase == PHASE_TOUR and #state.tourOrder > 0
	return {
		phase = state.phase,
		timeLeft = Round.timeLeft(state, now),
		endsAt = if state.holding then 0 else state.phaseEndsAt,
		holding = state.holding,
		themeId = if theme then theme.id else "",
		themeName = if theme then theme.name else "",
		roundType = if theme then theme.roundType else "",
		typeLabel = if theme then Themes.typeLabel(theme.roundType) else "",
		tourIndex = if touring then state.tourIndex else 0,
		tourCount = if touring then #state.tourOrder else 0,
		seasonLabel = Themes.seasonLabel(season),
		roundNumber = state.roundNumber,
	}
end

function Round.activeIds(state: State): { string }
	local ids = {}
	for _, id in ipairs(state.arrival) do
		local member = state.members[id]
		if member and member.active then
			table.insert(ids, id)
		end
	end
	return ids
end

return Round
