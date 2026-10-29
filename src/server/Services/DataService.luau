-- Loads and saves player profiles. Works offline in Studio (falls back to a
-- fresh profile) when API access is disabled.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Goods = require(Shared.Goods)
local ShipGrid = require(Shared.ShipGrid)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, progress will not be saved:", result)
	end
end

local function defaultProfile()
	return {
		Version = 2,
		Gold = Config.STARTING_GOLD,
		Inventory = { Wood = 4, Fiber = 6 },
		Holds = {}, -- [cell key] = { goodId, ... } crates stowed in each cargo hold
		Blueprint = ShipGrid.StarterBlueprint(),
		Stats = { GoldEarned = 0, Trades = 0, Harvests = 0 },
		Quest = { Step = 1, Progress = 0 },
		SeenTutorial = false,
	}
end

local function sanitize(raw)
	local profile = defaultProfile()
	if type(raw) ~= "table" then
		return profile
	end
	if type(raw.Gold) == "number" and raw.Gold >= 0 then
		profile.Gold = math.floor(raw.Gold)
	end
	if type(raw.Inventory) == "table" then
		profile.Inventory = {}
		for id, n in raw.Inventory do
			if Items.Get(id) and type(n) == "number" and n > 0 then
				profile.Inventory[id] = math.floor(n)
			end
		end
	end
	profile.Blueprint = ShipGrid.Sanitize(raw.Blueprint, Config.BIG_BUILD_BOUNDS) or profile.Blueprint
	-- Only keep crates in holds that still exist on the ship
	if type(raw.Holds) == "table" then
		local holdKeys = {}
		for _, e in profile.Blueprint do
			if e.t == "CargoHold" then
				holdKeys[ShipGrid.Key(e.x, e.y, e.z)] = true
			end
		end
		for key, list in raw.Holds do
			if holdKeys[key] and type(list) == "table" then
				local clean = {}
				for _, goodId in list do
					if Goods.Get(goodId) and #clean < Config.CRATES_PER_HOLD then
						table.insert(clean, goodId)
					end
				end
				profile.Holds[key] = clean
			end
		end
	end
	if type(raw.Quest) == "table" and type(raw.Quest.Step) == "number" and type(raw.Quest.Progress) == "number" then
		profile.Quest = { Step = math.max(1, math.floor(raw.Quest.Step)), Progress = math.max(0, math.floor(raw.Quest.Progress)) }
	end
	if type(raw.Stats) == "table" then
		for key, value in raw.Stats do
			if type(value) == "number" then
				profile.Stats[key] = value
			end
		end
	end
	profile.SeenTutorial = raw.SeenTutorial == true
	return profile
end

local function withRetries(fn)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataService] attempt {attempt} failed: {result}`)
		task.wait(attempt * 1.5)
	end
	return false, nil
end

function DataService.Load(player: Player)
	local raw
	if store then
		local ok, result = withRetries(function()
			return store:GetAsync(`player_{player.UserId}`)
		end)
		if ok then
			raw = result
		end
	end
	local profile = sanitize(raw)
	DataService.Profiles[player] = profile
	return profile
end

function DataService.Get(player: Player)
	return DataService.Profiles[player]
end

function DataService.Save(player: Player)
	local profile = DataService.Profiles[player]
	if not profile or not store then
		return
	end
	withRetries(function()
		store:SetAsync(`player_{player.UserId}`, profile, { player.UserId })
	end)
end

function DataService.Release(player: Player)
	DataService.Save(player)
	DataService.Profiles[player] = nil
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.Save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
