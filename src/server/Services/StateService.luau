-- Sends each player a compact snapshot of everything the UI needs.
-- Pushes are coalesced: many changes in one frame produce one network send.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local StateService = {}
local DataService, ShipService

local pending: { [Player]: boolean } = {}
local stateEvent = Remotes.Event("StateUpdate")
local notifyEvent = Remotes.Event("Notify")

function StateService.Init(services)
	DataService = services.DataService
	ShipService = services.ShipService
end

local function cargoCount(cargo): number
	local n = 0
	for _, amount in cargo do
		n += amount
	end
	return n
end
StateService.CargoCount = cargoCount

function StateService.Send(player: Player)
	local profile = DataService.Get(player)
	if not profile or not player.Parent then
		return
	end
	local ship = ShipService.Get(player)
	stateEvent:FireClient(player, {
		Gold = profile.Gold,
		Inventory = profile.Inventory,
		Cargo = profile.Cargo,
		CargoCount = cargoCount(profile.Cargo),
		Blueprint = profile.Blueprint,
		Stats = ship and ship.Stats,
		Building = ship ~= nil and ship.Building,
		DockedAt = ship and ship.DockedAt,
		Berth = ship and ship.Berth,
		SeenTutorial = profile.SeenTutorial,
		Lifetime = profile.Stats,
	})
end

function StateService.Push(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		StateService.Send(player)
	end)
end

-- kind: "info" | "good" | "bad" | "gain"; position shows floating world text
function StateService.Notify(player: Player, text: string, kind: string?, position: Vector3?)
	notifyEvent:FireClient(player, { Text = text, Kind = kind or "info", Position = position })
end

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
end)

return StateService
