-- Island definitions. The world builder, market and navigation markers all read from here.
--
-- Market.Sells: goods the island produces (cheap to buy here), factor x base price
-- Market.Buys:  goods the island wants (good price when you sell here), factor x base price

local Config = require(script.Parent.Config)

local Islands = {}

Islands.Defs = {
	PortHaven = {
		Name = "Port Haven",
		Position = Vector3.new(0, 0, 0),
		Radius = 90,
		Biome = "Home",
		Home = true,
		Resources = { Oak = 8, Palm = 5, Bush = 6 },
		Trader = { Name = "Captain Marlo", Shirt = Color3.fromRGB(64, 120, 220), Hat = Color3.fromRGB(40, 50, 90) },
		Stall = Color3.fromRGB(64, 142, 232),
		Market = {
			Sells = { Fish = 0.6, Pottery = 0.65 },
			Buys = { Spices = 1.5, Tools = 1.4, Furs = 1.3 },
		},
	},
	PalmCove = {
		Name = "Palm Cove",
		Position = Vector3.new(650, 0, -560),
		Radius = 72,
		Biome = "Tropical",
		Resources = { Palm = 14, Bush = 10 },
		Trader = { Name = "Kiki Coco", Shirt = Color3.fromRGB(255, 120, 160), Hat = Color3.fromRGB(246, 220, 120) },
		Stall = Color3.fromRGB(255, 120, 160),
		Market = {
			Sells = { Fruit = 0.6, Coffee = 0.65 },
			Buys = { Pottery = 1.6, Tools = 1.5, Fish = 1.3 },
		},
	},
	Ironrock = {
		Name = "Ironrock",
		Position = Vector3.new(-880, 0, -260),
		Radius = 85,
		Biome = "Rocky",
		Resources = { Pine = 6, Iron = 10 },
		Trader = { Name = "Old Brannoc", Shirt = Color3.fromRGB(150, 80, 50), Hat = Color3.fromRGB(70, 70, 80) },
		Stall = Color3.fromRGB(255, 152, 54),
		Market = {
			Sells = { Tools = 0.6 },
			Buys = { Fish = 1.6, Fruit = 1.6, Coffee = 1.5 },
		},
	},
	SpiceAtoll = {
		Name = "Spice Atoll",
		Position = Vector3.new(920, 0, 620),
		Radius = 62,
		Biome = "Tropical",
		Resources = { Palm = 8, Bush = 10 },
		Trader = { Name = "Madame Saffra", Shirt = Color3.fromRGB(150, 96, 220), Hat = Color3.fromRGB(232, 72, 60) },
		Stall = Color3.fromRGB(150, 96, 220),
		Market = {
			Sells = { Spices = 0.6 },
			Buys = { Fish = 1.5, Tools = 1.6, Pottery = 1.5, Furs = 1.4 },
		},
	},
	Frostpeak = {
		Name = "Frostpeak",
		Position = Vector3.new(-520, 0, 980),
		Radius = 82,
		Biome = "Snowy",
		Resources = { Pine = 12, Iron = 5 },
		Trader = { Name = "Yrsa Frostbeard", Shirt = Color3.fromRGB(40, 192, 182), Hat = Color3.fromRGB(246, 251, 255) },
		Stall = Color3.fromRGB(40, 192, 182),
		Market = {
			Sells = { Furs = 0.6 },
			Buys = { Spices = 1.6, Coffee = 1.6, Fruit = 1.5 },
		},
	},
}

Islands.Order = { "PortHaven", "PalmCove", "Ironrock", "SpiceAtoll", "Frostpeak" }

Islands.HOME_PIER_LENGTH = 160
Islands.PIER_LENGTH = 56
Islands.HOME_HARBOUR_RADIUS = 360 -- the safe harbour around Port Haven

for id, def in Islands.Defs do
	def.Id = id
	if def.Home then
		def.DockDirection = Vector3.new(0, 0, 1)
	else
		-- Piers point back towards Port Haven so the way home is obvious.
		local toHome = Islands.Defs.PortHaven.Position - def.Position
		def.DockDirection = Vector3.new(toHome.X, 0, toHome.Z).Unit
	end
end

function Islands.Get(id: string)
	return Islands.Defs[id]
end

-- Where ships moor. Being within the dock radius of this point counts as "docked".
function Islands.GetDockPoint(def): Vector3
	if def.Home then
		return def.Position + def.DockDirection * (def.Radius + Islands.HOME_PIER_LENGTH * 0.5)
	end
	return def.Position + def.DockDirection * (def.Radius + Islands.PIER_LENGTH + 14)
end

function Islands.GetDockRadius(def): number
	if def.Home then
		return Islands.HOME_HARBOUR_RADIUS
	end
	return Config.DOCK_RADIUS
end

-- No cannon fire or damage inside Port Haven's harbour.
function Islands.IsSafe(position: Vector3): boolean
	local home = Islands.Defs.PortHaven
	local dock = Islands.GetDockPoint(home)
	return Vector3.new(position.X - dock.X, 0, position.Z - dock.Z).Magnitude <= Islands.HOME_HARBOUR_RADIUS
end

function Islands.FindDocked(position: Vector3): string?
	for _, id in Islands.Order do
		local def = Islands.Defs[id]
		local dock = Islands.GetDockPoint(def)
		local flat = Vector3.new(position.X - dock.X, 0, position.Z - dock.Z)
		if flat.Magnitude <= Islands.GetDockRadius(def) then
			return id
		end
	end
	return nil
end

return Islands
