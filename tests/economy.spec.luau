-- Progression rules and the real EconomyService/QuestService with stubbed dependencies.
local Loader = require("./loader")

local Config = Loader.get("ReplicatedStorage.Shared.Config")
local Cosmetics = Loader.get("ReplicatedStorage.Shared.Cosmetics")
local Progression = Loader.get("ReplicatedStorage.Shared.Progression")
local DataSchema = Loader.get("ServerScriptService.Server.Core.DataSchema")

local function noop() end

Loader.services.BadgeService = { AwardBadge = noop }
Loader.mocks["src/shared/Net.luau"] = Loader.mocks["src/shared/Net.luau"]
	or { Notify = { FireClient = noop } }

local Economy = Loader.get("ServerScriptService.Server.Services.EconomyService")
local QuestService = Loader.get("ServerScriptService.Server.Services.QuestService")

local player = { UserId = 1 }
local data = DataSchema.defaults(os.time())
local passes = {}
local economyEvents = {}
local S = {
	DataService = {
		Get = function()
			return data
		end,
		MarkDirty = noop,
	},
	TelemetryService = {
		Economy = function(_, _, flow, amount, balance, tx, sku)
			table.insert(economyEvents, { flow = flow, amount = amount, balance = balance, tx = tx, sku = sku })
		end,
		Custom = noop,
	},
	MonetizationService = { GetPasses = function()
		return passes
	end },
	AvatarService = { Refresh = noop },
}
S.EconomyService = Economy
S.QuestService = QuestService
Economy:Init(S)
QuestService:Init(S)

return function(t)
	t.test("xp curve and level ups", function()
		t.eq(Progression.xpToNext(1), 100)
		local level, xp, gained = Progression.addXp(1, 0, 250) -- 100 (L1) + 140 (L2) = 240
		t.eq(level, 3)
		t.eq(xp, 10)
		t.eq(gained, 2)
		level = Progression.addXp(99, 0, 1e9)
		t.eq(level, 100, "level cap")
	end)

	t.test("round rewards scale with performance and passes", function()
		local c1 = Progression.roundRewards({ percent = 10, rank = 4, kills = 0, participants = 6 }, 1)
		local c2 = Progression.roundRewards({ percent = 30, rank = 1, kills = 2, participants = 6 }, 1)
		local c3 = Progression.roundRewards({ percent = 30, rank = 1, kills = 2, participants = 6 }, 2.25)
		t.eq(c1, 25)
		t.eq(c2, 10 + 45 + 10 + 30)
		t.eq(c3, math.floor(c2 * 2.25))
		local solo = Progression.roundRewards({ percent = 30, rank = 1, kills = 0, participants = 2 }, 1)
		t.eq(solo, 55, "no placement bonus in tiny rounds")
		t.eq(Progression.coinMultiplier({ VIP = true, DoubleCoins = true }), 2.25)
	end)

	t.test("daily quests are 3 distinct kinds and stable per day", function()
		for day = 19000, 19060 do
			local ids = Progression.questsForDay(day)
			t.eq(#ids, 3)
			local kinds = {}
			for _, id in ids do
				local q = Progression.quest(id)
				t.ok(not kinds[q.kind], "distinct kinds")
				kinds[q.kind] = true
			end
			t.eq(table.concat(Progression.questsForDay(day), ","), table.concat(ids, ","), "deterministic")
		end
	end)

	t.test("daily reward cycles without resetting on missed days", function()
		local daily = { lastDay = -1, step = 0 }
		local ok, step, coins = Progression.dailyStatus(daily, 100)
		t.ok(ok)
		t.eq(step, 1)
		t.eq(coins, Config.Economy.DailyRewards[1])
		daily.lastDay, daily.step = 100, 1
		t.ok(not (Progression.dailyStatus(daily, 100)), "once per day")
		local _, step2 = Progression.dailyStatus(daily, 150)
		t.eq(step2, 2, "gap does not reset")
		daily.step = 7
		local _, step3 = Progression.dailyStatus(daily, 151)
		t.eq(step3, 1, "cycle wraps")
	end)

	t.test("cosmetic unlock rules", function()
		local d = DataSchema.defaults(0)
		t.ok(Cosmetics.isUnlocked(d, {}, Cosmetics.get("ink_mint")), "default")
		t.ok(not Cosmetics.isUnlocked(d, {}, Cosmetics.get("ink_lemon")), "coins item locked")
		t.ok(not Cosmetics.isUnlocked(d, {}, Cosmetics.get("ink_ice")), "level locked")
		d.level = 10
		t.ok(Cosmetics.isUnlocked(d, {}, Cosmetics.get("ink_ice")), "level unlocks")
		t.ok(Cosmetics.isUnlocked(d, { VIP = true }, Cosmetics.get("ink_gold")), "pass unlocks")
		d.achievements.land_baron = 1
		t.ok(Cosmetics.isUnlocked(d, {}, Cosmetics.get("title_baron")), "achievement unlocks")
	end)

	t.test("buying cosmetics: insufficient funds, success, no double buy", function()
		data.coins = 100
		t.eq(Economy:BuyCosmetic(player, "ink_lemon").err, "coins")
		t.eq(data.coins, 100, "no charge on failure")
		data.coins = 300
		t.ok(Economy:BuyCosmetic(player, "ink_lemon").ok)
		t.eq(data.coins, 50)
		t.ok(data.owned.ink_lemon)
		t.eq(data.equipped.ink, "ink_lemon", "auto-equipped")
		t.eq(Economy:BuyCosmetic(player, "ink_lemon").err, "owned")
		t.eq(data.coins, 50)
		local sink = economyEvents[#economyEvents]
		t.eq(sink.flow, "Sink")
		t.eq(sink.amount, 250)
		t.eq(sink.balance, 50)
	end)

	t.test("non-coin items cannot be bought with coins; locked items cannot be equipped", function()
		data.coins = 100000
		t.eq(Economy:BuyCosmetic(player, "ink_gold").err, "invalid")
		t.eq(Economy:BuyCosmetic(player, "does_not_exist").err, "invalid")
		t.eq(Economy:Equip(player, "ink_gold").err, "locked")
		passes.VIP = true
		t.ok(Economy:Equip(player, "ink_gold").ok, "pass owner can equip")
		passes.VIP = nil
	end)

	t.test("daily claim once per day", function()
		data.daily = { lastDay = -1, step = 0 }
		local before = data.coins
		t.ok(Economy:ClaimDaily(player).ok)
		t.eq(data.coins, before + Config.Economy.DailyRewards[1])
		t.eq(Economy:ClaimDaily(player).err, "claimed")
	end)

	t.test("achievements pay once", function()
		data.stats.captures = 1
		local before = data.coins
		Economy:CheckAchievements(player)
		t.ok(data.achievements.first_loop ~= nil)
		local after = data.coins
		t.ok(after > before, "reward paid")
		Economy:CheckAchievements(player)
		t.eq(data.coins, after, "not paid twice")
	end)

	t.test("quests progress, cap at goal and claim once", function()
		QuestService:Ensure(data)
		local q = data.quests.list[1]
		local def = Progression.quest(q.id)
		QuestService:Progress(player, def.kind, def.goal * 5)
		t.eq(q.progress, def.goal, "capped")
		local coins = data.coins
		t.ok(QuestService:Claim(player, q.id).ok)
		t.eq(data.coins, coins + def.coins)
		t.eq(QuestService:Claim(player, q.id).err, "notready")
		t.eq(QuestService:Claim(player, "fake").err, "invalid")
	end)

	t.test("xp grants level-up coins", function()
		data.level, data.xp = 1, 0
		local coins = data.coins
		local gained = Economy:AddXp(player, 100)
		t.eq(gained, 1)
		t.eq(data.coins, coins + Config.Progression.LevelUpCoins)
	end)
end
