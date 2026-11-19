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
		boardHeight = 188,
		boardShort = 128,
		countdownHeight = 72,
		revealHeight = 116,
		revealShort = 80,
		minButton = 64,
		-- Below this height the board, reveal, meter, tray, and DONE button use
		-- the compact sizes. 520px phones are inside this range.
		compactBelow = 680,
		trayHeight = 172,
		trayShort = 120,
		meterHeight = 44,
		meterShort = 40,
		stackGap = 8,
		minGap = 4,
		minBoard = 112,
		minReveal = 64,
		minTray = 96,
		minMeter = 32,
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
		-- Props pop in from a small scale. The client tween reads these numbers.
		place = { from = 0.25, to = 1, time = 0.22, style = "Back" },
		-- Tour spotlight brightens when a room is revealed, then eases for lock-in.
		spotlight = { from = 0, to = 6, time = 0.45, style = "Quad" },
		lock = { from = 6, to = 2.2, time = 0.3, style = "Quad" },
		crowd = { from = 0.4, to = 1, time = 0.28, style = "Back" },
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

export type Band = { top: number, bottom: number }
export type Bands = {
	board: Band,
	reveal: Band,
	meter: Band,
	tray: Band,
	done: Band,
}

local function shrink(current: number, minimum: number, overflow: number): (number, number)
	local room = current - minimum
	if room < 0 then
		room = 0
	end
	local cut = math.min(room, overflow)
	return current - cut, overflow - cut
end

-- Screen bands for the HUD. The meter band also holds the coin budget.
-- From 420px up, the tray, meter, and budget stay off the board, the reveal, and DONE.
function UIKit.bands(viewportHeight: number): Bands
	local height = math.floor(viewportHeight)
	if height < 1 then
		height = 1
	end
	local L = UIKit.Layout
	local compact = height < L.compactBelow
	local boardH = if compact then L.boardShort else L.boardHeight
	local revealH = if compact then L.revealShort else L.revealHeight
	local trayH = if compact then L.trayShort else L.trayHeight
	local meterH = if compact then L.meterShort else L.meterHeight
	local doneH = UIKit.Buttons.primary.height
	local gap = L.stackGap

	local function total(): number
		return L.top + boardH + revealH + meterH + trayH + doneH + L.bottom + gap * 4
	end

	local overflow = total() - height
	if overflow < 0 then
		overflow = 0
	end
	trayH, overflow = shrink(trayH, L.minTray, overflow)
	meterH, overflow = shrink(meterH, L.minMeter, overflow)
	revealH, overflow = shrink(revealH, L.minReveal, overflow)
	boardH, overflow = shrink(boardH, L.minBoard, overflow)
	while overflow > 0 and gap > L.minGap do
		gap -= 1
		overflow -= 4
	end

	local boardTop = L.top
	local boardBottom = boardTop + boardH
	local doneBottom = height - L.bottom
	local doneTop = doneBottom - doneH
	local trayBottom = doneTop - gap
	local trayTop = trayBottom - trayH
	local meterBottom = trayTop - gap
	local meterTop = meterBottom - meterH

	local gapTop = boardBottom + gap
	local gapBottom = meterTop - gap
	local room = gapBottom - gapTop
	local revealTop = gapTop
	local revealBottom = gapTop + revealH
	if room > revealH then
		revealTop = gapTop + math.floor((room - revealH) / 2)
		revealBottom = revealTop + revealH
	elseif room < revealH and room > 0 then
		revealBottom = gapBottom
		revealTop = revealBottom - room
	end

	return {
		board = { top = boardTop, bottom = boardBottom },
		reveal = { top = revealTop, bottom = revealBottom },
		meter = { top = meterTop, bottom = meterBottom },
		tray = { top = trayTop, bottom = trayBottom },
		done = { top = doneTop, bottom = doneBottom },
	}
end

return UIKit
