-- Pure progression rules: levels, round rewards, achievements, daily quests, daily reward.

local Config = require(script.Parent.Config)

local Progression = {}

local P = Config.Progression
local E = Config.Economy

function Progression.xpToNext(level: number): number
	return P.XpBase + P.XpPerLevel * (level - 1)
end

-- Adds xp; returns newLevel, newXp, levelsGained.
function Progression.addXp(level: number, xp: number, gained: number): (number, number, number)
	xp += math.max(0, math.floor(gained))
	local start = level
	while level < P.MaxLevel and xp >= Progression.xpToNext(level) do
		xp -= Progression.xpToNext(level)
		level += 1
	end
	if level >= P.MaxLevel then
		level = P.MaxLevel
		xp = math.min(xp, Progression.xpToNext(level))
	end
	return level, xp, level - start
end

-- result: { percent, rank, kills, participants }; multiplier >= 1 (passes).
function Progression.roundRewards(result, multiplier: number): (number, number)
	local percent = math.clamp(result.percent or 0, 0, 100)
	local coins = E.BaseCoins + percent * E.CoinsPerPercent + (result.kills or 0) * E.CoinsPerKill
	if (result.participants or 0) >= Config.Match.WinMinParticipants then
		coins += E.PlacementCoins[result.rank] or 0
	end
	local xp = E.BaseXp + percent * E.XpPerPercent + (result.kills or 0) * E.XpPerKill
	return math.floor(coins * math.max(1, multiplier)), math.floor(xp)
end

function Progression.coinMultiplier(passes: { [string]: boolean }): number
	local m = 1
	if passes.VIP then
		m += E.VipCoinBonus
	end
	if passes.DoubleCoins then
		m += E.DoubleCoinsBonus
	end
	return m
end

-- Achievements: check(data) -> boolean, evaluated against lifetime stats.
Progression.Achievements = {
	{ id = "first_loop", name = "First Loop", desc = "Close your first loop.", coins = 50, check = function(d)
		return d.stats.captures >= 1
	end },
	{ id = "big_loop", name = "Big Loop", desc = "Claim 100+ tiles with one loop.", coins = 150, check = function(d)
		return d.stats.bestLoop >= 100
	end },
	{ id = "first_win", name = "Champion", desc = "Win a round.", coins = 200, check = function(d)
		return d.stats.wins >= 1
	end },
	{ id = "trail_cutter", name = "Trail Snapper", desc = "Cut 10 rival trails.", coins = 200, check = function(d)
		return d.stats.kills >= 10
	end },
	{ id = "veteran", name = "Veteran", desc = "Play 50 rounds.", coins = 300, check = function(d)
		return d.stats.rounds >= 50
	end },
	{ id = "land_baron", name = "Land Baron", desc = "Claim 10,000 tiles in total.", coins = 500, check = function(d)
		return d.stats.tilesClaimed >= 10000
	end },
	{ id = "conqueror", name = "Conqueror", desc = "Own 40% of the map at once.", coins = 400, check = function(d)
		return d.stats.bestPercent >= 40
	end },
}

-- Returns achievements newly satisfied by data (does not mutate).
function Progression.newAchievements(data): { any }
	local out = {}
	for _, a in Progression.Achievements do
		if data.achievements[a.id] == nil and a.check(data) then
			out[#out + 1] = a
		end
	end
	return out
end

-- Daily quest pool. kind matches the progress events the server emits.
Progression.QuestPool = {
	{ id = "claim_400", kind = "tiles", goal = 400, coins = 60, xp = 80, text = "Claim 400 tiles" },
	{ id = "claim_1200", kind = "tiles", goal = 1200, coins = 120, xp = 150, text = "Claim 1,200 tiles" },
	{ id = "cut_2", kind = "kills", goal = 2, coins = 70, xp = 90, text = "Cut 2 rival trails" },
	{ id = "cut_5", kind = "kills", goal = 5, coins = 140, xp = 160, text = "Cut 5 rival trails" },
	{ id = "top3_1", kind = "top3", goal = 1, coins = 80, xp = 100, text = "Finish in the top 3" },
	{ id = "top3_3", kind = "top3", goal = 3, coins = 150, xp = 180, text = "Finish in the top 3 three times" },
	{ id = "rounds_3", kind = "rounds", goal = 3, coins = 60, xp = 80, text = "Play 3 rounds" },
	{ id = "bigloop_50", kind = "bigloop", goal = 1, coins = 100, xp = 120, text = "Claim 50+ tiles in one loop" },
	{ id = "powerups_4", kind = "powerups", goal = 4, coins = 60, xp = 80, text = "Grab 4 power-ups" },
	{ id = "win_1", kind = "wins", goal = 1, coins = 160, xp = 200, text = "Win a round" },
}

local questById = {}
for _, q in Progression.QuestPool do
	questById[q.id] = q
end

function Progression.quest(id: string)
	return questById[id]
end

-- Deterministic 3 quests of different kinds for a UTC day number.
function Progression.questsForDay(day: number): { string }
	local seed = (day * 1103515245 + 12345) % 2147483648
	local picked, kinds = {}, {}
	local pool = Progression.QuestPool
	local guard = 0
	while #picked < 3 and guard < 200 do
		guard += 1
		seed = (seed * 1103515245 + 12345) % 2147483648
		local q = pool[seed % #pool + 1]
		if not kinds[q.kind] then
			kinds[q.kind] = true
			picked[#picked + 1] = q.id
		end
	end
	return picked
end

function Progression.dayNumber(unixTime: number): number
	return unixTime // 86400
end

-- Daily reward: claimable once per UTC day. Missing days never resets progress (no streak pressure).
function Progression.dailyStatus(daily, today: number): (boolean, number, number)
	local canClaim = daily.lastDay < today
	local step = daily.step % #E.DailyRewards + 1
	return canClaim, step, E.DailyRewards[step]
end

return Progression
