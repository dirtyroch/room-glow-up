--!strict
-- Spotlight, sting, and crowd emoji for the room on tour.
-- Driven only by TourIndex, TourPlot, and TourLabel. No client room timer.
-- Crowd emoji are a reaction, not a vote, and they never change the score.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Listen = require(script.Parent.Listen)
local UI = require(script.Parent.UI)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bases = require(Shared:WaitForChild("Bases") :: ModuleScript) :: any
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Look = require(Shared:WaitForChild("Look") :: ModuleScript) :: any
local UIKit = UI.kit

local Show = {}

local function ease(style: string): Enum.EasingStyle
	if style == "Back" then
		return Enum.EasingStyle.Back
	end
	return Enum.EasingStyle.Quad
end

function Show.start()
	local folder = ReplicatedStorage:WaitForChild("RoundState")
	local host = Instance.new("Part")
	host.Name = "TourSpot"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.new(1, 1, 1)
	host.Parent = Workspace

	local spot = Instance.new("SpotLight")
	spot.Name = "Spot"
	spot.Angle = 78
	spot.Range = 90
	spot.Brightness = 0
	spot.Shadows = false
	local cream = UIKit.color("cream")
	spot.Color = Color3.fromRGB(cream[1], cream[2], cream[3])
	spot.Parent = host

	local rings: { Part } = {}
	for index = 1, 4 do
		local ring = Instance.new("Part")
		ring.Name = "Cone"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(cream[1], cream[2], cream[3])
		ring.Transparency = 1
		ring.CastShadow = false
		ring.Size = Vector3.new(0.35, 2 + index * 3, 2 + index * 3)
		ring.Parent = host
		rings[index] = ring
	end

	local function tone(themeId: string, index: number): Color3
		local swatch = Look.swatch(themeId)
		local channels = swatch[index]
		return Color3.fromRGB(channels[1], channels[2], channels[3])
	end

	local function paintCone(aim: Vector3, open: boolean)
		local origin = host.Position
		local look = if (aim - origin).Magnitude > 0.1 then (aim - origin).Unit else host.CFrame.LookVector
		for index, ring in ipairs(rings) do
			local dist = 6 + index * 6
			local diam = 2 + index * 3.4
			ring.Size = Vector3.new(0.4, diam, diam)
			ring.CFrame = CFrame.lookAt(origin + look * dist, origin + look * (dist + 1)) * CFrame.Angles(0, math.rad(90), 0)
			if open and not Listen.lowEnd() then
				ring.Transparency = 0.72 + index * 0.04
			else
				ring.Transparency = 1
			end
		end
	end

	local function confetti(at: Vector3, themeId: string)
		if Listen.lowEnd() then
			return
		end
		local holder = Instance.new("Part")
		holder.Name = "Confetti"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		holder.Position = at
		holder.Parent = Workspace
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Speed = NumberRange.new(4, 9)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Acceleration = Vector3.new(0, -14, 0)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 0.05),
		})
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, tone(themeId, 1)),
			ColorSequenceKeypoint.new(0.5, tone(themeId, 2)),
			ColorSequenceKeypoint.new(1, tone(themeId, 3)),
		})
		emitter.LightEmission = 0.35
		emitter.Parent = holder
		emitter:Emit(22)
		Debris:AddItem(holder, 1.6)
	end

	local function riseStar(aim: Vector3, themeId: string)
		if Listen.lowEnd() then
			return
		end
		local model = Instance.new("Model")
		model.Name = "RisingStar"
		local origin = aim + Vector3.new(0, 1.4, 0)
		local function bit(name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType): Part
			local piece = Instance.new("Part")
			piece.Name = name
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			piece.Material = Enum.Material.Neon
			piece.Color = color
			piece.Size = size
			piece.CFrame = cf
			piece.Shape = shape
			piece.Parent = model
			return piece
		end
		local gold = tone(themeId, 1)
		local across = bit("Across", Vector3.new(2.4, 0.35, 0.35), CFrame.new(origin), gold, Enum.PartType.Block)
		local up = bit("Up", Vector3.new(0.35, 2.4, 0.35), CFrame.new(origin), gold, Enum.PartType.Block)
		local core = bit("Core", Vector3.new(0.7, 0.7, 0.7), CFrame.new(origin), tone(themeId, 3), Enum.PartType.Ball)
		model.Parent = Workspace
		local info = TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local lift = Vector3.new(0, 8, 0)
		TweenService:Create(across, info, { CFrame = across.CFrame + lift }):Play()
		TweenService:Create(up, info, { CFrame = up.CFrame + lift }):Play()
		TweenService:Create(core, info, { CFrame = core.CFrame + lift }):Play()
		confetti(origin, themeId)
		Debris:AddItem(model, 2.2)
	end

	local board = Instance.new("BillboardGui")
	board.Name = "Crowd"
	board.Size = UDim2.fromOffset(220, 64)
	board.StudsOffset = Vector3.new(0, 5, 0)
	board.AlwaysOnTop = false
	board.MaxDistance = 180
	board.Enabled = false
	board.Parent = host
	local crowd = Instance.new("TextLabel")
	crowd.Name = "Emoji"
	crowd.BackgroundTransparency = 1
	crowd.Size = UDim2.fromScale(1, 1)
	crowd.Font = Enum.Font.GothamBold
	crowd.TextSize = 32
	crowd.TextColor3 = UI.rgb("ink")
	crowd.Text = ""
	crowd.Parent = board
	local crowdScale = Instance.new("UIScale")
	crowdScale.Parent = crowd

	local seenRoom = ""
	local seenLocked = false

	local function playSting(speed: number, volume: number)
		local heard = Listen.volume(volume)
		if Listen.lowEnd() then
			heard *= 0.4
		end
		if heard <= 0 then
			return
		end
		local sound = Instance.new("Sound")
		sound.SoundId = Config.Show.Sting
		sound.PlaybackSpeed = speed
		sound.Volume = heard
		sound.RollOffMaxDistance = 80
		sound.Parent = host
		sound:Play()
		Debris:AddItem(sound, 2)
	end

	local function tweenLight(motion: { from: number, to: number, time: number, style: string }, goal: number)
		spot.Brightness = motion.from
		local info = TweenInfo.new(motion.time, ease(motion.style), Enum.EasingDirection.Out)
		TweenService:Create(spot, info, { Brightness = goal }):Play()
	end

	local function hide()
		seenRoom = ""
		seenLocked = false
		spot.Brightness = 0
		board.Enabled = false
		paintCone(host.Position + host.CFrame.LookVector, false)
	end

	local function reveal(roundType: string, plot: number, index: number, locked: boolean)
		local px, py, pz, lx, ly, lz = Bases.camera(roundType, plot)
		local aim = Vector3.new(lx, ly, lz)
		host.CFrame = CFrame.lookAt(Vector3.new(px, py, pz), aim)
		local themeId = folder:GetAttribute("ThemeId")
		local themeKey = if type(themeId) == "string" then themeId else ""
		spot.Color = tone(themeKey, 1)
		for _, ring in ipairs(rings) do
			ring.Color = tone(themeKey, 2)
		end
		paintCone(aim, true)
		if not locked then
			riseStar(aim, themeKey)
		end
		local motion = UIKit.Motion.spotlight
		local goal = if locked then UIKit.Motion.lock.to else motion.to
		goal *= if Listen.lowEnd() then 0.4 else 1
		tweenLight(motion, goal)
		playSting(1.25, 0.55)
		local marks = Config.Show.Crowd
		local count = #marks
		local a = marks[(index - 1) % count + 1]
		local b = marks[index % count + 1]
		local c = marks[(index + 1) % count + 1]
		crowd.Text = a .. "   " .. b .. "   " .. c
		board.Enabled = true
		UI.pop(crowdScale, UIKit.Motion.crowd)
	end

	local function lockBeat()
		tweenLight(UIKit.Motion.lock, UIKit.Motion.lock.to)
		playSting(0.85, 0.28)
	end

	local function apply()
		local phase = folder:GetAttribute("Phase")
		if phase ~= "Tour" then
			hide()
			return
		end
		local roundType = folder:GetAttribute("RoundType")
		if type(roundType) ~= "string" or roundType == "" then
			roundType = "room"
		end
		local label = folder:GetAttribute("TourLabel")
		local index = folder:GetAttribute("TourIndex")
		local plot = folder:GetAttribute("TourPlot")
		if type(label) ~= "string" or label == "" or type(index) ~= "number" or index < 1 or type(plot) ~= "number" or plot < 1 then
			return
		end
		local roomKey = tostring(index) .. ":" .. tostring(plot)
		local isLocked = string.find(label, "Locked", 1, true) ~= nil
		if roomKey ~= seenRoom then
			seenRoom = roomKey
			seenLocked = isLocked
			reveal(roundType, plot, index, isLocked)
			return
		end
		if isLocked and not seenLocked then
			seenLocked = true
			lockBeat()
		elseif not isLocked then
			seenLocked = false
		end
	end

	folder:GetAttributeChangedSignal("Phase"):Connect(apply)
	folder:GetAttributeChangedSignal("TourIndex"):Connect(apply)
	folder:GetAttributeChangedSignal("TourPlot"):Connect(apply)
	folder:GetAttributeChangedSignal("TourLabel"):Connect(apply)
	folder:GetAttributeChangedSignal("RoundType"):Connect(apply)
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("LowEnd"):Connect(function()
		local phase = folder:GetAttribute("Phase")
		if phase == "Tour" and seenRoom ~= "" then
			local roundType = folder:GetAttribute("RoundType")
			local plot = folder:GetAttribute("TourPlot")
			if type(roundType) == "string" and type(plot) == "number" then
				local _, _, _, lx, ly, lz = Bases.camera(roundType, plot)
				paintCone(Vector3.new(lx, ly, lz), true)
			end
		else
			paintCone(host.Position, false)
		end
	end)
	apply()
end

return Show
