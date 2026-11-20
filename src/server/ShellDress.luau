--!strict
-- Room shell finish: textured floors and walls, painted wainscoting, and drapes
-- at the window. Cells stay the placement targets with the same size, Surface
-- attributes and colors, so theme packs and Designer Tools paint still work.
--
-- Each floor/wall cell gets the family's surface (Look.shellStyle):
--   1. a MaterialVariant saved in MaterialService (Meshes.Surfaces.<key>.variant),
--   2. else a Texture overlay when the surface's Image ids are uploaded,
--   3. else the built-in engine material (WoodPlanks, CeramicTiles, Carpet,
--      Plaster), plus thin stripe parts for the striped wallpaper.
-- All three take their color from the part, so paint and theme tints carry over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Look = require(Shared:WaitForChild("Look") :: ModuleScript) :: any
local Bases = require(Shared:WaitForChild("Bases") :: ModuleScript) :: any
local MeshFit = require(Shared:WaitForChild("MeshFit") :: ModuleScript) :: any
local MeshProps = require(script.Parent:WaitForChild("MeshProps") :: ModuleScript) :: any

local ShellDress = {}

local function asMaterial(name: string): Enum.Material?
	local ok, material = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and typeof(material) == "EnumItem" then
		return material :: Enum.Material
	end
	return nil
end

local function variantSaved(name: string): boolean
	local ok, found = pcall(function()
		local service = game:GetService("MaterialService")
		local child = service:FindFirstChild(name)
		return child ~= nil and child:IsA("MaterialVariant")
	end)
	return ok and found == true
end

-- How a surface key renders here: "variant", "texture", or "builtin".
function ShellDress.mode(key: string): string
	local surface = MeshFit.surface(key)
	if surface == nil then
		return "builtin"
	end
	if MeshProps.preview or variantSaved(surface.variant) then
		return "variant"
	end
	if (surface.ids.color or 0) > 0 then
		return "texture"
	end
	return "builtin"
end

local function clearOverlay(part: BasePart)
	local old = part:FindFirstChild("Surf")
	if old then
		old:Destroy()
	end
end

-- Puts one surface on a shell part. face is the side that faces the room.
function ShellDress.surface(part: BasePart, key: string, face: Enum.NormalId)
	local surface = MeshFit.surface(key)
	if surface == nil then
		return
	end
	local base = asMaterial(surface.base)
	if base then
		part.Material = base
	end
	part:SetAttribute("Surf", key)
	local mode = ShellDress.mode(key)
	clearOverlay(part)
	if mode == "variant" then
		pcall(function()
			(part :: any).MaterialVariant = surface.variant
		end)
	else
		pcall(function()
			(part :: any).MaterialVariant = ""
		end)
	end
	if mode == "texture" then
		local tex = Instance.new("Texture")
		tex.Name = "Surf"
		tex.Texture = "rbxassetid://" .. tostring(surface.ids.color)
		tex.Face = face
		tex.StudsPerTileU = surface.studs
		tex.StudsPerTileV = surface.studs
		tex.Color3 = part.Color
		tex.Parent = part
	end
end

-- Keeps Texture overlays in step with a part's color (paint, theme tint).
function ShellDress.sync(part: BasePart)
	local tex = part:FindFirstChild("Surf")
	if tex and tex:IsA("Texture") then
		tex.Color3 = part.Color
	end
end

-- Stripe parts and wainscot boards follow the wall paint a shade deeper/lighter.
function ShellDress.shade(color: Color3, kind: string): Color3
	local h, s, v = color:ToHSV()
	if kind == "stripe" then
		return Color3.fromHSV(h, math.min(1, s * 1.35 + 0.04), v * 0.93)
	elseif kind == "panel" then
		return Color3.fromHSV(h, math.min(1, s * 1.3 + 0.03), v * 0.95)
	elseif kind == "trim" then
		return Color3.fromHSV(h, math.min(1, s * 1.6 + 0.05), v * 0.9)
	end
	return color
end

local function deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p:SetAttribute("ShowT", 0)
	p:SetAttribute("ShowQ", false)
	p:SetAttribute("ShowC", false)
	p.Parent = parent
	return p
end

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local curtainAt: { [Instance]: { cf: CFrame, unit: number } } = setmetatable({}, { __mode = "k" }) :: any

-- One wall run: x along the wall, the room on the +normal side.
type Run = { origin: CFrame, length: number }

local function runs(pivot: CFrame, width: number, depth: number): { Run }
	local planeZ = Bases.wallPlane("room")
	local back = planeZ + 0.275
	return {
		{ origin = pivot * CFrame.new(0, 1, back), length = width },
		-- Left wall: inner face at x = -width/2 - 0.2 + 0.35; local +Z points into the room (+X).
		{ origin = pivot * CFrame.new(-width / 2 + 0.15, 1, 0) * CFrame.Angles(0, math.rad(90), 0), length = depth },
		{ origin = pivot * CFrame.new(width / 2 - 0.15, 1, 0) * CFrame.Angles(0, math.rad(-90), 0), length = depth },
	}
end

local RAIL = 4.4

-- Builds the dress parts once; restyle() shows the right ones per family.
function ShellDress.dress(shellModel: Model, pivot: CFrame, width: number, depth: number, height: number, unit: number)
	local folder = Instance.new("Folder")
	folder.Name = "Dress"
	folder.Parent = shellModel
	local cream = rgb(Look.pack("hearth").cream)
	local wall = rgb(Look.pack("hearth").wallA)
	for index, run in ipairs(runs(pivot, width, depth)) do
		local len = run.length - (if index == 1 then 0.9 else 1.2)
		-- Wainscoting: a board, a chair rail, and stiles every half cell.
		local board = deco(folder, "Wainscot", Vector3.new(len, RAIL - 0.72, 0.1), run.origin * CFrame.new(0, 0.72 + (RAIL - 0.72) / 2, 0.06), cream, Enum.Material.SmoothPlastic)
		board:SetAttribute("Shell", "cream")
		board:SetAttribute("Dress", "wainscot")
		local rail = deco(folder, "ChairRail", Vector3.new(len, 0.26, 0.28), run.origin * CFrame.new(0, RAIL, 0.14), ShellDress.shade(cream, "trim"), Enum.Material.SmoothPlastic)
		rail:SetAttribute("Shell", "cream")
		rail:SetAttribute("Tone", "trim")
		rail:SetAttribute("Dress", "wainscot")
		-- Raised panels: inset rectangles a shade deeper, the board shows as the frame.
		local panels = math.max(2, math.floor(len / (unit / 2)))
		local pw = len / panels
		local ph = RAIL - 0.72 - 0.8
		for k = 0, panels - 1 do
			local x = -len / 2 + (k + 0.5) * pw
			local panel = deco(folder, "Panel", Vector3.new(pw - 0.55, ph, 0.05), run.origin * CFrame.new(x, 0.72 + 0.4 + ph / 2, 0.13), ShellDress.shade(cream, "panel"), Enum.Material.SmoothPlastic)
			panel:SetAttribute("Shell", "cream")
			panel:SetAttribute("Tone", "panel")
			panel:SetAttribute("Dress", "wainscot")
		end
		-- Wallpaper stripes (only shown on the built-in fallback).
		local count = math.floor(len / 2.4)
		for k = 0, count - 1 do
			local x = -len / 2 + (k + 0.5) * len / count
			local stripe = deco(folder, "Stripe", Vector3.new(0.85, height - 0.9, 0.03), run.origin * CFrame.new(x, 0.3 + (height - 0.9) / 2, 0.02), wall, Enum.Material.Plaster)
			stripe:SetAttribute("Paint", "wall")
			stripe:SetAttribute("Shade", "stripe")
			stripe:SetAttribute("Dress", "stripe")
		end
	end
	-- Drapes at the back window: mesh when ready, otherwise gathered fabric parts.
	local planeZ = Bases.wallPlane("room")
	local winW = math.clamp(width * 0.36, 4, 9)
	local winH = math.clamp(height * 0.42, 3.5, 7)
	local winY = 1 + height * 0.58
	local rodY = math.min(winY + winH / 2 + 1.3, 1 + height - 1.0)
	local entry = MeshFit.shell("curtains")
	if entry then
		local k = unit / MeshFit.refCell()
		local size = entry.size
		local top = entry.center[2] + size[2] / 2
		curtainAt[folder] = {
			cf = pivot * CFrame.new(0, rodY - (top - entry.center[2]) * k, planeZ + 0.275 + 0.05 + size[3] * k / 2),
			unit = unit,
		}
	end
	local cloth = rgb(Look.pack("hearth").cloth)
	local brass = Color3.fromRGB(222, 184, 112)
	local rodLen = winW + 2 * 2.6 + 1.2
	local rodZ = planeZ + 0.275 + 0.5
	local rod = deco(folder, "Rod", Vector3.new(rodLen, 0.18, 0.18), pivot * CFrame.new(0, rodY, rodZ), brass, Enum.Material.Metal)
	rod.Shape = Enum.PartType.Cylinder
	rod:SetAttribute("Dress", "drape")
	for _, side in ipairs({ -1, 1 }) do
		local ball = deco(folder, "Finial", Vector3.new(0.4, 0.4, 0.4), pivot * CFrame.new(side * rodLen / 2, rodY, rodZ), brass, Enum.Material.Metal)
		ball.Shape = Enum.PartType.Ball
		ball:SetAttribute("Dress", "drape")
		local x0 = side * (winW / 2 + 0.2 + 1.25)
		local length = rodY - 1.2
		for f = -2, 2 do
			local fold = deco(
				folder,
				"Drape",
				Vector3.new(length, 0.52, 0.52),
				pivot * CFrame.new(x0 + f * 0.48, rodY - 0.15 - length / 2, rodZ - 0.05 + (if f % 2 == 0 then 0.06 else -0.06)) * CFrame.Angles(0, 0, math.rad(90)),
				cloth,
				Enum.Material.Fabric
			)
			fold.Shape = Enum.PartType.Cylinder
			fold:SetAttribute("Shell", "cloth")
			fold:SetAttribute("Dress", "drape")
		end
	end
end

local FACES = {
	floor = Enum.NormalId.Top,
}

-- Puts the drape mesh up when one is ready; the part drapes hide behind it.
local function hang(plot: Instance, color: Color3): boolean
	local folder = plot:FindFirstChild("Dress")
	if folder == nil then
		return false
	end
	if folder:FindFirstChild("ShellMesh") then
		return true
	end
	local spot = curtainAt[folder]
	if spot == nil then
		return false
	end
	local mesh = MeshProps.shellPiece("curtains", folder, spot.cf, spot.unit, color)
	if mesh then
		mesh:SetAttribute("Shell", "cloth")
		return true
	end
	return false
end

-- Applies the family's floor/wall surfaces and shows the matching dress parts.
function ShellDress.restyle(plot: Instance, family: string)
	local style = Look.shellStyle(family)
	local wallMode = ShellDress.mode(style.wall)
	local hung = hang(plot, rgb(Look.pack(family).cloth))
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") then
			local surface = child:GetAttribute("Surface")
			local sideWall = child:GetAttribute("SideWall")
			if surface == "floor" then
				ShellDress.surface(child, style.floor, FACES.floor)
			elseif surface == "wall" then
				ShellDress.surface(child, style.wall, Enum.NormalId.Back)
			elseif sideWall == -1 then
				ShellDress.surface(child, style.wall, Enum.NormalId.Right)
			elseif sideWall == 1 then
				ShellDress.surface(child, style.wall, Enum.NormalId.Left)
			end
			local dress = child:GetAttribute("Dress")
			if dress == "wainscot" then
				child.Transparency = if style.wainscot then 0 else 1
				child:SetAttribute("ShowT", child.Transparency)
			elseif dress == "drape" then
				child.Transparency = if hung then 1 else 0
				child:SetAttribute("ShowT", child.Transparency)
			elseif dress == "stripe" then
				child.Transparency = if style.wall == "stripe" and wallMode == "builtin" then 0 else 1
				child:SetAttribute("ShowT", child.Transparency)
			end
			ShellDress.sync(child)
		end
	end
end

return ShellDress
