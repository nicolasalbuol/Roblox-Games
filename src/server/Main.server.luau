-- Server bootstrap: require every service, Init (wire dependencies), then Start.
local Services = script.Parent.Services

local ORDER = {
	"TelemetryService",
	"DataService",
	"MonetizationService",
	"EconomyService",
	"QuestService",
	"WorldBuilder",
	"AvatarService",
	"PowerupService",
	"BotService",
	"MatchService",
	"LeaderboardService",
	"RequestRouter",
}

local registry = {}
for _, name in ORDER do
	registry[name] = require(Services[name])
end
for _, name in ORDER do
	local s = registry[name]
	if s.Init then
		s:Init(registry)
	end
end
for _, name in ORDER do
	local s = registry[name]
	if s.Start then
		task.spawn(s.Start, s)
	end
end

print(string.format("[ChromaTurf] server started (%d services)", #ORDER))
