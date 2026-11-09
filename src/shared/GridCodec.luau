-- Compact binary encoding of grid state for RemoteEvents (buffers replicate natively).
-- Snapshot: 2 bytes per cell. Delta: 4 bytes per changed cell.

local GridCodec = {}

local function encodeSlot(v: number): number
	return if v < 0 then 255 else v
end

local function decodeSlot(b: number): number
	return if b == 255 then -1 else b
end

function GridCodec.snapshot(grid): buffer
	local buf = buffer.create(grid.n * 2)
	for i = 1, grid.n do
		buffer.writeu8(buf, (i - 1) * 2, encodeSlot(grid.owner[i]))
		buffer.writeu8(buf, (i - 1) * 2 + 1, grid.trail[i])
	end
	return buf
end

function GridCodec.applySnapshot(grid, buf: buffer)
	for i = 1, grid.n do
		grid:setOwner(i, decodeSlot(buffer.readu8(buf, (i - 1) * 2)))
		grid:setTrail(i, buffer.readu8(buf, (i - 1) * 2 + 1))
	end
end

function GridCodec.delta(grid, cells: { number }): buffer
	local buf = buffer.create(#cells * 4)
	for k, i in cells do
		local o = (k - 1) * 4
		buffer.writeu16(buf, o, i)
		buffer.writeu8(buf, o + 2, encodeSlot(grid.owner[i]))
		buffer.writeu8(buf, o + 3, grid.trail[i])
	end
	return buf
end

-- Applies a delta; returns the list of changed cell indices.
function GridCodec.applyDelta(grid, buf: buffer): { number }
	local changed = {}
	for o = 0, buffer.len(buf) - 4, 4 do
		local i = buffer.readu16(buf, o)
		if i >= 1 and i <= grid.n then
			grid:setOwner(i, decodeSlot(buffer.readu8(buf, o + 2)))
			grid:setTrail(i, buffer.readu8(buf, o + 3))
			changed[#changed + 1] = i
		end
	end
	return changed
end

return GridCodec
