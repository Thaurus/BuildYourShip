--!strict
-- Single place that defines every RemoteEvent / RemoteFunction.
-- The server creates them on first require; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"StateUpdate", -- S -> C: full player state snapshot
	"Notify", -- S -> C: toast / floating text
	"OpenMarket", -- S -> C: trader prompt used
	"OpenShop", -- S -> C: shipwright prompt used
	"CrewInvite", -- S -> C: someone invited you to their crew
	"Effect", -- S -> C: one-shot visual effect (explosion, splash, muzzle flash)
	"TutorialDone", -- C -> S: player closed the welcome card
	"HelmInput", -- C -> S: throttle / steer while at the helm
}

local FUNCTIONS = {
	"Craft",
	"Buy",
	"GetMarket",
	"BuyCrate",
	"DropCrate",
	"ToggleBuild",
	"PlaceBlock",
	"RemoveBlock",
	"BoardShip",
	"ResetShip",
	"RepairShip",
	"FireBroadside",
	"CrewAction",
	"BuyGamepass",
}

local Remotes = {}

local function createFolder(): Folder
	local created = Instance.new("Folder")
	created.Name = "Remotes"
	for _, name in EVENTS do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = created
	end
	for _, name in FUNCTIONS do
		local f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = created
	end
	created.Parent = ReplicatedStorage
	return created
end

local folder: Folder = if RunService:IsServer()
	then (ReplicatedStorage:FindFirstChild("Remotes") :: Folder?) or createFolder()
	else ReplicatedStorage:WaitForChild("Remotes") :: Folder

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
