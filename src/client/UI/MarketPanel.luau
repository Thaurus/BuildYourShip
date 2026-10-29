-- Island trader: buy crates of local goods cheaply; carry crates here to sell them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.UIKit)
local C = UIKit.Colors

local MarketPanel = {}

function MarketPanel.Init(ctx)
	local panel = UIKit.Panel(ctx.Screen, "Market", UDim2.fromOffset(680, 560), C.Green)
	local currentIsland: string? = nil
	local busy = false

	local header = UIKit.Card({ Color = C.White, Size = UDim2.new(1, 0, 0, 58), Parent = panel.Content })
	local headerTitle = UIKit.Label({
		Text = "",
		RichText = true,
		TextSize = 20,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 4),
		Parent = header,
	})
	local headerInfo = UIKit.Label({
		Text = "",
		RichText = true,
		TextSize = 15,
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 30),
		Parent = header,
	})

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 66)
	holder.Size = UDim2.new(1, 0, 1, -66)
	holder.Parent = panel.Content
	local list = UIKit.ScrollList(holder)

	local refresh

	local function buy(goodId: string)
		if busy or not currentIsland then
			return
		end
		busy = true
		local result = ctx.Invoke("BuyCrate", currentIsland, goodId)
		if result and result.ok then
			ctx.Sounds.Pop()
		end
		busy = false
		refresh()
	end

	local function render(snapshot)
		UIKit.Clear(list)
		panel.Banner.Title.Text = string.upper(snapshot.IslandName)
		panel.Banner.Size = UDim2.fromOffset(math.max(220, #snapshot.IslandName * 22 + 60), 54)
		headerTitle.Text = `<b>{snapshot.Trader}</b>'s trading post    💰 <b>{snapshot.Gold}g</b>`
		if snapshot.Carrying then
			local carried
			for _, good in snapshot.Goods do
				if good.Id == snapshot.Carrying then
					carried = good
				end
			end
			headerInfo.Text = `You carry {carried.Icon} {carried.Name}: close this and press <b>E · Sell crate</b> for <b>{carried.SellPrice}g</b>`
		else
			headerInfo.Text = "Bought crates appear on the loading pad. Carry them aboard and stow them!"
		end

		for order, good in snapshot.Goods do
			local card = UIKit.Card({
				Color = if good.Wanted then Color3.fromRGB(250, 238, 206) else C.White,
				Size = UDim2.new(1, 0, 0, 60),
				LayoutOrder = order,
				Parent = list,
			})
			UIKit.Label({
				Text = good.Icon,
				TextSize = 30,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(56, 60),
				Parent = card,
			})
			local tag = if good.Wanted then `<font color="#B0602A">WANTED</font>` elseif good.Local then `<font color="#305A88">LOCAL</font>` else ""
			UIKit.Label({
				Text = `<b>{good.Name}</b>  {tag}`,
				RichText = true,
				TextSize = 17,
				Size = UDim2.new(1, -320, 0, 24),
				Position = UDim2.fromOffset(58, 8),
				Parent = card,
			})
			UIKit.Label({
				Text = `Pays {good.SellPrice}g per crate here`,
				TextSize = 13,
				TextColor3 = Color3.fromRGB(110, 100, 90),
				Size = UDim2.new(1, -320, 0, 18),
				Position = UDim2.fromOffset(58, 33),
				Parent = card,
			})
			if good.BuyPrice then
				local b = UIKit.Button({
					Text = `Buy crate {good.BuyPrice}g`,
					Color = C.Blue,
					TextSize = 15,
					Size = UDim2.fromOffset(170, 40),
					Position = UDim2.new(1, -178, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Parent = card,
					OnClick = function()
						buy(good.Id)
					end,
				})
				UIKit.SetEnabled(b, snapshot.Gold >= good.BuyPrice)
			else
				UIKit.Label({
					Text = "not sold here",
					TextSize = 13,
					TextColor3 = C.Grey,
					TextXAlignment = Enum.TextXAlignment.Right,
					Size = UDim2.fromOffset(160, 40),
					Position = UDim2.new(1, -170, 0.5, -20),
					Parent = card,
				})
			end
		end
	end

	refresh = function()
		if not currentIsland or not panel.IsOpen() then
			return
		end
		local ok, snapshot = pcall(function()
			return Remotes.Function("GetMarket"):InvokeServer(currentIsland)
		end)
		if ok and snapshot then
			render(snapshot)
		end
	end

	Remotes.Event("OpenMarket").OnClientEvent:Connect(function(islandId)
		currentIsland = islandId
		panel.Open()
		refresh()
	end)
	ctx.State.Changed:Connect(function()
		if panel.IsOpen() and not busy then
			refresh()
		end
	end)

	-- Close when walking away from the trader
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel.IsOpen() and currentIsland then
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local near = false
				for _, npc in CollectionService:GetTagged("Trader") do
					if npc:GetAttribute("IslandId") == currentIsland and root and (npc:GetPivot().Position - root.Position).Magnitude < 45 then
						near = true
					end
				end
				if not near then
					panel.Close()
				end
			end
		end
	end)
	return panel
end

return MarketPanel
