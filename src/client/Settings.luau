--!strict
-- Mute, volume, and low-end. Local only. Effects read these attributes.

local Players = game:GetService("Players")

local UI = require(script.Parent.UI)

local Settings = {}

function Settings.start()
	local player = Players.LocalPlayer
	local gui = UI.screen(player:WaitForChild("PlayerGui"), "GlowSettings", 12)

	if player:GetAttribute("Volume") == nil then
		player:SetAttribute("Volume", 1)
	end
	if player:GetAttribute("LowEnd") == nil then
		player:SetAttribute("LowEnd", "auto")
	end

	local mute = Instance.new("TextButton")
	mute.Name = "Mute"
	mute.AnchorPoint = Vector2.new(0, 0)
	mute.Position = UDim2.fromOffset(16, 8)
	mute.Size = UDim2.fromOffset(118, 44)
	mute.BackgroundColor3 = UI.rgb("lavender")
	mute.Font = UI.face()
	mute.TextSize = UI.kit.Text.body
	mute.TextColor3 = UI.rgb("ink")
	mute.Text = "Sound"
	mute.ZIndex = 8
	mute.Parent = gui
	UI.corner(mute, 20)
	UI.stroke(mute, "ink", 2)

	local low = Instance.new("TextButton")
	low.Name = "LowEnd"
	low.AnchorPoint = Vector2.new(0, 0)
	low.Position = UDim2.fromOffset(142, 8)
	low.Size = UDim2.fromOffset(124, 44)
	low.BackgroundColor3 = UI.rgb("mint")
	low.Font = UI.face()
	low.TextSize = UI.kit.Text.body
	low.TextColor3 = UI.rgb("ink")
	low.Text = "Low-end"
	low.ZIndex = 8
	low.Parent = gui
	UI.corner(low, 20)
	UI.stroke(low, "ink", 2)

	local function paint()
		local muted = player:GetAttribute("Muted") == true
		local note = UI.kit.Icons.note
		mute.Text = if muted then note .. " Off" else note .. " On"
		local mode = player:GetAttribute("LowEnd")
		if mode == "on" then
			low.Text = "Low-end"
		elseif mode == "off" then
			low.Text = "Full"
		else
			low.Text = "Auto"
		end
	end

	mute.Activated:Connect(function()
		local muted = player:GetAttribute("Muted") == true
		player:SetAttribute("Muted", not muted)
		paint()
	end)

	low.Activated:Connect(function()
		local mode = player:GetAttribute("LowEnd")
		if mode == "auto" then
			player:SetAttribute("LowEnd", "on")
		elseif mode == "on" then
			player:SetAttribute("LowEnd", "off")
		else
			player:SetAttribute("LowEnd", "auto")
		end
		paint()
	end)

	paint()
end

return Settings
