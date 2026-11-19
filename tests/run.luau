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

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
