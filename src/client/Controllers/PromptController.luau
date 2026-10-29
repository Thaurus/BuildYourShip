-- Shows each "FilteredPrompt" only when it applies to the local player:
--   Need = "Crate"  only while carrying a crate (stow, sell)
--   Need = "Empty"  only with empty hands (pick up, take, trade, fire)
-- and hides prompts the server marked "Locked".
-- Changing Enabled on the client only affects this player's view; the server
-- still validates every trigger.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local PromptController = {}

function PromptController.Init()
	local player = Players.LocalPlayer

	local function carrying(): boolean
		local character = player.Character
		return character ~= nil and character:GetAttribute("Carrying") ~= nil
	end

	local watched = {}
	local function apply(prompt: Instance)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		local need = prompt:GetAttribute("Need")
		local show = true
		if need == "Crate" then
			show = carrying()
		elseif need == "Empty" then
			show = not carrying()
		end
		-- "Locked" is set by the server, e.g. on a crate someone else is carrying
		prompt.Enabled = show and not prompt:GetAttribute("Locked")
		if not watched[prompt] then
			watched[prompt] = true
			prompt:GetAttributeChangedSignal("Locked"):Connect(function()
				apply(prompt)
			end)
			prompt.Destroying:Connect(function()
				watched[prompt] = nil
			end)
		end
	end

	local function applyAll()
		for _, prompt in CollectionService:GetTagged("FilteredPrompt") do
			apply(prompt)
		end
	end

	CollectionService:GetInstanceAddedSignal("FilteredPrompt"):Connect(apply)
	local function watch(character: Model)
		character:GetAttributeChangedSignal("Carrying"):Connect(applyAll)
		applyAll()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
	applyAll()
end

return PromptController
