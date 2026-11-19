--!strict
-- Bottom tray, theme meter, and coin budget. Bands keep them off the board,
-- the theme reveal, and the DONE button, including short phones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)
local Listen = require(script.Parent.Listen)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items") :: ModuleScript) :: any
local Logic = Shared:WaitForChild("Logic")
local Levels = require(Logic:WaitForChild("Levels") :: ModuleScript) :: any
local Hints = require(Logic:WaitForChild("Hints") :: ModuleScript) :: any
local Preview = require(Logic:WaitForChild("Preview") :: ModuleScript) :: any
local UIKit = UI.kit

local Tray = {}

local HINT = {
	room = "Tap an item, then tap a square.",
	gingerbread = "Tap a candy, then tap the house.",
	tree = "Tap an ornament, then tap a hook.",
}

local actions = {
	choose = function(_id: string) end,
	rotate = function() end,
	recolor = function() end,
	delete = function() end,
	undo = function() end,
	placeAt = function(_id: string, _pos: Vector2) end,
}

local noteLabel: TextLabel? = nil
local selectedId: string? = nil
local buttons: { [string]: TextButton } = {}

function Tray.setActions(next: any)
	actions = next
end

function Tray.setNote(text: string)
	if noteLabel then
		noteLabel.Text = text
	end
end

function Tray.mark(itemId: string?)
	selectedId = itemId
	for id, button in pairs(buttons) do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = if id == itemId then 5 else 2
			stroke.Color = if id == itemId then UI.rgb("ink") else UI.rgb("ink")
		end
	end
end

local function hintFor(roundType: string): string
	return HINT[roundType] or HINT.room
end

function Tray.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local roundFolder = ReplicatedStorage:WaitForChild("RoundState")
	local gui = UI.screen(playerGui, "GlowTray", 12)

	local meter = Instance.new("Frame")
	meter.Name = "Meter"
	meter.AnchorPoint = Vector2.new(0.5, 0)
	meter.BackgroundColor3 = UI.rgb("lavender")
	meter.BorderSizePixel = 0
	meter.Visible = false
	meter.Parent = gui
	UI.corner(meter, 18)
	UI.stroke(meter, "ink", 3)

	local matchLabel = UI.label(meter, "Theme Match 0", 18, 22)
	matchLabel.Name = "Match"
	matchLabel.AnchorPoint = Vector2.new(0, 0.5)
	matchLabel.Position = UDim2.new(0, 10, 0.5, 0)
	matchLabel.Size = UDim2.new(0.42, 0, 1, -8)
	matchLabel.TextXAlignment = Enum.TextXAlignment.Left

	local barBack = Instance.new("Frame")
	barBack.Name = "Bar"
	barBack.AnchorPoint = Vector2.new(0, 0.5)
	barBack.Position = UDim2.new(0.44, 0, 0.5, 0)
	barBack.Size = UDim2.new(0.3, 0, 0, 18)
	barBack.BackgroundColor3 = UI.rgb("cream")
	barBack.BorderSizePixel = 0
	barBack.Parent = meter
	UI.corner(barBack, 8)
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = UI.rgb("mint")
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	UI.corner(barFill, 8)

	local coins = UI.label(meter, "0 coins", 18, 22)
	coins.Name = "Coins"
	coins.AnchorPoint = Vector2.new(1, 0.5)
	coins.Position = UDim2.new(1, -10, 0.5, 0)
	coins.Size = UDim2.new(0.24, 0, 1, -8)
	coins.TextXAlignment = Enum.TextXAlignment.Right

	local tray = Instance.new("Frame")
	tray.Name = "Tray"
	tray.AnchorPoint = Vector2.new(0.5, 0)
	tray.BackgroundColor3 = UI.rgb("cream")
	tray.BorderSizePixel = 0
	tray.Visible = false
	tray.Parent = gui
	UI.corner(tray, UIKit.Shape.cornerChunky)
	UI.stroke(tray, "ink", UIKit.Shape.stroke)
	UI.pad(tray, 6)

	local hint = UI.label(tray, hintFor("room"), UIKit.Text.body, 28)
	hint.Name = "Hint"
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextWrapped = true
	noteLabel = hint

	local chips = Instance.new("ScrollingFrame")
	chips.Name = "Chips"
	chips.BackgroundTransparency = 1
	chips.BorderSizePixel = 0
	chips.ScrollBarThickness = 4
	chips.ScrollingDirection = Enum.ScrollingDirection.X
	chips.AutomaticCanvasSize = Enum.AutomaticSize.X
	chips.CanvasSize = UDim2.new()
	chips.Parent = tray
	local chipList = Instance.new("UIListLayout")
	chipList.FillDirection = Enum.FillDirection.Horizontal
	chipList.Padding = UDim.new(0, 6)
	chipList.SortOrder = Enum.SortOrder.LayoutOrder
	chipList.Parent = chips

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Items"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 6
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroller.CanvasSize = UDim2.new()
	scroller.Parent = tray
	local itemList = Instance.new("UIListLayout")
	itemList.FillDirection = Enum.FillDirection.Horizontal
	itemList.Padding = UDim.new(0, 8)
	itemList.SortOrder = Enum.SortOrder.LayoutOrder
	itemList.Parent = scroller

	local tools = Instance.new("Frame")
	tools.Name = "Tools"
	tools.BackgroundTransparency = 1
	tools.Parent = tray
	local toolList = Instance.new("UIListLayout")
	toolList.FillDirection = Enum.FillDirection.Horizontal
	toolList.Padding = UDim.new(0, 6)
	toolList.SortOrder = Enum.SortOrder.LayoutOrder
	toolList.Parent = tools

	local function tool(text: string, order: number, fn: () -> ())
		local wrap = Instance.new("Frame")
		wrap.Name = text
		wrap.BackgroundTransparency = 1
		wrap.Size = UDim2.new(0.25, -6, 1, 0)
		wrap.LayoutOrder = order
		wrap.Parent = tools
		local button = UI.button(wrap, text, "quiet", fn)
		button.TextSize = UIKit.Text.min
		button.Selectable = false
	end

	tool("Rotate", 1, function()
		actions.rotate()
	end)
	tool("Color", 2, function()
		actions.recolor()
	end)
	tool("Delete", 3, function()
		actions.delete()
	end)
	tool("Undo", 4, function()
		actions.undo()
	end)

	local category = "All"
	local drag: { id: string, input: InputObject, x: number, y: number, moved: boolean }? = nil

	local function roundType(): string
		local value = roundFolder:GetAttribute("RoundType")
		if type(value) == "string" and value ~= "" then
			return value
		end
		return "room"
	end

	local function atHome(): boolean
		return roundFolder:GetAttribute("Phase") == "Lobby" and player:GetAttribute("AtHome") == true
	end

	local function playerLevel(): number
		local level = player:GetAttribute("Level")
		if type(level) ~= "number" then
			return 1
		end
		return level
	end

	local function shopOwns(itemId: string): boolean
		local raw = player:GetAttribute("OwnedItems")
		if type(raw) ~= "string" or raw == "" then
			return false
		end
		return string.find("," .. raw .. ",", "," .. itemId .. ",", 1, true) ~= nil
	end

	local function visibleItems(): { any }
		if atHome() then
			local list: { any } = {}
			for _, item in ipairs(Items.list) do
				if item.surface == "floor" or item.surface == "wall" then
					table.insert(list, item)
				end
			end
			return list
		end
		return Items.forRound(roundType())
	end

	local function editing(): boolean
		if atHome() then
			return true
		end
		if roundFolder:GetAttribute("Phase") ~= "Build" then
			return false
		end
		if player:GetAttribute("Spectating") == true then
			return false
		end
		if player:GetAttribute("BuildDone") == true then
			return false
		end
		return true
	end

	local function showMeter(): boolean
		if atHome() then
			return true
		end
		local phase = roundFolder:GetAttribute("Phase")
		if phase == "Tour" then
			return true
		end
		return phase == "Build" and player:GetAttribute("Spectating") ~= true
	end

	local function readStats(): (number, number)
		local phase = roundFolder:GetAttribute("Phase")
		if phase == "Tour" then
			local plotIndex = roundFolder:GetAttribute("TourPlot")
			local plots = workspace:FindFirstChild("Plots")
			if type(plotIndex) == "number" and plots then
				local model = plots:FindFirstChild("Plot" .. tostring(plotIndex))
				if model then
					local match = model:GetAttribute("ThemeMatch")
					local left = model:GetAttribute("CoinsLeft")
					return if type(match) == "number" then match else 0, if type(left) == "number" then left else 0
				end
			end
		end
		local match = player:GetAttribute("ThemeMatch")
		local left = player:GetAttribute("CoinsLeft")
		return if type(match) == "number" then match else 0, if type(left) == "number" then left else 0
	end

	local function refreshStats()
		local match, left = readStats()
		local home = atHome()
		if home then
			matchLabel.Text = "Dream Home"
			coins.Text = "Free"
			barFill.Size = UDim2.fromScale(1, 1)
		else
			matchLabel.Text = "Theme Match " .. tostring(match)
			coins.Text = tostring(left) .. " coins"
			barFill.Size = UDim2.fromScale(math.clamp(match / 100, 0, 1), 1)
		end
		local level = playerLevel()
		for _, item in ipairs(visibleItems()) do
			local button = buttons[item.id]
			if button then
				local gate = Levels.gate(item.id, level)
				local owned = gate.owned == true or shopOwns(item.id)
				local name = button:FindFirstChild("ItemName")
				local price = button:FindFirstChild("Price")
				button.Text = ""
				if owned ~= true then
					if name and name:IsA("TextLabel") then
						name.Text = item.name .. "  Lv " .. tostring(gate.level)
					end
					if price and price:IsA("TextLabel") then
						price.Text = "Lv"
					end
					button.BackgroundTransparency = 0.35
					button.AutoButtonColor = false
				else
					local pricey = item.cost > left and not home
					if name and name:IsA("TextLabel") then
						name.Text = item.name
					end
					if price and price:IsA("TextLabel") then
						price.Text = tostring(item.cost)
					end
					button.BackgroundTransparency = if pricey then 0.2 else 0
					button.AutoButtonColor = true
				end
			end
		end
	end

	local function layout()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 800
		if height < 1 then
			height = 800
		end
		local bands = UIKit.bands(height)
		local side = UIKit.Layout.side
		meter.Position = UDim2.new(0.5, 0, 0, bands.meter.top)
		meter.Size = UDim2.new(1, -side * 2, 0, bands.meter.bottom - bands.meter.top)
		tray.Position = UDim2.new(0.5, 0, 0, bands.tray.top)
		tray.Size = UDim2.new(1, -side * 2, 0, bands.tray.bottom - bands.tray.top)
		local inner = bands.tray.bottom - bands.tray.top - 12
		local chipH = UIKit.Layout.chip
		local toolH = 40
		local hintH = 28
		if inner < hintH + chipH + toolH + 56 then
			hintH = 0
		end
		if inner < chipH + toolH + 48 then
			chipH = 0
		end
		local showHint = hintH > 0
		local showChips = chipH > 0
		hint.Visible = showHint
		hint.Position = UDim2.new(0, 0, 0, 0)
		hint.Size = UDim2.new(1, 0, 0, hintH)
		chips.Visible = showChips
		chips.Position = UDim2.new(0, 0, 0, hintH)
		chips.Size = UDim2.new(1, 0, 0, chipH)
		local itemsTop = hintH + chipH
		local itemsH = math.max(36, inner - itemsTop - toolH)
		scroller.Position = UDim2.new(0, 0, 0, itemsTop)
		scroller.Size = UDim2.new(1, 0, 0, itemsH)
		tools.Position = UDim2.new(0, 0, 1, -toolH)
		tools.Size = UDim2.new(1, 0, 0, toolH)
		local buttonH = math.max(56, itemsH - 6)
		for _, button in pairs(buttons) do
			button.Size = UDim2.fromOffset(112, buttonH)
			local preview = button:FindFirstChild("Preview")
			if preview and preview:IsA("GuiObject") then
				preview.Size = UDim2.new(1, -8, 1, -(UIKit.Text.item + 10))
			end
		end
	end

	local function rebuild()
		for _, child in chips:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for _, child in scroller:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		buttons = {}
		local kind = if atHome() then "room" else roundType()
		local names = Items.categories(kind)
		if atHome() then
			names = {}
			local seen: { [string]: boolean } = {}
			for _, item in ipairs(visibleItems()) do
				if seen[item.category] ~= true then
					seen[item.category] = true
					table.insert(names, item.category)
				end
			end
		end
		local function addChip(label: string, order: number)
			local chip = Instance.new("TextButton")
			chip.Name = label
			chip.AutoButtonColor = true
			chip.Text = label
			chip.Font = UI.face()
			chip.TextSize = UIKit.Text.min
			chip.TextColor3 = UI.rgb("ink")
			chip.BackgroundColor3 = if label == category then UI.rgb("butter") else UI.rgb("lavender")
			chip.Size = UDim2.fromOffset(math.max(UIKit.Layout.chip, #label * 12 + 28), UIKit.Layout.chip)
			chip.LayoutOrder = order
			chip.Selectable = false
			chip.Parent = chips
			UI.corner(chip, 18)
			local cap = Instance.new("UITextSizeConstraint")
			cap.MinTextSize = UIKit.Text.min
			cap.MaxTextSize = UIKit.Text.min
			cap.Parent = chip
			chip.Activated:Connect(function()
				category = label
				rebuild()
			end)
		end
		addChip("All", 0)
		for index, name in ipairs(names) do
			addChip(name, index)
		end
		local shown = 0
		local level = playerLevel()
		for _, item in ipairs(visibleItems()) do
			if category == "All" or item.category == category then
				shown += 1
				local gate = Levels.gate(item.id, level)
				local locked = gate.owned ~= true
				local button = Instance.new("TextButton")
				button.Name = item.id
				button.AutoButtonColor = not locked
				button.Font = UI.face()
				button.Text = ""
				button.TextSize = UIKit.Text.item
				button.BackgroundTransparency = if locked then 0.35 else 0
				button.TextColor3 = UI.rgb("ink")
				button.BackgroundColor3 = UI.rgb("cream")
				button.Size = UDim2.fromOffset(112, 96)
				button.LayoutOrder = shown
				button.Selectable = false
				button.Parent = scroller
				UI.corner(button, 22)
				UI.stroke(button, "ink", 2)
				local themeId = roundFolder:GetAttribute("ThemeId")
				local themeKey = if type(themeId) == "string" then themeId else ""
				local fits = Preview.fits(item, themeKey)
				local previews = ReplicatedStorage:FindFirstChild("PropPreviews")
				local template = if previews then previews:FindFirstChild(item.id) else nil
				local hasModel = template ~= nil and template:IsA("Model")
				local useViewport = Preview.mode(Listen.lowEnd(), hasModel) == "viewport"
				local picture = Instance.new("Frame")
				picture.Name = "Preview"
				picture.BackgroundColor3 = UI.rgb(item.color)
				picture.BackgroundTransparency = if locked then 0.4 else 0.05
				picture.BorderSizePixel = 0
				picture.Position = UDim2.fromOffset(4, 4)
				picture.Size = UDim2.new(1, -8, 1, -(UIKit.Text.item + 10))
				picture.ClipsDescendants = true
				picture.Parent = button
				UI.corner(picture, 16)
				if useViewport and template and template:IsA("Model") then
					local source = template
					task.defer(function()
						if not button.Parent then
							return
						end
						local view = Instance.new("ViewportFrame")
						view.Name = "Model"
						view.BackgroundTransparency = 1
						view.Size = UDim2.fromScale(1, 1)
						view.Ambient = Color3.fromRGB(220, 210, 200)
						view.LightColor = Color3.fromRGB(255, 244, 230)
						view.Parent = picture
						local world = Instance.new("WorldModel")
						world.Parent = view
						local clone = source:Clone()
						clone.Parent = world
						local camera = Instance.new("Camera")
						camera.CFrame = CFrame.new(Vector3.new(7, 5.5, 8), Vector3.new(0, 1.2, 0))
						camera.Parent = view
						view.CurrentCamera = camera
					end)
				else
					local blob = Instance.new("Frame")
					blob.Name = "Silhouette"
					blob.AnchorPoint = Vector2.new(0.5, 0.5)
					blob.Position = UDim2.fromScale(0.5, 0.48)
					blob.Size = UDim2.fromOffset(36, 28)
					blob.BackgroundColor3 = UI.rgb(item.color)
					blob.BorderSizePixel = 0
					blob.Parent = picture
					UI.corner(blob, 10)
				end
				local name = Instance.new("TextLabel")
				name.Name = "ItemName"
				name.BackgroundTransparency = 1
				name.AnchorPoint = Vector2.new(0, 1)
				name.Position = UDim2.new(0, 4, 1, -2)
				name.Size = UDim2.new(1, -8, 0, UIKit.Text.item + 2)
				name.Font = UI.face()
				name.TextSize = UIKit.Text.item
				name.TextColor3 = UI.rgb("ink")
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.TextTruncate = Enum.TextTruncate.AtEnd
				name.Text = if locked then item.name .. "  Lv " .. tostring(gate.level) else item.name
				name.Parent = button
				local nameCap = Instance.new("UITextSizeConstraint")
				nameCap.MinTextSize = UIKit.Text.item
				nameCap.MaxTextSize = UIKit.Text.item
				nameCap.Parent = name
				local price = Instance.new("TextLabel")
				price.Name = "Price"
				price.AnchorPoint = Vector2.new(1, 0)
				price.Position = UDim2.new(1, -6, 0, 6)
				price.Size = UDim2.fromOffset(40, 22)
				price.BackgroundColor3 = UI.rgb("butter")
				price.Font = UI.face()
				price.TextSize = UIKit.Text.min
				price.TextColor3 = UI.rgb("ink")
				price.Text = if locked then "Lv" else tostring(item.cost)
				price.Parent = button
				UI.corner(price, 8)
				if fits and not locked then
					local star = Instance.new("TextLabel")
					star.Name = "StarFit"
					star.Position = UDim2.fromOffset(6, 6)
					star.Size = UDim2.fromOffset(22, 18)
					star.BackgroundColor3 = UI.rgb("mint")
					star.Font = UI.face()
					star.TextSize = UIKit.Text.min
					star.TextColor3 = UI.rgb("ink")
					star.Text = UIKit.Icons.star
					star.Parent = button
					UI.corner(star, 8)
				end
				buttons[item.id] = button
				button.Activated:Connect(function()
					if locked then
						return
					end
					actions.choose(item.id)
				end)
				button.InputBegan:Connect(function(input)
					if locked then
						return
					end
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						drag = { id = item.id, input = input, x = input.Position.X, y = input.Position.Y, moved = false }
					end
				end)
			end
		end
		if category ~= "All" and shown == 0 then
			category = "All"
			rebuild()
			return
		end
		Tray.mark(selectedId)
		if atHome() then
			local nextUnlock = player:GetAttribute("NextUnlock")
			if type(nextUnlock) ~= "string" or nextUnlock == "" then
				nextUnlock = "Your dream home"
			end
			hint.Text = nextUnlock
		else
			local text = hintFor(kind)
			if player:GetAttribute("ThemeHint") == true then
				local themeId = roundFolder:GetAttribute("ThemeId")
				if type(themeId) == "string" then
					local extra = Hints.line(themeId, Items.list)
					if extra ~= "" then
						text = text .. " Fits: " .. extra
					end
				end
			end
			hint.Text = text
		end
		layout()
		refreshStats()
	end

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not drag or input ~= drag.input then
			return
		end
		local dx = math.abs(input.Position.X - drag.x)
		local dy = math.abs(input.Position.Y - drag.y)
		if dx + dy > 12 then
			drag.moved = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not drag or input ~= drag.input then
			return
		end
		local ended = drag
		drag = nil
		if ended.moved then
			actions.placeAt(ended.id, Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	local function refreshVisibility()
		meter.Visible = showMeter()
		tray.Visible = editing()
		refreshStats()
		layout()
	end

	rebuild()
	refreshVisibility()
	roundFolder:GetAttributeChangedSignal("RoundType"):Connect(function()
		category = "All"
		selectedId = nil
		rebuild()
	end)
	roundFolder:GetAttributeChangedSignal("Phase"):Connect(refreshVisibility)
	roundFolder:GetAttributeChangedSignal("TourPlot"):Connect(refreshStats)
	player:GetAttributeChangedSignal("Spectating"):Connect(refreshVisibility)
	player:GetAttributeChangedSignal("BuildDone"):Connect(refreshVisibility)
	player:GetAttributeChangedSignal("CoinsLeft"):Connect(refreshStats)
	player:GetAttributeChangedSignal("ThemeMatch"):Connect(refreshStats)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		rebuild()
	end)
	player:GetAttributeChangedSignal("AtHome"):Connect(function()
		category = "All"
		rebuild()
		refreshVisibility()
	end)
	player:GetAttributeChangedSignal("NextUnlock"):Connect(function()
		if atHome() then
			rebuild()
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local nextCamera = workspace.CurrentCamera
		if nextCamera then
			nextCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
		layout()
	end)
end

return Tray
