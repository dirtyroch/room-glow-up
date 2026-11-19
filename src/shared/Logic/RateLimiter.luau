--!strict
-- Token bucket per key. `now` is passed in (the server uses os.clock()) so tests can drive it.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Bucket = { tokens: number, t: number }
export type Limiter = typeof(setmetatable(
	{} :: { capacity: number, refill: number, buckets: { [any]: Bucket } },
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
	local buckets = self.buckets
	local b = buckets[key]
	if not b then
		b = { tokens = self.capacity, t = now }
		buckets[key] = b
	end
	local elapsed = now - b.t
	if elapsed < 0 then
		elapsed = 0
	end
	b.tokens = math.min(self.capacity, b.tokens + elapsed * self.refill)
	b.t = now
	if b.tokens >= c then
		b.tokens -= c
		return true
	end
	return false
end

function RateLimiter.forget(self: Limiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
