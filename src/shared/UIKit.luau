--!strict
-- Shared look tokens for Room Glow Up. Later PRs (placement, voting, the shop)
-- should reuse this palette, these sizes, and these button styles.
-- Colors are 0-255 channels so this module loads in tests without a place file.
-- Text on every fill is the dark ink color.

local UIKit = {
	Palette = {
		cream = { 255, 246, 234 },
		coral = { 255, 186, 173 },
		mint = { 186, 232, 206 },
		butter = { 255, 226, 156 },
		lavender = { 214, 201, 235 },
		ink = { 47, 36, 56 },
	},
	-- Phone-readable sizes. The countdown is the largest type on the screen.
	Text = {
		eyebrow = 16,
		body = 22,
		theme = 26,
		button = 28,
		countdown = 64,
		countdownMin = 32,
		reveal = 32,
	},
	Shape = {
		corner = 22,
		cornerChunky = 28,
		stroke = 3,
	},
	-- Thumb reach: the primary button sits along the bottom, inside the safe area.
	Layout = {
		side = 16,
		top = 12,
		bottom = 18,
		boardHeight = 168,
		countdownHeight = 72,
		revealHeight = 116,
		minButton = 64,
	},
	Buttons = {
		primary = {
			fill = "coral",
			text = "ink",
			stroke = "ink",
			height = 64,
			textSize = 28,
			corner = 28,
			strokeThickness = 3,
		},
		quiet = {
			fill = "lavender",
			text = "ink",
			stroke = "ink",
			height = 56,
			textSize = 22,
			corner = 24,
			strokeThickness = 3,
		},
	},
	PhaseFill = {
		Lobby = "lavender",
		ThemeReveal = "butter",
		Build = "coral",
		Tour = "mint",
		Results = "cream",
	},
	-- UIScale pops. The client maps style names onto easing enums.
	Motion = {
		phase = { from = 0.94, to = 1, time = 0.22, style = "Back" },
		reveal = { from = 0.86, to = 1, time = 0.28, style = "Back" },
	},
	Typeface = "FredokaOne",
}

export type Rgb = { number }
export type Motion = { from: number, to: number, time: number, style: string }

local function channel(c: number): number
	local x = c / 255
	if x <= 0.04045 then
		return x / 12.92
	end
	return ((x + 0.055) / 1.055) ^ 2.4
end

function UIKit.luminance(rgb: Rgb): number
	return 0.2126 * channel(rgb[1]) + 0.7152 * channel(rgb[2]) + 0.0722 * channel(rgb[3])
end

-- Contrast ratio between two palette colors (1 = identical).
function UIKit.contrast(a: Rgb, b: Rgb): number
	local la = UIKit.luminance(a)
	local lb = UIKit.luminance(b)
	local hi = math.max(la, lb)
	local lo = math.min(la, lb)
	return (hi + 0.05) / (lo + 0.05)
end

function UIKit.color(name: string): Rgb
	local rgb = UIKit.Palette[name]
	assert(rgb, "unknown color " .. name)
	return rgb
end

return UIKit
