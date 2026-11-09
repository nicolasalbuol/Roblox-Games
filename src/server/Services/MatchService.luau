-- Authoritative round loop. Server samples every participant's position at TickRate, walks the
-- 4-connected path between samples, and applies trail / capture / cut rules on the shared Grid.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Grid = require(ReplicatedStorage.Shared.Grid)
local GridCodec = require(ReplicatedStorage.Shared.GridCodec)
local Maps = require(ReplicatedStorage.Shared.Maps)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Net = require(ReplicatedStorage.Shared.Net)

local G, MC = Config.Grid, Config.Match

local MatchService = {
	state = "Intermission",
	grid = Grid.new(G.Size),
	participants = {} :: { [number]: any }, -- slot -> participant
	byPlayer = {} :: { [Player]: any },
	mapIndex = 0,
	map = Maps.List[1],
	rng = Random.new(),
}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

function MatchService:CellCenter(x: number, z: number): Vector3
	return Vector3.new(G.OriginX + (x - 0.5) * G.TileSize, G.FloorY, G.OriginZ + (z - 0.5) * G.TileSize)
end

function MatchService:CellAt(pos: Vector3): (number, number)
	return math.floor((pos.X - G.OriginX) / G.TileSize) + 1, math.floor((pos.Z - G.OriginZ) / G.TileSize) + 1
end

function MatchService:AssignedColor(player: Player): Color3?
	local p = self.byPlayer[player]
	return p and p.color
end

function MatchService:IsPlaying(): boolean
	return self.state == "Playing"
end

-- Participants --------------------------------------------------------------------------------

function MatchService:_freeSlot(): number
	for s = 1, 250 do
		if not self.participants[s] then
			return s
		end
	end
	error("no free slot")
end

function MatchService:_pickInk(preferred: string?): (string, Color3)
	local used = {}
	for _, p in self.participants do
		used[p.ink] = true
	end
	if preferred and not used[preferred] and Cosmetics.get(preferred) then
		return preferred, rgb(Cosmetics.get(preferred).color)
	end
	local free = {}
	for _, ink in Cosmetics.Inks do
		if not used[ink.id] then
			free[#free + 1] = ink
		end
	end
	local ink = free[self.rng:NextInteger(1, math.max(1, #free))] or Cosmetics.Inks[1]
	return ink.id, rgb(ink.color)
end

function MatchService:_newParticipant(kind: string, name: string, ink: string?)
	local slot = self:_freeSlot()
	local inkId, color = self:_pickInk(ink)
	local p = {
		slot = slot,
		kind = kind,
		name = name,
		ink = inkId,
		color = color,
		alive = false,
		respawnAt = 0,
		trail = {},
		lastCell = nil,
		lastPos = nil,
		lastTime = 0,
		shieldUntil = 0,
		dashUntil = 0,
		strikes = 0,
		stats = { tiles = 0, kills = 0, deaths = 0, peak = 0, captures = 0, bestLoop = 0, powerups = 0 },
	}
	self.participants[slot] = p
	return p
end

function MatchService:AddPlayer(player: Player)
	if self.byPlayer[player] or self.state ~= "Playing" then
		return
	end
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local p = self:_newParticipant("player", player.DisplayName, data.equipped.ink)
	p.player = player
	p.userId = player.UserId
	self.byPlayer[player] = p
	if p.ink ~= data.equipped.ink then
		self.S.EconomyService:Notify(player, "Your ink is taken this round - you're painting in " .. Cosmetics.get(p.ink).name .. ".", "info")
	end
	self.S.AvatarService:Refresh(player)
	self:_balanceBots()
	self:_sendRoster()
end

function MatchService:_remove(p)
	self.grid:clearSlot(p.slot, p.trail)
	self.participants[p.slot] = nil
	if p.player then
		self.byPlayer[p.player] = nil
	end
	if p.bot then
		self.S.BotService:Destroy(p)
	end
end

function MatchService:_balanceBots()
	if self.state ~= "Playing" then
		return
	end
	local humans, bots = 0, {}
	for _, p in self.participants do
		if p.kind == "player" then
			humans += 1
		else
			table.insert(bots, p)
		end
	end
	local want = math.clamp(MC.MinParticipants - humans, 0, MC.MaxBots)
	while #bots < want do
		local p = self:_newParticipant("bot", self.S.BotService:NextName())
		self.S.BotService:Attach(p)
		table.insert(bots, p)
	end
	while #bots > want do
		-- Prefer removing the bot with the least territory to keep the round stable.
		table.sort(bots, function(a, b)
			return self.grid:countOf(a.slot) > self.grid:countOf(b.slot)
		end)
		self:_remove(table.remove(bots))
	end
end

function MatchService:_rosterPayload()
	local list = {}
	for slot, p in self.participants do
		list[#list + 1] = {
			slot = slot,
			name = p.name,
			isBot = p.kind == "bot",
			userId = p.userId or 0,
			color = { math.floor(p.color.R * 255 + 0.5), math.floor(p.color.G * 255 + 0.5), math.floor(p.color.B * 255 + 0.5) },
		}
	end
	return list
end

function MatchService:_sendRoster(target: Player?)
	local payload = self:_rosterPayload()
	if target then
		Net.Roster:FireClient(target, payload)
	else
		Net.Roster:FireAllClients(payload)
	end
end

-- Spawning / elimination ----------------------------------------------------------------------

function MatchService:_characterParts(player: Player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then
		return char, root, hum
	end
	return nil
end

function MatchService:_spawn(p): boolean
	local char, root, hum
	if p.kind == "player" then
		char, root, hum = self:_characterParts(p.player)
		if not char then
			return false
		end
	end
	local r = MC.SpawnRadius
	local cx, cz = self.grid:findSpawn(r, function(a, b)
		return self.rng:NextInteger(a, b)
	end)
	self.grid:claimSquare(p.slot, cx, cz, r)
	table.clear(p.trail)
	p.alive = true
	p.lastCell, p.lastPos = nil, nil
	p.dashUntil = 0
	local pos = self:CellCenter(cx, cz)
	if p.kind == "player" then
		root.Anchored = false
		hum.WalkSpeed = Config.Movement.WalkSpeed
		char:PivotTo(CFrame.new(pos + Vector3.new(0, 3.5, 0)))
		self:_tutorial(p.player, 1, "Spawned")
	else
		self.S.BotService:Respawn(p, pos)
	end
	Net.Match:FireAllClients({ t = "spawn", slot = p.slot })
	return true
end

function MatchService:_eliminate(victim, killer, reason: string)
	if not victim.alive then
		return
	end
	victim.alive = false
	victim.respawnAt = os.clock() + MC.RespawnSeconds
	local pos = victim.lastPos
	self.grid:clearSlot(victim.slot, victim.trail)
	table.clear(victim.trail)
	victim.lastCell, victim.lastPos = nil, nil
	victim.stats.deaths += 1
	if victim.kind == "player" then
		local data = self.S.DataService:Get(victim.player)
		if data then
			data.stats.deaths += 1
		end
		local _, root = self:_characterParts(victim.player)
		if root then
			root.Anchored = true
		end
	end
	if killer and killer ~= victim then
		killer.stats.kills += 1
		if killer.kind == "player" then
			local data = self.S.DataService:Get(killer.player)
			if data then
				data.stats.kills += 1
			end
			self.S.QuestService:Progress(killer.player, "kills", 1)
			self.S.EconomyService:CheckAchievements(killer.player)
		end
	end
	Net.Match:FireAllClients({
		t = "elim",
		victim = victim.slot,
		killer = killer and killer.slot or 0,
		reason = reason,
		x = pos and pos.X or 0,
		z = pos and pos.Z or 0,
	})
end

-- Rules ---------------------------------------------------------------------------------------

function MatchService:_capture(p)
	local gained, victims = self.grid:capture(p.slot, p.trail)
	table.clear(p.trail)
	local now = os.clock()
	for slot in victims do
		local v = self.participants[slot]
		if v and v.alive and now >= v.shieldUntil then
			self:_eliminate(v, p, "enclosed")
		end
	end
	-- A rival whose whole territory was swallowed has nowhere to close a loop: they are out.
	for _, v in self.participants do
		if v ~= p and v.alive and self.grid:countOf(v.slot) == 0 then
			self:_eliminate(v, p, "overrun")
		end
	end
	if gained <= 0 then
		return
	end
	p.stats.tiles += gained
	p.stats.captures += 1
	p.stats.bestLoop = math.max(p.stats.bestLoop, gained)
	p.stats.peak = math.max(p.stats.peak, self.grid:percentOf(p.slot))
	if p.kind == "player" then
		local player = p.player
		local data = self.S.DataService:Get(player)
		if data then
			data.stats.tilesClaimed += gained
			data.stats.captures += 1
			data.stats.bestLoop = math.max(data.stats.bestLoop, gained)
			data.stats.bestPercent = math.max(data.stats.bestPercent, math.floor(p.stats.peak))
		end
		self.S.QuestService:Progress(player, "tiles", gained)
		if gained >= 50 then
			self.S.QuestService:Progress(player, "bigloop", 1)
		end
		self.S.EconomyService:CheckAchievements(player)
		self:_tutorial(player, 3, "FirstCapture")
		Net.Match:FireClient(player, { t = "capture", n = gained })
	end
end

function MatchService:_enterCell(p, i: number)
	local grid = self.grid
	local owner = grid.owner[i]
	if owner == -1 then
		return
	end
	local t = grid.trail[i]
	if t ~= 0 and t ~= p.slot then
		local victim = self.participants[t]
		if not victim or not victim.alive then
			grid:setTrail(i, 0)
		elseif os.clock() >= victim.shieldUntil then
			self:_eliminate(victim, p, "cut")
		end
		t = grid.trail[i]
	end
	if owner == p.slot then
		if #p.trail > 0 then
			self:_capture(p)
		end
	elseif t == p.slot then
		local n = #p.trail
		for k = math.max(1, n - MC.TrailGrace + 1), n do
			if p.trail[k] == i then
				return
			end
		end
		self:_eliminate(p, nil, "self")
	elseif t == 0 then
		grid:setTrail(i, p.slot)
		table.insert(p.trail, i)
		if #p.trail == 1 and p.kind == "player" then
			self:_tutorial(p.player, 2, "LeftZone")
		end
	end
end

function MatchService:SpeedOf(p): number
	local base = if p.kind == "bot" then Config.Movement.BotSpeed else Config.Movement.WalkSpeed
	return if os.clock() < p.dashUntil then base * Config.Movement.DashMultiplier else base
end

function MatchService:PositionOf(p): Vector3?
	if p.kind == "bot" then
		return p.bot.pos
	end
	local _, root = self:_characterParts(p.player)
	return root and root.Position
end

function MatchService:_processMovement(p, pos: Vector3, now: number)
	local grid = self.grid
	if pos.Y > G.FloorY + MC.MaxPaintHeight or pos.Y < G.FloorY - 6 then
		p.lastPos, p.lastTime = pos, now
		return
	end
	local cx, cz = self:CellAt(pos)
	if not grid:inBounds(cx, cz) then
		p.lastPos, p.lastCell, p.lastTime = pos, nil, now
		return
	end
	local i = grid:index(cx, cz)
	if p.kind == "player" and p.lastPos then
		-- Anti-exploit: movement faster than physically possible never paints through the gap.
		local dt = math.max(now - p.lastTime, 1 / MC.TickRate)
		local flat = Vector3.new(pos.X - p.lastPos.X, 0, pos.Z - p.lastPos.Z).Magnitude
		if flat > (self:SpeedOf(p) * MC.SpeedTolerance + MC.SpeedSlack) * dt then
			p.strikes += 1
			if p.strikes % 20 == 1 then
				warn(string.format("[Match] speed anomaly for %s (%.1f studs in %.2fs)", p.name, flat, dt))
			end
			p.lastPos, p.lastTime, p.lastCell = pos, now, i
			return
		end
	end
	p.lastPos, p.lastTime = pos, now
	if p.lastCell == nil then
		p.lastCell = i
		self:_enterCell(p, i)
		return
	end
	if i == p.lastCell then
		return
	end
	local lx, lz = grid:coords(p.lastCell)
	for _, c in grid:walk(lx, lz, cx, cz) do
		self:_enterCell(p, c)
		if not p.alive then
			return
		end
	end
	p.lastCell = i
end

-- Tutorial / onboarding funnel (server-tracked so it cannot be skipped by a client).
function MatchService:_tutorial(player: Player, step: number, name: string)
	local data = self.S.DataService:Get(player)
	if not data or data.tutorialStep >= step then
		return
	end
	for s = data.tutorialStep + 1, step do
		local stepName = ({ "Spawned", "LeftZone", "FirstCapture", "FirstRoundComplete" })[s]
		self.S.TelemetryService:Onboarding(player, s, stepName or name)
	end
	data.tutorialStep = step
	if step >= 3 then
		data.tutorialDone = true
	end
	self.S.DataService:MarkDirty(player)
end

-- Tick ----------------------------------------------------------------------------------------

function MatchService:_tick()
	if self.state ~= "Playing" then
		return
	end
	local now = os.clock()
	for _, p in self.participants do
		if not p.alive and now >= p.respawnAt then
			if not self:_spawn(p) then
				p.respawnAt = now + 0.5
			end
		end
	end
	self.S.BotService:Step(1 / MC.TickRate, self)
	for _, p in self.participants do
		if p.alive then
			local pos = self:PositionOf(p)
			if pos then
				self:_processMovement(p, pos, now)
			end
			if p.kind == "player" and p.dashUntil > 0 and now >= p.dashUntil then
				p.dashUntil = 0
				local _, _, hum = self:_characterParts(p.player)
				if hum then
					hum.WalkSpeed = Config.Movement.WalkSpeed
				end
			end
		end
	end
	self.S.PowerupService:Step(self, now)
	local dirty = self.grid:takeDirty()
	if #dirty > 0 then
		Net.GridDelta:FireAllClients(GridCodec.delta(self.grid, dirty))
	end
	self.S.BotService:Broadcast(self)
end

-- Round flow ----------------------------------------------------------------------------------

function MatchService:_setState(state: string, endsAt: number)
	self.state = state
	workspace:SetAttribute("RoundState", state)
	workspace:SetAttribute("RoundEndsAt", endsAt)
end

function MatchService:_sendSnapshot(target: Player?)
	local buf = GridCodec.snapshot(self.grid)
	if target then
		Net.GridSnapshot:FireClient(target, self.map.id, buf)
	else
		Net.GridSnapshot:FireAllClients(self.map.id, buf)
	end
end

-- Called (rate limited) when a client signals it is ready, so a late joiner never misses the snapshot.
function MatchService:SendStateTo(player: Player)
	self:_sendSnapshot(player)
	self:_sendRoster(player)
end

function MatchService:_startRound()
	self.mapIndex = self.mapIndex % #Maps.List + 1
	self.map = Maps.List[self.mapIndex]
	self.S.WorldBuilder:BuildArena(self.map)
	self.S.PowerupService:Clear()
	local grid = self.grid
	grid:reset()
	Maps.forEachBlocked(self.map, function(x, z)
		grid:setOwner(grid:index(x, z), -1)
	end)
	grid:takeDirty()
	self:_setState("Playing", workspace:GetServerTimeNow() + MC.RoundSeconds)
	self:_sendSnapshot()
	for _, player in Players:GetPlayers() do
		self:AddPlayer(player)
	end
	self:_balanceBots()
	self:_sendRoster()
	Net.Match:FireAllClients({ t = "roundStart", map = self.map.id })
end

function MatchService:_endRound()
	local grid = self.grid
	local ranking = {}
	for _, p in self.participants do
		p.stats.peak = math.max(p.stats.peak, grid:percentOf(p.slot))
		table.insert(ranking, p)
	end
	table.sort(ranking, function(a, b)
		local ca, cb = grid:countOf(a.slot), grid:countOf(b.slot)
		if ca ~= cb then
			return ca > cb
		end
		return a.stats.tiles > b.stats.tiles
	end)
	local count = #ranking
	local top = {}
	for rank = 1, math.min(3, count) do
		local p = ranking[rank]
		top[rank] = { name = p.name, percent = grid:percentOf(p.slot), color = p.color, isBot = p.kind == "bot" }
	end
	self:_setState("Intermission", workspace:GetServerTimeNow() + MC.IntermissionSeconds)
	self.S.WorldBuilder:ShowPodium(top)

	for rank, p in ranking do
		if p.kind == "player" and p.player.Parent then
			self:_reward(p, rank, count, top)
		end
	end
	for _, p in table.clone(self.participants) do
		self:_remove(p)
	end
	self.S.PowerupService:Clear()
	grid:takeDirty()
	self:_sendRoster()
	-- Everyone back to the hub; podium spots for human top-3.
	for _, player in Players:GetPlayers() do
		local char, root = self:_characterParts(player)
		if char then
			root.Anchored = false
			local cf = self.S.WorldBuilder:HubCFrame(self.rng)
			for rank, p in ranking do
				if rank <= 3 and p.player == player then
					cf = self.S.WorldBuilder:PodiumCFrame(rank) or cf
				end
			end
			char:PivotTo(cf)
		end
	end
end

function MatchService:_reward(p, rank: number, count: number, top)
	local player = p.player
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local S = self.S
	local percent = self.grid:percentOf(p.slot)
	local multiplier = Progression.coinMultiplier(S.MonetizationService:GetPasses(player))
	local coins, xp = Progression.roundRewards({ percent = percent, rank = rank, kills = p.stats.kills, participants = count }, multiplier)
	local levelBefore = data.level
	data.stats.rounds += 1
	data.stats.powerups += p.stats.powerups
	data.stats.bestPercent = math.max(data.stats.bestPercent, math.floor(p.stats.peak))
	local won = rank == 1 and count >= MC.WinMinParticipants
	if won then
		data.stats.wins += 1
		S.QuestService:Progress(player, "wins", 1)
	end
	S.QuestService:Progress(player, "rounds", 1)
	if rank <= 3 then
		S.QuestService:Progress(player, "top3", 1)
	end
	S.EconomyService:AddCoins(player, coins, "Gameplay", "RoundReward")
	S.EconomyService:AddXp(player, xp)
	S.EconomyService:CheckAchievements(player)
	self:_tutorial(player, 4, "FirstRoundComplete")
	S.TelemetryService:Custom(player, "RoundEnd", rank, { self.map.id, tostring(math.floor(percent)), tostring(p.stats.kills) })
	S.LeaderboardService:MarkWins(player, data.stats.wins)
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Wins") then
		ls.Wins.Value = data.stats.wins
	end

	local topPayload = {}
	for k, e in top do
		topPayload[k] = { name = e.name, percent = e.percent, isBot = e.isBot, color = { math.floor(e.color.R * 255), math.floor(e.color.G * 255), math.floor(e.color.B * 255) } }
	end
	Net.Match:FireClient(player, {
		t = "results",
		rank = rank,
		count = count,
		percent = percent,
		peak = p.stats.peak,
		kills = p.stats.kills,
		tiles = p.stats.tiles,
		coins = coins,
		xp = xp,
		won = won,
		levelBefore = levelBefore,
		levelAfter = data.level,
		top = topPayload,
		map = self.map.name,
	})
end

function MatchService:_updateLeaderstats()
	for player, p in self.byPlayer do
		local ls = player:FindFirstChild("leaderstats")
		local turf = ls and ls:FindFirstChild("Turf")
		if turf then
			turf.Value = string.format("%.1f%%", self.grid:percentOf(p.slot))
		end
	end
end

function MatchService:Init(S)
	self.S = S
	workspace:SetAttribute("RoundState", "Intermission")
	workspace:SetAttribute("RoundEndsAt", 0)
end

function MatchService:Start()
	local S = self.S
	S.DataService.Loaded:Connect(function(player, data)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local wins = Instance.new("IntValue")
		wins.Name = "Wins"
		wins.Value = data.stats.wins
		wins.Parent = ls
		local turf = Instance.new("StringValue")
		turf.Name = "Turf"
		turf.Value = "-"
		turf.Parent = ls
		ls.Parent = player
		self:AddPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local p = self.byPlayer[player]
		if p then
			self:_remove(p)
			self:_balanceBots()
			self:_sendRoster()
		end
	end)

	local acc, statsAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		statsAcc += dt
		if acc >= 1 / MC.TickRate then
			acc = math.min(acc - 1 / MC.TickRate, 1 / MC.TickRate)
			debug.profilebegin("ChromaTurf.MatchTick")
			local ok, err = pcall(self._tick, self)
			debug.profileend()
			if not ok then
				warn("[Match] tick error: " .. tostring(err))
			end
		end
		if statsAcc >= 1 then
			statsAcc = 0
			self:_updateLeaderstats()
		end
	end)

	-- Characters that respawn through Roblox (reset/fall) re-enter via our spawn rules.
	local function hook(player)
		player.CharacterAdded:Connect(function()
			local p = self.byPlayer[player]
			if p and p.alive then
				self:_eliminate(p, nil, "reset")
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	self:_setState("Intermission", workspace:GetServerTimeNow() + MC.IntermissionSeconds)
	task.wait(MC.IntermissionSeconds)
	while true do
		self:_startRound()
		while workspace:GetServerTimeNow() < workspace:GetAttribute("RoundEndsAt") do
			task.wait(0.25)
		end
		self:_endRound()
		task.wait(MC.IntermissionSeconds)
	end
end

return MatchService
