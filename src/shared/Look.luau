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
	wallA: Rgb,
	wallB: Rgb,
	floorA: Rgb,
	floorB: Rgb,
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
	grade: number,
	exposure: number,
	tint: Rgb,
	light: Rgb,
}

local Packs: { [string]: Pack } = {
	hearth = {
		accent = { 255, 130, 110 },
		trim = { 122, 78, 62 },
		cream = { 255, 236, 214 },
		wood = { 176, 112, 70 },
		cloth = { 255, 186, 160 },
		wallA = { 250, 226, 204 },
		wallB = { 236, 206, 184 },
		floorA = { 168, 108, 70 },
		floorB = { 138, 86, 54 },
	},
	ginger = {
		accent = { 255, 90, 130 },
		trim = { 255, 250, 245 },
		cream = { 255, 248, 240 },
		wood = { 176, 102, 52 },
		cloth = { 255, 140, 160 },
		wallA = { 196, 126, 72 },
		wallB = { 168, 102, 56 },
		floorA = { 148, 86, 46 },
		floorB = { 122, 70, 38 },
	},
	winter = {
		accent = { 110, 186, 214 },
		trim = { 70, 96, 124 },
		cream = { 228, 238, 248 },
		wood = { 150, 132, 118 },
		cloth = { 170, 198, 226 },
		wallA = { 220, 234, 246 },
		wallB = { 200, 218, 236 },
		floorA = { 96, 124, 158 },
		floorB = { 74, 102, 138 },
	},
	glow = {
		accent = { 255, 200, 80 },
		trim = { 110, 80, 160 },
		cream = { 246, 230, 255 },
		wood = { 150, 110, 90 },
		cloth = { 200, 170, 240 },
		wallA = { 230, 210, 246 },
		wallB = { 210, 186, 236 },
		floorA = { 88, 58, 122 },
		floorB = { 68, 42, 102 },
	},
	frost = {
		accent = { 150, 214, 236 },
		trim = { 64, 96, 124 },
		cream = { 232, 242, 250 },
		wood = { 140, 128, 118 },
		cloth = { 170, 206, 226 },
		wallA = { 226, 238, 248 },
		wallB = { 206, 224, 240 },
		floorA = { 84, 116, 148 },
		floorB = { 64, 94, 128 },
	},
}

local Presets: { [string]: Preset } = {
	hearth = {
		clock = 17.1,
		brightness = 1.2,
		ambient = { 78, 56, 48 },
		outdoor = { 140, 108, 90 },
		shift = { 255, 196, 150 },
		density = 0.1,
		haze = 0.28,
		glare = 0.06,
		offset = 0.06,
		air = { 255, 210, 190 },
		decay = { 150, 100, 80 },
		bloom = 0.16,
		bloomSize = 14,
		bloomThreshold = 0.96,
		saturation = 0.3,
		contrast = 0.26,
		grade = -0.04,
		exposure = -0.4,
		tint = { 255, 244, 232 },
		light = { 255, 186, 120 },
	},
	ginger = {
		clock = 16.0,
		brightness = 1.28,
		ambient = { 86, 58, 44 },
		outdoor = { 160, 112, 80 },
		shift = { 255, 190, 130 },
		density = 0.1,
		haze = 0.24,
		glare = 0.08,
		offset = 0.05,
		air = { 255, 216, 186 },
		decay = { 160, 96, 70 },
		bloom = 0.18,
		bloomSize = 14,
		bloomThreshold = 0.95,
		saturation = 0.38,
		contrast = 0.28,
		grade = -0.03,
		exposure = -0.32,
		tint = { 255, 240, 224 },
		light = { 255, 176, 110 },
	},
	glow = {
		clock = 19.2,
		brightness = 1.0,
		ambient = { 48, 38, 78 },
		outdoor = { 90, 76, 130 },
		shift = { 255, 200, 140 },
		density = 0.14,
		haze = 0.32,
		glare = 0.1,
		offset = 0.08,
		air = { 210, 190, 240 },
		decay = { 110, 80, 150 },
		bloom = 0.26,
		bloomSize = 18,
		bloomThreshold = 0.9,
		saturation = 0.34,
		contrast = 0.28,
		grade = -0.05,
		exposure = -0.35,
		tint = { 236, 226, 255 },
		light = { 255, 210, 130 },
	},
	winter = {
		clock = 14.6,
		brightness = 1.22,
		ambient = { 58, 74, 96 },
		outdoor = { 130, 160, 190 },
		shift = { 190, 214, 240 },
		density = 0.1,
		haze = 0.3,
		glare = 0.04,
		offset = 0.06,
		air = { 200, 220, 240 },
		decay = { 90, 120, 150 },
		bloom = 0.12,
		bloomSize = 12,
		bloomThreshold = 0.97,
		saturation = 0.22,
		contrast = 0.26,
		grade = -0.04,
		exposure = -0.38,
		tint = { 228, 238, 250 },
		light = { 190, 216, 255 },
	},
	frost = {
		clock = 16.4,
		brightness = 1.1,
		ambient = { 50, 68, 92 },
		outdoor = { 120, 150, 180 },
		shift = { 180, 210, 236 },
		density = 0.12,
		haze = 0.34,
		glare = 0.05,
		offset = 0.08,
		air = { 196, 220, 240 },
		decay = { 80, 110, 140 },
		bloom = 0.14,
		bloomSize = 14,
		bloomThreshold = 0.96,
		saturation = 0.2,
		contrast = 0.26,
		grade = -0.05,
		exposure = -0.4,
		tint = { 224, 236, 248 },
		light = { 180, 210, 240 },
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
