--!strict
-- Schema 1 profiles and dream homes.
-- One session holds the lock. A second session does not write.
-- Tour and open votes are not a save point. Results, leave, and shutdown are.

local Save = {}

Save.Schema = 1
-- Hard cap per dream home and lookbook page. Matches a maxed two-storey house.
Save.MaxDreamPieces = 36

export type Lock = { session: string, at: number }

export type Store = {
	update: (string, (any) -> any) -> any,
}

function Save.profileKey(userId: string): string
	return "profile:" .. userId
end

function Save.dreamKey(userId: string): string
	return "dream:" .. userId
end

function Save.blankProfile(): { [string]: any }
	return {
		schema = 1,
		coins = 0,
		xp = 0,
		paid = {},
		stamps = {},
		bonuses = {},
		questDay = "",
		quests = {},
		rankMonth = "",
		rankPoints = 0,
		rankClaimed = {},
		receipts = {},
		codes = {},
		passes = {},
		owned = {},
		designPassStart = 0,
		designPassClaimed = {},
		dreamExtra = 0,
		hintRound = "",
		tutorialDone = false,
		funnel = {},
		spotPaid = {},
		rugPlaces = 0,
		seatPlaces = 0,
	}
end

function Save.blankDream(): { [string]: any }
	return {
		schema = 1,
		homes = { { pieces = {} } },
		lookbook = {},
	}
end

function Save.clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy: { [any]: any } = {}
	for key, entry in pairs(value) do
		copy[key] = Save.clone(entry)
	end
	return copy
end

local function asNumber(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return value
end

local function stringList(value: any): { string }
	local out: { string } = {}
	if type(value) ~= "table" then
		return out
	end
	for _, entry in ipairs(value) do
		if type(entry) == "string" and entry ~= "" then
			table.insert(out, entry)
		end
	end
	return out
end

local function numberList(value: any): { number }
	local out: { number } = {}
	if type(value) ~= "table" then
		return out
	end
	for _, entry in ipairs(value) do
		if type(entry) == "number" and entry == entry then
			table.insert(out, entry)
		end
	end
	return out
end

-- Drops a tampered luck flag. The server is the only writer of that hook.
function Save.normalizeProfile(raw: any): { [string]: any }
	local doc = Save.blankProfile()
	if type(raw) ~= "table" or raw.schema ~= 1 then
		return doc
	end
	doc.coins = math.max(0, math.floor(asNumber(raw.coins, 0)))
	doc.xp = math.max(0, math.floor(asNumber(raw.xp, 0)))
	doc.paid = stringList(raw.paid)
	doc.stamps = stringList(raw.stamps)
	doc.bonuses = stringList(raw.bonuses)
	if type(raw.questDay) == "string" then
		doc.questDay = raw.questDay
	end
	if type(raw.quests) == "table" then
		local quests: { any } = {}
		for _, entry in ipairs(raw.quests) do
			if type(entry) == "table" and type(entry.id) == "string" then
				table.insert(quests, {
					id = entry.id,
					progress = math.max(0, math.floor(asNumber(entry.progress, 0))),
				})
			end
		end
		doc.quests = quests
	end
	if type(raw.rankMonth) == "string" then
		doc.rankMonth = raw.rankMonth
	end
	doc.rankPoints = math.max(0, math.floor(asNumber(raw.rankPoints, 0)))
	doc.rankClaimed = numberList(raw.rankClaimed)
	doc.receipts = stringList(raw.receipts)
	doc.codes = stringList(raw.codes)
	doc.passes = stringList(raw.passes)
	doc.owned = stringList(raw.owned)
	doc.designPassStart = math.max(0, math.floor(asNumber(raw.designPassStart, 0)))
	doc.designPassClaimed = numberList(raw.designPassClaimed)
	doc.dreamExtra = math.max(0, math.floor(asNumber(raw.dreamExtra, 0)))
	if type(raw.hintRound) == "string" then
		doc.hintRound = raw.hintRound
	end
	doc.tutorialDone = raw.tutorialDone == true
	doc.funnel = stringList(raw.funnel)
	doc.spotPaid = stringList(raw.spotPaid)
	doc.rugPlaces = math.max(0, math.floor(asNumber(raw.rugPlaces, 0)))
	doc.seatPlaces = math.max(0, math.floor(asNumber(raw.seatPlaces, 0)))
	return doc
end

local function pieceList(value: any): { any }
	local out: { any } = {}
	if type(value) ~= "table" then
		return out
	end
	for _, entry in ipairs(value) do
		if type(entry) == "table" and type(entry.itemId) == "string" then
			table.insert(out, {
				id = math.floor(asNumber(entry.id, #out + 1)),
				itemId = entry.itemId,
				surface = if type(entry.surface) == "string" then entry.surface else "floor",
				x = math.floor(asNumber(entry.x, 0)),
				z = math.floor(asNumber(entry.z, 0)),
				rot = math.floor(asNumber(entry.rot, 0)) % 4,
				color = if type(entry.color) == "string" then entry.color else "cream",
				cost = math.max(0, math.floor(asNumber(entry.cost, 0))),
				placedAt = asNumber(entry.placedAt, 0),
				material = if type(entry.material) == "string" then entry.material else nil,
			})
		end
	end
	if #out > Save.MaxDreamPieces then
		local clipped: { any } = {}
		for index = 1, Save.MaxDreamPieces do
			table.insert(clipped, out[index])
		end
		return clipped
	end
	return out
end

function Save.normalizeDream(raw: any): { [string]: any }
	local doc = Save.blankDream()
	if type(raw) ~= "table" or raw.schema ~= 1 then
		return doc
	end
	if type(raw.homes) == "table" then
		local homes: { any } = {}
		for _, home in ipairs(raw.homes) do
			if type(home) == "table" then
				table.insert(homes, { pieces = pieceList(home.pieces) })
			end
		end
		if #homes > 0 then
			doc.homes = homes
		end
	end
	if type(raw.lookbook) == "table" then
		local book: { any } = {}
		for _, snap in ipairs(raw.lookbook) do
			if type(snap) == "table" and type(snap.roundId) == "string" then
				table.insert(book, {
					roundId = snap.roundId,
					themeId = if type(snap.themeId) == "string" then snap.themeId else "",
					themeName = if type(snap.themeName) == "string" then snap.themeName else "",
					roundType = if type(snap.roundType) == "string" then snap.roundType else "room",
					average = asNumber(snap.average, 0),
					pieces = pieceList(snap.pieces),
				})
			end
		end
		doc.lookbook = book
	end
	return doc
end

-- steps[n] upgrades a document that is already at schema n - 1.
-- Schema 1 is the baseline. The next save format adds a step here and bumps Save.Schema.
local steps: { [number]: (any) -> () } = {}

function Save.migrate(raw: any): (any?, string?)
	if type(raw) ~= "table" then
		return nil, "Schema."
	end
	local schema = raw.schema
	if type(schema) ~= "number" or schema ~= schema or schema ~= math.floor(schema) then
		return nil, "Schema."
	end
	if schema > Save.Schema or schema < 0 then
		return nil, "Schema."
	end
	local doc = Save.clone(raw)
	local version = schema
	while version < Save.Schema do
		local step = steps[version + 1]
		if step then
			step(doc)
		end
		version += 1
		doc.schema = version
	end
	doc.schema = Save.Schema
	return doc, nil
end

function Save.claim(current: any, sessionId: string, now: number, ttl: number): (any?, string?)
	if current ~= nil and type(current) ~= "table" then
		return nil, "Schema."
	end
	if type(current) == "table" and current.schema ~= nil and current.schema ~= Save.Schema then
		local migrated, err = Save.migrate(current)
		if not migrated then
			return nil, err or "Schema."
		end
		current = migrated
	end
	local lock = if type(current) == "table" then current.lock else nil
	if type(lock) == "table" and type(lock.session) == "string" and lock.session ~= sessionId then
		local at = if type(lock.at) == "number" then lock.at else 0
		if now < at + ttl then
			return nil, "Busy."
		end
	end
	local nextDoc = if type(current) == "table" then Save.clone(current) else { schema = 1 }
	nextDoc.schema = 1
	nextDoc.lock = { session = sessionId, at = now }
	nextDoc.luck = nil
	return nextDoc, nil
end

function Save.release(current: any, sessionId: string): (any?, string?)
	if type(current) ~= "table" then
		return nil, "Busy."
	end
	local lock = current.lock
	if type(lock) ~= "table" or lock.session ~= sessionId then
		return nil, "Busy."
	end
	local nextDoc = Save.clone(current)
	nextDoc.lock = nil
	nextDoc.luck = nil
	return nextDoc, nil
end

function Save.backoff(attempt: number): number
	local seconds = 0.5
	local step = 1
	while step < attempt do
		seconds *= 2
		step += 1
	end
	if seconds > 8 then
		return 8
	end
	return seconds
end

-- "live" writes the current profile. "settled" writes the last Results copy.
-- "skip" means a vote is still open, so this call must not touch the store.
function Save.which(phase: string, reason: string): string
	if phase == "Tour" then
		if reason == "leave" or reason == "shutdown" then
			return "settled"
		end
		return "skip"
	end
	if reason == "results" then
		if phase == "Results" then
			return "live"
		end
		return "skip"
	end
	if reason == "leave" or reason == "shutdown" then
		return "live"
	end
	return "skip"
end

function Save.memory(): Store
	local data: { [string]: any } = {}
	return {
		update = function(key: string, transform: (any) -> any): any
			local current = data[key]
			local snapshot = if current == nil then nil else Save.clone(current)
			local nextValue = transform(snapshot)
			if nextValue == nil then
				return nil
			end
			data[key] = Save.clone(nextValue)
			return Save.clone(nextValue)
		end,
	}
end

function Save.open(store: Store, key: string, sessionId: string, now: number, ttl: number): (any?, string?)
	local rejected: string? = nil
	local held: any = nil
	store.update(key, function(current)
		local nextDoc, err = Save.claim(current, sessionId, now, ttl)
		if not nextDoc then
			rejected = err or "Busy."
			return nil
		end
		held = nextDoc
		return nextDoc
	end)
	if rejected then
		return nil, rejected
	end
	return held, nil
end

function Save.write(
	store: Store,
	key: string,
	sessionId: string,
	doc: any,
	waitFn: ((number) -> ())?,
	maxAttempts: number?,
	now: number?
): (any?, number)
	local attempt = 0
	local limit = maxAttempts or 4
	local pause = waitFn or function(_seconds: number) end
	while attempt < limit do
		attempt += 1
		local ok, result = pcall(function()
			return store.update(key, function(current)
				if type(current) == "table" and type(current.lock) == "table" then
					if current.lock.session ~= nil and current.lock.session ~= sessionId then
						error("Busy.")
					end
				end
				local nextDoc = Save.clone(doc)
				nextDoc.schema = 1
				nextDoc.luck = nil
				if type(current) == "table" and type(current.lock) == "table" then
					local at = current.lock.at
					if type(now) == "number" and now == now then
						at = now
					end
					nextDoc.lock = {
						session = current.lock.session,
						at = at,
					}
				end
				return nextDoc
			end)
		end)
		if ok then
			return result, attempt
		end
		if attempt >= limit then
			return nil, attempt
		end
		pause(Save.backoff(attempt))
	end
	return nil, attempt
end

function Save.close(store: Store, key: string, sessionId: string): (any?, string?)
	local rejected: string? = nil
	local released: any = nil
	store.update(key, function(current)
		local nextDoc, err = Save.release(current, sessionId)
		if not nextDoc then
			rejected = err or "Busy."
			return nil
		end
		released = nextDoc
		return nextDoc
	end)
	if rejected then
		return nil, rejected
	end
	return released, nil
end

-- One in-flight write per session. A nested call is refused.
function Save.locker(): { run: (any) -> (any?, any?) }
	local busy = false
	return {
		run = function(fn: any): (any?, any?)
			if busy then
				return nil, "Busy."
			end
			busy = true
			local ok, a, b = pcall(function()
				return fn()
			end)
			busy = false
			if not ok then
				return nil, a
			end
			return a, b
		end,
	}
end

function Save.hasPaid(profile: { [string]: any }, roundId: string): boolean
	local paid = profile.paid
	if type(paid) ~= "table" then
		return false
	end
	for _, id in ipairs(paid) do
		if id == roundId then
			return true
		end
	end
	return false
end

function Save.markPaid(profile: { [string]: any }, roundId: string, cap: number)
	if Save.hasPaid(profile, roundId) then
		return
	end
	if type(profile.paid) ~= "table" then
		profile.paid = {}
	end
	table.insert(profile.paid, roundId)
	while #profile.paid > cap do
		table.remove(profile.paid, 1)
	end
end

function Save.hasId(list: any, id: string): boolean
	if type(list) ~= "table" then
		return false
	end
	for _, entry in ipairs(list) do
		if entry == id then
			return true
		end
	end
	return false
end

return Save
