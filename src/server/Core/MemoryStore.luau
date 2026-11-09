-- In-memory stand-in for a DataStore (Studio without API access, and tests).
-- Values are deep-copied to mimic serialization. failNext forces errors for failure tests.
local MemoryStore = {}
MemoryStore.__index = MemoryStore

local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end

function MemoryStore.new()
	return setmetatable({ values = {}, failNext = 0, writes = 0 }, MemoryStore)
end

function MemoryStore:UpdateAsync(key: string, transform)
	if self.failNext > 0 then
		self.failNext -= 1
		error("simulated DataStore failure")
	end
	local result = transform(copy(self.values[key]))
	if result ~= nil then
		self.values[key] = copy(result)
		self.writes += 1
	end
	return copy(self.values[key])
end

return MemoryStore
