--!strict
-- Holiday Season runs through December 31. After that, winter themes are active
-- until the next November. Config.Season can force either set.

local Season = {}

export type Parts = { year: number, month: number, day: number, hour: number, min: number, sec: number }

-- Howard Hinnant's civil_from_days / days_from_civil, so tests do not depend on the machine timezone.
local function daysFromCivil(year: number, month: number, day: number): number
	local y = year
	local m = month
	if m <= 2 then
		y -= 1
		m += 9
	else
		m -= 3
	end
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local doy = math.floor((153 * m + 2) / 5) + day - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

function Season.unix(year: number, month: number, day: number, hour: number?, min: number?, sec: number?): number
	local days = daysFromCivil(year, month, day)
	return days * 86400 + (hour or 0) * 3600 + (min or 0) * 60 + (sec or 0)
end

function Season.parts(unix: number, offsetHours: number): Parts
	local shifted = unix + offsetHours * 3600
	local days = math.floor(shifted / 86400)
	local rem = shifted - days * 86400
	if rem < 0 then
		rem += 86400
		days -= 1
	end
	local z = days + 719468
	local adjusted = if z >= 0 then z else z - 146096
	local era = math.floor(adjusted / 146097)
	local doe = z - era * 146097
	local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
	local mp = math.floor((5 * doy + 2) / 153)
	local d = doy - math.floor((153 * mp + 2) / 5) + 1
	local m = mp + (if mp < 10 then 3 else -9)
	y += if m <= 2 then 1 else 0
	return {
		year = y,
		month = m,
		day = d,
		hour = math.floor(rem / 3600),
		min = math.floor(rem / 60) % 60,
		sec = rem % 60,
	}
end

-- setting: "holiday", "winter", or "auto".
function Season.resolve(setting: string, unix: number, offsetHours: number): string
	if setting == "holiday" or setting == "winter" then
		return setting
	end
	local parts = Season.parts(unix, offsetHours)
	if parts.month == 11 or parts.month == 12 then
		return "holiday"
	end
	return "winter"
end

return Season
