-- Server entry point: builds the world, then wires up every service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes) -- creates the remotes before clients look for them

local Services = script.Parent:WaitForChild("Services")
local services = {
	WorldBuilder = require(Services.WorldBuilder),
	DataService = require(Services.DataService),
	StateService = require(Services.StateService),
	InventoryService = require(Services.InventoryService),
	GamepassService = require(Services.GamepassService),
	QuestService = require(Services.QuestService),
	CrewService = require(Services.CrewService),
	HarvestService = require(Services.HarvestService),
	CraftingService = require(Services.CraftingService),
	CargoService = require(Services.CargoService),
	MarketService = require(Services.MarketService),
	ShipService = require(Services.ShipService),
	CombatService = require(Services.CombatService),
	StormService = require(Services.StormService),
	PirateService = require(Services.PirateService),
}

for _, service in services do
	if service.Init then
		service.Init(services)
	end
end

services.WorldBuilder.Build()

-- Start order matters a little: ships need the world, pirates need ships
local START_ORDER = {
	"DataService",
	"GamepassService",
	"CrewService",
	"HarvestService",
	"CraftingService",
	"CargoService",
	"MarketService",
	"ShipService",
	"CombatService",
	"StormService",
	"PirateService",
}
for _, name in START_ORDER do
	services[name].Start()
end

local function onPlayerAdded(player: Player)
	local profile = services.DataService.Load(player)
	services.GamepassService.Load(player)
	if not player.Parent then
		services.DataService.Profiles[player] = nil
		return
	end
	services.InventoryService.SetupLeaderstats(player)

	-- Characters only load once the world exists (CharacterAutoLoads is off)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			task.wait(4)
			if player.Parent then
				player:LoadCharacterAsync()
			end
		end)
	end)
	player:LoadCharacterAsync()

	services.ShipService.SpawnPlayerShip(player)
	services.StateService.Push(player)
	if not profile.SeenTutorial then
		services.StateService.Notify(player, "Welcome to Port Haven, captain!", "good")
	end
end

Remotes.Event("TutorialDone").OnServerEvent:Connect(function(player)
	local profile = services.DataService.Get(player)
	if profile then
		profile.SeenTutorial = true
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	services.ShipService.DespawnPlayer(player)
	services.DataService.Release(player)
end)
