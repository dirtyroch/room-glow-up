--!nocheck
-- Round loop, themes, placement, and voting. Run with: lune run tests/run.luau
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
local Crates = require("../src/shared/Logic/Crates")
local Shop = require("../src/shared/Logic/Shop")
local Codes = require("../src/shared/Logic/Codes")
local Host = require("../src/shared/Logic/Host")
local Hints = require("../src/shared/Logic/Hints")
local ShopSync = require("../scripts/lib/ShopSync")
local Save = require("../src/shared/Logic/Save")
local Levels = require("../src/shared/Logic/Levels")
local Rewards = require("../src/shared/Logic/Rewards")
local Dream = require("../src/shared/Logic/Dream")
local Duo = require("../src/shared/Logic/Duo")
local Quests = require("../src/shared/Logic/Quests")
local Collections = require("../src/shared/Logic/Collections")
local Rank = require("../src/shared/Logic/Rank")
local Monetization = require("../src/shared/Logic/Monetization")
local Voting = require("../src/shared/Logic/Voting")
local Tutorial = require("../src/shared/Logic/Tutorial")
local Modifiers = require("../src/shared/Logic/Modifiers")
local Spot = require("../src/shared/Logic/Spot")
local Audio = require("../src/shared/Logic/Audio")
local LowEnd = require("../src/shared/Logic/LowEnd")
local Look = require("../src/shared/Look")
local Analytics = require("../src/shared/Logic/Analytics")
local Preview = require("../src/shared/Logic/Preview")
local Easter = require("../src/shared/Logic/Easter")

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
	eq(Config.Phases.TourPerRoom, 10)
	eq(Config.Phases.TourLockIn, 1)
	eq(Config.Phases.TourVoteGrace, 1)
	eq(Config.Phases.Results, 30)
	eq(Config.Phases.ResultsRewardsAt, 10)
	truthy(Config.Phases.TourLockIn > 0)
	truthy(Config.Phases.TourLockIn < Config.Phases.TourPerRoom)
	truthy(Config.Phases.TourVoteGrace >= 1)
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
	eq(RoundEngine.timeLeft(state, 25), Config.Phases.TourPerRoom)
	eq(RoundEngine.snapshot(state, 25).tourLabel, "Room 1 of 1")
	eq(RoundEngine.snapshot(state, 25).tourLocked, false)
	local tourEnd = 25 + Config.Phases.TourPerRoom
	RoundEngine.advance(state, tourEnd - 1)
	eq(state.phase, "Tour")
	RoundEngine.advance(state, tourEnd)
	eq(state.phase, "Results")
	eq(state.history[1], "hearth_cocoa")
	RoundEngine.advance(state, tourEnd + Config.Phases.Results)
	eq(state.phase, "Lobby")
	eq(state.roundIndex, 1)
	local seen = {}
	for _, entry in ipairs(state.trace) do
		table.insert(seen, entry.phase)
	end
	eq(table.concat(seen, ","), "Lobby,ThemeReveal,Build,Tour,Results,Lobby")
end)

test("build uses the full timer when most builders are still working", function()
	local state = fresh()
	for _, id in ipairs({ "a", "b", "c", "d" }) do
		RoundEngine.join(state, id, 0)
	end
	RoundEngine.advance(state, 25)
	eq(state.phase, "Build")
	RoundEngine.pressDone(state, "a", 30)
	eq(state.phase, "Build")
	eq(state.showBanner, false)
	RoundEngine.advance(state, 264)
	eq(state.phase, "Build")
	RoundEngine.advance(state, 265)
	eq(state.phase, "Tour")
end)

test("60 percent done, or everyone but one, cuts the build to 30 seconds", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.advance(state, 25)
	eq(RoundEngine.pressDone(state, "mike", 30), true)
	eq(state.phase, "Build")
	eq(state.phaseEndsAt, 60)
	eq(state.showBanner, true)
	eq(RoundEngine.snapshot(state, 30).banner, "30 seconds left!")
	RoundEngine.advance(state, 59)
	eq(state.phase, "Build")
	RoundEngine.advance(state, 60)
	eq(state.phase, "Tour")
	local crowd = fresh()
	for i = 1, 5 do
		RoundEngine.join(crowd, "p" .. tostring(i), 0)
	end
	RoundEngine.setHasWork(crowd, function()
		return true
	end)
	RoundEngine.advance(crowd, 25)
	RoundEngine.pressDone(crowd, "p1", 40)
	RoundEngine.pressDone(crowd, "p2", 41)
	eq(crowd.showBanner, false)
	RoundEngine.pressDone(crowd, "p3", 42)
	eq(crowd.phase, "Build")
	eq(crowd.phaseEndsAt, 72)
	eq(crowd.showBanner, true)
	local idle = fresh()
	RoundEngine.join(idle, "ada", 0)
	RoundEngine.join(idle, "idle", 0)
	RoundEngine.join(idle, "empty", 0)
	RoundEngine.setHasWork(idle, function(id)
		return id == "ada"
	end)
	RoundEngine.advance(idle, 25)
	RoundEngine.pressDone(idle, "ada", 30)
	eq(idle.phase, "Build")
	eq(idle.phaseEndsAt, 60)
	eq(idle.showBanner, true)
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
	eq(state.phaseEndsAt, 40 + 2 * Config.Phases.TourPerRoom)
	eq(state.tourStops[1], "sam")
	eq(state.tourStops[2], "mike")
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

test("a late joiner with a minute left builds, and a later one waits", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 25)
	eq(state.phase, "Build")
	RoundEngine.join(state, "lee", 26)
	eq(RoundEngine.playerView(state, "lee").spectating, false)
	eq(RoundEngine.timeLeft(state, 26) >= Config.LateJoin.MinBuild, true)
	eq(RoundEngine.pressDone(state, "lee", 27), true)
	eq(state.phase, "Build")
	eq(state.phaseEndsAt, 57)
	local early = RoundEngine.pressDone(state, "mike", 40)
	eq(early, true)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 2)
	local back = 40 + 2 * Config.Phases.TourPerRoom + Config.Phases.Results
	RoundEngine.advance(state, back)
	local waited = fresh()
	RoundEngine.join(waited, "mike", 0)
	RoundEngine.advance(waited, 25)
	local lateAt = 25 + Config.Phases.Build - 40
	RoundEngine.join(waited, "lee", lateAt)
	eq(RoundEngine.playerView(waited, "lee").spectating, true)
	eq(RoundEngine.pressDone(waited, "lee", lateAt + 1), false)
	eq(RoundEngine.snapshot(waited, lateAt).nextRound > 0, true)
	eq(RoundEngine.pressDone(waited, "mike", lateAt + 2), true)
	eq(waited.phase, "Tour")
	eq(#waited.tourStops, 1)
	local lobbyAt = lateAt + 2 + Config.Phases.TourPerRoom + Config.Phases.Results
	RoundEngine.advance(waited, lobbyAt)
	eq(waited.phase, "Lobby")
	eq(RoundEngine.playerView(waited, "lee").spectating, false)
end)

test("joining mid-round with time left plays, then the next lobby too", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 25)
	eq(state.phase, "Build")
	RoundEngine.join(state, "lee", 220)
	local view = RoundEngine.playerView(state, "lee")
	eq(view.spectating, true)
	local denied = RoundEngine.pressDone(state, "lee", 221)
	eq(denied, false)
	local ok = RoundEngine.pressDone(state, "mike", 222)
	eq(ok, true)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 1)
	eq(state.tourStops[1], "mike")
	local back = 222 + Config.Phases.TourPerRoom + Config.Phases.Results
	RoundEngine.advance(state, back)
	eq(state.phase, "Lobby")
	eq(RoundEngine.playerView(state, "lee").spectating, false)
	eq(state.players.lee.role, "active")
	RoundEngine.advance(state, back + 20)
	eq(state.phase, "ThemeReveal")
	RoundEngine.advance(state, back + 25)
	eq(state.phase, "Build")
	local played = RoundEngine.pressDone(state, "lee", back + 25)
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
	eq(state.phaseEndsAt, 31 + 2 * Config.Phases.TourPerRoom)
	RoundEngine.leave(state, "sam", 33)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 1)
	eq(state.tourStops[1], "mike")
	eq(state.phaseEndsAt, 33 + Config.Phases.TourPerRoom)
	RoundEngine.advance(state, 33 + Config.Phases.TourPerRoom)
	eq(state.phase, "Results")
end)

test("leaving before your tour stop drops that stop only", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 30)
	RoundEngine.pressDone(state, "sam", 31)
	RoundEngine.leave(state, "mike", 32)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 1)
	eq(state.tourStops[1], "sam")
	eq(state.phaseEndsAt, 31 + Config.Phases.TourPerRoom)
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
	eq(RoundEngine.snapshot(state, 32).tourTarget, "sam")
	local per = Config.Phases.TourPerRoom
	local lockIn = Config.Phases.TourLockIn
	eq(state.phaseEndsAt, 32 + 3 * per)
	RoundEngine.advance(state, 32 + per - lockIn - 0.1)
	eq(state.phase, "Tour")
	eq(state.tourIndex, 1)
	eq(RoundEngine.snapshot(state, 32 + per - lockIn - 0.1).tourLabel, "Room 1 of 3")
	eq(RoundEngine.snapshot(state, 32 + per - lockIn - 0.1).tourLocked, false)
	local lockAt = 32 + per - lockIn
	RoundEngine.advance(state, lockAt)
	eq(state.tourIndex, 1)
	eq(state.tourStops[state.tourIndex], "sam")
	eq(RoundEngine.snapshot(state, lockAt).tourLocked, true)
	eq(RoundEngine.snapshot(state, lockAt).tourTarget, "sam")
	eq(RoundEngine.votesClosed(state, lockAt), false)
	eq(RoundEngine.votesClosed(state, lockAt + Config.Phases.TourVoteGrace - 0.05), false)
	eq(RoundEngine.votesClosed(state, lockAt + Config.Phases.TourVoteGrace), true)
	truthy(string.find(RoundEngine.snapshot(state, lockAt).tourLabel, "Locked", 1, true) ~= nil)
	RoundEngine.advance(state, 32 + per)
	eq(state.phase, "Tour")
	eq(state.tourIndex, 2)
	eq(state.tourStops[state.tourIndex], "lee")
	eq(RoundEngine.snapshot(state, 32 + per).tourLabel, "Room 2 of 3")
	eq(RoundEngine.snapshot(state, 32 + per).tourIndex, 2)
	eq(RoundEngine.snapshot(state, 32 + per).tourTarget, "lee")
	eq(RoundEngine.snapshot(state, 32 + per).tourLocked, false)
	eq(state.phaseEndsAt, 32 + 3 * per)
	RoundEngine.advance(state, 32 + 2 * per)
	eq(state.tourIndex, 3)
	eq(RoundEngine.snapshot(state, 32 + 2 * per).tourLabel, "Room 3 of 3")
	RoundEngine.advance(state, 32 + 3 * per - 1)
	eq(state.phase, "Tour")
	RoundEngine.advance(state, 32 + 3 * per)
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
	local per = Config.Phases.TourPerRoom
	local at = 32 + 2 * per + 5
	RoundEngine.advance(state, at)
	eq(state.phase, "Tour")
	eq(state.tourIndex, 3)
	eq(state.tourStops[state.tourIndex], "mike")
	eq(RoundEngine.snapshot(state, at).tourLabel, "Room 3 of 3")
	eq(RoundEngine.timeLeft(state, at), per - 5)
	local resultsAt = 32 + 3 * per
	RoundEngine.advance(state, resultsAt)
	eq(state.phase, "Results")
	eq(state.phaseStartedAt, resultsAt)
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
			local per = Config.Phases.TourPerRoom
			for i = 1, count do
				local at = tourStart + (i - 1) * per
				RoundEngine.advance(state, at)
				eq(state.phase, "Tour")
				eq(state.tourIndex, i)
				eq(RoundEngine.snapshot(state, at).tourLabel, string.format("Room %d of %d", i, count))
			end
			local tourEnd = tourStart + count * per
			RoundEngine.advance(state, tourEnd)
			eq(state.phase, "Results")
			RoundEngine.advance(state, tourEnd + Config.Phases.Results)
			eq(state.phase, "Lobby")
			eq(state.roundIndex, 1)
		else
			-- Solo player never presses DONE; the full build timer is used.
			RoundEngine.advance(state, 264)
			eq(state.phase, "Build")
			RoundEngine.advance(state, 265)
			eq(state.phase, "Results")
			eq(#state.tourStops, 0)
			RoundEngine.advance(state, 265 + Config.Phases.Results)
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
	local lobbyAt = 25 + Config.Phases.TourPerRoom + Config.Phases.Results
	RoundEngine.advance(state, lobbyAt)
	eq(state.phase, "Lobby")
	RoundEngine.advance(state, lobbyAt + 20)
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
	local lobbyAt = 25 + Config.Phases.TourPerRoom + Config.Phases.Results
	RoundEngine.advance(state, lobbyAt)
	RoundEngine.advance(state, lobbyAt + 20)
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
	local lobbyAt = 25 + Config.Phases.TourPerRoom + Config.Phases.Results
	RoundEngine.advance(state, lobbyAt)
	RoundEngine.setUnixNow(state, function()
		return Season.unix(2027, 1, 1, 6, 0, 0)
	end)
	RoundEngine.advance(state, lobbyAt + 20)
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
	now = 230
	RoundEngine.join(state, "lee", 220)
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
test("130 props, theme tags, and no banned words", function()
	eq(#Items.list, 130)
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
	eq(counts.room + counts.gingerbread + counts.tree, 130)
	local cheap = 0
	for _, item in ipairs(Items.list) do
		if item.cost <= 4 and item.w * item.d == 2 then
			cheap += 1
		end
	end
	truthy(cheap >= 6 and cheap <= 8, "cheap 2-cell pieces " .. tostring(cheap))
	local rug = Items.get("dot_rug")
	eq(rug.cost, 4)
	eq(rug.w, 2)
	eq(rug.d, 1)
	truthy(rug.h <= 0.1)
	eq(rug.surface, "floor")
	local accent = Items.get("bow_accent")
	eq(accent.cost, 4)
	eq(accent.w * accent.d, 2)
	truthy(accent.h > 0.1)
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
	local front = Bases.pivot("gingerbread", "wall", 0, 0, 0, 1, 1, 0.28)
	truthy(front ~= nil and front.z > Bases.wallPlane("gingerbread"), "candy should sit on the front of the house")
	local hanging = Bases.pivot("room", "wall", 0, 0, 0, 1, 1, 0.12)
	truthy(hanging ~= nil and hanging.z > Bases.wallPlane("room"), "hangings should sit in front of the back wall")
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
	eq(#tint.undo, 2)
	eq(Placement.recolor(tint, rich, 1, "mint"), true)
	eq(#tint.undo, 2)
	eq(tint.pieces[1].color, "mint")
end)

test("undo cannot turn a piece into an occupied cell", function()
	local ctx = placeCtx()
	local room = Placement.empty()
	eq(Placement.place(room, ctx, "butter_bench", 0, 0), true)
	eq(Placement.rotate(room, ctx, 1), true)
	eq(room.pieces[1].rot, 1)
	-- Occupy the cell the bench would need if it turned back to rot 0.
	eq(Placement.place(room, ctx, "cocoa_mug", 1, 0), true)
	-- Undo the mug place so rotate is on top, then put the mug back without
	-- a new undo-tracked gap: delete is not needed. After undo, mug is gone.
	-- Place it again, then manually pop? Better: undo mug, place mug, the
	-- rotate op is still in the stack under the new place. Undo the new place
	-- (mug gone), rotate is on top, place mug again... that adds another place
	-- on top. Can't get rotate on top while mug occupies the cell.

	-- Directly replace the undo stack top after placing both.
	room.undo = { { kind = "rotate", id = 1, rot = 0 } }
	local turned, turnMsg = Placement.undo(room, ctx)
	eq(turned, false)
	eq(turnMsg, "It cannot turn there.")
	eq(room.pieces[1].rot, 1)
	eq(#room.pieces, 2)
	eq(#room.undo, 1)
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
	eq(Config.Budget, 128)
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
	eq(state.tourStops[1], "lee")
	eq(state.tourStops[2], "sam")
	eq(state.tourStops[3], "mike")
	eq(RoundEngine.snapshot(state, 265).tourTarget, "lee")
	eq(RoundEngine.snapshot(state, 265).tourLabel, "Room 1 of 3")
end)

test("a spectator with props still cannot be submitted", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.join(state, "lee", 220)
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
	local source = fs.readFile("src/server/Services/ActionService.luau")
	truthy(string.find(source, "placeBurst", 1, true) ~= nil)
	truthy(string.find(source, "overrides", 1, true) ~= nil)
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
	local show = fs.readFile("src/client/Show.luau")
	truthy(string.find(show, "TourIndex", 1, true) ~= nil)
	truthy(string.find(show, "TourLabel", 1, true) ~= nil)
	truthy(string.find(show, "TourPlot", 1, true) ~= nil)
	truthy(string.find(show, "SpotLight", 1, true) ~= nil)
	truthy(string.find(show, "Sound", 1, true) ~= nil)
	truthy(string.find(show, "task.wait", 1, true) == nil)
	truthy(string.find(show, "task.delay", 1, true) == nil)
	truthy(string.find(string.lower(show), "tourperroom", 1, true) == nil)
	truthy(string.find(show, "Voting", 1, true) == nil)
	truthy(string.find(show, "Net", 1, true) == nil)
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

print("Voting")
local function near(a, b, msg)
	if type(a) ~= "number" or math.abs(a - b) > 1e-6 then
		error(string.format("%s: expected %s, got %s", msg or current, tostring(b), tostring(a)), 2)
	end
end

local function openGate(owner, role, voters)
	return {
		phase = "Tour",
		locked = false,
		tourTarget = owner,
		role = role or "active",
		ownerPresent = true,
		voterCount = voters or 6,
	}
end

local lowFacts = { meter = 0, unique = 1, pieces = 8, maxItems = 16 }
local highFacts = { meter = 80, unique = 6, pieces = 8, maxItems = 16 }

test("trimmed average drops the high and low star at 5 votes", function()
	near(Voting.average({ 1, 2, 3, 4, 5 }, Config.Voting.TrimAt), 3)
	near(Voting.average({ 5, 5, 5, 1, 1 }, Config.Voting.TrimAt), (5 + 5 + 1) / 3)
	near(Voting.average({ 1, 2, 3, 4 }, Config.Voting.TrimAt), 2.5)
	near(Voting.average({ 5 }, Config.Voting.TrimAt), 5)
	eq(Voting.withinEye(4, 3, Config.Voting.EyeWindow), true)
	eq(Voting.withinEye(2, 3, Config.Voting.EyeWindow), true)
	eq(Voting.withinEye(5, 3, Config.Voting.EyeWindow), false)
	eq(Voting.withinEye(1, 2.5, 1), false)
	eq(Voting.withinEye(2, 2.5, 1), true)
end)

test("a player cannot vote on their own room, and a spectator can", function()
	local state = Voting.create()
	local denied, why = Voting.cast(state, "mike", "mike", 5, openGate("mike", "active"), Config)
	eq(denied, false)
	eq(why, "You cannot vote on your own room.")
	eq(state.rooms.mike, nil)
	local watching, watchWhy = Voting.cast(state, "lee", "mike", 4, openGate("mike", "spectator"), Config)
	eq(watching, true)
	eq(watchWhy, "Voted.")
	eq(state.rooms.mike.votes.lee, 4)
	eq(state.rooms.mike.votes.mike, nil)
end)

test("a vote can change until lock-in, and a late vote is rejected", function()
	local state = Voting.create()
	local open = openGate("mike", "active")
	eq(Voting.cast(state, "sam", "mike", 2, open, Config), true)
	eq(Voting.cast(state, "sam", "mike", 5, open, Config), true)
	eq(state.rooms.mike.votes.sam, 5)
	local keys = 0
	for _ in pairs(state.rooms.mike.votes) do
		keys += 1
	end
	eq(keys, 1)
	local locked = openGate("mike", "active")
	locked.locked = true
	local late, lateWhy = Voting.cast(state, "sam", "mike", 1, locked, Config)
	eq(late, false)
	eq(lateWhy, "Votes are locked.")
	eq(state.rooms.mike.votes.sam, 5)
	local missed = Voting.cast(state, "ada", "mike", 3, locked, Config)
	eq(missed, false)
	eq(state.rooms.mike.votes.ada, nil)
	local offstage, offWhy = Voting.cast(state, "ada", "mike", 3, openGate("lee", "active"), Config)
	eq(offstage, false)
	eq(offWhy, "That room is not on stage.")
	eq(state.rooms.mike.votes.ada, nil)
end)

test("Vote and Report share the action remote and will not take a username", function()
	local state = Voting.create()
	local gate = openGate("room", "active", 10)
	local api = Actions.create({
		globalBurst = Config.RateLimit.globalBurst,
		globalRefill = Config.RateLimit.globalRefill,
		actionBurst = Config.RateLimit.actionBurst,
		actionRefill = Config.RateLimit.actionRefill,
		nameMax = Config.RateLimit.nameMax,
	})
	api.register("Vote", { "number" }, function(key, args)
		return Voting.cast(state, key, "room", args[1], gate, Config)
	end)
	api.register("Report", {}, function(key)
		local ok, msg = Voting.report(state, key, "room", gate, Config)
		return ok, msg
	end)
	eq(api.handle("p", "Vote", { "sam" }, 0), false)
	eq(api.handle("p", "Report", { "sam" }, 0), false)
	for _ = 1, Config.RateLimit.actionBurst do
		eq(api.handle("p", "Vote", { 4 }, 0), true)
	end
	local limited, why = api.handle("p", "Vote", { 1 }, 0)
	eq(limited, false)
	eq(why, "Slow down a moment.")
	eq(state.rooms.room.votes.p, 4)
	eq(api.handle("p", "Report", {}, 0), true)
	local voteSrc = fs.readFile("src/server/Services/VoteService.luau")
	truthy(string.find(voteSrc, 'register("Vote", { "number" }', 1, true) ~= nil)
	truthy(string.find(voteSrc, 'register("Report", {}', 1, true) ~= nil)
	truthy(string.find(voteSrc, "tourTarget", 1, true) ~= nil)
	truthy(string.find(voteSrc, "DataStore", 1, true) == nil)
	local actionSrc = fs.readFile("src/server/Services/ActionService.luau")
	truthy(string.find(actionSrc, "Vote", 1, true) == nil)
end)

test("a room is removed at the higher of 3 reports or half the voters", function()
	eq(Config.Voting.ReportFraction, 0.5)
	eq(Voting.threshold(10, Config), 5)
	eq(Voting.threshold(8, Config), 4)
	eq(Voting.threshold(7, Config), 4)
	eq(Voting.threshold(6, Config), 3)
	eq(Voting.threshold(5, Config), 3)
	eq(Voting.threshold(4, Config), 3)
	eq(Voting.threshold(3, Config), 3)
	eq(Voting.threshold(2, Config), 3)
	eq(Voting.threshold(20, Config), 10)
	eq(Voting.threshold(0, Config), 3)
	local state = Voting.create()
	local gate = openGate("mike", "spectator", 10)
	for i = 1, 4 do
		local ok, _, removed = Voting.report(state, "p" .. tostring(i), "mike", gate, Config)
		eq(ok, true)
		eq(removed, false)
	end
	local again, _, againRemoved = Voting.report(state, "p1", "mike", gate, Config)
	eq(again, true)
	eq(againRemoved, false)
	local ok, _, removed = Voting.report(state, "p5", "mike", gate, Config)
	eq(ok, true)
	eq(removed, true)
	eq(state.rooms.mike.removed, true)
	-- Half of 7 voters rounds up to 4, so three reports cannot drop the room.
	local wide = Voting.create()
	local crowd = openGate("ada", "active", 7)
	eq(select(3, Voting.report(wide, "a", "ada", crowd, Config)), false)
	eq(select(3, Voting.report(wide, "b", "ada", crowd, Config)), false)
	eq(select(3, Voting.report(wide, "c", "ada", crowd, Config)), false)
	eq(wide.rooms.ada.removed, false)
	eq(select(3, Voting.report(wide, "d", "ada", crowd, Config)), true)
	local own = Voting.report(state, "mike", "mike", openGate("mike", "active", 10), Config)
	eq(own, false)
	local small = Voting.create()
	local few = openGate("ada", "active", 5)
	eq(select(3, Voting.report(small, "a", "ada", few, Config)), false)
	eq(select(3, Voting.report(small, "b", "ada", few, Config)), false)
	eq(select(3, Voting.report(small, "c", "ada", few, Config)), true)
	-- In a 3-player server only two people can vote, so 3 reports are
	-- required and two friends cannot take the third player's room down.
	eq(Voting.threshold(2, Config), 3)
	local trio = Voting.create()
	local tight = openGate("ada", "active", 2)
	eq(select(3, Voting.report(trio, "a", "ada", tight, Config)), false)
	eq(select(3, Voting.report(trio, "b", "ada", tight, Config)), false)
	eq(trio.rooms.ada.removed, false)
end)

test("Auntie Roch's vote and line are deterministic", function()
	local stars, line = Voting.critic(highFacts, Config)
	local againStars, againLine = Voting.critic(highFacts, Config)
	eq(stars, 4)
	eq(againStars, stars)
	eq(againLine, line)
	eq(line, "Lovely variety, and the theme is clear.")
	local lowStars, lowLine = Voting.critic(lowFacts, Config)
	local lowAgain, lowLineAgain = Voting.critic(lowFacts, Config)
	eq(lowStars, 1)
	eq(lowAgain, lowStars)
	eq(lowLineAgain, lowLine)
	eq(lowLine, "I can see the idea. Let's welcome the theme in.")
	local fullStars = Voting.critic({ meter = 100, unique = 8, pieces = 16, maxItems = 16 }, Config)
	eq(fullStars, 5)
	truthy(lowLine ~= line)
	local solo = Voting.create()
	Voting.ensure(solo, "mike")
	local rows = Voting.finalize(solo, { mike = highFacts }, { mike = true }, Config)
	eq(#rows, 1)
	eq(rows[1].criticStars, stars)
	eq(rows[1].average, stars)
	eq(rows[1].comment, line)
	eq(solo.eyeCoins.mike, nil)
end)

test("Judge's Eye pays the placeholder purse for stars near the final average", function()
	local state = Voting.create()
	local facts = { ada = lowFacts, bea = lowFacts }
	for _, pair in ipairs({
		{ "p1", 1 },
		{ "p2", 2 },
		{ "p3", 3 },
		{ "p4", 4 },
		{ "p5", 5 },
	}) do
		eq(Voting.cast(state, pair[1], "ada", pair[2], openGate("ada"), Config), true)
	end
	eq(Voting.cast(state, "p2", "bea", 1, openGate("bea"), Config), true)
	Voting.ensure(state, "bea")
	local rows = Voting.finalize(state, facts, { ada = true, bea = true }, Config)
	eq(#rows, 2)
	eq(rows[1].owner, "ada")
	near(rows[1].average, 2.5)
	eq(rows[1].criticStars, 1)
	eq(rows[2].owner, "bea")
	near(rows[2].average, 1)
	eq(state.eyeCoins.p1, nil)
	eq(state.eyeCoins.p2, Config.Voting.EyeNoRoomCoins * 2)
	eq(state.eyeCoins.p3, Config.Voting.EyeNoRoomCoins)
	eq(state.eyeCoins.p4, nil)
	eq(state.eyeCoins.p5, nil)
	eq(Voting.cast(state, "ada", "bea", 1, openGate("bea"), Config), true)
	local again = Voting.finalize(state, facts, { ada = true, bea = true }, Config)
	eq(#again, 2)
	eq(state.eyeCoins.ada, Config.Voting.EyeCoins)
	eq(state.eyeCoins[Config.Critic.id], nil)
end)

test("votes for a room whose owner left are ignored", function()
	local state = Voting.create()
	eq(Voting.cast(state, "sam", "mike", 1, openGate("mike"), Config), true)
	eq(Voting.cast(state, "sam", "lee", 2, openGate("lee"), Config), true)
	local rows = Voting.finalize(state, { mike = lowFacts, lee = lowFacts }, { lee = true, sam = true }, Config)
	eq(#rows, 1)
	eq(rows[1].owner, "lee")
	near(rows[1].average, 1.5)
	eq(state.eyeCoins.sam, Config.Voting.EyeNoRoomCoins)
	local gone = Voting.cast(state, "sam", "mike", 5, {
		phase = "Tour",
		locked = false,
		tourTarget = "mike",
		role = "active",
		ownerPresent = false,
		voterCount = 4,
	}, Config)
	eq(gone, false)
end)

test("names stay hidden until the podium", function()
	eq(Voting.signLabel("Tour", 4, "Mike"), "Room 4")
	eq(Voting.signLabel("Results", 4, "Mike"), "Room 4")
	eq(Voting.signLabel("Build", 4, "Mike"), "Mike")
	eq(Voting.signLabel("Lobby", 4, ""), "Plot 4")
	local card = Voting.photoCard({
		theme = "Cocoa Hearth",
		stars = 4.5,
		line = "Oh, this glows. The theme is right at home.",
		name = "Mike",
	})
	eq(card.theme, "Cocoa Hearth")
	near(card.stars, 4.5)
	eq(card.line, "Oh, this glows. The theme is right at home.")
	eq(card.name, nil)
	eq(card.owner, nil)
	local rows = {
		{ owner = "1", average = 5, comment = "A full glow-up. The theme is everywhere it should be.", criticStars = 5 },
		{ owner = "2", average = 4, comment = "Oh, this glows. The theme is right at home.", criticStars = 4 },
		{ owner = "3", average = 3, comment = "A happy room. The theme feels welcome.", criticStars = 3 },
		{ owner = "4", average = 2, comment = "Getting there. The theme is peeking through.", criticStars = 2 },
	}
	local payload = Voting.encodeBoard(rows, { ["1"] = "Ada", ["2"] = "Bea", ["3"] = "Cal", ["4"] = "Dee" }, Config.Voting.Podium)
	local decoded = Voting.decodeBoard(payload)
	eq(decoded[1].name, "Ada")
	eq(decoded[1].userId, "1")
	eq(decoded[3].name, "Cal")
	eq(decoded[4].name, "")
	eq(decoded[4].userId, "")
	near(decoded[4].average, 2)
	eq(decoded[4].comment, "Getting there. The theme is peeking through.")
	local plots = fs.readFile("src/server/Services/PlotService.luau")
	truthy(string.find(plots, "signLabel", 1, true) ~= nil)
	truthy(string.find(plots, "label.Text = display", 1, true) == nil)
	local hud = fs.readFile("src/client/Hud.luau")
	truthy(string.find(hud, "DisplayName", 1, true) == nil)
	local voteUi = fs.readFile("src/client/Vote.luau")
	truthy(string.find(voteUi, "DisplayName", 1, true) == nil)
	truthy(string.find(voteUi, "photoCard", 1, true) ~= nil)
	truthy(string.find(voteUi, "UIKit.bands", 1, true) ~= nil)
	truthy(string.find(voteUi, "bands.tray", 1, true) ~= nil)
	truthy(string.find(voteUi, "bands.reveal", 1, true) ~= nil)
	truthy(string.find(voteUi, 'Net.act("Report")', 1, true) ~= nil)
	truthy(string.find(voteUi, 'Net.act("Vote"', 1, true) ~= nil)
	truthy(string.find(voteUi, "TourPlot", 1, true) ~= nil)
	truthy(string.find(voteUi, "isOwnRoom", 1, true) ~= nil)
	local roundSrc = fs.readFile("src/server/Services/RoundService.luau")
	truthy(string.find(roundSrc, 'SetAttribute("TourTarget", snap.tourTarget', 1, true) == nil)
	truthy(string.find(plots, "hideOwner", 1, true) ~= nil)
	local banned = { "impress", "cozy", "roblox", "blox", "bedroom", "bathroom", "eggnog", "mulled", "wine", "alcohol", "beer", "whiskey", "vodka" }
	for stars, lines in ipairs(Config.Critic.lines) do
		eq(#lines >= 1, true)
		for _, line in ipairs(lines) do
			local blob = string.lower(line)
			for _, word in ipairs(banned) do
				truthy(string.find(blob, word, 1, true) == nil, "line " .. tostring(stars) .. " contains " .. word)
			end
		end
	end
end)

test("a reported room leaves the tour and the panels stay off the board", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.join(state, "lee", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 30)
	RoundEngine.pressDone(state, "sam", 31)
	RoundEngine.pressDone(state, "lee", 32)
	eq(state.tourStops[1], "sam")
	RoundEngine.removeStop(state, "sam", 33)
	eq(state.phase, "Tour")
	eq(#state.tourStops, 2)
	eq(state.tourStops[1], "lee")
	eq(state.tourIndex, 1)
	for _, height in ipairs({ 420, 480, 520, 700, 800 }) do
		local bands = UIKit.bands(height)
		local tourTop = bands.tray.top
		local tourBottom = bands.tray.bottom
		local resultsTop = bands.reveal.top
		local resultsBottom = bands.tray.bottom
		truthy(tourTop >= bands.board.bottom + 4, "tour " .. tostring(height))
		truthy(tourBottom <= bands.done.top - 4, "tour button " .. tostring(height))
		truthy(resultsTop >= bands.board.bottom + 4, "results " .. tostring(height))
		truthy(resultsBottom <= bands.done.top - 4, "results button " .. tostring(height))
		truthy(tourBottom - tourTop >= 90, "tray " .. tostring(height))
	end
end)

local function catalog()
	return {
		get = function(id)
			return Items.get(id)
		end,
	}
end

local function buildCtx(extra)
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
		now = 0,
		undoCap = Config.UndoCap,
	}
	if extra then
		for key, value in pairs(extra) do
			ctx[key] = value
		end
	end
	return ctx
end

print("Saves")
test("schema 1 round-trips and a second session cannot write", function()
	local store = Save.memory()
	local key = Save.profileKey("7")
	local dreamKey = Save.dreamKey("7")
	truthy(key ~= dreamKey)
	local opened = Save.open(store, key, "A", 1000, 60)
	truthy(opened)
	eq(opened.schema, 1)
	local other, err = Save.open(store, key, "B", 1010, 60)
	eq(other, nil)
	eq(err, "Busy.")
	local profile = Save.normalizeProfile(opened)
	profile.coins = 15
	profile.xp = 46
	profile.stamps = { "hearth_cocoa" }
	local doc = Save.clone(profile)
	doc.schema = 1
	doc.lock = opened.lock
	local waits = {}
	local fails = 0
	local flaky = {
		update = function(_, transform)
			fails += 1
			if fails < 3 then
				error("not ready")
			end
			return transform(opened)
		end,
	}
	local saved, attempts = Save.write(flaky, key, "A", doc, function(seconds)
		table.insert(waits, seconds)
	end, 4)
	eq(attempts, 3)
	eq(waits[1], 0.5)
	eq(waits[2], 1)
	truthy(saved)
	eq(saved.luck, nil)
	eq(saved.schema, 1)
	local lock = Save.locker()
	local nested = nil
	local wrote = lock.run(function()
		nested = lock.run(function()
			return "inner"
		end)
		return Save.write(store, key, "A", doc, function() end, 4)
	end)
	eq(nested, nil)
	truthy(wrote)
	eq(wrote.coins, 15)
	local closed = Save.close(store, key, "A")
	truthy(closed)
	eq(closed.lock, nil)
	local again = Save.open(store, key, "B", 2000, 60)
	truthy(again)
	local loaded = Save.normalizeProfile(again)
	eq(loaded.coins, 15)
	eq(loaded.xp, 46)
	eq(loaded.stamps[1], "hearth_cocoa")
	eq(loaded.luck, nil)
	eq(again.schema, 1)
	local dream = Save.open(store, dreamKey, "B", 2000, 60)
	local home = Save.normalizeDream(dream)
	eq(#home.homes, 1)
	eq(#home.lookbook, 0)
	eq(Save.which("Tour", "results"), "skip")
	eq(Save.which("Tour", "leave"), "settled")
	eq(Save.which("Tour", "shutdown"), "settled")
	eq(Save.which("Results", "results"), "live")
	eq(Save.which("Build", "results"), "skip")
	eq(Save.which("Lobby", "leave"), "live")
	local src = fs.readFile("src/server/Services/SaveService.luau")
	truthy(string.find(src, "BindToClose", 1, true) ~= nil)
	truthy(string.find(src, "UpdateAsync", 1, true) ~= nil)
	truthy(string.find(src, "PlayerRemoving", 1, true) ~= nil)
	truthy(string.find(src, "DreamStore", 1, true) ~= nil)
	truthy(string.find(src, "ProfileStore", 1, true) ~= nil)
	eq(Config.Progress.DreamStore ~= Config.Progress.ProfileStore, true)
	eq(Save.MaxDreamPieces, Config.Progress.HouseItems)
	-- A 10-player round is 395s. The lock has to outlast it, and a stale lock
	-- can be stolen. A newer schema is refused and is not overwritten.
	truthy(Config.Progress.LockSeconds >= 900)
	local stale = Save.memory()
	local staleKey = Save.profileKey("9")
	local first = Save.open(stale, staleKey, "A", 1000, 60)
	first.coins = 40
	Save.write(stale, staleKey, "A", first, function() end, 4, 1000)
	local early, earlyErr = Save.open(stale, staleKey, "B", 1059, 60)
	eq(early, nil)
	eq(earlyErr, "Busy.")
	local stolen = Save.open(stale, staleKey, "B", 1060, 60)
	truthy(stolen)
	eq(stolen.lock.session, "B")
	local bounced, bouncedTries = Save.write(stale, staleKey, "A", first, function() end, 2)
	eq(bounced, nil)
	eq(bouncedTries, 2)
	local loaded = Save.normalizeProfile(stolen)
	eq(loaded.coins, 40)
	local schemaStore = Save.memory()
	local schemaKey = Save.profileKey("11")
	schemaStore.update(schemaKey, function()
		return { schema = 2, coins = 99 }
	end)
	local refused, why = Save.open(schemaStore, schemaKey, "C", 3000, 60)
	eq(refused, nil)
	eq(why, "Schema.")
	local raw = nil
	schemaStore.update(schemaKey, function(current)
		raw = current
		return nil
	end)
	eq(raw.schema, 2)
	eq(raw.coins, 99)
	truthy(string.find(src, "task.spawn", 1, true) ~= nil)
	truthy(string.find(src, "bag.hold ~= true", 1, true) ~= nil)
	local progressSrc = fs.readFile("src/server/Services/ProgressService.luau")
	truthy(string.find(progressSrc, "bag.hold ~= true", 1, true) ~= nil)
end)

print("Rewards and levels")
test("a round id pays once, from the ballot, with the level curve", function()
	Monetization.reset()
	local profile = Save.blankProfile()
	local eyes = { ada = Config.Voting.EyeCoins }
	local decoy = { EyeCoins = 999 }
	local input = {
		roundId = "server:1",
		rank = 1,
		average = 4,
		podium = 1,
		eye = Rewards.eyeFromBallot(eyes, "ada"),
		userId = "ada",
	}
	eq(input.eye, Config.Voting.EyeCoins)
	eq(decoy.EyeCoins, 999)
	local hooks = {
		coinMultiplier = function()
			return Monetization.coinMultiplier("ada")
		end,
		luck = function()
			return Monetization.luck("ada")
		end,
	}
	local first = Rewards.grant(profile, input, Config, hooks)
	eq(first.duplicate, false)
	eq(first.luck, false)
	local place = Config.Rewards.PlaceCoins[1]
	local stars = math.floor(4 * Config.Rewards.StarCoins)
	local podium = Config.Rewards.PodiumCoins[1]
	local expected = place + stars + podium + Config.Voting.EyeCoins * Config.Rewards.EyeRate
	eq(first.coins, expected)
	local xp = Config.Rewards.PlaceXp[1] + math.floor(4 * Config.Rewards.StarXp) + Config.Rewards.PodiumXp[1]
	eq(first.xp, xp)
	eq(profile.coins, expected)
	local second = Rewards.grant(profile, input, Config, hooks)
	eq(second.duplicate, true)
	eq(second.coins, 0)
	eq(profile.coins, expected)
	local rejoin = Save.normalizeProfile(Save.clone(profile))
	local again = Rewards.grant(rejoin, input, Config, hooks)
	eq(again.duplicate, true)
	eq(rejoin.coins, expected)
	local lastXp = Config.Rewards.PlaceXp[5] + math.floor(1 * Config.Rewards.StarXp)
	truthy(lastXp >= Levels.total(2), "first room should reach level 2")
	local boosted = Save.blankProfile()
	Monetization.setCoinSource(function()
		return 2
	end)
	Monetization.setLuckSource(function()
		return true
	end)
	local doubled = Rewards.grant(boosted, input, Config, {
		coinMultiplier = function(userId)
			return Monetization.coinMultiplier(userId)
		end,
		luck = function(userId)
			return Monetization.luck(userId)
		end,
	})
	eq(doubled.coins, expected * 2 + Config.Shop.LuckBonusCoins)
	eq(doubled.xp, xp)
	eq(doubled.luck, true)
	Monetization.reset()
	eq(Levels.total(1), 0)
	eq(Levels.total(2), Config.Progress.XpBase)
	eq(Levels.total(3), Config.Progress.XpBase + Levels.step(2))
	eq(Levels.fromXp(0), 1)
	eq(Levels.fromXp(Levels.total(2) - 1), 1)
	eq(Levels.fromXp(Levels.total(2)), 2)
	eq(Levels.fromXp(Levels.total(50)), 50)
	eq(Levels.fromXp(Levels.total(50) + 5000), 50)
	truthy(Levels.total(50) > Levels.total(25))
	eq(Levels.ownedCount(1), 40)
	eq(Levels.owns("butter_bench", 1), true)
	eq(Levels.owns("carol_piano", 1), false)
	local gate = Levels.gate("carol_piano", 1)
	eq(gate.owned, false)
	truthy(gate.level > 1)
	eq(Levels.owns("carol_piano", gate.level), true)
	truthy(string.find(Levels.next(1), "Level 2", 1, true) ~= nil)
	eq(Levels.next(50), "All the furniture is yours.")
	for level = 2, Config.Progress.MaxLevel do
		local row = Levels.setAt(level)
		truthy(row and #row.items > 0, "level " .. tostring(level))
	end
	local room = Placement.empty()
	local locked = buildCtx({
		allow = function(id)
			return Levels.owns(id, 1)
		end,
	})
	local denied = Placement.place(room, locked, "carol_piano", 0, 0)
	eq(denied, false)
	eq(#room.pieces, 0)
	local placed = Placement.place(room, locked, "butter_bench", 0, 0)
	eq(placed, true)
	eq(#room.pieces, 1)
	local progress = fs.readFile("src/server/Services/ProgressService.luau")
	truthy(string.find(progress, 'GetAttribute("EyeCoins")', 1, true) == nil)
	truthy(string.find(progress, "eyeFromBallot", 1, true) ~= nil)
end)

print("Dream home and duo")
test("the dream home survives a lobby wipe and only spends owned items", function()
	local contest = Placement.empty()
	local doc = Save.blankDream()
	eq(Dream.ensureSlots(doc, 0), 1)
	eq(Dream.slots(Monetization.extraDreamSlots("1")), 1)
	Monetization.setSlotSource(function()
		return 1
	end)
	eq(Dream.ensureSlots(doc, Monetization.extraDreamSlots("1")), 2)
	eq(#doc.homes, 2)
	Monetization.reset()
	local home = Dream.roomFrom(doc.homes[1].pieces)
	local ctx = Dream.context(1, catalog(), 0)
	eq(ctx.freeSpend, true)
	eq(ctx.phase, "Dream")
	eq(ctx.gridType, "studio")
	eq(Placement.place(home, ctx, "butter_bench", 0, 0), true)
	eq(Placement.place(home, ctx, "carol_piano", 2, 0), false)
	eq(Placement.place(contest, buildCtx(), "cocoa_table", 0, 0), true)
	contest = Placement.empty()
	eq(#contest.pieces, 0)
	eq(#home.pieces, 1)
	eq(#doc.homes, 2)
	eq(Dream.tier(1), "studio")
	eq(Dream.tier(Config.Progress.LoftLevel), "loft")
	eq(Dream.tier(Config.Progress.HouseLevel), "house")
	eq(Dream.cap(1), Config.Progress.StudioItems)
	eq(Dream.cap(Config.Progress.HouseLevel), Config.Progress.HouseItems)
	local stuffed = {}
	for index = 1, Config.Progress.HouseItems + 8 do
		table.insert(stuffed, { id = index, itemId = "butter_bench", surface = "floor", x = 0, z = 0, rot = 0, color = "cream", cost = 0, placedAt = 0 })
	end
	eq(#Dream.clip(stuffed, Dream.cap(1)), Config.Progress.StudioItems)
	local normalized = Save.normalizeDream({ schema = 1, homes = { { pieces = stuffed } }, lookbook = {} })
	eq(#normalized.homes[1].pieces, Config.Progress.HouseItems)
	eq(#Dream.roomFrom(stuffed, Dream.cap(1)).pieces, Config.Progress.StudioItems)
	local down = Bases.pivot("house", "floor", 0, 0, 0, 1, 1, 1)
	local up = Bases.pivot("house", "floor", 0, 4, 0, 1, 1, 1)
	truthy(up.y > down.y)
	local book = {}
	eq(Dream.remember(book, { roundId = "r1", average = 3, pieces = {} }, Config.Progress.Lookbook), true)
	eq(Dream.remember(book, { roundId = "r2", average = 4, pieces = {} }, Config.Progress.Lookbook), true)
	eq(Dream.remember(book, { roundId = "r3", average = 5, pieces = {} }, Config.Progress.Lookbook), true)
	eq(Dream.remember(book, { roundId = "weak", average = 2, pieces = {} }, Config.Progress.Lookbook), false)
	eq(#book, 3)
	eq(Dream.remember(book, { roundId = "best", average = 5, pieces = {} }, Config.Progress.Lookbook), true)
	eq(#book, 3)
	local rooms = fs.readFile("src/server/Services/RoomService.luau")
	truthy(string.find(rooms, "rooms[key] = Placement.empty()", 1, true) ~= nil)
	truthy(string.find(rooms, "homes[key] = Placement.empty()", 1, true) == nil)
end)

test("duo shares 1.5x budget and both owners are excluded from votes", function()
	local group = Duo.create()
	eq(Duo.toggle(group, "ada", "Build"), false)
	eq(Duo.toggle(group, "ada", "Lobby"), true)
	eq(Duo.toggle(group, "bea", "Lobby"), true)
	eq(Duo.toggle(group, "cal", "Lobby"), true)
	Duo.freeze(group, { "cal", "ada", "bea" })
	eq(Duo.partnerOf(group, "ada"), "bea")
	eq(Duo.leadOf(group, "bea"), "ada")
	eq(Duo.paired(group, "cal"), false)
	local budget = Duo.budget(Config.Budget, true)
	eq(budget, math.floor(Config.Budget * Config.Progress.DuoScale))
	truthy(budget > Config.Budget)
	eq(Duo.itemCap(Config.MaxItems, true), math.floor(Config.MaxItems * 1.5))
	eq(Duo.gridType("room", true), "duo_room")
	eq(Bases.fits("room", "floor", 6, 0, 1, 1, 0), false)
	eq(Bases.fits("duo_room", "floor", 6, 0, 1, 1, 0), true)
	local room = Placement.empty()
	local ctx = buildCtx({
		budget = budget,
		maxItems = Duo.itemCap(Config.MaxItems, true),
		gridType = "duo_room",
	})
	local spent = 0
	local x = 0
	local z = 0
	while spent + 12 <= Config.Budget do
		eq(Placement.place(room, ctx, "cocoa_table", x, z), true)
		spent += 12
		x += 2
		if x > 6 then
			x = 0
			z += 1
		end
	end
	truthy(room.spent + 12 > Config.Budget)
	eq(Placement.place(room, ctx, "cocoa_table", x, z), true)
	truthy(room.spent <= budget)
	local state = Voting.create()
	local voters = Duo.eligible(6, 2)
	eq(voters, 4)
	local gate = openGate("ada", "active", voters)
	gate.owners = Duo.owners(group, "ada")
	eq(Voting.cast(state, "bea", "ada", 5, gate, Config), false)
	eq(Voting.cast(state, "ada", "ada", 5, gate, Config), false)
	local reported, _, removed = Voting.report(state, "bea", "ada", gate, Config)
	eq(reported, false)
	eq(removed, false)
	eq(Voting.cast(state, "cal", "ada", 4, gate, Config), true)
	eq(Voting.threshold(voters, Config), 3)
	local plots = Plots.create(10)
	eq(Plots.assign(plots, "ada"), 1)
	eq(Plots.assign(plots, "bea"), 2)
	local keep, freed = Plots.transfer(plots, "ada", "bea")
	eq(keep, 1)
	eq(freed, 2)
	eq(Plots.plotOf(plots, "bea"), 1)
	eq(Plots.plotOf(plots, "ada"), nil)
	eq(Plots.owner(plots, 1), "bea")
	eq(Plots.owner(plots, 2), nil)
	local leftover, wasLead = Duo.detach(group, "ada")
	eq(leftover, "bea")
	eq(wasLead, true)
	eq(Duo.partnerOf(group, "bea"), nil)
	eq(Duo.leadOf(group, "bea"), "bea")
	eq(Duo.paired(group, "bea"), true)
	local engine = fresh(Config)
	RoundEngine.join(engine, "ada", 0)
	RoundEngine.join(engine, "bea", 0)
	engine.tourStops = { "ada", "cal" }
	engine.tourIndex = 1
	engine.phase = "Tour"
	RoundEngine.reassignStop(engine, "ada", "bea")
	eq(engine.tourStops[1], "bea")
	Voting.reassign(state, "ada", "bea")
	eq(state.rooms.ada, nil)
	truthy(state.rooms.bea)
	local after = openGate("bea", "active", 4)
	after.owners = { "bea" }
	eq(Voting.cast(state, "bea", "bea", 5, after, Config), false)
	local roundSrc = fs.readFile("src/server/Services/RoundService.luau")
	truthy(string.find(roundSrc, "handOff", 1, true) ~= nil)
	truthy(string.find(roundSrc, "reassignStop", 1, true) ~= nil)
end)

print("Quests, stamps, and rank")
test("daily quests follow the Central date and a few rounds finish them", function()
	local offset = Config.TimezoneOffsetHours
	local before = Season.unix(2026, 11, 19, 5, 59, 0)
	local at = Season.unix(2026, 11, 19, 6, 0, 0)
	eq(Quests.dayKey(before, offset), "2026-11-18")
	eq(Quests.dayKey(at, offset), "2026-11-19")
	local day = Quests.pick("2026-11-19")
	local again = Quests.pick("2026-11-19")
	eq(#day, 3)
	eq(day[1].id, again[1].id)
	eq(day[2].id, again[2].id)
	eq(day[3].id, again[3].id)
	local other = Quests.pick("2026-11-20")
	local same = day[1].id == other[1].id and day[2].id == other[2].id and day[3].id == other[3].id
	eq(same, false)
	local profile = Save.blankProfile()
	Quests.ensure(profile, "2026-11-19")
	local stats = { rooms = 1, starRounds = 1, props = 4, meterRounds = 1, recolors = 2, fullRounds = 1 }
	Quests.apply(profile, stats, 0)
	local done = 0
	for _, quest in ipairs(profile.quests) do
		if quest.progress >= quest.goal then
			done += 1
		end
	end
	eq(done < 3, true)
	for _ = 2, 4 do
		Quests.apply(profile, stats, 0)
	end
	for _, quest in ipairs(profile.quests) do
		truthy(quest.progress >= quest.goal, quest.id)
	end
end)

test("stamps start at 4 stars and a finished set pays once", function()
	local themes = {
		{ id = "one", name = "One", roundType = "room", season = "holiday" },
		{ id = "two", name = "Two", roundType = "room", season = "holiday" },
	}
	local profile = Save.blankProfile()
	local low = Collections.consider(profile, "one", 3.9, themes, Config)
	eq(low.stamped, false)
	eq(#profile.stamps, 0)
	local first = Collections.consider(profile, "one", 4, themes, Config)
	eq(first.stamped, true)
	eq(first.setComplete, false)
	local repeatStamp = Collections.consider(profile, "one", 5, themes, Config)
	eq(repeatStamp.already, true)
	eq(profile.coins, 0)
	local done = Collections.consider(profile, "two", 4, themes, Config)
	eq(done.setComplete, true)
	eq(profile.coins, Config.Progress.SetBonusCoins)
	local purse = profile.coins
	Collections.consider(profile, "two", 5, themes, Config)
	eq(profile.coins, purse)
end)

test("designer rank uses the month and does not decay or follow the theme season", function()
	local offset = Config.TimezoneOffsetHours
	local nov = Season.unix(2026, 11, 19, 18, 0, 0)
	local dec = Season.unix(2026, 12, 15, 18, 0, 0)
	local jan = Season.unix(2027, 1, 15, 18, 0, 0)
	eq(Season.resolve("auto", nov, offset), "holiday")
	eq(Season.resolve("auto", dec, offset), "holiday")
	eq(Season.resolve("auto", jan, offset), "winter")
	eq(Rank.month(nov, offset), "2026-11")
	eq(Rank.month(dec, offset), "2026-12")
	eq(Rank.month(jan, offset), "2027-01")
	truthy(Rank.month(nov, offset) ~= Season.resolve("auto", nov, offset))
	truthy(Rank.month(nov, offset) ~= Rank.month(dec, offset))
	local profile = Save.blankProfile()
	local first = Rank.award(profile, "2026-11", 100, Config.RankTrack)
	eq(profile.rankPoints, 100)
	eq(first.coins, Config.RankTrack[1].coins)
	eq(profile.coins, Config.RankTrack[1].coins)
	local held = profile.rankPoints
	Rank.award(profile, "2026-11", 0, Config.RankTrack)
	eq(profile.rankPoints, held)
	Rank.award(profile, "2026-12", 0, Config.RankTrack)
	eq(profile.rankPoints, 0)
	eq(profile.rankMonth, "2026-12")
end)

test("results shows rewards after the podium inside the same bands", function()
	eq(Config.Phases.Results, 30)
	eq(Voting.showRewards(30, 30), false)
	eq(Voting.showRewards(21, 30), false)
	eq(Voting.showRewards(20, 30), true)
	eq(Voting.showRewards(16, 30), true)
	eq(Voting.showRewards(1, 30), true)
	local voteUi = fs.readFile("src/client/Vote.luau")
	truthy(string.find(voteUi, "showRewards", 1, true) ~= nil)
	truthy(string.find(voteUi, "AwardCoins", 1, true) ~= nil)
	truthy(string.find(voteUi, "RewardCard", 1, true) ~= nil)
	truthy(string.find(voteUi, "AutomaticSize", 1, true) ~= nil)
	truthy(string.find(voteUi, "LevelUp", 1, true) ~= nil)
	truthy(string.find(voteUi, "DisplayName", 1, true) == nil)
	local tray = fs.readFile("src/client/Tray.luau")
	truthy(string.find(tray, "Lv ", 1, true) ~= nil)
	truthy(string.find(tray, "Levels.gate", 1, true) ~= nil)
	for _, height in ipairs({ 420, 800 }) do
		local bands = UIKit.bands(height)
		local top = bands.reveal.top
		local bottom = bands.tray.bottom
		truthy(top >= bands.board.bottom + 4, "reward " .. tostring(height))
		truthy(bottom <= bands.done.top - 4, "reward button " .. tostring(height))
		truthy(bottom - top >= 120, "reward room " .. tostring(height))
	end
end)

print("Shop")
test("crate odds sum to 100 and the display uses those odds", function()
	local function nameOf(id)
		return Items.get(id).name
	end
	local base = Crates.rows(false)
	local rain = Crates.rows(true)
	eq(Crates.total(base), 100)
	eq(Crates.total(rain), 100)
	eq(base[1].percent == rain[1].percent, false)
	local shown = Crates.display(base, nameOf)
	local rainShown = Crates.display(rain, nameOf)
	eq(shown == rainShown, false)
	for _, row in ipairs(base) do
		truthy(string.find(shown, tostring(row.percent) .. "%", 1, true) ~= nil, row.itemId)
	end
	for _, row in ipairs(rain) do
		truthy(string.find(rainShown, tostring(row.percent) .. "%", 1, true) ~= nil, row.itemId)
	end
	local function at(sample)
		return function()
			return sample
		end
	end
	eq(Crates.roll(base, at(0.20)), "sleigh_bell")
	eq(Crates.roll(rain, at(0.20)), "nutcracker_stand")
end)

test("a receipt grants once, duplicates become coins, and a failed save grants nothing", function()
	local profile = Save.blankProfile()
	local ctx = {
		rng = function()
			return 0
		end,
		restricted = false,
		raining = false,
		level = 1,
	}
	local first, result = Shop.grant(profile, "DecorCrate", "receipt-1", ctx)
	eq(result.ok, true)
	eq(result.duplicate, false)
	eq(result.itemId, "sleigh_bell")
	eq(Save.hasId(first.owned, "sleigh_bell"), true)
	eq(profile.coins, 0)
	eq(Save.hasId(profile.receipts, "receipt-1"), false)
	local again, dup = Shop.grant(first, "DecorCrate", "receipt-1", {
		rng = function()
			error("rolled twice")
		end,
	})
	eq(dup.duplicate, true)
	eq(again.coins, first.coins)
	eq(#again.owned, 1)
	local second, rolled = Shop.grant(first, "DecorCrate", "receipt-2", ctx)
	eq(rolled.duplicate, true)
	eq(second.coins, Config.Shop.DuplicateCoins)
	eq(#second.owned, 1)
	local third, same = Shop.grant(second, "DecorCrate", "receipt-2", ctx)
	eq(same.duplicate, true)
	eq(third.coins, second.coins)
	local kept, failed = Shop.commit(profile, "DecorCrate", "receipt-9", ctx, function()
		return false
	end)
	eq(failed.ok, false)
	eq(Save.hasId(kept.receipts, "receipt-9"), false)
	eq(kept.coins, 0)
	local stored = nil
	local saved, ok = Shop.commit(profile, "DecorCrate", "receipt-9", ctx, function(doc)
		stored = doc
		return true
	end)
	eq(ok.ok, true)
	eq(stored, saved)
	eq(Save.hasId(saved.receipts, "receipt-9"), true)
	eq(Shop.keyForId(0, "product"), nil)
	eq(Shop.canPrompt({ id = 0, random = true }, { hold = true, phase = "Lobby", policyOk = true }), false)
	eq(Shop.canPrompt({ id = 9, random = true }, { hold = false, phase = "Lobby", policyOk = true }), false)
	eq(Shop.canPrompt({ id = 9, random = true }, { hold = true, phase = "Tour", policyOk = true }), false)
	eq(Shop.canPrompt({ id = 9, random = true }, { hold = true, phase = "Lobby", policyOk = false }), false)
	eq(Shop.canPrompt({ id = 9, random = true }, { hold = true, phase = "Lobby", policyOk = true }), true)
	eq(Shop.canPrompt({ id = 9, random = true }, { hold = true, phase = "Lobby", policyOk = true, restricted = true }), false)
end)

test("restricted players get the fixed set and Decor Rain changes the roll", function()
	local called = false
	local fixed, result = Shop.grant(Save.blankProfile(), "DecorCrate", "fall-1", {
		restricted = true,
		level = 1,
		rng = function()
			called = true
			return 0.99
		end,
	})
	eq(called, false)
	eq(result.fallback, true)
	for _, id in ipairs(Crates.fallback()) do
		eq(Save.hasId(fixed.owned, id), true)
	end
	local repeatGrant, dup = Shop.grant(fixed, "DecorCrate", "fall-1", { restricted = true, level = 1 })
	eq(dup.duplicate, true)
	eq(repeatGrant.coins, fixed.coins)
	local rainy, rainResult = Shop.grant(Save.blankProfile(), "DecorCrate", "rain-1", {
		restricted = false,
		raining = true,
		level = 1,
		rng = function()
			return 0.20
		end,
	})
	eq(rainResult.itemId, "nutcracker_stand")
	eq(Save.hasId(rainy.owned, "nutcracker_stand"), true)
	local plain = Crates.roll(Crates.rows(false), function()
		return 0.20
	end)
	eq(plain, "sleigh_bell")
	eq(plain == rainResult.itemId, false)
end)

test("extra time stops at two per round and a refused minute still saves", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.advance(state, 25)
	eq(state.phase, "Build")
	eq(state.phaseEndsAt, 265)
	eq(RoundEngine.extend(state, Config.Shop.TimeBonus, Config.Shop.TimeCap), true)
	eq(RoundEngine.extend(state, Config.Shop.TimeBonus, Config.Shop.TimeCap), true)
	local denied, why = RoundEngine.extend(state, Config.Shop.TimeBonus, Config.Shop.TimeCap)
	eq(denied, false)
	eq(why, "This round already has two extra minutes.")
	eq(state.phaseEndsAt, 265 + Config.Shop.TimeBonus * 2)
	local lobby = fresh()
	RoundEngine.join(lobby, "mike", 0)
	eq(RoundEngine.extend(lobby, 60, 2), true)
	eq(RoundEngine.extend(lobby, 60, 2), true)
	eq(lobby.bankedTime, 120)
	RoundEngine.advance(lobby, 25)
	eq(lobby.phase, "Build")
	eq(lobby.phaseEndsAt, 25 + Config.Phases.Build + 120)
	eq(RoundEngine.extend(lobby, 60, 2), false)
	local profile = Save.blankProfile()
	local paid, result = Shop.grant(profile, "ExtraMinute", "time-1", {
		extend = function()
			return false
		end,
	})
	eq(result.ok, true)
	eq(result.extended, false)
	eq(paid.coins, Config.Shop.TimeFallbackCoins)
	local twice, dup = Shop.grant(paid, "ExtraMinute", "time-1", {
		extend = function()
			return true
		end,
	})
	eq(dup.duplicate, true)
	eq(twice.coins, paid.coins)
end)

test("2x coins pays once and a second pass does not stack", function()
	Monetization.reset()
	local profile = Save.blankProfile()
	local once, added = Shop.grantPass(profile, "DoubleCoins")
	eq(added, true)
	eq(Shop.multiplier(once), 2)
	local twice, again = Shop.grantPass(once, "DoubleCoins")
	eq(again, false)
	eq(Shop.multiplier(twice), 2)
	local input = {
		roundId = "boost:1",
		rank = 1,
		average = 0,
		podium = 0,
		eye = 0,
		userId = "ada",
	}
	local hooks = {
		coinMultiplier = function()
			return Shop.multiplier(twice)
		end,
		luck = function()
			return false
		end,
	}
	local paid = Rewards.grant(twice, input, Config, hooks)
	eq(paid.coins, Config.Rewards.PlaceCoins[1] * 2)
	eq(paid.luck, false)
	local replay = Rewards.grant(twice, input, Config, hooks)
	eq(replay.duplicate, true)
	eq(twice.coins, Config.Rewards.PlaceCoins[1] * 2)
	eq(Shop.multiplier(twice), 2)
end)

test("codes redeem once per player and then slow down", function()
	local limiter = RateLimiter.new(Config.RateLimit.codeBurst, Config.RateLimit.codeRefill)
	local profile = Save.blankProfile()
	local ok, msg = Codes.redeem(profile, "  welcome\n", 0, limiter, "ada", 1)
	eq(ok, true)
	eq(msg, "Code accepted.")
	eq(profile.coins, Config.Shop.Codes.WELCOME.coins)
	local again, againMsg = Codes.redeem(profile, "WELCOME", 0, limiter, "ada", 1)
	eq(again, false)
	eq(againMsg, "Already used.")
	eq(profile.coins, Config.Shop.Codes.WELCOME.coins)
	local glow, glowMsg = Codes.redeem(profile, "glowup", 0, limiter, "ada", 1)
	eq(glow, true)
	eq(glowMsg, "Code accepted.")
	eq(Save.hasId(profile.owned, Config.Shop.Codes.GLOWUP.itemId), true)
	local unknown, unknownMsg = Codes.redeem(profile, "NOPE", 0, limiter, "ada", 1)
	eq(unknown, false)
	eq(unknownMsg, "That code is not active.")
	local limited, limitedMsg = Codes.redeem(profile, "NOPE", 0, limiter, "ada", 1)
	eq(limited, false)
	eq(limitedMsg, "Slow down a moment.")
	eq(#profile.codes, 2)
end)

test("Family Night themes stay on the server allowlist", function()
	eq(Host.price, 0)
	eq(Host.pick("hearth_cocoa", true, true), true)
	eq(Host.allowed("hearth_cocoa"), true)
	local denied, why = Host.pick("tinsel_topper", true, true)
	eq(denied, false)
	eq(why, "That theme is not on the Family Night list.")
	eq(ThemePicker.find(Themes, "tinsel_topper") ~= nil, true)
	eq(Host.pick("hearth_cocoa", false, true), false)
	eq(Host.pick("hearth_cocoa", true, false), false)
	eq(Host.pick("not-a-theme", true, true), false)
	local group = Duo.create()
	eq(Duo.setAll(group, { "ada", "bea" }, "Build", true), false)
	eq(Duo.setAll(group, { "ada", "bea" }, "Lobby", true), true)
	eq(group.opted.ada, true)
	eq(group.opted.bea, true)
	eq(Duo.setAll(group, { "ada", "bea" }, "Lobby", false), true)
	eq(group.opted.ada, nil)
	for _, row in ipairs(Shop.list()) do
		eq(row.id, 0)
		eq(row.price >= 1, true)
		eq(row.votes, nil)
		eq(row.stars, nil)
		eq(row.budget, nil)
	end
	local plan = ShopSync.plan(ShopSync.items(Config.Shop), { pass = {}, product = {} })
	eq(#plan.problems, 0)
	eq(#plan.create, #ShopSync.items(Config.Shop))
end)

test("the design pass and dream slots do not skip unlocks or raise the 36 cap", function()
	local profile = Save.blankProfile()
	local started, opened = Shop.grant(profile, "DesignPass", "pass-1", { now = 5000, level = 1 })
	eq(opened.pass, true)
	eq(started.xp, 0)
	local nextLine = Levels.next(1)
	eq(Shop.claimPass(started, 5000 + 6 * 86400), 7)
	eq(started.xp, 0)
	eq(Levels.next(1), nextLine)
	eq(Levels.owns("carol_piano", 1), false)
	eq(Save.hasId(started.owned, "carol_piano"), true)
	local vip, added = Shop.grantPass(Save.blankProfile(), "VIP")
	eq(added, true)
	eq(Shop.extraSlots(vip), 1)
	local wing, slot = Shop.grant(vip, "DreamWing", "wing-1", {})
	eq(slot.slots, 3)
	eq(Shop.extraSlots(wing), 3)
	eq(Config.Shop.Products.DreamNook.slots, 1)
	eq(Config.Shop.Products.DreamWing.slots, 2)
	eq(Dream.cap(Config.Progress.HouseLevel), Config.Progress.HouseItems)
	eq(Save.MaxDreamPieces, 36)
	eq(Config.Progress.HouseItems, 36)
	local room = Placement.empty()
	local locked = buildCtx({ tools = false, materials = Config.Shop.Materials })
	eq(Placement.place(room, locked, "cocoa_mug", 0, 0), true)
	eq(Placement.paint(room, locked, "wall", "mint"), false)
	eq(Placement.finish(room, locked, 1, "Wood"), false)
	locked.tools = true
	eq(Placement.paint(room, locked, "wall", "mint"), true)
	eq(Placement.paint(room, locked, "roof", "coral"), true)
	eq(Placement.finish(room, locked, 1, "Wood"), true)
	eq(room.pieces[1].material, "Wood")
	local preview = Shop.preview(Items.get("carol_piano"))
	eq(preview.name, "Carol Piano")
	eq(preview.w, 2)
	eq(preview.surface, "floor")
	local fit = Hints.line("hearth_cocoa", Items.list)
	truthy(fit ~= "", "hint lists pieces")
	truthy(string.find(fit, "Cocoa Hearth", 1, true) == nil)
end)

test("quest and rank days follow Central daylight time", function()
	local july = Season.unix(2026, 7, 15, 5, 30, 0)
	eq(Season.centralOffset(july), -5)
	eq(Quests.dayKey(july, Config.TimezoneOffsetHours), "2026-07-14")
	eq(Quests.dayKey(july, Season.centralOffset(july)), "2026-07-15")
	eq(Rank.month(july, Season.centralOffset(july)), "2026-07")
	eq(Season.centralOffset(Season.unix(2026, 1, 15, 18, 0, 0)), -6)
	eq(Season.centralOffset(Season.unix(2026, 3, 8, 7, 59, 0)), -6)
	eq(Season.centralOffset(Season.unix(2026, 3, 8, 8, 0, 0)), -5)
	eq(Season.centralOffset(Season.unix(2026, 11, 1, 6, 59, 0)), -5)
	eq(Season.centralOffset(Season.unix(2026, 11, 1, 7, 0, 0)), -6)
	local old = Save.migrate({ schema = 0, coins = 12, xp = 4 })
	eq(old.schema, 1)
	eq(old.coins, 12)
	local future, err = Save.migrate({ schema = 2, coins = 9 })
	eq(future, nil)
	eq(err, "Schema.")
	local store = Save.memory()
	local key = Save.profileKey("40")
	store.update(key, function()
		return { schema = 0, coins = 12 }
	end)
	local opened = Save.open(store, key, "A", 10, 60)
	eq(opened.schema, 1)
	eq(opened.coins, 12)
	local progress = fs.readFile("src/server/Services/ProgressService.luau")
	truthy(string.find(progress, "centralOffset", 1, true) ~= nil)
end)

test("the shop stays in the lobby and does not sell stars, votes, or a bigger room", function()
	local fit = UIKit.shop(420)
	truthy(fit.body >= 160, "shop body " .. tostring(fit.body))
	truthy(fit.tabs >= 44)
	truthy(fit.close >= UIKit.Layout.minButton)
	truthy(fit.bodyTop < fit.bodyBottom)
	local shopUi = fs.readFile("src/client/Shop.luau")
	truthy(string.find(shopUi, "Lobby", 1, true) ~= nil)
	truthy(string.find(shopUi, "VipFrame", 1, true) ~= nil)
	truthy(string.find(shopUi, "RainName", 1, true) ~= nil)
	truthy(string.find(shopUi, "SALE", 1, true) == nil)
	truthy(string.find(string.lower(shopUi), "countdown", 1, true) == nil)
	truthy(string.find(shopUi, "UIKit.shop", 1, true) ~= nil)
	local hud = fs.readFile("src/client/Hud.luau")
	truthy(string.find(hud, "ThemeName", 1, true) ~= nil)
	truthy(string.find(hud, "ThemeHint", 1, true) == nil)
	local tray = fs.readFile("src/client/Tray.luau")
	truthy(string.find(tray, "ThemeHint", 1, true) ~= nil)
	local server = fs.readFile("src/server/Services/ShopService.luau")
	truthy(string.find(server, "ArePaidRandomItemsRestricted", 1, true) ~= nil)
	truthy(string.find(server, "ProcessReceipt", 1, true) ~= nil)
	truthy(string.find(server, "UserOwnsGamePassAsync", 1, true) ~= nil)
	truthy(string.find(server, "bag.hold ~= true", 1, true) ~= nil)
	truthy(string.find(server, "CratePolicy", 1, true) ~= nil)
	truthy(string.find(shopUi, "CratePolicy", 1, true) ~= nil)
	truthy(string.find(shopUi, "Fixed set", 1, true) ~= nil)
	truthy(string.find(server, "PromptProductPurchase", 1, true) ~= nil)
	local logic = fs.readFile("src/shared/Logic/Shop.luau")
	truthy(string.find(logic, "This crate is not available here.", 1, true) ~= nil)
	truthy(string.find(shopUi, "Not available here", 1, true) ~= nil)
	truthy(string.find(shopUi, "CrateOdds", 1, true) ~= nil)
	truthy(string.find(server, "tostring(receipt.PurchaseId)", 1, true) ~= nil)
	truthy(string.find(server, "claimPass(draft", 1, true) ~= nil)
end)

print("Polish")
test("the mini room is server owned and the practice stars stay off the ballot", function()
	local pace = Tutorial.pace()
	eq(pace.duration, 30)
	eq(pace.placeBy, 15)
	truthy(pace.reactionBy <= 25)
	local freshProfile = Save.blankProfile()
	eq(Tutorial.needed(freshProfile), true)
	freshProfile.tutorialDone = true
	eq(Tutorial.needed(freshProfile), false)
	local profile = Save.blankProfile()
	local state = Tutorial.start(100)
	local early = Tutorial.view(state, 110)
	eq(early.line, "")
	eq(early.canSkip, true)
	eq(early.canPlace, true)
	eq(early.record, false)
	eq(Tutorial.place(state, 108), true)
	truthy(108 - state.startedAt <= pace.placeBy)
	local shown = Tutorial.view(state, 100 + pace.reactionBy)
	eq(shown.stars, 4)
	eq(shown.record, false)
	truthy(shown.line ~= "")
	local at25 = Tutorial.view(state, 125)
	eq(at25.stars, 4)
	eq(at25.line, Config.Tutorial.Line)
	local ballot = Voting.create()
	local stats = { props = 0, coins = profile.coins, xp = profile.xp }
	local result = Tutorial.complete(profile, state, ballot, stats, 5)
	eq(result.recorded, false)
	eq(result.stars, 0)
	eq(profile.tutorialDone, true)
	eq(profile.coins, 0)
	eq(profile.xp, 0)
	eq(stats.props, 0)
	eq(next(ballot.rooms), nil)
	local skipped = Tutorial.start(0)
	eq(Tutorial.skip(skipped), true)
	eq(Tutorial.place(skipped, 1), false)
	local fit = UIKit.tutorial(420)
	truthy(fit.hint >= Config.Tutorial.HintMin)
	truthy(fit.hintText >= Config.Tutorial.HintText)
	eq(fit.coversHint, false)
	truthy(fit.hintTop > 420 * 0.45)
	local round = fs.readFile("src/server/Services/FunnelService.luau")
	truthy(string.find(round, "Tutorial.complete", 1, true) ~= nil)
	truthy(string.find(round, "Voting.cast", 1, true) == nil)
	truthy(string.find(round, "never covers", 1, true) ~= nil)
	truthy(string.find(round, "keepLobby", 1, true) ~= nil)
	truthy(string.find(round, "spectating", 1, true) ~= nil)
	local screen = fs.readFile("src/client/Tutorial.luau")
	truthy(string.find(screen, "Place the rug", 1, true) ~= nil)
	truthy(string.find(screen, "Skip", 1, true) ~= nil)
	truthy(string.find(screen, "CardStars", 1, true) == nil)
end)

test("modifiers are picked on the server about one round in three", function()
	local hits = 0
	for index = 0, 29 do
		if Modifiers.pick(index) ~= nil then
			hits += 1
		end
	end
	eq(hits, 10)
	eq(Modifiers.pick(0), nil)
	eq(Modifiers.pick(1), nil)
	eq(Modifiers.pick(2), "speed")
	eq(Modifiers.pick(5), "tiny")
	eq(Modifiers.pick(8), "mystery")
	eq(Modifiers.pick(11), "mirror")
	eq(Modifiers.announce("speed", "Lobby"), "")
	eq(Modifiers.announce("speed", "ThemeReveal"), "Speed Round")
	local state = fresh()
	RoundEngine.join(state, "ada", 0)
	state.modifier = "speed"
	RoundEngine.advance(state, 25)
	eq(state.phase, "Build")
	eq(state.phaseEndsAt, 25 + Config.Modifiers.SpeedBuild)
	local blocked, why = RoundEngine.extend(state, Config.Shop.TimeBonus, Config.Shop.TimeCap)
	eq(blocked, false)
	eq(why, "Speed Round keeps its clock.")
	eq(state.phaseEndsAt, 25 + Config.Modifiers.SpeedBuild)
	eq(Shop.canPrompt({ id = 9, time = true }, { hold = true, phase = "Lobby", policyOk = true, speed = true }), false)
	local paid, grant = Shop.grant(Save.blankProfile(), "ExtraMinute", "speed-time", {
		extend = function()
			return false
		end,
	})
	eq(grant.extended, false)
	eq(paid.coins, Config.Shop.TimeFallbackCoins)
	local normal = fresh()
	RoundEngine.join(normal, "ada", 0)
	RoundEngine.advance(normal, 25)
	eq(normal.phaseEndsAt, 265)
	eq(RoundEngine.extend(normal, Config.Shop.TimeBonus, Config.Shop.TimeCap), true)
end)

test("tiny budget still lets a new player place, and mystery is a free piece", function()
	eq(Modifiers.budget(Config.Budget, "tiny", 4) >= 4, true)
	eq(Modifiers.budget(Config.Budget, "tiny", 40), 40)
	eq(Modifiers.budget(Config.Budget, nil, 4), Config.Budget)
	local room = Placement.empty()
	local tiny = placeCtx({ budget = Modifiers.budget(Config.Budget, "tiny", 4) })
	eq(Placement.place(room, tiny, "dot_rug", 0, 0), true)
	eq(room.pieces[1].cost, 4)
	local mysteryId = Modifiers.mystery("room", 0)
	truthy(Items.get(mysteryId) ~= nil)
	eq(Config.Modifiers.Paid, false)
	local freeRoom = Placement.empty()
	local freeCtx = placeCtx({ budget = 0, freeItem = mysteryId })
	eq(Placement.place(freeRoom, freeCtx, mysteryId, 0, 0), true)
	eq(freeRoom.pieces[1].cost, 0)
	eq(freeRoom.spent, 0)
	eq(Placement.place(freeRoom, freeCtx, mysteryId, 2, 0), false)
	local modifierSource = fs.readFile("src/shared/Logic/Modifiers.luau")
	truthy(string.find(modifierSource, "Crates", 1, true) == nil)
	local engine = fs.readFile("src/shared/Logic/RoundEngine.luau")
	truthy(string.find(engine, "Modifiers.pick", 1, true) ~= nil)
	local remote = fs.readFile("src/server/Services/RoundService.luau")
	truthy(string.find(remote, "SetModifier", 1, true) == nil)
end)

test("mirror duo tour copy does not include names", function()
	local names = { "Jordan", "Auntie Mae" }
	local line = Modifiers.tourLine(1, 2, names)
	eq(line, "Room 1 of 2")
	eq(Modifiers.leaks(line, names), false)
	local state = fresh()
	RoundEngine.join(state, "ada", 0)
	state.modifier = "mirror"
	RoundEngine.advance(state, 25)
	eq(RoundEngine.pressDone(state, "ada", 25), true)
	local snap = RoundEngine.snapshot(state, 25)
	eq(snap.modifier, "mirror")
	eq(snap.modifierLabel, "Mirror Duo")
	eq(Modifiers.leaks(snap.tourLabel, { "ada", "Jordan", "Auntie Mae" }), false)
	eq(string.find(snap.tourLabel, "ada", 1, true), nil)
	local group = Duo.create()
	Duo.pairAll(group, { "ada", "bea", "cam" })
	eq(Duo.paired(group, "ada"), true)
	eq(Duo.paired(group, "bea"), true)
	eq(Duo.partnerOf(group, "ada"), "bea")
	eq(Duo.paired(group, "cam"), false)
	local progress = fs.readFile("src/server/Services/ProgressService.luau")
	truthy(string.find(progress, "pairAll", 1, true) ~= nil)
	truthy(string.find(progress, "DisplayName", 1, true) == nil)
	eq(Voting.signLabel("Tour", 2, "Jordan"), "Room 2")
end)

test("spot the theme pays a little, after the podium, and sells no time", function()
	eq(Spot.sellsTime(), false)
	eq(Config.Spot.SellsTime, false)
	eq(Spot.visible("Results", ""), false)
	eq(Spot.visible("Tour", "1|ada|Ada|4|hi"), false)
	eq(Spot.visible("Results", "1|ada|Ada|4|hi"), true)
	local options = Spot.deal("hearth_cocoa", Themes, 1)
	eq(#options, 3)
	local found = false
	for _, row in ipairs(options) do
		if row.id == "hearth_cocoa" then
			found = true
		end
	end
	eq(found, true)
	local encoded = Spot.encode(options)
	eq(#Spot.decode(encoded), 3)
	eq(Spot.grade("hearth_cocoa", "hearth_cocoa"), true)
	eq(Spot.grade("frosted_window", "hearth_cocoa"), false)
	local profile = Save.blankProfile()
	eq(Spot.pay(profile, "0:hearth_cocoa", true), Config.Spot.Coins)
	eq(profile.coins, Config.Spot.Coins)
	eq(Spot.pay(profile, "0:hearth_cocoa", true), 0)
	eq(profile.coins, Config.Spot.Coins)
	local skipped = Save.blankProfile()
	eq(Spot.pay(skipped, "0:hearth_cocoa", false), 0)
	eq(skipped.coins, 0)
	eq(Spot.pay(skipped, "0:hearth_cocoa", true), 0)
	local fit = UIKit.spot(420)
	eq(fit.coversNames, false)
	truthy(fit.top >= fit.podium)
	for _, row in ipairs(Shop.list()) do
		eq(row.name == "Spot the Theme", false)
	end
	local spotUi = fs.readFile("src/client/SpotGame.luau")
	truthy(string.find(spotUi, "Skip", 1, true) ~= nil)
	truthy(string.find(spotUi, "SpotChoices", 1, true) ~= nil)
	local voteUi = fs.readFile("src/client/Vote.luau")
	truthy(string.find(voteUi, "SpotPanel", 1, true) ~= nil)
end)

test("audio, low-end, and the funnel stay out of the way", function()
	eq(Audio.onHud, false)
	eq(Audio.volume(true, 1, 0.5), 0)
	eq(Audio.volume(false, 0.5, 0.4), 0.2)
	truthy(Audio.particles(10, true) < Audio.particles(10, false))
	eq(LowEnd.auto(2), true)
	eq(LowEnd.auto(8), false)
	eq(LowEnd.resolve("on", false), true)
	eq(LowEnd.resolve("off", true), false)
	eq(LowEnd.resolve("auto", true), true)
	eq(LowEnd.pieceCap(48), 36)
	eq(LowEnd.pieceCap(16), 16)
	eq(Config.MaxItems, 16)
	eq(Config.Progress.HouseItems, 36)
	local tour = LowEnd.tour(10, true)
	eq(tour.rooms, 10)
	eq(tour.lights, false)
	eq(tour.shadows, false)
	eq(tour.tween, 0)
	truthy(tour.particles < LowEnd.tour(10, false).particles)
	local profile = Save.blankProfile()
	eq(Analytics.mark(profile, "joined"), true)
	eq(Analytics.mark(profile, "joined"), false)
	eq(Analytics.step("shop_opened"), 7)
	local clean = Analytics.sanitize({ round = 1, name = "Ada", email = "a@b.c", username = "ada" })
	eq(clean.round, 1)
	eq(clean.name, nil)
	eq(clean.email, nil)
	eq(clean.username, nil)
	eq(Analytics.emit(function()
		error("analytics down")
	end), false)
	eq(Analytics.play(function()
		error("analytics down")
	end), true)
	local funnel = fs.readFile("src/server/Services/FunnelService.luau")
	truthy(string.find(funnel, "LogFunnelStepEvent", 1, true) ~= nil)
	truthy(string.find(funnel, "LogCustomEvent", 1, true) ~= nil)
	truthy(string.find(funnel, "Analytics.play", 1, true) ~= nil)
	truthy(string.find(funnel, ".Name", 1, true) == nil)
	local juice = fs.readFile("src/client/Juice.luau")
	truthy(string.find(juice, "Workspace", 1, true) ~= nil)
	truthy(string.find(juice, "PlayerGui", 1, true) == nil)
	truthy(string.find(juice, "Muted", 1, true) ~= nil)
	local settings = fs.readFile("src/client/Settings.luau")
	truthy(string.find(settings, "Mute", 1, true) ~= nil)
	truthy(string.find(settings, "LowEnd", 1, true) ~= nil)
end)

test("pibble and unc are free, and Dream Wing adds two homes", function()
	local pibble = Items.get("pibble_rug")
	local unc = Items.get("unc_chair")
	eq(pibble.name, "Pibble Rug")
	eq(pibble.surface, "floor")
	eq(unc.name, "Unc Armchair")
	eq(unc.shape, "recliner")
	eq(Levels.owns("pibble_rug", 1), false)
	eq(Levels.owns("unc_chair", 1), false)
	local profile = Save.blankProfile()
	eq(Save.hasId(profile.owned, "pibble_rug"), false)
	for _ = 1, Config.Easter.PibbleRugs do
		Easter.note(profile, { category = "Rugs" }, 1)
	end
	eq(Save.hasId(profile.owned, "pibble_rug"), true)
	eq(Save.hasId(profile.owned, "unc_chair"), false)
	Easter.grant(Save.blankProfile(), Config.Easter.UncLevel)
	local leveled = Save.blankProfile()
	Easter.grant(leveled, Config.Easter.UncLevel)
	eq(Save.hasId(leveled.owned, "unc_chair"), true)
	eq(Save.hasId(leveled.owned, "pibble_rug"), true)
	eq(Easter.crateOnly(), false)
	for _, row in ipairs(Crates.rows(false)) do
		eq(row.itemId == "pibble_rug", false)
		eq(row.itemId == "unc_chair", false)
	end
	for _, row in ipairs(Crates.rows(true)) do
		eq(row.itemId == "pibble_rug", false)
		eq(row.itemId == "unc_chair", false)
	end
	local pibbleLine = Easter.line({ "pibble_rug" })
	local uncLine = Easter.line({ "unc_chair" })
	truthy(string.find(pibbleLine, "pit-bull", 1, true) ~= nil)
	truthy(string.find(uncLine, "reading glasses", 1, true) ~= nil)
	local facts = { meter = 80, unique = 6, pieces = 8, maxItems = 16, itemIds = { "pibble_rug" } }
	local stars = Voting.critic(facts, Config)
	local ballot = Voting.create()
	Voting.cast(ballot, "judge", "ada", 4, {
		phase = "Tour",
		locked = false,
		tourTarget = "ada",
		role = "spectator",
		ownerPresent = true,
		voterCount = 2,
	}, Config)
	local rows = Voting.finalize(ballot, { ada = facts }, { ada = true }, Config)
	eq(rows[1].criticStars, stars)
	eq(rows[1].comment, pibbleLine)
	local nook = Save.blankProfile()
	local nookProfile, nookGrant = Shop.grant(nook, "DreamNook", "nook-2", {})
	eq(nookGrant.slots, 1)
	eq(Shop.extraSlots(nookProfile), 1)
	local both, wingGrant = Shop.grant(nookProfile, "DreamWing", "wing-2", {})
	eq(wingGrant.slots, 3)
	eq(Shop.extraSlots(both), 3)
	eq(Dream.cap(Config.Progress.HouseLevel), 36)
	truthy(string.find(Config.Shop.Products.DreamWing.desc, "Two extra", 1, true) ~= nil)
	truthy(string.find(Config.Shop.Products.DreamNook.desc, "One extra", 1, true) ~= nil)
	local restored = Save.normalizeProfile({
		schema = 1,
		coins = 3,
		tutorialDone = true,
		funnel = { "joined" },
		rugPlaces = 2,
	})
	eq(restored.tutorialDone, true)
	eq(restored.funnel[1], "joined")
	eq(restored.rugPlaces, 2)
	local progressSource = fs.readFile("src/server/Services/ProgressService.luau")
	truthy(string.find(progressSource, "Easter.grant", 1, true) ~= nil)
	local roomSource = fs.readFile("src/server/Services/RoomService.luau")
	truthy(string.find(roomSource, "Easter.note", 1, true) ~= nil)
	truthy(string.find(roomSource, "saves.queue", 1, true) ~= nil)
end)

-- Headless playtest regressions. These boot the real server scripts on the
-- fake Roblox in playtest/World.luau and drive them through the Action remote.
local World = require("../playtest/World")

local function server(options)
	local opts = options or {}
	opts.root = "."
	return World.new(opts):boot()
end

local function stepFor(world, seconds)
	local n = math.floor(seconds / 0.1 + 0.5)
	for _ = 1, n do
		world:step(0.1)
	end
end

local function untilPhase(world, phase, cap)
	local limit = world.clock + (cap or 600)
	while world.ctx.round.phase ~= phase and world.clock < limit do
		world:step(0.1)
	end
	eq(world.ctx.round.phase, phase, "reached " .. phase)
end

local function noErrors(world)
	for _, e in ipairs(world.log.error) do
		error("server error: " .. e.msg, 2)
	end
	for _, e in ipairs(world.log.warn) do
		error("server warning: " .. e.msg, 2)
	end
end

test("playtest: a leave on the last tour stop still pays everyone else", function()
	local world = server()
	local a = world:addPlayer("aa_kid", "Aaa")
	local b = world:addPlayer("bb_kid", "Bbb")
	world:invoke(a, "TutorialSkip")
	world:invoke(b, "TutorialSkip")
	untilPhase(world, "Build")
	stepFor(world, 10)
	world:invoke(a, "Place", "mint_pouf", 1, 1)
	stepFor(world, 10)
	world:invoke(b, "Place", "mint_pouf", 2, 2)
	stepFor(world, 10)
	world:invoke(a, "Done")
	stepFor(world, 1)
	world:invoke(b, "Done")
	stepFor(world, 1)
	local round = world.ctx.round
	eq(round.phase, "Tour")
	eq(#round.tourStops, 2)
	while round.tourIndex < #round.tourStops do
		world:step(0.1)
	end
	stepFor(world, 2)
	local last = round.tourStops[#round.tourStops]
	local leaver = if last == tostring(a.UserId) then a else b
	local stayer = if leaver == a then b else a
	world:removePlayer(leaver)
	-- The round jumps to Results inside the leave, between heartbeats.
	eq(round.phase, "Results")
	stepFor(world, 1)
	truthy(type(stayer:GetAttribute("AwardCoins")) == "number", "stayer was paid")
	local podium = world.game:GetService("ReplicatedStorage").RoundState:GetAttribute("Podium")
	truthy(type(podium) == "string" and podium ~= "", "podium shown")
	noErrors(world)
end)

test("playtest: placing a piece does not hold the next tap behind a save", function()
	local world = server()
	local kid = world:addPlayer("tapper", "Tapper")
	world:invoke(kid, "TutorialSkip")
	untilPhase(world, "Build")
	stepFor(world, 8)
	local results = {}
	for i, spot in ipairs({ { 0, 0 }, { 2, 0 }, { 4, 0 }, { 0, 2 } }) do
		local payload, status = world:invoke(kid, "Place", "mint_pouf", spot[1], spot[2])
		eq(status, "done", "tap " .. i .. " answered at once")
		results[i] = payload
		stepFor(world, 0.3)
	end
	for i, payload in ipairs(results) do
		eq(payload.ok, true, "tap " .. i .. " placed")
	end
	noErrors(world)
end)

test("playtest: a save lock waits for the other writer instead of dropping it", function()
	local waits = 0
	local lock = Save.locker(function(_seconds)
		waits += 1
		coroutine.yield()
	end, 5)
	local order = {}
	local first = coroutine.create(function()
		lock.run(function()
			table.insert(order, "first")
			coroutine.yield()
			return true
		end)
	end)
	local second = coroutine.create(function()
		local ok = lock.run(function()
			table.insert(order, "second")
			return true
		end)
		table.insert(order, if ok then "second ok" else "second dropped")
	end)
	coroutine.resume(first)
	coroutine.resume(second)
	eq(#order, 1)
	coroutine.resume(first)
	coroutine.resume(second)
	eq(order[2], "second")
	eq(order[3], "second ok")
	truthy(waits >= 1)
	-- Same-thread nesting still refuses rather than waiting on itself.
	local nested = "unset"
	lock.run(function()
		nested = lock.run(function()
			return "inner"
		end)
		return true
	end)
	eq(nested, nil)
end)

test("playtest: leaving right after a save still writes and frees the lock", function()
	local store = {}
	local world = server({ datastore = store })
	local kid = world:addPlayer("leaver", "Leaver")
	stepFor(world, 1)
	local key = tostring(kid.UserId)
	local bag = world.ctx.saves.session(key)
	eq(bag.hold, true)
	-- A write is in flight, then coins change and the kid leaves.
	world:spawn("apply", function()
		world.ctx.saves.apply(key, bag.profile)
	end)
	world.ctx.saves.session(key).profile.coins += 77
	world:removePlayer(kid)
	stepFor(world, 30)
	local doc = nil
	for k, v in pairs(store[Config.Progress.ProfileStore]) do
		if string.find(k, key, 1, true) then
			doc = v
		end
	end
	truthy(doc ~= nil, "profile stored")
	eq(doc.coins, 77)
	truthy(doc.lock == nil or doc.lock.session == nil, "lock released")
	noErrors(world)
end)

test("playtest: saving the live profile keeps changes made during the write", function()
	local world = server()
	local kid = world:addPlayer("keeper", "Keeper")
	stepFor(world, 1)
	local key = tostring(kid.UserId)
	local bag = world.ctx.saves.session(key)
	local live = bag.profile
	local done = false
	world:spawn("apply", function()
		world.ctx.saves.apply(key, live)
		done = true
	end)
	live.coins += 5
	stepFor(world, 15)
	truthy(done, "write finished")
	eq(world.ctx.saves.session(key).profile, live)
	eq(world.ctx.saves.session(key).profile.coins, 5)
end)

test("playtest: results pay every kid before any save finishes", function()
	local world = server()
	local kids = {}
	for i = 1, 10 do
		local kid = world:addPlayer("kid" .. i, "Kid" .. i)
		world:invoke(kid, "TutorialSkip")
		table.insert(kids, kid)
	end
	untilPhase(world, "Build")
	stepFor(world, 5)
	for i, kid in ipairs(kids) do
		world:invoke(kid, "Place", "mint_pouf", i % 6, 0)
	end
	stepFor(world, 10)
	for _, kid in ipairs(kids) do
		world:invoke(kid, "Done")
	end
	untilPhase(world, "Results")
	-- One heartbeat after Results starts. The podium is up. Spot waits until second 10.
	world:step(0.1)
	for i, kid in ipairs(kids) do
		truthy(type(kid:GetAttribute("AwardCoins")) == "number", "kid " .. i .. " sees coins")
	end
	local folder = world.game:GetService("ReplicatedStorage").RoundState
	local early = folder:GetAttribute("SpotChoices")
	eq(early == nil or early == "", true)
	stepFor(world, 10)
	local spot = folder:GetAttribute("SpotChoices")
	truthy(type(spot) == "string" and spot ~= "", "Spot the Theme dealt")
	noErrors(world)
end)

test("playtest: a first-time kid gets the Mini Room as soon as the save loads", function()
	local world = server()
	local kid = world:addPlayer("brand_new", "Newbie")
	stepFor(world, 1)
	-- Roblox spaces writes to one key about 6 s apart. The join mark must not
	-- make the Mini Room wait behind that, or the 20 s lobby is too short for it.
	eq(kid:GetAttribute("TutorialActive"), true)
	local payload, status = world:invoke(kid, "TutorialPlace")
	eq(status, "done")
	eq(payload.ok, true)
	noErrors(world)
end)

test("playtest: new kids arriving cannot hold the lobby open", function()
	local world = server()
	world:addPlayer("first_kid", "First")
	local started = world.clock
	local joined = 1
	while world.ctx.round.phase == "Lobby" and world.clock - started < 300 do
		world:step(0.1)
		if joined < 10 and world.clock - started >= joined * 10 then
			joined += 1
			world:addPlayer("kid" .. joined, "Kid" .. joined)
		end
	end
	local held = world.clock - started
	truthy(held <= Config.Phases.Lobby + Config.Tutorial.Duration + 0.5, "lobby held " .. held .. " s")
end)

print("Look")
test("theme families, part budget, and low-end grade", function()
	local known = { hearth = true, ginger = true, glow = true, winter = true, frost = true }
	for _, theme in ipairs(Themes) do
		local family = Look.family(theme.id)
		truthy(known[family] == true, theme.id .. " " .. family)
		local preset = Look.preset(family)
		truthy(preset.clock > 0, theme.id)
		truthy(preset.bloom > 0, theme.id)
		eq(#Look.swatch(theme.id), 3)
	end
	eq(Look.family("hearth_cocoa"), "hearth")
	eq(Look.family("gumdrop_gable"), "ginger")
	eq(Look.family("tinsel_topper"), "glow")
	eq(Look.family("frosted_window"), "winter")
	eq(Look.family("frosted_fir"), "frost")
	eq(Look.packFor("room", "hearth_cocoa"), "hearth")
	eq(Look.packFor("gingerbread", nil), "ginger")
	eq(Look.Budget.min, 3)
	eq(Look.Budget.max, 10)
	local off = LowEnd.effects(true)
	eq(off.bloom, false)
	eq(off.correction, false)
	eq(off.atmosphere, false)
	eq(off.lights, false)
	eq(off.shadows, false)
	eq(off.technology, "ShadowMap")
	local on = LowEnd.effects(false)
	eq(on.bloom, true)
	eq(on.correction, true)
	eq(on.atmosphere, true)
	eq(on.technology, "Future")
	local stage = fs.readFile("src/client/Stage.luau")
	truthy(string.find(stage, "BloomEffect", 1, true) ~= nil)
	truthy(string.find(stage, "ColorCorrectionEffect", 1, true) ~= nil)
	truthy(string.find(stage, "Atmosphere", 1, true) ~= nil)
	truthy(string.find(stage, "Future", 1, true) ~= nil)
	truthy(string.find(stage, "LowEnd", 1, true) ~= nil)
	local show = fs.readFile("src/client/Show.luau")
	truthy(string.find(show, "Cone", 1, true) ~= nil)
	truthy(string.find(show, "RisingStar", 1, true) ~= nil)
	local podium = fs.readFile("src/client/Podium.luau")
	truthy(string.find(podium, "Results", 1, true) ~= nil)
	truthy(string.find(podium, "DisplayName", 1, true) == nil)
	local plaza = fs.readFile("src/server/Plaza.luau")
	truthy(string.find(plaza, "Auntie Roch", 1, true) == nil)
	truthy(string.find(plaza, "Config.Critic.name", 1, true) ~= nil)
	truthy(string.find(plaza, "Config.Title", 1, true) ~= nil)
	local props = fs.readFile("src/server/Props.luau")
	truthy(string.find(props, "planeZ * 0.15", 1, true) == nil)
	truthy(string.find(props, '"Eave"', 1, true) ~= nil)
	truthy(string.find(props, "planeZ + 0.55", 1, true) ~= nil)
	truthy(string.find(props, "DiagA", 1, true) ~= nil)
	truthy(string.find(props, "DiagB", 1, true) ~= nil)
	truthy(string.find(props, '"Rail"', 1, true) ~= nil)
	truthy(string.find(props, "TopperC", 1, true) ~= nil)
	truthy(string.find(props, "RoofDeck", 1, true) ~= nil)
end)

print("Pace")
test("votes stay open for a second after the visual lock, then the tour hurries", function()
	local state = fresh()
	RoundEngine.join(state, "mike", 0)
	RoundEngine.join(state, "sam", 0)
	RoundEngine.advance(state, 25)
	RoundEngine.pressDone(state, "mike", 30)
	RoundEngine.pressDone(state, "sam", 31)
	local start = 31
	local per = Config.Phases.TourPerRoom
	local lockAt = start + per - Config.Phases.TourLockIn
	eq(RoundEngine.roomLocked(state, lockAt), true)
	eq(RoundEngine.votesClosed(state, lockAt), false)
	eq(RoundEngine.snapshot(state, lockAt).votesOpen, true)
	RoundEngine.hurryTour(state, start + 2)
	eq(state.phaseEndsAt, start + 2 + Config.Phases.TourSkipBeat + per)
	local stops = { state.tourStops[1], state.tourStops[2] }
	table.sort(stops)
	eq(stops[1], "mike")
	eq(stops[2], "sam")
	eq(state.tourStops[1] == "mike" and state.tourStops[2] == "sam", false)
end)

test("a player with no room cannot match a builder on Judge's Eye", function()
	eq(Config.Voting.EyeNoRoomCap < Config.Rewards.PlaceCoins[1], true)
	local state = Voting.create()
	local built = { ada = true }
	for i = 1, 8 do
		local owner = "room" .. tostring(i)
		eq(Voting.cast(state, "idle", owner, 3, openGate(owner), Config), true)
		eq(Voting.cast(state, "ada", owner, 3, openGate(owner), Config), true)
	end
	local facts = {}
	local present = { ada = true }
	for i = 1, 8 do
		local owner = "room" .. tostring(i)
		facts[owner] = { meter = 40, unique = 4, pieces = 8, maxItems = 16 }
		present[owner] = true
	end
	Voting.finalize(state, facts, present, Config, built)
	eq(state.eyeCoins.idle, Config.Voting.EyeNoRoomCap)
	eq(state.eyeCoins.ada, Config.Voting.EyeCoins * 8)
	truthy(state.eyeCoins.ada > state.eyeCoins.idle)
end)

test("reactions are a fixed set, and tray tiles keep a picture fallback", function()
	eq(Voting.reactionIndex(1, #Config.Show.Crowd), true)
	eq(Voting.reactionIndex(#Config.Show.Crowd, #Config.Show.Crowd), true)
	eq(Voting.reactionIndex(0, #Config.Show.Crowd), false)
	eq(Voting.reactionIndex(1.5, #Config.Show.Crowd), false)
	eq(Voting.reactionIndex("clap", #Config.Show.Crowd), false)
	eq(Preview.mode(true, true), "silhouette")
	eq(Preview.mode(false, false), "silhouette")
	eq(Preview.mode(false, true), "viewport")
	eq(Preview.fits({ tags = { "room", "hearth_cocoa" } }, "hearth_cocoa"), true)
	eq(Preview.fits({ tags = { "room", "hearth_cocoa" } }, "paper_star"), false)
	eq(UIKit.Layout.chip >= 44, true)
	eq(UIKit.Text.item >= 16, true)
	eq(UIKit.Text.min >= 18, true)
	eq(Spot.open(9, 10), false)
	eq(Spot.open(10, 10), true)
	local tray = fs.readFile("src/client/Tray.luau")
	truthy(string.find(tray, "ViewportFrame", 1, true) ~= nil)
	truthy(string.find(tray, "Silhouette", 1, true) ~= nil)
	truthy(string.find(tray, "StarFit", 1, true) ~= nil)
	truthy(string.find(tray, "ItemName", 1, true) ~= nil)
	local voteUi = fs.readFile("src/client/Vote.luau")
	truthy(string.find(voteUi, "RewardCard", 1, true) ~= nil)
	truthy(string.find(voteUi, "ResultsRewardsAt", 1, true) ~= nil)
	truthy(string.find(voteUi, "React", 1, true) ~= nil)
	truthy(string.find(voteUi, "Judge's Eye", 1, true) ~= nil)
	local settings = fs.readFile("src/client/Settings.luau")
	truthy(string.find(settings, "Text.min", 1, true) == nil)
	local hud = fs.readFile("src/client/Hud.luau")
	truthy(string.find(hud, "30 seconds left!", 1, true) == nil)
	truthy(string.find(hud, "BuildRush.Banner", 1, true) ~= nil)
	truthy(string.find(hud, "Next round in", 1, true) ~= nil)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
