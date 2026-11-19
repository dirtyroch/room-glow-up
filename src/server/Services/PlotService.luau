--!strict
-- Builds ten plots and the three shells. Assigns a plot on join and frees it on leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlotService = {}
local ctx: any = nil
local state: any = nil
local models: { Model } = {}
local displayNames: { [number]: string } = {}
local Voting: any = nil

local function face(): Enum.Font
	local kit = ctx.UIKit
	local named = (Enum.Font :: any)[kit.Typeface]
	if typeof(named) == "EnumItem" then
		return named :: Enum.Font
	end
	return Enum.Font.GothamBold
end

local function ink(): Color3
	local channels = ctx.UIKit.color("ink")
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

local function cream(): Color3
	local channels = ctx.UIKit.color("cream")
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

local function setShellVisible(shellModel: Model, visible: boolean)
	for _, child in shellModel:GetDescendants() do
		if child:IsA("BasePart") then
			if visible then
				local transparency = child:GetAttribute("ShowT")
				local query = child:GetAttribute("ShowQ")
				local collide = child:GetAttribute("ShowC")
				child.Transparency = if type(transparency) == "number" then transparency else 0
				child.CanQuery = if type(query) == "boolean" then query else true
				child.CanCollide = collide == true
			else
				child.Transparency = 1
				child.CanQuery = false
				child.CanCollide = false
			end
		end
	end
end

local function itemsFolder(index: number): Folder?
	local model = models[index]
	if not model then
		return nil
	end
	local folder = model:FindFirstChild("Items")
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function show(roundType: string?)
	local want = roundType or "room"
	for _, model in ipairs(models) do
		local room = model:FindFirstChild("RoomBase")
		local house = model:FindFirstChild("GingerbreadBase")
		local tree = model:FindFirstChild("TreeBase")
		if room and room:IsA("Model") then
			setShellVisible(room, want == "room")
		end
		if house and house:IsA("Model") then
			setShellVisible(house, want == "gingerbread")
		end
		if tree and tree:IsA("Model") then
			setShellVisible(tree, want == "tree")
		end
	end
end

local function clearIndex(index: number)
	local folder = itemsFolder(index)
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		child:Destroy()
	end
end

local function buildPlot(index: number, folder: Folder)
	local Bases = ctx.Bases
	local Props = ctx.Props
	local ox, oy, oz = Bases.plotOrigin(index)
	local model = Instance.new("Model")
	model.Name = "Plot" .. tostring(index)
	model:SetAttribute("PlotIndex", index)
	local pivot = Instance.new("Part")
	pivot.Name = "Pivot"
	pivot.Anchored = true
	pivot.CanCollide = false
	pivot.CanQuery = false
	pivot.CanTouch = false
	pivot.Transparency = 1
	pivot.Size = Vector3.new(1, 1, 1)
	pivot.CFrame = CFrame.new(ox, oy, oz)
	pivot.Parent = model
	model.PrimaryPart = pivot

	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanQuery = false
	sign.CanTouch = false
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = cream()
	sign.Size = Vector3.new(6, 2.2, 0.4)
	local front = Bases.worldCell() * 4
	sign.CFrame = pivot.CFrame * CFrame.new(0, 3.2, front)
	sign.Parent = model
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(180, 48)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 220
	billboard.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "SignLabel"
	label.BackgroundColor3 = cream()
	label.BackgroundTransparency = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = face()
	label.Text = "Plot " .. tostring(index)
	label.TextColor3 = ink()
	label.TextScaled = true
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label

	local room = Instance.new("Model")
	room.Name = "RoomBase"
	room.Parent = model
	local house = Instance.new("Model")
	house.Name = "GingerbreadBase"
	house.Parent = model
	local tree = Instance.new("Model")
	tree.Name = "TreeBase"
	tree.Parent = model
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = model
	model.Parent = folder
	Props.room(room)
	Props.gingerbread(house)
	Props.tree(tree)
	models[index] = model
end

local function phaseNow(): string
	local round = ctx.round
	if type(round) == "table" and type(round.phase) == "string" then
		return round.phase
	end
	return "Lobby"
end

local function writeSign(index: number, phase: string)
	local model = models[index]
	if not model then
		return
	end
	local label = model:FindFirstChild("SignLabel", true)
	if label and label:IsA("TextLabel") then
		label.Text = Voting.signLabel(phase, index, displayNames[index])
	end
end

local function veil(phase: string)
	local hideOwner = phase == "Tour" or phase == "Results"
	for index = 1, #models do
		writeSign(index, phase)
		local model = models[index]
		if model then
			if hideOwner then
				model:SetAttribute("OwnerKey", nil)
			else
				model:SetAttribute("OwnerKey", ctx.Plots.owner(state, index))
			end
		end
	end
end

local function assign(player: Player): number?
	local key = tostring(player.UserId)
	local index = ctx.Plots.assign(state, key)
	if not index then
		player:SetAttribute("Plot", nil)
		return nil
	end
	player:SetAttribute("Plot", index)
	local model = models[index]
	local phase = phaseNow()
	if phase == "Tour" or phase == "Results" then
		model:SetAttribute("OwnerKey", nil)
	else
		model:SetAttribute("OwnerKey", key)
	end
	local display = player.DisplayName
	if display == "" then
		display = player.Name
	end
	displayNames[index] = display
	writeSign(index, phaseNow())
	return index
end

local function release(player: Player)
	local key = tostring(player.UserId)
	local index = ctx.Plots.release(state, key)
	player:SetAttribute("Plot", nil)
	player:SetAttribute("BuildPlot", nil)
	if not index then
		return
	end
	clearIndex(index)
	local model = models[index]
	if not model then
		return
	end
	model:SetAttribute("OwnerKey", nil)
	model:SetAttribute("ThemeMatch", 0)
	model:SetAttribute("CoinsLeft", 0)
	displayNames[index] = nil
	writeSign(index, phaseNow())
end

local function handOff(fromPlayer: Player, toKey: string): number?
	local fromKey = tostring(fromPlayer.UserId)
	local keep, freed = ctx.Plots.transfer(state, fromKey, toKey)
	fromPlayer:SetAttribute("Plot", nil)
	fromPlayer:SetAttribute("BuildPlot", nil)
	if type(freed) == "number" then
		clearIndex(freed)
		local empty = models[freed]
		if empty then
			empty:SetAttribute("OwnerKey", nil)
			empty:SetAttribute("ThemeMatch", 0)
			empty:SetAttribute("CoinsLeft", 0)
		end
		displayNames[freed] = nil
		writeSign(freed, phaseNow())
	end
	if type(keep) ~= "number" then
		return nil
	end
	local userId = tonumber(toKey)
	local toPlayer = if userId then Players:GetPlayerByUserId(userId) else nil
	if toPlayer then
		toPlayer:SetAttribute("Plot", keep)
		toPlayer:SetAttribute("BuildPlot", keep)
		local display = toPlayer.DisplayName
		if display == "" then
			display = toPlayer.Name
		end
		displayNames[keep] = display
	end
	local model = models[keep]
	local phase = phaseNow()
	if model and phase ~= "Tour" and phase ~= "Results" then
		model:SetAttribute("OwnerKey", toKey)
	end
	writeSign(keep, phase)
	return keep
end

function PlotService.init(c: any)
	ctx = c
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	ctx.UIKit = require(Shared:WaitForChild("UIKit") :: ModuleScript) :: any
	ctx.Bases = require(Shared:WaitForChild("Bases") :: ModuleScript) :: any
	local Logic = Shared:WaitForChild("Logic")
	ctx.Plots = require(Logic:WaitForChild("Plots") :: ModuleScript) :: any
	Voting = require(Logic:WaitForChild("Voting") :: ModuleScript) :: any
	ctx.Props = require(script.Parent.Parent:WaitForChild("Props") :: ModuleScript) :: any
	local Plaza = require(script.Parent.Parent:WaitForChild("Plaza") :: ModuleScript) :: any
	local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
	state = ctx.Plots.create(Config.Plots)
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = Workspace
	for index = 1, Config.Plots do
		buildPlot(index, folder)
	end
	show("room")
	Plaza.build()
	ctx.plots = {
		assign = assign,
		release = release,
		handOff = handOff,
		veil = veil,
		indexOf = function(key: string): number?
			return ctx.Plots.plotOf(state, key)
		end,
		model = function(index: number): Model?
			return models[index]
		end,
		show = show,
		tint = function(family: string)
			for _, model in ipairs(models) do
				ctx.Props.tintShell(model, family)
			end
		end,
		clearItems = function()
			for index = 1, #models do
				clearIndex(index)
			end
		end,
		clearIndex = clearIndex,
		removePiece = function(index: number, pieceId: number)
			local folderItems = itemsFolder(index)
			if not folderItems then
				return
			end
			local existing = folderItems:FindFirstChild("P" .. tostring(pieceId))
			if existing then
				existing:Destroy()
			end
		end,
		spawnPiece = function(index: number, piece: any, roundType: string, fresh: boolean?)
			local model = models[index]
			if not model or not model.PrimaryPart then
				return
			end
			local Items = require(Shared:WaitForChild("Items") :: ModuleScript) :: any
			local item = Items.get(piece.itemId)
			if not item then
				return
			end
			local folderItems = itemsFolder(index)
			if not folderItems then
				return
			end
			local built = ctx.Props.prop(model.PrimaryPart.CFrame, item, piece, roundType)
			built:SetAttribute("Fresh", fresh == true)
			built.Parent = folderItems
		end,
	}
end

return PlotService
