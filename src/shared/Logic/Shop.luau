--!strict
-- Shop grants. The receipt is recorded on a copy. The caller saves that copy
-- before it becomes the live profile. The same purchase id does not grant twice.
-- Pass and product ids of 0 never match a receipt and never open a prompt.

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
local Crates = sibling("Crates")

local Shop = {}

export type GrantContext = {
	now: number?,
	rng: (() -> number)?,
	restricted: boolean?,
	raining: boolean?,
	level: number?,
	extend: ((number, string?) -> boolean)?,
	purchaseId: string?,
	startRain: ((string, number) -> ())?,
	buyerName: string?,
	roundId: string?,
}

local function nowOf(ctx: GrantContext?): number
	if ctx and type(ctx.now) == "number" then
		return ctx.now
	end
	return 0
end

local function levelOf(ctx: GrantContext?): number
	if ctx and type(ctx.level) == "number" then
		return ctx.level
	end
	return 1
end

function Shop.pass(key: string): any
	return Config.Shop.Passes[key]
end

function Shop.product(key: string): any
	return Config.Shop.Products[key]
end

function Shop.entry(key: string): (any, string?)
	local pass = Shop.pass(key)
	if type(pass) == "table" then
		return pass, "pass"
	end
	local product = Shop.product(key)
	if type(product) == "table" then
		return product, "product"
	end
	return nil, nil
end

function Shop.keyForId(id: number, kind: string): string?
	if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then
		return nil
	end
	local bag = if kind == "pass" then Config.Shop.Passes else Config.Shop.Products
	for key, entry in pairs(bag) do
		if entry.id == id then
			return key
		end
	end
	return nil
end

function Shop.list(tab: string?): { any }
	local rows: { any } = {}
	local function push(key: string, entry: any, kind: string)
		if tab ~= nil and entry.tab ~= tab then
			return
		end
		table.insert(rows, {
			key = key,
			kind = kind,
			name = entry.name,
			price = entry.price,
			desc = entry.desc,
			tab = entry.tab,
			id = entry.id,
			random = entry.random == true,
			itemId = entry.itemId,
			items = entry.items,
		})
	end
	for key, entry in pairs(Config.Shop.Passes) do
		push(key, entry, "pass")
	end
	for key, entry in pairs(Config.Shop.Products) do
		push(key, entry, "product")
	end
	table.sort(rows, function(a, b)
		return a.name < b.name
	end)
	return rows
end

-- id 0 never prompts. A failed save blocks the window. Crates need a policy answer.
function Shop.canPrompt(entry: any, state: { [string]: any }): (boolean, string?)
	if type(entry) ~= "table" or type(entry.id) ~= "number" or entry.id <= 0 or entry.id ~= math.floor(entry.id) then
		return false, "This item is not for sale yet."
	end
	if state.hold ~= true then
		return false, "Your save is still loading."
	end
	if state.phase ~= "Lobby" then
		return false, "The shop is open in the lobby."
	end
	if entry.random == true and state.policyOk ~= true then
		return false, "Purchases are paused."
	end
	if entry.random == true and state.restricted == true then
		return false, "This crate is not available here."
	end
	local cap = state.timeCap
	if type(cap) ~= "number" then
		cap = Config.Shop.TimeCap
	end
	local adds = state.timeAdds
	if type(adds) ~= "number" then
		adds = 0
	end
	if entry.time == true and state.speed == true then
		return false, "Speed Round keeps its clock."
	end
	if entry.time == true and adds >= cap then
		return false, "This round already has two extra minutes."
	end
	return true, nil
end

function Shop.multiplier(profile: { [string]: any }): number
	if Save.hasId(profile.passes, "DoubleCoins") then
		return 2
	end
	return 1
end

function Shop.extraSlots(profile: { [string]: any }): number
	local n = profile.dreamExtra
	if type(n) ~= "number" or n ~= n then
		n = 0
	end
	n = math.max(0, math.floor(n))
	if Save.hasId(profile.passes, "VIP") then
		n += 1
	end
	local cap = Config.Shop.MaxExtraSlots
	if n > cap then
		return cap
	end
	return n
end

function Shop.hasPass(profile: { [string]: any }, key: string): boolean
	return Save.hasId(profile.passes, key)
end

local function remember(profile: { [string]: any }, purchaseId: string)
	if type(profile.receipts) ~= "table" then
		profile.receipts = {}
	end
	table.insert(profile.receipts, purchaseId)
	while #profile.receipts > Config.Shop.ReceiptCap do
		table.remove(profile.receipts, 1)
	end
end

local function giveMany(profile: { [string]: any }, ids: { string }, level: number): { string }
	local gained: { string } = {}
	for _, itemId in ipairs(ids) do
		local duplicate = Owned.give(profile, itemId, level)
		if not duplicate then
			table.insert(gained, itemId)
		end
	end
	return gained
end

function Shop.passReward(day: number): { coins: number, itemId: string? }
	local coins = 10 + day * 2
	local itemId = nil
	if day == 7 then
		itemId = "carol_piano"
	elseif day == 14 then
		itemId = "lavender_settee"
	elseif day == 21 then
		itemId = "glass_drop"
	elseif day == 30 then
		itemId = "star_lamp"
	end
	return { coins = coins, itemId = itemId }
end

function Shop.track(): { any }
	local rows: { any } = {}
	for day = 1, Config.Shop.DesignDays do
		local reward = Shop.passReward(day)
		table.insert(rows, { day = day, coins = reward.coins, itemId = reward.itemId })
	end
	return rows
end

local function claimed(profile: { [string]: any }, day: number): boolean
	local list = profile.designPassClaimed
	if type(list) ~= "table" then
		return false
	end
	for _, entry in ipairs(list) do
		if entry == day then
			return true
		end
	end
	return false
end

-- Fixed days. No XP, so the level unlock order does not move.
function Shop.claimPass(profile: { [string]: any }, now: number): number
	local startAt = profile.designPassStart
	if type(startAt) ~= "number" or startAt <= 0 or now < startAt then
		return 0
	end
	local untilAt = startAt + Config.Shop.DesignDays * 86400
	if now >= untilAt then
		return 0
	end
	local day = math.floor((now - startAt) / 86400) + 1
	if day > Config.Shop.DesignDays then
		day = Config.Shop.DesignDays
	end
	if type(profile.designPassClaimed) ~= "table" then
		profile.designPassClaimed = {}
	end
	local gained = 0
	for index = 1, day do
		if not claimed(profile, index) then
			table.insert(profile.designPassClaimed, index)
			local reward = Shop.passReward(index)
			profile.coins += reward.coins
			if type(reward.itemId) == "string" then
				Owned.give(profile, reward.itemId, nil)
			end
			gained += 1
		end
	end
	return gained
end

local function applyPass(profile: { [string]: any }, key: string): boolean
	if type(profile.passes) ~= "table" then
		profile.passes = {}
	end
	if Save.hasId(profile.passes, key) then
		return false
	end
	table.insert(profile.passes, key)
	return true
end

function Shop.grantPass(profile: { [string]: any }, key: string): ({ [string]: any }, boolean)
	local nextProfile = Save.clone(profile)
	if Shop.pass(key) == nil then
		return nextProfile, false
	end
	local added = applyPass(nextProfile, key)
	return nextProfile, added
end

local function applyProduct(profile: { [string]: any }, entry: any, ctx: GrantContext): { [string]: any }
	local level = levelOf(ctx)
	local detail: { [string]: any } = { items = {} }
	if type(entry.items) == "table" then
		detail.items = giveMany(profile, entry.items, level)
	end
	if type(entry.itemId) == "string" then
		local duplicate = Owned.give(profile, entry.itemId, level)
		if not duplicate then
			table.insert(detail.items, entry.itemId)
		end
		detail.duplicate = duplicate
	end
	if entry.random == true then
		if ctx.restricted == true then
			detail.items = giveMany(profile, Crates.fallback(), level)
			detail.fallback = true
		else
			local rows = Crates.rows(ctx.raining == true)
			local rng = ctx.rng or function()
				return 0
			end
			local itemId = Crates.roll(rows, rng)
			local duplicate = Owned.give(profile, itemId, level)
			detail.itemId = itemId
			detail.duplicate = duplicate
			if not duplicate then
				detail.items = { itemId }
			end
		end
	end
	if entry.time == true then
		local extend = ctx.extend
		local ok = false
		if extend then
			ok = extend(Config.Shop.TimeBonus, ctx.purchaseId) == true
		end
		detail.extended = ok
		if not ok then
			profile.coins += Config.Shop.TimeFallbackCoins
			detail.coins = Config.Shop.TimeFallbackCoins
		end
	end
	if entry.rain == true and ctx.startRain then
		local buyer = "Someone"
		if type(ctx.buyerName) == "string" and ctx.buyerName ~= "" then
			buyer = ctx.buyerName
		end
		ctx.startRain(buyer, Config.Shop.RainSeconds)
		detail.rain = true
	end
	if entry.hint == true then
		local roundId = ctx.roundId
		if type(roundId) == "string" then
			profile.hintRound = roundId
		end
		detail.hint = true
	end
	if entry.designPass == true then
		local now = nowOf(ctx)
		local startAt = profile.designPassStart
		local active = type(startAt) == "number" and startAt > 0 and now < startAt + Config.Shop.DesignDays * 86400
		if active then
			profile.coins += Config.Shop.DuplicateCoins
			detail.coins = Config.Shop.DuplicateCoins
		else
			profile.designPassStart = now
			profile.designPassClaimed = {}
			detail.pass = true
		end
	end
	if type(entry.slots) == "number" and entry.slots > 0 then
		local before = Shop.extraSlots(profile)
		profile.dreamExtra = (if type(profile.dreamExtra) == "number" then profile.dreamExtra else 0) + math.floor(entry.slots)
		if Shop.extraSlots(profile) == before then
			profile.dreamExtra -= math.floor(entry.slots)
			profile.coins += Config.Shop.DuplicateCoins
			detail.coins = Config.Shop.DuplicateCoins
		else
			detail.slots = Shop.extraSlots(profile)
		end
	end
	return detail
end

-- Returns a new profile. The input is left as it was so a failed save grants nothing.
function Shop.grant(profile: { [string]: any }, key: string, purchaseId: string, ctx: GrantContext?): ({ [string]: any }, { [string]: any })
	-- A copy, so the purchase id never leaks into the caller's table.
	local context: GrantContext = {}
	if type(ctx) == "table" then
		for k, v in pairs(ctx :: any) do
			(context :: any)[k] = v
		end
	end
	if type(purchaseId) ~= "string" or purchaseId == "" then
		return profile, { ok = false, reason = "Bad receipt." }
	end
	if Save.hasId(profile.receipts, purchaseId) then
		return profile, { ok = true, duplicate = true }
	end
	local entry, kind = Shop.entry(key)
	if entry == nil or kind ~= "product" then
		return profile, { ok = false, reason = "Unknown product." }
	end
	local nextProfile = Save.clone(profile)
	remember(nextProfile, purchaseId)
	context.purchaseId = purchaseId
	local detail = applyProduct(nextProfile, entry, context)
	detail.ok = true
	detail.duplicate = detail.duplicate == true
	detail.kind = kind
	return nextProfile, detail
end

-- Save the granted copy first. A failed save leaves the live profile alone.
function Shop.commit(
	profile: { [string]: any },
	key: string,
	purchaseId: string,
	ctx: GrantContext?,
	saveFn: (any) -> boolean
): ({ [string]: any }, { [string]: any })
	local nextProfile, result = Shop.grant(profile, key, purchaseId, ctx)
	if result.ok ~= true then
		return profile, result
	end
	if result.duplicate == true then
		return profile, result
	end
	local saved = saveFn(nextProfile)
	if saved ~= true then
		return profile, { ok = false, reason = "Not saved." }
	end
	return nextProfile, result
end

function Shop.preview(item: any): { [string]: any }?
	if type(item) ~= "table" then
		return nil
	end
	local tags: { string } = {}
	if type(item.tags) == "table" then
		for _, tag in ipairs(item.tags) do
			if type(tag) == "string" then
				table.insert(tags, tag)
			end
		end
	end
	return {
		id = item.id,
		name = item.name,
		category = item.category,
		w = item.w,
		d = item.d,
		color = item.color,
		surface = item.surface,
		tags = tags,
	}
end

return Shop
