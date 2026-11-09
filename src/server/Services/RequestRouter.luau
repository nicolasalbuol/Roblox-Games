-- Single validated, rate-limited entry point for client actions. Clients never send amounts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(script.Parent.Parent.Core.RateLimiter)

local RequestRouter = {}

local function isId(v): boolean
	return type(v) == "string" and #v > 0 and #v <= 64
end

local SETTINGS = {
	sfx = function(v)
		return type(v) == "number" and v == v and v >= 0 and v <= 1
	end,
	music = function(v)
		return type(v) == "number" and v == v and v >= 0 and v <= 1
	end,
	camera = function(v)
		return v == "top" or v == "classic"
	end,
	reducedFx = function(v)
		return type(v) == "boolean"
	end,
}

function RequestRouter:Init(S)
	self.S = S
	self.requestLimiter = RateLimiter.new(Config.RateLimits.Request.capacity, Config.RateLimits.Request.refillPerSecond)
	self.eventLimiter = RateLimiter.new(Config.RateLimits.ClientEvent.capacity, Config.RateLimits.ClientEvent.refillPerSecond)
	self.handlers = {
		buy = function(player, id)
			return if isId(id) then S.EconomyService:BuyCosmetic(player, id) else nil
		end,
		equip = function(player, id)
			return if isId(id) then S.EconomyService:Equip(player, id) else nil
		end,
		claimQuest = function(player, id)
			return if isId(id) then S.QuestService:Claim(player, id) else nil
		end,
		claimDaily = function(player)
			return S.EconomyService:ClaimDaily(player)
		end,
		setting = function(player, arg, data)
			if type(arg) ~= "table" or not SETTINGS[arg.key] or not SETTINGS[arg.key](arg.value) then
				return nil
			end
			data.settings[arg.key] = arg.value
			S.DataService:MarkDirty(player)
			return { ok = true }
		end,
		prompt = function(player, arg)
			if type(arg) ~= "table" or not isId(arg.kind) or not isId(arg.key) then
				return nil
			end
			return S.MonetizationService:Prompt(player, arg.kind, arg.key)
		end,
	}
end

function RequestRouter:Start()
	local S = self.S
	Net.Request.OnServerInvoke = function(player, action, arg)
		if type(action) ~= "string" or not self.handlers[action] then
			return { ok = false, err = "unknown" }
		end
		if not self.requestLimiter:allow(player) then
			return { ok = false, err = "slow" }
		end
		local data = S.DataService:Get(player)
		if not data then
			return { ok = false, err = "loading" }
		end
		local ok, result = pcall(self.handlers[action], player, arg, data)
		if not ok then
			warn("[Request] " .. action .. " failed: " .. tostring(result))
			return { ok = false, err = "error" }
		end
		return result or { ok = false, err = "invalid" }
	end

	-- Fire-and-forget hints used only for analytics funnels.
	Net.ClientEvent.OnServerEvent:Connect(function(player, kind, arg)
		if not self.eventLimiter:allow(player) or type(kind) ~= "string" then
			return
		end
		if kind == "ready" then
			S.MatchService:SendStateTo(player)
		elseif kind == "storeOpen" then
			S.TelemetryService:StoreFunnel(player, 1, "OpenStore", true)
		elseif kind == "storeView" and isId(arg) then
			S.TelemetryService:StoreFunnel(player, 2, "ViewItem")
		elseif kind == "invite" then
			S.TelemetryService:Custom(player, "InvitePrompt")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.requestLimiter:forget(player)
		self.eventLimiter:forget(player)
	end)
end

return RequestRouter
