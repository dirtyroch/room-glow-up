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

local function catalog(): any
	return {
		get = function(id: string): any
			return Items.get(id)
		end,
	}
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
	return {
		catalog = catalog(),
		roundType = roundType,
		themeId = themeId,
		budget = Config.Budget,
		maxItems = Config.MaxItems,
		role = role,
		phase = round.phase,
		locked = view.done == true,
		matchExact = Config.MatchExact,
		matchFamily = Config.MatchFamily,
		matchCap = Config.MatchCap,
		palette = Config.Palette,
		now = Workspace:GetServerTimeNow(),
		undoCap = Config.UndoCap,
	}
end

local function publish(player: Player, key: string, room: any, c: any)
	local coins = 0
	local meter = 0
	if c.role == "active" then
		coins = Placement.coinsLeft(room, c.budget)
		meter = Placement.meter(room, c)
	end
	player:SetAttribute("CoinsLeft", coins)
	player:SetAttribute("ThemeMatch", meter)
	local index = ctx.plots.indexOf(key)
	if type(index) == "number" then
		local model = ctx.plots.model(index)
		if model then
			model:SetAttribute("CoinsLeft", coins)
			model:SetAttribute("ThemeMatch", meter)
		end
	end
end

local function roomFor(key: string): any
	local room = rooms[key]
	if not room then
		room = Placement.empty()
		rooms[key] = room
	end
	return room
end

local function apply(key: string, effect: any, roundType: string)
	if type(effect) ~= "table" or type(effect.piece) ~= "table" then
		return
	end
	local index = ctx.plots.indexOf(key)
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
	if room then
		local seen: { [string]: boolean } = {}
		pieces = #room.pieces
		spent = room.spent
		for _, piece in ipairs(room.pieces) do
			if seen[piece.itemId] ~= true then
				seen[piece.itemId] = true
				unique += 1
			end
		end
		meter = Placement.meter(room, contextFor(key))
	end
	return {
		pieces = pieces,
		unique = unique,
		spent = spent,
		meter = meter,
		maxItems = Config.MaxItems,
	}
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
		for _, player in Players:GetPlayers() do
			local key = tostring(player.UserId)
			rooms[key] = Placement.empty()
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
	ctx.rooms = {
		welcome = RoomService.welcome,
		forget = RoomService.forget,
		onPhase = RoomService.onPhase,
		inspect = RoomService.inspect,
	}

	ctx.actions.register("Place", { "string", "number", "number" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local index = ctx.plots.indexOf(key)
		if type(index) ~= "number" then
			return false, "No plot yet."
		end
		local c = contextFor(key)
		local room = roomFor(key)
		local ok, msg, piece = Placement.place(room, c, args[1], args[2], args[3])
		if ok and piece then
			ctx.plots.spawnPiece(index, piece, c.roundType, true)
			publish(player, key, room, c)
			return true, msg, { id = piece.id }
		end
		return false, msg
	end)

	ctx.actions.register("Rotate", { "number" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local c = contextFor(key)
		local room = roomFor(key)
		local ok, msg, piece = Placement.rotate(room, c, args[1])
		if ok and piece then
			apply(key, { kind = "update", piece = piece }, c.roundType)
			publish(player, key, room, c)
			return true, msg, { id = piece.id }
		end
		return false, msg
	end)

	ctx.actions.register("Recolor", { "number", "string" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local c = contextFor(key)
		local room = roomFor(key)
		local ok, msg, piece = Placement.recolor(room, c, args[1], args[2])
		if ok and piece then
			local index = ctx.plots.indexOf(key)
			if type(index) == "number" then
				local model = ctx.plots.model(index)
				local folder = if model then model:FindFirstChild("Items") else nil
				local existing = if folder then folder:FindFirstChild("P" .. tostring(piece.id)) else nil
				if existing and existing:IsA("Model") then
					ctx.Props.recolor(existing, piece.color)
				else
					apply(key, { kind = "update", piece = piece }, c.roundType)
				end
			end
			publish(player, key, room, c)
			return true, msg, { id = piece.id }
		end
		return false, msg
	end)

	ctx.actions.register("Delete", { "number" }, function(key: string, args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local c = contextFor(key)
		local room = roomFor(key)
		local ok, msg, piece = Placement.delete(room, c, args[1])
		if ok and piece then
			apply(key, { kind = "remove", piece = piece }, c.roundType)
			publish(player, key, room, c)
			return true, msg, { id = piece.id }
		end
		return false, msg
	end)

	ctx.actions.register("Undo", {}, function(key: string, _args: { any })
		local player = playerFromKey(key)
		if not player then
			return false, "You are not in this round."
		end
		local c = contextFor(key)
		local room = roomFor(key)
		local ok, msg, effect = Placement.undo(room, c)
		if ok then
			apply(key, effect, c.roundType)
			publish(player, key, room, c)
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
