--!strict
-- Funnel and custom events. Fields are numbers only.
-- A failed send is reported as false and does not raise.

local function sibling(name: string): any
	local ok, loaded = pcall(function()
		local child = script.Parent:WaitForChild(name)
		return (require :: any)(child)
	end)
	if ok then
		return loaded
	end
	return (require :: any)("./" .. name)
end

local Save = sibling("Save")

local Analytics = {}

local EVENTS: { [string]: number } = {
	joined = 1,
	tutorial_done = 2,
	first_item = 3,
	first_vote = 4,
	round_1_finished = 5,
	round_3_finished = 6,
	shop_opened = 7,
}

local BANNED: { [string]: boolean } = {
	name = true,
	username = true,
	displayname = true,
	email = true,
	ip = true,
	userid = true,
}

function Analytics.step(event: string): number?
	return EVENTS[event]
end

function Analytics.events(): { string }
	local names: { string } = {}
	for name in pairs(EVENTS) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- True the first time this profile records the event.
function Analytics.mark(profile: { [string]: any }, event: string): boolean
	if Analytics.step(event) == nil then
		return false
	end
	if type(profile.funnel) ~= "table" then
		profile.funnel = {}
	end
	if Save.hasId(profile.funnel, event) then
		return false
	end
	table.insert(profile.funnel, event)
	return true
end

function Analytics.sanitize(fields: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(fields) ~= "table" then
		return out
	end
	for key, value in pairs(fields) do
		if type(key) == "string" and BANNED[string.lower(key)] ~= true and type(value) == "number" and value == value then
			out[key] = value
		end
	end
	return out
end

function Analytics.emit(send: any): boolean
	if type(send) ~= "function" then
		return false
	end
	local ok = pcall(send)
	return ok == true
end

-- Gameplay continues either way. The boolean is only the send result.
function Analytics.play(send: any): boolean
	Analytics.emit(send)
	return true
end

return Analytics
