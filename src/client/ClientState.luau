-- Holds the latest state snapshot from the server and announces changes.

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

-- The local player's ship model in workspace.Ships, if spawned
function ClientState.GetShipModel(): Model?
	local folder = workspace:FindFirstChild("Ships")
	if not folder then
		return nil
	end
	local userId = game:GetService("Players").LocalPlayer.UserId
	for _, model in folder:GetChildren() do
		if model:GetAttribute("OwnerId") == userId then
			return model
		end
	end
	return nil
end

return ClientState
