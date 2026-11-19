--!strict
-- Builds chunky, rounded controls from the shared UI kit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared:WaitForChild("UIKit") :: ModuleScript) :: any

local UI = {}
UI.kit = UIKit

function UI.rgb(name: string): Color3
	local c = UIKit.color(name)
	return Color3.fromRGB(c[1], c[2], c[3])
end

function UI.face(): Enum.Font
	local named = (Enum.Font :: any)[UIKit.Typeface]
	if typeof(named) == "EnumItem" then
		return named :: Enum.Font
	end
	return Enum.Font.GothamBold
end

function UI.corner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function UI.stroke(parent: Instance, colorName: string, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.rgb(colorName)
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UI.pad(parent: Instance, px: number): UIPadding
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, px)
	pad.PaddingBottom = UDim.new(0, px)
	pad.PaddingLeft = UDim.new(0, px)
	pad.PaddingRight = UDim.new(0, px)
	pad.Parent = parent
	return pad
end

function UI.label(parent: Instance, text: string, textSize: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = UI.face()
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = UI.rgb("ink")
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = UDim2.new(1, 0, 0, height)
	label.Parent = parent
	return label
end

function UI.button(parent: Instance, text: string, styleName: string, onClick: () -> ()): TextButton
	local style = UIKit.Buttons[styleName]
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Font = UI.face()
	button.Text = text
	button.TextSize = style.textSize
	button.TextColor3 = UI.rgb(style.text)
	button.BackgroundColor3 = UI.rgb(style.fill)
	button.Size = UDim2.fromScale(1, 1)
	button.Parent = parent
	UI.corner(button, style.corner)
	UI.stroke(button, style.stroke, style.strokeThickness)
	button.Activated:Connect(onClick)
	return button
end

function UI.pop(scale: UIScale, motion: { from: number, to: number, time: number, style: string })
	scale.Scale = motion.from
	local easing = if motion.style == "Back" then Enum.EasingStyle.Back else Enum.EasingStyle.Quad
	local info = TweenInfo.new(motion.time, easing, Enum.EasingDirection.Out)
	TweenService:Create(scale, info, { Scale = motion.to }):Play()
end

return UI
