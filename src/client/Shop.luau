--!strict
-- Lobby shop. Three tabs, UI kit colors, and a layout that fits a 420px phone.
-- Crates show their odds before the buy button. The tour never opens this panel.
-- The VIP frame is lobby-only and has no name on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local UI = require(script.Parent.UI)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items") :: ModuleScript) :: any
local Logic = Shared:WaitForChild("Logic")
local Crates = require(Logic:WaitForChild("Crates") :: ModuleScript) :: any
local ShopLogic = require(Logic:WaitForChild("Shop") :: ModuleScript) :: any
local UIKit = UI.kit

local Shop = {}

local TABS = { "Boosts", "Decor", "Passes" }

local function itemName(itemId: string): string
	local item = Items.get(itemId)
	if type(item) == "table" then
		return item.name
	end
	return itemId
end

local function raining(folder: Instance): boolean
	local untilAt = folder:GetAttribute("RainUntil")
	return type(untilAt) == "number" and untilAt > os.time()
end

function Shop.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local roundFolder = ReplicatedStorage:WaitForChild("RoundState")
	local gui = UI.screen(playerGui, "GlowShop", 20)

	local frame = Instance.new("Frame")
	frame.Name = "VipFrame"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Visible = false
	frame.Parent = gui
	UI.stroke(frame, "butter", 8)

	local banner = UI.label(gui, "", UIKit.Text.body, 36)
	banner.Name = "RainBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, UIKit.Layout.top + 4)
	banner.Size = UDim2.new(1, -UIKit.Layout.side * 2, 0, 36)
	banner.BackgroundColor3 = UI.rgb("mint")
	banner.BackgroundTransparency = 0
	banner.Visible = false
	UI.corner(banner, 22)
	UI.stroke(banner, "ink", 3)

	local open = Instance.new("TextButton")
	open.Name = "OpenShop"
	open.AnchorPoint = Vector2.new(1, 0)
	open.Position = UDim2.new(1, -UIKit.Layout.side, 0, UIKit.Layout.top)
	open.Size = UDim2.fromOffset(96, 44)
	open.BackgroundColor3 = UI.rgb("coral")
	open.Text = "Shop"
	open.Font = UI.face()
	open.TextSize = 22
	open.TextColor3 = UI.rgb("ink")
	open.Visible = false
	open.Parent = gui
	UI.corner(open, 18)
	UI.stroke(open, "ink", 3)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Visible = false
	panel.BackgroundColor3 = UI.rgb("cream")
	panel.BorderSizePixel = 0
	panel.Parent = gui
	UI.corner(panel, UIKit.Shape.cornerChunky)
	UI.stroke(panel, "ink", UIKit.Shape.stroke)

	local title = UI.label(panel, "Shop", UIKit.Text.theme, 36)
	title.Name = "Title"
	title.TextXAlignment = Enum.TextXAlignment.Left

	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabRow

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "List"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 6
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new()
	scroller.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroller

	local codeRow = Instance.new("Frame")
	codeRow.Name = "CodeRow"
	codeRow.BackgroundTransparency = 1
	codeRow.Parent = panel
	local codeBox = Instance.new("TextBox")
	codeBox.Name = "Code"
	codeBox.ClearTextOnFocus = false
	codeBox.Font = UI.face()
	codeBox.PlaceholderText = "Code"
	codeBox.Text = ""
	codeBox.TextSize = 22
	codeBox.TextColor3 = UI.rgb("ink")
	codeBox.BackgroundColor3 = UI.rgb("lavender")
	codeBox.Size = UDim2.new(0.62, -8, 1, 0)
	codeBox.Parent = codeRow
	UI.corner(codeBox, 22)
	UI.stroke(codeBox, "ink", 3)
	local codeButton = Instance.new("TextButton")
	codeButton.Name = "Redeem"
	codeButton.AnchorPoint = Vector2.new(1, 0)
	codeButton.Position = UDim2.new(1, 0, 0, 0)
	codeButton.Size = UDim2.new(0.38, 0, 1, 0)
	codeButton.BackgroundColor3 = UI.rgb("mint")
	codeButton.Font = UI.face()
	codeButton.Text = "Redeem"
	codeButton.TextSize = 22
	codeButton.TextColor3 = UI.rgb("ink")
	codeButton.Parent = codeRow
	UI.corner(codeButton, 22)
	UI.stroke(codeButton, "ink", 3)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.BackgroundColor3 = UI.rgb(UIKit.Buttons.primary.fill)
	close.Font = UI.face()
	close.Text = "Close"
	close.TextSize = UIKit.Buttons.primary.textSize
	close.TextColor3 = UI.rgb("ink")
	close.Parent = panel
	UI.corner(close, UIKit.Buttons.primary.corner)
	UI.stroke(close, "ink", 3)

	local tab = "Boosts"
	local tabButtons: { [string]: TextButton } = {}

	local function layout()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 800
		if height < 1 then
			height = 800
		end
		local fit = UIKit.shop(height)
		local side = UIKit.Layout.side
		panel.Position = UDim2.fromOffset(side, fit.top)
		panel.Size = UDim2.new(1, -side * 2, 0, fit.bottom - fit.top)
		title.Position = UDim2.fromOffset(12, 0)
		title.Size = UDim2.new(1, -24, 0, fit.header)
		tabRow.Position = UDim2.fromOffset(12, fit.header)
		tabRow.Size = UDim2.new(1, -24, 0, fit.tabs)
		scroller.Position = UDim2.fromOffset(12, fit.bodyTop - fit.top)
		scroller.Size = UDim2.new(1, -24, 0, math.max(80, fit.body - 56))
		codeRow.Position = UDim2.new(0, 12, 1, -(fit.close + 8 + 48))
		codeRow.Size = UDim2.new(1, -24, 0, 44)
		close.Position = UDim2.new(0, 12, 1, -(fit.close + 4))
		close.Size = UDim2.new(1, -24, 0, fit.close)
	end

	local function addCard(order: number, heading: string, body: string, action: string?, itemKey: string?)
		local card = Instance.new("Frame")
		card.Name = heading
		card.BackgroundColor3 = UI.rgb("butter")
		card.Size = UDim2.new(1, -4, 0, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.LayoutOrder = order
		card.Parent = scroller
		UI.corner(card, 22)
		UI.stroke(card, "ink", 2)
		local pad = UI.pad(card, 10)
		pad.Name = "Pad"
		local stack = Instance.new("UIListLayout")
		stack.Padding = UDim.new(0, 4)
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = card
		local name = UI.label(card, heading, UIKit.Text.body, 28)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.LayoutOrder = 1
		local copy = UI.label(card, body, 18, 0)
		copy.AutomaticSize = Enum.AutomaticSize.Y
		copy.Size = UDim2.new(1, 0, 0, 0)
		copy.TextXAlignment = Enum.TextXAlignment.Left
		copy.TextYAlignment = Enum.TextYAlignment.Top
		copy.LayoutOrder = 2
		if action and itemKey then
			local button = Instance.new("TextButton")
			button.Name = "Buy"
			button.BackgroundColor3 = UI.rgb("coral")
			button.Font = UI.face()
			button.Text = action
			button.TextSize = 22
			button.TextColor3 = UI.rgb("ink")
			button.Size = UDim2.new(1, 0, 0, 48)
			button.LayoutOrder = 3
			button.Parent = card
			UI.corner(button, 22)
			UI.stroke(button, "ink", 3)
			button.Activated:Connect(function()
				if roundFolder:GetAttribute("Phase") ~= "Lobby" then
					return
				end
				local ok, msg = Net.act("Buy", itemKey)
				if msg and msg ~= "" then
					copy.Text = msg
				elseif ok then
					copy.Text = body
				end
			end)
		end
	end

	local function rebuild()
		for _, child in scroller:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, name in ipairs(TABS) do
			local button = tabButtons[name]
			if button then
				button.BackgroundColor3 = if name == tab then UI.rgb("coral") else UI.rgb("lavender")
			end
		end
		local rows = ShopLogic.list(tab)
		for index, row in ipairs(rows) do
			local body = row.desc .. "\n" .. tostring(row.price) .. " R$"
			if row.random == true then
				local policy = player:GetAttribute("CratePolicy")
				if policy == "fallback" then
					local names: { string } = {}
					for _, itemId in ipairs(Crates.fallback()) do
						table.insert(names, itemName(itemId))
					end
					body = "Fixed set\n" .. table.concat(names, ", ") .. "\n\n" .. body
				elseif policy == "paused" then
					body = "Purchases are paused.\n" .. body
				else
					local published = roundFolder:GetAttribute("CrateOdds")
					local odds = if type(published) == "string" and published ~= "" then published else Crates.display(Crates.rows(raining(roundFolder)), itemName)
					body = "Odds\n" .. odds .. "\n\n" .. body
				end
			end
			if type(row.itemId) == "string" then
				local preview = ShopLogic.preview(Items.get(row.itemId))
				if preview then
					local tags = table.concat(preview.tags, ", ")
					body = string.format(
						"%s\n%s · %s · %d by %d · %s\nTags: %s\n%s R$",
						preview.name,
						preview.category,
						preview.surface,
						preview.w,
						preview.d,
						preview.color,
						tags,
						tostring(row.price)
					)
				end
			end
			if type(row.items) == "table" then
				local names: { string } = {}
				for _, itemId in ipairs(row.items) do
					table.insert(names, itemName(itemId))
				end
				body = table.concat(names, ", ") .. "\n" .. tostring(row.price) .. " R$\n" .. row.desc
			end
			local label = "Buy"
			local itemKey = row.key
			if row.id == 0 then
				label = "Not for sale yet"
			end
			if row.random == true then
				local policy = player:GetAttribute("CratePolicy")
				if policy == "fallback" or policy == "paused" then
					label = if policy == "paused" then "Purchases are paused" else "Not available here"
					itemKey = nil
				end
			end
			addCard(index, row.name, body, label, itemKey)
		end
	end

	for index, name in ipairs(TABS) do
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(108, 44)
		button.BackgroundColor3 = UI.rgb("lavender")
		button.Font = UI.face()
		button.Text = name
		button.TextSize = 18
		button.TextColor3 = UI.rgb("ink")
		button.LayoutOrder = index
		button.Parent = tabRow
		UI.corner(button, 20)
		UI.stroke(button, "ink", 2)
		tabButtons[name] = button
		button.Activated:Connect(function()
			tab = name
			rebuild()
		end)
	end

	local function sync()
		local phase = roundFolder:GetAttribute("Phase")
		local inLobby = phase == "Lobby"
		open.Visible = inLobby
		if not inLobby then
			panel.Visible = false
		end
		local vip = player:GetAttribute("Vip") == true and inLobby
		frame.Visible = vip
		local announced = roundFolder:GetAttribute("RainName")
		local showRain = inLobby and type(announced) == "string" and announced ~= ""
		banner.Visible = showRain
		if showRain then
			banner.Text = announced .. " started Decor Rain"
		else
			banner.Text = ""
		end
		layout()
		if panel.Visible then
			rebuild()
		end
	end

	open.Activated:Connect(function()
		if roundFolder:GetAttribute("Phase") ~= "Lobby" then
			panel.Visible = false
			return
		end
		panel.Visible = true
		rebuild()
		layout()
		Net.act("ShopOpen")
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	codeButton.Activated:Connect(function()
		if roundFolder:GetAttribute("Phase") ~= "Lobby" then
			return
		end
		local text = codeBox.Text
		local _ok, msg = Net.act("Code", text)
		if msg and msg ~= "" then
			codeBox.Text = ""
			title.Text = msg
		end
	end)

	roundFolder:GetAttributeChangedSignal("Phase"):Connect(sync)
	roundFolder:GetAttributeChangedSignal("RainName"):Connect(sync)
	roundFolder:GetAttributeChangedSignal("RainUntil"):Connect(sync)
	player:GetAttributeChangedSignal("Vip"):Connect(sync)
	player:GetAttributeChangedSignal("CratePolicy"):Connect(function()
		if panel.Visible then
			rebuild()
		end
	end)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	sync()
end

return Shop
