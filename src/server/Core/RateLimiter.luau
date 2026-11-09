-- Token-bucket rate limiter keyed by any value (usually a Player).
local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(capacity: number, refillPerSecond: number, clock: (() -> number)?)
	return setmetatable({
		capacity = capacity,
		refill = refillPerSecond,
		clock = clock or os.clock,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter:allow(key: any): boolean
	local now = self.clock()
	local b = self.buckets[key]
	if not b then
		b = { tokens = self.capacity, at = now }
		self.buckets[key] = b
	end
	b.tokens = math.min(self.capacity, b.tokens + (now - b.at) * self.refill)
	b.at = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function RateLimiter:forget(key: any)
	self.buckets[key] = nil
end

return RateLimiter
