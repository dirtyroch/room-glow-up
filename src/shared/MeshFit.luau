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

function MeshFit.ids(): { string }
	local out: { string } = {}
	for id in pairs(Meshes.Items) do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

return MeshFit
