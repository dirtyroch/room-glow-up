--!nocheck
--[[
	create-shop.luau — dry-run by default. Lists every pass and product in Config.Shop.
	With a universe id and --apply, creates them through Open Cloud and writes ids
	over the `id = 0` placeholders. This script does not publish the place.

	  lune run scripts/create-shop
	  ROBLOX_API_KEY=... lune run scripts/create-shop <universeId> --apply
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local ShopSync = require("./lib/ShopSync")
local Config = require("../src/shared/Config")

local CONFIG_PATH = "src/shared/Config.luau"
local universeId = process.args[1]
local apply = table.find(process.args, "--apply") ~= nil

local function die(msg: string)
	print("x " .. msg)
	process.exit(1)
end

local items = ShopSync.items(Config.Shop)
local plan = ShopSync.plan(items, { pass = {}, product = {} })
for _, problem in ipairs(plan.problems) do
	print("x " .. problem)
end
if #plan.problems > 0 then
	die("Fix the catalog first.")
end

print("Shop catalog")
for _, it in ipairs(items) do
	local state = if it.id == 0 then "id 0, will not prompt" else ("id " .. tostring(it.id))
	print(string.format("  %-8s %-20s %4d R$  %s  (%s)", it.kind, it.key, it.price, it.name, state))
end
local passes, products, placeholders = 0, 0, 0
for _, it in ipairs(items) do
	if it.kind == "pass" then
		passes += 1
	else
		products += 1
	end
	if it.id == 0 then
		placeholders += 1
	end
end
print(string.format("%d passes, %d products, %d still at id 0.", passes, products, placeholders))

if not apply then
	print("\nDry run only. Nothing was created and the place was not published.")
	print("Add a universe id and --apply to create these and save the ids into " .. CONFIG_PATH .. ".")
	return
end

if not universeId or not string.match(universeId, "^%d+$") then
	die("Usage: ROBLOX_API_KEY=... lune run scripts/create-shop <universeId> --apply")
end

local key = process.env.ROBLOX_API_KEY
if not key or key == "" then
	die("Set ROBLOX_API_KEY to an Open Cloud key with game-pass and developer-product read + write.")
end

local net = require("@lune/net")
local serde = require("@lune/serde")
local task = require("@lune/task")
local BASE = process.env.ROBLOX_API_BASE or "https://apis.roblox.com"

local function call(method: string, path: string, body: string?, contentType: string?): any
	local headers = { ["x-api-key"] = key }
	if contentType then
		headers["content-type"] = contentType
	end
	for attempt = 1, 5 do
		local res = net.request({ url = BASE .. path, method = method, headers = headers, body = body })
		if res.ok then
			return if res.body ~= "" then serde.decode("json", res.body) else {}
		end
		if res.statusCode == 429 or res.statusCode >= 500 then
			task.wait(attempt * 2)
		else
			die(string.format("%s %s -> %d %s", method, path, res.statusCode, res.body))
		end
	end
	return die(method .. " " .. path .. " kept failing")
end

local function listAll(path: string, field: string, idField: string): { ShopSync.Existing }
	local out, token = {}, nil
	repeat
		local q = "?pageSize=50" .. (token and ("&pageToken=" .. token) or "")
		local page = call("GET", path .. q)
		for _, e in ipairs(page[field] or {}) do
			table.insert(out, { id = tonumber(e[idField]), name = e.name })
		end
		token = page.nextPageToken
	until token == nil or token == ""
	return out
end

local passPath = "/game-passes/v1/universes/" .. universeId .. "/game-passes"
local productPath = "/developer-products/v2/universes/" .. universeId .. "/developer-products"
print("Reading what's already created for universe " .. universeId .. "...")
local existing = {
	pass = listAll(passPath .. "/creator", "gamePasses", "gamePassId"),
	product = listAll(productPath .. "/creator", "developerProducts", "productId"),
}
plan = ShopSync.plan(items, existing)
for _, problem in ipairs(plan.problems) do
	print("x " .. problem)
end
if #plan.problems > 0 then
	die("Fix the catalog first.")
end

local ids: { [string]: number } = {}
for _, linked in ipairs(plan.link) do
	ids[linked.key] = linked.id
end
local function save()
	local src = fs.readFile(CONFIG_PATH)
	local newSrc = ShopSync.applyIds(src, ids)
	if newSrc ~= src then
		fs.writeFile(CONFIG_PATH, newSrc)
	end
end
save()

for i, it in ipairs(plan.create) do
	local boundary = "----RoomGlowUp" .. tostring(os.time()) .. tostring(i)
	local body = ShopSync.multipart(ShopSync.formFields(it, nil), boundary)
	local path = if it.kind == "pass" then passPath else productPath
	local res = call("POST", path, body, "multipart/form-data; boundary=" .. boundary)
	local id = tonumber(if it.kind == "pass" then res.gamePassId else res.productId)
	if not id or id <= 0 then
		die("No id returned for " .. it.key)
	end
	ids[it.key] = id
	save()
	print(string.format("  ok %s -> %d", it.key, id))
	task.wait(0.4)
end

print("Ids saved in " .. CONFIG_PATH .. ". The place was not published.")
