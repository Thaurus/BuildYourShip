--!strict
-- Trade goods. Each unit is one physical crate that has to be carried and stowed.

local Goods = {}

Goods.Defs = {
	Fish = { Name = "Fish", Icon = "🐟", Price = 40, Color = Color3.fromRGB(70, 120, 160) },
	Fruit = { Name = "Tropical Fruit", Icon = "🍍", Price = 50, Color = Color3.fromRGB(214, 160, 50) },
	Pottery = { Name = "Pottery", Icon = "🏺", Price = 70, Color = Color3.fromRGB(176, 96, 60) },
	Coffee = { Name = "Coffee", Icon = "☕", Price = 90, Color = Color3.fromRGB(96, 62, 42) },
	Tools = { Name = "Tools", Icon = "🛠️", Price = 120, Color = Color3.fromRGB(110, 116, 126) },
	Spices = { Name = "Spices", Icon = "🌶️", Price = 150, Color = Color3.fromRGB(170, 50, 40) },
	Furs = { Name = "Furs", Icon = "🧣", Price = 180, Color = Color3.fromRGB(140, 110, 80) },
	Oil = { Name = "Lamp Oil", Icon = "🛢️", Price = 230, Color = Color3.fromRGB(60, 56, 50) },
}

Goods.Order = { "Fish", "Fruit", "Pottery", "Coffee", "Tools", "Spices", "Furs", "Oil" }

-- Price multiplier when an island buys a good it does not specifically want
Goods.NEUTRAL_SELL_FACTOR = 0.5

function Goods.Get(id: string)
	return Goods.Defs[id]
end

return Goods
