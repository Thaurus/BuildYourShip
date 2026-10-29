-- Grid math for ship blueprints. Used by the server for validation and by the
-- client for build previews and the vessel checklist, so both always agree.
--
-- A blueprint is an array of entries: { t = blockId, x = int, y = int, z = int, r = 0..3 }
-- (x, y, z) is the anchor cell; r is the rotation around Y in 90 degree steps.
-- Ship forward (the bow) is -Z, starboard is +X. Row y = 0 is the waterline.

local Config = require(script.Parent.Config)
local Items = require(script.Parent.Items)

local ShipGrid = {}

local NEIGHBOURS = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

function ShipGrid.Key(x: number, y: number, z: number): string
	return `{x},{y},{z}`
end

function ShipGrid.ParseKey(key: string): (number?, number?, number?)
	local x, y, z = string.match(key, "^(-?%d+),(-?%d+),(-?%d+)$")
	return tonumber(x), tonumber(y), tonumber(z)
end

-- Rotates an {x, y, z} offset around Y by r * 90 degrees, matching CFrame.Angles(0, r * pi/2, 0).
function ShipGrid.RotateOffset(offset: { number }, r: number): (number, number, number)
	local x, y, z = offset[1], offset[2], offset[3]
	for _ = 1, r % 4 do
		x, z = z, -x
	end
	return x, y, z
end

function ShipGrid.Footprint(blockId: string, x: number, y: number, z: number, r: number): { Vector3 }
	local def = Items.Get(blockId)
	local cells = {}
	for _, offset in def.Cells do
		local ox, oy, oz = ShipGrid.RotateOffset(offset, r)
		table.insert(cells, Vector3.new(x + ox, y + oy, z + oz))
	end
	return cells
end

function ShipGrid.InBounds(cell: Vector3, bounds): boolean
	local b = bounds or Config.BUILD_BOUNDS
	return cell.X >= b.MinX and cell.X <= b.MaxX and cell.Y >= b.MinY and cell.Y <= b.MaxY and cell.Z >= b.MinZ and cell.Z <= b.MaxZ
end

-- Local CFrame of a block's anchor cell relative to the ship root.
function ShipGrid.CellToCFrame(x: number, y: number, z: number, r: number): CFrame
	local g = Config.GRID
	return CFrame.new(x * g, y * g, z * g) * CFrame.Angles(0, (r or 0) * math.pi / 2, 0)
end

-- Maps every occupied cell key -> blueprint index.
function ShipGrid.BuildOccupancy(blueprint): { [string]: number }
	local occ = {}
	for index, entry in blueprint do
		for _, cell in ShipGrid.Footprint(entry.t, entry.x, entry.y, entry.z, entry.r or 0) do
			occ[ShipGrid.Key(cell.X, cell.Y, cell.Z)] = index
		end
	end
	return occ
end

local function isInteger(n: any): boolean
	return type(n) == "number" and n == n and math.floor(n) == n
end

-- Rotation actually used for a block (bows, sterns, keels and rudders always face forward)
function ShipGrid.EffectiveRotation(blockId: string, r: number): number
	local def = Items.Get(blockId)
	if def and def.Fixed then
		return 0
	end
	return r
end

function ShipGrid.CanPlace(blueprint, occ, blockId: string, x: number, y: number, z: number, r: number, bounds): (boolean, string?)
	local def = Items.Get(blockId)
	if not def or def.Kind ~= "Block" then
		return false, "That is not a ship block."
	end
	if not (isInteger(x) and isInteger(y) and isInteger(z) and isInteger(r)) or r < 0 or r > 3 then
		return false, "Invalid position."
	end
	r = ShipGrid.EffectiveRotation(blockId, r)
	if #blueprint >= Config.MAX_BLOCKS then
		return false, `Your ship is at the {Config.MAX_BLOCKS} block limit!`
	end
	if def.Unique then
		for _, entry in blueprint do
			if entry.t == blockId then
				return false, `Only one {def.Name} per ship.`
			end
		end
	end

	-- Placement rules keep ships looking like ships
	local placement = def.Placement or "Hull"
	if placement == "Keel" then
		if y ~= -1 then
			return false, "Keels go in the row under the waterline."
		end
		local above = occ[ShipGrid.Key(x, 0, z)]
		if not above or not Items.HullTypes[blueprint[above].t] then
			return false, "A keel must sit directly under a hull block."
		end
	elseif y < 0 then
		return false, "Only keels go below the waterline."
	end
	if placement == "Mounted" then
		if y < 1 then
			return false, `{def.Name} goes on deck, on top of the hull.`
		end
		if not occ[ShipGrid.Key(x, y - 1, z)] then
			return false, `{def.Name} needs something solid underneath.`
		end
	end

	local footprint = ShipGrid.Footprint(blockId, x, y, z, r)
	local own = {}
	for _, cell in footprint do
		if not ShipGrid.InBounds(cell, bounds) then
			return false, "Outside the shipyard frame."
		end
		local key = ShipGrid.Key(cell.X, cell.Y, cell.Z)
		if occ[key] then
			return false, "Something is already there."
		end
		own[key] = true
	end

	-- Must touch an existing block so the ship stays in one piece.
	for _, cell in footprint do
		for _, dir in NEIGHBOURS do
			local n = cell + dir
			local key = ShipGrid.Key(n.X, n.Y, n.Z)
			if occ[key] and not own[key] then
				return true, nil
			end
		end
	end
	return false, "Blocks must attach to your ship."
end

-- Returns the blueprint index that would be removed, or nil + reason.
function ShipGrid.CanRemove(blueprint, occ, x: number, y: number, z: number): (number?, string?)
	local index = occ[ShipGrid.Key(x, y, z)]
	if not index then
		return nil, "Nothing to remove there."
	end
	local entry = blueprint[index]
	if Items.Get(entry.t).Unique then
		return nil, "Your ship needs its helm!"
	end

	-- Anything standing on this block would lose its support
	for i, other in blueprint do
		if i ~= index then
			local otherDef = Items.Get(other.t)
			if otherDef.Placement == "Mounted" and occ[ShipGrid.Key(other.x, other.y - 1, other.z)] == index then
				return nil, `Remove the {otherDef.Name} on top first.`
			end
			if otherDef.Placement == "Keel" and occ[ShipGrid.Key(other.x, 0, other.z)] == index then
				return nil, "Remove the keel underneath first."
			end
		end
	end

	-- Flood fill from the helm without the removed block; everything must still be reachable.
	local start
	for i, e in blueprint do
		if e.t == "Helm" then
			start = Vector3.new(e.x, e.y, e.z)
			break
		end
		if not start and i ~= index then
			start = Vector3.new(e.x, e.y, e.z)
		end
	end
	if not start then
		return index, nil
	end

	local visited = {}
	local reached = { [index] = true }
	local reachedCount = 1
	local queue = { start }
	visited[ShipGrid.Key(start.X, start.Y, start.Z)] = true
	local head = 1
	while head <= #queue do
		local cell = queue[head]
		head += 1
		local owner = occ[ShipGrid.Key(cell.X, cell.Y, cell.Z)]
		if owner and not reached[owner] then
			reached[owner] = true
			reachedCount += 1
		end
		for _, dir in NEIGHBOURS do
			local n = cell + dir
			local key = ShipGrid.Key(n.X, n.Y, n.Z)
			local nIndex = occ[key]
			if not visited[key] and nIndex and nIndex ~= index then
				visited[key] = true
				table.insert(queue, n)
			end
		end
	end

	if reachedCount < #blueprint then
		return nil, "That would break your ship in two!"
	end
	return index, nil
end

--------------------------------------------------------------------------------
-- Vessel check: a ship must look like a ship before it may be launched
--------------------------------------------------------------------------------

export type Rule = { Id: string, Text: string, Ok: boolean }

function ShipGrid.VesselCheck(blueprint): (boolean, { Rule })
	local hasHelm, thrust = false, 0
	local waterline = {}
	local byCell = {}
	for _, e in blueprint do
		local def = Items.Get(e.t)
		if e.t == "Helm" then
			hasHelm = true
		end
		if def.Stats and def.Stats.Thrust then
			thrust += def.Stats.Thrust
		end
		if e.y == 0 and Items.HullTypes[e.t] then
			table.insert(waterline, e)
		end
		byCell[ShipGrid.Key(e.x, e.y, e.z)] = e.t
	end

	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, e in waterline do
		minX, maxX = math.min(minX, e.x), math.max(maxX, e.x)
		minZ, maxZ = math.min(minZ, e.z), math.max(maxZ, e.z)
	end

	local bowOk = #waterline > 0
	local bowCentre = false
	for _, e in waterline do
		if e.z == minZ then
			if e.t ~= "Bow" then
				bowOk = false
			elseif e.x == 0 then
				bowCentre = true
			end
		end
	end

	local length = if #waterline > 0 then maxZ - minZ + 1 else 0
	local width = if #waterline > 0 then maxX - minX + 1 else 0

	local mirrored = 0
	for _, e in blueprint do
		if e.x == 0 or byCell[ShipGrid.Key(-e.x, e.y, e.z)] == e.t then
			mirrored += 1
		end
	end
	local symmetry = if #blueprint > 0 then mirrored / #blueprint else 0

	local rules: { Rule } = {
		{ Id = "helm", Text = "Has a helm", Ok = hasHelm },
		{ Id = "propulsion", Text = "Has a sail or engine", Ok = thrust > 0 },
		{ Id = "hull", Text = `Waterline hull of 6+ blocks ({#waterline})`, Ok = #waterline >= 6 },
		{ Id = "bow", Text = "Front row is all Bow blocks, one in the centre", Ok = bowOk and bowCentre },
		{ Id = "length", Text = `Longer than wide (+2): {length} x {width}`, Ok = length >= width + 2 },
		{ Id = "symmetry", Text = `Left and right match ({math.floor(symmetry * 100)}% / 80%)`, Ok = symmetry >= 0.8 },
	}
	local ok = true
	for _, rule in rules do
		ok = ok and rule.Ok
	end
	return ok, rules
end

--------------------------------------------------------------------------------

function ShipGrid.StarterBlueprint()
	local bp = {}
	local function add(t, x, y, z, r)
		table.insert(bp, { t = t, x = x, y = y, z = z, r = r or 0 })
	end
	for x = -1, 1 do
		add("Bow", x, 0, -2)
		for z = -1, 2 do
			add("WoodHull", x, 0, z)
		end
	end
	add("Stern", 0, 0, 3)
	add("Rudder", 0, 0, 4)
	add("Keel", 0, -1, 0)
	add("Helm", 0, 1, 2)
	add("SmallSail", 0, 1, -1)
	add("CargoHold", -1, 1, 0)
	add("CargoHold", 1, 1, 0)
	add("Flag", 0, 1, 3)
	return bp
end

-- Cleans up a blueprint loaded from storage. Returns nil if it is unusable.
function ShipGrid.Sanitize(raw, bounds)
	if type(raw) ~= "table" then
		return nil
	end
	local clean = {}
	local occ = {}
	local helms = 0
	for _, e in raw do
		if type(e) == "table" and Items.IsBlock(e.t) and isInteger(e.x) and isInteger(e.y) and isInteger(e.z) then
			local r = if isInteger(e.r) and e.r >= 0 and e.r <= 3 then e.r else 0
			r = ShipGrid.EffectiveRotation(e.t, r)
			local ok = true
			local footprint = ShipGrid.Footprint(e.t, e.x, e.y, e.z, r)
			for _, cell in footprint do
				if not ShipGrid.InBounds(cell, bounds) or occ[ShipGrid.Key(cell.X, cell.Y, cell.Z)] then
					ok = false
				end
			end
			if e.t == "Helm" then
				if helms > 0 then
					ok = false
				else
					helms += 1
				end
			end
			if ok then
				table.insert(clean, { t = e.t, x = e.x, y = e.y, z = e.z, r = r })
				for _, cell in footprint do
					occ[ShipGrid.Key(cell.X, cell.Y, cell.Z)] = #clean
				end
			end
		end
	end
	if helms ~= 1 or #clean < 2 or #clean > Config.MAX_BLOCKS then
		return nil
	end
	return clean
end

return ShipGrid
