--!nocheck
-- Headless stand-in for a Roblox server. A fake clock, a cooperative task
-- scheduler, a small Instance tree, and the services the server code touches.
-- It loads the real src/server and src/shared modules from disk, the same tree
-- default.project.json builds. Nothing here talks to Roblox.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local World = {}
World.__index = World

local CLASS_TREE = {
	Part = { "Part", "FormFactorPart", "BasePart", "PVInstance" },
	WedgePart = { "WedgePart", "BasePart", "PVInstance" },
	Model = { "Model", "PVInstance" },
	Folder = { "Folder" },
	BillboardGui = { "BillboardGui", "LayerCollector", "GuiBase2d" },
	SurfaceGui = { "SurfaceGui", "LayerCollector", "GuiBase2d" },
	TextLabel = { "TextLabel", "GuiObject", "GuiBase2d" },
	Frame = { "Frame", "GuiObject", "GuiBase2d" },
	UICorner = { "UICorner" },
	ModuleScript = { "ModuleScript", "LuaSourceContainer" },
	Script = { "Script", "LuaSourceContainer" },
	RemoteFunction = { "RemoteFunction" },
	RemoteEvent = { "RemoteEvent" },
	Player = { "Player" },
}

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[deepCopy(k)] = deepCopy(x)
	end
	return out
end
World.deepCopy = deepCopy

------------------------------------------------------------------ signals

local function newSignal(world)
	local signal = { _conns = {} }
	function signal:Connect(fn)
		local conn = { Connected = true, _fn = fn }
		function conn:Disconnect()
			conn.Connected = false
		end
		table.insert(signal._conns, conn)
		return conn
	end
	function signal:Once(fn)
		local conn
		conn = signal:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end
	function signal:Fire(...)
		for _, conn in ipairs(table.clone(signal._conns)) do
			if conn.Connected then
				world:spawn("signal", conn._fn, ...)
			end
		end
	end
	function signal:Wait()
		local co = coroutine.running()
		local got
		signal:Once(function(...)
			got = table.pack(...)
			world:resume(co)
		end)
		coroutine.yield()
		return table.unpack(got, 1, got.n)
	end
	return signal
end

------------------------------------------------------------------ instances

local Instance = {}
local instanceMeta = {}

local function isInstance(v: any): boolean
	return type(v) == "table" and getmetatable(v) == instanceMeta
end
World.isInstance = isInstance

local methods = {}

function methods:IsA(className: string): boolean
	local chain = CLASS_TREE[rawget(self, "_class")] or { rawget(self, "_class") }
	if className == "Instance" then
		return true
	end
	return table.find(chain, className) ~= nil
end

function methods:GetChildren()
	return table.clone(rawget(self, "_children"))
end

function methods:GetDescendants()
	local out = {}
	local function walk(node)
		for _, child in ipairs(rawget(node, "_children")) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function methods:FindFirstChild(name: string, recursive: boolean?)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_props").Name == name then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(rawget(self, "_children")) do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function methods:FindFirstChildOfClass(className: string)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_class") == className then
			return child
		end
	end
	return nil
end

function methods:FindFirstChildWhichIsA(className: string)
	for _, child in ipairs(rawget(self, "_children")) do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

function methods:FindFirstAncestor(name: string)
	local node = rawget(self, "_props").Parent
	while node do
		if node.Name == name then
			return node
		end
		node = rawget(node, "_props").Parent
	end
	return nil
end

function methods:WaitForChild(name: string, timeout: number?)
	local found = self:FindFirstChild(name)
	if found then
		return found
	end
	local world = rawget(self, "_world")
	world:note("error", "WaitForChild would yield forever: " .. self:GetFullName() .. "." .. tostring(name))
	error("Infinite yield possible on '" .. self:GetFullName() .. ":WaitForChild(\"" .. tostring(name) .. "\")'")
end

function methods:GetFullName(): string
	local parts = {}
	local node = self
	while node and rawget(node, "_class") ~= "DataModel" do
		table.insert(parts, 1, rawget(node, "_props").Name)
		node = rawget(node, "_props").Parent
	end
	return table.concat(parts, ".")
end

function methods:Destroy()
	self.Parent = nil
	rawset(self, "_destroyed", true)
	for _, child in ipairs(table.clone(rawget(self, "_children"))) do
		child:Destroy()
	end
end

function methods:ClearAllChildren()
	for _, child in ipairs(table.clone(rawget(self, "_children"))) do
		child:Destroy()
	end
end

function methods:Clone()
	local world = rawget(self, "_world")
	local copy = world:newInstance(rawget(self, "_class"))
	for k, v in pairs(rawget(self, "_props")) do
		if k ~= "Parent" then
			rawget(copy, "_props")[k] = v
		end
	end
	for k, v in pairs(rawget(self, "_attrs")) do
		rawget(copy, "_attrs")[k] = v
	end
	for _, child in ipairs(rawget(self, "_children")) do
		child:Clone().Parent = copy
	end
	return copy
end

local ATTR_TYPES = {
	["nil"] = true,
	string = true,
	number = true,
	boolean = true,
}

function methods:SetAttribute(name: string, value: any)
	local world = rawget(self, "_world")
	if type(name) ~= "string" then
		error("Attribute name must be a string")
	end
	local kind = if isInstance(value) then "Instance" else typeof(value)
	if not ATTR_TYPES[kind] and kind ~= "Vector3" and kind ~= "Color3" and kind ~= "CFrame" and kind ~= "UDim2" then
		-- Roblox throws here. Tables and functions cannot be attributes.
		error("SetAttribute: " .. kind .. " is not a supported attribute type (" .. name .. ")")
	end
	if kind == "number" and value ~= value then
		world:note("warn", "NaN attribute " .. name .. " on " .. self:GetFullName())
	end
	local attrs = rawget(self, "_attrs")
	local old = attrs[name]
	attrs[name] = value
	if old ~= value then
		local sig = rawget(self, "_attrSignals")[name]
		if sig then
			sig:Fire()
		end
		world:onAttribute(self, name, value)
	end
end

function methods:GetAttribute(name: string)
	return rawget(self, "_attrs")[name]
end

function methods:GetAttributes()
	return table.clone(rawget(self, "_attrs"))
end

function methods:GetAttributeChangedSignal(name: string)
	local sigs = rawget(self, "_attrSignals")
	if not sigs[name] then
		sigs[name] = newSignal(rawget(self, "_world"))
	end
	return sigs[name]
end

function methods:GetPropertyChangedSignal(_name: string)
	return newSignal(rawget(self, "_world"))
end

function methods:GetPivot()
	local props = rawget(self, "_props")
	if props.PrimaryPart then
		return props.PrimaryPart.CFrame
	end
	return props.CFrame or roblox.CFrame.new()
end

function methods:PivotTo(cf)
	local props = rawget(self, "_props")
	if props.PrimaryPart then
		props.PrimaryPart.CFrame = cf
	else
		props.CFrame = cf
	end
end

instanceMeta.__index = function(self, key)
	local m = methods[key]
	if m then
		return m
	end
	local extra = rawget(self, "_methods")
	if extra and extra[key] ~= nil then
		return extra[key]
	end
	local props = rawget(self, "_props")
	local v = props[key]
	if v ~= nil then
		return v
	end
	if key == "ClassName" then
		return rawget(self, "_class")
	end
	return self:FindFirstChild(key)
end

instanceMeta.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		if rawget(self, "_destroyed") and value ~= nil then
			error("The Parent property of " .. tostring(props.Name) .. " is locked")
		end
		local old = props.Parent
		if old == value then
			return
		end
		if old then
			local list = rawget(old, "_children")
			local idx = table.find(list, self)
			if idx then
				table.remove(list, idx)
			end
		end
		props.Parent = value
		if value then
			if not isInstance(value) then
				error("Parent must be an Instance")
			end
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	local hook = rawget(self, "_setHook")
	if hook then
		hook(self, key, value)
	end
	props[key] = value
end

instanceMeta.__tostring = function(self)
	return rawget(self, "_props").Name or rawget(self, "_class")
end

function World:newInstance(className: string, parent: any?)
	local inst = setmetatable({
		_class = className,
		_world = self,
		_props = { Name = className },
		_attrs = {},
		_attrSignals = {},
		_children = {},
	}, instanceMeta)
	if parent then
		inst.Parent = parent
	end
	return inst
end

------------------------------------------------------------------ scheduler

function World.new(options: any?)
	local opts = options or {}
	local self = setmetatable({}, World)
	self.root = opts.root or "."
	self.clock = 0
	-- Server time is unix seconds, like workspace:GetServerTimeNow().
	self.unix0 = opts.unix0 or 1797357600
	self.jobId = opts.jobId or ("job-" .. tostring(math.random(1, 1e9)))
	self.datastore = opts.datastore or {}
	self.storeLatency = opts.storeLatency or 0.15
	self.storeFailures = opts.storeFailures or 0
	self.keyGap = opts.keyGap or 6
	self.storeStats = { calls = 0, times = {}, lastWrite = {}, queued = 0, maxQueue = 0 }
	self.ready = {}
	self.sleeping = {}
	self.log = { error = {}, warn = {}, pcall = {}, print = {} }
	self.prompts = {}
	self.analytics = {}
	self.attrWatchers = {}
	self.bindToClose = {}
	self.moduleCache = {}
	self.nextUserId = 1000
	self.policy = {}
	return self
end

function World:note(kind: string, msg: string)
	local list = self.log[kind]
	if not list then
		list = {}
		self.log[kind] = list
	end
	table.insert(list, { at = self.clock, msg = msg })
end

function World:onAttribute(inst, name, value)
	for _, fn in ipairs(self.attrWatchers) do
		fn(inst, name, value)
	end
end

function World:resume(co, ...)
	if coroutine.status(co) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		self:note("error", "thread error: " .. tostring(err) .. "\n" .. debug.traceback(co))
	end
end

function World:spawn(label: string, fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		self:note("error", "[" .. label .. "] " .. tostring(err) .. "\n" .. debug.traceback(co))
	end
	return co
end

function World:wait(seconds: number?)
	local co = coroutine.running()
	local dt = math.max(seconds or 0, 1 / 60)
	table.insert(self.sleeping, { co = co, at = self.clock + dt, start = self.clock })
	local elapsed = coroutine.yield()
	return elapsed or dt
end

function World:runDue()
	local guard = 0
	while true do
		guard += 1
		if guard > 10000 then
			self:note("error", "scheduler livelock")
			return
		end
		local due = nil
		local index = nil
		for i, item in ipairs(self.sleeping) do
			if item.at <= self.clock + 1e-9 and (due == nil or item.at < due.at) then
				due = item
				index = i
			end
		end
		if not due then
			return
		end
		table.remove(self.sleeping, index)
		self:resume(due.co, self.clock - due.start)
	end
end

------------------------------------------------------------------ services

function World:buildGame()
	local world = self
	local game = self:newInstance("DataModel")
	game.Name = "Game"
	self.game = game
	local services = {}
	rawset(game, "_methods", {
		GetService = function(_self, name)
			local svc = services[name]
			if not svc then
				error("'" .. tostring(name) .. "' is not a valid Service name")
			end
			return svc
		end,
		BindToClose = function(_self, fn)
			table.insert(world.bindToClose, fn)
		end,
	})
	rawget(game, "_props").JobId = self.jobId
	rawget(game, "_props").PrivateServerOwnerId = 0
	rawget(game, "_props").PlaceId = 0
	rawget(game, "_props").GameId = 0

	local function service(name, className)
		local svc = self:newInstance(className or name, game)
		svc.Name = name
		services[name] = svc
		return svc
	end

	local workspace = service("Workspace")
	rawset(workspace, "_methods", {
		GetServerTimeNow = function()
			return world.unix0 + world.clock
		end,
	})
	self.workspace = workspace
	service("ReplicatedStorage")
	service("ServerScriptService")
	service("ServerStorage")
	service("Lighting")
	service("SoundService")
	service("StarterGui")
	service("StarterPlayer")

	local players = service("Players")
	self.players = players
	local playerAdded = newSignal(self)
	local playerRemoving = newSignal(self)
	rawset(players, "_methods", {
		PlayerAdded = playerAdded,
		PlayerRemoving = playerRemoving,
		GetPlayers = function()
			local out = {}
			for _, child in ipairs(rawget(players, "_children")) do
				if rawget(child, "_class") == "Player" then
					table.insert(out, child)
				end
			end
			return out
		end,
		GetPlayerByUserId = function(_self, userId)
			for _, child in ipairs(rawget(players, "_children")) do
				if rawget(child, "_class") == "Player" and child.UserId == userId then
					return child
				end
			end
			return nil
		end,
	})
	rawget(players, "_props").MaxPlayers = 10

	local runService = service("RunService")
	local heartbeat = newSignal(self)
	self.heartbeat = heartbeat
	rawset(runService, "_methods", {
		Heartbeat = heartbeat,
		Stepped = newSignal(self),
		RenderStepped = newSignal(self),
		IsStudio = function()
			return false
		end,
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
	})

	local dss = service("DataStoreService")
	rawset(dss, "_methods", {
		GetDataStore = function(_self, name)
			local bucket = world.datastore[name]
			if not bucket then
				bucket = {}
				world.datastore[name] = bucket
			end
			return {
				UpdateAsync = function(_store, key, transform)
					-- Real UpdateAsync yields. Two writers can overlap.
					-- Roblox also spaces writes to one key about 6 s apart and
					-- queues the extra ones, so a busy key makes the caller wait.
					local full = name .. "/" .. key
					local stats = world.storeStats
					stats.calls += 1
					table.insert(stats.times, world.clock)
					local last = stats.lastWrite[full]
					local queued = 0
					if last and world.clock - last < world.keyGap then
						queued = last + world.keyGap - world.clock
						stats.queued += 1
						stats.maxQueue = math.max(stats.maxQueue, queued)
					end
					stats.lastWrite[full] = math.max(world.clock, (last or -1e9) + world.keyGap)
					world:wait(queued + world.storeLatency)
					world.storeCalls = (world.storeCalls or 0) + 1
					if world.storeFailures > 0 then
						world.storeFailures -= 1
						error("DataStore request was throttled (simulated)")
					end
					local current = deepCopy(bucket[key])
					local nextValue = transform(current)
					if nextValue == nil then
						return nil
					end
					bucket[key] = deepCopy(nextValue)
					return deepCopy(nextValue)
				end,
			}
		end,
	})

	local mps = service("MarketplaceService")
	rawset(mps, "_methods", {
		PromptProductPurchase = function(_self, player, id)
			table.insert(world.prompts, { kind = "product", user = player.UserId, id = id, at = world.clock })
		end,
		PromptGamePassPurchase = function(_self, player, id)
			table.insert(world.prompts, { kind = "pass", user = player.UserId, id = id, at = world.clock })
		end,
		UserOwnsGamePassAsync = function(_self, _userId, _id)
			world:wait(0.05)
			return false
		end,
		PromptGamePassPurchaseFinished = newSignal(self),
		PromptProductPurchaseFinished = newSignal(self),
	})
	self.marketplace = mps

	local policy = service("PolicyService")
	rawset(policy, "_methods", {
		ArePaidRandomItemsRestricted = function(_self, player)
			world:wait(0.05)
			return world.policy[player.UserId] == true
		end,
		GetPolicyInfoForPlayerAsync = function(_self, player)
			world:wait(0.05)
			return { ArePaidRandomItemsRestricted = world.policy[player.UserId] == true }
		end,
	})

	local analytics = service("AnalyticsService")
	rawset(analytics, "_methods", {
		LogFunnelStepEvent = function(_self, player, funnel, session, step, name)
			table.insert(world.analytics, {
				kind = "funnel",
				user = player.UserId,
				args = { funnel, session, step, name },
			})
		end,
		LogCustomEvent = function(_self, player, name, value)
			table.insert(world.analytics, { kind = "custom", user = player.UserId, args = { name, value } })
		end,
	})
	return game
end

------------------------------------------------------------------ module loader

function World:mount(parent, dir: string, skipClient: boolean?)
	for _, entry in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			local folder = self:newInstance("Folder", parent)
			folder.Name = entry
			self:mount(folder, path)
		elseif string.sub(entry, -5) == ".luau" then
			local className = "ModuleScript"
			local name = string.sub(entry, 1, -6)
			if string.sub(name, -7) == ".server" then
				className = "Script"
				name = string.sub(name, 1, -8)
			elseif string.sub(name, -7) == ".client" then
				className = "LocalScript"
				name = string.sub(name, 1, -8)
			end
			local inst = self:newInstance(className, parent)
			inst.Name = name
			rawset(inst, "_path", path)
			-- Read now, on the main thread. fs.readFile yields to Lune's own
			-- scheduler, which would look like a stray yield inside a server thread.
			rawset(inst, "_source", fs.readFile(path))
		end
	end
end

function World:envFor(script)
	local world = self
	local env = {}
	local virtualOs = table.clone(os)
	virtualOs.clock = function()
		return world.clock
	end
	virtualOs.time = function(t)
		if t ~= nil then
			return os.time(t)
		end
		return math.floor(world.unix0 + world.clock)
	end
	local virtualTask = {
		wait = function(n)
			return world:wait(n)
		end,
		spawn = function(fn, ...)
			return world:spawn("task.spawn", fn, ...)
		end,
		defer = function(fn, ...)
			local args = table.pack(...)
			local co = coroutine.create(fn)
			table.insert(world.sleeping, { co = co, at = world.clock, start = world.clock })
			-- Arguments are dropped for deferred threads here. Callers pass none.
			return co
		end,
		delay = function(n, fn, ...)
			local args = table.pack(...)
			return world:spawn("task.delay", function()
				world:wait(n)
				fn(table.unpack(args, 1, args.n))
			end)
		end,
		cancel = function(co)
			for i, item in ipairs(world.sleeping) do
				if item.co == co then
					table.remove(world.sleeping, i)
					break
				end
			end
		end,
	}
	local function envTypeof(v)
		if isInstance(v) then
			return "Instance"
		end
		return typeof(v)
	end
	local function envPcall(fn, ...)
		local result = table.pack(pcall(fn, ...))
		if not result[1] then
			world:note("pcall", tostring(result[2]))
		end
		return table.unpack(result, 1, result.n)
	end
	local function envXpcall(fn, handler, ...)
		return xpcall(fn, function(err)
			world:note("pcall", tostring(err))
			return handler(err)
		end, ...)
	end
	env.game = self.game
	env.Game = self.game
	env.workspace = self.workspace
	env.script = script
	env.task = virtualTask
	env.os = virtualOs
	env.typeof = envTypeof
	env.pcall = envPcall
	env.xpcall = envXpcall
	env.wait = virtualTask.wait
	env.tick = function()
		return world.unix0 + world.clock
	end
	env.time = function()
		return world.clock
	end
	env.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			table.insert(parts, tostring((select(i, ...))))
		end
		world:note("warn", table.concat(parts, " "))
	end
	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			table.insert(parts, tostring((select(i, ...))))
		end
		world:note("print", table.concat(parts, " "))
	end
	env.Instance = {
		new = function(className, parent)
			return world:newInstance(className, parent)
		end,
	}
	env.Vector3 = roblox.Vector3
	env.Vector2 = roblox.Vector2
	env.CFrame = roblox.CFrame
	env.Color3 = roblox.Color3
	env.UDim = roblox.UDim
	env.UDim2 = roblox.UDim2
	env.Enum = roblox.Enum
	env.BrickColor = roblox.BrickColor
	env.NumberSequence = roblox.NumberSequence
	env.ColorSequence = roblox.ColorSequence
	env.NumberRange = roblox.NumberRange
	env.Random = roblox.Random
	env.require = function(target)
		return world:require(target, script)
	end
	return setmetatable(env, { __index = _G })
end

function World:require(target, fromScript)
	if type(target) == "string" then
		-- The Lune fallback path inside shared modules. Resolve against the caller.
		local base = rawget(fromScript, "_path")
		local dir = string.match(base, "^(.*)/[^/]+$")
		local rel = target
		local node = fromScript.Parent
		while string.sub(rel, 1, 3) == "../" do
			node = node.Parent
			rel = string.sub(rel, 4)
			dir = string.match(dir, "^(.*)/[^/]+$")
		end
		rel = string.gsub(rel, "^%./", "")
		local found = node:FindFirstChild(rel)
		if found then
			return self:require(found, fromScript)
		end
		error("string require not found: " .. target .. " from " .. tostring(base))
	end
	if not isInstance(target) then
		error("Attempted to call require with invalid argument(s).")
	end
	local cached = self.moduleCache[target]
	if cached then
		return cached.value
	end
	local path = rawget(target, "_path")
	if not path then
		error("require: " .. target:GetFullName() .. " has no source")
	end
	local source = rawget(target, "_source")
	local chunk = luau.load(source, {
		debugName = path,
		environment = self:envFor(target),
	})
	local value = chunk()
	self.moduleCache[target] = { value = value }
	return value
end

function World:runScript(script)
	local path = rawget(script, "_path")
	local source = rawget(script, "_source")
	local chunk = luau.load(source, { debugName = path, environment = self:envFor(script) })
	self:spawn(path, chunk)
end

-- Builds the same tree as default.project.json (server side only) and starts Main.
function World:boot()
	local game = self:buildGame()
	local rs = game:GetService("ReplicatedStorage")
	local shared = self:newInstance("Folder", rs)
	shared.Name = "Shared"
	self:mount(shared, self.root .. "/src/shared")
	local sss = game:GetService("ServerScriptService")
	local server = self:newInstance("Folder", sss)
	server.Name = "Server"
	self:mount(server, self.root .. "/src/server")
	self.shared = shared
	self.server = server
	-- Keep a handle on the server ctx so the harness can read ballots and saves.
	local boot = self:require(server:FindFirstChild("Boot"), server:FindFirstChild("Main"))
	local run = boot.run
	boot.run = function(ctx, ...)
		self.ctx = ctx
		return run(ctx, ...)
	end
	self:runScript(server:FindFirstChild("Main"))
	self:runDue()
	return self
end

------------------------------------------------------------------ players

function World:addPlayer(name: string, displayName: string?, userId: number?)
	self.nextUserId += 1
	local player = self:newInstance("Player")
	player.Name = name
	player.DisplayName = displayName or name
	player.UserId = userId or self.nextUserId
	player.AccountAge = 30
	rawset(player, "_methods", {
		Kick = function(p, msg)
			self:note("warn", "kick " .. tostring(p.Name) .. ": " .. tostring(msg))
			self:removePlayer(p)
		end,
	})
	player.Parent = self.players
	self.players.PlayerAdded:Fire(player)
	self:runDue()
	return player
end

function World:removePlayer(player)
	if player.Parent == nil then
		return
	end
	self.players.PlayerRemoving:Fire(player)
	player.Parent = nil
	self:runDue()
end

-- Calls the one client remote the way a LocalScript would, from a new thread.
-- A handler that yields (a save, a policy check) finishes later; onDone gets the payload.
function World:invoke(player, action, a, b, c, onDone)
	local remotes = self.game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("Action")
	local handler = remote and remote.OnServerInvoke
	if type(handler) ~= "function" then
		return nil, "no handler"
	end
	local result = nil
	local finished = false
	local started = self.clock
	self:spawn("invoke " .. tostring(action), function()
		local ok, payload = pcall(handler, player, action, a, b, c)
		if not ok then
			self:note("error", "OnServerInvoke " .. tostring(action) .. ": " .. tostring(payload))
			payload = nil
		end
		result = payload
		finished = true
		if onDone then
			onDone(payload, self.clock - started)
		end
	end)
	return result, if finished then "done" else "pending"
end

function World:step(dt: number)
	self.clock += dt
	self:runDue()
	self.heartbeat:Fire(dt)
	self:runDue()
end

function World:shutdown()
	for _, fn in ipairs(self.bindToClose) do
		local co = self:spawn("BindToClose", fn)
		local guard = 0
		while coroutine.status(co) ~= "dead" and guard < 400 do
			guard += 1
			self.clock += 0.1
			self:runDue()
		end
	end
end

return World
