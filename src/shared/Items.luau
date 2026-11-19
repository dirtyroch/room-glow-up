--!strict
-- Original prop library. Chunks, pastel fills, about 1.2x so they read on a phone.
-- Each prop carries a round type and theme ids from the 42-theme list.
-- Gingerbread entries are preset candy and icing pieces. There is no draw tool.

export type Item = {
	id: string,
	name: string,
	category: string,
	cost: number,
	surface: string,
	w: number,
	d: number,
	h: number,
	shape: string,
	color: string,
	roundType: string,
	tags: { string },
}

local RAW = [[
butter_bench|Butter Bench|Seating|12|floor|2|1|0.85|sofa|butter|room hearth_cocoa flannel_corner
mint_pouf|Mint Pouf|Seating|6|floor|1|1|0.55|ball|mint|room snow_globe_parlor snowfall_sunroom
coral_armchair|Coral Armchair|Seating|10|floor|1|1|1.05|chair|coral|room starlight_nook flannel_corner
lavender_settee|Lavender Settee|Seating|14|floor|2|1|0.85|sofa|lavender|room ribbon_window quilted_window
cream_rocker|Cream Rocker|Seating|10|floor|1|1|1.05|chair|cream|room carol_piano birch_den
cocoa_stool|Cocoa Stool|Seating|6|floor|1|1|0.7|chair|butter|room hearth_cocoa thermos_table
pine_bench|Pine Bench|Seating|12|floor|2|1|0.75|sofa|mint|room sleigh_entry birch_den
cloud_pouf|Cloud Pouf|Seating|6|floor|1|1|0.55|ball|cream|room snow_globe_parlor ice_hall
reader_chair|Reader Chair|Seating|10|floor|1|1|1.1|chair|lavender|room starlight_nook flannel_corner
entry_bench|Entry Bench|Seating|12|floor|2|1|0.75|sofa|coral|room sleigh_entry lantern_mudroom
cocoa_table|Cocoa Table|Tables|12|floor|2|1|0.7|table|butter|room hearth_cocoa thermos_table
round_side|Round Side Table|Tables|8|floor|1|1|0.7|table|cream|room starlight_nook snowfall_sunroom
parcel_table|Parcel Table|Tables|12|floor|2|1|0.7|table|coral|room stocking_mantel lantern_mudroom
sunroom_table|Sunroom Table|Tables|14|floor|2|2|0.7|table|mint|room snowfall_sunroom frosted_window
birch_side|Birch Side Table|Tables|8|floor|1|1|0.75|table|cream|room birch_den ice_hall
quilt_table|Quilt Table|Tables|12|floor|2|1|0.7|table|lavender|room quilted_window blanket_fort
bell_table|Bell Entry Table|Tables|8|floor|1|1|0.75|table|butter|room sleigh_entry carol_piano
low_board|Low Board|Tables|10|floor|2|1|0.45|table|mint|room nutcracker_nook pinecone_shelf
hearth_lamp|Hearth Lamp|Lighting|8|floor|1|1|1.35|lamp|coral|room hearth_cocoa lantern_mudroom
star_lamp|Star Lamp|Lighting|10|floor|1|1|1.4|lamp|butter|room starlight_nook ice_hall
mudroom_lantern|Mudroom Lantern|Lighting|8|floor|1|1|1.2|lamp|mint|room lantern_mudroom birch_den
window_candle|Window Candle|Lighting|6|floor|1|1|0.8|lamp|cream|room frosted_window carol_piano
string_lights|String Lights|Lighting|8|floor|2|1|0.35|slab|butter|room ribbon_window quilted_window
pinecone_lamp|Pinecone Lamp|Lighting|8|floor|1|1|1.15|lamp|coral|room pinecone_shelf birch_den
globe_light|Globe Light|Lighting|10|floor|1|1|1.1|ball|lavender|room snow_globe_parlor ice_hall
reading_lamp|Reading Lamp|Lighting|8|floor|1|1|1.35|lamp|mint|room starlight_nook flannel_corner
mantel_shelf|Mantel Shelf|Shelves|10|floor|2|1|0.9|shelf|cream|room stocking_mantel pinecone_shelf
pinecone_shelf|Pinecone Shelf|Shelves|10|floor|2|1|0.9|shelf|butter|room pinecone_shelf birch_den
nutcracker_stand|Nutcracker Stand|Shelves|8|floor|1|1|1.2|shelf|coral|room nutcracker_nook sleigh_entry
book_ledge|Book Ledge|Shelves|10|floor|2|1|0.8|shelf|lavender|room starlight_nook flannel_corner
quilt_cabinet|Quilt Cabinet|Shelves|12|floor|1|1|1.25|shelf|mint|room quilted_window blanket_fort
hall_cabinet|Hall Cabinet|Shelves|12|floor|1|1|1.3|shelf|cream|room ice_hall lantern_mudroom
hearth_rug|Hearth Rug|Rugs|10|floor|2|2|0.08|slab|coral|room hearth_cocoa blanket_fort
snow_rug|Snowflake Rug|Rugs|10|floor|2|2|0.08|slab|cream|room snow_globe_parlor ice_hall
ribbon_rug|Ribbon Rug|Rugs|8|floor|2|1|0.08|slab|lavender|room ribbon_window quilted_window
flannel_mat|Flannel Mat|Rugs|8|floor|2|2|0.08|slab|butter|room flannel_corner blanket_fort
birch_mat|Birch Mat|Rugs|8|floor|2|1|0.08|slab|mint|room birch_den lantern_mudroom
star_mat|Star Mat|Rugs|6|floor|1|1|0.08|slab|butter|room starlight_nook snowfall_sunroom
dot_rug|Dot Rug|Rugs|4|floor|2|1|0.08|slab|coral|room hearth_cocoa stocking_mantel
stripe_rug|Stripe Rug|Rugs|4|floor|2|1|0.08|slab|mint|room ribbon_window quilted_window
checker_rug|Checker Rug|Rugs|4|floor|2|1|0.08|slab|butter|room starlight_nook snowfall_sunroom
plaid_rug|Plaid Rug|Rugs|4|floor|2|1|0.08|slab|lavender|room flannel_corner blanket_fort
pebble_rug|Pebble Rug|Rugs|4|floor|2|1|0.08|slab|cream|room birch_den lantern_mudroom
bow_accent|Bow Accent|Accents|4|floor|2|1|0.22|slab|coral|room sleigh_entry carol_piano
sprig_accent|Sprig Accent|Accents|4|floor|2|1|0.22|slab|mint|room pinecone_shelf frosted_window
spark_accent|Spark Accent|Accents|4|floor|2|1|0.22|slab|butter|room nutcracker_nook snow_globe_parlor
mini_pine|Mini Pine|Plants|8|floor|1|1|1.4|plant|mint|room sleigh_entry birch_den
potted_spruce|Potted Spruce|Plants|8|floor|1|1|1.35|plant|mint|room frosted_window snowfall_sunroom
berry_pot|Berry Pot|Plants|6|floor|1|1|0.8|plant|coral|room stocking_mantel quilted_window
fern_pot|Fern Pot|Plants|6|floor|1|1|0.9|plant|mint|room snowfall_sunroom starlight_nook
birch_sapling|Birch Sapling|Plants|8|floor|1|1|1.45|plant|cream|room birch_den ice_hall
holly_pot|Holly Pot|Plants|6|floor|1|1|0.85|plant|coral|room nutcracker_nook ribbon_window
cocoa_wreath|Cocoa Wreath|Hangings|8|wall|1|1|0.12|frame|coral|room hearth_cocoa sleigh_entry
stocking_row|Stocking Row|Hangings|10|wall|2|1|0.1|frame|cream|room stocking_mantel carol_piano
ribbon_sash|Ribbon Sash|Hangings|8|wall|2|1|0.08|slab|lavender|room ribbon_window quilted_window
frosted_frame|Frosted Frame|Hangings|8|wall|1|1|0.1|frame|cream|room frosted_window ice_hall
quilt_square|Quilt Square|Hangings|6|wall|1|1|0.1|frame|lavender|room quilted_window blanket_fort
globe_frame|Snow Globe Frame|Hangings|8|wall|1|1|0.1|frame|mint|room snow_globe_parlor snowfall_sunroom
nutcracker_frame|Nutcracker Portrait|Hangings|8|wall|1|1|0.1|frame|coral|room nutcracker_nook starlight_nook
bell_banner|Bell Banner|Hangings|10|wall|2|1|0.08|frame|butter|room sleigh_entry carol_piano
gift_stack|Gift Stack|Holiday Trim|8|floor|1|1|0.7|box|coral|room stocking_mantel nutcracker_nook
cocoa_mug|Cocoa Mug|Holiday Trim|6|floor|1|1|0.45|cylinder|butter|room hearth_cocoa thermos_table
snow_globe|Snow Globe|Holiday Trim|10|floor|1|1|0.7|ball|cream|room snow_globe_parlor ice_hall
toy_drum|Toy Drum|Holiday Trim|8|floor|1|1|0.55|cylinder|coral|room nutcracker_nook carol_piano
sleigh_bell|Sleigh Bell|Holiday Trim|6|floor|1|1|0.45|bell|butter|room sleigh_entry stocking_mantel
star_pillow|Star Pillow|Holiday Trim|6|floor|1|1|0.4|ball|lavender|room starlight_nook flannel_corner
blanket_roll|Blanket Roll|Holiday Trim|8|floor|1|1|0.45|cylinder|mint|room blanket_fort quilted_window
thermos|Thermos|Holiday Trim|8|floor|1|1|0.7|cylinder|cream|room thermos_table lantern_mudroom
carol_piano|Carol Piano|Music|16|floor|2|1|1.05|piano|cream|room carol_piano starlight_nook
bell_set|Bell Set|Music|8|floor|1|1|0.6|bell|butter|room carol_piano sleigh_entry
sheet_stand|Sheet Stand|Music|6|floor|1|1|1.15|shelf|lavender|room carol_piano starlight_nook
drum_stool|Drum Stool|Music|6|floor|1|1|0.65|chair|coral|room nutcracker_nook carol_piano
icing_drip|Icing Drip|Icing|6|roof|1|1|0.12|slab|cream|gingerbread frosting_roof icing_shingles
icing_shingle|Icing Shingle|Icing|6|roof|1|1|0.1|slab|cream|gingerbread icing_shingles ginger_bake
frosting_swirl|Frosting Swirl|Icing|6|roof|1|1|0.2|ball|cream|gingerbread frosting_roof gumdrop_gable
sugar_border|Sugar Border|Icing|8|wall|2|1|0.1|slab|cream|gingerbread icing_shingles peppermint_door
drip_row|Drip Row|Icing|8|roof|2|1|0.12|slab|cream|gingerbread frosting_roof ginger_bake
white_scallop|White Scallop|Icing|6|wall|1|1|0.12|slab|cream|gingerbread icing_shingles cane_porch
peak_icing|Peak Icing|Icing|8|roof|1|1|0.25|wedge|cream|gingerbread gumdrop_gable frosting_roof
door_icing|Door Frame Icing|Icing|6|wall|1|1|0.12|frame|cream|gingerbread peppermint_door ginger_bake
roof_swirl|Roof Swirl|Icing|6|roof|1|1|0.2|ball|cream|gingerbread frosting_roof sprinkle_chimney
eave_trim|Eave Trim|Icing|8|roof|2|1|0.1|slab|cream|gingerbread icing_shingles licorice_lane
gumdrop|Gumdrop|Candy|6|wall|1|1|0.28|ball|coral|gingerbread gumdrop_gable sprinkle_chimney
gumdrop_cluster|Gumdrop Cluster|Candy|8|wall|1|1|0.32|ball|mint|gingerbread gumdrop_gable cane_porch
candy_cane|Candy Cane|Candy|8|wall|1|1|0.2|cane|coral|gingerbread cane_porch peppermint_door
cane_pair|Cane Pair|Candy|8|wall|1|1|0.2|cane|cream|gingerbread cane_porch licorice_lane
peppermint_disc|Peppermint Disc|Candy|6|wall|1|1|0.12|cylinder|coral|gingerbread peppermint_door sprinkle_chimney
sprinkle_dash|Sprinkle Dash|Candy|6|wall|1|1|0.08|slab|lavender|gingerbread sprinkle_chimney ginger_bake
chimney_cap|Sprinkle Chimney Cap|Candy|8|roof|1|1|0.3|cylinder|coral|gingerbread sprinkle_chimney gumdrop_gable
licorice_stick|Licorice Stick|Candy|6|wall|1|1|0.16|cane|lavender|gingerbread licorice_lane ginger_bake
licorice_twist|Licorice Twist|Candy|8|wall|1|1|0.18|cane|lavender|gingerbread licorice_lane cane_porch
mint_disc|Mint Disc|Candy|6|wall|1|1|0.12|cylinder|mint|gingerbread peppermint_door gumdrop_gable
jelly_square|Jelly Square|Candy|6|wall|1|1|0.16|box|coral|gingerbread ginger_bake gumdrop_gable
candy_dot|Candy Dot|Candy|6|wall|1|1|0.16|ball|butter|gingerbread sprinkle_chimney icing_shingles
porch_cane|Porch Cane|Candy|8|wall|1|1|0.2|cane|mint|gingerbread cane_porch peppermint_door
bake_tile|Bake Tile|Candy|6|wall|1|1|0.1|box|butter|gingerbread ginger_bake licorice_lane
butter_bauble|Butter Bauble|Baubles|6|hook|1|1|0.55|ball|butter|tree bauble_burst silver_cone
coral_bauble|Coral Bauble|Baubles|6|hook|1|1|0.55|ball|coral|tree bauble_burst blue_glass_branches
mint_bauble|Mint Bauble|Baubles|6|hook|1|1|0.55|ball|mint|tree bauble_burst frosted_fir
lavender_bauble|Lavender Bauble|Baubles|6|hook|1|1|0.55|ball|lavender|tree bauble_burst quiet_snow_pine
cream_bauble|Cream Bauble|Baubles|6|hook|1|1|0.55|ball|cream|tree silver_cone quiet_snow_pine
glass_drop|Glass Drop|Baubles|8|hook|1|1|0.6|ball|mint|tree blue_glass_branches ice_lantern_spruce
silver_drop|Silver Drop|Baubles|8|hook|1|1|0.6|ball|cream|tree silver_cone birch_white
blue_glass_ball|Blue Glass Ball|Baubles|8|hook|1|1|0.6|ball|lavender|tree blue_glass_branches silver_cone
frosted_ball|Frosted Ball|Baubles|6|hook|1|1|0.55|ball|cream|tree frosted_fir quiet_snow_pine
ice_drop|Ice Drop|Baubles|8|hook|1|1|0.6|ball|mint|tree ice_lantern_spruce frosted_fir
wool_pom|Wool Pom|Baubles|6|hook|1|1|0.5|ball|coral|tree wool_pom_pine quiet_snow_pine
blush_pom|Blush Pom|Baubles|6|hook|1|1|0.5|ball|coral|tree wool_pom_pine birch_white
paper_star|Paper Star|Strands|8|hook|1|1|0.7|star|butter|tree paper_star tinsel_topper
tinsel_bow|Tinsel Bow|Strands|8|hook|1|1|0.6|star|mint|tree tinsel_topper ribbon_spiral
ribbon_loop|Ribbon Loop|Strands|6|hook|1|1|0.5|star|lavender|tree ribbon_spiral paper_star tinsel_topper
ribbon_curl|Ribbon Curl|Strands|6|hook|1|1|0.45|slab|coral|tree ribbon_spiral bell_branch
popcorn_string|Popcorn String|Strands|8|hook|1|1|0.4|slab|cream|tree popcorn_garland cranberry_strand
cranberry_string|Cranberry String|Strands|8|hook|1|1|0.4|slab|coral|tree cranberry_strand popcorn_garland
bell_drop|Bell Drop|Strands|8|hook|1|1|0.55|bell|butter|tree bell_branch tinsel_topper
jingle_bell|Jingle Bell|Strands|6|hook|1|1|0.5|bell|butter|tree bell_branch paper_star
snowflake_cut|Snowflake Cutout|Strands|8|hook|1|1|0.65|star|cream|tree snowflake_ladder paper_star
ladder_snow|Ladder Snowflake|Strands|6|hook|1|1|0.6|star|mint|tree snowflake_ladder frosted_fir
pinecone_charm|Pinecone Charm|Charms|6|hook|1|1|0.45|ball|butter|tree quiet_snow_pine frosted_fir
cedar_candle|Cedar Candle|Charms|8|hook|1|1|0.7|lamp|cream|tree cedar_candles ice_lantern_spruce
candle_cup|Candle Cup|Charms|8|hook|1|1|0.55|lamp|butter|tree cedar_candles birch_white
ice_lantern|Ice Lantern|Charms|10|hook|1|1|0.7|lamp|mint|tree ice_lantern_spruce cedar_candles
birch_disc|Birch Disc|Charms|6|hook|1|1|0.35|cylinder|cream|tree birch_white quiet_snow_pine
birch_star|White Birch Star|Charms|8|hook|1|1|0.65|star|cream|tree birch_white paper_star
wool_strand|Wool Strand|Charms|6|hook|1|1|0.4|slab|lavender|tree wool_pom_pine popcorn_garland
cone_charm|Cone Charm|Charms|6|hook|1|1|0.5|ball|mint|tree silver_cone cedar_candles
garland_bell|Garland Bell|Charms|6|hook|1|1|0.5|bell|coral|tree popcorn_garland bell_branch
berry_strand|Berry Strand|Charms|8|hook|1|1|0.4|slab|coral|tree cranberry_strand snowflake_ladder
pibble_rug|Pibble Rug|Rugs|8|floor|2|2|0.08|slab|coral|room hearth_cocoa blanket_fort
unc_chair|Unc Armchair|Seating|12|floor|1|1|1.1|recliner|butter|room starlight_nook flannel_corner
]]

local function parse(raw: string): { Item }
	local list: { Item } = {}
	for line in string.gmatch(raw, "[^\n]+") do
		if line ~= "" then
			local bits = string.split(line, "|")
			local cost = tonumber(bits[4])
			local w = tonumber(bits[6])
			local d = tonumber(bits[7])
			local h = tonumber(bits[8])
			local tagText = bits[11]
			if cost == nil or w == nil or d == nil or h == nil or tagText == nil then
				error("bad prop line " .. line)
			end
			local tags = string.split(tagText, " ")
			table.insert(list, {
				id = bits[1],
				name = bits[2],
				category = bits[3],
				cost = cost,
				surface = bits[5],
				w = w,
				d = d,
				h = h,
				shape = bits[9],
				color = bits[10],
				roundType = tags[1],
				tags = tags,
			})
		end
	end
	return list
end

local list = parse(RAW)
local byId: { [string]: Item } = {}
for _, item in ipairs(list) do
	byId[item.id] = item
end

local Items = {
	list = list,
	byId = byId,
}

function Items.get(id: string): Item?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function Items.forRound(roundType: string): { Item }
	local out: { Item } = {}
	for _, item in ipairs(list) do
		if item.roundType == roundType then
			table.insert(out, item)
		end
	end
	return out
end

function Items.categories(roundType: string?): { string }
	local seen: { [string]: boolean } = {}
	local names: { string } = {}
	for _, item in ipairs(list) do
		if (roundType == nil or item.roundType == roundType) and not seen[item.category] then
			seen[item.category] = true
			table.insert(names, item.category)
		end
	end
	return names
end

return Items
