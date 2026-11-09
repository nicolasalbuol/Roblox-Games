-- Server bots so every round is lively even at low traffic. Clearly labelled "Bot" in UI.
-- Bots obey exactly the same Grid rules as players (MatchService samples their position).
-- Positions are simulated on the server and rendered by clients (no physics cost).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local G = Config.Grid

local BotService = { rng = Random.new(), nameIndex = 0 }

local NAMES = { "Pip", "Zippy", "Mochi", "Blip", "Nova", "Taffy", "Echo", "Bean", "Juno", "Pixel", "Sprout", "Wobble", "Kiwi", "Dot", "Fizz", "Rumble" }
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

function BotService:NextName(): string
	self.nameIndex = self.nameIndex % #NAMES + 1
	return "Bot " .. NAMES[self.nameIndex]
end

function BotService:Attach(p)
	p.bot = { pos = Vector3.new(0, G.FloorY, 0), path = {}, pathIndex = 1, skill = self.rng:NextNumber(0.3, 0.85) }
	p.respawnAt = 0
end

function BotService:Respawn(p, pos: Vector3)
	local b = p.bot
	b.pos = Vector3.new(pos.X, G.FloorY, pos.Z)
	b.path, b.pathIndex = {}, 1
end

function BotService:Destroy(_p) end

local function clamp(v: number): number
	return math.clamp(v, 1, G.Size)
end

-- Builds a path through waypoints; nil if it touches a blocked cell or our own trail.
local function route(grid, trailSet, waypoints): { number }?
	local cells = {}
	for k = 2, #waypoints do
		local a, b = waypoints[k - 1], waypoints[k]
		for _, i in grid:walk(a[1], a[2], b[1], b[2]) do
			if grid.owner[i] == -1 or trailSet[i] then
				return nil
			end
			cells[#cells + 1] = i
		end
	end
	return cells
end

local function trailSetOf(p)
	local set = {}
	local n = #p.trail
	for k = 1, n - Config.Match.TrailGrace do
		set[p.trail[k]] = true
	end
	return set
end

function BotService:_pathTo(p, grid, cx: number, cz: number, tx: number, tz: number): { number }?
	local set = trailSetOf(p)
	return route(grid, set, { { cx, cz }, { tx, cz }, { tx, tz } })
		or route(grid, set, { { cx, cz }, { cx, tz }, { tx, tz } })
end

function BotService:_nearest(grid, cx: number, cz: number, radius: number, pred: (number) -> boolean): (number?, number?)
	local best, bx, bz = math.huge, nil, nil
	for z = math.max(1, cz - radius), math.min(G.Size, cz + radius) do
		for x = math.max(1, cx - radius), math.min(G.Size, cx + radius) do
			local d = math.abs(x - cx) + math.abs(z - cz)
			if d < best and pred(grid:index(x, z)) then
				best, bx, bz = d, x, z
			end
		end
	end
	return bx, bz
end

function BotService:_plan(p, match, cx: number, cz: number)
	local grid, b, rng = match.grid, p.bot, self.rng
	local here = grid:index(cx, cz)
	b.path, b.pathIndex = {}, 1

	if grid.owner[here] ~= p.slot or #p.trail > 0 then
		local hx, hz = self:_nearest(grid, cx, cz, G.Size, function(i)
			return grid.owner[i] == p.slot
		end)
		if hx then
			b.path = self:_pathTo(p, grid, cx, cz, hx, hz) or grid:walk(cx, cz, hx, hz)
		end
		return
	end

	-- Hunt: chase a nearby rival trail.
	if rng:NextNumber() < b.skill * 0.5 then
		local tx, tz = self:_nearest(grid, cx, cz, 7, function(i)
			local t = grid.trail[i]
			return t ~= 0 and t ~= p.slot
		end)
		if tx then
			local path = self:_pathTo(p, grid, cx, cz, tx, tz)
			if path then
				b.path = path
				return
			end
		end
	end

	-- Expand: rectangular excursion that returns home.
	for _ = 1, 6 do
		local d = DIRS[rng:NextInteger(1, 4)]
		local side = if rng:NextInteger(0, 1) == 0 then 1 else -1
		local px, pz = d[2] * side, d[1] * side
		local a = rng:NextInteger(3, 5 + math.floor(b.skill * 8))
		local w = rng:NextInteger(3, 4 + math.floor(b.skill * 6))
		local x1, z1 = clamp(cx + d[1] * a), clamp(cz + d[2] * a)
		local x2, z2 = clamp(x1 + px * w), clamp(z1 + pz * w)
		local x3, z3 = clamp(x2 - d[1] * a), clamp(z2 - d[2] * a)
		local path = route(grid, {}, { { cx, cz }, { x1, z1 }, { x2, z2 }, { x3, z3 }, { cx, cz } })
		if path and #path > 0 then
			b.path = path
			return
		end
	end
	-- Nothing valid: shuffle to a random neighbouring own cell.
	local d = DIRS[rng:NextInteger(1, 4)]
	b.path = { grid:index(clamp(cx + d[1]), clamp(cz + d[2])) }
end

function BotService:_danger(p, match): boolean
	if #p.trail < 3 then
		return false
	end
	local reach = G.TileSize * (3 + p.bot.skill * 3)
	for _, o in match.participants do
		if o ~= p and o.alive and o.kind == "player" then
			local pos = match:PositionOf(o)
			if pos and (Vector3.new(pos.X, G.FloorY, pos.Z) - p.bot.pos).Magnitude < reach then
				return true
			end
		end
	end
	return false
end

function BotService:_stepBot(p, dt: number, match)
	local b = p.bot
	local grid = match.grid
	local cx, cz = match:CellAt(b.pos)
	cx, cz = clamp(cx), clamp(cz)
	if b.pathIndex > #b.path then
		self:_plan(p, match, cx, cz)
	elseif not b.fleeing and self:_danger(p, match) and self.rng:NextNumber() < b.skill then
		b.fleeing = true
		b.path = {}
		self:_plan(p, match, cx, cz)
	end
	if #p.trail == 0 then
		b.fleeing = false
	end
	local remaining = match:SpeedOf(p) * dt
	while remaining > 0 and b.pathIndex <= #b.path do
		local tx, tz = grid:coords(b.path[b.pathIndex])
		local target = match:CellCenter(tx, tz)
		local delta = Vector3.new(target.X - b.pos.X, 0, target.Z - b.pos.Z)
		local d = delta.Magnitude
		if d <= remaining then
			b.pos = Vector3.new(target.X, G.FloorY, target.Z)
			remaining -= d
			b.pathIndex += 1
		else
			b.pos += delta.Unit * remaining
			remaining = 0
		end
	end
end

function BotService:Step(dt: number, match)
	for _, p in match.participants do
		if p.kind == "bot" and p.alive then
			self:_stepBot(p, dt, match)
		end
	end
end

-- u8 count, then per bot: u8 slot, u8 alive, f32 x, f32 z
function BotService:Broadcast(match)
	local bots = {}
	for _, p in match.participants do
		if p.kind == "bot" then
			bots[#bots + 1] = p
		end
	end
	if #bots == 0 then
		return
	end
	local buf = buffer.create(1 + #bots * 10)
	buffer.writeu8(buf, 0, #bots)
	for k, p in bots do
		local o = 1 + (k - 1) * 10
		buffer.writeu8(buf, o, p.slot)
		buffer.writeu8(buf, o + 1, if p.alive then 1 else 0)
		buffer.writef32(buf, o + 2, p.bot.pos.X)
		buffer.writef32(buf, o + 6, p.bot.pos.Z)
	end
	Net.BotPos:FireAllClients(buf)
end

return BotService
