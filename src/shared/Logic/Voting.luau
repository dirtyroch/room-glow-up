--!strict
-- Server-side votes, reports, Auntie Roch, and Judge's Eye.
-- The client can ask. This module decides. Crowd emoji are not votes.

local Voting = {}

export type RoomFacts = {
	meter: number,
	unique: number,
	pieces: number,
	maxItems: number,
}

export type Gate = {
	phase: string,
	locked: boolean,
	tourTarget: string,
	role: string,
	ownerPresent: boolean,
	voterCount: number,
	-- Duo partners. Both are blocked from voting and reporting this room.
	owners: { string }?,
}

export type Ballot = {
	votes: { [string]: number },
	reports: { [string]: boolean },
	removed: boolean,
	comment: string,
	criticStars: number,
	average: number,
}

export type State = {
	rooms: { [string]: Ballot },
	-- Placeholder purse until a later save milestone. Not written to a store.
	eyeCoins: { [string]: number },
}

export type ScoreRow = {
	owner: string,
	average: number,
	comment: string,
	criticStars: number,
}

export type Card = {
	theme: string,
	stars: number,
	line: string,
}

local function blank(): Ballot
	return {
		votes = {},
		reports = {},
		removed = false,
		comment = "",
		criticStars = 0,
		average = 0,
	}
end

function Voting.create(): State
	return {
		rooms = {},
		eyeCoins = {},
	}
end

function Voting.reset(state: State)
	state.rooms = {}
	state.eyeCoins = {}
end

function Voting.ensure(state: State, owner: string): Ballot
	local found = state.rooms[owner]
	if found then
		return found
	end
	local room = blank()
	state.rooms[owner] = room
	return room
end

function Voting.threshold(voters: number, config: any): number
	local minimum = config.Voting.ReportMin
	local fraction = config.Voting.ReportFraction
	local scaled = voters * fraction
	-- ceil, so half of an odd ballot rounds up.
	local percent = math.floor(scaled)
	if scaled - percent > 1e-9 then
		percent += 1
	end
	if percent < 0 then
		percent = 0
	end
	if minimum > percent then
		return minimum
	end
	return percent
end

function Voting.average(stars: { number }, trimAt: number): number
	local copy: { number } = {}
	for _, n in ipairs(stars) do
		table.insert(copy, n)
	end
	table.sort(copy)
	if #copy >= trimAt and #copy >= 3 then
		table.remove(copy, 1)
		table.remove(copy)
	end
	if #copy == 0 then
		return 0
	end
	local sum = 0
	for _, n in ipairs(copy) do
		sum += n
	end
	return sum / #copy
end

function Voting.withinEye(stars: number, average: number, window: number): boolean
	return math.abs(stars - average) <= window
end

local function clamp01(n: number): number
	return math.clamp(n, 0, 100)
end

function Voting.critic(facts: RoomFacts, config: any): (number, string)
	local meter = clamp01(facts.meter)
	local pieces = facts.pieces
	if pieces < 0 then
		pieces = 0
	end
	local unique = facts.unique
	if unique < 0 then
		unique = 0
	end
	local variety = 0
	if pieces > 0 then
		variety = math.clamp(unique / pieces, 0, 1) * 100
	end
	local fill = 0
	if facts.maxItems > 0 then
		fill = math.clamp(pieces / facts.maxItems, 0, 1) * 100
	end
	local weights = config.Critic.weights
	local score = weights.match * meter + weights.variety * variety + weights.fill * fill
	local stars = math.clamp(math.floor(score / 20) + 1, 1, 5)
	local lines = config.Critic.lines[stars]
	local seed = math.floor(meter) * 17 + unique * 31 + pieces * 13 + stars * 7
	local index = (seed % #lines) + 1
	return stars, lines[index]
end

local function sharesRoom(gate: Gate, person: string, owner: string): boolean
	if person == owner then
		return true
	end
	if type(gate.owners) ~= "table" then
		return false
	end
	for _, id in ipairs(gate.owners) do
		if id == person then
			return true
		end
	end
	return false
end

local function starOk(stars: number, config: any): boolean
	if type(stars) ~= "number" then
		return false
	end
	if stars ~= stars then
		return false
	end
	if stars % 1 ~= 0 then
		return false
	end
	return stars >= config.Voting.MinStars and stars <= config.Voting.MaxStars
end

function Voting.cast(state: State, voter: string, owner: string, stars: number, gate: Gate, config: any): (boolean, string?)
	if voter == config.Critic.id then
		return false, "Bad request."
	end
	if not starOk(stars, config) then
		return false, "Pick 1 to 5 stars."
	end
	if gate.phase ~= "Tour" then
		return false, "Voting is only on tour."
	end
	if gate.role ~= "active" and gate.role ~= "spectator" then
		return false, "You are not in this round."
	end
	if sharesRoom(gate, voter, owner) then
		return false, "You cannot vote on your own room."
	end
	local existing = state.rooms[owner]
	if (existing and existing.removed) or gate.ownerPresent ~= true then
		return false, "That room is gone."
	end
	if gate.tourTarget ~= owner then
		return false, "That room is not on stage."
	end
	if gate.locked then
		return false, "Votes are locked."
	end
	local room = Voting.ensure(state, owner)
	room.votes[voter] = stars
	return true, "Voted."
end

local function reportTotal(room: Ballot): number
	local n = 0
	for _ in pairs(room.reports) do
		n += 1
	end
	return n
end

function Voting.report(state: State, reporter: string, owner: string, gate: Gate, config: any): (boolean, string?, boolean)
	if gate.phase ~= "Tour" then
		return false, "You can report during the tour.", false
	end
	if gate.role ~= "active" and gate.role ~= "spectator" then
		return false, "You are not in this round.", false
	end
	if sharesRoom(gate, reporter, owner) then
		return false, "You cannot report your own room.", false
	end
	if gate.tourTarget ~= owner then
		return false, "That room is not on stage.", false
	end
	local existing = state.rooms[owner]
	if (existing and existing.removed) or gate.ownerPresent ~= true then
		return false, "That room is gone.", false
	end
	local room = Voting.ensure(state, owner)
	if room.reports[reporter] then
		return true, "Already reported.", false
	end
	room.reports[reporter] = true
	local need = Voting.threshold(gate.voterCount, config)
	if reportTotal(room) >= need then
		room.removed = true
		return true, "Reported.", true
	end
	return true, "Reported.", false
end

function Voting.finalize(state: State, factsByOwner: { [string]: RoomFacts }, present: { [string]: boolean }, config: any): { ScoreRow }
	state.eyeCoins = {}
	local criticId = config.Critic.id
	local window = config.Voting.EyeWindow
	local purse = config.Voting.EyeCoins
	local rows: { ScoreRow } = {}
	for owner, ballot in pairs(state.rooms) do
		local facts = factsByOwner[owner]
		if ballot.removed or present[owner] ~= true then
			ballot.average = 0
			ballot.comment = ""
			ballot.criticStars = 0
		else
			if not facts then
				facts = { meter = 0, unique = 0, pieces = 0, maxItems = 0 }
			end
			local stars, line = Voting.critic(facts, config)
			ballot.votes[criticId] = stars
			ballot.criticStars = stars
			ballot.comment = line
			local list: { number } = {}
			for _, value in pairs(ballot.votes) do
				table.insert(list, value)
			end
			local average = Voting.average(list, config.Voting.TrimAt)
			ballot.average = average
			for voter, value in pairs(ballot.votes) do
				if voter ~= criticId and Voting.withinEye(value, average, window) then
					local soFar = state.eyeCoins[voter] or 0
					state.eyeCoins[voter] = soFar + purse
				end
			end
			table.insert(rows, {
				owner = owner,
				average = average,
				comment = line,
				criticStars = stars,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.average == b.average then
			return a.owner < b.owner
		end
		return a.average > b.average
	end)
	return rows
end

-- Read the board after finalize. Does not grant coins or change ballots.
function Voting.standings(state: State): { ScoreRow }
	local rows: { ScoreRow } = {}
	for owner, ballot in pairs(state.rooms) do
		if ballot.removed ~= true and (ballot.criticStars > 0 or ballot.comment ~= "") then
			table.insert(rows, {
				owner = owner,
				average = ballot.average,
				comment = ballot.comment,
				criticStars = ballot.criticStars,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.average == b.average then
			return a.owner < b.owner
		end
		return a.average > b.average
	end)
	return rows
end

-- The podium uses the first half of Results. Coins and XP use the rest.
function Voting.showRewards(timeLeft: number, span: number): boolean
	if type(timeLeft) ~= "number" or type(span) ~= "number" or span <= 0 then
		return false
	end
	return timeLeft <= math.floor(span / 2)
end

-- Plot signs through Tour and Results. The owner's name stays off the sign.
function Voting.signLabel(phase: string, index: number, ownerName: string?): string
	if phase == "Tour" or phase == "Results" then
		return "Room " .. tostring(index)
	end
	if type(ownerName) == "string" and ownerName ~= "" then
		return ownerName
	end
	return "Plot " .. tostring(index)
end

-- Screenshot card. Theme, stars, and her line. No player name.
function Voting.photoCard(source: { theme: string, stars: number, line: string, name: string? }): Card
	return {
		theme = source.theme,
		stars = source.stars,
		line = source.line,
	}
end

local function clean(text: string): string
	return (string.gsub(text, "[|\r\n]", " "))
end

-- Names are written only for the podium slots. Later rows keep the average and her line.
function Voting.encodeBoard(rows: { ScoreRow }, names: { [string]: string }, slots: number): string
	local parts: { string } = {}
	for index, row in ipairs(rows) do
		local id = ""
		local name = ""
		if index <= slots then
			id = clean(row.owner)
			local raw = names[row.owner]
			if type(raw) == "string" then
				name = clean(raw)
			end
		end
		local line = string.format("%d|%s|%s|%.4f|%s", index, id, name, row.average, clean(row.comment))
		table.insert(parts, line)
	end
	return table.concat(parts, "\n")
end

function Voting.decodeBoard(payload: string): { { rank: number, userId: string, name: string, average: number, comment: string } }
	local rows: { { rank: number, userId: string, name: string, average: number, comment: string } } = {}
	if type(payload) ~= "string" or payload == "" then
		return rows
	end
	for line in string.gmatch(payload, "[^\n]+") do
		local rank, id, name, average, comment = string.match(line, "^(%d+)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
		if rank and id and name and average and comment then
			table.insert(rows, {
				rank = tonumber(rank) or 0,
				userId = id,
				name = name,
				average = tonumber(average) or 0,
				comment = comment,
			})
		end
	end
	return rows
end

return Voting
