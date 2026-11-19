--!strict
-- Pastel plaza beside the spawn. Critic booth, a three-place stage, the game
-- sign, and two photo spots. Place plates say 1st, 2nd, and 3rd until Results.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local UIKit = require(Shared:WaitForChild("UIKit") :: ModuleScript) :: any

local Plaza = {}

local function rgb(name: string): Color3
	local channels = UIKit.color(name)
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

local function face(): Enum.Font
	local named = (Enum.Font :: any)[UIKit.Typeface]
	if typeof(named) == "EnumItem" then
		return named :: Enum.Font
	end
	return Enum.Font.GothamBold
end

local function bit(
	parent: Instance,
	name: string,
	shape: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?,
	transparency: number?
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CanCollide = collide == true
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.Transparency = transparency or 0
	piece.CastShadow = collide == true
	if shape == "Ball" then
		piece.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		piece.Shape = Enum.PartType.Cylinder
	elseif shape == "Wedge" then
		piece.Shape = Enum.PartType.Wedge
	end
	piece.Parent = parent
	return piece
end

local function glow(host: BasePart, color: Color3, brightness: number, range: number)
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

local function stand(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

local function labelOn(host: BasePart, name: string, text: string, rank: number?, textSize: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(400, 160)
	gui.LightInfluence = 0.2
	gui.Parent = host
	local label = Instance.new("TextLabel")
	label.Name = if rank ~= nil then "Plate" else "Caption"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = face()
	label.Text = text
	label.TextColor3 = rgb("ink")
	label.TextScaled = true
	label.Parent = gui
	if rank ~= nil then
		label:SetAttribute("Rank", rank)
	end
	local cap = Instance.new("UITextSizeConstraint")
	cap.MinTextSize = 18
	cap.MaxTextSize = textSize
	cap.Parent = label
end


local GLYPHS: { [string]: { string } } = {
	[" "] = { "     ", "     ", "     ", "     ", "     " },
	A = { " ### ", "#   #", "#####", "#   #", "#   #" },
	B = { "#### ", "#   #", "#### ", "#   #", "#### " },
	C = { " ### ", "#    ", "#    ", "#    ", " ### " },
	D = { "#### ", "#   #", "#   #", "#   #", "#### " },
	E = { "#####", "#    ", "#### ", "#    ", "#####" },
	G = { " ### ", "#    ", "#  ##", "#   #", " ### " },
	H = { "#   #", "#   #", "#####", "#   #", "#   #" },
	I = { "#####", "  #  ", "  #  ", "  #  ", "#####" },
	L = { "#    ", "#    ", "#    ", "#    ", "#####" },
	M = { "#   #", "## ##", "# # #", "#   #", "#   #" },
	N = { "#   #", "##  #", "# # #", "#  ##", "#   #" },
	O = { " ### ", "#   #", "#   #", "#   #", " ### " },
	P = { "#### ", "#   #", "#### ", "#    ", "#    " },
	R = { "#### ", "#   #", "#### ", "#  # ", "#   #" },
	S = { " ####", "#    ", " ### ", "    #", "#### " },
	T = { "#####", "  #  ", "  #  ", "  #  ", "  #  " },
	U = { "#   #", "#   #", "#   #", "#   #", " ### " },
	W = { "#   #", "#   #", "# # #", "## ##", "#   #" },
	Y = { "#   #", " # # ", "  #  ", "  #  ", "  #  " },
}

local function writeLine(parent: Instance, text: string, origin: CFrame, color: Color3, cell: number, thick: number)
	local glyphs: { { string } } = {}
	local width = 0
	for index = 1, #text do
		local ch = string.upper(string.sub(text, index, index))
		local rows = GLYPHS[ch] or GLYPHS[" "]
		table.insert(glyphs, rows)
		width += #rows[1]
		if index < #text then
			width += 1
		end
	end
	local cursor = -width / 2
	for _, rows in ipairs(glyphs) do
		local cols = #rows[1]
		for r = 1, #rows do
			for c = 1, cols do
				if string.sub(rows[r], c, c) == "#" then
					local x = (cursor + c - 0.5) * cell
					local y = ((#rows + 1) / 2 - r) * cell
					bit(parent, "Glyph", "Block", Vector3.new(cell * 0.9, cell * 0.9, thick), origin * CFrame.new(x, y, 0), color, Enum.Material.SmoothPlastic, false, nil)
				end
			end
		end
		cursor += cols + 1
	end
end

local function pine(parent: Instance, at: Vector3, scale: number, pot: Color3, leaf: Color3, snow: Color3)
	bit(parent, "Pot", "Cylinder", Vector3.new(0.9 * scale, 1.0 * scale, 1.0 * scale), stand(CFrame.new(at.X, 0.6 * scale, at.Z)), pot, Enum.Material.SmoothPlastic, true, nil)
	bit(parent, "Trunk", "Cylinder", Vector3.new(1.4 * scale, 0.32 * scale, 0.32 * scale), stand(CFrame.new(at.X, 1.4 * scale, at.Z)), Color3.fromRGB(110, 78, 52), Enum.Material.Wood, true, nil)
	local tiers = {
		{ y = 2.15, d = 2.4, h = 1.35 },
		{ y = 3.15, d = 1.85, h = 1.25 },
		{ y = 4.05, d = 1.3, h = 1.15 },
		{ y = 4.8, d = 0.8, h = 1.0 },
	}
	for _, row in ipairs(tiers) do
		bit(parent, "Leaf", "Cylinder", Vector3.new(row.h * scale, row.d * scale, row.d * scale), stand(CFrame.new(at.X, row.y * scale, at.Z)), leaf, Enum.Material.Grass, false, nil)
	end
	bit(parent, "Snow", "Cylinder", Vector3.new(0.22 * scale, 0.55 * scale, 0.55 * scale), stand(CFrame.new(at.X, 5.35 * scale, at.Z)), snow, Enum.Material.Fabric, false, nil)
end

local function span(parent: Instance, name: string, p0: Vector3, p1: Vector3, radius: number, color: Color3)
	local delta = p1 - p0
	local len = delta.Magnitude
	if len < 0.2 then
		return
	end
	local mid = (p0 + p1) * 0.5
	bit(parent, name, "Cylinder", Vector3.new(len, radius * 2, radius * 2), CFrame.lookAt(mid, p1) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.SmoothPlastic, false, nil)
end

local function spark(parent: Instance, at: Vector3, color: Color3, size: number): BasePart
	local arm = bit(parent, "StarArm", "Block", Vector3.new(size, size * 0.22, size * 0.22), CFrame.new(at), color, Enum.Material.Neon, false, nil)
	bit(parent, "StarArm", "Block", Vector3.new(size * 0.22, size, size * 0.22), CFrame.new(at), color, Enum.Material.Neon, false, nil)
	bit(parent, "StarArm", "Block", Vector3.new(size * 0.72, size * 0.2, size * 0.2), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(45)), color, Enum.Material.Neon, false, nil)
	bit(parent, "StarArm", "Block", Vector3.new(size * 0.72, size * 0.2, size * 0.2), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(-45)), color, Enum.Material.Neon, false, nil)
	return arm
end

local function swag(parent: Instance, a: Vector3, b: Vector3, drop: number, butter: Color3, coral: Color3, lit: boolean)
	local mid = Vector3.new((a.X + b.X) * 0.5, math.min(a.Y, b.Y) - drop, (a.Z + b.Z) * 0.5)
	local cord = Color3.fromRGB(70, 62, 78)
	span(parent, "Cord", a, mid, 0.06, cord)
	span(parent, "Cord", mid, b, 0.06, cord)
	local bulbs = {
		{ p = a:Lerp(mid, 0.35), c = butter },
		{ p = mid, c = coral },
		{ p = mid:Lerp(b, 0.65), c = butter },
	}
	for index, row in ipairs(bulbs) do
		local bulb = bit(parent, "Fairy", "Ball", Vector3.new(0.38, 0.38, 0.38), CFrame.new(row.p), row.c, Enum.Material.Neon, false, nil)
		if lit and index == 2 then
			glow(bulb, butter, 0.35, 7)
		end
	end
end

local function gift(parent: Instance, at: Vector3, box: Color3, ribbon: Color3)
	bit(parent, "Gift", "Block", Vector3.new(1.4, 1.1, 1.4), CFrame.new(at.X, 0.85, at.Z), box, Enum.Material.SmoothPlastic, true, nil)
	bit(parent, "Ribbon", "Block", Vector3.new(0.25, 1.25, 1.45), CFrame.new(at.X, 0.9, at.Z), ribbon, Enum.Material.SmoothPlastic, false, nil)
	bit(parent, "Bow", "Ball", Vector3.new(0.55, 0.35, 0.55), CFrame.new(at.X, 1.55, at.Z), ribbon, Enum.Material.SmoothPlastic, false, nil)
end

local function heroTree(parent: Instance, at: Vector3, cream: Color3, coral: Color3, mint: Color3, butter: Color3, lavender: Color3)
	local tree = Instance.new("Model")
	tree.Name = "HeroTree"
	tree.Parent = parent
	local scale = 2.05
	local snow = Color3.fromRGB(245, 250, 255)
	local leaf = Color3.fromRGB(36, 150, 82)
	bit(tree, "Ring", "Cylinder", Vector3.new(0.28, 3.6, 3.6), stand(CFrame.new(at.X, 0.45, at.Z)), cream, Enum.Material.SmoothPlastic, true, nil)
	bit(tree, "Trunk", "Cylinder", Vector3.new(2.4 * scale, 0.55 * scale, 0.55 * scale), stand(CFrame.new(at.X, 1.4 * scale, at.Z)), Color3.fromRGB(110, 78, 52), Enum.Material.Wood, true, nil)
	-- A tapered cone: six shrinking tiers, not a fat even stack.
	local tiers = {
		{ y = 2.15, d = 4.6, h = 1.7 },
		{ y = 3.3, d = 3.75, h = 1.6 },
		{ y = 4.4, d = 2.95, h = 1.5 },
		{ y = 5.4, d = 2.2, h = 1.4 },
		{ y = 6.3, d = 1.5, h = 1.25 },
		{ y = 7.05, d = 0.9, h = 1.1 },
	}
	for _, row in ipairs(tiers) do
		bit(tree, "TreeTier", "Cylinder", Vector3.new(row.h * scale, row.d * scale, row.d * scale), stand(CFrame.new(at.X, row.y * scale, at.Z)), leaf, Enum.Material.Grass, false, nil)
	end
	bit(tree, "Snow", "Cylinder", Vector3.new(0.2 * scale, 0.5 * scale, 0.5 * scale), stand(CFrame.new(at.X, 7.65 * scale, at.Z)), snow, Enum.Material.Fabric, false, nil)
	spark(tree, Vector3.new(at.X, 8.05 * scale, at.Z), butter, 1.15)
	local tip = tree:FindFirstChild("StarArm")
	if tip and tip:IsA("BasePart") then
		glow(tip, butter, 0.55, 10)
	end
	local ornaments: { { x: number, y: number, z: number, color: Color3 } } = {
		{ x = 1.9, y = 3.0, z = 1.1, color = coral },
		{ x = -1.7, y = 3.6, z = 1.4, color = butter },
		{ x = 0.9, y = 4.8, z = -1.6, color = lavender },
		{ x = -1.5, y = 5.5, z = 0.9, color = coral },
		{ x = 1.2, y = 6.4, z = -0.7, color = butter },
		{ x = -0.7, y = 7.0, z = 0.8, color = mint },
		{ x = 0.6, y = 2.6, z = -1.8, color = lavender },
		{ x = -1.1, y = 4.2, z = -1.3, color = mint },
	}
	for _, row in ipairs(ornaments) do
		bit(tree, "Bauble", "Ball", Vector3.new(0.55, 0.55, 0.55), CFrame.new(at.X + row.x, row.y * scale * 0.92, at.Z + row.z), row.color, Enum.Material.SmoothPlastic, false, nil)
	end
	gift(tree, Vector3.new(at.X - 1.6, 0, at.Z + 1.3), coral, butter)
	gift(tree, Vector3.new(at.X + 1.5, 0, at.Z + 1.1), mint, lavender)
end

function Plaza.build()
	local existing = Workspace:FindFirstChild("Plaza")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = Workspace

	local cz = -34
	local cream = rgb("cream")
	local coral = rgb("coral")
	local mint = rgb("mint")
	local butter = rgb("butter")
	local lavender = rgb("lavender")
	local ink = rgb("ink")

	bit(folder, "Disc", "Cylinder", Vector3.new(0.7, 56, 56), stand(CFrame.new(0, 0.4, cz)), Color3.fromRGB(245, 250, 255), Enum.Material.Fabric, true, nil)

	for index = 0, 5 do
		local z = -6 - index * 3.2
		local tint = if index % 2 == 0 then butter else mint
		bit(folder, "Path", "Block", Vector3.new(6, 0.35, 2.6), CFrame.new(0, 0.3, z), tint, Enum.Material.SmoothPlastic, true, nil)
	end

	-- Taller, wider sign so the title stays clear above the plaza from spawn.
	bit(folder, "Sign", "Block", Vector3.new(24, 7.2, 0.7), CFrame.new(0, 12.6, cz - 16), cream, Enum.Material.SmoothPlastic, true, nil)
	-- Title is built from letter parts so it also shows in 3D previews.
	bit(folder, "Post", "Cylinder", Vector3.new(9.2, 0.75, 0.75), stand(CFrame.new(-10.2, 4.7, cz - 16)), ink, Enum.Material.Wood, true, nil)
	bit(folder, "Post", "Cylinder", Vector3.new(9.2, 0.75, 0.75), stand(CFrame.new(10.2, 4.7, cz - 16)), ink, Enum.Material.Wood, true, nil)
	spark(folder, Vector3.new(-11.4, 16.4, cz - 15.4), butter, 1.35)
	spark(folder, Vector3.new(11.4, 16.3, cz - 15.4), coral, 1.15)

	local boothX = -16
	bit(folder, "Counter", "Block", Vector3.new(8, 3.2, 3.2), CFrame.new(boothX, 2.2, cz + 2), cream, Enum.Material.Wood, true, nil)
	bit(folder, "CounterTop", "Block", Vector3.new(8.6, 0.35, 3.6), CFrame.new(boothX, 3.9, cz + 2), butter, Enum.Material.Wood, true, nil)
	local awning = bit(folder, "Awning", "Wedge", Vector3.new(8.8, 1.4, 3.4), CFrame.new(boothX, 7.4, cz + 1.2), coral, Enum.Material.Fabric, false, nil)
	glow(awning, coral, 0.4, 10)
	local bell = bit(folder, "Bell", "Ball", Vector3.new(0.8, 0.7, 0.8), CFrame.new(boothX, 4.5, cz + 3.4), butter, Enum.Material.Metal, false, nil)
	glow(bell, butter, 0.3, 7)

	local body = bit(folder, "Auntie", "Cylinder", Vector3.new(2.6, 2.1, 2.1), stand(CFrame.new(boothX, 5.6, cz - 0.4)), lavender, Enum.Material.Fabric, false, nil)
	local head = bit(folder, "Head", "Ball", Vector3.new(1.8, 1.8, 1.8), CFrame.new(boothX, 7.5, cz - 0.4) * CFrame.Angles(0, math.pi, 0), cream, Enum.Material.SmoothPlastic, false, nil)
	local decal = Instance.new("Decal")
	decal.Name = "Face"
	decal.Texture = "rbxasset://textures/face.png"
	decal.Face = Enum.NormalId.Front
	decal.Parent = head
	bit(folder, "Hair", "Ball", Vector3.new(1.9, 1.1, 1.9), CFrame.new(boothX, 8.15, cz - 0.7), Color3.fromRGB(90, 62, 78), Enum.Material.Fabric, false, nil)
	bit(folder, "Scarf", "Block", Vector3.new(1.6, 0.35, 1.7), CFrame.new(boothX, 6.6, cz - 0.2), coral, Enum.Material.Fabric, false, nil)
	bit(folder, "Arm", "Cylinder", Vector3.new(1.5, 0.4, 0.4), stand(CFrame.new(boothX - 1.2, 5.8, cz)), coral, Enum.Material.SmoothPlastic, false, nil)
	bit(folder, "Arm", "Cylinder", Vector3.new(1.5, 0.4, 0.4), stand(CFrame.new(boothX + 1.2, 5.8, cz)), coral, Enum.Material.SmoothPlastic, false, nil)
	local boothSign = bit(folder, "BoothSign", "Block", Vector3.new(6.4, 1.6, 0.3), CFrame.new(boothX, 9.2, cz + 1.6), cream, Enum.Material.SmoothPlastic, false, nil)
	labelOn(boothSign, "Booth", Config.Critic.name, nil, 36)
	glow(body, lavender, 0.3, 8)

	local stage = bit(folder, "Stage", "Cylinder", Vector3.new(1.1, 16, 16), stand(CFrame.new(15, 1.05, cz)), mint, Enum.Material.SmoothPlastic, true, nil)
	glow(stage, mint, 0.25, 12)
	local places = {
		{ rank = 2, x = -4.2, h = 3.1, color = lavender, word = "2nd" },
		{ rank = 1, x = 0, h = 4.6, color = butter, word = "1st" },
		{ rank = 3, x = 4.2, h = 2.4, color = coral, word = "3rd" },
	}
	for _, place in ipairs(places) do
		local baseY = 1.55 + place.h / 2
		local plinth = bit(folder, "Plinth" .. tostring(place.rank), "Block", Vector3.new(3.4, place.h, 3.4), CFrame.new(15 + place.x, baseY, cz), place.color, Enum.Material.SmoothPlastic, true, nil)
		local cap = bit(folder, "PlinthCap", "Cylinder", Vector3.new(0.28, 3.6, 3.6), stand(CFrame.new(15 + place.x, 1.55 + place.h, cz)), cream, Enum.Material.SmoothPlastic, true, nil)
		local plate = bit(folder, "Nameplate", "Block", Vector3.new(2.8, 1.15, 0.2), CFrame.new(15 + place.x, 1.7 + place.h * 0.45, cz + 1.8), cream, Enum.Material.SmoothPlastic, false, nil)
		labelOn(plate, "Place", place.word, place.rank, 40)
		if place.rank == 1 then
			local star = spark(folder, Vector3.new(15, 1.55 + place.h + 0.85, cz), butter, 1.2)
			star.Name = "CrownStar"
			glow(star, butter, 0.5, 10)
			glow(plinth, butter, 0.25, 8)
		end
		cap.Name = "PlinthCap"
	end

	for _, side in ipairs({ -1, 1 }) do
		local x = side * 12
		local pad = bit(folder, "PhotoSpot", "Cylinder", Vector3.new(0.35, 7.2, 7.2), stand(CFrame.new(x, 0.85, -16)), if side < 0 then lavender else coral, Enum.Material.SmoothPlastic, true, nil)
		bit(folder, "PhotoRing", "Cylinder", Vector3.new(0.2, 5.2, 5.2), stand(CFrame.new(x, 1.1, -16)), cream, Enum.Material.Neon, false, 0.15)
		local cam = bit(folder, "Camera", "Block", Vector3.new(1.6, 1.1, 1.2), CFrame.new(x, 2.2, -16), ink, Enum.Material.SmoothPlastic, false, nil)
		bit(folder, "Lens", "Cylinder", Vector3.new(0.4, 0.7, 0.7), CFrame.new(x, 2.25, -15.2) * CFrame.Angles(0, math.rad(90), 0), cream, Enum.Material.Glass, false, 0.15)
		local board = Instance.new("BillboardGui")
		board.Name = "PhotoLabel"
		board.Size = UDim2.fromOffset(140, 40)
		board.StudsOffset = Vector3.new(0, 2.2, 0)
		board.MaxDistance = 80
		board.Parent = pad
		local caption = Instance.new("TextLabel")
		caption.BackgroundColor3 = cream
		caption.Size = UDim2.fromScale(1, 1)
		caption.Font = face()
		caption.Text = UIKit.Icons.spark .. " Photo"
		caption.TextColor3 = ink
		caption.TextSize = 22
		caption.Parent = board
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = caption
		glow(cam, butter, 0.2, 7)
	end

	local lamps = { Vector3.new(-22, 0, -22), Vector3.new(22, 0, -22), Vector3.new(-22, 0, -48), Vector3.new(22, 0, -48) }
	for index, spot in ipairs(lamps) do
		local tint = if index % 2 == 0 then coral else lavender
		bit(folder, "LampPost", "Cylinder", Vector3.new(5.4, 0.45, 0.45), stand(CFrame.new(spot.X, 3.2, spot.Z)), ink, Enum.Material.Metal, true, nil)
		local shade = bit(folder, "LampShade", "Ball", Vector3.new(1.5, 1.2, 1.5), CFrame.new(spot.X, 6.1, spot.Z), tint, Enum.Material.SmoothPlastic, false, 0.05)
		glow(shade, butter, 0.45, 11)
	end

	for index, spot in ipairs({ Vector3.new(-20, 0, cz), Vector3.new(18, 0, cz - 12), Vector3.new(-8, 0, -20), Vector3.new(22, 0, -40) }) do
		bit(folder, "Planter", "Cylinder", Vector3.new(1.3, 1.6, 1.6), stand(CFrame.new(spot.X, 1.2, spot.Z)), cream, Enum.Material.SmoothPlastic, true, nil)
		bit(folder, "Leaf", "Ball", Vector3.new(1.8, 1.6, 1.8), CFrame.new(spot.X, 2.5, spot.Z), mint, Enum.Material.Grass, false, nil)
		local berry = if index % 2 == 0 then coral else butter
		bit(folder, "Berry", "Ball", Vector3.new(0.4, 0.4, 0.4), CFrame.new(spot.X + 0.4, 2.8, spot.Z), berry, Enum.Material.SmoothPlastic, false, nil)
	end

	bit(folder, "Bench", "Block", Vector3.new(4.4, 0.4, 1.5), CFrame.new(-6, 1.5, -18), lavender, Enum.Material.Fabric, true, nil)
	bit(folder, "Bench", "Block", Vector3.new(4.4, 0.4, 1.5), CFrame.new(6, 1.5, -18), coral, Enum.Material.Fabric, true, nil)
	bit(folder, "BenchLeg", "Cylinder", Vector3.new(0.8, 0.3, 0.3), stand(CFrame.new(-7.4, 1.05, -18)), ink, Enum.Material.Wood, true, nil)
	bit(folder, "BenchLeg", "Cylinder", Vector3.new(0.8, 0.3, 0.3), stand(CFrame.new(7.4, 1.05, -18)), ink, Enum.Material.Wood, true, nil)
	bit(folder, "Bench", "Block", Vector3.new(4.4, 0.4, 1.5), CFrame.new(-10, 1.5, cz - 8), mint, Enum.Material.Fabric, true, nil)
	bit(folder, "Bench", "Block", Vector3.new(4.4, 0.4, 1.5), CFrame.new(26, 1.5, cz + 2), butter, Enum.Material.Fabric, true, nil)
	bit(folder, "BenchLeg", "Cylinder", Vector3.new(0.8, 0.3, 0.3), stand(CFrame.new(-11.4, 1.05, cz - 8)), ink, Enum.Material.Wood, true, nil)
	bit(folder, "BenchLeg", "Cylinder", Vector3.new(0.8, 0.3, 0.3), stand(CFrame.new(27.4, 1.05, cz + 2)), ink, Enum.Material.Wood, true, nil)

	-- Title letters sit on the +Z face so they read from the plaza and in 3D previews.
	local words: { string } = {}
	for word in string.gmatch(Config.Title, "%S+") do
		table.insert(words, string.upper(word))
	end
	local top = words[1] or "ROOM"
	local bottom = if #words > 1 then table.concat(words, " ", 2) else ""
	local signCf = CFrame.new(0, 12.6, cz - 15.5)
	writeLine(folder, top, signCf * CFrame.new(0, 1.7, 0), ink, 0.62, 0.36)
	if bottom ~= "" then
		writeLine(folder, bottom, signCf * CFrame.new(0, -1.75, 0), ink, 0.5, 0.36)
	end

	-- Snowy ring, trees, gifts, and paths around the plaza.
	local snow = Color3.fromRGB(245, 250, 255)
	bit(folder, "SnowRing", "Cylinder", Vector3.new(0.7, 64, 64), stand(CFrame.new(0, 0.32, cz)), snow, Enum.Material.Fabric, true, nil)
	for index = 0, 11 do
		local angle = index * math.pi / 6
		local radius = 29
		local x = math.cos(angle) * radius
		local z = cz + math.sin(angle) * radius
		bit(folder, "Drift", "Ball", Vector3.new(4.2, 1.7, 3.0), CFrame.new(x, 0.85, z), snow, Enum.Material.Fabric, false, nil)
		if index % 2 == 0 then
			local tx, tz = x * 1.08, cz + (z - cz) * 1.08
			-- Leave a gap for the side display room and the side tree.
			local nearDisplay = tx < -18 and tz > cz - 16 and tz < cz + 6
			local nearTree = tx > 16 and tz > cz - 22 and tz < cz - 6
			if not (nearDisplay or nearTree) then
				pine(folder, Vector3.new(tx, 0, tz), 1.28, cream, Color3.fromRGB(56, 176, 108), snow)
			end
		end
	end

	for index = 0, 7 do
		local z = 8 + index * 3.4
		local tint = if index % 2 == 0 then cream else snow
		bit(folder, "Path", "Block", Vector3.new(5.2, 0.3, 2.8), CFrame.new(0, 0.28, z), tint, Enum.Material.SmoothPlastic, true, nil)
	end
	for index = 0, 5 do
		local x = 8 + index * 3.2
		bit(folder, "Path", "Block", Vector3.new(2.6, 0.3, 4.4), CFrame.new(x, 0.28, -18), if index % 2 == 0 then mint else cream, Enum.Material.SmoothPlastic, true, nil)
	end

	gift(folder, Vector3.new(-24, 0, cz + 6), coral, butter)
	gift(folder, Vector3.new(-22.2, 0, cz + 7.2), butter, lavender)
	gift(folder, Vector3.new(24, 0, cz - 6), lavender, coral)
	gift(folder, Vector3.new(8, 0, cz + 10), mint, butter)

	-- Candy-cane posts at the path mouth.
	for _, side in ipairs({ -1, 1 }) do
		bit(folder, "Cane", "Cylinder", Vector3.new(4.2, 0.45, 0.45), stand(CFrame.new(side * 4.2, 2.3, 6)), Color3.fromRGB(245, 245, 250), Enum.Material.SmoothPlastic, true, nil)
		bit(folder, "CaneStripe", "Cylinder", Vector3.new(2.2, 0.52, 0.52), stand(CFrame.new(side * 4.2, 1.7, 6)), Color3.fromRGB(220, 50, 70), Enum.Material.SmoothPlastic, false, nil)
	end

	-- String lights on visible cords, only on the sides and front so they never cross the sign.
	local lampY = 6.05
	swag(folder, Vector3.new(-22, lampY, -22), Vector3.new(22, lampY, -22), 1.6, butter, coral, true)
	swag(folder, Vector3.new(-22, lampY, -22), Vector3.new(-22, lampY, -48), 1.2, butter, coral, false)
	swag(folder, Vector3.new(22, lampY, -22), Vector3.new(22, lampY, -48), 1.2, coral, butter, false)
	-- A short garland along the top of the sign, on a visible cord.
	swag(folder, Vector3.new(-11.2, 16.4, cz - 15.3), Vector3.new(11.2, 16.4, cz - 15.3), 0.7, butter, coral, true)

	-- Winner room and tree sit on the sides, leaving a clear aisle to the title.
	heroTree(folder, Vector3.new(24, 0, cz - 14), cream, coral, mint, butter, lavender)

	local dx, dz = -28, cz - 6
	local display = Instance.new("Model")
	display.Name = "DisplayRoom"
	display.Parent = folder
	bit(display, "Floor", "Block", Vector3.new(14, 0.5, 11), CFrame.new(dx, 0.4, dz), Color3.fromRGB(168, 108, 70), Enum.Material.Wood, true, nil)
	bit(display, "FloorB", "Block", Vector3.new(6.6, 0.12, 10.6), CFrame.new(dx - 3.4, 0.68, dz), Color3.fromRGB(138, 86, 54), Enum.Material.WoodPlanks, false, nil)
	bit(display, "BackWall", "Block", Vector3.new(14, 7.6, 0.5), CFrame.new(dx, 4.2, dz - 5.4), Color3.fromRGB(255, 228, 200), Enum.Material.SmoothPlastic, true, nil)
	bit(display, "SideWall", "Block", Vector3.new(0.5, 7.6, 11), CFrame.new(dx - 7.0, 4.2, dz), Color3.fromRGB(255, 214, 184), Enum.Material.SmoothPlastic, true, nil)
	bit(display, "SideWall", "Block", Vector3.new(0.5, 7.6, 11), CFrame.new(dx + 7.0, 4.2, dz), Color3.fromRGB(255, 214, 184), Enum.Material.SmoothPlastic, true, nil)
	local dwin = bit(display, "Window", "Block", Vector3.new(4.8, 3.6, 0.2), CFrame.new(dx, 4.8, dz - 5.15), Color3.fromRGB(226, 240, 248), Enum.Material.Glass, false, 0.3)
	bit(display, "WindowFrame", "Block", Vector3.new(5.5, 4.3, 0.28), CFrame.new(dx, 4.8, dz - 5.3), Color3.fromRGB(255, 186, 173), Enum.Material.Wood, false, nil)
	glow(dwin, Color3.fromRGB(255, 186, 120), 1.1, 20)
	bit(display, "Seat", "Block", Vector3.new(6.4, 1.1, 2.2), CFrame.new(dx, 1.35, dz - 2.8), butter, Enum.Material.Fabric, false, nil)
	bit(display, "Back", "Block", Vector3.new(6.4, 1.8, 0.8), CFrame.new(dx, 2.6, dz - 3.5), butter, Enum.Material.Fabric, false, nil)
	bit(display, "Arm", "Cylinder", Vector3.new(2.2, 0.75, 0.75), stand(CFrame.new(dx - 2.9, 1.8, dz - 2.4)), coral, Enum.Material.SmoothPlastic, false, nil)
	bit(display, "Arm", "Cylinder", Vector3.new(2.2, 0.75, 0.75), stand(CFrame.new(dx + 2.9, 1.8, dz - 2.4)), coral, Enum.Material.SmoothPlastic, false, nil)
	bit(display, "LampBase", "Cylinder", Vector3.new(0.35, 1.2, 1.2), stand(CFrame.new(dx + 4.6, 0.95, dz + 2.2)), Color3.fromRGB(110, 78, 52), Enum.Material.Wood, true, nil)
	local shade = bit(display, "LampShade", "Ball", Vector3.new(1.6, 1.3, 1.6), CFrame.new(dx + 4.6, 2.7, dz + 2.2), coral, Enum.Material.SmoothPlastic, false, 0.05)
	glow(shade, Color3.fromRGB(255, 200, 140), 0.8, 14)
	bit(display, "PlantPot", "Cylinder", Vector3.new(0.85, 0.95, 0.95), stand(CFrame.new(dx - 4.6, 0.95, dz + 2.6)), cream, Enum.Material.SmoothPlastic, true, nil)
	bit(display, "Leaf", "Cylinder", Vector3.new(1.0, 1.5, 1.5), stand(CFrame.new(dx - 4.6, 1.9, dz + 2.6)), mint, Enum.Material.Grass, false, nil)
	bit(display, "Leaf", "Cylinder", Vector3.new(0.85, 1.05, 1.05), stand(CFrame.new(dx - 4.6, 2.6, dz + 2.6)), mint, Enum.Material.Grass, false, nil)
	bit(display, "Wreath", "Cylinder", Vector3.new(0.28, 1.7, 1.7), CFrame.new(dx - 3.8, 5.6, dz - 5.15) * CFrame.Angles(math.rad(90), 0, 0), coral, Enum.Material.SmoothPlastic, false, 0.05)
	bit(display, "ShowSign", "Block", Vector3.new(7.0, 1.3, 0.2), CFrame.new(dx, 3.4, dz + 5.6), cream, Enum.Material.SmoothPlastic, false, nil)
	writeLine(display, "WINNER", CFrame.new(dx, 3.4, dz + 5.75), ink, 0.16, 0.16)

	-- A small metal can above the display, not a floating globe.
	local lamp = bit(folder, "HeroSpot", "Cylinder", Vector3.new(0.9, 0.7, 0.7), CFrame.new(dx, 10.6, dz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(50, 52, 70), Enum.Material.Metal, false, nil)
	glow(lamp, Color3.fromRGB(255, 236, 200), 1.4, 22)
	local beam = Instance.new("SpotLight")
	beam.Name = "SoftLight"
	beam.Face = Enum.NormalId.Bottom
	beam.Angle = 60
	beam.Brightness = 3.2
	beam.Range = 20
	beam.Color = Color3.fromRGB(255, 236, 200)
	beam.Shadows = false
	beam:SetAttribute("SoftB", 3.2)
	beam:SetAttribute("Kind", "key")
	beam.Parent = lamp
end

return Plaza
