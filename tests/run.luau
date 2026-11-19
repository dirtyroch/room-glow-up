--!nocheck
-- Unit tests for the round engine. Run with:  lune run tests/run
local fs = require("@lune/fs")
local process = require("@lune/process")

local Config = require("../src/shared/Config")
local Replica = require("../src/shared/Replica")
local Themes = require("../src/shared/Themes")
local ClockFormat = require("../src/shared/Logic/ClockFormat")
local HudLayout = require("../src/shared/Logic/HudLayout")
local RateLimiter = require("../src/shared/Logic/RateLimiter")
local ThemePicker = require("../src/shared/Logic/ThemePicker")
local Round = require("../src/shared/Logic/Round")
local Actions = require("../src/shared/Logic/Actions")

local passed, failed = 0, 0
local current = ""

local function test(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n      " .. tostring(err))
	end
end

local function eq(a, b, msg: string?)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or current, tostring(b), tostring(a)), 2)
	end
end

local function truthy(v, msg: string?)
	if not v then
		error(msg or (current .. ": expected truthy"), 2)
	end
end

local function zeroRng(): number
	return 0
end

local function newRound(override: string?, year: number?, month: number?, day: number?)
	return Round.new(0, {
		rng = zeroRng,
		seasonOverride = override,
		year = year or 2026,
		month = month or 12,
		day = day or 1,
	})
end

local function enterBuild(ids: { string }, override: string?)
	local state = newRound(override or "holiday")
	for _, id in ipairs(ids) do
		local ok, err = Round.join(state, id, 0)
		truthy(ok, err)
	end
	eq(state.phase, Round.Lobby)
	eq(state.holding, false)
	Round.tick(state, Config.Phases.Lobby - 0.01)
	eq(state.phase, Round.Lobby)
	Round.tick(state, Config.Phases.Lobby)
	eq(state.phase, Round.ThemeReveal)
	local buildAt = Config.Phases.Lobby + Config.Phases.ThemeReveal
	Round.tick(state, buildAt - 0.01)
	eq(state.phase, Round.ThemeReveal)
	Round.tick(state, buildAt)
	eq(state.phase, Round.Build)
	return state, buildAt
end

print("Config")
test("phase lengths match the round spec", function()
	eq(Config.Phases.Lobby, 20)
	eq(Config.Phases.ThemeReveal, 5)
	eq(Config.Phases.Build, 240)
	eq(Config.Phases.TourPerRoom, 8)
	eq(Config.Phases.Results, 15)
end)

test("server holds 10 and a solo round is allowed", function()
	eq(Config.MaxPlayers, 10)
	eq(Config.MinPlayers, 1)
	eq(Config.Critic.name, "Auntie Roch")
	eq(Config.Stars.min, 1)
	eq(Config.Stars.max, 5)
	eq(Config.RecentThemes, 10)
	eq(Config.Season, "auto")
	eq(Config.GameName, "Room Glow Up")
	eq(Config.SeasonTitle, "Holiday Season")
	eq(Config.RoundTypeOrder[1], "room")
	eq(Config.RoundTypeOrder[2], "gingerbread")
	eq(Config.RoundTypeOrder[3], "tree")
end)

test("theme catalog passes the sanity audit", function()
	local problems = Themes.audit()
	if #problems > 0 then
		error(table.concat(problems, "; "))
	end
	truthy(Themes.count() >= 40)
	truthy(#Themes.forSeason("holiday") >= 40)
	truthy(#Themes.forSeason("winter") >= 12)
end)

test("replica attribute names are unique", function()
	local seen = {}
	for _, key in pairs(Replica) do
		truthy(type(key) == "string" and key ~= "")
		truthy(not seen[key], "duplicate attribute " .. tostring(key))
		seen[key] = true
	end
end)

print("Themes")
test("season filter keeps holiday and winter apart", function()
	for _, theme in ipairs(Themes.forSeason("holiday")) do
		eq(theme.season, "holiday")
	end
	for _, theme in ipairs(Themes.forSeason("winter")) do
		eq(theme.season, "winter", theme.id)
		truthy(theme.roundType ~= "gingerbread", theme.id)
	end
	eq(Themes.byId("gumdrop-cottage").season, "holiday")
	eq(Themes.byId("frost-pane-parlor").season, "winter")
	local holiday = {}
	for _, theme in ipairs(Themes.forSeason("holiday")) do
		holiday[theme.id] = true
	end
	truthy(not holiday["frost-pane-parlor"])
	truthy(holiday["bell-choir-room"])
end)

test("auto season is holiday through 31 Dec 2026 and winter after", function()
	eq(Themes.seasonForDate(2026, 11, 19), "holiday")
	eq(Themes.seasonForDate(2026, 12, 31), "holiday")
	eq(Themes.seasonForDate(2027, 1, 1), "winter")
	eq(Themes.seasonForDate(2027, 12, 25), "winter")
	eq(Themes.seasonForDate(2026, 13, 1), "winter")
	eq(Themes.activeSeason("auto", 2026, 12, 31), "holiday")
	eq(Themes.activeSeason("auto", 2027, 1, 1), "winter")
	eq(Themes.activeSeason("holiday", 2027, 6, 1), "holiday")
	eq(Themes.activeSeason("winter", 2026, 12, 1), "winter")
end)

test("holiday rounds rotate room, gingerbread, tree", function()
	local recent = {}
	local typeIndex = 1
	local expected = { "room", "gingerbread", "tree" }
	local first = {}
	for i = 1, 9 do
		local picked = ThemePicker.pick({
			season = "holiday",
			recent = recent,
			typeIndex = typeIndex,
			rng = zeroRng,
			window = 10,
		})
		truthy(picked)
		eq(picked.theme.roundType, expected[((i - 1) % 3) + 1])
		eq(picked.theme.season, "holiday")
		eq(picked.usedHost, false)
		table.insert(first, picked.theme.id)
		recent = picked.recent
		typeIndex = picked.typeIndex
	end
	eq(first[1], "bell-choir-room")
	eq(first[2], "candy-cane-porch")
	eq(first[3], "bell-strand-tree")
end)

test("winter rotation skips gingerbread and stays in winter", function()
	local recent = {}
	local typeIndex = 1
	local kinds = {}
	for _ = 1, 6 do
		local picked = ThemePicker.pick({
			season = "winter",
			recent = recent,
			typeIndex = typeIndex,
			rng = zeroRng,
			window = 10,
		})
		truthy(picked)
		eq(picked.theme.season, "winter")
		truthy(picked.theme.roundType ~= "gingerbread")
		table.insert(kinds, picked.theme.roundType)
		recent = picked.recent
		typeIndex = picked.typeIndex
	end
	eq(kinds[1], "room")
	eq(kinds[2], "tree")
	eq(kinds[3], "room")
	eq(kinds[4], "tree")
	eq(kinds[1] == "room" and recent[1] ~= nil, true)
	eq(Themes.byId("aurora-window").roundType, "room")
end)

test("no theme repeats inside the last 10 picks", function()
	local recent = {}
	local typeIndex = 1
	local ids = {}
	for i = 1, 24 do
		local picked = ThemePicker.pick({
			season = "holiday",
			recent = recent,
			typeIndex = typeIndex,
			rng = zeroRng,
			window = 10,
		})
		truthy(picked)
		for j = math.max(1, i - 10), i - 1 do
			if ids[j] == picked.theme.id then
				error("repeat of " .. picked.theme.id .. " at " .. tostring(i))
			end
		end
		ids[i] = picked.theme.id
		recent = picked.recent
		typeIndex = picked.typeIndex
	end
end)

test("a tight pool of 11 still avoids the last 10, then reuses the oldest", function()
	local tiny = {}
	for n = 1, 11 do
		table.insert(tiny, {
			id = string.format("room-%02d", n),
			name = "Room " .. tostring(n),
			roundType = "room",
			season = "holiday",
		})
	end
	local recent = {}
	local ids = {}
	for n = 1, 12 do
		local before = table.clone(recent)
		local picked = ThemePicker.pick({
			season = "holiday",
			themes = tiny,
			recent = recent,
			typeIndex = 1,
			rng = zeroRng,
			window = 10,
		})
		truthy(picked)
		if n <= 11 then
			for _, old in ipairs(before) do
				truthy(old ~= picked.theme.id, "repeated " .. picked.theme.id .. " on pick " .. tostring(n))
			end
		end
		ids[n] = picked.theme.id
		recent = picked.recent
	end
	eq(ids[1], "room-01")
	eq(ids[11], "room-11")
	eq(ids[12], "room-01")
	eq(#recent, 10)
end)

test("host theme hook accepts an in-season id and does not consume the rotation", function()
	local picked = ThemePicker.pick({
		season = "holiday",
		recent = {},
		typeIndex = 1,
		rng = zeroRng,
		hostThemeId = "gumdrop-cottage",
	})
	truthy(picked)
	eq(picked.theme.id, "gumdrop-cottage")
	eq(picked.usedHost, true)
	eq(picked.typeIndex, 1)

	local follow = ThemePicker.pick({
		season = "holiday",
		recent = picked.recent,
		typeIndex = picked.typeIndex,
		rng = zeroRng,
	})
	truthy(follow)
	eq(follow.theme.roundType, "room")
	eq(follow.theme.id, "bell-choir-room")

	local wrongSeason = ThemePicker.pick({
		season = "holiday",
		typeIndex = 1,
		rng = zeroRng,
		hostThemeId = "frost-pane-parlor",
	})
	truthy(wrongSeason)
	eq(wrongSeason.usedHost, false)
	eq(wrongSeason.theme.roundType, "room")

	local missing = ThemePicker.pick({
		season = "holiday",
		typeIndex = 1,
		rng = zeroRng,
		hostThemeId = "not-a-real-theme",
	})
	truthy(missing)
	eq(missing.usedHost, false)
	eq(ThemePicker.pick({ season = "holiday", themes = {}, typeIndex = 1, rng = zeroRng }), nil)
end)

print("Round")
test("lobby waits with nobody here, then counts 20s from the first join", function()
	local state = newRound("holiday")
	eq(state.holding, true)
	eq(Round.timeLeft(state, 0), -1)
	eq(#Round.tick(state, 500), 0)
	eq(state.phase, Round.Lobby)
	local ok, msg = Round.join(state, "a", 100)
	truthy(ok)
	eq(msg, "You're in.")
	eq(state.holding, false)
	eq(state.phaseEndsAt, 120)
	eq(Round.timeLeft(state, 100), 20)
	eq(Round.timeLeft(state, 101), 19)
	Round.tick(state, 119.9)
	eq(state.phase, Round.Lobby)
	local entered = Round.tick(state, 120)
	eq(state.phase, Round.ThemeReveal)
	eq(entered[1], Round.ThemeReveal)
end)

test("a second lobby join does not reset the clock", function()
	local state = newRound("holiday")
	Round.join(state, "a", 0)
	Round.join(state, "b", 5)
	eq(state.phaseEndsAt, Config.Phases.Lobby)
	eq(Round.timeLeft(state, 5), 15)
end)

test("the last player leaving the lobby holds it again", function()
	local state = newRound("holiday")
	Round.join(state, "a", 0)
	Round.leave(state, "a", 4)
	eq(state.phase, Round.Lobby)
	eq(state.holding, true)
	eq(#Round.tick(state, 1000), 0)
	eq(state.phase, Round.Lobby)
end)

test("every phase runs, in order, on the full clock", function()
	local state = newRound("holiday")
	Round.join(state, "p", 0)
	eq(Round.timeLeft(state, 0), 20)
	eq(Round.timeLeft(state, 1), 19)
	local seen = { state.phase }
	local last = state.phase
	for t = 1, 300 do
		Round.tick(state, t)
		if state.phase ~= last then
			table.insert(seen, state.phase)
			last = state.phase
		end
	end
	eq(table.concat(seen, ">"), "Lobby>ThemeReveal>Build>Tour>Results>Lobby")
	local revealAt = Config.Phases.Lobby
	local fresh = newRound("holiday")
	Round.join(fresh, "p", 0)
	Round.tick(fresh, revealAt)
	local view = Round.view(fresh, revealAt)
	eq(view.phase, Round.ThemeReveal)
	eq(view.timeLeft, Config.Phases.ThemeReveal)
	eq(view.themeName, "Bell Choir Room")
	eq(view.themeId, "bell-choir-room")
	eq(view.roundType, "room")
	eq(view.seasonLabel, "Holiday Season")
end)

test("build ends early when every active player presses DONE", function()
	local state, buildAt = enterBuild({ "a", "b" })
	local ok, msg = Round.done(state, "a", buildAt + 1)
	truthy(ok)
	eq(msg, "Room locked in.")
	eq(state.phase, Round.Build)
	eq(Round.role(state, "a"), "done")
	eq(Round.role(state, "b"), "playing")
	ok, msg = Round.done(state, "b", buildAt + 3)
	truthy(ok)
	eq(state.phase, Round.Tour)
	eq(#state.tourOrder, 2)
	eq(state.tourOrder[1], "a")
	eq(state.tourOrder[2], "b")
	truthy(buildAt + 3 < buildAt + Config.Phases.Build)
	eq(state.phaseEndsAt, buildAt + 3 + Config.Phases.TourPerRoom)
end)

test("a second DONE is rejected and a spectator cannot lock in", function()
	local state, buildAt = enterBuild({ "a" })
	local ok = Round.done(state, "a", buildAt + 1)
	truthy(ok)
	eq(state.phase, Round.Tour)
	local state2, at2 = enterBuild({ "a", "b" })
	local first, firstMsg = Round.done(state2, "a", at2 + 1)
	truthy(first, firstMsg)
	local second, secondMsg = Round.done(state2, "a", at2 + 2)
	eq(second, false)
	eq(secondMsg, "Already finished.")
	eq(state2.phase, Round.Build)
	local joined, joinMsg = Round.join(state2, "late", at2 + 2)
	truthy(joined, joinMsg)
	eq(Round.role(state2, "late"), "spectating")
	local watched, watchMsg = Round.done(state2, "late", at2 + 3)
	eq(watched, false)
	eq(watchMsg, "You're watching this round.")
	eq(state2.phase, Round.Build)
end)

test("DONE outside of build is rejected", function()
	local state = newRound("holiday")
	Round.join(state, "a", 0)
	local ok, msg = Round.done(state, "a", 1)
	eq(ok, false)
	eq(msg, "Not during build.")
end)

test("the clock submits everyone who stayed, including players who did not press DONE", function()
	local state, buildAt = enterBuild({ "a", "b" })
	truthy(Round.done(state, "a", buildAt + 1))
	eq(state.phase, Round.Build)
	Round.tick(state, buildAt + Config.Phases.Build)
	eq(state.phase, Round.Tour)
	eq(#state.tourOrder, 2)
	eq(state.phaseEndsAt, buildAt + Config.Phases.Build + Config.Phases.TourPerRoom)
	Round.tick(state, buildAt + Config.Phases.Build + Config.Phases.TourPerRoom)
	eq(state.phase, Round.Tour)
	eq(state.tourIndex, 2)
	eq(state.phaseEndsAt, buildAt + Config.Phases.Build + Config.Phases.TourPerRoom * 2)
	Round.tick(state, state.phaseEndsAt)
	eq(state.phase, Round.Results)
end)

test("a player who joins mid-round spectates, then plays the next lobby", function()
	local state, buildAt = enterBuild({ "a" })
	local ok, msg = Round.join(state, "late", buildAt + 1)
	truthy(ok)
	eq(msg, "You'll play next round.")
	eq(Round.role(state, "late"), "spectating")
	Round.tick(state, buildAt + Config.Phases.Build)
	eq(state.phase, Round.Tour)
	eq(#state.tourOrder, 1)
	eq(state.tourOrder[1], "a")
	local resultsAt = state.phaseEndsAt
	Round.tick(state, resultsAt)
	eq(state.phase, Round.Results)
	Round.tick(state, state.phaseEndsAt)
	eq(state.phase, Round.Lobby)
	eq(Round.role(state, "late"), "playing")
	eq(Round.role(state, "a"), "playing")
	eq(state.holding, false)
end)

test("a player who joins during the theme reveal does not get a room", function()
	local state = newRound("holiday")
	Round.join(state, "a", 0)
	Round.tick(state, Config.Phases.Lobby)
	eq(state.phase, Round.ThemeReveal)
	Round.join(state, "late", Config.Phases.Lobby + 1)
	eq(Round.role(state, "late"), "spectating")
	Round.tick(state, Config.Phases.Lobby + Config.Phases.ThemeReveal)
	eq(state.phase, Round.Build)
	Round.tick(state, Config.Phases.Lobby + Config.Phases.ThemeReveal + Config.Phases.Build)
	eq(#state.tourOrder, 1)
	eq(state.tourOrder[1], "a")
end)

test("leaving mid-build skips that room", function()
	local state, buildAt = enterBuild({ "a", "b" })
	Round.leave(state, "b", buildAt + 1)
	eq(state.phase, Round.Build)
	Round.tick(state, buildAt + Config.Phases.Build)
	eq(state.phase, Round.Tour)
	eq(#state.tourOrder, 1)
	eq(state.tourOrder[1], "a")
end)

test("leaving after the others have pressed DONE ends build early and skips the room", function()
	local state, buildAt = enterBuild({ "a", "b" })
	truthy(Round.done(state, "a", buildAt + 1))
	Round.leave(state, "b", buildAt + 2)
	eq(state.phase, Round.Tour)
	eq(#state.tourOrder, 1)
	eq(state.tourOrder[1], "a")
end)

test("leaving during your tour slot skips the rest of it", function()
	local state, buildAt = enterBuild({ "a", "b", "c" })
	truthy(Round.done(state, "a", buildAt))
	truthy(Round.done(state, "b", buildAt))
	truthy(Round.done(state, "c", buildAt))
	eq(state.phase, Round.Tour)
	eq(state.tourIndex, 1)
	eq(state.tourOrder[1], "a")
	local showingB = buildAt + 1
	Round.leave(state, "a", showingB)
	eq(state.phase, Round.Tour)
	eq(state.tourOrder[1], "b")
	eq(state.tourIndex, 1)
	eq(#state.tourOrder, 2)
	eq(state.phaseEndsAt, showingB + Config.Phases.TourPerRoom)
	local ends = state.phaseEndsAt
	Round.leave(state, "c", showingB + 1)
	eq(state.phase, Round.Tour)
	eq(state.tourIndex, 1)
	eq(state.tourOrder[1], "b")
	eq(#state.tourOrder, 1)
	eq(state.phaseEndsAt, ends)
end)

test("leaving the room on screen does not replay an earlier room", function()
	local state, buildAt = enterBuild({ "a", "b", "c" })
	truthy(Round.done(state, "a", buildAt))
	truthy(Round.done(state, "b", buildAt))
	truthy(Round.done(state, "c", buildAt))
	Round.tick(state, buildAt + Config.Phases.TourPerRoom)
	eq(state.tourOrder[state.tourIndex], "b")
	Round.leave(state, "b", buildAt + Config.Phases.TourPerRoom + 1)
	eq(state.phase, Round.Tour)
	eq(state.tourOrder[state.tourIndex], "c")
	eq(state.tourOrder[1], "a")
	Round.leave(state, "c", buildAt + Config.Phases.TourPerRoom + 2)
	eq(state.phase, Round.Results)
	eq(Round.role(state, "a"), "playing")
end)

test("a round with nobody left to build returns to the lobby", function()
	local state, buildAt = enterBuild({ "a" })
	Round.join(state, "spec", buildAt + 1)
	Round.leave(state, "a", buildAt + 2)
	eq(state.phase, Round.Lobby)
	eq(Round.role(state, "spec"), "playing")
	eq(state.holding, false)
	local solo, soloAt = enterBuild({ "a" })
	Round.leave(solo, "a", soloAt + 1)
	eq(solo.phase, Round.Lobby)
	eq(solo.holding, true)
end)

test("leaving during the reveal drops that room", function()
	local state = newRound("holiday")
	Round.join(state, "a", 0)
	Round.join(state, "b", 0)
	Round.tick(state, Config.Phases.Lobby)
	eq(state.phase, Round.ThemeReveal)
	Round.leave(state, "b", Config.Phases.Lobby + 1)
	eq(state.phase, Round.ThemeReveal)
	Round.tick(state, Config.Phases.Lobby + Config.Phases.ThemeReveal)
	eq(state.phase, Round.Build)
	eq(#Round.activeIds(state), 1)
	eq(Round.activeIds(state)[1], "a")
end)

test("the server refuses an 11th player", function()
	local state = newRound("holiday")
	for i = 1, Config.MaxPlayers do
		local ok, err = Round.join(state, "p" .. tostring(i), 0)
		truthy(ok, err)
	end
	local ok, msg = Round.join(state, "overflow", 0)
	eq(ok, false)
	eq(msg, "This server is full.")
end)

test("auto season picks holiday on 31 Dec 2026 and winter on 1 Jan 2027", function()
	local holiday = Round.new(0, { rng = zeroRng, year = 2026, month = 12, day = 31 })
	Round.join(holiday, "a", 0)
	Round.tick(holiday, Config.Phases.Lobby)
	eq(Themes.byId(holiday.themeId).season, "holiday")

	local winter = Round.new(0, { rng = zeroRng, year = 2027, month = 1, day = 1 })
	Round.join(winter, "a", 0)
	Round.tick(winter, Config.Phases.Lobby)
	eq(Themes.byId(winter.themeId).season, "winter")
	eq(winter.themeId, "aurora-window")

	local forced = Round.new(0, {
		rng = zeroRng,
		seasonOverride = "winter",
		year = 2026,
		month = 12,
		day = 31,
	})
	Round.join(forced, "a", 0)
	Round.tick(forced, Config.Phases.Lobby)
	eq(Themes.byId(forced.themeId).season, "winter")
end)

test("host theme is used for one reveal and is not a client action", function()
	local state = newRound("holiday")
	local ok, msg = Round.setHostTheme(state, "gumdrop-cottage")
	truthy(ok, msg)
	local bad = Round.setHostTheme(state, "frost-pane-parlor")
	eq(bad, false)
	eq(state.hostThemeId, "gumdrop-cottage")
	Round.setHostTheme(state, "gumdrop-cottage")
	Round.join(state, "a", 0)
	Round.tick(state, Config.Phases.Lobby)
	eq(state.phase, Round.ThemeReveal)
	eq(state.themeId, "gumdrop-cottage")
	eq(state.hostThemeId, nil)
	Round.tick(state, Config.Phases.Lobby + Config.Phases.ThemeReveal)
	truthy(Round.done(state, "a", state.phaseEndsAt))
	-- done during build ends the build immediately for a solo player
	eq(state.phase, Round.Tour)
	Round.tick(state, state.phaseEndsAt)
	eq(state.phase, Round.Results)
	Round.tick(state, state.phaseEndsAt)
	eq(state.phase, Round.Lobby)
	Round.tick(state, state.phaseEndsAt)
	eq(state.phase, Round.ThemeReveal)
	eq(Themes.byId(state.themeId).roundType, "room")
end)

print("Actions")
test("DONE goes through the handler and ignores client payload", function()
	local state, buildAt = enterBuild({ "p" })
	local themeBefore = state.themeId
	local ctx = Actions.newContext(state, buildAt + 1)
	local ok, msg = Actions.handle(ctx, "p", "Done", 5, "gumdrop-cottage", "eggnog")
	truthy(ok, msg)
	eq(msg, "Room locked in.")
	eq(state.phase, Round.Tour)
	eq(state.themeId, themeBefore)
	eq(state.scores, nil)
end)

test("unknown actions are rejected and client text is not echoed", function()
	local state = newRound("holiday")
	Round.join(state, "p", 0)
	local ctx = Actions.newContext(state, 1)
	local ok, msg = Actions.handle(ctx, "p", "HostTheme", "eggnog", "bathroom", "cozy")
	eq(ok, false)
	eq(msg, "Unknown action.")
	truthy(string.find(msg, "eggnog", 1, true) == nil)
	truthy(string.find(msg, "cozy", 1, true) == nil)
	local badType, badMsg = Actions.handle(ctx, "p", 12)
	eq(badType, false)
	eq(badMsg, "Bad request.")
	local huge, hugeMsg = Actions.handle(ctx, "p", string.rep("Z", Config.RateLimit.maxActionLength + 1))
	eq(huge, false)
	eq(hugeMsg, "Bad request.")
	local who, whoMsg = Actions.handle(ctx, 4, "Hello")
	eq(who, false)
	eq(whoMsg, "Bad request.")
end)

test("actions are rate-limited per player and per action", function()
	local state = newRound("holiday")
	Round.join(state, "p", 0)
	local ctx = Actions.newContext(state, 0)
	for _ = 1, Config.RateLimit.actionBurst do
		local ok, err = Actions.handle(ctx, "p", "Hello")
		truthy(ok, err)
	end
	local blocked, blockedMsg = Actions.handle(ctx, "p", "Hello")
	eq(blocked, false)
	eq(blockedMsg, "Slow down a moment.")
	ctx.limitNow = 1
	local refilled = Actions.handle(ctx, "p", "Hello")
	truthy(refilled)

	local flood = Actions.newContext(state, 0)
	for _ = 1, Config.RateLimit.globalBurst do
		local ok, msg = Actions.handle(flood, "p", "Nope")
		eq(ok, false)
		eq(msg, "Unknown action.")
	end
	local slowed, slowMsg = Actions.handle(flood, "p", "Nope")
	eq(slowed, false)
	eq(slowMsg, "Slow down a moment.")
end)

test("a second call while one is in flight is rejected", function()
	local state = newRound("holiday")
	Round.join(state, "p", 0)
	local ctx = Actions.newContext(state, 1)
	ctx.acting["p"] = true
	local ok, msg = Actions.handle(ctx, "p", "Hello")
	eq(ok, false)
	eq(msg, "Slow down a moment.")
end)

test("DONE from the handler follows the round rules", function()
	local state = newRound("holiday")
	Round.join(state, "p", 0)
	local ctx = Actions.newContext(state, 1)
	local early, earlyMsg = Actions.handle(ctx, "p", "Done")
	eq(early, false)
	eq(earlyMsg, "Not during build.")
	local state2, buildAt = enterBuild({ "a" })
	Round.join(state2, "late", buildAt + 1)
	local ctx2 = Actions.newContext(state2, buildAt + 1)
	local watched, watchMsg = Actions.handle(ctx2, "late", "Done")
	eq(watched, false)
	eq(watchMsg, "You're watching this round.")
end)

test("rate limiter buckets are independent and refill", function()
	local rl = RateLimiter.new(3, 1)
	truthy(rl:allow("p", 0))
	truthy(rl:allow("p", 0))
	truthy(rl:allow("p", 0))
	truthy(not rl:allow("p", 0))
	truthy(rl:allow("p", 1.01))
	truthy(rl:allow("q", 0))
	rl:forget("q")
	truthy(rl:allow("q", 0))
end)

print("HUD")
test("clock text and phone layout stay readable", function()
	eq(ClockFormat.clock(240), "4:00")
	eq(ClockFormat.clock(65), "1:05")
	eq(ClockFormat.clock(5), "0:05")
	eq(ClockFormat.clock(0), "0:00")
	eq(ClockFormat.clock(-1), "--")
	truthy(HudLayout.topWidthScale >= 0.9)
	truthy(HudLayout.bottomWidthScale >= 0.9)
	truthy(HudLayout.minTouchHeight >= 44)
	truthy(HudLayout.padding >= 8)
	truthy(HudLayout.themeText >= HudLayout.phaseText)
	truthy(HudLayout.maxCardWidth >= 320)
end)

print("Safety")
test("source does not call web services", function()
	local function walk(dir: string)
		for _, name in ipairs(fs.readDir(dir)) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				walk(path)
			elseif string.sub(name, -5) == ".luau" then
				local body = fs.readFile(path)
				local lower = string.lower(body)
				truthy(string.find(lower, "httpservice", 1, true) == nil, path)
				truthy(string.find(lower, "requestasync", 1, true) == nil, path)
			end
		end
	end
	walk("src")
end)

test("titles and theme names avoid blocked words", function()
	local blocked = { "cozy", "roblox", "blox", "impress", "eggnog", "bedroom", "bathroom" }
	local function scan(text: string, where: string)
		local lower = string.lower(text)
		for _, word in ipairs(blocked) do
			if string.find(lower, word, 1, true) then
				error(where .. " contains " .. word)
			end
		end
	end
	scan(Config.GameName, "game name")
	scan(Config.SeasonTitle, "season title")
	scan(Config.Critic.name, "critic")
	for _, theme in ipairs(Themes.all()) do
		scan(theme.name, theme.id)
		scan(theme.id, theme.id)
	end
	-- The selene std command is a tool name, not a title. Strip that token, then scan.
	local readme = string.gsub(fs.readFile("README.md"), "generate%-roblox%-std", "")
	scan(readme, "README")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
