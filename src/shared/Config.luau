--!strict
-- Shared knobs for the round loop. Timings, the coin budget, votes, and the
-- critic live here so the tour show does not hard-code them.

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
		-- Each tour stop is this long. The last TourLockIn seconds are the
		-- lock-in beat: votes freeze, then the camera moves with the next index.
		TourPerRoom = 10,
		TourLockIn = 2,
		-- Long enough for the podium, then coins, XP, and unlocks.
		Results = 30,
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
		-- Theme Match, item variety, and how full the room is. Weights sum to 1.
		weights = { match = 0.5, variety = 0.25, fill = 0.25 },
		-- One line per star, picked from that band. Same room, same line.
		lines = {
			{
				"A gentle start. A few more theme pieces would sing.",
				"I can see the idea. Let's welcome the theme in.",
				"Sweet bones. The theme still wants a seat.",
			},
			{
				"Getting there. The theme is peeking through.",
				"A kind little room. One more theme piece would help.",
				"Nice start. Fill a corner and it will glow.",
			},
			{
				"A happy room. The theme feels welcome.",
				"This one smiles. I would linger a minute.",
				"Balanced and bright. I like the middle.",
			},
			{
				"Oh, this glows. The theme is right at home.",
				"Lovely variety, and the theme is clear.",
				"I would show this one to the neighbors.",
			},
			{
				"A full glow-up. The theme is everywhere it should be.",
				"This room is ready for the season. Beautiful.",
				"Starlight and care. I am clapping.",
			},
		},
	},
	Voting = {
		MinStars = 1,
		MaxStars = 5,
		-- Drop the highest and lowest star once this many votes are in.
		TrimAt = 5,
		-- Judge's Eye: within this many stars of the final average.
		EyeWindow = 1,
		-- Judge's Eye coins. The server turns these into real coins after Results.
		-- The EyeCoins attribute is a display copy. Payout never reads it.
		EyeCoins = 8,
		-- A room drops after this many different reports, or this share of the
		-- people who can vote, whichever is higher. Half, rounded up.
		ReportMin = 3,
		ReportFraction = 0.5,
		Podium = 3,
	},
	-- Profile saves, levels, and the dream home. The shop reads the hooks later.
	Progress = {
		Schema = 1,
		ProfileStore = "RoomGlowProfile_v1",
		DreamStore = "RoomGlowDream_v1",
		-- A second server cannot take the lock until this many seconds pass.
		LockSeconds = 120,
		PaidCap = 48,
		Lookbook = 3,
		StampStars = 4,
		SetBonusCoins = 40,
		SetBonusXp = 24,
		QuestCoins = 12,
		MaxLevel = 50,
		-- XP to leave level L is XpBase + (L - 1) * XpStep.
		XpBase = 20,
		XpStep = 6,
		DuoScale = 1.5,
		LoftLevel = 15,
		HouseLevel = 30,
		StudioItems = 16,
		LoftItems = 24,
		HouseItems = 36,
		RetrySeconds = { 0.5, 1, 2, 4 },
	},
	-- Granted once per round id. Placement, stars, and the podium each add some.
	Rewards = {
		PlaceCoins = { 36, 24, 18, 12, 8 },
		PlaceXp = { 40, 30, 24, 18, 12 },
		StarCoins = 4,
		StarXp = 6,
		PodiumCoins = { 20, 14, 8 },
		PodiumXp = { 20, 14, 8 },
		EyeRate = 1,
	},
	-- Monthly designer track. Points only rise inside the month.
	RankTrack = {
		{ points = 100, coins = 20 },
		{ points = 250, coins = 30 },
		{ points = 450, coins = 40 },
		{ points = 700, coins = 55 },
		{ points = 1000, coins = 75 },
	},
	-- Reveal show. The client plays these when the server tour attributes change.
	-- Crowd marks are not votes and never enter the average.
	Show = {
		Sting = "rbxasset://sounds/electronicpingshort.wav",
		Crowd = { "👏", "✨", "💛", "🎉", "🌟" },
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
	Budget = 128,
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
