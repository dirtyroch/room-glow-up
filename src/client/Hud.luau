--!strict
-- Phone HUD: phase, a large countdown, and the theme. The DONE button sits in the
-- thumb zone. Safe insets keep it off the notch and the home indicator.
-- A phase change pops the board. Theme reveal adds a short banner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local UIKit = UI.kit

local Hud = {}

local function clockText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds - 1e-6))
	local mins = math.floor(whole / 60)
	local secs = whole % 60
	return string.format("%d:%02d", mins, secs)
end

function Hud.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local roundFolder = ReplicatedStorage:WaitForChild("RoundState")

	local gui = UI.screen(playerGui, "GlowHud", 10)

	local layout = UIKit.Layout
	local board = Instance.new("Frame")
	board.Name = "Board"
	board.AnchorPoint = Vector2.new(0.5, 0)
	board.Position = UDim2.new(0.5, 0, 0, layout.top)
	board.Size = UDim2.new(1, -layout.side * 2, 0, layout.boardHeight)
	board.BackgroundColor3 = UI.rgb("cream")
	board.BorderSizePixel = 0
	board.Parent = gui
	board.AutomaticSize = Enum.AutomaticSize.None
	UI.corner(board, UIKit.Shape.cornerChunky)
	UI.stroke(board, "ink", UIKit.Shape.stroke)
	local boardPad = UI.pad(board, 12)
	local boardList = Instance.new("UIListLayout")
	boardList.FillDirection = Enum.FillDirection.Vertical
	boardList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	boardList.SortOrder = Enum.SortOrder.LayoutOrder
	boardList.Padding = UDim.new(0, 2)
	boardList.Parent = board
	local boardScale = Instance.new("UIScale")
	boardScale.Parent = board

	local phaseLabel = UI.label(board, "Lobby", UIKit.Text.body, 28)
	phaseLabel.Name = "Phase"
	phaseLabel.LayoutOrder = 1
	local countdown = UI.label(board, "0:20", UIKit.Text.countdown, layout.countdownHeight)
	countdown.Name = "Countdown"
	countdown.LayoutOrder = 2
	countdown.TextScaled = true
	local sizeCap = Instance.new("UITextSizeConstraint")
	sizeCap.MaxTextSize = UIKit.Text.countdown
	sizeCap.MinTextSize = UIKit.Text.countdownMin
	sizeCap.Parent = countdown
	local themeLabel = UI.label(board, Config.SeasonTitle, UIKit.Text.theme, 36)
	themeLabel.Name = "Theme"
	themeLabel.LayoutOrder = 3
	local detail = UI.label(board, Config.Critic.line, UIKit.Text.eyebrow, 22)
	detail.Name = "Detail"
	detail.LayoutOrder = 4

	local reveal = Instance.new("Frame")
	reveal.Name = "ThemeReveal"
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Position = UDim2.new(0.5, 0, 0.4, 0)
	reveal.Size = UDim2.new(1, -layout.side * 2, 0, layout.revealHeight)
	reveal.BackgroundColor3 = UI.rgb("butter")
	reveal.BorderSizePixel = 0
	reveal.Visible = false
	reveal.ZIndex = 5
	reveal.Parent = gui
	UI.corner(reveal, UIKit.Shape.cornerChunky)
	UI.stroke(reveal, "ink", UIKit.Shape.stroke)
	UI.pad(reveal, 14)
	local revealList = Instance.new("UIListLayout")
	revealList.FillDirection = Enum.FillDirection.Vertical
	revealList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	revealList.SortOrder = Enum.SortOrder.LayoutOrder
	revealList.Parent = reveal
	local revealScale = Instance.new("UIScale")
	revealScale.Parent = reveal
	local revealKicker = UI.label(reveal, "This round", UIKit.Text.body, 28)
	revealKicker.LayoutOrder = 1
	revealKicker.ZIndex = 6
	local revealName = UI.label(reveal, "", UIKit.Text.reveal, 48)
	revealName.Name = "Name"
	revealName.LayoutOrder = 2
	revealName.ZIndex = 6

	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.AnchorPoint = Vector2.new(0.5, 1)
	thumb.Position = UDim2.new(0.5, 0, 1, -layout.bottom)
	thumb.Size = UDim2.new(1, -layout.side * 2, 0, UIKit.Buttons.primary.height)
	thumb.BackgroundTransparency = 1
	thumb.ZIndex = 6
	thumb.Parent = gui

	local pending = false
	local function onDone()
		if pending then
			return
		end
		pending = true
		local ok, msg = Net.act("Done")
		pending = false
		if msg and msg ~= "" then
			detail.Text = msg
		elseif ok then
			detail.Text = "Locked in."
		end
	end

	local doneButton = UI.button(thumb, "DONE", "primary", onDone)
	doneButton.Name = "Done"
	doneButton.ZIndex = 7

	local quiet = UI.label(thumb, "", UIKit.Text.button, UIKit.Buttons.quiet.height)
	quiet.Name = "Quiet"
	quiet.BackgroundColor3 = UI.rgb(UIKit.Buttons.quiet.fill)
	quiet.BackgroundTransparency = 0
	quiet.Size = UDim2.fromScale(1, 1)
	quiet.Visible = false
	quiet.ZIndex = 7
	UI.corner(quiet, UIKit.Buttons.quiet.corner)
	UI.stroke(quiet, UIKit.Buttons.quiet.stroke, UIKit.Buttons.quiet.strokeThickness)

	local function read(name: string, fallback: any): any
		local value = (roundFolder :: Instance):GetAttribute(name)
		if value == nil then
			return fallback
		end
		return value
	end

	local function layoutForViewport()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 800
		if height < 1 then
			height = 800
		end
		local bands = UIKit.bands(height)
		local boardH = bands.board.bottom - bands.board.top
		local revealH = bands.reveal.bottom - bands.reveal.top
		local compact = boardH < UIKit.Layout.boardHeight - 1
		local padPx = if compact then 8 else 12
		boardPad.PaddingTop = UDim.new(0, padPx)
		boardPad.PaddingBottom = UDim.new(0, padPx)
		boardPad.PaddingLeft = UDim.new(0, padPx)
		boardPad.PaddingRight = UDim.new(0, padPx)
		board.Position = UDim2.new(0.5, 0, 0, bands.board.top)
		board.Size = UDim2.new(1, -layout.side * 2, 0, boardH)
		countdown.Size = UDim2.new(1, 0, 0, if compact then 48 else layout.countdownHeight)
		themeLabel.Size = UDim2.new(1, 0, 0, if compact then 28 else 36)
		phaseLabel.Size = UDim2.new(1, 0, 0, if compact then 24 else 28)
		detail.Visible = not compact
		local revealCenter = (bands.reveal.top + bands.reveal.bottom) / 2
		reveal.Position = UDim2.new(0.5, 0, 0, revealCenter)
		reveal.Size = UDim2.new(1, -layout.side * 2, 0, revealH)
		revealKicker.Size = UDim2.new(1, 0, 0, if revealH < 100 then 22 else 28)
		revealName.Size = UDim2.new(1, 0, 0, if revealH < 100 then 32 else 48)
		thumb.Position = UDim2.new(0.5, 0, 0, bands.done.bottom)
		thumb.Size = UDim2.new(1, -layout.side * 2, 0, bands.done.bottom - bands.done.top)
		local fillName = UIKit.PhaseFill[read("Phase", "Lobby")] or "cream"
		board.BackgroundColor3 = UI.rgb(fillName)
	end

	local lastPhase = ""
	local revealShown = false

	local function refresh()
		local phase = read("Phase", "Lobby") :: string
		local waiting = read("Waiting", false) == true
		local endsAt = read("EndsAt", 0)
		local fallbackLeft = read("TimeLeft", Config.Phases.Lobby)
		local remaining = fallbackLeft
		if not waiting and type(endsAt) == "number" and endsAt > 0 then
			remaining = math.max(0, endsAt - workspace:GetServerTimeNow())
		end
		local themeName = read("ThemeName", "") :: string
		local season = read("Season", "holiday") :: string
		if themeName == "" then
			themeName = Config.SeasonLabels[season] or Config.SeasonTitle
		end
		local roundType = read("RoundType", "") :: string
		local typeLabel = Config.RoundTypeLabels[roundType]
		local phaseLabelText = Config.PhaseLabels[phase] or phase
		if typeLabel and phase ~= "Lobby" then
			phaseLabelText = phaseLabelText .. "  ·  " .. typeLabel
		end
		phaseLabel.Text = phaseLabelText
		countdown.Text = clockText(if type(remaining) == "number" then remaining else 0)
		themeLabel.Text = themeName
		local spectating = player:GetAttribute("Spectating") == true
		local built = player:GetAttribute("BuildDone") == true
		local touring = read("TourLabel", "") :: string
		if spectating then
			quiet.Text = "You'll play the next round"
		elseif phase == "Build" and built then
			quiet.Text = "Locked in"
		elseif touring ~= "" then
			quiet.Text = touring
		else
			quiet.Text = read("Critic", Config.Critic.name) .. " is here"
		end
		local showDone = phase == "Build" and not spectating and not built
		doneButton.Visible = showDone
		quiet.Visible = not showDone
		layoutForViewport()

		if phase ~= lastPhase then
			local previous = lastPhase
			lastPhase = phase
			if previous ~= "" then
				UI.pop(boardScale, UIKit.Motion.phase)
			end
		end
		local showing = phase == "ThemeReveal" and themeName ~= ""
		if showing and not revealShown then
			revealShown = true
			reveal.Visible = true
			revealName.Text = themeName
			UI.pop(revealScale, UIKit.Motion.reveal)
		elseif not showing and revealShown then
			revealShown = false
			reveal.Visible = false
		elseif showing then
			revealName.Text = themeName
		end
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutForViewport)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local nextCamera = workspace.CurrentCamera
		if nextCamera then
			nextCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutForViewport)
		end
		layoutForViewport()
	end)

	refresh()
	RunService.RenderStepped:Connect(refresh)
end

return Hud
