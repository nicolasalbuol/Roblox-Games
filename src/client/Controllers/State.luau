-- Client-side mirror of server state + signals. The client never decides outcomes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local GridCodec = require(ReplicatedStorage.Shared.GridCodec)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Net = require(ReplicatedStorage.Shared.Net)

local LocalPlayer = Players.LocalPlayer

local State = {
	profile = nil,
	passes = {},
	roster = {},
	bySlot = {},
	mySlot = nil,
	mapId = nil,
	grid = nil,
	ProfileChanged = Signal.new(),
	RosterChanged = Signal.new(),
	GridReset = Signal.new(),
	GridChanged = Signal.new(),
	MatchEvent = Signal.new(),
	Notify = Signal.new(),
}

local GRAY = Color3.fromRGB(120, 120, 140)

function State:ColorOf(slot: number): Color3
	local e = self.bySlot[slot]
	return e and e.color3 or GRAY
end

function State:NameOf(slot: number): string
	local e = self.bySlot[slot]
	return e and e.name or "?"
end

function State:RoundState(): (string, number)
	return workspace:GetAttribute("RoundState") or "Intermission", workspace:GetAttribute("RoundEndsAt") or 0
end

function State:Request(action: string, arg: any)
	local ok, res = pcall(Net.Request.InvokeServer, Net.Request, action, arg)
	if not ok or type(res) ~= "table" then
		return { ok = false, err = "network" }
	end
	return res
end

function State:Event(kind: string, arg: any)
	Net.ClientEvent:FireServer(kind, arg)
end

function State:Start()
	Net.Profile.OnClientEvent:Connect(function(data, passes)
		self.profile = data
		self.passes = passes or {}
		self.ProfileChanged:Fire(data)
	end)
	Net.Roster.OnClientEvent:Connect(function(list)
		self.roster, self.bySlot, self.mySlot = list, {}, nil
		for _, e in list do
			e.color3 = Color3.fromRGB(e.color[1], e.color[2], e.color[3])
			self.bySlot[e.slot] = e
			if not e.isBot and e.userId == LocalPlayer.UserId then
				self.mySlot = e.slot
			end
		end
		self.RosterChanged:Fire()
	end)
	Net.GridSnapshot.OnClientEvent:Connect(function(mapId, buf)
		local g = Grid.new(Config.Grid.Size)
		GridCodec.applySnapshot(g, buf)
		g:takeDirty()
		self.grid, self.mapId = g, mapId
		self.GridReset:Fire(mapId)
	end)
	Net.GridDelta.OnClientEvent:Connect(function(buf)
		if self.grid then
			local changed = GridCodec.applyDelta(self.grid, buf)
			self.grid:takeDirty()
			self.GridChanged:Fire(changed)
		end
	end)
	Net.Match.OnClientEvent:Connect(function(evt)
		self.MatchEvent:Fire(evt)
	end)
	Net.Notify.OnClientEvent:Connect(function(text, style)
		self.Notify:Fire(text, style)
	end)
end

return State
