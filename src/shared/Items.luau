-- Every item a player can own: raw resources, crafted materials, tools and ship blocks.
--
--   Kind       "Raw" (harvested), "Material" (crafted), "Tool" (usable), "Block" (placeable)
--   Price      gold cost at the Shipwright
--   Recipe     { [itemId] = amount } needed to craft one batch
--   Yield      how many items one craft produces (default 1)
--   Stats      ship stats contributed by a placed block (Mass, Buoyancy, Thrust, Turn, Crates, HP, Stability)
--   Cells      grid cells occupied relative to the anchor cell (default { {0,0,0} })
--   Placement  "Hull"    rows 0 and up, attaches anywhere
--              "Keel"    only the row below the waterline, directly under a hull block
--              "Mounted" on deck (row 1+), needs a block directly underneath
--   Fixed      always faces the bow (rotation is ignored)
--   Tier       technology era needed to craft or buy it (1 rowing, 2 sail, 3 steam, 4 motor);
--              higher tiers unlock by discovering islands in further zones (see Islands.Unlocks)

local Items = {}

Items.Defs = {
	-- Raw resources ---------------------------------------------------------
	Wood = { Name = "Wood", Icon = "🪵", Kind = "Raw", Price = 4, Description = "Chopped from trees on every island." },
	Fiber = { Name = "Fiber", Icon = "🌿", Kind = "Raw", Price = 4, Description = "Gathered from flax bushes on sunny islands." },
	IronOre = {
		Name = "Iron Ore",
		Icon = "🪨",
		Kind = "Raw",
		Price = 10,
		Description = "Mined from ore rocks on Ironrock and Frostpeak.",
	},

	-- Materials ------------------------------------------------------------
	Plank = { Name = "Plank", Icon = "🟫", Kind = "Material", Price = 10, Recipe = { Wood = 2 }, Description = "Sturdy planks for hulls and decks." },
	Rope = { Name = "Rope", Icon = "🪢", Kind = "Material", Price = 10, Recipe = { Fiber = 2 }, Description = "Every sailor needs rope." },
	Cloth = { Name = "Sailcloth", Icon = "🧵", Kind = "Material", Price = 14, Recipe = { Fiber = 3 }, Description = "Woven fiber for sails and flags." },
	IronIngot = {
		Name = "Iron Ingot",
		Icon = "🔩",
		Kind = "Material",
		Price = 28,
		Recipe = { IronOre = 2, Wood = 1 },
		Description = "Smelted iron for fittings, cannons and engines.",
	},
	Cannonball = {
		Name = "Cannonball",
		Icon = "⚫",
		Kind = "Material",
		Price = 8,
		Recipe = { IronIngot = 1 },
		Yield = 4,
		Description = "Ammunition. Every shot uses one.",
	},

	-- Tools ----------------------------------------------------------------
	RepairKit = {
		Name = "Repair Kit",
		Icon = "🧰",
		Kind = "Tool",
		Price = 30,
		Recipe = { Plank = 2, Rope = 1 },
		Description = "Patch up your hull at sea (+35 HP). Ships repair for free in Port Haven.",
	},

	-- Hull blocks ------------------------------------------------------------
	WoodHull = {
		Name = "Wooden Hull",
		Icon = "🧱",
		Kind = "Block",
		Placement = "Hull",
		Price = 35,
		Recipe = { Plank = 3 },
		Stats = { Mass = 3, Buoyancy = 10, HP = 10 },
		Description = "Planked hull. The backbone of every ship.",
	},
	Bow = {
		Name = "Bow",
		Icon = "🔺",
		Kind = "Block",
		Placement = "Hull",
		Fixed = true,
		Price = 45,
		Recipe = { Plank = 4 },
		Stats = { Mass = 3, Buoyancy = 8, HP = 10 },
		Description = "Tapered front of the hull. Your front row must be bows.",
	},
	Stern = {
		Name = "Stern",
		Icon = "🔻",
		Kind = "Block",
		Placement = "Hull",
		Fixed = true,
		Price = 45,
		Recipe = { Plank = 4 },
		Stats = { Mass = 3, Buoyancy = 9, HP = 10 },
		Description = "A proper transom with cabin windows for the back of the ship.",
	},
	Keel = {
		Tier = 2,
		Name = "Keel",
		Icon = "🦴",
		Kind = "Block",
		Placement = "Keel",
		Fixed = true,
		Price = 55,
		Recipe = { Plank = 2, IronIngot = 1 },
		Stats = { Mass = 4, Buoyancy = 3, HP = 8, Stability = 1 },
		Description = "Goes under the hull. Calmer in storms, takes less storm damage.",
	},
	IronHull = {
		Tier = 3,
		Name = "Iron Hull",
		Icon = "⬛",
		Kind = "Block",
		Placement = "Hull",
		Price = 90,
		Recipe = { IronIngot = 2, Plank = 1 },
		Stats = { Mass = 5, Buoyancy = 18, HP = 25 },
		Description = "Armoured plating. Heavy, but floats a lot and shrugs off cannonballs.",
	},
	Deck = {
		Name = "Deck Planks",
		Icon = "🪜",
		Kind = "Block",
		Placement = "Hull",
		Price = 14,
		Recipe = { Plank = 1 },
		Stats = { Mass = 1, Buoyancy = 2, HP = 3 },
		Description = "A light floor, flush with the top of the hull.",
	},

	-- Deck equipment -----------------------------------------------------------
	CargoHold = {
		Name = "Cargo Crate",
		Icon = "📦",
		Kind = "Block",
		Placement = "Mounted",
		Price = 50,
		Recipe = { Plank = 4, Rope = 1 },
		Stats = { Mass = 2, HP = 4, Crates = 2 },
		Description = "Stows 2 trade crates. Carry crates aboard and stow them here.",
	},
	SmallSail = {
		Tier = 2,
		Name = "Small Sail",
		Icon = "⛵",
		Kind = "Block",
		Placement = "Mounted",
		Price = 80,
		Recipe = { Plank = 3, Cloth = 3, Rope = 2 },
		Stats = { Mass = 2, Thrust = 40, HP = 4 },
		Cells = { { 0, 0, 0 }, { 0, 1, 0 }, { 0, 2, 0 } },
		Description = "A trusty mast and sail. +40 thrust.",
	},
	LargeSail = {
		Tier = 2,
		Name = "Large Sail",
		Icon = "🏴",
		Kind = "Block",
		Placement = "Mounted",
		Price = 220,
		Recipe = { Plank = 6, Cloth = 8, Rope = 4, IronIngot = 1 },
		Stats = { Mass = 4, Thrust = 95, HP = 6 },
		Cells = { { 0, 0, 0 }, { 0, 1, 0 }, { 0, 2, 0 }, { 0, 3, 0 } },
		Description = "Two big square sails on a tall mast. +95 thrust.",
	},
	SteamEngine = {
		Tier = 3,
		Name = "Steam Engine",
		Icon = "🚂",
		Kind = "Block",
		Placement = "Mounted",
		Price = 600,
		Recipe = { IronIngot = 8, Plank = 4, Rope = 2 },
		Stats = { Mass = 10, Thrust = 180, HP = 15 },
		Cells = { { 0, 0, 0 }, { 0, 1, 0 } },
		Description = "Chuff chuff! A huge +180 thrust, but heavy.",
	},
	Oars = {
		Name = "Oars",
		Icon = "🚣",
		Kind = "Block",
		Placement = "Mounted",
		Price = 30,
		Recipe = { Plank = 2, Rope = 1 },
		Stats = { Mass = 1, Thrust = 12, HP = 3 },
		Description = "A rowing bench and oar. Rotate it to face over the side. +12 thrust.",
	},
	Ram = {
		Tier = 2,
		Name = "Ram",
		Icon = "🐏",
		Kind = "Block",
		Placement = "Hull",
		Fixed = true,
		Price = 140,
		Recipe = { IronIngot = 3, Plank = 2 },
		Stats = { Mass = 5, Buoyancy = 8, HP = 20, Ram = 1 },
		Description = "An iron-shod bow. Counts as a bow; rams deal 3x damage and hurt you less.",
	},
	DieselMotor = {
		Tier = 4,
		Name = "Diesel Motor",
		Icon = "⚙️",
		Kind = "Block",
		Placement = "Mounted",
		Price = 1400,
		Recipe = { IronIngot = 10, Rope = 2, Plank = 2 },
		Stats = { Mass = 7, Thrust = 260, HP = 15 },
		Description = "Modern power: +260 thrust in a compact, lighter block.",
	},
	SteelHull = {
		Tier = 4,
		Name = "Steel Hull",
		Icon = "🔷",
		Kind = "Block",
		Placement = "Hull",
		Price = 200,
		Recipe = { IronIngot = 4 },
		Stats = { Mass = 5, Buoyancy = 22, HP = 40 },
		Description = "Welded steel plating. The toughest, most buoyant hull.",
	},
	Rudder = {
		Name = "Rudder",
		Icon = "🦈",
		Kind = "Block",
		Placement = "Hull",
		Fixed = true,
		Price = 70,
		Recipe = { Plank = 4, IronIngot = 1 },
		Stats = { Mass = 1, Turn = 0.25, HP = 4 },
		Description = "Hang it on the stern to turn faster.",
	},
	Cannon = {
		Tier = 2,
		Name = "Cannon",
		Icon = "💣",
		Kind = "Block",
		Placement = "Mounted",
		Price = 160,
		Recipe = { IronIngot = 3, Plank = 2 },
		Stats = { Mass = 3, HP = 6 },
		Description = "Rotate it to face the side. Crew can man it, or the captain fires a broadside [F].",
	},
	Railing = {
		Name = "Railing",
		Icon = "🚧",
		Kind = "Block",
		Placement = "Mounted",
		Price = 12,
		Recipe = { Plank = 1 },
		Stats = { Mass = 0.5, HP = 2 },
		Description = "Keeps your crew from falling overboard.",
	},
	Lantern = {
		Name = "Lantern",
		Icon = "🏮",
		Kind = "Block",
		Placement = "Mounted",
		Price = 30,
		Recipe = { IronIngot = 1 },
		Stats = { Mass = 0.5, HP = 1 },
		Description = "A warm light for night voyages.",
	},
	Flag = {
		Name = "Flag",
		Icon = "🚩",
		Kind = "Block",
		Placement = "Mounted",
		Price = 20,
		Recipe = { Cloth = 1, Plank = 1 },
		Stats = { Mass = 0.5, HP = 1 },
		Description = "Show your colours!",
	},
	Helm = {
		Name = "Helm",
		Icon = "☸️",
		Kind = "Block",
		Placement = "Mounted",
		Price = 0,
		Hidden = true, -- every ship has exactly one; it cannot be bought or removed
		Unique = true,
		Stats = { Mass = 1, HP = 4 },
		Description = "Take the wheel, captain.",
	},
}

-- Display order for menus
Items.Order = {
	"Wood",
	"Fiber",
	"IronOre",
	"Plank",
	"Rope",
	"Cloth",
	"IronIngot",
	"Cannonball",
	"RepairKit",
	"WoodHull",
	"Bow",
	"Stern",
	"Deck",
	"CargoHold",
	"Oars",
	"SmallSail",
	"Rudder",
	"Keel",
	"Railing",
	"Flag",
	"Lantern",
	"Cannon",
	"Ram",
	"IronHull",
	"LargeSail",
	"SteamEngine",
	"SteelHull",
	"DieselMotor",
	"Helm",
}

-- Blocks that form the hull's waterline row
Items.HullTypes = { WoodHull = true, IronHull = true, SteelHull = true, Bow = true, Ram = true, Stern = true }
Items.MetalHulls = { IronHull = true, SteelHull = true }
Items.Bows = { Bow = true, Ram = true }
Items.Sails = { SmallSail = true, LargeSail = true }
Items.Engines = { SteamEngine = true, DieselMotor = true }

Items.TIER_NAMES = { "Rowing", "Sailing", "Steam", "Motor" }

for id, def in Items.Defs do
	def.Id = id
	def.Cells = def.Cells or { { 0, 0, 0 } }
	def.Yield = def.Yield or 1
	def.Tier = def.Tier or 1
end

function Items.Get(id: string)
	return Items.Defs[id]
end

function Items.IsBlock(id: string): boolean
	local def = Items.Defs[id]
	return def ~= nil and def.Kind == "Block"
end

function Items.Placeable(): { string }
	local list = {}
	for _, id in Items.Order do
		local def = Items.Defs[id]
		if def.Kind == "Block" and not def.Hidden then
			table.insert(list, id)
		end
	end
	return list
end

function Items.StatsText(id: string): string
	local stats = Items.Defs[id].Stats
	if not stats then
		return ""
	end
	local parts = {}
	if stats.Thrust then
		table.insert(parts, `+{stats.Thrust} thrust`)
	end
	if stats.Crates then
		table.insert(parts, `{stats.Crates} crate slots`)
	end
	if stats.Turn then
		table.insert(parts, `+{stats.Turn} turn`)
	end
	if stats.Ram then
		table.insert(parts, "3x ramming")
	end
	if stats.Stability then
		table.insert(parts, "storm stability")
	end
	if stats.Buoyancy then
		table.insert(parts, `{stats.Buoyancy} float`)
	end
	table.insert(parts, `{stats.HP or 0} HP`)
	table.insert(parts, `{stats.Mass} weight`)
	return table.concat(parts, " · ")
end

return Items
