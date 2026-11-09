-- Arena themes. Obstacles are inclusive cell rectangles {x1, z1, x2, z2} (1..Grid.Size) that block claiming.
-- Colors are {r, g, b}.

local Maps = {}

Maps.List = {
	{
		id = "neon_plaza",
		name = "Neon Plaza",
		tileA = { 30, 34, 58 },
		tileB = { 36, 41, 68 },
		floor = { 22, 24, 42 },
		wall = { 80, 230, 255 },
		accent = { 255, 70, 200 },
		obstacleMaterial = "Neon",
		obstacleColor = { 120, 90, 255 },
		decor = "towers",
		lighting = {
			ClockTime = 20.5,
			Ambient = { 70, 60, 110 },
			OutdoorAmbient = { 90, 80, 140 },
			Brightness = 1.5,
			Atmosphere = { 0.3, { 120, 90, 200 } },
			Tint = { 245, 235, 255 },
		},
		obstacles = { { 12, 12, 13, 13 }, { 28, 12, 29, 13 }, { 12, 28, 13, 29 }, { 28, 28, 29, 29 } },
	},
	{
		id = "sunset_docks",
		name = "Sunset Docks",
		tileA = { 196, 160, 118 },
		tileB = { 182, 146, 104 },
		floor = { 150, 112, 76 },
		wall = { 255, 170, 90 },
		accent = { 60, 170, 210 },
		obstacleMaterial = "WoodPlanks",
		obstacleColor = { 140, 92, 56 },
		decor = "docks",
		lighting = {
			ClockTime = 17.6,
			Ambient = { 120, 90, 70 },
			OutdoorAmbient = { 160, 120, 90 },
			Brightness = 2.2,
			Atmosphere = { 0.35, { 255, 170, 120 } },
			Tint = { 255, 240, 225 },
		},
		obstacles = { { 19, 19, 22, 22 }, { 8, 17, 9, 24 }, { 32, 17, 33, 24 } },
	},
	{
		id = "frost_grid",
		name = "Frost Grid",
		tileA = { 214, 232, 245 },
		tileB = { 198, 220, 238 },
		floor = { 170, 200, 225 },
		wall = { 140, 220, 255 },
		accent = { 255, 255, 255 },
		obstacleMaterial = "Glass",
		obstacleColor = { 150, 220, 255 },
		decor = "crystals",
		lighting = {
			ClockTime = 13,
			Ambient = { 120, 140, 170 },
			OutdoorAmbient = { 150, 170, 200 },
			Brightness = 2.6,
			Atmosphere = { 0.25, { 210, 235, 255 } },
			Tint = { 235, 245, 255 },
		},
		obstacles = {
			{ 6, 6, 7, 7 },
			{ 34, 6, 35, 7 },
			{ 6, 34, 7, 35 },
			{ 34, 34, 35, 35 },
			{ 19, 10, 22, 11 },
			{ 19, 30, 22, 31 },
		},
	},
}

local byId = {}
for _, m in Maps.List do
	byId[m.id] = m
end

function Maps.get(id: string)
	return byId[id]
end

-- Calls fn(x, z) for every blocked cell of the map.
function Maps.forEachBlocked(map, fn: (number, number) -> ())
	for _, r in map.obstacles do
		for z = r[2], r[4] do
			for x = r[1], r[3] do
				fn(x, z)
			end
		end
	end
end

return Maps
