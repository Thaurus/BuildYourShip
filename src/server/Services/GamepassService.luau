-- Gamepass ownership and purchase prompts. Pass IDs live in Config.GAMEPASSES;
-- a pass with Id = 0 is not configured yet and is never granted.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local GamepassService = {}
local S

local owned: { [Player]: { [string]: boolean } } = {}

function GamepassService.Init(services)
	S = services
end

function GamepassService.Has(player: Player, key: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[key] == true
end

function GamepassService.Owned(player: Player): { [string]: boolean }
	return owned[player] or {}
end

local function grant(player: Player, key: string)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	if key == "GrandShipyard" then
		S.ShipService.SetBounds(player, Config.BIG_BUILD_BOUNDS)
	end
	S.StateService.Push(player)
end

-- Called while the player's profile loads, before their ship spawns
function GamepassService.Load(player: Player)
	owned[player] = {}
	for key, pass in Config.GAMEPASSES do
		if pass.Id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and has then
				owned[player][key] = true
			end
		end
	end
end

function GamepassService.Start()
	Remotes.Function("BuyGamepass").OnServerInvoke = function(player, key)
		local pass = type(key) == "string" and Config.GAMEPASSES[key]
		if not pass then
			return { ok = false }
		end
		if pass.Id == 0 then
			return { ok = false, msg = "This pass isn't available yet." }
		end
		if GamepassService.Has(player, key) then
			return { ok = false, msg = "You already own this pass!" }
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		return { ok = true }
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in Config.GAMEPASSES do
			if pass.Id == passId then
				grant(player, key)
				S.StateService.Notify(player, `🎉 Thanks! {pass.Name} unlocked.`, "good")
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
end

return GamepassService
