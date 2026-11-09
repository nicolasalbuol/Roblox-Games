-- Daily quests: 3 per UTC day, same for everyone, progress tracked server-side.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)

local QuestService = {}

function QuestService:Init(S)
	self.S = S
end

function QuestService:Ensure(data)
	local today = Progression.dayNumber(os.time())
	if data.quests.day ~= today then
		local list = {}
		for _, id in Progression.questsForDay(today) do
			list[#list + 1] = { id = id, progress = 0, claimed = false }
		end
		data.quests = { day = today, list = list }
	end
end

function QuestService:Progress(player: Player, kind: string, amount: number)
	local data = self.S.DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	self:Ensure(data)
	for _, q in data.quests.list do
		local def = Progression.quest(q.id)
		if def and def.kind == kind and not q.claimed and q.progress < def.goal then
			q.progress = math.min(def.goal, q.progress + amount)
			if q.progress >= def.goal then
				self.S.EconomyService:Notify(player, "Quest complete: " .. def.text .. " - claim it in Quests!", "quest")
			end
			self.S.DataService:MarkDirty(player)
		end
	end
end

function QuestService:Claim(player: Player, id: string)
	local data = self.S.DataService:Get(player)
	if not data then
		return { ok = false, err = "loading" }
	end
	self:Ensure(data)
	for _, q in data.quests.list do
		if q.id == id then
			local def = Progression.quest(id)
			if q.claimed or q.progress < def.goal then
				return { ok = false, err = "notready" }
			end
			q.claimed = true
			self.S.EconomyService:AddCoins(player, def.coins, "Gameplay", "Quest_" .. id)
			self.S.EconomyService:AddXp(player, def.xp)
			self.S.TelemetryService:Custom(player, "QuestClaim", 1, { id })
			return { ok = true }
		end
	end
	return { ok = false, err = "invalid" }
end

function QuestService:Start()
	self.S.DataService.Loaded:Connect(function(_, data)
		self:Ensure(data)
	end)
end

return QuestService
