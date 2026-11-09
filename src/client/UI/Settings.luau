-- Settings: volumes, camera mode, reduced effects. Saved server-side with the profile.
local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Controllers.State)

local T = Kit.Theme
local Settings = { rows = {} }

local function set(key: string, value)
	State.profile.settings[key] = value
	State.ProfileChanged:Fire(State.profile) -- apply instantly, server confirms on next push
	State:Request("setting", { key = key, value = value })
end

function Settings:_row(content, order: number, title: string)
	local r = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = T.PanelLight, LayoutOrder = order, Parent = content }, { Kit.corner(14) })
	Kit.label({ Size = UDim2.new(0.45, 0, 0, 34), Position = UDim2.fromOffset(16, 18), Text = title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24, Parent = r })
	return r
end

function Settings:_volume(content, order: number, title: string, key: string)
	local r = self:_row(content, order, title)
	local value = Kit.label({ Size = UDim2.fromOffset(80, 34), Position = UDim2.new(1, -196, 0, 18), MaxText = 24, Parent = r })
	local function step(delta)
		local v = math.clamp(math.floor((State.profile.settings[key] + delta) * 10 + 0.5) / 10, 0, 1)
		set(key, v)
	end
	Kit.button({ text = "-", color = T.Sky, size = UDim2.fromOffset(52, 48), position = UDim2.new(1, -256, 0, 11), parent = r, onClick = function()
		step(-0.1)
	end })
	Kit.button({ text = "+", color = T.Sky, size = UDim2.fromOffset(52, 48), position = UDim2.new(1, -108, 0, 11), parent = r, onClick = function()
		step(0.1)
	end })
	self.rows[key] = function(s)
		value.Text = math.floor(s[key] * 100 + 0.5) .. "%"
	end
end

function Settings:_toggle(content, order: number, title: string, key: string, labels, values)
	local r = self:_row(content, order, title)
	local _, label = Kit.button({ text = "", color = T.Mint, size = UDim2.fromOffset(240, 48), position = UDim2.new(1, -256, 0, 11), parent = r, onClick = function()
		local cur = State.profile.settings[key]
		set(key, if cur == values[1] then values[2] else values[1])
	end })
	self.rows[key] = function(s)
		label.Text = if s[key] == values[1] then labels[1] else labels[2]
	end
end

function Settings:Start(gui)
	local frame, content = Kit.panel(gui, "SETTINGS", UDim2.fromOffset(620, 440))
	Kit.list(10).Parent = content
	self:_volume(content, 1, "Sound effects", "sfx")
	self:_volume(content, 2, "Music", "music")
	self:_toggle(content, 3, "Camera", "camera", { "TOP-DOWN", "CLASSIC" }, { "top", "classic" })
	self:_toggle(content, 4, "Effects", "reducedFx", { "REDUCED", "FULL" }, { true, false })
	Kit.registerModal("Settings", frame, function()
		self:Render()
	end)
	State.ProfileChanged:Connect(function()
		self:Render()
	end)
end

function Settings:Render()
	local s = State.profile and State.profile.settings
	if s then
		for _, fn in self.rows do
			fn(s)
		end
	end
end

return Settings
