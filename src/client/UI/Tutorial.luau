-- First-time welcome card that explains the game loop in four comic panels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local UIKit = require(script.Parent.UIKit)
local C = UIKit.Colors

local Tutorial = {}

local STEPS = {
	{ "🪓", "Gather", "Chop trees, gather flax and mine ore on the islands. Hold [E] on them.", C.Green },
	{ "🔨", "Craft & Build", "Craft planks, rope and sails [I], then press [B] at your berth to expand your ship.", C.Orange },
	{ "⛵", "Sail", "Press [H] to take the helm. W/S to sail, A/D to steer. Follow the island markers!", C.Blue },
	{ "💰", "Trade", "Buy goods cheap where they're LOCAL, sell where they're WANTED. Bigger ship = bigger profit!", C.Yellow },
}

function Tutorial.Init(ctx)
	local panel = UIKit.Panel(ctx.Screen, "Ahoy, Captain!", UDim2.fromOffset(760, 430), C.Blue)

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 1, -70)
	grid.Position = UDim2.fromOffset(0, 8)
	grid.Parent = panel.Content
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.25, -12, 1, -8)
	layout.CellPadding = UDim2.fromOffset(14, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i, step in STEPS do
		local card = UIKit.Card({ Color = C.White, LayoutOrder = i, Parent = grid })
		card.Rotation = if i % 2 == 0 then 1.5 else -1.5
		local number = UIKit.Card({
			Color = step[4],
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.fromOffset(-10, -10),
			Radius = 20,
			Parent = card,
		})
		UIKit.Label({
			Text = tostring(i),
			Font = UIKit.TitleFont,
			TextSize = 24,
			TextColor3 = C.White,
			TextXAlignment = Enum.TextXAlignment.Center,
			Outlined = 2,
			Size = UDim2.fromScale(1, 1),
			Parent = number,
		})
		UIKit.Label({
			Text = step[1],
			TextSize = 54,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 80),
			Position = UDim2.fromOffset(0, 16),
			Parent = card,
		})
		UIKit.Label({
			Text = string.upper(step[2]),
			Font = UIKit.TitleFont,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 100),
			Parent = card,
		})
		UIKit.Label({
			Text = step[3],
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -16, 1, -140),
			Position = UDim2.fromOffset(8, 134),
			Parent = card,
		})
	end

	UIKit.Button({
		Text = "Set sail!",
		Color = C.Green,
		Size = UDim2.fromOffset(220, 52),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		TextSize = 26,
		Parent = panel.Content,
		OnClick = function()
			panel.Close()
		end,
	})

	panel.OnClose(function()
		Remotes.Event("TutorialDone"):FireServer()
	end)

	local shown = false
	ctx.State.Observe(function(data)
		if not shown and not data.SeenTutorial then
			shown = true
			panel.Open()
		end
	end)
	return panel
end

return Tutorial
