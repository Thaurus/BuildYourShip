-- Island markets. Each island sells what it produces cheaply and pays well for
-- what it wants. Prices react to trading (buying pushes them up, selling pushes
-- them down) and slowly recover, so the best routes shift over time.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Goods = require(Shared.Goods)
local Islands = require(Shared.Islands)
local Remotes = require(Shared.Remotes)

local MarketService = {}
local DataService, InventoryService, ShipService, StateService

local PRESSURE_PER_UNIT = 0.012
local MAX_PRESSURE = 0.5
local RECOVERY = 0.97 -- per tick
local RECOVERY_TICK = 5

-- pressure[islandId][goodId] = { buy = n, sell = n }
local pressure = {}

function MarketService.Init(services)
	DataService = services.DataService
	InventoryService = services.InventoryService
	ShipService = services.ShipService
	StateService = services.StateService
	for _, id in Islands.Order do
		pressure[id] = {}
		for _, goodId in Goods.Order do
			pressure[id][goodId] = { buy = 0, sell = 0 }
		end
	end
end

-- Price the player pays to buy one unit here (nil if this island doesn't sell it)
local function buyPrice(islandId: string, goodId: string): number?
	local factor = Islands.Get(islandId).Market.Sells[goodId]
	if not factor then
		return nil
	end
	local p = pressure[islandId][goodId].buy
	return math.max(1, math.floor(Goods.Get(goodId).Price * factor * (1 + p) + 0.5))
end

-- Price the player receives for selling one unit here
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
	local profile = DataService.Get(player)
	if not island or not profile then
		return nil
	end
	local ship = ShipService.Get(player)
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
			Owned = profile.Cargo[goodId] or 0,
		})
	end
	return {
		IslandId = islandId,
		IslandName = island.Name,
		Trader = island.Trader.Name,
		Docked = ship ~= nil and ship.DockedAt == islandId and not ship.Building,
		Gold = profile.Gold,
		CargoCount = StateService.CargoCount(profile.Cargo),
		MaxCargo = ship and ship.Stats.MaxCargo or 0,
		Goods = goods,
	}
end

function MarketService.Trade(player: Player, islandId: any, goodId: any, action: any, amount: any)
	local island = type(islandId) == "string" and Islands.Get(islandId)
	local good = type(goodId) == "string" and Goods.Get(goodId)
	local profile = DataService.Get(player)
	if not island or not good or not profile or (action ~= "buy" and action ~= "sell") then
		return { ok = false, msg = "Invalid trade." }
	end
	if type(amount) ~= "number" or amount ~= amount then
		return { ok = false, msg = "Invalid amount." }
	end
	amount = math.clamp(math.floor(amount), 1, 100)

	if not nearTrader(player, islandId) then
		return { ok = false, msg = "Walk over to the trader first." }
	end
	local ship = ShipService.Get(player)
	if not ship or ship.DockedAt ~= islandId or ship.Building then
		return { ok = false, msg = `Dock your ship at {island.Name} to load cargo!` }
	end

	if action == "buy" then
		if not buyPrice(islandId, goodId) then
			return { ok = false, msg = `{island.Name} doesn't sell {good.Name}.` }
		end
		local room = ship.Stats.MaxCargo - StateService.CargoCount(profile.Cargo)
		amount = math.min(amount, room)
		if amount <= 0 then
			return { ok = false, msg = "Your cargo hold is full! Build more crates." }
		end
		-- Price each unit separately so big orders feel the price climb
		local total = 0
		for _ = 1, amount do
			total += buyPrice(islandId, goodId)
			local p = pressure[islandId][goodId]
			p.buy = math.min(MAX_PRESSURE, p.buy + PRESSURE_PER_UNIT)
		end
		if not InventoryService.SpendGold(player, total) then
			-- Roll back the price change
			local p = pressure[islandId][goodId]
			p.buy = math.max(0, p.buy - PRESSURE_PER_UNIT * amount)
			return { ok = false, msg = `You need {total} gold.` }
		end
		profile.Cargo[goodId] = (profile.Cargo[goodId] or 0) + amount
		ShipService.RefreshStats(player)
		return { ok = true, msg = `Loaded {amount}x {good.Icon} {good.Name} for {total}g` }
	else
		local have = profile.Cargo[goodId] or 0
		amount = math.min(amount, have)
		if amount <= 0 then
			return { ok = false, msg = `You have no {good.Name} aboard.` }
		end
		local total = 0
		for _ = 1, amount do
			total += sellPrice(islandId, goodId)
			local p = pressure[islandId][goodId]
			p.sell = math.min(MAX_PRESSURE, p.sell + PRESSURE_PER_UNIT)
		end
		profile.Cargo[goodId] = if have - amount > 0 then have - amount else nil
		profile.Stats.Trades = (profile.Stats.Trades or 0) + 1
		InventoryService.AddGold(player, total)
		ShipService.RefreshStats(player)
		return { ok = true, msg = `Sold {amount}x {good.Icon} {good.Name} for {total}g!` }
	end
end

function MarketService.Start()
	Remotes.Function("GetMarket").OnServerInvoke = MarketService.Snapshot
	Remotes.Function("Trade").OnServerInvoke = MarketService.Trade

	local openMarket = Remotes.Event("OpenMarket")
	local function hook(npc: Instance)
		local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
		local islandId = npc:GetAttribute("IslandId")
		if prompt and islandId then
			prompt.Triggered:Connect(function(player)
				openMarket:FireClient(player, islandId)
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
