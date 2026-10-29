-- Plays every sound in the game. Ids live in Shared/SoundIds; empty ids are
-- simply skipped, so the game works before custom audio is added.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundIds = require(ReplicatedStorage:WaitForChild("Shared").SoundIds)

local Sounds = {}

local cache: { [string]: Sound } = {}

local function template(name: string): Sound?
	local id = SoundIds[name]
	if not id or id == "" or id == "EXPLOSION" then
		return nil
	end
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Parent = SoundService
		cache[name] = sound
	end
	return sound
end

-- Non-positional UI sound
function Sounds.Play(name: string, volume: number?)
	local sound = template(name)
	if sound then
		sound.Volume = volume or 0.5
		SoundService:PlayLocalSound(sound)
	end
end

function Sounds.Pop()
	Sounds.Play("Pop", 0.4)
end

function Sounds.Click()
	Sounds.Play("Click", 0.5)
end

-- Positional sound in the world (cannons, splashes, crashes)
function Sounds.PlayAt(name: string, position: Vector3, volume: number?, pitch: number?)
	local id = SoundIds[name]
	if not id or id == "" then
		return
	end
	if id == "EXPLOSION" then
		-- Roblox's Explosion has a built-in boom; this one is invisible and harmless
		local explosion = Instance.new("Explosion")
		explosion.Position = position
		explosion.BlastRadius = 0
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.ExplosionType = Enum.ExplosionType.NoCraters
		explosion.Visible = false
		explosion.Parent = workspace
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace.CurrentCamera
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.8
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMaxDistance = 600
	sound.RollOffMinDistance = 20
	sound.Parent = anchor
	sound:Play()
	task.delay(6, function()
		anchor:Destroy()
	end)
end

-- A looping sound whose volume can be faded (ambience, music)
function Sounds.Loop(name: string): Sound?
	local id = SoundIds[name]
	if not id or id == "" or id == "EXPLOSION" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	return sound
end

return Sounds
