-- Daily reward, daily quests, achievements and lifetime stats.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Controllers.State)

local T = Kit.Theme
local Quests = {}

function Quests:Render()
	local data = State.profile
	if not data then
		return
	end
	for _, c in self.list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local order = 0
	local function row(height: number)
		order += 1
		return Kit.new("Frame", { Size = UDim2.new(1, -12, 0, height), BackgroundColor3 = T.PanelLight, LayoutOrder = order, Parent = self.list }, { Kit.corner(14) })
	end

	-- Daily reward
	local today = Progression.dayNumber(os.time())
	local canClaim, step, coins = Progression.dailyStatus(data.daily, today)
	local daily = row(80)
	Kit.label({ Size = UDim2.new(0.62, 0, 0, 34), Position = UDim2.fromOffset(16, 8), Text = "DAILY GIFT - DAY " .. step .. " of " .. #Config.Economy.DailyRewards, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Gold, MaxText = 22, Parent = daily })
	Kit.label({ Size = UDim2.new(0.62, 0, 0, 24), Position = UDim2.fromOffset(16, 44), Text = if canClaim then Kit.comma(coins) .. " coins waiting for you" else "Claimed! New gift tomorrow (missing a day never resets)", Font = T.Body, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15, Parent = daily })
	local dailyBtn = Kit.button({ text = if canClaim then "CLAIM" else "DONE", color = T.Gold, size = UDim2.fromOffset(150, 52), position = UDim2.new(1, -166, 0.5, -26), parent = daily, onClick = function()
		local res = State:Request("claimDaily")
		if res.ok then
			State.Notify:Fire("+" .. res.coins .. " coins!", "gold")
		end
	end })
	Kit.setEnabled(dailyBtn, canClaim, T.Gold)

	-- Quests
	for _, q in data.quests.list do
		local def = Progression.quest(q.id)
		if def then
			local r = row(84)
			Kit.label({ Size = UDim2.new(0.62, 0, 0, 30), Position = UDim2.fromOffset(16, 8), Text = def.text, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, Parent = r })
			local barBg = Kit.new("Frame", { Size = UDim2.new(0.55, 0, 0, 16), Position = UDim2.fromOffset(16, 46), BackgroundColor3 = T.Bg, Parent = r }, { Kit.corner(8) })
			Kit.new("Frame", { Size = UDim2.fromScale(math.clamp(q.progress / def.goal, 0, 1), 1), BackgroundColor3 = T.Mint, Parent = barBg }, { Kit.corner(8) })
			Kit.label({ Size = UDim2.new(0.2, 0, 0, 20), Position = UDim2.new(0.58, 0, 0, 44), Text = Kit.comma(q.progress) .. "/" .. Kit.comma(def.goal), Font = T.Bold, TextColor3 = T.Sub, MaxText = 15, Parent = r })
			local ready = q.progress >= def.goal and not q.claimed
			local btn = Kit.button({ text = if q.claimed then "CLAIMED" elseif ready then "+" .. def.coins else def.coins .. " coins", color = T.Mint, size = UDim2.fromOffset(150, 52), position = UDim2.new(1, -166, 0.5, -26), parent = r, onClick = function()
				State:Request("claimQuest", q.id)
			end })
			Kit.setEnabled(btn, ready, T.Mint)
		end
	end

	-- Achievements
	local header = row(40)
	header.BackgroundTransparency = 1
	Kit.label({ Size = UDim2.fromScale(1, 1), Text = "ACHIEVEMENTS", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Pink, MaxText = 24, Parent = header })
	for _, a in Progression.Achievements do
		local done = data.achievements[a.id] ~= nil
		local r = row(56)
		r.BackgroundColor3 = if done then T.PanelLight else T.Bg
		Kit.label({ Size = UDim2.new(0.4, 0, 1, -12), Position = UDim2.fromOffset(16, 6), Text = (if done then "[x] " else "[ ] ") .. a.name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if done then T.Mint else T.Text, MaxText = 20, Parent = r })
		Kit.label({ Size = UDim2.new(0.58, -16, 1, -12), Position = UDim2.new(0.42, 0, 0, 6), Text = a.desc .. "  (+" .. a.coins .. ")", Font = T.Body, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15, Parent = r })
	end

	local s = data.stats
	self.stats.Text = string.format("Rounds %s   Wins %s   Trails cut %s   Tiles %s   Best loop %s", Kit.comma(s.rounds), Kit.comma(s.wins), Kit.comma(s.kills), Kit.comma(s.tilesClaimed), Kit.comma(s.bestLoop))
end

function Quests:Start(gui)
	local frame, content = Kit.panel(gui, "QUESTS", UDim2.fromOffset(760, 520))
	self.stats = Kit.label({ Size = UDim2.new(1, 0, 0, 22), Font = T.Bold, TextColor3 = T.Sub, MaxText = 15, Parent = content })
	self.list = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -30),
		Position = UDim2.fromOffset(0, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { Kit.list(8) })
	Kit.registerModal("Quests", frame, function()
		self:Render()
	end)
	State.ProfileChanged:Connect(function()
		if Kit.currentModal() == "Quests" then
			self:Render()
		end
	end)
end

return Quests
