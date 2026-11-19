--!strict
-- Theme Hint lists pieces whose tags match the theme.
-- The theme name is already on the board. This line is extra, not a replacement.

local Hints = {}

function Hints.names(themeId: string, list: { any }, limit: number?): { string }
	local cap = limit or 4
	local out: { string } = {}
	if type(themeId) ~= "string" or themeId == "" then
		return out
	end
	for _, item in ipairs(list) do
		local tags = item.tags
		if type(tags) == "table" then
			for index, tag in ipairs(tags) do
				if index > 1 and tag == themeId then
					table.insert(out, item.name)
					break
				end
			end
		end
		if #out >= cap then
			break
		end
	end
	return out
end

function Hints.line(themeId: string, list: { any }): string
	local names = Hints.names(themeId, list, 4)
	if #names == 0 then
		return ""
	end
	return table.concat(names, ", ")
end

return Hints
