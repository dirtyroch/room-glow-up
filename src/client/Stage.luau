--!strict
-- Applies the theme-family light preset in the lobby and on tour.
-- Low-end turns bloom, the color grade, atmosphere, and wash lights off.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Listen = require(script.Parent.Listen)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Look = require(Shared:WaitForChild("Look") :: ModuleScript) :: any
local Logic = Shared:WaitForChild("Logic")
local LowEnd = require(Logic:WaitForChild("LowEnd") :: ModuleScript) :: any

local Stage = {}

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function ensure(className: string, name: string): any
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then
		return found
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = Lighting
	return made
end

local function familyNow(folder: Instance): string
	local phase = folder:GetAttribute("Phase")
	local themeId = folder:GetAttribute("ThemeId")
	if phase == "Lobby" or type(themeId) ~= "string" or themeId == "" then
		if folder:GetAttribute("Season") == "winter" then
			return "winter"
		end
		return "hearth"
	end
	return Look.family(themeId)
end

function Stage.start()
	local folder = ReplicatedStorage:WaitForChild("RoundState")
	local player = Players.LocalPlayer

	local function apply()
		local low = Listen.lowEnd()
		local fx = LowEnd.effects(low)
		local grade = Look.preset(familyNow(folder))
		Lighting.ClockTime = grade.clock
		Lighting.Brightness = if fx.lights then grade.brightness else grade.brightness * 0.85
		Lighting.Ambient = rgb(grade.ambient)
		Lighting.OutdoorAmbient = rgb(grade.outdoor)
		Lighting.ColorShift_Top = rgb(grade.shift)
		Lighting.GlobalShadows = fx.shadows == true
		pcall(function()
			Lighting.Technology = if fx.technology == "Future" then Enum.Technology.Future else Enum.Technology.ShadowMap
		end)
		pcall(function()
			(Lighting :: any).ExposureCompensation = grade.exposure
		end)
		pcall(function()
			(Lighting :: any).EnvironmentDiffuseScale = 0.55
			(Lighting :: any).EnvironmentSpecularScale = 0.35
		end)

		local air = ensure("Atmosphere", "SoftAir")
		air.Density = if fx.atmosphere then grade.density else 0
		air.Offset = grade.offset
		air.Haze = if fx.atmosphere then grade.haze else 0
		air.Glare = if fx.atmosphere then grade.glare else 0
		air.Color = rgb(grade.air)
		air.Decay = rgb(grade.decay)

		local bloom = ensure("BloomEffect", "Bloom")
		bloom.Enabled = fx.bloom == true
		bloom.Intensity = grade.bloom
		bloom.Size = grade.bloomSize
		bloom.Threshold = grade.bloomThreshold

		local correction = ensure("ColorCorrectionEffect", "Grade")
		correction.Enabled = fx.correction == true
		correction.Saturation = grade.saturation
		correction.Contrast = grade.contrast
		correction.Brightness = grade.grade
		correction.TintColor = rgb(grade.tint)

		local wash = rgb(grade.light)
		local function isWash(child: Instance): boolean
			return child.Name == "SoftLight" and (child:IsA("PointLight") or child:IsA("SurfaceLight") or child:IsA("SpotLight"))
		end
		for _, child in Workspace:GetDescendants() do
			if isWash(child) then
				local lamp = child :: any
				local saved = lamp:GetAttribute("SoftB")
				if type(saved) ~= "number" then
					lamp:SetAttribute("SoftB", lamp.Brightness)
					saved = lamp.Brightness
				end
				if lamp:GetAttribute("Kind") == "wash" or lamp:GetAttribute("Kind") == "key" then
					lamp.Color = wash
				end
				lamp.Enabled = fx.lights == true
				lamp.Brightness = if fx.lights then saved else 0
			end
		end
	end

	folder:GetAttributeChangedSignal("Phase"):Connect(apply)
	folder:GetAttributeChangedSignal("ThemeId"):Connect(apply)
	folder:GetAttributeChangedSignal("Season"):Connect(apply)
	player:GetAttributeChangedSignal("LowEnd"):Connect(apply)
	Workspace.DescendantAdded:Connect(function(child)
		if child.Name == "SoftLight" and (child:IsA("PointLight") or child:IsA("SurfaceLight") or child:IsA("SpotLight")) then
			apply()
		end
	end)
	apply()
end

return Stage
