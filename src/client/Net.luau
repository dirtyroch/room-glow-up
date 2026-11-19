--!strict
-- Client networking. One RemoteFunction. The round itself arrives as attributes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Net = {}

local action: RemoteFunction? = nil

local function ensure(): boolean
	if action then
		return true
	end
	local folder = ReplicatedStorage:FindFirstChild(Config.Names.Remotes)
	if not folder then
		return false
	end
	local remote = folder:FindFirstChild(Config.Names.Action)
	if not remote or not remote:IsA("RemoteFunction") then
		return false
	end
	action = remote
	return true
end

function Net.ready(): boolean
	return ensure()
end

function Net.act(name: string, a: any?, b: any?, c: any?): (boolean, string?)
	if not ensure() or not action then
		return false, "Still connecting."
	end
	local fn = action :: RemoteFunction
	local ok, res = pcall(function()
		return fn:InvokeServer(name, a, b, c)
	end)
	if not ok or type(res) ~= "table" then
		return false, "Connection hiccup. Try again."
	end
	local result = res :: { ok: boolean?, msg: string? }
	return result.ok == true, result.msg
end

ensure()
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == Config.Names.Remotes then
		ensure()
	end
end)

return Net
