-- Store: cosmetics for coins, coin packs and passes for Robux. Prices always visible; coin buys confirm;
-- Robux buys use Roblox's own purchase dialog. Never opens by itself.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Progression = require(ReplicatedStorage.Shared.Progression)

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Controllers.State)

local T = Kit.Theme
local Shop = { tab = "ink", livePrices = {} }

local TABS = {
	{ id = "ink", text = "INKS" },
	{ id = "trail", text = "TRAILS" },
	{ id = "title", text = "TITLES" },
	{ id = "coins", text = "COINS" },
	{ id = "passes", text = "PASSES" },
}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function achievementName(id: string): string
	for _, a in Progression.Achievements do
		if a.id == id then
			return a.name
		end
	end
	return id
end

function Shop:_confirm(text: string, onYes)
	local c = self.confirmFrame
	c.Visible = true
	self.confirmText.Text = text
	self.onConfirm = onYes
end

function Shop:_card(parent, order: number)
	local card = Kit.new("Frame", { Size = UDim2.fromOffset(150, 176), BackgroundColor3 = T.PanelLight, LayoutOrder = order, Parent = parent }, { Kit.corner(14), Kit.stroke(Color3.new(0, 0, 0), 2, 0.6) })
	return card
end

function Shop:_cosmeticCard(parent, item, order: number)
	local data, passes = State.profile, State.passes
	local card = self:_card(parent, order)
	local preview = Kit.new("Frame", { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = T.Bg, Parent = card }, { Kit.corner(35) })
	if item.category == "ink" then
		preview.BackgroundColor3 = rgb(item.color)
		Kit.stroke(Color3.new(1, 1, 1), 3, 0.2).Parent = preview
	else
		Kit.label({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Text = if item.category == "trail" then "~" else "Aa", TextColor3 = T.Mint, Parent = preview })
	end
	Kit.label({ Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 88), Text = if item.name == "" then "No Title" else item.name, MaxText = 18, Parent = card })

	local unlocked = Cosmetics.isUnlocked(data, passes, item)
	local equipped = data.equipped[item.category] == item.id
	local u = item.unlock
	local text, color, enabled, action = "EQUIP", T.Mint, true, nil
	if equipped then
		text, enabled = "EQUIPPED", false
	elseif unlocked then
		action = function()
			self:_result(State:Request("equip", item.id))
		end
	elseif u.type == "coins" then
		text, color = "BUY  " .. Kit.comma(u.price), T.Gold
		enabled = data.coins >= u.price
		if not enabled then
			text = Kit.comma(u.price) .. " coins"
		end
		action = function()
			self:_confirm(string.format("Buy %s for %s coins?", item.name, Kit.comma(u.price)), function()
				self:_result(State:Request("buy", item.id))
			end)
		end
	elseif u.type == "level" then
		text, enabled = "LEVEL " .. u.level, false
	elseif u.type == "achievement" then
		text, enabled = achievementName(u.id), false
	elseif u.type == "pass" then
		text, color = "GET PASS", T.Pink
		action = function()
			self.tab = "passes"
			self:Render()
		end
	end
	local btn = Kit.button({ text = text, color = color, size = UDim2.new(1, -16, 0, 40), position = UDim2.new(0, 8, 1, -48), maxText = 16, parent = card, onClick = function()
		State:Event("storeView", item.id)
		if action then
			action()
		end
	end })
	Kit.setEnabled(btn, enabled and action ~= nil, color)
end

function Shop:_price(kind: string, def): string
	if def.id == 0 then
		return "Coming soon"
	end
	local live = self.livePrices[def.id]
	if live == nil then
		self.livePrices[def.id] = false
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, def.id, if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				self.livePrices[def.id] = info.PriceInRobux
				if Kit.currentModal() == "Shop" then
					self:Render()
				end
			end
		end)
	end
	return Kit.ROBUX .. " " .. tostring(if live then live else def.price)
end

function Shop:_robuxCard(parent, kind: string, key: string, def, order: number)
	local card = self:_card(parent, order)
	card.Size = UDim2.fromOffset(150, 196)
	local owned = kind == "pass" and State.passes[key]
	local headline = if kind == "product" then Kit.comma(def.coins) .. " coins" else def.name
	Kit.label({ Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 10), Text = headline, TextColor3 = if kind == "product" then T.Gold else T.Pink, MaxText = 20, Parent = card })
	Kit.label({ Size = UDim2.new(1, -16, 0, 88), Position = UDim2.fromOffset(8, 44), Text = if kind == "product" then def.name else def.description, Font = T.Body, TextColor3 = T.Sub, TextWrapped = true, MaxText = 14, Parent = card })
	local text = if owned then "OWNED" else self:_price(kind, def)
	local btn = Kit.button({ text = text, color = if owned then T.Mint else T.Gold, size = UDim2.new(1, -16, 0, 42), position = UDim2.new(0, 8, 1, -50), maxText = 18, parent = card, onClick = function()
		State:Event("storeView", key)
		local res = State:Request("prompt", { kind = kind, key = key })
		if not res.ok and res.err == "unavailable" then
			State.Notify:Fire("This item isn't on sale yet.", "info")
		end
	end })
	Kit.setEnabled(btn, not owned and def.id ~= 0, T.Gold)
end

function Shop:_result(res)
	if res.ok then
		State.Notify:Fire("Done!", "success")
	elseif res.err == "coins" then
		State.Notify:Fire("Not enough coins yet - play a round to earn more!", "info")
	elseif res.err ~= "owned" then
		State.Notify:Fire("Couldn't do that right now.", "info")
	end
end

function Shop:Render()
	if not State.profile then
		return
	end
	for _, c in self.grid:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for _, b in self.tabButtons do
		b.btn.BackgroundColor3 = if b.id == self.tab then T.Sky else T.PanelLight
		b.label.TextColor3 = if b.id == self.tab then Color3.fromRGB(20, 20, 40) else T.Text
	end
	self.coinsLabel.Text = "Your coins: " .. Kit.comma(State.profile.coins)
	local order = 0
	if Cosmetics.Categories[self.tab] then
		for _, item in Cosmetics.Categories[self.tab] do
			order += 1
			self:_cosmeticCard(self.grid, item, order)
		end
	elseif self.tab == "coins" then
		local keys = {}
		for key in Config.Monetization.Products do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return Config.Monetization.Products[a].coins < Config.Monetization.Products[b].coins
		end)
		for _, key in keys do
			order += 1
			self:_robuxCard(self.grid, "product", key, Config.Monetization.Products[key], order)
		end
	else
		for _, key in { "VIP", "DoubleCoins", "PrismPack" } do
			order += 1
			self:_robuxCard(self.grid, "pass", key, Config.Monetization.GamePasses[key], order)
		end
	end
	self.note.Visible = self.tab == "coins" or self.tab == "passes"
end

function Shop:Start(gui)
	local frame, content = Kit.panel(gui, "SHOP", UDim2.fromOffset(820, 520))
	local tabs = Kit.new("Frame", { Size = UDim2.new(0, 130, 1, 0), BackgroundTransparency = 1, Parent = content }, { Kit.list(8) })
	self.tabButtons = {}
	for k, tab in TABS do
		local btn, label = Kit.button({ text = tab.text, color = T.PanelLight, textColor = T.Text, size = UDim2.fromOffset(124, 52), layoutOrder = k, maxText = 20, parent = tabs, onClick = function()
			self.tab = tab.id
			self:Render()
		end })
		table.insert(self.tabButtons, { id = tab.id, btn = btn, label = label })
	end
	self.coinsLabel = Kit.label({ Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(146, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Gold, MaxText = 20, Parent = content })
	self.grid = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, -146, 1, -60),
		Position = UDim2.fromOffset(146, 32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 196), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Kit.pad(4),
	})
	self.note = Kit.label({ Size = UDim2.new(1, -150, 0, 22), Position = UDim2.new(0, 146, 1, -24), Font = T.Body, TextColor3 = T.Sub, MaxText = 13, Text = "Purchases are optional and cosmetic or coin-boost only - they never decide who wins a round.", Parent = content })

	-- Confirmation dialog for coin purchases.
	local confirm = Kit.new("Frame", { Size = UDim2.fromOffset(420, 190), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.Bg, Visible = false, ZIndex = 5, Parent = frame }, { Kit.corner(18), Kit.stroke(T.Gold, 3, 0) })
	self.confirmText = Kit.label({ Size = UDim2.new(1, -30, 0, 80), Position = UDim2.fromOffset(15, 14), TextWrapped = true, MaxText = 24, Parent = confirm })
	Kit.button({ text = "BUY", color = T.Gold, size = UDim2.fromOffset(160, 52), position = UDim2.new(0.5, -170, 1, -70), parent = confirm, onClick = function()
		confirm.Visible = false
		if self.onConfirm then
			self.onConfirm()
		end
	end })
	Kit.button({ text = "CANCEL", color = T.PanelLight, textColor = T.Text, size = UDim2.fromOffset(160, 52), position = UDim2.new(0.5, 10, 1, -70), parent = confirm, onClick = function()
		confirm.Visible = false
	end })
	self.confirmFrame = confirm

	Kit.registerModal("Shop", frame, function()
		confirm.Visible = false
		State:Event("storeOpen")
		self:Render()
	end)
	State.ProfileChanged:Connect(function()
		if Kit.currentModal() == "Shop" then
			self:Render()
		end
	end)
end

return Shop
