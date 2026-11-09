-- Test runner: lune run tests/run.luau  (from the repo root)
local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0
local failures = {}

local t = {}

function t.eq(actual, expected, msg)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", msg or "eq", tostring(expected), tostring(actual)), 2)
	end
end

function t.ok(cond, msg)
	if not cond then
		error(msg or "expected truthy", 2)
	end
end

local current = ""
function t.test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		table.insert(failures, current .. " > " .. name .. "\n    " .. tostring(err))
	end
end

local files = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

local filter = process.args[1]
for _, name in files do
	if not filter or string.find(name, filter, 1, true) then
		current = name
		local spec = require("./" .. string.gsub(name, "%.luau$", ""))
		spec(t)
	end
end

print(string.format("\n%d passed, %d failed", passed, failed))
for _, f in failures do
	print("FAIL " .. f)
end
process.exit(if failed == 0 then 0 else 1)
