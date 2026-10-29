--!strict
-- Global tuning values shared by server and client.

local Config = {}

-- World
Config.SEA_LEVEL = 0
Config.OCEAN_SIZE = 4400 -- studs, square
Config.OCEAN_DEPTH = 40
Config.WORLD_RADIUS = 2050 -- ships are gently pushed back beyond this

-- Safe zones: no damage within this distance of any island's shore
Config.ISLAND_SAFE_MARGIN = 150

-- Ramming: an impact is a sudden loss of speed within one sample (0.1s)
Config.RAM_MIN_DROP = 9 -- studs/s of speed lost
Config.RAM_DAMAGE_PER_SPEED = 2 -- damage to the ship that was hit
Config.RAM_SELF_DAMAGE = 1.2 -- damage to the rammer per stud/s above the threshold
Config.RAM_BONUS = 3 -- multiplier for ships with a Ram bow

-- Ship building grid
Config.GRID = 4 -- studs per block cell
Config.BUILD_BOUNDS = { MinX = -3, MaxX = 3, MinY = -1, MaxY = 5, MinZ = -7, MaxZ = 7 }
Config.BIG_BUILD_BOUNDS = { MinX = -5, MaxX = 5, MinY = -1, MaxY = 7, MinZ = -11, MaxZ = 11 } -- "Grand Shipyard" pass
Config.MAX_BLOCKS = 220

-- Virtual drydocks: generated on demand far away from the playable ocean,
-- one per player who is building, so the world never needs more berths.
Config.DRYDOCK_ORIGIN = Vector3.new(0, 0, 6000)
Config.DRYDOCK_SPACING = 200

-- Ship physics
Config.BASE_THRUST = 8 -- "oars": every ship can crawl, even without sails
Config.BASE_TURN = 0.5 -- radians / second
Config.MAX_TURN = 1.6
Config.SPEED_FACTOR = 3.5
Config.MAX_SPEED = 70

-- Cargo: goods are physical crates carried by hand and stowed in Cargo Crate blocks
Config.CRATE_MASS = 4
Config.CRATES_PER_HOLD = 2
Config.CARRY_WALKSPEED = 11
Config.PAD_CRATES_PER_PLAYER = 6
Config.LOOSE_CRATE_LIFETIME = 300

-- Interaction ranges
Config.DOCK_RADIUS = 95
Config.TRADER_RANGE = 40
Config.SHOP_RANGE = 40
Config.SHIP_ACCESS_RANGE = 80 -- how close you must be to your ship to enter the drydock

-- Combat
Config.CANNON_SPEED = 240
Config.CANNON_GRAVITY = 60
Config.CANNON_DAMAGE = 20
Config.CANNON_PLAYER_DAMAGE = 35
Config.CANNON_COOLDOWN = 4
Config.SINK_DURATION = 14 -- seconds the wreck takes to go under
Config.RESPAWN_DELAY = 20 -- seconds until a sunk player ship is rebuilt in harbour
Config.HARBOUR_REPAIR_RATE = 4 -- HP per second inside the safe harbour
Config.REPAIR_KIT_HP = 35

-- Pirates
Config.PIRATE_COUNT = 3
Config.PIRATE_RESPAWN = 90
Config.PIRATE_AGGRO_RANGE = 320
Config.PIRATE_REWARD = 150

-- Storms
Config.STORM_ENABLED = true
Config.STORM_RADIUS = 280
Config.STORM_DURATION = 180
Config.STORM_INTERVAL = { 180, 360 }

-- Crew
Config.MAX_CREW = 4 -- members besides the captain

-- Economy
Config.STARTING_GOLD = 150
Config.HARVEST_REGROW = 25

-- Gamepasses. Create them on the Creator Dashboard and paste the IDs here.
-- A pass with Id = 0 is shown as "coming soon" and grants nothing.
Config.GAMEPASSES = {
	GrandShipyard = {
		Id = 0,
		Name = "Grand Shipyard",
		Icon = "🏗️",
		Description = "A much bigger build frame: 11 wide, 23 long, 9 tall.",
	},
	MerchantGuild = {
		Id = 0,
		Name = "Merchant Guild",
		Icon = "💰",
		Description = "+25% gold every time you sell a crate.",
	},
	ShipwrightFriend = {
		Id = 0,
		Name = "Shipwright's Friend",
		Icon = "🔨",
		Description = "25% off everything in the Shipwright's shop.",
	},
}
Config.GAMEPASS_ORDER = { "GrandShipyard", "MerchantGuild", "ShipwrightFriend" }

-- Visuals
Config.OUTLINES_ENABLED = true
Config.DAY_CYCLE_ENABLED = true
Config.DAY_LENGTH_MINUTES = 16

-- Persistence
Config.DATASTORE_NAME = "BuildYourShip_v3"
Config.AUTOSAVE_INTERVAL = 120

return Config
