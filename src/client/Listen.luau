--!strict
-- Reads mute, volume, and the low-end toggle for world effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Audio = require(Logic:WaitForChild("Audio") :: ModuleScript) :: any
local LowEnd = require(Logic:WaitForChild("LowEnd") :: ModuleScript) :: any

local Listen = {}

local function quality(): number
	local level = 10
	pcall(function()
		local settings = UserSettings():GetService("UserGameSettings")
		local saved = settings.SavedQualityLevel
		if typeof(saved) == "EnumItem" then
			level = saved.Value
		end
	end)
	return level
end

function Listen.lowEnd(): boolean
	local player = Players.LocalPlayer
	local mode = if player then player:GetAttribute("LowEnd") else "auto"
	return LowEnd.resolve(mode, LowEnd.auto(quality()))
end

function Listen.volume(base: number): number
	local player = Players.LocalPlayer
	local muted = player ~= nil and player:GetAttribute("Muted") == true
	local volume = if player then player:GetAttribute("Volume") else 1
	return Audio.volume(muted, volume, base)
end

function Listen.particles(count: number): number
	return Audio.particles(count, Listen.lowEnd())
end

return Listen
