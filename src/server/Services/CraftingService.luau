-- Crafting (anywhere) and the Shipwright shop (at Port Haven).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local CraftingService = {}
local InventoryService, StateService

local MAX_BATCH = 50

function CraftingService.Init(services)
	InventoryService = services.InventoryService
	StateService = services.StateService
end

local function validAmount(amount: any): number?
	if type(amount) ~= "number" or amount ~= amount then
		return nil
	end
	amount = math.floor(amount)
	if amount < 1 or amount > MAX_BATCH then
		return nil
	end
	return amount
end

local function nearShipwright(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, npc in CollectionService:GetTagged("Shipwright") do
		if npc:IsA("Model") and (npc:GetPivot().Position - root.Position).Magnitude <= Config.SHOP_RANGE then
			return true
		end
	end
	return false
end

function CraftingService.Craft(player: Player, id: any, amount: any)
	local def = type(id) == "string" and Items.Get(id)
	amount = validAmount(amount)
	if not def or not def.Recipe or def.Hidden or not amount then
		return { ok = false, msg = "You can't craft that." }
	end
	if not InventoryService.ConsumeRecipe(player, def.Recipe, amount) then
		return { ok = false, msg = "Not enough materials!" }
	end
	InventoryService.Add(player, id, amount)
	return { ok = true, msg = `Crafted {amount}x {def.Icon} {def.Name}!` }
end

function CraftingService.Buy(player: Player, id: any, amount: any)
	local def = type(id) == "string" and Items.Get(id)
	amount = validAmount(amount)
	if not def or def.Hidden or not amount then
		return { ok = false, msg = "Not for sale." }
	end
	if not nearShipwright(player) then
		return { ok = false, msg = "Visit the Shipwright in Port Haven to shop." }
	end
	local cost = def.Price * amount
	if not InventoryService.SpendGold(player, cost) then
		return { ok = false, msg = `You need {cost} gold.` }
	end
	InventoryService.Add(player, id, amount)
	return { ok = true, msg = `Bought {amount}x {def.Icon} {def.Name} for {cost}g` }
end

function CraftingService.Start()
	Remotes.Function("Craft").OnServerInvoke = CraftingService.Craft
	Remotes.Function("Buy").OnServerInvoke = CraftingService.Buy

	local openShop = Remotes.Event("OpenShop")
	local function hook(npc: Instance)
		local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				openShop:FireClient(player)
			end)
		end
	end
	for _, npc in CollectionService:GetTagged("Shipwright") do
		hook(npc)
	end
	CollectionService:GetInstanceAddedSignal("Shipwright"):Connect(hook)
end

return CraftingService
