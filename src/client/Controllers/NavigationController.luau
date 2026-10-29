-- Floating island markers with distance, so you can always find your way.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Goods = require(Shared.Goods)
local Islands = require(Shared.Islands)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local C = UIKit.Colors

local NavigationController = {}

local function tradeHint(def): string
	local sells = {}
	for _, id in Goods.Order do
		if def.Market.Sells[id] then
			table.insert(sells, Goods.Get(id).Icon)
		end
	end
	local wants = {}
	for _, id in Goods.Order do
		if def.Market.Buys[id] then
			table.insert(wants, Goods.Get(id).Icon)
		end
	end
	return `sells {table.concat(sells, "")}  ·  wants {table.concat(wants, "")}`
end

function NavigationController.Init(ctx)
	local markers = {}
	for _, id in Islands.Order do
		local def = Islands.Get(id)
		local anchor = Instance.new("Part")
		anchor.Name = `{id}Marker`
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = CFrame.new(def.Position + Vector3.new(0, def.Radius * 0.8 + 40, 0))
		anchor.Parent = workspace.CurrentCamera

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(230, 84)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Parent = anchor

		local card = UIKit.Card({
			Color = if def.Home then C.Yellow else C.White,
			Size = UDim2.fromOffset(220, 72),
			Position = UDim2.fromOffset(5, 6),
			Radius = 14,
			Parent = gui,
		})
		UIKit.Label({
			Text = (if def.Home then "🏠 " else "🏝️ ") .. def.Name,
			Font = UIKit.TitleFont,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.fromOffset(0, 4),
			Parent = card,
		})
		local distance = UIKit.Label({
			Text = "",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 28),
			Parent = card,
		})
		UIKit.Label({
			Text = tradeHint(def),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 48),
			Parent = card,
		})
		markers[id] = { Gui = gui, Distance = distance, Def = def }
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local origin = if root then root.Position else workspace.CurrentCamera.CFrame.Position
		for _, marker in markers do
			local d = (Vector3.new(marker.Def.Position.X, origin.Y, marker.Def.Position.Z) - origin).Magnitude
			-- Hide the marker of the island you're standing on
			marker.Gui.Enabled = d > marker.Def.Radius + 80
			marker.Distance.Text = `{math.floor(d)} studs`
		end
	end)
end

return NavigationController
