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
	RateLimit = {
		globalBurst = 25,
		globalRefill = 12,
		actionBurst = 6,
		actionRefill = 3,
		nameMax = 24,
	},
}

return Config
