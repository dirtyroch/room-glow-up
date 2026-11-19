--!strict
-- Runs the round loop and copies it onto attributes. DONE is the only client action.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoundService = {}
local ctx: any = nil
local state: any = nil
local RoundEngine: any = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function keyOf(player: Player): string
	return tostring(player.UserId)
end

local function publish(at: number)
	local snap = RoundEngine.snapshot(state, at)
	local folder = ctx.RoundState
	local seconds = math.max(0, math.ceil(snap.timeLeft - 1e-6))
	folder:SetAttribute("Phase", snap.phase)
	folder:SetAttribute("TimeLeft", seconds)
	folder:SetAttribute("EndsAt", snap.endsAt)
	folder:SetAttribute("Waiting", snap.waiting == true)
	folder:SetAttribute("ThemeName", snap.themeName)
	folder:SetAttribute("ThemeId", snap.themeId)
	folder:SetAttribute("RoundType", snap.roundType)
	folder:SetAttribute("Season", snap.season)
	folder:SetAttribute("TourLabel", snap.tourLabel)
	folder:SetAttribute("TourIndex", snap.tourIndex or 0)
	-- Never replicate the owner's user id. The camera and vote UI use TourPlot.
	folder:SetAttribute("TourTarget", "")
	local tourPlot = 0
	if snap.tourTarget ~= "" and ctx.plots then
		local index = ctx.plots.indexOf(snap.tourTarget)
		if type(index) == "number" then
			tourPlot = index
		end
	end
	folder:SetAttribute("TourPlot", tourPlot)
	folder:SetAttribute("Critic", snap.critic)
	if ctx.plots and type(ctx.plots.veil) == "function" then
		ctx.plots.veil(snap.phase)
	end
	if ctx.votes and type(ctx.votes.sync) == "function" then
		ctx.votes.sync(state)
	end
	for _, player in Players:GetPlayers() do
		local view = RoundEngine.playerView(state, keyOf(player))
		player:SetAttribute("Spectating", view.spectating)
		player:SetAttribute("BuildDone", view.done)
	end
end

local function onJoin(player: Player)
	RoundEngine.join(state, keyOf(player), now())
	if ctx.plots then
		ctx.plots.assign(player)
	end
	if ctx.rooms then
		ctx.rooms.welcome(player)
	end
	publish(now())
end

local function onLeave(player: Player)
	local key = keyOf(player)
	if ctx.duo and type(ctx.duo.noteLeave) == "function" then
		ctx.duo.noteLeave(state, key)
	end
	RoundEngine.leave(state, key, now())
	if ctx.rooms then
		ctx.rooms.forget(key)
	end
	if ctx.plots then
		ctx.plots.release(player)
	end
	if ctx.actions then
		ctx.actions.forget(key)
	end
	if ctx.votes and type(ctx.votes.forget) == "function" then
		ctx.votes.forget(key)
	end
	publish(now())
end

function RoundService.init(c: any)
	ctx = c
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
	local Themes = require(Shared:WaitForChild("Themes") :: ModuleScript) :: any
	local Logic = Shared:WaitForChild("Logic")
	RoundEngine = require(Logic:WaitForChild("RoundEngine") :: ModuleScript) :: any
	state = RoundEngine.create({
		config = Config,
		themes = Themes,
		unixNow = function()
			return os.time()
		end,
	})
	ctx.round = state
	ctx.actions.register("Done", {}, function(playerKey: string): (boolean, string?)
		local at = now()
		local ok, msg = RoundEngine.pressDone(state, playerKey, at)
		publish(at)
		return ok, msg
	end)
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	publish(now())
	ctx.republish = function()
		publish(now())
	end
end

-- Server-only hook for a future private-server host control. Not a client remote.
function RoundService.setHostTheme(themeId: string?): (boolean, string?)
	if not state then
		return false, "Not ready."
	end
	local ok, msg = RoundEngine.setHostTheme(state, themeId)
	return ok, msg
end

function RoundService.start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local at = now()
		local before = state.phase
		local beforeTour = state.tourIndex
		local wasLocked = RoundEngine.roomLocked(state, at)
		RoundEngine.advance(state, at)
		local nowLocked = RoundEngine.roomLocked(state, at)
		if state.phase ~= before then
			if ctx.progress and type(ctx.progress.onPhase) == "function" then
				ctx.progress.onPhase(state)
			end
			if ctx.rooms then
				ctx.rooms.onPhase(state)
			end
			if ctx.votes and type(ctx.votes.onPhase) == "function" then
				ctx.votes.onPhase(state, at)
			end
			if ctx.progress and type(ctx.progress.settle) == "function" then
				ctx.progress.settle(state)
			end
		end
		acc += dt
		if state.phase ~= before or state.tourIndex ~= beforeTour or wasLocked ~= nowLocked or acc >= 0.25 then
			acc = 0
			publish(at)
		end
	end)
end

return RoundService
