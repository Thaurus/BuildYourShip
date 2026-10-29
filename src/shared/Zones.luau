-- Sea zones are rings around Port Haven. Each needs a more advanced ship:
-- you start rowing in the Sheltered Bay, need a proper sailing ship for the
-- Open Sea, and a steam/motor ship with iron plating for the Far Reaches.
-- A ship that isn't rated for a zone is pushed back by the rough water.

local Islands = require(script.Parent.Islands)
local ShipGrid = require(script.Parent.ShipGrid)

local Zones = {}

export type Rule = { Text: string, Ok: boolean }

Zones.Defs = {
	{
		Name = "Sheltered Bay",
		Era = "Rowing",
		Outer = 650,
		Swell = 1,
		Waves = 0.35,
		Requirements = function(_m): { Rule }
			return {}
		end,
	},
	{
		Name = "Open Sea",
		Era = "Sailing",
		Outer = 1300,
		Swell = 1.8,
		Waves = 0.65,
		Requirements = function(m): { Rule }
			return {
				{ Text = "At least one sail", Ok = m.Sails >= 1 },
				{ Text = `A keel ({m.Keels}/1)`, Ok = m.Keels >= 1 },
				{ Text = `Waterline hull of 10+ ({m.Waterline})`, Ok = m.Waterline >= 10 },
				{ Text = `7+ blocks long ({m.Length})`, Ok = m.Length >= 7 },
			}
		end,
	},
	{
		Name = "Far Reaches",
		Era = "Steam",
		Outer = math.huge,
		Swell = 2.6,
		Waves = 0.95,
		Requirements = function(m): { Rule }
			return {
				{ Text = "A steam engine or motor", Ok = m.Engines >= 1 },
				{ Text = `Iron or steel waterline plates ({m.MetalWaterline}/4)`, Ok = m.MetalWaterline >= 4 },
				{ Text = `Two keels ({m.Keels}/2)`, Ok = m.Keels >= 2 },
				{ Text = `Waterline hull of 16+ ({m.Waterline})`, Ok = m.Waterline >= 16 },
				{ Text = `9+ blocks long ({m.Length})`, Ok = m.Length >= 9 },
			}
		end,
	},
}

-- Zone index at a world position (distance from Port Haven)
function Zones.At(position: Vector3): number
	local home = Islands.Get("PortHaven").Position
	local d = Vector3.new(position.X - home.X, 0, position.Z - home.Z).Magnitude
	for i, zone in Zones.Defs do
		if d <= zone.Outer then
			return i
		end
	end
	return #Zones.Defs
end

function Zones.Get(index: number)
	return Zones.Defs[index]
end

-- Requirements for one zone, evaluated against a blueprint
function Zones.Check(blueprint, index: number): (boolean, { Rule })
	local rules = Zones.Defs[index].Requirements(ShipGrid.Metrics(blueprint))
	local ok = true
	for _, rule in rules do
		ok = ok and rule.Ok
	end
	return ok, rules
end

-- Highest zone this ship may sail in (zones must be passed in order)
function Zones.Rating(blueprint): number
	local rating = 1
	for i = 2, #Zones.Defs do
		if Zones.Check(blueprint, i) then
			rating = i
		else
			break
		end
	end
	return rating
end

return Zones
