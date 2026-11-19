--!strict
-- Family Night. A private server is free. The owner picks from the allowlist
-- and can turn Duo on for everyone. The client cannot widen the list.

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

local Host = {}

Host.price = 0

function Host.allowed(themeId: string): boolean
	if type(themeId) ~= "string" then
		return false
	end
	for _, id in ipairs(Config.Shop.HostThemes) do
		if id == themeId then
			return true
		end
	end
	return false
end

function Host.owner(isPrivate: boolean, isOwner: boolean): (boolean, string?)
	if isPrivate ~= true then
		return false, "Family Night is a private server."
	end
	if isOwner ~= true then
		return false, "Only the server owner can choose."
	end
	return true, nil
end

function Host.pick(themeId: string, isPrivate: boolean, isOwner: boolean): (boolean, string?)
	local allowed, why = Host.owner(isPrivate, isOwner)
	if not allowed then
		return false, why
	end
	if not Host.allowed(themeId) then
		return false, "That theme is not on the Family Night list."
	end
	return true, nil
end

return Host
