-- Sends each player a compact snapshot of everything the UI needs.
-- Pushes are coalesced: many changes in one frame produce one network send.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ShipGrid = require(Shared.ShipGrid)

local StateService = {}
local S

local pending: { [Player]: boolean } = {}
local stateEvent = Remotes.Event("StateUpdate")
local notifyEvent = Remotes.Event("Notify")

function StateService.Init(services)
	S = services
end

local function holdSummary(ship)
	local counts = {}
	for _, list in ship.Holds do
		for _, goodId in list do
			counts[goodId] = (counts[goodId] or 0) + 1
		end
	end
	return counts
end

function StateService.Send(player: Player)
	local profile = S.DataService.Get(player)
	if not profile or not player.Parent then
		return
	end
	local own = S.ShipService.Get(player)
	local sailing = S.ShipService.ShipFor(player) -- captain's ship if crew
	local vesselOk, vesselRules = ShipGrid.VesselCheck(profile.Blueprint)
	local carried = S.CargoService.GetCarried(player)
	stateEvent:FireClient(player, {
		Gold = profile.Gold,
		Inventory = profile.Inventory,
		Blueprint = profile.Blueprint,
		Bounds = own and own.Bounds,
		Vessel = { Ok = vesselOk, Rules = vesselRules },
		Building = own ~= nil and own.Building,
		Ship = sailing and {
			Id = sailing.Id,
			Own = sailing == own,
			Stats = sailing.Stats,
			HP = sailing.HP,
			Crates = S.ShipService.CrateCount(sailing),
			Cargo = holdSummary(sailing),
			DockedAt = sailing.DockedAt,
			Sinking = sailing.Sinking,
			Building = sailing.Building,
		},
		Carrying = carried and carried.Good,
		Crew = S.CrewService.Summary(player),
		Quest = S.QuestService.Summary(player),
		Passes = S.GamepassService.Owned(player),
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
