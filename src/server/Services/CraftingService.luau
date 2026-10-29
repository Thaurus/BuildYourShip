-- Crafting (anywhere) and the Shipwright shop (at Port Haven).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Islands = require(Shared.Islands)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local CraftingService = {}
local InventoryService, QuestService, GamepassService, DataService

local MAX_BATCH = 50

function CraftingService.Init(services)
	InventoryService = services.InventoryService
	QuestService = services.QuestService
	GamepassService = services.GamepassService
	DataService = services.DataService
end

-- Parts from later eras must be discovered first
local function tierLock(player: Player, def): string?
	local profile = DataService.Get(player)
	if profile and def.Tier > profile.Tier then
		return `🔒 {def.Name} is {Items.TIER_NAMES[def.Tier]}-era tech. Discover {Islands.UnlockSource(def.Tier)} to unlock it.`
	end
	return nil
end

function CraftingService.PriceFor(player: Player, id: string): number
	local price = Items.Get(id).Price
	if GamepassService.Has(player, "ShipwrightFriend") then
		price = math.ceil(price * 0.75)
	end
	return price
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
	local locked = tierLock(player, def)
	if locked then
		return { ok = false, msg = locked }
	end
	if not InventoryService.ConsumeRecipe(player, def.Recipe, amount) then
		return { ok = false, msg = "Not enough materials!" }
	end
	local made = amount * def.Yield
	InventoryService.Add(player, id, made)
	QuestService.Fire(player, "Craft", id, made)
	return { ok = true, msg = `Crafted {made}x {def.Icon} {def.Name}!` }
end

function CraftingService.Buy(player: Player, id: any, amount: any)
	local def = type(id) == "string" and Items.Get(id)
	amount = validAmount(amount)
	if not def or def.Hidden or not amount then
		return { ok = false, msg = "Not for sale." }
	end
	if not nearShipwright(player) then
		return { ok = false, msg = "Visit a shipwright (every village and drydock has one) to shop." }
	end
	local locked = tierLock(player, def)
	if locked then
		return { ok = false, msg = locked }
	end
	local cost = CraftingService.PriceFor(player, id) * amount
	if not InventoryService.SpendGold(player, cost) then
		return { ok = false, msg = `You need {cost} gold.` }
	end
	InventoryService.Add(player, id, amount)
	QuestService.Fire(player, "Craft", id, amount) -- buying counts for "get one of these" steps
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
