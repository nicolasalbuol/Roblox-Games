-- Opens the built place file and checks the instance tree Studio will load.
-- Usage: lune run scripts/verify-place.luau release/ChromaTurf.rbxlx
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or "release/ChromaTurf.rbxlx"
local game = roblox.deserializePlace(fs.readFile(path))
local failures = 0
local function expect(cond, msg)
	print((if cond then "  ok   " else "  FAIL ") .. msg)
	if not cond then
		failures += 1
	end
end

local function find(root, dotted)
	local node = root
	for _, name in string.split(dotted, ".") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local server = find(game, "ServerScriptService.Server.Main")
expect(server ~= nil and server.ClassName == "Script", "ServerScriptService.Server.Main is a Script")
local client = find(game, "StarterPlayer.StarterPlayerScripts.Client.Main")
expect(client ~= nil and client.ClassName == "LocalScript", "StarterPlayerScripts.Client.Main is a LocalScript")
for _, name in { "Config", "Grid", "GridCodec", "Cosmetics", "Progression", "Maps", "Net", "Signal" } do
	local m = find(game, "ReplicatedStorage.Shared." .. name)
	expect(m ~= nil and m.ClassName == "ModuleScript", "ReplicatedStorage.Shared." .. name)
end
local services = find(game, "ServerScriptService.Server.Services")
local count = 0
for _, s in services:GetChildren() do
	if s.ClassName == "ModuleScript" then
		count += 1
	end
end
expect(count == 12, "12 server services (" .. count .. ")")

local scripts, bad = 0, 0
for _, inst in game:GetDescendants() do
	if inst:IsA("LuaSourceContainer") then
		scripts += 1
		local ok = pcall(luau.compile, inst.Source)
		if not ok then
			bad += 1
			print("  FAIL compile " .. inst:GetFullName())
		end
	end
end
expect(bad == 0, string.format("%d scripts in place compile", scripts))
local lighting = game:GetService("Lighting")
expect(lighting.Technology == roblox.Enum.Technology.ShadowMap, "Lighting.Technology = ShadowMap")
expect(game:GetService("Workspace").StreamingEnabled == false, "StreamingEnabled off (small arena, client tiles)")
expect(game:GetService("Players").RespawnTime == 2, "Players.RespawnTime = 2")

print(if failures == 0 then "PLACE OK" else failures .. " place check(s) failed")
process.exit(if failures == 0 then 0 else 1)
