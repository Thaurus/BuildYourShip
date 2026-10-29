-- NPC pirate ships. They patrol the open sea, hunt nearby player ships,
-- turn to bring their broadside to bear and fire. Sinking one pays a bounty
-- to everyone who damaged it and spills its loot crates into the water.
-- Pirates never enter safe waters around islands and never sail in the
-- Sheltered Bay; the Far Reaches have armoured ironclads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Goods = require(Shared.Goods)
local Islands = require(Shared.Islands)
local Zones = require(Shared.Zones)

local PirateService = {}
local S

local pirates = {}
local pendingRespawns = 0
local rng = Random.new()

local NAMES = { "☠️ The Salty Jackal", "☠️ Black Gull", "☠️ The Rusty Hook", "☠️ Widow's Wake", "☠️ Barnacle Bess" }

function PirateService.Init(services)
	S = services
end

local function sloop()
	local bp = {}
	local function add(t, x, y, z, r)
		table.insert(bp, { t = t, x = x, y = y, z = z, r = r or 0 })
	end
	for x = -1, 1 do
		add("Bow", x, 0, -3)
		for z = -2, 2 do
			add("WoodHull", x, 0, z)
		end
	end
	add("WoodHull", -1, 0, 3)
	add("WoodHull", 1, 0, 3)
	add("Stern", 0, 0, 3)
	add("Rudder", 0, 0, 4)
	add("Keel", 0, -1, -1)
	add("Keel", 0, -1, 0)
	add("Keel", 0, -1, 1)
	add("Helm", 0, 1, 3)
	add("LargeSail", 0, 1, 0)
	add("SmallSail", 0, 1, -2)
	add("Cannon", -1, 1, -1, 1)
	add("Cannon", 1, 1, -1, 3)
	add("Cannon", -1, 1, 1, 1)
	add("Cannon", 1, 1, 1, 3)
	add("CargoHold", -1, 1, 2)
	add("CargoHold", 1, 1, 2)
	add("Flag", 0, 1, -3)
	return bp
end

-- Armoured steam pirate for the Far Reaches
local function ironclad()
	local bp = {}
	local function add(t, x, y, z, r)
		table.insert(bp, { t = t, x = x, y = y, z = z, r = r or 0 })
	end
	for x = -1, 1 do
		add(if x == 0 then "Ram" else "Bow", x, 0, -4)
		for z = -3, 3 do
			add("IronHull", x, 0, z)
		end
	end
	add("IronHull", -1, 0, 4)
	add("IronHull", 1, 0, 4)
	add("Stern", 0, 0, 4)
	add("Rudder", 0, 0, 5)
	for z = -2, 2 do
		add("Keel", 0, -1, z)
	end
	add("Helm", 0, 1, 4)
	add("SteamEngine", 0, 1, 2)
	add("LargeSail", 0, 1, -1)
	for _, z in { -3, -1, 1 } do
		add("Cannon", -1, 1, z, 1)
		add("Cannon", 1, 1, z, 3)
	end
	add("CargoHold", -1, 1, 3)
	add("CargoHold", 1, 1, 3)
	add("Flag", 0, 1, -4)
	return bp
end

local function lootHolds(keys)
	local holds = {}
	for _, key in keys do
		local list = {}
		for _ = 1, rng:NextInteger(1, 2) do
			table.insert(list, Goods.Order[rng:NextInteger(3, #Goods.Order)])
		end
		holds[key] = list
	end
	return holds
end

local function isClearOfLand(pos: Vector3, margin: number): boolean
	for _, id in Islands.Order do
		local def = Islands.Get(id)
		if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(def.Position.X, 0, def.Position.Z)).Magnitude < def.Radius + margin then
			return false
		end
	end
	return not Islands.IsSafe(pos)
end

local function randomSeaPoint(minFromPlayers: number, zone: number): Vector3?
	local inner = Zones.Get(zone - 1).Outer + 120
	local outer = math.min(Zones.Get(zone).Outer, Config.WORLD_RADIUS) - 120
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(inner, outer)
		local pos = Vector3.new(math.cos(a) * r, Config.SEA_LEVEL, math.sin(a) * r)
		local ok = isClearOfLand(pos, 220)
		if ok and minFromPlayers > 0 then
			for _, ship in S.ShipService.All() do
				if not ship.IsNPC and ship.Root and (ship.Root.Position - pos).Magnitude < minFromPlayers then
					ok = false
					break
				end
			end
		end
		if ok then
			return pos
		end
	end
	return nil
end

local function spawnPirate()
	local zone = if rng:NextNumber() < 0.65 then 2 else 3
	local pos = randomSeaPoint(450, zone)
	if not pos then
		return
	end
	local cf = CFrame.lookAt(pos, pos + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
	local armoured = zone == 3
	local ship = S.ShipService.SpawnNPC(if armoured then ironclad() else sloop(), cf, {
		Name = (if armoured then "⚙️ " else "") .. NAMES[rng:NextInteger(1, #NAMES)],
		Style = "Pirate",
		Holds = lootHolds(if armoured then { "-1,1,3", "1,1,3" } else { "-1,1,2", "1,1,2" }),
	})
	ship.PirateZone = zone
	ship.Patrol = randomSeaPoint(0, zone) or pos
	pirates[ship] = true
end

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Steer value (-1..1, positive = right) that turns the ship towards a direction
local function steerTowards(ship, direction: Vector3): number
	local desired = math.atan2(-direction.X, -direction.Z)
	local diff = wrapAngle(desired - ship.Yaw)
	return -math.clamp(diff * 2, -1, 1)
end

local function findTarget(ship)
	local best, bestDistance = nil, Config.PIRATE_AGGRO_RANGE
	for _, other in S.ShipService.All() do
		if not other.IsNPC and other.Root and other.Root.Parent and not other.Sinking and not other.Building and not Islands.IsSafe(other.Root.Position) then
			local d = (other.Root.Position - ship.Root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = other, d
			end
		end
	end
	return best, bestDistance
end

local function think(ship)
	if not ship.Root or not ship.Root.Parent or ship.Sinking then
		ship.AI.Throttle, ship.AI.Steer = 0, 0
		return
	end
	local pos = ship.Root.Position
	local forward = Vector3.new(-math.sin(ship.Yaw), 0, -math.cos(ship.Yaw))
	local target, distance = findTarget(ship)
	local desired: Vector3

	if target then
		local toTarget = Vector3.new(target.Root.Position.X - pos.X, 0, target.Root.Position.Z - pos.Z)
		if distance > 150 then
			desired = toTarget.Unit
			ship.AI.Throttle = 1
		else
			-- Run alongside the target so the cannons on one side can bear
			local side = if forward:Cross(toTarget).Y > 0 then 1 else -1
			desired = (toTarget.Unit:Cross(Vector3.new(0, side, 0))).Unit
			if distance < 70 then
				desired = (desired - toTarget.Unit * 0.6).Unit
			end
			ship.AI.Throttle = 0.6
		end

		local elevation = S.CombatService.ElevationFor(distance)
		for _, cannon in ship.Cannons do
			local barrel = cannon.Barrel.CFrame.RightVector
			local aim = Vector3.new(barrel.X, 0, barrel.Z)
			if aim.Magnitude > 0 and aim.Unit:Dot(toTarget.Unit) > 0.93 and distance < 280 then
				S.CombatService.FireNPC(ship, cannon, elevation + rng:NextNumber(-0.02, 0.02))
			end
		end
	else
		local toPatrol = Vector3.new(ship.Patrol.X - pos.X, 0, ship.Patrol.Z - pos.Z)
		if toPatrol.Magnitude < 60 then
			ship.Patrol = randomSeaPoint(0, ship.PirateZone) or ship.Patrol
		end
		desired = toPatrol.Unit
		ship.AI.Throttle = 0.5
	end

	-- Keep clear of islands and the safe harbour
	local ahead = pos + forward * 120
	if not isClearOfLand(ahead, 60) then
		local home = Islands.Get("PortHaven").Position
		local away = Vector3.new(pos.X - home.X, 0, pos.Z - home.Z)
		for _, id in Islands.Order do
			local def = Islands.Get(id)
			local offset = Vector3.new(pos.X - def.Position.X, 0, pos.Z - def.Position.Z)
			if offset.Magnitude < def.Radius + 260 then
				away = offset
			end
		end
		desired = away.Unit
	end

	ship.AI.Steer = steerTowards(ship, desired)
end

local function onSunk(ship)
	if not pirates[ship] then
		return
	end
	pirates[ship] = nil
	local total = 0
	for _, amount in ship.DamageBy do
		total += amount
	end
	for player, amount in ship.DamageBy do
		if player.Parent == Players then
			local bounty = Config.PIRATE_REWARD * (if ship.PirateZone == 3 then 3 else 1)
			local share = math.max(10, math.floor(bounty * amount / math.max(total, 1)))
			S.InventoryService.AddGold(player, share)
			S.StateService.Notify(player, `☠️ Pirates sunk! Bounty: {share}g. Grab the floating loot!`, "good")
			S.QuestService.Fire(player, "SinkPirate")
		end
	end
	pendingRespawns += 1
	task.delay(Config.PIRATE_RESPAWN, function()
		pendingRespawns -= 1
		spawnPirate()
	end)
end

function PirateService.Start()
	table.insert(S.ShipService.SunkHandlers, onSunk)
	task.spawn(function()
		for _ = 1, Config.PIRATE_COUNT do
			spawnPirate()
			task.wait(1)
		end
		while true do
			task.wait(0.25)
			for ship in pirates do
				think(ship)
			end
		end
	end)
	-- Safety net: top the fleet up if a pirate got lost somehow
	task.spawn(function()
		while true do
			task.wait(60)
			local count = 0
			for ship in pirates do
				if S.ShipService.GetById(ship.Id) then
					count += 1
				else
					pirates[ship] = nil
				end
			end
			if count + pendingRespawns < Config.PIRATE_COUNT then
				spawnPirate()
			end
		end
	end)
end

return PirateService
