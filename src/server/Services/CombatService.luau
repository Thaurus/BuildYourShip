-- Cannons and cannonballs.
--   * Each Cannon block has a "Fire" prompt any crew member can use.
--   * The captain (or crew) presses F to fire a broadside: every cannon on the
--     side the camera looks at fires, with elevation taken from the camera pitch.
--   * Cannonballs are simulated on the server (gravity + raycasts) and damage
--     ships and sailors. Nothing can be damaged inside Port Haven's harbour.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Islands = require(Shared.Islands)
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)

local CombatService = {}
local S

local projectiles = {}
local projectileFolder: Folder
local effectEvent = Remotes.Event("Effect")

local DEFAULT_ELEVATION = 0.1
local MAX_LIFETIME = 5

function CombatService.Init(services)
	S = services
end

-- Broadcast a visual effect to every client
function CombatService.Effect(kind: string, position: Vector3, scale: number?, direction: Vector3?)
	effectEvent:FireAllClients(kind, position, scale or 1, direction)
end

function CombatService.SetupCannon(ship, key: string, block: Model)
	local barrel = block:FindFirstChild("Barrel") :: BasePart?
	if not barrel then
		return
	end
	ship.Cannons[key] = {
		Key = key,
		Block = block,
		Barrel = barrel,
		Muzzle = barrel:FindFirstChild("MuzzlePoint") :: Attachment,
		LastFire = 0,
	}
	if not ship.IsNPC then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Fire"
		prompt.ObjectText = "Cannon"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt:SetAttribute("Need", "Empty")
		CollectionService:AddTag(prompt, "FilteredPrompt")
		prompt.Parent = block:FindFirstChild("Main")
		prompt.Triggered:Connect(function(player)
			local result = CombatService.FireCannon(player, ship, key, DEFAULT_ELEVATION)
			if result and not result.ok and result.msg then
				S.StateService.Notify(player, result.msg, "bad")
			end
		end)
	end
end

-- Direction the barrel points, flattened to the horizon
local function barrelDirection(cannon): Vector3
	local forward = cannon.Barrel.CFrame.RightVector -- barrel cylinders are built along their local X
	local flat = Vector3.new(forward.X, 0, forward.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

local function launch(ship, cannon, shooter: Player?, elevation: number)
	cannon.LastFire = os.clock()
	local origin = cannon.Muzzle.WorldPosition
	local dir = barrelDirection(cannon)
	local velocity = (dir + Vector3.new(0, elevation, 0)).Unit * Config.CANNON_SPEED + ship.Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)

	local ball = Instance.new("Part")
	ball.Name = "Cannonball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.9, 0.9, 0.9)
	ball.Material = Enum.Material.Metal
	ball.Color = Palette.Ink
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CFrame = CFrame.new(origin)
	ball.Parent = projectileFolder

	table.insert(projectiles, {
		Part = ball,
		Position = origin,
		Velocity = velocity,
		Ship = ship,
		Shooter = shooter,
		Born = os.clock(),
	})
	CombatService.Effect("Muzzle", origin, 1, dir)
end

local function ammoCheck(player: Player): boolean
	return S.InventoryService.Count(player, "Cannonball") > 0
end

function CombatService.FireCannon(player: Player, ship, key: string, elevation: number?)
	local cannon = ship.Cannons[key]
	if not cannon or not ship.Root or ship.Building or ship.Sinking then
		return { ok = false }
	end
	if not S.ShipService.CanAccess(player, ship) then
		return { ok = false, msg = "That's not your crew's cannon." }
	end
	if Islands.IsSafe(ship.Root.Position) then
		return { ok = false, msg = "No firing inside the harbour!" }
	end
	if os.clock() - cannon.LastFire < Config.CANNON_COOLDOWN then
		return { ok = false, msg = "Reloading..." }
	end
	if not S.InventoryService.Remove(player, "Cannonball", 1) then
		return { ok = false, msg = "No cannonballs! Craft some from Iron Ingots." }
	end
	launch(ship, cannon, player, elevation or DEFAULT_ELEVATION)
	return { ok = true }
end

function CombatService.Broadside(player: Player, aim: any)
	if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.1 then
		return { ok = false }
	end
	aim = aim.Unit
	local ship = S.ShipService.ShipFor(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not ship or not ship.Root or not root or ship.Building or ship.Sinking then
		return { ok = false, msg = "Get aboard your ship first." }
	end
	if (root.Position - ship.Root.Position).Magnitude > 50 then
		return { ok = false, msg = "Get aboard your ship first." }
	end
	if Islands.IsSafe(ship.Root.Position) then
		return { ok = false, msg = "No firing inside the harbour!" }
	end
	if next(ship.Cannons) == nil then
		return { ok = false, msg = "Your ship has no cannons. Build some in the drydock!" }
	end

	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	flatAim = if flatAim.Magnitude > 0.01 then flatAim.Unit else Vector3.new(0, 0, -1)
	local elevation = math.clamp(aim.Y + 0.06, 0.02, 0.4)

	local ready = {}
	for _, cannon in ship.Cannons do
		if barrelDirection(cannon):Dot(flatAim) > 0.5 and os.clock() - cannon.LastFire >= Config.CANNON_COOLDOWN then
			table.insert(ready, cannon)
		end
	end
	if #ready == 0 then
		return { ok = false, msg = "No loaded cannons face that way. Look to the side you want to fire at." }
	end
	if not ammoCheck(player) then
		return { ok = false, msg = "No cannonballs! Craft some from Iron Ingots." }
	end
	local fired = 0
	for i, cannon in ready do
		if not S.InventoryService.Remove(player, "Cannonball", 1) then
			break
		end
		cannon.LastFire = os.clock()
		fired += 1
		task.delay((i - 1) * 0.18, function()
			if ship.Root and ship.Root.Parent and not ship.Sinking then
				launch(ship, cannon, player, elevation + (math.random() - 0.5) * 0.02)
			end
		end)
	end
	return { ok = true, msg = `💥 Broadside! {fired} cannon{if fired == 1 then "" else "s"}` }
end

-- Used by pirates (no ammo needed)
function CombatService.FireNPC(ship, cannon, elevation: number)
	if os.clock() - cannon.LastFire < Config.CANNON_COOLDOWN or not ship.Root then
		return false
	end
	launch(ship, cannon, nil, elevation)
	return true
end

-- Elevation that lands a cannonball at the given horizontal distance
function CombatService.ElevationFor(distance: number): number
	local ratio = math.clamp(Config.CANNON_GRAVITY * distance / (Config.CANNON_SPEED ^ 2), 0, 1)
	return math.tan(0.5 * math.asin(ratio))
end

local function hitCharacter(ball, instance: Instance)
	local model = instance:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim and ball.Shooter and S.CrewService.IsCrew(victim, S.CrewService.CaptainOf(ball.Shooter)) then
		return true
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and Islands.IsSafe(root.Position) then
		return true
	end
	humanoid:TakeDamage(Config.CANNON_PLAYER_DAMAGE)
	return true
end

local function step(dt: number)
	local now = os.clock()
	for i = #projectiles, 1, -1 do
		local ball = projectiles[i]
		local nextVelocity = ball.Velocity - Vector3.new(0, Config.CANNON_GRAVITY * dt, 0)
		local nextPosition = ball.Position + ball.Velocity * dt
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclude = { projectileFolder }
		if ball.Ship.Model then
			table.insert(exclude, ball.Ship.Model)
		end
		params.FilterDescendantsInstances = exclude
		params.IgnoreWater = true
		local result = Workspace:Raycast(ball.Position, nextPosition - ball.Position, params)

		local finished = false
		if result then
			finished = true
			local target = S.ShipService.FromInstance(result.Instance)
			if target then
				S.ShipService.Damage(target, Config.CANNON_DAMAGE, ball.Shooter, ball.Ship)
				CombatService.Effect("Explosion", result.Position, 1)
			elseif hitCharacter(ball, result.Instance) then
				CombatService.Effect("Explosion", result.Position, 0.6)
			else
				CombatService.Effect(if result.Position.Y <= Config.SEA_LEVEL + 0.5 then "Splash" else "Impact", result.Position, 1)
			end
		elseif nextPosition.Y < Config.SEA_LEVEL then
			finished = true
			CombatService.Effect("Splash", Vector3.new(nextPosition.X, Config.SEA_LEVEL, nextPosition.Z), 1)
		elseif now - ball.Born > MAX_LIFETIME then
			finished = true
		end

		if finished then
			ball.Part:Destroy()
			table.remove(projectiles, i)
		else
			ball.Position = nextPosition
			ball.Velocity = nextVelocity
			ball.Part.CFrame = CFrame.new(nextPosition)
		end
	end
end

function CombatService.Start()
	projectileFolder = Instance.new("Folder")
	projectileFolder.Name = "Projectiles"
	projectileFolder.Parent = Workspace

	Remotes.Function("FireBroadside").OnServerInvoke = CombatService.Broadside
	RunService.Heartbeat:Connect(step)
end

return CombatService
