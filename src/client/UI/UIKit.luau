-- Nautical UI toolkit: parchment panels, brass and ink trim, serif titles,
-- gently bouncing buttons and pop-in animations.

local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Colors = {
	Ink = Color3.fromRGB(38, 30, 26),
	Paper = Color3.fromRGB(244, 234, 212),
	PaperDark = Color3.fromRGB(222, 206, 174),
	White = Color3.fromRGB(252, 248, 240),
	Yellow = Color3.fromRGB(206, 164, 72),
	Orange = Color3.fromRGB(192, 118, 56),
	Red = Color3.fromRGB(164, 58, 48),
	Green = Color3.fromRGB(78, 132, 70),
	Blue = Color3.fromRGB(48, 90, 136),
	Teal = Color3.fromRGB(44, 114, 112),
	Purple = Color3.fromRGB(100, 76, 128),
	Grey = Color3.fromRGB(146, 140, 130),
}

UIKit.TitleFont = Enum.Font.Merriweather
UIKit.BodyFont = Enum.Font.GothamMedium

local C = UIKit.Colors

function UIKit.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent
	for key, value in props or ({} :: { [string]: any }) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local Create = UIKit.Create

function UIKit.Corner(parent: Instance, radius: number?)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UIKit.Stroke(parent: Instance, thickness: number?, color: Color3?)
	return Create("UIStroke", {
		Name = "Outline",
		Thickness = (thickness or 3) * 0.7,
		Color = color or C.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function UIKit.TextStroke(parent: Instance, thickness: number?)
	return Create("UIStroke", {
		Name = "TextOutline",
		Thickness = thickness or 2,
		Color = C.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function UIKit.Padding(parent: Instance, px: number)
	return Create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

-- Light-to-dark vertical shading that makes flat colours read as "inked" comic fills
function UIKit.Shade(parent: Instance, amount: number?)
	local a = 1 - (amount or 0.16)
	return Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(a, a, a)),
		Parent = parent,
	})
end

function UIKit.Label(props: { [string]: any }): TextLabel
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = UIKit.BodyFont,
		TextColor3 = C.Ink,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	local outlined = props.Outlined
	props.Outlined = nil
	for key, value in props do
		if key ~= "Parent" then
			label[key] = value
		end
	end
	if outlined then
		UIKit.TextStroke(label, if type(outlined) == "number" then outlined else 2)
	end
	label.Parent = props.Parent
	return label
end

local function bounce(scale: UIScale, target: number, time: number?)
	TweenService:Create(scale, TweenInfo.new(time or 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
end

-- props: Text, Color, Size, Position, AnchorPoint, Parent, OnClick, TextSize, LayoutOrder, TextColor
function UIKit.Button(props: { [string]: any }): TextButton
	local button = Create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = props.Color or C.Yellow,
		Size = props.Size or UDim2.fromOffset(120, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Text = props.Text or "",
		Font = UIKit.TitleFont,
		TextSize = props.TextSize or 20,
		TextColor3 = props.TextColor or C.White,
		LayoutOrder = props.LayoutOrder or 0,
		Name = props.Name or "Button",
	})
	UIKit.Corner(button, 10)
	UIKit.Stroke(button, 3)
	UIKit.Shade(button)
	UIKit.TextStroke(button, 2)
	local scale = Create("UIScale", { Parent = button })

	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		bounce(scale, 1.06)
	end)
	button.MouseLeave:Connect(function()
		bounce(scale, 1)
	end)
	button.MouseButton1Down:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		bounce(scale, 0.92, 0.06)
	end)
	button.MouseButton1Up:Connect(function()
		bounce(scale, 1)
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		if props.OnClick then
			props.OnClick(button)
		end
	end)
	button:SetAttribute("BaseColor", props.Color or C.Yellow)
	button.Parent = props.Parent
	return button
end

function UIKit.SetEnabled(button: GuiButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	button.BackgroundColor3 = if enabled then button:GetAttribute("BaseColor") or C.Yellow else C.Grey
end

-- A small rounded "card" with an ink outline
function UIKit.Card(props: { [string]: any }): Frame
	local frame = Create("Frame", {
		BackgroundColor3 = props.Color or C.White,
		Size = props.Size or UDim2.new(1, 0, 0, 60),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Name = props.Name or "Card",
	})
	UIKit.Corner(frame, props.Radius or 12)
	UIKit.Stroke(frame, props.Stroke or 3)
	frame.Parent = props.Parent
	return frame
end

function UIKit.ScrollList(parent: Instance, padding: number?): ScrollingFrame
	local scroll = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Ink,
		Parent = parent,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 14),
		Parent = scroll,
	})
	return scroll
end

function UIKit.Clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- Panels (one open at a time)
--------------------------------------------------------------------------------

local openPanel = nil

export type Panel = {
	Root: Frame,
	Content: Frame,
	Open: () -> (),
	Close: () -> (),
	Toggle: () -> (),
	IsOpen: () -> boolean,
	OnClose: ((() -> ()) -> ()),
}

function UIKit.Panel(parent: Instance, title: string, size: UDim2, accent: Color3?): Panel
	local holder = Create("Frame", {
		Name = title .. "Panel",
		BackgroundTransparency = 1,
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	local scale = Create("UIScale", { Parent = holder })

	-- Offset ink shadow, the classic comic "drop"
	local shadow = Create("Frame", {
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(8, 8),
		ZIndex = 5,
		Parent = holder,
	})
	UIKit.Corner(shadow, 20)

	local body = Create("Frame", {
		BackgroundColor3 = C.Paper,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = holder,
	})
	UIKit.Corner(body, 20)
	UIKit.Stroke(body, 4)
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(C.White, C.PaperDark),
		Parent = body,
	})

	local banner = Create("Frame", {
		BackgroundColor3 = accent or C.Orange,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(math.max(220, #title * 22 + 60), 54),
		Rotation = 0,
		ZIndex = 8,
		Parent = holder,
	})
	UIKit.Corner(banner, 12)
	UIKit.Stroke(banner, 4)
	UIKit.Shade(banner, 0.2)
	local titleLabel = UIKit.Label({
		Text = string.upper(title),
		Font = UIKit.TitleFont,
		TextSize = 32,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 9,
		Outlined = 3,
		Parent = banner,
	})
	titleLabel.Name = "Title"

	local content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 40),
		Size = UDim2.new(1, -36, 1, -56),
		ZIndex = 7,
		Parent = body,
	})

	local panel = {} :: any
	local closeCallbacks = {}

	local close = UIKit.Button({
		Text = "X",
		Color = C.Red,
		Size = UDim2.fromOffset(46, 46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		TextSize = 26,
		Parent = holder,
		OnClick = function()
			panel.Close()
		end,
	})
	close.ZIndex = 10
	UIKit.Corner(close, 23)

	panel.Root = holder
	panel.Content = content
	panel.Banner = banner
	function panel.IsOpen()
		return holder.Visible
	end
	function panel.Open()
		if openPanel and openPanel ~= panel then
			openPanel.Close()
		end
		openPanel = panel
		holder.Visible = true
		-- Shrink to fit small (phone) screens
		local viewport = workspace.CurrentCamera.ViewportSize
		local fit = math.min(1, (viewport.X - 24) / size.X.Offset, (viewport.Y - 90) / size.Y.Offset)
		scale.Scale = fit * 0.8
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
	end
	function panel.Close()
		if not holder.Visible then
			return
		end
		holder.Visible = false
		if openPanel == panel then
			openPanel = nil
		end
		for _, cb in closeCallbacks do
			task.spawn(cb)
		end
	end
	function panel.Toggle()
		if holder.Visible then
			panel.Close()
		else
			panel.Open()
		end
	end
	function panel.OnClose(cb)
		table.insert(closeCallbacks, cb)
	end
	return panel
end

function UIKit.CloseAll()
	if openPanel then
		openPanel.Close()
	end
end

--------------------------------------------------------------------------------
-- Toasts
--------------------------------------------------------------------------------

local toastStack: Frame? = nil

local KIND_COLORS = {
	info = C.Blue,
	good = C.Green,
	bad = C.Red,
	gain = C.Yellow,
}

function UIKit.Toast(screen: ScreenGui, text: string, kind: string?)
	if not toastStack then
		toastStack = Create("Frame", {
			Name = "Toasts",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 70),
			Size = UDim2.fromOffset(460, 300),
			ZIndex = 20,
			Parent = screen,
		})
		Create("UIListLayout", {
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = toastStack,
		})
	end
	local color = KIND_COLORS[kind or "info"] or C.Blue
	local toast = Create("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = math.floor(os.clock() * 1000),
		ZIndex = 20,
		Parent = toastStack,
	})
	UIKit.Corner(toast, 12)
	UIKit.Stroke(toast, 3)
	UIKit.Shade(toast)
	Create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = toast })
	UIKit.Label({
		Text = text,
		Font = UIKit.TitleFont,
		TextSize = 22,
		TextColor3 = if kind == "gain" then C.Ink else C.White,
		Outlined = if kind == "gain" then nil else 2,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 21,
		Parent = toast,
	})
	local scale = Create("UIScale", { Scale = 0.3, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(3, function()
		local tween = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)

	-- Keep the stack short
	local toasts = {}
	for _, child in (toastStack :: Frame):GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 5 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
end

return UIKit
