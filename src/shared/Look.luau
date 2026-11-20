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
		wood = { 176, 102, 38 },
		cloth = { 255, 120, 160 },
		wallA = { 208, 136, 54 },
		wallB = { 176, 102, 38 },
		floorA = { 176, 102, 38 },
		floorB = { 150, 86, 32 },
	},
	winter = {
		accent = { 80, 186, 230 },
		trim = { 90, 120, 150 },
		cream = { 252, 248, 242 },
		wood = { 160, 140, 124 },
		cloth = { 160, 200, 236 },
		wallA = { 246, 248, 252 },
		wallB = { 234, 240, 250 },
		floorA = { 120, 154, 190 },
		floorB = { 96, 132, 172 },
	},
	glow = {
		accent = { 255, 210, 80 },
		trim = { 130, 90, 200 },
		cream = { 255, 244, 228 },
		wood = { 160, 120, 100 },
		cloth = { 255, 140, 150 },
		wallA = { 250, 236, 248 },
		wallB = { 236, 222, 244 },
		floorA = { 130, 92, 186 },
		floorB = { 108, 72, 164 },
	},
	frost = {
		accent = { 120, 214, 240 },
		trim = { 80, 114, 148 },
		cream = { 250, 249, 245 },
		wood = { 150, 136, 124 },
		cloth = { 160, 210, 236 },
		wallA = { 244, 248, 252 },
		wallB = { 228, 238, 248 },
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
		ambient = { 170, 160, 175 },
		outdoor = { 160, 165, 190 },
		shift = { 255, 230, 200 },
		density = 0.05,
		haze = 0.07,
		glare = 0.04,
		offset = 0.08,
		air = { 230, 220, 240 },
		decay = { 180, 170, 210 },
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
		ambient = { 172, 174, 182 },
		outdoor = { 160, 174, 198 },
		shift = { 236, 242, 252 },
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
		light = { 244, 246, 252 },
	},
	frost = {
		clock = 14.8,
		brightness = 2.15,
		ambient = { 170, 173, 182 },
		outdoor = { 158, 172, 198 },
		shift = { 234, 240, 252 },
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
		light = { 242, 246, 254 },
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

-- Room shell finish per family: floor and wall surface keys (Meshes.Surfaces),
-- and whether the walls get painted wainscoting. Colors still come from the
-- pack (or Designer Tools paint); these only pick the texture and trim.
-- floorLift mixes the theme floor toward white (cool families read less flat
-- blue), drape "cream" hangs cream curtains with a hint of the pack cloth, and
-- light is the warm ceiling-light color.
export type ShellStyle = { floor: string, wall: string, wainscot: boolean, floorLift: number, drape: string, light: Rgb }

Look.ShellStyles = {
	hearth = { floor = "planks", wall = "stripe", wainscot = true, floorLift = 0, drape = "cloth", light = { 255, 206, 150 } },
	ginger = { floor = "planks", wall = "plaster", wainscot = false, floorLift = 0, drape = "cloth", light = { 255, 204, 146 } },
	winter = { floor = "carpet", wall = "plaster", wainscot = true, floorLift = 0.5, drape = "cream", light = { 255, 222, 184 } },
	glow = { floor = "carpet", wall = "sprig", wainscot = true, floorLift = 0, drape = "cloth", light = { 255, 210, 160 } },
	frost = { floor = "tile", wall = "sprig", wainscot = true, floorLift = 0.55, drape = "cream", light = { 255, 226, 192 } },
} :: { [string]: ShellStyle }

function Look.shellStyle(family: string): ShellStyle
	return Look.ShellStyles[family] or Look.ShellStyles.hearth
end

return Look
