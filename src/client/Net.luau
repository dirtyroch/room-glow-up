--!strict
-- Client side of the one action remote. The server decides what actually happens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}
local action: RemoteFunction? = nil

local function remote(): RemoteFunction?
	if action then
		return action
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		return nil
	end
	local found = folder:FindFirstChild("Action")
	if found and found:IsA("RemoteFunction") then
		action = found
		return found
	end
	return nil
end

function Net.act(name: string, a: any?, b: any?, c: any?): (boolean, string?)
	local fn = remote()
	if not fn then
		return false, "Still connecting."
	end
	local ok, res = pcall(function()
		return fn:InvokeServer(name, a, b, c)
	end)
	if not ok or type(res) ~= "table" then
		return false, "Try again."
	end
	local msg = if type(res.msg) == "string" then res.msg else nil
	return res.ok == true, msg
end

return Net
