-- Owns player profiles: session-locked load, autosave, save on leave and on shutdown.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Net = require(ReplicatedStorage.Shared.Net)
local ProfileStore = require(script.Parent.Parent.Core.ProfileStore)
local DataSchema = require(script.Parent.Parent.Core.DataSchema)
local MemoryStore = require(script.Parent.Parent.Core.MemoryStore)

local DataService = {
	profiles = {} :: { [Player]: any },
	dirty = {} :: { [Player]: boolean },
	Loaded = Signal.new(), -- (player, data)
	Releasing = Signal.new(), -- (player, data) fired before the final save
	usingMemory = false,
}

local function storeFor(store)
	local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
	return ProfileStore.new({
		store = store,
		jobId = jobId,
		now = os.time,
		sleep = task.wait,
		lockStale = Config.Data.LockStaleSeconds,
		attempts = Config.Data.LoadAttempts,
		retryDelay = Config.Data.LoadRetryDelay,
	})
end

function DataService:Init(S)
	self.S = S
	self.store = storeFor(DataStoreService:GetDataStore(Config.Data.StoreName))
	self.memory = storeFor(MemoryStore.new())
	if RunService:IsStudio() then
		self.store.attempts = 2 -- fail fast to the memory fallback when API access is off
		self.store.retryDelay = 1
	end
end

function DataService:Get(player: Player)
	local p = self.profiles[player]
	return p and p.data
end

function DataService:GetProfile(player: Player)
	return self.profiles[player]
end

function DataService:MarkDirty(player: Player)
	self.dirty[player] = true
end

function DataService:Push(player: Player)
	local data = self:Get(player)
	if data then
		local passes = self.S.MonetizationService:GetPasses(player)
		Net.Profile:FireClient(player, DataSchema.publicView(data), passes)
	end
end

function DataService:_onPlayerAdded(player: Player)
	local key = "u_" .. player.UserId
	local profile, err = self.store:load(key)
	if not profile and RunService:IsStudio() then
		warn("[DataService] DataStore unavailable in Studio (" .. tostring(err) .. "); using a temporary profile")
		self.usingMemory = true
		profile, err = self.memory:load(key)
	end
	if not player.Parent then
		if profile then
			profile:save(true)
		end
		return
	end
	if not profile then
		player:Kick(
			if err == "newer"
				then "A newer version of Chroma Turf is live. Please rejoin."
				else "We couldn't load your save safely. Please rejoin in a moment."
		)
		return
	end
	local data = profile.data
	data.sessions += 1
	data.lastJoin = os.time()
	self.profiles[player] = profile
	-- Return-day signal for D1/D7/D30 cohorts (days since first join; 0 = first day).
	local days = (os.time() - data.firstJoin) // 86400
	self.S.TelemetryService:Custom(player, "SessionStart", days, { if data.sessions == 1 then "new" else "returning" })
	self.S.MonetizationService:LoadPasses(player)
	self.Loaded:Fire(player, data)
	self:Push(player)
end

function DataService:_release(player: Player)
	local profile = self.profiles[player]
	if not profile then
		return
	end
	self.Releasing:Fire(player, profile.data)
	self.profiles[player] = nil
	self.dirty[player] = nil
	profile:save(true)
end

function DataService:SaveNow(player: Player): boolean
	local profile = self.profiles[player]
	return profile ~= nil and profile:save(false)
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self._onPlayerAdded, self, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)

	game:BindToClose(function()
		local pending = 0
		for player in self.profiles do
			pending += 1
			task.spawn(function()
				self:_release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	-- Batched client replication (at most 4 pushes per second per player).
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in self.dirty do
				self.dirty[player] = nil
				self:Push(player)
			end
		end
	end)

	-- Autosave, staggered across players.
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for player, profile in table.clone(self.profiles) do
				if player.Parent then
					profile:save(false)
					if profile.lost then
						self.profiles[player] = nil
						player:Kick("Your save was opened on another server. Please rejoin.")
					end
					task.wait(0.5)
				end
			end
		end
	end)
end

return DataService
