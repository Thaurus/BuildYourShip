-- Gold and item bookkeeping. Every change schedules a state push to the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)

local InventoryService = {}
local DataService, StateService

function InventoryService.Init(services)
	DataService = services.DataService
	StateService = services.StateService
end

function InventoryService.Count(player: Player, id: string): number
	local profile = DataService.Get(player)
	return profile and profile.Inventory[id] or 0
end

function InventoryService.Add(player: Player, id: string, amount: number)
	local profile = DataService.Get(player)
	if not profile or not Items.Get(id) or amount <= 0 then
		return
	end
	profile.Inventory[id] = (profile.Inventory[id] or 0) + amount
	StateService.Push(player)
end

function InventoryService.Remove(player: Player, id: string, amount: number): boolean
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return false
	end
	local have = profile.Inventory[id] or 0
	if have < amount then
		return false
	end
	profile.Inventory[id] = if have - amount > 0 then have - amount else nil
	StateService.Push(player)
	return true
end

function InventoryService.HasRecipe(player: Player, recipe: { [string]: number }, times: number): boolean
	for id, n in recipe do
		if InventoryService.Count(player, id) < n * times then
			return false
		end
	end
	return true
end

function InventoryService.ConsumeRecipe(player: Player, recipe: { [string]: number }, times: number): boolean
	if not InventoryService.HasRecipe(player, recipe, times) then
		return false
	end
	for id, n in recipe do
		InventoryService.Remove(player, id, n * times)
	end
	return true
end

function InventoryService.Gold(player: Player): number
	local profile = DataService.Get(player)
	return profile and profile.Gold or 0
end

function InventoryService.AddGold(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Gold = math.max(0, math.floor(profile.Gold + amount))
	if amount > 0 then
		profile.Stats.GoldEarned = (profile.Stats.GoldEarned or 0) + amount
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold")
	if gold then
		gold.Value = profile.Gold
	end
	StateService.Push(player)
end

function InventoryService.SpendGold(player: Player, amount: number): boolean
	if InventoryService.Gold(player) < amount then
		return false
	end
	InventoryService.AddGold(player, -amount)
	return true
end

function InventoryService.SetupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = InventoryService.Gold(player)
	gold.Parent = leaderstats
	leaderstats.Parent = player
end

return InventoryService
