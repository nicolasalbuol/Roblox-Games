-- Client bootstrap.
local ContextActionService = game:GetService("ContextActionService")

local Controllers = script.Parent.Controllers
local UI = script.Parent.UI

local State = require(Controllers.State)
local GridRenderer = require(Controllers.GridRenderer)
local BotRenderer = require(Controllers.BotRenderer)
local CameraController = require(Controllers.CameraController)
local SoundController = require(Controllers.SoundController)
local EffectsController = require(Controllers.EffectsController)

local Kit = require(UI.Kit)
local HUD = require(UI.HUD)
local Shop = require(UI.Shop)
local Quests = require(UI.Quests)
local Results = require(UI.Results)
local Settings = require(UI.Settings)
local Onboarding = require(UI.Onboarding)

State:Start()
GridRenderer:Start()
BotRenderer:Start()
CameraController:Start()
SoundController:Start()
EffectsController:Start()

local gui = Kit.root("ChromaUI")
HUD:Start(gui, Kit.openModal)
Shop:Start(gui)
Quests:Start(gui)
Results:Start(gui)
Settings:Start(gui)
Onboarding:Start(gui)

State.ProfileChanged:Connect(function(data)
	local s = data.settings
	SoundController:SetVolumes(s.sfx, s.music)
	CameraController:SetMode(s.camera)
	EffectsController:SetReduced(s.reducedFx)
	GridRenderer:SetReducedFx(s.reducedFx)
end)

-- Keyboard / gamepad shortcuts.
local function bind(name: string, modal: string, ...)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			Kit.openModal(modal)
		end
		return Enum.ContextActionResult.Sink
	end, false, ...)
end
bind("ChromaShop", "Shop", Enum.KeyCode.B, Enum.KeyCode.ButtonY)
bind("ChromaQuests", "Quests", Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
ContextActionService:BindAction("ChromaClose", function(_, state)
	if Kit.currentModal() then
		if state == Enum.UserInputState.Begin then
			Kit.closeModal()
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonB)

-- Ask for state only once every listener is connected.
State:Event("ready")
