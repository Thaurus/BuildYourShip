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

-- One-shot particle bursts for cannon fire, explosions and splashes
local EFFECTS = {
	Muzzle = { Color = { Color3.fromRGB(255, 220, 150), Color3.fromRGB(120, 116, 112) }, Count = 14, Size = { 1.5, 5 }, Speed = { 8, 20 }, Life = { 0.6, 1.4 }, Light = 0.6 },
	Explosion = { Color = { Color3.fromRGB(255, 170, 70), Color3.fromRGB(70, 64, 60) }, Count = 30, Size = { 2, 7 }, Speed = { 10, 26 }, Life = { 0.6, 1.6 }, Light = 0.8 },
	Impact = { Color = { Color3.fromRGB(170, 150, 120), Color3.fromRGB(110, 100, 90) }, Count = 14, Size = { 1, 3 }, Speed = { 6, 14 }, Life = { 0.5, 1 }, Light = 0 },
	Splash = { Color = { Color3.fromRGB(235, 245, 250), Color3.fromRGB(180, 210, 220) }, Count = 26, Size = { 1.2, 4 }, Speed = { 14, 26 }, Life = { 0.6, 1.2 }, Light = 0.1, Up = true },
}

local function burst(kind: string, position: Vector3, scale: number, direction: Vector3?)
	local spec = EFFECTS[kind]
	if not spec then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = if direction then CFrame.lookAt(position, position + direction) else CFrame.new(position)
	part.Parent = workspace.CurrentCamera

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(spec.Color[1], spec.Color[2])
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.Size[1] * scale), NumberSequenceKeypoint.new(1, spec.Size[2] * scale) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(spec.Life[1], spec.Life[2])
	emitter.Speed = NumberRange.new(spec.Speed[1] * scale, spec.Speed[2] * scale)
	emitter.SpreadAngle = if direction then Vector2.new(20, 20) else Vector2.new(180, 180)
	emitter.EmissionDirection = if spec.Up then Enum.NormalId.Top elseif direction then Enum.NormalId.Front else Enum.NormalId.Top
	emitter.Acceleration = if spec.Up then Vector3.new(0, -40, 0) else Vector3.new(0, 3, 0)
	emitter.LightEmission = spec.Light
	emitter.Drag = 2
	emitter.Enabled = false
	emitter.Parent = part
	emitter:Emit(math.floor(spec.Count * math.max(scale, 0.5)))

	if spec.Light > 0.5 then
		local light = Instance.new("PointLight")
		light.Color = spec.Color[1]
		light.Range = 24 * scale
		light.Brightness = 4
		light.Parent = part
		TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	end
	task.delay(spec.Life[2] + 0.5, function()
		part:Destroy()
	end)
end

function EffectsController.Init(ctx)
	Remotes.Event("Effect").OnClientEvent:Connect(function(kind, position, scale, direction)
		if typeof(position) == "Vector3" then
			burst(kind, position, scale or 1, direction)
		end
	end)

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
