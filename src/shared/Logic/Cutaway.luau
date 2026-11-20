--!strict
-- Dollhouse cutaway: a room's ceiling hides while the camera looks down on it
-- from above (build and tour cameras), and shows from inside the room.

local Cutaway = {}

-- Margin so the ceiling does not flicker as the camera crosses its height.
Cutaway.Margin = 0.5

function Cutaway.hidden(cameraY: any, ceilingY: any): boolean
	if type(cameraY) ~= "number" or type(ceilingY) ~= "number" then
		return false
	end
	return cameraY > ceilingY - Cutaway.Margin
end

return Cutaway
