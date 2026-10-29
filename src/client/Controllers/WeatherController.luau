-- Storm visuals: dark clouds over the storm area seen from afar, and rain,
-- thick fog, darker grading and lightning flashes when you sail into it.
-- Reads the replicated ReplicatedStorage.Weather attributes from StormService.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeatherController = {}

function WeatherController.Init(_ctx)
	local weather = ReplicatedStorage:WaitForChild("Weather")
	local camera = workspace.CurrentCamera
	local atmosphere = Lighting:WaitForChild("SeaAir", 10) :: Atmosphere?
	local grade = Lighting:WaitForChild("Grade", 10) :: ColorCorrectionEffect?
	local baseDensity = if atmosphere then atmosphere.Density else 0.32
	local baseBrightness = if grade then grade.Brightness else 0

	-- Storm clouds: a cluster of big dark puffs that follows the storm
	local clouds = Instance.new("Model")
	clouds.Name = "StormClouds"
	local puffs = {}
	local rng = Random.new(7)
	for i = 1, 14 do
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		local size = rng:NextNumber(90, 160)
		puff.Size = Vector3.new(size, size, size)
		puff.Material = Enum.Material.SmoothPlastic
		puff.Color = Color3.fromRGB(70, 74, 82)
		puff.Transparency = 0.25
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.CastShadow = true
		puff.Parent = clouds
		local a = i / 14 * math.pi * 2
		puffs[i] = { Part = puff, Offset = Vector3.new(math.cos(a) * rng:NextNumber(40, 200), rng:NextNumber(150, 190), math.sin(a) * rng:NextNumber(40, 200)) }
	end
	clouds.Parent = camera

	-- Rain follows the camera
	local rainPart = Instance.new("Part")
	rainPart.Name = "Rain"
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Transparency = 1
	rainPart.Size = Vector3.new(120, 1, 120)
	rainPart.Parent = camera
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(200, 210, 225))
	rain.Size = NumberSequence.new(0.25)
	rain.Squash = NumberSequence.new(-4)
	rain.Transparency = NumberSequence.new(0.3)
	rain.Lifetime = NumberRange.new(1, 1.4)
	rain.Speed = NumberRange.new(90, 110)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Rate = 0
	rain.LightInfluence = 0.6
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Parent = rainPart

	local intensity = 0
	local nextFlash = 0
	RunService.RenderStepped:Connect(function(dt)
		local active = weather:GetAttribute("Active")
		local target = 0
		local stormPos = weather:GetAttribute("Position") :: Vector3?
		if active and stormPos then
			local radius = weather:GetAttribute("Radius") or 280
			local strength = weather:GetAttribute("Strength") or 1
			local camPos = camera.CFrame.Position
			local d = Vector3.new(camPos.X - stormPos.X, 0, camPos.Z - stormPos.Z).Magnitude
			target = math.clamp((1 - d / radius) * 1.6, 0, 1) * strength
			for _, puff in puffs do
				puff.Part.CFrame = CFrame.new(stormPos + puff.Offset)
				puff.Part.Transparency = 1 - 0.75 * strength
			end
		else
			for _, puff in puffs do
				puff.Part.Transparency = 1
			end
		end
		intensity += (target - intensity) * math.min(1, dt * 1.5)

		rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 60, 0))
		rain.Rate = intensity * 1500
		if atmosphere then
			atmosphere.Density = baseDensity + intensity * 0.35
		end
		local flash = 0
		if intensity > 0.4 and os.clock() > nextFlash then
			nextFlash = os.clock() + math.random(4, 12)
			flash = 0.6
		end
		if grade then
			grade.Brightness = baseBrightness - intensity * 0.12 + flash
			if flash > 0 then
				task.delay(0.08, function()
					grade.Brightness = baseBrightness - intensity * 0.12
				end)
			end
		end
	end)
end

return WeatherController
