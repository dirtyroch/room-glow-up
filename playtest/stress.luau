--!nocheck
-- Rough-player playtests. Griefers, kids who rejoin over and over, a +60 s
-- buyer at the build boundary, a Speed Round with late joiners, a duo that
-- splits, and a 10-kid server of phones and laggy low-end clients.
-- Run: lune run playtest/stress.luau [--seed N]
-- Writes playtest/out/stress.md and stress.json. Exits 1 on problems.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local World = require("./World")
local Bots = require("./Bots")
local Rng = require("./Rng")
local Config = require("../src/shared/Config")

local SEED = 4242
local args = process.args
for i, a in ipairs(args) do
	if a == "--seed" and args[i + 1] then
		SEED = tonumber(args[i + 1]) or SEED
	end
end

local DT = 0.1
local EXTRA_MINUTE_ID = 990001
local HOLIDAY_UNIX = 1797357600

local problems = {}
local function problem(kind, detail)
	table.insert(problems, { kind = kind, detail = detail })
end

local function rsOf(world)
	return world.game:GetService("ReplicatedStorage"):FindFirstChild("RoundState")
end

-- The world's own copy of Config, so a test product id never touches the repo.
local function worldConfig(world)
	local shared = world.game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
	return world:require(shared:FindFirstChild("Config"), shared)
end

local function receipt(world, player, purchaseId, out)
	local mps = world.marketplace
	local fn = rawget(mps, "_props").ProcessReceipt
	if type(fn) ~= "function" then
		problem("receipt", "no ProcessReceipt")
		return
	end
	world:spawn("receipt", function()
		local decision = fn({ PlayerId = player.UserId, ProductId = EXTRA_MINUTE_ID, PurchaseId = purchaseId })
		out.decision = tostring(decision)
		out.doneAt = world.clock
	end)
end

local function run(opts)
	local world = World.new({ root = ".", unix0 = HOLIDAY_UNIX, jobId = "job-" .. opts.name }):boot()
	worldConfig(world).Shop.Products.ExtraMinute.id = EXTRA_MINUTE_ID
	local ctx = world.ctx
	local rng = Rng.new(opts.seed)
	local bots = {}
	for i, spec in ipairs(opts.bots) do
		spec.userId = spec.userId or (9000 + i)
		spec.name = spec.name or ("kid" .. i)
		spec.display = spec.display or ("Kid" .. i)
		table.insert(bots, Bots.new(world, rng, spec))
	end
	local byKey = {}
	local out = {
		name = opts.name,
		rounds = {},
		perKind = {},
		votes = { sent = 0, ok = 0, misrouted = 0, lateLocked = 0, lagged = 0 },
		reports = { sent = 0, ok = 0, misrouted = 0, removedHonest = 0 },
		reactions = { sent = 0, ok = 0, maxPerStop = 0 },
		midBuildRejoins = 0,
		roomsKept = 0,
		multiPlot = 0,
		dupStops = 0,
		purchases = {},
		spectateSeconds = {},
		errors = {},
	}
	local function piecesOf(key)
		local plots = world.workspace:FindFirstChild("Plots")
		for _, plot in ipairs(plots and plots:GetChildren() or {}) do
			if plot:GetAttribute("OwnerKey") == key then
				local items = plot:FindFirstChild("Items")
				return items and #items:GetChildren() or 0
			end
		end
		return 0
	end
	local function leave(bot)
		bot.piecesAtLeave = if ctx.round.phase == "Build" then piecesOf(tostring(bot.userId)) else 0
		bot.leftRound = ctx.round.roundIndex
		Bots.leave(bot)
	end
	local checks = {}
	local function join(bot)
		if (bot.piecesAtLeave or 0) > 0 and ctx.round.phase == "Build" and ctx.round.roundIndex == bot.leftRound then
			table.insert(checks, { bot = bot, at = world.clock + 1, had = bot.piecesAtLeave })
		end
		bot.piecesAtLeave = 0
		Bots.join(bot)
		byKey[tostring(bot.userId)] = bot
		bot.player:SetAttribute("Device", bot.spec.device or "pc")
	end
	for _, bot in ipairs(bots) do
		if not bot.spec.join then
			join(bot)
		end
	end
	local roundNo = 0
	local current = nil
	local lastPhase = ctx.round.phase
	local phaseStart = world.clock
	local reactStop, reactCount = -1, 0
	local lastNonce = 0
	local limit = opts.rounds * 600 + 200
	while world.clock < limit do
		world:step(DT)
		local round = ctx.round
		local phase = round.phase
		local since = world.clock - phaseStart
		if phase ~= lastPhase then
			if current and lastPhase ~= "Lobby" then
				current.phases[lastPhase] = (current.phases[lastPhase] or 0) + since
			end
			if lastPhase == "Lobby" and phase ~= "Lobby" then
				roundNo += 1
				current = { n = roundNo, modifier = round.modifier or "", phases = { Lobby = since }, active = 0, startedAt = world.clock - since }
				for _, p in pairs(round.players) do
					if p.role == "active" then
						current.active += 1
					end
				end
				table.insert(out.rounds, current)
			end
			if phase == "Tour" and current then
				current.stops = #round.tourStops
				current.rush = round.rush == true
				local seen = {}
				for _, id in ipairs(round.tourStops) do
					if seen[id] then
						out.dupStops += 1
						problem("dup-stop", opts.name .. " round " .. roundNo .. ": " .. id .. " twice on tour")
					end
					seen[id] = true
				end
			end
			if phase == "Results" and current then
				current.resultsAt = world.clock
				-- Honest rooms that a report took off the tour.
				local ballots = ctx.votes.ballots
				for owner, room in pairs(ballots.rooms) do
					local b = byKey[owner]
					if room.removed and b and b.kind ~= "griefer" then
						out.reports.removedHonest += 1
						problem("report-grief", opts.name .. ": " .. b.kind .. " room removed by reports")
					end
				end
			end
			if phase == "Lobby" and current then
				current.total = world.clock - current.startedAt
				if roundNo >= opts.rounds then
					break
				end
			end
			lastPhase = phase
			phaseStart = world.clock
			since = 0
		end
		if phase == "Build" and current and round.rush and not current.rushAt then
			current.rushAt = world.clock - phaseStart
		end
		-- Reaction flood: how many land on one stop.
		if phase == "Tour" then
			local idx = round.tourIndex
			if idx ~= reactStop then
				reactStop, reactCount = idx, 0
			end
			local nonce = rsOf(world):GetAttribute("ReactionNonce") or 0
			if nonce ~= lastNonce then
				reactCount += nonce - lastNonce
				lastNonce = nonce
				out.reactions.maxPerStop = math.max(out.reactions.maxPerStop, reactCount)
			end
		end
		-- Payouts, once per round.
		if phase == "Results" and current and not current.paid and since >= Config.Phases.Results - 1 then
			current.paid = true
			for _, bot in ipairs(bots) do
				if bot.player and not bot.left then
					local k = bot.kind .. (if bot.spec.tag then "/" .. bot.spec.tag else "")
					local row = out.perKind[k] or { n = 0, coins = 0, xp = 0, spectating = 0 }
					row.n += 1
					row.coins += bot.player:GetAttribute("AwardCoins") or 0
					row.xp += bot.player:GetAttribute("AwardXp") or 0
					if bot.player:GetAttribute("Spectating") == true then
						row.spectating += 1
					end
					out.perKind[k] = row
				end
			end
		end
		-- One kid, one plot.
		local owners = {}
		local plots = world.workspace:FindFirstChild("Plots")
		if plots and phase == "Build" then
			for _, plot in ipairs(plots:GetChildren()) do
				local key = plot:GetAttribute("OwnerKey")
				if type(key) == "string" and key ~= "" then
					owners[key] = (owners[key] or 0) + 1
					if owners[key] == 2 then
						out.multiPlot += 1
						problem("two-plots", opts.name .. ": " .. key .. " owns two plots")
					end
				end
			end
		end
		-- Scheduled joins, leaves, churn and purchases.
		for _, bot in ipairs(bots) do
			local spec = bot.spec
			local j = spec.join
			if j and not bot.joinedOnce and not bot.player and roundNo == j.round and phase == j.phase and since >= (j.after or 0) then
				bot.joinedOnce = true
				join(bot)
			end
			local l = spec.leave
			if l and bot.player and not bot.left and not bot.leftOnce and roundNo == l.round and phase == l.phase and since >= (l.after or 0) then
				bot.leftOnce = true
				leave(bot)
				bot.backAt = if spec.rejoinAfter then world.clock + spec.rejoinAfter else nil
			end
			if spec.churn and bot.player then
				bot.churnAt = bot.churnAt or (world.clock + rng:NextNumber(spec.churn[1], spec.churn[2]))
				if not bot.left and world.clock >= bot.churnAt then
					leave(bot)
					out.churns = (out.churns or 0) + 1
					bot.backAt = world.clock + rng:NextNumber(2, 8)
				end
			end
			if bot.left and bot.backAt and world.clock >= bot.backAt then
				bot.backAt = nil
				bot.churnAt = nil
				join(bot)
			end
			for _, buy in ipairs(spec.buys or {}) do
				if not buy.sent and bot.player and not bot.left and roundNo == buy.round and phase == buy.phase then
					local left = (round.phaseEndsAt or 0) - world.workspace:GetServerTimeNow()
					local fire = if buy.left ~= nil then left <= buy.left else since >= (buy.after or 0)
					if fire then
						buy.sent = true
						local rec = {
							label = buy.label,
							phase = phase,
							endsBefore = round.phaseEndsAt,
							coinsBefore = ctx.saves.session(tostring(bot.userId)).profile.coins,
							at = world.clock,
						}
						table.insert(out.purchases, rec)
						receipt(world, bot.player, "p-" .. opts.name .. "-" .. #out.purchases, rec)
						rec.round = round
					end
				end
			end
		end
		for _, bot in ipairs(bots) do
			Bots.think(bot, world.clock)
			if bot.player and not bot.left and bot.player:GetAttribute("Spectating") == true and phase ~= "Lobby" then
				local idle = bot.player:GetAttribute("TutorialActive") ~= true and bot.player:GetAttribute("AtHome") ~= true
				if idle then
					out.spectateSeconds[bot.kind] = (out.spectateSeconds[bot.kind] or 0) + DT
				end
			end
		end
		for i = #checks, 1, -1 do
			local c = checks[i]
			if world.clock >= c.at then
				table.remove(checks, i)
				out.midBuildRejoins += 1
				local now = piecesOf(tostring(c.bot.userId))
				if now >= c.had and c.bot.player:GetAttribute("Spectating") ~= true then
					out.roomsKept += 1
				end
			end
		end
		-- Purchase follow-ups a few seconds later.
		for _, rec in ipairs(out.purchases) do
			if rec.round and world.clock - rec.at > 14 then
				local r = rec.round
				rec.round = nil
				rec.endsAfter = r.phaseEndsAt
				rec.phaseAfter = r.phase
				local bot = nil
				for _, b in ipairs(bots) do
					if b.spec.buys then
						bot = b
					end
				end
				rec.coinsAfter = bot and ctx.saves.session(tostring(bot.userId)).profile.coins or 0
			end
		end
	end
	-- Paid time that the rush then took away.
	for _, bot in ipairs(bots) do
		for _, r in ipairs(bot.responses) do
			if r.action == "Vote" then
				out.votes.sent += 1
				if r.ok then
					out.votes.ok += 1
				end
				if r.sentIndex ~= r.landedIndex then
					out.votes.lagged += 1
					if r.ok and r.sentPhase == "Tour" then
						out.votes.misrouted += 1
					end
				end
				if r.msg == "Votes are locked." then
					out.votes.lateLocked += 1
				end
			elseif r.action == "Report" then
				out.reports.sent += 1
				if r.ok then
					out.reports.ok += 1
				end
				if r.ok and r.sentIndex ~= r.landedIndex and r.sentPhase == "Tour" then
					out.reports.misrouted += 1
				end
			elseif r.action == "React" then
				out.reactions.sent += 1
				if r.ok then
					out.reactions.ok += 1
				end
			end
			if r.msg == "Something went wrong." then
				problem("handler-error", opts.name .. " " .. bot.kind .. " " .. r.action)
			end
		end
	end
	for _, list in ipairs({ "error", "warn" }) do
		for _, e in ipairs(world.log[list]) do
			table.insert(out.errors, e.msg)
			problem(list, opts.name .. ": " .. e.msg)
		end
	end
	if #world.prompts > 0 then
		problem("purchase-prompt", opts.name .. ": " .. #world.prompts .. " windows")
	end
	local st = world.storeStats
	local worst = 0
	for i, t in ipairs(st.times) do
		local n = 0
		for k = i, #st.times do
			if st.times[k] - t < 60 then
				n += 1
			else
				break
			end
		end
		worst = math.max(worst, n)
	end
	out.store = { calls = st.calls, perMinutePeak = worst, minutes = world.clock / 60 }
	out.minutes = world.clock / 60
	return out
end

local function phones(n, start, tag)
	local list = {}
	for i = 1, n do
		table.insert(list, { kind = "builder", tag = tag, device = tag, userId = start + i, skill = 0.6, slow = if tag == "phone" then 1.5 else 1, lag = if tag == "lowend" then { 0.4, 1.4 } else nil })
	end
	return list
end

local function concat(...)
	local all = {}
	for _, list in ipairs({ ... }) do
		for _, x in ipairs(list) do
			table.insert(all, x)
		end
	end
	return all
end

local scenarios = {
	{
		name = "griefers10",
		rounds = 4,
		bots = concat({
			{ kind = "griefer", userId = 9101 },
			{ kind = "griefer", userId = 9102 },
		}, phones(4, 9110, "phone"), phones(4, 9120, "pc")),
	},
	{
		name = "rejoiner",
		rounds = 5,
		bots = concat({ { kind = "builder", tag = "rejoiner", userId = 9201, churn = { 25, 70 } } }, phones(3, 9210, "pc")),
	},
	{
		name = "buyer",
		rounds = 3,
		bots = concat({
			{
				kind = "builder",
				tag = "buyer",
				userId = 9301,
				buys = {
					{ label = "lobby", round = 1, phase = "ThemeReveal", after = 1 },
					{ label = "build-before-rush", round = 2, phase = "Build", after = 40 },
					{ label = "build-last-second", round = 3, phase = "Build", left = 0.3 },
					{ label = "tour-just-after", round = 3, phase = "Tour", after = 0.2 },
				},
			},
		}, phones(3, 9310, "pc")),
	},
	{
		name = "speed-late",
		rounds = 4,
		bots = concat(phones(3, 9410, "pc"), {
			{ kind = "late", userId = 9401, join = { round = 3, phase = "Build", after = 10 } },
			{ kind = "late", userId = 9402, join = { round = 3, phase = "Build", after = 45 } },
			{ kind = "late", userId = 9403, join = { round = 3, phase = "Tour", after = 1 } },
		}),
	},
	{
		name = "duo-split",
		rounds = 4,
		bots = concat({
			{ kind = "duo", tag = "duo-leaves", userId = 9501, leave = { round = 1, phase = "Build", after = 60 }, rejoinAfter = 20 },
			{ kind = "duo", tag = "duo-stays", userId = 9502 },
		}, phones(2, 9510, "pc")),
	},
	{
		name = "mixed10",
		rounds = 8,
		bots = concat(phones(4, 9610, "phone"), phones(3, 9620, "lowend"), phones(3, 9630, "pc")),
	},
}

local results = {}
for i, sc in ipairs(scenarios) do
	sc.seed = SEED + i * 17
	local out = run(sc)
	table.insert(results, out)
end

-- Report.
local lines = {}
local function w(s)
	table.insert(lines, s)
end
w("# Stress playtest, seed " .. SEED)
w("")
w("## Problems: " .. #problems)
for _, p in ipairs(problems) do
	w("- " .. p.kind .. ": " .. p.detail)
end
for _, out in ipairs(results) do
	w("")
	w("## " .. out.name .. string.format(" (%.1f min)", out.minutes))
	for _, r in ipairs(out.rounds) do
		w(string.format(
			"- round %d %s: %.0fs total; lobby %.0f build %.0f tour %.0f results %.0f; %d active, %s stops%s",
			r.n,
			r.modifier,
			r.total or 0,
			r.phases.Lobby or 0,
			r.phases.Build or 0,
			r.phases.Tour or 0,
			r.phases.Results or 0,
			r.active,
			tostring(r.stops or "-"),
			if r.rushAt then string.format(", rush at %.0fs", r.rushAt) else ""
		))
	end
	local kinds = {}
	for k in pairs(out.perKind) do
		table.insert(kinds, k)
	end
	table.sort(kinds)
	for _, k in ipairs(kinds) do
		local row = out.perKind[k]
		w(string.format("- pay %s: %.0f coins, %.0f xp per round (%d rows, %d spectating)", k, row.coins / row.n, row.xp / row.n, row.n, row.spectating))
	end
	w(string.format("- votes: %d sent, %d ok, %d crossed a stop in flight, %d counted for the wrong room, %d locked", out.votes.sent, out.votes.ok, out.votes.lagged, out.votes.misrouted, out.votes.lateLocked))
	w(string.format("- reports: %d sent, %d ok, %d wrong room, %d honest rooms removed", out.reports.sent, out.reports.ok, out.reports.misrouted, out.reports.removedHonest))
	w(string.format("- reactions: %d sent, %d ok, max %d on one stop", out.reactions.sent, out.reactions.ok, out.reactions.maxPerStop))
	for kind, s in pairs(out.spectateSeconds) do
		w(string.format("- %s spent %.0fs spectating with nothing to do", kind, s))
	end
	for _, p in ipairs(out.purchases) do
		w(string.format(
			"- +60s %s in %s: end %s -> %s (%s), coins %s -> %s, %s",
			p.label,
			p.phase,
			tostring(p.endsBefore and math.floor(p.endsBefore) or "-"),
			tostring(p.endsAfter and math.floor(p.endsAfter) or "-"),
			tostring(p.phaseAfter),
			tostring(p.coinsBefore),
			tostring(p.coinsAfter),
			tostring(p.decision)
		))
	end
	if out.churns then
		w("- rejoins: " .. out.churns)
	end
	if out.midBuildRejoins > 0 then
		w(string.format("- came back mid-build with pieces down: %d, room kept: %d", out.midBuildRejoins, out.roomsKept))
	end
	w(string.format("- DataStore: %d calls, peak %d a minute", out.store.calls, out.store.perMinutePeak))
end
fs.writeDir("playtest/out")
fs.writeFile("playtest/out/stress.md", table.concat(lines, "\n") .. "\n")
for _, out in ipairs(results) do
	for _, p in ipairs(out.purchases) do
		p.round = nil
	end
end
fs.writeFile("playtest/out/stress.json", serde.encode("json", results, true))
print(table.concat(lines, "\n"))
if #problems > 0 then
	process.exit(1)
end
