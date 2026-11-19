--!strict
-- Attribute names shared by the server writer and the client HUD.
-- One folder in ReplicatedStorage carries the round. Each player carries their own role.

local Replica = {
	Phase = "Phase",
	TimeLeft = "TimeLeft",
	EndsAt = "EndsAt",
	Holding = "Holding",
	ThemeName = "ThemeName",
	ThemeId = "ThemeId",
	RoundType = "RoundType",
	TypeLabel = "TypeLabel",
	TourIndex = "TourIndex",
	TourCount = "TourCount",
	SeasonLabel = "SeasonLabel",
	Role = "RoundRole",
}

return Replica
