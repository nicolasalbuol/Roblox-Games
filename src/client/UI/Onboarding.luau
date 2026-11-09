-- Title splash (main menu), first-time tutorial coach, and toast notifications.
local Players = game:GetService("Players")

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Controllers.State)

local T = Kit.Theme
local Onboarding = {}

local STEPS = {
	[0] = { "WALK OUT OF YOUR ZONE", "Leaving your colored zone draws a glowing trail." },
	[1] = { "WALK OUT OF YOUR ZONE", "Leaving your colored zone draws a glowing trail." },
	[2] = { "NOW LOOP BACK HOME!", "Return to your zone to claim everything inside the loop." },
}

function Onboarding:_splash(gui)
	local splash = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Bg, ZIndex = 50, Active = true, Parent = gui }, {
		Kit.gradient(Color3.fromRGB(30, 22, 70), Color3.fromRGB(12, 10, 28), 90),
	})
	local logo = Kit.label({ Size = UDim2.fromOffset(760, 130), Position = UDim2.fromScale(0.5, 0.32), AnchorPoint = Vector2.new(0.5, 0.5), Text = "CHROMA TURF", MaxText = 110, ZIndex = 51, Parent = splash })
	Kit.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, T.Mint), ColorSequenceKeypoint.new(0.5, T.Sky), ColorSequenceKeypoint.new(1, T.Pink) }), Parent = logo })
	Kit.new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(10, 8, 24), Parent = logo })
	Kit.label({ Size = UDim2.fromOffset(700, 40), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Text = "Draw a loop. Claim the land. Cut their trail.", Font = T.Bold, TextColor3 = T.Sub, MaxText = 28, ZIndex = 51, Parent = splash })
	local status = Kit.label({ Size = UDim2.fromOffset(500, 30), Position = UDim2.fromScale(0.5, 0.75), AnchorPoint = Vector2.new(0.5, 0.5), Text = "Loading your save...", Font = T.Bold, TextColor3 = T.Sub, MaxText = 20, ZIndex = 51, Parent = splash })
	local play = Kit.button({ text = "PLAY", color = T.Mint, size = UDim2.fromOffset(260, 80), position = UDim2.fromScale(0.5, 0.62), anchor = Vector2.new(0.5, 0.5), maxText = 44, parent = splash, onClick = function()
		Kit.tween(splash, 0.35, { BackgroundTransparency = 1 })
		for _, d in splash:GetDescendants() do
			if d:IsA("GuiObject") then
				Kit.tween(d, 0.3, { BackgroundTransparency = 1 })
			end
			if d:IsA("TextLabel") then
				Kit.tween(d, 0.3, { TextTransparency = 1 })
			end
			if d:IsA("UIStroke") then
				Kit.tween(d, 0.3, { Transparency = 1 })
			end
		end
		task.delay(0.4, function()
			splash:Destroy()
		end)
	end })
	play.ZIndex = 52
	play.Visible = false
	local function ready()
		status.Text = if State.profile.sessions > 1 then "Welcome back, " .. Players.LocalPlayer.DisplayName .. "!" else "Welcome, " .. Players.LocalPlayer.DisplayName .. "!"
		play.Visible = true
	end
	if State.profile then
		ready()
	else
		local conn
		conn = State.ProfileChanged:Connect(function()
			conn.Disconnect()
			ready()
		end)
	end
end

function Onboarding:_coach(gui)
	local box = Kit.new("Frame", { Size = UDim2.fromOffset(560, 92), Position = UDim2.new(0.5, 0, 0, 78), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, Visible = false, Parent = gui }, { Kit.corner(18), Kit.stroke(T.Mint, 3, 0) })
	local title = Kit.label({ Size = UDim2.new(1, -24, 0, 42), Position = UDim2.fromOffset(12, 6), TextColor3 = T.Mint, MaxText = 32, Parent = box })
	local body = Kit.label({ Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 50), Font = T.Bold, TextColor3 = T.Text, MaxText = 18, Parent = box })
	local celebrated = false
	local function update()
		local data = State.profile
		local playing = State:RoundState() == "Playing" and State.mySlot ~= nil
		if not data or data.tutorialDone then
			if data and data.tutorialDone and not celebrated and data.tutorialStep == 3 and box.Visible then
				celebrated = true
				title.Text, body.Text = "AWESOME! BIGGER LOOPS = MORE TURF", "Walk through a rival's trail to cut it - but guard yours!"
				task.delay(6, function()
					box.Visible = false
				end)
			elseif not celebrated then
				box.Visible = false
			end
			return
		end
		local step = STEPS[data.tutorialStep] or STEPS[0]
		title.Text, body.Text = step[1], step[2]
		box.Visible = playing
	end
	State.ProfileChanged:Connect(update)
	State.MatchEvent:Connect(update)
	State.RosterChanged:Connect(update)
end

local STYLE = {
	info = Kit.Theme.Sky,
	success = Kit.Theme.Mint,
	gold = Kit.Theme.Gold,
	level = Kit.Theme.Mint,
	unlock = Kit.Theme.Pink,
	achievement = Kit.Theme.Gold,
	quest = Kit.Theme.Mint,
}

function Onboarding:_toasts(gui)
	local stack = Kit.new("Frame", { Size = UDim2.fromOffset(420, 300), Position = UDim2.new(0.5, 0, 1, -70), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = gui }, {
		Kit.new("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local n = 0
	State.Notify:Connect(function(text, style)
		n += 1
		local color = STYLE[style] or T.Sky
		local toast = Kit.new("Frame", { Size = UDim2.fromOffset(420, 46), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.05, LayoutOrder = n, Parent = stack }, { Kit.corner(14), Kit.stroke(color, 2.5, 0) })
		local l = Kit.label({ Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Text = text, Font = T.Bold, TextColor3 = color, TextWrapped = true, MaxText = 18, Parent = toast })
		local items = {}
		for _, c in stack:GetChildren() do
			if c:IsA("Frame") then
				table.insert(items, c)
			end
		end
		if #items > 4 then
			items[1]:Destroy()
		end
		task.delay(3.5, function()
			if toast.Parent then
				Kit.tween(toast, 0.4, { BackgroundTransparency = 1 })
				Kit.tween(l, 0.4, { TextTransparency = 1 })
				task.wait(0.45)
				toast:Destroy()
			end
		end)
	end)
end

function Onboarding:Start(gui)
	self:_toasts(gui)
	self:_coach(gui)
	self:_splash(gui)
end

return Onboarding
