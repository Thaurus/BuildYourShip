-- Player ships: spawning from blueprints, building/removing blocks, and sailing.
--
-- A ship is an invisible "Root" part with every block welded (massless) to it.
-- Sailing uses three constraints on the root:
--   LinearVelocity   (plane mode)      horizontal speed and heading
--   AlignPosition    (Y axis only)     float height + gentle bobbing
--   AlignOrientation                   heading plus a little roll/pitch sway
-- The captain sits in the Helm's VehicleSeat; its Throttle/Steer drive the ship.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockFactory = require(Shared.BlockFactory)
local Config = require(Shared.Config)
local Islands = require(Shared.Islands)
local Items = require(Shared.Items)
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)
local ShipGrid = require(Shared.ShipGrid)
local ShipStats = require(Shared.ShipStats)

local ShipService = {}
local DataService, InventoryService, StateService

local ships: { [Player]: any } = {}
local berths: { [number]: Player } = {}
local shipsFolder: Folder

local RESET_COOLDOWN = 8

function ShipService.Init(services)
	DataService = services.DataService
	InventoryService = services.InventoryService
	StateService = services.StateService
end

function ShipService.Get(player: Player)
	return ships[player]
end

local function fail(msg: string)
	return { ok = false, msg = msg }
end

local function success(msg: string?)
	return { ok = true, msg = msg }
end

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function claimBerth(player: Player): number
	for i = 1, Config.MAX_BERTHS do
		if not berths[i] then
			berths[i] = player
			return i
		end
	end
	-- Server is fuller than the harbour; share a berth (ships simply overlap at spawn)
	return math.random(1, Config.MAX_BERTHS)
end

local function computeStats(ship)
	ship.Stats = ShipStats.Compute(ship.Blueprint, StateService.CargoCount(ship.Profile.Cargo))
end

local function ejectSeat(ship)
	local seat = ship.Seat
	if seat and seat.Occupant then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		seat.Occupant.Sit = false
	end
end

local function hookSeat(ship, seat: VehicleSeat?)
	ship.Seat = seat
	if not seat then
		return
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if not humanoid then
			return
		end
		local who = Players:GetPlayerFromCharacter(humanoid.Parent)
		if who ~= ship.Player or ship.Building then
			task.defer(function()
				local weld = seat:FindFirstChild("SeatWeld")
				if weld then
					weld:Destroy()
				end
				humanoid.Sit = false
				humanoid.Jump = true
			end)
			if who and who ~= ship.Player then
				StateService.Notify(who, `Only {ship.Player.DisplayName} can steer this ship!`, "bad")
			end
		elseif not ship.Root.Anchored then
			pcall(function()
				ship.Root:SetNetworkOwner(ship.Player)
			end)
		end
	end)
end

local function weldBlock(ship, entry)
	local block = BlockFactory.Create(entry.t)
	local key = ShipGrid.Key(entry.x, entry.y, entry.z)
	block.Name = `{entry.t}_{key}`
	block:SetAttribute("Cell", key)
	block:PivotTo(ship.Root.CFrame * ShipGrid.CellToCFrame(entry.x, entry.y, entry.z, entry.r or 0))
	for _, d in block:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = ship.Root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	block.Parent = ship.Model
	ship.Parts[key] = block
	if entry.t == "Helm" then
		hookSeat(ship, block:FindFirstChild("Seat") :: VehicleSeat?)
	end
end

local function updateWake(ship)
	local maxZ = 0
	for _, entry in ship.Blueprint do
		maxZ = math.max(maxZ, entry.z)
	end
	ship.Wake.Position = Vector3.new(0, -ship.Stats.FloatOffset + 0.3, (maxZ + 0.6) * Config.GRID)
end

local function setupPhysics(ship)
	local root = ship.Root
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = center
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = 4e5
	lv.PlaneVelocity = Vector2.zero
	lv.Enabled = false
	lv.Parent = root

	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = center
	ap.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	ap.ForceRelativeTo = Enum.ActuatorRelativeTo.World
	ap.MaxAxesForce = Vector3.new(0, 6e5, 0)
	ap.Responsiveness = 12
	ap.Position = root.Position
	ap.Enabled = false
	ap.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = center
	ao.MaxTorque = 1e7
	ao.Responsiveness = 18
	ao.CFrame = root.CFrame.Rotation
	ao.Enabled = false
	ao.Parent = root

	local wake = Instance.new("Attachment")
	wake.Name = "Wake"
	wake.Parent = root
	local foam = Instance.new("ParticleEmitter")
	foam.Name = "Foam"
	foam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	foam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	foam.LightEmission = 0.3
	foam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	foam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	foam.Lifetime = NumberRange.new(1.2, 2)
	foam.Speed = NumberRange.new(1, 3)
	foam.SpreadAngle = Vector2.new(30, 30)
	foam.EmissionDirection = Enum.NormalId.Back
	foam.Rate = 0
	foam.Parent = wake

	ship.LinearVelocity = lv
	ship.AlignPosition = ap
	ship.AlignOrientation = ao
	ship.Wake = wake
	ship.Foam = foam
end

local function nameTag(ship)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShipTag"
	gui.Size = UDim2.fromOffset(240, 40)
	gui.StudsOffset = Vector3.new(0, 26, 0)
	gui.MaxDistance = 500
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Palette.Yellow
	label.Text = `⚓ {ship.Player.DisplayName}`
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Palette.Ink
	stroke.Parent = label
	gui.Parent = ship.Root
end

local function hold(ship)
	ship.LinearVelocity.Enabled = false
	ship.AlignPosition.Enabled = false
	ship.AlignOrientation.Enabled = false
	ship.Root.Anchored = true
	ship.Speed = 0
	ship.Foam.Rate = 0
end

local function release(ship)
	ship.Yaw = yawOf(ship.Root.CFrame)
	ship.Speed = 0
	ship.AlignOrientation.CFrame = CFrame.Angles(0, ship.Yaw, 0)
	ship.AlignPosition.Position = Vector3.new(0, Config.SEA_LEVEL + ship.Stats.FloatOffset, 0)
	ship.Root.Anchored = false
	ship.LinearVelocity.Enabled = true
	ship.AlignPosition.Enabled = true
	ship.AlignOrientation.Enabled = true
	pcall(function()
		ship.Root:SetNetworkOwner(ship.Player)
	end)
end

local function berthCFrame(ship): CFrame
	return Islands.GetBerthCFrame(ship.Berth) + Vector3.new(0, ship.Stats.FloatOffset, 0)
end

local function buildModel(ship, cf: CFrame)
	if ship.Model then
		ship.Model:Destroy()
	end
	computeStats(ship)

	local model = Instance.new("Model")
	model.Name = `{ship.Player.Name}_Ship`
	model:SetAttribute("OwnerId", ship.Player.UserId)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root

	ship.Model = model
	ship.Root = root
	ship.Parts = {}
	ship.Seat = nil

	for _, entry in ship.Blueprint do
		weldBlock(ship, entry)
	end
	setupPhysics(ship)
	nameTag(ship)
	updateWake(ship)

	CollectionService:AddTag(model, "Outline")
	CollectionService:AddTag(model, "Ship")
	model.Parent = shipsFolder

	if ship.Building then
		hold(ship)
	else
		release(ship)
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function ShipService.Spawn(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local ship = {
		Player = player,
		Profile = profile,
		Blueprint = profile.Blueprint,
		Berth = claimBerth(player),
		Building = false,
		Speed = 0,
		Yaw = 0,
		Phase = math.random() * 10,
		DockedAt = nil,
		LastReset = 0,
	}
	ships[player] = ship
	computeStats(ship)
	buildModel(ship, berthCFrame(ship))
	StateService.Push(player)
end

function ShipService.Despawn(player: Player)
	local ship = ships[player]
	if not ship then
		return
	end
	if ship.Model then
		ship.Model:Destroy()
	end
	if berths[ship.Berth] == player then
		berths[ship.Berth] = nil
	end
	ships[player] = nil
end

function ShipService.RefreshStats(player: Player)
	local ship = ships[player]
	if not ship then
		return
	end
	computeStats(ship)
	updateWake(ship)
	StateService.Push(player)
end

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

function ShipService.ToggleBuild(player: Player)
	local ship = ships[player]
	if not ship then
		return fail("You have no ship yet.")
	end

	if ship.Building then
		ship.Building = false
		computeStats(ship)
		updateWake(ship)
		release(ship)
		StateService.Push(player)
		local warning = if ship.Stats.Overloaded then " ...but she's too heavy and barely floats!" else ""
		return success("⛵ Ship launched!" .. warning)
	end

	local berth = Islands.GetBerthCFrame(ship.Berth)
	local offset = ship.Root.Position - berth.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > Config.BERTH_RADIUS then
		return fail("Sail back to your berth in Port Haven to build. (Or use Reset Ship.)")
	end

	ejectSeat(ship)
	ship.Building = true
	hold(ship)
	ship.Root.CFrame = berthCFrame(ship)
	StateService.Push(player)
	return success("🔨 Build mode! Click to place blocks.")
end

local function isInt(n: any): boolean
	return type(n) == "number" and n == n and math.floor(n) == n and math.abs(n) < 64
end

function ShipService.PlaceBlock(player: Player, blockId: any, x: any, y: any, z: any, r: any)
	local ship = ships[player]
	if not ship or not ship.Building then
		return fail("Enter build mode at your berth first.")
	end
	if type(blockId) ~= "string" or not Items.IsBlock(blockId) or not (isInt(x) and isInt(y) and isInt(z) and isInt(r)) then
		return fail("Invalid block.")
	end
	local def = Items.Get(blockId)
	if InventoryService.Count(player, blockId) < 1 then
		return fail(`You have no {def.Name}. Craft or buy one!`)
	end
	local occ = ShipGrid.BuildOccupancy(ship.Blueprint)
	local ok, reason = ShipGrid.CanPlace(ship.Blueprint, occ, blockId, x, y, z, r)
	if not ok then
		return fail(reason or "Can't place that there.")
	end
	if not InventoryService.Remove(player, blockId, 1) then
		return fail("Not enough blocks.")
	end
	local entry = { t = blockId, x = x, y = y, z = z, r = r }
	table.insert(ship.Blueprint, entry)
	weldBlock(ship, entry)
	computeStats(ship)
	updateWake(ship)
	StateService.Push(player)
	return success()
end

function ShipService.RemoveBlock(player: Player, x: any, y: any, z: any)
	local ship = ships[player]
	if not ship or not ship.Building then
		return fail("Enter build mode at your berth first.")
	end
	if not (isInt(x) and isInt(y) and isInt(z)) then
		return fail("Invalid position.")
	end
	local occ = ShipGrid.BuildOccupancy(ship.Blueprint)
	local index, reason = ShipGrid.CanRemove(ship.Blueprint, occ, x, y, z)
	if not index then
		return fail(reason or "Can't remove that.")
	end

	-- Don't let players remove the crates their cargo is sitting in
	local preview = table.clone(ship.Blueprint)
	table.remove(preview, index)
	local cargo = StateService.CargoCount(ship.Profile.Cargo)
	if cargo > ShipStats.Compute(preview, cargo).MaxCargo then
		return fail("Sell some cargo first, it wouldn't fit anymore!")
	end

	local entry = table.remove(ship.Blueprint, index)
	local key = ShipGrid.Key(entry.x, entry.y, entry.z)
	local part = ship.Parts[key]
	if part then
		part:Destroy()
		ship.Parts[key] = nil
	end
	InventoryService.Add(player, entry.t, 1)
	computeStats(ship)
	updateWake(ship)
	StateService.Push(player)
	return success()
end

--------------------------------------------------------------------------------
-- Helpers for players
--------------------------------------------------------------------------------

function ShipService.Board(player: Player)
	local ship = ships[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not ship or not ship.Seat or not humanoid or humanoid.Health <= 0 then
		return fail("Can't board right now.")
	end
	if humanoid.SeatPart then
		humanoid.Sit = false
	end
	character:PivotTo(ship.Seat.CFrame + Vector3.new(0, 4, 0))
	if not ship.Building then
		task.defer(function()
			ship.Seat:Sit(humanoid)
		end)
		return success("☸️ You have the helm! W/S sail, A/D steer.")
	end
	return success("Welcome aboard!")
end

function ShipService.Reset(player: Player)
	local ship = ships[player]
	if not ship then
		return fail("You have no ship yet.")
	end
	local now = os.clock()
	if now - ship.LastReset < RESET_COOLDOWN then
		return fail("Easy, captain! Wait a few seconds.")
	end
	ship.LastReset = now
	ejectSeat(ship)
	ship.Building = false
	computeStats(ship)
	buildModel(ship, berthCFrame(ship))

	local character = player.Character
	if character then
		local berth = Islands.GetBerthCFrame(ship.Berth)
		local side = if berth.Position.X > 0 then 1 else -1
		character:PivotTo(CFrame.new(side * 6, Config.SEA_LEVEL + 7, berth.Position.Z))
	end
	StateService.Push(player)
	return success("🧭 Your ship was towed back to Port Haven.")
end

--------------------------------------------------------------------------------
-- Simulation
--------------------------------------------------------------------------------

local function moveToward(current: number, target: number, step: number): number
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

local function stepShip(ship, dt: number, t: number)
	if ship.Building or not ship.Root or not ship.Root.Parent or ship.Root.Anchored then
		return
	end
	local stats = ship.Stats
	local throttle, steer = 0, 0
	local seat = ship.Seat
	if seat and seat.Occupant then
		-- Prefer the input the captain's client reports; fall back to the seat's replicated values
		if ship.Input and os.clock() - ship.Input.Time < 0.6 then
			throttle, steer = ship.Input.Throttle, ship.Input.Steer
		else
			throttle = seat.ThrottleFloat
			steer = seat.SteerFloat
		end
	end

	local target = if throttle >= 0 then throttle * stats.MaxSpeed else throttle * stats.MaxSpeed * 0.35
	local accel = math.max(stats.MaxSpeed * 0.3, 3)
	-- Coasting slows down gently, active braking is quicker
	if throttle == 0 then
		accel *= 0.5
	end
	ship.Speed = moveToward(ship.Speed, target, accel * dt)

	local speedFraction = if stats.MaxSpeed > 0 then math.clamp(math.abs(ship.Speed) / stats.MaxSpeed, 0, 1) else 0
	ship.Yaw -= steer * stats.TurnRate * (0.35 + 0.65 * speedFraction) * dt

	local forward = Vector3.new(-math.sin(ship.Yaw), 0, -math.cos(ship.Yaw))
	local velocity = forward * ship.Speed

	-- Soft world border
	local pos = ship.Root.Position
	local flat = Vector3.new(pos.X, 0, pos.Z)
	local distance = flat.Magnitude
	if distance > Config.WORLD_RADIUS then
		velocity -= flat.Unit * (distance - Config.WORLD_RADIUS + 10)
	end
	ship.LinearVelocity.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)

	local bob = math.sin(t * 1.1 + ship.Phase) * 0.35
	ship.AlignPosition.Position = Vector3.new(0, Config.SEA_LEVEL + stats.FloatOffset + bob, 0)

	local roll = math.sin(t * 0.9 + ship.Phase) * math.rad(2) + steer * speedFraction * math.rad(4)
	local pitch = math.sin(t * 0.7 + ship.Phase * 1.3) * math.rad(1.2) + (ship.Speed / Config.MAX_SPEED) * math.rad(2)
	ship.AlignOrientation.CFrame = CFrame.Angles(0, ship.Yaw, 0) * CFrame.Angles(pitch, 0, roll)

	ship.Foam.Rate = if math.abs(ship.Speed) > 2 then math.abs(ship.Speed) * 1.2 else 0
end

local function updateDocking()
	for player, ship in ships do
		if ship.Root and ship.Root.Parent then
			local docked = if ship.Building then "PortHaven" else Islands.FindDocked(ship.Root.Position)
			if docked ~= ship.DockedAt then
				ship.DockedAt = docked
				if docked then
					StateService.Notify(player, `⚓ Docked at {Islands.Get(docked).Name}`, "info")
				end
				StateService.Push(player)
			end
		end
	end
end

function ShipService.Start()
	shipsFolder = Instance.new("Folder")
	shipsFolder.Name = "Ships"
	shipsFolder.Parent = Workspace

	Remotes.Function("ToggleBuild").OnServerInvoke = ShipService.ToggleBuild
	Remotes.Function("PlaceBlock").OnServerInvoke = ShipService.PlaceBlock
	Remotes.Function("RemoveBlock").OnServerInvoke = ShipService.RemoveBlock
	Remotes.Function("BoardShip").OnServerInvoke = ShipService.Board
	Remotes.Function("ResetShip").OnServerInvoke = ShipService.Reset

	Remotes.Event("HelmInput").OnServerEvent:Connect(function(player, throttle, steer)
		local ship = ships[player]
		if not ship or type(throttle) ~= "number" or type(steer) ~= "number" or throttle ~= throttle or steer ~= steer then
			return
		end
		ship.Input = {
			Throttle = math.clamp(throttle, -1, 1),
			Steer = math.clamp(steer, -1, 1),
			Time = os.clock(),
		}
	end)

	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for _, ship in ships do
			stepShip(ship, dt, t)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			updateDocking()
		end
	end)
end

return ShipService
