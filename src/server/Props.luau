--!strict
-- Chunky shells and props. Parts stay anchored so ten rooms do not simulate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared:WaitForChild("UIKit") :: ModuleScript) :: any
local Bases = require(Shared:WaitForChild("Bases") :: ModuleScript) :: any

local Props = {}

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function asMaterial(name: string): Enum.Material?
	local material = (Enum.Material :: any)[name]
	if typeof(material) ~= "EnumItem" then
		return nil
	end
	return material :: Enum.Material
end

local function named(colorName: string): Color3
	local channels = UIKit.color(colorName)
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

local function shell(name: string): Color3
	return rgb(Bases.Shell[name])
end

type Options = {
	collide: boolean?,
	query: boolean?,
	transparency: number?,
	shadow: boolean?,
	surface: string?,
	x: number?,
	z: number?,
}

local function part(parent: Instance, name: string, shape: string, size: Vector3, cf: CFrame, color: Color3, opts: Options): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.Material = Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.CanTouch = false
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.CanCollide = opts.collide == true
	piece.CanQuery = opts.query ~= false
	piece.Transparency = opts.transparency or 0
	piece.CastShadow = opts.shadow ~= false
	if shape == "Ball" then
		piece.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		piece.Shape = Enum.PartType.Cylinder
	elseif shape == "Wedge" then
		piece.Shape = Enum.PartType.Wedge
	end
	piece:SetAttribute("ShowT", piece.Transparency)
	piece:SetAttribute("ShowQ", piece.CanQuery)
	piece:SetAttribute("ShowC", piece.CanCollide)
	if opts.surface then
		piece:SetAttribute("Surface", opts.surface)
		piece:SetAttribute("CellX", opts.x or 0)
		piece:SetAttribute("CellZ", opts.z or 0)
	end
	piece.Parent = parent
	return piece
end

-- The plot model is the parent of each shell. Its PrimaryPart is the pivot.
local function originOf(shellModel: Model): CFrame
	local plot = shellModel.Parent
	if plot and plot:IsA("Model") and plot.PrimaryPart then
		return plot.PrimaryPart.CFrame
	end
	return CFrame.new()
end

function Props.room(shellModel: Model)
	local pivot = originOf(shellModel)
	local unit = Bases.worldCell()
	local floor = Bases.grid("room", "floor")
	local wall = Bases.grid("room", "wall")
	if not floor or not wall then
		return
	end
	for x = 0, floor.x - 1 do
		for z = 0, floor.z - 1 do
			local lx, ly, lz = Bases.tileCenter("room", "floor", x, z)
			if lx and ly and lz then
				local tint = if (x + z) % 2 == 0 then "floorA" else "floorB"
				part(shellModel, "Cell", "Block", Vector3.new(unit, 1, unit), pivot * CFrame.new(lx, ly, lz), shell(tint), {
					collide = true,
					query = true,
					shadow = true,
					surface = "floor",
					x = x,
					z = z,
				})
			end
		end
	end
	for x = 0, wall.x - 1 do
		for row = 0, wall.z - 1 do
			local lx, ly, lz = Bases.tileCenter("room", "wall", x, row)
			if lx and ly and lz then
				local tint = if (x + row) % 2 == 0 then "wallA" else "wallB"
				part(shellModel, "Cell", "Block", Vector3.new(unit, unit, 0.55), pivot * CFrame.new(lx, ly, lz), shell(tint), {
					collide = false,
					query = true,
					shadow = false,
					surface = "wall",
					x = x,
					z = row,
				})
			end
		end
	end
	local depth = floor.z * unit
	local width = floor.x * unit
	local height = wall.z * unit
	part(shellModel, "Side", "Block", Vector3.new(0.7, height, depth), pivot * CFrame.new(-width / 2 - 0.2, 1 + height / 2, 0), shell("floorA"), {
		collide = true,
		query = false,
		shadow = true,
	})
	part(shellModel, "Side", "Block", Vector3.new(0.7, height, depth), pivot * CFrame.new(width / 2 + 0.2, 1 + height / 2, 0), shell("floorA"), {
		collide = true,
		query = false,
		shadow = true,
	})
	part(shellModel, "Trim", "Block", Vector3.new(width, 0.4, 0.6), pivot * CFrame.new(0, 1.2, depth / 2 + 0.2), shell("trim"), {
		collide = false,
		query = false,
		shadow = false,
	})
end

function Props.gingerbread(shellModel: Model)
	local pivot = originOf(shellModel)
	local unit = Bases.worldCell()
	local wall = Bases.grid("gingerbread", "wall")
	local roof = Bases.grid("gingerbread", "roof")
	if not wall or not roof then
		return
	end
	local width = wall.x * unit
	local depth = roof.z * unit
	local height = wall.z * unit
	part(shellModel, "Base", "Block", Vector3.new(width + 1.2, 1, depth + 1.2), pivot * CFrame.new(0, 0.5, 0), shell("gingerA"), {
		collide = true,
		query = false,
		shadow = true,
	})
	part(shellModel, "Side", "Block", Vector3.new(0.8, height, depth), pivot * CFrame.new(-width / 2, 1 + height / 2, 0), shell("gingerB"), {
		collide = true,
		query = false,
		shadow = true,
	})
	part(shellModel, "Side", "Block", Vector3.new(0.8, height, depth), pivot * CFrame.new(width / 2, 1 + height / 2, 0), shell("gingerB"), {
		collide = true,
		query = false,
		shadow = true,
	})
	part(
		shellModel,
		"Back",
		"Block",
		Vector3.new(width, height, 0.8),
		pivot * CFrame.new(0, 1 + height / 2, -depth / 2),
		shell("gingerB"),
		{ collide = true, query = false, shadow = true }
	)
	for x = 0, wall.x - 1 do
		for row = 0, wall.z - 1 do
			local lx, ly, lz = Bases.tileCenter("gingerbread", "wall", x, row)
			if lx and ly and lz then
				local tint = if (x + row) % 2 == 0 then "icingA" else "icingB"
				part(shellModel, "Cell", "Block", Vector3.new(unit, unit, 0.5), pivot * CFrame.new(lx, ly, lz), shell(tint), {
					collide = false,
					query = true,
					shadow = false,
					surface = "wall",
					x = x,
					z = row,
				})
			end
		end
	end
	for x = 0, roof.x - 1 do
		for z = 0, roof.z - 1 do
			local lx, ly, lz = Bases.tileCenter("gingerbread", "roof", x, z)
			if lx and ly and lz then
				local tint = if (x + z) % 2 == 0 then "roofA" else "roofB"
				part(shellModel, "Cell", "Block", Vector3.new(unit - 0.12, 0.45, unit - 0.12), pivot * CFrame.new(lx, ly, lz), shell(tint), {
					collide = false,
					query = true,
					shadow = false,
					surface = "roof",
					x = x,
					z = z,
				})
			end
		end
	end
end

function Props.tree(shellModel: Model)
	local pivot = originOf(shellModel)
	part(shellModel, "Trunk", "Cylinder", Vector3.new(3.2, 1.5, 1.5), pivot * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)), shell("trunk"), {
		collide = true,
		query = false,
		shadow = true,
	})
	local foliage = {
		{ y = 4.6, s = 7.2, tint = "pine" },
		{ y = 7.2, s = 5.6, tint = "pineDark" },
		{ y = 9.6, s = 4.1, tint = "pine" },
	}
	for index, blob in ipairs(foliage) do
		part(shellModel, "Foliage" .. tostring(index), "Ball", Vector3.new(blob.s, blob.s, blob.s), pivot * CFrame.new(0, blob.y, 0), shell(blob.tint), {
			collide = false,
			query = false,
			shadow = true,
		})
	end
	part(shellModel, "Top", "Ball", Vector3.new(1.6, 1.6, 1.6), pivot * CFrame.new(0, 12.1, 0), shell("hook"), {
		collide = false,
		query = false,
		shadow = false,
	})
	for index, hook in ipairs(Bases.hooks()) do
		part(shellModel, "Hook" .. tostring(index), "Ball", Vector3.new(2.3, 2.3, 2.3), pivot * CFrame.new(hook.x, hook.y, hook.z), shell("hook"), {
			collide = false,
			query = true,
			shadow = false,
			surface = "hook",
			x = index,
			z = 0,
		})
	end
end

local function add(model: Model, cf: CFrame, name: string, shape: string, size: Vector3, offset: Vector3, color: Color3, tinted: boolean)
	local localCF = CFrame.new(offset)
	if shape == "Cylinder" then
		localCF = localCF * CFrame.Angles(0, 0, math.rad(90))
	end
	local piece = part(model, name, shape, size, cf * localCF, color, {
		collide = false,
		query = true,
		shadow = false,
	})
	piece:SetAttribute("Tint", tinted)
end

function Props.prop(plotPivot: CFrame, item: any, piece: any, roundType: string): Model
	local model = Instance.new("Model")
	model.Name = "P" .. tostring(piece.id)
	model:SetAttribute("PlacementId", piece.id)
	model:SetAttribute("ItemId", item.id)
	model:SetAttribute("PlacedAt", piece.placedAt or 0)
	model:SetAttribute("Color", piece.color)
	local spot = Bases.pivot(roundType, item.surface, piece.x, piece.z, piece.rot, item.w, item.d, item.h)
	local unit = Bases.worldCell()
	local cf = plotPivot
	if spot then
		local spin = CFrame.Angles(0, spot.yaw, 0)
		if item.surface == "wall" then
			spin = CFrame.Angles(0, 0, -piece.rot * math.pi / 2)
		end
		cf = plotPivot * CFrame.new(spot.x, spot.y, spot.z) * spin
	end
	local sx = item.w * unit
	local sy = math.max(0.35, item.h * unit)
	local sz = item.d * unit
	if item.surface == "wall" then
		sx = item.w * unit
		sy = item.d * unit
		sz = math.max(0.35, item.h * unit)
	elseif item.surface == "hook" then
		local ornament = math.max(1.5, item.h * unit)
		sx, sy, sz = ornament, ornament, ornament
	end
	local main = named(piece.color)
	local trim = named("ink")
	local cream = named("cream")
	local root = part(model, "Root", "Block", Vector3.new(0.2, 0.2, 0.2), cf, main, {
		collide = false,
		query = false,
		transparency = 1,
		shadow = false,
	})
	model.PrimaryPart = root

	local shape = item.shape
	if shape == "sofa" or shape == "piano" then
		add(model, cf, "Seat", "Block", Vector3.new(sx * 0.92, sy * 0.42, sz * 0.78), Vector3.new(0, -sy * 0.16, 0), main, true)
		add(model, cf, "Back", "Block", Vector3.new(sx * 0.92, sy * 0.62, sz * 0.22), Vector3.new(0, sy * 0.12, -sz * 0.28), main, true)
		if shape == "sofa" then
			add(model, cf, "Arm", "Block", Vector3.new(sx * 0.14, sy * 0.38, sz * 0.78), Vector3.new(-sx * 0.4, 0, 0), trim, false)
			add(model, cf, "Arm", "Block", Vector3.new(sx * 0.14, sy * 0.38, sz * 0.78), Vector3.new(sx * 0.4, 0, 0), trim, false)
		end
	elseif shape == "chair" or shape == "recliner" then
		add(model, cf, "Seat", "Block", Vector3.new(sx * 0.82, sy * 0.28, sz * 0.72), Vector3.new(0, -sy * 0.12, 0), main, true)
		add(model, cf, "Back", "Block", Vector3.new(sx * 0.82, sy * 0.62, sz * 0.16), Vector3.new(0, sy * 0.16, -sz * 0.28), main, true)
		if shape == "recliner" then
			add(model, cf, "Foot", "Block", Vector3.new(sx * 0.7, sy * 0.12, sz * 0.42), Vector3.new(0, -sy * 0.28, sz * 0.46), main, true)
			add(model, cf, "Remote", "Block", Vector3.new(sx * 0.18, sy * 0.08, sz * 0.28), Vector3.new(sx * 0.28, sy * 0.08, sz * 0.05), trim, false)
			add(model, cf, "Glasses", "Block", Vector3.new(sx * 0.42, sy * 0.06, sz * 0.1), Vector3.new(0, sy * 0.42, sz * 0.05), cream, false)
		end
	elseif shape == "table" then
		add(model, cf, "Top", "Block", Vector3.new(sx * 0.92, math.max(0.35, sy * 0.22), sz * 0.92), Vector3.new(0, sy * 0.28, 0), main, true)
		add(model, cf, "Leg", "Block", Vector3.new(sx * 0.22, sy * 0.7, sz * 0.22), Vector3.new(0, -sy * 0.1, 0), trim, false)
	elseif shape == "lamp" then
		add(model, cf, "Stem", "Cylinder", Vector3.new(sy * 0.7, math.min(sx, sz) * 0.16, math.min(sx, sz) * 0.16), Vector3.new(0, -sy * 0.05, 0), trim, false)
		add(model, cf, "Shade", "Block", Vector3.new(sx * 0.7, sy * 0.32, sz * 0.7), Vector3.new(0, sy * 0.28, 0), main, true)
	elseif shape == "shelf" then
		add(model, cf, "Box", "Block", Vector3.new(sx * 0.9, sy * 0.86, sz * 0.7), Vector3.zero, main, true)
		add(model, cf, "Plank", "Block", Vector3.new(sx * 0.84, sy * 0.08, sz * 0.62), Vector3.new(0, sy * 0.12, 0), cream, false)
	elseif shape == "plant" then
		add(model, cf, "Pot", "Cylinder", Vector3.new(sy * 0.32, sx * 0.55, sz * 0.55), Vector3.new(0, -sy * 0.28, 0), cream, false)
		add(model, cf, "Leaf", "Ball", Vector3.new(sx * 0.85, sy * 0.6, sz * 0.85), Vector3.new(0, sy * 0.12, 0), main, true)
	elseif shape == "ball" then
		add(model, cf, "Body", "Ball", Vector3.new(sx * 0.86, sy * 0.86, sz * 0.86), Vector3.zero, main, true)
	elseif shape == "cylinder" or shape == "cane" then
		local height = if item.surface == "wall" then sy * 0.9 else sy
		local diam = math.min(sx, sz) * (if shape == "cane" then 0.28 else 0.7)
		add(model, cf, "Body", "Cylinder", Vector3.new(height, diam, diam), Vector3.zero, main, true)
	elseif shape == "wedge" then
		add(model, cf, "Body", "Wedge", Vector3.new(sx * 0.9, sy, sz * 0.9), Vector3.zero, main, true)
	elseif shape == "star" then
		add(model, cf, "Across", "Block", Vector3.new(sx * 0.95, sy * 0.22, sz * 0.22), Vector3.zero, main, true)
		add(model, cf, "Up", "Block", Vector3.new(sx * 0.22, sy * 0.95, sz * 0.22), Vector3.zero, main, true)
		add(model, cf, "Core", "Ball", Vector3.new(sx * 0.38, sy * 0.38, sz * 0.38), Vector3.zero, cream, false)
	elseif shape == "bell" then
		add(model, cf, "Cup", "Ball", Vector3.new(sx * 0.8, sy * 0.75, sz * 0.8), Vector3.new(0, -sy * 0.05, 0), main, true)
		add(model, cf, "Cap", "Block", Vector3.new(sx * 0.3, sy * 0.2, sz * 0.3), Vector3.new(0, sy * 0.32, 0), trim, false)
	elseif shape == "frame" then
		add(model, cf, "Back", "Block", Vector3.new(sx * 0.96, sy * 0.96, math.max(0.2, sz)), Vector3.zero, trim, false)
		add(model, cf, "Face", "Block", Vector3.new(sx * 0.7, sy * 0.7, math.max(0.16, sz * 0.7)), Vector3.new(0, 0, sz * 0.2), main, true)
	else
		add(model, cf, "Body", "Block", Vector3.new(sx * 0.9, math.max(sy, 0.3), sz * 0.9), Vector3.zero, main, true)
	end
	local materialName = piece.material
	if type(materialName) == "string" then
		local material = asMaterial(materialName)
		if material then
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") and child:GetAttribute("Tint") == true then
					child.Material = material
				end
			end
			model:SetAttribute("Material", materialName)
		end
	end
	return model
end

function Props.paintShell(plot: Instance, surface: string, colorName: string)
	local ok, color = pcall(named, colorName)
	if not ok then
		return
	end
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("Surface") == surface then
			child.Color = color
		end
	end
end

function Props.recolor(model: Model, colorName: string)
	local main = named(colorName)
	model:SetAttribute("Color", colorName)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("Tint") == true then
			child.Color = main
		end
	end
end

function Props.finish(model: Model, materialName: string)
	local material = asMaterial(materialName)
	if not material then
		return
	end
	model:SetAttribute("Material", materialName)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("Tint") == true then
			child.Material = material
		end
	end
end

return Props
