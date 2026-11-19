--!strict
-- Chunky shells and props. Parts stay anchored so ten rooms do not simulate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared:WaitForChild("UIKit") :: ModuleScript) :: any
local Bases = require(Shared:WaitForChild("Bases") :: ModuleScript) :: any
local Look = require(Shared:WaitForChild("Look") :: ModuleScript) :: any

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
	material: string?,
	shell: string?,
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
	if opts.material then
		local material = asMaterial(opts.material)
		if material then
			piece.Material = material
		end
	end
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
	if opts.shell then
		piece:SetAttribute("Shell", opts.shell)
	end
	piece.Parent = parent
	return piece
end

local function packColor(family: string, name: string): Color3
	local pack = Look.pack(family)
	if name == "floorA" then
		return rgb(pack.floorA)
	elseif name == "floorB" then
		return rgb(pack.floorB)
	elseif name == "wallA" then
		return rgb(pack.wallA)
	elseif name == "wallB" then
		return rgb(pack.wallB)
	end
	return shell(name)
end

local function wash(host: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Name = "SoftLight"
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light:SetAttribute("SoftB", brightness)
	light:SetAttribute("Kind", "wash")
	light.Parent = host
end

local function keyLight(host: BasePart, color: Color3, brightness: number, range: number, face: Enum.NormalId)
	local light = Instance.new("SurfaceLight")
	light.Name = "SoftLight"
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Angle = 80
	light.Face = face
	light.Shadows = false
	light:SetAttribute("SoftB", brightness)
	light:SetAttribute("Kind", "key")
	light.Parent = host
end

local function decor(parent: Instance, name: string, shape: string, size: Vector3, cf: CFrame, color: Color3, material: string?, transparency: number?): Part
	return part(parent, name, shape, size, cf, color, {
		collide = false,
		query = false,
		shadow = false,
		material = material,
		transparency = transparency,
	})
end

-- Trim, a back window, and a soft wash. Cells stay the placement targets.
local function dressRoom(shellModel: Model, pivot: CFrame, width: number, depth: number, height: number)
	local planeZ = Bases.wallPlane("room")
	local boardH = 0.72
	local boardY = 1 + boardH / 2
	decor(shellModel, "Baseboard", "Block", Vector3.new(width - 0.3, boardH, 0.4), pivot * CFrame.new(0, boardY, planeZ + 0.5), shell("trim"), "Wood", nil)
	decor(
		shellModel,
		"Baseboard",
		"Block",
		Vector3.new(0.4, boardH, depth - 0.4),
		pivot * CFrame.new(-width / 2 + 0.35, boardY, 0),
		shell("trim"),
		"Wood",
		nil
	)
	decor(
		shellModel,
		"Baseboard",
		"Block",
		Vector3.new(0.4, boardH, depth - 0.4),
		pivot * CFrame.new(width / 2 - 0.35, boardY, 0),
		shell("trim"),
		"Wood",
		nil
	)
	local crownY = 1 + height - 0.35
	decor(shellModel, "Crown", "Block", Vector3.new(width, 0.55, 0.55), pivot * CFrame.new(0, crownY, planeZ + 0.35), shell("floorA"), "Wood", nil)
	local winW = math.clamp(width * 0.36, 4, 9)
	local winH = math.clamp(height * 0.42, 3.5, 7)
	local winY = 1 + height * 0.58
	local winZ = planeZ + 0.62
	decor(shellModel, "WindowFrame", "Block", Vector3.new(winW + 0.7, winH + 0.7, 0.28), pivot * CFrame.new(0, winY, winZ), shell("trim"), "Wood", nil)
	local glass = decor(
		shellModel,
		"Window",
		"Block",
		Vector3.new(winW, winH, 0.18),
		pivot * CFrame.new(0, winY, winZ + 0.12),
		Color3.fromRGB(226, 240, 248),
		"Glass",
		0.35
	)
	decor(shellModel, "Sill", "Block", Vector3.new(winW + 1.1, 0.28, 0.7), pivot * CFrame.new(0, winY - winH / 2 - 0.1, winZ + 0.2), shell("trim"), "Wood", nil)
	decor(shellModel, "Mullion", "Block", Vector3.new(0.18, winH, 0.16), pivot * CFrame.new(0, winY, winZ + 0.2), shell("trim"), "Wood", nil)
	decor(shellModel, "Rail", "Block", Vector3.new(winW, 0.18, 0.16), pivot * CFrame.new(0, winY, winZ + 0.2), shell("trim"), "Wood", nil)
	wash(glass, Color3.fromRGB(255, 236, 210), 0.25, 10)
	keyLight(glass, Color3.fromRGB(255, 232, 200), 1.1, 20, Enum.NormalId.Back)
end

local function dressGinger(shellModel: Model, pivot: CFrame, width: number, _depth: number, height: number)
	local planeZ = Bases.wallPlane("gingerbread")
	local gable = Bases.gableMetrics("gingerbread")
	local eaveY = gable.eaveY
	local rise = gable.rise
	local frosting = Color3.fromRGB(236, 246, 255)
	local caneRed = Color3.fromRGB(230, 40, 70)
	local dropColors = {
		Color3.fromRGB(230, 40, 70),
		Color3.fromRGB(40, 180, 90),
		Color3.fromRGB(255, 120, 170),
		Color3.fromRGB(255, 252, 248),
		Color3.fromRGB(255, 200, 60),
	}

	-- Two frosted windows flanking the door.
	for _, side in ipairs({ -1, 1 }) do
		local wx = side * width * 0.28
		local winY = 1 + height * 0.58
		local winZ = planeZ + 0.55
		local glass = decor(
			shellModel,
			"Window",
			"Block",
			Vector3.new(3.6, 3.8, 0.2),
			pivot * CFrame.new(wx, winY, winZ + 0.12),
			frosting,
			"Glass",
			0.22
		)
		decor(
			shellModel,
			"WindowFrame",
			"Block",
			Vector3.new(4.3, 4.5, 0.28),
			pivot * CFrame.new(wx, winY, winZ),
			shell("icingA"),
			"SmoothPlastic",
			nil
		)
		decor(
			shellModel,
			"Mullion",
			"Block",
			Vector3.new(0.18, 3.8, 0.16),
			pivot * CFrame.new(wx, winY, winZ + 0.2),
			shell("icingA"),
			"SmoothPlastic",
			nil
		)
		decor(
			shellModel,
			"Rail",
			"Block",
			Vector3.new(3.6, 0.18, 0.16),
			pivot * CFrame.new(wx, winY, winZ + 0.2),
			shell("icingA"),
			"SmoothPlastic",
			nil
		)
		decor(
			shellModel,
			"Sill",
			"Block",
			Vector3.new(4.6, 0.32, 0.7),
			pivot * CFrame.new(wx, winY - 2.15, winZ + 0.22),
			shell("icingA"),
			"SmoothPlastic",
			nil
		)
		decor(
			shellModel,
			"FrostCap",
			"Block",
			Vector3.new(4.7, 0.45, 0.55),
			pivot * CFrame.new(wx, winY + 2.35, winZ + 0.12),
			shell("icingA"),
			"SmoothPlastic",
			nil
		)
		if side < 0 then
			wash(glass, Color3.fromRGB(255, 236, 210), 0.22, 10)
			keyLight(glass, Color3.fromRGB(255, 228, 190), 1.05, 18, Enum.NormalId.Back)
		end
	end

	-- Center door with a candy-cane frame and hooked tops.
	local doorZ = planeZ + 0.48
	decor(shellModel, "Door", "Block", Vector3.new(3.4, 6.4, 0.35), pivot * CFrame.new(0, 4.3, doorZ), shell("gingerB"), "Wood", nil)
	decor(shellModel, "Knob", "Ball", Vector3.new(0.45, 0.45, 0.45), pivot * CFrame.new(1.15, 4.1, doorZ + 0.28), shell("hook"), "Metal", nil)
	local caneH = 7.2
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 2.15
		decor(
			shellModel,
			"Cane",
			"Cylinder",
			Vector3.new(caneH, 0.7, 0.7),
			pivot * CFrame.new(x, 1 + caneH / 2, doorZ + 0.15) * CFrame.Angles(0, 0, math.rad(90)),
			shell("icingA"),
			"SmoothPlastic",
			nil
		)
		decor(
			shellModel,
			"CaneStripe",
			"Cylinder",
			Vector3.new(caneH * 0.5, 0.78, 0.78),
			pivot * CFrame.new(x, 1 + caneH * 0.38, doorZ + 0.15) * CFrame.Angles(0, 0, math.rad(90)),
			caneRed,
			"SmoothPlastic",
			nil
		)
		local hookX = x - side * 0.7
		decor(
			shellModel,
			"CaneHook",
			"Cylinder",
			Vector3.new(1.7, 0.7, 0.7),
			pivot * CFrame.new(hookX, 1 + caneH - 0.1, doorZ + 0.15) * CFrame.Angles(0, math.rad(90), 0),
			shell("icingA"),
			"SmoothPlastic",
			nil
		)
		decor(
			shellModel,
			"CaneStripe",
			"Cylinder",
			Vector3.new(0.8, 0.78, 0.78),
			pivot * CFrame.new(hookX + side * 0.15, 1 + caneH - 0.1, doorZ + 0.15) * CFrame.Angles(0, math.rad(90), 0),
			caneRed,
			"SmoothPlastic",
			nil
		)
	end

	-- Icing rails along the front gable, with drips hanging off the eaves.
	local slope = math.atan2(rise, width / 2)
	local slopeLen = math.sqrt((width / 2) ^ 2 + rise ^ 2)
	for _, side in ipairs({ -1, 1 }) do
		local midX = side * width / 4
		local midY = eaveY + rise / 2
		decor(
			shellModel,
			"Eave",
			"Block",
			Vector3.new(slopeLen + 0.4, 0.55, 0.7),
			pivot * CFrame.new(midX, midY + 0.1, planeZ + 0.5) * CFrame.Angles(0, 0, -side * slope),
			shell("icingA"),
			"SmoothPlastic",
			nil
		)
		for index = 1, 3 do
			local t = index / 4
			local x = side * (width / 2) * (1 - t)
			local y = eaveY + rise * t - 0.15
			decor(
				shellModel,
				"Drip",
				"Wedge",
				Vector3.new(1.15, 1.6, 0.7),
				pivot * CFrame.new(x, y, planeZ + 0.55),
				shell("icingA"),
				"SmoothPlastic",
				nil
			)
		end
	end

	-- Gumdrop path leading to the door.
	for index = 1, 5 do
		local x = math.sin(index * 1.1) * 0.7
		local z = planeZ + 1.6 + index * 2.05
		decor(
			shellModel,
			"PathDrop",
			"Ball",
			Vector3.new(1.35, 1.05, 1.35),
			pivot * CFrame.new(x, 1.15, z),
			dropColors[index],
			"SmoothPlastic",
			nil
		)
	end

	decor(
		shellModel,
		"IcingBase",
		"Block",
		Vector3.new(5.2, 0.5, 1.1),
		pivot * CFrame.new(0, 1.3, planeZ + 0.9),
		shell("icingA"),
		"SmoothPlastic",
		nil
	)
	for _, side in ipairs({ -1, 1 }) do
		decor(
			shellModel,
			"IcingPost",
			"Block",
			Vector3.new(0.55, height, 0.55),
			pivot * CFrame.new(side * (width / 2 - 0.15), 1 + height / 2, planeZ + 0.5),
			shell("icingA"),
			"SmoothPlastic",
			nil
		)
	end
end

local function dressTree(shellModel: Model, pivot: CFrame)
	local skirt = decor(shellModel, "Skirt", "Cylinder", Vector3.new(0.45, 8.5, 8.5), pivot * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), shell("floorA"), "Fabric", nil)
	decor(shellModel, "Stand", "Cylinder", Vector3.new(0.8, 3.2, 3.2), pivot * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), shell("trunk"), "Wood", nil)
	local top = pivot * CFrame.new(0, 12.1, 0)
	decor(shellModel, "TopperA", "Block", Vector3.new(2.2, 0.28, 0.28), top, shell("hook"), "Neon", nil)
	decor(shellModel, "TopperB", "Block", Vector3.new(0.28, 2.2, 0.28), top, shell("hook"), "Neon", nil)
	decor(shellModel, "TopperC", "Block", Vector3.new(2.0, 0.28, 0.28), top * CFrame.Angles(0, 0, math.rad(45)), shell("hook"), "Neon", nil)
	decor(shellModel, "TopperD", "Block", Vector3.new(2.0, 0.28, 0.28), top * CFrame.Angles(0, 0, math.rad(-45)), shell("hook"), "Neon", nil)
	wash(skirt, Color3.fromRGB(255, 226, 170), 0.45, 10)
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
				local floorMat = if (x + z) % 3 == 0 then "Wood" elseif (x + z) % 3 == 1 then "WoodPlanks" else "Fabric"
				part(shellModel, "Cell", "Block", Vector3.new(unit, 1, unit), pivot * CFrame.new(lx, ly, lz), packColor("hearth", tint), {
					collide = true,
					query = true,
					shadow = true,
					surface = "floor",
					x = x,
					z = z,
					material = floorMat,
					shell = tint,
				})
			end
		end
	end
	for x = 0, wall.x - 1 do
		for row = 0, wall.z - 1 do
			local lx, ly, lz = Bases.tileCenter("room", "wall", x, row)
			if lx and ly and lz then
				local tint = if (x + row) % 2 == 0 then "wallA" else "wallB"
				part(shellModel, "Cell", "Block", Vector3.new(unit, unit, 0.55), pivot * CFrame.new(lx, ly, lz), packColor("hearth", tint), {
					collide = false,
					query = true,
					shadow = false,
					surface = "wall",
					x = x,
					z = row,
					shell = tint,
				})
			end
		end
	end
	local depth = floor.z * unit
	local width = floor.x * unit
	local height = wall.z * unit
	part(shellModel, "Side", "Block", Vector3.new(0.7, height, depth), pivot * CFrame.new(-width / 2 - 0.2, 1 + height / 2, 0), packColor("hearth", "wallA"), {
		collide = true,
		query = false,
		shadow = true,
		shell = "wallA",
	})
	part(shellModel, "Side", "Block", Vector3.new(0.7, height, depth), pivot * CFrame.new(width / 2 + 0.2, 1 + height / 2, 0), packColor("hearth", "wallA"), {
		collide = true,
		query = false,
		shadow = true,
		shell = "wallA",
	})
	part(shellModel, "Trim", "Block", Vector3.new(width, 0.4, 0.6), pivot * CFrame.new(0, 1.2, depth / 2 + 0.2), shell("trim"), {
		collide = false,
		query = false,
		shadow = false,
		material = "Wood",
	})
	dressRoom(shellModel, pivot, width, depth, height)
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
		material = "Brick",
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
				local tint = if (x + row) % 2 == 0 then "gingerA" else "gingerB"
				part(shellModel, "Cell", "Block", Vector3.new(unit, unit, 0.5), pivot * CFrame.new(lx, ly, lz), shell(tint), {
					collide = false,
					query = true,
					shadow = false,
					surface = "wall",
					x = x,
					z = row,
					shell = tint,
				})
			end
		end
	end
	local gable = Bases.gableMetrics("gingerbread")
	local rise = gable.rise
	local eaveY = gable.eaveY
	local ridgeY = gable.ridgeY
	local slope = math.atan2(rise, width / 2)
	local slopeLen = math.sqrt((width / 2) ^ 2 + rise ^ 2) + 1.4
	for x = 0, roof.x - 1 do
		for z = 0, roof.z - 1 do
			local lx, ly, lz = Bases.tileCenter("gingerbread", "roof", x, z)
			if lx and ly and lz then
				local tint = if (x + z) % 2 == 0 then "gingerB" else "icingA"
				local tilt = if lx < 0 then slope else -slope
				part(shellModel, "Cell", "Block", Vector3.new(unit + 0.06, 0.4, unit + 0.06), pivot * CFrame.new(lx, ly, lz) * CFrame.Angles(0, 0, tilt), shell(tint), {
					collide = false,
					query = true,
					shadow = false,
					surface = "roof",
					x = x,
					z = z,
					material = "SmoothPlastic",
				})
			end
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local midX = side * width / 4
		local midY = (eaveY + ridgeY) / 2
		part(
			shellModel,
			"RoofDeck",
			"Block",
			Vector3.new(slopeLen, 0.75, depth + 1.8),
			pivot * CFrame.new(midX, midY, 0) * CFrame.Angles(0, 0, -side * slope),
			shell("gingerB"),
			{ collide = false, query = false, shadow = true, material = "SmoothPlastic", shell = "gingerB" }
		)
	end
	-- Front and back gable triangles, sitting on the wall plate.
	for _, face in ipairs({ { z = gable.planeZ, name = "Gable" }, { z = gable.backZ, name = "GableBack" } }) do
		for _, side in ipairs({ -1, 1 }) do
			part(
				shellModel,
				face.name,
				"Wedge",
				Vector3.new(0.6, rise, width / 2 + 0.2),
				pivot * CFrame.new(side * width / 4, eaveY + rise / 2, face.z)
					* CFrame.Angles(0, if side < 0 then math.rad(-90) else math.rad(90), 0),
				shell("gingerA"),
				{ collide = false, query = false, shadow = true, shell = "gingerA" }
			)
		end
	end
	-- Chimney on the right slope, with an icing cap.
	local chimX = width * 0.28
	local chimY = Bases.gableY("gingerbread", chimX) + 2.6
	local chimZ = -depth * 0.12
	part(
		shellModel,
		"Chimney",
		"Block",
		Vector3.new(2.4, 5.4, 2.4),
		pivot * CFrame.new(chimX, chimY, chimZ),
		shell("gingerB"),
		{ collide = false, query = false, shadow = true, shell = "gingerB", material = "Brick" }
	)
	part(
		shellModel,
		"ChimneyCap",
		"Block",
		Vector3.new(3.0, 0.55, 3.0),
		pivot * CFrame.new(chimX, chimY + 2.85, chimZ),
		shell("icingA"),
		{ collide = false, query = false, shadow = false, material = "SmoothPlastic" }
	)
	part(
		shellModel,
		"ChimneyPot",
		"Cylinder",
		Vector3.new(0.9, 0.8, 0.8),
		pivot * CFrame.new(chimX, chimY + 3.4, chimZ) * CFrame.Angles(0, 0, math.rad(90)),
		shell("icingB"),
		{ collide = false, query = false, shadow = false }
	)
	dressGinger(shellModel, pivot, width, depth, height)
end

function Props.tree(shellModel: Model)
	local pivot = originOf(shellModel)
	part(shellModel, "Trunk", "Cylinder", Vector3.new(3.2, 1.5, 1.5), pivot * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)), shell("trunk"), {
		collide = true,
		query = false,
		shadow = true,
		material = "Wood",
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
			material = "Grass",
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
	dressTree(shellModel, pivot)
end

type Bit = {
	name: string,
	shape: string,
	size: Vector3,
	at: Vector3,
	color: Color3,
	tint: boolean,
	material: string?,
	spin: CFrame?,
	transparency: number?,
	light: number?,
}

type Paint = {
	main: Color3,
	accent: Color3,
	wood: Color3,
	cream: Color3,
	cloth: Color3,
	trim: Color3,
}

local STAND = CFrame.Angles(0, 0, math.rad(90))
local FACE = CFrame.Angles(0, math.rad(90), 0)

local function box(x: number, y: number, z: number): Vector3
	return Vector3.new(math.max(0.12, x), math.max(0.12, y), math.max(0.12, z))
end

-- Each prop stays inside Look.Budget (3 to 10 parts, including the invisible root).
local function push(model: Model, cf: CFrame, bit: Bit)
	local count = model:GetAttribute("PartCount")
	local n = if type(count) == "number" then count else 0
	if n >= Look.Budget.max then
		return
	end
	local spin = bit.spin
	if spin == nil and bit.shape == "Cylinder" then
		spin = STAND
	end
	local localCF = CFrame.new(bit.at)
	if spin ~= nil then
		localCF = localCF * spin
	end
	local piece = part(model, bit.name, bit.shape, bit.size, cf * localCF, bit.color, {
		collide = false,
		query = true,
		shadow = bit.tint == true,
		transparency = bit.transparency,
		material = bit.material,
	})
	piece:SetAttribute("Tint", bit.tint)
	if bit.light ~= nil and bit.light > 0 then
		local glow = Instance.new("PointLight")
		glow.Name = "SoftLight"
		glow.Color = bit.color
		glow.Brightness = bit.light
		glow.Range = 9
		glow.Shadows = false
		glow:SetAttribute("SoftB", bit.light)
		glow:SetAttribute("Kind", "bulb")
		glow.Parent = piece
	end
	model:SetAttribute("PartCount", n + 1)
end

local function sculpt(model: Model, cf: CFrame, item: any, sx: number, sy: number, sz: number, paint: Paint)
	local main = paint.main
	local accent = paint.accent
	local wood = paint.wood
	local cream = paint.cream
	local cloth = paint.cloth
	local trim = paint.trim
	local shape = item.shape
	local id = item.id
	local function put(
		name: string,
		shapeName: string,
		size: Vector3,
		at: Vector3,
		color: Color3,
		tint: boolean,
		material: string?,
		spin: CFrame?,
		transparency: number?,
		light: number?
	)
		push(model, cf, {
			name = name,
			shape = shapeName,
			size = size,
			at = at,
			color = color,
			tint = tint,
			material = material,
			spin = spin,
			transparency = transparency,
			light = light,
		})
	end

	if shape == "sofa" then
		put("Seat", "Block", box(sx * 0.78, sy * 0.32, sz * 0.7), Vector3.new(0, -sy * 0.12, 0.04), main, true, "Fabric", nil, nil, nil)
		put("Cushion", "Cylinder", box(sx * 0.62, sy * 0.26, sy * 0.26), Vector3.new(0, sy * 0.02, 0.08), main, true, "Fabric", CFrame.new(), nil, nil)
		put("Back", "Wedge", box(sx * 0.78, sy * 0.55, sz * 0.32), Vector3.new(0, sy * 0.12, -sz * 0.24), main, true, "Fabric", nil, nil, nil)
		put("Arm", "Cylinder", box(sy * 0.5, sx * 0.14, sx * 0.14), Vector3.new(-sx * 0.38, 0, 0), accent, false, "SmoothPlastic", nil, nil, nil)
		put("Arm", "Cylinder", box(sy * 0.5, sx * 0.14, sx * 0.14), Vector3.new(sx * 0.38, 0, 0), accent, false, "SmoothPlastic", nil, nil, nil)
		put("Pillow", "Ball", box(sx * 0.28, sy * 0.28, sz * 0.28), Vector3.new(0, sy * 0.08, 0.02), cloth, false, "Fabric", nil, nil, nil)
		put("Foot", "Ball", box(sx * 0.12, sy * 0.14, sz * 0.12), Vector3.new(-sx * 0.28, -sy * 0.38, sz * 0.2), wood, false, "Wood", nil, nil, nil)
		put("Foot", "Ball", box(sx * 0.12, sy * 0.14, sz * 0.12), Vector3.new(sx * 0.28, -sy * 0.38, sz * 0.2), wood, false, "Wood", nil, nil, nil)
	elseif shape == "piano" then
		put("Body", "Block", box(sx * 0.9, sy * 0.55, sz * 0.72), Vector3.new(0, -sy * 0.05, 0), main, true, "Wood", nil, nil, nil)
		put("Lid", "Wedge", box(sx * 0.88, sy * 0.22, sz * 0.7), Vector3.new(0, sy * 0.28, -0.02), accent, false, "Wood", nil, nil, nil)
		put("Keys", "Block", box(sx * 0.7, sy * 0.08, sz * 0.22), Vector3.new(0, sy * 0.08, sz * 0.28), cream, false, "SmoothPlastic", nil, nil, nil)
		put("Leg", "Cylinder", box(sy * 0.62, sx * 0.1, sx * 0.1), Vector3.new(-sx * 0.32, -sy * 0.22, 0), wood, false, "Wood", nil, nil, nil)
		put("Leg", "Cylinder", box(sy * 0.62, sx * 0.1, sx * 0.1), Vector3.new(sx * 0.32, -sy * 0.22, 0), wood, false, "Wood", nil, nil, nil)
		put("Stand", "Block", box(sx * 0.36, sy * 0.28, sz * 0.08), Vector3.new(0, sy * 0.4, -sz * 0.08), cream, false, "SmoothPlastic", nil, nil, nil)
		put("Bench", "Cylinder", box(sy * 0.16, sx * 0.34, sx * 0.34), Vector3.new(0, -sy * 0.32, sz * 0.62), cloth, false, "Fabric", nil, nil, nil)
	elseif shape == "chair" then
		put("Seat", "Cylinder", box(sy * 0.22, sx * 0.72, sz * 0.72), Vector3.new(0, -sy * 0.06, 0.04), main, true, "Fabric", nil, nil, nil)
		put("Back", "Wedge", box(sx * 0.72, sy * 0.55, sz * 0.28), Vector3.new(0, sy * 0.16, -sz * 0.22), main, true, "Fabric", nil, nil, nil)
		put("Leg", "Cylinder", box(sy * 0.5, sx * 0.12, sx * 0.12), Vector3.new(-sx * 0.22, -sy * 0.28, sz * 0.08), wood, false, "Wood", nil, nil, nil)
		put("Leg", "Cylinder", box(sy * 0.5, sx * 0.12, sx * 0.12), Vector3.new(sx * 0.22, -sy * 0.28, sz * 0.08), wood, false, "Wood", nil, nil, nil)
		put("Pillow", "Ball", box(sx * 0.36, sy * 0.24, sz * 0.3), Vector3.new(0, sy * 0.02, 0.08), cloth, false, "Fabric", nil, nil, nil)
	elseif shape == "recliner" then
		put("Seat", "Block", box(sx * 0.8, sy * 0.28, sz * 0.62), Vector3.new(0, -sy * 0.08, 0), main, true, "Fabric", nil, nil, nil)
		put("Back", "Wedge", box(sx * 0.78, sy * 0.58, sz * 0.3), Vector3.new(0, sy * 0.16, -sz * 0.22), main, true, "Fabric", nil, nil, nil)
		put("Foot", "Wedge", box(sx * 0.7, sy * 0.16, sz * 0.4), Vector3.new(0, -sy * 0.22, sz * 0.42), main, true, "Fabric", nil, nil, nil)
		put("Remote", "Block", box(sx * 0.18, sy * 0.08, sz * 0.28), Vector3.new(sx * 0.22, sy * 0.08, sz * 0.05), trim, false, "SmoothPlastic", nil, nil, nil)
		put("Lens", "Cylinder", box(0.08, sx * 0.16, sx * 0.16), Vector3.new(-sx * 0.1, sy * 0.36, sz * 0.06), cream, false, "Glass", FACE, 0.2, nil)
		put("Lens", "Cylinder", box(0.08, sx * 0.16, sx * 0.16), Vector3.new(sx * 0.1, sy * 0.36, sz * 0.06), cream, false, "Glass", FACE, 0.2, nil)
		put("Bridge", "Block", box(sx * 0.16, sy * 0.04, sz * 0.06), Vector3.new(0, sy * 0.36, sz * 0.06), trim, false, "Metal", nil, nil, nil)
	elseif shape == "table" then
		if item.w == item.d then
			put("Top", "Cylinder", box(math.max(0.32, sy * 0.18), sx * 0.86, sz * 0.86), Vector3.new(0, sy * 0.28, 0), main, true, "Wood", nil, nil, nil)
			put("Leg", "Cylinder", box(sy * 0.62, sx * 0.16, sz * 0.16), Vector3.new(0, -sy * 0.12, 0), wood, false, "Wood", nil, nil, nil)
			put("Doily", "Cylinder", box(0.12, sx * 0.48, sz * 0.48), Vector3.new(0, sy * 0.4, 0), cream, false, "Fabric", nil, nil, nil)
			put("Vase", "Ball", box(sx * 0.22, sy * 0.22, sz * 0.22), Vector3.new(0, sy * 0.52, 0), accent, false, "Glass", nil, 0.15, nil)
		else
			put("Top", "Block", box(sx * 0.9, math.max(0.28, sy * 0.16), sz * 0.86), Vector3.new(0, sy * 0.3, 0), main, true, "Wood", nil, nil, nil)
			put("Apron", "Block", box(sx * 0.8, sy * 0.1, sz * 0.68), Vector3.new(0, sy * 0.16, 0), accent, false, "Wood", nil, nil, nil)
			put("Leg", "Cylinder", box(sy * 0.55, 0.35, 0.35), Vector3.new(-sx * 0.32, -sy * 0.16, -sz * 0.24), wood, false, "Wood", nil, nil, nil)
			put("Leg", "Cylinder", box(sy * 0.55, 0.35, 0.35), Vector3.new(sx * 0.32, -sy * 0.16, -sz * 0.24), wood, false, "Wood", nil, nil, nil)
			put("Leg", "Cylinder", box(sy * 0.55, 0.35, 0.35), Vector3.new(-sx * 0.32, -sy * 0.16, sz * 0.24), wood, false, "Wood", nil, nil, nil)
			put("Leg", "Cylinder", box(sy * 0.55, 0.35, 0.35), Vector3.new(sx * 0.32, -sy * 0.16, sz * 0.24), wood, false, "Wood", nil, nil, nil)
		end
	elseif shape == "lamp" then
		put("Base", "Cylinder", box(sy * 0.12, sx * 0.55, sz * 0.55), Vector3.new(0, -sy * 0.4, 0), wood, false, "Wood", nil, nil, nil)
		put("Stem", "Cylinder", box(sy * 0.5, sx * 0.12, sz * 0.12), Vector3.new(0, -sy * 0.08, 0), trim, false, "Metal", nil, nil, nil)
		if id == "star_lamp" then
			local starY = Vector3.new(0, sy * 0.28, 0)
			put("Across", "Block", box(sx * 0.56, sy * 0.1, sz * 0.1), starY, main, true, "Neon", nil, nil, nil)
			put("Up", "Block", box(sx * 0.1, sy * 0.56, sz * 0.1), starY, main, true, "Neon", nil, nil, nil)
			put("DiagA", "Block", box(sx * 0.5, sy * 0.08, sz * 0.1), starY, main, true, "Neon", CFrame.Angles(0, 0, math.rad(45)), nil, nil)
			put("DiagB", "Block", box(sx * 0.5, sy * 0.08, sz * 0.1), starY, main, true, "Neon", CFrame.Angles(0, 0, math.rad(-45)), nil, nil)
		else
			put("Shade", "Ball", box(sx * 0.5, sy * 0.26, sz * 0.5), Vector3.new(0, sy * 0.22, 0), main, true, "SmoothPlastic", nil, 0.08, nil)
		end
		put("Bulb", "Ball", box(sx * 0.22, sy * 0.18, sz * 0.22), Vector3.new(0, sy * 0.05, 0), cream, false, "Neon", nil, 0.05, 0.45)
		put("Finial", "Ball", box(sx * 0.12, sy * 0.1, sz * 0.12), Vector3.new(0, sy * 0.4, 0), accent, false, "Metal", nil, nil, nil)
	elseif shape == "shelf" then
		if item.h >= 1.15 then
			put("Box", "Block", box(sx * 0.88, sy * 0.82, sz * 0.7), Vector3.zero, main, true, "Wood", nil, nil, nil)
			put("Door", "Block", box(sx * 0.36, sy * 0.62, sz * 0.08), Vector3.new(-sx * 0.2, -sy * 0.02, sz * 0.32), cloth, false, "Wood", nil, nil, nil)
			put("Door", "Block", box(sx * 0.36, sy * 0.62, sz * 0.08), Vector3.new(sx * 0.2, -sy * 0.02, sz * 0.32), cloth, false, "Wood", nil, nil, nil)
			put("Knob", "Ball", box(0.28, 0.28, 0.28), Vector3.new(sx * 0.08, 0, sz * 0.4), accent, false, "Metal", nil, nil, nil)
			put("Crown", "Block", box(sx * 0.94, sy * 0.08, sz * 0.78), Vector3.new(0, sy * 0.4, 0), cream, false, "Wood", nil, nil, nil)
		else
			put("Box", "Block", box(sx * 0.9, sy * 0.78, sz * 0.55), Vector3.new(0, 0, -sz * 0.06), main, true, "Wood", nil, nil, nil)
			put("Plank", "Block", box(sx * 0.82, sy * 0.08, sz * 0.62), Vector3.new(0, sy * 0.16, sz * 0.04), cream, false, "Wood", nil, nil, nil)
			put("Plank", "Block", box(sx * 0.82, sy * 0.08, sz * 0.62), Vector3.new(0, -sy * 0.16, sz * 0.04), cream, false, "Wood", nil, nil, nil)
			put("Book", "Wedge", box(sx * 0.16, sy * 0.28, sz * 0.28), Vector3.new(-sx * 0.22, sy * 0.28, sz * 0.08), accent, false, "SmoothPlastic", nil, nil, nil)
			put("Jar", "Ball", box(sx * 0.16, sy * 0.16, sz * 0.16), Vector3.new(sx * 0.2, sy * 0.28, sz * 0.06), cloth, false, "Glass", nil, 0.15, nil)
		end
	elseif shape == "plant" then
		local treeForm = string.find(id, "pine", 1, true) ~= nil or string.find(id, "spruce", 1, true) ~= nil or string.find(id, "sapling", 1, true) ~= nil
		put("Pot", "Cylinder", box(sy * 0.28, sx * 0.5, sz * 0.5), Vector3.new(0, -sy * 0.3, 0), cream, false, "SmoothPlastic", nil, nil, nil)
		if treeForm then
			put("Trunk", "Cylinder", box(sy * 0.35, sx * 0.12, sz * 0.12), Vector3.new(0, -sy * 0.02, 0), wood, false, "Wood", nil, nil, nil)
			put("Leaf", "Cylinder", box(sy * 0.26, sx * 0.72, sz * 0.72), Vector3.new(0, sy * 0.06, 0), main, true, "Grass", nil, nil, nil)
			put("Leaf", "Cylinder", box(sy * 0.22, sx * 0.5, sz * 0.5), Vector3.new(0, sy * 0.26, 0), main, true, "Grass", nil, nil, nil)
			put("Tip", "Cylinder", box(sy * 0.18, sx * 0.28, sz * 0.28), Vector3.new(0, sy * 0.44, 0), accent, false, "Grass", nil, nil, nil)
		else
			put("Soil", "Cylinder", box(sy * 0.08, sx * 0.4, sz * 0.4), Vector3.new(0, -sy * 0.16, 0), wood, false, "Ground", nil, nil, nil)
			put("Leaf", "Ball", box(sx * 0.72, sy * 0.4, sz * 0.72), Vector3.new(0, sy * 0.08, 0), main, true, "Grass", nil, nil, nil)
			put("Leaf", "Ball", box(sx * 0.4, sy * 0.28, sz * 0.4), Vector3.new(sx * 0.16, sy * 0.22, 0), main, true, "Grass", nil, nil, nil)
			put("Berry", "Ball", box(sx * 0.16, sy * 0.14, sz * 0.16), Vector3.new(-sx * 0.12, sy * 0.16, sz * 0.12), accent, false, "SmoothPlastic", nil, nil, nil)
		end
	elseif shape == "ball" then
		if item.surface == "hook" or item.category == "Baubles" then
			put("Body", "Ball", box(sx * 0.82, sy * 0.82, sz * 0.82), Vector3.zero, main, true, "Glass", nil, 0.12, nil)
			put("Cap", "Cylinder", box(sy * 0.12, sx * 0.28, sz * 0.28), Vector3.new(0, sy * 0.38, 0), trim, false, "Metal", nil, nil, nil)
			put("Shine", "Ball", box(sx * 0.22, sy * 0.22, sz * 0.22), Vector3.new(sx * 0.16, sy * 0.16, sz * 0.12), cream, false, "SmoothPlastic", nil, 0.2, nil)
			put("Hook", "Cylinder", box(sy * 0.2, 0.16, 0.16), Vector3.new(0, sy * 0.5, 0), trim, false, "Metal", nil, nil, nil)
		else
			put("Body", "Ball", box(sx * 0.86, sy * 0.7, sz * 0.86), Vector3.new(0, -sy * 0.06, 0), main, true, "Fabric", nil, nil, nil)
			put("Band", "Cylinder", box(sy * 0.12, sx * 0.9, sz * 0.9), Vector3.zero, accent, false, "Fabric", nil, nil, nil)
			put("Button", "Ball", box(sx * 0.18, sy * 0.16, sz * 0.18), Vector3.new(0, sy * 0.22, 0), cream, false, "SmoothPlastic", nil, nil, nil)
		end
	elseif shape == "cane" then
		put("Shaft", "Cylinder", box(sy * 0.82, sx * 0.22, sz * 0.22), Vector3.new(0, -sy * 0.04, 0), main, true, "SmoothPlastic", nil, nil, nil)
		put("Stripe", "Cylinder", box(sy * 0.28, sx * 0.26, sz * 0.26), Vector3.new(0, sy * 0.08, 0), cream, false, "SmoothPlastic", nil, nil, nil)
		put("Hook", "Ball", box(sx * 0.36, sy * 0.22, sz * 0.36), Vector3.new(sx * 0.1, sy * 0.38, 0), main, true, "SmoothPlastic", nil, nil, nil)
		put("Bow", "Ball", box(sx * 0.22, sy * 0.16, sz * 0.22), Vector3.new(0, sy * 0.28, 0), accent, false, "SmoothPlastic", nil, nil, nil)
	elseif shape == "cylinder" then
		if item.surface == "wall" then
			put("Disc", "Cylinder", box(math.max(0.16, sz * 0.7), sx * 0.82, sy * 0.82), Vector3.zero, main, true, "SmoothPlastic", FACE, nil, nil)
			put("Stripe", "Cylinder", box(math.max(0.18, sz * 0.85), sx * 0.48, sy * 0.48), Vector3.new(0, 0, sz * 0.08), cream, false, "SmoothPlastic", FACE, nil, nil)
			put("Center", "Ball", box(sx * 0.22, sy * 0.22, sz * 0.22), Vector3.new(0, 0, sz * 0.16), accent, false, "SmoothPlastic", nil, nil, nil)
		elseif id == "blanket_roll" then
			put("Roll", "Cylinder", box(sx * 0.86, sy * 0.7, sz * 0.7), Vector3.zero, main, true, "Fabric", CFrame.new(), nil, nil)
			put("Band", "Cylinder", box(sx * 0.16, sy * 0.82, sz * 0.82), Vector3.zero, accent, false, "Fabric", CFrame.new(), nil, nil)
			put("Pom", "Ball", box(sy * 0.45, sy * 0.45, sy * 0.45), Vector3.new(sx * 0.42, 0, 0), cream, false, "Fabric", nil, nil, nil)
		elseif id == "toy_drum" then
			put("Body", "Cylinder", box(sy * 0.62, sx * 0.8, sz * 0.8), Vector3.new(0, -sy * 0.05, 0), main, true, "SmoothPlastic", nil, nil, nil)
			put("Head", "Cylinder", box(sy * 0.1, sx * 0.84, sz * 0.84), Vector3.new(0, sy * 0.28, 0), cream, false, "SmoothPlastic", nil, nil, nil)
			put("Rim", "Cylinder", box(sy * 0.08, sx * 0.9, sz * 0.9), Vector3.new(0, sy * 0.22, 0), accent, false, "Metal", nil, nil, nil)
			put("Stick", "Cylinder", box(sx * 0.7, 0.14, 0.14), Vector3.new(sx * 0.2, sy * 0.4, 0), wood, false, "Wood", CFrame.new(), nil, nil)
		elseif id == "thermos" then
			put("Body", "Cylinder", box(sy * 0.7, sx * 0.48, sz * 0.48), Vector3.new(0, -sy * 0.05, 0), main, true, "Metal", nil, nil, nil)
			put("Cup", "Cylinder", box(sy * 0.16, sx * 0.58, sz * 0.58), Vector3.new(0, sy * 0.28, 0), cream, false, "SmoothPlastic", nil, nil, nil)
			put("Cap", "Cylinder", box(sy * 0.14, sx * 0.4, sz * 0.4), Vector3.new(0, sy * 0.4, 0), accent, false, "SmoothPlastic", nil, nil, nil)
			put("Handle", "Cylinder", box(sy * 0.28, 0.16, 0.16), Vector3.new(sx * 0.32, 0, 0), trim, false, "Metal", nil, nil, nil)
		else
			put("Body", "Cylinder", box(sy * 0.62, sx * 0.55, sz * 0.55), Vector3.new(0, -sy * 0.08, 0), main, true, "SmoothPlastic", nil, nil, nil)
			put("Rim", "Cylinder", box(sy * 0.1, sx * 0.68, sz * 0.68), Vector3.new(0, sy * 0.24, 0), cream, false, "SmoothPlastic", nil, nil, nil)
			put("Handle", "Cylinder", box(sy * 0.28, 0.16, 0.16), Vector3.new(sx * 0.38, 0, 0), accent, false, "SmoothPlastic", nil, nil, nil)
			put("Fill", "Ball", box(sx * 0.36, sy * 0.16, sz * 0.36), Vector3.new(0, sy * 0.22, 0), wood, false, "SmoothPlastic", nil, nil, nil)
		end
	elseif shape == "wedge" then
		put("Body", "Wedge", box(sx * 0.9, sy * 0.9, sz * 0.9), Vector3.zero, main, true, "SmoothPlastic", nil, nil, nil)
		put("Dollop", "Ball", box(sx * 0.35, sy * 0.35, sz * 0.35), Vector3.new(0, sy * 0.2, 0), cream, false, "SmoothPlastic", nil, nil, nil)
		put("Edge", "Cylinder", box(sx * 0.9, 0.2, 0.2), Vector3.new(0, -sy * 0.28, sz * 0.2), accent, false, "SmoothPlastic", CFrame.new(), nil, nil)
	elseif shape == "star" then
		put("Across", "Block", box(sx * 0.92, sy * 0.18, sz * 0.18), Vector3.zero, main, true, "SmoothPlastic", nil, nil, nil)
		put("Up", "Block", box(sx * 0.18, sy * 0.92, sz * 0.18), Vector3.zero, main, true, "SmoothPlastic", nil, nil, nil)
		put("Diag", "Block", box(sx * 0.72, sy * 0.16, sz * 0.16), Vector3.zero, main, true, "SmoothPlastic", CFrame.Angles(0, 0, math.rad(45)), nil, nil)
		put("Diag", "Block", box(sx * 0.72, sy * 0.16, sz * 0.16), Vector3.zero, main, true, "SmoothPlastic", CFrame.Angles(0, 0, math.rad(-45)), nil, nil)
		put("Core", "Ball", box(sx * 0.28, sy * 0.28, sz * 0.28), Vector3.zero, cream, false, "Neon", nil, nil, nil)
	elseif shape == "bell" then
		put("Cup", "Ball", box(sx * 0.82, sy * 0.7, sz * 0.82), Vector3.new(0, -sy * 0.06, 0), main, true, "Metal", nil, nil, nil)
		put("Cap", "Cylinder", box(sy * 0.16, sx * 0.28, sz * 0.28), Vector3.new(0, sy * 0.32, 0), trim, false, "Metal", nil, nil, nil)
		put("Clapper", "Ball", box(sx * 0.22, sy * 0.18, sz * 0.22), Vector3.new(0, -sy * 0.12, 0), cream, false, "Metal", nil, nil, nil)
		put("Bow", "Ball", box(sx * 0.24, sy * 0.16, sz * 0.24), Vector3.new(0, sy * 0.42, 0), accent, false, "SmoothPlastic", nil, nil, nil)
	elseif shape == "frame" then
		if item.category == "Icing" then
			put("Top", "Block", box(sx * 0.9, sy * 0.16, sz), Vector3.new(0, sy * 0.38, 0), cream, true, "SmoothPlastic", nil, nil, nil)
			put("Bottom", "Block", box(sx * 0.9, sy * 0.16, sz), Vector3.new(0, -sy * 0.38, 0), cream, true, "SmoothPlastic", nil, nil, nil)
			put("Side", "Block", box(sx * 0.16, sy * 0.9, sz), Vector3.new(-sx * 0.38, 0, 0), cream, true, "SmoothPlastic", nil, nil, nil)
			put("Side", "Block", box(sx * 0.16, sy * 0.9, sz), Vector3.new(sx * 0.38, 0, 0), cream, true, "SmoothPlastic", nil, nil, nil)
			put("Knob", "Ball", box(sx * 0.16, sy * 0.16, sz * 0.4), Vector3.zero, accent, false, "SmoothPlastic", nil, nil, nil)
		elseif string.find(id, "wreath", 1, true) ~= nil then
			put("Ring", "Cylinder", box(math.max(0.2, sz), sx * 0.9, sy * 0.9), Vector3.zero, main, true, "Grass", FACE, nil, nil)
			put("Inner", "Cylinder", box(math.max(0.22, sz * 1.05), sx * 0.42, sy * 0.42), Vector3.new(0, 0, sz * 0.05), cream, false, "SmoothPlastic", FACE, nil, nil)
			put("Bow", "Ball", box(sx * 0.28, sy * 0.2, sz * 0.4), Vector3.new(0, -sy * 0.32, sz * 0.1), accent, false, "SmoothPlastic", nil, nil, nil)
			put("Berry", "Ball", box(sx * 0.12, sy * 0.12, sz * 0.2), Vector3.new(sx * 0.18, sy * 0.1, sz * 0.12), accent, false, "SmoothPlastic", nil, nil, nil)
		elseif string.find(id, "stocking", 1, true) ~= nil then
			put("Cuff", "Block", box(sx * 0.7, sy * 0.18, math.max(0.2, sz)), Vector3.new(0, sy * 0.34, 0), cream, false, "Fabric", nil, nil, nil)
			put("Body", "Wedge", box(sx * 0.55, sy * 0.62, math.max(0.24, sz)), Vector3.new(-sx * 0.08, -sy * 0.05, 0), main, true, "Fabric", nil, nil, nil)
			put("Toe", "Ball", box(sx * 0.28, sy * 0.22, math.max(0.24, sz)), Vector3.new(sx * 0.16, -sy * 0.28, 0), main, true, "Fabric", nil, nil, nil)
			put("Heel", "Ball", box(sx * 0.2, sy * 0.18, math.max(0.2, sz)), Vector3.new(-sx * 0.2, -sy * 0.16, 0), accent, false, "Fabric", nil, nil, nil)
		elseif string.find(id, "banner", 1, true) ~= nil then
			put("Cloth", "Block", box(sx * 0.86, sy * 0.7, math.max(0.16, sz * 0.6)), Vector3.new(0, -sy * 0.06, 0), main, true, "Fabric", nil, nil, nil)
			put("Pole", "Cylinder", box(sx * 0.96, 0.18, 0.18), Vector3.new(0, sy * 0.38, 0), wood, false, "Wood", CFrame.new(), nil, nil)
			put("Mark", "Ball", box(sx * 0.16, sy * 0.16, sz * 0.3), Vector3.zero, cream, false, "SmoothPlastic", nil, nil, nil)
		else
			put("Back", "Block", box(sx * 0.96, sy * 0.96, math.max(0.2, sz)), Vector3.zero, trim, false, "Wood", nil, nil, nil)
			put("Mat", "Block", box(sx * 0.78, sy * 0.78, math.max(0.16, sz * 0.7)), Vector3.new(0, 0, sz * 0.08), cream, false, "SmoothPlastic", nil, nil, nil)
			put("Face", "Block", box(sx * 0.58, sy * 0.58, math.max(0.14, sz * 0.55)), Vector3.new(0, 0, sz * 0.16), main, true, "SmoothPlastic", nil, nil, nil)
			put("Bow", "Ball", box(sx * 0.16, sy * 0.14, sz * 0.3), Vector3.new(0, -sy * 0.42, sz * 0.12), accent, false, "SmoothPlastic", nil, nil, nil)
		end
	elseif shape == "slab" or shape == "box" then
		if shape == "box" and item.h >= 0.4 then
			put("Box", "Block", box(sx * 0.82, sy * 0.62, sz * 0.82), Vector3.new(0, -sy * 0.08, 0), main, true, "SmoothPlastic", nil, nil, nil)
			put("Lid", "Block", box(sx * 0.86, sy * 0.16, sz * 0.86), Vector3.new(0, sy * 0.28, 0), cream, false, "SmoothPlastic", nil, nil, nil)
			put("Ribbon", "Block", box(sx * 0.16, sy * 0.7, sz * 0.88), Vector3.zero, accent, false, "SmoothPlastic", nil, nil, nil)
			put("Bow", "Ball", box(sx * 0.28, sy * 0.22, sz * 0.28), Vector3.new(0, sy * 0.4, 0), accent, false, "SmoothPlastic", nil, nil, nil)
		elseif shape == "box" then
			put("Tile", "Block", box(sx * 0.86, math.max(sy, 0.2), sz * 0.86), Vector3.zero, main, true, "SmoothPlastic", nil, nil, nil)
			put("Shine", "Ball", box(sx * 0.28, sy * 0.5, sz * 0.28), Vector3.new(-sx * 0.12, sy * 0.1, 0), cream, false, "Glass", nil, 0.2, nil)
			put("Dot", "Ball", box(sx * 0.16, sy * 0.4, sz * 0.16), Vector3.new(sx * 0.2, 0, 0), accent, false, "SmoothPlastic", nil, nil, nil)
		elseif item.id == "pibble_rug" then
			put("Rug", "Block", box(sx * 0.92, math.max(0.16, sy * 0.45), sz * 0.92), Vector3.new(0, -sy * 0.15, 0), main, true, "Fabric", nil, nil, nil)
			put("Body", "Ball", box(sx * 0.42, sy * 0.9, sz * 0.32), Vector3.new(-sx * 0.08, 0, 0), cloth, false, "Fabric", nil, nil, nil)
			put("Head", "Ball", box(sx * 0.22, sy * 0.9, sz * 0.22), Vector3.new(sx * 0.18, sy * 0.05, 0), cream, false, "Fabric", nil, nil, nil)
			put("Ear", "Ball", box(sx * 0.1, sy * 0.7, sz * 0.1), Vector3.new(sx * 0.24, sy * 0.15, -sz * 0.08), trim, false, "Fabric", nil, nil, nil)
			put("Snout", "Ball", box(sx * 0.1, sy * 0.45, sz * 0.1), Vector3.new(sx * 0.28, 0, sz * 0.06), accent, false, "Fabric", nil, nil, nil)
		elseif item.category == "Rugs" then
			put("Rug", "Block", box(sx * 0.94, math.max(0.14, sy * 0.4), sz * 0.94), Vector3.new(0, -sy * 0.1, 0), main, true, "Fabric", nil, nil, nil)
			put("Stripe", "Block", box(sx * 0.16, math.max(0.16, sy * 0.55), sz * 0.7), Vector3.new(-sx * 0.18, 0, 0), accent, false, "Fabric", nil, nil, nil)
			put("Stripe", "Block", box(sx * 0.16, math.max(0.16, sy * 0.55), sz * 0.7), Vector3.new(sx * 0.18, 0, 0), cloth, false, "Fabric", nil, nil, nil)
			put("Motif", "Ball", box(math.min(sx, sz) * 0.22, sy * 0.7, math.min(sx, sz) * 0.22), Vector3.zero, cream, false, "Fabric", nil, nil, nil)
		elseif item.id == "sprig_accent" then
			put("Stem", "Cylinder", box(sx * 0.7, 0.16, 0.16), Vector3.new(0, 0, 0), wood, false, "Wood", CFrame.new(), nil, nil)
			put("Leaf", "Ball", box(sx * 0.22, sy * 0.8, sz * 0.35), Vector3.new(-sx * 0.12, sy * 0.1, 0), main, true, "Grass", nil, nil, nil)
			put("Leaf", "Ball", box(sx * 0.22, sy * 0.8, sz * 0.35), Vector3.new(sx * 0.16, sy * 0.05, 0), main, true, "Grass", nil, nil, nil)
			put("Berry", "Ball", box(0.28, sy * 0.5, 0.28), Vector3.new(0, sy * 0.15, sz * 0.08), accent, false, "SmoothPlastic", nil, nil, nil)
		elseif item.id == "spark_accent" then
			put("Across", "Block", box(sx * 0.7, sy * 0.16, sz * 0.16), Vector3.zero, main, true, "Neon", nil, nil, nil)
			put("Up", "Block", box(sx * 0.16, sy * 0.7, sz * 0.16), Vector3.zero, main, true, "Neon", nil, nil, nil)
			put("DiagA", "Block", box(sx * 0.62, sy * 0.14, sz * 0.14), Vector3.zero, main, true, "Neon", CFrame.Angles(0, 0, math.rad(45)), nil, nil)
			put("DiagB", "Block", box(sx * 0.62, sy * 0.14, sz * 0.14), Vector3.zero, main, true, "Neon", CFrame.Angles(0, 0, math.rad(-45)), nil, nil)
			put("Core", "Ball", box(sx * 0.2, sy * 0.2, sz * 0.2), Vector3.zero, cream, false, "Neon", nil, nil, nil)
		elseif item.category == "Accents" then
			put("Loop", "Ball", box(sx * 0.22, sy * 0.8, sz * 0.4), Vector3.new(-sx * 0.16, sy * 0.1, 0), main, true, "SmoothPlastic", nil, nil, nil)
			put("Loop", "Ball", box(sx * 0.22, sy * 0.8, sz * 0.4), Vector3.new(sx * 0.16, sy * 0.1, 0), main, true, "SmoothPlastic", nil, nil, nil)
			put("Knot", "Ball", box(sx * 0.14, sy * 0.55, sz * 0.3), Vector3.zero, accent, false, "SmoothPlastic", nil, nil, nil)
			put("Tail", "Wedge", box(sx * 0.16, sy * 0.7, sz * 0.45), Vector3.new(0, -sy * 0.15, sz * 0.1), cloth, false, "SmoothPlastic", nil, nil, nil)
		elseif item.id == "string_lights" then
			-- Hang as a wall swag, not a straight floor stick.
			local droop = math.max(1.1, sy * 1.15)
			put("WireL", "Block", box(sx * 0.56, 0.1, 0.1), Vector3.new(-sx * 0.22, droop * 0.12, sz * 0.25), trim, false, "Metal", CFrame.Angles(0, 0, math.rad(26)), nil, nil)
			put("WireR", "Block", box(sx * 0.56, 0.1, 0.1), Vector3.new(sx * 0.22, droop * 0.12, sz * 0.25), trim, false, "Metal", CFrame.Angles(0, 0, math.rad(-26)), nil, nil)
			put("Bulb", "Ball", box(0.42, 0.42, 0.42), Vector3.new(-sx * 0.4, droop * 0.5, sz * 0.4), cream, false, "Neon", nil, 0.05, 0.4)
			put("Bulb", "Ball", box(0.42, 0.42, 0.42), Vector3.new(-sx * 0.18, -droop * 0.02, sz * 0.4), main, true, "Neon", nil, 0.05, 0.4)
			put("Bulb", "Ball", box(0.42, 0.42, 0.42), Vector3.new(0, -droop * 0.38, sz * 0.4), accent, false, "Neon", nil, 0.05, 0.45)
			put("Bulb", "Ball", box(0.42, 0.42, 0.42), Vector3.new(sx * 0.18, -droop * 0.02, sz * 0.4), cream, false, "Neon", nil, 0.05, 0.4)
			put("Bulb", "Ball", box(0.42, 0.42, 0.42), Vector3.new(sx * 0.4, droop * 0.5, sz * 0.4), main, true, "Neon", nil, 0.05, 0.4)
		elseif item.category == "Lighting" then
			put("Wire", "Block", box(sx * 0.92, math.max(0.12, sy * 0.25), 0.16), Vector3.zero, trim, false, "Metal", nil, nil, nil)
			put("Bulb", "Ball", box(0.45, 0.45, 0.45), Vector3.new(-sx * 0.28, sy * 0.15, 0), main, true, "Neon", nil, 0.05, 0.35)
			put("Bulb", "Ball", box(0.45, 0.45, 0.45), Vector3.zero, cream, false, "Neon", nil, 0.05, 0.35)
			put("Bulb", "Ball", box(0.45, 0.45, 0.45), Vector3.new(sx * 0.28, sy * 0.15, 0), accent, false, "Neon", nil, 0.05, 0.35)
		elseif item.category == "Icing" then
			put("Bar", "Block", box(sx * 0.92, math.max(0.16, sy * 0.45), sz * 0.7), Vector3.new(0, sy * 0.1, 0), main, true, "SmoothPlastic", nil, nil, nil)
			put("Drip", "Wedge", box(sx * 0.16, sy * 0.7, sz * 0.45), Vector3.new(-sx * 0.24, -sy * 0.15, 0), cream, false, "SmoothPlastic", nil, nil, nil)
			put("Drip", "Wedge", box(sx * 0.16, sy * 0.7, sz * 0.45), Vector3.zero, cream, false, "SmoothPlastic", nil, nil, nil)
			put("Drip", "Wedge", box(sx * 0.16, sy * 0.7, sz * 0.45), Vector3.new(sx * 0.24, -sy * 0.15, 0), cream, false, "SmoothPlastic", nil, nil, nil)
		elseif item.category == "Hangings" then
			put("Sash", "Block", box(sx * 0.92, sy * 0.55, math.max(0.14, sz * 0.5)), Vector3.zero, main, true, "Fabric", nil, nil, nil)
			put("Bow", "Ball", box(sx * 0.16, sy * 0.7, sz * 0.4), Vector3.new(-sx * 0.28, 0, 0), accent, false, "Fabric", nil, nil, nil)
			put("Tail", "Wedge", box(sx * 0.14, sy * 0.8, sz * 0.4), Vector3.new(sx * 0.2, -sy * 0.05, 0), cloth, false, "Fabric", nil, nil, nil)
		else
			put("Cord", "Block", box(sx * 0.9, math.max(0.12, sy * 0.28), 0.16), Vector3.zero, trim, false, "Fabric", nil, nil, nil)
			put("Bead", "Ball", box(0.4, math.max(0.28, sy * 0.7), 0.4), Vector3.new(-sx * 0.26, 0, 0), main, true, "SmoothPlastic", nil, nil, nil)
			put("Bead", "Ball", box(0.4, math.max(0.28, sy * 0.7), 0.4), Vector3.zero, cream, false, "SmoothPlastic", nil, nil, nil)
			put("Bead", "Ball", box(0.4, math.max(0.28, sy * 0.7), 0.4), Vector3.new(sx * 0.26, 0, 0), accent, false, "SmoothPlastic", nil, nil, nil)
		end
	else
		put("Body", "Block", box(sx * 0.86, math.max(sy * 0.7, 0.24), sz * 0.86), Vector3.zero, main, true, "SmoothPlastic", nil, nil, nil)
		put("Cap", "Cylinder", box(sy * 0.16, sx * 0.4, sz * 0.4), Vector3.new(0, sy * 0.32, 0), cream, false, "SmoothPlastic", nil, nil, nil)
		put("Stud", "Ball", box(sx * 0.18, sy * 0.18, sz * 0.18), Vector3.new(0, sy * 0.42, 0), accent, false, "SmoothPlastic", nil, nil, nil)
	end
end

-- One real model per item, at the origin, for tray ViewportFrames.
function Props.previews(parent: Folder, items: { any })
	for _, item in ipairs(items) do
		if type(item) == "table" and type(item.id) == "string" and parent:FindFirstChild(item.id) == nil then
			local piece = {
				id = 0,
				itemId = item.id,
				x = 0,
				z = 0,
				rot = 0,
				color = item.color,
				placedAt = 0,
			}
			local roundType = item.roundType
			if type(roundType) ~= "string" or roundType == "" then
				roundType = "room"
			end
			local model = Props.prop(CFrame.identity, item, piece, roundType)
			model.Name = item.id
			model.Parent = parent
		end
	end
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
	local themeTag = if type(item.tags) == "table" then item.tags[2] else nil
	local pack = Look.pack(Look.packFor(item.roundType, themeTag))
	local root = part(model, "Root", "Block", Vector3.new(0.2, 0.2, 0.2), cf, main, {
		collide = false,
		query = false,
		transparency = 1,
		shadow = false,
	})
	model.PrimaryPart = root
	model:SetAttribute("PartCount", 1)
	model:SetAttribute("Pack", Look.packFor(item.roundType, themeTag))
	sculpt(model, cf, item, sx, sy, sz, {
		main = main,
		accent = rgb(pack.accent),
		wood = rgb(pack.wood),
		cream = rgb(pack.cream),
		cloth = rgb(pack.cloth),
		trim = rgb(pack.trim),
	})
	local built = model:GetAttribute("PartCount")
	if type(built) == "number" and (built < Look.Budget.min or built > Look.Budget.max) then
		warn("[Props] " .. tostring(item.id) .. " uses " .. tostring(built) .. " parts")
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

function Props.tintShell(plot: Instance, family: string)
	if type(family) ~= "string" or family == "" then
		family = "hearth"
	end
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") then
			local name = child:GetAttribute("Shell")
			if type(name) == "string" then
				child.Color = packColor(family, name)
			end
		end
	end
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
