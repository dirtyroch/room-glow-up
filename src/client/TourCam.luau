--!strict
-- Moves the camera when the server changes tour index, tour plot, or tour label.
-- It does not advance rooms on a client timer. A lock-in mark in the label keeps
-- the same plot, so the camera stays until the server moves the index.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bases = require(Shared:WaitForChild("Bases") :: ModuleScript) :: any

local TourCam = {}

function TourCam.start()
	local player = Players.LocalPlayer
	local folder = ReplicatedStorage:WaitForChild("RoundState")
	local lastKey = ""

	local function release()
		if lastKey == "free" then
			return
		end
		lastKey = "free"
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
	end

	local function aim(roundType: string, plotIndex: number, reason: string)
		local key = reason .. ":" .. roundType .. ":" .. tostring(plotIndex)
		if key == lastKey then
			return
		end
		lastKey = key
		local camera = Workspace.CurrentCamera
		if not camera then
			lastKey = ""
			return
		end
		local px, py, pz, lx, ly, lz = Bases.camera(roundType, plotIndex)
		camera.CameraType = Enum.CameraType.Scriptable
		local goal = CFrame.lookAt(Vector3.new(px, py, pz), Vector3.new(lx, ly, lz))
		TweenService:Create(camera, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal }):Play()
	end

	local function apply()
		local phase = folder:GetAttribute("Phase")
		local roundType = folder:GetAttribute("RoundType")
		if type(roundType) ~= "string" or roundType == "" then
			roundType = "room"
		end
		-- TourLabel, TourIndex, and TourPlot are published together by the server.
		local label = folder:GetAttribute("TourLabel")
		local index = folder:GetAttribute("TourIndex")
		local plot = folder:GetAttribute("TourPlot")
		if phase == "Tour" and type(label) == "string" and label ~= "" and type(index) == "number" and index > 0 and type(plot) == "number" and plot > 0 then
			aim(roundType, plot, "tour")
			return
		end
		if (phase == "Build" or phase == "ThemeReveal") and player:GetAttribute("Spectating") ~= true then
			local mine = player:GetAttribute("Plot")
			if type(mine) == "number" and mine > 0 then
				aim(roundType, mine, tostring(phase))
				return
			end
		end
		release()
	end

	folder:GetAttributeChangedSignal("Phase"):Connect(apply)
	folder:GetAttributeChangedSignal("TourIndex"):Connect(apply)
	folder:GetAttributeChangedSignal("TourPlot"):Connect(apply)
	folder:GetAttributeChangedSignal("TourLabel"):Connect(apply)
	folder:GetAttributeChangedSignal("RoundType"):Connect(apply)
	player:GetAttributeChangedSignal("Plot"):Connect(apply)
	player:GetAttributeChangedSignal("Spectating"):Connect(apply)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		lastKey = ""
		apply()
	end)
	apply()
end

return TourCam
