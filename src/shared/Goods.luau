--!strict
-- Trade goods carried as cargo between island traders.

local Goods = {}

Goods.Defs = {
	Fish = { Name = "Fish", Icon = "🐟", Price = 8 },
	Fruit = { Name = "Tropical Fruit", Icon = "🍍", Price = 10 },
	Pottery = { Name = "Pottery", Icon = "🏺", Price = 14 },
	Coffee = { Name = "Coffee", Icon = "☕", Price = 18 },
	Tools = { Name = "Tools", Icon = "🛠️", Price = 24 },
	Spices = { Name = "Spices", Icon = "🌶️", Price = 30 },
	Furs = { Name = "Furs", Icon = "🧣", Price = 36 },
}

Goods.Order = { "Fish", "Fruit", "Pottery", "Coffee", "Tools", "Spices", "Furs" }

-- Price multiplier when an island buys a good it does not specifically want
Goods.NEUTRAL_SELL_FACTOR = 0.5

function Goods.Get(id: string)
	return Goods.Defs[id]
end

return Goods
