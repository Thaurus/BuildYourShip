-- Trees, flax bushes and ore rocks tagged "HarvestNode" can be harvested with a
-- hold prompt. They pop away and regrow after a while.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)

local HarvestService = {}
local InventoryService, StateService, DataService, QuestService

local NODE_TYPES = {
	Wood = { Item = "Wood", Min = 2, Max = 3, Action = "Chop", Hold = 1.0 },
	Fiber = { Item = "Fiber", Min = 2, Max = 3, Action = "Gather", Hold = 0.7 },
	Iron = { Item = "IronOre", Min = 1, Max = 2, Action = "Mine", Hold = 1.4 },
}

local rng = Random.new()

function HarvestService.Init(services)
	InventoryService = services.InventoryService
	StateService = services.StateService
	DataService = services.DataService
	QuestService = services.QuestService
end

local function setYieldVisible(node: Model, visible: boolean)
	for _, part in node:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Yield" then
			if part:GetAttribute("BaseTransparency") == nil then
				part:SetAttribute("BaseTransparency", part.Transparency)
				part:SetAttribute("BaseCollide", part.CanCollide)
			end
			if visible then
				part.Transparency = 1
				part.CanCollide = part:GetAttribute("BaseCollide")
				TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Back), {
					Transparency = part:GetAttribute("BaseTransparency"),
				}):Play()
			else
				part.CanCollide = false
				TweenService:Create(part, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			end
		end
	end
end

local function setupNode(node: Instance)
	if not node:IsA("Model") or not node.PrimaryPart then
		return
	end
	local nodeType = NODE_TYPES[node:GetAttribute("Resource")]
	if not nodeType then
		return
	end
	local item = Items.Get(nodeType.Item)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = nodeType.Action
	prompt.ObjectText = `{item.Icon} {item.Name}`
	prompt.HoldDuration = nodeType.Hold
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = node.PrimaryPart

	prompt.Triggered:Connect(function(player)
		if node:GetAttribute("Depleted") then
			return
		end
		node:SetAttribute("Depleted", true)
		prompt.Enabled = false

		local amount = rng:NextInteger(nodeType.Min, nodeType.Max)
		InventoryService.Add(player, nodeType.Item, amount)
		QuestService.Fire(player, "Harvest", nodeType.Item, amount)
		local profile = DataService.Get(player)
		if profile then
			profile.Stats.Harvests = (profile.Stats.Harvests or 0) + 1
		end
		StateService.Notify(player, `+{amount} {item.Icon} {item.Name}`, "gain", node.PrimaryPart.Position + Vector3.new(0, 5, 0))
		setYieldVisible(node, false)

		task.delay(Config.HARVEST_REGROW, function()
			node:SetAttribute("Depleted", nil)
			setYieldVisible(node, true)
			prompt.Enabled = true
		end)
	end)
end

function HarvestService.Start()
	for _, node in CollectionService:GetTagged("HarvestNode") do
		setupNode(node)
	end
	CollectionService:GetInstanceAddedSignal("HarvestNode"):Connect(setupNode)
end

return HarvestService
