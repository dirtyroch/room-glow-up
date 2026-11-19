--!strict
-- Place pop, star sting, podium confetti, level burst, and a quiet music loop.
-- Particles live on world parts. Mute and low-end scale them down.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Listen = require(script.Parent.Listen)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local UIKit = require(Shared:WaitForChild("UIKit") :: ModuleScript) :: any

local Juice = {}

local function anchor(): BasePart
	local existing = Workspace:FindFirstChild("JuiceAnchor")
	if existing and existing:IsA("BasePart") then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = "JuiceAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = Vector3.new(0, 6, 0)
	part.Parent = Workspace
	return part
end

local function play(parent: Instance, soundId: string, base: number, speed: number)
	local volume = Listen.volume(base)
	if volume <= 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.RollOffMaxDistance = 70
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 2)
end

local function burst(part: BasePart, count: number, lifetime: number)
	local amount = Listen.particles(count)
	if amount <= 0 then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if Listen.lowEnd() then 0.2 else 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.LightEmission = if Listen.lowEnd() then 0.15 else 0.4
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 156), Color3.fromRGB(255, 186, 173))
	emitter.Parent = part
	emitter:Emit(amount)
	Debris:AddItem(emitter, 1.2)
end

local function sparkle(part: BasePart)
	burst(part, 10, 0.5)
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
	play(host, Config.Audio.Place, Config.Audio.PlaceVolume, 1)
	sparkle(host)
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

	local host = anchor()
	local music = Instance.new("Sound")
	music.Name = "GlowMusic"
	music.SoundId = Config.Audio.Music
	music.Looped = true
	music.Volume = Listen.volume(Config.Audio.MusicVolume)
	music.Parent = SoundService
	music:Play()

	local function syncMusic()
		music.Volume = Listen.volume(Config.Audio.MusicVolume)
	end

	local player = game:GetService("Players").LocalPlayer
	player:GetAttributeChangedSignal("Muted"):Connect(syncMusic)
	player:GetAttributeChangedSignal("Volume"):Connect(syncMusic)

	local folder = ReplicatedStorage:WaitForChild("RoundState")
	folder:GetAttributeChangedSignal("Phase"):Connect(function()
		if folder:GetAttribute("Phase") == "Results" then
			local count = if Listen.lowEnd() then Config.Audio.ConfettiLow else Config.Audio.Confetti
			burst(host, count, 0.8)
		end
	end)

	player:GetAttributeChangedSignal("CardStars"):Connect(function()
		local stars = player:GetAttribute("CardStars")
		if folder:GetAttribute("Phase") == "Results" and type(stars) == "number" and stars > 0 then
			play(host, Config.Audio.Sting, Config.Audio.StingVolume, 1.35)
		end
	end)

	player:GetAttributeChangedSignal("LevelUp"):Connect(function()
		local levels = player:GetAttribute("LevelUp")
		if type(levels) == "number" and levels > 0 then
			play(host, Config.Audio.Level, Config.Audio.LevelVolume, 1.1)
			local count = if Listen.lowEnd() then Config.Audio.ConfettiLow else Config.Audio.Confetti
			burst(host, count, 0.7)
		end
	end)
end

return Juice
