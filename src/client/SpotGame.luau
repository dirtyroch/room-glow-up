--!strict
-- Spot the Theme sits under the podium during Results. Skip closes it.
-- It does not sell extra time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local UI = require(script.Parent.UI)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Spot = require(Logic:WaitForChild("Spot") :: ModuleScript) :: any

local SpotGame = {}

function SpotGame.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local vote = playerGui:WaitForChild("GlowVote")
	local results = vote:WaitForChild("Results")
	local folder = ReplicatedStorage:WaitForChild("RoundState")

	local panel = Instance.new("Frame")
	panel.Name = "SpotPanel"
	panel.LayoutOrder = 100
	panel.Size = UDim2.new(1, 0, 0, 132)
	panel.BackgroundColor3 = UI.rgb("mint")
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = results
	UI.corner(panel, 18)
	UI.stroke(panel, "ink", 3)

	local title = UI.label(panel, "Spot the Theme", 22, 28)
	title.Name = "Title"
	title.Position = UDim2.fromOffset(8, 6)

	local row = Instance.new("Frame")
	row.Name = "Choices"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(8, 38)
	row.Size = UDim2.new(1, -16, 0, 44)
	row.Parent = panel
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 6)
	list.Parent = row

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Position = UDim2.fromOffset(8, 88)
	skip.Size = UDim2.fromOffset(108, 36)
	skip.BackgroundColor3 = UI.rgb("lavender")
	skip.Font = UI.face()
	skip.TextSize = 20
	skip.TextColor3 = UI.rgb("ink")
	skip.Text = "Skip"
	skip.Parent = panel
	UI.corner(skip, 18)
	UI.stroke(skip, "ink", 2)

	local dismissed = false
	local pending = false

	local function clearChoices()
		for _, child in row:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end

	local function refresh()
		local phase = folder:GetAttribute("Phase")
		local podium = folder:GetAttribute("Podium")
		local encoded = folder:GetAttribute("SpotChoices")
		local phaseName = if type(phase) == "string" then phase else ""
		local show = Spot.visible(phaseName, podium) and type(encoded) == "string" and encoded ~= "" and not dismissed
		panel.Visible = show
		if not show then
			if phaseName ~= "Results" then
				dismissed = false
			end
			return
		end
		clearChoices()
		local options = Spot.decode(encoded :: string)
		for _, option in ipairs(options) do
			local button = Instance.new("TextButton")
			button.Name = option.id
			button.Size = UDim2.fromOffset(132, 44)
			button.BackgroundColor3 = UI.rgb("cream")
			button.Font = UI.face()
			button.TextSize = 20
			button.TextColor3 = UI.rgb("ink")
			button.Text = option.name
			button.TextWrapped = true
			button.Parent = row
			UI.corner(button, 18)
			UI.stroke(button, "ink", 2)
			local themeId = option.id
			button.Activated:Connect(function()
				if pending then
					return
				end
				pending = true
				Net.act("SpotGuess", themeId)
				dismissed = true
				panel.Visible = false
				pending = false
			end)
		end
	end

	skip.Activated:Connect(function()
		if pending then
			return
		end
		pending = true
		Net.act("SpotSkip")
		dismissed = true
		panel.Visible = false
		pending = false
	end)

	folder:GetAttributeChangedSignal("Phase"):Connect(refresh)
	folder:GetAttributeChangedSignal("Podium"):Connect(refresh)
	folder:GetAttributeChangedSignal("SpotChoices"):Connect(refresh)
	refresh()
end

return SpotGame
