-- Builds the visual model for each ship block, centred on its anchor cell.
-- Shared so the client's ghost preview looks exactly like the real thing.
--
-- Every model is built around the origin and has WorldPivot = identity, so
-- model:PivotTo(cellCFrame) drops it into place.

local Config = require(script.Parent.Config)
local Palette = require(script.Parent.Palette)

local BlockFactory = {}

local G = Config.GRID
local H = G / 2
local SMOOTH = Enum.SurfaceType.Smooth
local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- rotates a cylinder's X axis to Y

type PartOptions = {
	Shape: Enum.PartType?,
	Material: Enum.Material?,
	Decor: boolean?, -- no collision, ignored by build raycasts
	Reflectance: number?,
	Transparency: number?,
	ClassName: string?,
}

local function addPart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, opts: PartOptions?): BasePart
	local o: PartOptions = opts or {}
	local p = Instance.new(o.ClassName or "Part") :: Part
	p.Name = name
	if o.Shape then
		p.Shape = o.Shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = o.Material or Enum.Material.SmoothPlastic
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Reflectance = o.Reflectance or 0
	p.Transparency = o.Transparency or 0
	p.Anchored = true
	if o.Decor then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p:SetAttribute("Decor", true)
	end
	p.Parent = model
	return p
end

local function cylinder(model, name, height, diameter, cf, color, opts)
	local o = opts or {}
	o.Shape = Enum.PartType.Cylinder
	return addPart(model, name, Vector3.new(height, diameter, diameter), cf * VERTICAL, color, o)
end

-- Thin horizontal bands that read as plank seams on the sides of a cube.
local function bands(model, color, ys, inset)
	for i, y in ys do
		addPart(model, "Seam" .. i, Vector3.new(G + 0.04 - inset, 0.18, G + 0.04 - inset), CFrame.new(0, y, 0), color, { Decor = true })
	end
end

local builders: { [string]: (Model) -> () } = {}

builders.WoodHull = function(m)
	addPart(m, "Main", Vector3.new(G, G, G), CFrame.new(), Palette.Wood)
	bands(m, Palette.WoodDark, { -H + 1.3, H - 1.3 }, 0)
end

builders.IronHull = function(m)
	addPart(m, "Main", Vector3.new(G, G, G), CFrame.new(), Palette.Iron, { Reflectance = 0.05 })
	bands(m, Palette.IronDark, { 0 }, 0)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			addPart(m, "Rivet", Vector3.new(0.45, 0.45, 0.45), CFrame.new(x * 1.35, H, z * 1.35), Palette.IronDark, {
				Shape = Enum.PartType.Ball,
				Decor = true,
			})
		end
	end
end

-- A floor slab at the top of its cell, flush with the top of neighbouring hull blocks
builders.Deck = function(m)
	addPart(m, "Main", Vector3.new(G, 0.8, G), CFrame.new(0, H - 0.4, 0), Palette.WoodLight)
	for i = -1, 1 do
		addPart(m, "Seam", Vector3.new(0.12, 0.84, G + 0.02), CFrame.new(i * 1, H - 0.4, 0), Palette.Wood, { Decor = true })
	end
	addPart(m, "Joist", Vector3.new(0.6, G - 0.8, 0.6), CFrame.new(0, -0.4, 0), Palette.WoodDark)
end

builders.CargoHold = function(m)
	local s = G - 0.4
	addPart(m, "Main", Vector3.new(s, s, s), CFrame.new(0, -0.2, 0), Palette.WoodLight)
	-- Frame edges
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			addPart(m, "Edge", Vector3.new(0.4, s + 0.04, 0.4), CFrame.new(x * (s / 2 - 0.15), -0.2, z * (s / 2 - 0.15)), Palette.WoodDark, { Decor = true })
		end
	end
	addPart(m, "Band", Vector3.new(s + 0.06, 0.35, s + 0.06), CFrame.new(0, -0.2, 0), Palette.WoodDark, { Decor = true })
end

local function mastAndSails(m, height, sails)
	cylinder(m, "Mast", height, 0.7, CFrame.new(0, -H + height / 2, 0), Palette.WoodDark)
	addPart(m, "Main", Vector3.new(1.4, 1, 1.4), CFrame.new(0, -H + 0.5, 0), Palette.WoodDark)
	for i, sail in sails do
		local y = -H + sail.Y
		cylinder(m, "Yard" .. i, sail.W + 1, 0.4, CFrame.new(0, y + sail.H / 2 + 0.2, -0.45) * CFrame.Angles(0, 0, -math.pi / 2), Palette.WoodDark, { Decor = true })
		addPart(m, "Sail" .. i, Vector3.new(sail.W, sail.H, 0.25), CFrame.new(0, y, -0.7), Palette.Sail, { Decor = true })
		-- Billow: a slightly smaller panel pushed forward gives a puffed-out look
		addPart(m, "Billow" .. i, Vector3.new(sail.W - 1.2, sail.H - 1, 0.3), CFrame.new(0, y, -0.95), Palette.Sail, { Decor = true })
		addPart(m, "Stripe" .. i, Vector3.new(sail.W - 1.19, 0.7, 0.32), CFrame.new(0, y, -0.96), Palette.SailStripe, { Decor = true })
	end
	addPart(m, "Pennant", Vector3.new(0.12, 0.8, 2), CFrame.new(0, -H + height - 0.5, 1.05), Palette.SailStripe, { Decor = true })
end

builders.SmallSail = function(m)
	mastAndSails(m, 3 * G, { { Y = 7.4, W = 7, H = 5.5 } })
end

builders.LargeSail = function(m)
	mastAndSails(m, 4 * G, { { Y = 7.4, W = 10, H = 5 }, { Y = 12.8, W = 8, H = 4.2 } })
end

builders.SteamEngine = function(m)
	addPart(m, "Main", Vector3.new(G, 3, G), CFrame.new(0, -0.5, 0), Palette.IronDark, { Reflectance = 0.05 })
	addPart(m, "Boiler", Vector3.new(3.2, 2.6, 3.2), CFrame.new(0, 1.4, 0.3), Palette.Red)
	addPart(m, "Gauge", Vector3.new(0.9, 0.9, 0.2), CFrame.new(0, 1.6, -1.35), Palette.Yellow, { Decor = true })
	local chimney = cylinder(m, "Chimney", 4, 1.3, CFrame.new(0, 4.5, 0.8), Palette.Ink)
	cylinder(m, "ChimneyCap", 0.5, 1.8, CFrame.new(0, 6.6, 0.8), Palette.IronDark, { Decor = true })
	local attachment = Instance.new("Attachment")
	attachment.Name = "SmokeOrigin"
	attachment.Position = Vector3.new(2.3, 0, 0) -- the chimney's local X axis points up
	attachment.Parent = chimney
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240), Color3.fromRGB(150, 150, 160))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(2, 3)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(4, 6)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = attachment
end

builders.Rudder = function(m)
	addPart(m, "Main", Vector3.new(0.8, G - 0.4, G - 0.6), CFrame.new(0, -0.3, 0), Palette.WoodDark)
	addPart(m, "Blade", Vector3.new(0.5, 2.5, 2.4), CFrame.new(0, -H - 1, 0.2), Palette.Wood, { Decor = true })
	cylinder(m, "Tiller", 0.6, 0.6, CFrame.new(0, H - 0.1, 0), Palette.IronDark, { Decor = true })
end

builders.Helm = function(m)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = CFrame.new(0, -H + 0.5, 0.6)
	seat.Color = Palette.WoodDark
	seat.Material = Enum.Material.SmoothPlastic
	seat.TopSurface = SMOOTH
	seat.BottomSurface = SMOOTH
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.Anchored = true
	seat.Parent = m

	addPart(m, "Main", Vector3.new(0.6, 2.6, 0.6), CFrame.new(0, -H + 1.3, -1.1), Palette.WoodDark)
	local wheelCF = CFrame.new(0, -H + 2.9, -1.1)
	addPart(m, "Wheel", Vector3.new(0.3, 2.6, 2.6), wheelCF * CFrame.Angles(0, math.pi / 2, 0), Palette.Wood, {
		Shape = Enum.PartType.Cylinder,
		Decor = true,
	})
	addPart(m, "Hub", Vector3.new(0.5, 1, 1), wheelCF * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-0.1, 0, 0), Palette.Yellow, {
		Shape = Enum.PartType.Cylinder,
		Decor = true,
	})
	for i = 0, 3 do
		addPart(m, "Spoke", Vector3.new(0.25, 3.6, 0.25), wheelCF * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, 0, -0.05), Palette.WoodDark, { Decor = true })
	end
end

builders.Railing = function(m)
	local edge = -H + 0.25
	for _, x in { -1.6, 0, 1.6 } do
		addPart(m, "Post", Vector3.new(0.4, 2.4, 0.4), CFrame.new(x, -H + 1.2, edge), Palette.WoodDark)
	end
	addPart(m, "Main", Vector3.new(G, 0.4, 0.5), CFrame.new(0, -H + 2.4, edge), Palette.Wood)
end

builders.Lantern = function(m)
	addPart(m, "Main", Vector3.new(0.4, 3, 0.4), CFrame.new(0, -H + 1.5, 0), Palette.IronDark)
	local lamp = addPart(m, "Lamp", Vector3.new(1, 1.2, 1), CFrame.new(0, -H + 3.4, 0), Palette.Lamp, {
		Material = Enum.Material.Neon,
		Decor = true,
	})
	addPart(m, "Cap", Vector3.new(1.3, 0.3, 1.3), CFrame.new(0, -H + 4.15, 0), Palette.IronDark, { Decor = true })
	local light = Instance.new("PointLight")
	light.Color = Palette.Lamp
	light.Range = 18
	light.Brightness = 1.4
	light.Shadows = true
	light.Parent = lamp
end

builders.Flag = function(m)
	cylinder(m, "Main", 7, 0.35, CFrame.new(0, -H + 3.5, 0), Palette.WoodDark)
	addPart(m, "Cloth", Vector3.new(0.15, 1.8, 2.8), CFrame.new(0, -H + 6, 1.45), Palette.SailStripe, { Decor = true })
	addPart(m, "Emblem", Vector3.new(0.2, 0.9, 0.9), CFrame.new(0, -H + 6, 1.45), Palette.Yellow, {
		Decor = true,
		Shape = Enum.PartType.Ball,
	})
	addPart(m, "Knob", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, -H + 7.1, 0), Palette.Yellow, {
		Decor = true,
		Shape = Enum.PartType.Ball,
	})
end

function BlockFactory.Create(blockId: string): Model
	local model = Instance.new("Model")
	model.Name = blockId
	local builder = builders[blockId] or builders.WoodHull
	builder(model)
	model.WorldPivot = CFrame.new()
	return model
end

-- Turns a block model into a translucent, non-interactive preview.
function BlockFactory.MakeGhost(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.45)
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Anchored = true
			if d:IsA("VehicleSeat") then
				d.Disabled = true
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			d.Enabled = false
		end
	end
	return model
end

return BlockFactory
