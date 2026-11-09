-- Renders the territory grid locally: one cheap non-colliding tile per cell, recoloured on deltas.
-- Newly claimed tiles do a short "pop" wave (moved in bulk, skipped with Reduced Effects).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Maps = require(ReplicatedStorage.Shared.Maps)
local State = require(script.Parent.State)

local G = Config.Grid
local GridRenderer = { tiles = {}, base = {}, pops = {}, reducedFx = false }

local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local POP_TIME, POP_HEIGHT, MAX_POPS = 0.35, 0.9, 260

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

function GridRenderer:_build()
	local folder = Instance.new("Folder")
	folder.Name = "ChromaTiles"
	local size = Vector3.new(G.TileSize - 0.3, 0.2, G.TileSize - 0.3)
	for z = 1, G.Size do
		for x = 1, G.Size do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Size = size
			local cf = CFrame.new(G.OriginX + (x - 0.5) * G.TileSize, G.FloorY + 0.1, G.OriginZ + (z - 0.5) * G.TileSize)
			p.CFrame = cf
			p.Parent = folder
			local i = (z - 1) * G.Size + x
			self.tiles[i] = p
			self.base[i] = cf
		end
	end
	folder.Parent = workspace
	self.folder = folder
end

function GridRenderer:_paint(i: number)
	local grid, part = State.grid, self.tiles[i]
	local o, t = grid.owner[i], grid.trail[i]
	if o == -1 then
		part.Transparency = 1
		return
	end
	part.Transparency = 0
	local x, z = grid:coords(i)
	local alt = (x + z) % 2 == 0
	if t ~= 0 then
		part.Material = Enum.Material.Neon
		part.Color = State:ColorOf(t):Lerp(WHITE, 0.25)
	elseif o > 0 then
		part.Material = Enum.Material.SmoothPlastic
		local c = State:ColorOf(o)
		part.Color = if alt then c else c:Lerp(BLACK, 0.12)
	else
		part.Material = Enum.Material.SmoothPlastic
		part.Color = if alt then self.tileA else self.tileB
	end
end

function GridRenderer:_paintAll()
	if not State.grid then
		return
	end
	for i = 1, State.grid.n do
		self:_paint(i)
	end
end

function GridRenderer:_pop(i: number)
	if self.reducedFx or #self.pops >= MAX_POPS then
		return
	end
	table.insert(self.pops, { i = i, t0 = os.clock() })
end

function GridRenderer:_stepPops()
	local n = #self.pops
	if n == 0 then
		return
	end
	local now = os.clock()
	local parts, cfs, keep = table.create(n), table.create(n), {}
	for _, e in self.pops do
		local a = (now - e.t0) / POP_TIME
		local base = self.base[e.i]
		if a >= 1 then
			parts[#parts + 1] = self.tiles[e.i]
			cfs[#cfs + 1] = base
		else
			parts[#parts + 1] = self.tiles[e.i]
			cfs[#cfs + 1] = base + Vector3.new(0, math.sin(a * math.pi) * POP_HEIGHT, 0)
			keep[#keep + 1] = e
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	self.pops = keep
end

function GridRenderer:SetReducedFx(on: boolean)
	self.reducedFx = on
end

function GridRenderer:Start()
	self:_build()
	local function applyMap(mapId)
		local map = Maps.get(mapId) or Maps.List[1]
		self.tileA, self.tileB = rgb(map.tileA), rgb(map.tileB)
	end
	applyMap(Maps.List[1].id)
	State.GridReset:Connect(function(mapId)
		applyMap(mapId)
		self:_paintAll()
	end)
	State.RosterChanged:Connect(function()
		self:_paintAll()
	end)
	State.GridChanged:Connect(function(changed)
		local grid = State.grid
		for _, i in changed do
			local wasTrail = self.tiles[i].Material == Enum.Material.Neon
			self:_paint(i)
			-- Capture wave: trail turned into territory, or a big batch of new territory.
			if (wasTrail or #changed > 40) and grid.owner[i] > 0 and grid.trail[i] == 0 then
				self:_pop(i)
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		self:_stepPops()
	end)
end

return GridRenderer
