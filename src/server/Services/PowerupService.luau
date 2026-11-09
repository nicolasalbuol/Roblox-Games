-- Arena power-ups: Dash (speed), Shield (trail can't be cut), Ink Bomb (instant 5x5 claim).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local PC = Config.Powerups

local PowerupService = { active = {}, nextSpawn = 0, rng = Random.new() }

local KINDS = {
	Dash = { color = Color3.fromRGB(255, 220, 60), text = "DASH" },
	Shield = { color = Color3.fromRGB(90, 200, 255), text = "SHIELD" },
	Bomb = { color = Color3.fromRGB(255, 90, 170), text = "INK BOMB" },
}
local ORDER = { "Dash", "Shield", "Bomb" }

function PowerupService:Clear()
	for _, pu in self.active do
		pu.part:Destroy()
	end
	table.clear(self.active)
	self.nextSpawn = os.clock() + PC.SpawnInterval
end

function PowerupService:_spawn(match)
	local grid = match.grid
	for _ = 1, 30 do
		local x, z = self.rng:NextInteger(2, grid.size - 1), self.rng:NextInteger(2, grid.size - 1)
		local i = grid:index(x, z)
		if grid.owner[i] == 0 and grid.trail[i] == 0 then
			local kind = ORDER[self.rng:NextInteger(1, #ORDER)]
			local def = KINDS[kind]
			local pos = match:CellCenter(x, z) + Vector3.new(0, 2.5, 0)
			local part = Instance.new("Part")
			part.Name = "Powerup_" .. kind
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.one * 3
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Material = Enum.Material.Neon
			part.Color = def.color
			part.Position = pos
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(120, 30)
			bb.StudsOffset = Vector3.new(0, 3, 0)
			bb.MaxDistance = 120
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.Text = def.text
			t.TextColor3 = def.color
			t.TextStrokeTransparency = 0.2
			t.Parent = bb
			bb.Parent = part
			CollectionService:AddTag(part, "Powerup")
			part.Parent = match.S.WorldBuilder.arena
			table.insert(self.active, { kind = kind, pos = pos, part = part })
			return
		end
	end
end

function PowerupService:_apply(match, p, kind: string, now: number)
	local grid = match.grid
	if kind == "Dash" then
		p.dashUntil = now + PC.Dash.duration
		if p.kind == "player" then
			local _, _, hum = match:_characterParts(p.player)
			if hum then
				hum.WalkSpeed = Config.Movement.WalkSpeed * Config.Movement.DashMultiplier
			end
		end
	elseif kind == "Shield" then
		p.shieldUntil = now + PC.Shield.duration
	elseif kind == "Bomb" then
		local pos = match:PositionOf(p)
		if pos then
			local cx, cz = match:CellAt(pos)
			local gained = grid:claimSquare(p.slot, cx, cz, PC.Bomb.radius)
			p.stats.tiles += gained
			if p.kind == "player" then
				local data = match.S.DataService:Get(p.player)
				if data then
					data.stats.tilesClaimed += gained
				end
				match.S.QuestService:Progress(p.player, "tiles", gained)
			end
		end
	end
	p.stats.powerups += 1
	if p.kind == "player" then
		match.S.QuestService:Progress(p.player, "powerups", 1)
	end
	Net.Match:FireAllClients({ t = "powerup", slot = p.slot, kind = kind, duration = PC[kind].duration or 0 })
end

function PowerupService:Step(match, now: number)
	if #self.active < PC.MaxActive and now >= self.nextSpawn then
		self.nextSpawn = now + PC.SpawnInterval
		self:_spawn(match)
	end
	for k = #self.active, 1, -1 do
		local pu = self.active[k]
		for _, p in match.participants do
			if p.alive then
				local pos = match:PositionOf(p)
				if pos and Vector3.new(pos.X - pu.pos.X, 0, pos.Z - pu.pos.Z).Magnitude <= PC.PickupRadius then
					table.remove(self.active, k)
					pu.part:Destroy()
					self:_apply(match, p, pu.kind, now)
					break
				end
			end
		end
	end
end

return PowerupService
