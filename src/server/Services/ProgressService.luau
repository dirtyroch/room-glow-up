--!strict
-- Coins, XP, levels, dream home, duo rooms, stamps, quests, and the monthly track.
-- Payouts run once, after Results settles, from the server ballot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressService = {}
local ctx: any = nil
local Config: any = nil
local Levels: any = nil
local Rewards: any = nil
local Dream: any = nil
local Duo: any = nil
local Quests: any = nil
local Collections: any = nil
local Rank: any = nil
local Monetization: any = nil
local Season: any = nil
local Shop: any = nil
local Owned: any = nil
local Themes: any = nil
local Items: any = nil
local Voting: any = nil
local Easter: any = nil
local Tutorial: any = nil
local RoundEngine: any = nil

local group: any = nil
local visiting: { [string]: boolean } = {}
local homes: { [string]: any } = {}
local hands: { [string]: { props: number, recolors: number } } = {}

local function catalog(): any
	return {
		get = function(id: string): any
			return Items.get(id)
		end,
	}
end

local function playerFrom(key: string): Player?
	local userId = tonumber(key)
	if not userId then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function bagOf(key: string): any
	return ctx.saves.session(key)
end

local function levelOf(profile: any): number
	return Levels.fromXp(profile.xp)
end

local function present(player: Player)
	local key = tostring(player.UserId)
	local bag = bagOf(key)
	player:SetAttribute("SaveOk", bag.hold == true)
	if bag.hold ~= true then
		player:SetAttribute("DuoOn", group.opted[key] == true)
		return
	end
	local level = levelOf(bag.profile)
	if Easter then
		local owned = 0
		if type(bag.profile.owned) == "table" then
			owned = #bag.profile.owned
		end
		Easter.grant(bag.profile, level)
		if type(bag.profile.owned) == "table" and #bag.profile.owned ~= owned then
			if ctx.saves and type(ctx.saves.apply) == "function" then
				pcall(function()
					ctx.saves.apply(key, bag.profile)
				end)
			end
		end
	end
	Dream.ensureSlots(bag.dream, Monetization.extraDreamSlots(key))
	player:SetAttribute("Level", level)
	player:SetAttribute("NextUnlock", Levels.next(level))
	player:SetAttribute("Purse", bag.profile.coins)
	player:SetAttribute("DuoOn", group.opted[key] == true)
	if ctx.shop and type(ctx.shop.refresh) == "function" then
		ctx.shop.refresh(player)
	end
end

local function handOf(key: string): { props: number, recolors: number }
	local row = hands[key]
	if not row then
		row = { props = 0, recolors = 0 }
		hands[key] = row
	end
	return row
end

local function syncHome(key: string)
	local room = homes[key]
	local bag = bagOf(key)
	if not room or not bag then
		return
	end
	Dream.ensureSlots(bag.dream, Monetization.extraDreamSlots(key))
	bag.dream.homes[1].pieces = Dream.piecesOf(room)
end

local function homeRoom(key: string): (any, any)
	local bag = bagOf(key)
	local level = levelOf(bag.profile)
	Dream.ensureSlots(bag.dream, Monetization.extraDreamSlots(key))
	if not homes[key] then
		homes[key] = Dream.roomFrom(bag.dream.homes[1].pieces, Dream.cap(level))
	end
	local dreamCtx = Dream.context(level, catalog(), workspace:GetServerTimeNow())
	if Owned and bag.profile then
		dreamCtx.allow = function(itemId: string): boolean
			return Owned.has(bag.profile, itemId, level)
		end
	end
	if Shop and bag.profile then
		dreamCtx.tools = Shop.hasPass(bag.profile, "DesignerTools") == true
		dreamCtx.materials = Config.Shop.Materials
	end
	return homes[key], dreamCtx
end

local function clearPlot(key: string)
	if not ctx.plots then
		return
	end
	local index = ctx.plots.indexOf(key)
	if type(index) == "number" and type(ctx.plots.clearIndex) == "function" then
		ctx.plots.clearIndex(index)
	end
end

local function showHome(key: string)
	local room, dreamCtx = homeRoom(key)
	clearPlot(key)
	local index = ctx.plots.indexOf(key)
	if type(index) ~= "number" then
		return
	end
	for _, piece in ipairs(room.pieces) do
		ctx.plots.spawnPiece(index, piece, dreamCtx.gridType, false)
	end
end

local function roundTypeOf(round: any): string
	local theme = round.theme
	if type(theme) == "table" and type(theme.roundType) == "string" then
		return theme.roundType
	end
	return "room"
end

local function activeIds(round: any): { string }
	local ids: { string } = {}
	for id, player in pairs(round.players) do
		if player.role == "active" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

local function publishDuo(round: any)
	local kind = roundTypeOf(round)
	for _, player in Players:GetPlayers() do
		local key = tostring(player.UserId)
		local paired = Duo.paired(group, key)
		player:SetAttribute("DuoOn", group.opted[key] == true)
		player:SetAttribute("PartnerName", nil)
		if paired and ctx.plots then
			local lead = Duo.leadOf(group, key)
			local index = ctx.plots.indexOf(lead)
			if type(index) == "number" then
				player:SetAttribute("BuildPlot", index)
			end
			player:SetAttribute("Grid", Duo.gridType(kind, true))
		elseif player:GetAttribute("AtHome") ~= true then
			player:SetAttribute("BuildPlot", nil)
			player:SetAttribute("Grid", nil)
		end
	end
end

local function openSandbox(key: string, player: Player)
	if visiting[key] then
		return
	end
	local bag = bagOf(key)
	if bag.hold ~= true then
		return
	end
	if Tutorial and Tutorial.needed(bag.profile) then
		return
	end
	visiting[key] = true
	local level = levelOf(bag.profile)
	player:SetAttribute("AtHome", true)
	player:SetAttribute("Grid", Dream.tier(level))
	player:SetAttribute("Level", level)
	player:SetAttribute("NextUnlock", Levels.next(level))
	player:SetAttribute("CanSandbox", true)
	showHome(key)
end

local function offerWait(player: Player)
	local key = tostring(player.UserId)
	local round = ctx.round
	local waiting = false
	if type(round) == "table" and RoundEngine then
		waiting = RoundEngine.playerView(round, key).spectating == true
	else
		waiting = player:GetAttribute("Spectating") == true
	end
	player:SetAttribute("CanSandbox", waiting)
	if not waiting then
		return
	end
	openSandbox(key, player)
end

local function endVisits()
	for key in pairs(visiting) do
		syncHome(key)
		local player = playerFrom(key)
		if player then
			player:SetAttribute("AtHome", false)
			player:SetAttribute("Grid", nil)
		end
	end
	visiting = {}
end

local function applySkip(round: any)
	round.tourSkip = {}
	for id in pairs(group.partner) do
		if Duo.leadOf(group, id) ~= id then
			round.tourSkip[id] = true
		end
	end
end

local function rowFor(rows: { any }, key: string): (number, any)
	local lead = Duo.leadOf(group, key)
	for index, row in ipairs(rows) do
		if row.owner == key or row.owner == lead then
			return index, row
		end
	end
	return 0, nil
end

local function themeName(round: any): (string, string)
	local theme = round.theme
	if type(theme) ~= "table" then
		return "", ""
	end
	local id = if type(theme.id) == "string" then theme.id else ""
	local name = if type(theme.name) == "string" then theme.name else ""
	return id, name
end

local function settle(round: any)
	if round.phase ~= "Results" then
		return
	end
	local ballots = if ctx.votes then ctx.votes.ballots else nil
	local rows = if ballots then Voting.standings(ballots) else {}
	local eyeMap = if ballots then ballots.eyeCoins else {}
	local themeId, themeLabel = themeName(round)
	local clock = os.time()
	local offset = if Season then Season.centralOffset(clock) else Config.TimezoneOffsetHours
	local dayKey = Quests.dayKey(clock, offset)
	local monthId = Rank.month(clock, offset)
	local roundId = ctx.sessionId .. ":" .. tostring(round.roundIndex)
	local hooks = {
		coinMultiplier = function(userId: string?): number
			return Monetization.coinMultiplier(userId)
		end,
		luck = function(userId: string?): boolean
			return Monetization.luck(userId)
		end,
	}
	local toSave: { string } = {}
	for _, player in Players:GetPlayers() do
		local key = tostring(player.UserId)
		local bag = bagOf(key)
		-- A failed load uses a blank in-memory bag with hold = false.
		-- Do not pay or save it, or a later write could hide the real profile.
		if bag.hold ~= true then
			player:SetAttribute("SaveOk", false)
			continue
		end
		local profile = bag.profile
		local before = levelOf(profile)
		local rank, row = rowFor(rows, key)
		local average = if row then row.average else 0
		local podium = if rank >= 1 and rank <= Config.Voting.Podium then rank else 0
		local eye = Rewards.eyeFromBallot(eyeMap, key)
		local payout = Rewards.grant(profile, {
			roundId = roundId,
			rank = rank,
			average = average,
			podium = podium,
			eye = eye,
			userId = key,
		}, Config, hooks)
		local stamp = { stamped = false, setComplete = false, coins = 0, xp = 0, setName = "" }
		if rank > 0 and not payout.duplicate then
			stamp = Collections.consider(profile, themeId, average, Themes, Config)
		end
		local hand = handOf(key)
		local pieces = 0
		local meter = 0
		local lead = Duo.leadOf(group, key)
		if ctx.rooms and type(ctx.rooms.inspect) == "function" and rank > 0 then
			local facts = ctx.rooms.inspect(lead)
			if type(facts) == "table" then
				pieces = facts.pieces or 0
				meter = facts.meter or 0
			end
		end
		Quests.ensure(profile, dayKey)
		local questStats = {
			rooms = if rank > 0 then 1 else 0,
			starRounds = if rank > 0 and average >= 3 then 1 else 0,
			props = hand.props,
			meterRounds = if rank > 0 and meter >= 48 then 1 else 0,
			recolors = hand.recolors,
			fullRounds = if rank > 0 and pieces >= 8 then 1 else 0,
		}
		local questDone, questCoins = 0, 0
		if not payout.duplicate then
			questDone, questCoins = Quests.apply(profile, questStats, Config.Progress.QuestCoins)
			profile.coins += questCoins
		else
			for _, quest in ipairs(profile.quests) do
				if type(quest) == "table" and type(quest.progress) == "number" and type(quest.goal) == "number" then
					if quest.progress >= quest.goal then
						questDone += 1
					end
				end
			end
		end
		local rankXp = if payout.duplicate then 0 else payout.xp
		local ranked = Rank.award(profile, monthId, rankXp, Config.RankTrack)
		local after = levelOf(profile)
		if Easter then
			Easter.grant(profile, after)
		end
		local sets = Levels.setsBetween(before, after)
		local names: { string } = {}
		for _, unlock in ipairs(sets) do
			table.insert(names, unlock.name)
		end
		local unlockLine = ""
		if #names > 0 then
			unlockLine = "New: " .. table.concat(names, ", ")
		end
		local stampLine = ""
		if stamp.stamped then
			if stamp.setComplete then
				stampLine = stamp.setName .. " complete"
			elseif themeLabel ~= "" then
				stampLine = "Stamp: " .. themeLabel
			else
				stampLine = "New stamp"
			end
		end
		local award = payout.coins + (stamp.coins or 0) + questCoins + (ranked.coins or 0)
		player:SetAttribute("AwardCoins", award)
		player:SetAttribute("AwardXp", payout.xp + (stamp.xp or 0))
		player:SetAttribute("Level", after)
		player:SetAttribute("LevelUp", if after > before then after else 0)
		player:SetAttribute("UnlockLine", unlockLine)
		player:SetAttribute("NextUnlock", Levels.next(after))
		player:SetAttribute("StampLine", stampLine)
		player:SetAttribute("QuestLine", "Quests " .. tostring(questDone) .. "/3")
		player:SetAttribute("Purse", profile.coins)
		player:SetAttribute("SaveOk", true)
		table.insert(toSave, key)
	end
	-- Everyone sees their coins first. Then the writes run side by side, so ten
	-- saves do not hold the podium, the minigame, and the last kid's payout.
	if ctx.saves then
		for _, key in ipairs(toSave) do
			task.spawn(ctx.saves.commit, key, "results")
		end
	end
end

function ProgressService.init(c: any)
	ctx = c
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
	Themes = require(Shared:WaitForChild("Themes") :: ModuleScript) :: any
	Items = require(Shared:WaitForChild("Items") :: ModuleScript) :: any
	local Logic = Shared:WaitForChild("Logic")
	Levels = require(Logic:WaitForChild("Levels") :: ModuleScript) :: any
	Rewards = require(Logic:WaitForChild("Rewards") :: ModuleScript) :: any
	Dream = require(Logic:WaitForChild("Dream") :: ModuleScript) :: any
	Duo = require(Logic:WaitForChild("Duo") :: ModuleScript) :: any
	Quests = require(Logic:WaitForChild("Quests") :: ModuleScript) :: any
	Collections = require(Logic:WaitForChild("Collections") :: ModuleScript) :: any
	Rank = require(Logic:WaitForChild("Rank") :: ModuleScript) :: any
	Monetization = require(Logic:WaitForChild("Monetization") :: ModuleScript) :: any
	Voting = require(Logic:WaitForChild("Voting") :: ModuleScript) :: any
	Season = require(Logic:WaitForChild("Season") :: ModuleScript) :: any
	Shop = require(Logic:WaitForChild("Shop") :: ModuleScript) :: any
	Owned = require(Logic:WaitForChild("Owned") :: ModuleScript) :: any
	Easter = require(Logic:WaitForChild("Easter") :: ModuleScript) :: any
	Tutorial = require(Logic:WaitForChild("Tutorial") :: ModuleScript) :: any
	RoundEngine = require(Logic:WaitForChild("RoundEngine") :: ModuleScript) :: any
	group = Duo.create()

	ctx.duo = {
		lead = function(id: string): string
			return Duo.leadOf(group, id)
		end,
		partner = function(id: string): string?
			return Duo.partnerOf(group, id)
		end,
		paired = function(id: string): boolean
			return Duo.paired(group, id)
		end,
		owners = function(id: string): { string }
			return Duo.owners(group, id)
		end,
		noteLeave = function(round: any, id: string): (string?, boolean)
			local partner, wasLead = Duo.detach(group, id)
			if wasLead and partner and type(round.tourSkip) == "table" then
				round.tourSkip[partner] = nil
			end
			return partner, wasLead
		end,
	}
	ctx.family = {
		duoAll = function(ids: { string }, phase: string, enabled: boolean): (boolean, string?)
			local ok, msg = Duo.setAll(group, ids, phase, enabled)
			if ctx.round then
				publishDuo(ctx.round)
			end
			return ok, msg
		end,
	}
	ctx.dream = {
		isVisiting = function(key: string): boolean
			return visiting[key] == true
		end,
		editing = function(key: string): (any, any)
			return homeRoom(key)
		end,
		sync = syncHome,
	}
	ctx.progress = {
		present = present,
		bump = function(key: string, stat: string)
			local row = handOf(key)
			if stat == "props" then
				row.props += 1
			elseif stat == "recolors" then
				row.recolors += 1
			end
		end,
		onPhase = function(round: any)
			if round.phase == "Lobby" then
				endVisits()
				Duo.clearRound(group)
				round.tourSkip = {}
				hands = {}
				publishDuo(round)
				for _, player in Players:GetPlayers() do
					player:SetAttribute("AwardCoins", nil)
					player:SetAttribute("AwardXp", nil)
					player:SetAttribute("LevelUp", 0)
					player:SetAttribute("UnlockLine", "")
					player:SetAttribute("StampLine", "")
					player:SetAttribute("QuestLine", "")
					player:SetAttribute("CanSandbox", false)
				end
				return
			end
			if round.phase == "ThemeReveal" then
				endVisits()
				if round.modifier == "mirror" then
					Duo.pairAll(group, activeIds(round))
				else
					Duo.freeze(group, activeIds(round))
				end
				applySkip(round)
				publishDuo(round)
			elseif round.phase == "Build" then
				hands = {}
				publishDuo(round)
			end
			for _, player in Players:GetPlayers() do
				offerWait(player)
			end
		end,
		welcome = function(player: Player)
			offerWait(player)
		end,
		settle = settle,
	}

	ctx.actions.register("Duo", {}, function(key: string, _args: { any }): (boolean, string?)
		local round = ctx.round
		local phase = if type(round) == "table" then round.phase else ""
		local ok, msg = Duo.toggle(group, key, phase)
		local player = playerFrom(key)
		if player then
			player:SetAttribute("DuoOn", group.opted[key] == true)
		end
		return ok, msg
	end)

	ctx.actions.register("Home", {}, function(key: string, _args: { any }): (boolean, string?)
		local round = ctx.round
		local waiting = false
		if type(round) == "table" and RoundEngine then
			waiting = RoundEngine.playerView(round, key).spectating == true
		end
		if type(round) ~= "table" or (round.phase ~= "Lobby" and not waiting) then
			return false, "The dream home is open in the lobby."
		end
		local bag = bagOf(key)
		if bag.hold ~= true then
			return false, "Your home is still loading."
		end
		local player = playerFrom(key)
		if not player then
			return false, "You are not in this round."
		end
		if visiting[key] then
			syncHome(key)
			visiting[key] = nil
			player:SetAttribute("AtHome", false)
			player:SetAttribute("Grid", nil)
			clearPlot(key)
			return true, "Back in the lobby."
		end
		visiting[key] = true
		local level = levelOf(bagOf(key).profile)
		player:SetAttribute("AtHome", true)
		player:SetAttribute("Grid", Dream.tier(level))
		player:SetAttribute("Level", level)
		player:SetAttribute("NextUnlock", Levels.next(level))
		showHome(key)
		return true, "Welcome home."
	end)

	ctx.actions.register("Keep", {}, function(key: string, _args: { any }): (boolean, string?)
		local round = ctx.round
		if type(round) ~= "table" or round.phase ~= "Results" then
			return false, "You can save a look after the tour."
		end
		local ballots = if ctx.votes then ctx.votes.ballots else nil
		if not ballots then
			return false, "No score yet."
		end
		local rows = Voting.standings(ballots)
		local rank, row = rowFor(rows, key)
		if rank < 1 or not row then
			return false, "No score yet."
		end
		if not ctx.rooms or type(ctx.rooms.copyPieces) ~= "function" then
			return false, "No score yet."
		end
		local lead = Duo.leadOf(group, key)
		local pieces = ctx.rooms.copyPieces(lead)
		local themeId, themeLabel = themeName(round)
		local bag = bagOf(key)
		local snap = {
			roundId = ctx.sessionId .. ":" .. tostring(round.roundIndex),
			themeId = themeId,
			themeName = themeLabel,
			roundType = roundTypeOf(round),
			average = row.average,
			pieces = pieces,
		}
		local ok, msg = Dream.remember(bag.dream.lookbook, snap, Config.Progress.Lookbook)
		return ok, msg
	end)
end

return ProgressService
