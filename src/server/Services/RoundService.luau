--!strict
-- Runs the round loop and copies it onto attributes. DONE is the only client action.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoundService = {}
local ctx: any = nil
local state: any = nil
-- The phase the phase hooks last ran for. A DONE press, a leave, or a report can
-- move the round between heartbeats, so compare against this, not the tick start.
local seenPhase: string? = nil
local seenRound: number? = nil
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
	folder:SetAttribute("Modifier", snap.modifierLabel or "")
	folder:SetAttribute("MysteryItem", snap.mysteryItem or "")
	folder:SetAttribute("Banner", snap.banner or "")
	folder:SetAttribute("VotesOpen", snap.votesOpen == true)
	local nextRound = snap.nextRound
	if type(nextRound) ~= "number" then
		nextRound = 0
	end
	folder:SetAttribute("NextRound", math.max(0, math.ceil(nextRound - 1e-6)))
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

-- Rooms kept through a short disconnect, by player key.
local parked: { [string]: { round: number, untilAt: number } } = {}
local graceSeconds = 60

local function canResume(key: string, at: number): (boolean, boolean)
	local spot = parked[key]
	parked[key] = nil
	if not spot then
		return false, false
	end
	return state.phase == "Build" and state.roundIndex == spot.round and at <= spot.untilAt, true
end

local function onJoin(player: Player)
	local key = keyOf(player)
	local at = now()
	local resume, hadSpot = canResume(key, at)
	RoundEngine.join(state, key, at, resume)
	if resume and RoundEngine.playerView(state, key).spectating then
		-- The server filled up while they were gone.
		resume = false
	end
	if hadSpot and not resume and ctx.rooms then
		-- Back too late. The kept room is not theirs any more.
		ctx.rooms.forget(key)
	end
	if ctx.plots then
		ctx.plots.assign(player)
	end
	if ctx.rooms then
		ctx.rooms.welcome(player)
		if resume and type(ctx.rooms.restore) == "function" then
			ctx.rooms.restore(player)
		end
	end
	publish(now())
	if ctx.funnel and type(ctx.funnel.present) == "function" then
		ctx.funnel.present(player)
	end
	if ctx.progress and type(ctx.progress.welcome) == "function" then
		ctx.progress.welcome(player)
	end
end

local function onLeave(player: Player)
	local key = keyOf(player)
	local partner: string? = nil
	local wasLead = false
	if ctx.duo and type(ctx.duo.noteLeave) == "function" then
		partner, wasLead = ctx.duo.noteLeave(state, key)
	end
	local inherited = false
	if wasLead and type(partner) == "string" and state.players[partner] ~= nil then
		inherited = true
		if type(RoundEngine.reassignStop) == "function" then
			RoundEngine.reassignStop(state, key, partner)
		end
		if ctx.votes and type(ctx.votes.reassign) == "function" then
			ctx.votes.reassign(key, partner)
		end
		if ctx.plots and type(ctx.plots.handOff) == "function" then
			ctx.plots.handOff(player, partner)
		end
	end
	-- Mid-build, a solo builder with pieces down keeps the room for a short
	-- while in case this was a dropped connection.
	local before = state.players[key]
	local keep = false
	if not inherited and partner == nil and state.phase == "Build" and before and before.role == "active" then
		local fn = state.hasWork
		if type(fn) == "function" then
			local ok, has = pcall(fn, key)
			keep = ok and has == true
		end
	end
	RoundEngine.leave(state, key, now())
	if keep then
		parked[key] = { round = state.roundIndex, untilAt = now() + graceSeconds }
	elseif ctx.rooms then
		ctx.rooms.forget(key)
	end
	if not inherited and ctx.plots then
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
	local reconnect = Config.Reconnect
	if type(reconnect) == "table" and type(reconnect.Grace) == "number" then
		graceSeconds = reconnect.Grace
	end
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
	seenPhase = state.phase
	seenRound = state.roundIndex
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
		local before = seenPhase
		local beforeTour = state.tourIndex
		local beforeStop = ""
		if state.phase == "Tour" and beforeTour >= 1 and beforeTour <= #state.tourStops then
			beforeStop = state.tourStops[beforeTour]
		end
		local wasLocked = RoundEngine.roomLocked(state, at)
		RoundEngine.advance(state, at)
		local nowLocked = RoundEngine.roomLocked(state, at)
		local stopChanged = state.tourIndex ~= beforeTour or state.phase ~= "Tour"
		if beforeStop ~= "" and stopChanged and ctx.votes and type(ctx.votes.scoreRoom) == "function" then
			ctx.votes.scoreRoom(beforeStop)
		end
		local changed = state.phase ~= before or state.roundIndex ~= seenRound
		seenPhase = state.phase
		seenRound = state.roundIndex
		if changed then
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
			if ctx.funnel and type(ctx.funnel.onPhase) == "function" then
				pcall(ctx.funnel.onPhase, state)
			end
		end
		acc += dt
		if changed or state.tourIndex ~= beforeTour or wasLocked ~= nowLocked or acc >= 0.25 then
			acc = 0
			publish(at)
		end
	end)
end

return RoundService
