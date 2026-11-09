-- Game passes and developer products. Server-authoritative, idempotent receipt processing.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ReceiptLogic = require(script.Parent.Parent.Core.ReceiptLogic)

local M = Config.Monetization

local MonetizationService = { passes = {} :: { [Player]: { [string]: boolean } } }

local productById = {}
for key, p in M.Products do
	if p.id ~= 0 then
		productById[p.id] = { key = key, def = p }
	end
end
local passById = {}
for key, p in M.GamePasses do
	if p.id ~= 0 then
		passById[p.id] = key
	end
end

function MonetizationService:GetPasses(player: Player): { [string]: boolean }
	return self.passes[player] or {}
end

function MonetizationService:HasPass(player: Player, key: string): boolean
	return self:GetPasses(player)[key] == true
end

function MonetizationService:LoadPasses(player: Player)
	local owned = {}
	for key, p in M.GamePasses do
		if p.id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.id)
			owned[key] = ok and has == true
		end
	end
	self.passes[player] = owned
end

function MonetizationService:_grantPass(player: Player, key: string)
	local owned = self.passes[player] or {}
	owned[key] = true
	self.passes[player] = owned
	self.S.TelemetryService:StoreFunnel(player, 4, "PurchaseComplete")
	self.S.TelemetryService:Custom(player, "PassPurchased", M.GamePasses[key].price, { key })
	self.S.AvatarService:Refresh(player)
	self.S.DataService:MarkDirty(player)
	self.S.EconomyService:Notify(player, "Thank you! " .. M.GamePasses[key].name .. " is now active.", "gold")
end

-- kind: "pass" | "product". Returns a result table for the client.
function MonetizationService:Prompt(player: Player, kind: string, key: string)
	local def = if kind == "pass" then M.GamePasses[key] elseif kind == "product" then M.Products[key] else nil
	if not def then
		return { ok = false, err = "unknown" }
	end
	if def.id == 0 then
		return { ok = false, err = "unavailable" }
	end
	if kind == "pass" and self:HasPass(player, key) then
		return { ok = false, err = "owned" }
	end
	self.S.TelemetryService:StoreFunnel(player, 3, "PromptPurchase")
	if kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, def.id)
	else
		MarketplaceService:PromptProductPurchase(player, def.id)
	end
	return { ok = true }
end

function MonetizationService:Init(S)
	self.S = S
end

function MonetizationService:Start()
	local S = self.S

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passById[passId]
		if purchased and key then
			self:_grantPass(player, key)
		end
	end)

	MarketplaceService.ProcessReceipt = function(info)
		local decision = ReceiptLogic.process(info, {
			maxHistory = Config.Data.MaxReceiptHistory,
			now = os.time,
			getProfile = function(userId)
				local player = Players:GetPlayerByUserId(userId)
				return player and S.DataService:GetProfile(player)
			end,
			grant = function(profile, productId)
				local entry = productById[productId]
				if not entry then
					warn("[Monetization] receipt for unknown product " .. tostring(productId))
					return false
				end
				local data = profile.data
				data.coins = math.min(Config.Economy.MaxCoins, data.coins + entry.def.coins)
				data.stats.robuxSpent += info.CurrencySpent or 0
				local player = Players:GetPlayerByUserId(info.PlayerId)
				if player then
					S.TelemetryService:Economy(player, "Source", entry.def.coins, data.coins, "IAP", entry.key)
					S.TelemetryService:StoreFunnel(player, 4, "PurchaseComplete")
				end
				return true
			end,
			save = function(profile)
				return profile:save(false)
			end,
		})
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if decision == "Granted" and player then
			local entry = productById[info.ProductId]
			S.DataService:MarkDirty(player)
			S.EconomyService:Notify(player, string.format("+%d coins. Thanks for supporting Chroma Turf!", entry.def.coins), "gold")
		end
		return if decision == "Granted"
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Players.PlayerRemoving:Connect(function(player)
		self.passes[player] = nil
	end)
end

return MonetizationService
