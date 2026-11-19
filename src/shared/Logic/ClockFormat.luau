--!strict
-- Countdown text for the HUD. Negative means the lobby is waiting, not counting.

local ClockFormat = {}

function ClockFormat.clock(seconds: number): string
	if seconds < 0 then
		return "--"
	end
	local whole = math.floor(seconds + 1e-6)
	local minutes = math.floor(whole / 60)
	local remain = whole % 60
	return string.format("%d:%02d", minutes, remain)
end

return ClockFormat
