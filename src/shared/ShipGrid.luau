-- Grid math for ship blueprints. Used by the server for validation and by the
-- client for build previews, so both always agree.
--
-- A blueprint is an array of entries: { t = blockId, x = int, y = int, z = int, r = 0..3 }
-- (x, y, z) is the anchor cell; r is the rotation around Y in 90 degree steps.
-- Ship forward is -Z (the root part's LookVector).

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

function ShipGrid.InBounds(cell: Vector3): boolean
	local b = Config.BUILD_BOUNDS
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

function ShipGrid.CanPlace(blueprint, occ, blockId: string, x: number, y: number, z: number, r: number): (boolean, string?)
	local def = Items.Get(blockId)
	if not def or def.Kind ~= "Block" then
		return false, "That is not a ship block."
	end
	if not (isInteger(x) and isInteger(y) and isInteger(z) and isInteger(r)) or r < 0 or r > 3 then
		return false, "Invalid position."
	end
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

	local footprint = ShipGrid.Footprint(blockId, x, y, z, r)
	local own = {}
	for _, cell in footprint do
		if not ShipGrid.InBounds(cell) then
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

	local visitedCells = {}
	local reached = { [index] = true }
	local reachedCount = 1
	local queue = { start }
	visitedCells[ShipGrid.Key(start.X, start.Y, start.Z)] = true
	local head = 1
	while head <= #queue do
		local cell = queue[head]
		head += 1
		local ownerIndex = occ[ShipGrid.Key(cell.X, cell.Y, cell.Z)]
		if ownerIndex and not reached[ownerIndex] then
			reached[ownerIndex] = true
			reachedCount += 1
		end
		for _, dir in NEIGHBOURS do
			local n = cell + dir
			local key = ShipGrid.Key(n.X, n.Y, n.Z)
			local nIndex = occ[key]
			if not visitedCells[key] and nIndex and nIndex ~= index then
				visitedCells[key] = true
				table.insert(queue, n)
			end
		end
	end

	if reachedCount < #blueprint then
		return nil, "That would break your ship in two!"
	end
	return index, nil
end

function ShipGrid.StarterBlueprint()
	local bp = {}
	for x = -1, 1 do
		for z = -2, 2 do
			table.insert(bp, { t = "WoodHull", x = x, y = 0, z = z, r = 0 })
		end
	end
	table.insert(bp, { t = "Helm", x = 0, y = 1, z = 2, r = 0 })
	table.insert(bp, { t = "SmallSail", x = 0, y = 1, z = -1, r = 0 })
	table.insert(bp, { t = "CargoHold", x = -1, y = 1, z = 0, r = 0 })
	table.insert(bp, { t = "CargoHold", x = 1, y = 1, z = 0, r = 0 })
	table.insert(bp, { t = "Rudder", x = 0, y = 0, z = 3, r = 0 })
	table.insert(bp, { t = "Flag", x = 0, y = 1, z = -2, r = 0 })
	return bp
end

-- Cleans up a blueprint loaded from storage. Returns nil if it is unusable.
function ShipGrid.Sanitize(raw)
	if type(raw) ~= "table" then
		return nil
	end
	local clean = {}
	local occ = {}
	local helms = 0
	for _, e in raw do
		if type(e) == "table" and Items.IsBlock(e.t) and isInteger(e.x) and isInteger(e.y) and isInteger(e.z) then
			local r = if isInteger(e.r) and e.r >= 0 and e.r <= 3 then e.r else 0
			local ok = true
			local footprint = ShipGrid.Footprint(e.t, e.x, e.y, e.z, r)
			for _, cell in footprint do
				if not ShipGrid.InBounds(cell) or occ[ShipGrid.Key(cell.X, cell.Y, cell.Z)] then
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
