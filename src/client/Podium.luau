--!strict
-- World place plates. A name is written only during Results, from the podium
-- board. Tour, build, and the lobby keep 1st, 2nd, and 3rd.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Voting = require(Logic:WaitForChild("Voting") :: ModuleScript) :: any

local Podium = {}

local WORDS = { "1st", "2nd", "3rd" }

function Podium.start()
	local folder = ReplicatedStorage:WaitForChild("RoundState")
	local plaza = Workspace:WaitForChild("Plaza")

	local function paint()
		local phase = folder:GetAttribute("Phase")
		local payload = folder:GetAttribute("Podium")
		local names = { WORDS[1], WORDS[2], WORDS[3] }
		if phase == "Results" and type(payload) == "string" and payload ~= "" then
			for _, row in ipairs(Voting.decodeBoard(payload)) do
				if row.rank >= 1 and row.rank <= 3 and type(row.name) == "string" and row.name ~= "" then
					names[row.rank] = row.name
				end
			end
		end
		for _, child in plaza:GetDescendants() do
			if child:IsA("TextLabel") and child.Name == "Plate" then
				local rank = child:GetAttribute("Rank")
				if type(rank) == "number" and names[rank] ~= nil then
					child.Text = names[rank]
				end
			end
		end
	end

	folder:GetAttributeChangedSignal("Phase"):Connect(paint)
	folder:GetAttributeChangedSignal("Podium"):Connect(paint)
	paint()
end

return Podium
