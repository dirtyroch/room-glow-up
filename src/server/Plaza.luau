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

	bit(folder, "Disc", "Cylinder", Vector3.new(0.7, 56, 56), stand(CFrame.new(0, 0.4, cz)), Color3.fromRGB(232, 244, 236), Enum.Material.Fabric, true, nil)

	for index = 0, 5 do
		local z = -6 - index * 3.2
		local tint = if index % 2 == 0 then butter else mint
		bit(folder, "Path", "Block", Vector3.new(6, 0.35, 2.6), CFrame.new(0, 0.3, z), tint, Enum.Material.SmoothPlastic, true, nil)
	end

	local sign = bit(folder, "Sign", "Block", Vector3.new(18, 5.2, 0.6), CFrame.new(0, 8.2, cz - 16), cream, Enum.Material.SmoothPlastic, true, nil)
	labelOn(sign, "Title", Config.Title .. "\n" .. Config.SeasonTitle, nil, 64)
	bit(folder, "Post", "Cylinder", Vector3.new(6.2, 0.7, 0.7), stand(CFrame.new(-7.2, 3.2, cz - 16)), ink, Enum.Material.Wood, true, nil)
	bit(folder, "Post", "Cylinder", Vector3.new(6.2, 0.7, 0.7), stand(CFrame.new(7.2, 3.2, cz - 16)), ink, Enum.Material.Wood, true, nil)
	bit(folder, "Star", "Ball", Vector3.new(1.4, 1.4, 1.4), CFrame.new(-8.2, 10.6, cz - 15.4), butter, Enum.Material.Neon, false, nil)
	bit(folder, "Star", "Ball", Vector3.new(1.1, 1.1, 1.1), CFrame.new(8.2, 10.4, cz - 15.4), coral, Enum.Material.Neon, false, nil)

	local boothX = -16
	bit(folder, "Counter", "Block", Vector3.new(8, 3.2, 3.2), CFrame.new(boothX, 2.2, cz + 2), cream, Enum.Material.Wood, true, nil)
	bit(folder, "CounterTop", "Block", Vector3.new(8.6, 0.35, 3.6), CFrame.new(boothX, 3.9, cz + 2), butter, Enum.Material.Wood, true, nil)
	local awning = bit(folder, "Awning", "Wedge", Vector3.new(8.8, 1.4, 3.4), CFrame.new(boothX, 7.4, cz + 1.2), coral, Enum.Material.Fabric, false, nil)
	glow(awning, coral, 0.6, 12)
	local bell = bit(folder, "Bell", "Ball", Vector3.new(0.8, 0.7, 0.8), CFrame.new(boothX, 4.5, cz + 3.4), butter, Enum.Material.Metal, false, nil)
	glow(bell, butter, 0.4, 8)

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
	glow(body, lavender, 0.45, 10)

	local stage = bit(folder, "Stage", "Cylinder", Vector3.new(1.1, 16, 16), stand(CFrame.new(15, 1.05, cz)), mint, Enum.Material.SmoothPlastic, true, nil)
	glow(stage, mint, 0.35, 16)
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
			local star = bit(folder, "CrownStar", "Ball", Vector3.new(0.9, 0.9, 0.9), CFrame.new(15, 1.7 + place.h + 0.7, cz), butter, Enum.Material.Neon, false, nil)
			glow(star, butter, 0.8, 14)
			glow(plinth, butter, 0.35, 10)
		end
		cap.Name = "PlinthCap"
	end

	local burst = bit(folder, "Confetti", "Ball", Vector3.new(1, 1, 1), CFrame.new(15, 8.5, cz), cream, Enum.Material.SmoothPlastic, false, 1)
	burst.CanCollide = false

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
		glow(cam, butter, 0.25, 8)
	end

	local lamps = { Vector3.new(-22, 0, -22), Vector3.new(22, 0, -22), Vector3.new(-22, 0, -48), Vector3.new(22, 0, -48) }
	for index, spot in ipairs(lamps) do
		local tint = if index % 2 == 0 then coral else lavender
		bit(folder, "LampPost", "Cylinder", Vector3.new(5.4, 0.45, 0.45), stand(CFrame.new(spot.X, 3.2, spot.Z)), ink, Enum.Material.Metal, true, nil)
		local shade = bit(folder, "LampShade", "Ball", Vector3.new(1.5, 1.2, 1.5), CFrame.new(spot.X, 6.1, spot.Z), tint, Enum.Material.SmoothPlastic, false, 0.05)
		glow(shade, butter, 0.7, 14)
	end

	for index, spot in ipairs({ Vector3.new(-20, 0, cz), Vector3.new(8, 0, cz - 14), Vector3.new(-8, 0, -20), Vector3.new(22, 0, -40) }) do
		bit(folder, "Planter", "Cylinder", Vector3.new(1.3, 1.6, 1.6), stand(CFrame.new(spot.X, 1.2, spot.Z)), cream, Enum.Material.SmoothPlastic, true, nil)
		bit(folder, "Leaf", "Ball", Vector3.new(1.8, 1.6, 1.8), CFrame.new(spot.X, 2.5, spot.Z), mint, Enum.Material.Grass, false, nil)
		local berry = if index % 2 == 0 then coral else butter
		bit(folder, "Berry", "Ball", Vector3.new(0.4, 0.4, 0.4), CFrame.new(spot.X + 0.4, 2.8, spot.Z), berry, Enum.Material.SmoothPlastic, false, nil)
	end

	bit(folder, "Bench", "Block", Vector3.new(4.4, 0.4, 1.5), CFrame.new(-6, 1.5, -18), lavender, Enum.Material.Fabric, true, nil)
	bit(folder, "Bench", "Block", Vector3.new(4.4, 0.4, 1.5), CFrame.new(6, 1.5, -18), coral, Enum.Material.Fabric, true, nil)
	bit(folder, "BenchLeg", "Cylinder", Vector3.new(0.8, 0.3, 0.3), stand(CFrame.new(-7.4, 1.05, -18)), ink, Enum.Material.Wood, true, nil)
	bit(folder, "BenchLeg", "Cylinder", Vector3.new(0.8, 0.3, 0.3), stand(CFrame.new(7.4, 1.05, -18)), ink, Enum.Material.Wood, true, nil)

	for index = 0, 2 do
		bit(folder, "Cloud", "Ball", Vector3.new(7 - index, 3.2, 4), CFrame.new(-18 + index * 16, 22 + index, cz - 4), cream, Enum.Material.SmoothPlastic, false, 0.18)
	end
end

return Plaza
