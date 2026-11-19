--!strict
-- One validated, rate-limited action path. The client asks; the server decides.
-- Payloads are never trusted and never echoed. Unknown names, oversized names,
-- and extra arguments cannot set a theme, a score, or a phase.
--
-- Buckets match Cookout: a per-player burst, then a tighter per-action burst.
-- `limitNow` is the rate-limit clock (os.clock on the server). `now` is the
-- round clock. Tests pass both.

local Config = if script ~= nil and script.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")
local RateLimiter = if script ~= nil and script.Parent ~= nil then require(script.Parent.RateLimiter) else require("./RateLimiter")
local Round = if script ~= nil and script.Parent ~= nil then require(script.Parent.Round) else require("./Round")

local Actions = {}

export type Context = {
	round: any,
	globalLimiter: any,
	actionLimiter: any,
	acting: { [string]: boolean },
	now: number,
	limitNow: number,
}

type Handler = (Context, string, any, any, any) -> (boolean, string?)

local function onDone(ctx: Context, playerId: string, _a: any, _b: any, _c: any): (boolean, string?)
	return Round.done(ctx.round, playerId, ctx.now)
end

local function onHello(ctx: Context, playerId: string, _a: any, _b: any, _c: any): (boolean, string?)
	if ctx.round.members[playerId] == nil then
		return false, "Still joining."
	end
	return true, nil
end

local HANDLERS: { [string]: Handler } = {
	Done = onDone,
	Hello = onHello,
}

local NAMES = { "Done", "Hello" }

function Actions.names(): { string }
	return table.clone(NAMES)
end

function Actions.newContext(round: any, now: number): Context
	local limits = Config.RateLimit
	return {
		round = round,
		globalLimiter = RateLimiter.new(limits.globalBurst, limits.globalRefill),
		actionLimiter = RateLimiter.new(limits.actionBurst, limits.actionRefill),
		acting = {},
		now = now,
		limitNow = now,
	}
end

function Actions.forget(ctx: Context, playerId: string)
	ctx.globalLimiter:forget(playerId)
	ctx.acting[playerId] = nil
	for _, name in ipairs(NAMES) do
		ctx.actionLimiter:forget(playerId .. "\0" .. name)
	end
end

function Actions.handle(ctx: Context, playerId: any, action: any, a: any, b: any, c: any): (boolean, string?)
	if type(playerId) ~= "string" or playerId == "" then
		return false, "Bad request."
	end
	if not ctx.globalLimiter:allow(playerId, ctx.limitNow) then
		return false, "Slow down a moment."
	end
	if type(action) ~= "string" or action == "" or #action > Config.RateLimit.maxActionLength then
		return false, "Bad request."
	end
	local fn = HANDLERS[action]
	if not fn then
		return false, "Unknown action."
	end
	if not ctx.actionLimiter:allow(playerId .. "\0" .. action, ctx.limitNow) then
		return false, "Slow down a moment."
	end
	if ctx.acting[playerId] then
		return false, "Slow down a moment."
	end
	ctx.acting[playerId] = true
	local ok, res, msg = pcall(fn, ctx, playerId, a, b, c)
	ctx.acting[playerId] = nil
	if not ok then
		warn("[Actions] " .. action .. " failed: " .. tostring(res))
		return false, "Something went wrong."
	end
	return res == true, msg
end

return Actions
