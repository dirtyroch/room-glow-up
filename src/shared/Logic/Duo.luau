--!strict
-- Optional lobby pairing. Two players share one bigger room.
-- The partner is not a second tour stop, voter, or reporter.

local function sibling(name: string): any
	local ok, loaded = pcall(function()
		local child = script.Parent.Parent:WaitForChild(name)
		return (require :: any)(child)
	end)
	if ok then
		return loaded
	end
	return (require :: any)("../" .. name)
end

local Config = sibling("Config")

local Duo = {}

export type Group = {
	opted: { [string]: boolean },
	partner: { [string]: string },
	lead: { [string]: string },
	scale: { [string]: boolean },
}

function Duo.create(): Group
	return {
		opted = {},
		partner = {},
		lead = {},
		scale = {},
	}
end

function Duo.toggle(group: Group, id: string, phase: string): (boolean, string?)
	if phase ~= "Lobby" then
		return false, "Duo is only in the lobby."
	end
	if group.opted[id] then
		group.opted[id] = nil
		return true, "Duo off."
	end
	group.opted[id] = true
	return true, "Duo on."
end

function Duo.freeze(group: Group, ids: { string })
	local wanting: { string } = {}
	for _, id in ipairs(ids) do
		if group.opted[id] then
			table.insert(wanting, id)
		end
	end
	table.sort(wanting)
	group.partner = {}
	group.lead = {}
	group.scale = {}
	local index = 1
	while index + 1 <= #wanting do
		local a = wanting[index]
		local b = wanting[index + 1]
		group.partner[a] = b
		group.partner[b] = a
		group.lead[a] = a
		group.lead[b] = a
		group.scale[a] = true
		group.scale[b] = true
		index += 2
	end
end

function Duo.clearRound(group: Group)
	group.partner = {}
	group.lead = {}
	group.scale = {}
end

function Duo.partnerOf(group: Group, id: string): string?
	return group.partner[id]
end

function Duo.leadOf(group: Group, id: string): string
	return group.lead[id] or id
end

function Duo.paired(group: Group, id: string): boolean
	return group.scale[id] == true
end

function Duo.owners(group: Group, id: string): { string }
	local partner = group.partner[id]
	if not partner then
		return { id }
	end
	local lead = Duo.leadOf(group, id)
	if lead == id then
		return { id, partner }
	end
	return { lead, id }
end

function Duo.blocks(owners: { string }, person: string): boolean
	for _, id in ipairs(owners) do
		if id == person then
			return true
		end
	end
	return false
end

-- People who can vote: everyone in the server except the room's owners.
function Duo.eligible(players: number, owners: number): number
	local n = players - owners
	if n < 0 then
		return 0
	end
	return n
end

function Duo.budget(base: number, paired: boolean): number
	if not paired then
		return base
	end
	return math.floor(base * Config.Progress.DuoScale)
end

function Duo.itemCap(base: number, paired: boolean): number
	if not paired then
		return base
	end
	return math.floor(base * Config.Progress.DuoScale)
end

function Duo.gridType(roundType: string, paired: boolean): string
	if not paired then
		return roundType
	end
	if roundType == "room" or roundType == "gingerbread" then
		return "duo_" .. roundType
	end
	return roundType
end

-- Drop the link when someone leaves. The shared budget flag stays until the lobby.
function Duo.detach(group: Group, id: string): (string?, boolean)
	local partner = group.partner[id]
	local wasLead = group.lead[id] == id and partner ~= nil
	if partner then
		group.partner[id] = nil
		group.partner[partner] = nil
		group.lead[id] = nil
		group.lead[partner] = nil
	end
	return partner, wasLead == true
end

return Duo
