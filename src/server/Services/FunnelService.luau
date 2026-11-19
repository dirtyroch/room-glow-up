--!strict
-- Tutorial clock, Spot the Theme payout, and funnel events.
-- Analytics failures are swallowed. Names are not sent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FunnelService = {}
local ctx: any = nil
local Tutorial: any = nil
local Analytics: any = nil
local Spot: any = nil
local Themes: any = nil
local sessions: { [string]: any } = {}

local function keyOf(player: Player): string
	return tostring(player.UserId)
end

local function playerFrom(key: string): Player?
	local userId = tonumber(key)
	if not userId then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function emit(player: Player, event: string)
	local step = Analytics.step(event) or 0
	Analytics.play(function()
		local AnalyticsService = game:GetService("AnalyticsService")
		pcall(function()
			AnalyticsService:LogFunnelStepEvent(player, "GlowUp", "play", step, event)
		end)
		pcall(function()
			AnalyticsService:LogCustomEvent(player, event, step)
		end)
	end)
end

local function remember(player: Player?, bag: any, event: string)
	if type(bag) ~= "table" or bag.hold ~= true or type(bag.profile) ~= "table" then
		return
	end
	local marked = Analytics.mark(bag.profile, event)
	if not marked then
		return
	end
	local key = if player then keyOf(player) else ""
	if key ~= "" and ctx.saves and type(ctx.saves.queue) == "function" then
		ctx.saves.queue(key)
	end
	if player then
		emit(player, event)
	end
end

local function publishTutorial(player: Player, state: any)
	local now = workspace:GetServerTimeNow()
	local view = Tutorial.view(state, now)
	player:SetAttribute("TutorialActive", state.active == true)
	player:SetAttribute("TutorialHint", view.hint)
	player:SetAttribute("TutorialLine", view.line)
	player:SetAttribute("TutorialStars", view.stars)
	player:SetAttribute("TutorialPlaced", state.placed == true)
end

local function finishTutorial(key: string, state: any)
	sessions[key] = nil
	local player = playerFrom(key)
	local bag = ctx.saves.session(key)
	if bag.hold == true then
		Tutorial.complete(bag.profile, state, { rooms = {} }, { props = 0, coins = bag.profile.coins, xp = bag.profile.xp }, nil)
		remember(player, bag, "tutorial_done")
	end
	if player then
		player:SetAttribute("TutorialActive", false)
		player:SetAttribute("TutorialHint", "")
		player:SetAttribute("TutorialLine", "")
		player:SetAttribute("TutorialStars", 0)
		player:SetAttribute("TutorialPlaced", false)
	end
end

local function currentPhase(): string
	local round = ctx.round
	if type(round) == "table" and type(round.phase) == "string" then
		return round.phase
	end
	return ""
end

local function inLobby(): boolean
	local phase = currentPhase()
	return phase == "Lobby" or phase == ""
end

local function spectating(player: Player): boolean
	return player:GetAttribute("Spectating") == true
end

local function leftover(): number?
	local round = ctx.round
	if type(round) ~= "table" or type(round.phaseEndsAt) ~= "number" then
		return nil
	end
	return round.phaseEndsAt - workspace:GetServerTimeNow()
end

-- A just-opened lobby is only 20s. Hold it so a 30s Mini Room can finish.
-- The hold never runs past one Lobby plus one Mini Room from when the lobby
-- opened, so new kids arriving every few seconds cannot keep everyone waiting.
local function keepLobby(untilAt: number)
	local round = ctx.round
	if type(round) ~= "table" or round.phase ~= "Lobby" then
		return
	end
	local cap = untilAt
	local phases = if type(round.config) == "table" then round.config.Phases else nil
	if type(round.phaseStartedAt) == "number" and type(phases) == "table" and type(phases.Lobby) == "number" then
		cap = round.phaseStartedAt + phases.Lobby + Tutorial.pace().duration
	end
	local target = math.min(untilAt, cap)
	if type(round.phaseEndsAt) ~= "number" or target > round.phaseEndsAt then
		round.phaseEndsAt = target
	end
end

local function present(player: Player)
	local key = keyOf(player)
	local bag = ctx.saves.session(key)
	if bag.hold ~= true then
		return
	end
	remember(player, bag, "joined")
	if not Tutorial.needed(bag.profile) then
		player:SetAttribute("TutorialActive", false)
		return
	end
	local waiting = spectating(player) and not inLobby()
	-- Active players only see the Mini Room in the lobby, so it never covers
	-- Theme Reveal or a ballot. A spectator can start it while they wait.
	if not inLobby() and not waiting then
		player:SetAttribute("TutorialActive", false)
		return
	end
	if sessions[key] then
		publishTutorial(player, sessions[key])
		return
	end
	local pace = Tutorial.pace()
	local left = leftover()
	if not waiting and type(left) == "number" and left < pace.placeBy then
		player:SetAttribute("TutorialActive", false)
		return
	end
	local now = workspace:GetServerTimeNow()
	local state = Tutorial.start(now)
	sessions[key] = state
	if not waiting then
		local lobbySpan = 20
		if type(ctx.round) == "table" and type(ctx.round.config) == "table" then
			local phases = ctx.round.config.Phases
			if type(phases) == "table" and type(phases.Lobby) == "number" then
				lobbySpan = phases.Lobby
			end
		end
		if type(left) ~= "number" or left >= lobbySpan - 2 then
			keepLobby(now + pace.duration)
		end
	end
	publishTutorial(player, state)
end

local function publishSpot()
	local round = ctx.round
	local folder = ctx.RoundState
	if not folder or type(round) ~= "table" then
		return
	end
	if round.phase ~= "Results" then
		return
	end
	local existing = folder:GetAttribute("SpotChoices")
	if type(existing) == "string" and existing ~= "" then
		return
	end
	local span = 30
	local at = 10
	if type(round.config) == "table" and type(round.config.Phases) == "table" then
		local phases = round.config.Phases
		if type(phases.Results) == "number" then
			span = phases.Results
		end
		if type(phases.ResultsRewardsAt) == "number" then
			at = phases.ResultsRewardsAt
		end
	end
	local started = if type(round.phaseStartedAt) == "number" then round.phaseStartedAt else 0
	local elapsed = workspace:GetServerTimeNow() - started
	if not Spot.open(elapsed, at) then
		return
	end
	if elapsed > span then
		return
	end
	local themeId = ""
	local theme = round.theme
	if type(theme) == "table" and type(theme.id) == "string" then
		themeId = theme.id
	end
	local options = Spot.deal(themeId, Themes, round.roundIndex)
	folder:SetAttribute("SpotChoices", Spot.encode(options))
end

local function themeIdOf(round: any): string
	local theme = round.theme
	if type(theme) == "table" and type(theme.id) == "string" then
		return theme.id
	end
	return ""
end

local function roundKey(round: any): string
	return tostring(round.roundIndex) .. ":" .. themeIdOf(round)
end

local function onPhase(round: any)
	if type(round) == "table" and round.phase == "Lobby" then
		for _, player in Players:GetPlayers() do
			present(player)
		end
	else
		local keys: { string } = {}
		for key in pairs(sessions) do
			table.insert(keys, key)
		end
		for _, key in ipairs(keys) do
			local state = sessions[key]
			local player = playerFrom(key)
			if state and (not player or not spectating(player)) then
				finishTutorial(key, state)
			end
		end
		for _, player in Players:GetPlayers() do
			if spectating(player) then
				present(player)
			end
		end
	end
	local folder = ctx.RoundState
	if type(round) ~= "table" or round.phase ~= "Results" then
		if folder then
			folder:SetAttribute("SpotChoices", "")
		end
		return
	end
	local eventName: string? = nil
	if round.roundIndex == 0 then
		eventName = "round_1_finished"
	elseif round.roundIndex == 2 then
		eventName = "round_3_finished"
	end
	if eventName == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		local bag = ctx.saves.session(keyOf(player))
		remember(player, bag, eventName)
	end
end

function FunnelService.init(c: any)
	ctx = c
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	Themes = require(Shared:WaitForChild("Themes") :: ModuleScript) :: any
	local Logic = Shared:WaitForChild("Logic")
	Tutorial = require(Logic:WaitForChild("Tutorial") :: ModuleScript) :: any
	Analytics = require(Logic:WaitForChild("Analytics") :: ModuleScript) :: any
	Spot = require(Logic:WaitForChild("Spot") :: ModuleScript) :: any

	ctx.funnel = {
		present = present,
		onPhase = onPhase,
		onPlace = function(key: string)
			local player = playerFrom(key)
			if not player then
				return
			end
			remember(player, ctx.saves.session(key), "first_item")
		end,
		onVote = function(key: string)
			local player = playerFrom(key)
			if not player then
				return
			end
			remember(player, ctx.saves.session(key), "first_vote")
		end,
	}

	ctx.actions.register("TutorialPlace", {}, function(key: string): (boolean, string?)
		local state = sessions[key]
		if not state then
			return false, "No tutorial."
		end
		local ok, msg = Tutorial.place(state, workspace:GetServerTimeNow())
		local player = playerFrom(key)
		if player then
			publishTutorial(player, state)
		end
		return ok, msg
	end)

	ctx.actions.register("TutorialSkip", {}, function(key: string): (boolean, string?)
		local state = sessions[key]
		if not state then
			return true, "Skipped."
		end
		Tutorial.skip(state)
		finishTutorial(key, state)
		return true, "Skipped."
	end)

	ctx.actions.register("SpotGuess", { "string" }, function(key: string, args: { any }): (boolean, string?)
		local round = ctx.round
		if type(round) ~= "table" or round.phase ~= "Results" then
			return false, "Spot the Theme waits for results."
		end
		local podium = ""
		if ctx.RoundState then
			local value = ctx.RoundState:GetAttribute("Podium")
			if type(value) == "string" then
				podium = value
			end
		end
		if not Spot.visible(round.phase, podium) then
			return false, "The podium comes first."
		end
		local bag = ctx.saves.session(key)
		if bag.hold ~= true then
			return false, "Your save is still loading."
		end
		local correct = Spot.grade(args[1], themeIdOf(round))
		local coins = Spot.pay(bag.profile, roundKey(round), correct)
		ctx.saves.queue(key)
		if correct and coins > 0 then
			return true, "Plus " .. tostring(coins) .. " coins."
		end
		return true, "Not this one."
	end)

	ctx.actions.register("SpotSkip", {}, function(key: string): (boolean, string?)
		local round = ctx.round
		if type(round) == "table" and round.phase == "Results" then
			local bag = ctx.saves.session(key)
			if bag.hold == true then
				Spot.pay(bag.profile, roundKey(round), false)
				ctx.saves.queue(key)
			end
		end
		return true, "Skipped."
	end)

	ctx.actions.register("ShopOpen", {}, function(key: string): (boolean, string?)
		local player = playerFrom(key)
		if player then
			remember(player, ctx.saves.session(key), "shop_opened")
		end
		return true, "Shop."
	end)
end

function FunnelService.start()
	for _, player in Players:GetPlayers() do
		present(player)
	end
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		if inLobby() then
			for key, state in pairs(sessions) do
				Tutorial.tick(state, now)
				local player = playerFrom(key)
				if player then
					publishTutorial(player, state)
				end
				if state.finished then
					finishTutorial(key, state)
				end
			end
		else
			local keys: { string } = {}
			for key in pairs(sessions) do
				table.insert(keys, key)
			end
			for _, key in ipairs(keys) do
				local state = sessions[key]
				local player = playerFrom(key)
				if state and player and spectating(player) then
					Tutorial.tick(state, now)
					publishTutorial(player, state)
					if state.finished then
						finishTutorial(key, state)
						if ctx.progress and type(ctx.progress.welcome) == "function" then
							ctx.progress.welcome(player)
						end
					end
				elseif state then
					finishTutorial(key, state)
				end
			end
			for _, player in Players:GetPlayers() do
				local key = keyOf(player)
				if spectating(player) and sessions[key] == nil and player:GetAttribute("TutorialActive") ~= true then
					local bag = ctx.saves.session(key)
					if bag.hold == true and Tutorial.needed(bag.profile) then
						present(player)
					elseif ctx.progress and type(ctx.progress.welcome) == "function" then
						ctx.progress.welcome(player)
					end
				end
			end
		end
		publishSpot()
	end)
end

return FunnelService
