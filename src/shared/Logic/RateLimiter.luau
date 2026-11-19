--!strict
-- Token bucket per key. `now` is passed in (the server uses os.clock()) so tests
-- can drive the clock. Same shape as the Cookout action limiter: a burst, then
-- a steady refill, with independent buckets per key.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Limiter = typeof(setmetatable(
	{} :: {
		capacity: number,
		refill: number,
		buckets: { [any]: { tokens: number, t: number } },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number): Limiter
	return setmetatable({
		capacity = capacity,
		refill = refillPerSecond,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter.allow(self: Limiter, key: any, now: number, cost: number?): boolean
	local c = cost or 1
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.capacity, t = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.capacity, bucket.tokens + (now - bucket.t) * self.refill)
	bucket.t = now
	if bucket.tokens >= c then
		bucket.tokens -= c
		return true
	end
	return false
end

function RateLimiter.forget(self: Limiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
