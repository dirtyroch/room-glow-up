--!nocheck
-- Simulated players. Each bot only reads what a real client could read
-- (replicated attributes on RoundState, Players, and plot models) and only
-- talks to the server through the one Action remote.

local Items = require("../src/shared/Items")
local Bases = require("../src/shared/Bases")
local Config = require("../src/shared/Config")
local Spot = require("../src/shared/Logic/Spot")
local Levels = require("../src/shared/Logic/Levels")

local Bots = {}

-- Newer servers want the plot on screen with each Vote and Report. Older
-- builds (for before/after runs) take the bare form.
local fs = require("@lune/fs")
local okSrc, voteSrc = pcall(fs.readFile, "src/server/Services/VoteService.luau")
Bots.namesStop = okSrc and string.find(voteSrc, "stillOnStage", 1, true) ~= nil

local function stopArg(plot)
	if Bots.namesStop then
		return plot or 0
	end
	return nil
end

-- kind: builder | newbie | returning | leaver | idle | duo | spammer | novote | late
--       | griefer (one piece then DONE, spams React/Report/Vote) | rejoiner
-- spec.lag = { min, max }: a slow phone network. Every call lands that much later.
-- spec.slow = number: a phone kid who taps slower (think gaps times this).
function Bots.new(world, rng, spec)
	local bot = {
		world = world,
		rng = rng,
		spec = spec,
		kind = spec.kind,
		name = spec.name,
		display = spec.display or spec.name,
		userId = spec.userId,
		player = nil,
		nextThink = 0,
		placed = 0,
		target = spec.target or rng:NextInteger(6, 12),
		skill = spec.skill or rng:NextNumber(0.3, 0.95),
		doneAt = nil,
		pressedDone = false,
		votedFor = {},
		lastStop = 0,
		voteAt = nil,
		log = {},
		responses = {},
		tutorial = nil,
		spotDone = false,
		lastPhase = "",
		phaseSince = 0,
		roundSeen = 0,
	}
	return bot
end

-- Returns ok, msg. A handler that yields counts as ok for now; its row is
-- filled in when it returns, so the report still sees the real answer.
local function rs(world)
	return world.game:GetService("ReplicatedStorage"):FindFirstChild("RoundState")
end

local function send(bot, row, action, a, b, c)
	local state = rs(bot.world)
	row.landedIndex = state and state:GetAttribute("TourIndex") or 0
	row.landedPhase = state and state:GetAttribute("Phase") or ""
	if not bot.player or bot.left then
		row.status = "dropped"
		return
	end
	local _payload, status = bot.world:invoke(bot.player, action, a, b, c, function(p, took)
		row.ok = type(p) == "table" and p.ok == true
		row.msg = if type(p) == "table" then p.msg else nil
		row.status = "done"
		row.took = took
	end)
	return status
end

-- Calls that were sent over a laggy network and have now arrived.
function Bots.flush(bot, now)
	local queue = bot.queue
	if not queue or #queue == 0 then
		return
	end
	local keep = {}
	for _, item in ipairs(queue) do
		if now >= item.due then
			send(bot, item.row, item.action, item.a, item.b, item.c)
		else
			table.insert(keep, item)
		end
	end
	bot.queue = keep
end

function Bots.call(bot, action, a, b, c)
	local state = rs(bot.world)
	local row = { at = bot.world.clock, action = action, ok = false, msg = nil, status = "pending" }
	row.sentIndex = state and state:GetAttribute("TourIndex") or 0
	row.sentPhase = state and state:GetAttribute("Phase") or ""
	table.insert(bot.responses, row)
	local lag = bot.spec.lag
	if type(lag) == "table" then
		bot.queue = bot.queue or {}
		table.insert(bot.queue, { due = bot.world.clock + bot.rng:NextNumber(lag[1], lag[2]), row = row, action = action, a = a, b = b, c = c })
		return true, "queued", nil
	end
	row.landedIndex = row.sentIndex
	row.landedPhase = row.sentPhase
	local payload, status = bot.world:invoke(bot.player, action, a, b, c, function(p, took)
		row.ok = type(p) == "table" and p.ok == true
		row.msg = if type(p) == "table" then p.msg else nil
		row.status = "done"
		row.took = took
	end)
	if status == "pending" then
		return true, "pending", nil
	end
	return row.ok, row.msg, payload
end

function Bots.join(bot)
	bot.player = bot.world:addPlayer(bot.name, bot.display, bot.userId)
	bot.userId = bot.player.UserId
	bot.joinedAt = bot.world.clock
	bot.left = false
	return bot.player
end

function Bots.leave(bot)
	if bot.player and not bot.left then
		bot.world:removePlayer(bot.player)
		bot.left = true
	end
end

local function gridFor(bot, state)
	local grid = bot.player:GetAttribute("Grid")
	if type(grid) == "string" and grid ~= "" then
		return grid
	end
	local roundType = state:GetAttribute("RoundType")
	if type(roundType) ~= "string" or roundType == "" then
		return "room"
	end
	return roundType
end

local function baseType(grid)
	if string.sub(grid, 1, 4) == "duo_" then
		return string.sub(grid, 5)
	end
	return grid
end

local function tryPlace(bot, state)
	local grid = gridFor(bot, state)
	local roundType = baseType(grid)
	local themeId = state:GetAttribute("ThemeId")
	local pool = Items.forRound(roundType)
	local mystery = state:GetAttribute("MysteryItem")
	if #pool == 0 then
		return false
	end
	local coins = bot.player:GetAttribute("CoinsLeft") or 0
	-- Skilled bots pick theme pieces. Everyone else grabs what is on top.
	local picks = {}
	local level = bot.player:GetAttribute("Level") or 1
	local owned = bot.player:GetAttribute("OwnedItems") or ""
	for _, item in ipairs(pool) do
		-- The tray greys out locked pieces, so a kid does not keep tapping them.
		local unlocked = Levels.owns(item.id, level) or string.find("," .. owned .. ",", "," .. item.id .. ",", 1, true) ~= nil
		if unlocked and (item.cost <= coins or item.id == mystery) then
			local weight = 1
			if table.find(item.tags, themeId) and bot.rng:NextNumber() < bot.skill then
				weight = 6
			end
			if item.id == mystery then
				weight += 4
			end
			for _ = 1, weight do
				table.insert(picks, item)
			end
		end
	end
	if #picks == 0 then
		return false
	end
	for _ = 1, 3 do
		local item = picks[bot.rng:NextInteger(1, #picks)]
		local g = Bases.grid(grid, item.surface)
		local x, z = 0, 0
		if g then
			x = bot.rng:NextInteger(0, math.max(0, g.x - item.w))
			z = if item.surface == "hook" then 0 else bot.rng:NextInteger(0, math.max(0, g.z - item.d))
		elseif item.surface == "hook" then
			x = bot.rng:NextInteger(0, Bases.HookCount - 1)
		end
		local ok, msg = Bots.call(bot, "Place", item.id, x, z)
		if ok then
			bot.placed += 1
			if bot.firstPlaceAt == nil then
				bot.firstPlaceAt = bot.world.clock
			end
			return true
		end
		if msg == "Not enough coins." or msg == "This room is full." then
			return false
		end
	end
	return true
end

local function starsFor(bot, meter)
	-- Kids vote on what they see. The meter is public on the plot sign.
	local base = 1 + (meter or 0) / 25
	local noise = bot.rng:NextNumber(-1.2, 1.2)
	if bot.spec.generous then
		return 5
	end
	return math.clamp(math.floor(base + noise + 0.5), 1, 5)
end

function Bots.think(bot, now)
	if bot.left or not bot.player then
		return
	end
	Bots.flush(bot, now)
	local world = bot.world
	local state = rs(world)
	if not state then
		return
	end
	local phase = state:GetAttribute("Phase")
	if bot.player:GetAttribute("TutorialActive") == true then
		if not bot.tutorial then
			bot.tutorial = { seenAt = now, lobbyLeft = state:GetAttribute("TimeLeft") }
			bot.tutorial.tapAt = now + (bot.spec.tutorialReact or bot.rng:NextNumber(3, 9))
		end
		if not bot.tutorial.placedAt and now >= bot.tutorial.tapAt then
			local ok, msg = Bots.call(bot, "TutorialPlace")
			if ok then
				bot.tutorial.placedAt = now
			else
				bot.tutorial.failed = msg
			end
		end
	end

	if phase ~= bot.lastPhase then
		bot.lastPhase = phase
		bot.phaseSince = now
		bot.nextThink = now + bot.rng:NextNumber(0.5, 3)
		if phase == "Build" then
			bot.placed = 0
			bot.pressedDone = false
			bot.target = bot.spec.target or bot.rng:NextInteger(6, 12)
			bot.firstPlaceAt = nil
			bot.spectating = bot.player:GetAttribute("Spectating") == true
			-- First tap usually lands within a few seconds of the build clock.
			bot.nextThink = now + bot.rng:NextNumber(2, 8)
		elseif phase == "Results" then
			bot.spotDone = false
		elseif phase == "Lobby" then
			bot.duoAsked = false
		end
	end

	-- Spammer taps every shop button over and over, in every phase.
	if bot.kind == "spammer" and now >= (bot.nextSpam or 0) then
		bot.nextSpam = now + 0.25
		local keys = bot.shopKeys
		if not keys then
			keys = {}
			for k in pairs(Config.Shop.Passes) do
				table.insert(keys, k)
			end
			for k in pairs(Config.Shop.Products) do
				table.insert(keys, k)
			end
			table.sort(keys)
			bot.shopKeys = keys
		end
		Bots.call(bot, "Buy", keys[bot.rng:NextInteger(1, #keys)])
		if bot.rng:NextNumber() < 0.2 then
			Bots.call(bot, "Code", if bot.rng:NextNumber() < 0.5 then "WELCOME" else "FREEROBUX")
		end
		Bots.call(bot, "ShopOpen")
	end

	-- Griefer: every tour stop, report it, one-star it, and mash reactions.
	if bot.kind == "griefer" and phase == "Tour" and now >= (bot.nextGrief or 0) then
		bot.nextGrief = now + 0.2
		Bots.call(bot, "React", bot.rng:NextInteger(0, #Config.Show.Crowd + 1))
		local stop = state:GetAttribute("TourIndex") or 0
		if stop ~= bot.griefStop then
			bot.griefStop = stop
			Bots.call(bot, "Report", stopArg(state:GetAttribute("TourPlot")))
		end
		if bot.rng:NextNumber() < 0.3 then
			Bots.call(bot, "Vote", 1, stopArg(state:GetAttribute("TourPlot")))
		end
	end

	if now < bot.nextThink then
		return
	end
	bot.nextThink = now + 0.5
	local slow = bot.spec.slow or 1

	if phase == "Lobby" then
		if bot.kind == "duo" and not bot.duoAsked then
			bot.duoAsked = true
			if bot.player:GetAttribute("DuoOn") ~= true then
				Bots.call(bot, "Duo")
			end
		end
		return
	end

	if phase == "Build" then
		if bot.player:GetAttribute("Spectating") == true then
			return
		end
		if bot.kind == "idle" then
			return
		end
		if bot.kind == "griefer" then
			-- One piece, then DONE straight away, to try to cut everyone's build.
			if bot.placed == 0 then
				tryPlace(bot, state)
			elseif not bot.pressedDone then
				bot.pressedDone = true
				Bots.call(bot, "Done")
			end
			return
		end
		if bot.placed < bot.target then
			local before = bot.placed
			local ok = tryPlace(bot, state)
			bot.misses = if bot.placed > before then 0 else (bot.misses or 0) + 1
			-- A kid who keeps missing a full room stops and presses DONE.
			if not ok or bot.misses >= 4 then
				bot.target = bot.placed
			end
			bot.nextThink = now + bot.rng:NextNumber(3, 11) * slow
			if bot.rng:NextNumber() < 0.15 and bot.placed > 0 then
				Bots.call(bot, "Recolor", 1, Config.Palette[bot.rng:NextInteger(1, #Config.Palette)])
			end
			if bot.rng:NextNumber() < 0.08 and bot.placed > 0 then
				Bots.call(bot, "Undo")
				bot.placed = math.max(0, bot.placed - 1)
			end
			return
		end
		if not bot.pressedDone and bot.spec.pressesDone ~= false then
			bot.pressedDone = true
			Bots.call(bot, "Done")
		end
		return
	end

	if phase == "Tour" then
		local stop = state:GetAttribute("TourIndex") or 0
		local plot = state:GetAttribute("TourPlot") or 0
		if stop ~= bot.lastStop then
			bot.lastStop = stop
			bot.voteAt = now + bot.rng:NextNumber(1.0, 7.5) * slow
			bot.voteTarget = plot
			if bot.kind ~= "novote" and bot.rng:NextNumber() < 0.7 then
				Bots.call(bot, "React", bot.rng:NextInteger(1, #Config.Show.Crowd))
			end
		end
		if bot.kind == "novote" or bot.kind == "griefer" then
			return
		end
		if bot.voteAt and now >= bot.voteAt then
			bot.voteAt = nil
			local myPlot = bot.player:GetAttribute("BuildPlot") or bot.player:GetAttribute("Plot")
			if plot ~= 0 and plot ~= myPlot then
				local model = world.workspace:FindFirstChild("Plots")
				model = model and model:FindFirstChild("Plot" .. tostring(plot))
				local meter = model and model:GetAttribute("ThemeMatch") or 0
				local ok, msg = Bots.call(bot, "Vote", starsFor(bot, meter), stopArg(plot))
				bot.votes = (bot.votes or 0) + 1
				if not ok then
					bot.voteFails = bot.voteFails or {}
					bot.voteFails[msg or "?"] = (bot.voteFails[msg or "?"] or 0) + 1
				end
			end
		end
		return
	end

	if phase == "Results" then
		if not bot.spotDone then
			local choices = state:GetAttribute("SpotChoices")
			local podium = state:GetAttribute("Podium")
			if type(choices) == "string" and choices ~= "" and type(podium) == "string" and podium ~= "" then
				if now - bot.phaseSince > 4 then
					bot.spotDone = true
					local options = Spot.decode(choices)
					if #options > 0 and bot.rng:NextNumber() < 0.7 then
						local pick = options[bot.rng:NextInteger(1, #options)]
						Bots.call(bot, "SpotGuess", pick.id)
					else
						Bots.call(bot, "SpotSkip")
					end
				end
			end
		end
		return
	end
end

return Bots
