--!strict
-- First-visit Mini Room. One big place button, and skip is always there.
-- Practice stars stay on this screen. They are not sent as a vote.

local Players = game:GetService("Players")

local Net = require(script.Parent.Net)
local UI = require(script.Parent.UI)

local UIKit = UI.kit

local Tutorial = {}

function Tutorial.start()
	local player = Players.LocalPlayer
	local gui = UI.screen(player:WaitForChild("PlayerGui"), "GlowTutorial", 30)
	gui.Enabled = false

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = UI.rgb("cream")
	dim.BackgroundTransparency = 0.08
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -16, 0, 16)
	skip.Size = UDim2.fromOffset(120, 56)
	skip.BackgroundColor3 = UI.rgb("lavender")
	skip.Font = UI.face()
	skip.TextSize = 22
	skip.TextColor3 = UI.rgb("ink")
	skip.Text = "Skip"
	skip.ZIndex = 4
	skip.Parent = gui
	UI.corner(skip, 18)
	UI.stroke(skip, "ink", 3)

	local reaction = Instance.new("TextLabel")
	reaction.Name = "Reaction"
	reaction.AnchorPoint = Vector2.new(0.5, 0)
	reaction.Position = UDim2.new(0.5, 0, 0, 72)
	reaction.Size = UDim2.new(1, -32, 0, 96)
	reaction.BackgroundColor3 = UI.rgb("butter")
	reaction.Font = UI.face()
	reaction.TextSize = 22
	reaction.TextColor3 = UI.rgb("ink")
	reaction.TextWrapped = true
	reaction.Text = ""
	reaction.Visible = false
	reaction.ZIndex = 4
	reaction.Parent = gui
	UI.corner(reaction, 18)
	UI.stroke(reaction, "ink", 3)

	local place = Instance.new("TextButton")
	place.Name = "PlaceRug"
	place.AnchorPoint = Vector2.new(0.5, 1)
	place.Position = UDim2.new(0.5, 0, 1, -18)
	place.Size = UDim2.new(1, -32, 0, 96)
	place.BackgroundColor3 = UI.rgb("coral")
	place.Font = UI.face()
	place.TextSize = 32
	place.TextColor3 = UI.rgb("ink")
	place.Text = "Place the rug"
	place.ZIndex = 4
	place.Parent = gui
	UI.corner(place, 28)
	UI.stroke(place, "ink", 3)

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -122)
	hint.Size = UDim2.new(1, -32, 0, 36)
	hint.BackgroundTransparency = 1
	hint.Font = UI.face()
	hint.TextSize = 22
	hint.TextColor3 = UI.rgb("ink")
	hint.Text = "Tap the big rug."
	hint.ZIndex = 4
	hint.Parent = gui

	local function layout()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 800
		if height < 1 then
			height = 800
		end
		local fit = UIKit.tutorial(height)
		place.Size = UDim2.new(1, -32, 0, fit.hint)
		place.TextSize = fit.hintText
		skip.Size = UDim2.fromOffset(120, fit.skip)
		reaction.Position = UDim2.new(0.5, 0, 0, fit.reactionTop)
		reaction.Size = UDim2.new(1, -32, 0, fit.reactionBottom - fit.reactionTop)
		hint.Position = UDim2.new(0.5, 0, 1, -(18 + fit.hint + 8))
	end

	local pending = false
	place.Activated:Connect(function()
		if pending then
			return
		end
		pending = true
		Net.act("TutorialPlace")
		pending = false
	end)
	skip.Activated:Connect(function()
		if pending then
			return
		end
		pending = true
		Net.act("TutorialSkip")
		pending = false
	end)

	local function refresh()
		local active = player:GetAttribute("TutorialActive") == true
		gui.Enabled = active
		if not active then
			return
		end
		local roundFolder = game:GetService("ReplicatedStorage"):FindFirstChild("RoundState")
		local phase = if roundFolder then roundFolder:GetAttribute("Phase") else ""
		local onTour = phase == "Tour"
		-- During the tour the card stays clear of the star buttons and the names.
		dim.Visible = not onTour
		dim.Active = false
		local line = player:GetAttribute("TutorialLine")
		local stars = player:GetAttribute("TutorialStars")
		local placed = player:GetAttribute("TutorialPlaced") == true
		place.Visible = not placed
		if type(line) == "string" and line ~= "" then
			local shown = line
			if type(stars) == "number" and stars > 0 then
				shown = "Practice · " .. tostring(stars) .. " stars\n" .. line
			end
			reaction.Text = shown
			reaction.Visible = true
		else
			reaction.Visible = false
		end
		local text = player:GetAttribute("TutorialHint")
		if type(text) == "string" and text ~= "" then
			hint.Text = text
		end
		layout()
		if onTour then
			place.AnchorPoint = Vector2.new(0.5, 0.5)
			place.Position = UDim2.new(0.5, 0, 0.42, 0)
			hint.AnchorPoint = Vector2.new(0.5, 0)
			hint.Position = UDim2.new(0.5, 0, 0.42, 56)
			reaction.Position = UDim2.new(0.5, 0, 0.42, -110)
		else
			place.AnchorPoint = Vector2.new(0.5, 1)
			place.Position = UDim2.new(0.5, 0, 1, -18)
			hint.AnchorPoint = Vector2.new(0.5, 1)
		end
	end

	player:GetAttributeChangedSignal("TutorialActive"):Connect(refresh)
	player:GetAttributeChangedSignal("TutorialLine"):Connect(refresh)
	player:GetAttributeChangedSignal("TutorialHint"):Connect(refresh)
	player:GetAttributeChangedSignal("TutorialStars"):Connect(refresh)
	player:GetAttributeChangedSignal("TutorialPlaced"):Connect(refresh)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	refresh()
end

return Tutorial
