-- Ships: spawning from blueprints, the virtual drydock, building, sailing,
-- damage and sinking. Player ships and NPC pirate ships share this code.
--
-- A ship is an invisible "Root" part with every block welded (massless) to it.
-- Sailing uses three constraints on the root:
--   LinearVelocity   (plane mode)      horizontal speed and heading
--   AlignPosition    (Y axis only)     float height, bobbing, sinking
--   AlignOrientation                   heading plus roll/pitch sway
-- The captain sits in the Helm's VehicleSeat and reports throttle/steer.
--
-- There are no fixed berths. Ships moor at any free spot in Port Haven's
-- harbour, and building happens in a private drydock that is generated on
-- demand far away from the ocean, so any number of players fits.

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
local S -- all services

local ships: { [number]: any } = {}
local playerShips: { [Player]: any } = {}
local drydockSlots: { [number]: any } = {}
local harbourSpots: { Vector3 } = {}
local nextId = 0
local shipsFolder: Folder

local RESET_COOLDOWN = 30
local COMBAT_LOCK = 20 -- seconds after taking damage during which you can't teleport the ship home

ShipService.SunkHandlers = {} :: { (any) -> () }

function ShipService.Init(services)
	S = services
end

--------------------------------------------------------------------------------
-- Lookup helpers
--------------------------------------------------------------------------------

function ShipService.Get(player: Player)
	return playerShips[player]
end

function ShipService.GetById(id: number)
	return ships[id]
end

function ShipService.All()
	return ships
end

function ShipService.FromInstance(inst: Instance?)
	while inst and inst ~= Workspace do
		local id = inst:GetAttribute("ShipId")
		if id then
			return ships[id]
		end
		inst = inst.Parent
	end
	return nil
end

-- Captain or crew of a player ship
function ShipService.CanAccess(player: Player, ship): boolean
	if not ship or ship.IsNPC or not ship.Captain then
		return false
	end
	return S.CrewService.IsCrew(player, ship.Captain)
end

-- The ship a player sails on: their own, or their captain's if they are crew
function ShipService.ShipFor(player: Player)
	local captain = S.CrewService.CaptainOf(player)
	return playerShips[captain] or playerShips[player]
end

-- Current world CFrame of a block's anchor cell (models' pivots don't follow physics)
function ShipService.CellCFrame(ship, key: string): CFrame
	local x, y, z = ShipGrid.ParseKey(key)
	local r = 0
	for _, entry in ship.Blueprint do
		if entry.x == x and entry.y == y and entry.z == z then
			r = entry.r or 0
			break
		end
	end
	return ship.Root.CFrame * ShipGrid.CellToCFrame(x or 0, y or 0, z or 0, r)
end

function ShipService.CrateCount(ship): number
	local n = 0
	for _, list in ship.Holds do
		n += #list
	end
	return n
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

local function rootPart(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

--------------------------------------------------------------------------------
-- Model construction
--------------------------------------------------------------------------------

local function computeStats(ship)
	ship.Stats = ShipStats.Compute(ship.Blueprint, ShipService.CrateCount(ship))
	ship.HP = math.min(ship.HP or ship.Stats.MaxHP, ship.Stats.MaxHP)
end

local function updateHealth(ship)
	if not ship.Model then
		return
	end
	ship.Model:SetAttribute("HP", ship.HP)
	ship.Model:SetAttribute("MaxHP", ship.Stats.MaxHP)
	local bar = ship.HealthFill
	if bar then
		local frac = math.clamp(ship.HP / ship.Stats.MaxHP, 0, 1)
		bar.Size = UDim2.fromScale(frac, 1)
		bar.BackgroundColor3 = if frac > 0.5 then Color3.fromRGB(96, 190, 90) elseif frac > 0.25 then Color3.fromRGB(230, 170, 60) else Color3.fromRGB(220, 70, 60)
	end
end

local function pushCrew(ship)
	if ship.Captain then
		for _, member in S.CrewService.Members(ship.Captain) do
			S.StateService.Push(member)
		end
	end
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
	if ship.IsNPC then
		seat.Disabled = true
		return
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if not humanoid then
			return
		end
		local who = Players:GetPlayerFromCharacter(humanoid.Parent)
		if who ~= ship.Captain or ship.Building or ship.Sinking then
			task.defer(function()
				local weld = seat:FindFirstChild("SeatWeld")
				if weld then
					weld:Destroy()
				end
				humanoid.Sit = false
				humanoid.Jump = true
			end)
			if who and who ~= ship.Captain then
				S.StateService.Notify(who, `Only {ship.Captain.DisplayName} can steer this ship!`, "bad")
			end
			return
		end
		S.CargoService.DropCarried(who)
		S.QuestService.Fire(who, "Helm")
		if not ship.Root.Anchored then
			pcall(function()
				ship.Root:SetNetworkOwner(ship.Captain)
			end)
		end
	end)
end

local function weldBlock(ship, entry)
	local block = BlockFactory.Create(entry.t, { X = entry.x, Style = ship.Style })
	local key = ShipGrid.Key(entry.x, entry.y, entry.z)
	block.Name = `{entry.t}_{key}`
	block:SetAttribute("Cell", key)
	block:SetAttribute("BlockType", entry.t)
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
	elseif entry.t == "CargoHold" then
		ship.Holds[key] = ship.Holds[key] or {}
		S.CargoService.SetupHold(ship, key, block)
	elseif entry.t == "Cannon" then
		S.CombatService.SetupCannon(ship, key, block)
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
	foam.Color = ColorSequence.new(Color3.fromRGB(236, 242, 244))
	foam.LightEmission = 0.1
	foam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
	foam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	foam.Lifetime = NumberRange.new(1.5, 2.5)
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
	gui.Size = UDim2.fromOffset(220, 46)
	gui.StudsOffset = Vector3.new(0, 26, 0)
	gui.MaxDistance = 600
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 28)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = if ship.IsNPC then Color3.fromRGB(240, 110, 90) else Color3.fromRGB(250, 236, 200)
	label.Text = ship.Name
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Palette.Ink
	stroke.Parent = label
	local back = Instance.new("Frame")
	back.Size = UDim2.new(0.7, 0, 0, 10)
	back.Position = UDim2.new(0.15, 0, 0, 32)
	back.BackgroundColor3 = Palette.Ink
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner:Clone().Parent = fill
	ship.HealthFill = fill
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
	if ship.Captain then
		pcall(function()
			ship.Root:SetNetworkOwner(ship.Captain)
		end)
	else
		pcall(function()
			ship.Root:SetNetworkOwner(nil)
		end)
	end
end

local function buildModel(ship, cf: CFrame)
	if ship.Model then
		ship.Model:Destroy()
	end
	computeStats(ship)

	local model = Instance.new("Model")
	model.Name = ship.Name
	model:SetAttribute("ShipId", ship.Id)
	model:SetAttribute("OwnerId", if ship.Captain then ship.Captain.UserId else 0)
	model:SetAttribute("Pirate", ship.IsNPC == true)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.CFrame = cf + Vector3.new(0, ship.Stats.FloatOffset, 0)
	root.Parent = model
	model.PrimaryPart = root

	ship.Model = model
	ship.Root = root
	ship.Parts = {}
	ship.Seat = nil
	ship.Cannons = {}

	setupPhysics(ship)
	for _, entry in ship.Blueprint do
		weldBlock(ship, entry)
	end
	nameTag(ship)
	updateWake(ship)
	updateHealth(ship)

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
-- Harbour moorings and drydocks
--------------------------------------------------------------------------------

local function computeHarbourSpots()
	local home = Islands.Get("PortHaven")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = true
	local anchor = home.Position + Vector3.new(0, 0, home.Radius + 60)
	for z = home.Radius + 60, home.Radius + 340, 70 do
		for x = -220, 220, 60 do
			if math.abs(x) >= 40 then
				local pos = home.Position + Vector3.new(x, 0, z)
				local hit = Workspace:Raycast(pos + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), params)
				local depth = if hit then hit.Position.Y else -Config.OCEAN_DEPTH
				if depth < -10 and Islands.IsSafe(pos) then
					table.insert(harbourSpots, Vector3.new(pos.X, Config.SEA_LEVEL, pos.Z))
				end
			end
		end
	end
	table.sort(harbourSpots, function(a, b)
		return (a - anchor).Magnitude < (b - anchor).Magnitude
	end)
end

local function findHarbourSpot(forShip): CFrame
	for _, spot in harbourSpots do
		local free = true
		for _, other in ships do
			if other ~= forShip and other.Root and not other.Building and flatDistance(other.Root.Position, spot) < 66 then
				free = false
				break
			end
		end
		if free then
			return CFrame.lookAt(spot, spot + Vector3.new(0, 0, 1))
		end
	end
	-- Harbour is packed: anchor further out to sea
	local home = Islands.Get("PortHaven")
	local pos = home.Position + Vector3.new(math.random(-200, 200), Config.SEA_LEVEL, home.Radius + 380 + math.random(0, 120))
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
end

local function claimDrydock(ship): (number, Vector3)
	local slot = 1
	while drydockSlots[slot] do
		slot += 1
	end
	drydockSlots[slot] = ship
	return slot, Config.DRYDOCK_ORIGIN + Vector3.new((slot - 1) * Config.DRYDOCK_SPACING, 0, 0)
end

local function releaseDrydock(ship)
	if ship.Dock then
		if ship.Dock.Model then
			ship.Dock.Model:Destroy()
		end
		drydockSlots[ship.Dock.Slot] = nil
		ship.Dock = nil
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local function newShip(props)
	nextId += 1
	local ship = {
		Id = nextId,
		Building = false,
		Sinking = false,
		Speed = 0,
		Yaw = 0,
		Phase = math.random() * 10,
		LastReset = 0,
		LastDamaged = 0,
		DamageBy = {},
		Holds = {},
		Parts = {},
		Cannons = {},
		AI = { Throttle = 0, Steer = 0 },
	}
	for k, v in props do
		ship[k] = v
	end
	ships[ship.Id] = ship
	return ship
end

function ShipService.SpawnPlayerShip(player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local ship = newShip({
		Captain = player,
		Name = `⚓ {player.DisplayName}`,
		Profile = profile,
		Blueprint = profile.Blueprint,
		Holds = profile.Holds,
		Bounds = if S.GamepassService.Has(player, "GrandShipyard") then Config.BIG_BUILD_BOUNDS else Config.BUILD_BOUNDS,
	})
	playerShips[player] = ship
	buildModel(ship, findHarbourSpot(ship))
	S.StateService.Push(player)
	return ship
end

function ShipService.SpawnNPC(blueprint, cf: CFrame, props)
	local ship = newShip({
		IsNPC = true,
		Name = props.Name or "☠️ Pirates",
		Style = props.Style or "Pirate",
		Blueprint = blueprint,
		Holds = props.Holds or {},
	})
	buildModel(ship, cf)
	return ship
end

function ShipService.Despawn(ship)
	if not ship then
		return
	end
	releaseDrydock(ship)
	if ship.Model then
		ship.Model:Destroy()
	end
	ships[ship.Id] = nil
	if ship.Captain and playerShips[ship.Captain] == ship then
		playerShips[ship.Captain] = nil
	end
end

function ShipService.DespawnPlayer(player: Player)
	ShipService.Despawn(playerShips[player])
end

function ShipService.RefreshStats(ship)
	if not ship then
		return
	end
	computeStats(ship)
	updateWake(ship)
	updateHealth(ship)
	pushCrew(ship)
end

-- Grand Shipyard bought mid-session
function ShipService.SetBounds(player: Player, bounds)
	local ship = playerShips[player]
	if ship then
		ship.Bounds = bounds
		S.StateService.Push(player)
	end
end

--------------------------------------------------------------------------------
-- Damage, repair and sinking
--------------------------------------------------------------------------------

local function sink(ship)
	ship.Sinking = true
	ship.SinkStart = os.clock()
	ship.Model:SetAttribute("Sinking", true)
	ejectSeat(ship)
	ship.Speed = 0
	ship.Foam.Rate = 0
	S.CargoService.SpillHolds(ship)

	S.CombatService.Effect("Explosion", ship.Root.Position + Vector3.new(0, 4, 0), 2)

	for _, handler in ShipService.SunkHandlers do
		task.spawn(handler, ship)
	end

	if ship.Captain then
		for _, member in S.CrewService.Members(ship.Captain) do
			S.StateService.Notify(member, "💥 The ship is going down! Abandon ship!", "bad")
		end
	end
	pushCrew(ship)

	task.delay(Config.SINK_DURATION, function()
		if ship.Model then
			ship.Model:Destroy()
			ship.Model = nil
		end
		if ship.IsNPC then
			ShipService.Despawn(ship)
			return
		end
		task.wait(math.max(0, Config.RESPAWN_DELAY - Config.SINK_DURATION))
		if ships[ship.Id] ~= ship then
			return -- captain left meanwhile
		end
		ship.Sinking = false
		ship.HP = nil
		ship.DamageBy = {}
		buildModel(ship, findHarbourSpot(ship))
		S.StateService.Notify(ship.Captain, "🔨 The shipwrights rebuilt your ship in Port Haven.", "good")
		pushCrew(ship)
	end)
end

-- Returns true if the hit counted
function ShipService.Damage(ship, amount: number, attacker: Player?, attackerShip): boolean
	if not ship or ship.Sinking or ship.Building or not ship.Root then
		return false
	end
	if Islands.IsSafe(ship.Root.Position) then
		return false
	end
	if attacker and ShipService.CanAccess(attacker, ship) then
		return false -- no friendly fire within a crew
	end
	if attackerShip and attackerShip.IsNPC and ship.IsNPC then
		return false
	end
	ship.HP -= amount
	ship.LastDamaged = os.clock()
	if attacker then
		ship.DamageBy[attacker] = (ship.DamageBy[attacker] or 0) + amount
	end
	updateHealth(ship)
	if ship.HP <= 0 then
		ship.HP = 0
		sink(ship)
	end
	pushCrew(ship)
	return true
end

function ShipService.Repair(ship, amount: number)
	if not ship or ship.Sinking then
		return
	end
	local before = ship.HP
	ship.HP = math.min(ship.Stats.MaxHP, ship.HP + amount)
	if ship.HP ~= before then
		updateHealth(ship)
		pushCrew(ship)
	end
end

function ShipService.UseRepairKit(player: Player)
	local ship = ShipService.ShipFor(player)
	local root = rootPart(player)
	if not ship or not ship.Root or not root then
		return fail("No ship to repair.")
	end
	if ship.Sinking then
		return fail("Too late, she's going under!")
	end
	if ship.HP >= ship.Stats.MaxHP then
		return fail("The hull is already in perfect shape.")
	end
	if (root.Position - ship.Root.Position).Magnitude > 60 then
		return fail("Get aboard your ship to repair it.")
	end
	if not S.InventoryService.Remove(player, "RepairKit", 1) then
		return fail("You need a Repair Kit (2 Planks + 1 Rope).")
	end
	ShipService.Repair(ship, Config.REPAIR_KIT_HP)
	return success(`🧰 Hull patched! {math.floor(ship.HP)}/{ship.Stats.MaxHP} HP`)
end

--------------------------------------------------------------------------------
-- Building (virtual drydock)
--------------------------------------------------------------------------------

local function teleport(player: Player, cf: CFrame)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	if humanoid.SeatPart then
		humanoid.Sit = false
	end
	character:PivotTo(cf)
end

local function launch(ship)
	local player = ship.Captain
	local ok, rules = ShipGrid.VesselCheck(ship.Blueprint)
	if not ok then
		for _, rule in rules do
			if not rule.Ok then
				return fail(`Not seaworthy yet: {rule.Text}`)
			end
		end
	end
	ship.Building = false
	computeStats(ship)
	ship.HP = ship.Stats.MaxHP -- the shipwrights patch everything up in drydock
	local spot = findHarbourSpot(ship)
	ship.Root.CFrame = spot + Vector3.new(0, ship.Stats.FloatOffset, 0)
	updateWake(ship)
	updateHealth(ship)
	release(ship)
	releaseDrydock(ship)
	if ship.Seat then
		teleport(player, ship.Seat.CFrame + Vector3.new(0, 4, 3))
	end
	S.QuestService.Fire(player, "Launch")
	pushCrew(ship)
	local warning = if ship.Stats.Overloaded then " ...but she's too heavy and barely floats!" else ""
	return success("⛵ Launched into Port Haven harbour!" .. warning)
end

function ShipService.ToggleBuild(player: Player)
	local ship = playerShips[player]
	if not ship or not ship.Root then
		return fail("You have no ship right now.")
	end
	if ship.Building then
		return launch(ship)
	end
	if ship.Sinking then
		return fail("Your ship is sinking!")
	end
	if ship.DockedAt ~= "PortHaven" then
		return fail("Sail back to Port Haven harbour to use the drydock.")
	end
	local root = rootPart(player)
	if not root or (root.Position - ship.Root.Position).Magnitude > Config.SHIP_ACCESS_RANGE then
		return fail("Walk over to your ship first (it's moored in the harbour).")
	end

	ejectSeat(ship)
	ship.Building = true
	hold(ship)
	local slot, origin = claimDrydock(ship)
	local dock = S.WorldBuilder.CreateDrydock(origin, ship.Bounds, slot)
	ship.Dock = { Slot = slot, Origin = origin, Model = dock.Model, Walkway = dock.Walkway }
	ship.Root.CFrame = CFrame.new(origin + Vector3.new(0, ship.Stats.FloatOffset, 0))

	-- Crew left standing on the old mooring would fall in; bring them along
	for _, member in S.CrewService.Members(player) do
		local memberRoot = rootPart(member)
		if member == player or (memberRoot and (memberRoot.Position - root.Position).Magnitude < 60) then
			teleport(member, dock.Walkway)
		end
	end
	S.QuestService.Fire(player, "EnterBuild")
	pushCrew(ship)
	return success("🔨 Welcome to your drydock! Click to place blocks.")
end

local function isInt(n: any): boolean
	return type(n) == "number" and n == n and math.floor(n) == n and math.abs(n) < 64
end

function ShipService.PlaceBlock(player: Player, blockId: any, x: any, y: any, z: any, r: any)
	local ship = playerShips[player]
	if not ship or not ship.Building then
		return fail("Open your drydock first (B in Port Haven).")
	end
	if type(blockId) ~= "string" or not Items.IsBlock(blockId) or not (isInt(x) and isInt(y) and isInt(z) and isInt(r)) then
		return fail("Invalid block.")
	end
	local def = Items.Get(blockId)
	if S.InventoryService.Count(player, blockId) < 1 then
		return fail(`You have no {def.Name}. Craft or buy one!`)
	end
	local occ = ShipGrid.BuildOccupancy(ship.Blueprint)
	local ok, reason = ShipGrid.CanPlace(ship.Blueprint, occ, blockId, x, y, z, r, ship.Bounds)
	if not ok then
		return fail(reason or "Can't place that there.")
	end
	if not S.InventoryService.Remove(player, blockId, 1) then
		return fail("Not enough blocks.")
	end
	local entry = { t = blockId, x = x, y = y, z = z, r = ShipGrid.EffectiveRotation(blockId, r) }
	table.insert(ship.Blueprint, entry)
	weldBlock(ship, entry)
	computeStats(ship)
	ship.HP = ship.Stats.MaxHP
	updateWake(ship)
	updateHealth(ship)
	S.QuestService.Fire(player, "Place", blockId)
	S.StateService.Push(player)
	return success()
end

function ShipService.RemoveBlock(player: Player, x: any, y: any, z: any)
	local ship = playerShips[player]
	if not ship or not ship.Building then
		return fail("Open your drydock first (B in Port Haven).")
	end
	if not (isInt(x) and isInt(y) and isInt(z)) then
		return fail("Invalid position.")
	end
	local occ = ShipGrid.BuildOccupancy(ship.Blueprint)
	local index, reason = ShipGrid.CanRemove(ship.Blueprint, occ, x, y, z)
	if not index then
		return fail(reason or "Can't remove that.")
	end
	local entry = ship.Blueprint[index]
	local key = ShipGrid.Key(entry.x, entry.y, entry.z)
	if entry.t == "CargoHold" and ship.Holds[key] and #ship.Holds[key] > 0 then
		return fail("Unload the crates in that hold first.")
	end

	table.remove(ship.Blueprint, index)
	ship.Holds[key] = if entry.t == "CargoHold" then nil else ship.Holds[key]
	local part = ship.Parts[key]
	if part then
		part:Destroy()
		ship.Parts[key] = nil
	end
	ship.Cannons[key] = nil
	S.InventoryService.Add(player, entry.t, 1)
	computeStats(ship)
	ship.HP = ship.Stats.MaxHP
	updateWake(ship)
	updateHealth(ship)
	S.StateService.Push(player)
	return success()
end

--------------------------------------------------------------------------------
-- Helpers for players
--------------------------------------------------------------------------------

function ShipService.Board(player: Player)
	local ship = ShipService.ShipFor(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not ship or not ship.Seat or not ship.Root or not humanoid or humanoid.Health <= 0 then
		return fail("Can't board right now.")
	end
	if ship.Sinking then
		return fail("That ship is sinking!")
	end
	local isCaptain = ship.Captain == player
	if ship.Building and not isCaptain then
		teleport(player, ship.Dock.Walkway)
		return success("Your captain is in the drydock.")
	end
	teleport(player, ship.Seat.CFrame + Vector3.new(0, 4, if isCaptain then 0 else 3))
	if isCaptain and not ship.Building then
		task.defer(function()
			ship.Seat:Sit(humanoid)
		end)
		return success("☸️ You have the helm! W/S sail, A/D steer, F broadside.")
	end
	return success("Welcome aboard!")
end

function ShipService.Reset(player: Player)
	local ship = playerShips[player]
	if not ship then
		return fail("You have no ship right now.")
	end
	if ship.Building then
		return fail("Your ship is in the drydock. Press B to launch.")
	end
	if ship.Sinking then
		return fail("Your ship is sinking, it will be rebuilt soon.")
	end
	local now = os.clock()
	if now - ship.LastDamaged < COMBAT_LOCK then
		return fail("You're under fire! No escaping now.")
	end
	if now - ship.LastReset < RESET_COOLDOWN then
		return fail("The tugboat is busy. Try again in a few seconds.")
	end
	ship.LastReset = now
	ejectSeat(ship)
	buildModel(ship, findHarbourSpot(ship))
	if ship.Seat then
		teleport(player, ship.Seat.CFrame + Vector3.new(0, 4, 3))
	end
	pushCrew(ship)
	return success("🧭 A tugboat towed your ship back to Port Haven.")
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

	if ship.Sinking then
		local progress = math.clamp((os.clock() - ship.SinkStart) / Config.SINK_DURATION, 0, 1)
		ship.LinearVelocity.PlaneVelocity = Vector2.zero
		ship.AlignPosition.Position = Vector3.new(0, Config.SEA_LEVEL + stats.FloatOffset - progress * progress * 18, 0)
		ship.AlignOrientation.CFrame = CFrame.Angles(0, ship.Yaw, 0) * CFrame.Angles(progress * math.rad(-14), 0, progress * math.rad(28))
		return
	end

	local throttle, steer = 0, 0
	if ship.IsNPC then
		throttle, steer = ship.AI.Throttle, ship.AI.Steer
	elseif ship.Seat and ship.Seat.Occupant then
		if ship.Input and os.clock() - ship.Input.Time < 0.6 then
			throttle, steer = ship.Input.Throttle, ship.Input.Steer
		else
			throttle = ship.Seat.ThrottleFloat
			steer = ship.Seat.SteerFloat
		end
	end

	local target = if throttle >= 0 then throttle * stats.MaxSpeed else throttle * stats.MaxSpeed * 0.35
	local accel = math.max(stats.MaxSpeed * 0.3, 3)
	if throttle == 0 then
		accel *= 0.5
	end
	ship.Speed = moveToward(ship.Speed, target, accel * dt)

	local speedFraction = if stats.MaxSpeed > 0 then math.clamp(math.abs(ship.Speed) / stats.MaxSpeed, 0, 1) else 0
	ship.Yaw -= steer * stats.TurnRate * (0.35 + 0.65 * speedFraction) * dt

	local forward = Vector3.new(-math.sin(ship.Yaw), 0, -math.cos(ship.Yaw))
	local velocity = forward * ship.Speed

	local pos = ship.Root.Position
	local storm = S.StormService.IntensityAt(pos)
	if storm > 0 then
		velocity += S.StormService.Wind() * storm * 7
	end

	-- Soft world border
	local flat = Vector3.new(pos.X, 0, pos.Z)
	local distance = flat.Magnitude
	if distance > Config.WORLD_RADIUS then
		velocity -= flat.Unit * (distance - Config.WORLD_RADIUS + 10)
	end
	ship.LinearVelocity.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)

	local calm = 1 / (1 + stats.Stability * 0.5)
	local swell = 1 + storm * 4 * calm
	local bob = math.sin(t * 1.1 + ship.Phase) * 0.35 * swell
	ship.AlignPosition.Position = Vector3.new(0, Config.SEA_LEVEL + stats.FloatOffset + bob, 0)

	local roll = math.sin(t * 0.9 + ship.Phase) * math.rad(2) * swell + steer * speedFraction * math.rad(4)
	local pitch = math.sin(t * 0.7 + ship.Phase * 1.3) * math.rad(1.2) * swell + (ship.Speed / Config.MAX_SPEED) * math.rad(2)
	ship.AlignOrientation.CFrame = CFrame.Angles(0, ship.Yaw, 0) * CFrame.Angles(pitch, 0, roll)

	ship.Foam.Rate = if math.abs(ship.Speed) > 2 then math.abs(ship.Speed) * 1.2 else 0
end

local function slowUpdate()
	for _, ship in ships do
		if ship.Root and ship.Root.Parent and not ship.IsNPC then
			-- Docking
			local docked = if ship.Building then "PortHaven" else Islands.FindDocked(ship.Root.Position)
			if docked ~= ship.DockedAt then
				ship.DockedAt = docked
				if docked and not ship.Building then
					S.StateService.Notify(ship.Captain, `⚓ Moored at {Islands.Get(docked).Name}`, "info")
					S.QuestService.Fire(ship.Captain, "Dock", docked)
				end
				pushCrew(ship)
			end
			-- Free repairs in the safe harbour
			if not ship.Building and not ship.Sinking and Islands.IsSafe(ship.Root.Position) and ship.HP < ship.Stats.MaxHP then
				ShipService.Repair(ship, Config.HARBOUR_REPAIR_RATE * 0.5)
			end
			-- Anyone who falls into the drydock basin climbs back out
			if ship.Building and ship.Dock then
				for _, member in S.CrewService.Members(ship.Captain) do
					local r = rootPart(member)
					if r and r.Position.Y < -5 and flatDistance(r.Position, ship.Dock.Origin) < Config.DRYDOCK_SPACING / 2 then
						teleport(member, ship.Dock.Walkway)
					end
				end
			end
		end
	end
end

function ShipService.Start()
	shipsFolder = Instance.new("Folder")
	shipsFolder.Name = "Ships"
	shipsFolder.Parent = Workspace
	computeHarbourSpots()

	Remotes.Function("ToggleBuild").OnServerInvoke = ShipService.ToggleBuild
	Remotes.Function("PlaceBlock").OnServerInvoke = ShipService.PlaceBlock
	Remotes.Function("RemoveBlock").OnServerInvoke = ShipService.RemoveBlock
	Remotes.Function("BoardShip").OnServerInvoke = ShipService.Board
	Remotes.Function("ResetShip").OnServerInvoke = ShipService.Reset
	Remotes.Function("RepairShip").OnServerInvoke = ShipService.UseRepairKit

	Remotes.Event("HelmInput").OnServerEvent:Connect(function(player, throttle, steer)
		local ship = playerShips[player]
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
			slowUpdate()
		end
	end)
end

return ShipService
