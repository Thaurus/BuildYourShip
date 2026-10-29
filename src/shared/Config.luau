--!strict
-- Global tuning values shared by server and client.

local Config = {}

-- World
Config.SEA_LEVEL = 0
Config.OCEAN_SIZE = 3400 -- studs, square
Config.OCEAN_DEPTH = 40
Config.WORLD_RADIUS = 1450 -- ships are gently pushed back beyond this

-- Ship building grid
Config.GRID = 4 -- studs per block cell
Config.BUILD_BOUNDS = {
	MinX = -3,
	MaxX = 3,
	MinY = -1,
	MaxY = 5,
	MinZ = -6,
	MaxZ = 6,
}
Config.MAX_BLOCKS = 180
Config.MAX_BERTHS = 10

-- Ship physics
Config.BASE_THRUST = 8 -- "oars": every ship can crawl, even without sails
Config.BASE_TURN = 0.5 -- radians / second
Config.MAX_TURN = 1.6
Config.SPEED_FACTOR = 3.5
Config.MAX_SPEED = 70
Config.CARGO_UNIT_MASS = 1

-- Interaction ranges
Config.DOCK_RADIUS = 95
Config.BERTH_RADIUS = 60
Config.TRADER_RANGE = 40
Config.SHOP_RANGE = 40

-- Economy
Config.STARTING_GOLD = 150
Config.HARVEST_REGROW = 25

-- Atmosphere
Config.DAY_CYCLE_ENABLED = true
Config.DAY_LENGTH_MINUTES = 14

-- Persistence
Config.DATASTORE_NAME = "BuildYourShip_v1"
Config.AUTOSAVE_INTERVAL = 120

return Config
