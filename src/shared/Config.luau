--!strict
-- Shared knobs for the round loop. Later PRs (rooms, voting, the shop) read these
-- instead of hard-coding timings.

local Config = {
	Title = "Room Glow Up",
	SeasonTitle = "Holiday Season",
	-- Place cap. A family server: one household plus a few siblings.
	MaxPlayers = 10,
	-- Solo play is allowed. Auntie Roch still adds one vote, so a single builder has a critic.
	MinPlayers = 1,
	-- Central time, so "after Dec 31" flips at local midnight rather than UTC.
	TimezoneOffsetHours = -6,
	-- "holiday" | "winter" | "auto". auto is Holiday Season through Dec 31, then winter.
	Season = "auto",
	RecentThemes = 10,
	Phases = {
		Lobby = 20,
		ThemeReveal = 5,
		Build = 240,
		TourPerRoom = 8,
		Results = 15,
	},
	PhaseOrder = { "Lobby", "ThemeReveal", "Build", "Tour", "Results" },
	PhaseLabels = {
		Lobby = "Lobby",
		ThemeReveal = "Theme",
		Build = "Build",
		Tour = "Tour",
		Results = "Results",
	},
	-- Holiday rounds cycle these in order. Winter does not force a cycle.
	RoundTypeOrder = { "room", "gingerbread", "tree" },
	RoundTypeLabels = {
		room = "Room",
		gingerbread = "Gingerbread",
		tree = "Tree",
	},
	SeasonLabels = {
		holiday = "Holiday Season",
		winter = "Winter",
	},
	Critic = {
		id = "auntie-roch",
		name = "Auntie Roch",
		line = "Auntie Roch adds one vote.",
	},
	-- Token buckets for the single action remote. Keyed per player on the server.
	-- Place has its own wider bucket. The shared action bucket (6, then 3 per
	-- second) is too tight for tapping props onto a grid.
	RateLimit = {
		globalBurst = 25,
		globalRefill = 12,
		actionBurst = 6,
		actionRefill = 3,
		placeBurst = 16,
		placeRefill = 8,
		nameMax = 24,
	},
	-- One plot per player. The place cap is the same number.
	Plots = 10,
	-- Phone-readable prop scale. Grid cells are Cell * ItemScale studs.
	Cell = 4,
	ItemScale = 1.2,
	-- Hard cap so 10 rooms stay cheap. The coin budget usually binds first.
	MaxItems = 16,
	-- Spent during Build. The server is the only one that subtracts from it.
	Budget = 96,
	-- Theme Match. An item tagged with this round's theme scores Exact.
	-- An item tagged only with the round type scores Family. The meter stops at Cap.
	MatchExact = 16,
	MatchFamily = 8,
	MatchCap = 100,
	-- Recolor uses these names only. They match the UI kit palette.
	Palette = { "cream", "coral", "mint", "butter", "lavender" },
	UndoCap = 24,
}

return Config
