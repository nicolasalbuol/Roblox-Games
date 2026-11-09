-- Persistence, session locking, migrations, receipts, rate limiting.
local Loader = require("./loader")

local DataSchema = Loader.get("ServerScriptService.Server.Core.DataSchema")
local ProfileStore = Loader.get("ServerScriptService.Server.Core.ProfileStore")
local MemoryStore = Loader.get("ServerScriptService.Server.Core.MemoryStore")
local ReceiptLogic = Loader.get("ServerScriptService.Server.Core.ReceiptLogic")
local RateLimiter = Loader.get("ServerScriptService.Server.Core.RateLimiter")

local clock = 1000

local function server(store, jobId: string)
	return ProfileStore.new({
		store = store,
		jobId = jobId,
		now = function()
			return clock
		end,
		sleep = function() end,
		lockStale = 600,
		attempts = 3,
		retryDelay = 1,
	})
end

return function(t)
	t.test("new profile gets defaults and a session lock", function()
		local store = MemoryStore.new()
		local p = assert(server(store, "A"):load("u_1"))
		t.eq(p.data.coins, 0)
		t.eq(p.data.version, DataSchema.Version)
		t.eq(store.values.u_1.lock.jobId, "A")
	end)

	t.test("a locked profile cannot be loaded by another server", function()
		local store = MemoryStore.new()
		assert(server(store, "A"):load("u_1"))
		local p, err = server(store, "B"):load("u_1")
		t.eq(p, nil)
		t.eq(err, "locked")
	end)

	t.test("release hands data to the next server", function()
		local store = MemoryStore.new()
		local a = assert(server(store, "A"):load("u_1"))
		a.data.coins = 777
		t.ok(a:save(true), "release save")
		t.eq(store.values.u_1.lock, nil)
		local b = assert(server(store, "B"):load("u_1"))
		t.eq(b.data.coins, 777)
		t.ok(not a:save(false), "released profile never writes again")
	end)

	t.test("stale lock is taken over; old server detects loss and stops writing", function()
		local store = MemoryStore.new()
		local a = assert(server(store, "A"):load("u_1"))
		a.data.coins = 5
		a:save(false)
		clock += 601
		local b = assert(server(store, "B"):load("u_1"))
		b.data.coins = 50
		b:save(false)
		a.data.coins = 999999 -- would be a dupe if written
		t.ok(not a:save(false), "A save refused")
		t.ok(a.lost, "A marked lost")
		t.eq(store.values.u_1.data.coins, 50)
	end)

	t.test("transient DataStore errors are retried", function()
		local store = MemoryStore.new()
		store.failNext = 2
		local p = server(store, "A"):load("u_1")
		t.ok(p ~= nil, "loaded on 3rd attempt")
	end)

	t.test("all attempts failing returns an error (caller kicks, never blank-saves)", function()
		local store = MemoryStore.new()
		store.failNext = 3
		local p, err = server(store, "A"):load("u_1")
		t.eq(p, nil)
		t.ok(string.find(err, "simulated") ~= nil, "error surfaced")
		t.eq(store.writes, 0)
	end)

	t.test("data from a newer game version is never overwritten", function()
		local store = MemoryStore.new()
		store.values.u_1 = { data = { version = DataSchema.Version + 1, coins = 5 } }
		local p, err = server(store, "A"):load("u_1")
		t.eq(p, nil)
		t.eq(err, "newer")
		t.eq(store.writes, 0)
	end)

	t.test("migrations run in order and defaults reconcile", function()
		DataSchema.Migrations[0] = function(d)
			d.coins = d.money
			d.money = nil
			return d
		end
		local data = DataSchema.load({ money = 42, stats = { wins = 3 }, equipped = { ink = "nope" } }, 0)
		DataSchema.Migrations[0] = nil
		t.eq(data.version, DataSchema.Version)
		t.eq(data.coins, 42)
		t.eq(data.stats.wins, 3, "existing stat kept")
		t.eq(data.stats.kills, 0, "missing stat filled")
		t.eq(data.equipped.ink, "ink_mint", "invalid cosmetic reset")
		t.eq(data.settings.camera, "top")
	end)

	t.test("corrupt numbers are sanitized", function()
		local data = DataSchema.load({ version = DataSchema.Version, coins = 0 / 0, level = 9999, xp = -5 }, 0)
		t.eq(data.coins, 0)
		t.eq(data.level, 100)
		t.eq(data.xp, 0)
	end)

	t.test("public view hides receipts", function()
		local d = DataSchema.defaults(0)
		d.receipts.x = 1
		t.eq(DataSchema.publicView(d).receipts, nil)
		t.eq(d.receipts.x, 1, "original untouched")
	end)

	local function receiptDeps(profile, opts)
		opts = opts or {}
		local grants = 0
		local deps = {
			maxHistory = opts.max or 60,
			now = function()
				clock += 1
				return clock
			end,
			getProfile = function()
				return profile
			end,
			grant = function(p)
				grants += 1
				p.data.coins += 100
				return true
			end,
			save = function()
				return opts.saveOk ~= false
			end,
		}
		return deps, function()
			return grants
		end
	end

	t.test("receipts grant exactly once", function()
		local profile = { data = DataSchema.defaults(0) }
		local deps, grants = receiptDeps(profile)
		local info = { PlayerId = 1, PurchaseId = "abc", ProductId = 5 }
		t.eq(ReceiptLogic.process(info, deps), "Granted")
		t.eq(ReceiptLogic.process(info, deps), "Granted")
		t.eq(grants(), 1)
		t.eq(profile.data.coins, 100)
	end)

	t.test("receipt is not acknowledged until saved; retry does not double grant", function()
		local profile = { data = DataSchema.defaults(0) }
		local opts = { saveOk = false }
		local deps, grants = receiptDeps(profile, opts)
		local info = { PlayerId = 1, PurchaseId = "p1", ProductId = 5 }
		t.eq(ReceiptLogic.process(info, deps), "NotProcessedYet")
		opts.saveOk = true
		deps = receiptDeps(profile, opts)
		t.eq(ReceiptLogic.process(info, deps), "Granted")
		t.eq(grants(), 1)
		t.eq(profile.data.coins, 100)
	end)

	t.test("receipt without a loaded profile waits", function()
		local deps = receiptDeps(nil)
		t.eq(ReceiptLogic.process({ PlayerId = 1, PurchaseId = "z", ProductId = 1 }, deps), "NotProcessedYet")
	end)

	t.test("unknown product is not acknowledged", function()
		local profile = { data = DataSchema.defaults(0) }
		local deps = receiptDeps(profile)
		deps.grant = function()
			return false
		end
		t.eq(ReceiptLogic.process({ PlayerId = 1, PurchaseId = "q", ProductId = 999 }, deps), "NotProcessedYet")
		t.eq(profile.data.receipts.q, nil)
	end)

	t.test("receipt history is trimmed to the newest entries", function()
		local profile = { data = DataSchema.defaults(0) }
		local deps = receiptDeps(profile, { max = 3 })
		for k = 1, 6 do
			ReceiptLogic.process({ PlayerId = 1, PurchaseId = "r" .. k, ProductId = 1 }, deps)
		end
		local n = 0
		for _ in profile.data.receipts do
			n += 1
		end
		t.eq(n, 3)
		t.ok(profile.data.receipts.r6 ~= nil, "newest kept")
		t.eq(profile.data.receipts.r1, nil, "oldest dropped")
	end)

	t.test("rate limiter allows bursts and refills", function()
		local c = 0
		local rl = RateLimiter.new(3, 1, function()
			return c
		end)
		t.ok(rl:allow("p") and rl:allow("p") and rl:allow("p"), "burst")
		t.ok(not rl:allow("p"), "blocked")
		c = 1
		t.ok(rl:allow("p"), "refilled")
		t.ok(rl:allow("other"), "independent keys")
	end)
end
