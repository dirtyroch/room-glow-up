--!strict
-- Fewer particles and a lighter tour when the device asks, or when the player toggles it.
-- The dream home still stops at 36 pieces. This does not raise that cap.

local LowEnd = {}

function LowEnd.auto(quality: any): boolean
	if type(quality) ~= "number" or quality ~= quality then
		return false
	end
	return quality <= 3
end

function LowEnd.resolve(mode: any, autoOn: boolean): boolean
	if mode == "on" then
		return true
	end
	if mode == "off" then
		return false
	end
	return autoOn == true
end

function LowEnd.pieceCap(requested: any): number
	local n = requested
	if type(n) ~= "number" or n ~= n then
		n = 0
	end
	n = math.floor(n)
	if n < 0 then
		return 0
	end
	if n > 36 then
		return 36
	end
	return n
end

-- A full server is 10 rooms. Low-end drops lights, shadows, and the camera tween.
function LowEnd.tour(roomCount: any, enabled: boolean): { [string]: any }
	local rooms = roomCount
	if type(rooms) ~= "number" or rooms ~= rooms then
		rooms = 0
	end
	rooms = math.floor(rooms)
	if rooms < 0 then
		rooms = 0
	end
	if rooms > 10 then
		rooms = 10
	end
	if enabled == true then
		return {
			rooms = rooms,
			particles = 2,
			lights = false,
			shadows = false,
			tween = 0,
		}
	end
	return {
		rooms = rooms,
		particles = 10,
		lights = true,
		shadows = true,
		tween = 0.55,
	}
end

function LowEnd.lightScale(enabled: boolean): number
	if enabled == true then
		return 0.4
	end
	return 1
end

-- Heavy grade (bloom, color grade, atmosphere, future lights) drops out on low-end.
function LowEnd.effects(enabled: boolean): { [string]: any }
	if enabled == true then
		return {
			bloom = false,
			correction = false,
			atmosphere = false,
			lights = false,
			shadows = false,
			technology = "ShadowMap",
		}
	end
	return {
		bloom = true,
		correction = true,
		atmosphere = true,
		lights = true,
		shadows = true,
		technology = "Future",
	}
end

return LowEnd
