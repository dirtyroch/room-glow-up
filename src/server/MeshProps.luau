--!strict
-- Real furniture meshes (assets/meshes, built by tools/meshes). One MeshPart per
-- item with a TintMask SurfaceAppearance, so the palette recolor tints the fabric
-- or paint and leaves wood, metal and glass alone.
--
-- An item only switches to its mesh after scripts/upload-meshes.luau has written
-- its asset ids (the FBX Model and the Image maps) into Shared.Meshes and the template loaded at boot. Until then
-- (ids 0) Props builds the part version, with the same root, cell and hitbox.
-- Templates come from ServerStorage.MeshTemplates.<itemId> when a MeshPart with
-- a SurfaceAppearance was saved there in Studio, or else are made at boot with
-- AssetService. A failed load keeps the part version for that item.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeshFit = require(Shared:WaitForChild("MeshFit") :: ModuleScript) :: any

local MeshProps = {}

-- Offline stills only (scripts/dump_previews.luau): build a plain MeshPart stand-in
-- tagged with the item id, even with ids 0. Never set in the game.
MeshProps.preview = false

local templates: { [string]: MeshPart } = {}
local loaded = false

local function fromStorage(itemId: string): MeshPart?
	local ok, found = pcall(function()
		local storage = game:GetService("ServerStorage")
		local folder = storage:FindFirstChild("MeshTemplates")
		local child = folder and folder:FindFirstChild(itemId)
		if child and child:IsA("MeshPart") and child:FindFirstChildOfClass("SurfaceAppearance") then
			return child
		end
		return nil
	end)
	if ok then
		return found
	end
	return nil
end

local function fromAssets(entry: any): MeshPart?
	local ok, part = pcall(function()
		local AssetService = game:GetService("AssetService") :: any
		local InsertService = game:GetService("InsertService")
		local ids = entry.ids
		-- The Open Cloud FBX upload is a Model holding one MeshPart.
		local container = InsertService:LoadAsset(ids.model)
		local meshPart = container:FindFirstChildWhichIsA("MeshPart", true) :: MeshPart
		meshPart.Parent = nil
		for _, old in meshPart:GetChildren() do
			old:Destroy()
		end
		container:Destroy()
		local maps: { [string]: any } = { ColorMap = Content.fromAssetId(ids.color) }
		if ids.normal > 0 then
			maps.NormalMap = Content.fromAssetId(ids.normal)
		end
		if ids.roughness > 0 then
			maps.RoughnessMap = Content.fromAssetId(ids.roughness)
		end
		if ids.metalness > 0 then
			maps.MetalnessMap = Content.fromAssetId(ids.metalness)
		end
		if ids.emissive > 0 then
			maps.EmissiveMask = Content.fromAssetId(ids.emissive)
		end
		local look = AssetService:CreateSurfaceAppearanceAsync(maps)
		look.AlphaMode = Enum.AlphaMode.TintMask
		if ids.emissive > 0 then
			look.EmissiveStrength = 1
		end
		look.Parent = meshPart
		return meshPart
	end)
	if ok and part then
		return part
	end
	warn("[MeshProps] mesh load failed, keeping parts: " .. tostring(part))
	return nil
end

-- Loads every uploaded mesh once. Yields only when some ids are set.
function MeshProps.preload()
	if loaded then
		return
	end
	loaded = true
	for _, itemId in ipairs(MeshFit.ids()) do
		local entry = MeshFit.entry(itemId)
		if MeshFit.uploaded(entry) then
			local template = fromStorage(itemId) or fromAssets(entry)
			if template then
				template.Anchored = true
				template.CanCollide = false
				template.CanTouch = false
				template.CanQuery = true
				template.CastShadow = true
				templates[itemId] = template
			end
		end
	end
end

function MeshProps.ready(itemId: string): boolean
	if MeshProps.preview then
		return MeshFit.entry(itemId) ~= nil
	end
	return templates[itemId] ~= nil
end

local function tintOf(main: Color3): Color3
	local r, g, b = MeshFit.tint(main.R, main.G, main.B)
	return Color3.new(r, g, b)
end

-- Builds the mesh into the prop model. Returns false to fall back to parts.
function MeshProps.build(model: Model, cf: CFrame, item: any, sy: number, unit: number, main: Color3): boolean
	local entry = MeshFit.entry(item.id)
	if entry == nil or not MeshProps.ready(item.id) then
		return false
	end
	local piece: MeshPart
	local template = templates[item.id]
	if template then
		piece = template:Clone()
	else
		piece = Instance.new("MeshPart")
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanTouch = false
		piece.CanQuery = true
	end
	local w, h, d, ox, oy, oz = MeshFit.fit(entry, sy, unit)
	piece.Name = "Mesh"
	piece.Size = Vector3.new(w, h, d)
	piece.CFrame = cf * CFrame.new(ox, oy, oz)
	piece.Color = main
	piece:SetAttribute("Tint", true)
	piece:SetAttribute("MeshItem", item.id)
	piece:SetAttribute("ShowT", 0)
	piece:SetAttribute("ShowQ", true)
	piece:SetAttribute("ShowC", false)
	local look = piece:FindFirstChildOfClass("SurfaceAppearance")
	if look then
		(look :: any).Color = tintOf(main)
	end
	piece.Parent = model
	if entry.light then
		local lx, ly, lz = MeshFit.light(entry, sy, unit)
		local spot = Instance.new("Attachment")
		spot.Name = "Bulb"
		spot.Position = Vector3.new(lx, ly, lz) - Vector3.new(ox, oy, oz)
		spot.Parent = piece
		local glow = Instance.new("PointLight")
		glow.Name = "SoftLight"
		local c = entry.light.color
		glow.Color = if c then Color3.fromRGB(c[1], c[2], c[3]) else Color3.fromRGB(255, 226, 180)
		glow.Brightness = entry.light.brightness
		glow.Range = entry.light.range
		glow.Shadows = false
		glow:SetAttribute("SoftB", entry.light.brightness)
		glow:SetAttribute("Kind", "bulb")
		glow.Parent = spot
	end
	model:SetAttribute("Mesh", true)
	return true
end

function MeshProps.recolor(model: Model, main: Color3)
	for _, child in model:GetDescendants() do
		if child:IsA("SurfaceAppearance") then
			(child :: any).Color = tintOf(main)
		end
	end
end

return MeshProps
