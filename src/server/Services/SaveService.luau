--!strict
-- Session-locked saves. One writer per player. Writes retry with backoff.
-- Nothing is written during Tour. Leave and shutdown write the last settled copy
-- if a vote is still open, and the live profile otherwise.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveService = {}
local ctx: any = nil
local Save: any = nil
local Config: any = nil
local profileStore: any = nil
local dreamStore: any = nil
local sessions: { [string]: any } = {}

local function sessionId(): string
	local job = game.JobId
	if type(job) == "string" and job ~= "" then
		return job
	end
	return "server-" .. tostring(os.time())
end

local function memoryOr(name: string): any
	local ok, store = pcall(function()
		return game:GetService("DataStoreService"):GetDataStore(name)
	end)
	if not ok or store == nil then
		return Save.memory()
	end
	return {
		update = function(key: string, transform: (any) -> any): any
			return store:UpdateAsync(key, function(old)
				return transform(old)
			end)
		end,
	}
end

local function pause(seconds: number)
	task.wait(seconds)
end

local function phaseNow(): string
	local round = ctx.round
	if type(round) == "table" and type(round.phase) == "string" then
		return round.phase
	end
	return "Lobby"
end

local function writeDoc(store: any, key: string, bag: any, doc: any): boolean
	local result = bag.lock.run(function()
		local saved = Save.write(
			store,
			key,
			ctx.sessionId,
			doc,
			pause,
			#Config.Progress.RetrySeconds,
			os.time()
		)
		return saved
	end)
	return result ~= nil
end

local function loadKey(store: any, key: string, normalize: (any) -> any): (any?, boolean)
	local claimed, err = Save.open(store, key, ctx.sessionId, os.time(), Config.Progress.LockSeconds)
	if not claimed then
		if err ~= "Busy." then
			local attempt = 0
			while not claimed and attempt < #Config.Progress.RetrySeconds do
				attempt += 1
				pause(Save.backoff(attempt))
				claimed, err = Save.open(store, key, ctx.sessionId, os.time(), Config.Progress.LockSeconds)
				if err == "Busy." then
					break
				end
			end
		end
	end
	if not claimed then
		return normalize(nil), false
	end
	return normalize(claimed), true
end

local function remember(player: Player)
	local key = tostring(player.UserId)
	if sessions[key] then
		return
	end
	local placeholder = {
		hold = false,
		profile = Save.normalizeProfile(nil),
		dream = Save.normalizeDream(nil),
		settledProfile = Save.normalizeProfile(nil),
		settledDream = Save.normalizeDream(nil),
		lock = Save.locker(pause, 30),
	}
	sessions[key] = placeholder
	local profile, profileHeld = loadKey(profileStore, Save.profileKey(key), Save.normalizeProfile)
	local dream, dreamHeld = loadKey(dreamStore, Save.dreamKey(key), Save.normalizeDream)
	if sessions[key] ~= placeholder then
		if profileHeld then
			Save.close(profileStore, Save.profileKey(key), ctx.sessionId)
		end
		if dreamHeld then
			Save.close(dreamStore, Save.dreamKey(key), ctx.sessionId)
		end
		return
	end
	local hold = profileHeld == true and dreamHeld == true
	if not hold then
		if profileHeld then
			Save.close(profileStore, Save.profileKey(key), ctx.sessionId)
		end
		if dreamHeld then
			Save.close(dreamStore, Save.dreamKey(key), ctx.sessionId)
		end
		profile = Save.normalizeProfile(nil)
		dream = Save.normalizeDream(nil)
	end
	placeholder.hold = hold
	placeholder.profile = profile
	placeholder.dream = dream
	placeholder.settledProfile = Save.clone(profile)
	placeholder.settledDream = Save.clone(dream)
	if ctx.progress and type(ctx.progress.present) == "function" then
		ctx.progress.present(player)
	end
	if ctx.funnel and type(ctx.funnel.present) == "function" then
		ctx.funnel.present(player)
	end
end

local function commit(key: string, reason: string)
	local bag = sessions[key]
	if not bag or bag.hold ~= true then
		return
	end
	local mode = Save.which(phaseNow(), reason)
	if mode == "skip" then
		return
	end
	local profile = if mode == "settled" then bag.settledProfile else bag.profile
	local dream = if mode == "settled" then bag.settledDream else bag.dream
	local profileDoc = Save.clone(profile)
	profileDoc.schema = 1
	local dreamDoc = Save.clone(dream)
	dreamDoc.schema = 1
	writeDoc(profileStore, Save.profileKey(key), bag, profileDoc)
	writeDoc(dreamStore, Save.dreamKey(key), bag, dreamDoc)
	if mode == "live" then
		bag.settledProfile = Save.clone(bag.profile)
		bag.settledDream = Save.clone(bag.dream)
	end
end

local function release(key: string)
	local bag = sessions[key]
	if not bag then
		return
	end
	if bag.hold then
		bag.lock.run(function()
			Save.close(profileStore, Save.profileKey(key), ctx.sessionId)
			Save.close(dreamStore, Save.dreamKey(key), ctx.sessionId)
			return true
		end)
	end
	sessions[key] = nil
end

function SaveService.init(c: any)
	ctx = c
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
	local Logic = Shared:WaitForChild("Logic")
	Save = require(Logic:WaitForChild("Save") :: ModuleScript) :: any
	ctx.sessionId = sessionId()
	profileStore = memoryOr(Config.Progress.ProfileStore)
	dreamStore = memoryOr(Config.Progress.DreamStore)
	ctx.saves = {
		session = function(key: string): any
			local bag = sessions[key]
			if bag then
				return bag
			end
			return {
				hold = false,
				profile = Save.normalizeProfile(nil),
				dream = Save.normalizeDream(nil),
				settledProfile = Save.normalizeProfile(nil),
				settledDream = Save.normalizeDream(nil),
				lock = Save.locker(),
			}
		end,
		commit = commit,
		release = release,
		commitAll = function(reason: string)
			for key in pairs(sessions) do
				commit(key, reason)
			end
		end,
		-- Writes even during Tour. Used after a receipt is stored and before it is shown.
		apply = function(key: string, doc: any): boolean
			local bag = sessions[key]
			if not bag or bag.hold ~= true or type(doc) ~= "table" then
				return false
			end
			local profileDoc = Save.clone(doc)
			profileDoc.schema = 1
			profileDoc.luck = nil
			local live = doc == bag.profile
			local wrote = writeDoc(profileStore, Save.profileKey(key), bag, profileDoc)
			if not wrote then
				return false
			end
			-- A save of the live table keeps that table. Swapping in the copy would
			-- drop anything that changed while the write was waiting on the store.
			if not live then
				bag.profile = profileDoc
			end
			bag.settledProfile = Save.clone(profileDoc)
			return true
		end,
		-- Saves the live profile without making the caller wait. For small things
		-- (a minigame payout, a funnel mark, an Easter egg) that the next results
		-- or leave write would cover anyway. Never for receipts.
		queue = function(key: string)
			task.spawn(function()
				local bag = sessions[key]
				if bag and bag.hold == true then
					ctx.saves.apply(key, bag.profile)
				end
			end)
		end,
	}
	Players.PlayerAdded:Connect(remember)
	Players.PlayerRemoving:Connect(function(player: Player)
		local key = tostring(player.UserId)
		commit(key, "leave")
		release(key)
	end)
	for _, player in Players:GetPlayers() do
		remember(player)
	end
end

function SaveService.start()
	game:BindToClose(function()
		if not ctx.saves then
			return
		end
		-- Flush every player at once so 10 profiles fit in the shutdown window.
		local keys: { string } = {}
		for key in pairs(sessions) do
			table.insert(keys, key)
		end
		local left = #keys
		for _, key in ipairs(keys) do
			task.spawn(function()
				commit(key, "shutdown")
				release(key)
				left -= 1
			end)
		end
		local started = os.clock()
		while left > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return SaveService
