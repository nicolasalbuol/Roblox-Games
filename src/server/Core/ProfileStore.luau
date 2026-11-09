-- Session-locked profile persistence on top of any store exposing UpdateAsync(key, transform).
-- One server owns a profile at a time; a server that loses the lock stops writing (no dupes).

local DataSchema = require(script.Parent.DataSchema)

local ProfileStore = {}
ProfileStore.__index = ProfileStore

local Profile = {}
Profile.__index = Profile

-- opts: store, jobId, now(), sleep(s), lockStale, attempts, retryDelay
function ProfileStore.new(opts)
	return setmetatable(opts, ProfileStore)
end

function ProfileStore:load(key: string)
	local lastErr = "unknown"
	for attempt = 1, self.attempts do
		local state, loaded = nil, nil
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(record)
				record = if type(record) == "table" then record else {}
				local now = self.now()
				local lock = record.lock
				if lock and lock.jobId ~= self.jobId and now - (lock.time or 0) < self.lockStale then
					state = "locked"
					return nil
				end
				local data, reason = DataSchema.load(record.data, now)
				if not data then
					state = reason
					return nil
				end
				record.data = data
				record.lock = { jobId = self.jobId, time = now }
				state, loaded = "ok", record
				return record
			end)
		end)
		if ok and state == "ok" then
			return setmetatable({ key = key, data = loaded.data, owner = self, lost = false, released = false }, Profile),
				nil
		elseif state == "newer" then
			return nil, "newer"
		end
		lastErr = if ok then tostring(state) else tostring(err)
		if attempt < self.attempts then
			self.sleep(self.retryDelay * attempt)
		end
	end
	return nil, lastErr
end

-- Writes data. release = true drops the session lock (player leaving / server closing).
function Profile:save(release: boolean?): boolean
	if self.lost or self.released then
		return false
	end
	local owner = self.owner
	local lostNow = false
	local ok, err = pcall(function()
		owner.store:UpdateAsync(self.key, function(record)
			record = if type(record) == "table" then record else {}
			local lock = record.lock
			if not lock or lock.jobId ~= owner.jobId then
				lostNow = true
				return nil
			end
			record.data = self.data
			record.lock = if release then nil else { jobId = owner.jobId, time = owner.now() }
			return record
		end)
	end)
	if lostNow then
		self.lost = true
		return false
	end
	if ok and release then
		self.released = true
	end
	if not ok then
		warn("[ProfileStore] save failed for " .. self.key .. ": " .. tostring(err))
	end
	return ok
end

return ProfileStore
