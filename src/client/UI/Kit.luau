-- Tiny UI toolkit: theme, instance builder, styled buttons/panels, single-modal router, responsive scale.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Kit = {}

Kit.Theme = {
	Bg = Color3.fromRGB(22, 18, 44),
	Panel = Color3.fromRGB(34, 29, 66),
	PanelLight = Color3.fromRGB(50, 43, 92),
	Text = Color3.fromRGB(246, 244, 255),
	Sub = Color3.fromRGB(184, 178, 226),
	Mint = Color3.fromRGB(62, 240, 178),
	Sky = Color3.fromRGB(72, 170, 255),
	Pink = Color3.fromRGB(255, 92, 200),
	Gold = Color3.fromRGB(255, 202, 64),
	Red = Color3.fromRGB(255, 92, 92),
	Disabled = Color3.fromRGB(90, 86, 120),
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}
local T = Kit.Theme

Kit.ROBUX = utf8.char(0xE002) -- Roblox's built-in Robux glyph

function Kit.new(class: string, props, children)
	local inst = Instance.new(class)
	local parent = props and props.Parent
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(r: number?)
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, r or 14) })
end

function Kit.stroke(color: Color3?, thickness: number?, transparency: number?)
	return Kit.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.pad(px: number)
	local u = UDim.new(0, px)
	return Kit.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Kit.gradient(a: Color3, b: Color3, rotation: number?)
	return Kit.new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90 })
end

function Kit.list(padding: number?, horizontal: boolean?, align)
	return Kit.new("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
end

function Kit.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = T.Title,
		TextColor3 = T.Text,
		TextScaled = true,
		Text = "",
	}
	for k, v in props do
		if k ~= "MaxText" then
			defaults[k] = v
		end
	end
	local l = Kit.new("TextLabel", defaults)
	Kit.new("UITextSizeConstraint", { MaxTextSize = props.MaxText or 34, MinTextSize = 9, Parent = l })
	return l
end

function Kit.tween(inst, time: number, goal, style)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

-- Styled button. opts: text, color, size, position, anchor, onClick, textColor, maxText, parent, layoutOrder
function Kit.button(opts)
	local scale = Kit.new("UIScale", { Scale = 1 })
	local btn = Kit.new("TextButton", {
		Name = opts.name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = opts.color or T.Mint,
		Size = opts.size or UDim2.fromOffset(160, 52),
		Position = opts.position or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
		Text = "",
		LayoutOrder = opts.layoutOrder or 0,
		Parent = opts.parent,
	}, {
		Kit.corner(opts.radius or 14),
		Kit.stroke(Color3.new(0, 0, 0), 2.5, 0.55),
		Kit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 215)),
		scale,
	})
	local label = Kit.label({
		Name = "Label",
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		Text = opts.text or "",
		TextColor3 = opts.textColor or Color3.fromRGB(26, 22, 50),
		MaxText = opts.maxText or 26,
		Parent = btn,
	})
	btn.MouseEnter:Connect(function()
		Kit.tween(scale, 0.12, { Scale = 1.05 })
	end)
	btn.MouseLeave:Connect(function()
		Kit.tween(scale, 0.12, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		Kit.tween(scale, 0.06, { Scale = 0.94 })
	end)
	btn.MouseButton1Up:Connect(function()
		Kit.tween(scale, 0.1, { Scale = 1.05 })
	end)
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then
			return
		end
		SoundController:Play("Click", 0.5, 1.2)
		if opts.onClick then
			opts.onClick()
		end
	end)
	return btn, label
end

function Kit.setEnabled(btn, enabled: boolean, color: Color3?)
	btn:SetAttribute("Disabled", not enabled)
	btn.BackgroundColor3 = if enabled then (color or btn.BackgroundColor3) else T.Disabled
end

-- Root ScreenGui with responsive UIScale (designed at 1280x720, clamped for phones/4K).
function Kit.root(name: string, order: number?)
	local gui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 0,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local scale = Kit.new("UIScale", { Parent = gui })
	local function fit()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(vp.X / 1150, vp.Y / 640), 0.6, 1.35)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	return gui
end

-- Modal window with title and close button. Returns frame, content.
function Kit.panel(parent, title: string, size: UDim2)
	local frame = Kit.new("Frame", {
		Name = title,
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Panel,
		Visible = false,
		Parent = parent,
	}, {
		Kit.corner(20),
		Kit.stroke(T.Sky, 3, 0.2),
		Kit.new("UIScale", { Name = "PopScale" }),
	})
	Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = T.PanelLight, Parent = frame }, {
		Kit.corner(20),
		Kit.gradient(T.PanelLight, T.Panel),
	})
	Kit.label({ Text = title, Size = UDim2.new(1, -140, 0, 44), Position = UDim2.fromOffset(24, 10), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 36, Parent = frame })
	local close = Kit.button({
		text = "X",
		color = T.Red,
		size = UDim2.fromOffset(48, 48),
		position = UDim2.new(1, -60, 0, 8),
		textColor = Color3.new(1, 1, 1),
		parent = frame,
		onClick = function()
			Kit.closeModal()
		end,
	})
	close.Name = "Close"
	local content = Kit.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -32, 1, -84),
		Position = UDim2.fromOffset(16, 72),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	return frame, content
end

local modals, current = {}, nil

function Kit.registerModal(name: string, frame, onOpen)
	modals[name] = { frame = frame, onOpen = onOpen }
end

function Kit.openModal(name: string)
	if current == name then
		Kit.closeModal()
		return
	end
	Kit.closeModal()
	local m = modals[name]
	if not m then
		return
	end
	current = name
	if m.onOpen then
		m.onOpen()
	end
	local pop = m.frame:FindFirstChild("PopScale")
	if pop then
		pop.Scale = 0.85
		Kit.tween(pop, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	m.frame.Visible = true
	if GuiService:IsTenFootInterface() or game:GetService("UserInputService").GamepadEnabled then
		local close = m.frame:FindFirstChild("Close")
		GuiService.SelectedObject = close
	end
end

function Kit.closeModal()
	if current and modals[current] then
		modals[current].frame.Visible = false
	end
	current = nil
	GuiService.SelectedObject = nil
end

function Kit.currentModal(): string?
	return current
end

function Kit.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Kit.comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

return Kit
