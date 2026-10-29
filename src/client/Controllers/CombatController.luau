-- Keyboard actions at sea: F fires a broadside where the camera looks,
-- G drops the crate you're carrying.

local UserInputService = game:GetService("UserInputService")

local CombatController = {}

function CombatController.Init(ctx)
	local camera = workspace.CurrentCamera
	local lastFire = 0

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local data = ctx.State.Data
		if not data then
			return
		end
		if input.KeyCode == Enum.KeyCode.F and not data.Building then
			if os.clock() - lastFire < 0.5 then
				return
			end
			lastFire = os.clock()
			ctx.Invoke("FireBroadside", camera.CFrame.LookVector)
		elseif input.KeyCode == Enum.KeyCode.G and data.Carrying then
			ctx.Invoke("DropCrate")
		end
	end)
end

return CombatController
