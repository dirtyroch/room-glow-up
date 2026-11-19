--!strict
-- World look: style-pack colors and a light preset for each theme family.
-- Numbers only, so tests can read them without a place file.
-- Families: holiday rooms (warm hearth), gingerbread, holiday trees (glow),
-- winter rooms, and winter trees (frost).

local FAMILIES: { [string]: string } = {
	hearth_cocoa = "hearth",
	stocking_mantel = "hearth",
	nutcracker_nook = "hearth",
	snow_globe_parlor = "hearth",
	ribbon_window = "hearth",
	carol_piano = "hearth",
	sleigh_entry = "hearth",
	starlight_nook = "hearth",

	gumdrop_gable = "ginger",
	icing_shingles = "ginger",
	cane_porch = "ginger",
	sprinkle_chimney = "ginger",
	licorice_lane = "ginger",
	frosting_roof = "ginger",
	peppermint_door = "ginger",
	ginger_bake = "ginger",

	tinsel_topper = "glow",
	popcorn_garland = "glow",
	paper_star = "glow",
	bauble_burst = "glow",
	ribbon_spiral = "glow",
	bell_branch = "glow",
	snowflake_ladder = "glow",
	cranberry_strand = "glow",

	frosted_window = "winter",
	blanket_fort = "winter",
	lantern_mudroom = "winter",
	snowfall_sunroom = "winter",
	pinecone_shelf = "winter",
	ice_hall = "winter",
	flannel_corner = "winter",
	thermos_table = "winter",
	quilted_window = "winter",
	birch_den = "winter",

	frosted_fir = "frost",
	ice_lantern_spruce = "frost",
	silver_cone = "frost",
	quiet_snow_pine = "frost",
	blue_glass_branches = "frost",
	wool_pom_pine = "frost",
	cedar_candles = "frost",
	birch_white = "frost",
}

export type Rgb = { number }

export type Pack = {
	accent: Rgb,
	trim: Rgb,
	cream: Rgb,
	wood: Rgb,
	cloth: Rgb,
}

export type Preset = {
	clock: number,
	brightness: number,
	ambient: Rgb,
	outdoor: Rgb,
	shift: Rgb,
	density: number,
	haze: number,
	glare: number,
	offset: number,
	air: Rgb,
	decay: Rgb,
	bloom: number,
	bloomSize: number,
	bloomThreshold: number,
	saturation: number,
	contrast: number,
	tint: Rgb,
	light: Rgb,
}

local Packs: { [string]: Pack } = {
	hearth = {
		accent = { 255, 154, 138 },
		trim = { 122, 78, 62 },
		cream = { 255, 246, 234 },
		wood = { 196, 142, 98 },
		cloth = { 255, 214, 196 },
	},
	ginger = {
		accent = { 255, 122, 146 },
		trim = { 168, 86, 112 },
		cream = { 255, 252, 248 },
		wood = { 198, 132, 78 },
		cloth = { 255, 196, 206 },
	},
	winter = {
		accent = { 168, 206, 214 },
		trim = { 86, 108, 128 },
		cream = { 244, 248, 250 },
		wood = { 186, 164, 140 },
		cloth = { 206, 214, 232 },
	},
	glow = {
		accent = { 255, 208, 112 },
		trim = { 120, 96, 150 },
		cream = { 255, 246, 234 },
		wood = { 176, 140, 110 },
		cloth = { 220, 204, 236 },
	},
	frost = {
		accent = { 186, 220, 232 },
		trim = { 78, 108, 128 },
		cream = { 246, 250, 252 },
		wood = { 170, 150, 132 },
		cloth = { 198, 216, 228 },
	},
}

local Presets: { [string]: Preset } = {
	hearth = {
		clock = 17.4,
		brightness = 2.15,
		ambient = { 156, 132, 140 },
		outdoor = { 196, 168, 160 },
		shift = { 255, 214, 186 },
		density = 0.3,
		haze = 1.25,
		glare = 0.18,
		offset = 0.14,
		air = { 255, 228, 220 },
		decay = { 214, 170, 160 },
		bloom = 0.42,
		bloomSize = 22,
		bloomThreshold = 0.84,
		saturation = 0.14,
		contrast = 0.06,
		tint = { 255, 236, 226 },
		light = { 255, 214, 176 },
	},
	ginger = {
		clock = 16.5,
		brightness = 2.28,
		ambient = { 168, 136, 124 },
		outdoor = { 206, 170, 146 },
		shift = { 255, 206, 170 },
		density = 0.28,
		haze = 1.15,
		glare = 0.22,
		offset = 0.12,
		air = { 255, 232, 214 },
		decay = { 214, 160, 140 },
		bloom = 0.48,
		bloomSize = 24,
		bloomThreshold = 0.8,
		saturation = 0.18,
		contrast = 0.07,
		tint = { 255, 228, 210 },
		light = { 255, 196, 150 },
	},
	glow = {
		clock = 18.7,
		brightness = 1.9,
		ambient = { 140, 128, 168 },
		outdoor = { 176, 164, 196 },
		shift = { 255, 220, 186 },
		density = 0.34,
		haze = 1.4,
		glare = 0.26,
		offset = 0.18,
		air = { 236, 220, 240 },
		decay = { 186, 160, 196 },
		bloom = 0.55,
		bloomSize = 26,
		bloomThreshold = 0.78,
		saturation = 0.16,
		contrast = 0.05,
		tint = { 244, 228, 236 },
		light = { 255, 220, 176 },
	},
	winter = {
		clock = 15.1,
		brightness = 2.3,
		ambient = { 150, 168, 186 },
		outdoor = { 186, 204, 216 },
		shift = { 214, 228, 240 },
		density = 0.26,
		haze = 1.35,
		glare = 0.12,
		offset = 0.16,
		air = { 226, 236, 244 },
		decay = { 170, 190, 206 },
		bloom = 0.32,
		bloomSize = 18,
		bloomThreshold = 0.88,
		saturation = 0.04,
		contrast = 0.05,
		tint = { 226, 236, 246 },
		light = { 206, 226, 240 },
	},
	frost = {
		clock = 16.2,
		brightness = 2.05,
		ambient = { 140, 164, 186 },
		outdoor = { 176, 200, 214 },
		shift = { 200, 220, 236 },
		density = 0.32,
		haze = 1.5,
		glare = 0.16,
		offset = 0.2,
		air = { 220, 234, 244 },
		decay = { 160, 186, 206 },
		bloom = 0.36,
		bloomSize = 20,
		bloomThreshold = 0.86,
		saturation = 0.06,
		contrast = 0.04,
		tint = { 220, 234, 244 },
		light = { 196, 220, 236 },
	},
}

local Look = {
	Packs = Packs,
	Presets = Presets,
	Budget = { min = 3, max = 10 },
}

function Look.family(themeId: string): string
	if type(themeId) ~= "string" then
		return "hearth"
	end
	local name = FAMILIES[themeId]
	if name == nil then
		return "hearth"
	end
	return name
end

function Look.packFor(roundType: string, themeTag: string?): string
	if type(themeTag) == "string" and FAMILIES[themeTag] ~= nil then
		return FAMILIES[themeTag]
	end
	if roundType == "gingerbread" then
		return "ginger"
	end
	if roundType == "tree" then
		return "glow"
	end
	return "hearth"
end

function Look.pack(name: string): Pack
	local found = Packs[name]
	if found == nil then
		return Packs.hearth
	end
	return found
end

function Look.preset(name: string): Preset
	local found = Presets[name]
	if found == nil then
		return Presets.hearth
	end
	return found
end

-- Three colors for confetti: accent, cloth, and the grade tint.
function Look.swatch(themeId: string): { Rgb }
	local family = Look.family(themeId)
	local colors = Look.pack(family)
	local grade = Look.preset(family)
	return { colors.accent, colors.cloth, grade.tint }
end

return Look
