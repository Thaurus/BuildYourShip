-- Builds the visual model for each ship block, centred on its anchor cell.
-- Shared so the client's ghost preview looks exactly like the real thing.
--
-- Shapes are generated procedurally from parts (wedges for the tapered bow,
-- angled panels for billowing sails, cylinders for masts and cannons) using
-- Roblox's realistic materials: planks, wood, fabric, metal and glass.
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
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0) -- rotates a cylinder's X axis to -Z

local M = Enum.Material

export type Options = {
	X: number?, -- the block's cell x (bows taper differently on each side)
	Style: string?, -- "Pirate" for dark hulls and black sails
}

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
	p.Material = o.Material or M.SmoothPlastic
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

local function wedge(model, name, size, cf, color, opts)
	local o = opts or {}
	o.ClassName = "WedgePart"
	return addPart(model, name, size, cf, color, o)
end

-- A thin part stretched between two points (ropes, stays, shrouds)
local function rope(model, a: Vector3, b: Vector3, thickness: number?)
	local t = thickness or 0.12
	return addPart(model, "Rope", Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Palette.Rope, {
		Decor = true,
		Material = M.Fabric,
	})
end

local function colours(style: string?)
	if style == "Pirate" then
		return {
			Hull = Palette.PirateHull,
			Trim = Palette.Tar,
			Sail = Palette.PirateSail,
			Stripe = Palette.Red,
			Flag = Palette.Ink,
		}
	end
	return {
		Hull = Palette.Wood,
		Trim = Palette.WoodDark,
		Sail = Palette.Sail,
		Stripe = Palette.SailStripe,
		Flag = Palette.SailStripe,
	}
end

-- Tar band at the bottom, a heavy wale in the middle and a cap rail on top
local function hullBands(m, col)
	addPart(m, "Tar", Vector3.new(G + 0.06, 1.1, G + 0.06), CFrame.new(0, -H + 0.55, 0), Palette.Tar, { Decor = true, Material = M.Wood })
	addPart(m, "Wale", Vector3.new(G + 0.1, 0.35, G + 0.1), CFrame.new(0, 0.7, 0), col.Trim, { Decor = true, Material = M.Wood })
	addPart(m, "CapRail", Vector3.new(G + 0.08, 0.22, G + 0.08), CFrame.new(0, H - 0.11, 0), Palette.WoodLight, { Decor = true, Material = M.Wood })
end

local builders: { [string]: (Model, Options, any) -> () } = {}

builders.WoodHull = function(m, _opts, col)
	addPart(m, "Main", Vector3.new(G, G, G), CFrame.new(), col.Hull, { Material = M.WoodPlanks })
	hullBands(m, col)
end

builders.IronHull = function(m, _opts, col)
	addPart(m, "Main", Vector3.new(G, G, G), CFrame.new(), Palette.Iron, { Material = M.Metal, Reflectance = 0.04 })
	addPart(m, "AntiFoul", Vector3.new(G + 0.06, 1.1, G + 0.06), CFrame.new(0, -H + 0.55, 0), Palette.AntiFoul, { Decor = true, Material = M.Metal })
	addPart(m, "Plate", Vector3.new(G + 0.08, 0.5, G + 0.08), CFrame.new(0, 0.6, 0), Palette.IronDark, { Decor = true, Material = M.DiamondPlate })
	addPart(m, "CapRail", Vector3.new(G + 0.08, 0.22, G + 0.08), CFrame.new(0, H - 0.11, 0), col.Trim, { Decor = true, Material = M.Wood })
end

-- Centre bows get a pointed stem and a bowsprit; side bows taper towards the centre.
builders.Bow = function(m, opts, col)
	local x = opts.X or 0
	if x == 0 then
		addPart(m, "Main", Vector3.new(G, G, G), CFrame.new(), col.Hull, { Material = M.WoodPlanks })
		hullBands(m, col)
		local len = 3
		-- Two wedges whose tips meet at the centre line in front of the cell
		wedge(m, "Prow", Vector3.new(G, H, len), CFrame.new(1, 0, -H - len / 2) * CFrame.Angles(0, 0, -math.pi / 2), col.Hull, { Material = M.WoodPlanks, Decor = true })
		wedge(m, "Prow", Vector3.new(G, H, len), CFrame.new(-1, 0, -H - len / 2) * CFrame.Angles(0, 0, math.pi / 2), col.Hull, { Material = M.WoodPlanks, Decor = true })
		addPart(m, "Stem", Vector3.new(0.45, G + 0.6, 0.45), CFrame.new(0, 0.3, -H - len), col.Trim, { Decor = true, Material = M.Wood })
		local base = Vector3.new(0, H - 0.2, -H - 0.5)
		local tip = Vector3.new(0, H + 2.6, -H - len - 4.2)
		addPart(m, "Bowsprit", Vector3.new(0.5, 0.5, (tip - base).Magnitude), CFrame.lookAt((base + tip) / 2, tip), col.Trim, { Decor = true, Material = M.Wood })
		rope(m, tip, Vector3.new(0, -H + 0.4, -H - len + 0.2))
	else
		-- Triangle: full width at the back, full length on the inner edge, tip at the inner front corner
		local roll = if x < 0 then math.pi / 2 else -math.pi / 2
		wedge(m, "Main", Vector3.new(G, G, G), CFrame.Angles(0, 0, roll), col.Hull, { Material = M.WoodPlanks })
		local inner = if x < 0 then 1 else -1
		addPart(m, "CapRail", Vector3.new(0.22, 0.22, G * 1.41), CFrame.new(0, H - 0.11, 0) * CFrame.Angles(0, -inner * math.rad(45), 0), Palette.WoodLight, {
			Decor = true,
			Material = M.Wood,
		})
	end
end

builders.SteelHull = function(m)
	addPart(m, "Main", Vector3.new(G, G, G), CFrame.new(), Color3.fromRGB(112, 122, 134), { Material = M.Metal, Reflectance = 0.06 })
	addPart(m, "Boot", Vector3.new(G + 0.06, 1.1, G + 0.06), CFrame.new(0, -H + 0.55, 0), Palette.AntiFoul, { Decor = true, Material = M.Metal })
	addPart(m, "Weld", Vector3.new(G + 0.08, 0.12, G + 0.08), CFrame.new(0, 0.4, 0), Palette.IronDark, { Decor = true, Material = M.Metal })
	addPart(m, "Gunwale", Vector3.new(G + 0.1, 0.3, G + 0.1), CFrame.new(0, H - 0.15, 0), Palette.IronDark, { Decor = true, Material = M.DiamondPlate })
end

-- An iron-shod bow with a spike at the waterline
builders.Ram = function(m, opts, col)
	builders.Bow(m, opts, col)
	addPart(m, "Plating", Vector3.new(G + 0.08, 1.6, G + 0.08), CFrame.new(0, -H + 0.8, 0), Palette.IronDark, { Decor = true, Material = M.Metal })
	if (opts.X or 0) == 0 then
		for _, side in { -1, 1 } do
			wedge(m, "Spike", Vector3.new(1.4, 0.8, 3.2), CFrame.new(side * 0.4, -H + 0.9, -H - 3.6) * CFrame.Angles(0, 0, side * -math.pi / 2), Palette.Iron, {
				Decor = true,
				Material = M.Metal,
			})
		end
	end
end

builders.Stern = function(m, opts, col)
	addPart(m, "Main", Vector3.new(G, G, G), CFrame.new(), col.Hull, { Material = M.WoodPlanks })
	hullBands(m, col)
	addPart(m, "Transom", Vector3.new(G + 0.1, 2.8, 0.3), CFrame.new(0, 0.4, H + 0.12), col.Trim, { Decor = true, Material = M.Wood })
	addPart(m, "Gilding", Vector3.new(G + 0.14, 0.2, 0.36), CFrame.new(0, H - 0.2, H + 0.14), Palette.Brass, { Decor = true, Material = M.Metal })
	local lit = opts.Style ~= "Pirate"
	for _, wx in { -0.95, 0.95 } do
		local pane = addPart(m, "Window", Vector3.new(0.9, 1, 0.12), CFrame.new(wx, 0.6, H + 0.3), if lit then Palette.Lamp else Palette.Glass, {
			Decor = true,
			Material = M.Glass,
			Transparency = 0.15,
		})
		addPart(m, "WindowFrame", Vector3.new(1.1, 1.2, 0.08), CFrame.new(wx, 0.6, H + 0.26), Palette.WoodLight, { Decor = true, Material = M.Wood })
		if lit then
			local light = Instance.new("PointLight")
			light.Color = Palette.Lamp
			light.Range = 8
			light.Brightness = 0.6
			light.Parent = pane
		end
	end
end

builders.Keel = function(m)
	addPart(m, "Main", Vector3.new(1.3, G, G), CFrame.new(), Palette.Tar, { Material = M.Wood })
	addPart(m, "Shoe", Vector3.new(1.4, 0.35, G + 0.02), CFrame.new(0, -H + 0.17, 0), Palette.IronDark, { Decor = true, Material = M.Metal })
end

-- A floor slab at the top of its cell, flush with the top of neighbouring hull blocks
builders.Deck = function(m)
	addPart(m, "Main", Vector3.new(G, 0.8, G), CFrame.new(0, H - 0.4, 0), Palette.WoodLight, { Material = M.WoodPlanks })
	addPart(m, "Joist", Vector3.new(0.6, G - 0.8, 0.6), CFrame.new(0, -0.4, 0), Palette.WoodDark, { Material = M.Wood })
end

-- Crates stowed in a hold sit at these offsets (relative to the hold's cell)
BlockFactory.HOLD_SLOTS = {
	CFrame.new(-0.95, -0.2, 0),
	CFrame.new(0.95, -0.2, 0),
}
BlockFactory.STOWED_CRATE_SIZE = 1.8

builders.CargoHold = function(m)
	addPart(m, "Main", Vector3.new(G - 0.2, 0.8, G - 0.2), CFrame.new(0, -H + 0.4, 0), Palette.Wood, { Material = M.Wood })
	addPart(m, "Grating", Vector3.new(G - 0.8, 0.12, G - 0.8), CFrame.new(0, -H + 0.82, 0), Palette.WoodDark, { Decor = true, Material = M.WoodPlanks })
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			addPart(m, "Cleat", Vector3.new(0.3, 0.5, 0.3), CFrame.new(x * 1.7, -H + 1.05, z * 1.7), Palette.IronDark, { Decor = true, Material = M.Metal })
		end
	end
end

local function sailPanel(m, name, width, height, centre: CFrame, col)
	-- Three slightly angled strips read as a sail filled with wind
	local strip = height / 3
	local rows = {
		{ strip, -0.55, math.rad(10) },
		{ 0, -0.85, 0 },
		{ -strip, -0.55, math.rad(-10) },
	}
	for i, row in rows do
		addPart(m, name, Vector3.new(width - (if i == 2 then 0 else 0.3), strip + 0.05, 0.12), centre * CFrame.new(0, row[1], row[2]) * CFrame.Angles(row[3], 0, 0), if i == 2 then col.Sail else (if col.Sail == Palette.Sail then Palette.SailShade else col.Sail), {
			Decor = true,
			Material = M.Fabric,
		})
	end
	addPart(m, "SailBand", Vector3.new(width - 0.2, 0.35, 0.14), centre * CFrame.new(0, 0, -0.93), col.Stripe, { Decor = true, Material = M.Fabric })
end

local function mastAndSails(m, height, sails, col, crowsNest)
	cylinder(m, "Mast", height, 0.75, CFrame.new(0, -H + height / 2, 0), Palette.WoodDark, { Material = M.Wood })
	addPart(m, "Main", Vector3.new(1.4, 1, 1.4), CFrame.new(0, -H + 0.5, 0), Palette.WoodDark, { Material = M.Wood })
	for i, sail in sails do
		local centre = CFrame.new(0, -H + sail.Y, 0)
		cylinder(m, "Yard" .. i, sail.W + 1.2, 0.35, centre * CFrame.new(0, sail.H / 2 + 0.15, -0.4) * CFrame.Angles(0, 0, -math.pi / 2), Palette.WoodDark, {
			Decor = true,
			Material = M.Wood,
		})
		sailPanel(m, "Sail" .. i, sail.W, sail.H, centre, col)
	end
	local top = Vector3.new(0, -H + height - 0.3, 0)
	for _, side in { -1, 1 } do
		rope(m, top, Vector3.new(side * 1.9, -H + 0.2, 1.4))
		rope(m, top, Vector3.new(side * 1.9, -H + 0.2, -1.4))
	end
	if crowsNest then
		cylinder(m, "CrowsNest", 0.9, 2.2, CFrame.new(0, -H + height - 2.2, 0), Palette.Wood, { Decor = true, Material = M.WoodPlanks })
	end
	addPart(m, "Pennant", Vector3.new(0.1, 0.7, 2.2), CFrame.new(0, -H + height - 0.4, 1.15), col.Flag, { Decor = true, Material = M.Fabric })
end

builders.SmallSail = function(m, _opts, col)
	mastAndSails(m, 3 * G, { { Y = 7.4, W = 7, H = 5.5 } }, col, false)
end

builders.LargeSail = function(m, _opts, col)
	mastAndSails(m, 4 * G, { { Y = 6.8, W = 10, H = 5 }, { Y = 12.4, W = 8, H = 4.2 } }, col, true)
end

builders.SteamEngine = function(m)
	addPart(m, "Main", Vector3.new(G, 3, G), CFrame.new(0, -0.5, 0), Palette.IronDark, { Material = M.Metal })
	cylinder(m, "Boiler", 3.2, 3, CFrame.new(0, 1.4, 0.3) * CFrame.Angles(0, 0, 0), Palette.Iron, { Material = M.Metal })
	addPart(m, "Gauge", Vector3.new(0.8, 0.8, 0.15), CFrame.new(0.8, 1.2, -1.4), Palette.Brass, { Decor = true, Material = M.Metal })
	local chimney = cylinder(m, "Chimney", 4, 1.2, CFrame.new(0, 4.5, 0.8), Palette.Ink, { Material = M.Metal })
	cylinder(m, "ChimneyCap", 0.4, 1.6, CFrame.new(0, 6.6, 0.8), Palette.Brass, { Decor = true, Material = M.Metal })
	local attachment = Instance.new("Attachment")
	attachment.Name = "SmokeOrigin"
	attachment.Position = Vector3.new(2.3, 0, 0) -- the chimney's local X axis points up
	attachment.Parent = chimney
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 118, 116), Color3.fromRGB(60, 58, 58))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(2.5, 3.5)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(4, 6)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = attachment
end

-- Rowing bench with an oar reaching over the side (the block's -Z faces outboard)
builders.Oars = function(m, _opts, col)
	addPart(m, "Main", Vector3.new(G - 0.6, 0.4, 1.2), CFrame.new(0, -H + 1.2, 0.6), Palette.WoodLight, { Material = M.WoodPlanks })
	for _, x in { -1.4, 1.4 } do
		addPart(m, "BenchLeg", Vector3.new(0.3, 1, 0.3), CFrame.new(x, -H + 0.5, 0.6), col.Trim, { Decor = true, Material = M.Wood })
	end
	addPart(m, "Oarlock", Vector3.new(0.5, 0.6, 0.5), CFrame.new(0, -H + 0.3, -H + 0.25), Palette.IronDark, { Decor = true, Material = M.Metal })
	local handle = Vector3.new(0, -H + 1.6, 0.4)
	local blade = Vector3.new(0, -H - 2.6, -H - 4.2)
	addPart(m, "Oar", Vector3.new(0.25, 0.25, (blade - handle).Magnitude), CFrame.lookAt((handle + blade) / 2, blade), Palette.WoodLight, {
		Decor = true,
		Material = M.Wood,
	})
	addPart(m, "Blade", Vector3.new(0.12, 0.9, 1.8), CFrame.lookAt(blade, blade + (blade - handle).Unit), Palette.WoodLight, {
		Decor = true,
		Material = M.Wood,
	})
end

builders.DieselMotor = function(m)
	addPart(m, "Main", Vector3.new(G - 0.4, 2.4, G - 0.6), CFrame.new(0, -H + 1.2, 0.2), Color3.fromRGB(70, 86, 74), { Material = M.Metal })
	addPart(m, "Head", Vector3.new(2.4, 0.8, 2.6), CFrame.new(0, -H + 2.8, 0.2), Palette.IronDark, { Material = M.DiamondPlate })
	for i = -1, 1 do
		addPart(m, "Fin", Vector3.new(2.6, 0.12, 0.12), CFrame.new(0, -H + 1.6, 0.2 + i * 0.7), Palette.Iron, { Decor = true, Material = M.Metal })
	end
	local exhaust = cylinder(m, "Exhaust", 3, 0.5, CFrame.new(1.2, -H + 4.2, 1.4), Palette.Ink, { Material = M.Metal })
	local attachment = Instance.new("Attachment")
	attachment.Name = "SmokeOrigin"
	attachment.Position = Vector3.new(1.6, 0, 0)
	attachment.Parent = exhaust
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 90, 92))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1, 1.8)
	smoke.Rate = 10
	smoke.Speed = NumberRange.new(3, 5)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = attachment
end

builders.Rudder = function(m, _opts, col)
	addPart(m, "Main", Vector3.new(0.7, G - 0.4, G - 1), CFrame.new(0, -0.3, -0.5), col.Trim, { Material = M.Wood })
	addPart(m, "Blade", Vector3.new(0.5, 2.5, 2.4), CFrame.new(0, -H - 1, -0.3), col.Hull, { Decor = true, Material = M.WoodPlanks })
	cylinder(m, "Tiller", 0.6, 0.5, CFrame.new(0, H - 0.1, -0.5), Palette.IronDark, { Decor = true, Material = M.Metal })
	addPart(m, "Pintle", Vector3.new(0.8, 0.25, 0.4), CFrame.new(0, 0.8, -1.2), Palette.IronDark, { Decor = true, Material = M.Metal })
end

-- Barrel points along the block's -Z; rotate the block so it faces over the side
builders.Cannon = function(m)
	addPart(m, "Main", Vector3.new(2, 0.8, 2.4), CFrame.new(0, -H + 0.7, 0.2), Palette.Wood, { Material = M.Wood })
	for _, x in { -1.05, 1.05 } do
		for _, z in { -0.6, 1 } do
			addPart(m, "Wheel", Vector3.new(0.25, 0.8, 0.8), CFrame.new(x, -H + 0.4, z), Palette.WoodDark, {
				Shape = Enum.PartType.Cylinder,
				Decor = true,
				Material = M.Wood,
			})
		end
	end
	local barrelY = -H + 1.5
	local barrel = addPart(m, "Barrel", Vector3.new(3.2, 0.8, 0.8), CFrame.new(0, barrelY, -0.4) * ALONG_Z, Palette.IronDark, {
		Shape = Enum.PartType.Cylinder,
		Material = M.Metal,
		Reflectance = 0.05,
	})
	addPart(m, "Muzzle", Vector3.new(0.3, 1, 1), CFrame.new(0, barrelY, -1.9) * ALONG_Z, Palette.IronDark, {
		Shape = Enum.PartType.Cylinder,
		Decor = true,
		Material = M.Metal,
	})
	addPart(m, "Breech", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, barrelY, 1.25), Palette.IronDark, {
		Shape = Enum.PartType.Ball,
		Decor = true,
		Material = M.Metal,
	})
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "MuzzlePoint"
	muzzle.Position = Vector3.new(1.75, 0, 0) -- barrel's local X points out of the muzzle
	muzzle.Parent = barrel
end

builders.Helm = function(m)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = CFrame.new(0, -H + 0.5, 0.6)
	seat.Color = Palette.WoodDark
	seat.Material = M.Wood
	seat.TopSurface = SMOOTH
	seat.BottomSurface = SMOOTH
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.Anchored = true
	seat.Parent = m

	addPart(m, "Main", Vector3.new(0.9, 2.6, 0.9), CFrame.new(0, -H + 1.3, -1.1), Palette.WoodDark, { Material = M.Wood })
	addPart(m, "Binnacle", Vector3.new(0.7, 0.5, 0.7), CFrame.new(0, -H + 2.85, -0.4), Palette.Brass, { Decor = true, Material = M.Metal })
	local wheelCF = CFrame.new(0, -H + 2.9, -1.1)
	addPart(m, "Wheel", Vector3.new(0.25, 2.4, 2.4), wheelCF * CFrame.Angles(0, math.pi / 2, 0), Palette.Wood, {
		Shape = Enum.PartType.Cylinder,
		Decor = true,
		Material = M.Wood,
	})
	addPart(m, "Hub", Vector3.new(0.45, 0.8, 0.8), wheelCF * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-0.1, 0, 0), Palette.Brass, {
		Shape = Enum.PartType.Cylinder,
		Decor = true,
		Material = M.Metal,
	})
	for i = 0, 3 do
		addPart(m, "Spoke", Vector3.new(0.2, 3.4, 0.2), wheelCF * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, 0, -0.05), Palette.WoodDark, {
			Decor = true,
			Material = M.Wood,
		})
	end
end

builders.Railing = function(m)
	local edge = -H + 0.25
	for i = 0, 4 do
		addPart(m, "Baluster", Vector3.new(0.25, 2.2, 0.25), CFrame.new(-1.8 + i * 0.9, -H + 1.1, edge), Palette.WoodLight, { Material = M.Wood })
	end
	addPart(m, "Main", Vector3.new(G, 0.3, 0.45), CFrame.new(0, -H + 2.3, edge), Palette.Wood, { Material = M.Wood })
end

builders.Lantern = function(m)
	addPart(m, "Main", Vector3.new(0.35, 3, 0.35), CFrame.new(0, -H + 1.5, 0), Palette.IronDark, { Material = M.Metal })
	addPart(m, "Glass", Vector3.new(1, 1.2, 1), CFrame.new(0, -H + 3.4, 0), Palette.Glass, { Decor = true, Material = M.Glass, Transparency = 0.4 })
	local flame = addPart(m, "Flame", Vector3.new(0.45, 0.6, 0.45), CFrame.new(0, -H + 3.35, 0), Palette.Lamp, { Decor = true, Material = M.Neon })
	addPart(m, "Cap", Vector3.new(1.2, 0.25, 1.2), CFrame.new(0, -H + 4.1, 0), Palette.IronDark, { Decor = true, Material = M.Metal })
	local light = Instance.new("PointLight")
	light.Color = Palette.Lamp
	light.Range = 18
	light.Brightness = 1.2
	light.Shadows = true
	light.Parent = flame
end

builders.Flag = function(m, opts, col)
	cylinder(m, "Main", 7, 0.3, CFrame.new(0, -H + 3.5, 0), Palette.WoodDark, { Material = M.Wood })
	addPart(m, "Cloth", Vector3.new(0.1, 1.8, 2.8), CFrame.new(0, -H + 6, 1.45) * CFrame.Angles(0, math.rad(6), 0), col.Flag, { Decor = true, Material = M.Fabric })
	if opts.Style == "Pirate" then
		addPart(m, "Skull", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, -H + 6.2, 1.45), Palette.White, { Decor = true, Shape = Enum.PartType.Ball })
		for _, a in { 35, -35 } do
			addPart(m, "Bone", Vector3.new(0.14, 0.18, 1.5), CFrame.new(0, -H + 5.6, 1.45) * CFrame.Angles(math.rad(a), 0, 0), Palette.White, { Decor = true })
		end
	else
		addPart(m, "Emblem", Vector3.new(0.14, 0.8, 0.8), CFrame.new(0, -H + 6, 1.45), Palette.Yellow, { Decor = true, Shape = Enum.PartType.Cylinder })
	end
	addPart(m, "Finial", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -H + 7.1, 0), Palette.Brass, { Decor = true, Shape = Enum.PartType.Ball, Material = M.Metal })
end

function BlockFactory.Create(blockId: string, opts: Options?): Model
	local o: Options = opts or {}
	local model = Instance.new("Model")
	model.Name = blockId
	local builder = builders[blockId] or builders.WoodHull
	builder(model, o, colours(o.Style))
	model.WorldPivot = CFrame.new()
	return model
end

-- A stowed / carried trade crate with the good's icon stencilled on it
function BlockFactory.CreateCrate(icon: string, color: Color3, size: number): Model
	local model = Instance.new("Model")
	model.Name = "Crate"
	local main = addPart(model, "Main", Vector3.new(size, size, size), CFrame.new(), Palette.WoodLight, { Material = M.WoodPlanks })
	local edge = size * 0.12
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			addPart(model, "Edge", Vector3.new(edge, size + 0.04, edge), CFrame.new(x * (size - edge) / 2, 0, z * (size - edge) / 2), Palette.Wood, {
				Decor = true,
				Material = M.Wood,
			})
		end
	end
	addPart(model, "Band", Vector3.new(size + 0.05, edge, size + 0.05), CFrame.new(0, 0, 0), color, { Decor = true, Material = M.Fabric })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 1
		gui.Parent = main
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.7, 0.7)
		label.Position = UDim2.fromScale(0.15, 0.15)
		label.TextScaled = true
		label.Text = icon
		label.Parent = gui
	end
	model.PrimaryPart = main
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
