-- Physical cargo. Every trade good is a crate:
--   * bought crates appear on the trader's loading pad
--   * players carry one crate at a time (slower walking, no jumping high)
--   * crates are stowed in Cargo Crate blocks on a ship (2 per block)
--   * dropped crates fall where they are and float in water
--   * when a ship sinks its crates spill into the sea for anyone to grab
--
-- Prompts carry a "Need" attribute ("Crate" / "Empty"); the client's
-- PromptController shows each one only when it applies to the local player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockFactory = require(Shared.BlockFactory)
local Config = require(Shared.Config)
local Goods = require(Shared.Goods)
local Remotes = require(Shared.Remotes)

local CargoService = {}
local S

local CRATE_SIZE = 2.2
local crateFolder: Folder
local carrying: { [Player]: any } = {} -- player -> crate record
local nextCrateId = 0

function CargoService.Init(services)
	S = services
end

local function filteredPrompt(parent: Instance, action: string, object: string, need: string, hold: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold or 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Need", need)
	CollectionService:AddTag(prompt, "FilteredPrompt")
	prompt.Parent = parent
	return prompt
end

local function setCarryState(player: Player, goodId: string?)
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("Carrying", goodId)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if goodId then Config.CARRY_WALKSPEED else 16
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = if goodId then 2.5 else 7.2
	end
	S.StateService.Push(player)
end

--------------------------------------------------------------------------------
-- Crate objects
--------------------------------------------------------------------------------

local function makeCrate(goodId: string, ownerId: number)
	local good = Goods.Get(goodId)
	nextCrateId += 1
	local model = BlockFactory.CreateCrate(good.Icon, good.Color, CRATE_SIZE)
	model.Name = `{goodId}Crate`
	model:SetAttribute("Good", goodId)
	model:SetAttribute("OwnerId", ownerId)
	model:SetAttribute("CrateId", nextCrateId)
	CollectionService:AddTag(model, "Crate")
	local record = { Id = nextCrateId, Good = goodId, OwnerId = ownerId, Model = model, State = "New" }
	local prompt = filteredPrompt(model.PrimaryPart, "Pick up", `{good.Icon} {good.Name} crate`, "Empty")
	prompt.Triggered:Connect(function(player)
		CargoService.PickUp(player, record)
	end)
	record.Prompt = prompt
	model.Parent = crateFolder
	return record
end

local function setPhysics(record, mode: string)
	for _, d in record.Model:GetDescendants() do
		if d:IsA("BasePart") then
			local main = d == record.Model.PrimaryPart
			if mode == "Anchored" then
				d.Anchored = true
				d.CanCollide = main
				d.Massless = false
			elseif mode == "Carried" then
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
			else -- "Loose": real physics, floats in water
				d.Anchored = false
				d.CanCollide = main
				d.Massless = not main
				if main then
					d.CustomPhysicalProperties = PhysicalProperties.new(0.45, 0.6, 0.1)
				end
			end
		end
	end
end

local function clearWelds(record)
	for _, d in record.Model:GetDescendants() do
		if d:IsA("WeldConstraint") and d.Name == "CarryWeld" then
			d:Destroy()
		end
	end
end

local function weldInternals(record)
	local main = record.Model.PrimaryPart
	for _, d in record.Model:GetDescendants() do
		if d:IsA("BasePart") and d ~= main and not d:FindFirstChild("InnerWeld") then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "InnerWeld"
			weld.Part0 = main
			weld.Part1 = d
			weld.Parent = d
		end
	end
end

local function makeLoose(record, cf: CFrame)
	clearWelds(record)
	record.State = "Loose"
	record.Model:PivotTo(cf)
	weldInternals(record)
	setPhysics(record, "Loose")
	record.Prompt:SetAttribute("Locked", nil)
	local id = record.Id
	task.delay(Config.LOOSE_CRATE_LIFETIME, function()
		if record.State == "Loose" and record.Id == id and record.Model.Parent then
			record.Model:Destroy()
		end
	end)
end

-- Captain id used for gold sharing: buying as crew counts for your captain's crew
local function teamOwnerId(player: Player): number
	return S.CrewService.CaptainOf(player).UserId
end

local function mayTake(player: Player, record): boolean
	if record.State == "Loose" then
		return true
	end
	return record.OwnerId == player.UserId or record.OwnerId == teamOwnerId(player)
end

--------------------------------------------------------------------------------
-- Pads (at the traders)
--------------------------------------------------------------------------------

local padUsage: { [BasePart]: { any } } = {}

local function findPad(islandId: string): BasePart?
	for _, pad in CollectionService:GetTagged("CratePad") do
		if pad:GetAttribute("IslandId") == islandId then
			return pad
		end
	end
	return nil
end

function CargoService.SpawnOnPad(player: Player, islandId: string, goodId: string): (boolean, string?)
	local pad = findPad(islandId)
	if not pad then
		return false, "This trader has no loading pad."
	end
	local list = padUsage[pad] or {}
	padUsage[pad] = list
	-- Forget crates that left the pad
	for i = #list, 1, -1 do
		if list[i].State ~= "Pad" or not list[i].Model.Parent then
			table.remove(list, i)
		end
	end
	local mine = 0
	for _, record in list do
		if record.OwnerId == teamOwnerId(player) then
			mine += 1
		end
	end
	if mine >= Config.PAD_CRATES_PER_PLAYER then
		return false, "Your crates are piling up on the pad! Load them first."
	end
	local used = {}
	for _, record in list do
		used[record.Slot] = true
	end
	local slot = 1
	while used[slot] do
		slot += 1
	end
	local record = makeCrate(goodId, teamOwnerId(player))
	record.State = "Pad"
	record.Slot = slot
	local col = (slot - 1) % 4
	local row = math.floor((slot - 1) / 4) % 3
	local layer = math.floor((slot - 1) / 12)
	local offset = Vector3.new((col - 1.5) * 2.6, CRATE_SIZE / 2 + 0.5 + layer * CRATE_SIZE, (row - 1) * 2.6)
	record.Model:PivotTo(pad.CFrame * CFrame.new(offset) * CFrame.Angles(0, math.rad(math.random(-8, 8)), 0))
	setPhysics(record, "Anchored")
	table.insert(list, record)
	S.StateService.Notify(player, `📦 Your {Goods.Get(goodId).Name} crate is on the loading pad.`, "info", record.Model:GetPivot().Position + Vector3.new(0, 3, 0))
	return true, nil
end

--------------------------------------------------------------------------------
-- Carrying
--------------------------------------------------------------------------------

function CargoService.GetCarried(player: Player)
	return carrying[player]
end

local function attach(player: Player, record): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if humanoid.SeatPart then
		return false
	end
	clearWelds(record)
	record.State = "Carried"
	record.Carrier = player
	record.Prompt:SetAttribute("Locked", true)
	record.Model:PivotTo(root.CFrame * CFrame.new(0, 0.3, -2.1))
	weldInternals(record)
	setPhysics(record, "Carried")
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = record.Model.PrimaryPart
	weld.Parent = record.Model.PrimaryPart
	carrying[player] = record
	setCarryState(player, record.Good)
	return true
end

function CargoService.PickUp(player: Player, record)
	if carrying[player] then
		S.StateService.Notify(player, "You can only carry one crate.", "bad")
		return
	end
	if record.State ~= "Pad" and record.State ~= "Loose" then
		return
	end
	if not mayTake(player, record) then
		S.StateService.Notify(player, "That crate belongs to another crew.", "bad")
		return
	end
	if record.State == "Loose" and record.OwnerId ~= teamOwnerId(player) then
		record.OwnerId = teamOwnerId(player) -- finders keepers
		record.Model:SetAttribute("OwnerId", record.OwnerId)
	end
	attach(player, record)
end

-- Removes the carried crate (sold or stowed) and returns its record
function CargoService.TakeCarried(player: Player)
	local record = carrying[player]
	if not record then
		return nil
	end
	carrying[player] = nil
	record.State = "Gone"
	record.Model:Destroy()
	setCarryState(player, nil)
	return record
end

function CargoService.DropCarried(player: Player)
	local record = carrying[player]
	if not record then
		return false
	end
	carrying[player] = nil
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cf = if root then root.CFrame * CFrame.new(0, -0.6, -2.6) else record.Model:GetPivot()
	makeLoose(record, cf)
	record.Carrier = nil
	setCarryState(player, nil)
	return true
end

--------------------------------------------------------------------------------
-- Holds on ships
--------------------------------------------------------------------------------

local function renderHold(ship, key: string)
	local block = ship.Parts[key]
	if not block then
		return
	end
	local old = block:FindFirstChild("Stowed")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Stowed"
	folder.Parent = block
	local base = S.ShipService.CellCFrame(ship, key)
	for i, goodId in ship.Holds[key] or {} do
		local good = Goods.Get(goodId)
		local slot = BlockFactory.HOLD_SLOTS[i]
		if good and slot then
			local crate = BlockFactory.CreateCrate(good.Icon, good.Color, BlockFactory.STOWED_CRATE_SIZE)
			crate:PivotTo(base * slot)
			for _, d in crate:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = false
					d.Massless = true
					d.CanCollide = d.Name == "Main"
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = ship.Root
					weld.Part1 = d
					weld.Parent = d
				end
			end
			crate.Parent = folder
		end
	end
	if ship.HoldPrompts and ship.HoldPrompts[key] then
		local count = #(ship.Holds[key] or {})
		ship.HoldPrompts[key].Take.ObjectText = `Cargo crate ({count}/{Config.CRATES_PER_HOLD})`
		ship.HoldPrompts[key].Stow.ObjectText = `Cargo crate ({count}/{Config.CRATES_PER_HOLD})`
	end
end

function CargoService.SetupHold(ship, key: string, block: Model)
	ship.HoldPrompts = ship.HoldPrompts or {}
	local main = block:FindFirstChild("Main") :: BasePart
	if not ship.IsNPC then
		local stow = filteredPrompt(main, "Stow crate", "Cargo crate", "Crate")
		stow.Triggered:Connect(function(player)
			CargoService.Stow(player, ship, key)
		end)
		local take = filteredPrompt(main, "Take crate", "Cargo crate", "Empty")
		take.UIOffset = Vector2.new(0, 60)
		take.Triggered:Connect(function(player)
			CargoService.Unload(player, ship, key)
		end)
		ship.HoldPrompts[key] = { Stow = stow, Take = take }
	end
	renderHold(ship, key)
end

function CargoService.Stow(player: Player, ship, key: string)
	local record = carrying[player]
	if not record then
		return
	end
	if ship.Sinking or ship.Building then
		return
	end
	if not S.ShipService.CanAccess(player, ship) then
		S.StateService.Notify(player, "That's not your crew's ship.", "bad")
		return
	end
	local list = ship.Holds[key]
	if not list then
		return
	end
	if #list >= Config.CRATES_PER_HOLD then
		S.StateService.Notify(player, "This cargo crate is full. Try another one.", "bad")
		return
	end
	if S.ShipService.CrateCount(ship) >= ship.Stats.MaxCrates then
		S.StateService.Notify(player, "Too heavy! The hull can't float more cargo. Build more hull.", "bad")
		return
	end
	CargoService.TakeCarried(player)
	table.insert(list, record.Good)
	renderHold(ship, key)
	S.ShipService.RefreshStats(ship)
	S.QuestService.Fire(player, "Stow")
	S.StateService.Notify(player, `Stowed {Goods.Get(record.Good).Icon} {Goods.Get(record.Good).Name}`, "good")
end

function CargoService.Unload(player: Player, ship, key: string)
	if carrying[player] then
		return
	end
	local list = ship.Holds[key]
	if not list or #list == 0 then
		S.StateService.Notify(player, "This cargo crate is empty.", "bad")
		return
	end
	local looting = ship.Sinking or (ship.HP and ship.HP <= 0)
	if not looting and not S.ShipService.CanAccess(player, ship) then
		S.StateService.Notify(player, "Sink it first if you want their cargo, pirate!", "bad")
		return
	end
	local goodId = table.remove(list)
	local ownerId = if ship.Captain then ship.Captain.UserId else teamOwnerId(player)
	local record = makeCrate(goodId, ownerId)
	if not attach(player, record) then
		table.insert(list, goodId)
		record.Model:Destroy()
		return
	end
	renderHold(ship, key)
	S.ShipService.RefreshStats(ship)
end

-- A sinking ship spills its cargo into the sea
function CargoService.SpillHolds(ship)
	if not ship.Root then
		return
	end
	local origin = ship.Root.Position
	for key, list in ship.Holds do
		for _, goodId in list do
			local record = makeCrate(goodId, 0)
			local offset = Vector3.new(math.random(-14, 14), 4, math.random(-14, 14))
			makeLoose(record, CFrame.new(origin + offset) * CFrame.Angles(0, math.random() * 6, 0))
		end
		table.clear(list)
		local block = ship.Parts[key]
		local stowed = block and block:FindFirstChild("Stowed")
		if stowed then
			stowed:Destroy()
		end
	end
end

function CargoService.Start()
	crateFolder = Instance.new("Folder")
	crateFolder.Name = "Crates"
	crateFolder.Parent = Workspace

	Remotes.Function("DropCrate").OnServerInvoke = function(player)
		if CargoService.DropCarried(player) then
			return { ok = true }
		end
		return { ok = false, msg = "You're not carrying anything." }
	end

	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			CargoService.DropCarried(player)
		end)
		humanoid.Seated:Connect(function(active)
			if active then
				CargoService.DropCarried(player)
			end
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		CargoService.DropCarried(player)
	end)
end

return CargoService
