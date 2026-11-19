--!strict
-- Placement actions. The server checks the grid, the budget, and the theme meter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RoomService = {}
local ctx: any = nil
local rooms: { [string]: any } = {}
local Config: any = nil
local Items: any = nil
local Placement: any = nil
local RoundEngine: any = nil
local Levels: any = nil
local Duo: any = nil
local Owned: any = nil
local Shop: any = nil
local Modifiers: any = nil
local Easter: any = nil

local function catalog(): any
	return {
		get = function(id: string): any
			return Items.get(id)
		end,
	}
end

local function bagOf(key: string): any
	if not ctx.saves then
		return nil
	end
	local bag = ctx.saves.session(key)
	if type(bag) ~= "table" or bag.hold ~= true or type(bag.profile) ~= "table" then
		return nil
	end
	return bag
end

local function levelFor(key: string): number
	local bag = bagOf(key)
	if not bag or not Levels then
		return 1
	end
	return Levels.fromXp(bag.profile.xp)
end

local function contextFor(key: string): any
	local round = ctx.round
	local view = RoundEngine.playerView(round, key)
	local theme = round.theme
	local role = "none"
	if view.inRound then
		role = if view.spectating then "spectator" else "active"
	end
	local roundType = ""
	local themeId = ""
	if type(theme) == "table" then
		roundType = theme.roundType or ""
		themeId = theme.id or ""
	end
	local paired = ctx.duo ~= nil and ctx.duo.paired(key) == true
	local budget = Config.Budget
	local maxItems = Config.MaxItems
	local gridType = roundType
	if Duo then
		budget = Duo.budget(Config.Budget, paired)
		maxItems = Duo.itemCap(Config.MaxItems, paired)
		gridType = Duo.gridType(roundType, paired)
	end
	local freeItem: string? = nil
	if Modifiers and type(round) == "table" then
		if round.modifier == "tiny" then
			budget = Modifiers.budget(budget, "tiny", 4)
		elseif round.modifier == "mystery" then
			freeItem = Modifiers.mystery(roundType, round.roundIndex)
		end
	end
	local level = levelFor(key)
	local bag = bagOf(key)
	local profile = if bag then bag.profile else nil
	local tools = profile ~= nil and Shop ~= nil and Shop.hasPass(profile, "DesignerTools") == true
	return {
		catalog = catalog(),
		roundType = roundType,
		themeId = themeId,
		budget = budget,
		maxItems = maxItems,
		role = role,
		phase = round.phase,
		locked = view.done == true,
		matchExact = Config.MatchExact,
		matchFamily = Config.MatchFamily,
		matchCap = Config.MatchCap,
		palette = Config.Palette,
		now = Workspace:GetServerTimeNow(),
		undoCap = Config.UndoCap,
		gridType = gridType,
		tools = tools,
		materials = Config.Shop.Materials,
		freeItem = freeItem,
		allow = function(itemId: string): boolean
			if profile and Owned then
				return Owned.has(profile, itemId, level)
			end
			if not Levels then
				return true
			end
			return Levels.owns(itemId, level)
		end,
	}
end

local function plotKey(key: string): string
	if ctx.dream and ctx.dream.isVisiting(key) then
		return key
	end
	if ctx.duo then
		return ctx.duo.lead(key)
	end
	return key
end

local function publish(player: Player, key: string, room: any, c: any)
	local coins = 0
	local meter = 0
	if c.freeSpend == true then
		coins = 999
	elseif c.role == "active" then
		coins = Placement.coinsLeft(room, c.budget)
		meter = Placement.meter(room, c)
	end
	player:SetAttribute("CoinsLeft", coins)
	player:SetAttribute("ThemeMatch", meter)
	local index = ctx.plots.indexOf(plotKey(key))
	if type(index) == "number" then
		local model = ctx.plots.model(index)
		if model then
			model:SetAttribute("CoinsLeft", coins)
			model:SetAttribute("ThemeMatch", meter)
		end
	end
end

local function roomFor(key: string): any
	local lead = key
	if ctx.duo then
		lead = ctx.duo.lead(key)
	end
	local room = rooms[lead]
	if not room then
		room = rooms[key]
	end
	if not room then
		room = Placement.empty()
	end
	rooms[lead] = room
	rooms[key] = room
	return room
end

-- Contest room, or the dream home when this player is visiting.
-- The dream table is not `rooms`, so a lobby wipe cannot clear it.
local function resolve(key: string): (any, any, string, number?)
	if ctx.dream and ctx.dream.isVisiting(key) then
		local room, dreamCtx = ctx.dream.editing(key)
		local index = ctx.plots.indexOf(key)
		local grid = dreamCtx.gridType
		if type(grid) ~= "string" then
			grid = "studio"
		end
		return room, dreamCtx, grid, index
	end
	local c = contextFor(key)
	local room = roomFor(key)
	local lead = key
	if ctx.duo then
		lead = ctx.duo.lead(key)
	end
	local index = ctx.plots.indexOf(lead)
	local grid = c.gridType or c.roundType
	return room, c, grid, index
end

local function afterEdit(key: string, stat: string?)
	if ctx.dream and ctx.dream.isVisiting(key) then
		ctx.dream.sync(key)
		return
	end
	if stat and ctx.progress and type(ctx.progress.bump) == "function" then
		ctx.progress.bump(key, stat)
	end
end

local function apply(key: string, effect: any, roundType: string)
	if type(effect) ~= "table" or type(effect.piece) ~= "table" then
		return
	end
	local index = ctx.plots.indexOf(plotKey(key))
	if type(index) ~= "number" then
		return
	end
	local piece = effect.piece
	if effect.kind == "remove" then
		ctx.plots.removePiece(index, piece.id)
	elseif effect.kind == "spawn" or effect.kind == "update" then
		ctx.plots.removePiece(index, piece.id)
		if piece.itemId then
			ctx.plots.spawnPiece(index, piece, roundType, effect.kind == "spawn")
		end
	end
end

local function playerFromKey(key: string): Player?
	local userId = tonumber(key)
	if not userId then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

function RoomService.welcome(player: Player)
	local key = tostring(player.UserId)
	-- PlayerAdded can also fire for someone already in GetPlayers. Keep the room.
	if rooms[key] == nil then
		rooms[key] = Placement.empty()
	end
	local c = contextFor(key)
	publish(player, key, rooms[key], c)
end

function RoomService.forget(key: string)
	rooms[key] = nil
end

function RoomService.inspect(key: string): any
	local room = rooms[key]
	local pieces = 0
	local unique = 0
	local spent = 0
	local meter = 0
	local itemIds: { string } = {}
	if room then
		local seen: { [string]: boolean } = {}
		pieces = #room.pieces
		spent = room.spent
		for _, piece in ipairs(room.pieces) do
			table.insert(itemIds, piece.itemId)
			if seen[piece.itemId] ~= true then
				seen[piece.itemId] = true
				unique += 1
			end
		end
		meter = Placement.meter(room, contextFor(key))
	end
	local cap = Config.MaxItems
	if Duo and ctx.duo and ctx.duo.paired(key) then
		cap = Duo.itemCap(Config.MaxItems, true)
	end
	return {
		pieces = pieces,
		unique = unique,
		spent = spent,
		meter = meter,
		maxItems = cap,
		itemIds = itemIds,
	}
end

function RoomService.copyPieces(key: string): { any }
	local room = rooms[key]
	local list: { any } = {}
	if not room then
		return list
	end
	for _, piece in ipairs(room.pieces) do
		table.insert(list, {
			id = piece.id,
			itemId = piece.itemId,
			surface = piece.surface,
			x = piece.x,
			z = piece.z,
			rot = piece.rot,
			color = piece.color,
			cost = piece.cost,
			placedAt = piece.placedAt,
		})
	end
	return list
end

function RoomService.onPhase(round: any)
	local phase = round.phase
	local theme = round.theme
	local roundType = "room"
	if type(theme) == "table" and type(theme.roundType) == "string" then
		roundType = theme.roundType
	end
	if phase == "Lobby" then
		ctx.plots.clearItems()
		for key in pairs(rooms) do
			rooms[key] = Placement.empty()
		end
		ctx.plots.show("room")
		return
	end
	if phase == "ThemeReveal" then
		ctx.plots.show(roundType)
		return
	end
	if phase == "Build" then
		ctx.plots.clearItems()
		ctx.plots.show(roundType)
		local made: { [string]: any } = {}
		for _, player in Players:GetPlayers() do
			local key = tostring(player.UserId)
			local lead = key
			if ctx.duo then
				lead = ctx.duo.lead(key)
			end
			if not made[lead] then
				made[lead] = Placement.empty()
			end
			rooms[key] = made[lead]
			local c = contextFor(key)
			publish(player, key, rooms[key], c)
		end
	end
end

function RoomService.init(c: any)
	ctx = c
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
	Items = require(Shared:WaitForChild("Items") :: ModuleScript) :: any
	local Logic = Shared:WaitForChild("Logic")
	Placement = require(Logic:WaitForChild("Placement") :: ModuleScript) :: any
	RoundEngine = require(Logic:WaitForChild("RoundEngine") :: ModuleScript) :: any
	Levels = require(Logic:WaitForChild("Levels") :: ModuleScript) :: any
	Duo = require(Logic:WaitForChild("Duo") :: ModuleScript) :: any
	Owned = require(Logic:WaitForChild("Owned") :: ModuleScript) :: any
	Shop = require(Logic:WaitForChild("Shop") :: ModuleScript) :: any
	Modifiers = require(Logic:WaitForChild("Modifiers") :: ModuleScript) :: any
	Easter = require(Logic:WaitForChild("Easter") :: ModuleScript) :: any
	local Props = require(script.Parent.Parent:WaitForChild("Props") :: ModuleScript) :: any
	ctx.rooms = {
		welcome = RoomService.welcome,
		forget = RoomService.forget,
		onPhase = RoomService.onPhase,
		inspect = RoomService.inspect,
		copyPieces = RoomService.copyPieces,
	}

	ctx.actions.register("Place", { "string", "number", "number" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local room, c, grid, index = resolve(key)
		if type(index) ~= "number" then
			return false, "No plot yet."
		end
		local ok, msg, piece = Placement.place(room, c, args[1], args[2], args[3])
		if ok and piece then
			ctx.plots.spawnPiece(index, piece, grid, true)
			publish(player, key, room, c)
			afterEdit(key, "props")
			local visiting = ctx.dream and ctx.dream.isVisiting(key) == true
			if not visiting then
				local bag = bagOf(key)
				if bag and Easter then
					Easter.note(bag.profile, Items.get(args[1]), levelFor(key))
				end
				if ctx.funnel and type(ctx.funnel.onPlace) == "function" then
					pcall(ctx.funnel.onPlace, key)
				end
			end
			return true, msg, { id = piece.id }
		end
		return false, msg
	end)

	ctx.actions.register("Rotate", { "number" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local room, c, grid = resolve(key)
		local ok, msg, piece = Placement.rotate(room, c, args[1])
		if ok and piece then
			apply(key, { kind = "update", piece = piece }, grid)
			publish(player, key, room, c)
			afterEdit(key, nil)
			return true, msg, { id = piece.id }
		end
		return false, msg
	end)

	ctx.actions.register("Recolor", { "number", "string" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local room, c, grid, index = resolve(key)
		local ok, msg, piece = Placement.recolor(room, c, args[1], args[2])
		if ok and piece then
			if type(index) == "number" then
				local model = ctx.plots.model(index)
				local folder = if model then model:FindFirstChild("Items") else nil
				local existing = if folder then folder:FindFirstChild("P" .. tostring(piece.id)) else nil
				if existing and existing:IsA("Model") then
					ctx.Props.recolor(existing, piece.color)
				else
					apply(key, { kind = "update", piece = piece }, grid)
				end
			end
			publish(player, key, room, c)
			afterEdit(key, "recolors")
			return true, msg, { id = piece.id }
		end
		return false, msg
	end)

	ctx.actions.register("Delete", { "number" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local room, c, grid = resolve(key)
		local ok, msg, piece = Placement.delete(room, c, args[1])
		if ok and piece then
			apply(key, { kind = "remove", piece = piece }, grid)
			publish(player, key, room, c)
			afterEdit(key, nil)
			return true, msg, { id = piece.id }
		end
		return false, msg
	end)

	ctx.actions.register("Surface", { "string", "string" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local room, c, _grid, index = resolve(key)
		local ok, msg = Placement.paint(room, c, args[1], args[2])
		if ok and type(index) == "number" and ctx.plots then
			local model = ctx.plots.model(index)
			if model then
				Props.paintShell(model, args[1], args[2])
			end
		end
		return ok, msg
	end)

	ctx.actions.register("Finish", { "number", "string" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local room, c, grid = resolve(key)
		local ok, msg, piece = Placement.finish(room, c, args[1], args[2])
		if ok and piece then
			apply(key, { kind = "update", piece = piece }, grid)
		end
		return ok, msg
	end)

	ctx.actions.register("Undo", {}, function(key: string, _args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local room, c, grid = resolve(key)
		local ok, msg, effect = Placement.undo(room, c)
		if ok then
			apply(key, effect, grid)
			publish(player, key, room, c)
			afterEdit(key, nil)
			local id = nil
			if type(effect) == "table" and type(effect.piece) == "table" then
				id = effect.piece.id
			end
			return true, msg, { id = id }
		end
		return false, msg
	end)
end

function RoomService.start()
	RoundEngine.setHasWork(ctx.round, function(id: string): boolean
		return Placement.hasPieces(rooms[id])
	end)
end

return RoomService
