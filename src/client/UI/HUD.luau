-- Always-on HUD: gold, location, ship card (hull, cargo, load), action buttons,
-- the helm gauge and context hints (carrying a crate, broadside).

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

local function pill(parent, position, anchor, color, width, height)
	local frame = UIKit.Card({
		Color = color,
		Size = UDim2.fromOffset(width, height or 46),
		Position = position,
		AnchorPoint = anchor,
		Radius = 23,
		Parent = parent,
	})
	UIKit.Shade(frame)
	return frame
end

local function bar(parent, position, size)
	local back = UIKit.Card({ Color = C.PaperDark, Size = size, Position = position, Radius = 6, Stroke = 2, Parent = parent })
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = C.Green
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	UIKit.Corner(fill, 6)
	return fill
end

function HUD.Init(ctx)
	local screen = ctx.Screen
	local State = ctx.State

	local function invoke(name: string, ...)
		local remote = Remotes.Function(name)
		local ok, result = pcall(remote.InvokeServer, remote, ...)
		if ok and result and result.msg then
			UIKit.Toast(screen, result.msg, if result.ok then "good" else "bad")
		end
		return ok and result
	end
	HUD.Invoke = invoke

	--------------------------------------------------------------------------
	-- Gold
	--------------------------------------------------------------------------
	local goldPill = pill(screen, UDim2.fromOffset(16, 16), Vector2.zero, C.Paper, 180)
	UIKit.Label({
		Text = "🪙",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(46, 46),
		Parent = goldPill,
	})
	local goldLabel = UIKit.Label({
		Text = "0",
		Font = UIKit.TitleFont,
		TextSize = 26,
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Parent = goldPill,
	})
	local goldValue = Instance.new("NumberValue")
	goldValue.Changed:Connect(function(v)
		goldLabel.Text = `{math.floor(v + 0.5)}g`
	end)
	local goldScale = Instance.new("UIScale")
	goldScale.Parent = goldPill
	local lastGold = nil

	--------------------------------------------------------------------------
	-- Location
	--------------------------------------------------------------------------
	local location = pill(screen, UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0), C.Blue, 320)
	local locationLabel = UIKit.Label({
		Text = "",
		Font = UIKit.TitleFont,
		TextSize = 20,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Outlined = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = location,
	})

	--------------------------------------------------------------------------
	-- Ship card
	--------------------------------------------------------------------------
	local card = UIKit.Card({
		Color = C.Paper,
		Size = UDim2.fromOffset(270, 196),
		Position = UDim2.new(0, 16, 1, -16),
		AnchorPoint = Vector2.new(0, 1),
		Radius = 12,
		Stroke = 3,
		Parent = screen,
	})
	local cardTitle = UIKit.Label({
		Text = "Your Ship",
		Font = UIKit.TitleFont,
		TextSize = 20,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 8),
		Parent = card,
	})
	local badge = UIKit.Card({
		Color = C.Orange,
		Size = UDim2.fromOffset(96, 24),
		Position = UDim2.new(1, -104, 0, 10),
		Radius = 8,
		Stroke = 2,
		Parent = card,
	})
	local badgeLabel = UIKit.Label({
		Text = "",
		Font = UIKit.TitleFont,
		TextSize = 13,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = badge,
	})

	local hpLabel = UIKit.Label({ Text = "", RichText = true, TextSize = 15, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 38), Parent = card })
	local hpFill = bar(card, UDim2.fromOffset(12, 58), UDim2.new(1, -24, 0, 12))
	local function row(y)
		return UIKit.Label({ Text = "", RichText = true, TextSize = 15, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, y), Parent = card })
	end
	local speedRow = row(78)
	local cargoRow = row(100)
	local loadRow = row(122)
	local loadFill = bar(card, UDim2.fromOffset(12, 144), UDim2.new(1, -24, 0, 12))
	local extraRow = row(162)

	--------------------------------------------------------------------------
	-- Action buttons
	--------------------------------------------------------------------------
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(1, 0.5)
	actions.Position = UDim2.new(1, -16, 0.55, 0)
	actions.Size = UDim2.fromOffset(170, 400)
	actions.Parent = screen
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = actions

	local buildButton
	local buttons = {
		{ "🎒 Items [I]", C.Purple, function()
			ctx.Panels.Inventory.Toggle()
		end },
		{ "🔨 Drydock [B]", C.Orange, function()
			invoke("ToggleBuild")
		end },
		{ "☸️ Board [H]", C.Blue, function()
			invoke("BoardShip")
		end },
		{ "🤝 Crew [C]", C.Teal, function()
			ctx.Panels.Crew.Toggle()
		end },
		{ "🧰 Repair", C.Green, function()
			invoke("RepairShip")
		end },
		{ "⭐ Store", C.Yellow, function()
			ctx.Panels.Store.Toggle()
		end },
		{ "🧭 Tow home", C.Grey, function()
			invoke("ResetShip")
		end },
	}
	for i, spec in buttons do
		local b = UIKit.Button({
			Text = spec[1],
			Color = spec[2],
			Size = UDim2.fromOffset(170, 44),
			TextSize = 17,
			LayoutOrder = i,
			Parent = actions,
			OnClick = spec[3],
		})
		if i == 2 then
			buildButton = b
		end
	end

	--------------------------------------------------------------------------
	-- Bottom-centre: helm gauge and hints
	--------------------------------------------------------------------------
	local gauge = pill(screen, UDim2.new(0.5, 0, 1, -20), Vector2.new(0.5, 1), C.Paper, 320, 64)
	gauge.Visible = false
	local gaugeLabel = UIKit.Label({
		Text = "0 kn",
		Font = UIKit.TitleFont,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 38),
		Position = UDim2.fromOffset(0, 2),
		Parent = gauge,
	})
	UIKit.Label({
		Text = "W/S sail · A/D steer · F broadside · Space leave",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 40),
		Parent = gauge,
	})

	local hint = pill(screen, UDim2.new(0.5, 0, 1, -94), Vector2.new(0.5, 1), C.Yellow, 520, 44)
	hint.Visible = false
	local hintLabel = UIKit.Label({
		Text = "",
		RichText = true,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = hint,
	})

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local steering = seat ~= nil and seat:IsA("VehicleSeat")
		gauge.Visible = steering
		if steering then
			local v = seat.AssemblyLinearVelocity
			gaugeLabel.Text = `⛵ {math.floor(Vector3.new(v.X, 0, v.Z).Magnitude + 0.5)} kn`
		end
	end)

	--------------------------------------------------------------------------
	-- State binding
	--------------------------------------------------------------------------
	State.Observe(function(data)
		if lastGold ~= data.Gold then
			if lastGold ~= nil then
				TweenService:Create(goldValue, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = data.Gold }):Play()
				goldScale.Scale = 1.15
				TweenService:Create(goldScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			else
				goldValue.Value = data.Gold
			end
			lastGold = data.Gold
		end

		local ship = data.Ship
		local stats = ship and ship.Stats
		buildButton.Text = if data.Building then "⛵ Launch [B]" else "🔨 Drydock [B]"

		-- Location banner
		if data.Building then
			locationLabel.Text = "🔨 Your drydock"
			location.BackgroundColor3 = C.Orange
		elseif ship and ship.DockedAt == "PortHaven" then
			locationLabel.Text = "🛡️ Port Haven · safe harbour"
			location.BackgroundColor3 = C.Green
		elseif ship and ship.DockedAt then
			locationLabel.Text = `⚓ Moored at {Islands.Get(ship.DockedAt).Name}`
			location.BackgroundColor3 = C.Teal
		else
			locationLabel.Text = "🌊 Open sea · beware of pirates"
			location.BackgroundColor3 = C.Blue
		end

		-- Ship card
		card.Visible = stats ~= nil
		if stats then
			cardTitle.Text = if ship.Own then "Your Ship" else `{data.Crew.Captain}'s Ship`
			badge.Visible = data.Building or ship.Sinking
			badgeLabel.Text = if ship.Sinking then "SINKING" else "IN DRYDOCK"
			badge.BackgroundColor3 = if ship.Sinking then C.Red else C.Orange

			local hpFrac = math.clamp(ship.HP / stats.MaxHP, 0, 1)
			hpLabel.Text = `🛡️ Hull <b>{math.floor(ship.HP)} / {stats.MaxHP}</b>`
			hpFill.Size = UDim2.fromScale(hpFrac, 1)
			hpFill.BackgroundColor3 = if hpFrac > 0.5 then C.Green elseif hpFrac > 0.25 then C.Yellow else C.Red

			speedRow.Text = `💨 Top speed <b>{math.floor(stats.MaxSpeed + 0.5)} kn</b>   ⚙️ Thrust <b>{stats.Thrust}</b>`
			local cargoParts = {}
			for _, id in Goods.Order do
				local n = ship.Cargo[id]
				if n then
					table.insert(cargoParts, `{Goods.Get(id).Icon}{n}`)
				end
			end
			cargoRow.Text = `📦 Crates <b>{ship.Crates} / {stats.MaxCrates}</b>  {table.concat(cargoParts, " ")}`
			local loadPct = math.floor(stats.Load * 100 + 0.5)
			loadRow.Text = if stats.Overloaded
				then `⚠️ <font color="#A43A30"><b>Overloaded! {loadPct}%</b></font>`
				else `⚖️ Load <b>{loadPct}%</b> of float`
			loadFill.Size = UDim2.fromScale(math.clamp(stats.Load, 0.02, 1), 1)
			loadFill.BackgroundColor3 = if stats.Load > 1 then C.Red elseif stats.Load > 0.8 then C.Orange else C.Green
			extraRow.Text = `💣 Cannons <b>{stats.Cannons}</b>   🧱 Blocks <b>{stats.Blocks}</b>   ⚫ <b>{data.Inventory.Cannonball or 0}</b>`
		end

		-- Context hint
		if data.Carrying then
			local good = Goods.Get(data.Carrying)
			hint.Visible = true
			hint.BackgroundColor3 = C.Yellow
			hintLabel.Text = `Carrying <b>{good.Icon} {good.Name}</b> · stow it in a Cargo Crate (E) or sell it to a trader · <b>G</b> drop`
		elseif ship and ship.Sinking then
			hint.Visible = true
			hint.BackgroundColor3 = C.Red
			hintLabel.Text = "<b>Abandon ship!</b> It will be rebuilt in Port Haven shortly."
		else
			hint.Visible = false
		end
	end)
end

return HUD
