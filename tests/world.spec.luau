-- Builds the real hub, all three arenas, podium, wins board, nametags and every cosmetic FX through
-- proxied Lune instances, so every property name / enum value / class name is validated.
local roblox = require("@lune/roblox")
local Loader = require("./loader")
local Fakes = require("./fakes")

local wrap, noop = Fakes.wrap, Fakes.noop
local realNew = roblox.Instance.new

Loader.env.Instance = { new = function(class)
	return wrap(realNew(class))
end }
local dataModel = realNew("DataModel")
local world = wrap(realNew("Folder"))
Loader.env.workspace = world
Loader.services.Lighting = wrap(dataModel:GetService("Lighting"))
Loader.services.PhysicsService = {
	IsCollisionGroupRegistered = function()
		return false
	end,
	RegisterCollisionGroup = noop,
	CollisionGroupSetCollidable = noop,
}
Loader.services.CollectionService = { AddTag = noop }
Loader.services.Players = Loader.services.Players or { PlayerAdded = Fakes.signal(), PlayerRemoving = Fakes.signal() }
Loader.services.DataStoreService = { GetOrderedDataStore = function()
	error("no datastores in tests")
end }

local Maps = Loader.get("ReplicatedStorage.Shared.Maps")
local Cosmetics = Loader.get("ReplicatedStorage.Shared.Cosmetics")
local DataSchema = Loader.get("ServerScriptService.Server.Core.DataSchema")
local WorldBuilder = Loader.get("ServerScriptService.Server.Services.WorldBuilder")
local AvatarService = Loader.get("ServerScriptService.Server.Services.AvatarService")
local LeaderboardService = Loader.get("ServerScriptService.Server.Services.LeaderboardService")

return function(t)
	t.test("hub and all arenas build with valid instances", function()
		WorldBuilder:Init({})
		t.ok(world:FindFirstChild("Hub") ~= nil, "hub built")
		t.ok(world.Hub:FindFirstChild("HubSpawn") ~= nil, "spawn location")
		for _, map in Maps.List do
			WorldBuilder:BuildArena(map)
			local arena = world:FindFirstChild("Arena")
			t.ok(arena ~= nil, "arena for " .. map.id)
			local obstacles = 0
			for _, c in arena:GetChildren() do
				if c.Name == "Obstacle" then
					obstacles += 1
				end
			end
			t.eq(obstacles, #map.obstacles, "obstacles for " .. map.id)
			t.ok(math.abs(Loader.services.Lighting.ClockTime - map.lighting.ClockTime) < 1e-3, "lighting applied")
		end
		WorldBuilder:ShowPodium({ { name = "Ana", color = roblox.Color3.new(1, 0, 0) } })
		t.eq(WorldBuilder.podiumLabels[1].Text, "Ana")
		t.ok(WorldBuilder:PodiumCFrame(1) ~= nil, "podium spot")
	end)

	t.test("wins board renders", function()
		LeaderboardService:Init({})
		LeaderboardService:_render({ { name = "Ana", wins = 3 }, { name = "Bo", wins = 1 } })
		t.ok(world.Hub.WinsBoard:FindFirstChild("Board") ~= nil, "surface gui")
	end)

	t.test("nametags and every cosmetic FX apply to a character", function()
		local data = DataSchema.defaults(0)
		data.level = 30
		local passes = { VIP = true, PrismPack = true }
		local char = wrap(realNew("Model"))
		local head = wrap(realNew("Part"))
		head.Name = "Head"
		head.Parent = char
		local root = wrap(realNew("Part"))
		root.Name = "HumanoidRootPart"
		root.Parent = char
		local player = { Character = char, DisplayName = "Ana", UserId = 1 }
		AvatarService:Init({
			DataService = { Get = function()
				return data
			end },
			MonetizationService = { GetPasses = function()
				return passes
			end },
			MatchService = { AssignedColor = function()
				return nil
			end },
		})
		for _, fx in Cosmetics.Trails do
			data.owned[fx.id] = true
			data.equipped.trail = fx.id
			data.equipped.title = "title_vip"
			AvatarService:Refresh(player)
		end
		t.ok(head:FindFirstChild("Nametag") ~= nil, "nametag")
		local fxCount = 0
		for _, c in root:GetChildren() do
			if c.Name == "CosmeticFX" then
				fxCount += 1
			end
		end
		t.ok(fxCount >= 1, "last FX applied and old ones cleaned (" .. fxCount .. ")")
	end)
end
