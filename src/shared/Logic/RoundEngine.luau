--!strict
-- Server-authoritative round loop, with no place services so tests can step the clock.
-- Lobby waits for one player, then ThemeReveal, Build, Tour, Results, and back.
-- Someone who joins after the lobby spectates until the next lobby.
-- Someone who leaves has their room dropped from the tour.

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
local ThemePicker = sibling("ThemePicker")

local RoundEngine = {}

export type Role = "active" | "spectator"

export type PlayerState = {
	role: Role,
	done: boolean,
	submitted: boolean,
	doneOrder: number,
}

export type Trace = { phase: string, at: number }

export type State = {
	config: any,
	themes: { any },
	rng: () -> number,
	unixNow: () -> number,
	phase: string,
	phaseStartedAt: number,
	phaseEndsAt: number?,
	players: { [string]: PlayerState },
	tourStops: { string },
	tourIndex: number,
	tourSegmentStartedAt: number,
	history: { string },
	roundIndex: number,
	hostThemeId: string?,
	nextDoneOrder: number,
	theme: any,
	season: string,
	trace: { Trace },
	-- Returns true when that player has placed at least one prop.
	-- Wired by the room service. Nil keeps the older DONE-only tour.
	hasWork: ((string) -> any)?,
	-- Partner ids in a duo room. They build, but the tour stops once.
	tourSkip: { [string]: boolean },
}

local function activeCount(state: State): number
	local n = 0
	for _, player in pairs(state.players) do
		if player.role == "active" then
			n += 1
		end
	end
	return n
end

local function allActiveDone(state: State): boolean
	local anyActive = false
	for _, player in pairs(state.players) do
		if player.role == "active" then
			anyActive = true
			if not player.done then
				return false
			end
		end
	end
	return anyActive
end

local function note(state: State, phase: string, now: number)
	table.insert(state.trace, { phase = phase, at = now })
end

local function remember(state: State)
	local theme = state.theme
	if type(theme) ~= "table" or type(theme.id) ~= "string" then
		return
	end
	table.insert(state.history, theme.id)
	local limit = state.config.RecentThemes
	while #state.history > limit do
		table.remove(state.history, 1)
	end
end

local function collectStops(state: State): { string }
	local rows: { { id: string, order: number } } = {}
	for id, player in pairs(state.players) do
		if player.role == "active" and player.submitted and state.tourSkip[id] ~= true then
			table.insert(rows, { id = id, order = player.doneOrder })
		end
	end
	table.sort(rows, function(a, b)
		if a.order == b.order then
			return a.id < b.id
		end
		return a.order < b.order
	end)
	local ids: { string } = {}
	for _, row in ipairs(rows) do
		table.insert(ids, row.id)
	end
	return ids
end

local function retimeTour(state: State, now: number, restarted: boolean)
	if restarted then
		state.tourSegmentStartedAt = now
	end
	local per = state.config.Phases.TourPerRoom
	local remaining = #state.tourStops - state.tourIndex + 1
	if remaining < 1 then
		-- Use the scheduled end (last room end, or "now" when the last stop
		-- was just dropped and tourSegmentStartedAt was reset).
		state.phaseEndsAt = state.tourSegmentStartedAt
	else
		state.phaseEndsAt = state.tourSegmentStartedAt + per * remaining
	end
end

local function dropStop(state: State, id: string, now: number)
	local idx = table.find(state.tourStops, id)
	if not idx then
		return
	end
	table.remove(state.tourStops, idx)
	if state.phase ~= "Tour" then
		return
	end
	local restarted = false
	if idx < state.tourIndex then
		state.tourIndex -= 1
	elseif idx == state.tourIndex then
		restarted = true
	end
	retimeTour(state, now, restarted)
end

local function beginTheme(state: State, now: number)
	state.season = Season.resolve(state.config.Season, state.unixNow(), state.config.TimezoneOffsetHours)
	state.theme = ThemePicker.pick(state.themes, {
		season = state.season,
		history = state.history,
		roundIndex = state.roundIndex,
		roundTypeOrder = state.config.RoundTypeOrder,
		recentLimit = state.config.RecentThemes,
		hostThemeId = state.hostThemeId,
		rng = state.rng,
	})
	state.hostThemeId = nil
	state.phase = "ThemeReveal"
	state.phaseStartedAt = now
	state.phaseEndsAt = now + state.config.Phases.ThemeReveal
	note(state, "ThemeReveal", now)
end

local function beginBuild(state: State, now: number)
	state.phase = "Build"
	state.phaseStartedAt = now
	if activeCount(state) < 1 then
		-- Nobody left to decorate; skip the 240s wait and go to Tour.
		state.phaseEndsAt = now
	else
		state.phaseEndsAt = now + state.config.Phases.Build
	end
	note(state, "Build", now)
end

-- When Build ends, submit every active room that has props, not only DONE.
local function autoSubmit(state: State)
	local fn = state.hasWork
	if type(fn) ~= "function" then
		return
	end
	local pending: { string } = {}
	for id, player in pairs(state.players) do
		if player.role == "active" and not player.submitted then
			local ok, value = pcall(fn, id)
			if ok and value == true then
				table.insert(pending, id)
			end
		end
	end
	table.sort(pending)
	for _, id in ipairs(pending) do
		local player = state.players[id]
		player.submitted = true
		player.done = true
		player.doneOrder = state.nextDoneOrder
		state.nextDoneOrder += 1
	end
end

local function beginTour(state: State, now: number)
	autoSubmit(state)
	state.tourStops = collectStops(state)
	state.tourIndex = 1
	state.tourSegmentStartedAt = now
	state.phase = "Tour"
	state.phaseStartedAt = now
	retimeTour(state, now, false)
	note(state, "Tour", now)
end

local function beginResults(state: State, now: number)
	remember(state)
	state.phase = "Results"
	state.phaseStartedAt = now
	state.phaseEndsAt = now + state.config.Phases.Results
	note(state, "Results", now)
end

local function beginLobby(state: State, now: number)
	state.roundIndex += 1
	state.theme = nil
	state.tourStops = {}
	state.tourIndex = 1
	state.nextDoneOrder = 1
	for _, player in pairs(state.players) do
		player.role = "active"
		player.done = false
		player.submitted = false
		player.doneOrder = 0
	end
	state.phase = "Lobby"
	state.phaseStartedAt = now
	state.tourSkip = {}
	if activeCount(state) >= 1 then
		state.phaseEndsAt = now + state.config.Phases.Lobby
	else
		state.phaseEndsAt = nil
	end
	note(state, "Lobby", now)
end

local function expired(state: State, now: number): boolean
	local ends = state.phaseEndsAt
	if ends == nil or now < ends then
		return false
	end
	if state.phase == "Lobby" and activeCount(state) < 1 then
		return false
	end
	return true
end

local function enterNext(state: State, now: number)
	local phase = state.phase
	if phase == "Lobby" then
		beginTheme(state, now)
	elseif phase == "ThemeReveal" then
		beginBuild(state, now)
	elseif phase == "Build" then
		beginTour(state, now)
	elseif phase == "Tour" then
		beginResults(state, now)
	else
		beginLobby(state, now)
	end
end

function RoundEngine.roomLocked(state: State, now: number): boolean
	if state.phase ~= "Tour" or #state.tourStops == 0 then
		return false
	end
	local per = state.config.Phases.TourPerRoom
	local beat = state.config.Phases.TourLockIn or 0
	if type(per) ~= "number" or per <= 0 then
		return true
	end
	if type(beat) ~= "number" or beat < 0 then
		beat = 0
	end
	if beat > per then
		beat = per
	end
	return (now - state.tourSegmentStartedAt) >= (per - beat)
end

-- Move the tour pointer using scheduled room start times so a late tick still
-- lands on the room that should be showing, instead of jumping to Results.
local function advanceTour(state: State, now: number)
	if state.phase ~= "Tour" then
		return
	end
	local per = state.config.Phases.TourPerRoom
	if type(per) ~= "number" or per <= 0 then
		state.phaseEndsAt = now
		return
	end
	while state.tourIndex <= #state.tourStops do
		local roomEnd = state.tourSegmentStartedAt + per
		if now < roomEnd then
			break
		end
		state.tourIndex += 1
		state.tourSegmentStartedAt = roomEnd
	end
	retimeTour(state, now, false)
end

-- Phases start at the time they were scheduled, so a late tick still gives each
-- phase its full length instead of skipping ahead from "now".
local function settle(state: State, now: number)
	local guard = 0
	while guard < 32 do
		guard += 1
		advanceTour(state, now)
		if not expired(state, now) then
			break
		end
		local at = state.phaseEndsAt
		if at == nil then
			break
		end
		enterNext(state, at)
	end
end

local function finishBuild(state: State, now: number)
	if state.phase ~= "Build" then
		return
	end
	beginTour(state, now)
	settle(state, now)
end

function RoundEngine.create(options: {
	config: any,
	themes: { any },
	rng: (() -> number)?,
	unixNow: (() -> number)?,
	history: { string }?,
}): State
	local history: { string } = {}
	if options.history then
		for _, id in ipairs(options.history) do
			table.insert(history, id)
		end
	end
	local state: State = {
		config = options.config,
		themes = options.themes,
		rng = options.rng or math.random,
		unixNow = options.unixNow or function()
			return os.time()
		end,
		phase = "Lobby",
		phaseStartedAt = 0,
		phaseEndsAt = nil,
		players = {},
		tourStops = {},
		tourIndex = 1,
		tourSegmentStartedAt = 0,
		history = history,
		roundIndex = 0,
		hostThemeId = nil,
		nextDoneOrder = 1,
		theme = nil,
		season = "",
		trace = {},
		hasWork = nil,
		tourSkip = {},
	}
	state.season = Season.resolve(state.config.Season, state.unixNow(), state.config.TimezoneOffsetHours)
	note(state, "Lobby", 0)
	return state
end

function RoundEngine.setHasWork(state: State, fn: (string) -> any)
	state.hasWork = fn
end

function RoundEngine.setUnixNow(state: State, unixNow: () -> number)
	state.unixNow = unixNow
	state.season = Season.resolve(state.config.Season, unixNow(), state.config.TimezoneOffsetHours)
end

-- Private-server host pick. Not a client action. Applied on the next theme reveal, once.
function RoundEngine.setHostTheme(state: State, themeId: string?): (boolean, string?)
	if themeId == nil or themeId == "" then
		state.hostThemeId = nil
		return true, nil
	end
	if type(themeId) ~= "string" then
		return false, "Bad request."
	end
	if ThemePicker.find(state.themes, themeId) == nil then
		return false, "Unknown theme."
	end
	state.hostThemeId = themeId
	return true, nil
end

function RoundEngine.join(state: State, id: string, now: number)
	if state.players[id] then
		return
	end
	local role: Role = if state.phase == "Lobby" then "active" else "spectator"
	state.players[id] = {
		role = role,
		done = false,
		submitted = false,
		doneOrder = 0,
	}
	if state.phase == "Lobby" and state.phaseEndsAt == nil and activeCount(state) >= 1 then
		state.phaseStartedAt = now
		state.phaseEndsAt = now + state.config.Phases.Lobby
	end
end

function RoundEngine.leave(state: State, id: string, now: number)
	local player = state.players[id]
	if not player then
		return
	end
	state.players[id] = nil
	dropStop(state, id, now)
	if state.phase == "Lobby" then
		if activeCount(state) < 1 then
			state.phaseEndsAt = nil
		end
	elseif state.phase == "Build" then
		if activeCount(state) < 1 or allActiveDone(state) then
			finishBuild(state, now)
		end
	elseif state.phase == "Tour" then
		settle(state, now)
	end
end

function RoundEngine.pressDone(state: State, id: string, now: number): (boolean, string?)
	if state.phase ~= "Build" then
		return false, "DONE is only during Build."
	end
	local player = state.players[id]
	if not player then
		return false, "You are not in this round."
	end
	if player.role ~= "active" then
		return false, "Watching this round. You will play the next one."
	end
	if player.done then
		return false, "You already pressed DONE."
	end
	player.done = true
	player.submitted = true
	player.doneOrder = state.nextDoneOrder
	state.nextDoneOrder += 1
	if allActiveDone(state) then
		finishBuild(state, now)
	end
	return true, "Locked in."
end

function RoundEngine.advance(state: State, now: number)
	settle(state, now)
end

-- Pull a reported room off the tour. The same skip used when its owner leaves.
function RoundEngine.removeStop(state: State, id: string, now: number)
	dropStop(state, id, now)
	if state.phase == "Tour" then
		settle(state, now)
	end
end

function RoundEngine.timeLeft(state: State, now: number): number
	if state.phaseEndsAt == nil then
		if state.phase == "Lobby" then
			return state.config.Phases.Lobby
		end
		return 0
	end
	return math.max(0, state.phaseEndsAt - now)
end

function RoundEngine.snapshot(state: State, now: number): { [string]: any }
	local theme = state.theme
	local themeName = ""
	local themeId = ""
	local roundType = ""
	if type(theme) == "table" then
		themeName = theme.name or ""
		themeId = theme.id or ""
		roundType = theme.roundType or ""
	end
	local tourLabel = ""
	local tourIndex = 0
	local tourTarget = ""
	if state.phase == "Tour" and #state.tourStops > 0 then
		local shown = math.clamp(state.tourIndex, 1, #state.tourStops)
		tourIndex = shown
		tourTarget = state.tourStops[shown]
		tourLabel = string.format("Room %d of %d", shown, #state.tourStops)
		if RoundEngine.roomLocked(state, now) then
			tourLabel = tourLabel .. " · Locked"
		end
	end
	local waiting = state.phase == "Lobby" and state.phaseEndsAt == nil
	return {
		phase = state.phase,
		timeLeft = RoundEngine.timeLeft(state, now),
		endsAt = state.phaseEndsAt or 0,
		waiting = waiting,
		themeName = themeName,
		themeId = themeId,
		roundType = roundType,
		season = state.season,
		tourLabel = tourLabel,
		tourIndex = tourIndex,
		tourTarget = tourTarget,
		tourLocked = if state.phase == "Tour" then RoundEngine.roomLocked(state, now) else false,
		critic = state.config.Critic.name,
		roundIndex = state.roundIndex,
	}
end

function RoundEngine.playerView(state: State, id: string): { spectating: boolean, done: boolean, inRound: boolean }
	local player = state.players[id]
	if not player then
		return { spectating = false, done = false, inRound = false }
	end
	return {
		spectating = player.role == "spectator",
		done = player.done,
		inRound = true,
	}
end

return RoundEngine
