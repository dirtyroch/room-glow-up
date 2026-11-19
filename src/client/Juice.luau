--!strict
-- A new prop pops in, plays a short sound, and throws a few sparkles.
-- Older props that stream in later stay still.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared:WaitForChild("UIKit") :: ModuleScript) :: any

local Juice = {}

local function sparkle(part: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.LightEmission = 0.4
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 156), Color3.fromRGB(255, 186, 173))
	emitter.Parent = part
	emitter:Emit(10)
	Debris:AddItem(emitter, 1)
end

local function pop(model: Model)
	local motion = UIKit.Motion.place
	local info = TweenInfo.new(motion.time, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Transparency < 1 then
			local goal = child.Size
			child.Size = goal * motion.from
			TweenService:Create(child, info, { Size = goal * motion.to }):Play()
		end
	end
	local host = model.PrimaryPart
	if not host then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.45
	sound.RollOffMaxDistance = 70
	sound.Parent = host
	sound:Play()
	sparkle(host)
	Debris:AddItem(sound, 2)
end

local function watch(folder: Instance)
	folder.ChildAdded:Connect(function(child)
		if not child:IsA("Model") then
			return
		end
		if child:GetAttribute("Fresh") ~= true then
			return
		end
		local placedAt = child:GetAttribute("PlacedAt")
		if type(placedAt) == "number" then
			local age = Workspace:GetServerTimeNow() - placedAt
			if age > 2.5 then
				return
			end
		end
		pop(child)
	end)
end

local function watchPlot(plot: Instance)
	local items = plot:FindFirstChild("Items")
	if items then
		watch(items)
	end
	plot.ChildAdded:Connect(function(child)
		if child.Name == "Items" then
			watch(child)
		end
	end)
end

function Juice.start()
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		watchPlot(plot)
	end
	plots.ChildAdded:Connect(watchPlot)
end

return Juice
