--!strict
-- Hides room ceilings and their fixtures (parts with a Ceiling height
-- attribute) while the camera is above them, so the build and tour cameras
-- still look into the room. Lights under the ceiling stay on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Rule = require(Logic:WaitForChild("Cutaway") :: ModuleScript) :: any

local Cutaway = {}

function Cutaway.start()
	local tracked: { [BasePart]: boolean } = {}
	local function track(inst: Instance)
		if inst:IsA("BasePart") and type(inst:GetAttribute("Ceiling")) == "number" then
			tracked[inst] = false
		end
	end
	for _, inst in Workspace:GetDescendants() do
		track(inst)
	end
	Workspace.DescendantAdded:Connect(track)
	Workspace.DescendantRemoving:Connect(function(inst)
		if inst:IsA("BasePart") then
			tracked[inst] = nil
		end
	end)
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local y = camera.CFrame.Position.Y
		for part, wasHidden in tracked do
			local hide = Rule.hidden(y, part:GetAttribute("Ceiling"))
			if hide ~= wasHidden then
				tracked[part] = hide
				part.LocalTransparencyModifier = if hide then 1 else 0
			end
		end
	end)
end

return Cutaway
