--!strict
-- Phone-first grid placement. Touch and mouse tap or drag. Keyboard and gamepad
-- move the same cursor. The server still decides whether a prop is allowed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent.Net)
local Tray = require(script.Parent.Tray)
local UI = require(script.Parent.UI)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bases = require(Shared:WaitForChild("Bases") :: ModuleScript) :: any
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Items = require(Shared:WaitForChild("Items") :: ModuleScript) :: any

local Place = {}

local selectedId: string? = nil
local selectedPiece: number? = nil
local aimSurface = "floor"
local aimX = 0
local aimZ = 0
local busy = false

local function roundFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("RoundState")
end

local function roundType(): string
	local folder = roundFolder()
	local value = if folder then folder:GetAttribute("RoundType") else nil
	if type(value) == "string" and value ~= "" then
		return value
	end
	return "room"
end

local function atHome(): boolean
	local folder = roundFolder()
	local player = Players.LocalPlayer
	return folder ~= nil and folder:GetAttribute("Phase") == "Lobby" and player:GetAttribute("AtHome") == true
end

local function gridKind(): string
	local grid = Players.LocalPlayer:GetAttribute("Grid")
	if type(grid) == "string" and grid ~= "" then
		return grid
	end
	return roundType()
end

local function canEdit(): boolean
	if atHome() then
		return true
	end
	local folder = roundFolder()
	if not folder or folder:GetAttribute("Phase") ~= "Build" then
		return false
	end
	local player = Players.LocalPlayer
	if player:GetAttribute("Spectating") == true or player:GetAttribute("BuildDone") == true then
		return false
	end
	return true
end

local function myPlot(): Model?
	local player = Players.LocalPlayer
	local index = player:GetAttribute("BuildPlot")
	if type(index) ~= "number" then
		index = player:GetAttribute("Plot")
	end
	if type(index) ~= "number" then
		return nil
	end
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	local model = plots:FindFirstChild("Plot" .. tostring(index))
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

local function surfaces(): { string }
	local kind = gridKind()
	if kind == "gingerbread" or kind == "duo_gingerbread" then
		return { "wall", "roof" }
	end
	if kind == "tree" then
		return { "hook" }
	end
	return { "floor", "wall" }
end

local function clampAim()
	local options = surfaces()
	local known = false
	for _, name in ipairs(options) do
		if name == aimSurface then
			known = true
		end
	end
	if not known then
		aimSurface = options[1]
	end
	if aimSurface == "hook" then
		aimZ = 0
		if aimX < 1 then
			aimX = 1
		end
		if aimX > Bases.HookCount then
			aimX = Bases.HookCount
		end
		return
	end
	local grid = Bases.grid(gridKind(), aimSurface)
	if not grid then
		aimX = 0
		aimZ = 0
		return
	end
	if aimX < 0 then
		aimX = 0
	end
	if aimZ < 0 then
		aimZ = 0
	end
	if aimX > grid.x - 1 then
		aimX = grid.x - 1
	end
	if aimZ > grid.z - 1 then
		aimZ = grid.z - 1
	end
end

local function note(text: string)
	Tray.setNote(text)
end

local preview: Part? = nil

local function ensurePreview(): Part
	if preview and preview.Parent then
		return preview
	end
	local part = Instance.new("Part")
	part.Name = "PlacementPreview"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 0.45
	part.CastShadow = false
	preview = part
	return part
end

local function hidePreview()
	if preview then
		preview.Parent = nil
	end
end

local function showPreview()
	if not canEdit() then
		hidePreview()
		return
	end
	local plot = myPlot()
	if not plot or not plot.PrimaryPart then
		hidePreview()
		return
	end
	clampAim()
	local item = if selectedId then Items.get(selectedId) else nil
	local w = 1
	local d = 1
	local h = 0.2
	local surface = aimSurface
	if item and item.surface == surface then
		w = item.w
		d = item.d
		h = item.h
	end
	local spot = Bases.pivot(gridKind(), surface, aimX, aimZ, 0, w, d, h)
	if not spot then
		hidePreview()
		return
	end
	local unit = Bases.worldCell()
	local part = ensurePreview()
	part.Color = if item then UI.rgb(item.color) else UI.rgb("butter")
	if surface == "hook" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(2.4, 2.4, 2.4)
	elseif surface == "wall" then
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(w * unit * 0.92, d * unit * 0.92, 0.4)
	else
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(w * unit * 0.92, math.max(0.3, h * unit), d * unit * 0.92)
	end
	part.CFrame = plot.PrimaryPart.CFrame * CFrame.new(spot.x, spot.y, spot.z)
	part.Parent = plot
end

local function describe(hit: RaycastResult): any
	local current: Instance? = hit.Instance
	while current and current ~= Workspace do
		local pieceId = current:GetAttribute("PlacementId")
		if type(pieceId) == "number" then
			return { kind = "piece", id = pieceId }
		end
		local surface = current:GetAttribute("Surface")
		local x = current:GetAttribute("CellX")
		local z = current:GetAttribute("CellZ")
		if type(surface) == "string" and type(x) == "number" and type(z) == "number" then
			return { kind = "cell", surface = surface, x = x, z = z }
		end
		current = current.Parent
	end
	return nil
end

local function rayAt(screenPos: Vector2): any
	local camera = Workspace.CurrentCamera
	local plot = myPlot()
	if not camera or not plot then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plot }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not hit then
		return nil
	end
	return describe(hit)
end

local function aimAt(info: any)
	if type(info) ~= "table" or info.kind ~= "cell" then
		return false
	end
	aimSurface = info.surface
	aimX = info.x
	aimZ = info.z
	clampAim()
	showPreview()
	return true
end

local function placeNow()
	if busy or not canEdit() or not selectedId then
		if canEdit() and not selectedId then
			note("Tap an item first.")
		end
		return
	end
	busy = true
	local ok, msg, id = Net.act("Place", selectedId, aimX, aimZ)
	busy = false
	if msg and msg ~= "" then
		note(msg)
	end
	if ok and id then
		selectedPiece = id
	end
	showPreview()
end

function Place.choose(itemId: string)
	selectedId = itemId
	local item = Items.get(itemId)
	if item then
		aimSurface = item.surface
		clampAim()
	end
	Tray.mark(itemId)
	local kind = roundType()
	if kind == "tree" then
		note("Now tap a hook.")
	elseif kind == "gingerbread" then
		note("Now tap the house.")
	else
		note("Now tap a square.")
	end
	showPreview()
end

function Place.placeAt(itemId: string, screenPos: Vector2)
	Place.choose(itemId)
	local info = rayAt(screenPos)
	if info and info.kind == "cell" then
		aimAt(info)
		placeNow()
	end
end

local function requirePiece(): boolean
	if not selectedPiece then
		note("Tap a placed item first.")
		return false
	end
	return true
end

function Place.rotate()
	if not canEdit() or busy or not requirePiece() then
		return
	end
	busy = true
	local ok, msg = Net.act("Rotate", selectedPiece)
	busy = false
	if msg and msg ~= "" then
		note(msg)
	end
	if not ok then
		return
	end
end

function Place.recolor()
	if not canEdit() or busy or not requirePiece() then
		return
	end
	local current = "cream"
	local plot = myPlot()
	if plot then
		local folder = plot:FindFirstChild("Items")
		local model = if folder then folder:FindFirstChild("P" .. tostring(selectedPiece)) else nil
		if model then
			local colorName = model:GetAttribute("Color")
			if type(colorName) == "string" then
				current = colorName
			end
		end
	end
	local palette = Config.Palette
	local nextColor = palette[1]
	for index, name in ipairs(palette) do
		if name == current then
			nextColor = palette[(index % #palette) + 1]
		end
	end
	busy = true
	local ok, msg = Net.act("Recolor", selectedPiece, nextColor)
	busy = false
	if msg and msg ~= "" then
		note(msg)
	end
	if not ok then
		return
	end
end

function Place.delete()
	if not canEdit() or busy or not requirePiece() then
		return
	end
	busy = true
	local ok, msg = Net.act("Delete", selectedPiece)
	busy = false
	if msg and msg ~= "" then
		note(msg)
	end
	if ok then
		selectedPiece = nil
	end
end

function Place.undo()
	if not canEdit() or busy then
		return
	end
	busy = true
	local ok, msg, id = Net.act("Undo")
	busy = false
	if msg and msg ~= "" then
		note(msg)
	end
	if ok and id then
		selectedPiece = id
	end
end

local function nudge(dx: number, dz: number)
	if aimSurface == "hook" then
		aimX += if dx ~= 0 then dx else dz
	else
		aimX += dx
		aimZ += dz
	end
	clampAim()
	showPreview()
end

local function cycleSurface()
	local options = surfaces()
	local index = 1
	for i, name in ipairs(options) do
		if name == aimSurface then
			index = i
		end
	end
	aimSurface = options[(index % #options) + 1]
	clampAim()
	showPreview()
end

local function onWorld(screenPos: Vector2)
	if not canEdit() then
		return
	end
	local info = rayAt(screenPos)
	if not info then
		return
	end
	if info.kind == "piece" then
		selectedPiece = info.id
		note("Use Rotate, Color, or Delete.")
		return
	end
	aimAt(info)
	if selectedId then
		placeNow()
	else
		note("Tap an item first.")
	end
end

function Place.start()
	Tray.setActions({
		choose = Place.choose,
		rotate = Place.rotate,
		recolor = Place.recolor,
		delete = Place.delete,
		undo = Place.undo,
		placeAt = Place.placeAt,
	})

	local lastStick = 0
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed and input.UserInputType == Enum.UserInputType.Keyboard then
			return
		end
		if not canEdit() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if processed then
				return
			end
			onWorld(Vector2.new(input.Position.X, input.Position.Y))
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonX then
			Place.rotate()
		elseif key == Enum.KeyCode.C or key == Enum.KeyCode.ButtonY then
			Place.recolor()
		elseif key == Enum.KeyCode.Z or key == Enum.KeyCode.ButtonL2 then
			Place.undo()
		elseif key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB then
			Place.delete()
		elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonA then
			placeNow()
		elseif key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonR2 then
			cycleSurface()
		elseif key == Enum.KeyCode.Left or key == Enum.KeyCode.DPadLeft then
			nudge(-1, 0)
		elseif key == Enum.KeyCode.Right or key == Enum.KeyCode.DPadRight then
			nudge(1, 0)
		elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.DPadUp then
			nudge(0, 1)
		elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.DPadDown then
			nudge(0, -1)
		elseif key == Enum.KeyCode.ButtonL1 or key == Enum.KeyCode.ButtonR1 then
			local list = Items.forRound(roundType())
			if #list == 0 then
				return
			end
			local index = 0
			for i, item in ipairs(list) do
				if item.id == selectedId then
					index = i
				end
			end
			local step = if key == Enum.KeyCode.ButtonL1 then -1 else 1
			local nxt = list[((index - 1 + step) % #list) + 1]
			if nxt then
				Place.choose(nxt.id)
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.Thumbstick1 or not canEdit() then
			return
		end
		local now = os.clock()
		if now - lastStick < 0.18 then
			return
		end
		local stick = input.Position
		if math.abs(stick.X) < 0.55 and math.abs(stick.Y) < 0.55 then
			return
		end
		lastStick = now
		if math.abs(stick.X) > math.abs(stick.Y) then
			nudge(if stick.X > 0 then 1 else -1, 0)
		else
			nudge(0, if stick.Y > 0 then 1 else -1)
		end
	end)

	local folder = roundFolder()
	if folder then
		folder:GetAttributeChangedSignal("RoundType"):Connect(function()
			aimSurface = surfaces()[1]
			aimX = if aimSurface == "hook" then 1 else 0
			aimZ = 0
			selectedId = nil
			selectedPiece = nil
			Tray.mark(nil)
			showPreview()
		end)
		folder:GetAttributeChangedSignal("Phase"):Connect(function()
			if not canEdit() then
				hidePreview()
			end
		end)
	end
	showPreview()
end

return Place
