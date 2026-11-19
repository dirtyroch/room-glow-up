--!strict
-- Lobby buttons for the dream home and duo pairing.
-- They sit in the tray band, clear of the board and the bottom button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)

local UIKit = UI.kit

local Home = {}

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.Y > 1 then
		return camera.ViewportSize
	end
	return Vector2.new(800, 800)
end

function Home.start()
	local player = Players.LocalPlayer
	local gui = UI.screen(player:WaitForChild("PlayerGui"), "GlowHome", 13)
	local folder = ReplicatedStorage:WaitForChild("RoundState")

	local bar = Instance.new("Frame")
	bar.Name = "Lobby"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.BackgroundTransparency = 1
	bar.Visible = false
	bar.Parent = gui

	local nextLabel = UI.label(bar, "", UIKit.Text.eyebrow, 22)
	nextLabel.Name = "Next"
	nextLabel.BackgroundColor3 = UI.rgb("butter")
	nextLabel.BackgroundTransparency = 0
	nextLabel.Position = UDim2.new(0, 0, 0, 0)
	nextLabel.Size = UDim2.new(1, 0, 0, 28)
	UI.corner(nextLabel, 14)
	UI.stroke(nextLabel, "ink", 2)

	local row = Instance.new("Frame")
	row.Name = "Buttons"
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 0, 0, 34)
	row.Size = UDim2.new(1, 0, 1, -34)
	row.Parent = bar
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.Parent = row

	local homeWrap = Instance.new("Frame")
	homeWrap.Name = "Home"
	homeWrap.BackgroundTransparency = 1
	homeWrap.Size = UDim2.new(0.5, -4, 1, 0)
	homeWrap.LayoutOrder = 1
	homeWrap.Parent = row
	local duoWrap = Instance.new("Frame")
	duoWrap.Name = "Duo"
	duoWrap.BackgroundTransparency = 1
	duoWrap.Size = UDim2.new(0.5, -4, 1, 0)
	duoWrap.LayoutOrder = 2
	duoWrap.Parent = row

	local pendingHome = false
	local pendingDuo = false

	local homeButton = UI.button(homeWrap, "Dream Home", "primary", function()
		if pendingHome then
			return
		end
		pendingHome = true
		Net.act("Home")
		pendingHome = false
	end)
	homeButton.Name = "HomeButton"
	homeButton.TextSize = 22

	local duoButton = UI.button(duoWrap, "Duo", "quiet", function()
		if pendingDuo then
			return
		end
		pendingDuo = true
		Net.act("Duo")
		pendingDuo = false
	end)
	duoButton.Name = "DuoButton"
	duoButton.TextSize = 22

	local function layout()
		local size = viewport()
		local bands = UIKit.bands(size.Y)
		local side = UIKit.Layout.side
		bar.Position = UDim2.new(0.5, 0, 0, bands.tray.top)
		bar.Size = UDim2.new(1, -side * 2, 0, bands.tray.bottom - bands.tray.top)
	end

	local function refresh()
		local phase = folder:GetAttribute("Phase")
		local home = player:GetAttribute("AtHome") == true
		local show = phase == "Lobby" and not home
		bar.Visible = show
		local upcoming = player:GetAttribute("NextUnlock")
		if type(upcoming) ~= "string" or upcoming == "" then
			upcoming = "Level 1 · First room"
		end
		nextLabel.Text = upcoming
		duoButton.Text = if player:GetAttribute("DuoOn") == true then "Duo on" else "Duo"
		layout()
	end

	layout()
	refresh()
	folder:GetAttributeChangedSignal("Phase"):Connect(refresh)
	player:GetAttributeChangedSignal("AtHome"):Connect(refresh)
	player:GetAttributeChangedSignal("DuoOn"):Connect(refresh)
	player:GetAttributeChangedSignal("NextUnlock"):Connect(refresh)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			layout()
			refresh()
		end)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local nextCamera = workspace.CurrentCamera
		if nextCamera then
			nextCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
		layout()
	end)
end

return Home
