-- End-of-round summary: placement, turf, rewards, level-up and the podium.
local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Controllers.State)

local T = Kit.Theme
local Results = {}

local function ordinal(n: number): string
	local suffix = "th"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "st", "nd", "rd" })[n % 10] or "th"
	end
	return n .. suffix
end

function Results:Show(r)
	self.headline.Text = if r.rank == 1 then "YOU WON!" else ordinal(r.rank) .. " of " .. r.count
	self.headline.TextColor3 = if r.rank == 1 then T.Gold elseif r.rank <= 3 then T.Mint else T.Text
	self.stats.Text = string.format("Final turf %.1f%%   Peak %.1f%%   Tiles claimed %s   Trails cut %d", r.percent, r.peak, Kit.comma(r.tiles), r.kills)
	self.rewards.Text = string.format("+%s coins     +%s XP", Kit.comma(r.coins), Kit.comma(r.xp))
	self.levelUp.Visible = r.levelAfter > r.levelBefore
	self.levelUp.Text = "LEVEL UP!  " .. r.levelBefore .. " > " .. r.levelAfter
	for k = 1, 3 do
		local e = r.top[k]
		local l = self.podium[k]
		l.Visible = e ~= nil
		if e then
			l.Text = string.format("%d. %s  %.1f%%", k, e.name, e.percent)
			l.TextColor3 = Color3.fromRGB(e.color[1], e.color[2], e.color[3])
		end
	end
	Kit.openModal("Results")
end

function Results:Start(gui)
	local frame, content = Kit.panel(gui, "ROUND OVER", UDim2.fromOffset(620, 430))
	self.headline = Kit.label({ Size = UDim2.new(1, 0, 0, 70), MaxText = 64, Parent = content })
	self.stats = Kit.label({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 74), Font = T.Bold, TextColor3 = T.Sub, MaxText = 17, Parent = content })
	self.rewards = Kit.label({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 106), TextColor3 = T.Gold, MaxText = 32, Parent = content })
	self.levelUp = Kit.label({ Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 148), TextColor3 = T.Mint, Visible = false, MaxText = 28, Parent = content })
	self.podium = {}
	for k = 1, 3 do
		self.podium[k] = Kit.label({ Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 184 + (k - 1) * 34), MaxText = 24, Parent = content })
	end
	Kit.button({ text = "CONTINUE", color = T.Mint, size = UDim2.fromOffset(220, 56), position = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), parent = content, onClick = function()
		Kit.closeModal()
	end })
	Kit.registerModal("Results", frame)
	State.MatchEvent:Connect(function(evt)
		if evt.t == "results" then
			self:Show(evt)
		elseif evt.t == "roundStart" and Kit.currentModal() == "Results" then
			Kit.closeModal()
		end
	end)
end

return Results
