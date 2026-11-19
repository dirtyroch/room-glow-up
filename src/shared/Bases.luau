--!strict
-- Plot layout and the three round shells.
-- A small room, a gingerbread house (wall and roof grids), and a tree with hooks.
-- Numbers only, so tests can check the grid without a place file.

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

local Config = sibling("Config")

local Bases = {}

Bases.Columns = 5
Bases.Spacing = 72
Bases.OriginX = -144
Bases.OriginZ = 40

export type Grid = { x: number, z: number }
export type Hook = { x: number, y: number, z: number }
export type Pivot = { x: number, y: number, z: number, yaw: number }

local Grids = {
	room = {
		floor = { x = 6, z = 6 } :: Grid,
		wall = { x = 6, z = 3 } :: Grid,
	},
	gingerbread = {
		wall = { x = 8, z = 5 } :: Grid,
		roof = { x = 8, z = 4 } :: Grid,
	},
}

Bases.HookCount = 12

Bases.Camera = {
	room = { back = 36, up = 24, look = 5 },
	gingerbread = { back = 52, up = 28, look = 12 },
	tree = { back = 34, up = 16, look = 8 },
}

-- Shell colors. These are world fills, not text, so they are separate from the UI palette.
Bases.Shell = {
	floorA = { 255, 246, 234 },
	floorB = { 255, 232, 206 },
	wallA = { 255, 250, 246 },
	wallB = { 255, 214, 206 },
	trim = { 255, 186, 173 },
	gingerA = { 214, 156, 108 },
	gingerB = { 186, 124, 86 },
	icingA = { 255, 252, 248 },
	icingB = { 255, 214, 206 },
	roofA = { 255, 246, 234 },
	roofB = { 255, 226, 156 },
	pine = { 146, 186, 164 },
	pineDark = { 116, 160, 140 },
	trunk = { 168, 124, 90 },
	hook = { 255, 214, 140 },
}

local hookCache: { Hook }? = nil

function Bases.worldCell(): number
	return Config.Cell * Config.ItemScale
end

function Bases.grid(roundType: string, surface: string): Grid?
	local pack = (Grids :: any)[roundType]
	if type(pack) ~= "table" then
		return nil
	end
	local grid = pack[surface]
	if type(grid) ~= "table" then
		return nil
	end
	return grid
end

function Bases.allows(roundType: string, surface: string): boolean
	if surface == "hook" then
		return roundType == "tree"
	end
	return Bases.grid(roundType, surface) ~= nil
end

function Bases.isIndex(n: number): boolean
	if type(n) ~= "number" then
		return false
	end
	if n ~= n then
		return false
	end
	if n < 0 or n > 64 then
		return false
	end
	return n % 1 == 0
end

function Bases.plotOrigin(index: number): (number, number, number)
	local col = (index - 1) % Bases.Columns
	local row = math.floor((index - 1) / Bases.Columns)
	local x = Bases.OriginX + col * Bases.Spacing
	local z = Bases.OriginZ + row * Bases.Spacing
	return x, 0, z
end

function Bases.hooks(): { Hook }
	if hookCache then
		return hookCache
	end
	local list: { Hook } = {}
	for i = 0, Bases.HookCount - 1 do
		local layer = math.floor(i / 4)
		local step = i % 4
		local angle = step * (math.pi / 2) + layer * 0.55
		local radius = 4.6 - layer * 1.15
		local y = 4.4 + layer * 2.7
		list[i + 1] = {
			x = math.cos(angle) * radius,
			y = y,
			z = math.sin(angle) * radius,
		}
	end
	hookCache = list
	return list
end

function Bases.nearestHook(lx: number, ly: number, lz: number): number?
	local best: number? = nil
	local bestD = 2.5 * 2.5
	for index, hook in ipairs(Bases.hooks()) do
		local dx = lx - hook.x
		local dy = ly - hook.y
		local dz = lz - hook.z
		local dist = dx * dx + dy * dy + dz * dz
		if dist <= bestD then
			bestD = dist
			best = index
		end
	end
	return best
end

function Bases.camera(roundType: string, index: number): (number, number, number, number, number, number)
	local ox, oy, oz = Bases.plotOrigin(index)
	local rig = Bases.Camera[roundType] or Bases.Camera.room
	return ox, oy + rig.up, oz + rig.back, ox, oy + rig.look, oz
end

local function cell(): number
	return Bases.worldCell()
end

function Bases.tileCenter(roundType: string, surface: string, x: number, z: number): (number?, number?, number?)
	local unit = cell()
	if surface == "hook" then
		local hook = Bases.hooks()[x]
		if not hook or z ~= 0 then
			return nil, nil, nil
		end
		return hook.x, hook.y, hook.z
	end
	local grid = Bases.grid(roundType, surface)
	if not grid then
		return nil, nil, nil
	end
	if x < 0 or z < 0 or x >= grid.x or z >= grid.z then
		return nil, nil, nil
	end
	if surface == "floor" then
		local lx = (-grid.x / 2 + x + 0.5) * unit
		local lz = (-grid.z / 2 + z + 0.5) * unit
		return lx, 0.5, lz
	end
	if surface == "wall" then
		local planeZ = Bases.wallPlane(roundType)
		local lx = (-grid.x / 2 + x + 0.5) * unit
		local ly = 1 + (z + 0.5) * unit
		return lx, ly, planeZ
	end
	-- Roof pads step up toward the back of the house.
	local wall = Bases.grid(roundType, "wall")
	local wallRows = if wall then wall.z else 4
	local frontZ = grid.z / 2 * unit
	local lx = (-grid.x / 2 + x + 0.5) * unit
	local lz = frontZ - (z + 0.5) * unit
	local ly = 1 + wallRows * unit + 0.35 + z * unit * 0.38
	return lx, ly, lz
end

function Bases.wallPlane(roundType: string): number
	local unit = cell()
	if roundType == "room" then
		local floor = Bases.grid("room", "floor")
		local depth = if floor then floor.z else 6
		return -depth / 2 * unit - 0.3
	end
	local roof = Bases.grid("gingerbread", "roof")
	local depth = if roof then roof.z else 4
	return depth / 2 * unit
end

local function turned(w: number, d: number, rot: number): (number, number)
	if rot % 2 == 1 then
		return d, w
	end
	return w, d
end

function Bases.fits(roundType: string, surface: string, x: number, z: number, w: number, d: number, rot: number): boolean
	if surface == "hook" then
		return z == 0 and x >= 1 and x <= Bases.HookCount and rot >= 0 and rot <= 3
	end
	local grid = Bases.grid(roundType, surface)
	if not grid then
		return false
	end
	local aw, ad = turned(w, d, rot)
	if x < 0 or z < 0 then
		return false
	end
	if x + aw > grid.x or z + ad > grid.z then
		return false
	end
	return true
end

-- Center of a placed prop, in plot-local studs, plus a yaw in radians.
function Bases.pivot(
	roundType: string,
	surface: string,
	x: number,
	z: number,
	rot: number,
	w: number,
	d: number,
	h: number
): Pivot?
	local unit = cell()
	if surface == "hook" then
		local hx, hy, hz = Bases.tileCenter("tree", "hook", x, 0)
		if hx == nil or hy == nil or hz == nil then
			return nil
		end
		return { x = hx, y = hy, z = hz, yaw = rot * math.pi / 2 }
	end
	local grid = Bases.grid(roundType, surface)
	if not grid then
		return nil
	end
	local aw, ad = turned(w, d, rot)
	if surface == "floor" then
		return {
			x = (-grid.x / 2 + x + aw / 2) * unit,
			y = 1 + (h * unit) / 2,
			z = (-grid.z / 2 + z + ad / 2) * unit,
			yaw = rot * math.pi / 2,
		}
	end
	if surface == "wall" then
		local thick = math.max(0.4, h * unit)
		local outward = if roundType == "room" then thick / 2 else -thick / 2
		return {
			x = (-grid.x / 2 + x + aw / 2) * unit,
			y = 1 + (z + ad / 2) * unit,
			z = Bases.wallPlane(roundType) + outward,
			yaw = 0,
		}
	end
	local wall = Bases.grid(roundType, "wall")
	local wallRows = if wall then wall.z else 4
	local frontZ = grid.z / 2 * unit
	return {
		x = (-grid.x / 2 + x + aw / 2) * unit,
		y = 1 + wallRows * unit + 0.7 + z * unit * 0.38 + (h * unit) / 2,
		z = frontZ - (z + ad / 2) * unit,
		yaw = rot * math.pi / 2,
	}
end

return Bases
