-- Island trader: buy local goods cheaply, sell what the island wants for profit.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.UIKit)
local C = UIKit.Colors

local MarketPanel = {}

function MarketPanel.Init(ctx)
	local panel = UIKit.Panel(ctx.Screen, "Market", UDim2.fromOffset(720, 520), C.Green)
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

	local function trade(goodId: string, action: string, amount: number)
		if busy or not currentIsland then
			return
		end
		busy = true
		local result = ctx.Invoke("Trade", currentIsland, goodId, action, amount)
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
		headerTitle.Text = `<b>{snapshot.Trader}</b>'s trading post`
		local dock = if snapshot.Docked
			then `<font color="#3A9A3A">⚓ Your ship is docked here</font>`
			else `<font color="#D8443A">⚠️ Dock your ship here to load cargo</font>`
		headerInfo.Text = `{dock}    📦 Cargo <b>{snapshot.CargoCount}/{snapshot.MaxCargo}</b>    💰 <b>{snapshot.Gold}g</b>`

		for order, good in snapshot.Goods do
			-- Show goods this island trades in, plus anything you're carrying
			if good.Local or good.Wanted or good.Owned > 0 then
				local card = UIKit.Card({
					Color = if good.Wanted then Color3.fromRGB(255, 246, 214) else C.White,
					Size = UDim2.new(1, 0, 0, 64),
					LayoutOrder = order,
					Parent = list,
				})
				UIKit.Label({
					Text = good.Icon,
					TextSize = 32,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromOffset(56, 64),
					Parent = card,
				})
				local tag = if good.Wanted then `<font color="#E8762E">🔥 WANTED</font>` elseif good.Local then `<font color="#3A8AD8">🏷️ LOCAL</font>` else ""
				UIKit.Label({
					Text = `<b>{good.Name}</b>  {tag}`,
					RichText = true,
					TextSize = 18,
					Size = UDim2.new(1, -380, 0, 24),
					Position = UDim2.fromOffset(58, 8),
					Parent = card,
				})
				UIKit.Label({
					Text = `aboard: {good.Owned}`,
					TextSize = 14,
					TextColor3 = Color3.fromRGB(110, 100, 90),
					Size = UDim2.new(1, -380, 0, 20),
					Position = UDim2.fromOffset(58, 34),
					Parent = card,
				})

				local x = -8
				local function button(text, color, enabled, onClick, width)
					x -= width
					local b = UIKit.Button({
						Text = text,
						Color = color,
						TextSize = 16,
						Size = UDim2.fromOffset(width, 40),
						Position = UDim2.new(1, x, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						Parent = card,
						OnClick = onClick,
					})
					UIKit.SetEnabled(b, enabled)
					x -= 6
				end
				local room = snapshot.MaxCargo - snapshot.CargoCount
				button(`Sell x5`, C.Orange, good.Owned >= 1 and snapshot.Docked, function()
					trade(good.Id, "sell", 5)
				end, 80)
				button(`Sell {good.SellPrice}g`, C.Green, good.Owned >= 1 and snapshot.Docked, function()
					trade(good.Id, "sell", 1)
				end, 100)
				if good.BuyPrice then
					button(`x5`, C.Teal, room >= 1 and snapshot.Docked and snapshot.Gold >= good.BuyPrice, function()
						trade(good.Id, "buy", 5)
					end, 52)
					button(`Buy {good.BuyPrice}g`, C.Blue, room >= 1 and snapshot.Docked and snapshot.Gold >= good.BuyPrice, function()
						trade(good.Id, "buy", 1)
					end, 100)
				end
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
