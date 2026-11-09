-- Thin, failure-proof wrapper over Roblox AnalyticsService. No personal data is logged:
-- AnalyticsService attributes events to the Player internally; we never send names or chat.
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local TelemetryService = { counters = {}, shopSessions = {} }

-- Analytics must never break gameplay: argument building and the call itself are both protected.
local function call(method: string, build: () -> ...any)
	local ok, err = pcall(function()
		AnalyticsService[method](AnalyticsService, build())
	end)
	if not ok and RunService:IsStudio() then
		warn("[Telemetry] " .. method .. " failed: " .. tostring(err))
	end
end

function TelemetryService:Count(name: string, n: number?)
	self.counters[name] = (self.counters[name] or 0) + (n or 1)
end

-- Steps must be logged in increasing order starting at 1 (Roblox onboarding funnel rules).
function TelemetryService:Onboarding(player: Player, step: number, name: string)
	self:Count("onboarding_" .. name)
	call("LogOnboardingFunnelStepEvent", function()
		return player, step, name
	end)
end

-- Store funnel: 1 OpenStore, 2 ViewItem, 3 PromptPurchase, 4 PurchaseComplete.
function TelemetryService:StoreFunnel(player: Player, step: number, name: string, newSession: boolean?)
	if newSession or not self.shopSessions[player] then
		self.shopSessions[player] = HttpService:GenerateGUID(false)
	end
	self:Count("store_" .. name)
	local session = self.shopSessions[player]
	call("LogFunnelStepEvent", function()
		return player, "Store", session, step, name
	end)
end

-- flow: "Source" | "Sink"; txType: Enum.AnalyticsEconomyTransactionType name (Gameplay, IAP, Shop, TimedReward, Onboarding...)
function TelemetryService:Economy(player: Player, flow: string, amount: number, balance: number, txType: string, sku: string?)
	if amount <= 0 then
		return
	end
	self:Count("coins_" .. flow, amount)
	call("LogEconomyEvent", function()
		return player, Enum.AnalyticsEconomyFlowType[flow], "Coins", amount, balance, txType, sku or txType
	end)
end

function TelemetryService:Custom(player: Player, name: string, value: number?, fields: { string }?)
	self:Count(name)
	call("LogCustomEvent", function()
		local custom = nil
		if fields then
			custom = {}
			local keys = {
				Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
				Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
				Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
			}
			for k = 1, math.min(3, #fields) do
				custom[keys[k]] = fields[k]
			end
		end
		return player, name, value or 1, custom
	end)
end

function TelemetryService:Init()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		self.shopSessions[player] = nil
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			print("[Telemetry] session counters:", HttpService:JSONEncode(self.counters))
		end
	end)
end

return TelemetryService
