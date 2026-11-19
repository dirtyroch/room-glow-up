--!strict
-- Server entry. One RemoteFunction for client requests. Round state is replicated
-- with attributes so a late joiner still sees the phase and the time left.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boot = require(script.Parent.Boot)
local Services = script.Parent:WaitForChild("Services")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local action = Instance.new("RemoteFunction")
action.Name = "Action"
action.Parent = remotes
remotes.Parent = ReplicatedStorage

local roundState = Instance.new("Folder")
roundState.Name = "RoundState"
roundState.Parent = ReplicatedStorage

local ctx = {
	Remotes = { Action = action },
	RoundState = roundState,
	Actions = require(Services:WaitForChild("ActionService")),
	Round = require(Services:WaitForChild("RoundService")),
}

Boot.run(ctx, { "Actions", "Round" }, { "Actions", "Round" })
print("[Room Glow Up] server ready")
