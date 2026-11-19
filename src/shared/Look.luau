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
		cream = { 255, 248, 236 },
		wood = { 176, 112, 70 },
		cloth = { 255, 150, 140 },
		wallA = { 255, 228, 200 },
		wallB = { 255, 214, 184 },
		floorA = { 198, 126, 72 },
		floorB = { 174, 106, 60 },
	},
	ginger = {
		accent = { 255, 80, 130 },
		trim = { 255, 252, 248 },
		cream = { 255, 250, 242 },
		wood = { 196, 126, 64 },
		cloth = { 255, 120, 160 },
		wallA = { 232, 178, 88 },
		wallB = { 214, 156, 70 },
		floorA = { 196, 126, 64 },
		floorB = { 176, 108, 52 },
	},
	winter = {
		accent = { 80, 186, 230 },
		trim = { 90, 120, 150 },
		cream = { 240, 246, 255 },
		wood = { 160, 140, 124 },
		cloth = { 160, 200, 236 },
		wallA = { 240, 246, 255 },
		wallB = { 226, 236, 250 },
		floorA = { 120, 154, 190 },
		floorB = { 96, 132, 172 },
	},
	glow = {
		accent = { 255, 210, 80 },
		trim = { 130, 90, 200 },
		cream = { 248, 236, 255 },
		wood = { 160, 120, 100 },
		cloth = { 200, 150, 255 },
		wallA = { 245, 232, 255 },
		wallB = { 232, 216, 250 },
		floorA = { 130, 92, 186 },
		floorB = { 108, 72, 164 },
	},
	frost = {
		accent = { 120, 214, 240 },
		trim = { 80, 114, 148 },
		cream = { 240, 248, 255 },
		wood = { 150, 136, 124 },
		cloth = { 160, 210, 236 },
		wallA = { 236, 244, 252 },
		wallB = { 220, 232, 246 },
		floorA = { 118, 150, 186 },
		floorB = { 94, 126, 166 },
	},
}

local Presets: { [string]: Preset } = {
	hearth = {
		clock = 15.2,
		brightness = 2.2,
		ambient = { 180, 172, 164 },
		outdoor = { 160, 178, 200 },
		shift = { 255, 236, 214 },
		density = 0.04,
		haze = 0.06,
		glare = 0.02,
		offset = 0.08,
		air = { 220, 230, 245 },
		decay = { 180, 200, 230 },
		bloom = 0.1,
		bloomSize = 12,
		bloomThreshold = 0.98,
		saturation = 0.14,
		contrast = 0.08,
		grade = 0.02,
		exposure = 0,
		tint = { 255, 255, 255 },
		light = { 255, 232, 200 },
	},
	ginger = {
		clock = 15.0,
		brightness = 2.25,
		ambient = { 180, 170, 158 },
		outdoor = { 165, 180, 200 },
		shift = { 255, 236, 210 },
		density = 0.04,
		haze = 0.05,
		glare = 0.02,
		offset = 0.08,
		air = { 230, 236, 248 },
		decay = { 190, 200, 220 },
		bloom = 0.1,
		bloomSize = 12,
		bloomThreshold = 0.98,
		saturation = 0.16,
		contrast = 0.08,
		grade = 0.02,
		exposure = 0,
		tint = { 255, 255, 255 },
		light = { 255, 228, 190 },
	},
	glow = {
		clock = 17.4,
		brightness = 2.0,
		ambient = { 165, 155, 180 },
		outdoor = { 150, 155, 190 },
		shift = { 230, 210, 255 },
		density = 0.05,
		haze = 0.07,
		glare = 0.04,
		offset = 0.08,
		air = { 210, 200, 240 },
		decay = { 170, 160, 210 },
		bloom = 0.16,
		bloomSize = 16,
		bloomThreshold = 0.95,
		saturation = 0.16,
		contrast = 0.08,
		grade = 0.02,
		exposure = 0,
		tint = { 255, 255, 255 },
		light = { 255, 220, 160 },
	},
	winter = {
		clock = 14.5,
		brightness = 2.2,
		ambient = { 160, 170, 185 },
		outdoor = { 155, 175, 205 },
		shift = { 210, 230, 255 },
		density = 0.04,
		haze = 0.06,
		glare = 0.02,
		offset = 0.08,
		air = { 210, 226, 245 },
		decay = { 170, 190, 220 },
		bloom = 0.08,
		bloomSize = 10,
		bloomThreshold = 0.98,
		saturation = 0.12,
		contrast = 0.08,
		grade = 0.02,
		exposure = 0,
		tint = { 255, 255, 255 },
		light = { 220, 236, 255 },
	},
	frost = {
		clock = 14.8,
		brightness = 2.15,
		ambient = { 158, 168, 185 },
		outdoor = { 155, 172, 200 },
		shift = { 210, 228, 250 },
		density = 0.04,
		haze = 0.06,
		glare = 0.02,
		offset = 0.08,
		air = { 214, 228, 245 },
		decay = { 170, 190, 220 },
		bloom = 0.08,
		bloomSize = 12,
		bloomThreshold = 0.98,
		saturation = 0.12,
		contrast = 0.08,
		grade = 0.02,
		exposure = 0,
		tint = { 255, 255, 255 },
		light = { 210, 230, 255 },
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
