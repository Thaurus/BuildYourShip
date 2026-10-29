-- The Shipwright's shop at Port Haven: spend gold on anything you'd rather not farm.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Islands = require(Shared.Islands)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.UIKit)
local C = UIKit.Colors

local ShopPanel = {}

function ShopPanel.Init(ctx)
	local State = ctx.State
	local panel = UIKit.Panel(ctx.Screen, "Shipwright", UDim2.fromOffset(680, 500), C.Red)

	UIKit.Label({
		Text = "\"Short on timber, captain? I've got everything a ship needs... for a price!\"",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(110, 100, 90),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = panel.Content,
	})
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 40)
	holder.Size = UDim2.new(1, 0, 1, -40)
	holder.Parent = panel.Content
	local list = UIKit.ScrollList(holder)

	local function render()
		local data = State.Data
		if not data or not panel.IsOpen() then
			return
		end
		UIKit.Clear(list)
		for order, id in Items.Order do
			local def = Items.Get(id)
			if not def.Hidden then
				local card = UIKit.Card({ Color = C.White, Size = UDim2.new(1, 0, 0, 62), LayoutOrder = order, Parent = list })
				UIKit.Label({
					Text = def.Icon,
					TextSize = 30,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromOffset(56, 62),
					Parent = card,
				})
				UIKit.Label({
					Text = `<b>{def.Name}</b>   <font color="#8A8274">owned {data.Inventory[id] or 0}</font>`,
					RichText = true,
					TextSize = 18,
					Size = UDim2.new(1, -320, 0, 24),
					Position = UDim2.fromOffset(58, 8),
					Parent = card,
				})
				local locked = def.Tier > (data.Tier or 1)
				local info = if locked
					then `🔒 {Items.TIER_NAMES[def.Tier]} era · discover {Islands.UnlockSource(def.Tier)}`
					else Items.StatsText(id)
				UIKit.Label({
					Text = if info ~= "" then info else (def.Description or ""),
					TextSize = 13,
					TextColor3 = Color3.fromRGB(110, 100, 90),
					Size = UDim2.new(1, -320, 0, 18),
					Position = UDim2.fromOffset(58, 34),
					Parent = card,
				})
				for i, amount in { 1, 5 } do
					local unit = if data.Passes and data.Passes.ShipwrightFriend then math.ceil(def.Price * 0.75) else def.Price
					local cost = unit * amount
					local button = UIKit.Button({
						Text = if amount == 1 then `{cost}g` else `x5 {cost}g`,
						Color = if i == 1 then C.Yellow else C.Orange,
						TextColor = C.White,
						TextSize = 17,
						Size = UDim2.fromOffset(if i == 1 then 100 else 140, 40),
						Position = UDim2.new(1, if i == 1 then -258 else -148, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						Parent = card,
						OnClick = function()
							local result = ctx.Invoke("Buy", id, amount)
							if result and result.ok then
								ctx.Sounds.Pop()
							end
						end,
					})
					UIKit.SetEnabled(button, data.Gold >= cost and not locked)
				end
			end
		end
	end

	State.Changed:Connect(render)
	local open = panel.Open
	panel.Open = function()
		open()
		render()
	end

	Remotes.Event("OpenShop").OnClientEvent:Connect(function()
		panel.Open()
	end)

	-- Close when walking away from the shipwright
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel.IsOpen() then
				local character = game:GetService("Players").LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local near = false
				for _, npc in game:GetService("CollectionService"):GetTagged("Shipwright") do
					if root and (npc:GetPivot().Position - root.Position).Magnitude < 45 then
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

return ShopPanel
