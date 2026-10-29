-- Tracks each player's progress through the guided quest line (Shared/Quests).
-- Other services report what happens with QuestService.Fire(player, event, item, amount).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Quests = require(Shared.Quests)

local QuestService = {}
local S

function QuestService.Init(services)
	S = services
end

function QuestService.Summary(player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return nil
	end
	local quest = profile.Quest
	local step = Quests.Get(quest.Step)
	if not step then
		return { Done = true, Step = quest.Step, Total = #Quests.Steps }
	end
	return {
		Done = false,
		Step = quest.Step,
		Total = #Quests.Steps,
		Title = step.Title,
		Text = step.Text,
		Progress = quest.Progress,
		Count = step.Count,
		Target = step.Target,
	}
end

local function rewardText(reward): string
	local parts = {}
	if reward.Gold then
		table.insert(parts, `{reward.Gold}g`)
	end
	for id, n in reward.Items or {} do
		table.insert(parts, `{n} {Items.Get(id).Icon}`)
	end
	return table.concat(parts, " + ")
end

function QuestService.Fire(player: Player?, event: string, item: string?, amount: number?)
	if not player then
		return
	end
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local quest = profile.Quest
	local step = Quests.Get(quest.Step)
	if not step or step.Event ~= event or (step.Item and step.Item ~= item) then
		return
	end
	quest.Progress += amount or 1
	if quest.Progress >= step.Count then
		quest.Step += 1
		quest.Progress = 0
		local reward = step.Reward
		if reward then
			if reward.Gold then
				S.InventoryService.AddGold(player, reward.Gold)
			end
			for id, n in reward.Items or {} do
				S.InventoryService.Add(player, id, n)
			end
			S.StateService.Notify(player, `✅ {step.Title} complete! Reward: {rewardText(reward)}`, "good")
		else
			S.StateService.Notify(player, `✅ {step.Title} complete!`, "good")
		end
		-- Some steps may already be satisfied (e.g. already carrying the right items)
		local nextStep = Quests.Get(quest.Step)
		if nextStep and nextStep.Event == "Craft" and nextStep.Item and S.InventoryService.Count(player, nextStep.Item) >= nextStep.Count then
			QuestService.Fire(player, "Craft", nextStep.Item, nextStep.Count)
		end
	end
	S.StateService.Push(player)
end

return QuestService
