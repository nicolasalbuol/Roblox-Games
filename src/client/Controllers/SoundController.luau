-- Local SFX/music with volume from saved settings. IDs come from Config.Audio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local SoundController = { sfx = 0.8, music = 0.5, cache = {} }

function SoundController:Play(name: string, scale: number?, pitch: number?)
	local id = Config.Audio[name]
	if not id or id == "" or self.sfx <= 0 then
		return
	end
	local s = self.cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "SFX_" .. name
		s.SoundId = id
		s.Parent = SoundService
		self.cache[name] = s
	end
	s.Volume = self.sfx * 0.6 * (scale or 1)
	s.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(s)
end

function SoundController:SetVolumes(sfx: number, music: number)
	self.sfx, self.music = sfx, music
	if self.musicSound then
		self.musicSound.Volume = music * 0.35
	end
end

function SoundController:Start()
	if Config.Audio.Music ~= "" then
		local m = Instance.new("Sound")
		m.Name = "Music"
		m.SoundId = Config.Audio.Music
		m.Looped = true
		m.Volume = self.music * 0.35
		m.Parent = SoundService
		m:Play()
		self.musicSound = m
	end
end

return SoundController
