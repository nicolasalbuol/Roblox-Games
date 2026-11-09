-- In-game HUD: round timer, coins/level, live turf leaderboard, menu, big toasts, kill feed, power-up chips.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage.Shared.Progression)
local Maps = require(ReplicatedStorage.Shared.Maps)

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Controllers.State)

local T = Kit.Theme
local LocalPlayer = Players.LocalPlayer
local HUD = {}

local ROWS = 6

function HUD:_top(gui)
	local pill = Kit.new("Frame", {
		Size = UDim2.fromOffset(380, 58),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { Kit.corner(29), Kit.stroke(T.Sky, 2.5, 0.25) })
	self.timer = Kit.label({ Size = UDim2.new(1, -24, 0.62, 0), Position = UDim2.fromOffset(12, 4), MaxText = 32, Parent = pill })
	self.mapLabel = Kit.label({ Size = UDim2.new(1, -24, 0.34, 0), Position = UDim2.new(0, 12, 0.62, -2), Font = T.Bold, TextColor3 = T.Sub, MaxText = 15, Parent = pill })
end

function HUD:_wallet(gui)
	local box = Kit.new("Frame", { Size = UDim2.fromOffset(250, 100), Position = UDim2.fromOffset(12, 10), BackgroundTransparency = 1, Parent = gui })
	local coins = Kit.new("Frame", { Size = UDim2.fromOffset(200, 44), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1, Parent = box }, { Kit.corner(22), Kit.stroke(T.Gold, 2, 0.3) })
	Kit.new("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(8, 7), BackgroundColor3 = T.Gold, Parent = coins }, { Kit.corner(15), Kit.stroke(Color3.fromRGB(180, 120, 20), 2, 0) })
	self.coins = Kit.label({ Size = UDim2.new(1, -54, 1, -10), Position = UDim2.fromOffset(46, 5), TextXAlignment = Enum.TextXAlignment.Left, Text = "0", MaxText = 26, Parent = coins })

	local lvl = Kit.new("Frame", { Size = UDim2.fromOffset(240, 44), Position = UDim2.fromOffset(0, 52), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1, Parent = box }, { Kit.corner(22), Kit.stroke(T.Mint, 2, 0.3) })
	local badge = Kit.new("Frame", { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = T.Mint, Parent = lvl }, { Kit.corner(18) })
	self.level = Kit.label({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), TextColor3 = Color3.fromRGB(20, 40, 40), Text = "1", Parent = badge })
	local barBg = Kit.new("Frame", { Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 48, 0.5, -7), BackgroundColor3 = T.Bg, Parent = lvl }, { Kit.corner(7) })
	self.xpBar = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Mint, Parent = barBg }, { Kit.corner(7), Kit.gradient(T.Mint, T.Sky, 0) })
end

function HUD:_board(gui)
	local board = Kit.new("Frame", {
		Size = UDim2.fromOffset(250, 40 + ROWS * 34),
		Position = UDim2.new(1, -12, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { Kit.corner(16), Kit.stroke(T.Pink, 2, 0.35) })
	Kit.label({ Text = "TURF", Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, Parent = board })
	self.rows = {}
	for k = 1, ROWS do
		local row = Kit.new("Frame", { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 36 + (k - 1) * 34), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.3, Visible = false, Parent = board }, { Kit.corner(8) })
		local fill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0.45, Parent = row }, { Kit.corner(8) })
		local name = Kit.label({ Size = UDim2.new(0.7, -8, 1, -6), Position = UDim2.fromOffset(8, 3), Font = T.Bold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, Parent = row })
		local pct = Kit.label({ Size = UDim2.new(0.3, -8, 1, -6), Position = UDim2.new(0.7, 0, 0, 3), TextXAlignment = Enum.TextXAlignment.Right, MaxText = 17, Parent = row })
		self.rows[k] = { row = row, fill = fill, name = name, pct = pct }
	end
	self.board = board
	self.feed = Kit.new("Frame", { Size = UDim2.fromOffset(300, 120), Position = UDim2.new(1, -12, 0, 60 + ROWS * 34), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = gui }, { Kit.list(4, false, Enum.HorizontalAlignment.Right) })
end

function HUD:_menu(gui, open)
	local bar = Kit.new("Frame", { Size = UDim2.fromOffset(96, 330), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui }, { Kit.list(10) })
	local defs = {
		{ "SHOP", T.Gold, "Shop" },
		{ "QUESTS", T.Mint, "Quests" },
		{ "INVITE", T.Sky, nil },
		{ "SETTINGS", T.PanelLight, "Settings" },
	}
	for k, d in defs do
		local btn = Kit.button({
			text = d[1],
			color = d[2],
			size = UDim2.fromOffset(96, 66),
			textColor = if d[1] == "SETTINGS" then T.Text else nil,
			maxText = 18,
			layoutOrder = k,
			parent = bar,
			onClick = function()
				if d[3] then
					open(d[3])
				else
					self:_invite()
				end
			end,
		})
		if d[1] == "QUESTS" then
			self.questDot = Kit.new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -10, 0, -6), BackgroundColor3 = T.Red, Visible = false, Parent = btn }, { Kit.corner(9), Kit.stroke(Color3.new(1, 1, 1), 2, 0) })
		end
	end
end

function HUD:_invite()
	State:Event("invite")
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, LocalPlayer)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, LocalPlayer)
	else
		State.Notify:Fire("Invites aren't available on this device right now.", "info")
	end
end

function HUD:_center(gui)
	self.big = Kit.label({ Size = UDim2.fromOffset(600, 90), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), TextTransparency = 1, TextStrokeTransparency = 1, MaxText = 72, Parent = gui })
	self.bigScale = Kit.new("UIScale", { Parent = self.big })
	self.overlay = Kit.new("Frame", { Size = UDim2.fromOffset(520, 130), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15, Visible = false, Parent = gui }, { Kit.corner(20), Kit.stroke(T.Red, 3, 0.1) })
	self.overlayTitle = Kit.label({ Size = UDim2.new(1, -20, 0.55, 0), Position = UDim2.fromOffset(10, 8), TextColor3 = T.Red, MaxText = 40, Parent = self.overlay })
	self.overlaySub = Kit.label({ Size = UDim2.new(1, -20, 0.35, 0), Position = UDim2.new(0, 10, 0.58, 0), Font = T.Bold, TextColor3 = T.Sub, MaxText = 22, Parent = self.overlay })
	self.chips = Kit.new("Frame", { Size = UDim2.fromOffset(400, 40), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = gui }, { Kit.list(8, true) })
end

function HUD:BigToast(text: string, color: Color3?)
	local l = self.big
	l.Text = text
	l.TextColor3 = color or T.Text
	l.TextTransparency, l.TextStrokeTransparency = 0, 0.2
	self.bigScale.Scale = 0.5
	Kit.tween(self.bigScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	self.bigToken = (self.bigToken or 0) + 1
	local token = self.bigToken
	task.delay(1.1, function()
		if self.bigToken == token then
			Kit.tween(l, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

function HUD:Feed(text: string, color: Color3?)
	local l = Kit.label({ Size = UDim2.fromOffset(300, 24), Text = text, Font = T.Bold, TextColor3 = color or T.Text, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Right, MaxText = 17, Parent = self.feed })
	local items = {}
	for _, c in self.feed:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(items, c)
		end
	end
	if #items > 4 then
		items[1]:Destroy()
	end
	task.delay(4, function()
		if l.Parent then
			Kit.tween(l, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 }).Completed:Wait()
			l:Destroy()
		end
	end)
end

function HUD:Chip(text: string, color: Color3, seconds: number)
	local chip = Kit.new("Frame", { Size = UDim2.fromOffset(130, 36), BackgroundColor3 = color, Parent = self.chips }, { Kit.corner(18), Kit.stroke(Color3.new(0, 0, 0), 2, 0.5) })
	local l = Kit.label({ Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), TextColor3 = Color3.fromRGB(20, 20, 40), MaxText = 20, Parent = chip })
	local t0 = os.clock()
	task.spawn(function()
		while chip.Parent and os.clock() - t0 < seconds do
			l.Text = string.format("%s %.0fs", text, math.ceil(seconds - (os.clock() - t0)))
			task.wait(0.2)
		end
		chip:Destroy()
	end)
end

function HUD:_refreshProfile(data)
	self.coins.Text = Kit.comma(data.coins)
	self.level.Text = tostring(data.level)
	Kit.tween(self.xpBar, 0.3, { Size = UDim2.fromScale(math.clamp(data.xp / Progression.xpToNext(data.level), 0, 1), 1) })
	local today = Progression.dayNumber(os.time())
	local claimable = data.daily.lastDay < today
	for _, q in data.quests.list do
		local def = Progression.quest(q.id)
		if def and not q.claimed and q.progress >= def.goal then
			claimable = true
		end
	end
	self.questDot.Visible = claimable
end

function HUD:_refreshBoard()
	local grid = State.grid
	local roundState = State:RoundState()
	if not grid or roundState ~= "Playing" then
		self.board.Visible = false
		return
	end
	self.board.Visible = true
	local entries = {}
	for _, e in State.roster do
		table.insert(entries, { e = e, pct = grid:percentOf(e.slot) })
	end
	table.sort(entries, function(a, b)
		return a.pct > b.pct
	end)
	-- Always show the local player, even outside the top rows.
	local shown = {}
	for k = 1, math.min(ROWS, #entries) do
		shown[k] = entries[k]
	end
	local mine
	for k, entry in entries do
		if entry.e.slot == State.mySlot then
			mine = k
		end
	end
	if mine and mine > ROWS then
		shown[ROWS] = entries[mine]
	end
	for k, r in self.rows do
		local entry = shown[k]
		r.row.Visible = entry ~= nil
		if entry then
			local rank = if entry.e.slot == State.mySlot and mine then mine else k
			r.name.Text = rank .. ". " .. entry.e.name
			r.name.TextColor3 = if entry.e.slot == State.mySlot then T.Gold else T.Text
			r.pct.Text = string.format("%.1f%%", entry.pct)
			r.fill.BackgroundColor3 = entry.e.color3
			r.fill.Size = UDim2.fromScale(math.clamp(entry.pct / 50, 0.02, 1), 1)
		end
	end
end

function HUD:Start(gui, open)
	self:_top(gui)
	self:_wallet(gui)
	self:_board(gui)
	self:_menu(gui, open)
	self:_center(gui)

	State.ProfileChanged:Connect(function(data)
		self:_refreshProfile(data)
	end)

	State.MatchEvent:Connect(function(evt)
		if evt.t == "capture" then
			self:BigToast("+" .. evt.n .. " TILES", State:ColorOf(State.mySlot or 0):Lerp(Color3.new(1, 1, 1), 0.2))
		elseif evt.t == "elim" then
			local victim, killer = State:NameOf(evt.victim), evt.killer ~= 0 and State:NameOf(evt.killer)
			local vc = State:ColorOf(evt.victim)
			if evt.victim == State.mySlot then
				self.overlay.Visible = true
				self.overlayTitle.Text = if killer then "CUT BY " .. string.upper(killer) .. "!" else "SPLAT!"
				self.overlaySub.Text = if evt.reason == "self" then "You crossed your own trail. Respawning..." elseif evt.reason == "enclosed" then "Your trail got looped in. Respawning..." elseif evt.reason == "overrun" then "Your turf was swallowed. Respawning..." else "Respawning..."
			elseif evt.killer == State.mySlot then
				self:BigToast("SNAP! " .. victim, T.Gold)
			end
			if killer then
				self:Feed(killer .. "  cut  " .. victim, vc)
			end
		elseif evt.t == "spawn" and evt.slot == State.mySlot then
			self.overlay.Visible = false
		elseif evt.t == "powerup" and evt.slot == State.mySlot then
			if evt.kind == "Dash" then
				self:Chip("DASH", T.Gold, evt.duration)
			elseif evt.kind == "Shield" then
				self:Chip("SHIELD", T.Sky, evt.duration)
			else
				self:BigToast("INK BOMB!", T.Pink)
			end
		elseif evt.t == "roundStart" then
			self.overlay.Visible = false
			local map = Maps.get(evt.map)
			self:BigToast(if map then string.upper(map.name) else "GO!", T.Mint)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local roundState, endsAt = State:RoundState()
		local left = endsAt - workspace:GetServerTimeNow()
		if roundState == "Playing" then
			self.timer.Text = Kit.formatTime(left)
			self.timer.TextColor3 = if left <= 15 then T.Red else T.Text
			self.mapLabel.Text = string.upper(workspace:GetAttribute("MapName") or "")
		else
			self.timer.Text = "NEXT ROUND " .. Kit.formatTime(left)
			self.timer.TextColor3 = T.Mint
			self.mapLabel.Text = "HUB - GET READY"
			self.overlay.Visible = false
		end
		self:_refreshBoard()
	end)
end

return HUD
