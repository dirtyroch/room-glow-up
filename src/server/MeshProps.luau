--!strict
-- Real furniture meshes (assets/meshes, built by tools/meshes). One MeshPart per
-- item with a TintMask SurfaceAppearance, so the palette recolor tints the fabric
-- or paint and leaves wood, metal and glass alone.
--
-- An item only switches to its mesh after scripts/upload-meshes.luau has written
-- its asset ids (the FBX Model and the Image maps) into Shared.Meshes and the
-- template loaded at boot. Until then (ids 0) Props builds the part version,
-- with the same root, cell and hitbox.
-- Templates come from ServerStorage.MeshTemplates.<id> when a MeshPart with
-- a SurfaceAppearance was saved there in Studio, or else are made at boot with
-- AssetService. A failed load keeps the part version for that item.
-- Room shell pieces (curtains) use the same rules with Meshes.Shell.
--
-- Finish: the SurfaceAppearance tint moves toward the material look right away.
-- With the variant maps uploaded (ids satinR, metalR, ...) or saved in Studio as
-- extra SurfaceAppearances named Finish_<Name> under the template, the
-- roughness/metalness swap too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeshFit = require(Shared:WaitForChild("MeshFit") :: ModuleScript) :: any

local MeshProps = {}

-- Offline stills only (scripts/dump_previews.luau): build a plain MeshPart stand-in
-- tagged with the item id, even with ids 0. Never set in the game.
MeshProps.preview = false

local templates: { [string]: MeshPart } = {}
local finishLooks: { [string]: { [string]: SurfaceAppearance } } = {}
local loaded = false

local function fromStorage(id: string): MeshPart?
	local ok, found = pcall(function()
		local storage = game:GetService("ServerStorage")
		local folder = storage:FindFirstChild("MeshTemplates")
		local child = folder and folder:FindFirstChild(id)
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

local function makeLook(ids: any, rough: number?, metal: number?): SurfaceAppearance
	local AssetService = game:GetService("AssetService") :: any
	local maps: { [string]: any } = { ColorMap = Content.fromAssetId(ids.color) }
	if (ids.normal or 0) > 0 then
		maps.NormalMap = Content.fromAssetId(ids.normal)
	end
	local r = rough or ids.roughness or 0
	if r > 0 then
		maps.RoughnessMap = Content.fromAssetId(r)
	end
	local m = metal or ids.metalness or 0
	if m > 0 then
		maps.MetalnessMap = Content.fromAssetId(m)
	end
	if (ids.emissive or 0) > 0 then
		maps.EmissiveMask = Content.fromAssetId(ids.emissive)
	end
	local look = AssetService:CreateSurfaceAppearanceAsync(maps)
	look.AlphaMode = Enum.AlphaMode.TintMask
	if (ids.emissive or 0) > 0 then
		look.EmissiveStrength = 1
	end
	return look
end

local function fromAssets(entry: any): MeshPart?
	local ok, part = pcall(function()
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
		makeLook(ids, nil, nil).Parent = meshPart
		return meshPart
	end)
	if ok and part then
		return part
	end
	warn("[MeshProps] mesh load failed, keeping parts: " .. tostring(part))
	return nil
end

-- Finish variant looks for one item, from Studio (Finish_<Name>) or ids.
local function loadFinishes(id: string, entry: any, template: MeshPart)
	local looks: { [string]: SurfaceAppearance } = {}
	for name, spec in pairs(MeshFit.Finishes) do
		local saved = template:FindFirstChild("Finish_" .. name)
		if saved and saved:IsA("SurfaceAppearance") then
			saved.Parent = nil
			looks[name] = saved
		elseif spec.rough and entry.ids and (entry.ids[spec.rough] or 0) > 0 then
			local ok, look = pcall(makeLook, entry.ids, entry.ids[spec.rough], if spec.metal then entry.ids[spec.metal] else nil)
			if ok and look then
				look.Name = "Finish_" .. name
				looks[name] = look
			end
		end
	end
	finishLooks[id] = looks
end

local function prepare(template: MeshPart)
	template.Anchored = true
	template.CanCollide = false
	template.CanTouch = false
	template.CanQuery = true
	template.CastShadow = true
end

-- Loads every uploaded mesh once. Yields only when some ids are set.
function MeshProps.preload()
	if loaded then
		return
	end
	loaded = true
	for _, itemId in ipairs(MeshFit.ids()) do
		local entry = MeshFit.entry(itemId)
		local template = fromStorage(itemId)
		if template == nil and MeshFit.uploaded(entry) then
			template = fromAssets(entry)
		end
		if template then
			prepare(template)
			templates[itemId] = template
			loadFinishes(itemId, entry, template)
		end
	end
	for _, key in ipairs(MeshFit.shellIds()) do
		local entry = MeshFit.shell(key)
		local template = fromStorage(key)
		if template == nil and MeshFit.uploaded(entry) then
			template = fromAssets(entry)
		end
		if template then
			prepare(template)
			template.CanQuery = false
			template.CastShadow = false
			templates["shell:" .. key] = template
		end
	end
end

function MeshProps.ready(itemId: string): boolean
	if MeshProps.preview then
		return MeshFit.entry(itemId) ~= nil
	end
	return (templates[itemId] :: any) ~= nil
end

local function finishOf(model: Instance): string?
	local name = model:GetAttribute("Material")
	if type(name) == "string" then
		return name
	end
	return nil
end

local function tintOf(main: Color3, finish: string?): Color3
	local r, g, b = MeshFit.finishTint(main.R, main.G, main.B, finish)
	return Color3.new(r, g, b)
end

local function newPart(template: MeshPart?): MeshPart
	if template then
		return template:Clone()
	end
	local piece = Instance.new("MeshPart")
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = true
	return piece
end

-- Builds the mesh into the prop model. Returns false to fall back to parts.
function MeshProps.build(model: Model, cf: CFrame, item: any, sy: number, unit: number, main: Color3): boolean
	local entry = MeshFit.entry(item.id)
	if entry == nil or not MeshProps.ready(item.id) then
		return false
	end
	local piece = newPart(templates[item.id])
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
		(look :: any).Color = tintOf(main, nil)
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

local function meshes(model: Instance): { MeshPart }
	local out: { MeshPart } = {}
	for _, child in model:GetDescendants() do
		if child.ClassName == "MeshPart" and child:GetAttribute("MeshItem") ~= nil then
			table.insert(out, child :: MeshPart)
		end
	end
	return out
end

function MeshProps.recolor(model: Model, main: Color3)
	local finish = finishOf(model)
	for _, piece in meshes(model) do
		local look = piece:FindFirstChildOfClass("SurfaceAppearance")
		if look then
			(look :: any).Color = tintOf(main, finish)
		end
	end
end

-- Applies a Designer Tools finish to the mesh pieces. Returns how many changed.
function MeshProps.finish(model: Model, name: string): number
	local spec = MeshFit.finish(name)
	local changed = 0
	for _, piece in meshes(model) do
		local itemId = piece:GetAttribute("MeshItem")
		local looks = if type(itemId) == "string" then finishLooks[itemId] else nil
		local variant = looks and looks[name]
		local current: Instance? = piece:FindFirstChildOfClass("SurfaceAppearance")
		local template: MeshPart? = if type(itemId) == "string" then templates[itemId] else nil
		if variant then
			if current then
				current:Destroy()
			end
			local fresh = (variant :: SurfaceAppearance):Clone()
			fresh.Parent = piece
			current = fresh
		elseif current and name == "Fabric" and template then
			local base = template:FindFirstChildOfClass("SurfaceAppearance")
			if base and current.Name ~= base.Name then
				current:Destroy()
				local fresh = base:Clone()
				fresh.Parent = piece
				current = fresh
			end
		end
		if current then
			(current :: any).Color = tintOf(piece.Color, name)
		end
		piece.Transparency = spec.transparency
		piece:SetAttribute("ShowT", spec.transparency)
		piece:SetAttribute("Finish", name)
		changed += 1
	end
	return changed
end

-- Room shell mesh (curtains). Returns the MeshPart, or nil to build parts.
function MeshProps.shellPiece(key: string, parent: Instance, cf: CFrame, unit: number, color: Color3): MeshPart?
	local entry = MeshFit.shell(key)
	if entry == nil then
		return nil
	end
	local template = templates["shell:" .. key]
	if (template :: any) == nil and not MeshProps.preview then
		return nil
	end
	local piece = newPart(template)
	local k = unit / MeshFit.refCell()
	piece.Name = "ShellMesh"
	piece.Size = Vector3.new(entry.size[1] * k, entry.size[2] * k, entry.size[3] * k)
	piece.CFrame = cf
	piece.Color = color
	piece.CanQuery = false
	piece.CastShadow = false
	piece:SetAttribute("MeshItem", key)
	piece:SetAttribute("ShellMesh", key)
	local look = piece:FindFirstChildOfClass("SurfaceAppearance")
	if look then
		(look :: any).Color = tintOf(color, nil)
	end
	piece.Parent = parent
	return piece
end

function MeshProps.tintShellPiece(piece: Instance, color: Color3)
	if piece.ClassName ~= "MeshPart" then
		return
	end
	(piece :: MeshPart).Color = color
	local look = piece:FindFirstChildOfClass("SurfaceAppearance")
	if look then
		(look :: any).Color = tintOf(color, nil)
	end
end

return MeshProps
