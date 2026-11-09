-- Coins, XP/levels, cosmetics (buy/equip), achievements, daily reward. All server-side.
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Net = require(ReplicatedStorage.Shared.Net)

local EconomyService = {}

function EconomyService:Init(S)
	self.S = S
end

function EconomyService:Notify(player: Player, text: string, style: string?)
	Net.Notify:FireClient(player, text, style or "info")
end

function EconomyService:AddCoins(player: Player, amount: number, txType: string, sku: string?)
	local data = self.S.DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	data.coins = math.min(Config.Economy.MaxCoins, data.coins + amount)
	self.S.TelemetryService:Economy(player, "Source", amount, data.coins, txType, sku)
	self.S.DataService:MarkDirty(player)
end

function EconomyService:SpendCoins(player: Player, amount: number, sku: string): boolean
	local data = self.S.DataService:Get(player)
	if not data or amount <= 0 or data.coins < amount then
		return false
	end
	data.coins -= amount
	self.S.TelemetryService:Economy(player, "Sink", amount, data.coins, "Shop", sku)
	self.S.DataService:MarkDirty(player)
	return true
end

-- Returns levels gained.
function EconomyService:AddXp(player: Player, amount: number): number
	local data = self.S.DataService:Get(player)
	if not data then
		return 0
	end
	local before = data.level
	local gained
	data.level, data.xp, gained = Progression.addXp(data.level, data.xp, amount)
	if gained > 0 then
		self:AddCoins(player, Config.Progression.LevelUpCoins * gained, "Gameplay", "LevelUp")
		self:Notify(player, "Level " .. data.level .. "!", "level")
		for _, list in Cosmetics.Categories do
			for _, item in list do
				local u = item.unlock
				if u.type == "level" and u.level > before and u.level <= data.level then
					self:Notify(player, "Unlocked: " .. item.name, "unlock")
				end
			end
		end
		self.S.AvatarService:Refresh(player)
	end
	self.S.DataService:MarkDirty(player)
	return gained
end

function EconomyService:CheckAchievements(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	for _, a in Progression.newAchievements(data) do
		data.achievements[a.id] = os.time()
		self:AddCoins(player, a.coins, "Gameplay", "Achievement_" .. a.id)
		self:Notify(player, "Achievement: " .. a.name .. "  +" .. a.coins .. " coins", "achievement")
		self.S.TelemetryService:Custom(player, "Achievement", 1, { a.id })
		local badgeId = Config.Badges[a.id]
		if badgeId and badgeId ~= 0 then
			task.spawn(pcall, BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
		end
	end
end

function EconomyService:BuyCosmetic(player: Player, id: string)
	local data = self.S.DataService:Get(player)
	local item = Cosmetics.get(id)
	if not data or not item or item.unlock.type ~= "coins" then
		return { ok = false, err = "invalid" }
	end
	if data.owned[id] then
		return { ok = false, err = "owned" }
	end
	if not self:SpendCoins(player, item.unlock.price, id) then
		return { ok = false, err = "coins" }
	end
	data.owned[id] = true
	self:Equip(player, id)
	return { ok = true }
end

function EconomyService:Equip(player: Player, id: string)
	local data = self.S.DataService:Get(player)
	local item = Cosmetics.get(id)
	if not data or not item then
		return { ok = false, err = "invalid" }
	end
	if not Cosmetics.isUnlocked(data, self.S.MonetizationService:GetPasses(player), item) then
		return { ok = false, err = "locked" }
	end
	data.equipped[item.category] = id
	self.S.DataService:MarkDirty(player)
	self.S.AvatarService:Refresh(player)
	return { ok = true }
end

function EconomyService:ClaimDaily(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return { ok = false, err = "loading" }
	end
	local today = Progression.dayNumber(os.time())
	local canClaim, step, coins = Progression.dailyStatus(data.daily, today)
	if not canClaim then
		return { ok = false, err = "claimed" }
	end
	data.daily.lastDay = today
	data.daily.step = step
	self:AddCoins(player, coins, "TimedReward", "Daily" .. step)
	self.S.TelemetryService:Custom(player, "DailyClaim", step)
	return { ok = true, coins = coins }
end

return EconomyService
