-- Compiles every Luau source file (syntax check). Usage: lune run scripts/check.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local bad, count = 0, 0
local function walk(dir)
	for _, name in fs.readDir(dir) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			walk(p)
		elseif string.match(name, "%.luau$") then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(p))
			if not ok then
				bad += 1
				print("SYNTAX " .. p .. "\n" .. tostring(err))
			end
		end
	end
end
for _, d in { "src", "tests", "scripts" } do
	walk(d)
end
print(string.format("compiled %d files, %d with errors", count, bad))
process.exit(if bad == 0 then 0 else 1)
