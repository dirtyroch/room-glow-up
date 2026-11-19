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
local streak: { [string]: number } = {}
local scored: { [string]: boolean } = {}
-- Stops in a row a kid let pass without voting. A kid who has stopped voting
-- does not hold each room on screen waiting for a vote that will not come.
local quiet: { [string]: number } = {}

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

local function ownerSet(owner: string): { [string]: boolean }
	local set: { [string]: boolean } = { [owner] = true }
	if ctx.duo and type(ctx.duo.owners) == "function" then
		for _, id in ipairs(ctx.duo.owners(owner)) do
			set[id] = true
		end
	end
	return set
end

local function voterCount(round: any, owner: string): number
	local owners = ownerSet(owner)
	local n = 0
	for id, player in pairs(round.players) do
		if owners[id] ~= true and (player.role == "active" or player.role == "spectator") then
			n += 1
		end
	end
	return n
end

local function quietAfter(): number
	local n = Config.Voting.QuietAfter
	if type(n) ~= "number" or n < 1 then
		return math.huge
	end
	return n
end

local function everyoneVoted(round: any, owner: string): boolean
	local owners = ownerSet(owner)
	local pending = 0
	local room = ballots.rooms[owner]
	for id, player in pairs(round.players) do
		local waitFor = (quiet[id] or 0) < quietAfter()
		if owners[id] ~= true and (player.role == "active" or player.role == "spectator") and waitFor then
			pending += 1
			if not room or type(room.votes[id]) ~= "number" then
				return false
			end
		end
	end
	return pending > 0
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
	local owners: { string } = { owner }
	for id in pairs(ownerSet(owner)) do
		if id ~= owner then
			table.insert(owners, id)
		end
	end
	return {
		phase = round.phase,
		locked = RoundEngine.votesClosed(round, at),
		tourTarget = owner,
		role = "active",
		ownerPresent = present,
		voterCount = voterCount(round, owner),
		owners = owners,
	}
end

-- The client says which plot it was looking at. A vote or report that
-- arrives after the camera moved on is dropped, not given to the next room.
local function stillOnStage(owner: string, plot: any): boolean
	if type(plot) ~= "number" or plot ~= plot or plot % 1 ~= 0 then
		return false
	end
	if not ctx.plots or type(ctx.plots.indexOf) ~= "function" then
		return true
	end
	return ctx.plots.indexOf(owner) == plot
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
		streak = {}
		scored = {}
		quiet = {}
		clearCards()
		for _, player in Players:GetPlayers() do
			player:SetAttribute("MyStars", nil)
			player:SetAttribute("EyeCoins", nil)
			player:SetAttribute("EyeStreak", 0)
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
	local built: { [string]: boolean } = {}
	for id, player in pairs(round.players) do
		if player.submitted == true or player.done == true then
			built[id] = true
			if ctx.duo and type(ctx.duo.owners) == "function" then
				for _, partner in ipairs(ctx.duo.owners(id)) do
					built[partner] = true
				end
			end
		end
	end
	local rows = Voting.finalize(ballots, facts, present, Config, built)
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
		reassign = function(fromId: string, toId: string)
			Voting.reassign(ballots, fromId, toId)
		end,
		ballots = ballots,
		scoreRoom = function(owner: string)
			if type(owner) ~= "string" or owner == "" or scored[owner] then
				return
			end
			scored[owner] = true
			local ballot = ballots.rooms[owner]
			if not ballot or ballot.removed == true then
				return
			end
			local round = ctx.round
			if type(round) ~= "table" then
				return
			end
			local facts = { meter = 0, unique = 0, pieces = 0, maxItems = 0 }
			if ctx.rooms and type(ctx.rooms.inspect) == "function" then
				local got = ctx.rooms.inspect(owner)
				if type(got) == "table" then
					facts = got
				end
			end
			local hits = Voting.eyeHits(ballot, facts, Config)
			local owners = ownerSet(owner)
			for id, person in pairs(round.players) do
				if owners[id] ~= true and (person.role == "active" or person.role == "spectator") then
					if type(ballot.votes[id]) == "number" then
						quiet[id] = 0
					else
						quiet[id] = (quiet[id] or 0) + 1
					end
				end
			end
			for _, player in Players:GetPlayers() do
				local key = tostring(player.UserId)
				local person = round.players[key]
				if person and owners[key] ~= true and (person.role == "active" or person.role == "spectator") then
					if hits[key] == true then
						streak[key] = (streak[key] or 0) + 1
					else
						streak[key] = 0
					end
					player:SetAttribute("EyeStreak", streak[key])
				end
			end
		end,
	}

	ctx.actions.register("Vote", { "number", "number" }, function(key: string, args: { any }): (boolean, string?)
		local round = ctx.round
		if type(round) ~= "table" then
			return false, "Not ready."
		end
		local at = Workspace:GetServerTimeNow()
		local owner = currentOwner(round, at)
		if owner == "" then
			return false, "That room is not on stage."
		end
		if not stillOnStage(owner, args[2]) then
			-- Sent before the camera moved and landed just after: a first vote
			-- for the room that just left still counts.
			local late = RoundEngine.lateStop(round, at)
			local lateRoom = if late then ballots.rooms[late] else nil
			local already = lateRoom ~= nil and lateRoom.votes[key] ~= nil
			if late == nil or already or not stillOnStage(late, args[2]) then
				return false, "That room already moved on."
			end
			local lateGate = gateFor(round, late, at)
			lateGate.role = roleOf(round, key)
			lateGate.tourTarget = late
			lateGate.locked = false
			local lateOk, lateMsg = Voting.cast(ballots, key, late, args[1], lateGate, Config)
			if lateOk and ctx.funnel and type(ctx.funnel.onVote) == "function" then
				pcall(ctx.funnel.onVote, key)
			end
			return lateOk, lateMsg
		end
		local gate = gateFor(round, owner, at)
		gate.role = roleOf(round, key)
		gate.tourTarget = owner
		local ok, msg = Voting.cast(ballots, key, owner, args[1], gate, Config)
		if ok then
			sync(round)
			if ctx.funnel and type(ctx.funnel.onVote) == "function" then
				pcall(ctx.funnel.onVote, key)
			end
			if everyoneVoted(round, owner) then
				RoundEngine.hurryTour(round, at)
			end
		end
		return ok, msg
	end)

	ctx.actions.register("React", { "number" }, function(key: string, args: { any }): (boolean, string?)
		local round = ctx.round
		if type(round) ~= "table" or round.phase ~= "Tour" then
			return false, "Reactions wait for the tour."
		end
		local marks = Config.Show.Crowd
		if not Voting.reactionIndex(args[1], #marks) then
			return false, "Bad request."
		end
		local view = RoundEngine.playerView(round, key)
		if not view.inRound then
			return false, "You are not in this round."
		end
		local folder = ctx.RoundState
		if folder then
			local nonce = folder:GetAttribute("ReactionNonce")
			local nextNonce = if type(nonce) == "number" then nonce + 1 else 1
			folder:SetAttribute("ReactionIndex", args[1])
			folder:SetAttribute("ReactionNonce", nextNonce)
		end
		return true, "Sent."
	end)

	ctx.actions.register("Report", { "number" }, function(key: string, args: { any }): (boolean, string?)
		local round = ctx.round
		if type(round) ~= "table" then
			return false, "Not ready."
		end
		local at = Workspace:GetServerTimeNow()
		local owner = currentOwner(round, at)
		if owner == "" then
			return false, "That room is not on stage."
		end
		if not stillOnStage(owner, args[1]) then
			return false, "That room already moved on."
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
