-- Central tuning for Chroma Turf. Every gameplay, economy and store number lives here.
-- Values marked HYPOTHESIS are launch guesses that must be validated with analytics.

local Config = {}

Config.GameName = "Chroma Turf"
Config.Version = "1.0.0"

Config.Grid = {
	Size = 40, -- cells per side (1600 cells)
	TileSize = 6, -- studs per cell
	FloorY = 0, -- world Y of the arena floor top
}
Config.Grid.Extent = Config.Grid.Size * Config.Grid.TileSize -- 240 studs
Config.Grid.OriginX = -Config.Grid.Extent / 2
Config.Grid.OriginZ = -Config.Grid.Extent / 2

Config.Match = {
	TickRate = 10, -- server simulation ticks per second
	RoundSeconds = 180,
	IntermissionSeconds = 15,
	RespawnSeconds = 3,
	SpawnRadius = 2, -- start zone is (2r+1)^2 = 25 cells
	MinParticipants = 6, -- bots fill the round up to this many
	MaxBots = 6,
	TrailGrace = 2, -- newest trail cells that never self-cut (tile-boundary jitter)
	MaxPaintHeight = 14, -- studs above floor; higher than this does not paint
	SpeedTolerance = 1.6, -- allowed multiple of expected speed before a tick is ignored
	SpeedSlack = 10, -- studs/s of extra slack for physics/lag
	WinMinParticipants = 3, -- a win only counts with at least this many participants
	HubPosition = { 0, 0, -205 }, -- x, y, z of the hub platform centre
}

Config.Movement = {
	WalkSpeed = 22,
	DashMultiplier = 1.5,
	BotSpeed = 18,
}

Config.Powerups = {
	MaxActive = 4,
	SpawnInterval = 9,
	PickupRadius = 5,
	Dash = { duration = 3.5 },
	Shield = { duration = 6 },
	Bomb = { radius = 2 },
}

-- HYPOTHESIS: one round ~ 40-70 coins; an average cosmetic ~ 1 hour of play.
Config.Economy = {
	BaseCoins = 10,
	CoinsPerPercent = 1.5,
	CoinsPerKill = 5,
	PlacementCoins = { 30, 20, 10 },
	BaseXp = 50,
	XpPerPercent = 2,
	XpPerKill = 10,
	VipCoinBonus = 0.25,
	DoubleCoinsBonus = 1.0,
	MaxCoins = 100000000,
	DailyRewards = { 50, 75, 100, 125, 150, 200, 400 },
}

Config.Progression = {
	MaxLevel = 100,
	XpBase = 100,
	XpPerLevel = 40,
	LevelUpCoins = 25,
}

-- Roblox Creator Hub IDs. 0 = not configured yet: the store shows the item as unavailable
-- and never prompts. See docs/EXTERNAL_SETUP.md.
Config.Monetization = {
	GamePasses = {
		VIP = { id = 0, price = 199, name = "VIP", description = "Gold name, VIP title, Royal Gold ink and +25% coins." },
		DoubleCoins = { id = 0, price = 299, name = "Double Coins", description = "Earn 2x coins from every round, forever." },
		PrismPack = { id = 0, price = 149, name = "Prism Pack", description = "Rainbow Prism trail and the Prismatic title." },
	},
	-- HYPOTHESIS prices; the store always displays the live Roblox price when available.
	Products = {
		CoinsSmall = { id = 0, price = 49, coins = 500, name = "Pocket of Coins" },
		CoinsMedium = { id = 0, price = 99, coins = 1200, name = "Bag of Coins" },
		CoinsLarge = { id = 0, price = 249, coins = 3500, name = "Chest of Coins" },
		CoinsHuge = { id = 0, price = 499, coins = 8000, name = "Vault of Coins" },
	},
}

-- Optional Roblox badges awarded alongside in-game achievements (0 = disabled).
Config.Badges = {
	first_loop = 0,
	big_loop = 0,
	first_win = 0,
	trail_cutter = 0,
	land_baron = 0,
}

-- Built-in client sounds so the game has feedback with zero uploads.
-- Replace with uploaded original SFX ("rbxassetid://...") before launch; see KNOWN_ISSUES.md.
Config.Audio = {
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Capture = "rbxasset://sounds/electronicpingshort.wav",
	Splat = "rbxasset://sounds/uuhhh.mp3",
	Pickup = "rbxasset://sounds/electronicpingshort.wav",
	RoundStart = "rbxasset://sounds/electronicpingshort.wav",
	Music = "", -- empty: no music until an original track is uploaded
}

Config.Data = {
	StoreName = "ChromaTurf_Profiles_v1",
	LeaderboardStore = "ChromaTurf_Wins_v1",
	AutosaveSeconds = 90,
	LockStaleSeconds = 600, -- a session lock older than this is considered abandoned
	LoadAttempts = 8,
	LoadRetryDelay = 3,
	MaxReceiptHistory = 60,
}

Config.RateLimits = {
	Request = { capacity = 10, refillPerSecond = 4 },
	ClientEvent = { capacity = 20, refillPerSecond = 5 },
}

return Config
