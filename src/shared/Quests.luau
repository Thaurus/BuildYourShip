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

local Quests = {}

Quests.Steps = {
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
		Text = "Walk to your ship in Port Haven harbour and press B to open your drydock.",
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
		Text = "Press B again to launch. The vessel check must be all green!",
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
		Text = "Pick up the crate, carry it aboard and stow it in a Cargo Crate (E).",
		Event = "Stow",
		Count = 1,
		Target = "ship",
		Reward = { Gold = 20 },
	},
	{
		Title = "Take the helm",
		Text = "Board your ship and take the helm (H).",
		Event = "Helm",
		Count = 1,
		Target = "ship",
	},
	{
		Title = "Set sail",
		Text = "Sail to Ironrock and moor at its pier.",
		Event = "Dock",
		Item = "Ironrock",
		Count = 1,
		Target = "dock:Ironrock",
	},
	{
		Title = "Turn a profit",
		Text = "Carry the Fish crate to Old Brannoc and sell it.",
		Event = "SellCrate",
		Count = 1,
		Target = "trader:Ironrock",
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
		Text = "Sink a pirate ship. At sea, press F to fire a broadside where your camera looks.",
		Event = "SinkPirate",
		Count = 1,
		Reward = { Gold = 200 },
	},
	{
		Title = "Better together",
		Text = "Invite a friend to your crew (Crew button). Crews share trade gold.",
		Event = "CrewJoined",
		Count = 1,
		Reward = { Gold = 100 },
	},
	{
		Title = "Merchant prince",
		Text = "Earn 2,000 gold from selling crates. Big ships, big profits!",
		Event = "TradeGold",
		Count = 2000,
		Reward = { Gold = 500 },
	},
}

function Quests.Get(step: number)
	return Quests.Steps[step]
end

return Quests
