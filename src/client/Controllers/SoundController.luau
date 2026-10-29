-- World audio: effect sounds (cannons, explosions, splashes, crashes),
-- thunder in storms, rowing splashes, ocean/wind ambience and music per zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local SoundController = {}

local EFFECT_SOUNDS = {
	Muzzle = { "CannonFire", 1, 1 },
	Explosion = { "Explosion", 1, 1 },
	Splash = { "Splash", 0.9, 0.9 },
	Impact = { "Impact", 0.8, 0.8 },
	Crash = { "Crash", 1, 0.6 },
}

function SoundController.Init(ctx)
	local Sounds = ctx.Sounds
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local weather = ReplicatedStorage:WaitForChild("Weather")

	Remotes.Event("Effect").OnClientEvent:Connect(function(kind, position)
		local spec = EFFECT_SOUNDS[kind]
		if spec and typeof(position) == "Vector3" then
			Sounds.PlayAt(spec[1], position, spec[2], spec[3])
		end
	end)

	-- Ambience and music fade with where you are
	local ocean = Sounds.Loop("OceanLoop")
	local wind = Sounds.Loop("WindLoop")
	local music = {
		Sounds.Loop("MusicBay"),
		Sounds.Loop("MusicOpenSea"),
		Sounds.Loop("MusicFarReaches"),
	}
	local drydockMusic = Sounds.Loop("MusicDrydock")

	local function fade(sound: Sound?, volume: number)
		if sound and math.abs(sound.Volume - volume) > 0.01 then
			TweenService:Create(sound, TweenInfo.new(2), { Volume = volume }):Play()
		end
	end

	local nextThunder = 0
	local nextStroke = 0
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		local data = ctx.State.Data
		if not data then
			return
		end
		local camPos = camera.CFrame.Position
		local atSea = camPos.Y < 60 and not data.Building

		-- Storm intensity at the camera (same formula as WeatherController)
		local storm = 0
		local stormPos = weather:GetAttribute("Position") :: Vector3?
		if weather:GetAttribute("Active") and stormPos then
			local radius = weather:GetAttribute("Radius") or 280
			local d = Vector3.new(camPos.X - stormPos.X, 0, camPos.Z - stormPos.Z).Magnitude
			storm = math.clamp((1 - d / radius) * 1.6, 0, 1) * (weather:GetAttribute("Strength") or 1)
		end

		fade(ocean, if atSea then 0.35 else 0.12)
		fade(wind, storm * 0.6)
		for i, track in music do
			fade(track, if not data.Building and data.Zone == i then 0.25 else 0)
		end
		fade(drydockMusic, if data.Building then 0.25 else 0)

		if storm > 0.4 and os.clock() > nextThunder then
			nextThunder = os.clock() + math.random(5, 12)
			local offset = Vector3.new(math.random(-200, 200), 120, math.random(-200, 200))
			Sounds.PlayAt("Thunder", camPos + offset, 1, 0.5)
		end

		-- Rowing splashes while at the helm of a ship with oars
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if seat and seat:IsA("VehicleSeat") and seat.ThrottleFloat ~= 0 and os.clock() > nextStroke then
			local ship = ctx.State.GetShipModel()
			local blocks = if ship then ship:GetChildren() else {}
			for _, child in blocks do
				if child:GetAttribute("BlockType") == "Oars" then
					nextStroke = os.clock() + 1.4
					Sounds.PlayAt("Rowing", seat.Position, 0.5, 0.9)
					break
				end
			end
		end
	end)
end

return SoundController
