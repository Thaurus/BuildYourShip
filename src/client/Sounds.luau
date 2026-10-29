-- Tiny UI sound helper using sounds bundled with the Roblox client.

local SoundService = game:GetService("SoundService")

local Sounds = {}

local function make(id: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local pop = make("rbxasset://sounds/electronicpingshort.wav", 0.4)
local click = make("rbxasset://sounds/clickfast.wav", 0.5)

function Sounds.Pop()
	SoundService:PlayLocalSound(pop)
end

function Sounds.Click()
	SoundService:PlayLocalSound(click)
end

return Sounds
