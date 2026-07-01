-- Bold
-- _Main/Interface
-- Plinko Labs

-- Window orchestration + the public UI surface. Builds the frame/header/list,
-- owns visibility and theme/density, and wires Render (the message list) to
-- Compose (the input). Message rendering lives in Render; input lives in Compose.

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local _Main    = script.Parent
local _Utility = _Main.Parent._Utility

local Config = require(_Utility.Config)
local Skin   = require(_Utility.Skin)
local Motion = require(_Utility.Motion)
local Events = require(_Utility.Events)
local Types  = require(_Main.Parent.Types)
local Render  = require(_Main.Render)
local Compose = require(_Main.Compose)

local Interface = {}

-- live config alias (back-compat for code that reads Interface.Config)
Interface.Config = Config.Interface

-- the input event consumers (Client) subscribe to
Interface.SubmitText = Compose.SubmitText

local tk = Skin.tk

local _gui: ScreenGui? = nil
local _window: Frame? = nil
local _container: ScrollingFrame? = nil
local _header: Frame? = nil
local _winScale: UIScale? = nil

-- ─── build ───────────────────────────────────────────────────────────────────

local function enableDrag(handle: GuiObject, target: Frame)
	local dragging = false
	local dragStart, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local function buildGui()
	if _gui then return end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local cfg = Config.Interface

	_gui = Instance.new("ScreenGui")
	_gui.Name = "BoldUI"
	_gui.ResetOnSpawn = false
	_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_gui.Enabled = cfg.visible
	_gui.Parent = playerGui

	_window = Instance.new("Frame")
	_window.Name = "Window"
	_window.Size = cfg.window_size
	_window.AutomaticSize = Enum.AutomaticSize.Y
	_window.Position = cfg.window_position
	_window.AnchorPoint = cfg.window_anchor
	_window.BackgroundTransparency = 1
	_window.Parent = _gui
	Skin.list(_window, nil, 2)

	_winScale = Instance.new("UIScale")
	_winScale.Parent = _window

	if cfg.show_header and cfg.header_height > 0 then
		_header = Instance.new("Frame")
		_header.Name = "Header"
		_header.Size = UDim2.new(1, 0, 0, cfg.header_height)
		_header.BackgroundColor3 = tk("header")
		_header.BackgroundTransparency = tk("header_transparency")
		_header.BorderSizePixel = 0
		_header.LayoutOrder = 0
		_header.Parent = _window
		Skin.corner(_header)
		Skin.pad(_header, 10)

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.Text = cfg.channel_name
		lbl.Font = tk("font_bold")
		lbl.TextSize = Skin.density().text_size - 1
		lbl.TextColor3 = tk("text")
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = _header

		if cfg.draggable then enableDrag(_header, _window) end
	end

	-- draggable even when the header is hidden: a slim grip strip at the top
	if cfg.draggable and not _header then
		local handle = Instance.new("Frame")
		handle.Name = "DragHandle"
		handle.Size = UDim2.new(1, 0, 0, 14)
		handle.BackgroundColor3 = tk("header")
		handle.BackgroundTransparency = 0.5
		handle.BorderSizePixel = 0
		handle.LayoutOrder = 0
		handle.Parent = _window
		Skin.corner(handle, 6)
		local grip = Instance.new("Frame")
		grip.AnchorPoint = Vector2.new(0.5, 0.5)
		grip.Position = UDim2.fromScale(0.5, 0.5)
		grip.Size = UDim2.fromOffset(28, 3)
		grip.BackgroundColor3 = tk("subtext")
		grip.BackgroundTransparency = 0.4
		grip.BorderSizePixel = 0
		grip.Parent = handle
		Skin.corner(grip, 2)
		enableDrag(handle, _window)
	end

	local listWrapper = Instance.new("Frame")
	listWrapper.Name = "ListWrapper"
	listWrapper.BackgroundTransparency = 1
	listWrapper.Size = UDim2.new(1, 0, 0, cfg.min_list_height or 0)
	listWrapper.LayoutOrder = 1
	listWrapper.Parent = _window

	_container = Instance.new("ScrollingFrame")
	_container.Name = "Messages"
	_container.Size = UDim2.new(1, 0, 1, 0)
	_container.BackgroundColor3 = tk("background")
	_container.BackgroundTransparency = cfg.backdrop and tk("background_transparency") or 1
	_container.BorderSizePixel = 0
	_container.ScrollBarThickness = cfg.show_scrollbar and 4 or 0
	_container.ScrollBarImageColor3 = tk("subtext")
	_container.CanvasSize = UDim2.new(0, 0, 0, 0)
	_container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	_container.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	_container.Parent = listWrapper
	Skin.corner(_container)

	local layout = Skin.list(_container, nil, Skin.density().gap)
	Skin.pad(_container, 8, 8, 6, 6)

	local function syncWrapperHeight()
		local content = layout.AbsoluteContentSize.Y
		-- fully collapse when empty so the panel doesn't sit as a weird tiny box
		local h = content <= 0 and 0
			or math.clamp(content + 12, cfg.min_list_height or 0, cfg.max_list_height or 400)
		listWrapper.Size = UDim2.new(1, 0, 0, h)
		_container.Visible = content > 0
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(syncWrapperHeight)
	syncWrapperHeight()

	-- resize grip (bottom-right): drag to change width + how tall the list can grow
	if cfg.resizable then
		local grip = Instance.new("TextButton")
		grip.Name = "ResizeGrip"
		grip.AnchorPoint = Vector2.new(1, 1)
		grip.Position = UDim2.new(1, -2, 1, -2)
		grip.Size = UDim2.fromOffset(16, 16)
		grip.BackgroundTransparency = 1
		grip.Text = "⤡"
		grip.TextColor3 = tk("subtext")
		grip.TextSize = 16
		grip.ZIndex = 10
		grip.Parent = listWrapper

		local resizing, startPos, startWidth, startMax = false, nil, 0, 0
		grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				startPos = input.Position
				startWidth = (_window :: Frame).Size.X.Offset
				startMax = cfg.max_list_height or 400
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not resizing then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local d = input.Position - startPos
				;(_window :: Frame).Size = UDim2.new(0, math.max(220, startWidth + d.X), 0, 0)
				cfg.max_list_height = math.max(80, startMax + d.Y)
				syncWrapperHeight()
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = false
			end
		end)
	end

	_container:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		Events.UIScrolled:Fire(_container.CanvasPosition.Y)
	end)

	Render.SetContainer(_container)

	if cfg.show_input then
		Compose.Build(_window)
		Render.ReplyHandler = Compose.SetReplyTarget
		Compose.ToggleHandler = Interface.Toggle
	end
end

-- ─── public ──────────────────────────────────────────────────────────────────

function Interface.Build()
	buildGui()
end

function Interface.Render(message: any): GuiObject?
	if not _container then buildGui() end
	return Render.Render(message)
end

function Interface.ApplyUpdate(id: string, patch: any)
	Render.ApplyUpdate(id, patch)
end

function Interface.Clear()
	Render.Clear()
end

function Interface.SystemMessage(text: string)
	Render.SystemMessage(text)
end

function Interface.SetTheme(theme: Types.Theme)
	for k, v in theme do
		Config.Interface.theme[k] = v
	end
	Events.ThemeChanged:Fire(Config.Interface.theme)
end

function Interface.SetDensity(d: Types.LayoutDensity)
	Config.Interface.density = d
end

function Interface.SetChannelName(name: string)
	local old = Config.Interface.channel_name
	Config.Interface.channel_name = name
	Events.ChannelChanged:Fire(name, old)
	if _header then
		local lbl = _header:FindFirstChildOfClass("TextLabel")
		if lbl then lbl.Text = name end
	end
end

function Interface.Toggle(visible: boolean?)
	if not _gui then return end
	local target = if visible ~= nil then visible else not _gui.Enabled

	if not Config.Interface.open_animation or not _winScale then
		_gui.Enabled = target
		Events.UIToggled:Fire(target)
		return
	end

	if target then
		_gui.Enabled = true
		_winScale.Scale = 0.85
		Motion.tween(_winScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		Motion.tween(_winScale, 0.16, { Scale = 0.85 }, Enum.EasingStyle.Quad)
		task.delay(0.16, function()
			if _gui and _winScale and _winScale.Scale < 0.9 then _gui.Enabled = false end
		end)
	end

	Events.UIToggled:Fire(target)
end

function Interface.FocusInput()
	Compose.Focus()
end

function Interface.GetInputBox(): TextBox?
	return Compose.GetInputBox()
end

function Interface.SetReactHandler(fn: (id: string, emoji: string) -> ())
	Render.ReactHandler = fn
end

function Interface.RegisterRenderer(kind: string, fn: (any, any) -> Frame)
	Render.RegisterRenderer(kind, fn)
end

function Interface.RegisterPanel(name: string, fn: (any, any, any) -> Frame)
	Render.RegisterPanel(name, fn)
end

function Interface.RegisterLineDecorator(fn: (any) -> string?)
	Render.RegisterLineDecorator(fn)
end

function Interface.SetKindStyle(kind: string, textKey: string, prefix: string?, bold: boolean?)
	Render.SetKindStyle(kind, textKey, prefix, bold)
end

function Interface.SetKindOverride(kind: string, bgKey: string, textKey: string)
	Render.SetKindOverride(kind, bgKey, textKey)
end

return Interface
