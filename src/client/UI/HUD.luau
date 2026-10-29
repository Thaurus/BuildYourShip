-- Always-on HUD: gold, location, ship card, action buttons and the helm gauge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Goods = require(Shared.Goods)
local Islands = require(Shared.Islands)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.UIKit)
local C = UIKit.Colors

local HUD = {}

local player = Players.LocalPlayer

local function pill(parent, position, anchor, color, width)
	local frame = UIKit.Card({
		Color = color,
		Size = UDim2.fromOffset(width, 50),
		Position = position,
		AnchorPoint = anchor,
		Radius = 25,
		Parent = parent,
	})
	UIKit.Shade(frame)
	return frame
end

function HUD.Init(ctx)
	local screen = ctx.Screen
	local State = ctx.State

	--------------------------------------------------------------------------
	-- Gold
	--------------------------------------------------------------------------
	local goldPill = pill(screen, UDim2.fromOffset(16, 16), Vector2.zero, C.Yellow, 190)
	local coin = UIKit.Card({
		Color = C.Orange,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(5, 5),
		Radius = 20,
		Parent = goldPill,
	})
	UIKit.Label({
		Text = "$",
		Font = UIKit.TitleFont,
		TextSize = 26,
		TextColor3 = C.Yellow,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Outlined = 2,
		Parent = coin,
	})
	local goldLabel = UIKit.Label({
		Text = "0",
		Font = UIKit.TitleFont,
		TextSize = 30,
		TextColor3 = C.White,
		Outlined = 3,
		Position = UDim2.fromOffset(54, 0),
		Size = UDim2.new(1, -60, 1, 0),
		Parent = goldPill,
	})
	local goldValue = Instance.new("NumberValue")
	goldValue.Changed:Connect(function(v)
		goldLabel.Text = tostring(math.floor(v + 0.5))
	end)
	local goldScale = Instance.new("UIScale")
	goldScale.Parent = goldPill
	local lastGold = nil

	--------------------------------------------------------------------------
	-- Location banner
	--------------------------------------------------------------------------
	local location = pill(screen, UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0), C.Blue, 300)
	local locationLabel = UIKit.Label({
		Text = "🌊 Open Sea",
		Font = UIKit.TitleFont,
		TextSize = 24,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Outlined = 2,
		Size = UDim2.fromScale(1, 1),
		Parent = location,
	})

	--------------------------------------------------------------------------
	-- Ship card
	--------------------------------------------------------------------------
	local card = UIKit.Card({
		Color = C.Paper,
		Size = UDim2.fromOffset(250, 168),
		Position = UDim2.new(0, 16, 1, -16),
		AnchorPoint = Vector2.new(0, 1),
		Radius = 16,
		Stroke = 4,
		Parent = screen,
	})
	local cardBanner = UIKit.Card({
		Color = C.Teal,
		Size = UDim2.fromOffset(170, 34),
		Position = UDim2.fromOffset(-8, -16),
		Radius = 10,
		Parent = card,
	})
	cardBanner.Rotation = -3
	UIKit.Label({
		Text = "⛵ YOUR SHIP",
		Font = UIKit.TitleFont,
		TextSize = 20,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Outlined = 2,
		Size = UDim2.fromScale(1, 1),
		Parent = cardBanner,
	})
	local buildBadge = UIKit.Card({
		Color = C.Orange,
		Size = UDim2.fromOffset(90, 28),
		Position = UDim2.new(1, -96, 0, -12),
		Radius = 8,
		Parent = card,
	})
	buildBadge.Rotation = 4
	buildBadge.Visible = false
	UIKit.Label({
		Text = "BUILDING",
		Font = UIKit.TitleFont,
		TextSize = 16,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Outlined = 2,
		Size = UDim2.fromScale(1, 1),
		Parent = buildBadge,
	})

	local rows = {}
	local function row(order, icon)
		local label = UIKit.Label({
			Text = icon,
			TextSize = 18,
			Size = UDim2.new(1, -24, 0, 22),
			Position = UDim2.fromOffset(14, 22 + (order - 1) * 26),
			Parent = card,
		})
		rows[order] = label
		return label
	end
	local speedRow = row(1, "")
	local cargoRow = row(2, "")
	local loadRow = row(3, "")
	local blocksRow = row(4, "")

	local loadBarBack = UIKit.Card({
		Color = C.White,
		Size = UDim2.new(1, -28, 0, 16),
		Position = UDim2.fromOffset(14, 130),
		Radius = 8,
		Stroke = 2,
		Parent = card,
	})
	local loadBar = Instance.new("Frame")
	loadBar.BackgroundColor3 = C.Green
	loadBar.Size = UDim2.fromScale(0.3, 1)
	loadBar.Parent = loadBarBack
	UIKit.Corner(loadBar, 8)

	--------------------------------------------------------------------------
	-- Action buttons
	--------------------------------------------------------------------------
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(1, 0.5)
	actions.Position = UDim2.new(1, -16, 0.5, 0)
	actions.Size = UDim2.fromOffset(170, 260)
	actions.Parent = screen
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = actions

	local function invoke(name: string, ...)
		local ok, result = pcall(Remotes.Function(name).InvokeServer, Remotes.Function(name), ...)
		if ok and result and result.msg then
			UIKit.Toast(screen, result.msg, if result.ok then "good" else "bad")
		end
		return ok and result
	end
	HUD.Invoke = invoke

	local buildButton
	local buttons = {
		{ "🎒 Items [I]", C.Purple, function()
			ctx.Panels.Inventory.Toggle()
		end },
		{ "🔨 Build [B]", C.Orange, function()
			invoke("ToggleBuild")
		end },
		{ "☸️ Helm [H]", C.Blue, function()
			invoke("BoardShip")
		end },
		{ "🧭 Reset Ship", C.Teal, function()
			invoke("ResetShip")
		end },
	}
	for i, spec in buttons do
		local b = UIKit.Button({
			Text = spec[1],
			Color = spec[2],
			Size = UDim2.fromOffset(170, 50),
			TextSize = 20,
			LayoutOrder = i,
			Parent = actions,
			OnClick = spec[3],
		})
		if i == 2 then
			buildButton = b
		end
	end

	--------------------------------------------------------------------------
	-- Helm gauge (only while steering)
	--------------------------------------------------------------------------
	local gauge = pill(screen, UDim2.new(0.5, 0, 1, -20), Vector2.new(0.5, 1), C.Paper, 280)
	gauge.Size = UDim2.fromOffset(280, 64)
	gauge.Visible = false
	local gaugeLabel = UIKit.Label({
		Text = "0 kn",
		Font = UIKit.TitleFont,
		TextSize = 32,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = gauge,
	})
	UIKit.Label({
		Text = "W/S sail · A/D steer · Space to leave",
		TextSize = 14,
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 40),
		Parent = gauge,
	})

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local steering = seat ~= nil and seat:IsA("VehicleSeat")
		gauge.Visible = steering
		if steering then
			local v = seat.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			gaugeLabel.Text = `⛵ {math.floor(speed + 0.5)} kn`
		end
	end)

	--------------------------------------------------------------------------
	-- State binding
	--------------------------------------------------------------------------
	State.Observe(function(data)
		if lastGold ~= data.Gold then
			if lastGold ~= nil then
				TweenService:Create(goldValue, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = data.Gold }):Play()
				goldScale.Scale = 1.2
				TweenService:Create(goldScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			else
				goldValue.Value = data.Gold
			end
			lastGold = data.Gold
		end

		if data.Building then
			locationLabel.Text = "🔨 Shipyard - Build Mode"
			location.BackgroundColor3 = C.Orange
		elseif data.DockedAt then
			locationLabel.Text = `⚓ Docked: {Islands.Get(data.DockedAt).Name}`
			location.BackgroundColor3 = C.Green
		else
			locationLabel.Text = "🌊 Open Sea"
			location.BackgroundColor3 = C.Blue
		end

		buildBadge.Visible = data.Building
		buildButton.Text = if data.Building then "⛵ Launch [B]" else "🔨 Build [B]"

		local stats = data.Stats
		if stats then
			speedRow.Text = `💨 Top speed  <b>{math.floor(stats.MaxSpeed + 0.5)} kn</b>`
			speedRow.RichText = true
			local cargoParts = {}
			for _, id in Goods.Order do
				local n = data.Cargo[id]
				if n then
					table.insert(cargoParts, `{Goods.Get(id).Icon}{n}`)
				end
			end
			cargoRow.RichText = true
			cargoRow.Text = `📦 Cargo  <b>{data.CargoCount} / {stats.MaxCargo}</b>  {table.concat(cargoParts, " ")}`
			loadRow.RichText = true
			local loadPct = math.floor(stats.Load * 100 + 0.5)
			loadRow.Text = if stats.Overloaded
				then `⚠️ <font color="#E84C40"><b>Overloaded! {loadPct}%</b></font>`
				else `⚖️ Load  <b>{loadPct}%</b> of float`
			blocksRow.RichText = true
			blocksRow.Text = `🧱 Blocks  <b>{stats.Blocks}</b>   ⚙️ Thrust <b>{stats.Thrust}</b>`
			loadBar.Size = UDim2.fromScale(math.clamp(stats.Load, 0.02, 1), 1)
			loadBar.BackgroundColor3 = if stats.Load > 1 then C.Red elseif stats.Load > 0.8 then C.Orange else C.Green
		end
	end)
end

return HUD
