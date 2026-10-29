-- Roaming storms. A storm drifts across the open sea for a few minutes:
-- ships inside roll harder, get pushed by the wind, and heavily loaded hulls
-- take on water (damage). Keels reduce both. Clients read the replicated
-- "Weather" folder attributes to draw rain, fog and lightning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Islands = require(Shared.Islands)
local Zones = require(Shared.Zones)

local StormService = {}
local S

local weather: Folder
local rng = Random.new()
local storm = nil -- { Position, Velocity, Radius, Ends }
local wind = Vector3.new(1, 0, 0)

function StormService.Init(services)
	S = services
	weather = Instance.new("Folder")
	weather.Name = "Weather"
	weather:SetAttribute("Active", false)
	weather.Parent = ReplicatedStorage
end

-- 0 outside, rising smoothly to 1 at the eye
function StormService.IntensityAt(position: Vector3): number
	if not storm then
		return 0
	end
	local d = Vector3.new(position.X - storm.Position.X, 0, position.Z - storm.Position.Z).Magnitude
	local t = 1 - d / storm.Radius
	if t <= 0 then
		return 0
	end
	return math.clamp(t * 1.6, 0, 1) * storm.Strength
end

function StormService.Wind(): Vector3
	return wind
end

local function publish()
	weather:SetAttribute("Active", storm ~= nil)
	if storm then
		weather:SetAttribute("Position", storm.Position)
		weather:SetAttribute("Radius", storm.Radius)
		weather:SetAttribute("Strength", storm.Strength)
	end
end

local function startStorm()
	for _ = 1, 30 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(Zones.Get(1).Outer + 250, Config.WORLD_RADIUS - 200) -- never in the Sheltered Bay
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if not Islands.IsSafe(pos) and (pos - Islands.Get("PortHaven").Position).Magnitude > 600 then
			local heading = rng:NextNumber(0, math.pi * 2)
			wind = Vector3.new(math.cos(heading), 0, math.sin(heading))
			storm = {
				Position = pos,
				Velocity = wind * rng:NextNumber(4, 8),
				Radius = Config.STORM_RADIUS,
				Strength = 0,
				Started = os.clock(),
			}
			return
		end
	end
end

function StormService.Start()
	if not Config.STORM_ENABLED then
		return
	end
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(Config.STORM_INTERVAL[1], Config.STORM_INTERVAL[2]))
			startStorm()
			while storm do
				task.wait(1)
				local age = os.clock() - storm.Started
				-- Build up over 20s, die down over the last 20s
				storm.Strength = math.clamp(math.min(age, Config.STORM_DURATION - age) / 20, 0, 1)
				storm.Position += storm.Velocity
				if age >= Config.STORM_DURATION or Islands.IsSafe(storm.Position) then
					storm = nil
				end
				publish()
				if storm then
					for _, ship in S.ShipService.All() do
						if ship.Root and ship.Root.Parent and not ship.Building and not ship.Sinking then
							local intensity = StormService.IntensityAt(ship.Root.Position)
							if intensity > 0.2 and ship.Stats.Load > 0.8 then
								local damage = 2 * intensity / (1 + ship.Stats.Stability * 0.5)
								S.ShipService.Damage(ship, damage)
							end
						end
					end
				end
			end
		end
	end)
end

return StormService
