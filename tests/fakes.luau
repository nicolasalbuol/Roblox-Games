-- Shared fakes for tests: controllable signals and an Instance proxy that validates every property
-- and method against Lune's Roblox reflection database while faking engine-only events.
local function noop() end

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = noop }
		end,
		Wait = noop,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end

-- Instance proxy: property reads/writes and methods hit the real Lune instance (validated);
-- events that Lune lacks return fake signals.
local EVENTS = {
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	Activated = true,
	DescendantAdded = true,
	Completed = true,
}
local proxyOf = setmetatable({}, { __mode = "k" })
local realOf = setmetatable({}, { __mode = "k" })
local wrap

local function unwrap(v)
	return realOf[v] or v
end

wrap = function(real, extra)
	if typeof(real) ~= "Instance" then
		return real
	end
	if proxyOf[real] then
		return proxyOf[real]
	end
	local events = {}
	local proxy = setmetatable({}, {
		__index = function(_, k)
			if extra and extra[k] ~= nil then
				return extra[k]
			end
			if EVENTS[k] then
				events[k] = events[k] or signal()
				return events[k]
			end
			if k == "GetPropertyChangedSignal" then
				return function()
					return signal()
				end
			end
			-- Lune stores BasePart placement only in CFrame; Position is derived (like the engine).
			if k == "Position" and real:IsA("BasePart") then
				return real.CFrame.Position
			end
			local v = real[k]
			if type(v) == "function" then
				return function(_, ...)
					local args = table.pack(...)
					for i = 1, args.n do
						args[i] = unwrap(args[i])
					end
					local res = table.pack(v(real, table.unpack(args, 1, args.n)))
					for i = 1, res.n do
						if type(res[i]) == "table" then
							for j, x in res[i] do
								res[i][j] = wrap(x)
							end
						else
							res[i] = wrap(res[i])
						end
					end
					return table.unpack(res, 1, res.n)
				end
			end
			return wrap(v)
		end,
		__newindex = function(_, k, v)
			if k == "Position" and real:IsA("BasePart") then
				real.CFrame = real.CFrame.Rotation + v
				return
			end
			real[k] = unwrap(v)
		end,
	})
	proxyOf[real], realOf[proxy] = proxy, real
	return proxy
end

return { signal = signal, wrap = wrap, unwrap = unwrap, realOf = realOf, noop = noop }
