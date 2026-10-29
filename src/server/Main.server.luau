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
	HarvestService = require(Services.HarvestService),
	CraftingService = require(Services.CraftingService),
	MarketService = require(Services.MarketService),
	ShipService = require(Services.ShipService),
}

for _, service in services do
	if service.Init then
		service.Init(services)
	end
end

services.WorldBuilder.Build()

for _, service in services do
	if service.Start then
		service.Start()
	end
end

local function onPlayerAdded(player: Player)
	local profile = services.DataService.Load(player)
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
				player:LoadCharacter()
			end
		end)
	end)
	player:LoadCharacter()

	services.ShipService.Spawn(player)
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
	services.ShipService.Despawn(player)
	services.DataService.Release(player)
end)
