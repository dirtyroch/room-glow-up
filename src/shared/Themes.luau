--!strict
-- Starter themes for Room Glow Up. Each one is a round type (room, gingerbread, tree)
-- and a season (holiday or winter). Holiday Season is the launch list. Winter is
-- what "auto" selects after 31 Dec 2026 UTC.
--
-- Names are original. No bedrooms, no bathrooms, and no drinks with alcohol.

local Config = if script ~= nil and script.Parent ~= nil then require(script.Parent.Config) else require("./Config")

export type Theme = {
	id: string,
	name: string,
	roundType: string,
	season: string,
}

local function t(id: string, name: string, roundType: string, season: string): Theme
	return {
		id = id,
		name = name,
		roundType = roundType,
		season = season,
	}
end

local LIST: { Theme } = {
	-- Holiday rooms
	t("hearthside-parlor", "Hearthside Parlor", "room", "holiday"),
	t("stocking-nook", "Stocking Nook", "room", "holiday"),
	t("candle-window", "Candle Window", "room", "holiday"),
	t("wreath-hall", "Wreath Hall", "room", "holiday"),
	t("cocoa-corner", "Cocoa Corner", "room", "holiday"),
	t("mitten-mantel", "Mitten Mantel", "room", "holiday"),
	t("bell-choir-room", "Bell Choir Room", "room", "holiday"),
	t("starlight-landing", "Starlight Landing", "room", "holiday"),
	t("pinecone-den", "Pinecone Den", "room", "holiday"),
	t("ribbon-gallery", "Ribbon Gallery", "room", "holiday"),
	t("holly-hearth", "Holly Hearth", "room", "holiday"),
	t("nutcracker-stage", "Nutcracker Stage", "room", "holiday"),
	t("gift-wrap-station", "Gift Wrap Station", "room", "holiday"),
	t("carol-bench", "Carol Bench", "room", "holiday"),
	-- Holiday gingerbread houses
	t("gumdrop-cottage", "Gumdrop Cottage", "gingerbread", "holiday"),
	t("icing-roof-house", "Icing Roof House", "gingerbread", "holiday"),
	t("candy-cane-porch", "Candy Cane Porch", "gingerbread", "holiday"),
	t("peppermint-gate", "Peppermint Gate", "gingerbread", "holiday"),
	t("frosting-lane", "Frosting Lane", "gingerbread", "holiday"),
	t("licorice-shutters", "Licorice Shutters", "gingerbread", "holiday"),
	t("sprinkle-chimney", "Sprinkle Chimney", "gingerbread", "holiday"),
	t("wafer-wall-house", "Wafer Wall House", "gingerbread", "holiday"),
	t("marshmallow-eaves", "Marshmallow Eaves", "gingerbread", "holiday"),
	t("ginger-door-house", "Ginger Door House", "gingerbread", "holiday"),
	t("sugar-window-cottage", "Sugar Window Cottage", "gingerbread", "holiday"),
	t("caramel-path-house", "Caramel Path House", "gingerbread", "holiday"),
	t("gumdrop-garden-house", "Gumdrop Garden House", "gingerbread", "holiday"),
	t("royal-icing-house", "Royal Icing House", "gingerbread", "holiday"),
	-- Holiday trees
	t("tinsel-tree", "Tinsel Tree", "tree", "holiday"),
	t("popcorn-garland-tree", "Popcorn Garland Tree", "tree", "holiday"),
	t("glass-bauble-tree", "Glass Bauble Tree", "tree", "holiday"),
	t("star-topper-tree", "Star Topper Tree", "tree", "holiday"),
	t("ribbon-spiral-tree", "Ribbon Spiral Tree", "tree", "holiday"),
	t("pinecone-tree", "Pinecone Tree", "tree", "holiday"),
	t("bell-strand-tree", "Bell Strand Tree", "tree", "holiday"),
	t("candle-clip-tree", "Candle Clip Tree", "tree", "holiday"),
	t("snowflake-tree", "Snowflake Tree", "tree", "holiday"),
	t("cranberry-strand-tree", "Cranberry Strand Tree", "tree", "holiday"),
	t("paper-chain-tree", "Paper Chain Tree", "tree", "holiday"),
	t("mitten-ornament-tree", "Mitten Ornament Tree", "tree", "holiday"),
	t("gold-lantern-tree", "Gold Lantern Tree", "tree", "holiday"),
	t("robin-nest-tree", "Robin Nest Tree", "tree", "holiday"),
	-- Winter rooms (after 31 Dec)
	t("frost-pane-parlor", "Frost Pane Parlor", "room", "winter"),
	t("snowfort-den", "Snowfort Den", "room", "winter"),
	t("aurora-window", "Aurora Window", "room", "winter"),
	t("icicle-porch", "Icicle Porch", "room", "winter"),
	t("quilt-lantern-nook", "Quilt Lantern Nook", "room", "winter"),
	t("mitten-mudroom", "Mitten Mudroom", "room", "winter"),
	t("sled-rack-hall", "Sled Rack Hall", "room", "winter"),
	t("thermos-cocoa-nook", "Thermos Cocoa Nook", "room", "winter"),
	t("flannel-reading-nook", "Flannel Reading Nook", "room", "winter"),
	t("snowshoe-entry", "Snowshoe Entry", "room", "winter"),
	-- Winter trees
	t("frost-needle-tree", "Frost Needle Tree", "tree", "winter"),
	t("ice-lantern-tree", "Ice Lantern Tree", "tree", "winter"),
	t("silver-birch-tree", "Silver Birch Tree", "tree", "winter"),
	t("quiet-pine-tree", "Quiet Pine Tree", "tree", "winter"),
	t("crystal-icicle-tree", "Crystal Icicle Tree", "tree", "winter"),
	t("wool-star-tree", "Wool Star Tree", "tree", "winter"),
}

local BY_ID: { [string]: Theme } = {}
for _, theme in ipairs(LIST) do
	table.freeze(theme)
	BY_ID[theme.id] = theme
end
table.freeze(LIST)
table.freeze(BY_ID)

local BANNED = {
	"cozy",
	"roblox",
	"blox",
	"impress",
	"eggnog",
	"mulled",
	"wine",
	"beer",
	"alcohol",
	"bedroom",
	"bathroom",
	"whiskey",
	"whisky",
	"vodka",
	"champagne",
	"cocktail",
}

local ROUND_TYPES = {
	room = true,
	gingerbread = true,
	tree = true,
}

local SEASONS = {
	holiday = true,
	winter = true,
}

local Themes = {}

function Themes.all(): { Theme }
	return table.clone(LIST)
end

function Themes.count(): number
	return #LIST
end

function Themes.byId(id: string): Theme?
	return BY_ID[id]
end

function Themes.forSeason(season: string): { Theme }
	local out = {}
	for _, theme in ipairs(LIST) do
		if theme.season == season then
			table.insert(out, theme)
		end
	end
	return out
end

function Themes.forSeasonAndType(season: string, roundType: string, source: { Theme }?): { Theme }
	local out = {}
	local rows = source or LIST
	for _, theme in ipairs(rows) do
		if theme.season == season and theme.roundType == roundType then
			table.insert(out, theme)
		end
	end
	return out
end

-- Holiday Season through 31 Dec 2026 UTC. Winter from 1 Jan 2027 on.
-- A date that is not a real calendar day resolves to winter so a bad clock
-- cannot keep the launch list up forever.
function Themes.seasonForDate(year: number, month: number, day: number): string
	if month < 1 or month > 12 or day < 1 or day > 31 then
		return "winter"
	end
	if year > 2026 then
		return "winter"
	end
	return "holiday"
end

-- Config.Season wins when it is "holiday" or "winter". "auto" uses the date.
function Themes.activeSeason(setting: string, year: number, month: number, day: number): string
	if setting == "holiday" or setting == "winter" then
		return setting
	end
	return Themes.seasonForDate(year, month, day)
end

function Themes.seasonLabel(season: string): string
	if season == "holiday" then
		return "Holiday Season"
	end
	if season == "winter" then
		return "Winter"
	end
	return ""
end

function Themes.typeLabel(roundType: string): string
	if roundType == "gingerbread" then
		return "Gingerbread house"
	end
	if roundType == "tree" then
		return "Tree"
	end
	if roundType == "room" then
		return "Room"
	end
	return ""
end

local function contains(hay: string, needle: string): boolean
	return string.find(string.lower(hay), needle, 1, true) ~= nil
end

-- Structural checks used by tests and by the server at startup.
function Themes.audit(): { string }
	local problems = {}
	local function problem(text: string)
		table.insert(problems, text)
	end

	if Config.MaxPlayers ~= 10 then
		problem("MaxPlayers must be 10")
	end
	if Config.MinPlayers ~= 1 then
		problem("MinPlayers must be 1")
	end
	if Config.MinPlayers > Config.MaxPlayers then
		problem("MinPlayers is above MaxPlayers")
	end
	if Config.RecentThemes ~= 10 then
		problem("RecentThemes must be 10")
	end
	if Config.Stars.min ~= 1 or Config.Stars.max ~= 5 or Config.Stars.min > Config.Stars.max then
		problem("Stars must run from 1 to 5")
	end
	if Config.Season ~= "auto" and Config.Season ~= "holiday" and Config.Season ~= "winter" then
		problem("Season must be auto, holiday, or winter")
	end
	if Config.Critic.name ~= "Auntie Roch" then
		problem("Critic must be Auntie Roch")
	end

	local phases = Config.Phases
	if phases.Lobby ~= 20 then
		problem("Lobby must be 20 seconds")
	end
	if phases.ThemeReveal ~= 5 then
		problem("ThemeReveal must be 5 seconds")
	end
	if phases.Build ~= 240 then
		problem("Build must be 240 seconds")
	end
	if phases.TourPerRoom ~= 8 then
		problem("TourPerRoom must be 8 seconds")
	end
	if phases.Results ~= 15 then
		problem("Results must be 15 seconds")
	end
	for name, seconds in pairs(phases) do
		if type(seconds) ~= "number" or seconds <= 0 then
			problem("Phase " .. tostring(name) .. " must be a positive number")
		end
	end

	if #Config.RoundTypeOrder ~= 3 then
		problem("RoundTypeOrder must list room, gingerbread, and tree")
	end
	local seenOrder = {}
	for _, kind in ipairs(Config.RoundTypeOrder) do
		if not ROUND_TYPES[kind] then
			problem("Unknown round type in order: " .. tostring(kind))
		end
		if seenOrder[kind] then
			problem("Duplicate round type in order: " .. kind)
		end
		seenOrder[kind] = true
	end

	if Config.RateLimit.globalBurst < 1 or Config.RateLimit.actionBurst < 1 then
		problem("Rate limits need a positive burst")
	end
	if Config.RateLimit.globalRefill <= 0 or Config.RateLimit.actionRefill <= 0 then
		problem("Rate limits need a positive refill")
	end
	if Config.Names.Action == "" or Config.Names.RoundState == "" then
		problem("Remote names must be set")
	end

	if #LIST < 40 then
		problem("Need at least 40 starter themes")
	end

	local ids = {}
	local holidayTypes = {}
	local winterCount = 0
	for _, theme in ipairs(LIST) do
		if ids[theme.id] then
			problem("Duplicate theme id: " .. theme.id)
		end
		ids[theme.id] = true
		if theme.name == "" or theme.id == "" then
			problem("Theme is missing a name or id")
		end
		if string.match(theme.id, "^[a-z0-9%-]+$") == nil then
			problem("Theme id must be lowercase kebab: " .. theme.id)
		end
		if not ROUND_TYPES[theme.roundType] then
			problem("Bad round type on " .. theme.id)
		end
		if not SEASONS[theme.season] then
			problem("Bad season on " .. theme.id)
		end
		for _, banned in ipairs(BANNED) do
			if contains(theme.name, banned) or contains(theme.id, banned) then
				problem("Banned word '" .. banned .. "' on " .. theme.id)
			end
		end
		if theme.season == "holiday" then
			holidayTypes[theme.roundType] = (holidayTypes[theme.roundType] or 0) + 1
		else
			winterCount += 1
			if theme.roundType == "gingerbread" then
				problem("Winter has no gingerbread theme: " .. theme.id)
			end
		end
	end

	if #Themes.forSeason("holiday") < 40 then
		problem("Holiday Season needs at least 40 themes")
	end
	for kind in pairs(ROUND_TYPES) do
		if (holidayTypes[kind] or 0) < 10 then
			problem("Holiday needs at least 10 " .. kind .. " themes so the no-repeat window fits")
		end
	end
	if winterCount < 12 then
		problem("Winter needs a real theme list")
	end

	return problems
end

return Themes
