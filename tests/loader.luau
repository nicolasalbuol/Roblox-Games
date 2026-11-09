-- Loads game ModuleScripts unchanged under Lune by emulating `script`, `require(instance)` and `game:GetService`.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Loader = {}

local ROOTS = {
	ReplicatedStorage = { Shared = "src/shared" },
	ServerScriptService = { Server = "src/server" },
	StarterPlayerScripts = { Client = "src/client" },
}

Loader.services = {} -- test-provided stubs for other services, e.g. RunService
Loader.mocks = {} -- file path -> module value, e.g. ["src/shared/Net.luau"] = fakeNet
Loader.clock = os.clock -- tests may replace with a fake clock
Loader.workspace = nil -- tests may provide a fake workspace
Loader.env = {} -- extra/overriding globals for every module loaded afterwards (e.g. a proxied Instance)

-- Lune has no Roblox Random; deterministic polyfill with the same surface we use.
local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	return setmetatable({ s = (seed or 12345) % 2147483647 }, Random)
end
function Random:NextNumber(lo: number?, hi: number?): number
	self.s = (self.s * 48271) % 2147483647
	local u = self.s / 2147483647
	return if lo then lo + (hi - lo) * u else u
end
function Random:NextInteger(lo: number, hi: number): number
	return math.min(hi, lo + math.floor(self:NextNumber() * (hi - lo + 1)))
end
Loader.Random = Random

local fakeOs = setmetatable({
	clock = function()
		return Loader.clock()
	end,
}, { __index = os })

local cache = {}
local NodeMeta = {}

-- fs calls yield, which is not allowed inside __index, so index the source tree up front.
local DIRS, FILES = {}, {}
local function scan(dir: string)
	DIRS[dir] = true
	for _, name in fs.readDir(dir) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			scan(p)
		else
			FILES[p] = true
		end
	end
end
scan("src")

local function newNode(name: string, parent, dir: string?, file: string?, children)
	return setmetatable({ Name = name, Parent = parent, __dir = dir, __file = file, __children = children }, NodeMeta)
end

local function child(node, name: string)
	local children, dir = rawget(node, "__children"), rawget(node, "__dir")
	if children then
		local mapped = children[name]
		return mapped and newNode(name, node, mapped, nil, nil)
	end
	if dir then
		local base = dir .. "/" .. name
		if DIRS[base] then
			return newNode(name, node, base, nil, nil)
		end
		for _, ext in { ".luau", ".lua" } do
			if FILES[base .. ext] then
				return newNode(name, node, nil, base .. ext, nil)
			end
		end
	end
	return nil
end

NodeMeta.__index = function(node, key)
	if key == "WaitForChild" then
		return function(self, name)
			return assert(child(self, name), "missing child " .. name)
		end
	elseif key == "FindFirstChild" then
		return function(self, name)
			return child(self, name)
		end
	end
	return child(node, key) or error("no child '" .. tostring(key) .. "' in " .. tostring(rawget(node, "Name")))
end

local fakeGame = {
	GetService = function(_, name)
		if ROOTS[name] then
			return newNode(name, nil, nil, nil, ROOTS[name])
		end
		return Loader.services[name] or error("service not stubbed in tests: " .. name)
	end,
}

local requireNode

local function environment(node)
	return {
		script = node,
		require = requireNode,
		game = fakeGame,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		Instance = roblox.Instance,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberRange = roblox.NumberRange,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		task = task,
		Random = Random,
		os = fakeOs,
		workspace = setmetatable({}, {
			__index = function(_, k)
				return assert(Loader.workspace, "workspace not stubbed")[k]
			end,
		}),
		debug = debug,
		warn = function(...)
			if Loader.verbose then
				print("[warn]", ...)
			end
		end,
	}
end

local function withOverrides(env)
	for k, v in Loader.env do
		env[k] = v
	end
	return env
end

requireNode = function(node)
	if type(node) == "string" then
		return require(node)
	end
	local file = assert(rawget(node, "__file"), "require target is not a module")
	if Loader.mocks[file] ~= nil then
		return Loader.mocks[file]
	end
	if cache[file] == nil then
		local fn = luau.load(fs.readFile(file), { debugName = file, environment = withOverrides(environment(node)) })
		cache[file] = fn()
	end
	return cache[file]
end

-- Loads a module by Roblox-style path, e.g. Loader.get("ReplicatedStorage.Shared.Grid").
function Loader.get(path: string)
	local parts = string.split(path, ".")
	local node = fakeGame:GetService(parts[1])
	for k = 2, #parts do
		node = node[parts[k]]
	end
	return requireNode(node)
end

-- Runs a Script/LocalScript file whose `script.Parent` is the node at parentPath.
function Loader.runScript(file: string, parentPath: string)
	local parts = string.split(parentPath, ".")
	local parent = fakeGame:GetService(parts[1])
	for k = 2, #parts do
		parent = parent[parts[k]]
	end
	local node = newNode("Script", parent, nil, file, nil)
	local fn = luau.load(fs.readFile(file), { debugName = file, environment = withOverrides(environment(node)) })
	return fn()
end

function Loader.reset()
	table.clear(cache)
end

return Loader
