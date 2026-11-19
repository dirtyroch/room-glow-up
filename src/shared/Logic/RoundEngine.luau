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
local Modifiers = sibling("Modifiers")

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
	-- True when a DONE builder made a real room (a few pieces or half the
	-- budget). A one-piece DONE does not push the 30-second rush. Nil = any.
	realBuild: ((string) -> any)?,
	-- Seconds bought this build (+60 s). The rush never cuts these away.
	paidSeconds: number,
	-- Partner ids in a duo room. They build, but the tour stops once.
	tourSkip: { [string]: boolean },
	-- Extra minutes bought for this round. Reset when the next lobby starts.
	timeAdds: number,
	bankedTime: number,
	-- Server-picked twist for this round. Nil on the rounds in between.
	modifier: string?,
	-- The 30-second build rush. `rush` means it already fired this build.
	-- `showBanner` is the "30 seconds left!" call, cleared if time is added back.
	rush: boolean,
	showBanner: boolean,
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

-- Done builders count. Someone still placing counts. An idle or empty
-- builder does not, so they cannot hold the round open by themselves.
local function countsForRush(state: State, id: string, player: PlayerState): boolean
	if player.role ~= "active" then
		return false
	end
	if player.done then
		-- One piece and DONE is the same as idle: it neither waits on the
		-- others nor pushes them to hurry.
		local real = state.realBuild
		if type(real) == "function" then
			local ok, value = pcall(real, id)
			return ok and value == true
		end
		return true
	end
	local fn = state.hasWork
	if type(fn) ~= "function" then
		return true
	end
	local ok, value = pcall(fn, id)
	return ok and value == true
end

local function rushKnobs(state: State): (number, number, string, number)
	local spec = state.config.BuildRush
	local fraction = 0.6
	local seconds = 30
	local banner = "30 seconds left!"
	local minElapsed = 60
	if type(spec) == "table" then
		if type(spec.MinElapsed) == "number" and spec.MinElapsed >= 0 then
			minElapsed = spec.MinElapsed
		end
		if type(spec.Fraction) == "number" and spec.Fraction > 0 and spec.Fraction <= 1 then
			fraction = spec.Fraction
		end
		if type(spec.FinalSeconds) == "number" and spec.FinalSeconds > 0 then
			seconds = spec.FinalSeconds
		end
		if type(spec.Banner) == "string" and spec.Banner ~= "" then
			banner = spec.Banner
		end
	end
	return fraction, seconds, banner, minElapsed
end

local function rushReady(state: State): boolean
	local eligible = 0
	local done = 0
	for id, player in pairs(state.players) do
		if countsForRush(state, id, player) then
			eligible += 1
			if player.done then
				done += 1
			end
		end
	end
	if done < 1 or eligible < 1 then
		return false
	end
	local fraction = rushKnobs(state)
	local remaining = eligible - done
	if eligible >= 2 and remaining <= 1 then
		return true
	end
	return done / eligible >= fraction - 1e-9
end

local function maybeRush(state: State, now: number)
	if state.phase ~= "Build" or state.rush then
		return
	end
	-- Early on, most kids have not placed yet and would not count. Wait until
	-- the room has had time to fill, so one item and DONE cannot cut the clock.
	local _f, _s, _b, minElapsed = rushKnobs(state)
	if now - state.phaseStartedAt < minElapsed then
		return
	end
	if not rushReady(state) then
		return
	end
	local _, seconds = rushKnobs(state)
	-- A bought minute is kept on top of the rush clock.
	local paid = state.paidSeconds
	if type(paid) == "number" and paid > 0 then
		seconds += paid
	end
	local ends = state.phaseEndsAt
	if type(ends) ~= "number" then
		return
	end
	state.rush = true
	if ends - now <= seconds then
		return
	end
	state.phaseEndsAt = now + seconds
	state.showBanner = true
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
	-- Done-order put the fastest builder first, and that room scored lower.
	-- Shuffle with the round rng so the tour is not that sequence.
	local rng = state.rng
	if type(rng) == "function" then
		for i = #ids, 2, -1 do
			local roll = rng()
			if type(roll) ~= "number" or roll ~= roll then
				roll = 0
			end
			if roll < 0 then
				roll = 0
			elseif roll > 1 then
				roll = 1
			end
			local j = math.floor(roll * i) + 1
			if j < 1 then
				j = 1
			elseif j > i then
				j = i
			end
			ids[i], ids[j] = ids[j], ids[i]
		end
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
	if type(state.modifier) ~= "string" then
		state.modifier = Modifiers.pick(state.roundIndex)
	end
	state.phase = "ThemeReveal"
	state.phaseStartedAt = now
	state.phaseEndsAt = now + state.config.Phases.ThemeReveal
	note(state, "ThemeReveal", now)
end

local function beginBuild(state: State, now: number)
	state.phase = "Build"
	state.phaseStartedAt = now
	local extra = state.bankedTime
	if type(extra) ~= "number" or extra ~= extra or extra < 0 then
		extra = 0
	end
	local span = Modifiers.buildSeconds(state.config.Phases.Build, state.modifier)
	-- A minute bought ahead of a Speed Round does not stretch the clock.
	if state.modifier == "speed" then
		extra = 0
	end
	state.bankedTime = 0
	state.paidSeconds = extra
	state.rush = false
	state.showBanner = false
	if activeCount(state) < 1 then
		-- Nobody left to decorate; skip the 240s wait and go to Tour.
		state.phaseEndsAt = now
	else
		state.phaseEndsAt = now + span + extra
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
	state.timeAdds = 0
	state.bankedTime = 0
	state.modifier = Modifiers.pick(state.roundIndex)
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

local function tourBeat(state: State): (number, number, number)
	local per = state.config.Phases.TourPerRoom
	local beat = state.config.Phases.TourLockIn or 0
	local grace = state.config.Phases.TourVoteGrace or 0
	if type(per) ~= "number" or per <= 0 then
		return 0, 0, 0
	end
	if type(beat) ~= "number" or beat < 0 then
		beat = 0
	end
	if beat > per then
		beat = per
	end
	if type(grace) ~= "number" or grace < 0 then
		grace = 0
	end
	return per, beat, grace
end

function RoundEngine.roomLocked(state: State, now: number): boolean
	if state.phase ~= "Tour" or #state.tourStops == 0 then
		return false
	end
	local per, beat = tourBeat(state)
	if per <= 0 then
		return true
	end
	return (now - state.tourSegmentStartedAt) >= (per - beat)
end

-- Votes stay open through the visual lock, for TourVoteGrace seconds.
function RoundEngine.votesClosed(state: State, now: number): boolean
	if state.phase ~= "Tour" or #state.tourStops == 0 then
		return true
	end
	local per, beat, grace = tourBeat(state)
	if per <= 0 then
		return true
	end
	local closeAt = per - beat + grace
	if closeAt > per then
		closeAt = per
	end
	return (now - state.tourSegmentStartedAt) >= closeAt
end

-- Everyone who can vote has voted. End this room after a short beat.
function RoundEngine.hurryTour(state: State, now: number)
	if state.phase ~= "Tour" or #state.tourStops == 0 then
		return
	end
	if state.tourIndex < 1 or state.tourIndex > #state.tourStops then
		return
	end
	local per = tourBeat(state)
	if per <= 0 then
		return
	end
	local beat = state.config.Phases.TourSkipBeat
	if type(beat) ~= "number" or beat < 0 then
		beat = 1
	end
	local roomEnd = state.tourSegmentStartedAt + per
	local soon = now + beat
	if soon >= roomEnd - 1e-6 then
		return
	end
	state.tourSegmentStartedAt = soon - per
	retimeTour(state, now, false)
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
		realBuild = nil,
		paidSeconds = 0,
		tourSkip = {},
		timeAdds = 0,
		bankedTime = 0,
		modifier = Modifiers.pick(0),
		rush = false,
		showBanner = false,
	}
	state.season = Season.resolve(state.config.Season, state.unixNow(), state.config.TimezoneOffsetHours)
	note(state, "Lobby", 0)
	return state
end

function RoundEngine.setHasWork(state: State, fn: (string) -> any)
	state.hasWork = fn
end

function RoundEngine.setRealBuild(state: State, fn: (string) -> any)
	state.realBuild = fn
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

-- +60s for the whole server. Lobby and theme bank it onto Build. Tour does not.
-- The cap is per round. A refused call does not spend a charge.
function RoundEngine.extend(state: State, seconds: number, cap: number): (boolean, string?)
	if type(state.timeAdds) ~= "number" then
		state.timeAdds = 0
	end
	if not Modifiers.allowsTime(state.modifier) then
		return false, "Speed Round keeps its clock."
	end
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		return false, "Bad request."
	end
	if type(cap) ~= "number" or cap < 1 then
		cap = 1
	end
	if state.timeAdds >= cap then
		return false, "This round already has two extra minutes."
	end
	local add = math.floor(seconds)
	if state.phase == "Build" and type(state.phaseEndsAt) == "number" then
		state.timeAdds += 1
		state.phaseEndsAt += add
		state.paidSeconds = (state.paidSeconds or 0) + add
		-- Paid time is not the rush banner. The rush does not fire again.
		state.showBanner = false
		return true, "Added a minute for everyone."
	end
	if state.phase == "Lobby" or state.phase == "ThemeReveal" then
		state.timeAdds += 1
		state.bankedTime = (state.bankedTime or 0) + add
		return true, "The next build gets an extra minute."
	end
	return false, "Extra time waits for the lobby."
end

-- `returning` is a kid whose room was kept through a short disconnect. They
-- go back to building however much time is left.
function RoundEngine.join(state: State, id: string, now: number, returning: boolean?)
	if state.players[id] then
		return
	end
	local role: Role = "spectator"
	if state.phase == "Lobby" then
		role = "active"
	elseif state.phase == "Build" and returning == true then
		local cap = state.config.MaxPlayers
		if type(cap) ~= "number" or cap < 1 then
			cap = 10
		end
		if activeCount(state) < cap then
			role = "active"
		end
	elseif state.phase == "Build" then
		local minSeconds = 60
		local late = state.config.LateJoin
		if type(late) == "table" and type(late.MinBuild) == "number" then
			minSeconds = late.MinBuild
		end
		local cap = state.config.MaxPlayers
		if type(cap) ~= "number" or cap < 1 then
			cap = 10
		end
		if RoundEngine.timeLeft(state, now) >= minSeconds and activeCount(state) < cap then
			role = "active"
		end
	end
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
		else
			maybeRush(state, now)
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
	else
		maybeRush(state, now)
	end
	return true, "Locked in."
end

function RoundEngine.advance(state: State, now: number)
	-- The rush can come due on the clock alone, once MinElapsed has passed.
	maybeRush(state, now)
	settle(state, now)
end

-- Hand a duo stop to the remaining partner so the room stays on the tour.
function RoundEngine.reassignStop(state: State, fromId: string, toId: string)
	if type(fromId) ~= "string" or type(toId) ~= "string" or fromId == toId or toId == "" then
		return
	end
	if table.find(state.tourStops, toId) then
		return
	end
	local idx = table.find(state.tourStops, fromId)
	if idx then
		state.tourStops[idx] = toId
	end
end

-- Pull a reported room off the tour. The same skip used when its owner leaves.
function RoundEngine.removeStop(state: State, id: string, now: number)
	dropStop(state, id, now)
	if state.phase == "Tour" then
		settle(state, now)
	end
end

function RoundEngine.untilNextRound(state: State, now: number): number
	if state.phase == "Lobby" then
		return 0
	end
	local left = RoundEngine.timeLeft(state, now)
	local phases = state.config.Phases
	if state.phase == "Results" then
		return left
	end
	if state.phase == "Tour" then
		return left + phases.Results
	end
	local build = phases.Build
	if state.modifier == "speed" and type(state.config.Modifiers) == "table" then
		local speed = state.config.Modifiers.SpeedBuild
		if type(speed) == "number" then
			build = speed
		end
	end
	local rooms = 0
	for _, player in pairs(state.players) do
		if player.role == "active" then
			rooms += 1
		end
	end
	if rooms < 1 then
		rooms = 1
	end
	local tour = phases.TourPerRoom * rooms
	if state.phase == "ThemeReveal" then
		return left + build + tour + phases.Results
	end
	return left + tour + phases.Results
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
		tourLabel = Modifiers.tourLine(shown, #state.tourStops, {})
		if RoundEngine.roomLocked(state, now) then
			tourLabel = tourLabel .. " · Locked"
		end
	end
	local waiting = state.phase == "Lobby" and state.phaseEndsAt == nil
	local mysteryItem = ""
	if state.modifier == "mystery" and state.phase ~= "Lobby" then
		mysteryItem = Modifiers.mystery(roundType, state.roundIndex)
	end
	return {
		phase = state.phase,
		timeLeft = RoundEngine.timeLeft(state, now),
		endsAt = state.phaseEndsAt or 0,
		waiting = waiting,
		themeName = themeName,
		themeId = themeId,
		roundType = roundType,
		modifier = state.modifier or "",
		modifierLabel = Modifiers.announce(state.modifier, state.phase),
		mysteryItem = mysteryItem,
		season = state.season,
		tourLabel = tourLabel,
		tourIndex = tourIndex,
		tourTarget = tourTarget,
		tourLocked = if state.phase == "Tour" then RoundEngine.roomLocked(state, now) else false,
		votesOpen = state.phase == "Tour" and not RoundEngine.votesClosed(state, now),
		banner = if state.phase == "Build" and state.showBanner then (select(3, rushKnobs(state))) else "",
		nextRound = RoundEngine.untilNextRound(state, now),
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
