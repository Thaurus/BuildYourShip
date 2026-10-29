-- Quest tracker card plus a waypoint: a glowing beam from your character to
-- the current objective and a marker over it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Islands = require(Shared.Islands)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local C = UIKit.Colors

local QuestController = {}

function QuestController.Init(ctx)
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera

	--------------------------------------------------------------------------
	-- Tracker card
	--------------------------------------------------------------------------
	local card = UIKit.Card({
		Color = C.Paper,
		Size = UDim2.fromOffset(300, 116),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Stroke = 3,
		Parent = ctx.Screen,
	})
	local stepLabel = UIKit.Label({ Text = "", TextSize = 12, TextColor3 = C.Grey, Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 8), Parent = card })
	local titleLabel = UIKit.Label({ Text = "", Font = UIKit.TitleFont, TextSize = 18, Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 24), Parent = card })
	local textLabel = UIKit.Label({
		Text = "",
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 50),
		Parent = card,
	})
	local barBack = UIKit.Card({ Color = C.PaperDark, Size = UDim2.new(1, -24, 0, 10), Position = UDim2.new(0, 12, 1, -20), Radius = 5, Stroke = 2, Parent = card })
	local barFill = Instance.new("Frame")
	barFill.BackgroundColor3 = C.Yellow
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.Parent = barBack
	UIKit.Corner(barFill, 5)
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	--------------------------------------------------------------------------
	-- Waypoint
	--------------------------------------------------------------------------
	local anchor = Instance.new("Part")
	anchor.Name = "QuestWaypoint"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Parent = camera
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = anchor

	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(160, 56)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.StudsOffset = Vector3.new(0, 6, 0)
	marker.Parent = anchor
	local markerLabel = UIKit.Label({
		Text = "",
		Font = UIKit.TitleFont,
		TextSize = 18,
		TextColor3 = C.Yellow,
		TextXAlignment = Enum.TextXAlignment.Center,
		Outlined = 2,
		Size = UDim2.fromScale(1, 1),
		Parent = marker,
	})

	local beam = Instance.new("Beam")
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 214, 120))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.85) })
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 1
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 4
	beam.TextureSpeed = 1.5
	beam.Parent = anchor

	local currentTarget: string? = nil
	local lastStep = nil

	local function resolve(target: string?): Vector3?
		if not target then
			return nil
		end
		local kind, arg = string.match(target, "^(%a+):?(.*)$")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if kind == "ship" then
			local ship = ctx.State.GetOwnShipModel()
			local shipRoot = ship and ship:FindFirstChild("Root") :: BasePart?
			return shipRoot and shipRoot.Position + Vector3.new(0, 6, 0)
		elseif kind == "dock" then
			local def = Islands.Get(arg)
			return def and Islands.GetDockPoint(def) + Vector3.new(0, 4, 0)
		elseif kind == "trader" then
			for _, npc in CollectionService:GetTagged("Trader") do
				if npc:GetAttribute("IslandId") == arg and npc:IsA("Model") then
					return npc:GetPivot().Position + Vector3.new(0, 4, 0)
				end
			end
		elseif kind == "shipwright" then
			for _, npc in CollectionService:GetTagged("Shipwright") do
				if npc:IsA("Model") then
					return npc:GetPivot().Position + Vector3.new(0, 4, 0)
				end
			end
		elseif kind == "nearest" and root then
			local best, bestDistance = nil, math.huge
			for _, node in CollectionService:GetTagged("HarvestNode") do
				if node:IsA("Model") and node:GetAttribute("Resource") == arg and not node:GetAttribute("Depleted") then
					local d = (node:GetPivot().Position - root.Position).Magnitude
					if d < bestDistance then
						best, bestDistance = node, d
					end
				end
			end
			return best and best:GetPivot().Position + Vector3.new(0, 4, 0)
		end
		return nil
	end

	ctx.State.Observe(function(data)
		local quest = data.Quest
		if not quest then
			return
		end
		if quest.Done then
			stepLabel.Text = "ALL QUESTS COMPLETE"
			titleLabel.Text = "Master of the seas"
			textLabel.Text = "Keep trading, building and hunting pirates!"
			barFill.Size = UDim2.fromScale(1, 1)
			currentTarget = nil
			return
		end
		stepLabel.Text = `QUEST {quest.Step} / {quest.Total}`
		titleLabel.Text = quest.Title
		textLabel.Text = quest.Text
		local progress = math.clamp(quest.Progress / quest.Count, 0, 1)
		TweenService:Create(barFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(progress, 1) }):Play()
		if quest.Count > 1 then
			stepLabel.Text ..= `   ·   {quest.Progress} / {quest.Count}`
		end
		currentTarget = quest.Target
		if lastStep and lastStep ~= quest.Step then
			cardScale.Scale = 1.12
			TweenService:Create(cardScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastStep = quest.Step
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.15 then
			return
		end
		accumulator = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local pos = resolve(currentTarget)
		local data = ctx.State.Data
		if not pos or not root or (data and data.Building) then
			beam.Enabled = false
			marker.Enabled = false
			return
		end
		anchor.CFrame = CFrame.new(pos)
		local distance = (pos - root.Position).Magnitude
		marker.Enabled = distance > 12
		markerLabel.Text = `⬇ {math.floor(distance)} studs`
		local rootAttachment = root:FindFirstChild("RootAttachment") :: Attachment?
		beam.Attachment0 = rootAttachment
		beam.Enabled = rootAttachment ~= nil and distance > 12
	end)
end

return QuestController
