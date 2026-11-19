--!strict
-- Tray tiles. A ViewportFrame of the real prop when the device can take it.
-- Low-end, or a missing model, falls back to a colored silhouette.

local Preview = {}

function Preview.fits(item: any, themeId: string): boolean
	if type(themeId) ~= "string" or themeId == "" or type(item) ~= "table" then
		return false
	end
	local tags = item.tags
	if type(tags) ~= "table" then
		return false
	end
	for index, tag in ipairs(tags) do
		if index > 1 and tag == themeId then
			return true
		end
	end
	return false
end

function Preview.mode(lowEnd: boolean, hasModel: boolean): string
	if lowEnd == true or hasModel ~= true then
		return "silhouette"
	end
	return "viewport"
end

return Preview
