-- Every item a player can own: raw resources, crafted materials and ship blocks.
--
--   Kind      "Raw" (harvested), "Material" (crafted), "Block" (placeable on a ship)
--   Price     gold cost at the Shipwright
--   Recipe    { [itemId] = amount } needed to craft one
--   Stats     ship stats contributed by a placed block
--   Cells     grid cells occupied relative to the anchor cell (default { {0,0,0} })

local Items = {}

Items.Defs = {
	-- Raw resources ---------------------------------------------------------
	Wood = {
		Name = "Wood",
		Icon = "🪵",
		Kind = "Raw",
		Price = 4,
		Description = "Chopped from trees on every island.",
	},
	Fiber = {
		Name = "Fiber",
		Icon = "🌿",
		Kind = "Raw",
		Price = 4,
		Description = "Gathered from flax bushes on sunny islands.",
	},
	IronOre = {
		Name = "Iron Ore",
		Icon = "🪨",
		Kind = "Raw",
		Price = 10,
		Description = "Mined from glowing ore rocks on Ironrock and Frostpeak.",
	},

	-- Materials ------------------------------------------------------------
	Plank = {
		Name = "Plank",
		Icon = "🟫",
		Kind = "Material",
		Price = 10,
		Recipe = { Wood = 2 },
		Description = "Sturdy planks for hulls and decks.",
	},
	Rope = {
		Name = "Rope",
		Icon = "🪢",
		Kind = "Material",
		Price = 10,
		Recipe = { Fiber = 2 },
		Description = "Every sailor needs rope.",
	},
	Cloth = {
		Name = "Sailcloth",
		Icon = "🧵",
		Kind = "Material",
		Price = 14,
		Recipe = { Fiber = 3 },
		Description = "Woven fiber for sails and flags.",
	},
	IronIngot = {
		Name = "Iron Ingot",
		Icon = "🔩",
		Kind = "Material",
		Price = 28,
		Recipe = { IronOre = 2, Wood = 1 },
		Description = "Smelted iron for fittings and engines.",
	},

	-- Ship blocks ----------------------------------------------------------
	WoodHull = {
		Name = "Wooden Hull",
		Icon = "🧱",
		Kind = "Block",
		Price = 35,
		Recipe = { Plank = 3 },
		Stats = { Mass = 3, Buoyancy = 10 },
		Description = "Floats! The backbone of every ship.",
	},
	IronHull = {
		Name = "Iron Hull",
		Icon = "⬛",
		Kind = "Block",
		Price = 90,
		Recipe = { IronIngot = 2, Plank = 1 },
		Stats = { Mass = 5, Buoyancy = 18 },
		Description = "Heavy, but carries far more load per block.",
	},
	Deck = {
		Name = "Deck Planks",
		Icon = "🪜",
		Kind = "Block",
		Price = 14,
		Recipe = { Plank = 1 },
		Stats = { Mass = 1, Buoyancy = 2 },
		Description = "A light walkway. Cheap and cheerful.",
	},
	CargoHold = {
		Name = "Cargo Crate",
		Icon = "📦",
		Kind = "Block",
		Price = 50,
		Recipe = { Plank = 4, Rope = 1 },
		Stats = { Mass = 2, Buoyancy = 3, Cargo = 10 },
		Description = "+10 cargo space. More crates, more profit.",
	},
	SmallSail = {
		Name = "Small Sail",
		Icon = "⛵",
		Kind = "Block",
		Price = 80,
		Recipe = { Plank = 3, Cloth = 3, Rope = 2 },
		Stats = { Mass = 2, Thrust = 40 },
		Cells = { { 0, 0, 0 }, { 0, 1, 0 }, { 0, 2, 0 } },
		Description = "A trusty mast and sail. +40 thrust.",
	},
	LargeSail = {
		Name = "Large Sail",
		Icon = "🏴",
		Kind = "Block",
		Price = 220,
		Recipe = { Plank = 6, Cloth = 8, Rope = 4, IronIngot = 1 },
		Stats = { Mass = 4, Thrust = 95 },
		Cells = { { 0, 0, 0 }, { 0, 1, 0 }, { 0, 2, 0 }, { 0, 3, 0 } },
		Description = "Two big sails on a tall mast. +95 thrust.",
	},
	SteamEngine = {
		Name = "Steam Engine",
		Icon = "🚂",
		Kind = "Block",
		Price = 600,
		Recipe = { IronIngot = 8, Plank = 4, Rope = 2 },
		Stats = { Mass = 10, Thrust = 180 },
		Cells = { { 0, 0, 0 }, { 0, 1, 0 } },
		Description = "Chuff chuff! A huge +180 thrust, but heavy.",
	},
	Rudder = {
		Name = "Rudder",
		Icon = "🦈",
		Kind = "Block",
		Price = 70,
		Recipe = { Plank = 4, IronIngot = 1 },
		Stats = { Mass = 1, Turn = 0.25 },
		Description = "Turn faster. Stack a few on big ships.",
	},
	Railing = {
		Name = "Railing",
		Icon = "🚧",
		Kind = "Block",
		Price = 12,
		Recipe = { Plank = 1 },
		Stats = { Mass = 0.5 },
		Description = "Keeps your crew from falling overboard.",
	},
	Lantern = {
		Name = "Lantern",
		Icon = "🏮",
		Kind = "Block",
		Price = 30,
		Recipe = { IronIngot = 1 },
		Stats = { Mass = 0.5 },
		Description = "A warm light for night voyages.",
	},
	Flag = {
		Name = "Flag",
		Icon = "🚩",
		Kind = "Block",
		Price = 20,
		Recipe = { Cloth = 1, Plank = 1 },
		Stats = { Mass = 0.5 },
		Description = "Show your colours!",
	},
	Helm = {
		Name = "Helm",
		Icon = "☸️",
		Kind = "Block",
		Price = 0,
		Hidden = true, -- every ship has exactly one; it cannot be bought or removed
		Unique = true,
		Stats = { Mass = 1 },
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
	"WoodHull",
	"Deck",
	"CargoHold",
	"SmallSail",
	"Rudder",
	"Railing",
	"Flag",
	"Lantern",
	"IronHull",
	"LargeSail",
	"SteamEngine",
	"Helm",
}

for id, def in Items.Defs do
	def.Id = id
	def.Cells = def.Cells or { { 0, 0, 0 } }
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

-- "2 🟫  1 🪢" style recipe description
function Items.RecipeText(recipe: { [string]: number }?): string
	if not recipe then
		return ""
	end
	local parts = {}
	for _, id in Items.Order do
		local n = recipe[id]
		if n then
			table.insert(parts, `{n} {Items.Defs[id].Icon}`)
		end
	end
	return table.concat(parts, "   ")
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
	if stats.Cargo then
		table.insert(parts, `+{stats.Cargo} cargo`)
	end
	if stats.Turn then
		table.insert(parts, `+{stats.Turn} turn`)
	end
	if stats.Buoyancy then
		table.insert(parts, `{stats.Buoyancy} float`)
	end
	table.insert(parts, `{stats.Mass} weight`)
	return table.concat(parts, " · ")
end

return Items
