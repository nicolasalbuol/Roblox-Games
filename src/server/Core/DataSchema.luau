-- Versioned player data schema: defaults, migrations, reconciliation, sanitizing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Config = require(ReplicatedStorage.Shared.Config)

local DataSchema = {}

DataSchema.Version = 1

function DataSchema.defaults(now: number)
	return {
		version = DataSchema.Version,
		coins = 0,
		xp = 0,
		level = 1,
		stats = {
			rounds = 0,
			wins = 0,
			kills = 0,
			deaths = 0,
			captures = 0,
			tilesClaimed = 0,
			bestPercent = 0,
			bestLoop = 0,
			powerups = 0,
			robuxSpent = 0,
		},
		owned = {},
		equipped = table.clone(Cosmetics.Defaults),
		achievements = {},
		quests = { day = -1, list = {} },
		daily = { lastDay = -1, step = 0 },
		settings = { sfx = 0.8, music = 0.5, camera = "top", reducedFx = false },
		tutorialDone = false,
		tutorialStep = 0,
		receipts = {},
		firstJoin = now,
		lastJoin = now,
		sessions = 0,
	}
end

-- Migrations[n] upgrades a record from version n to n + 1. Add entries, never edit shipped ones.
DataSchema.Migrations = {} :: { [number]: (any) -> any }

local function reconcile(target, template)
	for k, v in template do
		local cur = target[k]
		if cur == nil or typeof(cur) ~= typeof(v) then
			target[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(cur, v)
		end
	end
end

local function sane(n: number, lo: number, hi: number): number
	if n ~= n then -- NaN
		return lo
	end
	return math.clamp(math.floor(n), lo, hi)
end

-- Turns whatever is stored into a valid current-version record.
-- Returns nil, reason when the record must not be touched (written by a newer game version).
function DataSchema.load(raw: any, now: number): (any, string?)
	if type(raw) ~= "table" then
		return DataSchema.defaults(now), nil
	end
	local data = raw
	if type(data.version) ~= "number" then
		data.version = 0
	end
	if data.version > DataSchema.Version then
		return nil, "newer"
	end
	while data.version < DataSchema.Version do
		local m = DataSchema.Migrations[data.version]
		if m then
			data = m(data)
		end
		data.version += 1
	end
	reconcile(data, DataSchema.defaults(now))
	data.coins = sane(data.coins, 0, Config.Economy.MaxCoins)
	data.level = sane(data.level, 1, Config.Progression.MaxLevel)
	data.xp = sane(data.xp, 0, 1e9)
	for slot, default in Cosmetics.Defaults do
		if type(data.equipped[slot]) ~= "string" or Cosmetics.get(data.equipped[slot]) == nil then
			data.equipped[slot] = default
		end
	end
	return data, nil
end

-- What the client is allowed to see (everything except receipt history).
function DataSchema.publicView(data)
	local view = table.clone(data)
	view.receipts = nil
	return view
end

return DataSchema
