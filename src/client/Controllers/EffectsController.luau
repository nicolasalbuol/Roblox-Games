-- Juice: capture bursts, splats, pickups, spinning power-ups, reduced-effects mode.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local SoundController = require(script.Parent.SoundController)
local CameraController = require(script.Parent.CameraController)

local LocalPlayer = Players.LocalPlayer
local EffectsController = { reduced = false, pool = {}, poolIndex = 0 }

local POOL = 6

function EffectsController:_emitter()
	self.poolIndex = self.poolIndex % POOL + 1
	return self.pool[self.poolIndex]
end

function EffectsController:Burst(pos: Vector3, color: Color3, count: number)
	if self.reduced then
		count = math.floor(count / 3)
	end
	if count <= 0 then
		return
	end
	local e = self:_emitter()
	e.part.Position = pos
	e.emitter.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.6))
	e.emitter:Emit(count)
end

function EffectsController:SetReduced(on: boolean)
	self.reduced = on
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = not on
	end
	for _, inst in CollectionService:GetTagged("CosmeticFX") do
		if not inst:IsA("Attachment") then
			inst.Enabled = not on
		end
	end
end

local function myPosition(): Vector3?
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

function EffectsController:Start()
	for _ = 1, POOL do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.one
		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(14, 26)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, -50, 0)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) })
		emitter.LightEmission = 0.6
		emitter.Parent = part
		part.Parent = workspace
		table.insert(self.pool, { part = part, emitter = emitter })
	end

	CollectionService:GetInstanceAddedSignal("CosmeticFX"):Connect(function(inst)
		if self.reduced and not inst:IsA("Attachment") then
			inst.Enabled = false
		end
	end)

	State.MatchEvent:Connect(function(evt)
		if evt.t == "capture" then
			local pos = myPosition()
			if pos then
				self:Burst(pos, State:ColorOf(State.mySlot or 0), math.clamp(evt.n // 2, 12, 60))
			end
			SoundController:Play("Capture", 1, 1 + math.clamp(evt.n / 300, 0, 0.5))
			CameraController:Shake(math.clamp(evt.n / 60, 0.3, 1.6))
		elseif evt.t == "elim" then
			local pos = Vector3.new(evt.x, Config.Grid.FloorY + 2, evt.z)
			self:Burst(pos, State:ColorOf(evt.victim), 50)
			if evt.victim == State.mySlot then
				SoundController:Play("Splat")
				CameraController:Shake(2.5)
			elseif evt.killer == State.mySlot then
				SoundController:Play("Splat", 0.7, 1.3)
			end
		elseif evt.t == "powerup" and evt.slot == State.mySlot then
			SoundController:Play("Pickup", 1, 1.4)
		elseif evt.t == "roundStart" then
			SoundController:Play("RoundStart", 1, 0.8)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, p in CollectionService:GetTagged("Powerup") do
			if p:IsA("BasePart") then
				local base = p:GetAttribute("BaseY")
				if not base then
					base = p.Position.Y
					p:SetAttribute("BaseY", base)
				end
				p.CFrame = CFrame.new(p.Position.X, base + math.sin(t * 3) * 0.6, p.Position.Z) * CFrame.Angles(0, t * 2, 0)
			end
		end
	end)
end

return EffectsController
