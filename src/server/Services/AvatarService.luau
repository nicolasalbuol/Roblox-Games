-- Character setup: no player-vs-player collisions (no body blocking), nametags with titles, cosmetic FX.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)

local AvatarService = {}

local GROUP = "Players"

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function rainbow(): ColorSequence
	local keys = {}
	for k = 0, 6 do
		keys[#keys + 1] = ColorSequenceKeypoint.new(k / 6, Color3.fromHSV(k / 6, 0.8, 1))
	end
	return ColorSequence.new(keys)
end

function AvatarService:Init(S)
	self.S = S
	if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
		PhysicsService:RegisterCollisionGroup(GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end

function AvatarService:InkColor(player: Player): Color3
	local assigned = self.S.MatchService:AssignedColor(player)
	if assigned then
		return assigned
	end
	local data = self.S.DataService:Get(player)
	local ink = Cosmetics.get(data and data.equipped.ink or Cosmetics.Defaults.ink)
	return rgb(ink.color)
end

local function tag(inst)
	inst.Name = "CosmeticFX"
	CollectionService:AddTag(inst, "CosmeticFX")
	return inst
end

function AvatarService:_applyFx(root: BasePart, fx, color: Color3)
	if fx.kind == "trail" then
		local a0 = tag(Instance.new("Attachment"))
		a0.Position = Vector3.new(0, 0.9, 0)
		a0.Parent = root
		local a1 = tag(Instance.new("Attachment"))
		a1.Position = Vector3.new(0, -0.9, 0)
		a1.Parent = root
		local trail = tag(Instance.new("Trail"))
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = if fx.rainbow then rainbow() else ColorSequence.new(color)
		trail.Lifetime = if fx.long then 1.4 else 0.6
		trail.LightEmission = 0.7
		trail.FaceCamera = true
		trail.Transparency = NumberSequence.new(0.15, 1)
		trail.Parent = root
	elseif fx.kind == "sparkles" then
		local s = tag(Instance.new("Sparkles"))
		s.SparkleColor = color
		s.Parent = root
	elseif fx.kind == "fire" then
		local f = tag(Instance.new("Fire"))
		f.Color = color
		f.SecondaryColor = Color3.new(1, 1, 1)
		f.Size = 4
		f.Heat = 6
		f.Parent = root
	elseif fx.kind == "smoke" then
		local s = tag(Instance.new("Smoke"))
		s.Color = color
		s.Opacity = 0.15
		s.RiseVelocity = 2
		s.Size = 2
		s.Parent = root
	elseif fx.kind == "particles" then
		local p = tag(Instance.new("ParticleEmitter"))
		p.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		p.LightEmission = 1
		p.Rate = 14
		p.Lifetime = NumberRange.new(0.6, 1.2)
		p.Speed = NumberRange.new(1, 3)
		p.Size = NumberSequence.new(0.5, 0)
		p.Parent = root
	end
end

function AvatarService:Refresh(player: Player)
	local char = player.Character
	local data = self.S.DataService:Get(player)
	local head = char and char:FindFirstChild("Head")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (data and head and root) then
		return
	end
	for _, inst in root:GetChildren() do
		if inst.Name == "CosmeticFX" then
			inst:Destroy()
		end
	end
	local color = self:InkColor(player)
	local passes = self.S.MonetizationService:GetPasses(player)
	local fx = Cosmetics.get(data.equipped.trail)
	if fx and Cosmetics.isUnlocked(data, passes, fx) then
		self:_applyFx(root, fx, color)
	end

	local tagGui = head:FindFirstChild("Nametag") or Instance.new("BillboardGui")
	tagGui.Name = "Nametag"
	tagGui.Size = UDim2.fromOffset(220, 56)
	tagGui.StudsOffset = Vector3.new(0, 2.8, 0)
	tagGui.MaxDistance = 140
	tagGui:ClearAllChildren()
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.58)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.Text = (if passes.VIP then "[VIP] " else "") .. player.DisplayName
	nameLabel.TextColor3 = if passes.VIP then Color3.fromRGB(255, 210, 70) else color
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Parent = tagGui
	local title = Cosmetics.get(data.equipped.title)
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(230, 230, 255)
	sub.TextStrokeTransparency = 0.4
	local titleText = if title and title.name ~= "" and Cosmetics.isUnlocked(data, passes, title) then title.name .. "  -  " else ""
	sub.Text = titleText .. "Lv " .. data.level
	sub.Parent = tagGui
	tagGui.Parent = head
end

function AvatarService:_setup(player: Player, char: Model)
	local function group(inst)
		if inst:IsA("BasePart") then
			inst.CollisionGroup = GROUP
		end
	end
	for _, d in char:GetDescendants() do
		group(d)
	end
	char.DescendantAdded:Connect(group)
	local humanoid = char:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.WalkSpeed = Config.Movement.WalkSpeed
	end
	char:WaitForChild("Head", 10)
	char:WaitForChild("HumanoidRootPart", 10)
	self:Refresh(player)
end

function AvatarService:Start()
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(char)
			self:_setup(player, char)
		end)
		if player.Character then
			task.spawn(self._setup, self, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	self.S.DataService.Loaded:Connect(function(player)
		self:Refresh(player)
	end)
end

return AvatarService
