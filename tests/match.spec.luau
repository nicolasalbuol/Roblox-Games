-- Headless integration tests: real MatchService + BotService + PowerupService + DataSchema,
-- with Roblox services, remotes and characters replaced by small fakes.
local roblox = require("@lune/roblox")
local Loader = require("./loader")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local now = 1000
local attrs = {}
local events = {}

local function noop() end
local function signal()
	return { Connect = function()
		return { Disconnect = noop }
	end }
end
local function remote(name)
	return {
		FireAllClients = function(_, a, b)
			table.insert(events, { name = name, payload = a, extra = b })
		end,
		FireClient = function(_, _, a, b)
			table.insert(events, { name = name, payload = a, extra = b })
		end,
	}
end

local players = {}
Loader.clock = function()
	return now
end
Loader.workspace = {
	SetAttribute = function(_, k, v)
		attrs[k] = v
	end,
	GetAttribute = function(_, k)
		return attrs[k]
	end,
	GetServerTimeNow = function()
		return now
	end,
}
Loader.services.Players = { GetPlayers = function()
	return players
end, PlayerAdded = signal(), PlayerRemoving = signal() }
Loader.services.RunService = { IsServer = function()
	return true
end, IsStudio = function()
	return true
end, Heartbeat = signal() }
Loader.services.CollectionService = { AddTag = noop }
Loader.mocks["src/shared/Net.luau"] = {
	Match = remote("Match"),
	Roster = remote("Roster"),
	GridSnapshot = remote("Snapshot"),
	GridDelta = remote("Delta"),
	BotPos = remote("BotPos"),
	Notify = remote("Notify"),
	ClientEvent = { OnServerEvent = signal() },
}

local Config = Loader.get("ReplicatedStorage.Shared.Config")
local DataSchema = Loader.get("ServerScriptService.Server.Core.DataSchema")
local Match = Loader.get("ServerScriptService.Server.Services.MatchService")
local Bots = Loader.get("ServerScriptService.Server.Services.BotService")
local Powerups = Loader.get("ServerScriptService.Server.Services.PowerupService")

local profiles, rewards, quests = {}, {}, {}
local S = {
	DataService = {
		Get = function(_, player)
			return profiles[player]
		end,
		MarkDirty = noop,
	},
	EconomyService = {
		Notify = noop,
		CheckAchievements = noop,
		AddCoins = function(_, player, n)
			rewards[player] = (rewards[player] or 0) + n
		end,
		AddXp = function()
			return 0
		end,
	},
	QuestService = { Progress = function(_, _, kind, n)
		quests[kind] = (quests[kind] or 0) + n
	end },
	AvatarService = { Refresh = noop },
	TelemetryService = { Onboarding = noop, Custom = noop },
	WorldBuilder = {
		BuildArena = noop,
		ShowPodium = noop,
		arena = roblox.Instance.new("Folder"),
		HubCFrame = function()
			return CFrame.new(0, 5, -200)
		end,
		PodiumCFrame = function()
			return nil
		end,
	},
	MonetizationService = { GetPasses = function()
		return {}
	end },
	LeaderboardService = { MarkWins = noop },
	PowerupService = Powerups,
	BotService = Bots,
	MatchService = Match,
}
Match:Init(S)
Match.rng, Bots.rng, Powerups.rng = Loader.Random.new(7), Loader.Random.new(11), Loader.Random.new(13)

local function fakePlayer(name: string, userId: number)
	local root = { Position = Vector3.new(0, 3, -200), Anchored = false }
	local hum = { Health = 100, WalkSpeed = 16 }
	local char = {
		FindFirstChild = function(_, n)
			return if n == "HumanoidRootPart" then root else nil
		end,
		FindFirstChildOfClass = function(_, n)
			return if n == "Humanoid" then hum else nil
		end,
		PivotTo = function(_, cf)
			root.Position = cf.Position
		end,
	}
	local player = { Name = name, DisplayName = name, UserId = userId, Character = char, Parent = true }
	function player.FindFirstChild()
		return nil
	end
	profiles[player] = DataSchema.defaults(os.time())
	return player, root
end

local function tick(n: number?)
	for _ = 1, n or 1 do
		now += 1 / Config.Match.TickRate
		Match:_tick()
	end
end

-- Walks root toward target at ~18 studs/s, ticking the match.
local function walkTo(root, target)
	while true do
		local delta = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		if delta.Magnitude < 0.05 then
			return
		end
		local step = math.min(1.8, delta.Magnitude)
		root.Position = root.Position + delta.Unit * step
		tick()
	end
end

local function checkInvariants(t)
	local grid = Match.grid
	local counts = {}
	for i = 1, grid.n do
		local o = grid.owner[i]
		if o > 0 then
			counts[o] = (counts[o] or 0) + 1
		end
	end
	for slot, p in Match.participants do
		t.eq(grid:countOf(slot), counts[slot] or 0, "count cache for slot " .. slot)
		for _, i in p.trail do
			t.eq(grid.trail[i], slot, "trail cell marked")
		end
		if not p.alive then
			t.eq(#p.trail, 0, "dead participants have no trail")
		end
	end
	for i = 1, grid.n do
		local tr = grid.trail[i]
		if tr ~= 0 then
			t.ok(Match.participants[tr] ~= nil, "trail belongs to a participant")
		end
	end
end

local function countEvents(kind: string): number
	local n = 0
	for _, e in events do
		if e.name == "Match" and e.payload.t == kind then
			n += 1
		end
	end
	return n
end

return function(t)
	t.test("bots-only round: 3 simulated minutes keep the grid consistent", function()
		table.clear(events)
		Match:_startRound()
		t.eq(Match.state, "Playing")
		local bots = 0
		for _ in Match.participants do
			bots += 1
		end
		t.eq(bots, Config.Match.MinParticipants, "bots fill the round")
		for k = 1, Config.Match.RoundSeconds * Config.Match.TickRate do
			tick()
			if k % 100 == 0 then
				checkInvariants(t)
			end
		end
		local claimed = 0
		for slot in Match.participants do
			claimed += Match.grid:countOf(slot)
		end
		t.ok(claimed > 300, "bots claimed territory (" .. claimed .. ")")
		t.ok(countEvents("spawn") >= bots, "spawn events")
		print(string.format("    sim: %d tiles owned at end, %d eliminations, %d delta packets", claimed, countEvents("elim"), #events))
		Match:_endRound()
		t.eq(next(Match.participants), nil, "round cleared")
		t.eq(Match.state, "Intermission")
	end)

	t.test("player loop captures land, completes tutorial and earns rewards", function()
		local maxBots = Config.Match.MaxBots
		Config.Match.MaxBots = 0
		local player, root = fakePlayer("Ana", 101)
		players = { player }
		table.clear(events)
		Match:_startRound()
		tick()
		local p = Match.byPlayer[player]
		t.ok(p and p.alive, "player spawned")
		t.eq(Match.grid:countOf(p.slot), 25, "5x5 start zone")
		local cx, cz = Match:CellAt(root.Position)
		local sx = if cx < 20 then 1 else -1
		local sz = if cz < 20 then 1 else -1
		local function cell(dx, dz)
			local c = Match:CellCenter(cx + dx * sx, cz + dz * sz)
			return Vector3.new(c.X, 3, c.Z)
		end
		walkTo(root, cell(7, 0))
		t.ok(#p.trail >= 4, "trail drawn outside the zone")
		t.eq(profiles[player].tutorialStep, 2, "tutorial step LeftZone")
		walkTo(root, cell(7, 7))
		walkTo(root, cell(0, 7))
		walkTo(root, cell(0, 1))
		t.ok(p.alive, "still alive")
		t.eq(#p.trail, 0, "trail consumed by capture")
		t.ok(Match.grid:countOf(p.slot) >= 64, "loop claimed the enclosed area (" .. Match.grid:countOf(p.slot) .. ")")
		t.ok(p.stats.captures >= 1, "capture counted")
		t.ok((quests.tiles or 0) > 0, "quest progress")
		t.ok(profiles[player].tutorialDone, "tutorial done after first capture")
		t.eq(profiles[player].stats.captures, p.stats.captures, "lifetime stat")
		checkInvariants(t)
		Match:_endRound()
		t.ok((rewards[player] or 0) > 0, "round rewards paid")
		t.eq(profiles[player].stats.rounds, 1)
		Config.Match.MaxBots = maxBots
	end)

	t.test("teleport/speed exploit never paints through the gap", function()
		local maxBots = Config.Match.MaxBots
		Config.Match.MaxBots = 0
		local player, root = fakePlayer("Exploiter", 102)
		players = { player }
		Match:_startRound()
		tick()
		local p = Match.byPlayer[player]
		local cx, cz = Match:CellAt(root.Position)
		local far = Match:CellCenter(if cx < 20 then cx + 12 else cx - 12, cz)
		root.Position = Vector3.new(far.X, 3, far.Z)
		tick()
		t.eq(p.strikes, 1, "anomaly flagged")
		t.eq(#p.trail, 0, "nothing painted by the jump")
		local nxt = Match:CellCenter(Match:CellAt(root.Position) + 0, cz + (if cz < 20 then 1 else -1))
		walkTo(root, Vector3.new(nxt.X, 3, nxt.Z))
		t.ok(#p.trail >= 1, "normal movement paints again")
		checkInvariants(t)
		Match:_endRound()
		Config.Match.MaxBots = maxBots
	end)

	t.test("cutting a rival trail eliminates them; shield blocks; self-cut; respawn", function()
		local maxBots = Config.Match.MaxBots
		Config.Match.MaxBots = 0
		local a, rootA = fakePlayer("A", 201)
		local b, rootB = fakePlayer("B", 202)
		players = { a, b }
		table.clear(events)
		Match:_startRound()
		tick()
		local pa, pb = Match.byPlayer[a], Match.byPlayer[b]
		t.ok(pa.alive and pb.alive, "both spawned")
		-- B walks 5 cells out of its zone.
		local bx, bz = Match:CellAt(rootB.Position)
		local dir = if bx < 20 then 1 else -1
		local target = Match:CellCenter(bx + 6 * dir, bz)
		walkTo(rootB, Vector3.new(target.X, 3, target.Z))
		t.ok(#pb.trail >= 3, "B has a trail")

		pb.shieldUntil = now + 5
		Match:_enterCell(pa, pb.trail[2])
		t.ok(pb.alive, "shield protects the trail")
		pb.shieldUntil = 0

		Match:_enterCell(pa, pb.trail[2])
		t.ok(not pb.alive, "B eliminated by the cut")
		t.eq(Match.grid:countOf(pb.slot), 0, "B's turf wiped")
		t.eq(pa.stats.kills, 1, "kill credited")
		t.eq(profiles[a].stats.kills, 1, "lifetime kill")
		local last = nil
		for _, e in events do
			if e.name == "Match" and e.payload.t == "elim" then
				last = e.payload
			end
		end
		t.eq(last.killer, pa.slot)
		t.eq(last.reason, "cut")

		-- Respawn after RespawnSeconds.
		tick(Config.Match.RespawnSeconds * Config.Match.TickRate + 2)
		t.ok(pb.alive, "B respawned")
		t.eq(Match.grid:countOf(pb.slot), 25, "fresh start zone")

		-- Self-cut: A steps back onto an old cell of its own trail.
		local ax, az = Match:CellAt(rootA.Position)
		local adir = if az < 20 then 1 else -1
		local out = Match:CellCenter(ax, az + 6 * adir)
		walkTo(rootA, Vector3.new(out.X, 3, out.Z))
		t.ok(#pa.trail >= 3, "A has a trail")
		Match:_enterCell(pa, pa.trail[1])
		t.ok(not pa.alive, "crossing your own trail is a self-cut")
		checkInvariants(t)
		Match:_endRound()
		Config.Match.MaxBots = maxBots
	end)

	t.test("bombs and power-ups apply server-side", function()
		local maxBots = Config.Match.MaxBots
		Config.Match.MaxBots = 0
		local player, root = fakePlayer("Bomber", 301)
		players = { player }
		Match:_startRound()
		tick()
		local p = Match.byPlayer[player]
		local before = Match.grid:countOf(p.slot)
		local cx, cz = Match:CellAt(root.Position)
		local away = Match:CellCenter(if cx < 20 then cx + 8 else cx - 8, cz)
		walkTo(root, Vector3.new(away.X, 3, away.Z))
		Powerups:_apply(Match, p, "Bomb", now)
		t.ok(Match.grid:countOf(p.slot) > before, "bomb claimed tiles")
		Powerups:_apply(Match, p, "Dash", now)
		t.ok(Match:SpeedOf(p) > Config.Movement.WalkSpeed, "dash speeds up")
		tick(Config.Powerups.Dash.duration * Config.Match.TickRate + 2)
		t.eq(Match:SpeedOf(p), Config.Movement.WalkSpeed, "dash expires")
		checkInvariants(t)
		Match:_endRound()
		Config.Match.MaxBots = maxBots
	end)
end
