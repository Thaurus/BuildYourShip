-- Holds the latest state snapshot from the server and announces changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local ClientState = {}
ClientState.Data = nil

local changed = Instance.new("BindableEvent")
ClientState.Changed = changed.Event

Remotes.Event("StateUpdate").OnClientEvent:Connect(function(data)
	ClientState.Data = data
	changed:Fire(data)
end)

function ClientState.Count(id: string): number
	local data = ClientState.Data
	return data and data.Inventory[id] or 0
end

-- Calls fn now (if data exists) and on every change
function ClientState.Observe(fn: (any) -> ())
	if ClientState.Data then
		task.spawn(fn, ClientState.Data)
	end
	return ClientState.Changed:Connect(fn)
end

local function shipsFolder(): Instance?
	return workspace:FindFirstChild("Ships")
end

-- Ship model by id (the ship you sail on may be your captain's)
function ClientState.GetShipModelById(id: number?): Model?
	local folder = shipsFolder()
	if not folder or not id then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("ShipId") == id then
			return model
		end
	end
	return nil
end

-- The ship the local player sails on (own, or captain's when in a crew)
function ClientState.GetShipModel(): Model?
	local data = ClientState.Data
	return ClientState.GetShipModelById(data and data.Ship and data.Ship.Id)
end

-- The local player's own ship (the one they build)
function ClientState.GetOwnShipModel(): Model?
	local folder = shipsFolder()
	if not folder then
		return nil
	end
	local userId = Players.LocalPlayer.UserId
	for _, model in folder:GetChildren() do
		if model:GetAttribute("OwnerId") == userId then
			return model
		end
	end
	return nil
end

return ClientState
