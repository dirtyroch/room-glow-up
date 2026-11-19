--!strict
-- The only client entry point. One RemoteFunction, validated and rate-limited.
-- Return values are server-written. Client strings are never copied into them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Actions = require(Logic:WaitForChild("Actions"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))

local ActionService = {}

local remote: RemoteFunction? = nil
local ctx: any = nil

function ActionService.forget(playerId: string)
	if ctx then
		Actions.forget(ctx, playerId)
	end
end

function ActionService.init(services: any)
	remote = services.ActionRemote
	ctx = Actions.newContext(RoundService.state(), 0)
end

function ActionService.start()
	local action = remote
	if not action then
		warn("[Room Glow Up] action remote is missing")
		return
	end
	action.OnServerInvoke = function(player: Player, name: any, a: any, b: any, c: any)
		local current = ctx
		if not current then
			return { ok = false, msg = "Still starting." }
		end
		current.now = workspace:GetServerTimeNow()
		current.limitNow = os.clock()
		local ok, res, msg = pcall(Actions.handle, current, tostring(player.UserId), name, a, b, c)
		if not ok then
			warn("[Actions] invoke failed: " .. tostring(res))
			return { ok = false, msg = "Something went wrong." }
		end
		if res == true then
			RoundService.sync()
		end
		return { ok = res == true, msg = msg }
	end
end

return ActionService
