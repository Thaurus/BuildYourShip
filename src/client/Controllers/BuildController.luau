-- Build mode: a hotbar of blocks, a ghost preview snapped to the ship grid,
-- and click-to-place / delete. The server re-validates every action.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockFactory = require(Shared.BlockFactory)
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local ShipGrid = require(Shared.ShipGrid)

local UIKit = require(script.Parent.Parent.UI.UIKit)
local C = UIKit.Colors

local BuildController = {}

local G = Config.GRID
local VALID = Color3.fromRGB(90, 230, 110)
local INVALID = Color3.fromRGB(240, 70, 60)

function BuildController.Init(ctx)
	local State = ctx.State
	local camera = workspace.CurrentCamera

	local active = false
	local selected: string? = nil
	local rotation = 0
	local deleteMode = false
	local busy = false

	local ghost: Model? = nil
	local ghostKey = ""
	local bounds: Part? = nil
	local renderConnection: RBXScriptConnection? = nil
	local target = nil -- { x, y, z, valid, reason } or { remove = key }

	local selection = Instance.new("SelectionBox")
	selection.LineThickness = 0.08
	selection.SurfaceTransparency = 0.85
	selection.Parent = camera

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	--------------------------------------------------------------------------
	-- Hotbar UI
	--------------------------------------------------------------------------
	local bar = Instance.new("Frame")
	bar.Name = "BuildBar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -16)
	bar.Size = UDim2.fromOffset(1100, 140)
	bar.Visible = false
	bar.Parent = ctx.Screen
	local barScale = Instance.new("UIScale")
	barScale.Parent = bar
	local function fitBar()
		barScale.Scale = math.min(1, (camera.ViewportSize.X - 40) / 1100)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBar)
	fitBar()

	-- Seaworthiness checklist: the ship can only launch when every line is green
	local checklist = UIKit.Card({
		Color = C.Paper,
		Size = UDim2.fromOffset(340, 340),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -246),
		Stroke = 3,
		Parent = ctx.Screen,
	})
	checklist.Visible = false
	UIKit.Label({
		Text = "Seaworthiness check",
		Font = UIKit.TitleFont,
		TextSize = 18,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 8),
		Parent = checklist,
	})
	local checkLabel = UIKit.Label({
		Text = "",
		RichText = true,
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.25,
		Size = UDim2.new(1, -24, 0, 248),
		Position = UDim2.fromOffset(12, 36),
		Parent = checklist,
	})
	local launchButton = UIKit.Button({
		Text = "⛵ Launch ship [B]",
		Color = C.Green,
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.new(0, 12, 1, -50),
		TextSize = 17,
		Parent = checklist,
		OnClick = function()
			ctx.Invoke("ToggleBuild")
		end,
	})
	local function refreshChecklist()
		local data = State.Data
		if not data or not data.Vessel then
			return
		end
		local lines = {}
		for _, rule in data.Vessel.Rules do
			table.insert(lines, (if rule.Ok then "<font color=\"#3F7A3A\">✔</font>  " else "<font color=\"#A43A30\">✖</font>  ") .. rule.Text)
		end
		-- What the next sea zone asks for, so players know what to redesign
		if data.NextZone then
			table.insert(lines, "")
			table.insert(lines, `<b>Next zone: {data.NextZone.Name}</b>`)
			for _, rule in data.NextZone.Rules do
				table.insert(lines, (if rule.Ok then "<font color=\"#3F7A3A\">✔</font>  " else "<font color=\"#A43A30\">✖</font>  ") .. rule.Text)
			end
		else
			table.insert(lines, "")
			table.insert(lines, "<b>Rated for every zone!</b>")
		end
		checkLabel.Text = table.concat(lines, "\n")
		UIKit.SetEnabled(launchButton, data.Vessel.Ok)
	end

	local info = UIKit.Card({
		Color = C.Paper,
		Size = UDim2.fromOffset(620, 50),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Parent = bar,
	})
	local infoLabel = UIKit.Label({
		Text = "",
		RichText = true,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Parent = info,
	})

	local slots = Instance.new("Frame")
	slots.BackgroundTransparency = 1
	slots.AnchorPoint = Vector2.new(0.5, 1)
	slots.Position = UDim2.fromScale(0.5, 1)
	slots.Size = UDim2.new(1, 0, 0, 84)
	slots.Parent = bar
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = slots

	local placeable = Items.Placeable()
	local slotButtons = {}
	local refreshBar

	local function selectBlock(id: string)
		selected = id
		deleteMode = false
		refreshBar()
	end

	for i, id in placeable do
		local def = Items.Get(id)
		local button = UIKit.Button({
			Text = "",
			Color = C.White,
			Size = UDim2.fromOffset(58, 72),
			LayoutOrder = i,
			Parent = slots,
			OnClick = function()
				selectBlock(id)
			end,
		})
		UIKit.Label({
			Text = def.Icon,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 6),
			Parent = button,
		})
		local count = UIKit.Label({
			Name = "Count",
			Text = "0",
			Font = UIKit.TitleFont,
			TextSize = 18,
			TextColor3 = C.White,
			TextXAlignment = Enum.TextXAlignment.Center,
			Outlined = 2,
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.new(0, 0, 1, -26),
			Parent = button,
		})
		if i <= 9 then
			UIKit.Label({
				Text = tostring(i),
				Font = UIKit.TitleFont,
				TextSize = 14,
				TextColor3 = C.Ink,
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.fromOffset(5, 3),
				Parent = button,
			})
		end
		slotButtons[id] = { Button = button, Count = count }
	end

	local deleteButton = UIKit.Button({
		Text = "🗑️",
		Color = C.Red,
		Size = UDim2.fromOffset(58, 72),
		TextSize = 26,
		LayoutOrder = 100,
		Parent = slots,
		OnClick = function()
			deleteMode = not deleteMode
			refreshBar()
		end,
	})
	UIKit.Button({
		Text = "🔨+",
		Color = C.Purple,
		Size = UDim2.fromOffset(58, 72),
		TextSize = 22,
		LayoutOrder = 101,
		Parent = slots,
		OnClick = function()
			ctx.Panels.Inventory.ShowCrafting()
		end,
	})

	refreshBar = function()
		for id, slot in slotButtons do
			local n = State.Count(id)
			slot.Count.Text = `x{n}`
			local isSelected = id == selected and not deleteMode
			slot.Button.BackgroundColor3 = if isSelected then C.Yellow elseif n > 0 then C.White else C.Grey
			slot.Button.Outline.Thickness = if isSelected then 3.5 else 2
		end
		deleteButton.Outline.Thickness = if deleteMode then 3.5 else 2
		deleteButton.BackgroundColor3 = if deleteMode then C.Yellow else C.Red

		local hints = "<b>Click</b> place · <b>R</b> rotate · <b>X</b> delete · <b>B</b> launch"
		if deleteMode then
			infoLabel.Text = `<b><font color="#A43A30">DELETE MODE</font></b> - click a block to take it back.  {hints}`
		elseif selected then
			local def = Items.Get(selected)
			infoLabel.Text = `<b>{def.Icon} {def.Name}</b>  <font color="#8A8274">{Items.StatsText(selected)}</font><br/>{hints}`
		else
			infoLabel.Text = hints
		end
	end

	--------------------------------------------------------------------------
	-- Preview
	--------------------------------------------------------------------------
	local function clearGhost()
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
		ghostKey = ""
	end

	local function shipRoot(): (Model?, BasePart?)
		local ship = State.GetOwnShipModel()
		local root = ship and ship:FindFirstChild("Root")
		return ship, root :: BasePart?
	end

	local function majorAxis(v: Vector3): Vector3
		local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
		if ax >= ay and ax >= az then
			return Vector3.new(math.sign(v.X), 0, 0)
		elseif ay >= az then
			return Vector3.new(0, math.sign(v.Y), 0)
		end
		return Vector3.new(0, 0, math.sign(v.Z))
	end

	local function findBlockModel(ship: Model, key: string): Model?
		for _, child in ship:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("Cell") == key then
				return child
			end
		end
		return nil
	end

	-- screenPos is given for touch input; otherwise the mouse is used
	local function update(screenPos: Vector2?)
		local data = State.Data
		local ship, root = shipRoot()
		target = nil
		selection.Adornee = nil
		if not data or not ship or not root then
			clearGhost()
			return
		end

		if bounds then
			local b = data.Bounds or Config.BUILD_BOUNDS
			local center = Vector3.new((b.MinX + b.MaxX) / 2, (b.MinY + b.MaxY) / 2, (b.MinZ + b.MaxZ) / 2) * G
			bounds.CFrame = root.CFrame * CFrame.new(center)
		end

		local ray
		if screenPos then
			ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
		else
			local mouse = UserInputService:GetMouseLocation()
			ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		end
		params.FilterDescendantsInstances = { ship }
		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		if not result then
			clearGhost()
			return
		end

		local localPos = root.CFrame:PointToObjectSpace(result.Position - result.Normal * 0.05)
		local hit = Vector3.new(math.round(localPos.X / G), math.round(localPos.Y / G), math.round(localPos.Z / G))
		local occ = ShipGrid.BuildOccupancy(data.Blueprint)

		if deleteMode then
			clearGhost()
			local index = occ[ShipGrid.Key(hit.X, hit.Y, hit.Z)]
			if index then
				local entry = data.Blueprint[index]
				local model = findBlockModel(ship, ShipGrid.Key(entry.x, entry.y, entry.z))
				selection.Adornee = model
				selection.Color3 = if Items.Get(entry.t).Unique then C.Grey else INVALID
				selection.SurfaceColor3 = selection.Color3
				target = { remove = true, x = hit.X, y = hit.Y, z = hit.Z }
			end
			return
		end

		if not selected then
			clearGhost()
			return
		end
		local normal = majorAxis(root.CFrame:VectorToObjectSpace(result.Normal))
		local cell = hit + normal
		local rot = ShipGrid.EffectiveRotation(selected, rotation)
		local valid, reason = ShipGrid.CanPlace(data.Blueprint, occ, selected, cell.X, cell.Y, cell.Z, rot, data.Bounds)
		if valid and State.Count(selected) < 1 then
			valid, reason = false, "You have none left - craft or buy more!"
		end

		-- Bows change shape with their side of the ship, so the ghost depends on x too
		local key = `{selected}:{rot}:{math.sign(cell.X)}`
		if key ~= ghostKey or not ghost then
			clearGhost()
			local created = BlockFactory.MakeGhost(BlockFactory.Create(selected, { X = cell.X }))
			created.Parent = camera
			ghost = created
			ghostKey = key
		end
		local preview = ghost :: Model
		preview:PivotTo(root.CFrame * ShipGrid.CellToCFrame(cell.X, cell.Y, cell.Z, rot))
		selection.Adornee = preview
		selection.Color3 = if valid then VALID else INVALID
		selection.SurfaceColor3 = selection.Color3
		target = { x = cell.X, y = cell.Y, z = cell.Z, valid = valid, reason = reason }
	end

	local function act()
		if busy or not target then
			return
		end
		if target.remove then
			busy = true
			local result = ctx.Invoke("RemoveBlock", target.x, target.y, target.z)
			busy = false
			if result and result.ok then
				ctx.Sounds.Click()
			end
		elseif target.valid then
			busy = true
			local result = ctx.Invoke("PlaceBlock", selected, target.x, target.y, target.z, rotation)
			busy = false
			if result and result.ok then
				ctx.Sounds.Click()
			end
		elseif target.reason then
			UIKit.Toast(ctx.Screen, target.reason, "bad")
		end
	end

	--------------------------------------------------------------------------
	-- Enter / exit
	--------------------------------------------------------------------------
	local function enter()
		active = true
		bar.Visible = true
		checklist.Visible = true
		refreshChecklist()
		if not selected then
			for _, id in placeable do
				if State.Count(id) > 0 then
					selected = id
					break
				end
			end
			selected = selected or placeable[1]
		end
		local b = (State.Data and State.Data.Bounds) or Config.BUILD_BOUNDS
		local frame = Instance.new("Part")
		frame.Name = "BuildBounds"
		frame.Anchored = true
		frame.CanCollide = false
		frame.CanQuery = false
		frame.CanTouch = false
		frame.CastShadow = false
		frame.Material = Enum.Material.ForceField
		frame.Color = C.Blue
		frame.Transparency = 0.2
		frame.Size = Vector3.new(b.MaxX - b.MinX + 1, b.MaxY - b.MinY + 1, b.MaxZ - b.MinZ + 1) * G
		frame.Parent = camera
		bounds = frame
		renderConnection = RunService.RenderStepped:Connect(function()
			update(nil)
		end)
		refreshBar()
	end

	local function exit()
		active = false
		bar.Visible = false
		checklist.Visible = false
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		if bounds then
			bounds:Destroy()
			bounds = nil
		end
		clearGhost()
		selection.Adornee = nil
		target = nil
	end

	State.Observe(function(data)
		if data.Building and not active then
			enter()
		elseif not data.Building and active then
			exit()
		end
		if active then
			refreshBar()
			refreshChecklist()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if input.UserInputType == Enum.UserInputType.Touch then
				-- On touch, aim where the finger is
				update(Vector2.new(input.Position.X, input.Position.Y))
			end
			act()
		elseif input.KeyCode == Enum.KeyCode.R then
			rotation = (rotation + 1) % 4
		elseif input.KeyCode == Enum.KeyCode.X then
			deleteMode = not deleteMode
			refreshBar()
		else
			local number = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
			if number >= 1 and number <= 9 and placeable[number] then
				selectBlock(placeable[number])
			end
		end
	end)
end

return BuildController
