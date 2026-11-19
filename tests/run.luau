--!nocheck
-- Round loop, themes, and the action handler. Run with: lune run tests/run.luau
local process = require("@lune/process")
local fs = require("@lune/fs")

local Config = require("../src/shared/Config")
local Themes = require("../src/shared/Themes")
local UIKit = require("../src/shared/UIKit")
local RateLimiter = require("../src/shared/Logic/RateLimiter")
local Season = require("../src/shared/Logic/Season")
local ThemePicker = require("../src/shared/Logic/ThemePicker")
local RoundEngine = require("../src/shared/Logic/RoundEngine")
local Actions = require("../src/shared/Logic/Actions")
local Bases = require("../src/shared/Bases")
local Items = require("../src/shared/Items")
local Plots = require("../src/shared/Logic/Plots")
local Placement = require("../src/shared/Logic/Placement")

local passed, failed = 0, 0
local current = ""

local function test(name, fn)
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

local function eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or current, tostring(b), tostring(a)), 2)
	end
end

local function truthy(v, msg)
	if not v then
		error(msg or (current .. ": expected truthy"), 2)
	end
end

local HOLIDAY_NOON = Season.unix(2026, 12, 15, 18, 0, 0)

local function fresh(config, unixNow)
	return RoundEngine.create({
		config = config or Config,
		themes = Themes,
		rng = function()
			return 0
		end,
		unixNow = unixNow or function()
			return HOLIDAY_NOON
		end,
	})
end

local function themeNamed(id)
	return ThemePicker.find(Themes, id)
end

print("Config")
test("phase timings match the round loop", function()
	eq(Config.Phases.Lobby, 20)
	eq(Config.Phases.ThemeReveal, 5)
	eq(Config.Phases.Build, 240)
	eq(Config.Phases.TourPerRoom, 8)
	eq(Config.Phases.Results, 15)
	eq(#Config.PhaseOrder, 5)
	eq(Config.PhaseOrder[1], "Lobby")
	eq(Config.PhaseOrder[2], "ThemeReveal")
	eq(Config.PhaseOrder[3], "Build")
	eq(Config.PhaseOrder[4], "Tour")
	eq(Config.PhaseOrder[5], "Results")
end)

test("server holds 10 players and solo still starts", function()
	eq(Config.MaxPlayers, 10)
	eq(Config.MinPlayers, 1)
	eq(Config.RecentThemes, 10)
	eq(Config.Critic.name, "Auntie Roch")
	eq(Config.Title, "Room Glow Up")
end)

test("at least 40 themes, unique ids, tagged season and round type", function()
	truthy(#Themes >= 40, "need 40 starter themes, have " .. tostring(#Themes))
	local ids = {}
	local names = {}
	local counts = { holiday = { room = 0, gingerbread = 0, tree = 0 }, winter = { room = 0, gingerbread = 0, tree = 0 } }
	local banned = { "impress", "cozy", "roblox", "blox", "bedroom", "bathroom", "eggnog", "mulled", "wine", "alcohol", "beer", "whiskey", "vodka" }
	for _, theme in ipairs(Themes) do
		truthy(ids[theme.id] == nil, "duplicate id " .. theme.id)
		truthy(names[theme.name] == nil, "duplicate name " .. theme.name)
		ids[theme.id] = true
		names[theme.name] = true
		truthy(theme.season == "holiday" or theme.season == "winter", theme.id)
		truthy(theme.roundType == "room" or theme.roundType == "gingerbread" or theme.roundType == "tree", theme.id)
		counts[theme.season][theme.roundType] += 1
		local blob = string.lower(theme.id .. " " .. theme.name)
		for _, word in ipairs(banned) do
			truthy(string.find(blob, word, 1, true) == nil, theme.name .. " contains " .. word)
		end
	end
	truthy(counts.holiday.room >= 4)
	truthy(counts.holiday.gingerbread >= 4)
	truthy(counts.holiday.tree >= 4)
	truthy(counts.winter.room + counts.winter.tree >= 8)
end)

test("source does not call HttpService or use blocked words", function()
	local banned = { "httpservice", "cozy", "roblox", "blox", "eggnog", "mulled wine", "to impress" }
	local function walk(dir)
		for _, name in ipairs(fs.readDir(dir)) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				walk(path)
			elseif string.sub(name, -5) == ".luau" then
				local text = string.lower(fs.readFile(path))
				for _, word in ipairs(banned) do
					truthy(string.find(text, word, 1, true) == nil, path .. " contains " .. word)
				end
			end
		end
	end
	walk("src")
end)

print("Season")
test("calendar helper round-trips a UTC date", function()
	eq(Season.unix(1970, 1, 1, 0, 0, 0), 0)
	local stamp = Season.unix(2026, 12, 31, 23, 59, 30)
	local parts = Season.parts(stamp, 0)
	eq(parts.year, 2026)
	eq(parts.month, 12)
	eq(parts.day, 31)
	eq(parts.hour, 23)
	eq(parts.min, 59)
	eq(parts.sec, 30)
end)

test("auto season is holiday through Dec 31 and winter after", function()
	local offset = Config.TimezoneOffsetHours
	local nov = Season.unix(2026, 11, 19, 18, 0, 0)
	local nye = Season.unix(2027, 1, 1, 5, 59, 0)
	local newYear = Season.unix(2027, 1, 1, 6, 0, 0)
	local july = Season.unix(2026, 7, 1, 18, 0, 0)
	eq(Season.resolve("auto", nov, offset), "holiday")
	eq(Season.resolve("auto", nye, offset), "holiday")
	eq(Season.resolve("auto", newYear, offset), "winter")
	eq(Season.resolve("auto", july, offset), "winter")
	eq(Season.resolve("holiday", july, offset), "holiday")
	eq(Season.resolve("winter", nov, offset), "winter")
end)

print("Themes")
test("holiday rotation is room, gingerbread, tree", function()
	local history = {}
	local expect = { "room", "gingerbread", "tree", "room", "gingerbread", "tree", "room", "gingerbread", "tree" }
	for i = 0, 8 do
		local theme = ThemePicker.pick(Themes, {
			season = "holiday",
			history = history,
			roundIndex = i,
			roundTypeOrder = Config.RoundTypeOrder,
			recentLimit = Config.RecentThemes,
			rng = function()
				return 0
			end,
		})
		eq(theme.roundType, expect[i + 1])
		eq(theme.season, "holiday")
		table.insert(history, theme.id)
	end
	eq(history[1], "hearth_cocoa")
	eq(history[4], "stocking_mantel")
end)

test("season filter never crosses holiday and winter", function()
	for i = 0, 16 do
		local sample = (i % 5) / 5
		local winter = ThemePicker.pick(Themes, {
			season = "winter",
			history = {},
			roundIndex = i,
			roundTypeOrder = Config.RoundTypeOrder,
			recentLimit = 10,
			rng = function()
				return sample
			end,
		})
		eq(winter.season, "winter")
		local holiday = ThemePicker.pick(Themes, {
			season = "holiday",
			history = {},
			roundIndex = i,
			roundTypeOrder = Config.RoundTypeOrder,
			recentLimit = 10,
			rng = function()
				return sample
			end,
		})
		eq(holiday.season, "holiday")
	end
end)

test("no repeat inside the last 10, older than that can return", function()
	local recentRooms = {
		"hearth_cocoa",
		"stocking_mantel",
		"nutcracker_nook",
		"snow_globe_parlor",
		"ribbon_window",
		"carol_piano",
		"sleigh_entry",
	}
	local theme = ThemePicker.pick(Themes, {
		season = "holiday",
		history = recentRooms,
		roundIndex = 0,
		roundTypeOrder = Config.RoundTypeOrder,
		recentLimit = 10,
		rng = function()
			return 0
		end,
	})
	eq(theme.id, "starlight_nook")

	local allRooms = {
		"hearth_cocoa",
		"stocking_mantel",
		"nutcracker_nook",
		"snow_globe_parlor",
		"ribbon_window",
		"carol_piano",
		"sleigh_entry",
		"starlight_nook",
	}
	local fallback = ThemePicker.pick(Themes, {
		season = "holiday",
		history = allRooms,
		roundIndex = 0,
		roundTypeOrder = Config.RoundTypeOrder,
		recentLimit = 10,
		rng = function()
			return 0
		end,
	})
	eq(fallback.id, "hearth_cocoa")

	local longAgo = { "hearth_cocoa", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }
	local again = ThemePicker.pick(Themes, {
		season = "holiday",
		history = longAgo,
		roundIndex = 0,
		roundTypeOrder = Config.RoundTypeOrder,
		recentLimit = 10,
		rng = function()
			return 0
		end,
	})
	eq(again.id, "hearth_cocoa")
end)

test("host theme is used when it matches the season", function()
	local theme = ThemePicker.pick(Themes, {
		season = "holiday",
		history = { "tinsel_topper" },
		roundIndex = 0,
		roundTypeOrder = Config.RoundTypeOrder,
		recentLimit = 10,
		hostThemeId = "tinsel_topper",
		rng = function()
			return 0
		end,
	})
	eq(theme.id, "tinsel_topper")
	local skipped = ThemePicker.pick(Themes, {
		season = "holiday",
		history = {},
		roundIndex = 0,
		roundTypeOrder = Config.RoundTypeOrder,
		recentLimit = 10,
		hostThemeId = "frosted_fir",
		rng = function()
			return 0
		end,
	})
	eq(skipped.id, "hearth_cocoa")
	eq(ThemePicker.pick(Themes, {
		season = "holiday",
		history = {},
		roundIndex = 0,
		roundTypeOrder = Config.RoundTypeOrder,
		recentLimit = 10,
		hostThemeId = "not-a-theme",
		rng = function()
			return 0
		end,
	}).id, "hearth_cocoa")
end)

print("Rounds")
test("lobby waits until a player arrives", function()
	local state = fresh()
	RoundEngine.advance(state, 10000)
	eq(state.phase, "Lobby")
	eq(state.phaseEndsAt, nil)
	eq(RoundEngine.timeLeft(state, 10000), 20)
	RoundEngine.join(state, "mike", 10000)
	eq(state.phaseEndsAt, 10020)
	RoundEngine.advance(state, 10019)
	eq(state.phase, "Lobby")
	RoundEngine.advance(state, 10020)
	eq(state.phase, "ThemeReveal")
end)

test("every phase runs, then the next lobby starts", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 20)
	eq(state.phase, "ThemeReveal")
	eq(state.theme.id, "hearth_cocoa")
	eq(state.theme.roundType, "room")
	RoundEngine.advance(state, 25)
	eq(state.phase, "Build")
	local ok, msg = RoundEngine.pressDone(state, "mike", 25)
	eq(ok, true)
	eq(msg, "Locked in.")
	eq(state.phase, "Tour")
	eq(#state.tourStops, 1)
	eq(RoundEngine.timeLeft(state, 25), 8)
	eq(RoundEngine.snapshot(state, 25).tourLabel, "Room 1 of 1")
	RoundEngine.advance(state, 32)
	eq(state.phase, "Tour")
	RoundEngine.advance(state, 33)
	eq(state.phase, "Results")
	eq(state.history[1], "hearth_cocoa")
	RoundEngine.advance(state, 48)
	eq(state.phase, "Lobby")
	eq(state.roundIndex, 1)
	local seen = {}
	for _, entry in ipairs(state.trace) do
		table.insert(seen, entry.phase)
	end
	eq(table.concat(seen, ","), "Lobby,ThemeReveal,Build,Tour,Results,Lobby")
end)

test("build uses the full timer when someone has not pressed DONE", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.advance(state, 25)
	eq(state.phase, "Build")
	RoundEngine.pressDone(state, "mike", 30)
	eq(state.phase, "Build")
	RoundEngine.advance(state, 264)
	eq(state.phase, "Build")
	RoundEngine.advance(state, 265)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 1)
	eq(state.tourStops[1], "mike")
	eq(RoundEngine.timeLeft(state, 265), 8)
end)

test("build ends early when every active player has pressed DONE", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 30)
	eq(state.phase, "Build")
	RoundEngine.pressDone(state, "sam", 40)
	eq(state.phase, "Tour")
	eq(state.phaseEndsAt, 56)
	eq(state.tourStops[1], "mike")
	eq(state.tourStops[2], "sam")
	local again = RoundEngine.pressDone(state, "mike", 41)
	eq(again, false)
end)

test("a round with no DONE still passes through Tour", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 265)
	eq(state.phase, "Results")
	local tourAt, resultsAt = nil, nil
	for _, entry in ipairs(state.trace) do
		if entry.phase == "Tour" then
			tourAt = entry.at
		elseif entry.phase == "Results" then
			resultsAt = entry.at
		end
	end
	eq(tourAt, 265)
	eq(resultsAt, 265)
	eq(state.history[1], "hearth_cocoa")
end)

test("phase lengths come from Config", function()
	local custom = table.clone(Config)
	custom.Phases = table.clone(Config.Phases)
	custom.Phases.Lobby = 1
	custom.Phases.ThemeReveal = 1
	custom.Phases.Build = 5
	custom.Phases.TourPerRoom = 2
	custom.Phases.Results = 3
	local state = fresh(custom)
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 1)
	eq(state.phase, "ThemeReveal")
	RoundEngine.advance(state, 2)
	eq(state.phase, "Build")
	RoundEngine.pressDone(state, "mike", 2)
	eq(state.phase, "Tour")
	eq(RoundEngine.timeLeft(state, 2), 2)
	RoundEngine.advance(state, 4)
	eq(state.phase, "Results")
	RoundEngine.advance(state, 7)
	eq(state.phase, "Lobby")
end)

test("joining mid-round spectates, then plays the next lobby", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 25)
	eq(state.phase, "Build")
	RoundEngine.join(state, "lee", 26)
	local view = RoundEngine.playerView(state, "lee")
	eq(view.spectating, true)
	local denied = RoundEngine.pressDone(state, "lee", 27)
	eq(denied, false)
	local ok = RoundEngine.pressDone(state, "mike", 28)
	eq(ok, true)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 1)
	eq(state.tourStops[1], "mike")
	RoundEngine.advance(state, 28 + 8 + 15)
	eq(state.phase, "Lobby")
	eq(RoundEngine.playerView(state, "lee").spectating, false)
	eq(state.players.lee.role, "active")
	RoundEngine.advance(state, 28 + 8 + 15 + 20)
	eq(state.phase, "ThemeReveal")
	RoundEngine.advance(state, 28 + 8 + 15 + 20 + 5)
	eq(state.phase, "Build")
	local played = RoundEngine.pressDone(state, "lee", 76)
	eq(played, true)
end)

test("leaving mid-round skips that room", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 30)
	RoundEngine.leave(state, "sam", 31)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 1)
	eq(state.tourStops[1], "mike")
	eq(state.players.sam, nil)
end)

test("leaving during your tour segment skips the rest of it", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 30)
	RoundEngine.pressDone(state, "sam", 31)
	eq(state.phase, "Tour")
	eq(state.phaseEndsAt, 47)
	RoundEngine.leave(state, "mike", 33)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 1)
	eq(state.tourStops[1], "sam")
	eq(state.phaseEndsAt, 41)
	RoundEngine.advance(state, 41)
	eq(state.phase, "Results")
end)

test("leaving before your tour stop drops that stop only", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 30)
	RoundEngine.pressDone(state, "sam", 31)
	RoundEngine.leave(state, "sam", 32)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 1)
	eq(state.tourStops[1], "mike")
	eq(state.phaseEndsAt, 39)
end)

test("the tour moves to the next room every TourPerRoom seconds", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.join(state, "lee", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 30)
	RoundEngine.pressDone(state, "sam", 31)
	RoundEngine.pressDone(state, "lee", 32)
	eq(state.phase, "Tour")
	eq(state.tourIndex, 1)
	eq(RoundEngine.snapshot(state, 32).tourLabel, "Room 1 of 3")
	eq(RoundEngine.snapshot(state, 32).tourIndex, 1)
	eq(RoundEngine.snapshot(state, 32).tourTarget, "mike")
	eq(state.phaseEndsAt, 56)
	RoundEngine.advance(state, 39)
	eq(state.phase, "Tour")
	eq(state.tourIndex, 1)
	eq(RoundEngine.snapshot(state, 39).tourLabel, "Room 1 of 3")
	RoundEngine.advance(state, 40)
	eq(state.phase, "Tour")
	eq(state.tourIndex, 2)
	eq(state.tourStops[state.tourIndex], "sam")
	eq(RoundEngine.snapshot(state, 40).tourLabel, "Room 2 of 3")
	eq(RoundEngine.snapshot(state, 40).tourIndex, 2)
	eq(RoundEngine.snapshot(state, 40).tourTarget, "sam")
	eq(state.phaseEndsAt, 56)
	RoundEngine.advance(state, 48)
	eq(state.tourIndex, 3)
	eq(RoundEngine.snapshot(state, 48).tourLabel, "Room 3 of 3")
	RoundEngine.advance(state, 55)
	eq(state.phase, "Tour")
	RoundEngine.advance(state, 56)
	eq(state.phase, "Results")
end)

test("a late tour tick still lands on the scheduled room", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.join(state, "lee", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 30)
	RoundEngine.pressDone(state, "sam", 31)
	RoundEngine.pressDone(state, "lee", 32)
	-- Jump from the start of the tour to the middle of room 3.
	RoundEngine.advance(state, 50)
	eq(state.phase, "Tour")
	eq(state.tourIndex, 3)
	eq(state.tourStops[state.tourIndex], "lee")
	eq(RoundEngine.snapshot(state, 50).tourLabel, "Room 3 of 3")
	eq(RoundEngine.timeLeft(state, 50), 6)
	RoundEngine.advance(state, 56)
	eq(state.phase, "Results")
	eq(state.phaseStartedAt, 56)
end)

test("build ends right away if every active player already left", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 20)
	eq(state.phase, "ThemeReveal")
	RoundEngine.leave(state, "mike", 21)
	RoundEngine.advance(state, 25)
	eq(state.phase, "Results")
	local buildAt, tourAt, resultsAt = nil, nil, nil
	for _, entry in ipairs(state.trace) do
		if entry.phase == "Build" then
			buildAt = entry.at
		elseif entry.phase == "Tour" then
			tourAt = entry.at
		elseif entry.phase == "Results" then
			resultsAt = entry.at
		end
	end
	eq(buildAt, 25)
	eq(tourAt, 25)
	eq(resultsAt, 25)
end)

test("a full round works with 1, 3, and 10 players", function()
	local function play(count, allDone)
		local state = fresh()
		local ids = {}
		for i = 1, count do
			local id = "p" .. tostring(i)
			table.insert(ids, id)
			RoundEngine.join(state, id, 0)
		end
		eq(state.phase, "Lobby")
		RoundEngine.advance(state, 20)
		eq(state.phase, "ThemeReveal")
		eq(state.theme ~= nil, true)
		RoundEngine.advance(state, 25)
		eq(state.phase, "Build")
		if allDone then
			for i, id in ipairs(ids) do
				local ok = RoundEngine.pressDone(state, id, 25 + i)
				eq(ok, true)
			end
			local tourStart = 25 + count
			eq(state.phase, "Tour")
			eq(#state.tourStops, count)
			for i = 1, count do
				local at = tourStart + (i - 1) * 8
				RoundEngine.advance(state, at)
				eq(state.phase, "Tour")
				eq(state.tourIndex, i)
				eq(RoundEngine.snapshot(state, at).tourLabel, string.format("Room %d of %d", i, count))
			end
			local tourEnd = tourStart + count * 8
			RoundEngine.advance(state, tourEnd)
			eq(state.phase, "Results")
			RoundEngine.advance(state, tourEnd + 15)
			eq(state.phase, "Lobby")
			eq(state.roundIndex, 1)
		else
			-- Solo player never presses DONE; the full build timer is used.
			RoundEngine.advance(state, 264)
			eq(state.phase, "Build")
			RoundEngine.advance(state, 265)
			eq(state.phase, "Results")
			eq(#state.tourStops, 0)
			RoundEngine.advance(state, 280)
			eq(state.phase, "Lobby")
		end
		return state
	end

	play(1, true)
	play(1, false)
	play(3, true)
	local ten = play(10, true)
	eq(ten.players["p10"].role, "active")
	-- Mid-round joiner on a fresh 10-player server spectates and is ignored by DONE.
	local busy = fresh()
	for i = 1, 10 do
		RoundEngine.join(busy, "p" .. tostring(i), 0)
	end
	RoundEngine.advance(busy, 25)
	RoundEngine.join(busy, "late", 26)
	eq(RoundEngine.playerView(busy, "late").spectating, true)
	eq(RoundEngine.pressDone(busy, "late", 27), false)
	for i = 1, 10 do
		RoundEngine.pressDone(busy, "p" .. tostring(i), 30)
	end
	eq(busy.phase, "Tour")
	eq(#busy.tourStops, 10)
end)

test("an empty lobby timer resets when the last player leaves", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 10)
	eq(state.phase, "Lobby")
	RoundEngine.leave(state, "mike", 10)
	eq(state.phaseEndsAt, nil)
	RoundEngine.advance(state, 500)
	eq(state.phase, "Lobby")
	RoundEngine.join(state, "mike", 500)
	eq(state.phaseEndsAt, 520)
	RoundEngine.join(state, "mike", 501)
	eq(state.phaseEndsAt, 520)
end)

test("the next holiday round rotates type and keeps the last 10", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 25)
	RoundEngine.advance(state, 48)
	eq(state.phase, "Lobby")
	RoundEngine.advance(state, 68)
	eq(state.phase, "ThemeReveal")
	eq(state.theme.roundType, "gingerbread")
	eq(state.theme.id, "gumdrop_gable")
	eq(#state.history, 1)
end)

test("host theme applies on the next reveal, then rotation resumes", function()
	local state = fresh()
	local unknownOk = RoundEngine.setHostTheme(state, "nope")
	eq(unknownOk, false)
	local setOk = RoundEngine.setHostTheme(state, "paper_star")
	eq(setOk, true)
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 20)
	eq(state.theme.id, "paper_star")
	eq(state.hostThemeId, nil)
	RoundEngine.advance(state, 25)
	local during = RoundEngine.setHostTheme(state, "bell_branch")
	eq(during, true)
	eq(state.theme.id, "paper_star")
	RoundEngine.pressDone(state, "mike", 25)
	RoundEngine.advance(state, 48)
	RoundEngine.advance(state, 68)
	eq(state.theme.id, "bell_branch")
end)

test("auto season flips to winter after Dec 31", function()
	local nye = Season.unix(2027, 1, 1, 5, 59, 0)
	local state = fresh(nil, function()
		return nye
	end)
	eq(state.season, "holiday")
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 20)
	eq(state.theme.season, "holiday")
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 25)
	RoundEngine.advance(state, 48)
	RoundEngine.setUnixNow(state, function()
		return Season.unix(2027, 1, 1, 6, 0, 0)
	end)
	RoundEngine.advance(state, 68)
	eq(state.phase, "ThemeReveal")
	eq(state.theme.season, "winter")
	eq(state.season, "winter")
end)

print("Actions")
test("rate limiter allows a burst, then refills", function()
	local rl = RateLimiter.new(3, 1)
	truthy(rl:allow("p", 0))
	truthy(rl:allow("p", 0))
	truthy(rl:allow("p", 0))
	truthy(not rl:allow("p", 0))
	truthy(rl:allow("p", 1.01))
	truthy(rl:allow("q", 0))
	rl:forget("p")
	truthy(rl:allow("p", 1.01))
	truthy(rl:allow("p", 1.01))
	truthy(rl:allow("p", 1.01))
end)

test("action handler rejects bad client input and limits repeats", function()
	local api = Actions.create({
		globalBurst = 20,
		globalRefill = 5,
		actionBurst = 2,
		actionRefill = 1,
		nameMax = 24,
	})
	api.register("Ping", {}, function()
		return true, "hi"
	end)
	api.register("Echo", { "string" }, function(_key, args)
		return true, args[1]
	end)
	local ok, msg = api.handle("p", "Ping", {}, 0)
	eq(ok, true)
	eq(msg, "hi")
	local second = api.handle("p", "Ping", {}, 0)
	eq(second, true)
	local limited, why = api.handle("p", "Ping", {}, 0)
	eq(limited, false)
	eq(why, "Slow down a moment.")
	local badType = api.handle("p", 12, {}, 1)
	eq(badType, false)
	local unknown, unknownMsg = api.handle("p", "Nope", {}, 1)
	eq(unknown, false)
	eq(unknownMsg, "Unknown action.")
	local missingArg = api.handle("p", "Echo", {}, 3)
	eq(missingArg, false)
	local wrongType = api.handle("p", "Echo", { 5 }, 4)
	eq(wrongType, false)
	local extraKey = api.handle("p", "Echo", { note = "x" }, 5)
	eq(extraKey, false)
	local badName = api.handle("p", "Bad Name", {}, 6)
	eq(badName, false)
	local echoed, text = api.handle("p", "Echo", { "hello" }, 7)
	eq(echoed, true)
	eq(text, "hello")
end)

test("a nested action from the same player is refused", function()
	local api = Actions.create({
		globalBurst = 8,
		globalRefill = 4,
		actionBurst = 4,
		actionRefill = 2,
		nameMax = 24,
	})
	api.register("Nest", {}, function(key)
		return api.handle(key, "Nest", {}, 0)
	end)
	local ok, msg = api.handle("p", "Nest", {}, 3)
	eq(ok, false)
	eq(msg, "Slow down a moment.")
end)

test("DONE goes through the handler and still obeys the round", function()
	local state = fresh()
	local now = 0
	local api = Actions.create({
		globalBurst = 10,
		globalRefill = 5,
		actionBurst = 4,
		actionRefill = 2,
		nameMax = Config.RateLimit.nameMax,
	})
	api.register("Done", {}, function(key)
		return RoundEngine.pressDone(state, key, now)
	end)
	RoundEngine.join(state, "mike", 0)
	local early = api.handle("mike", "Done", {}, 0)
	eq(early, false)
	RoundEngine.advance(state, 25)
	now = 30
	RoundEngine.join(state, "lee", 26)
	local peek = api.handle("lee", "Done", {}, now)
	eq(peek, false)
	local did, note = api.handle("mike", "Done", {}, now)
	eq(did, true)
	eq(note, "Locked in.")
	eq(state.phase, "Tour")
	eq(state.tourStops[1], "mike")
end)

print("UI kit")
test("palette, type, and buttons stay readable on a phone", function()
	local names = { "cream", "coral", "mint", "butter", "lavender" }
	for _, name in ipairs(names) do
		local ratio = UIKit.contrast(UIKit.Palette.ink, UIKit.Palette[name])
		truthy(ratio >= 4.5, name .. " contrast " .. tostring(ratio))
	end
	eq(UIKit.Buttons.primary.fill, "coral")
	eq(UIKit.Buttons.primary.text, "ink")
	eq(UIKit.Buttons.quiet.fill, "lavender")
	truthy(UIKit.Buttons.primary.height >= 48)
	truthy(UIKit.Buttons.primary.height >= UIKit.Layout.minButton)
	truthy(UIKit.Text.countdown >= 48)
	truthy(UIKit.Text.countdownMin >= 24)
	truthy(UIKit.Shape.corner >= 16)
	truthy(UIKit.Shape.cornerChunky >= UIKit.Shape.corner)
	truthy(UIKit.Layout.bottom >= 12)
	for _, phase in ipairs(Config.PhaseOrder) do
		truthy(UIKit.Palette[UIKit.PhaseFill[phase]] ~= nil, phase)
	end
	truthy(UIKit.Motion.phase.from < UIKit.Motion.phase.to)
	truthy(UIKit.Motion.reveal.time > 0)
	truthy(UIKit.Motion.reveal.from < 1)
	eq(themeNamed("hearth_cocoa").name, "Cocoa Hearth")
end)

print("Plots")
test("ten plots are assigned on join and freed for the next player", function()
	local state = Plots.create(Config.Plots)
	eq(Config.Plots, 10)
	local ids = {}
	for i = 1, 10 do
		local id = "p" .. tostring(i)
		table.insert(ids, id)
		eq(Plots.assign(state, id), i)
		eq(Plots.assign(state, id), i)
		eq(Plots.plotOf(state, id), i)
		eq(Plots.owner(state, i), id)
	end
	eq(Plots.assign(state, "extra"), nil)
	eq(Plots.release(state, "p3"), 3)
	eq(Plots.plotOf(state, "p3"), nil)
	eq(Plots.owner(state, 3), nil)
	eq(Plots.assign(state, "extra"), 3)
	eq(Plots.release(state, "nobody"), nil)
	eq(Plots.owner(state, 1), "p1")
	local seen = {}
	for i = 1, 10 do
		local x, y, z = Bases.plotOrigin(i)
		eq(y, 0)
		local key = string.format("%.3f:%.3f", x, z)
		truthy(seen[key] == nil, "plots overlap")
		seen[key] = true
	end
	local x1, _, z1 = Bases.plotOrigin(1)
	local x2, _, z2 = Bases.plotOrigin(2)
	truthy(math.abs((x2 - x1) - Bases.Spacing) < 1e-6)
	eq(z1, z2)
	local _, _, z6 = Bases.plotOrigin(6)
	truthy(math.abs((z6 - z1) - Bases.Spacing) < 1e-6)
end)

print("Library")
test("120 props, theme tags, and no banned words", function()
	eq(#Items.list, 120)
	eq(Config.ItemScale, 1.2)
	truthy(math.abs(Bases.worldCell() - Config.Cell * Config.ItemScale) < 1e-6)
	local ids = {}
	local names = {}
	local themes = {}
	for _, theme in ipairs(Themes) do
		themes[theme.id] = 0
	end
	local rounds = { room = true, gingerbread = true, tree = true }
	local banned = {
		"impress",
		"cozy",
		"roblox",
		"blox",
		"bedroom",
		"bathroom",
		"eggnog",
		"mulled",
		"wine",
		"alcohol",
		"beer",
		"whiskey",
		"vodka",
		"to impress",
	}
	local surfaces = { floor = true, wall = true, roof = true, hook = true }
	local counts = { room = 0, gingerbread = 0, tree = 0 }
	for _, item in ipairs(Items.list) do
		truthy(ids[item.id] == nil, "duplicate id " .. item.id)
		truthy(names[item.name] == nil, "duplicate name " .. item.name)
		ids[item.id] = true
		names[item.name] = true
		truthy(rounds[item.roundType] == true, item.id)
		truthy(item.tags[1] == item.roundType, item.id)
		truthy(surfaces[item.surface] == true, item.id)
		truthy(item.cost >= 4 and item.cost <= 20, item.name)
		truthy(item.w >= 1 and item.d >= 1, item.name)
		local knownColor = false
		for _, color in ipairs(Config.Palette) do
			if color == item.color then
				knownColor = true
			end
		end
		truthy(knownColor, item.name)
		if item.roundType == "room" then
			truthy(item.surface == "floor" or item.surface == "wall", item.id)
		elseif item.roundType == "gingerbread" then
			truthy(item.surface == "wall" or item.surface == "roof", item.id)
		else
			eq(item.surface, "hook")
		end
		counts[item.roundType] += 1
		local blob = string.lower(item.id .. " " .. item.name .. " " .. item.category .. " " .. table.concat(item.tags, " "))
		for _, word in ipairs(banned) do
			truthy(string.find(blob, word, 1, true) == nil, item.name .. " contains " .. word)
		end
		for index, tag in ipairs(item.tags) do
			if index == 1 then
				truthy(rounds[tag] == true, tag)
			else
				truthy(themes[tag] ~= nil, item.id .. " " .. tag)
				themes[tag] += 1
			end
		end
	end
	eq(counts.room + counts.gingerbread + counts.tree, 120)
	truthy(counts.room >= 40)
	truthy(counts.gingerbread >= 16)
	truthy(counts.tree >= 16)
	for id, count in pairs(themes) do
		truthy(count >= 2, id .. " tagged " .. tostring(count))
	end
	truthy(#Items.categories() >= 8)
	eq(#Bases.hooks(), 12)
end)

local function catalog()
	return {
		get = function(id)
			return Items.get(id)
		end,
	}
end

local function placeCtx(overrides)
	local ctx = {
		catalog = catalog(),
		roundType = "room",
		themeId = "hearth_cocoa",
		budget = Config.Budget,
		maxItems = Config.MaxItems,
		role = "active",
		phase = "Build",
		locked = false,
		matchExact = Config.MatchExact,
		matchFamily = Config.MatchFamily,
		matchCap = Config.MatchCap,
		palette = Config.Palette,
		now = 50,
		undoCap = Config.UndoCap,
	}
	if overrides then
		for key, value in pairs(overrides) do
			ctx[key] = value
		end
	end
	return ctx
end

print("Placement")
test("grid, hooks, overlap, and rotation are checked", function()
	local room = Placement.empty()
	local ctx = placeCtx()
	local ok, msg = Placement.place(room, ctx, "nope", 0, 0)
	eq(ok, false)
	eq(msg, "Unknown item.")
	local fractional = Placement.place(room, ctx, "cocoa_mug", 0.5, 0)
	eq(fractional, false)
	local outside = Placement.place(room, ctx, "cocoa_mug", 6, 0)
	eq(outside, false)
	eq(Placement.place(room, ctx, "butter_bench", 0, 0), true)
	eq(Placement.place(room, ctx, "butter_bench", 1, 0), false)
	local edge = Placement.empty()
	eq(Placement.place(edge, ctx, "butter_bench", 4, 5), true)
	local turned, turnMsg = Placement.rotate(edge, ctx, 1)
	eq(turned, false)
	eq(turnMsg, "It cannot turn there.")
	eq(edge.pieces[1].rot, 0)
	eq(Placement.rotate(room, ctx, 1), true)
	eq(room.pieces[1].rot, 1)
	local rug = Placement.empty()
	eq(Placement.place(rug, ctx, "hearth_rug", 0, 0), true)
	eq(Placement.place(rug, ctx, "coral_armchair", 0, 0), true)
	eq(Placement.place(rug, ctx, "hearth_rug", 1, 1), false)
	eq(Placement.place(rug, ctx, "coral_armchair", 0, 0), false)
	local house = placeCtx({ roundType = "gingerbread", themeId = "gumdrop_gable" })
	local candy = Placement.empty()
	eq(Placement.place(candy, house, "gumdrop", 0, 0), true)
	eq(Placement.place(candy, house, "gumdrop", 0.25, 1), false)
	eq(Placement.place(candy, house, "butter_bench", 0, 1), false)
	local tree = placeCtx({ roundType = "tree", themeId = "bauble_burst" })
	local ornaments = Placement.empty()
	eq(Placement.place(ornaments, tree, "butter_bauble", 1, 0), true)
	eq(Placement.place(ornaments, tree, "coral_bauble", 1, 0), false)
	eq(Placement.place(ornaments, tree, "coral_bauble", 13, 0), false)
	eq(Placement.place(ornaments, tree, "coral_bauble", 2, 1), false)
	eq(Placement.place(ornaments, tree, "cocoa_mug", 2, 0), false)
	eq(Placement.place(room, ctx, "butter_bauble", 1, 0), false)
	local hook = Bases.hooks()[3]
	eq(Bases.nearestHook(hook.x, hook.y, hook.z), 3)
	eq(Bases.nearestHook(0, 0, 0), nil)
	local floor = Bases.grid("room", "floor")
	local lx0, _, lz0 = Bases.tileCenter("room", "floor", 0, 0)
	local lx1, _, _lz1 = Bases.tileCenter("room", "floor", 1, 0)
	truthy(math.abs((lx1 - lx0) - Bases.worldCell()) < 1e-6)
	local back = math.floor(lx0 / Bases.worldCell() + floor.x / 2)
	local depth = math.floor(lz0 / Bases.worldCell() + floor.z / 2)
	eq(back, 0)
	eq(depth, 0)
end)

test("budget, meter, undo, and recolor stay on the server numbers", function()
	local room = Placement.empty()
	local ctx = placeCtx({ budget = 12 })
	eq(Placement.place(room, ctx, "butter_bench", 0, 0), true)
	eq(Placement.coinsLeft(room, 12), 0)
	eq(Placement.meter(room, ctx), Config.MatchExact)
	eq(Placement.place(room, ctx, "cocoa_mug", 3, 0), false)
	eq(room.spent, 12)
	eq(Placement.delete(room, ctx, 1), true)
	eq(Placement.coinsLeft(room, 12), 12)
	eq(Placement.meter(room, ctx), 0)
	eq(Placement.place(room, ctx, "cocoa_mug", 0, 0), true)
	eq(Placement.place(room, ctx, "gift_stack", 1, 0), false)
	local rich = placeCtx({ budget = 400 })
	local decorated = Placement.empty()
	eq(Placement.place(decorated, rich, "cocoa_mug", 0, 0), true)
	eq(Placement.meter(decorated, rich), Config.MatchExact)
	eq(Placement.place(decorated, rich, "gift_stack", 1, 0), true)
	eq(Placement.meter(decorated, rich), Config.MatchExact + Config.MatchFamily)
	for i = 1, 8 do
		eq(Placement.place(decorated, rich, "cocoa_mug", (i + 1) % 6, 1 + math.floor(i / 6)), true)
	end
	eq(Placement.meter(decorated, rich), Config.MatchCap)
	local tint = Placement.empty()
	eq(Placement.place(tint, rich, "cocoa_mug", 0, 0), true)
	eq(Placement.recolor(tint, rich, 1, "gold"), false)
	eq(tint.pieces[1].color, "butter")
	eq(Placement.recolor(tint, rich, 1, "mint"), true)
	eq(tint.pieces[1].color, "mint")
	eq(Placement.meter(tint, rich), Config.MatchExact)
	local steps = Placement.empty()
	eq(Placement.place(steps, rich, "cocoa_mug", 2, 2), true)
	eq(Placement.undo(steps, rich), true)
	eq(#steps.pieces, 0)
	eq(Placement.coinsLeft(steps, rich.budget), rich.budget)
	eq(Placement.place(steps, rich, "cocoa_mug", 2, 2), true)
	eq(Placement.delete(steps, rich, 2), true)
	eq(Placement.undo(steps, rich), true)
	eq(#steps.pieces, 1)
	eq(Placement.undo(steps, rich), true)
	eq(Placement.undo(steps, rich), false)
end)

test("spectators cannot place, spend, or move the meter", function()
	local room = Placement.empty()
	local ctx = placeCtx()
	eq(Placement.place(room, ctx, "cocoa_mug", 0, 0), true)
	local spent = room.spent
	local score = Placement.meter(room, ctx)
	ctx.role = "spectator"
	eq(Placement.place(room, ctx, "cocoa_mug", 1, 0), false)
	eq(Placement.rotate(room, ctx, 1), false)
	eq(Placement.recolor(room, ctx, 1, "coral"), false)
	eq(Placement.delete(room, ctx, 1), false)
	eq(Placement.undo(room, ctx), false)
	eq(room.spent, spent)
	eq(#room.pieces, 1)
	eq(Placement.meter(room, ctx), score)
	eq(room.pieces[1].color, "butter")
end)

test("a room stops at the item cap", function()
	local ctx = placeCtx({ budget = 1000, maxItems = 2 })
	local room = Placement.empty()
	eq(Placement.place(room, ctx, "cocoa_mug", 0, 0), true)
	eq(Placement.place(room, ctx, "cocoa_mug", 1, 0), true)
	local full, why = Placement.place(room, ctx, "cocoa_mug", 2, 0)
	eq(full, false)
	eq(why, "This room is full.")
	local rooms = {}
	for _ = 1, 10 do
		local one = Placement.empty()
		local wide = placeCtx({ budget = 1000 })
		for i = 1, Config.MaxItems do
			local x = (i - 1) % 6
			local z = math.floor((i - 1) / 6)
			eq(Placement.place(one, wide, "cocoa_mug", x, z), true)
		end
		eq(Placement.place(one, wide, "star_mat", 5, 5), false)
		table.insert(rooms, one)
	end
	eq(#rooms, 10)
	eq(Config.MaxItems, 16)
	eq(Config.Budget, 96)
end)

print("Auto submit")
test("build end submits every active room that has props", function()
	local state = fresh()
	RoundEngine.join(state, "ada", 0)
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.join(state, "lee", 0)
	RoundEngine.setHasWork(state, function(id)
		return id == "sam" or id == "lee"
	end)
	RoundEngine.advance(state, 25)
	eq(state.phase, "Build")
	eq(RoundEngine.snapshot(state, 30).tourIndex, 0)
	eq(RoundEngine.snapshot(state, 30).tourTarget, "")
	eq(RoundEngine.pressDone(state, "mike", 30), true)
	eq(state.phase, "Build")
	RoundEngine.advance(state, 265)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 3)
	eq(state.tourStops[1], "mike")
	eq(state.tourStops[2], "lee")
	eq(state.tourStops[3], "sam")
	eq(RoundEngine.snapshot(state, 265).tourTarget, "mike")
	eq(RoundEngine.snapshot(state, 265).tourLabel, "Room 1 of 3")
end)

test("a spectator with props still cannot be submitted", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.join(state, "lee", 26)
	eq(RoundEngine.playerView(state, "lee").spectating, true)
	RoundEngine.setHasWork(state, function()
		return true
	end)
	RoundEngine.advance(state, 265)
	eq(#state.tourStops, 1)
	eq(state.tourStops[1], "mike")
	eq(RoundEngine.playerView(state, "lee").spectating, true)
end)

test("a broken prop check does not stop the round", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.setHasWork(state, function()
		error("nope")
	end)
	RoundEngine.advance(state, 265)
	eq(state.phase, "Results")
	eq(#state.tourStops, 0)
end)

print("Rate limit")
test("Place has its own wider bucket on the action remote", function()
	eq(Config.RateLimit.placeBurst > Config.RateLimit.actionBurst, true)
	eq(Config.RateLimit.placeRefill > Config.RateLimit.actionRefill, true)
	local api = Actions.create({
		globalBurst = Config.RateLimit.globalBurst,
		globalRefill = Config.RateLimit.globalRefill,
		actionBurst = Config.RateLimit.actionBurst,
		actionRefill = Config.RateLimit.actionRefill,
		nameMax = Config.RateLimit.nameMax,
		overrides = {
			Place = { burst = Config.RateLimit.placeBurst, refill = Config.RateLimit.placeRefill },
		},
	})
	api.register("Ping", {}, function()
		return true, "ok"
	end)
	api.register("Place", { "string", "number", "number" }, function()
		return true, "Placed."
	end)
	for _ = 1, Config.RateLimit.actionBurst do
		eq(api.handle("p", "Ping", {}, 0), true)
	end
	local limited, why = api.handle("p", "Ping", {}, 0)
	eq(limited, false)
	eq(why, "Slow down a moment.")
	eq(api.handle("p", "Place", { "cocoa_mug", 0, 0 }, 0), true)
	api.forget("p")
	for _ = 1, Config.RateLimit.placeBurst do
		eq(api.handle("p", "Place", { "cocoa_mug", 1, 1 }, 5), true)
	end
	eq(api.handle("p", "Place", { "cocoa_mug", 1, 1 }, 5), false)
	eq(api.handle("p", "Place", { "cocoa_mug", 1, 1 }, 6), true)
	eq(api.handle("q", "Draw", {}, 0), false)
end)

print("HUD fit")
test("tray, meter, and budget stay clear of the board, reveal, and DONE", function()
	local function gap(a, b)
		return b.top - a.bottom
	end
	local heights = { 420, 480, 500, 519, 520, 600, 640, 679, 680, 800, 900 }
	for _, height in ipairs(heights) do
		local bands = UIKit.bands(height)
		local order = { bands.board, bands.reveal, bands.meter, bands.tray, bands.done }
		for _, band in ipairs(order) do
			truthy(band.bottom > band.top, tostring(height))
			truthy(band.top >= 0, tostring(height))
			truthy(band.bottom <= height, tostring(height))
		end
		truthy(gap(bands.board, bands.reveal) >= 4, "board " .. tostring(height))
		truthy(gap(bands.reveal, bands.meter) >= 4, "reveal " .. tostring(height))
		truthy(gap(bands.meter, bands.tray) >= 4, "meter " .. tostring(height))
		truthy(gap(bands.tray, bands.done) >= 4, "tray " .. tostring(height))
		eq(bands.done.bottom, height - UIKit.Layout.bottom)
		truthy(bands.done.bottom - bands.done.top >= UIKit.Layout.minButton, tostring(height))
	end
	local hud = fs.readFile("src/client/Hud.luau")
	local tray = fs.readFile("src/client/Tray.luau")
	truthy(string.find(hud, "UIKit.bands", 1, true) ~= nil)
	truthy(string.find(tray, "UIKit.bands", 1, true) ~= nil)
	truthy(string.find(tray, "Theme Match", 1, true) ~= nil)
	truthy(string.find(tray, "coins", 1, true) ~= nil)
end)

test("placement input and the tour camera follow the server", function()
	local place = fs.readFile("src/client/Place.luau")
	truthy(string.find(place, "Touch", 1, true) ~= nil)
	truthy(string.find(place, "MouseButton1", 1, true) ~= nil)
	truthy(string.find(place, "KeyCode", 1, true) ~= nil)
	truthy(string.find(place, "ButtonA", 1, true) ~= nil)
	truthy(string.find(place, "Thumbstick1", 1, true) ~= nil)
	local tour = fs.readFile("src/client/TourCam.luau")
	truthy(string.find(tour, "TourIndex", 1, true) ~= nil)
	truthy(string.find(tour, "TourLabel", 1, true) ~= nil)
	truthy(string.find(tour, "TourPlot", 1, true) ~= nil)
	truthy(string.find(tour, "task.wait", 1, true) == nil)
	truthy(string.find(tour, "task.delay", 1, true) == nil)
	truthy(string.find(string.lower(tour), "tourperroom", 1, true) == nil)
	local juice = fs.readFile("src/client/Juice.luau")
	truthy(string.find(juice, "TweenService", 1, true) ~= nil)
	truthy(string.find(juice, "ParticleEmitter", 1, true) ~= nil)
	truthy(string.find(juice, "Sound", 1, true) ~= nil)
	local function walk(dir)
		for _, name in ipairs(fs.readDir(dir)) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				walk(path)
			elseif string.sub(name, -5) == ".luau" then
				local text = fs.readFile(path)
				truthy(string.find(text, 'register("Draw"', 1, true) == nil, path)
				truthy(string.find(text, 'register("Paint"', 1, true) == nil, path)
			end
		end
	end
	walk("src")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
