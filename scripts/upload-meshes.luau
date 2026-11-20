--!nocheck
--[[
	upload-meshes.luau — dry run by default. Lists the furniture meshes in
	assets/meshes (with their Finish map variants), the room-shell meshes in
	assets/shell, and the floor/wall textures in assets/surfaces, and what would be
	uploaded. With --apply it uploads each FBX as a Model and each PNG map as an
	Image through Open Cloud, then writes the ids into src/shared/Meshes.luau.
	It never publishes the place and never prints the key.

	  lune run scripts/upload-meshes
	  ROBLOX_OPEN_CLOUD_KEY=... lune run scripts/upload-meshes --user <userId> --apply
	  ROBLOX_OPEN_CLOUD_KEY=... lune run scripts/upload-meshes --group <groupId> --apply [itemId ...]

	The key needs the asset:read and asset:write scopes. Items that already have
	ids are skipped. Check one item in Studio after the first run: it should face
	the room (+Z) and its fabric should follow the palette recolor.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local LUAU_PATH = "src/shared/Meshes.luau"
local MAPS = { "color", "normal", "roughness", "metalness", "emissive" }
-- Finish variants: id key -> file (tools/meshes/finishes.py).
local FINISH = { satinR = "rough_satin", metalR = "rough_metal", metalM = "metal_metal", glossR = "rough_gloss", matteR = "rough_matte" }
local FINISH_ORDER = { "satinR", "metalR", "metalM", "glossR", "matteR" }

local args = process.args
local apply = table.find(args, "--apply") ~= nil
local creator = nil
local only = {}
local i = 1
while i <= #args do
	local a = args[i]
	if a == "--user" or a == "--group" then
		local id = args[i + 1]
		if not id or not string.match(id, "^%d+$") then
			print("x " .. a .. " needs a numeric id")
			process.exit(1)
		end
		creator = if a == "--user" then { userId = id } else { groupId = id }
		i += 2
	elseif a == "--apply" then
		i += 1
	else
		only[a] = true
		i += 1
	end
end

local manifest = serde.decode("json", fs.readFile("assets/meshes/manifest.json"))
local source = fs.readFile(LUAU_PATH)

local function currentIds(itemId: string): ({ [string]: number }, { string })
	local block = string.match(source, "\n\t" .. itemId .. " = {(.-)\n\t},")
	local ids = {}
	local order = {}
	if block then
		local line = string.match(block, "ids = {(.-)}")
		for key, value in string.gmatch(line or "", "(%w+) = (%d+)") do
			ids[key] = tonumber(value)
			table.insert(order, key)
		end
	end
	return ids, order
end

local function writeIds(itemId: string, ids: { [string]: number }, order: { string })
	local parts = {}
	for _, key in ipairs(order) do
		table.insert(parts, key .. " = " .. tostring(ids[key] or 0))
	end
	local line = "ids = { " .. table.concat(parts, ", ") .. " }"
	local pattern = "(\n\t" .. itemId .. " = {.-)ids = {.-}"
	local updated, n = string.gsub(source, pattern, function(head)
		return head .. line
	end, 1)
	if n ~= 1 then
		error("could not find ids for " .. itemId)
	end
	source = updated
	fs.writeFile(LUAU_PATH, source)
end

local plan = {}
local totalBytes = 0

local function addRow(itemId: string, dir: string, fbx: boolean, maps: { string }, files: { [string]: string }?, label: string)
	if next(only) ~= nil and not only[itemId] then
		return
	end
	local ids, order = currentIds(itemId)
	local uploads = {}
	if fbx and (ids.model or 0) == 0 then
		table.insert(uploads, { key = "model", path = dir .. itemId .. ".fbx", assetType = "Model", mime = "model/fbx" })
	end
	for _, map in ipairs(maps) do
		local file = if files then files[map] else map
		local path = dir .. file .. ".png"
		if fs.isFile(path) and (ids[map] or 0) == 0 and table.find(order, map) ~= nil then
			table.insert(uploads, { key = map, path = path, assetType = "Image", mime = "image/png" })
		end
	end
	for _, up in ipairs(uploads) do
		totalBytes += #fs.readFile(up.path)
	end
	print(string.format("  %-16s %s  %d to upload", itemId, label, #uploads))
	table.insert(plan, { itemId = itemId, ids = ids, order = order, uploads = uploads })
end

local itemMaps = table.clone(MAPS)
for _, key in ipairs(FINISH_ORDER) do
	table.insert(itemMaps, key)
end
local itemFiles = {}
for _, map in ipairs(MAPS) do
	itemFiles[map] = map
end
for key, file in pairs(FINISH) do
	itemFiles[key] = file
end

print("Furniture meshes")
for _, entry in ipairs(manifest.items) do
	addRow(entry.id, "assets/meshes/" .. entry.id .. "/", true, itemMaps, itemFiles, string.format("%6d tris", entry.tris))
end
print("Room shell meshes")
for _, entry in ipairs(manifest.shell or {}) do
	addRow(entry.id, "assets/shell/" .. entry.id .. "/", true, MAPS, nil, string.format("%6d tris", entry.tris))
end
print("Floor and wall textures (also import them in Studio as MaterialVariants)")
for _, entry in ipairs(manifest.surfaces or {}) do
	addRow(entry.id, "assets/surfaces/" .. entry.id .. "/", false, { "color", "normal", "roughness" }, nil, entry.variant)
end
local count = 0
for _, row in ipairs(plan) do
	count += #row.uploads
end
print(string.format("%d uploads, %.1f MB.", count, totalBytes / 1e6))

if not apply then
	print("\nDry run only. Nothing was uploaded and the place was not published.")
	print("Add --user <id> or --group <id> and --apply to upload and save the ids into " .. LUAU_PATH .. ".")
	return
end

local key = process.env.ROBLOX_OPEN_CLOUD_KEY
if not key or key == "" then
	print("x ROBLOX_OPEN_CLOUD_KEY is not set")
	process.exit(1)
end
if not creator then
	print("x pass --user <id> or --group <id>")
	process.exit(1)
end

local BOUNDARY = "----RoomGlowUpMeshes7d3f"

local function multipart(requestJson: string, fileName: string, mime: string, bytes: string): string
	return table.concat({
		"--" .. BOUNDARY,
		'Content-Disposition: form-data; name="request"',
		"",
		requestJson,
		"--" .. BOUNDARY,
		'Content-Disposition: form-data; name="fileContent"; filename="' .. fileName .. '"',
		"Content-Type: " .. mime,
		"",
		bytes,
		"--" .. BOUNDARY .. "--",
		"",
	}, "\r\n")
end

local function upload(itemId: string, up): number
	local request = serde.encode("json", {
		assetType = up.assetType,
		displayName = "RGU " .. itemId .. " " .. up.key,
		description = "Room Glow Up furniture: " .. itemId .. " (" .. up.key .. ")",
		creationContext = { creator = creator },
	})
	local fileName = string.match(up.path, "[^/]+$")
	local res = net.request({
		url = "https://apis.roblox.com/assets/v1/assets",
		method = "POST",
		headers = { ["x-api-key"] = key, ["content-type"] = "multipart/form-data; boundary=" .. BOUNDARY },
		body = multipart(request, fileName, up.mime, fs.readFile(up.path)),
	})
	if not res.ok then
		error(string.format("upload %s %s failed: HTTP %d %s", itemId, up.key, res.statusCode, string.sub(res.body, 1, 300)))
	end
	local op = serde.decode("json", res.body)
	local path = op.path or ("operations/" .. tostring(op.operationId))
	for _ = 1, 30 do
		if op.done and op.response and op.response.assetId then
			return tonumber(op.response.assetId)
		end
		task.wait(2)
		local poll = net.request({
			url = "https://apis.roblox.com/assets/v1/" .. path,
			method = "GET",
			headers = { ["x-api-key"] = key },
		})
		if poll.ok then
			op = serde.decode("json", poll.body)
		end
	end
	error("upload " .. itemId .. " " .. up.key .. " did not finish")
end

for _, row in ipairs(plan) do
	for _, up in ipairs(row.uploads) do
		local id = upload(row.itemId, up)
		row.ids[up.key] = id
		writeIds(row.itemId, row.ids, row.order)
		print(string.format("  %s %s -> %d", row.itemId, up.key, id))
	end
end
print("Ids saved in " .. LUAU_PATH .. ". Rebuild with scripts/build.sh; nothing was published.")
