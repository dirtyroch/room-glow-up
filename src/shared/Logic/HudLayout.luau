--!strict
-- Phone layout numbers for the round HUD. The card uses most of a narrow
-- screen, the DONE control sits in the thumb zone, and the touch target
-- stays at least 48px tall.

local HudLayout = {
	topWidthScale = 0.92,
	bottomWidthScale = 0.92,
	maxCardWidth = 520,
	topOffset = 8,
	bottomOffset = 12,
	padding = 12,
	gap = 6,
	minTouchHeight = 48,
	phaseText = 18,
	themeText = 26,
	timerText = 22,
	corner = 16,
}

return HudLayout
