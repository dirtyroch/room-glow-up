--!strict
-- Spotlight, sting, and crowd emoji for the room on tour.
-- Driven only by TourIndex, TourPlot, and TourLabel. No client room timer.
-- Crowd emoji are a reaction, not a vote, and they never change the score.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent.UI)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bases = require(Shared:WaitForChild("Bases") :: ModuleScript) :: any
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
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
		local sound = Instance.new("Sound")
		sound.SoundId = Config.Show.Sting
		sound.PlaybackSpeed = speed
		sound.Volume = volume
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
	end

	local function reveal(roundType: string, plot: number, index: number, locked: boolean)
		local px, py, pz, lx, ly, lz = Bases.camera(roundType, plot)
		host.CFrame = CFrame.lookAt(Vector3.new(px, py, pz), Vector3.new(lx, ly, lz))
		local motion = UIKit.Motion.spotlight
		local goal = if locked then UIKit.Motion.lock.to else motion.to
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
	apply()
end

return Show
