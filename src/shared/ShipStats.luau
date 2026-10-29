-- Derives sailing and combat stats from a blueprint plus the crates on board.

local Config = require(script.Parent.Config)
local Items = require(script.Parent.Items)

local ShipStats = {}

function ShipStats.Compute(blueprint, crateCount: number)
	local mass, buoyancy, thrust, turn, slots, hp, stability, cannons = 0, 0, Config.BASE_THRUST, 0, 0, 0, 0, 0
	for _, entry in blueprint do
		local def = Items.Get(entry.t)
		local s = def and def.Stats
		if s then
			mass += s.Mass or 0
			buoyancy += s.Buoyancy or 0
			thrust += s.Thrust or 0
			turn += s.Turn or 0
			slots += s.Crates or 0
			hp += s.HP or 0
			stability += s.Stability or 0
		end
		if entry.t == "Cannon" then
			cannons += 1
		end
	end

	-- Crate space is limited by cargo holds AND by how much extra weight the hull can float.
	local reserve = math.max(0, math.floor((buoyancy - mass) / Config.CRATE_MASS))
	local maxCrates = math.min(slots, reserve)
	local totalMass = mass + crateCount * Config.CRATE_MASS
	local overloaded = totalMass > buoyancy
	local load = if buoyancy > 0 then totalMass / buoyancy else 2

	local maxSpeed = math.min(Config.MAX_SPEED, Config.SPEED_FACTOR * thrust / math.sqrt(math.max(totalMass, 1)))
	if overloaded then
		maxSpeed *= 0.25
	end
	local turnRate = math.min(Config.MAX_TURN, Config.BASE_TURN + turn) / (1 + totalMass / 400)

	-- How deep the hull sits: light ships ride high, heavy ships sit low.
	local draft = math.clamp((load - 0.5) * 2.5, -1, 3)

	return {
		Blocks = #blueprint,
		Mass = totalMass,
		Buoyancy = buoyancy,
		Thrust = thrust,
		CrateSlots = slots,
		MaxCrates = maxCrates,
		Load = load,
		Overloaded = overloaded,
		MaxSpeed = maxSpeed,
		TurnRate = turnRate,
		MaxHP = math.max(10, hp),
		Stability = stability,
		Cannons = cannons,
		-- Root height above sea level: the hull's top row sits just above the waterline
		FloatOffset = -0.6 - draft,
	}
end

return ShipStats
