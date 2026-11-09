-- Top-down follow camera while playing (territory readability), normal Roblox camera in the hub.
-- Mouse wheel / pinch zooms. Setting "classic" keeps the default camera everywhere.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.State)

local LocalPlayer = Players.LocalPlayer
local CameraController = { height = 62, shake = 0, mode = "top" }

local MIN_H, MAX_H = 34, 95

function CameraController:Shake(amount: number)
	self.shake = math.max(self.shake, amount)
end

function CameraController:SetMode(mode: string)
	self.mode = mode
end

function CameraController:Start()
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			self.height = math.clamp(self.height - input.Position.Z * 5, MIN_H, MAX_H)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
		if not processed and state == Enum.UserInputState.Change then
			self.height = math.clamp(self.height / math.clamp(scale, 0.9, 1.1), MIN_H, MAX_H)
		end
	end)

	local wasActive = false
	RunService:BindToRenderStep("ChromaCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = workspace.CurrentCamera
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local roundState = State:RoundState()
		local active = self.mode == "top" and State.mySlot ~= nil and roundState == "Playing" and root ~= nil
		if active then
			cam.CameraType = Enum.CameraType.Scriptable
			local focus = root.Position
			local goal = CFrame.lookAt(focus + Vector3.new(0, self.height, self.height * 0.5), focus)
			if self.shake > 0.01 then
				goal *= CFrame.new((math.random() - 0.5) * self.shake, (math.random() - 0.5) * self.shake, 0)
				self.shake *= math.exp(-8 * dt)
			end
			cam.CFrame = if wasActive then cam.CFrame:Lerp(goal, 1 - math.exp(-12 * dt)) else goal
		elseif wasActive then
			cam.CameraType = Enum.CameraType.Custom
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				cam.CameraSubject = hum
			end
		end
		wasActive = active
	end)
end

return CameraController
