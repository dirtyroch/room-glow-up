--!strict
-- Star votes and room reports on the shared action remote.
-- Auntie Roch's vote and Judge's Eye coins are settled at Results.
-- EyeCoins is a placeholder until saves land. It is not written to a store.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VoteService = {}
local ctx: any = nil
local Config: any = nil
local RoundEngine: any = nil
local Voting: any = nil
local ballots: any = nil

local function displayName(key: string): string
	local userId = tonumber(key)
	if not userId then
		return "Player"
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return "Player"
	end
	local name = player.DisplayName
	if name == "" then
		name = player.Name
	end
	return name
end

local function voterCount(round: any, owner: string): number
	local n = 0
	for id, player in pairs(round.players) do
		if id ~= owner and (player.role == "active" or player.role == "spectator") then
			n += 1
		end
	end
	return n
end

local function roleOf(round: any, key: string): string
	local view = RoundEngine.playerView(round, key)
	if not view.inRound then
		return "none"
	end
	if view.spectating then
		return "spectator"
	end
	return "active"
end

local function ensureStops(round: any)
	if type(round.tourStops) ~= "table" then
		return
	end
	for _, id in ipairs(round.tourStops) do
		Voting.ensure(ballots, id)
	end
end

local function gateFor(round: any, owner: string, at: number): any
	local room = ballots.rooms[owner]
	local present = round.players[owner] ~= nil and (room == nil or room.removed ~= true)
	return {
		phase = round.phase,
		locked = RoundEngine.roomLocked(round, at),
		tourTarget = owner,
		role = "active",
		ownerPresent = present,
		voterCount = voterCount(round, owner),
	}
end

local function currentOwner(round: any, at: number): string
	local snap = RoundEngine.snapshot(round, at)
	local owner = snap.tourTarget
	if type(owner) ~= "string" then
		return ""
	end
	return owner
end

local function sync(round: any)
	local target = ""
	if round.phase == "Tour" then
		target = currentOwner(round, Workspace:GetServerTimeNow())
	end
	for _, player in Players:GetPlayers() do
		local key = tostring(player.UserId)
		local stars: number? = nil
		local room = ballots.rooms[target]
		if room and type(room.votes[key]) == "number" then
			stars = room.votes[key]
		end
		if player:GetAttribute("MyStars") ~= stars then
			player:SetAttribute("MyStars", stars)
		end
	end
end

local function clearCards()
	local folder = ctx.RoundState
	if folder then
		folder:SetAttribute("Podium", "")
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute("CardStars", nil)
		player:SetAttribute("CardLine", nil)
	end
end

local function onPhase(round: any, _at: number)
	if round.phase == "Lobby" then
		Voting.reset(ballots)
		clearCards()
		for _, player in Players:GetPlayers() do
			player:SetAttribute("MyStars", nil)
			player:SetAttribute("EyeCoins", nil)
		end
		return
	end
	if round.phase == "Tour" then
		ensureStops(round)
		clearCards()
		return
	end
	if round.phase ~= "Results" then
		clearCards()
		return
	end
	ensureStops(round)
	local present: { [string]: boolean } = {}
	local names: { [string]: string } = {}
	for id in pairs(round.players) do
		present[id] = true
		names[id] = displayName(id)
	end
	local facts: { [string]: any } = {}
	for id in pairs(ballots.rooms) do
		if present[id] and ctx.rooms and type(ctx.rooms.inspect) == "function" then
			facts[id] = ctx.rooms.inspect(id)
		end
	end
	local rows = Voting.finalize(ballots, facts, present, Config)
	local folder = ctx.RoundState
	if folder then
		folder:SetAttribute("Podium", Voting.encodeBoard(rows, names, Config.Voting.Podium))
	end
	local byOwner: { [string]: any } = {}
	for _, row in ipairs(rows) do
		byOwner[row.owner] = row
	end
	local featured = rows[1]
	for _, player in Players:GetPlayers() do
		local key = tostring(player.UserId)
		local row = byOwner[key]
		if not row then
			row = featured
		end
		if row then
			player:SetAttribute("CardStars", row.average)
			player:SetAttribute("CardLine", row.comment)
		else
			player:SetAttribute("CardStars", nil)
			player:SetAttribute("CardLine", nil)
		end
		local coins = ballots.eyeCoins[key]
		local purse = if type(coins) == "number" then coins else 0
		player:SetAttribute("EyeCoins", purse)
	end
end

local function forget(_key: string)
	-- The round already dropped their stop. Finalize ignores a room whose owner is gone.
end

function VoteService.init(c: any)
	ctx = c
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
	local Logic = Shared:WaitForChild("Logic")
	RoundEngine = require(Logic:WaitForChild("RoundEngine") :: ModuleScript) :: any
	Voting = require(Logic:WaitForChild("Voting") :: ModuleScript) :: any
	ballots = Voting.create()
	ctx.votes = {
		sync = sync,
		onPhase = onPhase,
		forget = forget,
	}

	ctx.actions.register("Vote", { "number" }, function(key: string, args: { any }): (boolean, string?)
		local round = ctx.round
		if type(round) ~= "table" then
			return false, "Not ready."
		end
		local at = Workspace:GetServerTimeNow()
		local owner = currentOwner(round, at)
		if owner == "" then
			return false, "That room is not on stage."
		end
		local gate = gateFor(round, owner, at)
		gate.role = roleOf(round, key)
		gate.tourTarget = owner
		local ok, msg = Voting.cast(ballots, key, owner, args[1], gate, Config)
		if ok then
			sync(round)
		end
		return ok, msg
	end)

	ctx.actions.register("Report", {}, function(key: string, _args: { any }): (boolean, string?)
		local round = ctx.round
		if type(round) ~= "table" then
			return false, "Not ready."
		end
		local at = Workspace:GetServerTimeNow()
		local owner = currentOwner(round, at)
		if owner == "" then
			return false, "That room is not on stage."
		end
		local gate = gateFor(round, owner, at)
		gate.role = roleOf(round, key)
		gate.tourTarget = owner
		local ok, msg, removed = Voting.report(ballots, key, owner, gate, Config)
		if removed then
			RoundEngine.removeStop(round, owner, at)
			if round.phase == "Results" then
				onPhase(round, at)
			end
			if type(ctx.republish) == "function" then
				ctx.republish()
			end
		end
		return ok, msg
	end)
end

return VoteService
