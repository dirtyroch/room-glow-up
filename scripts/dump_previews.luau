--!nocheck
-- Dump actual place geometry (sizes, CFrames, shapes, colors, materials, lights)
-- from the real server builders running on the headless World stub.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local World = require("../playtest/World")
local Items = require("../src/shared/Items")
local Bases = require("../src/shared/Bases")
local Look = require("../src/shared/Look")

local OUT = "/workspace/renders/rgu3d-scenes.json"

local world = World.new({
	root = ".",
	unix0 = 1797357600, -- holiday season
	jobId = "preview-dump",
}):boot()

local ctx = world.ctx
if not ctx or not ctx.plots then
	error("server ctx or plots missing")
end

local workspace = world.workspace

local function vec(v)
	if v == nil then
		return { 0, 0, 0 }
	end
	return { v.X, v.Y, v.Z }
end

local function col(c)
	if c == nil then
		return { 1, 1, 1 }
	end
	return { c.R, c.G, c.B }
end

local function enumName(value, fallback)
	if value == nil then
		return fallback
	end
	local text = tostring(value)
	local dotted = string.match(text, "([%w]+)$")
	if dotted and dotted ~= "" then
		return dotted
	end
	return fallback
end

local function partPayload(inst)
	local cf = inst.CFrame
	if cf == nil then
		return nil
	end
	local size = inst.Size or Vector3.new(1, 1, 1)
	local transparency = inst.Transparency or 0
	if type(transparency) ~= "number" then
		transparency = 0
	end
	if transparency >= 0.99 then
		return nil
	end
	local shape = enumName(inst.Shape, "Block")
	local material = enumName(inst.Material, "SmoothPlastic")
	local payload = {
		name = inst.Name,
		p = vec(cf.Position),
		s = { size.X, size.Y, size.Z },
		right = vec(cf.RightVector),
		up = vec(cf.UpVector),
		back = vec(cf.ZVector),
		c = col(inst.Color),
		t = transparency,
		shape = shape,
		mat = material,
	}
	local lights = {}
	for _, child in ipairs(inst:GetChildren()) do
		if child:IsA("PointLight") or child:IsA("SurfaceLight") or child:IsA("SpotLight") then
			local light = {
				kind = child.ClassName,
				c = col(child.Color),
				b = child.Brightness or 1,
				range = child.Range or 8,
			}
			if child:IsA("SurfaceLight") or child:IsA("SpotLight") then
				light.face = enumName(child.Face, "Back")
				light.angle = child.Angle or 90
			end
			table.insert(lights, light)
		end
	end
	if #lights > 0 then
		payload.lights = lights
	end
	return payload
end

local function collect(root, filterFn)
	local parts = {}
	local skipped = 0
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("BasePart") then
			if filterFn == nil or filterFn(inst) then
				local row = partPayload(inst)
				if row then
					table.insert(parts, row)
				else
					skipped += 1
				end
			end
		end
	end
	return parts, skipped
end

local function underPlot(inst, index)
	local node = inst
	while node do
		if node.Name == "Plot" .. tostring(index) then
			return true
		end
		node = node.Parent
	end
	return false
end

local function underPlaza(inst)
	local node = inst
	while node do
		if node.Name == "Plaza" then
			return true
		end
		node = node.Parent
	end
	return false
end

local function decorate(index, roundType, placements, family)
	ctx.plots.clearIndex(index)
	ctx.plots.show(roundType)
	if family and ctx.plots.tint then
		ctx.plots.tint(family)
	end
	for i, row in ipairs(placements) do
		ctx.plots.spawnPiece(index, {
			id = i,
			itemId = row[1],
			x = row[2],
			z = row[3],
			rot = row[4] or 0,
			color = row[5] or (Items.get(row[1]) and Items.get(row[1]).color) or "cream",
			placedAt = 0,
		}, roundType, true)
	end
end

local function warnParts()
	-- Count visible parts on the last decorated plot's Items folder for budget checks.
	local counts = {}
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return counts
	end
	local plot = plots:FindFirstChild("Plot1")
	if not plot then
		return counts
	end
	local items = plot:FindFirstChild("Items")
	if not items then
		return counts
	end
	for _, model in ipairs(items:GetChildren()) do
		local id = model:GetAttribute("ItemId") or model.Name
		local n = 0
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("BasePart") then
				n += 1
			end
		end
		table.insert(counts, { id = id, parts = n })
	end
	return counts
end

local HEARTH = {
	{ "hearth_rug", 2, 2 },
	{ "butter_bench", 2, 4 },
	{ "cocoa_table", 2, 3 },
	{ "cocoa_stool", 4, 3 },
	{ "hearth_lamp", 5, 5 },
	{ "window_candle", 0, 5 },
	{ "mantel_shelf", 0, 0 },
	{ "gift_stack", 5, 0 },
	{ "mini_pine", 0, 3 },
	{ "cocoa_mug", 1, 3 },
	{ "cocoa_wreath", 0, 2 },
	{ "stocking_row", 3, 2 },
	{ "coral_armchair", 5, 2 },
	{ "star_pillow", 4, 4 },
}

local GINGER = {
	{ "sugar_border", 3, 0 },
	{ "door_icing", 3, 1 },
	{ "gumdrop", 1, 1 },
	{ "gumdrop", 6, 1 },
	{ "gumdrop_cluster", 0, 3 },
	{ "gumdrop_cluster", 7, 3 },
	{ "candy_cane", 2, 2 },
	{ "candy_cane", 5, 2 },
	{ "peppermint_disc", 1, 3 },
	{ "mint_disc", 6, 3 },
	{ "jelly_square", 0, 1 },
	{ "icing_shingle", 2, 1 },
	{ "icing_drip", 5, 0 },
	{ "frosting_swirl", 3, 2 },
	{ "peak_icing", 3, 3 },
	{ "chimney_cap", 6, 3 },
}

local WINTER = {
	{ "snow_rug", 2, 2 },
	{ "lavender_settee", 2, 4 },
	{ "sunroom_table", 2, 3 },
	{ "cloud_pouf", 4, 3 },
	{ "potted_spruce", 0, 4 },
	{ "window_candle", 5, 5 },
	{ "frosted_frame", 2, 1 },
	{ "blanket_roll", 5, 4 },
	{ "star_lamp", 0, 0 },
	{ "snow_globe", 1, 3 },
	{ "birch_sapling", 5, 0 },
	{ "flannel_mat", 1, 1 },
	{ "reading_lamp", 4, 5 },
	{ "quilt_square", 5, 2 },
}



local GLOW = {
	{ "ribbon_rug", 2, 2, 0, "lavender" },
	{ "lavender_settee", 2, 4, 0, "lavender" },
	{ "quilt_table", 2, 3, 0, "cream" },
	{ "star_lamp", 0, 0, 0, "butter" },
	{ "globe_light", 5, 5, 0, "coral" },
	{ "string_lights", 0, 2, 0, "butter" },
	{ "string_lights", 3, 2, 0, "coral" },
	{ "reader_chair", 5, 2, 0, "coral" },
	{ "star_pillow", 4, 4, 0, "butter" },
	{ "spark_accent", 1, 3, 0, "butter" },
	{ "ribbon_sash", 0, 0, 0, "coral" },
	{ "gift_stack", 5, 0, 0, "coral" },
	{ "holly_pot", 0, 3, 0, "mint" },
	{ "star_mat", 1, 1, 0, "butter" },
	{ "book_ledge", 3, 0, 0, "cream" },
}

local function gradeOf(family)
	local preset = Look.preset(family)
	local function rgb01(channels)
		return { channels[1] / 255, channels[2] / 255, channels[3] / 255 }
	end
	return {
		family = family,
		brightness = preset.brightness,
		bloom = preset.bloom,
		bloomThreshold = preset.bloomThreshold,
		saturation = preset.saturation,
		contrast = preset.contrast,
		grade = preset.grade,
		exposure = preset.exposure,
		tint = rgb01(preset.tint),
		light = rgb01(preset.light),
		ambient = rgb01(preset.ambient),
		air = rgb01(preset.air),
		outdoor = rgb01(preset.outdoor),
	}
end

local function cameraOf(roundType, index)
	local px, py, pz, lx, ly, lz = Bases.camera(roundType, index)
	return { pos = { px, py, pz }, look = { lx, ly, lz } }
end

local function addClientTourFx(parts, themeId, index)
	local px, py, pz, lx, ly, lz = Bases.camera("room", index)
	local origin = Vector3.new(px, py, pz)
	local aim = Vector3.new(lx, ly, lz)
	local look = (aim - origin)
	if look.Magnitude < 0.1 then
		return
	end
	look = look.Unit
	local swatch = Look.swatch(themeId)
	local function rgb(i)
		local ch = swatch[i]
		return { ch[1] / 255, ch[2] / 255, ch[3] / 255 }
	end
	local starAt = aim + Vector3.new(0, 9.5, 0)
	local gold = rgb(1)
	local function starArm(sx, sy, sz, right, up, back)
		table.insert(parts, {
			name = "RisingStar",
			p = vec(starAt),
			s = { sx, sy, sz },
			right = right,
			up = up,
			back = back,
			c = gold,
			t = 0,
			shape = "Block",
			mat = "Neon",
		})
	end
	starArm(2.4, 0.35, 0.35, { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 })
	starArm(0.35, 2.4, 0.35, { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 })
	local k = 0.70710678
	starArm(2.1, 0.3, 0.3, { k, k, 0 }, { -k, k, 0 }, { 0, 0, 1 })
	starArm(2.1, 0.3, 0.3, { k, -k, 0 }, { k, k, 0 }, { 0, 0, 1 })
	table.insert(parts, {
		name = "RisingStar",
		p = vec(starAt),
		s = { 0.9, 0.9, 0.9 },
		right = { 1, 0, 0 },
		up = { 0, 1, 0 },
		back = { 0, 0, 1 },
		c = rgb(3),
		t = 0,
		shape = "Ball",
		mat = "Neon",
	})
end

local scenes = {}
local partCounts = {}

-- Lobby: plaza + all room shells, no furniture.
ctx.plots.clearItems()
ctx.plots.show("room")
if ctx.plots.tint then
	ctx.plots.tint("hearth")
end
do
	local parts = collect(workspace, function(inst)
		return underPlaza(inst) or string.find(inst:GetFullName(), "Plots", 1, true) ~= nil
	end)
	scenes.lobby = {
		camera = { pos = { 6, 12, -8 }, look = { -1, 6.6, -46 } },
		family = "hearth",
		grade = gradeOf("hearth"),
		parts = parts,
	}
	print("lobby parts", #parts)
end

-- Cocoa Hearth on plot 3 (middle of first row-ish; plots 1-5 are first row)
decorate(3, "room", HEARTH, "hearth")
partCounts.hearth = warnParts()
do
	local parts = collect(workspace, function(inst)
		return underPlot(inst, 3)
	end)
	scenes.hearth = {
		family = "hearth",
		grade = gradeOf("hearth"),
		camera = { pos = { 11, 11, 82 }, look = { 0, 4, 38 } },
		parts = parts,
	}
	print("hearth parts", #parts)
end

-- Tour uses the same hearth room, plus client cone/star from Show.luau.
do
	local parts = collect(workspace, function(inst)
		return underPlot(inst, 3)
	end)
	addClientTourFx(parts, "hearth_cocoa", 3)
	scenes.tour = {
		family = "hearth",
		grade = gradeOf("hearth"),
		camera = { pos = { 10, 10, 80 }, look = { 0, 4.5, 40 } },
		parts = parts,
	}
	print("tour parts", #parts)
end

-- Gingerbread on plot 3
decorate(3, "gingerbread", GINGER, "ginger")
partCounts.ginger = warnParts()
do
	local parts = collect(workspace, function(inst)
		return underPlot(inst, 3)
	end)
	scenes.ginger = {
		family = "ginger",
		grade = gradeOf("ginger"),
		camera = { pos = { 52, 22, 112 }, look = { 0, 16, 46 } },
		parts = parts,
	}
	print("ginger parts", #parts)
end

-- Winter room on plot 3
decorate(3, "room", WINTER, "winter")
partCounts.winter = warnParts()
do
	local parts = collect(workspace, function(inst)
		return underPlot(inst, 3)
	end)
	scenes.winter = {
		family = "winter",
		grade = gradeOf("winter"),
		camera = { pos = { 11, 11, 82 }, look = { 0, 4, 38 } },
		parts = parts,
	}
	print("winter parts", #parts)
end

-- Glow / neon-ish room on plot 3
decorate(3, "room", GLOW, "glow")
partCounts.glow = warnParts()
do
	local parts = collect(workspace, function(inst)
		return underPlot(inst, 3)
	end)
	scenes.glow = {
		family = "glow",
		grade = gradeOf("glow"),
		camera = { pos = { 11, 11, 82 }, look = { 0, 4, 38 } },
		parts = parts,
	}
	print("glow parts", #parts)
end

-- Podium: just the plaza stage (the actual in-game results platform).
ctx.plots.clearItems()
ctx.plots.show("room")
do
	local parts = collect(workspace, function(inst)
		return underPlaza(inst)
	end)
	scenes.podium = {
		camera = { pos = { 18, 8, -4 }, look = { 14, 3.6, -34 } },
		family = "hearth",
		grade = gradeOf("hearth"),
		parts = parts,
	}
	print("podium parts", #parts)
end

local payload = {
	scenes = scenes,
	partCounts = partCounts,
	bootLog = {
		error = world.log.error,
		warn = world.log.warn,
	},
}

fs.writeFile(OUT, serde.encode("json", payload, true))
print("wrote", OUT)
