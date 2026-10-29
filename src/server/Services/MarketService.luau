-- Island markets. Each island sells what it produces cheaply and pays well for
-- what it wants. Goods are physical crates: buying puts a crate on the trader's
-- loading pad; selling means carrying a crate up to the trader.
-- Prices react to trading (buying pushes them up, selling pushes them down)
-- and slowly recover, so the best routes shift over time.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Goods = require(Shared.Goods)
local Islands = require(Shared.Islands)
local Remotes = require(Shared.Remotes)

local MarketService = {}
local S

local PRESSURE_PER_CRATE = 0.05
local MAX_PRESSURE = 0.5
local RECOVERY = 0.97 -- per tick
local RECOVERY_TICK = 5

-- pressure[islandId][goodId] = { buy = n, sell = n }
local pressure = {}

function MarketService.Init(services)
	S = services
	for _, id in Islands.Order do
		pressure[id] = {}
		for _, goodId in Goods.Order do
			pressure[id][goodId] = { buy = 0, sell = 0 }
		end
	end
end

-- Price to buy one crate here (nil if this island doesn't sell it)
local function buyPrice(islandId: string, goodId: string): number?
	local factor = Islands.Get(islandId).Market.Sells[goodId]
	if not factor then
		return nil
	end
	local p = pressure[islandId][goodId].buy
	return math.max(1, math.floor(Goods.Get(goodId).Price * factor * (1 + p) + 0.5))
end

-- Price received for selling one crate here
local function sellPrice(islandId: string, goodId: string): number
	local factor = Islands.Get(islandId).Market.Buys[goodId] or Goods.NEUTRAL_SELL_FACTOR
	local p = pressure[islandId][goodId].sell
	return math.max(1, math.floor(Goods.Get(goodId).Price * factor * (1 - p) + 0.5))
end

local function traderPosition(islandId: string): Vector3?
	for _, npc in CollectionService:GetTagged("Trader") do
		if npc:GetAttribute("IslandId") == islandId and npc:IsA("Model") then
			return npc:GetPivot().Position
		end
	end
	return nil
end

local function nearTrader(player: Player, islandId: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local pos = traderPosition(islandId)
	return root ~= nil and pos ~= nil and (root.Position - pos).Magnitude <= Config.TRADER_RANGE
end

function MarketService.Snapshot(player: Player, islandId: any)
	local island = type(islandId) == "string" and Islands.Get(islandId)
	local profile = S.DataService.Get(player)
	if not island or not profile then
		return nil
	end
	local goods = {}
	for _, goodId in Goods.Order do
		local good = Goods.Get(goodId)
		table.insert(goods, {
			Id = goodId,
			Name = good.Name,
			Icon = good.Icon,
			BuyPrice = buyPrice(islandId, goodId),
			SellPrice = sellPrice(islandId, goodId),
			Wanted = island.Market.Buys[goodId] ~= nil,
			Local = island.Market.Sells[goodId] ~= nil,
		})
	end
	local carried = S.CargoService.GetCarried(player)
	return {
		IslandId = islandId,
		IslandName = island.Name,
		Trader = island.Trader.Name,
		Gold = profile.Gold,
		Carrying = carried and carried.Good,
		Goods = goods,
	}
end

function MarketService.BuyCrate(player: Player, islandId: any, goodId: any)
	local island = type(islandId) == "string" and Islands.Get(islandId)
	local good = type(goodId) == "string" and Goods.Get(goodId)
	if not island or not good then
		return { ok = false, msg = "Invalid trade." }
	end
	if not nearTrader(player, islandId) then
		return { ok = false, msg = "Walk over to the trader first." }
	end
	local price = buyPrice(islandId, goodId)
	if not price then
		return { ok = false, msg = `{island.Name} doesn't sell {good.Name}.` }
	end
	if S.InventoryService.Gold(player) < price then
		return { ok = false, msg = `You need {price} gold.` }
	end
	local ok, reason = S.CargoService.SpawnOnPad(player, islandId, goodId)
	if not ok then
		return { ok = false, msg = reason }
	end
	S.InventoryService.SpendGold(player, price)
	local p = pressure[islandId][goodId]
	p.buy = math.min(MAX_PRESSURE, p.buy + PRESSURE_PER_CRATE)
	S.QuestService.Fire(player, "BuyCrate", goodId)
	return { ok = true, msg = `Bought a {good.Icon} {good.Name} crate for {price}g. Pick it up from the pad!` }
end

-- Sell the crate the player is carrying. Crew crates pay every crew member.
function MarketService.SellCarried(player: Player, islandId: string)
	local carried = S.CargoService.GetCarried(player)
	if not carried then
		return
	end
	if not nearTrader(player, islandId) then
		return
	end
	local record = S.CargoService.TakeCarried(player)
	local good = Goods.Get(record.Good)
	local price = sellPrice(islandId, record.Good)
	local p = pressure[islandId][record.Good]
	p.sell = math.min(MAX_PRESSURE, p.sell + PRESSURE_PER_CRATE)

	local captain = S.CrewService.CaptainOf(player)
	local recipients = { player }
	if record.OwnerId == captain.UserId then
		recipients = S.CrewService.Members(captain)
	end
	local share = math.floor(price / #recipients)
	local remainder = price - share * #recipients
	for _, member in recipients do
		local amount = share + (if member == player then remainder else 0)
		if S.GamepassService.Has(member, "MerchantGuild") then
			amount = math.floor(amount * 1.25)
		end
		if member.Parent == Players and amount > 0 then
			S.InventoryService.AddGold(member, amount)
			S.QuestService.Fire(member, "TradeGold", nil, amount)
			local profile = S.DataService.Get(member)
			if profile then
				profile.Stats.Trades = (profile.Stats.Trades or 0) + 1
			end
			local text = if member == player then `Sold {good.Icon} {good.Name} for {amount}g!` else `{player.DisplayName} sold {good.Icon} {good.Name}: your share {amount}g`
			S.StateService.Notify(member, text, "gain")
		end
	end
	S.QuestService.Fire(player, "SellCrate", record.Good)
end

function MarketService.Start()
	Remotes.Function("GetMarket").OnServerInvoke = MarketService.Snapshot
	Remotes.Function("BuyCrate").OnServerInvoke = MarketService.BuyCrate

	local openMarket = Remotes.Event("OpenMarket")
	local function hook(npc: Instance)
		local islandId = npc:GetAttribute("IslandId")
		local trade = npc:FindFirstChild("TradePrompt", true) :: ProximityPrompt?
		local sell = npc:FindFirstChild("SellPrompt", true) :: ProximityPrompt?
		if trade and islandId then
			trade.Triggered:Connect(function(player)
				openMarket:FireClient(player, islandId)
			end)
		end
		if sell and islandId then
			sell.Triggered:Connect(function(player)
				MarketService.SellCarried(player, islandId)
			end)
		end
	end
	for _, npc in CollectionService:GetTagged("Trader") do
		hook(npc)
	end
	CollectionService:GetInstanceAddedSignal("Trader"):Connect(hook)

	task.spawn(function()
		while true do
			task.wait(RECOVERY_TICK)
			for _, goods in pressure do
				for _, p in goods do
					p.buy *= RECOVERY
					p.sell *= RECOVERY
				end
			end
		end
	end)
end

return MarketService
