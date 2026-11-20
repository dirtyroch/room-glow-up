--!strict
-- Pure placement math for the furniture meshes in Meshes.luau. No engine types,
-- so the Lune tests can check it. The prop root CFrame is the center of the
-- item box (Bases.pivot), so the floor is at -sy / 2.

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

local Meshes = sibling("Meshes")

local MeshFit = {}

-- Pastel UI colors are strong; furniture fabric reads more real a little lighter.
MeshFit.Soften = 0.15

function MeshFit.entry(itemId: string): any?
	if type(itemId) ~= "string" then
		return nil
	end
	return Meshes.Items[itemId]
end

function MeshFit.uploaded(entry: any): boolean
	if type(entry) ~= "table" or type(entry.ids) ~= "table" then
		return false
	end
	local model = entry.ids.model
	local color = entry.ids.color
	return type(model) == "number" and model > 0 and type(color) == "number" and color > 0
end

-- Returns the MeshPart size and its offset from the prop root, both in studs.
function MeshFit.fit(entry: any, sy: number, unit: number): (number, number, number, number, number, number)
	local k = unit / Meshes.RefCell
	local size = entry.size
	local center = entry.center
	return size[1] * k, size[2] * k, size[3] * k, center[1] * k, center[2] * k - sy / 2, center[3] * k
end

-- Wall items (Meshes entry mount = "wall") hang on the wall face. Their prop
-- box is centered on the root with its back on the wall plane (Bases.pivot);
-- the wall cell's face is WallFace studs in front of that plane. standoff lifts
-- the mesh off the face (clears the wainscot rail). Returns size and offset.
MeshFit.WallFace = 0.275

function MeshFit.isWall(entry: any): boolean
	return type(entry) == "table" and entry.mount == "wall"
end

function MeshFit.fitWall(entry: any, unit: number, thick: number, standoff: number): (number, number, number, number, number, number)
	local k = unit / Meshes.RefCell
	local size = entry.size
	local w, h, d = size[1] * k, size[2] * k, size[3] * k
	local oz = -thick / 2 + MeshFit.WallFace + standoff + d / 2
	return w, h, d, entry.center[1] * k, 0, oz
end

-- Bulb position relative to the mesh center (MeshPart pivot = bounds center).
function MeshFit.bulb(entry: any, unit: number): (number, number, number)
	local k = unit / Meshes.RefCell
	local at = entry.light.at
	local c = entry.center
	return (at[1] - c[1]) * k, (at[2] - c[2]) * k, (at[3] - c[3]) * k
end

-- Light position from the prop root.
function MeshFit.light(entry: any, sy: number, unit: number): (number, number, number)
	local k = unit / Meshes.RefCell
	local at = entry.light.at
	return at[1] * k, at[2] * k - sy / 2, at[3] * k
end

function MeshFit.tint(r: number, g: number, b: number): (number, number, number)
	local s = MeshFit.Soften
	return r + (1 - r) * s, g + (1 - g) * s, b + (1 - b) * s
end

-- Designer Tools Finish on a mesh: the tint moves toward a material look and,
-- once uploaded, the roughness/metalness maps swap to the variant (ids keys).
-- Fabric is the baked look. Mirrors tools/meshes/palette.py FINISHES.
export type Finish = { target: { number }?, mix: number, rough: string?, metal: string?, transparency: number }

MeshFit.Finishes = {
	Fabric = { target = nil, mix = 0, rough = nil, metal = nil, transparency = 0 },
	-- Strong enough to read from the build camera, not only up close.
	Wood = { target = { 0.55, 0.37, 0.24 }, mix = 0.62, rough = "satinR", metal = nil, transparency = 0 },
	Metal = { target = { 0.86, 0.88, 0.92 }, mix = 0.5, rough = "metalR", metal = "metalM", transparency = 0 },
	Glass = { target = { 0.94, 0.98, 1 }, mix = 0.55, rough = "glossR", metal = nil, transparency = 0 },
	Slate = { target = { 0.36, 0.39, 0.44 }, mix = 0.68, rough = "matteR", metal = nil, transparency = 0 },
} :: { [string]: Finish }

function MeshFit.finish(name: string?): Finish
	return MeshFit.Finishes[name or "Fabric"] or MeshFit.Finishes.Fabric
end

-- SurfaceAppearance.Color for a placed mesh: soften, then pull toward the finish.
function MeshFit.finishTint(r: number, g: number, b: number, name: string?): (number, number, number)
	local tr, tg, tb = MeshFit.tint(r, g, b)
	local f = MeshFit.finish(name)
	local target = f.target
	if target == nil or f.mix <= 0 then
		return tr, tg, tb
	end
	local k = f.mix
	return tr + (target[1] - tr) * k, tg + (target[2] - tg) * k, tb + (target[3] - tb) * k
end

function MeshFit.shell(key: string): any?
	return (Meshes.Shell or {})[key]
end

function MeshFit.surface(key: string): any?
	return (Meshes.Surfaces or {})[key]
end

function MeshFit.refCell(): number
	return Meshes.RefCell
end

function MeshFit.shellIds(): { string }
	local out: { string } = {}
	for id in pairs(Meshes.Shell or {}) do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

function MeshFit.ids(): { string }
	local out: { string } = {}
	for id in pairs(Meshes.Items) do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

return MeshFit
