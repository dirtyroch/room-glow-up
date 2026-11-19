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
	if key ~= "" and ctx.saves and type(ctx.saves.apply) == "function" then
		pcall(function()
			ctx.saves.apply(key, bag.profile)
		end)
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
	if sessions[key] then
		publishTutorial(player, sessions[key])
		return
	end
	local state = Tutorial.start(workspace:GetServerTimeNow())
	sessions[key] = state
	publishTutorial(player, state)
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
	local folder = ctx.RoundState
	if type(round) ~= "table" or round.phase ~= "Results" then
		if folder then
			folder:SetAttribute("SpotChoices", "")
		end
		return
	end
	local options = Spot.deal(themeIdOf(round), Themes, round.roundIndex)
	if folder then
		folder:SetAttribute("SpotChoices", Spot.encode(options))
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
		pcall(function()
			ctx.saves.apply(key, bag.profile)
		end)
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
				pcall(function()
					ctx.saves.apply(key, bag.profile)
				end)
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
	end)
end

return FunnelService
