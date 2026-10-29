-- Makes each sea zone feel different: calm water in the Sheltered Bay, bigger
-- waves further out. Terrain water settings changed on the client are local.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Zones = require(ReplicatedStorage:WaitForChild("Shared").Zones)

local ZoneController = {}

function ZoneController.Init(ctx)
	local terrain = workspace.Terrain
	local current = nil
	ctx.State.Observe(function(data)
		local zone = if data.Building then 1 else (data.Zone or 1)
		if zone == current then
			return
		end
		current = zone
		TweenService:Create(terrain, TweenInfo.new(4), {
			WaterWaveSize = Zones.Get(zone).Waves,
			WaterWaveSpeed = 10 + zone * 3,
		}):Play()
	end)
end

return ZoneController
