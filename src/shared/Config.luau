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
		-- Each tour stop is this long. The visual lock starts TourLockIn seconds
		-- before the camera moves. Votes stay open for TourVoteGrace after that
		-- lock, so a room has about 10 seconds of voting. Once everyone has
		-- voted the server moves on after TourSkipBeat.
		TourPerRoom = 10,
		TourLockIn = 1,
		TourVoteGrace = 1,
		TourSkipBeat = 1,
		-- Podium and Auntie Roch first. Rewards and Spot the Theme at this second.
		Results = 30,
		ResultsRewardsAt = 10,
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
		-- A player with no submitted room earns a smaller purse, and it stops
		-- at this cap, so decorating stays the better path.
		EyeNoRoomCoins = 2,
		EyeNoRoomCap = 8,
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
		-- Long enough to cover a full 10-player round plus a long lobby sit.
		-- A second server cannot take the lock until this many seconds pass.
		LockSeconds = 1800,
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
		PlaceXp = { 40, 30, 24, 18, 14 },
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
		-- Emoji reactions. A short burst, then a slow refill. No free text.
		reactBurst = 3,
		reactRefill = 1,
		-- Code attempts. A burst, then a slow refill, so guessing cannot spin.
		codeBurst = 4,
		codeRefill = 1,
		nameMax = 24,
	},
	-- One plot per player. The place cap is the same number.
	Plots = 10,
	-- Phone-readable prop scale. Grid cells are Cell * ItemScale studs.
	Cell = 4,
	ItemScale = 1.2,
	-- When this share of the builders who actually placed are done, or everyone
	-- but one of them, the clock drops to FinalSeconds. Idle and empty builders
	-- are not in that count. The server owns the cut.
	BuildRush = {
		Fraction = 0.6,
		FinalSeconds = 30,
		Banner = "30 seconds left!",
		-- No cut before this many build seconds, so early DONE presses
		-- (when nobody else has placed yet) cannot shorten the round.
		MinElapsed = 60,
		-- A DONE only pushes the rush when the room has this many pieces,
		-- or has spent this share of the budget (Tiny Budget rounds).
		MinPieces = 3,
		RealSpend = 0.5,
	},
	-- A kid who drops and comes back within this many seconds of the same
	-- build gets their room back instead of starting over as a spectator.
	Reconnect = {
		Grace = 60,
	},
	-- A late joiner who still has this many build seconds gets a room.
	-- Otherwise they watch, vote, and play a tutorial or a sandbox.
	LateJoin = {
		MinBuild = 60,
	},
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
	-- First-minute Mini Room. The 4-star line is a practice reaction.
	-- It is never written into a ballot, a payout, or a stat.
	Tutorial = {
		Duration = 30,
		PlaceBy = 15,
		ReactionAt = 20,
		Stars = 4,
		ItemId = "dot_rug",
		PhoneHeight = 420,
		HintMin = 88,
		HintText = 32,
		Line = "Oh, this little rug already glows. Four warm stars, just for practice.",
	},
	-- About one round in three. The server picks. Theme Reveal is the announcement.
	Modifiers = {
		Every = 3,
		Order = { "speed", "tiny", "mystery", "mirror" },
		Labels = {
			speed = "Speed Round",
			tiny = "Tiny Budget",
			mystery = "Mystery Item",
			mirror = "Mirror Duo",
		},
		SpeedBuild = 90,
		TinyBudget = 16,
		-- Mystery Item is a free twist. It is not a paid roll.
		Paid = false,
		Mystery = {
			room = { "cocoa_mug", "star_pillow", "dot_rug" },
			gingerbread = { "gumdrop", "peppermint_disc", "icing_drip" },
			tree = { "paper_star", "bell_drop", "wool_pom" },
		},
	},
	-- Skippable results minigame. A few coins. No extra time is sold for it.
	Spot = {
		Coins = 6,
		Choices = 3,
		SellsTime = false,
	},
	Audio = {
		Place = "rbxasset://sounds/electronicpingshort.wav",
		Sting = "rbxasset://sounds/electronicpingshort.wav",
		Rush = "rbxasset://sounds/electronicpingshort.wav",
		Level = "rbxasset://sounds/electronicpingshort.wav",
		Music = "rbxasset://sounds/bass.mp3",
		PlaceVolume = 0.45,
		StingVolume = 0.55,
		LevelVolume = 0.4,
		MusicVolume = 0.18,
		Confetti = 18,
		ConfettiLow = 4,
	},
	-- Free unlocks. Quests or a level, never a crate-only path.
	Easter = {
		PibbleLevel = 5,
		PibbleRugs = 4,
		UncLevel = 8,
		UncSeats = 4,
	},
	-- One catalog. Placeholder ids stay 0 until create-shop fills them in.
	-- An id of 0 never opens a purchase window.
	Shop = {
		ReceiptCap = 48,
		DuplicateCoins = 40,
		LuckBonusCoins = 12,
		TimeBonus = 60,
		TimeCap = 2,
		TimeFallbackCoins = 30,
		RainSeconds = 180,
		DesignDays = 30,
		MaxExtraSlots = 4,
		Materials = { "Wood", "Fabric", "Metal", "Glass", "Slate" },
		Surfaces = { "floor", "wall", "roof", "hook" },
		-- Family Night is free. This list is the only host-theme allowlist.
		HostThemes = {
			"hearth_cocoa",
			"snow_globe_parlor",
			"starlight_nook",
			"gumdrop_gable",
			"paper_star",
			"frosted_window",
			"blanket_fort",
			"quiet_snow_pine",
		},
		Codes = {
			WELCOME = { coins = 80 },
			GLOWUP = { itemId = "sleigh_bell" },
		},
		-- Percents in each list sum to 100. Decor Rain swaps the list, it does not add a second roll.
		Crates = {
			base = {
				{ itemId = "sleigh_bell", percent = 40 },
				{ itemId = "nutcracker_stand", percent = 25 },
				{ itemId = "quilt_square", percent = 18 },
				{ itemId = "carol_piano", percent = 12 },
				{ itemId = "star_lamp", percent = 5 },
			},
			rain = {
				{ itemId = "sleigh_bell", percent = 15 },
				{ itemId = "nutcracker_stand", percent = 20 },
				{ itemId = "quilt_square", percent = 25 },
				{ itemId = "carol_piano", percent = 22 },
				{ itemId = "star_lamp", percent = 18 },
			},
			fallback = { "quilt_square", "sleigh_bell", "nutcracker_stand" },
		},
		Passes = {
			VIP = {
				id = 0,
				name = "VIP",
				price = 399,
				desc = "A butter frame in the lobby, and one extra Dream Home. The frame stays off during the tour.",
				tab = "Passes",
				vip = true,
			},
			DesignerTools = {
				id = 0,
				name = "Designer Tools",
				price = 249,
				desc = "Recolor the floor, wall, roof, and hooks, and set a material on any piece.",
				tab = "Passes",
				tools = true,
			},
			DoubleCoins = {
				id = 0,
				name = "2x Coins",
				price = 199,
				desc = "Contest coins pay double. Buying it again does not raise the multiplier.",
				tab = "Boosts",
				doubleCoins = true,
			},
		},
		Products = {
			StyleHearth = {
				id = 0,
				name = "Hearth Style Pack",
				price = 149,
				desc = "Mantel shelf, nutcracker stand, sleigh bell, and quilt square. Each piece is shown before you buy.",
				tab = "Decor",
				items = { "mantel_shelf", "nutcracker_stand", "sleigh_bell", "quilt_square" },
			},
			StyleGinger = {
				id = 0,
				name = "Gingerbread Style Pack",
				price = 199,
				desc = "Gumdrop cluster, sprinkle chimney cap, licorice twist, and door frame icing. Shown in full before you buy.",
				tab = "Decor",
				items = { "gumdrop_cluster", "chimney_cap", "licorice_twist", "door_icing" },
			},
			StyleWinter = {
				id = 0,
				name = "Winter Style Pack",
				price = 249,
				desc = "Mudroom lantern, pinecone shelf, quilt table, and string lights. Shown in full before you buy.",
				tab = "Decor",
				items = { "mudroom_lantern", "pinecone_shelf", "quilt_table", "string_lights" },
			},
			StyleGlow = {
				id = 0,
				name = "Glow Style Pack",
				price = 299,
				desc = "Star lamp, globe light, glass drop, and ribbon loop. Shown in full before you buy.",
				tab = "Decor",
				items = { "star_lamp", "globe_light", "glass_drop", "ribbon_loop" },
			},
			CarolPiano = {
				id = 0,
				name = "Carol Piano",
				price = 79,
				desc = "Carol Piano. Floor piece, 2 by 1, cream. You see the whole piece before you buy.",
				tab = "Decor",
				itemId = "carol_piano",
			},
			NutcrackerPortrait = {
				id = 0,
				name = "Nutcracker Portrait",
				price = 49,
				desc = "Nutcracker Portrait. Wall hanging, 1 by 1, coral. You see the whole piece before you buy.",
				tab = "Decor",
				itemId = "nutcracker_frame",
			},
			LavenderSettee = {
				id = 0,
				name = "Lavender Settee",
				price = 99,
				desc = "Lavender Settee. Floor seating, 2 by 1, lavender. You see the whole piece before you buy.",
				tab = "Decor",
				itemId = "lavender_settee",
			},
			QuiltTable = {
				id = 0,
				name = "Quilt Table",
				price = 69,
				desc = "Quilt Table. Floor table, 2 by 1, lavender. You see the whole piece before you buy.",
				tab = "Decor",
				itemId = "quilt_table",
			},
			ExtraMinute = {
				id = 0,
				name = "+60 Seconds",
				price = 49,
				desc = "Adds 60 seconds for the whole server. Two per round.",
				tab = "Boosts",
				time = true,
			},
			DecorCrate = {
				id = 0,
				name = "Decor Crate",
				price = 99,
				desc = "A decor piece from the posted odds. The server rolls after the receipt. A duplicate becomes coins.",
				tab = "Decor",
				random = true,
			},
			DecorRain = {
				id = 0,
				name = "Decor Rain",
				price = 129,
				desc = "A short luck event for the whole server. Crate odds and coin drops both change. Your name is announced in the lobby.",
				tab = "Boosts",
				rain = true,
			},
			ThemeHint = {
				id = 0,
				name = "Theme Hint",
				price = 29,
				desc = "Shows which pieces fit this theme. The theme name is still on the board without this.",
				tab = "Boosts",
				hint = true,
			},
			DesignPass = {
				id = 0,
				name = "Design Pass",
				price = 349,
				desc = "30 days of a fixed reward track. It sits beside the level unlocks and does not skip them.",
				tab = "Passes",
				designPass = true,
			},
			DreamNook = {
				id = 0,
				name = "Dream Nook",
				price = 99,
				desc = "One extra Dream Home. The house still holds 36 pieces.",
				tab = "Passes",
				slots = 1,
			},
			DreamWing = {
				id = 0,
				name = "Dream Wing",
				price = 179,
				desc = "Two extra Dream Homes. The house still holds 36 pieces.",
				tab = "Passes",
				slots = 2,
			},
		},
	},
}

return Config
