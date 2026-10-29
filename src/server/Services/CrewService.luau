-- Crews: a captain invites friends, who can then board, carry and stow cargo
-- on the captain's ship and man its cannons. Gold from selling the crew's
-- crates is split equally between every crew member online.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CrewService = {}
local S

local captainOf: { [Player]: Player } = {} -- member -> captain
local crews: { [Player]: { Player } } = {} -- captain -> members
local invites: { [Player]: { From: Player, Time: number } } = {}

function CrewService.Init(services)
	S = services
end

function CrewService.CaptainOf(player: Player): Player
	return captainOf[player] or player
end

function CrewService.IsCrew(player: Player, captain: Player): boolean
	return player == captain or captainOf[player] == captain
end

-- Captain first, then members
function CrewService.Members(captain: Player): { Player }
	local list = { captain }
	for _, member in ipairs(crews[captain] or {}) do
		table.insert(list, member)
	end
	return list
end

function CrewService.Summary(player: Player)
	local captain = CrewService.CaptainOf(player)
	local members = {}
	for _, member in CrewService.Members(captain) do
		table.insert(members, { Name = member.DisplayName, UserId = member.UserId, Captain = member == captain })
	end
	return {
		IsCaptain = captain == player,
		Captain = captain.DisplayName,
		Members = members,
	}
end

local function pushAll(captain: Player)
	for _, member in CrewService.Members(captain) do
		S.StateService.Push(member)
	end
end

local function removeMember(member: Player)
	local captain = captainOf[member]
	if not captain then
		return
	end
	captainOf[member] = nil
	local list = crews[captain]
	if list then
		local i = table.find(list, member)
		if i then
			table.remove(list, i)
		end
		if #list == 0 then
			crews[captain] = nil
		end
	end
	S.StateService.Push(member)
	pushAll(captain)
	return captain
end

local function disband(captain: Player)
	for _, member in table.clone(crews[captain] or {}) do
		removeMember(member)
		S.StateService.Notify(member, `{captain.DisplayName}'s crew was disbanded.`, "info")
	end
	crews[captain] = nil
end

local function findPlayer(userId: any): Player?
	if type(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

function CrewService.Action(player: Player, action: any, arg: any)
	if action == "invite" then
		local target = findPlayer(arg)
		if not target or target == player then
			return { ok = false, msg = "Player not found." }
		end
		if captainOf[player] then
			return { ok = false, msg = "Only captains can invite. Leave your crew first." }
		end
		if #(crews[player] or {}) >= Config.MAX_CREW then
			return { ok = false, msg = `Your crew is full ({Config.MAX_CREW} sailors).` }
		end
		if CrewService.IsCrew(target, player) then
			return { ok = false, msg = `{target.DisplayName} is already in your crew.` }
		end
		invites[target] = { From = player, Time = os.clock() }
		Remotes.Event("CrewInvite"):FireClient(target, player.DisplayName, player.UserId)
		return { ok = true, msg = `Invite sent to {target.DisplayName}.` }
	elseif action == "accept" then
		local invite = invites[player]
		invites[player] = nil
		local captain = invite and invite.From
		if not captain or not captain.Parent or os.clock() - invite.Time > 60 or captain.UserId ~= arg then
			return { ok = false, msg = "That invite has expired." }
		end
		if captainOf[captain] then
			return { ok = false, msg = "They joined another crew meanwhile." }
		end
		if #(crews[captain] or {}) >= Config.MAX_CREW then
			return { ok = false, msg = "Their crew is full." }
		end
		removeMember(player)
		disband(player)
		captainOf[player] = captain
		crews[captain] = crews[captain] or {}
		table.insert(crews[captain], player)
		for _, member in CrewService.Members(captain) do
			S.StateService.Notify(member, `🤝 {player.DisplayName} joined {captain.DisplayName}'s crew!`, "good")
		end
		S.QuestService.Fire(captain, "CrewJoined")
		S.QuestService.Fire(player, "CrewJoined")
		pushAll(captain)
		return { ok = true }
	elseif action == "decline" then
		invites[player] = nil
		return { ok = true }
	elseif action == "leave" then
		local captain = removeMember(player)
		if not captain then
			return { ok = false, msg = "You're not in a crew." }
		end
		S.StateService.Notify(captain, `{player.DisplayName} left your crew.`, "info")
		return { ok = true, msg = "You left the crew." }
	elseif action == "kick" then
		local target = findPlayer(arg)
		if not target or captainOf[target] ~= player then
			return { ok = false, msg = "They're not in your crew." }
		end
		removeMember(target)
		S.StateService.Notify(target, `{player.DisplayName} removed you from the crew.`, "bad")
		return { ok = true, msg = `{target.DisplayName} was removed from the crew.` }
	end
	return { ok = false }
end

function CrewService.Start()
	Remotes.Function("CrewAction").OnServerInvoke = CrewService.Action
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		removeMember(player)
		disband(player)
	end)
end

return CrewService
