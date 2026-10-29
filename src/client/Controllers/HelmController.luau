-- While you sit at your own helm, report throttle and steering to the server.
-- The VehicleSeat already reads keyboard, gamepad and the mobile thumbstick for us.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local HelmController = {}

local SEND_INTERVAL = 0.2

function HelmController.Init()
	local helmInput = Remotes.Event("HelmInput")
	local player = Players.LocalPlayer
	local lastThrottle, lastSteer, lastSend = 0, 0, 0

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if not seat or not seat:IsA("VehicleSeat") then
			return
		end
		local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
		local now = os.clock()
		if throttle ~= lastThrottle or steer ~= lastSteer or now - lastSend > SEND_INTERVAL then
			lastThrottle, lastSteer, lastSend = throttle, steer, now
			helmInput:FireServer(throttle, steer)
		end
	end)
end

return HelmController
