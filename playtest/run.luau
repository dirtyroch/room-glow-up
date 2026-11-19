--!nocheck
-- Headless playtest. Boots the real server code on a fake Roblox, plays full
-- rounds with simulated kids, and writes playtest/out/report.json and report.md.
-- Run: lune run playtest/run.luau [--quick] [--seed N]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local World = require("./World")
local Bots = require("./Bots")
local Rng = require("./Rng")
local Config = require("../src/shared/Config")
local Levels = require("../src/shared/Logic/Levels")
local Voting = require("../src/shared/Logic/Voting")
local Save = require("../src/shared/Logic/Save")

local args = process.args
local QUICK = table.find(args, "--quick") ~= nil
local SEED = 7
for i, a in ipairs(args) do
	if a == "--seed" and args[i + 1] then
		SEED = tonumber(args[i + 1]) or SEED
	end
end
math.randomseed(SEED)

local DT = 0.1
-- Mon Dec 14 2026 18:00 UTC, noon in Central. Holiday season themes.
local HOLIDAY_UNIX = 1797357600

local report = {
	seed = SEED,
	sessions = {},
	problems = {},
	leaks = {},
	tutorial = {},
	saves = {},
}

local function problem(kind, detail)
	table.insert(report.problems, { kind = kind, detail = detail })
end

local NAMES = {
	{ "zork_alpha", "Quillon" },
	{ "zork_bravo", "Marzipella" },
	{ "zork_charl", "Tobiwan" },
	{ "zork_delta", "Fizzbeth" },
	{ "zork_echoo", "Grumbleton" },
	{ "zork_foxtr", "Pippalou" },
	{ "zork_golff", "Wexley" },
	{ "zork_hotel", "Brindlemae" },
	{ "zork_india", "Snorkeline" },
	{ "zork_julie", "Velvetine" },
	{ "zork_kilo", "Orbisha" },
	{ "zork_limaa", "Cobbleworth" },
}

------------------------------------------------------------------ one server

local function expectedSpan(phase, round, stops)
	local P = Config.Phases
	if phase == "Lobby" then
		return P.Lobby
	elseif phase == "ThemeReveal" then
		return P.ThemeReveal
	elseif phase == "Build" then
		return if round.modifier == "speed" then Config.Modifiers.SpeedBuild else P.Build
	elseif phase == "Tour" then
		return P.TourPerRoom * stops
	elseif phase == "Results" then
		return P.Results
	end
	return 0
end

local function session(opts)
	local world = World.new({
		root = ".",
		unix0 = opts.unix0 or HOLIDAY_UNIX,
		datastore = opts.datastore,
		jobId = opts.jobId or ("job-" .. opts.name),
	}):boot()
	local rng = Rng.new(opts.seed or SEED)
	local out = {
		name = opts.name,
		rounds = {},
		errors = {},
		stuck = {},
		bots = {},
		prompts = 0,
	}
	local ctx = world.ctx
	if not ctx or not ctx.round then
		problem("boot", opts.name .. ": server ctx missing")
		return out, world
	end
	for _, list in ipairs({ "error", "warn" }) do
		for _, e in ipairs(world.log[list]) do
			problem("boot-" .. list, e.msg)
		end
	end

	local bots = {}
	local byKey = {}
	for i, spec in ipairs(opts.bots) do
		local pair = NAMES[i]
		spec.name = spec.name or pair[1]
		spec.display = spec.display or pair[2]
		local bot = Bots.new(world, rng, spec)
		table.insert(bots, bot)
	end

	local function allNames()
		local list = {}
		for _, bot in ipairs(bots) do
			table.insert(list, bot.name)
			table.insert(list, bot.display)
			if bot.userId then
				table.insert(list, tostring(bot.userId))
			end
		end
		return list
	end

	local function leakCheck(where, text)
		if type(text) ~= "string" or text == "" then
			return
		end
		local hay = string.lower(text)
		for _, name in ipairs(allNames()) do
			if string.find(hay, string.lower(name), 1, true) then
				table.insert(report.leaks, {
					session = opts.name,
					round = ctx.round.roundIndex,
					where = where,
					value = text,
					name = name,
				})
				return
			end
		end
	end

	-- Every replicated attribute change during the tour is checked for names.
	table.insert(world.attrWatchers, function(inst, attr, value)
		if ctx.round.phase ~= "Tour" then
			return
		end
		if type(value) ~= "string" then
			return
		end
		leakCheck(inst:GetFullName() .. "@" .. attr, value)
	end)

	local function scanWorkspace()
		for _, d in ipairs(world.workspace:GetDescendants()) do
			local text = rawget(d, "_props").Text
			if type(text) == "string" then
				leakCheck(d:GetFullName() .. ".Text", text)
			end
			for k, v in pairs(d:GetAttributes()) do
				if type(v) == "string" then
					leakCheck(d:GetFullName() .. "@" .. k, v)
				end
			end
		end
		local folder = world.game:GetService("ReplicatedStorage"):FindFirstChild("RoundState")
		for k, v in pairs(folder:GetAttributes()) do
			leakCheck("RoundState@" .. k, v)
		end
	end

	local roundNo = 0
	local lastPhase = ctx.round.phase
	local phaseStart = world.clock
	local current = nil
	local roundsWanted = opts.rounds
	local limit = opts.limit or (roundsWanted * 520 + 120)
	local lastTourIndex = 0

	-- How long after Results starts each kid sees their coins, and the minigame.
	table.insert(world.attrWatchers, function(inst, attr, value)
		if not current or ctx.round.phase ~= "Results" and attr ~= "AwardCoins" then
			return
		end
		if attr == "AwardCoins" and type(value) == "number" then
			current.awardLag = current.awardLag or {}
			table.insert(current.awardLag, { at = world.clock - (current.resultsAt or world.clock), phase = ctx.round.phase })
		elseif attr == "SpotChoices" and type(value) == "string" and value ~= "" then
			current.spotLag = world.clock - (current.resultsAt or world.clock)
		end
	end)

	local function bump(bot, event)
		for _, spec in ipairs({ bot.spec }) do
			if spec[event] then
				return spec[event]
			end
		end
		return nil
	end

	local function trigger(when, phase, sinceStart)
		for _, bot in ipairs(bots) do
			local spec = bot.spec
			local j = spec.join or { round = 1, phase = "Lobby", after = 0 }
			if not bot.player and not bot.joinedOnce and j.round == when and j.phase == phase and sinceStart >= (j.after or 0) then
				bot.joinedOnce = true
				Bots.join(bot)
				byKey[tostring(bot.userId)] = bot
				bot.joinedPhase = phase
				bot.joinedRound = when
			end
			local l = spec.leave
			if l and bot.player and not bot.left and l.round == when and l.phase == phase and sinceStart >= (l.after or 0) then
				bot.leftRound = when
				Bots.leave(bot)
			end
			local r = spec.rejoin
			if r and bot.left and not bot.rejoined and r.round == when and r.phase == phase and sinceStart >= (r.after or 0) then
				bot.rejoined = true
				Bots.join(bot)
			end
		end
	end

	local function captureStandings()
		local ballots = ctx.votes and ctx.votes.ballots
		if not ballots then
			return {}
		end
		local rows = Voting.standings(ballots)
		local list = {}
		for rank, row in ipairs(rows) do
			local room = ballots.rooms[row.owner]
			local stars = {}
			if room then
				for _, s in pairs(room.votes) do
					table.insert(stars, s)
				end
			end
			local bot = byKey[row.owner]
			table.insert(list, {
				rank = rank,
				owner = row.owner,
				kind = bot and bot.kind or "?",
				average = row.average,
				critic = row.criticStars,
				votes = #stars,
				stars = stars,
				quality = current and current.quality[row.owner] or nil,
				order = current and current.order[row.owner] or nil,
			})
		end
		return list
	end

	while world.clock < limit do
		world:step(DT)
		local phase = ctx.round.phase
		local since = world.clock - phaseStart
		trigger(roundNo == 0 and 1 or roundNo, phase, since)
		if phase ~= lastPhase then
			-- Phase change. Close the old one.
			if current and lastPhase ~= "Lobby" then
				table.insert(current.phases, { phase = lastPhase, seconds = since })
			end
			if phase == "ThemeReveal" or (phase ~= "Lobby" and lastPhase == "Lobby") then
				roundNo += 1
				current = {
					n = roundNo,
					index = ctx.round.roundIndex,
					modifier = ctx.round.modifier or "",
					roundType = ctx.round.theme and ctx.round.theme.roundType or "",
					theme = ctx.round.theme and ctx.round.theme.id or "",
					phases = {},
					players = #world.players:GetPlayers(),
					active = 0,
					quality = {},
					order = {},
					awards = {},
					startedAt = world.clock,
				}
				for _, p in pairs(ctx.round.players) do
					if p.role == "active" then
						current.active += 1
					end
				end
				table.insert(out.rounds, current)
				-- The lobby that just ended belongs to this round.
				table.insert(current.phases, { phase = "Lobby", seconds = since })
				if phase ~= "ThemeReveal" then
					problem("skipped-phase", opts.name .. " round " .. roundNo .. ": Lobby went to " .. phase)
				end
			end
			if current and phase == "Results" then
				current.resultsAt = world.clock
			end
			if current and phase == "Tour" then
				current.stops = #ctx.round.tourStops
				lastTourIndex = 0
				for i, id in ipairs(ctx.round.tourStops) do
					current.order[id] = i
					local facts = ctx.rooms.inspect(id)
					current.quality[id] = facts.meter
				end
				-- Who is on the tour, and who was dropped.
				current.tourKinds = {}
				for _, id in ipairs(ctx.round.tourStops) do
					local b = byKey[id]
					table.insert(current.tourKinds, b and b.kind or "?")
				end
			end
			if current and lastPhase == "Build" and phase ~= "Tour" then
				problem("skipped-phase", opts.name .. " round " .. roundNo .. ": Build went straight to " .. phase)
			end
			if current and lastPhase == "Tour" and phase ~= "Results" then
				problem("skipped-phase", opts.name .. " round " .. roundNo .. ": Tour went to " .. phase)
			end
			if phase == "Lobby" and current then
				current.total = 0
				for _, ph in ipairs(current.phases) do
					current.total += ph.seconds
				end
				current.done = true
				if roundNo >= roundsWanted then
					lastPhase = phase
					break
				end
			end
			lastPhase = phase
			phaseStart = world.clock
		end

		if phase == "Tour" then
			local idx = ctx.round.tourIndex
			if idx ~= lastTourIndex then
				lastTourIndex = idx
				scanWorkspace()
			end
		end

		if phase == "Results" and current and not current.standings and since >= Config.Phases.Results - 1 then
			current.standings = captureStandings()
			for _, bot in ipairs(bots) do
				if bot.player and not bot.left then
					local p = bot.player
					local bag = ctx.saves.session(tostring(bot.userId))
					table.insert(current.awards, {
						kind = bot.kind,
						key = tostring(bot.userId),
						coins = p:GetAttribute("AwardCoins"),
						xp = p:GetAttribute("AwardXp"),
						level = p:GetAttribute("Level"),
						purse = bag.profile.coins,
						totalXp = bag.profile.xp,
						spectating = p:GetAttribute("Spectating") == true,
						saveOk = p:GetAttribute("SaveOk"),
					})
				end
			end
		end

		since = world.clock - phaseStart
		-- Stuck phase watchdog.
		local cap = nil
		if phase == "Lobby" then
			cap = if #world.players:GetPlayers() > 0 then 45 else nil
		elseif phase == "ThemeReveal" then
			cap = 8
		elseif phase == "Build" then
			cap = Config.Phases.Build + 2 * Config.Shop.TimeBonus + 5
		elseif phase == "Tour" then
			cap = Config.Phases.TourPerRoom * 10 + 5
		elseif phase == "Results" then
			cap = Config.Phases.Results + 5
		end
		if cap and since > cap and not out.stuckNoted then
			out.stuckNoted = true
			table.insert(out.stuck, { phase = phase, seconds = since, round = roundNo })
			problem("stuck", opts.name .. ": " .. phase .. " has run " .. math.floor(since) .. "s in round " .. roundNo)
		end

		for _, bot in ipairs(bots) do
			Bots.think(bot, world.clock)
		end
	end

	-- Phase timing vs plan.
	for _, r in ipairs(out.rounds) do
		for _, ph in ipairs(r.phases) do
			local want = expectedSpan(ph.phase, r, r.stops or 0)
			ph.planned = want
		end
	end

	for _, list in ipairs({ "error", "warn" }) do
		for _, e in ipairs(world.log[list]) do
			table.insert(out.errors, { kind = list, at = e.at, msg = e.msg })
		end
	end
	out.pcalls = {}
	for _, e in ipairs(world.log.pcall) do
		local key = string.sub(e.msg, 1, 160)
		out.pcalls[key] = (out.pcalls[key] or 0) + 1
	end
	-- DataStore pressure. Roblox allows 60 + 10 per player UpdateAsync calls a minute.
	local st = world.storeStats
	local worst = 0
	for i, t in ipairs(st.times) do
		local n = 0
		for j = i, #st.times do
			if st.times[j] - t < 60 then
				n += 1
			else
				break
			end
		end
		worst = math.max(worst, n)
	end
	out.store = { calls = st.calls, perMinutePeak = worst, queuedSameKey = st.queued, maxQueueSeconds = st.maxQueue, minutes = world.clock / 60 }
	-- Slow answers. A tap that waits more than a second on a save feels broken.
	out.slowActions = {}
	for _, bot in ipairs(bots) do
		for _, r in ipairs(bot.responses) do
			if (r.took or 0) > 1 then
				local k = r.action
				out.slowActions[k] = out.slowActions[k] or { n = 0, max = 0 }
				out.slowActions[k].n += 1
				out.slowActions[k].max = math.max(out.slowActions[k].max, r.took)
			end
		end
	end
	out.prompts = #world.prompts
	if #world.prompts > 0 then
		problem("purchase-prompt", opts.name .. ": " .. #world.prompts .. " purchase windows opened for id 0 items")
	end
	for _, bot in ipairs(bots) do
		local fails = {}
		local counts = {}
		for _, r in ipairs(bot.responses) do
			counts[r.action] = (counts[r.action] or 0) + 1
			if not r.ok then
				local k = r.action .. ": " .. tostring(r.msg)
				fails[k] = (fails[k] or 0) + 1
			end
			if r.msg == "Something went wrong." then
				problem("handler-error", opts.name .. " " .. bot.kind .. " " .. r.action .. " at " .. r.at)
			end
		end
		table.insert(out.bots, {
			kind = bot.kind,
			key = tostring(bot.userId),
			calls = counts,
			fails = fails,
			tutorial = bot.tutorial,
			voteFails = bot.voteFails,
		})
		if bot.tutorial then
			table.insert(report.tutorial, {
				session = opts.name,
				kind = bot.kind,
				joined = bot.joinedPhase,
				lobbyLeftAtStart = bot.tutorial.lobbyLeft,
				reactedIn = bot.tutorial.placedAt and (bot.tutorial.placedAt - bot.tutorial.seenAt) or nil,
				failed = bot.tutorial.failed,
			})
		end
	end
	out.world = world
	out.botsRef = bots
	return out, world
end

------------------------------------------------------------------ scenarios

local family = {
	{ kind = "newbie", skill = 0.5 },
	{ kind = "returning", skill = 0.85 },
	{ kind = "leaver", leave = { round = 3, phase = "Build", after = 60 }, rejoin = { round = 5, phase = "Lobby", after = 2 } },
	{ kind = "idle", pressesDone = false },
	{ kind = "duo", skill = 0.7 },
	{ kind = "duo", skill = 0.6 },
	{ kind = "spammer", skill = 0.4 },
	{ kind = "novote", skill = 0.6 },
	{ kind = "late", join = { round = 2, phase = "Build", after = 30 } },
	{ kind = "builder", skill = 0.9, generous = true },
}

local datastore = {}

local function profileOf(world, key)
	local bag = world.ctx.saves.session(key)
	return bag.hold == true, bag.profile
end

local function stripVolatile(doc)
	local copy = World.deepCopy(doc)
	if type(copy) == "table" then
		copy.lock = nil
		copy.schema = nil
		copy.luck = nil
	end
	return copy
end

local function same(a, b, path, diffs)
	if type(a) ~= type(b) then
		table.insert(diffs, path .. ": " .. tostring(a) .. " vs " .. tostring(b))
		return
	end
	if type(a) ~= "table" then
		if a ~= b then
			table.insert(diffs, path .. ": " .. tostring(a) .. " vs " .. tostring(b))
		end
		return
	end
	local keys = {}
	for k in pairs(a) do
		keys[k] = true
	end
	for k in pairs(b) do
		keys[k] = true
	end
	for k in pairs(keys) do
		same(a[k], b[k], path .. "." .. tostring(k), diffs)
	end
end

-- 0. A short earlier visit so the returning kid has a real saved profile.
do
	local warm = session({
		name = "warmup-returning",
		rounds = 3,
		datastore = datastore,
		bots = {
			{ kind = "returning", userId = 5002, skill = 0.85, tutorialReact = 4 },
			{ kind = "builder", userId = 5090, skill = 0.6 },
		},
	})
	for _, b in ipairs(warm.botsRef) do
		Bots.leave(b)
	end
	for _ = 1, 30 do
		warm.world:step(DT)
	end
	warm.world = nil
	warm.botsRef = nil
	table.insert(report.sessions, warm)
end

local plans = {
	{ name = "solo", players = 1, rounds = if QUICK then 4 else 13 },
	{ name = "pair", players = 2, rounds = if QUICK then 3 else 12 },
	{ name = "five", players = 5, rounds = if QUICK then 3 else 12 },
	{ name = "family10", players = 10, rounds = if QUICK then 5 else 16 },
}

local finalWorld = nil
local finalBots = nil
for pi, plan in ipairs(plans) do
	local specs = {}
	if plan.name == "family10" then
		for i, spec in ipairs(family) do
			local copy = table.clone(spec)
			copy.userId = if spec.kind == "returning" then 5002 else 7000 + i
			table.insert(specs, copy)
		end
	elseif plan.name == "solo" then
		specs = { { kind = "newbie", userId = 6101, skill = 0.6 } }
	elseif plan.name == "pair" then
		specs = {
			{ kind = "duo", userId = 6201, skill = 0.6 },
			{ kind = "duo", userId = 6202, skill = 0.5 },
		}
	else
		specs = {
			{ kind = "newbie", userId = 6301, join = { round = 1, phase = "Lobby", after = 12 } },
			{ kind = "builder", userId = 6302, skill = 0.9 },
			{ kind = "idle", userId = 6303, pressesDone = false },
			{ kind = "novote", userId = 6304 },
			{ kind = "leaver", userId = 6305, leave = { round = 2, phase = "Tour", after = 3 } },
		}
	end
	local out, world = session({
		name = plan.name,
		rounds = plan.rounds,
		datastore = datastore,
		seed = SEED + pi,
		bots = specs,
	})
	if plan.name == "family10" then
		finalWorld = world
		finalBots = out.botsRef
	else
		out.world = nil
		out.botsRef = nil
	end
	table.insert(report.sessions, out)
end

------------------------------------------------------------------ save round trips

do
	local world = finalWorld
	local live = {}
	for _, bot in ipairs(finalBots) do
		if bot.player and not bot.left then
			local held, profile = profileOf(world, tostring(bot.userId))
			if held then
				-- Compare what a load would rebuild. Quests keep id and progress only.
				live[tostring(bot.userId)] = stripVolatile(Save.normalizeProfile(World.deepCopy(profile)))
			end
		end
	end
	-- Everyone leaves from the lobby. Leave writes the live copy.
	for _, bot in ipairs(finalBots) do
		Bots.leave(bot)
	end
	-- The leave write and the lock release can each wait about 6 s behind an
	-- earlier write to the same key. Give them half a minute.
	for _ = 1, 300 do
		world:step(DT)
	end
	local stored = datastore[Config.Progress.ProfileStore] or {}
	local checks = {}
	for key, snap in pairs(live) do
		local diffs = {}
		local docKey = nil
		for k in pairs(stored) do
			if string.find(k, key, 1, true) then
				docKey = k
			end
		end
		local doc = docKey and stored[docKey]
		if not doc then
			table.insert(diffs, "no stored doc")
		else
			same(snap, stripVolatile(Save.normalizeProfile(World.deepCopy(doc))), "profile", diffs)
			if type(doc.lock) == "table" and doc.lock.session ~= nil then
				table.insert(diffs, "lock still held after leave: " .. tostring(doc.lock.session))
			end
		end
		table.insert(checks, { key = key, step = "leave-write", diffs = diffs })
		if #diffs > 0 then
			problem("save", "leave write " .. key .. ": " .. table.concat(diffs, "; "))
		end
	end

	-- A fresh server loads the same kids back.
	local second = World.new({ root = ".", unix0 = HOLIDAY_UNIX + 3600, datastore = datastore, jobId = "job-second" }):boot()
	for key, snap in pairs(live) do
		local p = second:addPlayer("again" .. key, "Again", tonumber(key))
		for _ = 1, 20 do
			second:step(DT)
		end
		local held, profile = profileOf(second, key)
		local diffs = {}
		if not held then
			table.insert(diffs, "second server could not take the save lock")
		else
			same(snap, stripVolatile(Save.normalizeProfile(World.deepCopy(profile))), "profile", diffs)
		end
		table.insert(checks, { key = key, step = "reload", diffs = diffs })
		if #diffs > 0 then
			problem("save", "reload " .. key .. ": " .. table.concat(diffs, "; "))
		end
	end

	-- Two servers at once. The second must not take or overwrite the save.
	local third = World.new({ root = ".", unix0 = HOLIDAY_UNIX + 3700, datastore = datastore, jobId = "job-third" }):boot()
	local anyKey = next(live)
	local before = World.deepCopy(datastore[Config.Progress.ProfileStore])
	local dupe = third:addPlayer("dupe", "Dupe", tonumber(anyKey))
	for _ = 1, 30 do
		third:step(DT)
	end
	local heldThird = profileOf(third, anyKey)
	table.insert(checks, {
		key = anyKey,
		step = "second-server-lock",
		diffs = if heldThird then { "a second server took a held save" } else {},
	})
	if heldThird then
		problem("save", "two servers both hold " .. anyKey)
	end
	third:removePlayer(dupe)
	for _ = 1, 30 do
		third:step(DT)
	end

	-- Shutdown path: second server closes with everyone still in.
	second:shutdown()
	local stillLocked = {}
	for k, doc in pairs(datastore[Config.Progress.ProfileStore] or {}) do
		if type(doc.lock) == "table" and doc.lock.session == "job-second" then
			table.insert(stillLocked, k)
		end
	end
	table.insert(checks, { step = "shutdown-release", diffs = stillLocked })
	if #stillLocked > 0 then
		problem("save", "BindToClose left locks: " .. table.concat(stillLocked, ","))
	end
	for _, list in ipairs({ second.log.error, third.log.error, second.log.warn, third.log.warn }) do
		for _, e in ipairs(list) do
			problem("save-error", e.msg)
		end
	end
	report.saves = checks
end

finalWorld = nil
for _, s in ipairs(report.sessions) do
	s.world = nil
	s.botsRef = nil
end

------------------------------------------------------------------ summary

local function mean(list)
	if #list == 0 then
		return 0
	end
	local t = 0
	for _, v in ipairs(list) do
		t += v
	end
	return t / #list
end

local summary = { rounds = 0, byModifier = {}, coinsByKind = {}, xpByKind = {}, roundSeconds = {}, phaseDrift = {} }
local corr = { q = {}, s = {} }
local orderBias = {}
for _, s in ipairs(report.sessions) do
	for _, r in ipairs(s.rounds) do
		if r.done then
			summary.rounds += 1
			local mod = if r.modifier == "" then "none" else r.modifier
			summary.byModifier[mod] = (summary.byModifier[mod] or 0) + 1
			table.insert(summary.roundSeconds, { session = s.name, n = r.n, total = r.total, stops = r.stops, modifier = mod, players = r.players })
			for _, ph in ipairs(r.phases) do
				local drift = ph.seconds - (ph.planned or 0)
				if math.abs(drift) > 1.5 then
					table.insert(summary.phaseDrift, {
						session = s.name,
						round = r.n,
						phase = ph.phase,
						seconds = math.floor(ph.seconds * 10) / 10,
						planned = ph.planned,
					})
				end
			end
			for _, a in ipairs(r.awards) do
				if type(a.coins) == "number" then
					summary.coinsByKind[a.kind] = summary.coinsByKind[a.kind] or {}
					table.insert(summary.coinsByKind[a.kind], a.coins)
					summary.xpByKind[a.kind] = summary.xpByKind[a.kind] or {}
					table.insert(summary.xpByKind[a.kind], a.xp or 0)
				end
			end
			for _, row in ipairs(r.standings or {}) do
				if row.quality then
					table.insert(corr.q, row.quality)
					table.insert(corr.s, row.average)
				end
				if row.order and r.stops and r.stops >= 4 then
					local bucket = if row.order == 1 then "first" elseif row.order == r.stops then "last" else "middle"
					orderBias[bucket] = orderBias[bucket] or {}
					table.insert(orderBias[bucket], row.average)
				end
			end
		end
	end
end

local function pearson(x, y)
	local n = #x
	if n < 3 then
		return 0
	end
	local mx, my = mean(x), mean(y)
	local sxy, sxx, syy = 0, 0, 0
	for i = 1, n do
		sxy += (x[i] - mx) * (y[i] - my)
		sxx += (x[i] - mx) ^ 2
		syy += (y[i] - my) ^ 2
	end
	if sxx == 0 or syy == 0 then
		return 0
	end
	return sxy / math.sqrt(sxx * syy)
end

summary.qualityVsScore = pearson(corr.q, corr.s)
summary.orderBias = {}
for k, v in pairs(orderBias) do
	summary.orderBias[k] = { mean = mean(v), n = #v }
end
summary.coins = {}
for k, v in pairs(summary.coinsByKind) do
	summary.coins[k] = { mean = mean(v), n = #v, min = math.min(table.unpack(v)), max = math.max(table.unpack(v)) }
end
summary.xp = {}
local allXp = {}
for k, v in pairs(summary.xpByKind) do
	summary.xp[k] = { mean = mean(v), n = #v }
	if k ~= "late" and k ~= "idle" then
		for _, x in ipairs(v) do
			table.insert(allXp, x)
		end
	end
end
local avgXp = mean(allXp)
summary.avgXpPerRound = avgXp
summary.levelPace = {}
for _, L in ipairs({ 5, 8, 10, 15, 20, 30, 50 }) do
	local need = Levels.total(L)
	local rounds = if avgXp > 0 then need / avgXp else 0
	table.insert(summary.levelPace, { level = L, xp = need, rounds = math.ceil(rounds), hours = math.floor(rounds * 395 / 360) / 10 })
end
report.summary = summary

fs.writeDir("playtest/out")
fs.writeFile("playtest/out/report.json", serde.encode("json", report, true))

------------------------------------------------------------------ markdown

local lines = {}
local function w(s)
	table.insert(lines, s)
end
w("# Room Glow Up headless playtest")
w("")
w(string.format("Seed %d. %d rounds played across %d servers.", SEED, summary.rounds, #report.sessions))
w("")
w("## Problems")
if #report.problems == 0 then
	w("None.")
end
local seenProblem = {}
for _, p in ipairs(report.problems) do
	local key = p.kind .. p.detail
	if not seenProblem[key] then
		seenProblem[key] = true
		w("- **" .. p.kind .. "** " .. string.gsub(p.detail, "\n", " "))
	end
end
w("")
w("## Name leaks during the tour")
if #report.leaks == 0 then
	w("None.")
end
for i, l in ipairs(report.leaks) do
	if i > 20 then
		w("- ... " .. (#report.leaks - 20) .. " more")
		break
	end
	w(string.format("- %s round %d `%s` = `%s`", l.session, l.round, l.where, l.value))
end
w("")
w("## Rounds")
w("| server | round | twist | players | stops | seconds | phases |")
w("|---|---|---|---|---|---|---|")
for _, s in ipairs(report.sessions) do
	for _, r in ipairs(s.rounds) do
		if r.done then
			local parts = {}
			for _, ph in ipairs(r.phases) do
				table.insert(parts, string.format("%s %.0f", string.sub(ph.phase, 1, 5), ph.seconds))
			end
			w(string.format("| %s | %d | %s | %d | %s | %.0f | %s |", s.name, r.n, r.modifier ~= "" and r.modifier or "-", r.players, tostring(r.stops or 0), r.total or 0, table.concat(parts, ", ")))
		end
	end
end
w("")
w("## Rewards per round by player type")
w("| type | rounds | mean coins | min | max | mean XP |")
w("|---|---|---|---|---|---|")
for k, v in pairs(summary.coins) do
	w(string.format("| %s | %d | %.1f | %d | %d | %.1f |", k, v.n, v.mean, v.min, v.max, summary.xp[k].mean))
end
w("")
w(string.format("Mean XP per round for active builders: %.1f", avgXp))
w("")
w("| level | total XP | rounds | hours |")
w("|---|---|---|---|")
for _, row in ipairs(summary.levelPace) do
	w(string.format("| %d | %d | %d | %.1f |", row.level, row.xp, row.rounds, row.hours))
end
w("")
w(string.format("Room quality (Theme Match) vs. final stars, Pearson r = %.2f over %d rooms.", summary.qualityVsScore, #corr.q))
for k, v in pairs(summary.orderBias) do
	w(string.format("- Tour position %s: mean %.2f stars (%d rooms)", k, v.mean, v.n))
end
w("")
w("## Tutorial")
for _, t in ipairs(report.tutorial) do
	w(string.format("- %s %s joined in %s: lobby had %ss left, placed after %s s%s", t.session, t.kind, tostring(t.joined), tostring(t.lobbyLeftAtStart), t.reactedIn and string.format("%.1f", t.reactedIn) or "never", t.failed and (" (" .. t.failed .. ")") or ""))
end
w("")
w("## Results timing and DataStore load")
for _, s in ipairs(report.sessions) do
	local worstAward, worstSpot, late = 0, 0, 0
	for _, r in ipairs(s.rounds) do
		for _, a in ipairs(r.awardLag or {}) do
			worstAward = math.max(worstAward, a.at)
			if a.phase ~= "Results" then
				late += 1
			end
		end
		worstSpot = math.max(worstSpot, r.spotLag or 0)
	end
	local slow = {}
	for k, v in pairs(s.slowActions or {}) do
		table.insert(slow, string.format("%s x%d (max %.1fs)", k, v.n, v.max))
	end
	table.sort(slow)
	w(string.format("- %s: coins shown up to %.1fs into Results (%d after Results ended); Spot the Theme up to %.1fs; %d UpdateAsync calls in %.0f min, peak %d/min, %d same-key waits (max %.1fs); slow taps: %s",
		s.name, worstAward, late, worstSpot, s.store and s.store.calls or 0, s.store and s.store.minutes or 0, s.store and s.store.perMinutePeak or 0, s.store and s.store.queuedSameKey or 0, s.store and s.store.maxQueueSeconds or 0, if #slow > 0 then table.concat(slow, ", ") else "none"))
end
w("")
w("## Saves")
for _, c in ipairs(report.saves) do
	w(string.format("- %s %s: %s", tostring(c.key or ""), c.step, if #c.diffs == 0 then "ok" else table.concat(c.diffs, "; ")))
end
w("")
w("## Failed actions (by bot)")
for _, s in ipairs(report.sessions) do
	for _, b in ipairs(s.bots) do
		local parts = {}
		for k, v in pairs(b.fails) do
			table.insert(parts, k .. " x" .. v)
		end
		table.sort(parts)
		if #parts > 0 then
			w("- " .. s.name .. " " .. b.kind .. ": " .. table.concat(parts, "; "))
		end
	end
end
w("")
w("## Swallowed errors (pcall)")
for _, s in ipairs(report.sessions) do
	for k, v in pairs(s.pcalls or {}) do
		w("- " .. s.name .. " x" .. v .. ": " .. string.gsub(k, "\n", " "))
	end
end
fs.writeFile("playtest/out/report.md", table.concat(lines, "\n") .. "\n")
print(table.concat(lines, "\n"))
if #report.problems > 0 or #report.leaks > 0 then
	process.exit(1)
end
