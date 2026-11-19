--!strict
-- Receipts, passes, codes, and Family Night. The server checks ownership.
-- An id of 0 never opens a purchase window. A failed save never grants.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopService = {}
local ctx: any = nil
local Config: any = nil
local Items: any = nil
local Shop: any = nil
local Crates: any = nil
local Codes: any = nil
local Host: any = nil
local Monetization: any = nil
local RoundEngine: any = nil
local RateLimiter: any = nil
local Dream: any = nil
local Save: any = nil
local codeLimiter: any = nil
local rainUntil = 0
local rainName = ""
local policyChecked: { [string]: boolean } = {}

local function keyOf(player: Player): string
	return tostring(player.UserId)
end

local function phaseNow(): string
	local round = ctx.round
	if type(round) == "table" and type(round.phase) == "string" then
		return round.phase
	end
	return "Lobby"
end

local function roundId(): string
	local round = ctx.round
	if type(round) ~= "table" then
		return ""
	end
	return tostring(round.roundIndex or 0)
end

local function itemName(itemId: string): string
	if Items then
		local item = Items.get(itemId)
		if type(item) == "table" and type(item.name) == "string" then
			return item.name
		end
	end
	return itemId
end

local function publishRain()
	local folder = ctx.RoundState
	if not folder then
		return
	end
	local raining = os.time() < rainUntil
	local rows = Crates.rows(raining)
	folder:SetAttribute("CrateOdds", Crates.display(rows, itemName))
	folder:SetAttribute("RainUntil", rainUntil)
	-- The buyer's name is announced in the lobby only. Tour keeps it off the signs.
	if raining and phaseNow() == "Lobby" and rainName ~= "" then
		folder:SetAttribute("RainName", rainName)
	else
		folder:SetAttribute("RainName", "")
	end
end

-- Nil means the policy check failed. Do not prompt. A receipt that already
-- charged still grants the fixed set instead of rolling.
local function restricted(player: Player): boolean?
	local ok, result = pcall(function()
		return PolicyService:ArePaidRandomItemsRestricted(player)
	end)
	if ok then
		return result == true
	end
	local fallbackOk, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not fallbackOk or type(info) ~= "table" then
		return nil
	end
	return info.ArePaidRandomItemsRestricted == true
end

local function publishPolicy(player: Player)
	local key = keyOf(player)
	if policyChecked[key] then
		return
	end
	policyChecked[key] = true
	task.spawn(function()
		local flag = restricted(player)
		if player.Parent == nil then
			return
		end
		if flag == nil then
			player:SetAttribute("CratePolicy", "paused")
		elseif flag then
			player:SetAttribute("CratePolicy", "fallback")
		else
			player:SetAttribute("CratePolicy", "odds")
		end
	end)
end

local function refresh(player: Player)
	local key = keyOf(player)
	local bag = ctx.saves.session(key)
	local profile = bag.profile
	if bag.hold == true and type(profile) == "table" then
		if Save then
			local draft = Save.clone(profile)
			if Shop.claimPass(draft, os.time()) > 0 then
				if ctx.saves.apply(key, draft) == true then
					profile = bag.profile
				end
			end
		end
		if bag.dream and Dream then
			Dream.ensureSlots(bag.dream, Monetization.extraDreamSlots(key))
		end
		player:SetAttribute("Vip", Shop.hasPass(profile, "VIP"))
		player:SetAttribute("DesignerTools", Shop.hasPass(profile, "DesignerTools"))
		player:SetAttribute("DoubleCoins", Shop.hasPass(profile, "DoubleCoins"))
		player:SetAttribute("ThemeHint", profile.hintRound == roundId() and profile.hintRound ~= "")
		player:SetAttribute("OwnedItems", table.concat(profile.owned, ","))
		player:SetAttribute("Purse", profile.coins)
		player:SetAttribute("SaveOk", true)
	else
		player:SetAttribute("Vip", false)
		player:SetAttribute("DesignerTools", false)
		player:SetAttribute("DoubleCoins", false)
		player:SetAttribute("ThemeHint", false)
		player:SetAttribute("OwnedItems", "")
		player:SetAttribute("SaveOk", false)
	end
end

local function grantContext(player: Player, policy: boolean?): any
	return {
		now = os.time(),
		restricted = policy ~= false,
		raining = os.time() < rainUntil,
		level = player:GetAttribute("Level") or 1,
		buyerName = if player.DisplayName ~= "" then player.DisplayName else player.Name,
		roundId = roundId(),
		rng = function()
			return math.random()
		end,
		extend = function(seconds: number, purchaseId: string?): boolean
			if not ctx.round or not RoundEngine then
				return false
			end
			local ok = RoundEngine.extend(ctx.round, seconds, Config.Shop.TimeCap, purchaseId)
			return ok == true
		end,
		startRain = function(name: string, seconds: number)
			rainName = name
			rainUntil = os.time() + seconds
			publishRain()
		end,
	}
end

local function installPass(player: Player, passKey: string): boolean
	local key = keyOf(player)
	local bag = ctx.saves.session(key)
	if bag.hold ~= true then
		return false
	end
	local nextProfile, added = Shop.grantPass(bag.profile, passKey)
	if not added then
		refresh(player)
		return true
	end
	local saved = ctx.saves.apply(key, nextProfile)
	if saved ~= true then
		return false
	end
	refresh(player)
	return true
end

local function syncPasses(player: Player)
	for passKey, entry in pairs(Config.Shop.Passes) do
		if type(entry.id) == "number" and entry.id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, entry.id)
			end)
			if ok and owns == true then
				installPass(player, passKey)
			end
		end
	end
end

local function prompt(player: Player, itemKey: string): (boolean, string?)
	local entry, kind = Shop.entry(itemKey)
	if entry == nil or kind == nil then
		return false, "Unknown item."
	end
	local bag = ctx.saves.session(keyOf(player))
	local policyOk = true
	local isRestricted = false
	if entry.random == true then
		local flag = restricted(player)
		if flag == nil then
			return false, "Purchases are paused."
		end
		isRestricted = flag == true
	end
	local adds = 0
	if type(ctx.round) == "table" and type(ctx.round.timeAdds) == "number" then
		adds = ctx.round.timeAdds
	end
	local allowed, why = Shop.canPrompt(entry, {
		hold = bag.hold == true,
		phase = phaseNow(),
		policyOk = policyOk,
		restricted = isRestricted,
		timeAdds = adds,
		timeCap = Config.Shop.TimeCap,
		speed = type(ctx.round) == "table" and ctx.round.modifier == "speed",
	})
	if not allowed then
		return false, why
	end
	if entry.id <= 0 then
		return false, "This item is not for sale yet."
	end
	if kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, entry.id)
	else
		MarketplaceService:PromptProductPurchase(player, entry.id)
	end
	return true, "Confirm the purchase."
end

local function onReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = keyOf(player)
	local bag = ctx.saves.session(key)
	if bag.hold ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local productKey = Shop.keyForId(receipt.ProductId, "product")
	if productKey == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local flag = restricted(player)
	local context = grantContext(player, if flag == nil then true else flag)
	if flag == false then
		context.restricted = false
	else
		context.restricted = true
	end
	local function save(nextProfile: any): boolean
		return ctx.saves.apply(key, nextProfile) == true
	end
	local purchaseId = tostring(receipt.PurchaseId)
	local _installed, result = Shop.commit(bag.profile, productKey, purchaseId, context, save)
	if result.ok ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	refresh(player)
	publishRain()
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.init(c: any)
	ctx = c
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
	Items = require(Shared:WaitForChild("Items") :: ModuleScript) :: any
	local Logic = Shared:WaitForChild("Logic")
	Shop = require(Logic:WaitForChild("Shop") :: ModuleScript) :: any
	Crates = require(Logic:WaitForChild("Crates") :: ModuleScript) :: any
	Codes = require(Logic:WaitForChild("Codes") :: ModuleScript) :: any
	Host = require(Logic:WaitForChild("Host") :: ModuleScript) :: any
	Monetization = require(Logic:WaitForChild("Monetization") :: ModuleScript) :: any
	RoundEngine = require(Logic:WaitForChild("RoundEngine") :: ModuleScript) :: any
	RateLimiter = require(Logic:WaitForChild("RateLimiter") :: ModuleScript) :: any
	Dream = require(Logic:WaitForChild("Dream") :: ModuleScript) :: any
	Save = require(Logic:WaitForChild("Save") :: ModuleScript) :: any
	codeLimiter = RateLimiter.new(Config.RateLimit.codeBurst, Config.RateLimit.codeRefill)

	Monetization.setCoinSource(function(userId: string?): number
		if type(userId) ~= "string" then
			return 1
		end
		local bag = ctx.saves.session(userId)
		if bag.hold ~= true then
			return 1
		end
		return Shop.multiplier(bag.profile)
	end)
	Monetization.setSlotSource(function(userId: string?): number
		if type(userId) ~= "string" then
			return 0
		end
		local bag = ctx.saves.session(userId)
		if bag.hold ~= true then
			return 0
		end
		return Shop.extraSlots(bag.profile)
	end)
	Monetization.setLuckSource(function(_userId: string?): boolean
		return os.time() < rainUntil
	end)

	ctx.shop = {
		refresh = refresh,
	}

	ctx.actions.register("Buy", { "string" }, function(playerKey: string, args: { any }): (boolean, string?)
		local userId = tonumber(playerKey)
		local player = if userId then Players:GetPlayerByUserId(userId) else nil
		if not player then
			return false, "You are not in this round."
		end
		return prompt(player, args[1])
	end)

	ctx.actions.register("Code", { "string" }, function(playerKey: string, args: { any }): (boolean, string?)
		local bag = ctx.saves.session(playerKey)
		if bag.hold ~= true then
			return false, "Your save is still loading."
		end
		local level = 1
		local userId = tonumber(playerKey)
		local player = if userId then Players:GetPlayerByUserId(userId) else nil
		if player then
			local attr = player:GetAttribute("Level")
			if type(attr) == "number" then
				level = attr
			end
		end
		local draft = Save.clone(bag.profile)
		local ok, msg = Codes.redeem(draft, args[1], os.clock(), codeLimiter, playerKey, level)
		if ok then
			local saved = ctx.saves.apply(playerKey, draft)
			if saved ~= true then
				return false, "Your save is still loading."
			end
			if player then
				refresh(player)
			end
		end
		return ok, msg
	end)

	local function familyPlayer(playerKey: string): (Player?, boolean, string?)
		local userId = tonumber(playerKey)
		local player = if userId then Players:GetPlayerByUserId(userId) else nil
		if not player then
			return nil, false, "You are not in this round."
		end
		local isPrivate = game.PrivateServerOwnerId ~= 0
		local isOwner = player.UserId == game.PrivateServerOwnerId
		local allowed, why = Host.owner(isPrivate, isOwner)
		if not allowed then
			return nil, false, why
		end
		return player, true, nil
	end

	ctx.actions.register("HostTheme", { "string" }, function(playerKey: string, args: { any }): (boolean, string?)
		local _player, allowed, why = familyPlayer(playerKey)
		if not allowed then
			return false, why
		end
		local isPrivate = game.PrivateServerOwnerId ~= 0
		local picked, pickWhy = Host.pick(args[1], isPrivate, true)
		if not picked then
			return false, pickWhy
		end
		if ctx.Round and type(ctx.Round.setHostTheme) == "function" then
			return ctx.Round.setHostTheme(args[1])
		end
		return false, "Not ready."
	end)

	ctx.actions.register("HostDuo", { "string" }, function(playerKey: string, args: { any }): (boolean, string?)
		local _player, allowed, why = familyPlayer(playerKey)
		if not allowed then
			return false, why
		end
		if not ctx.family or type(ctx.family.duoAll) ~= "function" then
			return false, "Not ready."
		end
		local ids: { string } = {}
		for _, other in Players:GetPlayers() do
			table.insert(ids, keyOf(other))
		end
		local enabled = args[1] == "on"
		return ctx.family.duoAll(ids, phaseNow(), enabled)
	end)

	publishRain()
	for _, player in Players:GetPlayers() do
		refresh(player)
		publishPolicy(player)
		task.spawn(syncPasses, player)
	end
	Players.PlayerAdded:Connect(function(player)
		publishPolicy(player)
		task.spawn(syncPasses, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		policyChecked[keyOf(player)] = nil
	end)
end

function ShopService.start()
	MarketplaceService.ProcessReceipt = onReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, id: number, bought: boolean)
		if bought ~= true or type(id) ~= "number" or id <= 0 then
			return
		end
		local passKey = Shop.keyForId(id, "pass")
		if passKey == nil then
			return
		end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		if ok and owns == true then
			installPass(player, passKey)
		end
	end)
	local lastRain = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastRain < 0.5 then
			return
		end
		lastRain = now
		publishRain()
	end)
end

return ShopService
