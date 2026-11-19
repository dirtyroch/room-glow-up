--!strict
-- Round HUD for a phone screen. The theme sits in a card at the top so it
-- stays clear of thumbs. DONE sits in the bottom thumb zone and only shows
-- while this player is building. Spectators get a line instead of a button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Replica = require(Shared:WaitForChild("Replica"))
local ClockFormat = require(Logic:WaitForChild("ClockFormat"))
local HudLayout = require(Logic:WaitForChild("HudLayout"))

local Hud = {}

local PHASE_LABEL = {
	Lobby = "Lobby",
	ThemeReveal = "Theme",
	Build = "Build",
	Tour = "Tour",
	Results = "Results",
}

local CREAM = Color3.fromRGB(255, 246, 232)
local INK = Color3.fromRGB(36, 64, 54)
local PINE = Color3.fromRGB(24, 92, 72)
local GOLD = Color3.fromRGB(214, 154, 46)

local function label(parent: Instance, textSize: number, bold: boolean): TextLabel
	local widget = Instance.new("TextLabel")
	widget.BackgroundTransparency = 1
	widget.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	widget.TextSize = textSize
	widget.TextColor3 = INK
	widget.TextXAlignment = Enum.TextXAlignment.Left
	widget.TextYAlignment = Enum.TextYAlignment.Center
	widget.TextWrapped = true
	widget.Size = UDim2.new(1, 0, 0, textSize + 8)
	widget.Parent = parent
	return widget
end

local function secondsLeft(roundFolder: Folder): number
	if roundFolder:GetAttribute(Replica.Holding) == true then
		return -1
	end
	local endsAt = roundFolder:GetAttribute(Replica.EndsAt)
	if type(endsAt) == "number" and endsAt > 0 then
		return math.max(0, endsAt - workspace:GetServerTimeNow())
	end
	local left = roundFolder:GetAttribute(Replica.TimeLeft)
	if type(left) == "number" then
		return left
	end
	return -1
end

function Hud.mount(playerGui: PlayerGui, roundFolder: Folder, act: (string) -> (boolean, string?))
	local player = Players.LocalPlayer
	local layout = HudLayout

	local gui = Instance.new("ScreenGui")
	gui.Name = "RoundHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Parent = playerGui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, layout.topOffset)
	card.Size = UDim2.new(layout.topWidthScale, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = CREAM
	card.BorderSizePixel = 0
	card.Parent = gui

	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(layout.maxCardWidth, 320)
	cap.Parent = card

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, layout.corner)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = PINE
	stroke.Thickness = 2
	stroke.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, layout.padding)
	pad.PaddingBottom = UDim.new(0, layout.padding)
	pad.PaddingLeft = UDim.new(0, layout.padding)
	pad.PaddingRight = UDim.new(0, layout.padding)
	pad.Parent = card

	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, layout.gap)
	stack.Parent = card

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, layout.phaseText + 6)
	header.LayoutOrder = 1
	header.Parent = card

	local phase = label(header, layout.phaseText, true)
	phase.Name = "Phase"
	phase.Size = UDim2.new(0.55, 0, 1, 0)
	phase.TextXAlignment = Enum.TextXAlignment.Left

	local timer = label(header, layout.timerText, true)
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.new(1, 0, 0, 0)
	timer.Size = UDim2.new(0.45, 0, 1, 0)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.TextColor3 = PINE

	local theme = label(card, layout.themeText, true)
	theme.Name = "Theme"
	theme.LayoutOrder = 2
	theme.TextWrapped = true
	theme.TextScaled = true
	theme.Size = UDim2.new(1, 0, 0, layout.themeText + 12)
	local themeCap = Instance.new("UITextSizeConstraint")
	themeCap.MaxTextSize = layout.themeText
	themeCap.MinTextSize = 16
	themeCap.Parent = theme

	local detail = label(card, layout.phaseText, false)
	detail.Name = "Detail"
	detail.LayoutOrder = 3
	detail.TextWrapped = true
	detail.Size = UDim2.new(1, 0, 0, layout.phaseText * 2 + 4)

	local dock = Instance.new("Frame")
	dock.Name = "Dock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -layout.bottomOffset)
	dock.Size = UDim2.new(layout.bottomWidthScale, 0, 0, 0)
	dock.AutomaticSize = Enum.AutomaticSize.Y
	dock.BackgroundTransparency = 1
	dock.Parent = gui

	local dockCap = Instance.new("UISizeConstraint")
	dockCap.MaxSize = Vector2.new(layout.maxCardWidth, 160)
	dockCap.Parent = dock

	local dockStack = Instance.new("UIListLayout")
	dockStack.FillDirection = Enum.FillDirection.Vertical
	dockStack.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockStack.Padding = UDim.new(0, layout.gap)
	dockStack.Parent = dock

	local status = label(dock, layout.phaseText, false)
	status.Name = "Status"
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextColor3 = CREAM
	status.Size = UDim2.new(1, 0, 0, layout.phaseText + 4)
	status.Visible = false

	local button = Instance.new("TextButton")
	button.Name = "Done"
	button.Size = UDim2.new(1, 0, 0, layout.minTouchHeight)
	button.BackgroundColor3 = PINE
	button.TextColor3 = CREAM
	button.Font = Enum.Font.GothamBold
	button.TextSize = 20
	button.Text = "DONE"
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Visible = false
	button.Parent = dock

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, layout.corner)
	buttonCorner.Parent = button

	local busy = false
	button.Activated:Connect(function()
		if busy or not button.Active then
			return
		end
		busy = true
		button.Active = false
		local ok, msg = act("Done")
		busy = false
		if msg and msg ~= "" then
			status.Text = msg
			status.Visible = true
		end
		if not ok and msg == nil then
			status.Text = "Try again."
			status.Visible = true
		end
	end)

	local function refresh()
		local phaseName = roundFolder:GetAttribute(Replica.Phase)
		local phaseId = if type(phaseName) == "string" then phaseName else "Lobby"
		local holding = roundFolder:GetAttribute(Replica.Holding) == true
		local themeName = roundFolder:GetAttribute(Replica.ThemeName)
		local typeLabel = roundFolder:GetAttribute(Replica.TypeLabel)
		local seasonLabel = roundFolder:GetAttribute(Replica.SeasonLabel)
		local tourIndex = roundFolder:GetAttribute(Replica.TourIndex)
		local tourCount = roundFolder:GetAttribute(Replica.TourCount)
		local role = player:GetAttribute(Replica.Role)
		local roleId = if type(role) == "string" then role else "joining"
		local themeText = if type(themeName) == "string" then themeName else ""
		local seasonText = if type(seasonLabel) == "string" then seasonLabel else "Holiday Season"
		local kindText = if type(typeLabel) == "string" then typeLabel else ""
		local index = if type(tourIndex) == "number" then tourIndex else 0
		local count = if type(tourCount) == "number" then tourCount else 0

		phase.Text = string.upper(PHASE_LABEL[phaseId] or phaseId)
		if holding then
			timer.Text = "Wait"
		else
			timer.Text = ClockFormat.clock(secondsLeft(roundFolder))
		end
		if phaseId == "Lobby" or themeText == "" then
			theme.Text = seasonText
		else
			theme.Text = themeText
		end

		local line = ""
		if holding then
			line = "Waiting for players"
		elseif phaseId == "Lobby" then
			line = "Next round soon"
		elseif roleId == "spectating" then
			line = "You'll play next round"
		elseif phaseId == "ThemeReveal" then
			line = kindText
		elseif phaseId == "Build" then
			if roleId == "done" then
				line = "Locked in"
			else
				line = "Press DONE when you are finished"
			end
		elseif phaseId == "Tour" and count > 0 then
			line = string.format("Room %d of %d", index, count)
		elseif phaseId == "Results" then
			line = "Round complete"
		end
		detail.Text = line

		local showButton = phaseId == "Build" and (roleId == "playing" or roleId == "done")
		button.Visible = showButton
		if showButton then
			local locked = roleId == "done"
			button.Text = if locked then "Locked in" else "DONE"
			button.Active = not locked and not busy
			button.AutoButtonColor = not locked
			button.BackgroundColor3 = if locked then GOLD else PINE
			button.TextColor3 = if locked then INK else CREAM
		end
	end

	roundFolder.AttributeChanged:Connect(refresh)
	player:GetAttributeChangedSignal(Replica.Role):Connect(refresh)
	RunService.Heartbeat:Connect(refresh)
	refresh()
end

return Hud
