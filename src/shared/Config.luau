--!strict
-- Shared knobs for Room Glow Up. Phase lengths, the season switch, and the
-- server size live here so the round engine and the tests read one source.
--
-- Season "auto" is Holiday Season through 31 Dec 2026 (UTC) and Winter after
-- that. Set Season to "holiday" or "winter" to force a list, including the
-- private-server hook that later PRs will wire up.

local Config = {
	GameName = "Room Glow Up",
	SeasonTitle = "Holiday Season",
	-- Family servers: Mike, his wife, and siblings, with room to spare.
	MaxPlayers = 10,
	-- Auntie Roch always adds one vote, so a solo round can still be scored.
	MinPlayers = 1,
	Season = "auto",
	RecentThemes = 10,
	-- Scoring itself arrives in a later PR. The range is fixed now: 1 to 5, never random.
	Stars = {
		min = 1,
		max = 5,
	},
	Critic = {
		id = "auntie-roch",
		name = "Auntie Roch",
	},
	Phases = {
		Lobby = 20,
		ThemeReveal = 5,
		Build = 240,
		TourPerRoom = 8,
		Results = 15,
	},
	-- Holiday rounds walk this list. A season that lacks a type (Winter has no
	-- gingerbread) skips that slot and uses the next type that has themes.
	RoundTypeOrder = { "room", "gingerbread", "tree" },
	-- Token buckets, same shape as Cookout: one global bucket and one per action.
	RateLimit = {
		globalBurst = 25,
		globalRefill = 12,
		actionBurst = 6,
		actionRefill = 3,
		maxActionLength = 24,
	},
	Names = {
		Remotes = "Remotes",
		Action = "Action",
		RoundState = "RoundState",
	},
}

return Config
