-- Pure territory grid shared by server (authority) and client (rendering mirror).
-- owner[i]: 0 neutral, -1 blocked, >0 participant slot. trail[i]: 0 or slot.

local Grid = {}
Grid.__index = Grid

Grid.BLOCKED = -1

function Grid.new(size: number)
	local n = size * size
	return setmetatable({
		size = size,
		n = n,
		owner = table.create(n, 0),
		trail = table.create(n, 0),
		counts = {},
		blocked = 0,
		dirtyList = {},
		dirtyFlag = table.create(n, false),
	}, Grid)
end

function Grid:index(x: number, z: number): number
	return (z - 1) * self.size + x
end

function Grid:coords(i: number): (number, number)
	local z = (i - 1) // self.size + 1
	return i - (z - 1) * self.size, z
end

function Grid:inBounds(x: number, z: number): boolean
	return x >= 1 and z >= 1 and x <= self.size and z <= self.size
end

function Grid:_mark(i: number)
	if not self.dirtyFlag[i] then
		self.dirtyFlag[i] = true
		table.insert(self.dirtyList, i)
	end
end

function Grid:setOwner(i: number, v: number)
	local old = self.owner[i]
	if old == v then
		return
	end
	if old > 0 then
		self.counts[old] = (self.counts[old] or 0) - 1
	elseif old == -1 then
		self.blocked -= 1
	end
	if v > 0 then
		self.counts[v] = (self.counts[v] or 0) + 1
	elseif v == -1 then
		self.blocked += 1
	end
	self.owner[i] = v
	self:_mark(i)
end

function Grid:setTrail(i: number, v: number)
	if self.trail[i] ~= v then
		self.trail[i] = v
		self:_mark(i)
	end
end

function Grid:countOf(slot: number): number
	return self.counts[slot] or 0
end

function Grid:claimable(): number
	return self.n - self.blocked
end

function Grid:percentOf(slot: number): number
	local c = self:claimable()
	return c > 0 and self:countOf(slot) / c * 100 or 0
end

function Grid:takeDirty(): { number }
	local list = self.dirtyList
	for _, i in list do
		self.dirtyFlag[i] = false
	end
	self.dirtyList = {}
	return list
end

function Grid:reset()
	for i = 1, self.n do
		self:setOwner(i, 0)
		self:setTrail(i, 0)
	end
end

-- 4-connected walk from (x0,z0) to (x1,z1), excluding the start cell.
-- 4-connectivity guarantees that two crossing paths always share a cell.
function Grid:walk(x0: number, z0: number, x1: number, z1: number): { number }
	local cells = {}
	local dx, dz = math.abs(x1 - x0), math.abs(z1 - z0)
	local sx, sz = if x1 > x0 then 1 else -1, if z1 > z0 then 1 else -1
	local x, z, ix, iz = x0, z0, 0, 0
	while ix < dx or iz < dz do
		if (0.5 + ix) * dz < (0.5 + iz) * dx then
			x += sx
			ix += 1
		else
			z += sz
			iz += 1
		end
		cells[#cells + 1] = self:index(x, z)
	end
	return cells
end

-- Turns slot's trail into territory and fills every region it encloses.
-- Returns (cells gained, set of victim slots whose trail lay inside the enclosure).
function Grid:capture(slot: number, trailCells: { number }): (number, { [number]: boolean })
	local before = self:countOf(slot)
	local owner, trail, size, n = self.owner, self.trail, self.size, self.n
	for _, i in trailCells do
		if trail[i] == slot then
			self:setTrail(i, 0)
		end
		if owner[i] ~= -1 then
			self:setOwner(i, slot)
		end
	end

	-- Flood the "outside" from the border through every cell not owned by slot.
	local visited = table.create(n, false)
	local queue = {}
	local function push(i)
		if not visited[i] and owner[i] ~= slot then
			visited[i] = true
			queue[#queue + 1] = i
		end
	end
	for x = 1, size do
		push(x)
		push((size - 1) * size + x)
	end
	for z = 2, size - 1 do
		push((z - 1) * size + 1)
		push(z * size)
	end
	local head = 1
	while head <= #queue do
		local i = queue[head]
		head += 1
		local x = (i - 1) % size + 1
		if x > 1 then
			push(i - 1)
		end
		if x < size then
			push(i + 1)
		end
		if i > size then
			push(i - size)
		end
		if i <= n - size then
			push(i + size)
		end
	end

	local victims = {}
	for i = 1, n do
		local o = owner[i]
		if not visited[i] and o ~= slot and o ~= -1 then
			local t = trail[i]
			if t ~= 0 and t ~= slot then
				victims[t] = true
			end
			self:setOwner(i, slot)
		end
	end
	return self:countOf(slot) - before, victims
end

-- Claims a square around (cx,cz). Never touches blocked or trail cells.
function Grid:claimSquare(slot: number, cx: number, cz: number, r: number): number
	local gained = 0
	for z = cz - r, cz + r do
		for x = cx - r, cx + r do
			if self:inBounds(x, z) then
				local i = self:index(x, z)
				if self.owner[i] ~= -1 and self.owner[i] ~= slot and self.trail[i] == 0 then
					self:setOwner(i, slot)
					gained += 1
				end
			end
		end
	end
	return gained
end

-- Removes all territory and trail of slot. Returns cells freed.
function Grid:clearSlot(slot: number, trailCells: { number }?): number
	if trailCells then
		for _, i in trailCells do
			if self.trail[i] == slot then
				self:setTrail(i, 0)
			end
		end
	end
	local freed = 0
	for i = 1, self.n do
		if self.owner[i] == slot then
			self:setOwner(i, 0)
			freed += 1
		end
		if self.trail[i] == slot then
			self:setTrail(i, 0)
		end
	end
	return freed
end

function Grid:_squareFree(cx: number, cz: number, r: number, strict: boolean): boolean
	for z = cz - r, cz + r do
		for x = cx - r, cx + r do
			local i = self:index(x, z)
			if self.trail[i] ~= 0 or self.owner[i] == -1 or (strict and self.owner[i] ~= 0) then
				return false
			end
		end
	end
	return true
end

-- Finds a spawn centre whose square is free. rng: function(min, max) -> integer.
function Grid:findSpawn(r: number, rng: (number, number) -> number): (number, number)
	local lo, hi = 1 + r, self.size - r
	for pass = 1, 2 do
		for _ = 1, 60 do
			local cx, cz = rng(lo, hi), rng(lo, hi)
			if self:_squareFree(cx, cz, r, pass == 1) then
				return cx, cz
			end
		end
	end
	return rng(lo, hi), rng(lo, hi)
end

return Grid
