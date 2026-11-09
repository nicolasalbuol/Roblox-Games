-- Global "most wins" board (OrderedDataStore) displayed in the hub.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local LeaderboardService = { pending = {}, names = {} }

function LeaderboardService:Init(S)
	self.S = S
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.Data.LeaderboardStore)
	self.store = ok and store or nil
end

function LeaderboardService:MarkWins(player: Player, wins: number)
	if wins > 0 then
		self.pending[player.UserId] = wins
	end
end

function LeaderboardService:_flush()
	if not self.store then
		return
	end
	for userId, wins in table.clone(self.pending) do
		self.pending[userId] = nil
		pcall(self.store.SetAsync, self.store, tostring(userId), wins)
		task.wait(1)
	end
end

function LeaderboardService:_nameOf(userId: number): string
	if self.names[userId] then
		return self.names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	self.names[userId] = if ok then name else "Player"
	return self.names[userId]
end

function LeaderboardService:_render(rows)
	local hub = workspace:FindFirstChild("Hub")
	local board = hub and hub:FindFirstChild("WinsBoard")
	if not board then
		return
	end
	local gui = board:FindFirstChild("Board") or Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui:ClearAllChildren()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = gui
	local function line(text, color, size)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(0.92, 0, 0, size)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = color
		t.Text = text
		t.Parent = gui
	end
	line("TOP WINNERS", Color3.fromRGB(255, 210, 70), 70)
	if #rows == 0 then
		line("Be the first champion!", Color3.fromRGB(220, 220, 255), 44)
	end
	for rank, r in rows do
		line(string.format("%d. %s  -  %d", rank, r.name, r.wins), if rank <= 3 then Color3.fromRGB(120, 255, 200) else Color3.fromRGB(230, 230, 255), 44)
	end
	gui.Parent = board
end

function LeaderboardService:_refresh()
	if not self.store then
		self:_render({})
		return
	end
	local ok, pages = pcall(self.store.GetSortedAsync, self.store, false, 10)
	if not ok then
		return
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(rows, { name = self:_nameOf(userId), wins = entry.value })
		end
	end
	self:_render(rows)
end

function LeaderboardService:Start()
	self:_render({})
	Players.PlayerRemoving:Connect(function()
		task.spawn(self._flush, self)
	end)
	while true do
		self:_flush()
		self:_refresh()
		task.wait(120)
	end
end

return LeaderboardService
