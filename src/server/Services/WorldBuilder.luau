-- Procedural world: hub (spawn, podium, signage, wins board) and themed arenas. Original geometry only.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Maps = require(ReplicatedStorage.Shared.Maps)

local G = Config.Grid
local WorldBuilder = {}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	return p
end

local function decor(props)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = props.CastShadow or false
	return part(props)
end

local function label(parent, face, text, color, bg)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = bg or Color3.new(0, 0, 0)
	t.BackgroundTransparency = if bg then 0 else 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	t.Parent = gui
	gui.Parent = parent
	return t
end

local function hubOrigin(): Vector3
	local h = Config.Match.HubPosition
	return Vector3.new(h[1], h[2], h[3])
end

function WorldBuilder:HubCFrame(rng: Random): CFrame
	local o = hubOrigin()
	local offset = Vector3.new(rng:NextNumber(-14, 14), 4, rng:NextNumber(-10, 6))
	return CFrame.lookAt(o + offset, o + offset + Vector3.new(0, 0, 1))
end

function WorldBuilder:PodiumCFrame(rank: number): CFrame?
	local block = self.podium[rank]
	if not block then
		return nil
	end
	local top = block.Position + Vector3.new(0, block.Size.Y / 2 + 3, 0)
	return CFrame.lookAt(top, top - Vector3.new(0, 0, 1))
end

function WorldBuilder:ShowPodium(top)
	for rank, block in self.podium do
		local entry = top[rank]
		self.podiumLabels[rank].Text = if entry then entry.name else ""
		self.podiumLabels[rank].TextColor3 = if entry then entry.color else Color3.new(1, 1, 1)
		block.Color = if entry then entry.color else Color3.fromRGB(60, 60, 90)
	end
end

function WorldBuilder:_buildHub()
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	local o = hubOrigin()

	part({ Name = "Floor", Size = Vector3.new(96, 2, 64), Position = o - Vector3.new(0, 1, 0), Color = Color3.fromRGB(34, 30, 60), Parent = hub })
	-- Checker inlay so the hub previews the core visual language.
	for x = -3, 3 do
		for z = -2, 2 do
			if (x + z) % 2 == 0 then
				decor({
					Size = Vector3.new(6, 0.1, 6),
					Position = o + Vector3.new(x * 6, 0.05, z * 6),
					Color = Color3.fromHSV(((x + 3) / 7), 0.55, 0.95),
					Material = Enum.Material.Neon,
					Transparency = 0.35,
					Parent = hub,
				})
			end
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.lookAt(o + Vector3.new(0, 0.2, -12), o + Vector3.new(0, 0.2, 10))
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(80, 230, 255)
	spawn.Transparency = 0.4
	spawn.Parent = hub

	-- Rails
	for _, r in { { 0, 32, 96, 1 }, { 0, -32, 96, 1 }, { 48, 0, 1, 64 }, { -48, 0, 1, 64 } } do
		part({ Size = Vector3.new(r[3], 4, r[4]), Position = o + Vector3.new(r[1], 2, r[2]), Transparency = 0.7, Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 200, 255), Parent = hub })
		decor({ Size = Vector3.new(r[3], 0.4, r[4]), Position = o + Vector3.new(r[1], 4.2, r[2]), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 70, 200), Parent = hub })
	end

	-- Podium (2nd, 1st, 3rd from left to right as seen by players)
	self.podium, self.podiumLabels = {}, {}
	for rank, spec in { { 0, 6 }, { 9, 4 }, { -9, 2.5 } } do
		local block = part({
			Name = "Podium" .. rank,
			Size = Vector3.new(8, spec[2], 8),
			Position = o + Vector3.new(spec[1], spec[2] / 2, 20),
			Color = Color3.fromRGB(60, 60, 90),
			Parent = hub,
		})
		label(block, Enum.NormalId.Front, tostring(rank), Color3.new(1, 1, 1))
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(220, 50)
		bb.StudsOffset = Vector3.new(0, spec[2] / 2 + 7, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 150
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextStrokeTransparency = 0.3
		t.Text = ""
		t.Parent = bb
		bb.Parent = block
		self.podium[rank] = block
		self.podiumLabels[rank] = t
	end

	local sign = part({ Name = "TitleSign", Size = Vector3.new(44, 10, 1), Position = o + Vector3.new(0, 16, 30), Color = Color3.fromRGB(20, 18, 40), Parent = hub })
	local title = label(sign, Enum.NormalId.Front, "CHROMA TURF", Color3.fromRGB(255, 255, 255))
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(62, 240, 178)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(72, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 104, 200)),
	})
	grad.Parent = title
	decor({ Size = Vector3.new(46, 0.6, 1.4), Position = o + Vector3.new(0, 10.8, 30), Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 230, 255), Parent = hub })

	local board = part({ Name = "WinsBoard", Size = Vector3.new(18, 22, 1), Position = o + Vector3.new(-36, 11, 22), Color = Color3.fromRGB(20, 18, 40), Parent = hub })
	board.CFrame = CFrame.lookAt(board.Position, board.Position + Vector3.new(0.5, 0, -1))
	local how = part({ Name = "HowToBoard", Size = Vector3.new(18, 14, 1), Position = o + Vector3.new(36, 7, 22), Color = Color3.fromRGB(20, 18, 40), Parent = hub })
	how.CFrame = CFrame.lookAt(how.Position, how.Position + Vector3.new(-0.5, 0, -1))
	label(how, Enum.NormalId.Front, "HOW TO PLAY\n\n1. Leave your zone\n2. Loop back home\n3. Claim everything inside\n4. Cut rival trails!", Color3.fromRGB(230, 240, 255))

	hub.Parent = workspace
	self.hub = hub
end

local function cellRect(r)
	local T = G.TileSize
	local x0, x1 = G.OriginX + (r[1] - 1) * T, G.OriginX + r[3] * T
	local z0, z1 = G.OriginZ + (r[2] - 1) * T, G.OriginZ + r[4] * T
	return Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2), Vector3.new(x1 - x0, 0, z1 - z0)
end

function WorldBuilder:_decor(folder, map, rng: Random)
	local accent, wall = rgb(map.accent), rgb(map.wall)
	if map.decor == "towers" then
		decor({ Size = Vector3.new(1400, 2, 1400), Position = Vector3.new(0, -60, 0), Color = Color3.fromRGB(14, 12, 30), Parent = folder })
		for k = 1, 18 do
			local a = (k / 18) * math.pi * 2
			local radius = rng:NextNumber(175, 240)
			local h = rng:NextNumber(30, 95)
			local pos = Vector3.new(math.cos(a) * radius, h / 2 - 30, math.sin(a) * radius)
			decor({ Size = Vector3.new(10, h, 10), Position = pos, Color = Color3.fromRGB(30, 28, 60), Parent = folder })
			decor({ Size = Vector3.new(10.6, 1, 10.6), Position = pos + Vector3.new(0, h / 2, 0), Material = Enum.Material.Neon, Color = if k % 2 == 0 then accent else wall, Parent = folder })
		end
		for _ = 1, 10 do
			local p = decor({ Size = Vector3.one * rng:NextNumber(4, 9), Material = Enum.Material.Neon, Transparency = 0.2, Color = Color3.fromHSV(rng:NextNumber(), 0.6, 1), Parent = folder })
			p.CFrame = CFrame.new(rng:NextNumber(-260, 260), rng:NextNumber(40, 80), rng:NextNumber(-260, 260))
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		end
	elseif map.decor == "docks" then
		decor({ Size = Vector3.new(1400, 1, 1400), Position = Vector3.new(0, -7, 0), Color = Color3.fromRGB(40, 130, 170), Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.15, Parent = folder })
		for side = -1, 1, 2 do
			for k = -4, 4 do
				decor({ Size = Vector3.new(3, 12, 3), Position = Vector3.new(k * 28, -4, side * (G.Extent / 2 + 14)), Color = Color3.fromRGB(110, 72, 44), Material = Enum.Material.Wood, Parent = folder })
			end
			decor({ Size = Vector3.new(G.Extent + 20, 1, 14), Position = Vector3.new(0, 1.5, side * (G.Extent / 2 + 14)), Color = Color3.fromRGB(150, 104, 66), Material = Enum.Material.WoodPlanks, Parent = folder })
		end
		for _ = 1, 14 do
			local s = rng:NextNumber(4, 7)
			decor({ Size = Vector3.one * s, Position = Vector3.new(rng:NextNumber(-130, 130), 2 + s / 2, (if rng:NextNumber() > 0.5 then 1 else -1) * (G.Extent / 2 + rng:NextNumber(10, 18))), Color = Color3.fromRGB(170, 120, 70), Material = Enum.Material.WoodPlanks, Parent = folder })
		end
		for k = 1, 6 do
			local hull = decor({ Size = Vector3.new(14, 4, 34), Color = if k % 2 == 0 then accent else Color3.fromRGB(240, 240, 240), Parent = folder })
			hull.CFrame = CFrame.new(math.cos(k) * 230, -5, math.sin(k) * 230) * CFrame.Angles(0, k, 0)
			decor({ Size = Vector3.new(1, 18, 1), Position = hull.Position + Vector3.new(0, 11, 0), Color = Color3.fromRGB(120, 90, 60), Parent = folder })
		end
	elseif map.decor == "crystals" then
		decor({ Size = Vector3.new(1400, 2, 1400), Position = Vector3.new(0, -30, 0), Color = Color3.fromRGB(235, 245, 255), Material = Enum.Material.Snow, Parent = folder })
		for _ = 1, 26 do
			local a = rng:NextNumber(0, math.pi * 2)
			local radius = rng:NextNumber(170, 280)
			local h = rng:NextNumber(20, 70)
			local p = decor({ Size = Vector3.new(rng:NextNumber(6, 12), h, rng:NextNumber(6, 12)), Material = Enum.Material.Glass, Transparency = 0.25, Color = Color3.fromRGB(150, 220, 255), Parent = folder })
			p.CFrame = CFrame.new(math.cos(a) * radius, -30 + h / 2, math.sin(a) * radius) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), a, rng:NextNumber(-0.3, 0.3))
		end
	end
end

function WorldBuilder:_lighting(map)
	local L = map.lighting
	Lighting.ClockTime = L.ClockTime
	Lighting.Ambient = rgb(L.Ambient)
	Lighting.OutdoorAmbient = rgb(L.OutdoorAmbient)
	Lighting.Brightness = L.Brightness
	local function ensure(class)
		local inst = Lighting:FindFirstChildOfClass(class)
		if not inst then
			inst = Instance.new(class)
			inst.Parent = Lighting
		end
		return inst
	end
	local atm = ensure("Atmosphere")
	atm.Density = L.Atmosphere[1]
	atm.Color = rgb(L.Atmosphere[2])
	atm.Decay = rgb(L.Atmosphere[2])
	atm.Haze = 1.5
	atm.Glare = 0.2
	local bloom = ensure("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 24
	bloom.Threshold = 1.4
	local cc = ensure("ColorCorrectionEffect")
	cc.TintColor = rgb(L.Tint)
	cc.Saturation = 0.12
	cc.Contrast = 0.06
end

-- Rebuilds the arena for a map. Physics floor/walls/obstacles live here; tiles are rendered by clients.
function WorldBuilder:BuildArena(map)
	if self.arena then
		self.arena:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	local E = G.Extent
	part({ Name = "Floor", Size = Vector3.new(E + 4, 4, E + 4), Position = Vector3.new(0, G.FloorY - 2, 0), Color = rgb(map.floor), Parent = folder })
	decor({ Size = Vector3.new(E + 16, 3, E + 16), Position = Vector3.new(0, G.FloorY - 4.6, 0), Color = rgb(map.wall):Lerp(Color3.new(0, 0, 0), 0.6), Parent = folder })
	for _, w in { { 0, E / 2 + 1, E + 4, 2 }, { 0, -E / 2 - 1, E + 4, 2 }, { E / 2 + 1, 0, 2, E + 4 }, { -E / 2 - 1, 0, 2, E + 4 } } do
		part({ Name = "Wall", Size = Vector3.new(w[3], 8, w[4]), Position = Vector3.new(w[1], G.FloorY + 4, w[2]), Material = Enum.Material.Glass, Transparency = 0.6, Color = rgb(map.wall), CastShadow = false, Parent = folder })
		decor({ Size = Vector3.new(w[3], 0.5, w[4]), Position = Vector3.new(w[1], G.FloorY + 8.25, w[2]), Material = Enum.Material.Neon, Color = rgb(map.wall), Parent = folder })
	end
	for _, r in map.obstacles do
		local center, size = cellRect(r)
		local block = part({
			Name = "Obstacle",
			Size = Vector3.new(size.X - 0.4, 10, size.Z - 0.4),
			Position = center + Vector3.new(0, G.FloorY + 5, 0),
			Material = Enum.Material[map.obstacleMaterial],
			Color = rgb(map.obstacleColor),
			Transparency = if map.obstacleMaterial == "Glass" then 0.2 else 0,
			Parent = folder,
		})
		decor({ Size = Vector3.new(block.Size.X + 0.2, 0.4, block.Size.Z + 0.2), Position = block.Position + Vector3.new(0, 5.2, 0), Material = Enum.Material.Neon, Color = rgb(map.accent), Parent = folder })
	end
	self:_decor(folder, map, Random.new(#map.id * 7919))
	folder.Parent = workspace
	self.arena = folder
	self:_lighting(map)
	workspace:SetAttribute("MapId", map.id)
	workspace:SetAttribute("MapName", map.name)
end

function WorldBuilder:Init(S)
	self.S = S
	self:_buildHub()
	self:BuildArena(Maps.List[1])
end

return WorldBuilder
