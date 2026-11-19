--!strict
-- Volume, mute, and how many sparkles to throw.
-- Effects stay in the world. This module never parents anything to a screen.

local Audio = {}

Audio.onHud = false

function Audio.volume(muted: boolean, volume: any, base: number): number
	if muted == true then
		return 0
	end
	local scale = volume
	if type(scale) ~= "number" or scale ~= scale then
		scale = 1
	end
	if scale < 0 then
		scale = 0
	elseif scale > 1 then
		scale = 1
	end
	local amount = base
	if type(amount) ~= "number" or amount ~= amount or amount < 0 then
		amount = 0
	end
	return amount * scale
end

function Audio.particles(count: number, lowEnd: boolean): number
	local n = count
	if type(n) ~= "number" or n ~= n then
		n = 0
	end
	n = math.floor(n)
	if n < 0 then
		n = 0
	end
	if lowEnd == true then
		return math.max(0, math.floor(n * 0.3))
	end
	return n
end

return Audio
