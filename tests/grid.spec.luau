local Loader = require("./loader")
local Grid = Loader.get("ReplicatedStorage.Shared.Grid")
local GridCodec = Loader.get("ReplicatedStorage.Shared.GridCodec")

-- Simulates a participant walking a list of (x, z) waypoints with the same rules as MatchService.
local function walkTrail(g, slot, path)
	local trail = {}
	for k = 2, #path do
		for _, i in g:walk(path[k - 1][1], path[k - 1][2], path[k][1], path[k][2]) do
			if g.owner[i] ~= slot then
				g:setTrail(i, slot)
				table.insert(trail, i)
			end
		end
	end
	return trail
end

return function(t)
	t.test("index/coords roundtrip", function()
		local g = Grid.new(10)
		for z = 1, 10 do
			for x = 1, 10 do
				local cx, cz = g:coords(g:index(x, z))
				t.eq(cx, x)
				t.eq(cz, z)
			end
		end
	end)

	t.test("walk is 4-connected and ends at target", function()
		local g = Grid.new(20)
		local cells = g:walk(2, 3, 9, 15)
		t.eq(#cells, 7 + 12, "manhattan length")
		local px, pz = 2, 3
		for _, i in cells do
			local x, z = g:coords(i)
			t.eq(math.abs(x - px) + math.abs(z - pz), 1, "unit step")
			px, pz = x, z
		end
		t.eq(px, 9)
		t.eq(pz, 15)
		t.eq(#g:walk(4, 4, 4, 4), 0, "no movement")
	end)

	t.test("claimSquare counts and skips blocked/trail", function()
		local g = Grid.new(10)
		g:setOwner(g:index(5, 5), -1)
		g:setTrail(g:index(4, 4), 7)
		local gained = g:claimSquare(1, 5, 5, 1)
		t.eq(gained, 7)
		t.eq(g:countOf(1), 7)
		t.eq(g:claimable(), 99)
	end)

	t.test("capture fills enclosed area", function()
		local g = Grid.new(20)
		g:claimSquare(1, 5, 5, 1) -- 4..6
		-- leave zone at (6,5) -> east to (12,5) -> south to (12,12) -> west to (5,12) -> north back to (5,6)
		local trail = walkTrail(g, 1, { { 6, 5 }, { 12, 5 }, { 12, 12 }, { 5, 12 }, { 5, 6 } })
		local gained = g:capture(1, trail)
		-- rectangle x 4..12, z 4..12 minus nothing outside; square 4..6 already owned (9 cells)
		-- enclosed region is x5..12, z5..12 plus original square => count everything owned
		local owned = g:countOf(1)
		t.ok(gained > 0, "gained")
		t.eq(owned, 9 + gained, "count consistency")
		t.eq(g.owner[g:index(9, 9)], 1, "interior claimed")
		t.eq(g.owner[g:index(13, 9)], 0, "outside untouched")
		for _, i in trail do
			t.eq(g.trail[i], 0, "trail cleared")
		end
	end)

	t.test("capture cuts trails enclosed inside the loop", function()
		local g = Grid.new(20)
		g:claimSquare(1, 3, 3, 1)
		g:setTrail(g:index(8, 8), 2) -- rival trail inside
		local trail = walkTrail(g, 1, { { 4, 3 }, { 14, 3 }, { 14, 14 }, { 3, 14 }, { 3, 4 } })
		local _, victims = g:capture(1, trail)
		t.ok(victims[2], "rival trail cut")
		t.eq(g.owner[g:index(8, 8)], 1)
	end)

	t.test("capture does not claim blocked cells", function()
		local g = Grid.new(20)
		g:setOwner(g:index(8, 8), -1)
		g:claimSquare(1, 3, 3, 1)
		local trail = walkTrail(g, 1, { { 4, 3 }, { 14, 3 }, { 14, 14 }, { 3, 14 }, { 3, 4 } })
		g:capture(1, trail)
		t.eq(g.owner[g:index(8, 8)], -1)
	end)

	t.test("loop along the border still encloses", function()
		local g = Grid.new(12)
		g:claimSquare(1, 2, 2, 1) -- 1..3
		local trail = walkTrail(g, 1, { { 3, 1 }, { 12, 1 }, { 12, 12 }, { 1, 12 }, { 1, 3 } })
		g:capture(1, trail)
		t.eq(g:countOf(1), 144, "whole map")
	end)

	t.test("clearSlot frees territory and trail", function()
		local g = Grid.new(10)
		g:claimSquare(3, 5, 5, 2)
		g:setTrail(g:index(1, 1), 3)
		local freed = g:clearSlot(3, { g:index(1, 1) })
		t.eq(freed, 25)
		t.eq(g:countOf(3), 0)
		t.eq(g.trail[g:index(1, 1)], 0)
	end)

	t.test("findSpawn prefers free squares", function()
		local g = Grid.new(10)
		g:claimSquare(1, 3, 3, 2)
		local seed = 1
		local function rng(lo, hi)
			seed = (seed * 16807) % 2147483647
			return lo + seed % (hi - lo + 1)
		end
		for _ = 1, 20 do
			local cx, cz = g:findSpawn(1, rng)
			t.ok(g:_squareFree(cx, cz, 1, true), "free spawn")
		end
	end)

	t.test("codec snapshot and delta roundtrip", function()
		local g = Grid.new(16)
		g:setOwner(5, -1)
		g:claimSquare(4, 8, 8, 2)
		g:setTrail(200, 9)
		local mirror = Grid.new(16)
		GridCodec.applySnapshot(mirror, GridCodec.snapshot(g))
		for i = 1, g.n do
			t.eq(mirror.owner[i], g.owner[i])
			t.eq(mirror.trail[i], g.trail[i])
		end
		t.eq(mirror:countOf(4), 25)
		g:takeDirty()
		g:setOwner(1, 4)
		g:setTrail(2, 4)
		local changed = GridCodec.applyDelta(mirror, GridCodec.delta(g, g:takeDirty()))
		t.eq(#changed, 2)
		t.eq(mirror.owner[1], 4)
		t.eq(mirror.trail[2], 4)
		t.eq(mirror:countOf(4), 26)
	end)

	t.test("dirty tracking dedupes", function()
		local g = Grid.new(4)
		g:setOwner(1, 1)
		g:setOwner(1, 2)
		g:setTrail(1, 3)
		t.eq(#g:takeDirty(), 1)
		t.eq(#g:takeDirty(), 0)
	end)
end
