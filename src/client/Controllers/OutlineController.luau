-- Comic ink outlines. Roblox renders at most 31 Highlights at once, so we keep a
-- pool and assign it to the nearest models tagged "Outline" a few times a second.
-- Your own ship always gets one.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local OutlineController = {}

local MAX_OUTLINES = 28
local MAX_DISTANCE = 260
local INK = Color3.fromRGB(30, 26, 38)

function OutlineController.Init()
	local camera = workspace.CurrentCamera
	local pool: { Highlight } = {}
	local folder = Instance.new("Folder")
	folder.Name = "Outlines"
	folder.Parent = camera

	for i = 1, MAX_OUTLINES do
		local h = Instance.new("Highlight")
		h.Name = `Outline{i}`
		h.FillTransparency = 1
		h.OutlineColor = INK
		h.OutlineTransparency = 0.05
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Enabled = false
		h.Parent = folder
		pool[i] = h
	end

	local userId = Players.LocalPlayer.UserId

	task.spawn(function()
		while true do
			local origin = camera.CFrame.Position
			local candidates = {}
			for _, model in CollectionService:GetTagged("Outline") do
				if model:IsA("Model") and model:IsDescendantOf(workspace) then
					local ok, pivot = pcall(model.GetPivot, model)
					if ok then
						local distance = (pivot.Position - origin).Magnitude
						if model:GetAttribute("OwnerId") == userId then
							distance = -1
						end
						-- Big models (piers, ships) are measured generously
						if model.Name == "Pier" then
							distance *= 0.4
						end
						if distance < MAX_DISTANCE then
							table.insert(candidates, { model, distance })
						end
					end
				end
			end
			table.sort(candidates, function(a, b)
				return a[2] < b[2]
			end)
			for i, highlight in pool do
				local entry = candidates[i]
				if entry then
					if highlight.Adornee ~= entry[1] then
						highlight.Adornee = entry[1]
					end
					highlight.Enabled = true
				else
					highlight.Enabled = false
					highlight.Adornee = nil
				end
			end
			task.wait(0.4)
		end
	end)
end

return OutlineController
