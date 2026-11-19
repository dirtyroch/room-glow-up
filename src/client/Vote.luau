--!strict
-- Star votes, the report button, the podium, and the polaroid card.
-- Everything sits in the existing HUD bands, clear of the top board and the
-- bottom button. Owner names show up on the podium only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Voting = require(Logic:WaitForChild("Voting") :: ModuleScript) :: any
local UIKit = UI.kit

local Vote = {}

local function starsText(average: number): string
	local filled = math.clamp(math.floor(average + 0.5), 0, 5)
	local marks = string.rep("★", filled) .. string.rep("☆", 5 - filled)
	return marks .. "  " .. string.format("%.1f", average)
end

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.Y > 1 then
		return camera.ViewportSize
	end
	return Vector2.new(800, 800)
end

function Vote.start()
	local player = Players.LocalPlayer
	local gui = UI.screen(player:WaitForChild("PlayerGui"), "GlowVote", 14)
	local folder = ReplicatedStorage:WaitForChild("RoundState")

	local caption = Instance.new("TextLabel")
	caption.Name = "TourCaption"
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.BackgroundColor3 = UI.rgb("mint")
	caption.BorderSizePixel = 0
	caption.Font = UI.face()
	caption.Text = ""
	caption.TextColor3 = UI.rgb("ink")
	caption.TextScaled = true
	caption.Visible = false
	caption.Parent = gui
	UI.corner(caption, UIKit.Shape.corner)
	UI.stroke(caption, "ink", UIKit.Shape.stroke)
	local capSize = Instance.new("UITextSizeConstraint")
	capSize.MaxTextSize = UIKit.Text.body
	capSize.MinTextSize = 16
	capSize.Parent = caption
	local captionScale = Instance.new("UIScale")
	captionScale.Parent = caption

	local panel = Instance.new("Frame")
	panel.Name = "Votes"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.BackgroundColor3 = UI.rgb("cream")
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	UI.corner(panel, UIKit.Shape.cornerChunky)
	UI.stroke(panel, "ink", UIKit.Shape.stroke)

	local starRow = Instance.new("Frame")
	starRow.Name = "Stars"
	starRow.BackgroundTransparency = 1
	starRow.Position = UDim2.new(0, 8, 0, 8)
	starRow.Parent = panel
	local starList = Instance.new("UIListLayout")
	starList.FillDirection = Enum.FillDirection.Horizontal
	starList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	starList.VerticalAlignment = Enum.VerticalAlignment.Center
	starList.Padding = UDim.new(0, 6)
	starList.Parent = starRow

	local ownLabel = UI.label(panel, "Your room is up", UIKit.Text.body, 36)
	ownLabel.Name = "Yours"
	ownLabel.Visible = false
	ownLabel.Position = UDim2.new(0, 8, 0, 8)

	local reportWrap = Instance.new("Frame")
	reportWrap.Name = "ReportWrap"
	reportWrap.AnchorPoint = Vector2.new(0, 1)
	reportWrap.BackgroundTransparency = 1
	reportWrap.Parent = panel

	local results = Instance.new("ScrollingFrame")
	results.Name = "Results"
	results.AnchorPoint = Vector2.new(0.5, 0)
	results.BackgroundTransparency = 1
	results.BorderSizePixel = 0
	results.ScrollBarThickness = 6
	results.ScrollingDirection = Enum.ScrollingDirection.Y
	results.AutomaticCanvasSize = Enum.AutomaticSize.Y
	results.CanvasSize = UDim2.new()
	results.Visible = false
	results.Parent = gui
	local resultList = Instance.new("UIListLayout")
	resultList.FillDirection = Enum.FillDirection.Vertical
	resultList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	resultList.Padding = UDim.new(0, 8)
	resultList.SortOrder = Enum.SortOrder.LayoutOrder
	resultList.Parent = results

	local starButtons: { TextButton } = {}
	local pendingVote = false
	local pendingReport = false
	local status = ""
	local seenIndex = -1
	local wasLocked = false
	local painted = ""
	local cardHeight = 160

	local function lockedNow(label: string): boolean
		return string.find(label, "Locked", 1, true) ~= nil
	end

	local function layout()
		local size = viewport()
		local bands = UIKit.bands(size.Y)
		local side = UIKit.Layout.side
		local revealH = bands.reveal.bottom - bands.reveal.top
		local trayH = bands.tray.bottom - bands.tray.top
		caption.Position = UDim2.new(0.5, 0, 0, bands.reveal.top)
		caption.Size = UDim2.new(1, -side * 2, 0, revealH)
		panel.Position = UDim2.new(0.5, 0, 0, bands.tray.top)
		panel.Size = UDim2.new(1, -side * 2, 0, trayH)
		results.Position = UDim2.new(0.5, 0, 0, bands.reveal.top)
		results.Size = UDim2.new(1, -side * 2, 0, bands.tray.bottom - bands.reveal.top)
		local reportH = if trayH >= 92 then 40 else 34
		reportWrap.Position = UDim2.new(0, 8, 1, -6)
		reportWrap.Size = UDim2.new(1, -16, 0, reportH)
		local starH = math.max(36, trayH - reportH - 22)
		starRow.Size = UDim2.new(1, -16, 0, starH)
		ownLabel.Size = UDim2.new(1, -16, 0, starH)
		local inner = math.max(0, size.X - side * 2 - 16)
		local buttonW = math.floor((inner - 6 * 4) / 5)
		if buttonW < 36 then
			buttonW = 36
		end
		for _, button in ipairs(starButtons) do
			button.Size = UDim2.fromOffset(buttonW, starH)
		end
		local stageH = bands.tray.bottom - bands.reveal.top
		cardHeight = math.clamp(math.floor(stageH * 0.46), 120, 280)
		local card = results:FindFirstChild("PhotoCard")
		if card and card:IsA("Frame") then
			card.Size = UDim2.new(1, 0, 0, cardHeight)
		end
	end

	local function clearResults()
		for _, child in results:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	local function addLine(text: string, order: number, height: number)
		local label = UI.label(results, text, UIKit.Text.eyebrow, height)
		label.LayoutOrder = order
		label.TextXAlignment = Enum.TextXAlignment.Center
		return label
	end

	local function paint(payload: string, theme: string, stars: number?, line: string, coins: number)
		local key = payload .. "\0" .. theme .. "\0" .. tostring(stars) .. "\0" .. line .. "\0" .. tostring(coins)
		if key == painted then
			layout()
			return
		end
		painted = key
		clearResults()
		local order = 1
		if type(stars) == "number" and line ~= "" then
			local cardData = Voting.photoCard({
				theme = theme,
				stars = stars,
				line = line,
			})
			local frame = Instance.new("Frame")
			frame.Name = "PhotoCard"
			frame.LayoutOrder = order
			frame.Size = UDim2.new(1, 0, 0, cardHeight)
			frame.BackgroundColor3 = UI.rgb("cream")
			frame.BorderSizePixel = 0
			frame.Parent = results
			UI.corner(frame, 18)
			UI.stroke(frame, "ink", 3)
			order += 1
			local photoH = math.max(52, cardHeight - 72)
			local photo = Instance.new("Frame")
			photo.Name = "Photo"
			photo.BackgroundColor3 = UI.rgb("butter")
			photo.BorderSizePixel = 0
			photo.Position = UDim2.new(0, 12, 0, 12)
			photo.Size = UDim2.new(1, -24, 0, photoH)
			photo.Parent = frame
			UI.corner(photo, 12)
			local themeLabel = UI.label(photo, cardData.theme, UIKit.Text.theme, math.floor(photoH * 0.42))
			themeLabel.Position = UDim2.new(0, 0, 0.06, 0)
			themeLabel.Font = UI.face()
			local score = UI.label(photo, starsText(cardData.stars), UIKit.Text.body, math.floor(photoH * 0.36))
			score.Name = "Stars"
			score.Position = UDim2.new(0, 0, 0.5, 0)
			score.Font = Enum.Font.GothamBold
			local credit = UI.label(frame, "Auntie Roch", 14, 18)
			credit.Position = UDim2.new(0, 10, 1, -50)
			credit.Size = UDim2.new(1, -20, 0, 18)
			local quote = UI.label(frame, cardData.line, UIKit.Text.eyebrow, 28)
			quote.Name = "Line"
			quote.Position = UDim2.new(0, 10, 1, -30)
			quote.Size = UDim2.new(1, -20, 0, 26)
		end
		if coins > 0 then
			addLine("Judge's Eye +" .. tostring(coins), order, 22)
			order += 1
		end
		local rows = Voting.decodeBoard(payload)
		local podium = Instance.new("Frame")
		podium.Name = "Podium"
		podium.LayoutOrder = order
		podium.BackgroundTransparency = 1
		podium.Size = UDim2.new(1, 0, 0, 148)
		podium.Parent = results
		order += 1
		local shown: { any } = {}
		if rows[2] then
			table.insert(shown, rows[2])
		end
		if rows[1] then
			table.insert(shown, rows[1])
		end
		if rows[3] then
			table.insert(shown, rows[3])
		end
		local count = #shown
		for index, row in ipairs(shown) do
			local slot = Instance.new("Frame")
			slot.Name = "Place" .. tostring(row.rank)
			slot.BackgroundColor3 = if row.rank == 1 then UI.rgb("butter") else UI.rgb("lavender")
			slot.BorderSizePixel = 0
			local width = if count > 0 then 1 / count else 1
			slot.Position = UDim2.new(width * (index - 1), 4, 0, if row.rank == 1 then 0 else 16)
			slot.Size = UDim2.new(width, -8, 1, if row.rank == 1 then 0 else -16)
			slot.Parent = podium
			UI.corner(slot, 16)
			UI.stroke(slot, "ink", 2)
			local avatar = Instance.new("ImageLabel")
			avatar.Name = "Avatar"
			avatar.BackgroundColor3 = UI.rgb("cream")
			avatar.BorderSizePixel = 0
			avatar.AnchorPoint = Vector2.new(0.5, 0)
			avatar.Position = UDim2.new(0.5, 0, 0, 8)
			avatar.Size = UDim2.fromOffset(44, 44)
			avatar.Parent = slot
			UI.corner(avatar, 22)
			local userId = tonumber(row.userId)
			if type(userId) == "number" and row.name ~= "" then
				avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"
			end
			if row.name ~= "" then
				local name = UI.label(slot, row.name, 14, 18)
				name.Name = "Owner"
				name.Position = UDim2.new(0, 2, 0, 54)
				name.Size = UDim2.new(1, -4, 0, 18)
			end
			local avg = UI.label(slot, string.format("%.1f", row.average), 16, 18)
			avg.Position = UDim2.new(0, 2, 0, if row.name ~= "" then 72 else 56)
			avg.Size = UDim2.new(1, -4, 0, 18)
			local note = UI.label(slot, row.comment, 12, 32)
			note.Position = UDim2.new(0, 4, 1, -36)
			note.Size = UDim2.new(1, -8, 0, 32)
		end
		for _, row in ipairs(rows) do
			if row.rank > 3 then
				addLine(string.format("%.1f   %s", row.average, row.comment), order, 36)
				order += 1
			end
		end
		if #rows == 0 and type(stars) ~= "number" then
			addLine("No rooms this round", order, 28)
		end
		layout()
	end

	local refresh: () -> ()

	local function isOwnRoom(): boolean
		local phase = folder:GetAttribute("Phase")
		local plot = folder:GetAttribute("TourPlot")
		local mine = player:GetAttribute("Plot")
		return phase == "Tour" and type(plot) == "number" and plot > 0 and type(mine) == "number" and mine == plot
	end

	local function ownOrLocked(): (boolean, boolean)
		local phase = folder:GetAttribute("Phase")
		local label = folder:GetAttribute("TourLabel")
		local own = isOwnRoom()
		local locked = phase == "Tour" and type(label) == "string" and lockedNow(label)
		return own, locked
	end

	local function choose(stars: number)
		local own, locked = ownOrLocked()
		if pendingVote or own or locked then
			return
		end
		pendingVote = true
		local ok, msg = Net.act("Vote", stars)
		pendingVote = false
		if not ok and type(msg) == "string" and msg ~= "" then
			status = msg
		else
			status = ""
		end
		refresh()
	end

	for star = 1, 5 do
		local button = Instance.new("TextButton")
		button.Name = "Star" .. tostring(star)
		button.AutoButtonColor = true
		button.Font = UI.face()
		button.Text = tostring(star)
		button.TextSize = UIKit.Text.button
		button.TextColor3 = UI.rgb("ink")
		button.BackgroundColor3 = UI.rgb("lavender")
		button.BorderSizePixel = 0
		button.LayoutOrder = star
		button.Parent = starRow
		UI.corner(button, 16)
		UI.stroke(button, "ink", 3)
		local picked = star
		button.Activated:Connect(function()
			choose(picked)
		end)
		starButtons[star] = button
	end

	local function onReport()
		local own, _locked = ownOrLocked()
		if pendingReport or own then
			return
		end
		pendingReport = true
		local ok, msg = Net.act("Report")
		pendingReport = false
		if type(msg) == "string" and msg ~= "" then
			status = msg
		elseif ok then
			status = "Reported."
		end
		refresh()
	end

	local report = UI.button(reportWrap, "Report", "quiet", onReport)
	report.Name = "Report"
	report.TextSize = 20

	function refresh()
		local phase = folder:GetAttribute("Phase")
		local label = folder:GetAttribute("TourLabel")
		local index = folder:GetAttribute("TourIndex")
		if type(label) ~= "string" then
			label = ""
		end
		if type(index) ~= "number" then
			index = 0
		end
		if index ~= seenIndex then
			seenIndex = index
			status = ""
		end
		local own = isOwnRoom()
		local locked = phase == "Tour" and lockedNow(label)
		local touring = phase == "Tour" and label ~= ""
		panel.Visible = touring
		caption.Visible = touring
		results.Visible = phase == "Results"
		starRow.Visible = not own
		ownLabel.Visible = own
		reportWrap.Visible = not own
		local myStars = player:GetAttribute("MyStars")
		for star, button in ipairs(starButtons) do
			local on = myStars == star
			button.BackgroundColor3 = UI.rgb(if on then "butter" else "lavender")
			button.Active = not locked and not own
			button.AutoButtonColor = not locked and not own
		end
		if status ~= "" then
			caption.Text = status
		elseif locked then
			caption.Text = "Locked in"
		elseif own then
			caption.Text = "Your room"
		else
			caption.Text = "Rate this room"
		end
		caption.BackgroundColor3 = UI.rgb(if locked then "butter" else "mint")
		if locked and not wasLocked then
			UI.pop(captionScale, UIKit.Motion.reveal)
		end
		wasLocked = locked
		if phase == "Results" then
			local payload = folder:GetAttribute("Podium")
			if type(payload) ~= "string" then
				payload = ""
			end
			local theme = folder:GetAttribute("ThemeName")
			if type(theme) ~= "string" or theme == "" then
				theme = "Room Glow Up"
			end
			local cardStars = player:GetAttribute("CardStars")
			local cardLine = player:GetAttribute("CardLine")
			if type(cardLine) ~= "string" then
				cardLine = ""
			end
			local stars = if type(cardStars) == "number" then cardStars else nil
			local coinsAttr = player:GetAttribute("EyeCoins")
			local coins = if type(coinsAttr) == "number" then coinsAttr else 0
			paint(payload, theme, stars, cardLine, coins)
		end
		layout()
	end

	layout()
	refresh()
	folder:GetAttributeChangedSignal("Phase"):Connect(refresh)
	folder:GetAttributeChangedSignal("TourLabel"):Connect(refresh)
	folder:GetAttributeChangedSignal("TourIndex"):Connect(refresh)
	folder:GetAttributeChangedSignal("TourTarget"):Connect(refresh)
	folder:GetAttributeChangedSignal("TourPlot"):Connect(refresh)
	folder:GetAttributeChangedSignal("Podium"):Connect(refresh)
	folder:GetAttributeChangedSignal("ThemeName"):Connect(refresh)
	player:GetAttributeChangedSignal("MyStars"):Connect(refresh)
	player:GetAttributeChangedSignal("CardStars"):Connect(refresh)
	player:GetAttributeChangedSignal("CardLine"):Connect(refresh)
	player:GetAttributeChangedSignal("EyeCoins"):Connect(refresh)
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
			nextCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				layout()
				refresh()
			end)
		end
		layout()
	end)
end

return Vote
