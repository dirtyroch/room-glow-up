--!strict
-- Coins and XP for one round. The same round id never pays twice.
-- Eye coins are the number the server just scored, never an attribute.

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

local Rewards = {}

export type Input = {
	roundId: string,
	rank: number,
	average: number,
	podium: number,
	eye: number,
	userId: string?,
}

export type Hooks = {
	coinMultiplier: ((string?) -> number)?,
	luck: ((string?) -> boolean)?,
}

local function at(list: { number }, rank: number): number
	if type(rank) ~= "number" or rank < 1 then
		return 0
	end
	local index = math.floor(rank)
	if index > #list then
		return list[#list]
	end
	return list[index]
end

local function whole(n: number): number
	if type(n) ~= "number" or n ~= n or n < 0 then
		return 0
	end
	return math.floor(n + 1e-6)
end

function Rewards.eyeFromBallot(eyeCoins: any, userId: string): number
	if type(eyeCoins) ~= "table" then
		return 0
	end
	return whole(eyeCoins[userId])
end

function Rewards.grant(profile: { [string]: any }, input: Input, config: any, hooks: Hooks?): { [string]: any }
	if type(input.roundId) ~= "string" or input.roundId == "" then
		return { coins = 0, xp = 0, duplicate = true, luck = false }
	end
	if Save.hasPaid(profile, input.roundId) then
		return { coins = 0, xp = 0, duplicate = true, luck = false }
	end
	local rewards = config.Rewards
	local coins = at(rewards.PlaceCoins, input.rank)
	coins += whole((input.average or 0) * rewards.StarCoins)
	coins += at(rewards.PodiumCoins, input.podium)
	coins += whole((input.eye or 0) * rewards.EyeRate)
	local xp = at(rewards.PlaceXp, input.rank)
	xp += whole((input.average or 0) * rewards.StarXp)
	xp += at(rewards.PodiumXp, input.podium)
	local mult = 1
	local lucky = false
	if hooks then
		if hooks.coinMultiplier then
			local nextMult = hooks.coinMultiplier(input.userId)
			if type(nextMult) == "number" and nextMult == nextMult and nextMult >= 0 then
				mult = nextMult
			end
		end
		if hooks.luck then
			lucky = hooks.luck(input.userId) == true
		end
	end
	-- Luck adds a flat coin bonus on top of the multiplier. It does not multiply again.
	coins = whole(coins * mult)
	if lucky and type(config.Shop) == "table" then
		local extra = config.Shop.LuckBonusCoins
		if type(extra) == "number" and extra == extra and extra > 0 then
			coins += math.floor(extra)
		end
	end
	Save.markPaid(profile, input.roundId, config.Progress.PaidCap)
	profile.coins += coins
	profile.xp += xp
	return {
		coins = coins,
		xp = xp,
		duplicate = false,
		luck = lucky,
	}
end

return Rewards
