--!strict
-- Codes are redeemed on the server, once per player, and rate-limited.

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

local function parent(name: string): any
	local ok, loaded = pcall(function()
		local child = script.Parent.Parent:WaitForChild(name)
		return (require :: any)(child)
	end)
	if ok then
		return loaded
	end
	return (require :: any)("../" .. name)
end

local Config = parent("Config")
local Save = sibling("Save")
local Owned = sibling("Owned")

local Codes = {}

local function clean(text: string): string
	local trimmed = string.gsub(text, "%s", "")
	return string.upper(trimmed)
end

function Codes.redeem(
	profile: { [string]: any },
	text: string,
	now: number,
	limiter: any,
	userKey: string,
	level: number?
): (boolean, string?)
	if type(text) ~= "string" then
		return false, "Enter a code."
	end
	if limiter and limiter:allow(userKey, now) ~= true then
		return false, "Slow down a moment."
	end
	local code = clean(text)
	local spec = Config.Shop.Codes[code]
	if type(spec) ~= "table" then
		return false, "That code is not active."
	end
	if type(profile.codes) ~= "table" then
		profile.codes = {}
	end
	if Save.hasId(profile.codes, code) then
		return false, "Already used."
	end
	table.insert(profile.codes, code)
	if type(spec.coins) == "number" and spec.coins > 0 then
		profile.coins += math.floor(spec.coins)
		return true, "Code accepted."
	end
	if type(spec.itemId) == "string" then
		local duplicate = Owned.give(profile, spec.itemId, level)
		if duplicate then
			return true, "You already have that piece. Coins instead."
		end
		return true, "Code accepted."
	end
	return true, "Code accepted."
end

return Codes
