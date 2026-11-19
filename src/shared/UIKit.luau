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
		eyebrow = 18,
		body = 22,
		theme = 26,
		button = 28,
		countdown = 64,
		countdownMin = 32,
		reveal = 32,
		-- Nothing on a phone should sit under this.
		min = 18,
	},
	-- One icon style: filled star, open star, a note, a spark.
	Icons = {
		star = "★",
		starOff = "☆",
		note = "♪",
		spark = "✦",
	},
	Shape = {
		corner = 24,
		cornerChunky = 32,
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
			corner = 32,
			strokeThickness = 3,
		},
		quiet = {
			fill = "lavender",
			text = "ink",
			stroke = "ink",
			height = 60,
			textSize = 22,
			corner = 28,
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

export type ShopFit = {
	top: number,
	bottom: number,
	header: number,
	tabs: number,
	bodyTop: number,
	bodyBottom: number,
	body: number,
	close: number,
}

-- Shop overlay. From 420px tall the tabs, the list, and the close button all fit.
function UIKit.shop(viewportHeight: number): ShopFit
	local height = math.floor(viewportHeight)
	if height < 1 then
		height = 1
	end
	local L = UIKit.Layout
	local top = L.top
	local bottom = height - L.bottom
	local header = 36
	local tabs = 48
	local close = UIKit.Buttons.primary.height
	local bodyTop = top + header + L.stackGap + tabs
	local bodyBottom = bottom - close - L.stackGap
	if bodyBottom < bodyTop then
		bodyBottom = bodyTop
	end
	return {
		top = top,
		bottom = bottom,
		header = header,
		tabs = tabs,
		bodyTop = bodyTop,
		bodyBottom = bodyBottom,
		body = bodyBottom - bodyTop,
		close = close,
	}
end

export type TutorialFit = {
	hint: number,
	hintText: number,
	hintTop: number,
	skip: number,
	reactionTop: number,
	reactionBottom: number,
	coversHint: boolean,
}

-- One big place button on a 420px phone. The reaction card sits above it.
function UIKit.tutorial(viewportHeight: number): TutorialFit
	local height = math.floor(viewportHeight)
	if height < 1 then
		height = 1
	end
	local hint = 96
	if height < 420 then
		hint = 88
	end
	local skip = 56
	local text = 32
	local bottom = 18
	local hintTop = height - bottom - hint
	local reactionTop = 72
	local reactionHeight = 96
	return {
		hint = hint,
		hintText = text,
		hintTop = hintTop,
		skip = skip,
		reactionTop = reactionTop,
		reactionBottom = reactionTop + reactionHeight,
		coversHint = (reactionTop + reactionHeight) > hintTop,
	}
end

export type SpotFit = {
	top: number,
	height: number,
	skip: number,
	podium: number,
	coversNames: boolean,
}

-- Sits under the podium reserve so names stay visible.
function UIKit.spot(viewportHeight: number): SpotFit
	local height = math.floor(viewportHeight)
	if height < 1 then
		height = 1
	end
	local podium = 168
	local panel = 112
	local top = height - 18 - panel
	if top < podium then
		top = podium
	end
	local skip = 48
	if skip > panel - 8 then
		skip = math.max(36, panel - 8)
	end
	return {
		top = top,
		height = panel,
		skip = skip,
		podium = podium,
		coversNames = top < podium,
	}
end

return UIKit
