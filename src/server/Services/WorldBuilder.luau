-- Generates the whole world at server start: lighting, ocean, islands, piers,
-- traders, the home shipyard and all harvestable resource nodes.
--
-- The look is "clean comic": smooth plastic, saturated colours, chunky rounded
-- shapes, crisp shadows, strong colour grading and dark outlines (added on the
-- client by OutlineController for everything tagged "Outline").

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Islands = require(Shared.Islands)
local Palette = require(Shared.Palette)

local WorldBuilder = {}

local Terrain = Workspace.Terrain
local SMOOTH = Enum.SurfaceType.Smooth
local VERTICAL = CFrame.Angles(0, 0, math.pi / 2)
local UP = Vector3.new(0, 1, 0)

local worldFolder: Folder

--------------------------------------------------------------------------------
-- Part helpers
--------------------------------------------------------------------------------

-- Props pick a realistic material from their palette colour unless told otherwise,
-- so foliage reads as foliage, stone as stone and timber as timber.
local M = Enum.Material
local MATERIAL_BY_COLOUR = {
	[Palette.Leaf] = M.Grass,
	[Palette.LeafDark] = M.Grass,
	[Palette.LeafLight] = M.Grass,
	[Palette.Pine] = M.Grass,
	[Palette.Trunk] = M.Wood,
	[Palette.PalmTrunk] = M.Wood,
	[Palette.Wood] = M.WoodPlanks,
	[Palette.WoodLight] = M.WoodPlanks,
	[Palette.WoodDark] = M.Wood,
	[Palette.Rock] = M.Slate,
	[Palette.RockDark] = M.Slate,
	[Palette.Stone] = M.Cobblestone,
	[Palette.Snow] = M.Snow,
	[Palette.Plaster] = M.Plaster,
	[Palette.Cream] = M.Plaster,
	[Palette.RoofTile] = M.ClayRoofTiles,
	[Palette.Iron] = M.Metal,
	[Palette.IronDark] = M.Metal,
	[Palette.Ink] = M.Metal,
	[Palette.Brass] = M.Metal,
	[Palette.Rope] = M.Fabric,
	[Palette.Sail] = M.Fabric,
}

local function newPart(parent: Instance, props): BasePart
	local p = Instance.new(props.ClassName or "Part")
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Material = props.Material or MATERIAL_BY_COLOUR[props.Color] or M.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" and key ~= "Shape" and key ~= "Material" then
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function vcyl(parent, name, pos: Vector3, height: number, diameter: number, color: Color3, extra)
	local props = extra or {}
	props.Name = name
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(pos) * VERTICAL
	props.Color = color
	return newPart(parent, props)
end

local function ball(parent, name, pos: Vector3, diameter: number, color: Color3, extra)
	local props = extra or {}
	props.Name = name
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.CFrame = CFrame.new(pos)
	props.Color = color
	return newPart(parent, props)
end

local function newModel(parent: Instance, name: string, outline: boolean?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	if outline ~= false then
		CollectionService:AddTag(m, "Outline")
	end
	return m
end

local function comicBillboard(parent: Instance, title: string, subtitle: string?, offset: number, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = maxDistance or 120
	gui.LightInfluence = 0
	gui.Parent = parent

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.6, 0)
	name.Position = UDim2.fromScale(0, if subtitle then 0.4 else 0.2)
	name.Font = Enum.Font.Merriweather
	name.TextScaled = true
	name.Text = title
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Palette.Ink
	stroke.Parent = name

	if subtitle then
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.new(1, 0, 0.38, 0)
		sub.Font = Enum.Font.GothamMedium
		sub.TextScaled = true
		sub.Text = subtitle
		sub.TextColor3 = Palette.Yellow
		sub.Parent = gui
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 2
		s2.Color = Palette.Ink
		s2.Parent = sub
	end
	return gui
end

local function groundAt(x: number, z: number): (number, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Terrain }
	params.IgnoreWater = true
	local result = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), params)
	if result then
		return result.Position.Y, result.Material
	end
	return -Config.OCEAN_DEPTH, nil
end

local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1)
	return (ap - ab * t).Magnitude
end

--------------------------------------------------------------------------------
-- Lighting & atmosphere
--------------------------------------------------------------------------------

local function setupLighting()
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(96, 96, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 30
	Lighting.ExposureCompensation = 0

	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 11
	sky.MoonAngularSize = 9
	sky.StarCount = 2500
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "SeaAir"
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(199, 214, 226)
	atmosphere.Decay = Color3.fromRGB(106, 128, 150)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Grade"
	grade.Saturation = 0.08
	grade.Contrast = 0.08
	grade.Brightness = 0
	grade.TintColor = Color3.fromRGB(255, 251, 244)
	grade.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 28
	bloom.Threshold = 1.8
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.6
	rays.Parent = Lighting
end

local function setupTerrainLook()
	Terrain.WaterColor = Palette.Water
	Terrain.WaterTransparency = 0.4
	Terrain.WaterReflectance = 0.6
	Terrain.WaterWaveSize = 0.55
	Terrain.WaterWaveSpeed = 12

	Terrain:SetMaterialColor(Enum.Material.Grass, Palette.Grass)
	Terrain:SetMaterialColor(Enum.Material.Sand, Palette.Sand)
	Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(122, 118, 112))
	Terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(78, 74, 76))
	Terrain:SetMaterialColor(Enum.Material.Snow, Palette.Snow)
	Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(116, 92, 66))

	local clouds = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.6
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = Terrain
end

local function fillOcean()
	local size = Config.OCEAN_SIZE
	local chunk = 400
	local depth = Config.OCEAN_DEPTH
	local half = size / 2
	local x = -half
	while x < half do
		local z = -half
		while z < half do
			local w = math.min(chunk, half - x)
			local d = math.min(chunk, half - z)
			local cx, cz = x + w / 2, z + d / 2
			Terrain:FillBlock(CFrame.new(cx, Config.SEA_LEVEL - depth / 2, cz), Vector3.new(w, depth, d), Enum.Material.Water)
			Terrain:FillBlock(CFrame.new(cx, Config.SEA_LEVEL - depth - 4, cz), Vector3.new(w, 8, d), Enum.Material.Sand)
			z += chunk
		end
		x += chunk
		task.wait() -- keep the server responsive while filling
	end
end

--------------------------------------------------------------------------------
-- Island terrain
--------------------------------------------------------------------------------

local function sculptIsland(def, rng: Random)
	local c = def.Position
	local R = def.Radius
	local sea = Config.SEA_LEVEL

	-- Shallow shelf: makes the water around islands glow turquoise
	Terrain:FillCylinder(CFrame.new(c.X, sea - 22, c.Z), 28, R + 45, Enum.Material.Sand)
	-- Beach
	Terrain:FillCylinder(CFrame.new(c.X, sea - 12, c.Z), 30, R, Enum.Material.Sand)

	if def.Biome == "Home" then
		Terrain:FillBall(Vector3.new(c.X, sea - R * 0.55, c.Z - R * 0.1), R * 0.78, Enum.Material.Grass)
		Terrain:FillBall(Vector3.new(c.X - R * 0.3, sea - R * 0.2, c.Z - R * 0.25), R * 0.5, Enum.Material.Grass)
	elseif def.Biome == "Tropical" then
		Terrain:FillBall(Vector3.new(c.X, sea - R * 0.5, c.Z), R * 0.7, Enum.Material.Grass)
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local off = Vector3.new(math.cos(a), 0, math.sin(a)) * R * 0.3
			Terrain:FillBall(Vector3.new(c.X, sea - R * 0.25, c.Z) + off, R * 0.35, Enum.Material.Grass)
		end
	elseif def.Biome == "Rocky" then
		Terrain:FillBall(Vector3.new(c.X, sea - R * 0.5, c.Z), R * 0.8, Enum.Material.Ground)
		Terrain:FillBall(Vector3.new(c.X - R * 0.15, sea - R * 0.25, c.Z + R * 0.1), R * 0.6, Enum.Material.Rock)
		for _ = 1, 4 do
			local a = rng:NextNumber(0, math.pi * 2)
			local off = Vector3.new(math.cos(a), 0, math.sin(a)) * R * rng:NextNumber(0.25, 0.5)
			Terrain:FillBall(Vector3.new(c.X, sea - R * 0.05, c.Z) + off, R * rng:NextNumber(0.18, 0.3), Enum.Material.Basalt)
		end
	elseif def.Biome == "Snowy" then
		Terrain:FillBall(Vector3.new(c.X, sea - R * 0.5, c.Z), R * 0.8, Enum.Material.Grass)
		Terrain:FillBall(Vector3.new(c.X, sea + R * 0.05, c.Z - R * 0.1), R * 0.45, Enum.Material.Rock)
		Terrain:FillBall(Vector3.new(c.X, sea + R * 0.28, c.Z - R * 0.1), R * 0.3, Enum.Material.Snow)
		Terrain:FillBall(Vector3.new(c.X, sea - R * 0.42, c.Z), R * 0.72, Enum.Material.Snow)
		Terrain:FillBall(Vector3.new(c.X, sea - R * 0.5, c.Z), R * 0.7, Enum.Material.Grass)
	end
end

--------------------------------------------------------------------------------
-- Props
--------------------------------------------------------------------------------

local function makeOak(parent, pos: Vector3, rng: Random)
	local m = newModel(parent, "Oak")
	local scale = rng:NextNumber(0.85, 1.2)
	local stump = vcyl(m, "Stump", pos + Vector3.new(0, 0.8, 0), 2, 2 * scale, Palette.Trunk)
	vcyl(m, "Yield", pos + Vector3.new(0, 4.5 * scale, 0), 6 * scale, 1.6 * scale, Palette.Trunk)
	local top = pos + Vector3.new(0, 9 * scale, 0)
	ball(m, "Yield", top, 8 * scale, Palette.Leaf)
	ball(m, "Yield", top + Vector3.new(2.6, -1, 1) * scale, 6 * scale, Palette.LeafDark)
	ball(m, "Yield", top + Vector3.new(-2.4, -0.6, -1.4) * scale, 6.4 * scale, Palette.Leaf)
	ball(m, "Yield", top + Vector3.new(0.5, 2.2, -0.5) * scale, 5 * scale, Color3.fromRGB(130, 210, 90))
	m.PrimaryPart = stump
	m:SetAttribute("Resource", "Wood")
	CollectionService:AddTag(m, "HarvestNode")
	return m
end

local function makePine(parent, pos: Vector3, rng: Random, snowy: boolean)
	local m = newModel(parent, "Pine")
	local scale = rng:NextNumber(0.85, 1.25)
	local stump = vcyl(m, "Stump", pos + Vector3.new(0, 0.8, 0), 2, 1.8 * scale, Palette.Trunk)
	vcyl(m, "Yield", pos + Vector3.new(0, 3 * scale, 0), 3 * scale, 1.2 * scale, Palette.Trunk)
	local tiers = { { 4.5, 9 }, { 7.2, 6.8 }, { 9.7, 4.6 }, { 11.8, 2.4 } }
	for _, tier in tiers do
		local y, d = tier[1] * scale, tier[2] * scale
		vcyl(m, "Yield", pos + Vector3.new(0, y, 0), 2.6 * scale, d, Palette.Pine)
		if snowy then
			vcyl(m, "Yield", pos + Vector3.new(0, y + 1.4 * scale, 0), 0.5, d * 0.8, Palette.Snow)
		end
	end
	m.PrimaryPart = stump
	m:SetAttribute("Resource", "Wood")
	CollectionService:AddTag(m, "HarvestNode")
	return m
end

local function makePalm(parent, pos: Vector3, rng: Random)
	local m = newModel(parent, "Palm")
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * 0.55
	local p = pos
	local stump
	for i = 1, 6 do
		local nextP = p + Vector3.new(0, 2.4, 0) + lean * (i * 0.18)
		local mid = (p + nextP) / 2
		local seg = newPart(m, {
			Name = if i == 1 then "Stump" else "Yield",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new((nextP - p).Magnitude + 0.3, 1.6 - i * 0.08, 1.6 - i * 0.08),
			CFrame = CFrame.lookAt(mid, nextP) * CFrame.Angles(0, math.pi / 2, 0),
			Color = if i % 2 == 0 then Palette.PalmTrunk else Color3.fromRGB(184, 138, 86),
		})
		if i == 1 then
			stump = seg
		end
		p = nextP
	end
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local frond = CFrame.new(p) * CFrame.Angles(0, a, 0) * CFrame.Angles(-0.45, 0, 0) * CFrame.new(0, 0, -4)
		newPart(m, {
			Name = "Yield",
			Size = Vector3.new(2.2, 0.3, 8.5),
			CFrame = frond,
			Color = if i % 2 == 0 then Palette.Leaf else Palette.LeafDark,
			CanCollide = false,
		})
	end
	ball(m, "Yield", p + Vector3.new(0.6, -0.8, 0.3), 1.1, Palette.WoodDark, { CanCollide = false })
	ball(m, "Yield", p + Vector3.new(-0.5, -0.9, -0.4), 1.1, Palette.WoodDark, { CanCollide = false })
	m.PrimaryPart = stump
	m:SetAttribute("Resource", "Wood")
	CollectionService:AddTag(m, "HarvestNode")
	return m
end

local function makeFlaxBush(parent, pos: Vector3, rng: Random)
	local m = newModel(parent, "FlaxBush")
	local base = ball(m, "Base", pos + Vector3.new(0, 0.4, 0), 1.6, Palette.LeafDark)
	for i = 1, 4 do
		local a = i * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * 1.1
		ball(m, "Yield", pos + off + Vector3.new(0, 1.3, 0), rng:NextNumber(2.4, 3), Color3.fromRGB(150, 210, 90))
	end
	for i = 1, 5 do
		local off = Vector3.new(rng:NextNumber(-1.6, 1.6), rng:NextNumber(2.4, 3.2), rng:NextNumber(-1.6, 1.6))
		ball(m, "Yield", pos + off, 0.7, Color3.fromRGB(120, 170, 255), { CanCollide = false })
	end
	m.PrimaryPart = base
	m:SetAttribute("Resource", "Fiber")
	CollectionService:AddTag(m, "HarvestNode")
	return m
end

local function makeIronRock(parent, pos: Vector3, rng: Random)
	local m = newModel(parent, "IronRock")
	local base = newPart(m, {
		Name = "Base",
		Size = Vector3.new(5, 3.6, 4.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), 0.15),
		Color = Palette.RockDark,
	})
	newPart(m, {
		Name = "Cap",
		Size = Vector3.new(3.6, 2.4, 3.2),
		CFrame = CFrame.new(pos + Vector3.new(0.4, 3, -0.2)) * CFrame.Angles(0.3, rng:NextNumber(0, 6), -0.2),
		Color = Palette.Rock,
	})
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		local off = Vector3.new(math.cos(a) * 2.2, rng:NextNumber(1.5, 3.5), math.sin(a) * 2.2)
		newPart(m, {
			Name = "Yield",
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.new(pos + off) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Color = Palette.Ore,
			Material = Enum.Material.Neon,
		})
	end
	m.PrimaryPart = base
	m:SetAttribute("Resource", "Iron")
	CollectionService:AddTag(m, "HarvestNode")
	return m
end

local function makeRock(parent, pos: Vector3, rng: Random, size: number)
	local m = newModel(parent, "Rock")
	newPart(m, {
		Name = "Rock",
		Size = Vector3.new(size, size * 0.7, size * 0.9),
		CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
		Color = Palette.Rock,
	})
	newPart(m, {
		Name = "Rock",
		Size = Vector3.new(size * 0.6, size * 0.5, size * 0.6),
		CFrame = CFrame.new(pos + Vector3.new(size * 0.35, size * 0.1, size * 0.2)) * CFrame.Angles(0.4, rng:NextNumber(0, 6), 0.2),
		Color = Palette.RockDark,
	})
	return m
end

local function makeHut(parent, cf: CFrame, wallColor: Color3, roofColor: Color3)
	local m = newModel(parent, "Hut")
	newPart(m, { Name = "Floor", Size = Vector3.new(12, 1.2, 11), CFrame = cf * CFrame.new(0, 0.6, 0), Color = Palette.WoodDark })
	newPart(m, { Name = "Walls", Size = Vector3.new(10, 7, 9), CFrame = cf * CFrame.new(0, 4.7, 0), Color = wallColor })
	newPart(m, { Name = "Door", Size = Vector3.new(2.6, 4.6, 0.3), CFrame = cf * CFrame.new(0, 3.5, -4.55), Color = Palette.WoodDark })
	newPart(m, { Name = "Knob", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = cf * CFrame.new(0.8, 3.4, -4.75), Color = Palette.Yellow, Shape = Enum.PartType.Ball })
	for _, x in { -3.3, 3.3 } do
		newPart(m, { Name = "Window", Size = Vector3.new(1.8, 1.8, 0.3), CFrame = cf * CFrame.new(x, 5, -4.55), Color = Color3.fromRGB(150, 220, 255), Material = Enum.Material.Glass, Transparency = 0.2 })
		newPart(m, { Name = "Sill", Size = Vector3.new(2.3, 0.3, 0.5), CFrame = cf * CFrame.new(x, 3.95, -4.65), Color = Palette.White })
	end
	-- Gable roof from two wedges
	for _, side in { -1, 1 } do
		newPart(m, {
			ClassName = "WedgePart",
			Name = "Roof",
			Size = Vector3.new(11, 4, 6),
			CFrame = cf * CFrame.new(0, 10.2, side * 2.75) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
			Color = roofColor,
		})
	end
	vcyl(m, "Chimney", (cf * CFrame.new(3, 11, 2)).Position, 3, 1.4, Palette.RockDark)
	return m
end

local function makeLighthouse(parent, pos: Vector3)
	local m = newModel(parent, "Lighthouse")
	local y = pos.Y
	local segments = 6
	for i = 1, segments do
		local d = 9 - i * 0.6
		vcyl(m, "Tower", Vector3.new(pos.X, y + 2.5, pos.Z), 5, d, if i % 2 == 1 then Palette.White else Palette.Red)
		y += 5
	end
	vcyl(m, "Gallery", Vector3.new(pos.X, y + 0.4, pos.Z), 0.8, 8, Palette.Ink)
	local lamp = vcyl(m, "Lamp", Vector3.new(pos.X, y + 2.6, pos.Z), 3.6, 3.6, Palette.Lamp, { Material = Enum.Material.Neon })
	vcyl(m, "Roof", Vector3.new(pos.X, y + 4.9, pos.Z), 1, 5.2, Palette.Red)
	ball(m, "Tip", Vector3.new(pos.X, y + 5.8, pos.Z), 1.6, Palette.Ink)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 2
	light.Color = Palette.Lamp
	light.Parent = lamp
	local beam = Instance.new("SpotLight")
	beam.Range = 60
	beam.Angle = 40
	beam.Brightness = 4
	beam.Color = Palette.Lamp
	beam.Face = Enum.NormalId.Front
	beam.Parent = lamp
	lamp:SetAttribute("Spin", true)
	CollectionService:AddTag(lamp, "Spinner")
	return m
end

local function makePier(parent, def)
	local m = newModel(parent, "Pier")
	local dir = def.DockDirection
	local length = if def.Home then Islands.HOME_PIER_LENGTH else Islands.PIER_LENGTH
	local width = if def.Home then 10 else 9
	local start = def.Position + dir * (def.Radius - 14)
	local finish = def.Position + dir * (def.Radius + length)
	local deckY = Config.SEA_LEVEL + 3.5
	start = Vector3.new(start.X, deckY, start.Z)
	finish = Vector3.new(finish.X, deckY, finish.Z)
	local total = (finish - start).Magnitude
	local frame = CFrame.lookAt((start + finish) / 2, finish)

	newPart(m, { Name = "Deck", Size = Vector3.new(width, 1, total), CFrame = frame, Color = Palette.WoodLight })
	for _, side in { -1, 1 } do
		newPart(m, {
			Name = "Beam",
			Size = Vector3.new(0.8, 1.4, total),
			CFrame = frame * CFrame.new(side * (width / 2 + 0.2), -0.3, 0),
			Color = Palette.Wood,
		})
	end
	local postSpacing = 12
	for i = 0, math.floor(total / postSpacing) do
		local along = -total / 2 + i * postSpacing
		for _, side in { -1, 1 } do
			local p = (frame * CFrame.new(side * (width / 2 + 0.3), 0, along)).Position
			vcyl(m, "Post", Vector3.new(p.X, deckY - 8, p.Z), 18, 1.3, Palette.WoodDark)
			if i % 2 == 0 then
				ball(m, "PostCap", Vector3.new(p.X, deckY + 1.2, p.Z), 1.2, Palette.WoodDark)
			end
		end
	end

	-- Lamp posts every so often
	for i = 1, math.floor(total / 60) + 1 do
		local along = -total / 2 + 20 + (i - 1) * 60
		if along < total / 2 then
			local p = (frame * CFrame.new(-width / 2 + 0.8, 0, along)).Position
			vcyl(m, "LampPost", Vector3.new(p.X, deckY + 3.5, p.Z), 6, 0.5, Palette.Ink)
			local lamp = newPart(m, {
				Name = "LampGlow",
				Size = Vector3.new(1.2, 1.4, 1.2),
				CFrame = CFrame.new(p.X, deckY + 7.1, p.Z),
				Color = Palette.Lamp,
				Material = Enum.Material.Neon,
			})
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 1.2
			light.Color = Palette.Lamp
			light.Parent = lamp
		end
	end

	-- Island name sign at the tip
	local tip = newPart(m, {
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(finish + Vector3.new(0, 4, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	comicBillboard(tip, def.Name, if def.Home then "Home Harbour" else "Trading Post", 3, 600)

	return m, start, finish
end

local function makeBuoy(parent, pos: Vector3, color: Color3)
	local m = newModel(parent, "Buoy")
	vcyl(m, "Float", Vector3.new(pos.X, Config.SEA_LEVEL + 0.4, pos.Z), 2.4, 3, color)
	vcyl(m, "Band", Vector3.new(pos.X, Config.SEA_LEVEL + 1.6, pos.Z), 0.6, 3.05, Palette.White)
	vcyl(m, "Pole", Vector3.new(pos.X, Config.SEA_LEVEL + 3.5, pos.Z), 3, 0.4, Palette.Ink)
	ball(m, "Top", Vector3.new(pos.X, Config.SEA_LEVEL + 5.2, pos.Z), 0.9, color, { Material = Enum.Material.Neon })
	return m
end

-- A chunky cartoon NPC built from parts. Faces -Z of feetCF.
local function makeNPC(parent, name: string, title: string, feetCF: CFrame, shirt: Color3, hat: Color3)
	local m = newModel(parent, name)
	local function p(n, size, offset, color, shape)
		return newPart(m, { Name = n, Size = size, CFrame = feetCF * offset, Color = color, Shape = shape })
	end
	local pants = Color3.fromRGB(60, 64, 90)
	p("LegL", Vector3.new(0.9, 2.4, 0.9), CFrame.new(-0.55, 1.2, 0), pants)
	p("LegR", Vector3.new(0.9, 2.4, 0.9), CFrame.new(0.55, 1.2, 0), pants)
	local torso = p("Torso", Vector3.new(2.3, 2.5, 1.4), CFrame.new(0, 3.65, 0), shirt)
	p("Belt", Vector3.new(2.4, 0.4, 1.5), CFrame.new(0, 2.6, 0), Palette.WoodDark)
	p("Buckle", Vector3.new(0.6, 0.45, 0.2), CFrame.new(0, 2.6, -0.76), Palette.Yellow)
	p("ArmL", Vector3.new(0.8, 2.3, 0.8), CFrame.new(-1.6, 3.6, 0) * CFrame.Angles(0, 0, math.rad(-10)), shirt)
	p("ArmR", Vector3.new(0.8, 2.3, 0.8), CFrame.new(1.6, 3.6, 0) * CFrame.Angles(0, 0, math.rad(10)), shirt)
	p("HandL", Vector3.new(0.8, 0.8, 0.8), CFrame.new(-1.8, 2.3, 0), Palette.Skin, Enum.PartType.Ball)
	p("HandR", Vector3.new(0.8, 0.8, 0.8), CFrame.new(1.8, 2.3, 0), Palette.Skin, Enum.PartType.Ball)
	p("Head", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 6, 0), Palette.Skin, Enum.PartType.Ball)
	p("EyeL", Vector3.new(0.34, 0.34, 0.34), CFrame.new(-0.4, 6.15, -1.0), Palette.Ink, Enum.PartType.Ball)
	p("EyeR", Vector3.new(0.34, 0.34, 0.34), CFrame.new(0.4, 6.15, -1.0), Palette.Ink, Enum.PartType.Ball)
	p("Nose", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 5.85, -1.1), Color3.fromRGB(246, 170, 130), Enum.PartType.Ball)
	newPart(m, {
		Name = "HatBrim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 3.2, 3.2),
		CFrame = feetCF * CFrame.new(0, 7, 0) * VERTICAL,
		Color = hat,
	})
	newPart(m, {
		Name = "HatTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, 2, 2),
		CFrame = feetCF * CFrame.new(0, 7.7, 0) * VERTICAL,
		Color = hat,
	})
	m.PrimaryPart = torso
	comicBillboard(torso, name, title, 5.5, 90)
	return m, torso
end

local function addPrompt(part: BasePart, action: string, object: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = part
	return prompt
end

local function makeStall(parent, def, cf: CFrame)
	local m = newModel(parent, "MarketStall")
	local accent = def.Stall
	newPart(m, { Name = "Floor", Size = Vector3.new(14, 1, 10), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Palette.WoodDark })
	newPart(m, { Name = "Counter", Size = Vector3.new(12, 3.4, 2), CFrame = cf * CFrame.new(0, 2.7, -3), Color = Palette.Wood })
	newPart(m, { Name = "CounterTop", Size = Vector3.new(12.6, 0.5, 2.6), CFrame = cf * CFrame.new(0, 4.6, -3), Color = Palette.WoodLight })
	for _, x in { -6, 6 } do
		for _, z in { -4, 4 } do
			vcyl(m, "Post", (cf * CFrame.new(x, 5, z)).Position, 9, 0.7, Palette.WoodDark)
		end
	end
	-- Striped awning
	for i = 0, 6 do
		newPart(m, {
			Name = "Awning",
			Size = Vector3.new(2.1, 0.4, 11.4),
			CFrame = cf * CFrame.new(-6.3 + i * 2.1, 9.8, -0.4) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = if i % 2 == 0 then accent else Palette.White,
		})
	end
	-- Goods on display
	local displayColors = { Palette.Orange, Palette.Yellow, Palette.Red, Palette.Green }
	for i = 1, 4 do
		local x = -5 + (i - 1) * 3.3
		newPart(m, {
			Name = "Crate",
			Size = Vector3.new(2.2, 2, 2.2),
			CFrame = cf * CFrame.new(x, 2, -5.6) * CFrame.Angles(0, math.rad(i * 9), 0),
			Color = Palette.WoodLight,
		})
		ball(m, "Goods", (cf * CFrame.new(x, 3.3, -5.6)).Position, 1.3, displayColors[i])
	end
	local sign = newPart(m, {
		Name = "SignBoard",
		Size = Vector3.new(8, 2, 0.4),
		CFrame = cf * CFrame.new(0, 11.6, -5),
		Color = Palette.Cream,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Merriweather
	label.TextScaled = true
	label.Text = "TRADER"
	label.TextColor3 = accent
	label.Parent = surface
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Palette.Ink
	stroke.Parent = label

	local npc, torso = makeNPC(parent, def.Trader.Name, "🛒 Trader", cf * CFrame.new(0, 1, 0.5), def.Trader.Shirt, def.Trader.Hat)
	npc:SetAttribute("IslandId", def.Id)
	CollectionService:AddTag(npc, "Trader")
	local trade = addPrompt(torso, "Trade", def.Trader.Name)
	trade.Name = "TradePrompt"
	trade:SetAttribute("Need", "Empty")
	CollectionService:AddTag(trade, "FilteredPrompt")
	local sell = addPrompt(torso, "Sell crate", def.Trader.Name)
	sell.Name = "SellPrompt"
	sell:SetAttribute("Need", "Crate")
	CollectionService:AddTag(sell, "FilteredPrompt")

	-- Loading pad: bought crates appear here
	local padCF = cf * CFrame.new(0, 0.3, -16)
	local pad = newPart(m, {
		Name = "CratePad",
		Size = Vector3.new(12, 0.6, 9),
		CFrame = padCF,
		Color = Palette.WoodLight,
	})
	pad:SetAttribute("IslandId", def.Id)
	CollectionService:AddTag(pad, "CratePad")
	for _, x in { -5.6, 5.6 } do
		newPart(m, { Name = "PadEdge", Size = Vector3.new(0.6, 0.8, 9.2), CFrame = padCF * CFrame.new(x, 0.3, 0), Color = Palette.WoodDark })
	end
	local padSign = newPart(m, { Name = "PadSign", Size = Vector3.new(1, 1, 1), CFrame = padCF * CFrame.new(0, 5, 0), Transparency = 1, CanCollide = false })
	comicBillboard(padSign, "Loading Pad", "your crates appear here", 0, 60)
	return m
end

local function makeShipwright(parent, cf: CFrame)
	local m = newModel(parent, "Shipyard")
	newPart(m, { Name = "Floor", Size = Vector3.new(22, 1, 16), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Palette.WoodDark })
	for _, x in { -10, 10 } do
		for _, z in { -7, 7 } do
			vcyl(m, "Post", (cf * CFrame.new(x, 6, z)).Position, 11, 1, Palette.Wood)
		end
	end
	for _, side in { -1, 1 } do
		newPart(m, {
			ClassName = "WedgePart",
			Name = "Roof",
			Size = Vector3.new(24, 4, 9),
			CFrame = cf * CFrame.new(0, 13.5, side * 4.5) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
			Color = Palette.Red,
		})
	end
	-- Workbench with tools and timber
	newPart(m, { Name = "Bench", Size = Vector3.new(8, 3, 3), CFrame = cf * CFrame.new(-4, 2.5, -4), Color = Palette.Wood })
	newPart(m, { Name = "Saw", Size = Vector3.new(2.6, 0.2, 1), CFrame = cf * CFrame.new(-5, 4.1, -4), Color = Palette.Iron })
	ball(m, "Hammer", (cf * CFrame.new(-2.5, 4.3, -4)).Position, 0.8, Palette.IronDark)
	for i = 0, 3 do
		newPart(m, {
			Name = "Timber",
			Size = Vector3.new(1, 1, 8),
			CFrame = cf * CFrame.new(5 + (i % 2) * 1.1, 1.5 + math.floor(i / 2), 1),
			Color = Palette.WoodLight,
		})
	end
	local sign = newPart(m, { Name = "SignBoard", Size = Vector3.new(14, 2.6, 0.4), CFrame = cf * CFrame.new(0, 12, -8.4), Color = Palette.Cream })
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Merriweather
	label.TextScaled = true
	label.Text = "SHIPWRIGHT"
	label.TextColor3 = Palette.Red
	label.Parent = surface
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Palette.Ink
	stroke.Parent = label

	local npc, torso = makeNPC(parent, "Bosun Bertha", "🔨 Shipwright", cf * CFrame.new(3, 1, -3), Palette.Orange, Palette.Ink)
	CollectionService:AddTag(npc, "Shipwright")
	addPrompt(torso, "Shop", "Bosun Bertha")
	return m
end

--------------------------------------------------------------------------------
-- Island assembly
--------------------------------------------------------------------------------

local function buildIsland(def)
	local rng = Random.new(#def.Id * 7919 + math.floor(def.Position.X))
	local folder = Instance.new("Folder")
	folder.Name = def.Id
	folder.Parent = worldFolder

	sculptIsland(def, rng)

	local c = def.Position
	local R = def.Radius
	local dir = def.DockDirection
	local right = dir:Cross(UP).Unit

	local _, pierStart, pierEnd = makePier(folder, def)

	local blocked = {} -- { {pos, radius} }
	local function block(pos: Vector3, radius: number)
		table.insert(blocked, { pos, radius })
	end
	local function onGround(pos: Vector3): CFrame
		local y = groundAt(pos.X, pos.Z)
		local flat = Vector3.new(pos.X, y, pos.Z)
		return CFrame.lookAt(flat, flat + dir)
	end

	-- Trader stall at the foot of the pier
	local stallPos = c + dir * (R - 30) - right * 16
	makeStall(folder, def, onGround(stallPos))
	block(stallPos, 16)

	if def.Home then
		local yardPos = c + dir * (R - 30) + right * 20
		makeShipwright(folder, onGround(yardPos))
		block(yardPos, 18)

		local lighthousePos = c + Vector3.new(-R * 0.3, 0, -R * 0.25)
		local ly = groundAt(lighthousePos.X, lighthousePos.Z)
		makeLighthouse(folder, Vector3.new(lighthousePos.X, ly - 1, lighthousePos.Z))
		block(lighthousePos, 12)

		local hutColors = { { Palette.Plaster, Palette.RoofTile }, { Palette.Cream, Palette.RoofTile }, { Palette.Plaster, Palette.WoodDark } }
		local hutSpots = { Vector3.new(30, 0, -20), Vector3.new(-45, 0, 20), Vector3.new(12, 0, -48) }
		for i, offset in hutSpots do
			local pos = c + offset
			local y = groundAt(pos.X, pos.Z)
			local flat = Vector3.new(pos.X, y - 0.5, pos.Z)
			makeHut(folder, CFrame.lookAt(flat, Vector3.new(c.X, flat.Y, c.Z + R)), hutColors[i][1], hutColors[i][2])
			block(pos, 12)
		end

		local spawnPos = c + dir * (R - 44)
		local sy = groundAt(spawnPos.X, spawnPos.Z)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "HarbourSpawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.CFrame = CFrame.lookAt(Vector3.new(spawnPos.X, sy + 0.5, spawnPos.Z), Vector3.new(spawnPos.X, sy + 0.5, spawnPos.Z) + dir)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Color = Palette.WoodLight
		spawn.TopSurface = SMOOTH
		spawn.BottomSurface = SMOOTH
		spawn.Parent = folder
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
		block(spawnPos, 12)

		-- Buoys mark the edge of the safe harbour
		local dock = Islands.GetDockPoint(def)
		for i = 0, 23 do
			local a = i / 24 * math.pi * 2
			local pos = dock + Vector3.new(math.cos(a), 0, math.sin(a)) * Islands.HOME_HARBOUR_RADIUS
			if groundAt(pos.X, pos.Z) < -8 then
				makeBuoy(folder, pos, if i % 2 == 0 then Palette.Red else Palette.White)
			end
		end
	else
		makeBuoy(folder, pierEnd + right * 18 + dir * 6, Palette.Red)
		makeBuoy(folder, pierEnd - right * 18 + dir * 6, Palette.Green)
	end

	-- Resource nodes and decoration
	local placed = {}
	local function freeSpot(minR: number, maxR: number, minHeight: number, materials: { Enum.Material }?): Vector3?
		for _ = 1, 40 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber()) * (maxR - minR) + minR
			local x, z = c.X + math.cos(a) * r, c.Z + math.sin(a) * r
			local y, material = groundAt(x, z)
			local pos = Vector3.new(x, y, z)
			local ok = y >= minHeight
			if ok and materials then
				ok = table.find(materials, material) ~= nil
			end
			if ok and distanceToSegment(pos, pierStart, pierEnd) < 14 then
				ok = false
			end
			if ok then
				for _, b in blocked do
					if (Vector3.new(b[1].X, y, b[1].Z) - pos).Magnitude < b[2] then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, other in placed do
					if (other - pos).Magnitude < 9 then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(placed, pos)
				return pos
			end
		end
		return nil
	end

	local landMats = { Enum.Material.Grass, Enum.Material.Ground, Enum.Material.Rock, Enum.Material.Snow, Enum.Material.Basalt }
	local res = def.Resources
	for _ = 1, res.Oak or 0 do
		local pos = freeSpot(0, R * 0.6, 4, { Enum.Material.Grass })
		if pos then
			makeOak(folder, pos - Vector3.new(0, 0.3, 0), rng)
		end
	end
	for _ = 1, res.Pine or 0 do
		local pos = freeSpot(0, R * 0.7, 4, landMats)
		if pos then
			makePine(folder, pos - Vector3.new(0, 0.3, 0), rng, def.Biome == "Snowy")
		end
	end
	for _ = 1, res.Palm or 0 do
		local pos = freeSpot(R * 0.25, R * 0.9, 2.2, nil)
		if pos then
			makePalm(folder, pos - Vector3.new(0, 0.4, 0), rng)
		end
	end
	for _ = 1, res.Bush or 0 do
		local pos = freeSpot(0, R * 0.8, 2.5, nil)
		if pos then
			makeFlaxBush(folder, pos - Vector3.new(0, 0.2, 0), rng)
		end
	end
	for _ = 1, res.Iron or 0 do
		local pos = freeSpot(0, R * 0.75, 3, nil)
		if pos then
			makeIronRock(folder, pos - Vector3.new(0, 0.6, 0), rng)
		end
	end
	for _ = 1, 6 do
		local pos = freeSpot(R * 0.6, R * 1.05, -6, nil)
		if pos then
			makeRock(folder, pos, rng, rng:NextNumber(3, 7))
		end
	end
end

--------------------------------------------------------------------------------
-- Day / night
--------------------------------------------------------------------------------

local function startDayCycle()
	if not Config.DAY_CYCLE_ENABLED then
		return
	end
	local hoursPerSecond = 24 / (Config.DAY_LENGTH_MINUTES * 60)
	local dayAmbient = Color3.fromRGB(150, 150, 165)
	local nightAmbient = Color3.fromRGB(90, 110, 170) -- comic nights stay readable and blue
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local step = accumulator
		accumulator = 0
		local t = Lighting.ClockTime
		-- Nights pass twice as fast as days
		local isNight = t < 6 or t > 18.5
		Lighting.ClockTime = (t + step * hoursPerSecond * (if isNight then 2 else 1)) % 24
		local daylight = math.clamp(math.cos((Lighting.ClockTime - 12) / 12 * math.pi) * 1.4 + 0.5, 0, 1)
		Lighting.OutdoorAmbient = nightAmbient:Lerp(dayAmbient, daylight)
	end)
end

local function startSpinners()
	local angle = 0
	RunService.Heartbeat:Connect(function(dt)
		angle += dt * 0.8
		for _, part in CollectionService:GetTagged("Spinner") do
			local pos = part.Position
			part.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0) * VERTICAL
		end
	end)
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Virtual drydocks
--------------------------------------------------------------------------------

-- Builds a private stone drydock around `origin` sized for the build bounds.
-- Returns the model and a CFrame on the walkway where builders stand.
function WorldBuilder.CreateDrydock(origin: Vector3, bounds, slot: number)
	local g = Config.GRID
	local width = (bounds.MaxX - bounds.MinX + 1) * g + 16
	local length = (bounds.MaxZ - bounds.MinZ + 1) * g + 16
	local centre = origin + Vector3.new((bounds.MinX + bounds.MaxX) / 2 * g, 0, (bounds.MinZ + bounds.MaxZ) / 2 * g)
	local floorY, walkY, wall, walk = -10, 4, 4, 10

	local m = newModel(Workspace, `Drydock{slot}`)
	m:SetAttribute("Drydock", slot)

	local function slab(name, size, pos, color, extra)
		local props = extra or {}
		props.Name = name
		props.Size = size
		props.CFrame = CFrame.new(pos)
		props.Color = color
		return newPart(m, props)
	end

	-- Basin floor and walls
	slab("Floor", Vector3.new(width, 2, length), centre + Vector3.new(0, floorY - 1, 0), Palette.Stone)
	local wallHeight = walkY - floorY
	for _, side in { -1, 1 } do
		slab("WallX", Vector3.new(wall, wallHeight, length + wall * 2), centre + Vector3.new(side * (width / 2 + wall / 2), floorY + wallHeight / 2, 0), Palette.Stone)
		slab("WallZ", Vector3.new(width, wallHeight, wall), centre + Vector3.new(0, floorY + wallHeight / 2, side * (length / 2 + wall / 2)), Palette.Stone)
	end
	-- Walkway all around
	local outerW, outerL = width + (wall + walk) * 2, length + (wall + walk) * 2
	for _, side in { -1, 1 } do
		slab("WalkX", Vector3.new(walk, 1, outerL), centre + Vector3.new(side * (width / 2 + wall + walk / 2), walkY - 0.5, 0), Palette.WoodLight)
		slab("WalkZ", Vector3.new(width + wall * 2, 1, walk), centre + Vector3.new(0, walkY - 0.5, side * (length / 2 + wall + walk / 2)), Palette.WoodLight)
	end
	-- Still water in the basin (purely visual)
	slab("Water", Vector3.new(width, 0.3, length), centre + Vector3.new(0, Config.SEA_LEVEL - 0.15, 0), Palette.Water, {
		Material = M.Glass,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	-- Scaffolding along both long sides
	for _, side in { -1, 1 } do
		local x = side * (width / 2 + wall / 2)
		for z = -length / 2 + 6, length / 2 - 6, 12 do
			vcyl(m, "Scaffold", centre + Vector3.new(x, walkY + 6, z), 12, 0.6, Palette.WoodDark)
		end
		slab("ScaffoldBeam", Vector3.new(0.6, 0.6, length - 8), centre + Vector3.new(x, walkY + 11.5, 0), Palette.WoodDark)
		slab("ScaffoldDeck", Vector3.new(3, 0.4, length - 8), centre + Vector3.new(x - side * 1.2, walkY + 7, 0), Palette.WoodLight)
	end
	-- Lamps on the corners
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = centre + Vector3.new(sx * (width / 2 + wall + walk - 1.5), walkY, sz * (length / 2 + wall + walk - 1.5))
			vcyl(m, "LampPost", p + Vector3.new(0, 4, 0), 8, 0.5, Palette.Ink)
			local lamp = newPart(m, { Name = "Lamp", Size = Vector3.new(1.2, 1.4, 1.2), CFrame = CFrame.new(p + Vector3.new(0, 8.6, 0)), Color = Palette.Lamp, Material = M.Neon })
			local light = Instance.new("PointLight")
			light.Range = 40
			light.Brightness = 1.6
			light.Color = Palette.Lamp
			light.Parent = lamp
		end
	end
	-- Dock clerk sells parts right here
	local clerkFeet = centre + Vector3.new(width / 2 + wall + walk / 2, walkY, length / 2 - 4)
	local clerk, torso = makeNPC(m, "Dock Clerk Pim", "🔨 Parts & Supplies", CFrame.lookAt(clerkFeet, clerkFeet - Vector3.new(1, 0, 0)), Palette.Orange, Palette.Ink)
	addPrompt(torso, "Shop", "Dock Clerk Pim")
	CollectionService:AddTag(clerk, "Shipwright") -- after the prompt exists, the shop hooks it on tag

	local signPart = newPart(m, { Name = "Sign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(centre + Vector3.new(0, walkY + 16, -length / 2)), Transparency = 1, CanCollide = false })
	comicBillboard(signPart, `Drydock {slot}`, "build, then press B to launch", 0, 400)

	local walkwayPos = centre + Vector3.new(width / 2 + wall + walk / 2, walkY + 3, 0)
	return {
		Model = m,
		Walkway = CFrame.lookAt(walkwayPos, Vector3.new(centre.X, walkwayPos.Y, centre.Z)),
	}
end

function WorldBuilder.Build()
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = Workspace

	setupLighting()
	setupTerrainLook()
	fillOcean()
	for _, id in Islands.Order do
		buildIsland(Islands.Defs[id])
		task.wait()
	end
	startDayCycle()
	startSpinners()
end

return WorldBuilder
