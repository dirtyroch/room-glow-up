--!strict
-- Binds the single action remote. Handlers are registered by other services.

local ActionService = {}
local ctx: any = nil

local function pack(a: any, b: any, c: any): { any }?
	if b ~= nil and a == nil then
		return nil
	end
	if c ~= nil and (a == nil or b == nil) then
		return nil
	end
	local args: { any } = {}
	if a ~= nil then
		table.insert(args, a)
	end
	if b ~= nil then
		table.insert(args, b)
	end
	if c ~= nil then
		table.insert(args, c)
	end
	return args
end

function ActionService.init(c: any)
	ctx = c
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
	local Logic = Shared:WaitForChild("Logic")
	local Actions = require(Logic:WaitForChild("Actions") :: ModuleScript) :: any
	local limits = Config.RateLimit
	ctx.actions = Actions.create({
		globalBurst = limits.globalBurst,
		globalRefill = limits.globalRefill,
		actionBurst = limits.actionBurst,
		actionRefill = limits.actionRefill,
		nameMax = limits.nameMax,
	})
end

function ActionService.start()
	ctx.Remotes.Action.OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any)
		local args = pack(a, b, c)
		if not args then
			return { ok = false, msg = "Bad request." }
		end
		local ok, msg = ctx.actions.handle(tostring(player.UserId), action, args, os.clock())
		return { ok = ok, msg = msg }
	end
end

return ActionService
