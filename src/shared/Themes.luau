--!strict
-- Starter themes. Each one is a round type (room, gingerbread, tree) and a season
-- (holiday or winter). Names are original. Rooms, placement, and props come later.

export type Theme = {
	id: string,
	name: string,
	roundType: string,
	season: string,
}

local Themes: { Theme } = {
	-- Holiday rooms
	{ id = "hearth_cocoa", name = "Cocoa Hearth", roundType = "room", season = "holiday" },
	{ id = "stocking_mantel", name = "Stocking Mantel", roundType = "room", season = "holiday" },
	{ id = "nutcracker_nook", name = "Nutcracker Nook", roundType = "room", season = "holiday" },
	{ id = "snow_globe_parlor", name = "Snow Globe Parlor", roundType = "room", season = "holiday" },
	{ id = "ribbon_window", name = "Ribbon Window Seat", roundType = "room", season = "holiday" },
	{ id = "carol_piano", name = "Carol Piano Corner", roundType = "room", season = "holiday" },
	{ id = "sleigh_entry", name = "Sleigh Bell Entry", roundType = "room", season = "holiday" },
	{ id = "starlight_nook", name = "Starlight Reading Nook", roundType = "room", season = "holiday" },

	-- Holiday gingerbread houses
	{ id = "gumdrop_gable", name = "Gumdrop Gable", roundType = "gingerbread", season = "holiday" },
	{ id = "icing_shingles", name = "Icing Shingle Cottage", roundType = "gingerbread", season = "holiday" },
	{ id = "cane_porch", name = "Candy Cane Porch", roundType = "gingerbread", season = "holiday" },
	{ id = "sprinkle_chimney", name = "Sprinkle Chimney", roundType = "gingerbread", season = "holiday" },
	{ id = "licorice_lane", name = "Licorice Lane House", roundType = "gingerbread", season = "holiday" },
	{ id = "frosting_roof", name = "Frosting Drip Roof", roundType = "gingerbread", season = "holiday" },
	{ id = "peppermint_door", name = "Peppermint Doorway", roundType = "gingerbread", season = "holiday" },
	{ id = "ginger_bake", name = "Ginger Wall Bake", roundType = "gingerbread", season = "holiday" },

	-- Holiday trees
	{ id = "tinsel_topper", name = "Tinsel Topper", roundType = "tree", season = "holiday" },
	{ id = "popcorn_garland", name = "Popcorn Garland", roundType = "tree", season = "holiday" },
	{ id = "paper_star", name = "Paper Star Tree", roundType = "tree", season = "holiday" },
	{ id = "bauble_burst", name = "Bauble Burst", roundType = "tree", season = "holiday" },
	{ id = "ribbon_spiral", name = "Ribbon Spiral", roundType = "tree", season = "holiday" },
	{ id = "bell_branch", name = "Bell Branch", roundType = "tree", season = "holiday" },
	{ id = "snowflake_ladder", name = "Snowflake Ladder", roundType = "tree", season = "holiday" },
	{ id = "cranberry_strand", name = "Cranberry Strand", roundType = "tree", season = "holiday" },

	-- Winter rooms
	{ id = "frosted_window", name = "Frosted Window", roundType = "room", season = "winter" },
	{ id = "blanket_fort", name = "Knit Blanket Fort", roundType = "room", season = "winter" },
	{ id = "lantern_mudroom", name = "Lantern Mudroom", roundType = "room", season = "winter" },
	{ id = "snowfall_sunroom", name = "Snowfall Sunroom", roundType = "room", season = "winter" },
	{ id = "pinecone_shelf", name = "Pinecone Shelf", roundType = "room", season = "winter" },
	{ id = "ice_hall", name = "Ice Crystal Hall", roundType = "room", season = "winter" },
	{ id = "flannel_corner", name = "Flannel Reading Corner", roundType = "room", season = "winter" },
	{ id = "thermos_table", name = "Thermos Table", roundType = "room", season = "winter" },
	{ id = "quilted_window", name = "Quilted Window", roundType = "room", season = "winter" },
	{ id = "birch_den", name = "Birch Log Den", roundType = "room", season = "winter" },

	-- Winter trees
	{ id = "frosted_fir", name = "Frosted Fir", roundType = "tree", season = "winter" },
	{ id = "ice_lantern_spruce", name = "Ice Lantern Spruce", roundType = "tree", season = "winter" },
	{ id = "silver_cone", name = "Silver Cone", roundType = "tree", season = "winter" },
	{ id = "quiet_snow_pine", name = "Quiet Snow Pine", roundType = "tree", season = "winter" },
	{ id = "blue_glass_branches", name = "Blue Glass Branches", roundType = "tree", season = "winter" },
	{ id = "wool_pom_pine", name = "Wool Pom Pine", roundType = "tree", season = "winter" },
	{ id = "cedar_candles", name = "Cedar Candle Tree", roundType = "tree", season = "winter" },
	{ id = "birch_white", name = "Birch White Tree", roundType = "tree", season = "winter" },
}

return Themes
