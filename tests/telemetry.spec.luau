-- Analytics failures (missing API, bad enum, throttling) must never propagate into gameplay.
local Loader = require("./loader")

local calls = {}
Loader.services.AnalyticsService = setmetatable({}, {
	__index = function(_, method)
		return function(_, ...)
			table.insert(calls, { method, ... })
			error("analytics unavailable")
		end
	end,
})
Loader.services.HttpService = { GenerateGUID = function()
	return "guid"
end }
Loader.services.RunService = Loader.services.RunService or { IsStudio = function()
	return false
end }

local Telemetry = Loader.get("ServerScriptService.Server.Services.TelemetryService")

return function(t)
	t.test("every telemetry call swallows analytics errors", function()
		local player = {}
		Telemetry:Onboarding(player, 1, "Spawned")
		Telemetry:StoreFunnel(player, 1, "OpenStore", true)
		Telemetry:Economy(player, "Source", 10, 10, "Gameplay", "RoundReward")
		Telemetry:Custom(player, "RoundEnd", 1, { "neon_plaza", "12", "0" })
		t.ok(#calls >= 3, "analytics was attempted")
		t.eq(Telemetry.counters.RoundEnd, 1, "local counters still work")
	end)
end
