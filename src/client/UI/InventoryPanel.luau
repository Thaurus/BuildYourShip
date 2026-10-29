-- Items & crafting panel: shows what you own and turns materials into ship parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)

local UIKit = require(script.Parent.UIKit)
local C = UIKit.Colors

local InventoryPanel = {}

local KIND_COLORS = {
	Raw = C.Green,
	Material = C.Blue,
	Block = C.Orange,
}

function InventoryPanel.Init(ctx)
	local State = ctx.State
	local panel = UIKit.Panel(ctx.Screen, "Items & Crafting", UDim2.fromOffset(720, 500), C.Purple)

	-- Tabs
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(1, 0, 0, 44)
	tabs.Parent = panel.Content
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabs

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 52)
	body.Size = UDim2.new(1, 0, 1, -52)
	body.Parent = panel.Content

	local bagView = UIKit.ScrollList(body)
	bagView.UIListLayout:Destroy()
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 96)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = bagView

	local craftView = UIKit.ScrollList(body)
	craftView.Visible = false

	local current = "bag"
	local tabButtons = {}
	local render

	local function selectTab(name)
		current = name
		bagView.Visible = name == "bag"
		craftView.Visible = name == "craft"
		for id, button in tabButtons do
			UIKit.SetEnabled(button, true)
			button.BackgroundColor3 = if id == name then C.Yellow else C.Grey
			button.TextColor3 = if id == name then C.Ink else C.White
		end
		render()
	end

	tabButtons.bag = UIKit.Button({
		Text = "🎒 Backpack",
		Size = UDim2.fromOffset(170, 40),
		Parent = tabs,
		OnClick = function()
			selectTab("bag")
		end,
	})
	tabButtons.craft = UIKit.Button({
		Text = "🔨 Crafting",
		Size = UDim2.fromOffset(170, 40),
		Parent = tabs,
		OnClick = function()
			selectTab("craft")
		end,
	})

	local function craft(id: string, amount: number)
		local result = ctx.Invoke("Craft", id, amount)
		if result and result.ok then
			ctx.Sounds.Pop()
		end
	end

	local function renderBag(data)
		UIKit.Clear(bagView)
		local order = 0
		for _, id in Items.Order do
			local def = Items.Get(id)
			local count = data.Inventory[id] or 0
			if count > 0 then
				order += 1
				local card = UIKit.Card({ Color = C.White, LayoutOrder = order, Parent = bagView })
				UIKit.Label({
					Text = def.Icon,
					TextSize = 34,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 44),
					Position = UDim2.fromOffset(0, 4),
					Parent = card,
				})
				UIKit.Label({
					Text = def.Name,
					TextSize = 15,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, -8, 0, 20),
					Position = UDim2.fromOffset(4, 50),
					Parent = card,
				})
				local badge = UIKit.Card({
					Color = KIND_COLORS[def.Kind] or C.Blue,
					Size = UDim2.fromOffset(52, 26),
					Position = UDim2.new(1, -6, 0, 6),
					AnchorPoint = Vector2.new(1, 0),
					Radius = 13,
					Stroke = 2,
					Parent = card,
				})
				badge.Rotation = 6
				UIKit.Label({
					Text = `x{count}`,
					Font = UIKit.TitleFont,
					TextSize = 16,
					TextColor3 = C.White,
					TextXAlignment = Enum.TextXAlignment.Center,
					Outlined = 2,
					Size = UDim2.fromScale(1, 1),
					Parent = badge,
				})
				UIKit.Label({
					Text = def.Kind,
					TextSize = 12,
					TextColor3 = KIND_COLORS[def.Kind] or C.Blue,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 16),
					Position = UDim2.fromOffset(0, 72),
					Parent = card,
				})
			end
		end
		if order == 0 then
			UIKit.Label({
				Text = "Your backpack is empty. Chop trees, gather flax and mine ore on the islands!",
				TextSize = 18,
				Size = UDim2.fromOffset(600, 60),
				Parent = bagView,
			})
		end
	end

	local function renderCraft(data)
		UIKit.Clear(craftView)
		local order = 0
		for _, id in Items.Order do
			local def = Items.Get(id)
			if def.Recipe and not def.Hidden then
				order += 1
				local can = true
				for need, n in def.Recipe do
					if (data.Inventory[need] or 0) < n then
						can = false
					end
				end
				local card = UIKit.Card({
					Color = if can then C.White else C.Paper,
					Size = UDim2.new(1, 0, 0, 74),
					LayoutOrder = order,
					Parent = craftView,
				})
				UIKit.Label({
					Text = def.Icon,
					TextSize = 34,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromOffset(60, 74),
					Parent = card,
				})
				UIKit.Label({
					Text = `<b>{def.Name}</b>{if def.Yield > 1 then " x" .. def.Yield else ""}   <font color="#8A8274">owned {data.Inventory[id] or 0}</font>`,
					RichText = true,
					TextSize = 19,
					Size = UDim2.new(1, -330, 0, 24),
					Position = UDim2.fromOffset(62, 8),
					Parent = card,
				})
				local info = Items.StatsText(id)
				UIKit.Label({
					Text = if info ~= "" then info else (def.Description or ""),
					TextSize = 13,
					TextColor3 = Color3.fromRGB(110, 100, 90),
					Size = UDim2.new(1, -330, 0, 16),
					Position = UDim2.fromOffset(62, 32),
					Parent = card,
				})
				-- Ingredients, coloured by whether you have them
				local parts = {}
				for _, need in Items.Order do
					local n = def.Recipe[need]
					if n then
						local have = data.Inventory[need] or 0
						local color = if have >= n then "#3A9A3A" else "#D8443A"
						table.insert(parts, `<font color="{color}">{n} {Items.Get(need).Icon}</font>`)
					end
				end
				UIKit.Label({
					Text = "Needs  " .. table.concat(parts, "  "),
					RichText = true,
					TextSize = 16,
					Size = UDim2.new(1, -330, 0, 20),
					Position = UDim2.fromOffset(62, 50),
					Parent = card,
				})
				local one = UIKit.Button({
					Text = "Craft",
					Color = C.Green,
					Size = UDim2.fromOffset(110, 42),
					Position = UDim2.new(1, -196, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Parent = card,
					OnClick = function()
						craft(id, 1)
					end,
				})
				local five = UIKit.Button({
					Text = "x5",
					Color = C.Teal,
					Size = UDim2.fromOffset(70, 42),
					Position = UDim2.new(1, -78, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Parent = card,
					OnClick = function()
						craft(id, 5)
					end,
				})
				UIKit.SetEnabled(one, can)
				local canFive = true
				for need, n in def.Recipe do
					if (data.Inventory[need] or 0) < n * 5 then
						canFive = false
					end
				end
				UIKit.SetEnabled(five, canFive)
			end
		end
	end

	render = function()
		local data = State.Data
		if not data or not panel.IsOpen() then
			return
		end
		if current == "bag" then
			renderBag(data)
		else
			renderCraft(data)
		end
	end

	State.Changed:Connect(render)
	local open = panel.Open
	panel.Open = function()
		open()
		selectTab(current)
	end
	panel.ShowCrafting = function()
		panel.Open()
		selectTab("craft")
	end
	return panel
end

return InventoryPanel
