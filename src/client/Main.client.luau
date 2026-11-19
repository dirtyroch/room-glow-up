--!strict
-- Client entry. Waits for the round folder, then mounts the phone HUD.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local roundFolder = ReplicatedStorage:WaitForChild(Config.Names.RoundState)

if playerGui:IsA("PlayerGui") and roundFolder:IsA("Folder") then
	Hud.mount(playerGui, roundFolder, function(name: string): (boolean, string?)
		return Net.act(name)
	end)
end
