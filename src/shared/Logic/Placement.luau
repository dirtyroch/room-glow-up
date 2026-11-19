--!strict
-- Server-side placement rules: grid, hooks, coin budget, theme meter, undo.
-- The client can ask. This module decides.

local function sibling(name: string): any
	local ok, loaded = pcall(function()
		local child = script.Parent.Parent:WaitForChild(name)
		return (require :: any)(child)
	end)
	if ok then
		return loaded
	end
	return (require :: any)("../" .. name)
end

local Bases = sibling("Bases")

local Placement = {}

export type Piece = {
	id: number,
	itemId: string,
	surface: string,
	x: number,
	z: number,
	rot: number,
	color: string,
	cost: number,
	placedAt: number,
}

export type Room = {
	pieces: { Piece },
	nextId: number,
	spent: number,
	undo: { any },
}

export type Catalog = {
	get: (string) -> any,
}

export type Context = {
	catalog: Catalog,
	roundType: string,
	themeId: string,
	budget: number,
	maxItems: number,
	role: string,
	phase: string,
	locked: boolean,
	matchExact: number,
	matchFamily: number,
	matchCap: number,
	palette: { string },
	now: number?,
	undoCap: number?,
	-- Dream home and duo rooms. Absent means the contest grid, the budget, and every catalog item.
	gridType: string?,
	allow: ((string) -> boolean)?,
	freeSpend: boolean?,
}

local function copyPiece(piece: Piece): Piece
	return {
		id = piece.id,
		itemId = piece.itemId,
		surface = piece.surface,
		x = piece.x,
		z = piece.z,
		rot = piece.rot,
		color = piece.color,
		cost = piece.cost,
		placedAt = piece.placedAt,
	}
end

function Placement.empty(): Room
	return {
		pieces = {},
		nextId = 1,
		spent = 0,
		undo = {},
	}
end

function Placement.hasPieces(room: Room?): boolean
	return room ~= nil and #room.pieces > 0
end

function Placement.coinsLeft(room: Room, budget: number): number
	return math.max(0, budget - room.spent)
end

local function hasTag(item: any, tag: string): boolean
	if tag == "" or type(item.tags) ~= "table" then
		return false
	end
	for _, name in ipairs(item.tags) do
		if name == tag then
			return true
		end
	end
	return false
end

function Placement.meter(room: Room, ctx: Context): number
	local score = 0
	for _, piece in ipairs(room.pieces) do
		local item = ctx.catalog.get(piece.itemId)
		if item then
			if hasTag(item, ctx.themeId) then
				score += ctx.matchExact
			elseif hasTag(item, ctx.roundType) then
				score += ctx.matchFamily
			end
		end
	end
	if score < 0 then
		return 0
	end
	if score > ctx.matchCap then
		return ctx.matchCap
	end
	return score
end

local function findPiece(room: Room, id: number): (number?, Piece?)
	for index, piece in ipairs(room.pieces) do
		if piece.id == id then
			return index, piece
		end
	end
	return nil, nil
end

local function layerOf(item: any): string
	if item.surface == "floor" and type(item.h) == "number" and item.h <= 0.1 then
		return "flat"
	end
	return "solid"
end

local function span(item: any, rot: number): (number, number)
	if rot % 2 == 1 then
		return item.d, item.w
	end
	return item.w, item.d
end

local function cellsOf(item: any, surface: string, x: number, z: number, rot: number): { { number } }
	if surface == "hook" then
		return { { x, 0 } }
	end
	local w, d = span(item, rot)
	local cells: { { number } } = {}
	for dx = 0, w - 1 do
		for dz = 0, d - 1 do
			table.insert(cells, { x + dx, z + dz })
		end
	end
	return cells
end

local function occupied(room: Room, catalog: Catalog, ignoreId: number?): { [string]: boolean }
	local taken: { [string]: boolean } = {}
	for _, piece in ipairs(room.pieces) do
		if piece.id ~= ignoreId then
			local item = catalog.get(piece.itemId)
			if item then
				local layer = layerOf(item)
				for _, cell in ipairs(cellsOf(item, piece.surface, piece.x, piece.z, piece.rot)) do
					taken[piece.surface .. ":" .. layer .. ":" .. tostring(cell[1]) .. ":" .. tostring(cell[2])] = true
				end
			end
		end
	end
	return taken
end

local function pushUndo(room: Room, ctx: Context, op: any)
	table.insert(room.undo, op)
	local cap = ctx.undoCap or 24
	while #room.undo > cap do
		table.remove(room.undo, 1)
	end
end

local function gate(ctx: Context): (boolean, string?)
	if ctx.role == "spectator" then
		return false, "Watching this round. You will play the next one."
	end
	if ctx.role ~= "active" then
		return false, "You are not in this round."
	end
	if ctx.phase ~= "Build" and ctx.phase ~= "Dream" then
		return false, "You can place during Build."
	end
	if ctx.locked then
		return false, "Locked in."
	end
	return true, nil
end

local function gridOf(ctx: Context): string
	if type(ctx.gridType) == "string" and ctx.gridType ~= "" then
		return ctx.gridType
	end
	return ctx.roundType
end

local function itemAllowed(ctx: Context, itemId: string): boolean
	if type(ctx.allow) ~= "function" then
		return true
	end
	return ctx.allow(itemId) == true
end

local function overBudget(ctx: Context, room: Room, cost: number): boolean
	if ctx.freeSpend == true then
		return false
	end
	return room.spent + cost > ctx.budget
end

local function paletteHas(ctx: Context, color: string): boolean
	for _, name in ipairs(ctx.palette) do
		if name == color then
			return true
		end
	end
	return false
end

function Placement.place(room: Room, ctx: Context, itemId: string, x: number, z: number): (boolean, string?, Piece?)
	local allowed, why = gate(ctx)
	if not allowed then
		return false, why, nil
	end
	if type(itemId) ~= "string" then
		return false, "Unknown item.", nil
	end
	local item = ctx.catalog.get(itemId)
	if type(item) ~= "table" then
		return false, "Unknown item.", nil
	end
	if not itemAllowed(ctx, itemId) then
		return false, "That piece is still locked.", nil
	end
	local grid = gridOf(ctx)
	if not Bases.allows(grid, item.surface) then
		return false, "That piece does not fit this round.", nil
	end
	if #room.pieces >= ctx.maxItems then
		return false, "This room is full.", nil
	end
	if not Bases.isIndex(x) or not Bases.isIndex(z) then
		return false, "That spot is off the grid.", nil
	end
	if item.surface == "hook" and z ~= 0 then
		return false, "That spot is off the grid.", nil
	end
	if not Bases.fits(grid, item.surface, x, z, item.w, item.d, 0) then
		return false, "That spot does not fit.", nil
	end
	if overBudget(ctx, room, item.cost) then
		return false, "Not enough coins.", nil
	end
	local layer = layerOf(item)
	local taken = occupied(room, ctx.catalog, nil)
	for _, cell in ipairs(cellsOf(item, item.surface, x, z, 0)) do
		local key = item.surface .. ":" .. layer .. ":" .. tostring(cell[1]) .. ":" .. tostring(cell[2])
		if taken[key] then
			return false, "Something is already there.", nil
		end
	end
	local piece: Piece = {
		id = room.nextId,
		itemId = itemId,
		surface = item.surface,
		x = x,
		z = z,
		rot = 0,
		color = item.color,
		cost = item.cost,
		placedAt = ctx.now or 0,
	}
	room.nextId += 1
	room.spent += item.cost
	table.insert(room.pieces, piece)
	pushUndo(room, ctx, { kind = "place", id = piece.id })
	return true, "Placed.", copyPiece(piece)
end

function Placement.rotate(room: Room, ctx: Context, pieceId: number): (boolean, string?, Piece?)
	local allowed, why = gate(ctx)
	if not allowed then
		return false, why, nil
	end
	local _, piece = findPiece(room, pieceId)
	if not piece then
		return false, "That piece is gone.", nil
	end
	local item = ctx.catalog.get(piece.itemId)
	if not item then
		return false, "Unknown item.", nil
	end
	local nextRot = (piece.rot + 1) % 4
	if not Bases.fits(gridOf(ctx), piece.surface, piece.x, piece.z, item.w, item.d, nextRot) then
		return false, "It cannot turn there.", nil
	end
	local layer = layerOf(item)
	local taken = occupied(room, ctx.catalog, piece.id)
	for _, cell in ipairs(cellsOf(item, piece.surface, piece.x, piece.z, nextRot)) do
		local key = piece.surface .. ":" .. layer .. ":" .. tostring(cell[1]) .. ":" .. tostring(cell[2])
		if taken[key] then
			return false, "It cannot turn there.", nil
		end
	end
	local previous = piece.rot
	piece.rot = nextRot
	pushUndo(room, ctx, { kind = "rotate", id = piece.id, rot = previous })
	return true, "Turned.", copyPiece(piece)
end

function Placement.recolor(room: Room, ctx: Context, pieceId: number, color: string): (boolean, string?, Piece?)
	local allowed, why = gate(ctx)
	if not allowed then
		return false, why, nil
	end
	if not paletteHas(ctx, color) then
		return false, "Pick a color from the palette.", nil
	end
	local _, piece = findPiece(room, pieceId)
	if not piece then
		return false, "That piece is gone.", nil
	end
	local previous = piece.color
	if previous == color then
		return true, "Already that color.", copyPiece(piece)
	end
	piece.color = color
	pushUndo(room, ctx, { kind = "recolor", id = piece.id, color = previous })
	return true, "Recolored.", copyPiece(piece)
end

function Placement.delete(room: Room, ctx: Context, pieceId: number): (boolean, string?, Piece?)
	local allowed, why = gate(ctx)
	if not allowed then
		return false, why, nil
	end
	local index, piece = findPiece(room, pieceId)
	if not index or not piece then
		return false, "That piece is gone.", nil
	end
	local saved = copyPiece(piece)
	table.remove(room.pieces, index)
	room.spent = math.max(0, room.spent - piece.cost)
	pushUndo(room, ctx, { kind = "delete", piece = saved })
	return true, "Removed.", saved
end

local function effectFor(kind: string, piece: any): any
	return { kind = kind, piece = piece }
end

function Placement.undo(room: Room, ctx: Context): (boolean, string?, any)
	local allowed, why = gate(ctx)
	if not allowed then
		return false, why, nil
	end
	local op = room.undo[#room.undo]
	if not op then
		return false, "Nothing to undo.", nil
	end
	if op.kind == "place" then
		local index, piece = findPiece(room, op.id)
		if index and piece then
			table.remove(room.pieces, index)
			room.spent = math.max(0, room.spent - piece.cost)
		end
		table.remove(room.undo)
		return true, "Undone.", effectFor("remove", { id = op.id } :: any)
	end
	if op.kind == "delete" then
		local piece = op.piece
		local item = ctx.catalog.get(piece.itemId)
		if not item then
			return false, "Unknown item.", nil
		end
		if #room.pieces >= ctx.maxItems then
			return false, "This room is full.", nil
		end
		if overBudget(ctx, room, piece.cost) then
			return false, "Not enough coins.", nil
		end
		local layer = layerOf(item)
		local taken = occupied(room, ctx.catalog, nil)
		for _, cell in ipairs(cellsOf(item, piece.surface, piece.x, piece.z, piece.rot)) do
			local key = piece.surface .. ":" .. layer .. ":" .. tostring(cell[1]) .. ":" .. tostring(cell[2])
			if taken[key] then
				return false, "Something is already there.", nil
			end
		end
		room.spent += piece.cost
		local restored = copyPiece(piece)
		restored.placedAt = ctx.now or piece.placedAt
		table.insert(room.pieces, restored)
		table.remove(room.undo)
		return true, "Undone.", effectFor("spawn", restored)
	end
	if op.kind == "rotate" or op.kind == "recolor" then
		local _, piece = findPiece(room, op.id)
		if not piece then
			table.remove(room.undo)
			return false, "That piece is gone.", nil
		end
		if op.kind == "rotate" then
			local item = ctx.catalog.get(piece.itemId)
			if item then
				if not Bases.fits(gridOf(ctx), piece.surface, piece.x, piece.z, item.w, item.d, op.rot) then
					return false, "It cannot turn there.", nil
				end
				local layer = layerOf(item)
				local taken = occupied(room, ctx.catalog, piece.id)
				for _, cell in ipairs(cellsOf(item, piece.surface, piece.x, piece.z, op.rot)) do
					local key = piece.surface .. ":" .. layer .. ":" .. tostring(cell[1]) .. ":" .. tostring(cell[2])
					if taken[key] then
						return false, "It cannot turn there.", nil
					end
				end
			end
			piece.rot = op.rot
		else
			piece.color = op.color
		end
		table.remove(room.undo)
		return true, "Undone.", effectFor("update", copyPiece(piece))
	end
	table.remove(room.undo)
	return false, "Nothing to undo.", nil
end

return Placement
