-- Client smoke test: runs the real client bootstrap (Main.client.luau) and every UI/renderer module
-- against Lune's Roblox reflection database. Every property name and enum value the client sets is
-- validated for real; engine-only pieces (events, tweens, camera, input) are small fakes.
local roblox = require("@lune/roblox")
local Loader = require("./loader")

local realNew = roblox.Instance.new
local Vector2 = roblox.Vector2

local function noop() end

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = noop }
		end,
		Wait = noop,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end

-- Instance proxy: property reads/writes and methods hit the real Lune instance (validated);
-- events that Lune lacks return fake signals.
local EVENTS = {
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	Activated = true,
	DescendantAdded = true,
	Completed = true,
}
local proxyOf = setmetatable({}, { __mode = "k" })
local realOf = setmetatable({}, { __mode = "k" })
local wrap

local function unwrap(v)
	return realOf[v] or v
end

wrap = function(real, extra)
	if typeof(real) ~= "Instance" then
		return real
	end
	if proxyOf[real] then
		return proxyOf[real]
	end
	local events = {}
	local proxy = setmetatable({}, {
		__index = function(_, k)
			if extra and extra[k] ~= nil then
				return extra[k]
			end
			if EVENTS[k] then
				events[k] = events[k] or signal()
				return events[k]
			end
			if k == "GetPropertyChangedSignal" then
				return function()
					return signal()
				end
			end
			local v = real[k]
			if type(v) == "function" then
				return function(_, ...)
					local args = table.pack(...)
					for i = 1, args.n do
						args[i] = unwrap(args[i])
					end
					local res = table.pack(v(real, table.unpack(args, 1, args.n)))
					for i = 1, res.n do
						if type(res[i]) == "table" then
							for j, x in res[i] do
								res[i][j] = wrap(x)
							end
						else
							res[i] = wrap(res[i])
						end
					end
					return table.unpack(res, 1, res.n)
				end
			end
			return wrap(v)
		end,
		__newindex = function(_, k, v)
			real[k] = unwrap(v)
		end,
	})
	proxyOf[real], realOf[proxy] = proxy, real
	return proxy
end

local created = 0
Loader.env.TweenInfo = { new = function()
	return {}
end }
Loader.env.Instance = {
	new = function(class)
		created += 1
		return wrap(realNew(class))
	end,
}

-- Engine fakes -----------------------------------------------------------------------------
local playerGui = wrap(realNew("Folder"))
local localPlayer = {
	UserId = 42,
	DisplayName = "Tester",
	WaitForChild = function()
		return playerGui
	end,
}
local heartbeat, renderStepped = signal(), signal()
local attrs = { RoundState = "Playing", RoundEndsAt = 1100, MapName = "Neon Plaza" }
local now = 1000

Loader.workspace = {
	CurrentCamera = { ViewportSize = Vector2.new(844, 390), GetPropertyChangedSignal = function()
		return signal()
	end },
	GetAttribute = function(_, k)
		return attrs[k]
	end,
	GetServerTimeNow = function()
		return now
	end,
	BulkMoveTo = noop,
}
-- Renderers parent parts to workspace; give them a real folder through the proxy.
local worldFolder = wrap(realNew("Folder"))
setmetatable(Loader.workspace, { __index = function(_, k)
	if k == "Parent" then
		return nil
	end
	return nil
end })
Loader.env.workspace = setmetatable({}, {
	__index = function(_, k)
		return Loader.workspace[k]
	end,
})
realOf[Loader.env.workspace] = realOf[worldFolder]

Loader.services.Players = { LocalPlayer = localPlayer }
Loader.services.RunService = {
	IsServer = function()
		return false
	end,
	IsStudio = function()
		return true
	end,
	Heartbeat = heartbeat,
	RenderStepped = renderStepped,
	BindToRenderStep = noop,
}
Loader.services.TweenService = { Create = function()
	return { Play = noop, Completed = signal() }
end }
Loader.services.GuiService = { IsTenFootInterface = function()
	return false
end }
Loader.services.UserInputService = { GamepadEnabled = false, InputChanged = signal(), TouchPinch = signal() }
Loader.services.SoundService = wrap(realNew("Folder"), { PlayLocalSound = noop })
Loader.services.MarketplaceService = { GetProductInfo = function()
	error("offline")
end }
Loader.services.SocialService = { CanSendGameInviteAsync = function()
	return false
end, PromptGameInvite = noop }
Loader.services.CollectionService = { GetTagged = function()
	return {}
end, GetInstanceAddedSignal = function()
	return signal()
end, AddTag = noop }
Loader.services.Lighting = { FindFirstChildOfClass = function()
	return nil
end }
Loader.services.ContextActionService = { BindAction = noop }

local requests, clientEvents = {}, {}
local function inbound()
	return { OnClientEvent = signal() }
end
local Net = {
	Profile = inbound(),
	Roster = inbound(),
	GridSnapshot = inbound(),
	GridDelta = inbound(),
	Match = inbound(),
	Notify = inbound(),
	BotPos = inbound(),
	Request = { InvokeServer = function(_, action, arg)
		table.insert(requests, { action, arg })
		return { ok = true, coins = 50 }
	end },
	ClientEvent = { FireServer = function(_, kind, arg)
		table.insert(clientEvents, { kind, arg })
	end },
}
Loader.mocks["src/shared/Net.luau"] = Net

return function(t)
	local Config = Loader.get("ReplicatedStorage.Shared.Config")
	local Grid = Loader.get("ReplicatedStorage.Shared.Grid")
	local GridCodec = Loader.get("ReplicatedStorage.Shared.GridCodec")
	local DataSchema = Loader.get("ServerScriptService.Server.Core.DataSchema")

	t.test("client bootstrap builds every screen with valid properties", function()
		Loader.runScript("src/client/Main.client.luau", "StarterPlayerScripts.Client")
		t.ok(created > 1600, "tiles + UI instances created (" .. created .. ")")
		t.eq(clientEvents[#clientEvents][1], "ready", "client asked for state last")
		t.ok(playerGui:FindFirstChild("ChromaUI") ~= nil, "ScreenGui mounted")
	end)

	local Kit = Loader.get("StarterPlayerScripts.Client.UI.Kit")
	local State = Loader.get("StarterPlayerScripts.Client.Controllers.State")

	t.test("server messages drive HUD, grid, bots and every modal", function()
		local data = DataSchema.publicView(DataSchema.defaults(os.time()))
		data.coins = 1234
		data.quests = { day = 0, list = { { id = "claim_400", progress = 400, claimed = false }, { id = "cut_2", progress = 1, claimed = false } } }
		Net.Profile.OnClientEvent:Fire(data, { VIP = true })
		t.eq(State.profile.coins, 1234)

		Net.Roster.OnClientEvent:Fire({
			{ slot = 1, name = "Tester", isBot = false, userId = 42, color = { 62, 240, 178 } },
			{ slot = 2, name = "Bot Pip", isBot = true, userId = 0, color = { 255, 104, 104 } },
		})
		t.eq(State.mySlot, 1)

		local g = Grid.new(Config.Grid.Size)
		g:claimSquare(1, 5, 5, 2)
		g:claimSquare(2, 30, 30, 2)
		g:setOwner(g:index(12, 12), -1)
		Net.GridSnapshot.OnClientEvent:Fire("neon_plaza", GridCodec.snapshot(g))
		t.eq(State.grid:countOf(1), 25)
		g:takeDirty()
		g:setTrail(g:index(8, 5), 1)
		g:setTrail(g:index(9, 5), 1)
		Net.GridDelta.OnClientEvent:Fire(GridCodec.delta(g, g:takeDirty()))
		t.eq(State.grid.trail[g:index(9, 5)], 1)

		local buf = buffer.create(11)
		buffer.writeu8(buf, 0, 1)
		buffer.writeu8(buf, 1, 2)
		buffer.writeu8(buf, 2, 1)
		buffer.writef32(buf, 3, 10)
		buffer.writef32(buf, 7, -20)
		Net.BotPos.OnClientEvent:Fire(buf)

		for _, evt in {
			{ t = "roundStart", map = "neon_plaza" },
			{ t = "spawn", slot = 1 },
			{ t = "capture", n = 87 },
			{ t = "elim", victim = 2, killer = 1, reason = "cut", x = 10, z = -20 },
			{ t = "elim", victim = 1, killer = 2, reason = "self", x = 0, z = 0 },
			{ t = "powerup", slot = 1, kind = "Dash", duration = 0 },
			{ t = "powerup", slot = 1, kind = "Bomb", duration = 0 },
		} do
			Net.Match.OnClientEvent:Fire(evt)
		end
		Net.Notify.OnClientEvent:Fire("Achievement: First Loop", "achievement")

		for _ = 1, 3 do
			now += 0.3
			heartbeat:Fire(0.3)
			renderStepped:Fire(1 / 60)
		end

		for _, tab in { "ink", "trail", "title", "coins", "passes" } do
			local Shop = Loader.get("StarterPlayerScripts.Client.UI.Shop")
			Shop.tab = tab
			Kit.openModal("Shop")
			t.eq(Kit.currentModal(), "Shop", "shop opens on " .. tab)
			Kit.closeModal()
		end
		Kit.openModal("Quests")
		t.eq(Kit.currentModal(), "Quests")
		Kit.openModal("Settings")
		t.eq(Kit.currentModal(), "Settings")
		Kit.closeModal()

		Net.Match.OnClientEvent:Fire({
			t = "results",
			rank = 2,
			count = 6,
			percent = 21.5,
			peak = 30.2,
			kills = 3,
			tiles = 540,
			coins = 77,
			xp = 140,
			won = false,
			levelBefore = 1,
			levelAfter = 2,
			map = "Neon Plaza",
			top = { { name = "Bot Pip", percent = 25, isBot = true, color = { 255, 104, 104 } }, { name = "Tester", percent = 21.5, isBot = false, color = { 62, 240, 178 } } },
		})
		t.eq(Kit.currentModal(), "Results", "results shown")
		attrs.RoundState = "Intermission"
		heartbeat:Fire(0.3)
	end)

	t.test("settings changes are sent to the server", function()
		local Settings = Loader.get("StarterPlayerScripts.Client.UI.Settings")
		Settings:Render()
		local before = #requests
		State:Request("setting", { key = "camera", value = "classic" })
		t.eq(#requests, before + 1)
		t.eq(requests[#requests][1], "setting")
	end)
end
