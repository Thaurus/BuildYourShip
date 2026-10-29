-- Server notifications become comic toasts, or floating "+2 Wood" pops in the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local EffectsController = {}

local function floatingText(text: string, position: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace.CurrentCamera

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = UIKit.Label({
		Text = text,
		Font = UIKit.TitleFont,
		TextSize = 34,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Outlined = 3,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(anchor, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) }):Play()
	task.delay(0.9, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(label.TextOutline, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

function EffectsController.Init(ctx)
	Remotes.Event("Notify").OnClientEvent:Connect(function(payload)
		if payload.Position then
			floatingText(payload.Text, payload.Position, UIKit.Colors.Yellow)
			ctx.Sounds.Pop()
		else
			UIKit.Toast(ctx.Screen, payload.Text, payload.Kind)
		end
	end)
end

return EffectsController
