-- Remote definitions. The server creates them; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local DEFS = {
	Request = "RemoteFunction", -- client -> server actions (buy, equip, claim...), validated + rate limited
	ClientEvent = "RemoteEvent", -- client -> server telemetry hints (shop opened, tutorial step seen)
	Profile = "RemoteEvent", -- server -> client: public profile snapshot
	Match = "RemoteEvent", -- server -> client: match events (state, capture, elimination, results)
	Roster = "RemoteEvent", -- server -> client: slot -> participant info
	GridSnapshot = "RemoteEvent", -- server -> client: full grid buffer + map id
	GridDelta = "RemoteEvent", -- server -> client: changed cells buffer
	BotPos = "UnreliableRemoteEvent", -- server -> client: bot positions (lossy is fine)
	Notify = "RemoteEvent", -- server -> client: toast messages
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for name, class in DEFS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new(class)
			r.Name = name
			r.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for name in DEFS do
	Net[name] = folder:WaitForChild(name)
end

return Net
