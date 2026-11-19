--!strict
-- Server entry. Builds the one action remote and the round-state folder,
-- then starts the round. The server does not make web requests.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Boot = require(script.Parent:WaitForChild("Boot"))
local Services = script.Parent:WaitForChild("Services")

local remotes = Instance.new("Folder")
remotes.Name = Config.Names.Remotes
local action = Instance.new("RemoteFunction")
action.Name = Config.Names.Action
action.Parent = remotes
remotes.Parent = ReplicatedStorage

local roundFolder = Instance.new("Folder")
roundFolder.Name = Config.Names.RoundState
roundFolder.Parent = ReplicatedStorage

local ctx = {
	Round = require(Services:WaitForChild("RoundService")),
	Action = require(Services:WaitForChild("ActionService")),
	RoundFolder = roundFolder,
	ActionRemote = action,
}

-- The remote is hooked before players are accepted, and both inits finish
-- before either start runs.
Boot.run(ctx, { "Round", "Action" }, { "Action", "Round" })
print("[Room Glow Up] server ready, cap " .. tostring(Config.MaxPlayers))
