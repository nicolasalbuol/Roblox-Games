-- Draws server bots locally from compact position packets, with smoothing and a squishy bob.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)

local FLOOR = Config.Grid.FloorY
local BotRenderer = { bots = {} }

local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		p[k] = v
	end
	return p
end

function BotRenderer:_create(slot: number)
	local model = Instance.new("Model")
	model.Name = "Bot_" .. slot
	local body = newPart({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.4, Material = Enum.Material.SmoothPlastic, Color = State:ColorOf(slot), Parent = model })
	local eyes = {}
	for _, side in { -0.55, 0.55 } do
		local eye = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = Color3.new(1, 1, 1), Parent = model })
		local pupil = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Color = Color3.fromRGB(20, 20, 30), Parent = model })
		table.insert(eyes, { eye, Vector3.new(side, 0.45, -1.45) })
		table.insert(eyes, { pupil, Vector3.new(side, 0.45, -1.85) })
	end
	model.PrimaryPart = body
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 30)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.MaxDistance = 140
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = State:ColorOf(slot)
	t.TextStrokeTransparency = 0.25
	t.Text = State:NameOf(slot)
	t.Parent = bb
	bb.Parent = body
	model.Parent = workspace
	return { model = model, body = body, eyes = eyes, label = t, pos = nil, target = nil, alive = false, yaw = 0 }
end

function BotRenderer:_sync()
	for slot, b in self.bots do
		local e = State.bySlot[slot]
		if not e or not e.isBot then
			b.model:Destroy()
			self.bots[slot] = nil
		else
			b.body.Color = e.color3
			b.label.TextColor3 = e.color3
			b.label.Text = e.name
		end
	end
end

function BotRenderer:Start()
	State.RosterChanged:Connect(function()
		self:_sync()
	end)
	Net.BotPos.OnClientEvent:Connect(function(buf)
		local count = buffer.readu8(buf, 0)
		for k = 1, count do
			local o = 1 + (k - 1) * 10
			local slot = buffer.readu8(buf, o)
			local e = State.bySlot[slot]
			if e and e.isBot then
				local b = self.bots[slot] or self:_create(slot)
				self.bots[slot] = b
				local target = Vector3.new(buffer.readf32(buf, o + 2), FLOOR, buffer.readf32(buf, o + 6))
				local alive = buffer.readu8(buf, o + 1) == 1
				if alive and (not b.alive or not b.pos or (target - b.pos).Magnitude > 20) then
					b.pos = target -- respawn / teleport: snap
				end
				b.alive, b.target = alive, target
				b.model.Parent = if alive then workspace else nil
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, b in self.bots do
			if b.alive and b.pos and b.target then
				local prev = b.pos
				b.pos = prev:Lerp(b.target, 1 - math.exp(-12 * dt))
				local move = b.pos - prev
				if move.Magnitude > 0.01 then
					b.yaw = math.atan2(-move.X, -move.Z)
				end
				local bob = if move.Magnitude > 0.01 then math.abs(math.sin(t * 12)) * 0.5 else 0
				local root = CFrame.new(b.pos + Vector3.new(0, 1.7 + bob, 0)) * CFrame.Angles(0, b.yaw, 0)
				b.body.CFrame = root
				for _, pair in b.eyes do
					pair[1].CFrame = root * CFrame.new(pair[2])
				end
			end
		end
	end)
end

return BotRenderer
