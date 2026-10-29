-- Crew management: see your crew, invite players on the server, kick or leave,
-- and accept invitations from other captains.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local UIKit = require(script.Parent.UIKit)
local C = UIKit.Colors

local CrewPanel = {}

function CrewPanel.Init(ctx)
	local panel = UIKit.Panel(ctx.Screen, "Crew", UDim2.fromOffset(560, 480), C.Teal)
	local localPlayer = Players.LocalPlayer

	UIKit.Label({
		Text = "Crew members can board your ship (H), carry and stow cargo, and man the cannons. Gold from selling the crew's crates is shared equally.",
		TextSize = 14,
		TextColor3 = Color3.fromRGB(100, 90, 80),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = panel.Content,
	})
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 46)
	holder.Size = UDim2.new(1, 0, 1, -46)
	holder.Parent = panel.Content
	local list = UIKit.ScrollList(holder)

	local function heading(text, order)
		UIKit.Label({
			Text = text,
			Font = UIKit.TitleFont,
			TextSize = 18,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = order,
			Parent = list,
		})
	end

	local function rowCard(order, text, buttonText, color, onClick)
		local card = UIKit.Card({ Color = C.White, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = order, Parent = list })
		UIKit.Label({ Text = text, RichText = true, TextSize = 16, Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = card })
		if buttonText then
			UIKit.Button({
				Text = buttonText,
				Color = color,
				TextSize = 15,
				Size = UDim2.fromOffset(120, 36),
				Position = UDim2.new(1, -128, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Parent = card,
				OnClick = onClick,
			})
		end
	end

	local function render()
		local data = ctx.State.Data
		if not data or not panel.IsOpen() then
			return
		end
		UIKit.Clear(list)
		local crew = data.Crew
		local order = 0
		local function nextOrder()
			order += 1
			return order
		end

		heading(if crew.IsCaptain then "Your crew" else `{crew.Captain}'s crew`, nextOrder())
		local inCrew = {}
		for _, member in crew.Members do
			inCrew[member.UserId] = true
			local label = (if member.Captain then "⚓ " else "🧑‍✈️ ") .. member.Name .. (if member.Captain then "  <font color=\"#8A8274\">captain</font>" else "")
			if crew.IsCaptain and not member.Captain then
				rowCard(nextOrder(), label, "Kick", C.Red, function()
					ctx.Invoke("CrewAction", "kick", member.UserId)
				end)
			else
				rowCard(nextOrder(), label)
			end
		end
		if not crew.IsCaptain then
			rowCard(nextOrder(), "Want your own ship back?", "Leave crew", C.Red, function()
				ctx.Invoke("CrewAction", "leave")
			end)
			return
		end

		heading("Invite sailors", nextOrder())
		local any = false
		for _, other in Players:GetPlayers() do
			if other ~= localPlayer and not inCrew[other.UserId] then
				any = true
				rowCard(nextOrder(), other.DisplayName, "Invite", C.Green, function()
					ctx.Invoke("CrewAction", "invite", other.UserId)
				end)
			end
		end
		if not any then
			rowCard(nextOrder(), "<font color=\"#8A8274\">No other sailors on this server yet.</font>")
		end
	end

	ctx.State.Changed:Connect(render)
	Players.PlayerAdded:Connect(render)
	Players.PlayerRemoving:Connect(function()
		task.defer(render)
	end)
	local open = panel.Open
	panel.Open = function()
		open()
		render()
	end

	-- Incoming invitation card
	local inviteCard = UIKit.Card({
		Color = C.Paper,
		Size = UDim2.fromOffset(360, 120),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Stroke = 3,
		Parent = ctx.Screen,
	})
	inviteCard.Visible = false
	inviteCard.ZIndex = 30
	local inviteText = UIKit.Label({
		Text = "",
		RichText = true,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 54),
		Position = UDim2.fromOffset(10, 6),
		Parent = inviteCard,
	})
	local pendingCaptainId = nil
	UIKit.Button({
		Text = "Join crew",
		Color = C.Green,
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(0.5, -158, 1, -50),
		Parent = inviteCard,
		OnClick = function()
			inviteCard.Visible = false
			ctx.Invoke("CrewAction", "accept", pendingCaptainId)
		end,
	})
	UIKit.Button({
		Text = "No thanks",
		Color = C.Grey,
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(0.5, 8, 1, -50),
		Parent = inviteCard,
		OnClick = function()
			inviteCard.Visible = false
			ctx.Invoke("CrewAction", "decline")
		end,
	})
	Remotes.Event("CrewInvite").OnClientEvent:Connect(function(captainName, captainId)
		pendingCaptainId = captainId
		inviteText.Text = `<b>{captainName}</b> invites you to join their crew!`
		inviteCard.Visible = true
		ctx.Sounds.Pop()
		task.delay(55, function()
			if pendingCaptainId == captainId then
				inviteCard.Visible = false
			end
		end)
	end)

	return panel
end

return CrewPanel
