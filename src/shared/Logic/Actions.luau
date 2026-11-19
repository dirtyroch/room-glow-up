--!strict
-- One action remote. Names are checked, arguments are type-checked, and each
-- player is rate-limited before a handler runs. Callers must not trust the client.

local function sibling(name: string): any
	local ok, loaded = pcall(function()
		local child = script.Parent:WaitForChild(name)
		return (require :: any)(child)
	end)
	if ok then
		return loaded
	end
	-- Lune tests load the file by path and have no script global.
	return (require :: any)("./" .. name)
end

local RateLimiter = sibling("RateLimiter")

local Actions = {}

export type Limits = {
	globalBurst: number,
	globalRefill: number,
	actionBurst: number,
	actionRefill: number,
	nameMax: number?,
}

export type Handler = (playerKey: string, args: { any }) -> (boolean, string?)

export type Api = {
	register: (name: string, argTypes: { string }, fn: Handler) -> (),
	handle: (playerKey: string, action: any, args: any, now: number) -> (boolean, string?),
	forget: (playerKey: string) -> (),
}

function Actions.create(limits: Limits): Api
	local globalLimiter = RateLimiter.new(limits.globalBurst, limits.globalRefill)
	local actionLimiter = RateLimiter.new(limits.actionBurst, limits.actionRefill)
	local handlers: { [string]: Handler } = {}
	local specs: { [string]: { string } } = {}
	local busy: { [string]: boolean } = {}
	local nameMax = limits.nameMax or 24

	local api = {} :: Api

	function api.register(name: string, argTypes: { string }, fn: Handler)
		handlers[name] = fn
		specs[name] = argTypes
	end

	function api.handle(playerKey: string, action: any, args: any, now: number): (boolean, string?)
		if type(playerKey) ~= "string" or playerKey == "" then
			return false, "Bad request."
		end
		if busy[playerKey] then
			return false, "Slow down a moment."
		end
		if not globalLimiter:allow(playerKey, now) then
			return false, "Slow down a moment."
		end
		if type(action) ~= "string" or action == "" or #action > nameMax then
			return false, "Bad request."
		end
		if string.match(action, "^[%w]+$") == nil then
			return false, "Bad request."
		end
		local fn = handlers[action]
		if not fn then
			return false, "Unknown action."
		end
		if type(args) ~= "table" then
			return false, "Bad request."
		end
		local spec = specs[action]
		if #args ~= #spec then
			return false, "Bad request."
		end
		for key, _ in pairs(args) do
			if type(key) ~= "number" or key < 1 or key > #spec or key % 1 ~= 0 then
				return false, "Bad request."
			end
		end
		for i, expected in ipairs(spec) do
			if type(args[i]) ~= expected then
				return false, "Bad request."
			end
		end
		local actionKey = playerKey .. "\0" .. action
		if not actionLimiter:allow(actionKey, now) then
			return false, "Slow down a moment."
		end

		busy[playerKey] = true
		local ok, res, msg = pcall(fn, playerKey, args)
		busy[playerKey] = nil
		if not ok then
			return false, "Something went wrong."
		end
		if res ~= true then
			if type(msg) == "string" then
				return false, msg
			end
			return false, "Nope."
		end
		if type(msg) == "string" then
			return true, msg
		end
		return true, nil
	end

	function api.forget(playerKey: string)
		globalLimiter:forget(playerKey)
		busy[playerKey] = nil
		for name in pairs(handlers) do
			actionLimiter:forget(playerKey .. "\0" .. name)
		end
	end

	return api
end

return Actions
