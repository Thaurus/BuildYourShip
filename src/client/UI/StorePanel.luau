-- Gamepass store. Pass definitions (and their IDs) live in Shared/Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local UIKit = require(script.Parent.UIKit)
local C = UIKit.Colors

local StorePanel = {}

function StorePanel.Init(ctx)
	local panel = UIKit.Panel(ctx.Screen, "Store", UDim2.fromOffset(560, 420), C.Yellow)
	local list = UIKit.ScrollList(panel.Content, 10)

	local function render()
		local data = ctx.State.Data
		if not data or not panel.IsOpen() then
			return
		end
		UIKit.Clear(list)
		for order, key in Config.GAMEPASS_ORDER do
			local pass = Config.GAMEPASSES[key]
			local owned = data.Passes and data.Passes[key]
			local card = UIKit.Card({ Color = C.White, Size = UDim2.new(1, 0, 0, 84), LayoutOrder = order, Parent = list })
			UIKit.Label({ Text = pass.Icon, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(70, 84), Parent = card })
			UIKit.Label({ Text = pass.Name, Font = UIKit.TitleFont, TextSize = 19, Size = UDim2.new(1, -220, 0, 26), Position = UDim2.fromOffset(72, 12), Parent = card })
			UIKit.Label({
				Text = pass.Description,
				TextSize = 14,
				TextColor3 = Color3.fromRGB(100, 90, 80),
				Size = UDim2.new(1, -220, 0, 40),
				Position = UDim2.fromOffset(72, 38),
				Parent = card,
			})
			local button = UIKit.Button({
				Text = if owned then "Owned ✓" elseif pass.Id == 0 then "Coming soon" else "Get",
				Color = if owned then C.Green else C.Yellow,
				TextSize = 16,
				Size = UDim2.fromOffset(130, 42),
				Position = UDim2.new(1, -140, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Parent = card,
				OnClick = function()
					ctx.Invoke("BuyGamepass", key)
				end,
			})
			UIKit.SetEnabled(button, not owned and pass.Id ~= 0)
		end
	end

	ctx.State.Changed:Connect(render)
	local open = panel.Open
	panel.Open = function()
		open()
		render()
	end
	return panel
end

return StorePanel
