-- The guided path through the game. Steps unlock one at a time; each has an
-- objective, a waypoint target and a reward.
--
--   Event   what the server reports (see QuestService.Fire)
--   Item    optional filter for the event (item id, good id or island id)
--   Count   how many times it has to happen
--   Target  waypoint shown to the player:
--             "nearest:<Resource>"   closest harvest node of that resource
--             "trader:<IslandId>"    that island's trader
--             "dock:<IslandId>"      that island's pier
--             "shipwright"           Bosun Bertha in Port Haven
--             "ship"                 your own ship
--
-- "ShipTier" and "Discover" steps complete when the reported number is at
-- least the step's Item (ship zone rating / unlocked technology tier).

local Quests = {}

Quests.Steps = {
	-- Era 1: rowing in the Sheltered Bay ----------------------------------
	{
		Title = "Timber!",
		Text = "Chop 4 Wood from trees (walk up and hold E).",
		Event = "Harvest",
		Item = "Wood",
		Count = 4,
		Target = "nearest:Wood",
		Reward = { Gold = 20 },
	},
	{
		Title = "Plank it",
		Text = "Open your items (I) and craft 4 Planks.",
		Event = "Craft",
		Item = "Plank",
		Count = 4,
		Reward = { Gold = 20 },
	},
	{
		Title = "Hull of a job",
		Text = "Craft 2 Wooden Hull blocks.",
		Event = "Craft",
		Item = "WoodHull",
		Count = 2,
		Reward = { Gold = 30 },
	},
	{
		Title = "To the drydock",
		Text = "Walk to your rowing boat in Port Haven harbour and press B to open your drydock.",
		Event = "EnterBuild",
		Count = 1,
		Target = "ship",
	},
	{
		Title = "Make her longer",
		Text = "Place your 2 Wooden Hulls on both sides of the stern (back row). Keep it symmetric!",
		Event = "Place",
		Item = "WoodHull",
		Count = 2,
		Reward = { Gold = 40 },
	},
	{
		Title = "Launch day",
		Text = "Press B again to launch. The seaworthiness check must be all green!",
		Event = "Launch",
		Count = 1,
		Reward = { Gold = 30 },
	},
	{
		Title = "First cargo",
		Text = "Buy a crate of Fish from Captain Marlo at the pier.",
		Event = "BuyCrate",
		Item = "Fish",
		Count = 1,
		Target = "trader:PortHaven",
	},
	{
		Title = "Stow it",
		Text = "Pick up the crate, carry it aboard and stow it in the Cargo Crate (E).",
		Event = "Stow",
		Count = 1,
		Target = "ship",
		Reward = { Gold = 20 },
	},
	{
		Title = "Row, row, row",
		Text = "Board your boat and take the helm (H). W/S to row, A/D to steer.",
		Event = "Helm",
		Count = 1,
		Target = "ship",
	},
	{
		Title = "Palm Cove",
		Text = "Row across the bay to Palm Cove and moor at its pier. Islanders there know how to sail!",
		Event = "Dock",
		Item = "PalmCove",
		Count = 1,
		Target = "dock:PalmCove",
		Reward = { Gold = 40 },
	},
	{
		Title = "Turn a profit",
		Text = "Carry your Fish crate to Kiki Coco and sell it.",
		Event = "SellCrate",
		Count = 1,
		Target = "trader:PalmCove",
		Reward = { Gold = 40 },
	},
	-- Era 2: sailing the Open Sea ------------------------------------------
	{
		Title = "Canvas and rope",
		Text = "Sailing is unlocked! Craft or buy a Small Sail.",
		Event = "Craft",
		Item = "SmallSail",
		Count = 1,
		Reward = { Gold = 40 },
	},
	{
		Title = "A real ship",
		Text = "Redesign your boat for the Open Sea: a sail, a keel, 10+ waterline hull, 7+ long. Then launch.",
		Event = "ShipTier",
		Item = "2",
		Count = 1,
		Target = "ship",
		Reward = { Gold = 100 },
	},
	{
		Title = "Beyond the bay",
		Text = "Sail out onto the Open Sea and moor at Ironrock.",
		Event = "Dock",
		Item = "Ironrock",
		Count = 1,
		Target = "dock:Ironrock",
		Reward = { Gold = 60 },
	},
	{
		Title = "Iron will",
		Text = "Mine 6 Iron Ore from the glowing rocks on Ironrock.",
		Event = "Harvest",
		Item = "IronOre",
		Count = 6,
		Target = "nearest:Iron",
		Reward = { Gold = 30 },
	},
	{
		Title = "Gunsmith",
		Text = "Craft a Cannon (3 Iron Ingots + 2 Planks).",
		Event = "Craft",
		Item = "Cannon",
		Count = 1,
		Reward = { Items = { Cannonball = 8 } },
	},
	{
		Title = "Armed and ready",
		Text = "Mount the Cannon on your deck at the drydock. Rotate (R) so it faces the side.",
		Event = "Place",
		Item = "Cannon",
		Count = 1,
		Target = "ship",
		Reward = { Gold = 40 },
	},
	{
		Title = "Pirate hunter",
		Text = "Sink a pirate ship on the Open Sea. Press F to fire a broadside where your camera looks.",
		Event = "SinkPirate",
		Count = 1,
		Reward = { Gold = 200 },
	},
	{
		Title = "Better together",
		Text = "Invite a friend to your crew (C). Crews share trade gold.",
		Event = "CrewJoined",
		Count = 1,
		Reward = { Gold = 100 },
	},
	-- Era 3: steam and the Far Reaches -------------------------------------
	{
		Title = "Full steam ahead",
		Text = "Steam is unlocked! Build a Far Reaches ship: engine, 4 iron waterline plates, 2 keels, 16+ hull, 9+ long.",
		Event = "ShipTier",
		Item = "3",
		Count = 1,
		Target = "ship",
		Reward = { Gold = 300 },
	},
	{
		Title = "Edge of the map",
		Text = "Reach the Far Reaches and moor at Frostpeak or Cinder Isle.",
		Event = "Discover",
		Item = "4",
		Count = 1,
		Reward = { Gold = 300 },
	},
	{
		Title = "Merchant prince",
		Text = "Earn 5,000 gold from selling crates. Diesel motors and steel hulls await!",
		Event = "TradeGold",
		Count = 5000,
		Reward = { Gold = 1000 },
	},
}

function Quests.Get(step: number)
	return Quests.Steps[step]
end

return Quests
